local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local vanillaCalls = 0
ISReadABook = {}
function ISReadABook:complete()
    vanillaCalls = vanillaCalls + 1
    return "vanilla-result"
end
package.preload["TimedActions/ISReadABook"] = function()
    return ISReadABook
end

local character = { instant = true, pages = {} }
function character:isTimedActionInstant() return self.instant end
function character:setAlreadyReadPages(fullType, pages)
    self.pages[fullType] = pages
end

local item = {}
function item:getSkillTrained() return "Woodwork" end
function item:getNumberOfPages() return 220 end
function item:getFullType() return "Base.BookCarpentry1" end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_skillbook_compat.lua")

local action = setmetatable({ character = character, item = item }, { __index = ISReadABook })
assertEqual(action:complete(), "vanilla-result", "vanilla completion result preserved")
assertEqual(character.pages["Base.BookCarpentry1"], 220, "instant pages copied to character")
assertEqual(vanillaCalls, 1, "vanilla completion called once")

character.instant = false
character.pages = {}
assertEqual(action:complete(), "vanilla-result", "normal completion result preserved")
assertEqual(character.pages["Base.BookCarpentry1"], nil, "normal reading path unchanged")
assertEqual(vanillaCalls, 2, "normal vanilla completion called once")

print("Legacy Journal instant skill-book sync tests: PASS")
