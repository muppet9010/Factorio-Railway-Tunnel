--[[
    A series of tests that mines the tunnel during various states of use and confirms that the tunnel ends up in the expected state.
    Tests the below combinations end in an expected outcome:
        - Train state: none, startApproaching, enteringCarriageRemoved, fullyEntered, startedLeaving, fullyLeft.
        - Tunnel part: entrancePortal, tunnelSegment, exitPortal.
        - Removal action: mine, destroy
    Tunnel checks:
        - Check that the tunnel has an expected result from the API after part is removed. If it was mined and in use at the time the part should be replaced.
        - Check that the tunnel can/can't be used in both directions based on if the tunnel part was replaced or the train is left with no path to its destination.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

local TrainStates = {
    none = "none",
    startApproaching = "startApproaching",
    enteringCarriageRemoved = "enteringCarriageRemoved",
    fullyEntered = "fullyEntered",
    startedLeaving = "startedLeaving",
    fullyLeft = "fullyLeft"
}
local TunnelParts = {
    entrancePortal = "entrancePortal",
    tunnelSegment = "tunnelSegment",
    exitPortal = "exitPortal"
}
local RemovalActions = {
    mine = "mine",
    destroy = "destroy"
}
local FinalTunnelStates = {
    complete = "complete",
    broken = "broken"
}
local FinalTrainStates = {
    complete = "complete",
    halfDestroyed = "halfDestroyed", -- Train is only a 1-1. So when partially in/out there will be just 1 carriage on the surface.
    fullyDestroyed = "fullyDestroyed"
}

local DoMinimalTests = true -- If TRUE does minimal tests just to check the general mining and destroying behavior. Intended for regular use as part of all tests. If FALSE does the whole test suite and follows DoSpecificTests.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainStateFilter = {"startApproaching"} -- Pass in array of TrainStates keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificTunnelPartFilter = {"entrancePortal"} -- Pass in array of TunnelUsageTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.
local SpecificRemovalActionFilter = {"mine"} -- Pass in array of RemovalActions keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainState = the TrainStates of this test.
        tunnelPart = the TunnelParts of this test.
        removalAction = the RemovalActions of this test.
        expectedTunnelState = the FinalTunnelStates of this test. Either complete or broken.
        expectedTrainState = the FinalTrainStates of this test. Either complete, halfDestroyed or fullyDestroyed. Train is a 1-1 so when half in/out there will be just 1 carriage left.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

local blueprintString = "0eNqtml1P4kAUhv/LXINhPjof3O9v2IuNIRVHbLa0pC3uGsN/31b8IAvG5xhv1ELnnUOfPtKcmSd1U+/zrquaQS2fVLVum14tfz2pvto0ZT29NjzuslqqashbNVNNuZ2OurKq/5SPq2HfNLmeH3+tdm03lPWq33d35TrPd/X4c5vH6MNMVc1t/quW+jBD4SdDzOF6psaUaqjysbjng8dVs9/e5G7MfBs5jEObeT+0uzFt1/bjkLaZ5hlj5nY871EtbRijb6sur49v+pnqh/L4t/qZ+6nasynMFz757XkNryWksxIeyq56KUJfmN9+Mn+fN9OFfi1gNZ21Wndt31fN5sNyinCxHPNpOU5WzscFpC8WUHxTAV5/sQD/PTdE/CqB8DZ/P930m/th/qzNx7f9/1NcCI041CQcmnhowKF6wVMLnqp5quWphqdyVtriVM1hacdTBbQKniqg5XmqgBY3SwtocbUEsLhanJXhZnFUhovFSRnuFQdlsFaCTCyV4MNjpQSUsFBaIJQJPFVQa+Spgps/8VTuqcVKacEXgNU8ldOyhqdyWpZbJXgIsI6nCmhhs7Tg0cpyt6yAFnfLCmhxt6yAFnfLclqOu+U4LcfdcpyW4245Tstxtxyn5bhbTkCLu1UIaHG3CgEt7lYhoMXdKgS0uFsFp1VwtzynVXC3PKdVcLc8p1VwtzynVXC3vIAWdysIaHG3goAWdysIaHG3goAWdytwWp67FTktz92KnJbnbkVOy3O3IqfluVtRQIu7lQS0uFtJQIu7lQS0uFtJQIu7lTitgN0yC04raJ7KaQXDUzmtYHkqpxUcTxXQwm4ZQcMteJ4qoBV4qoBW5KkCWomnclqRuyXoZUTulqCXEd/dqtt1u22H6iFfigxXi2RPHzTarhqzXpZfFlfTW9MSZT+N6Nr17zzM7/a5ntYhDpcm5voJmiiR6ydookSun6CJEj279NZ9cumN9NJzQyULY9xQQfcmckMF3ZvEDRV0bxI3VNC9SfzbT9C9SVw/QfcmObTN4LVQp8+WdN+3Gfwop20G1+NL6/t8u69f9jW8qzIdj/++oj8557gv43yrwlnsFPy8o2J5srtjph5y1x9LidqFZIJNC6+DPxz+AeZROY0="

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainState .. "     " .. testScenario.tunnelPart .. "     " .. testScenario.removalAction .. "     Expected result: " .. testScenario.expectedTunnelState .. " tunnel - " .. testScenario.expectedTrainState .. " train"
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEast, stationWest
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "East" then
            stationEast = stationEntity
        elseif stationEntity.backer_name == "West" then
            stationWest = stationEntity
        end
    end

    -- Get the portals.
    local entrancePortal, entrancePortalXPos, exitPortal, exitPortalXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-tunnel_portal_surface"]) do
        if portalEntity.position.x > entrancePortalXPos then
            entrancePortal = portalEntity
            entrancePortalXPos = portalEntity.position.x
        end
        if portalEntity.position.x < exitPortalXPos then
            exitPortal = portalEntity
            exitPortalXPos = portalEntity.position.x
        end
    end

    -- Get the eastern most segment. Its touching a portal and has the othe segments to its west.
    local tunnelSegmentToRemove, tunnelSegmentXPos = nil, -1000000
    for _, semmentEntity in pairs(placedEntitiesByGroup["railway_tunnel-underground_segment-straight"]) do
        if semmentEntity.position.x > tunnelSegmentXPos then
            tunnelSegmentToRemove = semmentEntity
            tunnelSegmentXPos = semmentEntity.position.x
        end
    end

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = placedEntitiesByGroup["locomotive"][1].train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    testData.bespoke = {
        stationEast = stationEast,
        stationWest = stationWest,
        entrancePortal = entrancePortal,
        exitPortal = exitPortal,
        tunnelSegmentToRemove = tunnelSegmentToRemove,
        train = train,
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train),
        tunnelPartRemoved = false,
        westReached = false,
        eastReached = false
    }
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.TunnelUsageChanged = function(event)
    -- OVERHAUL: functionised
    local testData = TestFunctions.GetTestDataObject(event.testName)

    -- Record the action for later reference.
    local actionListEntry = testData.actions[event.action]
    if actionListEntry then
        actionListEntry.count = actionListEntry.count + 1
        actionListEntry.recentChangeReason = event.changeReason
    else
        testData.actions[event.action] = {
            name = event.action,
            count = 1,
            recentChangeReason = event.changeReason
        }
    end
end

Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario, testDataBespoke = testData.testScenario, testData.bespoke

    if not testDataBespoke.tunnelPartRemoved then
        if Test.ShouldTunnelPartBeRemoved(testDataBespoke) then
            -- This is the correct state to remove the tunnel part.
            game.print("train reached tunnel part removal state")
            local entityToDestroy, otherTunnelEntity
            if testScenario.tunnelPart == TunnelParts.entrancePortal then
                entityToDestroy = testDataBespoke.entrancePortal
                otherTunnelEntity = testDataBespoke.tunnelSegmentToRemove
            elseif testScenario.tunnelPart == TunnelParts.exitPortal then
                entityToDestroy = testDataBespoke.exitPortal
                otherTunnelEntity = testDataBespoke.tunnelSegmentToRemove
            elseif testScenario.tunnelPart == TunnelParts.tunnelSegment then
                entityToDestroy = testDataBespoke.tunnelSegmentToRemove
                otherTunnelEntity = testDataBespoke.entrancePortal
            else
                error("Unrecognised tunnelPart for test scenario: " .. testScenario.tunnelPart)
            end
            if testScenario.removalAction == RemovalActions.mine then
                local player = game.connected_players[1]
                local mined = player.mine_entity(entityToDestroy, true)
                if testScenario.expectedTunnelState == FinalTunnelStates.broken and not mined then
                    -- If the tunnel was expected to end up broken then the mine should have worked. But if we expected the tunnel to remain complete then we expect the mine to fail and so do nothing.
                    error("failed to mine tunnel part: " .. testScenario.tunnelPart)
                end
            elseif testScenario.removalAction == RemovalActions.destroy then
                entityToDestroy.damage(9999999, entityToDestroy.force, "impact", otherTunnelEntity)
            else
                error("Unrecognised removal action: " .. testScenario.removalAction)
            end
            testDataBespoke.tunnelPartRemoved = true

            -- Check the Tunnel Details API returns the expected results for one of the non removed entities
            local tunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity", otherTunnelEntity.unit_number)
            local apiResultAsExpected
            if testScenario.expectedTunnelState == FinalTunnelStates.complete then
                apiResultAsExpected = tunnelObject ~= nil
            else
                apiResultAsExpected = tunnelObject == nil
            end
            if apiResultAsExpected then
                game.print("API Result as expected.")
            else
                TestFunctions.TestFailed(testName, "tunnel API wrong result, tunnelObject is '" .. tostring(tunnelObject) .. "'")
                return
            end

            -- Check if the trains/tunnel usage existance meets expectations.
            if not Test.CheckTrainPostTunnelPartRemoval(testDataBespoke, testName, tunnelObject) then
                return -- Function raised any TestFailed() internally.
            end
            game.print("Train in expected state post tunnel part removal.")

            -- Complete the tests that end after the tunnel part removal.
            if testScenario.expectedTrainState == FinalTrainStates.fullyDestroyed or testScenario.expectedTrainState == FinalTrainStates.halfDestroyed then
                TestFunctions.TestCompleted(testName)
                return
            end

            -- Complete the tests that end with a broken tunnel after tunnel part removal.
            if testScenario.expectedTunnelState == FinalTunnelStates.broken then
                TestFunctions.TestCompleted(testName)
                return
            end
        end
        return -- End the tick loop here every time we check for the tunnel part removal. Regardless of if its removed or not.
    end

    -- Keep on checking the outcomes that have working tunnel usages to confirm the train reaches the stations as expected.
    if testScenario.trainState == TrainStates.none then
        if testDataBespoke.train == nil or not testDataBespoke.train.valid then
            -- Train should still exist as it never entered the tunnel
            TestFunctions.TestFailed(testName, "Train doesn't exist, but it shouldn't have entered the tunnel.")
            return
        end
        if testDataBespoke.train.state == defines.train_state.no_path then
            -- Train should have no path as tunnel is invalid.
            TestFunctions.TestCompleted(testName)
            return
        else
            -- Train should have no path as tunnel is invalid.
            TestFunctions.TestFailed(testName, "Train should have reached no path state on tunnel removal.")
            return
        end
    else
        if not testDataBespoke.westReached then
            local stationWestTrain = testDataBespoke.stationWest.get_stopped_train()
            if stationWestTrain ~= nil then
                local currentSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentSnapshot, false) then
                    TestFunctions.TestFailed(testName, "Train at west station not identical")
                    return
                end
                testDataBespoke.westReached = true
            end
        elseif not testDataBespoke.eastReached then
            local stationEastTrain = testDataBespoke.stationEast.get_stopped_train()
            if stationEastTrain ~= nil then
                local currentSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentSnapshot, false) then
                    TestFunctions.TestFailed(testName, "Train at east station not identical")
                    return
                end
                testDataBespoke.eastReached = true
            end
        else
            TestFunctions.TestCompleted(testName)
            return
        end
    end
end

Test.ShouldTunnelPartBeRemoved = function(testData)
    local testScenario = testData.testScenario
    if testScenario.trainState == TrainStates.none then
        return true
    else
        if testData.actions[testScenario.trainState] ~= nil and testData.actions[testScenario.trainState].count == 1 then
            return true
        else
            return false
        end
    end
end

Test.CheckTrainPostTunnelPartRemoval = function(testData, testName, tunnelObject)
    local testDataBespoke = testData.bespoke
    local testScenario = testData.testScenario
    local inspectionArea = {left_top = {x = testDataBespoke.stationWest.position.x, y = testDataBespoke.stationWest.position.y}, right_bottom = {x = testDataBespoke.stationEast.position.x, y = testDataBespoke.stationEast.position.y}} -- Inspection area needs to find trains that are anywhere on the tracks between the stations
    local trainOnSurface = TestFunctions.GetTrainInArea(inspectionArea)
    local tunnelUsageEntry
    if tunnelObject ~= nil then
        tunnelUsageEntry = remote.call("railway_tunnel", "get_tunnel_usage_entry_for_id", tunnelObject.tunnelUsageId)
    end

    if testScenario.expectedTrainState == FinalTrainStates.complete then
        -- We expect the train to exist so either: the train is on the surface and identical, or it is using the tunnel at present.
        if tunnelUsageEntry ~= nil then
            -- Train is using the underground so it must be complete. There may be a surface train, but it will be incomplete and so check underground first.
            if tunnelUsageEntry.undergroundTrain ~= nil then
                local currentSnapshot = TestFunctions.GetSnapshotOfTrain(tunnelUsageEntry.undergroundTrain)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentSnapshot, false) then
                    TestFunctions.TestFailed(testName, "Train underground not identical")
                    return false
                end
                return true
            end
        elseif trainOnSurface ~= nil then
            -- Train isn't underground and so the surface train must be complete.
            local currentSnapshot = TestFunctions.GetSnapshotOfTrain(trainOnSurface)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentSnapshot, false) then
                TestFunctions.TestFailed(testName, "Train on surface not identical")
                return false
            end
            return true
        else
            TestFunctions.TestFailed(testName, "No train on surface or underground")
        end
    elseif testScenario.expectedTrainState == FinalTrainStates.fullyDestroyed then
        if trainOnSurface ~= nil then
            TestFunctions.TestFailed(testName, "Shouldn't be a train on the surface")
            return false
        end
        if tunnelUsageEntry ~= nil then
            TestFunctions.TestFailed(testName, "Shouldn't be any underground tunnel")
            return false
        end
        return true
    elseif testScenario.expectedTrainState == FinalTrainStates.halfDestroyed then
        -- Confirm that theres a partial train on the surface.
        if trainOnSurface == nil then
            TestFunctions.TestFailed(testName, "Should be a partial train on the surface")
            return false
        end
        local currentSnapshot = TestFunctions.GetSnapshotOfTrain(trainOnSurface)
        if TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentSnapshot, false) then
            TestFunctions.TestFailed(testName, "Train on surface is the same, but should be partial")
            return false
        end
        return true
    end
end

Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local trainStatesToTest, tunnelPartsToTest, removalActionsToTest
    if DoMinimalTests then
        -- Minimal tests.
        trainStatesToTest = {[TrainStates.none] = TrainStates.none, [TrainStates.enteringCarriageRemoved] = TrainStates.enteringCarriageRemoved}
        tunnelPartsToTest = {TunnelParts.entrancePortal}
        removalActionsToTest = RemovalActions
    elseif DoSpecificTests then
        -- Adhock testing option.
        trainStatesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStates, SpecificTrainStateFilter)
        tunnelPartsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelParts, SpecificTunnelPartFilter)
        removalActionsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(RemovalActions, SpecificRemovalActionFilter)
    else
        -- Do whole test suite.
        trainStatesToTest = TrainStates
        tunnelPartsToTest = TunnelParts
        removalActionsToTest = RemovalActions
    end

    for _, trainState in pairs(trainStatesToTest) do
        for _, tunnelPart in pairs(tunnelPartsToTest) do
            for _, removalAction in pairs(removalActionsToTest) do
                local scenario = {
                    trainState = trainState,
                    tunnelPart = tunnelPart,
                    removalAction = removalAction
                }
                scenario.expectedTunnelState, scenario.expectedTrainState = Test.CalculateExpectedResults(scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
                table.insert(Test.TestScenarios, scenario)
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, {"trainState,tunnelPart,removalAction,expectedTunnelState,expectedTrainState"}, Test.TestScenarios)
    end
end

Test.CalculateExpectedResults = function(testScenario)
    local expectedTunnelState, expectedTrainState

    if testScenario.removalAction == RemovalActions.mine then
        -- Mine actions end tunnel states are affected by where the train is (blocking the mine action).
        if testScenario.trainState == TrainStates.none then
            -- Tunnel not in use so mined tunnel part won't be returned.
            expectedTunnelState = FinalTunnelStates.broken
        else
            -- Tunnel in use so mined tunnel part should be returned.
            expectedTunnelState = FinalTunnelStates.complete
        end
    elseif testScenario.removalAction == RemovalActions.destroy then
        -- destroy actions always make a broken tunnel.
        expectedTunnelState = FinalTunnelStates.broken
    else
        error("invalid testScenario.removalAction: " .. testScenario.removalAction)
    end

    if testScenario.removalAction == RemovalActions.mine then
        -- Mine action, so the train will always be either intact or complete using the tunnel.
        expectedTrainState = FinalTrainStates.complete
    elseif testScenario.removalAction == RemovalActions.destroy then
        -- Destroy action.
        if testScenario.trainState == TrainStates.none or testScenario.trainState == TrainStates.startApproaching then
            expectedTrainState = FinalTrainStates.complete
        elseif testScenario.trainState == TrainStates.fullyLeft and testScenario.tunnelPart ~= TunnelParts.exitPortal then
            -- Train has fully left and is on the exit portal. So as long as this portal isn't destroyed the train will be fine.
            expectedTrainState = FinalTrainStates.complete
        elseif (testScenario.trainState == TrainStates.enteringCarriageRemoved and testScenario.tunnelPart ~= TunnelParts.entrancePortal) or (testScenario.trainState == TrainStates.startedLeaving and testScenario.tunnelPart ~= TunnelParts.exitPortal) then
            -- Train will be half underground when the other portal/tunnel segment is removed. So only half the train will be lost as well as the tunnel.
            expectedTrainState = FinalTrainStates.halfDestroyed
        else
            -- Train is lost entirely with the tunnels loss.
            expectedTrainState = FinalTrainStates.fullyDestroyed
        end
    else
        error("invalid testScenario.removalAction: " .. testScenario.removalAction)
    end

    return expectedTunnelState, expectedTrainState
end

return Test
