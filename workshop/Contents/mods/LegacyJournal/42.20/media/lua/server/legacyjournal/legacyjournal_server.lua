require "legacyjournal/legacyjournal_shared"
require "legacyjournal/legacyjournal_skillbook_compat"

local LJ = LegacyJournal
local pendingActions = {}
local nextToken = 0
local SYNC_CHUNK_SIZE = 50
local BUILD = "20260825-stack-state-hotfix-1"
local ACTION_ABANDON_MS = 2 * 60 * 60 * 1000

local function protocolTrace(event, player, action, itemId, reason)
    local username = "unknown"
    if player and player.getUsername then
        local ok, value = pcall(player.getUsername, player)
        if ok and value then username = tostring(value) end
    end
    print("[LegacyJournal] protocol build=" .. BUILD
        .. " event=" .. tostring(event)
        .. " user=" .. username
        .. " action=" .. tostring(action)
        .. " item=" .. tostring(itemId)
        .. " reason=" .. tostring(reason or "ok"))
end

local function syncJournalItem(item)
    if item then
        item:syncItemFields()
    end
end

local function sendItemFields(player, item)
    if not sendServerCommand or not player or not item then return end
    sendServerCommand(player, LJ.MODULE, "itemFields", {
        itemId = item:getID(),
        authorName = tostring(item:getModData().LJ_authorName or ""),
        writtenAt = tostring(item:getModData().LJ_writtenAt or ""),
    })
end

local function slice(values, firstIndex, lastIndex)
    local result = {}
    for index = firstIndex, math.min(lastIndex, #values) do
        table.insert(result, values[index])
    end
    return result
end

local function sendReadFields(player, fields)
    if not sendServerCommand or not player then return end
    fields = fields or { recipes = {}, mediaLines = {} }
    local recipes = fields.recipes or {}
    local mediaLines = fields.mediaLines or {}
    local count = math.max(#recipes, #mediaLines)

    if count == 0 then
        sendServerCommand(player, LJ.MODULE, "readFields", {
            final = true,
            skillBooks = fields.skillBooks,
            skillBookStates = fields.skillBookStates,
            hasExactSkillBookSnapshot = fields.hasExactSkillBookSnapshot == true,
        })
        return
    end

    for firstIndex = 1, count, SYNC_CHUNK_SIZE do
        local lastIndex = firstIndex + SYNC_CHUNK_SIZE - 1
        local final = lastIndex >= count
        sendServerCommand(player, LJ.MODULE, "readFields", {
            recipes = slice(recipes, firstIndex, lastIndex),
            mediaLines = slice(mediaLines, firstIndex, lastIndex),
            final = final,
            skillBooks = final and fields.skillBooks or nil,
            skillBookStates = final and fields.skillBookStates or nil,
            hasExactSkillBookSnapshot = final
                and fields.hasExactSkillBookSnapshot == true or false,
        })
    end
end

local function nowMs()
    if not getTimestampMs then return nil end
    local ok, timestamp = pcall(getTimestampMs)
    if ok and tonumber(timestamp) then return math.floor(tonumber(timestamp)) end
    return nil
end

local function getActionDelta(player, item, action)
    if action == "write" then
        if not LJ.isSupportedItem(item) then return nil end
        if LJ.isWritten(item) and not LJ.isSupportedRecord(item) then return nil end
        if not LJ.hasWritingTool(player) then return nil end
        if not LJ.canCurrentCharacterUpdate(player, item) then return nil end
        local delta = LJ.getWriteDelta(player, item)
        if not LJ.hasDelta(delta) then return nil end
        return delta, LJ.getWriteTime(delta, player)
    end

    if action == "read" then
        if not LJ.isWritten(item) or not LJ.isSupportedRecord(item) then return nil end
        if not LJ.isAuthor(player, item) then return nil end
        local delta = LJ.getReadDelta(player, item)
        if not LJ.hasDelta(delta) then return nil end
        return delta, LJ.getReadTime(delta, player)
    end
    return nil
end

local function getBeginDeltaSummary(item, delta)
    local md = item and item:getModData() or {}
    return "written=" .. tostring(md.LJ_written == true)
        .. " deltaXp=" .. tostring(delta.xp or 0)
        .. " skills=" .. tostring(delta.skills or 0)
        .. " recipes=" .. tostring(delta.recipes or 0)
        .. " books=" .. tostring(delta.books or 0)
        .. " vhs=" .. tostring(delta.vhs or 0)
end

local function makeToken()
    nextToken = nextToken + 1
    return tostring(nextToken) .. ":" .. tostring(nowMs())
end

function LJ.serverBeginAction(player, action, itemId)
    if pendingActions[player] then
        protocolTrace("begin-denied", player, action, itemId, "action-already-pending")
        return nil
    end

    local item = LJ.findItemById(player, itemId)
    if not item then
        protocolTrace("begin-denied", player, action, itemId, "item-not-found")
        return nil
    end

    local delta, duration = getActionDelta(player, item, action)
    if not duration then
        protocolTrace("begin-denied", player, action, itemId, "invalid-or-empty-delta")
        return nil
    end

    local signature = LJ.getActionSignature(action, item, delta)
    local actorKey = LJ.getActionActorKey(player)
    local totalPages = LJ.getActionPageCount(action, delta)
    local startPage = LJ.getSavedActionPage(item, action, signature,
        actorKey, totalPages)
    LJ.saveActionProgress(item, action, signature, actorKey, startPage, totalPages)

    local startedAt = nowMs()
    local state = {
        action = action,
        itemId = item:getID(),
        token = makeToken(),
        delta = delta,
        signature = signature,
        actorKey = actorKey,
        totalDuration = duration,
        duration = LJ.getRemainingActionTime(duration, startPage, totalPages),
        startPage = startPage,
        completedPage = startPage,
        totalPages = totalPages,
        expiresAt = startedAt and (startedAt + ACTION_ABANDON_MS) or nil,
    }
    pendingActions[player] = state
    protocolTrace("begin-accepted", player, action, state.itemId,
        "duration=" .. tostring(duration)
        .. " startPage=" .. tostring(startPage)
        .. " totalPages=" .. tostring(totalPages)
        .. " " .. getBeginDeltaSummary(item, delta))
    return state
end

function LJ.serverCommitAction(player, action, itemId, token)
    local state = pendingActions[player]
    if not state then
        protocolTrace("commit-denied", player, action, itemId, "no-pending-action")
        return false
    end
    if state.action ~= action or tonumber(state.itemId) ~= tonumber(itemId)
        or state.token ~= tostring(token or "") then
        protocolTrace("commit-denied", player, action, itemId, "action-mismatch")
        return false
    end

    local currentTime = nowMs()
    if currentTime and state.expiresAt and currentTime > state.expiresAt then
        pendingActions[player] = nil
        protocolTrace("commit-denied", player, action, itemId, "abandoned")
        return false
    end
    -- A matched action token is single-use even when final revalidation fails.
    pendingActions[player] = nil

    local item = LJ.findItemById(player, itemId)
    if not item then
        protocolTrace("commit-denied", player, action, itemId, "item-not-found")
        return false
    end
    local delta = getActionDelta(player, item, action)
    if not delta then
        protocolTrace("commit-denied", player, action, itemId, "delta-changed")
        return false
    end
    if LJ.getActionSignature(action, item, delta) ~= state.signature then
        protocolTrace("commit-denied", player, action, itemId, "signature-changed")
        return false
    end

    local committed = false
    local readFields = nil
    if action == "write" then
        committed = LJ.commitWrite(player, item)
    elseif action == "read" then
        committed, readFields = LJ.applyRead(player, item)
    end
    if not committed then
        protocolTrace("commit-denied", player, action, itemId, "commit-rejected")
        return false
    end

    syncJournalItem(item)
    if action == "write" then
        sendItemFields(player, item)
    else
        sendReadFields(player, readFields)
        -- Display names are localized by the owning client. The server only
        -- sends stable author data and never persists its own locale here.
        sendItemFields(player, item)
    end
    protocolTrace("commit-accepted", player, action, itemId)
    return true
end

function LJ.serverCheckpointAction(player, action, itemId, token, page, cancel)
    local state = pendingActions[player]
    if not state then
        protocolTrace(cancel and "cancel-denied" or "checkpoint-denied",
            player, action, itemId, "no-pending-action")
        return false
    end
    if state.action ~= action or tonumber(state.itemId) ~= tonumber(itemId)
        or state.token ~= tostring(token or "") then
        protocolTrace(cancel and "cancel-denied" or "checkpoint-denied",
            player, action, itemId, "action-mismatch")
        return false
    end

    local item = LJ.findItemById(player, itemId)
    if not item then
        protocolTrace(cancel and "cancel-denied" or "checkpoint-denied",
            player, action, itemId, "item-not-found")
        return false
    end

    local completedPage = math.max(state.completedPage or state.startPage,
        state.startPage,
        math.min(state.totalPages, math.floor(tonumber(page) or state.startPage)))
    state.completedPage = completedPage
    LJ.saveActionProgress(item, action, state.signature, state.actorKey,
        completedPage, state.totalPages)
    syncJournalItem(item)
    if cancel then pendingActions[player] = nil end
    protocolTrace(cancel and "cancel-accepted" or "checkpoint-accepted",
        player, action, itemId, "page=" .. tostring(completedPage))
    return true
end

function LJ.serverCancelAction(player, action, itemId, token, page)
    return LJ.serverCheckpointAction(player, action, itemId, token, page, true)
end

function LJ.serverExpireActions()
    local currentTime = nowMs()
    if not currentTime then return 0 end
    local expired = 0
    for player, state in pairs(pendingActions) do
        if not state or (state.expiresAt and currentTime > state.expiresAt) then
            pendingActions[player] = nil
            expired = expired + 1
        end
    end
    return expired
end

local function clearPlayerAction(player)
    if player then pendingActions[player] = nil end
end

local function addServerEvent(name, handler)
    local event = Events and Events[name]
    if not event then return false end
    return pcall(function() event.Add(handler) end)
end

local function sendBegin(player, action, itemId)
    local state = LJ.serverBeginAction(player, action, itemId)
    if state and sendServerCommand then
        sendServerCommand(player, LJ.MODULE, "begin", {
            action = state.action,
            itemId = state.itemId,
            token = state.token,
            duration = state.duration,
            startPage = state.startPage,
            totalPages = state.totalPages,
        })
    elseif sendServerCommand then
        sendServerCommand(player, LJ.MODULE, "beginDenied", {
            action = action,
            itemId = itemId,
        })
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= LJ.MODULE or not player or not args then return end
    if command == "begin" then
        sendBegin(player, args.action, args.itemId)
    elseif command == "checkpoint" then
        LJ.serverCheckpointAction(player, args.action, args.itemId,
            args.token, args.page, false)
    elseif command == "cancel" then
        LJ.serverCancelAction(player, args.action, args.itemId,
            args.token, args.page)
    elseif command == "commit" then
        LJ.serverCommitAction(player, args.action, args.itemId, args.token)
    end
end

Events.OnClientCommand.Add(onClientCommand)
if Events.EveryOneMinute then Events.EveryOneMinute.Add(LJ.serverExpireActions) end
addServerEvent("OnPlayerDisconnect", clearPlayerAction)
addServerEvent("OnPlayerDisconnected", clearPlayerAction)

print("[LegacyJournal] server loaded build=" .. BUILD)
