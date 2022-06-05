-- Test to confirm that tunnels that have crossing tunnel underground parts (and portals) removed and replaced in them are detected correctly. Handles all the variations of parts removal and checks the tunnel are removed and re-established as expected.
-- Does individual parts and also a number of parts (next N in the list), which once its looped over all the starting parts means there's been a complete range of parts test removed in batches.
-- It rebuilds the parts in forwards and reverse removal order to ensure theres no variance here. The tunnels state is inspected after each part is rebuilt to ensure it only becomes valid on the final part.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local TableUtils = require("utility.table-utils")

-- Main tunnel is entrance to exit: right to left.
-- Crossing tunnel is north to south.
---@class Tests_TPRT_PartToRemove
local PartToRemove = {
    portal_main_entrance_innerSegment = "portal_main_entrance_innerSegment",
    portal_main_entrance_innerEnd = "portal_main_entrance_innerEnd",
    portal_crossing_entrance_innerSegment = "portal_crossing_entrance_innerSegment",
    portal_crossing_entrance_innerEnd = "portal_crossing_entrance_innerEnd",
    underground_main_segment_entranceSegment = "underground_main_segment_entranceSegment",
    underground_main_crossingTunnel_entranceSegment = "underground_main_crossingTunnel_entranceSegment",
    underground_main_crossingTunnel_middleSegment = "underground_main_crossingTunnel_middleSegment",
    underground_main_crossingTunnel_exitSegment = "underground_main_crossingTunnel_exitSegment",
    underground_crossing_segment_entranceSegment = "underground_crossing_segment_entranceSegment",
    portal_crossing_exit_innerEnd = "portal_crossing_exit_innerEnd",
    portal_crossing_exit_innerSegment = "portal_crossing_exit_innerSegment",
    portal_main_exit_innerEnd = "portal_main_exit_innerEnd",
    portal_main_exit_innerSegment = "portal_main_exit_innerSegment"
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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.partToRemove .. "     -     Removing part count: " .. testScenario.numberOfPartsToRemove .. "     -     Sequence to remove: " .. testScenario.sequenceOfPartsToRemove .. "    -    Rebuild order: " .. testScenario.rebuildPartOrder
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    -- E = portal End    S = portal Segment    U = Underground segment    C = Crossing Underground (2 tiles)    F = Fake Crossing Underground (6 tiles)
    -- Tunnel for 1-1 on main line (east/west):   E S*7 E U C C C E S*7 E
    -- Tunnel for 1-1 on crossing line (north/south):    E S*7 E U F E S*7 E
    local blueprint = "0eNq1mEuOgzAMhu+SNUhNAuVxlVGFaBsxkSCgJMwUVdx9UthU1VStjbtC4ZHP2ObH9pUd21ENVhvPyivTp944Vn5dmdONqdvbOT8NipVMe9WxiJm6u61srdvfeqr8aIxq46G3vm4rp5pOGR87H643357NEdPmrC6s5HOE3FSZ890+Yj5ELDC012q1dFlMlRm7o7IB9MZ2ERt6F3bozc2Wy/LQxMpYZAF01lad1mtJxH5qq+t1tbzCA01APfIULaFoSYbmUHRCheYFFJ2SocGx3pOhUyg6I0OD0ywnQ4PTrNjwKYOjy3fPaGNQHtvYPhzff1uwnzlKuIJkLbwH34rXuO3KFTQLyZYEbI5kb9euoFpIdkrAxsZ7T8BOkeyMgI3NtZyAjc01lIDFyAgLIgGLkZ4WHMOP13uqk+2d06b5z/1Ie8Rn7MGaIz9jDjZaCSY3salJULVh3U5QtWFdTFC1IRVXEFRt2FgX29HI/6vcbUZjywrJt6ORaSYF5kvG1o1S4otycE0uqRpNeO8hqRpNeMclqRpNeJ8pqRpNeHctqRpN+ExBFkRoxCRlR4UGp1myYVL2alB2iNbRXnk3Xgy3KOtWmcl5khUiS2U47PN5/gOHeB8A"
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local allPlacedEntities, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the various entities we need. Blueprints are built left to right and all of these are in the same vertical alignment. So we can just read them off in entity built order.
    local portalSegments = TableUtils.GetTableValueWithInnerKeyValue(allPlacedEntities, "name", "railway_tunnel-portal_segment-straight", true, false)
    local tunnelCrossingSegments = TableUtils.GetTableValueWithInnerKeyValue(allPlacedEntities, "name", "railway_tunnel-underground_segment-straight-tunnel_crossing", true, false)
    local portal_main_entrance_innerSegment = portalSegments[7]
    local portal_main_entrance_innerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][2]
    local portal_crossing_entrance_innerSegment = portalSegments[14]
    local portal_crossing_entrance_innerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][4]
    local underground_main_segment_entranceSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]
    local underground_main_crossingTunnel_entranceSegment = tunnelCrossingSegments[1]
    local underground_main_crossingTunnel_middleSegment = tunnelCrossingSegments[2]
    local underground_main_crossingTunnel_exitSegment = tunnelCrossingSegments[3]
    local underground_crossing_segment_entranceSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][2]
    local portal_crossing_exit_innerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][5]
    local portal_crossing_exit_innerSegment = portalSegments[15]
    local portal_main_exit_innerEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][7]
    local portal_main_exit_innerSegment = portalSegments[22]
    local reference_crossing_tunnelPart = placedEntitiesByGroup["railway_tunnel-portal_end"][6] -- exit far end.
    local reference_main_tunnelPart = placedEntitiesByGroup["railway_tunnel-portal_end"][8] -- exit far end.

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_TPRT_TestScenarioBespokeData
    local testDataBespoke = {
        portal_main_entrance_innerSegment = portal_main_entrance_innerSegment, ---@type LuaEntity
        portal_main_entrance_innerEnd = portal_main_entrance_innerEnd, ---@type LuaEntity
        portal_crossing_entrance_innerSegment = portal_crossing_entrance_innerSegment, ---@type LuaEntity
        portal_crossing_entrance_innerEnd = portal_crossing_entrance_innerEnd, ---@type LuaEntity
        underground_main_segment_entranceSegment = underground_main_segment_entranceSegment, ---@type LuaEntity
        underground_main_crossingTunnel_entranceSegment = underground_main_crossingTunnel_entranceSegment, ---@type LuaEntity
        underground_main_crossingTunnel_middleSegment = underground_main_crossingTunnel_middleSegment, ---@type LuaEntity
        underground_main_crossingTunnel_exitSegment = underground_main_crossingTunnel_exitSegment, ---@type LuaEntity
        underground_crossing_segment_entranceSegment = underground_crossing_segment_entranceSegment, ---@type LuaEntity
        portal_crossing_exit_innerEnd = portal_crossing_exit_innerEnd, ---@type LuaEntity
        portal_crossing_exit_innerSegment = portal_crossing_exit_innerSegment, ---@type LuaEntity
        portal_main_exit_innerEnd = portal_main_exit_innerEnd, ---@type LuaEntity
        portal_main_exit_innerSegment = portal_main_exit_innerSegment, ---@type LuaEntity
        reference_main_tunnelPart = reference_main_tunnelPart, ---@type LuaEntity
        reference_crossing_tunnelPart = reference_crossing_tunnelPart, ---@type LuaEntity
        entitiesRemoved = {}, ---@type Tests_TPRT_EntityToRemove[]
        rebuildEntitiesOnTick = nil, ---@type uint
        removedPartsFromMainTunnel = 0, ---@type uint
        removedPartsFromCrossingTunnel = 0 ---@type uint
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
    if player == nil then
        TestFunctions.TestFailed(testName, "no player to use for test")
        return
    end

    -- Do removal steps first.
    if testDataBespoke.rebuildEntitiesOnTick == nil then
        -- Check both tunnel exists at the start.
        if remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_main_tunnelPart.unit_number) == nil then
            TestFunctions.TestFailed(testName, "main tunnel should be complete at the start")
            return
        end
        if remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_crossing_tunnelPart.unit_number) == nil then
            TestFunctions.TestFailed(testName, "crossing tunnel should be complete at the start")
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
        local entityToHandleDetails = testDataBespoke.entitiesRemoved[1]
        local mined = player.mine_entity(entityToHandleDetails.entity)
        if mined == nil then
            TestFunctions.TestFailed(testName, "first tunnel part couldn't be mined")
            return
        end

        -- Check the tunnels are in the expected state after first removal.
        local mainTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_main_tunnelPart.unit_number) ---@type RemoteTunnelDetails
        local crossingTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_crossing_tunnelPart.unit_number) ---@type RemoteTunnelDetails
        if Test.PartRequiredByMainTunnel(entityToHandleDetails.partName) then
            testDataBespoke.removedPartsFromMainTunnel = testDataBespoke.removedPartsFromMainTunnel + 1

            -- Part required so check tunnel is removed.
            if mainTunnelObject ~= nil then
                TestFunctions.TestFailed(testName, "first part removed that main tunnel required, but tunnel wasn't removed: " .. entityToHandleDetails.partName)
                return
            end
        else
            -- Part not required so check tunnel remains.
            if mainTunnelObject == nil then
                TestFunctions.TestFailed(testName, "first part removed that main tunnel didn't require, but tunnel was removed: " .. entityToHandleDetails.partName)
                return
            end
        end
        if Test.PartRequiredByCrossingTunnel(entityToHandleDetails.partName) then
            testDataBespoke.removedPartsFromCrossingTunnel = testDataBespoke.removedPartsFromCrossingTunnel + 1

            -- Part required so check tunnel is removed.
            if crossingTunnelObject ~= nil then
                TestFunctions.TestFailed(testName, "first part removed that crossing tunnel required, but tunnel wasn't removed: " .. entityToHandleDetails.partName)
                return
            end
        else
            -- Part not required so check tunnel remains.
            if crossingTunnelObject == nil then
                TestFunctions.TestFailed(testName, "first part removed that crossing tunnel didn't require, but tunnel was removed: " .. entityToHandleDetails.partName)
                return
            end
        end

        -- Remove any other parts for this test.
        for i = 2, #testDataBespoke.entitiesRemoved do
            entityToHandleDetails = testDataBespoke.entitiesRemoved[i]
            mined = player.mine_entity(entityToHandleDetails.entity)
            if mined == nil then
                TestFunctions.TestFailed(testName, "subsequent tunnel part couldn't be mined for part number: " .. tostring(i) .. " type: " .. entityToHandleDetails.partName)
                return
            end

            local partRequiredByMainTunnel = Test.PartRequiredByMainTunnel(entityToHandleDetails.partName)
            local partRequiredByCrossingTunnel = Test.PartRequiredByCrossingTunnel(entityToHandleDetails.partName)

            -- Record if the part affected each tunnel - needed for whne rebuilding the parts.
            if partRequiredByMainTunnel then
                testDataBespoke.removedPartsFromMainTunnel = testDataBespoke.removedPartsFromMainTunnel + 1
            end
            if partRequiredByCrossingTunnel then
                testDataBespoke.removedPartsFromCrossingTunnel = testDataBespoke.removedPartsFromCrossingTunnel + 1
            end

            -- Check that any complete tunnels were broken only if expected.
            if mainTunnelObject ~= nil then
                -- Check this tunnel if it wasn't broken before.
                mainTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_main_tunnelPart.unit_number)
                if partRequiredByMainTunnel then
                    -- Part required so check tunnel is removed.
                    if mainTunnelObject ~= nil then
                        TestFunctions.TestFailed(testName, "part removed that main tunnel required, but tunnel wasn't removed: " .. entityToHandleDetails.partName)
                        return
                    end
                else
                    -- Part not required so check tunnel remains.
                    if mainTunnelObject == nil then
                        TestFunctions.TestFailed(testName, "part removed that main tunnel didn't require, but tunnel was removed: " .. entityToHandleDetails.partName)
                        return
                    end
                end
            else
                -- Tunnel didn't exist before, so check still not present.
                mainTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_main_tunnelPart.unit_number)
                if mainTunnelObject ~= nil then
                    TestFunctions.TestFailed(testName, "main tunnel didn't exist and un-required part removed, but tunnel now exists again: " .. entityToHandleDetails.partName)
                    return
                end
            end
            if crossingTunnelObject ~= nil then
                -- Check this tunnel if it wasn't broken before.
                crossingTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_crossing_tunnelPart.unit_number)
                if partRequiredByCrossingTunnel then
                    -- Part required so check tunnel is removed.
                    if crossingTunnelObject ~= nil then
                        TestFunctions.TestFailed(testName, "part removed that crossing tunnel required, but tunnel wasn't removed: " .. entityToHandleDetails.partName)
                        return
                    end
                else
                    -- Part not required so check tunnel remains.
                    if crossingTunnelObject == nil then
                        TestFunctions.TestFailed(testName, "part removed that crossing tunnel didn't require, but tunnel was removed: " .. entityToHandleDetails.partName)
                        return
                    end
                end
            else
                -- Tunnel didn't exist before, so check still not present.
                crossingTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_crossing_tunnelPart.unit_number)
                if crossingTunnelObject ~= nil then
                    TestFunctions.TestFailed(testName, "crossing tunnel didn't exist and un-required part removed, but tunnel now exists again: " .. entityToHandleDetails.partName)
                    return
                end
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

        -- Get current states of tunnels.
        local mainTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_main_tunnelPart.unit_number) ---@type RemoteTunnelDetails
        local crossingTunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", testDataBespoke.reference_crossing_tunnelPart.unit_number) ---@type RemoteTunnelDetails

        -- Update how many parts for each tunnel are awaiting to be rebuilt.
        if Test.PartRequiredByMainTunnel(partDetails.partName) then
            testDataBespoke.removedPartsFromMainTunnel = testDataBespoke.removedPartsFromMainTunnel - 1
        end
        if Test.PartRequiredByCrossingTunnel(partDetails.partName) then
            testDataBespoke.removedPartsFromCrossingTunnel = testDataBespoke.removedPartsFromCrossingTunnel - 1
        end

        -- Check expected tunnel state for each tunnel.
        if testDataBespoke.removedPartsFromMainTunnel == 0 then
            if mainTunnelObject == nil then
                TestFunctions.TestFailed(testName, "Last main tunnel part rebuilt, but tunnel not returned")
                return
            end
        else
            if mainTunnelObject ~= nil then
                TestFunctions.TestFailed(testName, "Non last main tunnel part rebuilt, but tunnel has returned early: " .. partDetails.partName)
                return
            end
        end
        if testDataBespoke.removedPartsFromCrossingTunnel == 0 then
            if crossingTunnelObject == nil then
                TestFunctions.TestFailed(testName, "Last crossing tunnel part rebuilt, but tunnel not returned")
                return
            end
        else
            if crossingTunnelObject ~= nil then
                TestFunctions.TestFailed(testName, "Non last crossing tunnel part rebuilt, but tunnel has returned early: " .. partDetails.partName)
                return
            end
        end
    end

    -- All parts rebuilt and tunnel states checked for each part, so test is complete.
    TestFunctions.TestCompleted(testName)
end

--- Returns true if the part is required by the main tunnel.
---@param partName Tests_TPRT_PartToRemove
---@return boolean
Test.PartRequiredByMainTunnel = function(partName)
    if partName == PartToRemove.portal_main_entrance_innerSegment or partName == PartToRemove.portal_main_entrance_innerEnd or partName == PartToRemove.portal_main_exit_innerEnd or partName == PartToRemove.portal_main_exit_innerSegment or partName == PartToRemove.underground_main_segment_entranceSegment or partName == PartToRemove.underground_main_crossingTunnel_entranceSegment or partName == PartToRemove.underground_main_crossingTunnel_middleSegment or partName == PartToRemove.underground_main_crossingTunnel_exitSegment then
        return true
    else
        return false
    end
end

--- Returns true if the part is required by the crossing tunnel.
---@param partName Tests_TPRT_PartToRemove
---@return boolean
Test.PartRequiredByCrossingTunnel = function(partName)
    if partName == PartToRemove.portal_crossing_entrance_innerSegment or partName == PartToRemove.portal_crossing_entrance_innerEnd or partName == PartToRemove.portal_crossing_exit_innerEnd or partName == PartToRemove.portal_crossing_exit_innerSegment or partName == PartToRemove.underground_main_crossingTunnel_entranceSegment or partName == PartToRemove.underground_main_crossingTunnel_middleSegment or partName == PartToRemove.underground_main_crossingTunnel_exitSegment or partName == PartToRemove.underground_crossing_segment_entranceSegment then
        return true
    else
        return false
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
        partToRemoveToTest = {PartToRemove.portal_main_entrance_innerEnd, PartToRemove.portal_crossing_entrance_innerEnd, PartToRemove.underground_main_crossingTunnel_entranceSegment}
        numberSequenceOfPartsToRemoveToTest = {NumberSequenceOfPartsToRemove.one, NumberSequenceOfPartsToRemove.threeEveryThird}
        rebuildPartOrderToTest = {RebuildPartOrder.removedOrder}
    else
        -- Do whole test suite.
        partToRemoveToTest = PartToRemove
        numberSequenceOfPartsToRemoveToTest = NumberSequenceOfPartsToRemove
        rebuildPartOrderToTest = RebuildPartOrder
    end

    -- Work out the combinations of the various types that we will do a test for.
    local numberOfPartsToRemove  ---@type uint
    local sequenceOfPartsToRemove  ---@type uint
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
