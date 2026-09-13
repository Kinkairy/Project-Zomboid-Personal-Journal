require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPane"
require "ISUI/ISToolTipInv"
require "legacyjournal/legacyjournal_shared"
require "legacyjournal/legacyjournal_actions"
require "legacyjournal/legacyjournal_presentation"

local LJ = LegacyJournal
-- One outstanding menu instance per local character, never a polling cache.
local pendingReadStatus = setmetatable({}, { __mode = "k" })
local nextReadStatusId = 0

local function getResultPlayer(args, requireRecipientKey)
    if type(args) ~= "table" then return nil end
    local onlineID = tonumber(args.onlineID)
    if not onlineID or onlineID < 0 or onlineID ~= math.floor(onlineID) then return nil end
    local player = getPlayerByOnlineID(onlineID)
    if player and player:isLocalPlayer() and not player:isDead()
        and (not requireRecipientKey
            or args.recipientKey == LJ.getActionActorKey(player)) then return player end
    return nil
end

local function requestAction(player, item, kind)
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(LegacyJournalAction:new(player, item, kind))
end

local function applyReadStatus(args)
    local player = getResultPlayer(args)
    local pending = player and pendingReadStatus[player] or nil
    if not pending or pending.requestId ~= args.requestId then return end
    pendingReadStatus[player] = nil
    if not pending.context:isVisible()
        or pending.actor ~= LJ.getActionActorKey(player) then return end
    for _, itemId in ipairs(args.readableItems or {}) do
        local entry = pending.entries[tonumber(itemId)]
        if entry and LJ.findItemById(player, itemId) == entry.item
            and LJ.isActionContextValid(player, entry.item, "read")
            and LJ.hasSkillBookMultiplierTarget(player, entry.item, false)
            and LJ.getActionSignature("read", entry.item, {}) == entry.signature then
            entry.option.notAvailable = false
            entry.option.toolTip = nil
        end
    end
end

local function disableOption(option, reasonKey)
    option.notAvailable = true
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText(reasonKey)
    option.toolTip = tooltip
end

local function removeVanillaNoteOptions(context, itemName)
    context:removeOptionByName(getText("ContextMenu_Write_Note", itemName))
    context:removeOptionByName(getText("ContextMenu_Read_Note", itemName))
end

local function openVanillaJournal(playerIndex, item)
    ISInventoryPaneContextMenu.onWriteSomething(item, false, playerIndex)
end

local function syncWrittenJournal(args)
    if not args or args.itemId == nil then return end
    local player = getResultPlayer(args, true)
    local item = LJ.findItemById(player, args.itemId)
    if not item then return end

    local authorName = tostring(args.authorName or "")
    local md = item:getModData()
    md.LJ_writtenAt = tostring(args.writtenAt or md.LJ_writtenAt or "")
    if authorName ~= "" then
        local ok, localizedName = pcall(function()
            return getText(LJ.NAME_TEXT_KEY, authorName)
        end)
        if ok and localizedName and tostring(localizedName) ~= LJ.NAME_TEXT_KEY then
            item:setName(tostring(localizedName))
        end
    else
        LJ.refreshJournalPresentation(item)
    end

    -- The server already sent the authoritative item through the native
    -- SyncItemFields packet. Do not sync this client-side presentation back:
    -- doing so can overwrite the server's freshly written journal ModData
    -- with the client's pre-write snapshot.
    item:setCustomName(true)
end

-- InventoryItem:DoTooltip is the vanilla renderer. Temporarily supply the
-- locally translated journal metadata, then restore the item's own tooltip.
if not ISToolTipInv.LegacyJournalTooltipInstalled then
    local vanillaToolTipRender = ISToolTipInv.render

    function ISToolTipInv:render(...)
        local item = self.item
        local journalTooltip = item and LJ.getJournalTooltip(item) or nil
        if not journalTooltip then return vanillaToolTipRender(self, ...) end

        local previousTooltip = item:getTooltip()
        item:setTooltip(journalTooltip)
        local ok, result = pcall(vanillaToolTipRender, self, ...)
        item:setTooltip(previousTooltip)
        if not ok then error(result) end
        return result
    end

    ISToolTipInv.LegacyJournalTooltipInstalled = true
end

local function applyReadFieldChunk(args)
    local player = getResultPlayer(args, true)
    if not player or not args then return end

    for _, recipeName in ipairs(args.recipes or {}) do
        player:learnRecipe(recipeName)
    end
    for _, guid in ipairs(args.mediaLines or {}) do
        if not player:isKnownMediaLine(guid) then
            player:addKnownMediaLine(guid)
        end
    end

    if args.final == true then
        local savedBooks = LJ.decodeSkills(args.skillBooks or "")
        local savedBookStates = LJ.decodeSkillBookStates(args.skillBookStates or "")
        LJ.applySkillBookProgress(player, savedBooks, savedBookStates,
            args.hasExactSkillBookSnapshot == true)
        if sendSyncPlayerFields then
            -- Vanilla book reading uses this exact field mask for recipes,
            -- read-page state, and the active skill-book multiplier.
            sendSyncPlayerFields(player, 0x00000007)
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= LJ.MODULE then return end
    if command == "readStatus" then
        applyReadStatus(args)
        return
    end
    if command == "itemFields" then
        syncWrittenJournal(args)
        return
    end
    if command == "readFields" then
        applyReadFieldChunk(args)
        return
    end
end

Events.OnServerCommand.Add(onServerCommand)

local function onFillInventoryObjectContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)

    if not player then return end
    pendingReadStatus[player] = nil
    local readStatusItems, readStatusEntries = {}, {}

    -- Match vanilla literature handling: skip each stack's dummy item and
    -- keep one representative (items[2]) per selected UI stack. The
    -- representative retains that physical item's independent ModData.
    local actualItems = ISInventoryPane.getActualUniqueItems(items)

    for _, item in ipairs(actualItems) do

        if item and LJ.isSupportedItem(item) then
            local written = LJ.isWritten(item) and LJ.isSupportedRecord(item)
            if written then
                -- Vanilla built the note option before this event. Personal
                -- journals expose our two stable commands instead.
                local oldName = item:getName()
                removeVanillaNoteOptions(context, oldName)
            end

            local writeOption = context:addOption(
                getText(LJ.WRITE_TEXT_KEY),
                item,
                function(selectedItem)
                    requestAction(player, selectedItem, "write")
                end
            )
            writeOption.itemForTexture = item

            if player:tooDarkToRead() then
                disableOption(writeOption, "ContextMenu_TooDark")
            elseif player:hasTrait(CharacterTrait.ILLITERATE) then
                disableOption(writeOption, "ContextMenu_Illiterate")
            elseif not LJ.canCurrentCharacterUpdate(player, item)
                or not LJ.hasWritingTool(player)
                or not LJ.hasDelta(LJ.getWriteDelta(player, item)) then
                disableOption(writeOption, "ContextMenu_LegacyJournal_CannotWrite")
            end

            if written then
                local readDelta = LJ.getReadDelta(player, item)

                -- Uses PZ's own ContextMenu_Read translation. Only the author
                -- may restore state; everyone else gets the vanilla read-only
                -- journal window used for locked journals.
                local readOption = context:addOption(
                    getText("ContextMenu_Read"),
                    item,
                    function(selectedItem)
                        if LJ.isAuthor(player, selectedItem) then
                            requestAction(player, selectedItem, "read")
                        else
                            openVanillaJournal(playerIndex, selectedItem)
                        end
                    end
                )
                readOption.itemForTexture = item

                if player:tooDarkToRead() then
                    disableOption(readOption, "ContextMenu_TooDark")
                elseif player:hasTrait(CharacterTrait.ILLITERATE) then
                    disableOption(readOption, "ContextMenu_Illiterate")
                elseif LJ.isAuthor(player, item) and not LJ.hasDelta(readDelta) then
                    disableOption(readOption, "ContextMenu_EmptyNotebook")
                    if isClient() and #readStatusItems < LJ.MAX_READ_STATUS_ITEMS
                        and LJ.hasSkillBookMultiplierTarget(player, item, false)
                        and LJ.findItemById(player, item:getID()) == item then
                        table.insert(readStatusItems, item:getID())
                        readStatusEntries[item:getID()] = { item = item, option = readOption,
                            signature = LJ.getActionSignature("read", item, {}) }
                    end
                elseif not LJ.isAuthor(player, item) and item:isEmptyPages() then
                    disableOption(readOption, "ContextMenu_EmptyNotebook")
                end
            end
        end
    end
    if #readStatusItems > 0 then
        nextReadStatusId = nextReadStatusId + 1
        pendingReadStatus[player] = { context = context, entries = readStatusEntries,
            actor = LJ.getActionActorKey(player), requestId = nextReadStatusId }
        -- Read-only menu status. No knowledge, progress or action is submitted.
        sendClientCommand(player, LJ.MODULE, "readStatus", {
            requestId = nextReadStatusId, itemIds = readStatusItems,
        })
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

print("[LegacyJournal] client loaded build=" .. tostring(LJ.BUILD))
