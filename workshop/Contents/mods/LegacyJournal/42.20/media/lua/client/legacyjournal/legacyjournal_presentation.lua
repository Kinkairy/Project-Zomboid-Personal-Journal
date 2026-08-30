require "ISUI/ISInventoryPane"
require "legacyjournal/legacyjournal_shared"

local LJ = LegacyJournal

local function refreshVisibleJournalNames(container)
    if not container then return end
    local items = container:getItems()
    if not items then return end

    for index = 0, items:size() - 1 do
        LJ.refreshJournalPresentation(items:get(index))
    end
end

-- PZ rebuilds every visible backpack, cupboard and floor list through this
-- method when its native container becomes draw-dirty. Localize dynamic
-- author names immediately before vanilla reads and groups the item names.
if not ISInventoryPane.LegacyJournalPresentationInstalled then
    local vanillaRefreshContainer = ISInventoryPane.refreshContainer

    function ISInventoryPane:refreshContainer(...)
        refreshVisibleJournalNames(self.inventory)
        return vanillaRefreshContainer(self, ...)
    end

    ISInventoryPane.LegacyJournalPresentationInstalled = true
end

print("[LegacyJournal] local journal presentation loaded")
