local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTrue(value, label)
    if not value then error(label) end
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

local player = {}
function player:hasTrait() return false end
function player:getWornItem() return nil end
function player:isSitOnGround() return false end

assertEqual(LJ.ACTION_PAGE_RATE_NUMERATOR, 7,
    "page formula uses seven pages per rate interval")
assertEqual(LJ.ACTION_PAGE_RATE_DENOMINATOR, 1000,
    "page formula uses one thousand content units per rate interval")
assertEqual(LJ.getPagesForContentUnits(100000), 700,
    "content that formerly produced one thousand pages now produces seven hundred")
assertEqual(LJ.getPagesForContentUnits(142), 1,
    "single final rounding stays below the first boundary")
assertEqual(LJ.getPagesForContentUnits(143), 2,
    "single final rounding crosses the first boundary")

local empty = { xp = 0, skills = 0, recipes = 0, books = 0, vhs = 0 }
assertEqual(LJ.getActionPageCount("write", empty), 5,
    "write base generates five pages")
assertEqual(LJ.getActionPageCount("read", empty), 7,
    "read base generates seven pages")

local small = { xp = 1, skills = 1, recipes = 0, books = 0, vhs = 0 }
assertEqual(LJ.getActionPageCount("write", small), 6,
    "small write delta rounds up once")
assertEqual(LJ.getActionPageCount("read", small), 7,
    "small read delta rounds up once")

assertEqual(LJ.getActionPageCount("write",
    { xp = 0, skills = 1, recipes = 0, books = 0, vhs = 0 }), 6,
    "changed skill contributes pages")
assertEqual(LJ.getActionPageCount("write",
    { xp = 0, skills = 0, recipes = 1, books = 0, vhs = 0 }), 5,
    "recipe contributes pages")
assertEqual(LJ.getActionPageCount("write",
    { xp = 0, skills = 0, recipes = 0, books = 1, vhs = 0 }), 5,
    "skill book contributes pages")
assertEqual(LJ.getActionPageCount("write",
    { xp = 0, skills = 0, recipes = 0, books = 0, vhs = 1 }), 5,
    "training media contributes pages")

local xp100 = { xp = 100, skills = 0, recipes = 0, books = 0, vhs = 0 }
local xp101 = { xp = 101, skills = 0, recipes = 0, books = 0, vhs = 0 }
assertTrue(LJ.getActionPageCount("write", xp101)
    >= LJ.getActionPageCount("write", xp100),
    "XP block rounding is monotonic across 100 XP")

local rich = { xp = 10000, skills = 5, recipes = 10, books = 5, vhs = 10 }
assertEqual(LJ.getActionPageCount("write", rich), 20,
    "rich write delta generates weighted pages")
assertEqual(LJ.getActionPageCount("read", rich), 19,
    "rich read delta generates weighted pages")
assertEqual(LJ.getWriteTime(rich, player), 9600,
    "write time uses rich page count")
assertEqual(LJ.getReadTime(rich, player), 9120,
    "read time uses rich page count")

local larger = { xp = 50000, skills = 10, recipes = 30, books = 10, vhs = 30 }
assertTrue(LJ.getActionPageCount("write", larger)
    > LJ.getActionPageCount("write", rich),
    "write pages increase with content")
assertTrue(LJ.getActionPageCount("read", larger)
    > LJ.getActionPageCount("read", rich),
    "read pages increase with missing content")

local extreme = { xp = 1000000, skills = 0, recipes = 0, books = 0, vhs = 0 }
assertEqual(LJ.getActionPageCount("write", extreme), 75,
    "large valid XP produces an uncapped finite page count")

print("Legacy Journal dynamic page count tests: PASS")
