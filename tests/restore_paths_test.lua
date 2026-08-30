local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local woodwork = { id = "Woodwork" }
PerkFactory = {
    Perks = {
        None = {},
        FromString = function(id) if id == "Woodwork" then return woodwork end end,
        getMaxIndex = function() return 0 end,
    },
}
isServer = function() return false end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")

LegacyJournal.getPermanentRewardMedia = function()
    return { byId = {
        ["vhs-test"] = {
            id = "vhs-test",
            rewardLines = { "vhs-line-1" },
            allLines = { "vhs-line-1" },
        },
    } }
end

local item = { modData = {
    LJ_written = true,
    LJ_version = 6,
    LJ_authorName = "Test Survivor",
    LJ_authorUser = "test-user",
    LJ_skills = "Woodwork=100",
    LJ_recipes = "Soup",
    LJ_skillBooks = "",
    LJ_mediaRewards = "vhs-test=1",
    LJ_mediaRewardMode = "whole-media",
} }
function item:getFullType() return "Base.Diary2" end
function item:getModData() return self.modData end

local player = { xpValues = { Woodwork = 40 }, recipes = {}, vhs = {} }
player.xp = {
    getXP = function(_, perk) return player.xpValues[perk.id] or 0 end,
    getMultiplier = function() return 0 end,
}
function player:getXp() return self.xp end
function player:getUsername() return "test-user" end
function player:getDisplayName() return "Test Survivor" end
function player:learnRecipe(recipe) self.recipes[recipe] = true end
function player:isKnownMediaLine(guid) return self.vhs[guid] == true end
function player:addKnownMediaLine(guid) self.vhs[guid] = true end

addXpNoMultiplier = function(target, perk, amount)
    target.xpValues[perk.id] = (target.xpValues[perk.id] or 0) + amount
end

LegacyJournal.captureSkills = function(target) return target.xpValues end
LegacyJournal.captureRecipes = function(target) return target.recipes end
LegacyJournal.isSkillXpEnabled = function() return true end
LegacyJournal.isRecipesEnabled = function() return true end
LegacyJournal.isSkillBooksEnabled = function() return false end
LegacyJournal.isTrainingMediaEnabled = function() return true end

local precisionItem = { modData = {
    LJ_written = true,
    LJ_version = 6,
    LJ_authorName = "Test Survivor",
    LJ_authorUser = "test-user",
    LJ_skills = "Woodwork=12345.678710938",
    LJ_recipes = "",
    LJ_skillBooks = "",
    LJ_skillBookStates = "",
    LJ_mediaRewards = "",
    LJ_mediaRewardMode = "whole-media",
} }
function precisionItem:getFullType() return "Base.Diary2" end
function precisionItem:getModData() return self.modData end
player.xpValues.Woodwork = 12345.6787109375
local precisionDelta = LegacyJournal.getReadDelta(player, precisionItem)
assertEqual(precisionDelta.xp, 0, "persisted XP precision is not a read delta")
assertEqual(precisionDelta.skills, 0, "persisted XP precision skill count")
player.xpValues.Woodwork = 12344.6787109375
precisionDelta = LegacyJournal.getReadDelta(player, precisionItem)
assertEqual(precisionDelta.skills, 1, "meaningfully lower XP remains a read delta")

player.xpValues.Woodwork = 40

local delta = LegacyJournal.getReadDelta(player, item)
assertEqual(delta.xp, 60, "XP read delta")
assertEqual(delta.skills, 1, "XP skill count")
assertEqual(delta.recipes, 1, "recipe read delta")
assertEqual(delta.vhs, 1, "VHS read delta")
assertEqual(LegacyJournal.applyRead(player, item), true, "read applies all paths")
assertEqual(player.xpValues.Woodwork, 100, "XP restored through native path")
assertEqual(player.recipes.Soup, true, "recipe restored")
assertEqual(player.vhs["vhs-line-1"], true, "VHS line restored")

function player:getUsername() return "other-user" end
assertEqual(LegacyJournal.applyRead(player, item), false, "non-author restore rejected")

print("Legacy Journal restore path tests: PASS")
