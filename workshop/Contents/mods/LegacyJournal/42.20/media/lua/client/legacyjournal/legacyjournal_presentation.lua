require "ISUI/ISInventoryPane"
require "legacyjournal/legacyjournal_shared"

local LJ = LegacyJournal
local localNames = setmetatable({}, { __mode = "k" })

local function refreshVisibleJournalNames(container)
    if not container then return end
    local items = container:getItems()
    if not items then return end

    for index = 0, items:size() - 1 do
        local item = items:get(index)
        LJ.refreshJournalPresentation(item)
        localNames[item] = LJ.isWritten(item) and item:getName() or nil
    end
end

-- PZ rebuilds every visible backpack, cupboard and floor list through this
-- method when its native container becomes draw-dirty. Localize dynamic
-- author names immediately before vanilla reads and groups the item names.
if not ISInventoryPane.LegacyJournalPresentationInstalled then
    local vanillaRefreshContainer = ISInventoryPane.refreshContainer
    local vanillaDrawItemIcon = ISInventoryPane.drawItemIcon

    function ISInventoryPane:refreshContainer(...)
        refreshVisibleJournalNames(self.inventory)
        return vanillaRefreshContainer(self, ...)
    end

    -- Native field packets may arrive after the action stopped, without a
    -- container-dirty event. Vanilla draws this icon before reading the row
    -- name. Only cached journals need a name comparison; stable rows do no
    -- translation, metadata access, inventory scan or network write here.
    function ISInventoryPane:drawItemIcon(item, ...)
        local expected = localNames[item]
        if expected and item:getName() ~= expected then
            LJ.refreshJournalPresentation(item)
            localNames[item] = LJ.isWritten(item) and item:getName() or nil
        end
        return vanillaDrawItemIcon(self, item, ...)
    end

    ISInventoryPane.LegacyJournalPresentationInstalled = true
end

print("[LegacyJournal] local journal presentation loaded")
