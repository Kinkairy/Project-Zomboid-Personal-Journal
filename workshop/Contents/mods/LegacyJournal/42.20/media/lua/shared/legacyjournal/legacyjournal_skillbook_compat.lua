require "TimedActions/ISReadABook"

-- B42's instant timed-action path can complete a skill book without copying
-- its final page count to the character. Use the same vanilla setter before
-- the original completion routine sends the player and item field syncs.
local version = tostring(getCore():getVersionNumber()):match("^(%d+%.%d+%.%d+)")
if version == "42.20.4" and ISReadABook and not ISReadABook._legacyJournalInstantPageFix then
    local vanillaComplete = ISReadABook.complete

    function ISReadABook:complete()
        if self.character and self.item
            and not self.forceStopped
            and self.character:isTimedActionInstant() then
            local skill = self.item:getSkillTrained()
            local pages = tonumber(self.item:getNumberOfPages() or 0) or 0
            if skill and SkillBook[skill] and pages > 0
                and self.character:getAlreadyReadPages(self.item:getFullType()) < pages then
                self.character:setAlreadyReadPages(self.item:getFullType(), pages)
            end
        end
        return vanillaComplete(self)
    end

    ISReadABook._legacyJournalInstantPageFix = true
end

print("[LegacyJournal] instant skill-book page compatibility loaded")
