--[[
    A series of tests that mines and destroys the tunnel parts during various states of use and confirms that the tunnel and train ends up in the expected state.
    Tests that the below combinations end in the expected outcome:
        - Train state: none, startApproaching, partiallyOnPortalTrack, entered, leaving.
        - Tunnel part: entrancePortal, tunnelSegment, exitPortal.
        - Removal action: mine, destroy
    Tunnel checks:
        - Check that the tunnel has an expected result from the API after part is removed. If it was mined and in use at the time the part should be replaced.
        - Check that the tunnel can/can't be used in both directions based on if the tunnel part was healed (automatically replaced) for an invalid mining or if the train is left with no path to its destination.
]]
local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

-- These must be the same name as Common.TunnelUsageAction, with the exception of "none" and "partiallyOnPortalTrack".
---@class Tests_MDTT_TrainStates
local TrainStates = {
    none = "none", -- Removal occurs before tunnel is used at all.
    startApproaching = Common.TunnelUsageAction.startApproaching,
    partiallyOnPortalTrack = "partiallyOnPortalTrack", -- Removal occurs when the entry train detector is killed. No published event for this as we have reserved the track from distance already.
    entered = Common.TunnelUsageAction.entered,
    leaving = Common.TunnelUsageAction.leaving
}
---@class Tests_MDTT_TunnelParts
local TunnelParts = {
    entrancePortal = "entrancePortal",
    tunnelSegment = "tunnelSegment",
    exitPortal = "exitPortal"
}
---@class Tests_MDTT_RemovalActions
local RemovalActions = {
    mine = "mine",
    destroy = "destroy"
}

local DoMinimalTests = true -- If TRUE does minimal tests just to check the general mining and destroying behavior. Intended for regular use as part of all tests. If FALSE does the whole test suite and follows DoSpecificTests.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainStateFilter = {} -- Pass in array of TrainStates keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificTunnelPartFilter = {} -- Pass in array of TunnelUsageTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.
local SpecificRemovalActionFilter = {} -- Pass in array of RemovalActions keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

---@class Tests_MDTT_FinalTunnelStates
local FinalTunnelStates = {
    complete = "complete",
    broken = "broken"
}
---@class Tests_MDTT_FinalTunnelStates
local FinalTrainStates = {
    complete = "complete",
    partDestroyed = "partDestroyed",
    fullyDestroyed = "fullyDestroyed"
}

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_MDTT_TestScenario[]
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainState = the TrainStates of this test.
        tunnelPart = the TunnelParts of this test.
        removalAction = the RemovalActions of this test.
        expectedTunnelState = the FinalTunnelStates of this test. Either complete or broken.
        expectedTrainState = the FinalTrainStates of this test. Either complete, partDestroyed or fullyDestroyed. Train is a 1-1 so when half in/out there will be just 1 carriage left.
    }
]]
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

local blueprintString = "0eNq1ms1y2jAUhd9Fa8hYkiVZ7PsMXXQyjAMq8dTYjG3SMhnevTakJQ1O+6G4K359juyj7yJf9Cweyn3YNUXVicWzKFZ11YrFl2fRFpsqL4f3usMuiIUourAVM1Hl2+FVkxfl9/yw7PZVFcr5rm66vFyGai2OM1FU6/BDLORxhnReHaKO9zMRqq7oinAex+nFYVnttw+h6TV/H9n1h1bztqt3vdqubvtD6mrw6WXmmZ+JQ//YD0Gsiyaszh/amWi7/PxcfA5tJ4YhvrFQ4CSvHdOz47XhU94UL5ZyxE3/w60Nm21/SH+i/eebx27M2sRZpxNY6zhrM4G1jLO2H7fWkVm7CazdmLX6p3U2gbWJs/YTWOs4a5lEsax8pJ18z27fl7dm09T949X5zofvLldN3bZFtRkbTuSFlypmOGMDiL38eqoByMgBpP8lEBk7P0zUdJSR9V1OUOpkZJWVE9S6yCorJ6h1LtJ6gloXCbtKJiizkdZygnkWaa0+bB05wZWOYTmSZHWpY38UqfdXvm+v5Jio4aIOi1ouarCo46Iai2ZcVGJRj0UdDkonXBQHpSUXxUFpxUVxUFpzURyU5kRZHhQnyvKgOFGWB8WJsjwoTpTlQXGiDA4q5UQZHFTKiTI4qJQTZXBQKSaKX1HMk8TRpxgnyU8d0yR5RhgmyScTZknyjDBKCmdkMEkKZ2QwSApnZDBHCmdkMEYKZ2QwR5pnhDnSPCPMkeYZYY40zwhzpHlGmKMUZ2QxRynOyGKOUpyRxRylOCOLOUpxRhZzZHhGmCP+U2wxR3zNYDFHfHFjMUd8FWYxR3y56DBHfF3rMEd8Ae4wR/xOwWGO+C2Nwxzxey+HOeI3iQ5zxO9mHeaI33Y7zBHvDzjMEW9kZJgj3nHJMEe8NZRhjngPK8Mc8WZbhjnyPCPMkecZYY48zwhz5HlGmCPPM8IcyQSH5BMuilPykovimLziojgnr7koDsrf0GzgQfFuA283eN5u4P0Gz/sNvOHgecOBdxz8haiyXtXbuiuewoii0neJ169+meum6KVe/hFJ7oZPhn1D7XBAU6++hW7+dR/KYdYcR//359TxXseJeqqquSrnjvc7TsWEXHqd/P3Sq5svPYeTt1pOZYyqeq7K8dQ3TBPOp75hmnBA9Q3ThP/m8aaLlBw/3naRkm3++zVQffVn8mXv36d82Pt337+1egzrffmy2fBCyvC6r149Rq++dN4Yeb2B8Ep3UD7tc1y82l45E0+hac9jyWTqvHKpN6kz+nj8CeO13jU="

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainState .. "     " .. testScenario.tunnelPart .. "     " .. testScenario.removalAction .. "     Expected result: " .. testScenario.expectedTunnelState .. " tunnel - " .. testScenario.expectedTrainState .. " train"
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    local surface = TestFunctions.GetTestSurface()

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEast, stationWest
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "East" then
            stationEast = stationEntity
        elseif stationEntity.backer_name == "West" then
            stationWest = stationEntity
        end
    end

    -- Get the portals, we will just use the 2 most extreme end parts. Entrance portal is easten one.
    local entrancePortalPart, entrancePortalXPos, exitPortalPart, exitPortalXPos = nil, -100000, nil, 100000
    for _, portalEndEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEndEntity.position.x > entrancePortalXPos then
            entrancePortalPart = portalEndEntity
            entrancePortalXPos = portalEndEntity.position.x
        end
        if portalEndEntity.position.x < exitPortalXPos then
            exitPortalPart = portalEndEntity
            exitPortalXPos = portalEndEntity.position.x
        end
    end

    -- Get any tunnel segment.
    local tunnelSegmentToRemove = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]

    -- Get the entrancePortal's entry train detector.
    local entrancePortalTrainDetector = surface.find_entities_filtered {area = {top_left = {x = entrancePortalPart.position.x - 3, y = entrancePortalPart.position.y - 3}, right_bottom = {x = entrancePortalPart.position.x + 3, y = entrancePortalPart.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1", limit = 1}[1]

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = placedEntitiesByGroup["locomotive"][1].train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_MDTT_TestScenarioBespokeData
    local testDataBespoke = {
        stationEast = stationEast, ---@type LuaEntity
        stationWest = stationWest, ---@type LuaEntity
        entrancePortalPart = entrancePortalPart, ---@type LuaEntity
        entrancePortalTrainDetector = entrancePortalTrainDetector, ---@type LuaEntity
        exitPortalPart = exitPortalPart, ---@type LuaEntity
        tunnelSegmentToRemove = tunnelSegmentToRemove, ---@type LuaEntity
        train = train, ---@type LuaTrain
        preFirstTunnelTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train, 0.75), ---@type TestFunctions_TrainSnapshot
        preSecondTunnelTrainSnapshot = nil, ---@type TestFunctions_TrainSnapshot
        tunnelPartRemoved = false, ---@type boolean
        westReached = false, ---@type boolean
        eastReached = false ---@type boolean
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_MDTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_MDTT_TestScenarioBespokeData

    if not testDataBespoke.tunnelPartRemoved then
        if Test.ShouldTunnelPartBeRemoved(testData) then
            -- This is the correct state to remove the tunnel part.
            game.print("train reached tunnel part removal state")
            local entityToDestroy, otherTunnelEntity
            if testScenario.tunnelPart == TunnelParts.entrancePortal then
                entityToDestroy = testDataBespoke.entrancePortalPart
                otherTunnelEntity = testDataBespoke.tunnelSegmentToRemove
            elseif testScenario.tunnelPart == TunnelParts.exitPortal then
                entityToDestroy = testDataBespoke.exitPortalPart
                otherTunnelEntity = testDataBespoke.tunnelSegmentToRemove
            elseif testScenario.tunnelPart == TunnelParts.tunnelSegment then
                entityToDestroy = testDataBespoke.tunnelSegmentToRemove
                otherTunnelEntity = testDataBespoke.entrancePortalPart
            else
                error("Unrecognised tunnelPart for test scenario: " .. testScenario.tunnelPart)
            end
            if testScenario.removalAction == RemovalActions.mine then
                local player = game.connected_players[1]
                local mined = player.mine_entity(entityToDestroy, true)
                if testScenario.expectedTunnelState == FinalTunnelStates.broken and not mined then
                    -- If the tunnel was expected to end up broken then the mine should have worked. But if we expected the tunnel to remain complete then we expect the mine to fail and so do nothing.
                    TestFunctions.TestFailed(testName, "failed to mine tunnel part: " .. testScenario.tunnelPart)
                    return
                end
            elseif testScenario.removalAction == RemovalActions.destroy then
                entityToDestroy.damage(9999999, entityToDestroy.force, "impact", otherTunnelEntity)
            else
                error("Unrecognised removal action: " .. testScenario.removalAction)
            end
            testDataBespoke.tunnelPartRemoved = true

            -- Check the Tunnel Details API returns the expected results for one of the non removed entities
            ---@type RemoteTunnelDetails
            local tunnelObject = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", otherTunnelEntity.unit_number)
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
            if not Test.CheckTrainPostTunnelPartRemoval(testData, testName, tunnelObject) then
                return -- Function raised any TestFailed() internally.
            end
            game.print("Train in expected state post tunnel part removal.")

            -- Complete the tests that end after the tunnel part removal.
            if testScenario.expectedTrainState == FinalTrainStates.fullyDestroyed or testScenario.expectedTrainState == FinalTrainStates.partDestroyed then
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
        else
            -- Train should have no path as tunnel is invalid.
            TestFunctions.TestFailed(testName, "Train should have reached no path state on tunnel removal.")
        end
        return
    else
        if not testDataBespoke.westReached then
            local stationWestTrain = testDataBespoke.stationWest.get_stopped_train()
            if stationWestTrain ~= nil then
                local currentSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain, 0.75)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preFirstTunnelTrainSnapshot, currentSnapshot, false) then
                    TestFunctions.TestFailed(testName, "Train at west station not identical")
                    return
                end
                testDataBespoke.westReached = true
                testDataBespoke.preSecondTunnelTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain, 0.25)
            end
        elseif not testDataBespoke.eastReached then
            local stationEastTrain = testDataBespoke.stationEast.get_stopped_train()
            if stationEastTrain ~= nil then
                local currentSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain, 0.25)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preSecondTunnelTrainSnapshot, currentSnapshot, false) then
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

---@param testData TestManager_TestData
---@return boolean
Test.ShouldTunnelPartBeRemoved = function(testData)
    local testScenario = testData.testScenario ---@type Tests_MDTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_MDTT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    if testScenario.trainState == TrainStates.none then
        -- Always the right time with "none" train state requirement.
        return true
    elseif testScenario.trainState == TrainStates.partiallyOnPortalTrack then
        -- Check if the portaltrain detector has been collided with yet to know if the train has reached the portal.
        if not testDataBespoke.entrancePortalTrainDetector.valid then
            return true
        else
            return false
        end
    else
        -- All other train states check if they have been reported as being reached yet.
        if tunnelUsageChanges.actions[testScenario.trainState] ~= nil and tunnelUsageChanges.actions[testScenario.trainState].count == 1 then
            return true
        else
            return false
        end
    end
end

--- Tunnel part is always removed while the train is heading west.
---@param testData TestManager_TestData
---@param testName string
---@param tunnelObject RemoteTunnelDetails
---@return boolean trainStateOk
Test.CheckTrainPostTunnelPartRemoval = function(testData, testName, tunnelObject)
    local testScenario = testData.testScenario ---@type Tests_MDTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_MDTT_TestScenarioBespokeData

    local inspectionArea = {left_top = {x = testDataBespoke.stationWest.position.x, y = testDataBespoke.stationWest.position.y}, right_bottom = {x = testDataBespoke.stationEast.position.x, y = testDataBespoke.stationEast.position.y}} -- Inspection area needs to find trains that are anywhere on the tracks between the stations
    local trainOnSurface = TestFunctions.GetTrainInArea(inspectionArea)
    local tunnelUsageEntry  ---@type RemoteTunnelUsageEntry
    if tunnelObject ~= nil then
        tunnelUsageEntry = remote.call("railway_tunnel", "get_tunnel_usage_entry_for_id", tunnelObject.tunnelUsageId)
    end

    if testScenario.expectedTrainState == FinalTrainStates.complete then
        -- We expect the train to exist so either: the train is on the surface and identical, or it is using the tunnel at present.
        if tunnelUsageEntry ~= nil then
            -- Train is using the underground so it must be complete. There may be a surface train, but it will be incomplete and so check underground first.
            if tunnelUsageEntry.train ~= nil then
                local currentSnapshot = TestFunctions.GetSnapshotOfTrain(tunnelUsageEntry.train, 0.75)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preFirstTunnelTrainSnapshot, currentSnapshot, false) then
                    TestFunctions.TestFailed(testName, "Train underground not identical")
                    return false
                end
                return true
            end
        elseif trainOnSurface ~= nil then
            -- Train isn't underground and so the surface train must be complete.
            local currentSnapshot = TestFunctions.GetSnapshotOfTrain(trainOnSurface, 0.75)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preFirstTunnelTrainSnapshot, currentSnapshot, false) then
                TestFunctions.TestFailed(testName, "Train on surface not identical")
                return false
            end
            return true
        else
            TestFunctions.TestFailed(testName, "No train on surface or underground")
            return false
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
    elseif testScenario.expectedTrainState == FinalTrainStates.partDestroyed then
        -- Confirm that theres a partial train on the surface.
        if trainOnSurface == nil then
            TestFunctions.TestFailed(testName, "Should be a partial train on the surface")
            return false
        end
        local currentSnapshot = TestFunctions.GetSnapshotOfTrain(trainOnSurface, 0.75)
        if TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.preFirstTunnelTrainSnapshot, currentSnapshot, false) then
            TestFunctions.TestFailed(testName, "Train on surface is the same, but should be partial")
            return false
        end
        return true
    end
end

---@param testName string
Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local trainStatesToTest  ---@type Tests_MDTT_TrainStates
    local tunnelPartsToTest  ---@type Tests_MDTT_TunnelParts
    local removalActionsToTest  ---@type Tests_MDTT_RemovalActions
    if DoSpecificTests then
        -- Adhock testing option.
        trainStatesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStates, SpecificTrainStateFilter)
        tunnelPartsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelParts, SpecificTunnelPartFilter)
        removalActionsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(RemovalActions, SpecificRemovalActionFilter)
    elseif DoMinimalTests then
        -- Minimal tests.
        trainStatesToTest = {[TrainStates.none] = TrainStates.none, [TrainStates.partiallyOnPortalTrack] = TrainStates.partiallyOnPortalTrack, [TrainStates.leaving] = TrainStates.leaving}
        tunnelPartsToTest = {TunnelParts.entrancePortal}
        removalActionsToTest = RemovalActions
    else
        -- Do whole test suite.
        trainStatesToTest = TrainStates
        tunnelPartsToTest = TunnelParts
        removalActionsToTest = RemovalActions
    end

    for _, trainState in pairs(trainStatesToTest) do
        for _, tunnelPart in pairs(tunnelPartsToTest) do
            for _, removalAction in pairs(removalActionsToTest) do
                ---@class Tests_MDTT_TestScenario
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
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

Test.CalculateExpectedResults = function(testScenario)
    local expectedTunnelState, expectedTrainState

    -- Work out expected tunnel state.
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

    -- Work out expected train state.
    if testScenario.removalAction == RemovalActions.mine then
        -- Mine action, so the train will always be either intact or complete using the tunnel.
        expectedTrainState = FinalTrainStates.complete
    elseif testScenario.removalAction == RemovalActions.destroy then
        -- Destroy action.
        if testScenario.trainState == TrainStates.none or testScenario.trainState == TrainStates.startApproaching then
            expectedTrainState = FinalTrainStates.complete
        elseif testScenario.trainState == TrainStates.partiallyOnPortalTrack then
            -- Train will be part on the portal when any portal/tunnel segment is removed. So only part of the train will be lost as well as all the tunnel and portal tracks.
            expectedTrainState = FinalTrainStates.partDestroyed
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
