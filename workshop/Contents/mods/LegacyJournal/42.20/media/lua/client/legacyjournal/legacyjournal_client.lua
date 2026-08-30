require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPane"
require "ISUI/ISToolTipInv"
require "legacyjournal/legacyjournal_shared"
require "legacyjournal/legacyjournal_actions"
require "legacyjournal/legacyjournal_presentation"

local LJ = LegacyJournal
local pendingBegins = {}

local function actionKey(action, itemId)
    return tostring(action) .. ":" .. tostring(itemId)
end

-- ============================================================
-- Context menu
-- ============================================================

local function getLocalResume(player, item, action, delta, totalTime)
    local totalPages = LJ.getActionPageCount(action, delta)
    local signature = LJ.getActionSignature(action, item, delta)
    local actorKey = LJ.getActionActorKey(player)
    local startPage = LJ.getSavedActionPage(item, action, signature,
        actorKey, totalPages)
    return LJ.getRemainingActionTime(totalTime, startPage, totalPages),
        startPage, totalPages, signature, actorKey
end

local function queueWrite(player, item, duration, token, startPage, totalPages,
        signature, actorKey)
    local delta = LJ.getWriteDelta(player, item)
    if not duration and not LJ.hasDelta(delta) then return end

    if not duration then
        duration, startPage, totalPages, signature, actorKey = getLocalResume(
            player, item, "write", delta, LJ.getWriteTime(delta, player))
    end

    ISTimedActionQueue.add(
        LegacyJournalWriteAction:new(
            player,
            item,
            duration,
            token,
            startPage,
            totalPages,
            signature,
            actorKey
        )
    )
end

local function queueRead(player, item, duration, token, startPage, totalPages,
        signature, actorKey)
    local delta = LJ.getReadDelta(player, item)
    if not duration and not LJ.hasDelta(delta) then return end

    if not duration then
        duration, startPage, totalPages, signature, actorKey = getLocalResume(
            player, item, "read", delta, LJ.getReadTime(delta, player))
    end

    ISTimedActionQueue.add(
        LegacyJournalReadAction:new(
            player,
            item,
            duration,
            token,
            startPage,
            totalPages,
            signature,
            actorKey
        )
    )
end

local function sendActionRequest(player, item, action)
    if not isClient() then
        if action == "write" then queueWrite(player, item) else queueRead(player, item) end
        return
    end

    local key = actionKey(action, item:getID())
    if pendingBegins[key] then return end
    pendingBegins[key] = true
    sendClientCommand(player, LJ.MODULE, "begin", {
        action = action,
        itemId = item:getID(),
    })
end

LegacyJournalBeginRequestAction = ISBaseTimedAction:derive(
    "LegacyJournalBeginRequestAction")

function LegacyJournalBeginRequestAction:isValid()
    return self.character and not self.character:isDead()
        and self.item and LJ.isSupportedItem(self.item)
end

function LegacyJournalBeginRequestAction:perform()
    local inventory = self.character:getInventory()
    if inventory and inventory:containsRecursive(self.item) then
        sendActionRequest(self.character, self.item, self.kind)
    end
    ISBaseTimedAction.perform(self)
end

function LegacyJournalBeginRequestAction:new(character, item, kind)
    local action = ISBaseTimedAction.new(self, character)
    action.item = item
    action.kind = kind
    action.maxTime = 0
    action.stopOnWalk = false
    action.stopOnRun = false
    return action
end

local function requestAction(player, item, action)
    local inventory = player:getInventory()
    if inventory and inventory:containsRecursive(item) then
        sendActionRequest(player, item, action)
        return
    end

    -- Match vanilla item actions: take a floor/container item first, then
    -- request the server-authoritative journal action after transfer finishes.
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(
        LegacyJournalBeginRequestAction:new(player, item, action)
    )
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
    local player = getSpecificPlayer(0)
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
    local player = getSpecificPlayer(0)
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
    if command == "itemFields" then
        syncWrittenJournal(args)
        return
    end
    if command == "readFields" then
        applyReadFieldChunk(args)
        return
    end
    if command ~= "begin" and command ~= "beginDenied" then return end
    if not args or not args.action or args.itemId == nil then return end

    local key = actionKey(args.action, args.itemId)
    pendingBegins[key] = nil
    if command ~= "begin" then return end

    local duration = tonumber(args.duration)
    if (args.action ~= "write" and args.action ~= "read")
        or not duration or duration <= 0 or not args.token then
        return
    end

    local player = getSpecificPlayer(0)
    local item = LJ.findItemById(player, args.itemId)
    if not item then return end
    if args.action == "write" then
        queueWrite(player, item, duration, tostring(args.token),
            tonumber(args.startPage), tonumber(args.totalPages))
    else
        queueRead(player, item, duration, tostring(args.token),
            tonumber(args.startPage), tonumber(args.totalPages))
    end
end

Events.OnServerCommand.Add(onServerCommand)

local function onFillInventoryObjectContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)

    if not player then return end

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
                elseif not LJ.isAuthor(player, item) and item:isEmptyPages() then
                    disableOption(readOption, "ContextMenu_EmptyNotebook")
                end
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

print("[LegacyJournal] client loaded")
