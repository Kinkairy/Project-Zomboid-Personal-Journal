local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

local refreshCalls = 0
local vanillaCalls = 0
local item = { name = "Author's Journal" }
local items = {}
function items:size() return 1 end
function items:get(index)
    if index == 0 then return item end
    return nil
end

local container = {}
function container:getItems() return items end

LegacyJournal = {}
function LegacyJournal.refreshJournalPresentation(candidate)
    refreshCalls = refreshCalls + 1
    candidate.name = "localized journal"
end

ISInventoryPane = {}
function ISInventoryPane:refreshContainer()
    vanillaCalls = vanillaCalls + 1
    assertEqual(self.inventory:getItems():get(0).name,
        "localized journal", "presentation precedes vanilla grouping")
    return "vanilla-result"
end

package.preload["ISUI/ISInventoryPane"] = function()
    return ISInventoryPane
end
package.preload["legacyjournal/legacyjournal_shared"] = function()
    return LegacyJournal
end

local modulePath = "workshop/Contents/mods/LegacyJournal/42.20/media/lua/client/legacyjournal/legacyjournal_presentation.lua"
dofile(modulePath)

local pane = setmetatable({ inventory = container }, { __index = ISInventoryPane })
assertEqual(pane:refreshContainer(), "vanilla-result", "vanilla return value")
assertEqual(refreshCalls, 1, "visible item localized once")
assertEqual(vanillaCalls, 1, "vanilla refresh called once")

-- Reloading client Lua must not wrap the vanilla method a second time.
dofile(modulePath)
pane:refreshContainer()
assertEqual(refreshCalls, 2, "reload remains single-wrapped")
assertEqual(vanillaCalls, 2, "reload preserves one vanilla call")

print("Legacy Journal client presentation tests: PASS")
