-- Test to confirm that portals and tunnels that have parts removed and replaced in them are detected correctly. Handles all the variations of parts removal and checks the portal and tunnel are removed and re-established as expected.
-- Does individual parts and also a number of parts (next N in the list), which once its looped over all the starting parts means there's been a complete range of parts test removed in batches.
-- It rebuilds the parts in forwards and reverse removal order to ensure theres no variance here. The tunnels state is inspected after each part is rebuilt to ensure it only becomes valid on the final part.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Utils = require("utility.utils")

---@class Tests_TPRT_PartToRemove
local PartToRemove = {
    portal_entrance_innerEnd = "portal_entrance_innerEnd",
    portal_entrance_innerSegment = "portal_entrance_innerSegment",
    portal_entrance_middleSegment = "portal_entrance_middleSegment",
    portal_entrance_outerSegment = "portal_entrance_outerSegment",
    portal_entrance_outerEnd = "portal_entrance_outerEnd",
    underground_entranceSegment = "underground_entranceSegment",
    underground_middleSegment = "underground_middleSegment",
    underground_exitSegment = "underground_exitSegment",
    portal_exit_innerEnd = "portal_exit_innerEnd",
    portal_exit_innerSegment = "portal_exit_innerSegment",
    portal_exit_middleSegment = "portal_exit_middleSegment",
    portal_exit_outerSegment = "portal_exit_outerSegment",
    portal_exit_outerEnd = "portal_exit_outerEnd"
}
-- Will remove the targetted PartToRemove and then the subsequent defined number of parts when iterating the list.
---@class Tests_TPRT_NumberSequenceOfPartsToRemove
local NumberSequenceOfPartsToRemove = {
    one = "one",
    threeSequential = "threeSequential",
    threeEveryThird = "threeEveryThird"
}
---@class Tests_TPRT_RebuildPartOrder
local RebuildPartOrder = {
    removedOrder = "removedOrder",
    reverseRemovedOrder = "reverseRemovedOrder"
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificPartToRemoveFilter = {} -- Pass in an array of PartToRemove keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificNumberSequenceOfPartsToRemoveFilter = {} -- Pass in an array of NumberSequenceOfPartsToRemove keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificRebuildPartOrderFilter = {} -- Pass in an array of RebuildPartOrder keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_TPRT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.partToRemove .. "     -     Removing part count: " .. testScenario.numberOfPartsToRemove .. "     -     Sequence to remove: " .. testScenario.sequenceOfPartsToRemove .. "    -    Rebuilt Order: " .. testScenario.rebuildPartOrder
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    -- Tunnel for 1-1:   E S*7 E U*5 E S*7 E
    local blueprint = "0eNqtlstqwzAQRf9l1gpYchzJ/pVSgpIIV2DLRpbbmuB/rxJvQmkhvZ2V0IM5V/NirnTqZjdGHxI1V/LnIUzUvFxp8m2w3e0sLaOjhnxyPQkKtr/tovXdh12OaQ7BdbtxiMl2x8m1vQtpN6V8374lWgX5cHGf1MhVgEZduDzYUeuroMzwybtN6X2zHMPcn1zMoCfMCRqHKVsYwk1LtrqTqhK0UKMz6eKjO2+XStC7jd5uu/sfvuHUX13yE1ti7JKBLWuMvedga4xdcbDBeB842CXG1hxsMNcMA7sAc63GSroAQyyL33hz7kGxjUNen/sw6GwpmRTUoMel4hIAlrgsuQSgSbDnEgAWu6ygrDdoxBkam0F9zdDYDOpmhsZm0DKv/8/WYLxVwcAGi1tJBjY6rzEMbBrMNVVCJX14KsR5LL5P083DRJ+fuDhtz43c61rpqszLwazrF84FJAs="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local allPlacedEntities, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 1, y = 1}, testName)

    -- Get the various entities we need. Blueprints are built left to right and all of these are in the same vertical alignment. So we can just read them off in entity built order.
    -- Entrance is on the right with exit on the left.
    local portal_exit_outerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][1]
    local portal_exit_innerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][2]
    local portal_entrance_innerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][3]
    local portal_entrance_outerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][4]
    local portalSegments = Utils.GetTableValueWithInnerKeyValue(allPlacedEntities, "name", "railway_tunnel-portal_segment-straight", true, false)
    local portal_exit_outerSegment = portalSegments[1]
    local portal_exit_middleSegment = portalSegments[3]
    local portal_exit_innerSegment = portalSegments[5]
    local portal_entrance_innerSegment = portalSegments[6]
    local portal_entrance_middleSegment = portalSegments[8]
    local portal_entrance_outerSegment = portalSegments[10]
    local underground_exitSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]
    local underground_middleSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][3]
    local referenceTunnelPart = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][4]
    local underground_entranceSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][5]

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_TPRT_TestScenarioBespokeData
    local testDataBespoke = {
        portal_entrance_innerEnd = portal_entrance_innerEnd, ---@type LuaEntity
        portal_entrance_outerEnd = portal_entrance_outerEnd, ---@type LuaEntity
        portal_entrance_innerSegment = portal_entrance_innerSegment, ---@type LuaEntity
        portal_entrance_middleSegment = portal_entrance_middleSegment, ---@type LuaEntity
        portal_entrance_outerSegment = portal_entrance_outerSegment, ---@type LuaEntity
        underground_entranceSegment = underground_entranceSegment, ---@type LuaEntity
        underground_middleSegment = underground_middleSegment, ---@type LuaEntity
        underground_exitSegment = underground_exitSegment, ---@type LuaEntity
        portal_exit_innerEnd = portal_exit_innerEnd, ---@type LuaEntity
        portal_exit_outerEnd = portal_exit_outerEnd, ---@type LuaEntity
        portal_exit_innerSegment = portal_exit_innerSegment, ---@type LuaEntity
        portal_exit_middleSegment = portal_exit_middleSegment, ---@type LuaEntity
        portal_exit_outerSegment = portal_exit_outerSegment, ---@type LuaEntity
        referenceTunnelPart = referenceTunnelPart, ---@type LuaEntity
        entitiesRemoved = {}, ---@type Tests_TPRT_EntityToRemove[]
        rebuildEntitiesOnTick = nil ---@type uint
    }
    testData.bespoke = testDataBespoke

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_TPRT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_TPRT_TestScenarioBespokeData

    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local player = game.connected_players[1]
    local refTunnelPart_unitNumber = testDataBespoke.referenceTunnelPart.unit_number
    local entityToHandleDetails  ---@type Tests_TPRT_EntityToRemove

    -- Do removal steps first.
    if testDataBespoke.rebuildEntitiesOnTick == nil then
        -- Check the tunnel exists at the start.
        ---@type RemoteTunnelDetails
        local tunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.referenceTunnelPart.unit_number)
        if tunnelObject == nil then
            TestFunctions.TestFailed(testName, "tunnel should be complete at the start")
            return
        end

        -- Make the removal entity list

        -- Theres always 1 entity to be removed and then add in the others for this test.
        local nextPartIndex = testScenario.partToRemove
        -- We always want to record the first one and then start counting from there.
        local sequenceToRemoveCount = testScenario.sequenceOfPartsToRemove
        while #testDataBespoke.entitiesRemoved < testScenario.numberOfPartsToRemove do
            -- If its the part count we want then record this.
            if sequenceToRemoveCount == testScenario.sequenceOfPartsToRemove then
                ---@type LuaEntity
                local entity = testDataBespoke[nextPartIndex]
                ---@class Tests_TPRT_EntityToRemove
                local entityToRemove = {
                    partName = PartToRemove[nextPartIndex],
                    entity = entity,
                    entity_name = entity.name,
                    entity_position = entity.position,
                    entity_direction = entity.direction
                }
                table.insert(testDataBespoke.entitiesRemoved, entityToRemove)

                --Reset count ready to skip for next lot.
                sequenceToRemoveCount = 1
            else
                -- Just increase the count until we reach the one we want.
                sequenceToRemoveCount = sequenceToRemoveCount + 1
            end

            -- Always iterate the list.
            nextPartIndex = next(PartToRemove, nextPartIndex)
            if nextPartIndex == nil then
                -- When the last part index is iterated it becomes nil index, so continue at the start of the list.
                nextPartIndex = next(PartToRemove)
            end
        end

        -- Remove the first part and check the tunnel isn't valid.
        entityToHandleDetails = testDataBespoke.entitiesRemoved[1]
        local mined = player.mine_entity(entityToHandleDetails.entity)
        if mined == nil then
            TestFunctions.TestFailed(testName, "first tunnel part couldn't be mined: " .. entityToHandleDetails.partName)
            return
        end
        tunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", refTunnelPart_unitNumber)
        if tunnelObject ~= nil then
            TestFunctions.TestFailed(testName, "tunnel should have been broken when the first part was removed: " .. entityToHandleDetails.partName)
            return
        end

        -- Remove any other parts for this test.
        for i = 2, #testDataBespoke.entitiesRemoved do
            entityToHandleDetails = testDataBespoke.entitiesRemoved[i]
            mined = player.mine_entity(entityToHandleDetails.entity)
            if mined == nil then
                TestFunctions.TestFailed(testName, "subsequent tunnel part couldn't be mined for part number: " .. tostring(i) .. " type: " .. entityToHandleDetails.partName)
                return
            end
        end

        -- Record when to rebuild the entities. Delay is just to help user see visually what was removed.
        testDataBespoke.rebuildEntitiesOnTick = event.tick + 60

        return
    end

    -- Wait until rebuild time.
    if event.tick < testDataBespoke.rebuildEntitiesOnTick then
        return
    end

    -- Rebuild each part and check the tunnel doesn't return until all are done.
    local indexStart, indexModifier, indexMax
    if testScenario.rebuildPartOrder == RebuildPartOrder.removedOrder then
        indexStart = 1
        indexModifier = 1
        indexMax = #testDataBespoke.entitiesRemoved
    else
        indexStart = #testDataBespoke.entitiesRemoved
        indexModifier = -1
        indexMax = 1
    end
    for index = indexStart, indexMax, indexModifier do
        local partDetails = testDataBespoke.entitiesRemoved[index]
        local createdEntity = surface.create_entity {name = partDetails.entity_name, position = partDetails.entity_position, direction = partDetails.entity_direction, force = force, create_build_effect_smoke = false, raise_built = true}
        if createdEntity == nil then
            TestFunctions.TestFailed(testName, "Failed to rebuild entity number: " .. tostring(index) .. " type: " .. partDetails.partName)
            return
        end
        -- Check expected tunnel state based on if last part to be rebuilt or not.

        local tunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", refTunnelPart_unitNumber)
        if index == indexMax then
            -- Is last part so should make a tunnel.
            if tunnelObject == nil then
                TestFunctions.TestFailed(testName, "last part being rebuilt should have returned tunnel")
            else
                TestFunctions.TestCompleted(testName)
            end
            return
        else
            -- Is not last part so there should be no tunnel.
            if tunnelObject ~= nil then
                TestFunctions.TestFailed(testName, "NON last part being rebuilt should NOT have returned tunnel, rebuilt number: " .. tostring(index) .. " type: " .. partDetails.partName)
                return
            end
        end
    end
end

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local partToRemoveToTest  ---@type Tests_TPRT_PartToRemove[]
    local numberSequenceOfPartsToRemoveToTest  ---@type Tests_TPRT_NumberSequenceOfPartsToRemove
    local rebuildPartOrderToTest  ---@type Tests_TPRT_RebuildPartOrder
    if DoSpecificTests then
        -- Adhock testing option.
        partToRemoveToTest = TestFunctions.ApplySpecificFilterToListByKeyName(PartToRemove, SpecificPartToRemoveFilter)
        numberSequenceOfPartsToRemoveToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NumberSequenceOfPartsToRemove, SpecificNumberSequenceOfPartsToRemoveFilter)
        rebuildPartOrderToTest = TestFunctions.ApplySpecificFilterToListByKeyName(RebuildPartOrder, SpecificRebuildPartOrderFilter)
    elseif DoMinimalTests then
        partToRemoveToTest = {PartToRemove.portal_entrance_innerEnd, PartToRemove.portal_entrance_innerSegment, PartToRemove.portal_entrance_middleSegment, PartToRemove.underground_entranceSegment, PartToRemove.underground_middleSegment}
        numberSequenceOfPartsToRemoveToTest = {NumberSequenceOfPartsToRemove.one, NumberSequenceOfPartsToRemove.threeEveryThird}
        rebuildPartOrderToTest = {RebuildPartOrder.removedOrder}
    else
        -- Do whole test suite.
        partToRemoveToTest = PartToRemove
        numberSequenceOfPartsToRemoveToTest = NumberSequenceOfPartsToRemove
        rebuildPartOrderToTest = RebuildPartOrder
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, partToRemove in pairs(partToRemoveToTest) do
        for _, numberSequenceOfPartsToRemove in pairs(numberSequenceOfPartsToRemoveToTest) do
            for _, rebuildPartOrder in pairs(rebuildPartOrderToTest) do
                if numberSequenceOfPartsToRemove == NumberSequenceOfPartsToRemove.one then
                    numberOfPartsToRemove = 1
                    sequenceOfPartsToRemove = 1
                elseif numberSequenceOfPartsToRemove == NumberSequenceOfPartsToRemove.threeSequential then
                    numberOfPartsToRemove = 3
                    sequenceOfPartsToRemove = 1
                elseif numberSequenceOfPartsToRemove == NumberSequenceOfPartsToRemove.threeEveryThird then
                    numberOfPartsToRemove = 3
                    sequenceOfPartsToRemove = 3
                end

                ---@class Tests_TPRT_TestScenario
                local scenario = {
                    partToRemove = partToRemove,
                    numberOfPartsToRemove = numberOfPartsToRemove,
                    sequenceOfPartsToRemove = sequenceOfPartsToRemove,
                    rebuildPartOrder = rebuildPartOrder
                }
                table.insert(Test.TestScenarios, scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
