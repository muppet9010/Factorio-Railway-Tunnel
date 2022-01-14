--[[
    A series of tests that removes the target train stop and rail while the tunnel is in use. Covers:
        - TargetTypes = rail, trainStop
        - TunnelUsageStates = startApproaching, startedEntering, fullyEntered, startedLeaving, fullyLeft.
        - NextScheduleOrder = none, forwards, reversal.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

local TargetTypes = {
    rail = "rail",
    trainStop = "trainStop"
}
local TunnelUsageStates = {
    startApproaching = "startApproaching",
    startedEntering = "startedEntering",
    fullyEntered = "fullyEntered",
    startedLeaving = "startedLeaving",
    fullyLeft = "fullyLeft"
}
local NextScheduleOrders = {
    none = "none",
    fowards = "forwards",
    reversal = "reversal"
}
local FinalTrainStates = {
    stoppedWhenFirstTargetRemoval = "stoppedWhenFirstTargetRemoval",
    pulledToExitPortalEntry = "pulledToExitPortalEntry",
    secondTargetReached = "secondTargetReached"
}

local DoMinimalTests = true -- The minimal test to prove the concept with a few varieties.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTargetTypesFilter = {"trainStop"} -- Pass in array of TargetTypes keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificTunnelUsageStatesFilter = {"fullyEntered"} -- Pass in array of TunnelUsageStates keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.
local SpecificNextScheduleOrdersFilter = {"reversal"} -- Pass in array of TRUE/FALSE (boolean) to do just those specific Next Schedule Order tests. Leave as nil or empty table for both combinations. Only used when DoSpecificTrainTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1200
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        targetType = the TargetTypes of this test.
        tunnelUsageState = the TunnelUsageStates of this test.
        nextScheduleOrder = the NextScheduleOrders of this test.
        expectedFinalTrainState = the FinalTrainStates calculated for this test.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

local blueprintString = "0eNqtmdlu4kAQRf+lnyGiF3fbfEA+IPM4GiEHOow1xka2IYMi/n3aIUqixEpOjXhh8XKr3LeOe3tS9/Uh7ruqGdTySVXrtunV8ueT6qttU9bjseG0j2qpqiHu1Ew15W7815VV/VieVsOhaWI9v3yt9m03lPWqP3QP5TrO93X63MUkfZ6pqtnEv2qpz79mKh2qhipeIj3/Oa2aw+4+dumC1xhDCtLM+6Hdp7j7tk+3tM2YUZKZF2GmTulqnaQ3VRfXl5N+pvqhvPxWd3HXHmMK/imIYUHy4vsgP2Jqs81t2z2W3aafCmb/o9U2E9kYfcnGfsrmWHbVSz56IgF3nQRMMRnffBs/e43fj829/T3Mx0S+cPVjiAlRz0UzLBq4qMWiORfVWLTAonmBRfWCq3KntOaq3CptuCr3Sluuys3SDqsGgVucqyBwi4MVBG5xsoLALY5WELjF2fLcLcPZ8twtw9ny3C3D2fLcLcPZ8twtw9nKBG5xtjKBW5ytTOAWZysTuMXZygRucbYcd8tythx3y2K2BGZZjJagriwmS4CAxWAJaLWYK8GLxWKsBO9Ai6kSvK4thkrQs1jMlKATdBgpQX/tMFGCoYXDRAlGQQ4TJRiwOUyUYGzpMFGCYbDDRAlG7A4TJZhcOEyUYB7kMFGCGVuGiRLMLTNMlGAWnGGiBPP1DBNVcKMyTJReCJzKuKrAKs9VBV69QVW363bXDtUxTkkWN4V9/1ZtuypJvazaLG7GU+MSXz/e0LXrP3GYPxxiPd56noqb86cRFEnBVXmVeEye1rxKvOaqvEr8G3vrstu288dym66d0PRfGzrOYKrmmA61XbqkOdT1VDjLH4IXpedYasGKH8dSC4rDwwY39ioNjjtBbQS1yGk0glrkNBrBGiun0fDiCBraaBfXsDEY/hC8FgOn0fLiCJxGy4sjZLTBw1UanPeeVlCLnEYrqEVOoxUUB6fR8eLIF2z84BxwUTB+yHnv6QRbLRxLx6sk51gKlpdyjqVgKSznnaRg2S7n9AmWGPOAtmFfE80+bTx+3Ia9i8fY9VGNm8zPG9bLd/vbMzWevNyaJ6cKE2yx8Dr48/kfaIwz2A=="

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.targetType .. "     " .. testScenario.tunnelUsageState .. "     " .. tostring(testScenario.nextScheduleOrder) .. "     Expected result: " .. testScenario.expectedFinalTrainState
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationSecondForwards, stationRemove, stationSecondReverse
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "SecondForwards" then
            stationSecondForwards = stationEntity
        elseif stationEntity.backer_name == "SecondReverse" then
            stationSecondReverse = stationEntity
        elseif stationEntity.backer_name == "Remove" then
            stationRemove = stationEntity
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

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = placedEntitiesByGroup["locomotive"][1].train

    -- Create the train schedule for this specific test.
    local trainSchedule = {
        current = 1,
        records = {}
    }
    if testScenario.targetType == TargetTypes.trainStop then
        trainSchedule.records[1] = {
            station = stationRemove.backer_name,
            wait_conditions = {
                {
                    type = "time",
                    ticks = 60,
                    compare_type = "or"
                }
            }
        }
    elseif testScenario.targetType == TargetTypes.rail then
        trainSchedule.records[1] = {
            rail = stationRemove.connected_rail,
            wait_conditions = {
                {
                    type = "time",
                    ticks = 60,
                    compare_type = "or"
                }
            },
            temporary = true
        }
    else
        error("Unsupported testScenario.targetTunnelRail: " .. testScenario.targetType)
    end
    -- If nextScheduleOrders is "none" there is no second schedule record to add.
    local secondStationName
    if testScenario.nextScheduleOrder == NextScheduleOrders.fowards then
        secondStationName = stationSecondForwards.backer_name
    elseif testScenario.nextScheduleOrder == NextScheduleOrders.reversal then
        secondStationName = stationSecondReverse.backer_name
    end
    if secondStationName ~= nil then
        table.insert(
            trainSchedule.records,
            {
                station = secondStationName,
                wait_conditions = {
                    {
                        type = "time",
                        ticks = 60,
                        compare_type = "or"
                    }
                }
            }
        )
    end
    train.schedule = trainSchedule

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationRemove = stationRemove
    testData.stationSecondForwards = stationSecondForwards
    testData.stationSecondReverse = stationSecondReverse
    testData.entrancePortal = entrancePortal
    testData.exitPortal = exitPortal
    testData.train = train
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.firstTargetRemoved = false
    testData.testScenario = testScenario
    testData.actions = {}
    --[[
        A list of actions and how many times they have occured. Populated as the events come in.
        [actionName] = {
            name = the action name string, same as the key in the table.
            count = how many times the event has occured.
            recentChangeReason = the last change reason text for this action if there was one. Only occurs on single fire actions.
        }
    --]]
    testData.tunnelUsageEntry = nil -- Populated on tunnel usage events.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.TunnelUsageChanged = function(event)
    local testData = TestFunctions.GetTestDataObject(event.testName)
    local testScenario = testData.testScenario

    if not testData.firstTargetRemoved and testScenario.tunnelUsageState == TunnelUsageStates[event.action] then
        -- Is the state we are wanting to act upon.
        if testScenario.targetType == TargetTypes.trainStop then
            testData.stationRemove.destroy()
            game.print("Removed target schedule station.")
        elseif testScenario.targetType == TargetTypes.rail then
            testData.stationRemove.connected_rail.destroy()
            game.print("Removed target schedule rail.")
        else
            error("Unsupported testScenario.targetType: " .. testScenario.targetType)
        end
        testData.firstTargetRemoved = true
        testData.tunnelUsageEntry = {enteringTrain = event.enteringTrain, leavingTrain = event.leavingTrain}
    end
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario = testData.testScenario

    if not testData.firstTargetRemoved then
        -- Wait for the tunnel usage state to trigger the removal.
        return
    end

    if testScenario.expectedFinalTrainState == FinalTrainStates.stoppedWhenFirstTargetRemoval then
        local train = testData.train -- Check for train pre entering.
        if train == nil or not train.valid then
            -- Try to get the leaving train. No other states should have this outcome.
            train = testData.tunnelUsageEntry.leavingTrain
        end
        if train ~= nil and train.valid then
            if train.state == defines.train_state.no_path then
                local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
                if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, false) then
                    TestFunctions.TestFailed(testName, "train stopped doesn't match origional")
                    return
                end
                TestFunctions.TestCompleted(testName)
                return
            end
        end
    elseif testScenario.expectedFinalTrainState == FinalTrainStates.pulledToExitPortalEntry then
        -- Train should be sent to the end of the exit portal as no path anywhere else.
        local atrainAtExitTunnelEntryRail = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testData.exitPortal.position, {x = -22, y = 0}))
        if atrainAtExitTunnelEntryRail ~= nil then
            -- Train will end up with either Wait Station (reached valid schedule record) or No Schedule (has no valid schedule record in its list) once it reaches end of portal track.
            if atrainAtExitTunnelEntryRail.state == defines.train_state.wait_station or atrainAtExitTunnelEntryRail.state == defines.train_state.no_schedule then
                -- Current train will be a part of the full train, rest will still be in the tunnel.
                local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(atrainAtExitTunnelEntryRail)
                if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, true) then
                    TestFunctions.TestFailed(testName, "part of train at end of portal doesn't match origional")
                    return
                end
                TestFunctions.TestCompleted(testName)
                return
            end
        end
    elseif testScenario.expectedFinalTrainState == FinalTrainStates.secondTargetReached then
        -- Try both second stations, only one will end up with a train.
        local stationSecondTrain = testData.stationSecondForwards.get_stopped_train()
        if stationSecondTrain == nil then
            stationSecondTrain = testData.stationSecondReverse.get_stopped_train()
        end
        if stationSecondTrain ~= nil then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationSecondTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, false) then
                TestFunctions.TestFailed(testName, "train at second station doesn't match origional")
                return
            end
            TestFunctions.TestCompleted(testName)
            return
        end
    else
        error("Unsupported testScenario.expectedFinalTrainState: " .. testScenario.expectedFinalTrainState)
    end
end

Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local targetTypesToTest, tunnelUsageStatesToTest, nextScheduleOrdersToTest
    if DoMinimalTests then
        targetTypesToTest = TargetTypes
        tunnelUsageStatesToTest = {TunnelUsageStates.fullyEntered, TunnelUsageStates.startedLeaving}
        nextScheduleOrdersToTest = {NextScheduleOrders.reversal}
    elseif DoSpecificTests then
        -- Adhock testing option.
        targetTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TargetTypes, SpecificTargetTypesFilter)
        tunnelUsageStatesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelUsageStates, SpecificTunnelUsageStatesFilter)
        nextScheduleOrdersToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NextScheduleOrders, SpecificNextScheduleOrdersFilter)
    else
        -- Do whole test suite.
        targetTypesToTest = TargetTypes
        tunnelUsageStatesToTest = TunnelUsageStates
        nextScheduleOrdersToTest = NextScheduleOrders
    end

    for _, targetType in pairs(targetTypesToTest) do
        for _, tunnelUsageState in pairs(tunnelUsageStatesToTest) do
            for _, nextScheduleOrder in pairs(nextScheduleOrdersToTest) do
                local scenario = {
                    targetType = targetType,
                    tunnelUsageState = tunnelUsageState,
                    nextScheduleOrder = nextScheduleOrder
                }
                scenario.expectedFinalTrainState = Test.CalculateExpectedResults(scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
                table.insert(Test.TestScenarios, scenario)
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, {"targetType,tunnelUsageState,nextScheduleOrder,expectedFinalTrainState"}, Test.TestScenarios)
    end
end

Test.CalculateExpectedResults = function(testScenario)
    local expectedFinalTrainState

    if testScenario.nextScheduleOrder == NextScheduleOrders.fowards or testScenario.nextScheduleOrder == NextScheduleOrders.reversal then
        expectedFinalTrainState = FinalTrainStates.secondTargetReached
    elseif testScenario.nextScheduleOrder == NextScheduleOrders.none then
        if testScenario.tunnelUsageState == TunnelUsageStates.startApproaching or testScenario.tunnelUsageState == TunnelUsageStates.fullyLeft then
            expectedFinalTrainState = FinalTrainStates.stoppedWhenFirstTargetRemoval
        else
            expectedFinalTrainState = FinalTrainStates.pulledToExitPortalEntry
        end
    else
        error("Unsupported testScenario.nextScheduleOrder: " .. testScenario.nextScheduleOrder)
    end

    return expectedFinalTrainState
end

return Test
