local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local sent = {}
local basePerformed = 0
isServer = function() return false end
isClient = function() return true end
getText = function(key)
    if key == "ContextMenu_LegacyJournal_Write" then return "写入日志" end
    if key == "ContextMenu_Read" then return "阅读" end
    return key
end
sendClientCommand = function(player, module, command, args)
    table.insert(sent, { player = player, module = module, command = command, args = args })
end

ISBaseTimedAction = {}
function ISBaseTimedAction:derive()
    local action = {}
    action.__index = action
    setmetatable(action, { __index = self })
    return action
end
function ISBaseTimedAction.new(class, character)
    return setmetatable({ character = character, jobDelta = 0 }, class)
end
function ISBaseTimedAction:getJobDelta() return self.jobDelta end
function ISBaseTimedAction.stop() end
function ISBaseTimedAction.perform() basePerformed = basePerformed + 1 end
function ISBaseTimedAction.forceCancel() end
function ISBaseTimedAction:isUsingTimeout() return true end
function ISBaseTimedAction:setAnimVariable() end
function ISBaseTimedAction:setActionAnim() end
function ISBaseTimedAction:setOverrideHandModels() end

package.preload["TimedActions/ISBaseTimedAction"] = function() return ISBaseTimedAction end

LegacyJournal = {
    MODULE = "LegacyJournal",
    WRITE_TEXT_KEY = "ContextMenu_LegacyJournal_Write",
    DEFAULT_ACTION_PROGRESS_PAGES = 1,
}
function LegacyJournal.isWritten(candidate) return candidate.written == true end
package.preload["legacyjournal/legacyjournal_shared"] = function() return LegacyJournal end

CharacterActionAnims = { Read = "Read" }

local item = { id = 777, written = false, displayName = "日记本" }
function item:getID() return self.id end
function item:setJobDelta(value) self.jobDelta = value end
function item:setJobType(value) self.jobType = value end
function item:getContainer() return nil end
function item:getType() return "Diary2" end
function item:getName(character)
    self.lastNameCharacter = character
    if character then return self.displayName end
    return "Diary"
end
function item:getReadType() return "book" end

local player = {}
function player:setReading() end
function player:playSound() end
function player:reportEvent() end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_actions.lua")

local writeStarted = LegacyJournalWriteAction:new(player, item, 120,
    "write-start-token", 0, 40)
writeStarted:start()
assertEqual(item.jobType, "写入日志",
    "first write keeps action-only title")

item.written = true
item.displayName = "凯恩的日志本"
local updateStarted = LegacyJournalWriteAction:new(player, item, 120,
    "update-start-token", 0, 40)
updateStarted:start()
assertEqual(item.jobType, "写入日志 凯恩的日志本",
    "updated written journal keeps its localized custom title")
assertEqual(item.lastNameCharacter, player,
    "written journal title uses player-aware vanilla name lookup")

local readStarted = LegacyJournalReadAction:new(player, item, 90,
    "read-start-token", 0, 40)
readStarted:start()
assertEqual(item.jobType, "阅读 凯恩的日志本",
    "read job title keeps the written journal custom title")

item.displayName = ""
local blankNameStarted = LegacyJournalWriteAction:new(player, item, 120,
    "blank-name-token", 0, 40)
blankNameStarted:start()
assertEqual(item.jobType, "写入日志",
    "blank localized name falls back to action text without internal Diary")

local completed = LegacyJournalWriteAction:new(player, item, 120,
    "write-token", 0, 40)
completed.jobDelta = 1
completed:perform()
assertEqual(basePerformed, 1, "client perform reaches base action")
assertEqual(#sent, 1, "client completion sends one command")
assertEqual(sent[1].command, "commit", "client completion command")
assertEqual(sent[1].args.action, "write", "client completion action")
assertEqual(sent[1].args.itemId, 777, "client completion item")
assertEqual(sent[1].args.token, "write-token", "client completion token")

local interrupted = LegacyJournalWriteAction:new(player, item, 120,
    "cancel-token", 0, 40)
interrupted.jobDelta = 0.25
interrupted:stop()
assertEqual(#sent, 2, "interruption sends one cancellation command")
assertEqual(sent[2].command, "cancel", "interruption command")
assertEqual(sent[2].args.page, 10, "interruption saves completed pages")

local resumed = LegacyJournalReadAction:new(player, item, 90,
    "read-token", 10, 40)
resumed.jobDelta = 0.5
resumed:update()
assertEqual(#sent, 3, "page crossing sends one checkpoint")
assertEqual(sent[3].command, "checkpoint", "checkpoint command")
assertEqual(sent[3].args.action, "read", "checkpoint action")
assertEqual(sent[3].args.page, 25, "checkpoint includes overall page")
resumed:update()
assertEqual(#sent, 3, "same page does not duplicate checkpoint")

resumed.jobDelta = 1
resumed:perform()
assertEqual(basePerformed, 2, "read perform reaches base action")
assertEqual(#sent, 4, "read completion sends one command")
assertEqual(sent[4].command, "commit", "read completion command")
assertEqual(sent[4].args.action, "read", "read completion action")

assertEqual(completed:isUsingTimeout(), true,
    "journal uses normal timed completion")

print("Legacy Journal client action protocol tests: PASS")
