require "TimedActions/ISReadABook"

-- B42's instant timed-action path can complete a skill book without copying
-- its final page count to the character. Use the same vanilla setter before
-- the original completion routine sends the player and item field syncs.
if ISReadABook and not ISReadABook._legacyJournalInstantPageFix then
    local vanillaComplete = ISReadABook.complete

    function ISReadABook:complete()
        if self.character and self.item
            and self.character:isTimedActionInstant() then
            local skill = self.item:getSkillTrained()
            local pages = tonumber(self.item:getNumberOfPages() or 0) or 0
            if skill and pages > 0 then
                self.character:setAlreadyReadPages(self.item:getFullType(), pages)
            end
        end
        return vanillaComplete(self)
    end

    ISReadABook._legacyJournalInstantPageFix = true
end

print("[LegacyJournal] instant skill-book page compatibility loaded")
