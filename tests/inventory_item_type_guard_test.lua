local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

function instanceof(candidate, className)
    return candidate and candidate.className == className
end

LegacyJournal = nil
dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")

local nonInventoryLookups = 0
local resource = setmetatable({ className = "EnergyResource" }, {
    __index = function(_, key)
        if key == "getFullType" then
            nonInventoryLookups = nonInventoryLookups + 1
            error("non-InventoryItem getFullType must not be accessed")
        end
        return nil
    end,
})

assertEqual(LegacyJournal.isSupportedItem(nil), false, "nil is rejected")
assertEqual(LegacyJournal.isSupportedItem(resource), false,
    "resource tooltip object is rejected")
assertEqual(nonInventoryLookups, 0,
    "resource object bypasses getFullType")

local diary = { className = "InventoryItem" }
function diary:getFullType() return "Base.Diary1" end
assertEqual(LegacyJournal.isSupportedItem(diary), true,
    "supported diary InventoryItem is accepted")

local book = { className = "InventoryItem" }
function book:getFullType() return "Base.Book" end
assertEqual(LegacyJournal.isSupportedItem(book), false,
    "unrelated InventoryItem is rejected")

print("Legacy Journal InventoryItem type-guard tests: PASS")
