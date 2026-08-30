local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

CharacterTrait = {}
ItemTag = {}
getSandboxOptions = function()
    return { getOptionByName = function() return nil end }
end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")
local LJ = LegacyJournal

local item = { modData = { LJ_written = true, LJ_version = 6 } }
function item:getModData() return self.modData end

local savedSkills = { Woodwork = 100 }
local savedRecipes = { Soup = true }
local savedBooks = { ["Base.BookCarpentry1"] = 110 }
local savedBookStates = {
    ["Base.BookCarpentry1"] = {
        perkId = "Woodwork", multiplier = 1.5, minLevel = 1, maxLevel = 2,
    },
}
local savedMedia = { ["training-a"] = 1 }
local player = {
    skills = { Woodwork = 100 },
    recipes = { Soup = true },
    books = { ["Base.BookCarpentry1"] = 110 },
    bookStates = {
        ["Base.BookCarpentry1"] = {
            perkId = "Woodwork", multiplier = 1.5, minLevel = 1, maxLevel = 2,
        },
    },
    media = { ["training-a"] = 1 },
}

LJ.isSupportedRecord = function(candidate)
    return candidate == item and candidate:getModData().LJ_version == 6
end
LJ.getSavedSkills = function() return savedSkills end
LJ.getSavedRecipes = function() return savedRecipes end
LJ.getSavedSkillBooks = function() return savedBooks end
LJ.getSavedSkillBookStates = function() return savedBookStates, true end
LJ.getSavedMediaRewards = function() return savedMedia end
LJ.isSkillXpEnabled = function() return true end
LJ.isRecipesEnabled = function() return true end
LJ.isSkillBooksEnabled = function() return true end
LJ.isTrainingMediaEnabled = function() return true end
LJ.captureSkills = function(target) return target.skills end
LJ.captureRecipes = function(target) return target.recipes end
LJ.captureSkillBooks = function(target)
    return target.books, { ["Base.BookCarpentry1"] = true }, true
end
LJ.captureSkillBookStates = function(target)
    return target.bookStates, { ["Base.BookCarpentry1"] = true }, true
end
LJ.captureKnownMediaRewards = function(target) return target.media end

local function assertDelta(label)
    assertEqual(LJ.hasDelta(LJ.getWriteDelta(player, item)), true, label)
end

assertEqual(LJ.hasDelta(LJ.getWriteDelta(player, item)), false,
    "v6 completed journal with identical full snapshot has no write delta")

local captureSkillBookStates = LJ.captureSkillBookStates
LJ.captureSkillBookStates = function()
    -- Simulate a multiplayer client that can identify the book but cannot
    -- observe its active XP multiplier.
    return {}, { ["Base.BookCarpentry1"] = true }, true
end
assertEqual(LJ.hasDelta(LJ.getWriteDelta(player, item)), false,
    "unobservable skill-book multiplier does not enable writing")
LJ.captureSkillBookStates = captureSkillBookStates

player.skills.Woodwork = 101
assertDelta("XP-only change is detected")
player.skills.Woodwork = 100

player.recipes.Stew = true
assertDelta("recipe-only change is detected")
player.recipes.Stew = nil

player.books["Base.BookCarpentry1"] = 111
assertDelta("skill-book page-only change is detected")
player.books["Base.BookCarpentry1"] = 110

player.bookStates["Base.BookCarpentry1"].multiplier = 2
assertDelta("skill-book state-only change is detected")
player.bookStates["Base.BookCarpentry1"].multiplier = 1.5

player.media["training-b"] = 1
assertDelta("training-media-only change is detected")

print("Legacy Journal write-delta no-change regression tests: PASS")
