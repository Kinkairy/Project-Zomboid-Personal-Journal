-- Personal Journal 1.3.2: read-only, action-scoped progress presentation.
-- No custom begin/commit protocol, client-supplied workload or local completion.
require "legacyjournal/legacyjournal_shared"
local LJ = LegacyJournal
LJ.PROGRESS_VIEW_SCALE = 1000000 -- normalized UI scale, NOT a reading duration
local POLL_MS, STALE_MS = 500, 3000
local views = setmetatable({}, { __mode = "k" })
LJ._progressKeyCounter = LJ._progressKeyCounter or 0

local function now() return getTimestampMs() end
local function finite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function integer(n) return finite(n) and n == math.floor(n) end
function LJ.isProgressKey(key)
    return type(key) == "string" and #key > 0 and #key <= 96
end
function LJ.newProgressKey()
    LJ._progressKeyCounter = LJ._progressKeyCounter + 1
    return tostring(now()) .. ":" .. tostring(LJ._progressKeyCounter)
end

-- The key only routes a response to the exact action instance. It is never
-- used as authorization; the existing native action/connection owns that.
function LJ.beginProgressView(action, label)
    if not isClient() then return end
    views[action.character] = action
    action.progressView = { value = 0, sequence = 0, phase = "waiting",
        label = label, nextPoll = 0, receivedAt = nil }
    action.action:setTime(LJ.PROGRESS_VIEW_SCALE)
    action:setJobDelta(0)
end
function LJ.endProgressView(action)
    if views[action.character] == action then views[action.character] = nil end
    action.progressView = nil
end

local function setLabel(action, key)
    local v = action.progressView
    local label = key and getText(key, v.label) or v.label
    if v.displayLabel ~= label then
        v.displayLabel = label
        action.item:setJobType(label)
        local container = action.item:getContainer()
        if container then container:setDrawDirty(true) end
    end
end
local function draw(action)
    local v = action.progressView
    local progress = v.value
    local total = v.pages and (v.startPage + (v.pages - v.startPage) * progress) / v.pages
        or action.plan.startPage / action.plan.pages
    -- setJobDelta also sets BaseAction.currentTime. Pin it to the last actual
    -- server sample every frame; do not extrapolate a guessed finish time.
    -- LuaTimedActionNew checks native Done/Reject AFTER the Lua update, so
    -- pinning this view never takes over or suppresses native completion.
    action:setJobDelta(progress)
    action.item:setJobDelta(total)
    -- BaseAction paints its locally advanced bar BEFORE Lua update. Repaint
    -- only this active local action's bar with the same cumulative fraction.
    UIManager.getProgressBar(action.character:getPlayerNum()):setValue(total)
    local age = now() - (v.receivedAt or 0)
    if v.phase == "complete" then
        setLabel(action, "IGUI_LegacyJournal_WaitActionDone")
    elseif v.phase == "applying" then
        setLabel(action, "IGUI_LegacyJournal_Applying")
    elseif not v.receivedAt or age > STALE_MS or age < 0 then
        setLabel(action, "IGUI_LegacyJournal_WaitServer")
    elseif progress >= 1 then
        setLabel(action, "IGUI_LegacyJournal_WaitActionDone")
    else
        setLabel(action, nil)
    end
end
function LJ.updateProgressView(action)
    local v = action.progressView
    if not v or views[action.character] ~= action then return end
    local t = now()
    if t >= v.nextPoll or t < v.nextPoll - POLL_MS then
        v.nextPoll = t + POLL_MS
        -- Only identification is sent, never progress, duration or knowledge.
        local ok, err = pcall(sendClientCommand, action.character, LJ.MODULE, "progress", {
            itemId = action.item:getID(), kind = action.kind,
            progressKey = action.progressKey,
        })
        if not ok and not v.warningLogged then
            v.warningLogged = true
            print("[LegacyJournal] progress request failed: " .. tostring(err))
        end
    end
    draw(action)
end

-- Telemetry failure must not abort a native action or a knowledge commit.
function LJ.publishActionProgress(action, phase)
    if not isServer() or not action.plan or not LJ.isProgressKey(action.progressKey) then return end
    local ok, err = pcall(function()
        local p = action.plan
        local value = phase == "complete" and 1 or action.netAction:getProgress()
        if not finite(value) then return end
        action.progressSequence = (action.progressSequence or 0) + 1
        sendServerCommand(action.character, LJ.MODULE, "progress", {
            onlineID = action.character:getOnlineID(), recipientKey = action.recipientKey,
            itemId = action.item:getID(), kind = action.kind, progressKey = action.progressKey,
            sequence = action.progressSequence, phase = phase,
            progress = math.max(0, math.min(1, value)), pages = p.pages, startPage = p.startPage,
        })
    end)
    if not ok and not action.progressWarningLogged then
        action.progressWarningLogged = true
        print("[LegacyJournal] progress view send failed: " .. tostring(err))
    end
end

local function receiveRequest(module, command, player, args)
    if not isServer() or module ~= LJ.MODULE or command ~= "progress"
        or not player or type(args) ~= "table" then return end
    local action = LJ.activeJournalActions and LJ.activeJournalActions[player]
    if not action or action.finished or action.rejected or not action.plan
        or args.progressKey ~= action.progressKey or args.kind ~= action.kind
        or tonumber(args.itemId) ~= action.item:getID() then return end
    local t = now()
    if action.lastProgressReply and t >= action.lastProgressReply
        and t - action.lastProgressReply < POLL_MS then return end
    action.lastProgressReply = t
    -- Existing authoritative checkpoint implementation, sampled on a clock
    -- rather than only when the client's already-full bar crosses a page.
    action:saveProgress()
    LJ.publishActionProgress(action, "running")
end
local phaseRank = { running = 1, applying = 2, complete = 3, rejected = 3, cancelled = 3 }
local function receiveReply(module, command, args)
    if not isClient() or module ~= LJ.MODULE or command ~= "progress"
        or type(args) ~= "table" or not integer(args.onlineID) or args.onlineID < 0 then return end
    local player = getPlayerByOnlineID(args.onlineID)
    local action = player and views[player]
    local v = action and action.progressView
    if not v or not player:isLocalPlayer() or player:isDead()
        or args.recipientKey ~= LJ.getActionActorKey(player)
        or args.progressKey ~= action.progressKey or args.kind ~= action.kind
        or tonumber(args.itemId) ~= action.item:getID()
        or LJ.findItemById(player, args.itemId) ~= action.item
        or not integer(args.sequence) or args.sequence <= v.sequence
        or not phaseRank[args.phase] or not finite(args.progress)
        or args.progress < 0 or args.progress > 1
        or not integer(args.pages) or args.pages < 1
        or not integer(args.startPage) or args.startPage < 0 or args.startPage > args.pages then return end
    if v.pages and (args.pages ~= v.pages or args.startPage ~= v.startPage) then return end
    if (phaseRank[v.phase] or 0) > phaseRank[args.phase] then return end
    if args.progress < v.value then return end
    v.sequence, v.receivedAt, v.phase = args.sequence, now(), args.phase
    v.pages, v.startPage, v.value = args.pages, args.startPage, args.progress
    if args.phase == "rejected" or args.phase == "cancelled" then
        -- No reward and no forceComplete. Native validity/cancel handles cleanup.
        action.rejected = true
    end
end
Events.OnClientCommand.Add(receiveRequest)
Events.OnServerCommand.Add(receiveReply)
