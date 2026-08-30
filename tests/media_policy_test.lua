local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function makeList(values)
    return {
        size = function() return #values end,
        get = function(_, index) return values[index + 1] end,
    }
end

local function makeLine(guid, codes)
    return {
        getTextGuid = function() return guid end,
        getCodes = function() return codes end,
    }
end

local function makeMedia(id, lines)
    return {
        getId = function() return id end,
        getLineCount = function() return #lines end,
        getLine = function(_, index) return lines[index + 1] end,
    }
end

local cds = makeList({
    makeMedia("cd-entertainment-id", { makeLine("cd-entertainment", "BOR-1") }),
})
local vhs = makeList({
    makeMedia("mixed-tape", {
        makeLine("mixed-entertainment", "BOR-1"),
        makeLine("mixed-skill", "CRP+1"),
    }),
    makeMedia("transient-tape", { makeLine("transient-only", "STS-1") }),
    makeMedia("recipe-tape", { makeLine("recipe", "RCP=Make Soup") }),
})

local recordedMedia = {
    getAllMediaForType = function(_, mediaType)
        if mediaType == 0 then return cds end
        if mediaType == 1 then return vhs end
    end,
}

getZomboidRadio = function()
    return { getRecordedMedia = function() return recordedMedia end }
end

local trainingMediaEnabled = true
getSandboxOptions = function()
    return {
        getOptionByName = function(_, name)
            if name ~= "LegacyJournal.TrainingMedia" then return nil end
            return { getValue = function() return trainingMediaEnabled end }
        end,
    }
end

dofile("workshop/Contents/mods/LegacyJournal/42.20/media/lua/shared/legacyjournal/legacyjournal_shared.lua")

assertEqual(LegacyJournal.isTrainingMediaEnabled(), true, "training media defaults enabled")
trainingMediaEnabled = false
assertEqual(LegacyJournal.isTrainingMediaEnabled(), false, "training media can be disabled")
trainingMediaEnabled = true

local eligible = LegacyJournal.getPermanentRewardMedia().byId
assertEqual(eligible["mixed-tape"].allLines[1], "mixed-entertainment", "mixed media keeps entertainment line")
assertEqual(eligible["mixed-tape"].rewardLines[1], "mixed-skill", "mixed media keeps reward line")
assertEqual(eligible["recipe-tape"].rewardLines[1], "recipe", "recipe media is retained")
assertEqual(eligible["cd-entertainment-id"], nil, "entertainment CD is excluded")
assertEqual(eligible["transient-tape"], nil, "transient-only VHS is excluded")

local player = {
    isKnownMediaLine = function(_, guid)
        return guid == "mixed-skill" or guid == "recipe"
    end,
}
local captured = LegacyJournal.captureKnownMediaRewards(player)
assertEqual(captured["mixed-tape"], 1, "known mixed media is captured once")
assertEqual(captured["recipe-tape"], 1, "known recipe media is captured once")
assertEqual(captured["cd-entertainment-id"], nil, "known entertainment CD is not captured")
assertEqual(captured["transient-tape"], nil, "known transient VHS is not captured")

local item = { modData = {
    LJ_written = true,
    LJ_version = 6,
    LJ_mediaRewards = table.concat({
        "cd-entertainment-id=1",
        "mixed-tape=1",
        "recipe-tape=1",
        "transient-tape=1",
    }, ";"),
} }
function item:getFullType() return "Base.Diary2" end
function item:getModData() return self.modData end

local saved = LegacyJournal.getSavedMediaRewards(item)
assertEqual(saved["mixed-tape"], 1, "mixed media record remains usable")
assertEqual(saved["recipe-tape"], 1, "recipe media record remains usable")
assertEqual(saved["cd-entertainment-id"], nil, "entertainment CD record is ignored")
assertEqual(saved["transient-tape"], nil, "transient VHS record is ignored")

print("Legacy Journal media policy tests: PASS")
