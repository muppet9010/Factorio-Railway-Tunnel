--[[
    A series of tests that removes the target train stop and rail while the tunnel is in use. The train will have an alternative station target either in front of it, behind it, or none. As we remove the rail in all different tunnel states this tests the full range of reactions by the managed train. Covers:
        - TargetTypes = rail, trainStop
        - TunnelUsageStates = startApproaching, onPortalTrack, entered, leaving, partlyLeftExitPortalTracks.
        - NextScheduleOrder = none, forwards, reversal.
]]
local Test = {}
local TestFunctions = require("scripts.test-functions")
local Utils = require("utility.utils")
local Common = require("scripts.common")

---@class Tests_RTSR_TargetTypes
local TargetTypes = {
    rail = "rail",
    trainStop = "trainStop"
}
---@class Tests_RTSR_TunnelUsageStates
local TunnelUsageStates = {
    startApproaching = Common.TunnelUsageAction.startApproaching,
    onPortalTrack = "onPortalTrack", -- Have to detect manually in the test from the entrance portal's entry train detector's death.
    entered = "entered", -- When the entering train is removed the train is traversing (physcially sitting idle in the exit portal).
    leaving = Common.TunnelUsageAction.leaving, -- When the train starts actively leaving the exit portal.
    partlyLeftExitPortalTracks = "partlyLeftExitPortalTracks" -- Have to detect manually in the test from the exit portal's entry train detector's death.
}
---@class Tests_RTSR_NextScheduleOrders
local NextScheduleOrders = {
    none = "none",
    fowards = "forwards",
    reversal = "reversal"
}
---@class Tests_RTSR_FinalTrainStates
local FinalTrainStates = {
    stoppedWhenFirstTargetRemoval = "stoppedWhenFirstTargetRemoval",
    pulledToExitPortalEntry = "pulledToExitPortalEntry",
    secondTargetReached = "secondTargetReached"
}

local DoMinimalTests = true -- The minimal test to prove the concept with a few varieties.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTargetTypesFilter = {} -- Pass in array of TargetTypes keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificTunnelUsageStatesFilter = {} -- Pass in array of TunnelUsageStates keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.
local SpecificNextScheduleOrdersFilter = {} -- Pass in array of TRUE/FALSE (boolean) to do just those specific Next Schedule Order tests. Leave as nil or empty table for both combinations. Only used when DoSpecificTrainTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_RTSR_TestScenario[]
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        targetType = the TargetTypes of this test.
        tunnelUsageState = the TunnelUsageStates of this test.
        nextScheduleOrder = the NextScheduleOrders of this test.
        expectedFinalTrainState = the FinalTrainStates calculated for this test.
    }
]]
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

local blueprintString = "0eNqtW9tu2koU/Rc/Q+U9Vw8f0A/oeTw6ihyYUqvGRrYhJ4r4945L2qCE0rU38xICNmvhWRePR/ZL8dge4n5ouqlYvRTNuu/GYvXvSzE2265u58+m530sVkUzxV2xKB7r9ffDPr0f6qZ9qp8fpkPXxXZ5fnnY98NUtw/jYfhar+Ny36a/u5jAT4ui6Tbx/2JFp/8WRfqomZp45vr55vmhO+we45B2WBRdvZs5p0TSLcep3yfmfT+mr/Td/JsSzJK0XhTP8z+UwDfNENfnzW5RjFN9/r/4Enf9MSb6DzQKpFEWoPknppHbfO6Hp3rYjNfo9G+6dyP3OmSx21xhr8KZPHzgPtZD88pOV+jMX+jGuJ11SUedtm+/Tde4rZDbZuDWQm6XgZuE3P5+bi/Vu8rA7YXcIQO31GtUZiCXmo0oA7nUbaTuJ3dSu5HOQC71G2UoNyc2XIZ2c2LDZag3JzZchn6zYsNlKDgrNlyGhrNSw6kMDWelhlMZGs5KDacyNJyRGk5laDgjNZzK0HBGbDgrmqoascx/LLVDumIYtkOfXpEj1uLh9qIj1uJUZSgzJTZ2hjJT0pHWGcpMSY2tM5SZkmquM5SZkkZMZygzkhpOZygzEhsuw3SNxIbLMF0jseEyTNdIbLgMDSf2W47rUemyS47JmpQ7Q71JzWYytJvUa+b+chNT319t4hG/v9jERru/1sT5ur/UxCuq91eauE5NkExQxect+9Zivw5mOfPeWoV/R6KuwRIDlnBYhcP+YdZ8FVYzYD0OaxiwFoe1DFiGZI4By5DM47DEkKxiwDIkCwxYXDLHSBnhkjlGygiXzDFSVuKSOUbKSlwyx0hZyZCMkbKSIRkjZSVDMjxlgaEYHrLAEAzPWMD18njEAi6XhxPG6C4P54vRsx5OF+Oc4OFsMc5fHk4W41zr4Vwx5gUeThVjDuPhUDHmWx7OlMaFquBIaVyoCk6UxoWq4EQZXKgKTpTBhargRBmGUHCiDEMoOFGGIRScKMsQCk6UZQgFJ8riQgU4URYXKsCJsrhQAU6Uw4UKcKIcLlSAE+UYQsGJcgyh4EQ5hlBviWr7db/rp+YYr6zC6E9BX9560w9NQnpdGSg/zZvm+/7Gef+hX3+P0/LrIbbzbTena7Rw5jzDH3DmPO4PKuHQectAhVPnPQP1LXbretj2y6d6m3b+gFmVt+Wcp2NNd0wf9UPapTu07VU6OJA+MA4CTmRFDFQ4khXHHA4ccJ9nwOHzX8XxIhzGiuNFOI0VwxwEpzEwzHFxe95NGYPJIiPBZ0fGtSYRnEbGdTERnEbGNTxd3Bt3c8BTT+YZcfjcGThmhOPIWYwhqnBYjj8CDsswyMVdZ7dmEKllACUZUwhS+OIKYz2QlMJhGV5RcDo5a62kDA7L8IqyOCzHKw6H5UjmoSc0fv9U/w7z4/MZX+IxDmMs5idQfj7Psrp4/GVRzBvPX63I+KC8CdZ4q0+nH1VIKUU="

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.targetType .. "     " .. testScenario.tunnelUsageState .. "     " .. tostring(testScenario.nextScheduleOrder) .. "     Expected result: " .. testScenario.expectedFinalTrainState
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    local surface = TestFunctions.GetTestSurface()

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

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

    -- Get the outside ends of both portals.
    local entrancePortalPart, entrancePortalXPos, exitPortalPart, exitPortalXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x > entrancePortalXPos then
            entrancePortalPart = portalEntity
            entrancePortalXPos = portalEntity.position.x
        end
        if portalEntity.position.x < exitPortalXPos then
            exitPortalPart = portalEntity
            exitPortalXPos = portalEntity.position.x
        end
    end

    -- Get the entrance portal's entry train detector.
    local entrancePortalTrainDetector = surface.find_entities_filtered {area = {top_left = {x = entrancePortalPart.position.x - 3, y = entrancePortalPart.position.y - 3}, right_bottom = {x = entrancePortalPart.position.x + 3, y = entrancePortalPart.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1", limit = 1}[1]

    -- Get the exit portal's entry train detector.
    local exitPortalTrainDetector = surface.find_entities_filtered {area = {top_left = {x = exitPortalPart.position.x - 3, y = exitPortalPart.position.y - 3}, right_bottom = {x = exitPortalPart.position.x + 3, y = exitPortalPart.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1", limit = 1}[1]

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
    train.speed = 0.75 -- Set so that it triggers approaching before it gets on to the portal tracks.

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_RTSR_TestScenarioBespokeData
    local testDataBespoke = {
        stationRemove = stationRemove, ---@type LuaEntity
        stationSecondForwards = stationSecondForwards, ---@type LuaEntity
        stationSecondReverse = stationSecondReverse, ---@type LuaEntity
        entrancePortalPart = entrancePortalPart, ---@type LuaEntity
        entrancePortalTrainDetector = entrancePortalTrainDetector, ---@type LuaEntity
        exitPortalPart = exitPortalPart, ---@type LuaEntity
        exitPortalTrainDetector = exitPortalTrainDetector, ---@type LuaEntity
        train = train, ---@type LuaTrain
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train, 0.75),
        firstTargetRemoved = false ---@type boolean
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
    local testScenario = testData.testScenario ---@type Tests_RTSR_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_RTSR_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    if not testDataBespoke.firstTargetRemoved then
        local removeFirstTarget = false
        if (testScenario.tunnelUsageState == TunnelUsageStates.startApproaching or testScenario.tunnelUsageState == TunnelUsageStates.entered or testScenario.tunnelUsageState == TunnelUsageStates.leaving) and testScenario.tunnelUsageState == tunnelUsageChanges.lastAction then
            removeFirstTarget = true
        elseif testScenario.tunnelUsageState == TunnelUsageStates.onPortalTrack and not testDataBespoke.entrancePortalTrainDetector.valid then
            removeFirstTarget = true
        elseif testScenario.tunnelUsageState == TunnelUsageStates.partlyLeftExitPortalTracks and not testDataBespoke.exitPortalTrainDetector.valid then
            removeFirstTarget = true
        end
        if removeFirstTarget then
            -- Is the state we are wanting to act upon.
            if testScenario.targetType == TargetTypes.trainStop then
                testDataBespoke.stationRemove.destroy {raise_destroy = false}
                game.print("Removed target schedule station.")
            elseif testScenario.targetType == TargetTypes.rail then
                testDataBespoke.stationRemove.connected_rail.destroy {raise_destroy = false}
                game.print("Removed target schedule rail.")
            else
                error("Unsupported testScenario.targetType: " .. testScenario.targetType)
            end
            testDataBespoke.firstTargetRemoved = true
        end
    end

    if not testDataBespoke.firstTargetRemoved then
        -- Wait for the tunnel usage state to trigger the removal.
        return
    end

    if testScenario.expectedFinalTrainState == FinalTrainStates.stoppedWhenFirstTargetRemoval then
        local train = testDataBespoke.train -- Check for train pre entering.
        if train == nil or not train.valid then
            -- Try to get the leaving train. No other states should have this outcome.
            train = tunnelUsageChanges.train
        end
        if train ~= nil and train.valid then
            if train.state == defines.train_state.no_path then
                local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train, 0.75)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot, false) then
                    TestFunctions.TestFailed(testName, "train stopped doesn't match origional")
                    return
                end
                TestFunctions.TestCompleted(testName)
                return
            end
        end
    elseif testScenario.expectedFinalTrainState == FinalTrainStates.pulledToExitPortalEntry then
        -- Train should be sent to the end of the exit portal as no path anywhere else.
        local trainAtExitPortal = TestFunctions.GetTrainInArea(Utils.CalculateBoundingBoxFromPositionAndRange(testDataBespoke.exitPortalPart.position, 3))
        if trainAtExitPortal ~= nil then
            -- Train will end up with either Wait Station (reached valid schedule record) or No Schedule (has no valid schedule record in its list) once it reaches end of portal track.
            if trainAtExitPortal.state == defines.train_state.wait_station or trainAtExitPortal.state == defines.train_state.no_schedule then
                local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(trainAtExitPortal, 0.75)
                if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot, false) then
                    TestFunctions.TestFailed(testName, "part of train at end of portal doesn't match origional")
                    return
                end
                TestFunctions.TestCompleted(testName)
                return
            end
        end
    elseif testScenario.expectedFinalTrainState == FinalTrainStates.secondTargetReached then
        -- Try both second stations, only one will end up with a train.
        local stationSecondTrain = testDataBespoke.stationSecondForwards.get_stopped_train()
        local stoppedTrainFacing = 0.75
        if stationSecondTrain == nil then
            stationSecondTrain = testDataBespoke.stationSecondReverse.get_stopped_train()
            stoppedTrainFacing = 0.75 -- Seems counter intuative, but gives the correct answer and the tunnel ahsn't been used so must be right.
        end
        if stationSecondTrain ~= nil then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationSecondTrain, stoppedTrainFacing)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot, false) then
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

---@param testName string
Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local targetTypesToTest  ---@type Tests_RTSR_TargetTypes
    local tunnelUsageStatesToTest  ---@type Tests_RTSR_TunnelUsageStates
    local nextScheduleOrdersToTest  ---@type Tests_RTSR_NextScheduleOrders
    if DoSpecificTests then
        -- Adhock testing option.
        targetTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TargetTypes, SpecificTargetTypesFilter)
        tunnelUsageStatesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelUsageStates, SpecificTunnelUsageStatesFilter)
        nextScheduleOrdersToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NextScheduleOrders, SpecificNextScheduleOrdersFilter)
    elseif DoMinimalTests then
        targetTypesToTest = {TargetTypes.trainStop}
        tunnelUsageStatesToTest = {TunnelUsageStates.onPortalTrack, TunnelUsageStates.entered, TunnelUsageStates.leaving}
        nextScheduleOrdersToTest = {NextScheduleOrders.reversal, NextScheduleOrders.none}
    else
        -- Do whole test suite.
        targetTypesToTest = TargetTypes
        tunnelUsageStatesToTest = TunnelUsageStates
        nextScheduleOrdersToTest = NextScheduleOrders
    end

    for _, targetType in pairs(targetTypesToTest) do
        for _, tunnelUsageState in pairs(tunnelUsageStatesToTest) do
            for _, nextScheduleOrder in pairs(nextScheduleOrdersToTest) do
                ---@class Tests_RTSR_TestScenario
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
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

---@param testScenario table
Test.CalculateExpectedResults = function(testScenario)
    local expectedFinalTrainState

    if testScenario.nextScheduleOrder == NextScheduleOrders.fowards or testScenario.nextScheduleOrder == NextScheduleOrders.reversal then
        expectedFinalTrainState = FinalTrainStates.secondTargetReached
    elseif testScenario.nextScheduleOrder == NextScheduleOrders.none then
        if testScenario.tunnelUsageState == TunnelUsageStates.entered then
            expectedFinalTrainState = FinalTrainStates.pulledToExitPortalEntry
        else
            expectedFinalTrainState = FinalTrainStates.stoppedWhenFirstTargetRemoval
        end
    else
        error("Unsupported testScenario.nextScheduleOrder: " .. testScenario.nextScheduleOrder)
    end

    return expectedFinalTrainState
end

return Test
