
local TableGetn = table.getn

local BuildOffsets = { { 2, 0 }, { 0, 2 }, { -2, 0 }, { 0, -2 } }

---@param extractor Unit
---@param engineers Unit[]
RingExtractor = function(extractor, engineers)

    -- verify the storage
    local storage = engineers[1].Blueprint.BlueprintId:sub(1, 2) .. 'b1106'
    if (not __blueprints[storage]) or
        (not engineers[1]:CanBuild(storage))
    then
        return
    end

    -- split engineers by faction
    local faction = engineers[1].Blueprint.FactionCategory
    local engineersOfFaction = EntityCategoryFilterDown(categories[faction], engineers)
    local engineersOther = EntityCategoryFilterDown(categories.ALLUNITS - categories[faction], engineers)

    local blueprint = extractor:GetBlueprint()
    local skirtSize = blueprint.Physics.SkirtSizeX
    local cx, _, cz = extractor:GetPositionXYZ()

    -- we manually scan for build skirts in the surrounding area. The function brain:CanBuildStructureAt(...) does
    -- not always return correct results: it may end up returning true after factories upgraded

    local x1 = cx - (skirtSize + 10)
    local z1 = cz - (skirtSize + 10)
    local x2 = cx + (skirtSize + 10)
    local z2 = cz + (skirtSize + 10)

    -- find all units that may prevent us from building
    local structures = GetUnitsInRect(x1, z1, x2, z2)
    if not structures then
        return
    end

    structures = EntityCategoryFilterDown(categories.STRUCTURE + categories.EXPERIMENTAL, structures)

    -- populate the skirts to check
    local skirts = {}
    for k, unit in structures do
        local blueprint = unit:GetBlueprint()
        local px, _, pz = unit:GetPositionXYZ()
        local sx, sz = 0.5 * blueprint.Physics.SkirtSizeX, 0.5 * blueprint.Physics.SkirtSizeZ
        local rect = {
            px - sx, -- top left
            pz - sz, -- top left
            px + sx, -- bottom right
            pz + sz -- bottom right
        }

        skirts[k] = rect
    end

    local buildLocation = {}
    local engineerTable = {}
    local emptyTable = {}

    -- loop over build locations in given layer
    for k, location in BuildOffsets do
        buildLocation[1] = cx + location[1]
        buildLocation[3] = cz + location[2]
        buildLocation[2] = GetTerrainHeight(buildLocation[1], buildLocation[3])

        local freeToBuild = true
        for _, skirt in skirts do
            if buildLocation[1] > skirt[1] and buildLocation[1] < skirt[3] then
                if buildLocation[3] > skirt[2] and buildLocation[3] < skirt[4] then
                    freeToBuild = false
                    break
                end
            end
        end

        if freeToBuild then
            for _, engineer in engineersOfFaction do
                engineerTable[1] = engineer
                IssueBuildMobile(engineerTable, buildLocation, storage, emptyTable)
            end
        end
    end

    -- assist for all other builders, spread over the number of actual builders
    local builderIndex = 1
    local builderCount = TableGetn(engineersOfFaction)
    for _, builder in engineersOther do
        engineerTable[1] = builder
        IssueGuard(engineerTable, engineersOfFaction[builderIndex])

        builderIndex = builderIndex + 1
        if builderIndex > builderCount then
            builderIndex = 1
        end
    end
end
