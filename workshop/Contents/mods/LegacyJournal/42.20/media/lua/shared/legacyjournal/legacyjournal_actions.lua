require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISWriteSomething"
require "legacyjournal/legacyjournal_shared"
require "legacyjournal/legacyjournal_progress"

local LJ = LegacyJournal
LegacyJournalAction = ISBaseTimedAction:derive("LegacyJournalAction")

local function trace(self, event)
    print("[LegacyJournal] native build=" .. LJ.BUILD .. " kind=" .. tostring(self.kind)
        .. " event=" .. event .. " item=" .. tostring(self.item and self.item:getID()))
end

function LegacyJournalAction:isValid()
    return not self.rejected and LJ.isActionContextValid(self.character, self.item, self.kind)
end

-- NetTimedAction rebuilds this plan on the authoritative side. None of these
-- fields are constructor arguments, so the client cannot supply the workload.
function LegacyJournalAction:getDuration()
    if self.rejected then return 1 end
    if not self.plan then
        local delta = self.kind == "write" and LJ.getWriteDelta(self.character, self.item)
            or LJ.getReadDelta(self.character, self.item)
        local pages = LJ.getActionPageCount(self.kind, delta)
        local actor = LJ.getActionActorKey(self.character)
        local signature = LJ.getActionSignature(self.kind, self.item, delta)
        local startPage = LJ.getSavedActionPage(self.item, self.kind, signature, actor, pages)
        local totalTime = self.kind == "write" and LJ.getWriteTime(delta, self.character)
            or LJ.getReadTime(delta, self.character)
        self.plan = { pages = pages, startPage = startPage, actor = actor,
            signature = signature, lastPage = startPage,
            duration = LJ.getRemainingActionTime(totalTime, startPage, pages) }
    end
    return self.plan.duration
end

function LegacyJournalAction:isUsingTimeout()
    -- Match native books: a journal may legitimately take over 30 real minutes.
    return false
end

function LegacyJournalAction:isBook(item)
    return ISWriteSomething.isBook(self, item)
end

function LegacyJournalAction:start()
    self:getDuration()
    ISWriteSomething.start(self)
    self.character:setReading(true)
    local label = getText(self.kind == "write" and LJ.WRITE_TEXT_KEY or "ContextMenu_Read")
    if LJ.isWritten(self.item) then
        if not isServer() then
            LJ.refreshJournalPresentation(self.item)
        end
        local name = tostring(self.item:getName(self.character) or "")
        if name:match("%S") then label = label .. " " .. name end
    end
    self.item:setJobType(label)
    self.item:setJobDelta(self.plan.startPage / self.plan.pages)
    LJ.beginProgressView(self, label)
    trace(self, "start")
end

local function pageAt(self, progress)
    local p = self.plan
    progress = math.max(0, math.min(1, tonumber(progress) or 0))
    return p.startPage + math.floor((p.pages - p.startPage) * progress + 0.000001)
end

function LegacyJournalAction:saveProgress()
    if isClient() or self.finished or self.rejected or not self.plan then return end
    if not self.item or LJ.findItemById(self.character, self.item:getID()) ~= self.item then return end
    if LJ.getActionActorKey(self.character) ~= self.plan.actor then return end
    local progress = isServer() and self.netAction:getProgress() or self:getJobDelta()
    local page = pageAt(self, progress)
    if page <= self.plan.lastPage then return end
    self.plan.lastPage = page
    LJ.saveActionProgress(self.item, self.kind, self.plan.signature,
        self.plan.actor, page, self.plan.pages)
    if isServer() then self.item:syncItemFields() end
end

function LegacyJournalAction:update()
    if isClient() then
        LJ.updateProgressView(self)
        return
    end
    local p = self.plan
    local progress = math.max(0, math.min(1, self:getJobDelta()))
    self.item:setJobDelta((p.startPage + (p.pages - p.startPage) * progress) / p.pages)
    if not isServer() then self:saveProgress() end
end

function LegacyJournalAction:serverStart()
    self:getDuration()
    local active = LJ.activeJournalActions[self.character]
    if self.rejected or not LJ.canPerformAction(self.character, self.item, self.kind) or active then
        self.rejected = true
        LJ.publishActionProgress(self, "rejected")
        self.netAction:forceComplete()
        return
    end
    LJ.activeJournalActions[self.character] = self
    ISWriteSomething.serverStart(self)
    LJ.publishActionProgress(self, "running")
    trace(self, "server-start")
end

local function release(self)
    if isServer() and LJ.activeJournalActions[self.character] == self then
        LJ.activeJournalActions[self.character] = nil
        ISWriteSomething.serverStop(self)
    end
end

function LegacyJournalAction:serverStop()
    self:saveProgress()
    LJ.publishActionProgress(self, "cancelled")
    release(self)
    trace(self, "server-stop")
end

local function clearJob(self)
    LJ.endProgressView(self)
    self.character:setReading(false)
    self.item:setJobDelta(0)
    self.item:setJobType("")
    local container = self.item:getContainer()
    if container then container:setDrawDirty(true) end
end

function LegacyJournalAction:stop()
    if not isClient() then self:saveProgress() end
    clearJob(self)
    self.character:playSound(self:isBook(self.item) and "CloseBook" or "CloseMagazine")
    ISBaseTimedAction.stop(self)
end

function LegacyJournalAction:forceCancel()
    LJ.endProgressView(self)
    -- Queued-but-not-started actions have no progress or animation to clear.
    ISBaseTimedAction.forceCancel(self)
end

function LegacyJournalAction:perform()
    -- The engine only releases a multiplayer action after authoritative Done.
    clearJob(self)
    self.character:playSound(self:isBook(self.item) and "CloseBook" or "CloseMagazine")
    ISBaseTimedAction.perform(self)
end

function LegacyJournalAction:complete()
    if isClient() or self.finished or self.rejected then return false end
    if isServer() and LJ.activeJournalActions[self.character] ~= self then return false end
    local valid = self:isValid()
        and LJ.getActionActorKey(self.character) == self.plan.actor
        and LJ.canPerformAction(self.character, self.item, self.kind)
    if valid then
        local delta = self.kind == "write" and LJ.getWriteDelta(self.character, self.item)
            or LJ.getReadDelta(self.character, self.item)
        valid = LJ.getActionSignature(self.kind, self.item, delta) == self.plan.signature
    end
    if not valid then
        self:saveProgress()
        self.finished = true
        LJ.publishActionProgress(self, "rejected")
        release(self)
        trace(self, "rejected-state-changed")
        return false
    end
    self.finished = true
    LJ.publishActionProgress(self, "applying")
    local ok, applied, fields = pcall(function()
        if self.kind == "write" then return LJ.commitWrite(self.character, self.item) end
        return LJ.applyRead(self.character, self.item)
    end)
    LJ.publishActionProgress(self, ok and applied and "complete" or "rejected")
    release(self)
    if not ok then error(applied) end
    if applied and isServer() then
        self.item:syncItemFields()
        LJ.sendJournalResult(self.character, self.item, fields, self.recipientKey)
    end
    trace(self, applied and "complete" or "rejected-empty")
    return applied == true
end

function LegacyJournalAction:animEvent(event, parameter)
    ISWriteSomething.animEvent(self, event, parameter)
end

-- Parameter names must equal stored fields: NetTimedAction serializes these
-- names and reconstructs the same arguments on the server. recipientKey is
-- opaque client-local routing context, never an authorization or progress token.
function LegacyJournalAction:new(character, item, kind, recipientKey, progressKey)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.item = item
    o.kind = kind
    o.recipientKey = recipientKey
    o.progressKey = progressKey
    if not isServer() and character then
        o.recipientKey = LJ.getActionActorKey(character)
        o.progressKey = LJ.newProgressKey()
    end
    if not character or not LJ.isSupportedItem(item)
        or (kind ~= "write" and kind ~= "read")
        or type(o.recipientKey) ~= "string" or #o.recipientKey > 1024
        or not LJ.isProgressKey(o.progressKey) then
        o.rejected = true
    end
    o.ignoreHandsWounds = true
    o.forceProgressBar = true
    o.caloriesModifier = kind == "read" and 0.5 or 1
    -- MP presentation is sampled from the server, not advanced by a second
    -- local countdown. getDuration() still owns the authoritative workload.
    -- Native Done/Reject still owns completion/cancellation.
    o.maxTime = isClient() and LJ.PROGRESS_VIEW_SCALE or o:getDuration()
    return o
end

print("[LegacyJournal] actions loaded build=" .. LJ.BUILD)
