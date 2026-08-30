require "TimedActions/ISBaseTimedAction"
require "legacyjournal/legacyjournal_shared"

local LJ = LegacyJournal
local BUILD = "20260825-stack-state-hotfix-1"

local function side()
    if isServer() then return "server" end
    if isClient() then return "client" end
    return "singleplayer"
end

local function trace(action, event)
    local itemId = action.item and action.item:getID() or "nil"
    print("[LegacyJournal] action build=" .. BUILD
        .. " side=" .. side()
        .. " kind=" .. tostring(action.kind)
        .. " event=" .. event
        .. " item=" .. tostring(itemId))
end

local function isBook(item)
    return item and string.match(item:getType(), "Book") ~= nil
end

local function startJournalAnimation(action)
    local item = action.item
    if item:getReadType() then
        action:setAnimVariable("ReadType", item:getReadType())
    elseif item:getType() == "Newspaper" or item:hasTag(ItemTag.NEWSPAPER_READ) then
        action:setAnimVariable("ReadType", "newspaper")
    elseif item:hasTag(ItemTag.PICTURE) then
        action:setAnimVariable("ReadType", "photo")
    else
        action:setAnimVariable("ReadType", "book")
    end
    action:setActionAnim(CharacterActionAnims.Read)
    action:setOverrideHandModels(nil, item)
    action.character:setReading(true)
    action.character:reportEvent("EventRead")
    action.character:playSound(isBook(item) and "OpenBook" or "OpenMagazine")
end

local function stopJournalAnimation(action)
    action.character:setReading(false)
    action.character:playSound(isBook(action.item) and "CloseBook" or "CloseMagazine")
end

local function clearJournalJob(action)
    action.character:setReading(false)
    action.item:setJobDelta(0.0)
    action.item:setJobType("")
    local container = action.item:getContainer()
    if container then container:setDrawDirty(true) end
end

local function canUseJournal(character)
    if character:tooDarkToRead() then return false end
    local vehicle = character:getVehicle()
    if vehicle and vehicle:isDriver(character) then
        return not vehicle:isEngineRunning() or vehicle:getSpeed2D() == 0
    end
    return true
end

local function completedPage(action)
    local remainingPages = action.totalPages - action.startPage
    local progress = math.max(0, math.min(1, tonumber(action:getJobDelta()) or 0))
    return math.min(action.totalPages,
        action.startPage + math.floor((progress * remainingPages) + 0.000001))
end

local function overallProgress(action)
    local remainingPages = action.totalPages - action.startPage
    local progress = math.max(0, math.min(1, tonumber(action:getJobDelta()) or 0))
    return (action.startPage + (progress * remainingPages)) / action.totalPages
end

local function saveProgress(action, command)
    if not action.item then return end
    local page = completedPage(action)
    if command == "checkpoint" and page <= action.lastCheckpointPage then return end
    action.lastCheckpointPage = page

    if isClient() then
        sendClientCommand(action.character, LJ.MODULE, command, {
            action = action.kind,
            itemId = action.item:getID(),
            token = action.token,
            page = page,
        })
    elseif not isServer() then
        LJ.saveActionProgress(action.item, action.kind, action.signature,
            action.actorKey, page, action.totalPages)
    end
end

local function performAction(action)
    trace(action, "perform")
    if isClient() then
        sendClientCommand(action.character, LJ.MODULE, "commit", {
            action = action.kind,
            itemId = action.item:getID(),
            token = action.token,
        })
    elseif not isServer() then
        if action.kind == "write" then
            LJ.commitWrite(action.character, action.item)
        else
            LJ.applyRead(action.character, action.item)
        end
    end
    clearJournalJob(action)
    stopJournalAnimation(action)
    ISBaseTimedAction.perform(action)
end

local function stopAction(action)
    trace(action, "stop")
    saveProgress(action, "cancel")
    clearJournalJob(action)
    stopJournalAnimation(action)
    ISBaseTimedAction.stop(action)
end

local function forceCancelAction(action)
    trace(action, "force-cancel")
    saveProgress(action, "cancel")
    clearJournalJob(action)
    stopJournalAnimation(action)
    ISBaseTimedAction.forceCancel(action)
end

local function initializeAction(action, character, item, maxTime, token, kind,
        startPage, totalPages, signature, actorKey)
    action.character = character
    action.item = item
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = maxTime
    action.token = token
    action.kind = kind
    action.startPage = math.max(0, math.floor(tonumber(startPage) or 0))
    action.totalPages = math.max(1, math.floor(tonumber(totalPages)
        or LJ.DEFAULT_ACTION_PROGRESS_PAGES))
    action.startPage = math.min(action.startPage, action.totalPages)
    action.lastCheckpointPage = action.startPage
    action.signature = signature
    action.actorKey = actorKey
    action.ignoreHandsWounds = false
    action.forceProgressBar = true
    return action
end

LegacyJournalWriteAction = ISBaseTimedAction:derive("LegacyJournalWriteAction")

function LegacyJournalWriteAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.item or not LJ.isSupportedItem(self.item) then return false end
    if not canUseJournal(self.character) then return false end
    local inventory = self.character:getInventory()
    return inventory and inventory:containsRecursive(self.item)
end

function LegacyJournalWriteAction:start()
    trace(self, "start")
    self.item:setJobType(getText(LJ.WRITE_TEXT_KEY) .. " " .. self.item:getName())
    self.item:setJobDelta(self.startPage / self.totalPages)
    startJournalAnimation(self)
end

function LegacyJournalWriteAction:update()
    self.item:setJobDelta(overallProgress(self))
    saveProgress(self, "checkpoint")
end

function LegacyJournalWriteAction:stop()
    stopAction(self)
end

function LegacyJournalWriteAction:forceCancel()
    forceCancelAction(self)
end

function LegacyJournalWriteAction:perform()
    performAction(self)
end

function LegacyJournalWriteAction:new(character, item, maxTime, token,
        startPage, totalPages, signature, actorKey)
    return initializeAction(
        ISBaseTimedAction.new(self, character),
        character,
        item,
        maxTime,
        token,
        "write",
        startPage,
        totalPages,
        signature,
        actorKey
    )
end

LegacyJournalReadAction = ISBaseTimedAction:derive("LegacyJournalReadAction")

function LegacyJournalReadAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if not self.item or not LJ.isWritten(self.item) then return false end
    if not canUseJournal(self.character) then return false end
    local inventory = self.character:getInventory()
    return inventory and inventory:containsRecursive(self.item)
end

function LegacyJournalReadAction:start()
    trace(self, "start")
    self.item:setJobType(getText("ContextMenu_Read") .. " " .. self.item:getName())
    self.item:setJobDelta(self.startPage / self.totalPages)
    startJournalAnimation(self)
end

function LegacyJournalReadAction:update()
    self.item:setJobDelta(overallProgress(self))
    saveProgress(self, "checkpoint")
end

function LegacyJournalReadAction:stop()
    stopAction(self)
end

function LegacyJournalReadAction:forceCancel()
    forceCancelAction(self)
end

function LegacyJournalReadAction:perform()
    performAction(self)
end

function LegacyJournalReadAction:new(character, item, maxTime, token,
        startPage, totalPages, signature, actorKey)
    return initializeAction(
        ISBaseTimedAction.new(self, character),
        character,
        item,
        maxTime,
        token,
        "read",
        startPage,
        totalPages,
        signature,
        actorKey
    )
end

print("[LegacyJournal] actions loaded build=" .. BUILD .. " side=" .. side())
