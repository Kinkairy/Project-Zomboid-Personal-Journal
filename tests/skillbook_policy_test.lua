local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTrue(value, label)
    if not value then error(label .. ": expected true") end
end

local function assertNil(value, label)
    if value ~= nil then error(label .. ": expected nil, got " .. tostring(value)) end
end

local woodwork = { id = "Woodwork" }
local books = {}
local allBookItems = {}

local function makeBook(fullType, minLevel, maxLevel, pages)
    local book = {}
    function book:getFullName() return fullType end
    function book:getSkillTrained() return "Carpentry" end
    function book:getNumberOfPages() return pages end
    function book:getLvlSkillTrained() return minLevel end
    function book:getMaxLevelTrained() return maxLevel end
    books[fullType] = book
    table.insert(allBookItems, book)
end

makeBook("Base.BookCarpentry1", 1, 2, 220)
makeBook("Base.BookCarpentry2", 3, 4, 260)
makeBook("Base.ABookCarpentry1Alt", 1, 2, 220)

SkillBook = {
    Carpentry = {
        perk = woodwork,
        maxMultiplier1 = 3,
        maxMultiplier2 = 5,
        maxMultiplier3 = 8,
        maxMultiplier4 = 12,
        maxMultiplier5 = 16,
    },
}

CharacterTrait = { ILLITERATE = "ILLITERATE" }
getScriptManager = function()
    return {
        FindItem = function(_, fullType) return books[fullType] end,
        getAllItems = function()
            return {
                size = function() return #allBookItems end,
                get = function(_, index) return allBookItems[index + 1] end,
            }
        end,
    }
end
getSandboxOptions = function() return nil end
isServer = function() return false end

PerkFactory = {
    Perks = {
        None = {},
        getMaxIndex = function() return 0 end,
    },
}

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")

local function makePlayer(level, pages, multiplier, illiterate)
    local player = {
        level = level,
        pages = pages or {},
        multiplier = multiplier or 0,
        illiterate = illiterate == true,
        modData = { LJ_written = true, LJ_version = 6 },
    }
    player.xp = {
        getMultiplier = function() return player.multiplier end,
    }
    function player:getPerkLevel() return self.level end
    function player:hasTrait() return self.illiterate end
    function player:getAlreadyReadPages(fullType) return self.pages[fullType] or 0 end
    function player:setAlreadyReadPages(fullType, value) self.pages[fullType] = value end
    function player:getXp() return self.xp end
    function player:getModData() return self.modData end
    return player
end

addXpMultiplier = function(player, _, multiplier, minLevel, maxLevel)
    player.multiplier = multiplier
    player.lastMinLevel = minLevel
    player.lastMaxLevel = maxLevel
end

local savedBoth = {
    ["Base.BookCarpentry1"] = 220,
    ["Base.BookCarpentry2"] = 260,
}

local levelZero = makePlayer(0)
local applicable = LegacyJournal.getApplicableSkillBookEntries(levelZero, savedBoth)
assertEqual(#applicable, 1, "level 0 applicable book count")
assertEqual(applicable[1].fullType, "Base.BookCarpentry1", "level 0 applicable book")

local sortedApplicable = LegacyJournal.getApplicableSkillBookEntries(levelZero, {
    ["Base.BookCarpentry1"] = 220,
    ["Base.ABookCarpentry1Alt"] = 220,
})
assertEqual(#sortedApplicable, 2, "overlapping applicable book count")
assertEqual(sortedApplicable[1].fullType, "Base.ABookCarpentry1Alt", "stable first book")
assertEqual(sortedApplicable[2].fullType, "Base.BookCarpentry1", "stable second book")

local levelTwo = makePlayer(2)
applicable = LegacyJournal.getApplicableSkillBookEntries(levelTwo, savedBoth)
assertEqual(#applicable, 1, "level 2 applicable book count")
assertEqual(applicable[1].fullType, "Base.BookCarpentry2", "level 2 applicable book")

local illiterate = makePlayer(0, {}, 0, true)
assertEqual(#LegacyJournal.getApplicableSkillBookEntries(illiterate, savedBoth), 0,
    "illiterate applicable book count")

local capturedPlayer = makePlayer(0, { ["Base.BookCarpentry1"] = 77 }, 0)
local capturedBooks = LegacyJournal.captureSkillBooks(capturedPlayer)
assertEqual(capturedBooks["Base.BookCarpentry1"], 77, "captured full-type pages")
assertEqual(capturedBooks["Base.BookCarpentry2"], nil, "zero-page book omitted")

capturedPlayer.multiplier = 1.5
local capturedStates, observableStates, statesCaptured =
    LegacyJournal.captureSkillBookStates(capturedPlayer, capturedBooks)
assertEqual(statesCaptured, true, "native multiplier getter captured")
assertEqual(observableStates["Base.BookCarpentry1"], true,
    "captured multiplier book is observable")
assertEqual(capturedStates["Base.BookCarpentry1"].perkId, "Woodwork",
    "captured multiplier perk id")
assertEqual(capturedStates["Base.BookCarpentry1"].multiplier, 1.5,
    "captured actual multiplier")
assertEqual(capturedStates["Base.BookCarpentry1"].minLevel, 1,
    "captured multiplier minimum level")
assertEqual(capturedStates["Base.BookCarpentry1"].maxLevel, 2,
    "captured multiplier maximum level")

local restore = makePlayer(0, { ["Base.BookCarpentry1"] = 110 }, 1.5)
assertEqual(LegacyJournal.applySkillBookProgress(restore,
    { ["Base.BookCarpentry1"] = 220 }), true, "restore changed")
assertEqual(restore.pages["Base.BookCarpentry1"], 220, "restore pages")
assertEqual(restore.multiplier, 3, "restore multiplier")
assertEqual(restore.lastMinLevel, 1, "restore minimum level")
assertEqual(restore.lastMaxLevel, 2, "restore maximum level")

local noDowngrade = makePlayer(0, { ["Base.BookCarpentry1"] = 220 }, 3)
assertEqual(LegacyJournal.applySkillBookProgress(noDowngrade,
    { ["Base.BookCarpentry1"] = 110 }), false, "no downgrade changed")
assertEqual(noDowngrade.pages["Base.BookCarpentry1"], 220, "no downgrade pages")
assertEqual(noDowngrade.multiplier, 3, "no downgrade multiplier")

local missingMultiplier = makePlayer(0, { ["Base.BookCarpentry1"] = 220 }, 0)
assertEqual(missingMultiplier:getModData().LJ_version, 6,
    "multiplier visibility regression uses a v6 completed journal")
assertEqual(LegacyJournal.applySkillBookProgress(missingMultiplier,
    { ["Base.BookCarpentry1"] = 220 }), true, "equal pages rebuild missing multiplier")
assertEqual(missingMultiplier.multiplier, 3, "equal pages rebuilt multiplier")

local savedSnapshot = { ["Base.BookCarpentry1"] = 220 }
local currentSnapshot = { ["Base.BookCarpentry1"] = 110 }
local observableSnapshot = { ["Base.BookCarpentry1"] = true }
local captureSucceeded = true
local realGetSavedSkillBookStates = LegacyJournal.getSavedSkillBookStates
local realCaptureSkillBookStates = LegacyJournal.captureSkillBookStates
LegacyJournal.getSavedSkills = function() return {} end
LegacyJournal.getSavedRecipes = function() return {} end
LegacyJournal.getSavedSkillBooks = function() return savedSnapshot end
LegacyJournal.getSavedVhsLines = function() return {} end
LegacyJournal.captureSkills = function() return {} end
LegacyJournal.captureRecipes = function() return {} end
LegacyJournal.captureSkillBooks = function()
    return currentSnapshot, observableSnapshot, captureSucceeded
end
LegacyJournal.getSavedSkillBookStates = function() return {}, false end
LegacyJournal.captureSkillBookStates = function()
    return {}, observableSnapshot, captureSucceeded
end
LegacyJournal.captureKnownVhsLines = function() return {} end
LegacyJournal.isSkillXpEnabled = function() return false end
LegacyJournal.isRecipesEnabled = function() return false end
LegacyJournal.isSkillBooksEnabled = function() return true end

local readDelta = LegacyJournal.getReadDelta(missingMultiplier, {})
assertEqual(readDelta.books, 0, "restored multiplier read delta")

missingMultiplier.multiplier = 0
readDelta = LegacyJournal.getReadDelta(missingMultiplier, {})
assertEqual(readDelta.books, 0,
    "equal pages with an unobservable client multiplier do not enable reading")

local javaFloatMultiplier = 1.2000000476837158
local storedFloatMultiplier = tonumber(string.format("%.9g", javaFloatMultiplier))
missingMultiplier.multiplier = javaFloatMultiplier
local emptyGetSavedSkillBookStates = LegacyJournal.getSavedSkillBookStates
LegacyJournal.getSavedSkillBookStates = function()
    return {
        ["Base.BookCarpentry1"] = {
            fullType = "Base.BookCarpentry1",
            perkId = "Woodwork",
            multiplier = storedFloatMultiplier,
            minLevel = 1,
            maxLevel = 2,
        },
    }, true
end
readDelta = LegacyJournal.getReadDelta(missingMultiplier, {})
assertEqual(readDelta.books, 0, "persisted float multiplier is not a read delta")
assertEqual(LegacyJournal.applySkillBookProgress(missingMultiplier,
    { ["Base.BookCarpentry1"] = 220 }, {
        ["Base.BookCarpentry1"] = {
            fullType = "Base.BookCarpentry1",
            perkId = "Woodwork",
            multiplier = storedFloatMultiplier,
            minLevel = 1,
            maxLevel = 2,
        },
    }, true), false, "persisted float multiplier is not reapplied")

missingMultiplier.multiplier = javaFloatMultiplier - 0.01
readDelta = LegacyJournal.getReadDelta(missingMultiplier, {})
assertEqual(readDelta.books, 0,
    "multiplier-only difference remains excluded from menu read delta")
LegacyJournal.getSavedSkillBookStates = emptyGetSavedSkillBookStates

local writeDelta = LegacyJournal.getWriteDelta({}, {})
assertEqual(writeDelta.books, 1, "latest snapshot changed count")
assertEqual(writeDelta.mergedBooks["Base.BookCarpentry1"], 110, "latest snapshot replacement")

currentSnapshot = {}
observableSnapshot = {}
writeDelta = LegacyJournal.getWriteDelta({}, {})
assertEqual(writeDelta.books, 0, "empty snapshot changed count")
assertEqual(writeDelta.mergedBooks["Base.BookCarpentry1"], 220, "empty snapshot retains old pages")

currentSnapshot = { ["Base.BookCarpentry1"] = 110 }
observableSnapshot = { ["Base.BookCarpentry1"] = true }
savedSnapshot = {
    ["Base.BookCarpentry1"] = 220,
    ["Mod.RemovedBook"] = 200,
}
writeDelta = LegacyJournal.getWriteDelta({}, {})
assertEqual(writeDelta.mergedBooks["Base.BookCarpentry1"], 110,
    "observable lower snapshot remains intentional")
assertEqual(writeDelta.mergedBooks["Mod.RemovedBook"], 200,
    "missing mod book is retained")

currentSnapshot = {}
observableSnapshot = {}
captureSucceeded = false
writeDelta = LegacyJournal.getWriteDelta({}, {})
assertEqual(writeDelta.mergedBooks["Base.BookCarpentry1"], 220,
    "enumeration failure retains observable old entry")
assertEqual(writeDelta.mergedBooks["Mod.RemovedBook"], 200,
    "enumeration failure retains removed-mod entry")
captureSucceeded = true

LegacyJournal.isSkillBooksEnabled = function() return false end
currentSnapshot = { ["Base.BookCarpentry1"] = 110 }
observableSnapshot = { ["Base.BookCarpentry1"] = true }
writeDelta = LegacyJournal.getWriteDelta({}, {})
assertEqual(writeDelta.books, 0, "disabled snapshot changed count")
assertEqual(writeDelta.mergedBooks["Base.BookCarpentry1"], 220, "disabled snapshot retention")

LegacyJournal.getSavedSkillBookStates = realGetSavedSkillBookStates
LegacyJournal.captureSkillBookStates = realCaptureSkillBookStates

local function makeJournal(modData)
    local item = { modData = modData }
    function item:getFullType() return "Base.Diary2" end
    function item:getModData() return self.modData end
    return item
end

local partialJournal = makeJournal({
    LJ_written = true,
    LJ_skills = "Woodwork=25",
    externalField = "keep",
})
local version, supported = LegacyJournal.getRecordVersion(partialJournal)
assertNil(version, "versionless journal has no supported schema")
assertEqual(supported, false, "versionless journal is rejected")
assertEqual(LegacyJournal.migrateRecord(partialJournal), false, "versionless journal is not upgraded")
assertNil(partialJournal.modData.LJ_version, "rejected journal is not stamped")
assertEqual(partialJournal.modData.externalField, "keep", "rejection preserves unknown fields")

local priorJournal = makeJournal({ LJ_written = true, LJ_version = "2", LJ_recipes = "Soup" })
assertEqual(LegacyJournal.migrateRecord(priorJournal), false, "prior version is not upgraded")
assertEqual(priorJournal.modData.LJ_version, "2", "prior version remains unchanged")

local futureJournal = makeJournal({ LJ_written = true, LJ_version = LegacyJournal.VERSION + 1, externalField = "keep" })
assertEqual(LegacyJournal.isSupportedRecord(futureJournal), false, "future version rejected")
assertEqual(LegacyJournal.migrateRecord(futureJournal), false, "future version not migrated")
assertEqual(futureJournal.modData.LJ_version, LegacyJournal.VERSION + 1, "future version not overwritten")
assertEqual(futureJournal.modData.externalField, "keep", "future fields preserved")

local malformedJournal = makeJournal({ LJ_written = true, LJ_version = "3.0" })
assertEqual(LegacyJournal.isSupportedRecord(malformedJournal), false, "malformed version rejected")
assertEqual(LegacyJournal.migrateRecord(malformedJournal), false, "malformed version not overwritten")
assertEqual(malformedJournal.modData.LJ_version, "3.0", "malformed field preserved")

-- Current records preserve the exact multiplier state. Page counts remain a
-- separate progress field and must not replace the saved multiplier range.
local exactState = {
    ["Base.BookCarpentry1"] = {
        fullType = "Base.BookCarpentry1",
        perkId = "Woodwork",
        multiplier = 1.5,
        minLevel = 1,
        maxLevel = 2,
    },
}
LegacyJournal.isAuthor = function() return true end
LegacyJournal.isSkillBooksEnabled = function() return true end
local currentJournal = makeJournal({
    LJ_written = true,
    LJ_version = LegacyJournal.VERSION,
    LJ_skillBooks = "Base.BookCarpentry1=220",
    LJ_skillBookStates = LegacyJournal.encodeSkillBookStates(exactState),
})
local savedStates = LegacyJournal.getSavedSkillBookStates(currentJournal)
local savedState = savedStates["Base.BookCarpentry1"]
assertTrue(savedState ~= nil, "current state exists")
assertEqual(savedState.fullType, "Base.BookCarpentry1", "current state full type")
assertEqual(savedState.perkId, "Woodwork", "current state perk id")
assertEqual(savedState.multiplier, 1.5, "current state multiplier")
assertEqual(savedState.minLevel, 1, "current state minimum level")
assertEqual(savedState.maxLevel, 2, "current state maximum level")

local persistedJournal = makeJournal({})
local originalIsSupportedItem = LegacyJournal.isSupportedItem
local originalIsWritten = LegacyJournal.isWritten
local originalHasWritingTool = LegacyJournal.hasWritingTool
local originalCanCurrentCharacterUpdate = LegacyJournal.canCurrentCharacterUpdate
local originalRefreshJournalPresentation = LegacyJournal.refreshJournalPresentation
local originalGetWriteDelta = LegacyJournal.getWriteDelta
LegacyJournal.isSupportedItem = function() return true end
LegacyJournal.isWritten = function() return false end
LegacyJournal.hasWritingTool = function() return true end
LegacyJournal.canCurrentCharacterUpdate = function() return true end
LegacyJournal.refreshJournalPresentation = function() end
LegacyJournal.getWriteDelta = function()
    return {
        xp = 0,
        skills = 0,
        recipes = 0,
        books = 1,
        vhs = 0,
        mergedSkills = {},
        mergedRecipes = {},
        mergedBooks = { ["Base.BookCarpentry1"] = 220 },
        mergedBookStates = exactState,
        mergedMedia = {},
    }
end
assertEqual(LegacyJournal.commitWrite({}, persistedJournal), true, "current state commit")
assertTrue(persistedJournal.modData.LJ_skillBookStates ~= nil,
    "current state is persisted in journal mod data")
LegacyJournal.isSupportedItem = originalIsSupportedItem
LegacyJournal.isWritten = originalIsWritten
LegacyJournal.hasWritingTool = originalHasWritingTool
LegacyJournal.canCurrentCharacterUpdate = originalCanCurrentCharacterUpdate
LegacyJournal.refreshJournalPresentation = originalRefreshJournalPresentation
LegacyJournal.getWriteDelta = originalGetWriteDelta
local persistedState = LegacyJournal.getSavedSkillBookStates(persistedJournal)["Base.BookCarpentry1"]
assertEqual(persistedState.multiplier, 1.5, "persisted current state reads back exactly")

local exactRestore = makePlayer(0, { ["Base.BookCarpentry1"] = 0 }, 0)
assertEqual(LegacyJournal.applyRead(exactRestore, currentJournal), true, "current exact state restore")
assertEqual(exactRestore.pages["Base.BookCarpentry1"], 220, "current exact state pages")
assertEqual(exactRestore.multiplier, 1.5, "current exact state multiplier restored")
assertEqual(exactRestore.lastMinLevel, 1, "current exact state minimum restored")
assertEqual(exactRestore.lastMaxLevel, 2, "current exact state maximum restored")

-- Changing only multiplier/range metadata is a new skill-book snapshot and
-- therefore must create a write action even when page progress is unchanged.
LegacyJournal.getSavedSkillBooks = function() return { ["Base.BookCarpentry1"] = 220 } end
LegacyJournal.getSavedSkillBookStates = function()
    return {
        ["Base.BookCarpentry1"] = {
            fullType = "Base.BookCarpentry1",
            perkId = "Woodwork",
            multiplier = 3,
            minLevel = 1,
            maxLevel = 2,
        },
    }
end
LegacyJournal.captureSkillBooks = function()
    return { ["Base.BookCarpentry1"] = 220 }, { ["Base.BookCarpentry1"] = true }, true
end
LegacyJournal.captureSkillBookStates = function()
    return {
        ["Base.BookCarpentry1"] = {
            fullType = "Base.BookCarpentry1",
            perkId = "Woodwork",
            multiplier = 4.5,
            minLevel = 2,
            maxLevel = 3,
        },
    }, { ["Base.BookCarpentry1"] = true }, true
end
LegacyJournal.isSkillBooksEnabled = function() return true end
local stateDelta = LegacyJournal.getWriteDelta({}, {})
assertEqual(stateDelta.books, 1, "multiplier or range state change creates write delta")
assertEqual(stateDelta.mergedBookStates["Base.BookCarpentry1"].multiplier, 4.5,
    "latest exact multiplier is merged")
assertEqual(stateDelta.mergedBookStates["Base.BookCarpentry1"].minLevel, 2,
    "latest exact minimum is merged")
assertEqual(stateDelta.mergedBookStates["Base.BookCarpentry1"].maxLevel, 3,
    "latest exact maximum is merged")

LegacyJournal.getSavedSkillBookStates = function() return {} end
LegacyJournal.captureSkillBookStates = function()
    return {}, { ["Base.BookCarpentry1"] = true }, true
end
stateDelta = LegacyJournal.getWriteDelta({}, {})
assertNil(stateDelta.mergedBookStates["Base.BookCarpentry1"],
    "no multiplier snapshot is not composed")

print("Legacy Journal skill-book policy tests: PASS")
