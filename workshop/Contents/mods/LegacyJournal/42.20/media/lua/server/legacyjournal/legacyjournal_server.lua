require "legacyjournal/legacyjournal_shared"
require "legacyjournal/legacyjournal_skillbook_compat"

local LJ = LegacyJournal
local SYNC_CHUNK_SIZE = 50
-- Weak references are an index of live native actions, not a second protocol
-- or lifetime owner. Native cancellation/completion/disconnect owns lifetime.
LJ.activeJournalActions = setmetatable({}, { __mode = "kv" })

local function sendResult(player, command, args, recipientKey)
    args.onlineID = player:getOnlineID()
    args.recipientKey = recipientKey
    sendServerCommand(player, LJ.MODULE, command, args)
end

local function sendItemFields(player, item, recipientKey)
    if not sendServerCommand or not player or not item then return end
    sendResult(player, "itemFields", {
        itemId = item:getID(),
        authorName = tostring(item:getModData().LJ_authorName or ""),
        writtenAt = tostring(item:getModData().LJ_writtenAt or ""),
    }, recipientKey)
end

local function slice(values, firstIndex, lastIndex)
    local result = {}
    for index = firstIndex, math.min(lastIndex, #values) do
        table.insert(result, values[index])
    end
    return result
end

local function sendReadFields(player, fields, recipientKey)
    if not sendServerCommand or not player then return end
    fields = fields or { recipes = {}, mediaLines = {} }
    local recipes = fields.recipes or {}
    local mediaLines = fields.mediaLines or {}
    local count = math.max(#recipes, #mediaLines)

    if count == 0 then
        sendResult(player, "readFields", {
            final = true,
            skillBooks = fields.skillBooks,
            skillBookStates = fields.skillBookStates,
            hasExactSkillBookSnapshot = fields.hasExactSkillBookSnapshot == true,
        }, recipientKey)
        return
    end

    for firstIndex = 1, count, SYNC_CHUNK_SIZE do
        local lastIndex = firstIndex + SYNC_CHUNK_SIZE - 1
        local final = lastIndex >= count
        sendResult(player, "readFields", {
            recipes = slice(recipes, firstIndex, lastIndex),
            mediaLines = slice(mediaLines, firstIndex, lastIndex),
            final = final,
            skillBooks = final and fields.skillBooks or nil,
            skillBookStates = final and fields.skillBookStates or nil,
            hasExactSkillBookSnapshot = final
                and fields.hasExactSkillBookSnapshot == true or false,
        }, recipientKey)
    end
end


function LJ.sendJournalResult(player, item, fields, recipientKey)
    sendItemFields(player, item, recipientKey)
    if fields then sendReadFields(player, fields, recipientKey) end
end

local function onClientCommand(module, command, player, args)
    if module ~= LJ.MODULE or not player or type(args) ~= "table" then return end
    if command == "readStatus" then
        if type(args.itemIds) ~= "table" or type(args.requestId) ~= "number" then return end
        local readable = {}
        for index = 1, math.min(#args.itemIds, LJ.MAX_READ_STATUS_ITEMS) do
            local item = LJ.findItemById(player, args.itemIds[index])
            if item and LJ.isActionContextValid(player, item, "read")
                and LJ.getReadDelta(player, item).multiplierRepair == true then
                table.insert(readable, item:getID())
            end
        end
        sendServerCommand(player, LJ.MODULE, "readStatus", {
            onlineID = player:getOnlineID(), requestId = args.requestId,
            readableItems = readable,
        })
        return
    end
    if command ~= "checkpoint" then return end
    local action = LJ.activeJournalActions[player]
    if action and not action.finished and not action.rejected
        and args.kind == action.kind and tonumber(args.itemId) == action.item:getID() then
        action:saveProgress()
    end
end

Events.OnClientCommand.Add(onClientCommand)
print("[LegacyJournal] server loaded build=" .. LJ.BUILD)
