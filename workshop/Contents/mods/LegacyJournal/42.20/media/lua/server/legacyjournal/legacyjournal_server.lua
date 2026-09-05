require "legacyjournal/legacyjournal_shared"
require "legacyjournal/legacyjournal_skillbook_compat"

local LJ = LegacyJournal
local SYNC_CHUNK_SIZE = 50
-- Weak references are an index of live native actions, not a second protocol
-- or lifetime owner. Native cancellation/completion/disconnect owns lifetime.
LJ.activeJournalActions = setmetatable({}, { __mode = "kv" })

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


function LJ.sendJournalResult(player, item, fields)
    sendItemFields(player, item)
    if fields then sendReadFields(player, fields) end
end

local function onClientCommand(module, command, player, args)
    if module ~= LJ.MODULE or command ~= "checkpoint" or not player or not args then return end
    local action = LJ.activeJournalActions[player]
    if action and not action.finished and not action.rejected
        and args.kind == action.kind and tonumber(args.itemId) == action.item:getID() then
        action:saveProgress()
    end
end

Events.OnClientCommand.Add(onClientCommand)
print("[LegacyJournal] server loaded build=" .. LJ.BUILD)
