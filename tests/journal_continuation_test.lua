local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

CharacterTrait = { FAST_READER = "fast", SLOW_READER = "slow" }
ItemTag = { READING_GLASSES = "reading-glasses" }
getSandboxOptions = function()
    return {
        getOptionByName = function(_, name)
            local values = {
                MinutesPerPage = 2,
                ["LegacyJournal.WriteTimeMultiplier"] = 1,
                ["LegacyJournal.ReadTimeMultiplier"] = 1,
            }
            local value = values[name]
            if value == nil then return nil end
            return { getValue = function() return value end }
        end,
    }
end
getGameTime = function()
    return { getMinutesPerDay = function() return 120 end }
end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")
local LJ = LegacyJournal

local function makeItem(fullType)
    local item = { fullType = fullType, modData = {} }
    function item:getFullType() return self.fullType end
    function item:getModData() return self.modData end
    return item
end

local diaryOne = makeItem("Base.Diary1")
local diaryTwo = makeItem("Base.Diary2")
local notebook = makeItem("Base.Notebook")
assertEqual(LJ.isSupportedItem(diaryOne), true, "Diary1 supported")
assertEqual(LJ.isSupportedItem(diaryTwo), true, "Diary2 supported")
assertEqual(LJ.isSupportedItem(notebook), false, "ordinary notebook excluded")

local player = { fast = false }
function player:hasTrait(trait) return trait == CharacterTrait.FAST_READER and self.fast end
function player:getWornItem() return nil end
function player:isSitOnGround() return false end

local delta = { xp = 1, skills = 1, recipes = 0, books = 0, vhs = 0 }
assertEqual(LJ.getActionPageCount("write", delta), 6,
    "small write delta generates six pages")
assertEqual(LJ.getActionPageCount("read", delta), 7,
    "small read delta generates seven pages")
assertEqual(LJ.getWriteTime(delta, player), 2880,
    "write duration uses generated pages and vanilla page time")
assertEqual(LJ.getReadTime(delta, player), 3360,
    "read duration uses generated pages and vanilla page time")
player.fast = true
assertEqual(LJ.getReadTime(delta, player), 2352,
    "fast reader uses vanilla modifier")

local signature = "snapshot-a"
local actor = "actor-a"
LJ.saveActionProgress(diaryOne, "write", signature, actor, 2, 8)
assertEqual(LJ.getSavedActionPage(diaryOne, "write", signature, actor, 8),
    2, "matching continuation restored")
LJ.saveActionProgress(diaryOne, "write", signature, actor, 2, 8)
assertEqual(LJ.getSavedActionPage(diaryOne, "write", "snapshot-b", actor, 4),
    2, "continuation survives a changed snapshot signature")
LJ.saveActionProgress(diaryOne, "write", signature, actor, 10, 40)
assertEqual(LJ.getSavedActionPage(diaryOne, "write", signature, actor, 8),
    8, "continuation clamps to a reduced page count")
assertEqual(diaryOne.modData.LJ_progressModelVersion,
    LJ.ACTION_PROGRESS_MODEL_VERSION, "new checkpoint stores progress model")
assertEqual(LJ.getRemainingActionTime(3840, 2, 8), 2880,
    "remaining duration follows remaining pages")
assertEqual(LJ.getSavedActionPage(diaryOne, "write", signature, "actor-b", 8),
    0, "different character cannot inherit continuation")
LJ.clearActionProgress(diaryOne)
assertEqual(LJ.getSavedActionPage(diaryOne, "write", signature, actor, 8),
    0, "completed action clears continuation")
assertEqual(diaryOne.modData.LJ_progressModelVersion, nil,
    "completed action clears progress model")

local legacyDiary = makeItem("Base.Diary1")
legacyDiary.modData.LJ_progressAction = "write"
legacyDiary.modData.LJ_progressSignature = "legacy-snapshot"
legacyDiary.modData.LJ_progressActor = actor
legacyDiary.modData.LJ_progressPage = 500
legacyDiary.modData.LJ_progressTotalPages = 1000
assertEqual(LJ.getSavedActionPage(legacyDiary, "write", signature, actor, 700),
    350, "unversioned 1.01 checkpoint preserves completed proportion")

legacyDiary.modData.LJ_progressModelVersion = 99
assertEqual(LJ.getSavedActionPage(legacyDiary, "write", signature, actor, 700),
    0, "unknown explicit progress models are not guessed")

print("Legacy Journal continuation tests: PASS")
