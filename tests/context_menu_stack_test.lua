local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual))
    end
end

-- Mirror the B42 ISInventoryPane.getActualUniqueItems contract: a collapsed
-- stack stores a dummy at [1], so [2] is its one representative item.
local function vanillaActualUniqueItems(items)
    local result = {}
    for _, entry in ipairs(items) do
        if entry.kind == "stack" then
            table.insert(result, entry.items[2])
        else
            table.insert(result, entry)
        end
    end
    return result
end

local function makeItem(id, written, authorUser, page)
    return {
        id = id,
        modData = {
            LJ_written = written,
            LJ_authorUser = authorUser,
            LJ_progressPage = page,
        },
    }
end

local blankStackItems = { makeItem(100, false, "", 0) }
for id = 1, 20 do
    blankStackItems[#blankStackItems + 1] = makeItem(id, false, "", 0)
end
local secondStackItems = {
    makeItem(200, true, "", 0),
    makeItem(201, true, "author-a", 12),
}

local singleStack = vanillaActualUniqueItems({
    { kind = "stack", items = blankStackItems },
})
assertEqual(#blankStackItems - 1, 20, "fixture contains twenty blank journals")
assertEqual(#singleStack, 1, "one twenty-item stack gets one representative")
assertEqual(singleStack[1].id, 1,
    "single stack representative is the first real item after dummy")

local twoStacks = vanillaActualUniqueItems({
    { kind = "stack", items = blankStackItems },
    { kind = "stack", items = secondStackItems },
})
assertEqual(#twoStacks, 2, "two collapsed stacks get two representatives")
assertEqual(twoStacks[2].id, 201,
    "completed stack representative keeps its own item identity")
assertEqual(twoStacks[2].modData.LJ_written, true,
    "completed representative does not become the blank item")
assertEqual(twoStacks[2].modData.LJ_progressPage, 12,
    "representative preserves independent continuation ModData")

print("Legacy Journal context-menu stack aggregation tests: PASS")
