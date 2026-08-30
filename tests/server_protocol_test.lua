local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local clock = 1000
local clientCommandHandler = nil
getTimestampMs = function() return clock end
sendServerCommand = function() end
Events = {
    OnClientCommand = { Add = function(handler) clientCommandHandler = handler end },
    EveryOneMinute = { Add = function() end },
}

local function makeItem(id, fullType)
    local item = { id = id, fullType = fullType or "Base.Diary2", modData = {} }
    function item:getID() return self.id end
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    function item:syncItemFields() self.synced = (self.synced or 0) + 1 end
    return item
end

local nestedJournal = makeItem(777)
local diaryOne = makeItem(778, "Base.Diary1")
local nestedBag = { items = { nestedJournal, diaryOne } }
local inventory = { items = { nestedBag } }

function inventory:getItemWithIDRecursiv(id)
    local function find(items)
        for _, entry in ipairs(items) do
            if entry.items then
                local found = find(entry.items)
                if found then return found end
            elseif entry:getID() == id then
                return entry
            end
        end
        return nil
    end
    return find(self.items)
end

local descriptor = {}
function descriptor:getForename() return "Test" end
function descriptor:getSurname() return "Player" end
function descriptor:getID() return 99 end

local player = {}
function player:getInventory() return inventory end
function player:getDescriptor() return descriptor end
function player:getUsername() return "tester" end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")
package.preload["legacyjournal/legacyjournal_shared"] = function() return LegacyJournal end
package.preload["legacyjournal/legacyjournal_skillbook_compat"] = function() return true end
dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/server/legacyjournal/legacyjournal_server.lua")

local LJ = LegacyJournal
local commits = 0
local valid = true
local changedXp = 0
LJ.hasWritingTool = function() return valid end
LJ.canCurrentCharacterUpdate = function() return valid end
LJ.getWriteDelta = function()
    if not valid then return { xp = 0, skills = 0, recipes = 0, books = 0, vhs = 0 } end
    return {
        xp = changedXp,
        skills = 1,
        recipes = 0,
        books = 0,
        vhs = 0,
        mergedSkills = { Woodwork = changedXp + 10 },
        mergedRecipes = {},
        mergedBooks = {},
        mergedBookStates = {},
        mergedMedia = {},
    }
end
LJ.getWriteTime = function() return 120 end
LJ.commitWrite = function()
    commits = commits + 1
    return true
end

assertEqual(LJ.findItemById(player, 777), nestedJournal, "nested journal lookup")
assertEqual(LJ.isSupportedItem(diaryOne), true, "Diary1 is supported")
assertEqual(type(clientCommandHandler), "function", "client command route registered")

local state = LJ.serverBeginAction(player, "write", 777)
assertEqual(state.action, "write", "begin action")
assertEqual(state.itemId, 777, "begin item id")
assertEqual(state.delta.skills, 1, "server computed delta")
assertEqual(state.duration, 120, "server computed initial duration")
assertEqual(state.startPage, 0, "initial action starts at page zero")
assertEqual(state.totalPages, 6, "journal pages derive from 1.02 content formula")
assertEqual(type(state.token), "string", "per-action token")
assertEqual(LJ.serverBeginAction(player, "write", 777), nil,
    "a second begin cannot replace an active action token")

assertEqual(LJ.serverCheckpointAction(player, "write", 777,
    state.token, 2, false), true, "checkpoint accepted")
assertEqual(nestedJournal.modData.LJ_progressPage, 2,
    "checkpoint persisted on journal")
assertEqual(LJ.serverCancelAction(player, "write", 777,
    state.token, 3), true, "interruption saves final page")
assertEqual(nestedJournal.modData.LJ_progressPage, 3,
    "interruption persisted latest page")
assertEqual(LJ.serverCommitAction(player, "write", 777,
    state.token), false, "cancelled token cannot commit")

state = LJ.serverBeginAction(player, "write", 777)
assertEqual(state.startPage, 3, "new action resumes saved page")
assertEqual(state.duration, 60, "new action uses remaining duration")
assertEqual(LJ.serverCommitAction(player, "read", 777,
    state.token), false, "action mismatch rejected")
assertEqual(LJ.serverCommitAction(player, "write", 778,
    state.token), false, "item mismatch rejected")
assertEqual(LJ.serverCommitAction(player, "write", 777,
    "wrong"), false, "token mismatch rejected")

clientCommandHandler("LegacyJournal", "commit", player, {
    action = "write", itemId = 777, token = state.token,
})
assertEqual(commits, 1, "client commit route applies once")
assertEqual(nestedJournal.synced, 3, "checkpoints and commit synchronize journal")
assertEqual(LJ.serverCommitAction(player, "write", 777,
    state.token), false, "duplicate commit rejected")

clock = clock + 1000
state = LJ.serverBeginAction(player, "write", 777)
valid = false
assertEqual(LJ.serverCommitAction(player, "write", 777,
    state.token), false, "commit revalidates state")
assertEqual(commits, 1, "failed revalidation does not apply")

valid = true
changedXp = 0
clock = clock + 1000
state = LJ.serverBeginAction(player, "write", 777)
changedXp = 10
assertEqual(LJ.serverCommitAction(player, "write", 777,
    state.token), false, "changed action payload is rejected")
assertEqual(commits, 1, "changed payload does not apply")

changedXp = 0
clock = clock + 1000
state = LJ.serverBeginAction(player, "write", 777)
clock = state.expiresAt + 1
assertEqual(LJ.serverExpireActions(), 1, "abandoned action is removed")
assertEqual(LJ.serverCommitAction(player, "write", 777,
    state.token), false, "abandoned token cannot commit")

print("Legacy Journal server protocol tests: PASS")
