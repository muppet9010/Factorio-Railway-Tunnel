-- A train that goes through 2 tunnels in a row, but reverses back and forwards due to different rail path changes at different times.
-- The train is longer than the gap between the 2 tunnel portal tracks so that it will straddle the 2 at one point.
-- There's a second train that will do a straight tunnel usage once the first trian has completed it manouvers. This is to confirm the tunnels are left in a stable state.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

---@class Tests_STRT_ReversePoint
local ReversePoint = {
    approachingSecond = "approachingSecond", -- Once the train starts approaching the second tunnel.
    approachingSecondPlus10 = "approachingSecondPlus10", -- Once the train starts approaching the second tunnel and 10 ticks later.
    onPortalTrackSecond = "onPortalTrackSecond", -- Once the train is on the second tunnel's entrance portal tracks.
    onPortalTrackSecondPlus10 = "onPortalTrackSecondPlus10", -- Once the train is on the second tunnel's entrance portal tracks and 10 ticks later.
    leftFirst = "leftFirst", -- Once the train has left the first tunnel's exit portal's tracks entirely.
    leftFirstPlus10 = "leftFirstPlus10" -- Once the train has left the first tunnel's exit portal's tracks entirely and 10 ticks later.
}

---@class Tests_STRT_ResumeForwardsPoint
local ResumeForwardsPoint = {
    none = "none", -- Never resumes its forwards journey and continues on its reverse path.
    tick1 = "tick1", -- 1 tick after the reverse.
    tick30 = "tick30", -- 30 ticks after the reverse. This is just to let the train start moving backwards properly before we flip its direction again. This is when the train has moved a little bit since the reverse triggered.
    tick120 = "tick120" -- 120 ticks after the reverse. This is just to let the train start moving backwards properly before we flip its direction again. This is when the train has moved multiple rail tiles since the reverse triggered and will have changed state in most cases.
}

---@class Tests_STRT_TrainStartingSpeed
local TrainStartingSpeed = {
    none = "none", -- 0 speed
    half = "half", -- 0.6 half max speed.
    full = "full" -- 1.2 speed is the max of this train type and fuel type in the BP.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificReversePointFilter = {} -- Pass in an array of ReversePoint keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificResumeForwardsPointFilter = {} -- Pass in an array of ResumeForwardsPoint keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTrainStartingSpeedFilter = {} -- Pass in an array of TrainStartingSpeed keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0
---@type Tests_STRT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName) -- Have tunnel usage changes being added to the test's TestData object.
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.reversePoint .. "    -    ResumeForwardsPoint: " .. testScenario.resumeForwardsPoint .. "    -    Speed: " .. testScenario.trainStartingSpeed
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "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"
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the train stops from the BP and the related rails taht we want to remove.
    ---@typelist LuaEntity, LuaEntity, LuaEntity, Position, LuaEntity
    local endStop, forwardsRail, reverseRail, forwardsRailPosition, secondTrainEndStop
    for _, trainStop in pairs(placedEntitiesByGroup["train-stop"]) do
        if trainStop.backer_name == "End" then
            endStop = trainStop
        elseif trainStop.backer_name == "ForwardRail" then
            forwardsRail = trainStop.connected_rail
            forwardsRailPosition = forwardsRail.position
            trainStop.destroy()
        elseif trainStop.backer_name == "ReverseRail" then
            reverseRail = trainStop.connected_rail
            trainStop.destroy()
        elseif trainStop.backer_name == "SecondTrain_End" then
            secondTrainEndStop = trainStop
        end
    end

    -- Get the train detector entity of the entry entrance portal end of the 2nd tunnel (5th portal end from the left).
    local secondTunnelEntranceTrainDetector
    -- Portal ends a rebuild top-left to bottom-right, so we can just count them for this messy requirement.
    local fifthPortalEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][5] ---@type LuaEntity
    local trainDetectorsFound = fifthPortalEnd.surface.find_entities_filtered {area = {{fifthPortalEnd.position.x - 3, fifthPortalEnd.position.y - 3}, {fifthPortalEnd.position.x + 3, fifthPortalEnd.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1"}
    secondTunnelEntranceTrainDetector = trainDetectorsFound[1]

    -- Set the first trains starting speed based on the test scenario. Will be the east most locomotive.
    ---@typelist LuaEntity, double
    local eastLoco, eastLocoXPos = nil, -999999
    for _, loco in pairs(placedEntitiesByGroup["locomotive"]) do
        if loco.position.x > eastLocoXPos then
            eastLoco = loco
            eastLocoXPos = loco.position.x
        end
    end
    local firstTrain = eastLoco.train
    local targetSpeed
    if testScenario.trainStartingSpeed == TrainStartingSpeed.full then
        targetSpeed = 1.2
    elseif testScenario.trainStartingSpeed == TrainStartingSpeed.half then
        targetSpeed = 0.6
    else
        targetSpeed = 0
    end
    if targetSpeed > 0 then
        firstTrain.manual_mode = true
        firstTrain.speed = targetSpeed
        firstTrain.manual_mode = false
        if firstTrain.speed == 0 then
            firstTrain.speed = -targetSpeed
        end
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_STRT_TestScenarioBespokeData
    local testDataBespoke = {
        endStop = endStop, ---@type LuaEntity
        forwardsRail = forwardsRail, ---@type LuaEntity
        reverseRail = reverseRail, ---@type LuaEntity
        forwardsRailPosition = forwardsRailPosition, ---@type Position
        reversedTrain = false, ---@type boolean
        reversedStateReachedTick = nil, ---@type Tick
        reversedTick = nil, ---@type Tick
        resumedTrain = false, ---@type boolean
        secondTunnelEntranceTrainDetector = secondTunnelEntranceTrainDetector, ---@type LuaEntity
        secondTrainEndStop = secondTrainEndStop, ---@type LuaEntity
        firstTrainInitialSnapshot = TestFunctions.GetSnapshotOfTrain(firstTrain, 0.25)
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
    local testScenario = testData.testScenario ---@type Tests_STRT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_STRT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Check and wait to remove the forwards path if not done yet.
    if not testDataBespoke.reversedTrain then
        local doReversalNow = false
        if testScenario.reversePoint == ReversePoint.approachingSecond then
            if tunnelUsageChanges.actions[Common.TunnelUsageAction.startApproaching] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.startApproaching].count == 2 then
                doReversalNow = true
            end
        elseif testScenario.reversePoint == ReversePoint.approachingSecondPlus10 then
            if testDataBespoke.reversedStateReachedTick == nil then
                if tunnelUsageChanges.actions[Common.TunnelUsageAction.startApproaching] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.startApproaching].count == 2 then
                    testDataBespoke.reversedStateReachedTick = event.tick
                end
            else
                if event.tick == testDataBespoke.reversedStateReachedTick + 10 then
                    doReversalNow = true
                end
            end
        elseif testScenario.reversePoint == ReversePoint.onPortalTrackSecond then
            if not testDataBespoke.secondTunnelEntranceTrainDetector.valid then
                doReversalNow = true
            end
        elseif testScenario.reversePoint == ReversePoint.onPortalTrackSecondPlus10 then
            if testDataBespoke.reversedStateReachedTick == nil then
                if not testDataBespoke.secondTunnelEntranceTrainDetector.valid then
                    testDataBespoke.reversedStateReachedTick = event.tick
                end
            else
                if event.tick == testDataBespoke.reversedStateReachedTick + 10 then
                    doReversalNow = true
                end
            end
        elseif testScenario.reversePoint == ReversePoint.leftFirst then
            if tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving].count == 1 and tunnelUsageChanges.actions[Common.TunnelUsageAction.terminated] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.terminated].count == 1 then
                -- Train has completed leaving the first tunnel (hopefully).
                doReversalNow = true
            end
        elseif testScenario.reversePoint == ReversePoint.leftFirstPlus10 then
            if testDataBespoke.reversedStateReachedTick == nil then
                if tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving].count == 1 and tunnelUsageChanges.actions[Common.TunnelUsageAction.terminated] ~= nil and tunnelUsageChanges.actions[Common.TunnelUsageAction.terminated].count == 1 then
                    testDataBespoke.reversedStateReachedTick = event.tick
                end
            else
                if event.tick == testDataBespoke.reversedStateReachedTick + 10 then
                    doReversalNow = true
                end
            end
        end

        if doReversalNow then
            testDataBespoke.reversedTrain = true
            testDataBespoke.forwardsRail.destroy()
            testDataBespoke.reversedTick = event.tick
        end

        return
    end

    -- If there's a tick delay before resuming the forwards path then wait for this point.
    if testScenario.resumeForwardsPoint ~= ResumeForwardsPoint.none then
        -- Waiting for a tick to occur to resume the forwards path.
        if not testDataBespoke.resumedTrain then
            local resumeForwardsPathNow = false
            if testScenario.resumeForwardsPoint == ResumeForwardsPoint.tick1 then
                if testDataBespoke.reversedTick + 1 == event.tick then
                    resumeForwardsPathNow = true
                end
            elseif testScenario.resumeForwardsPoint == ResumeForwardsPoint.tick30 then
                if testDataBespoke.reversedTick + 30 == event.tick then
                    resumeForwardsPathNow = true
                end
            elseif testScenario.resumeForwardsPoint == ResumeForwardsPoint.tick120 then
                if testDataBespoke.reversedTick + 120 == event.tick then
                    resumeForwardsPathNow = true
                end
            end

            if resumeForwardsPathNow then
                testDataBespoke.resumedTrain = true
                testDataBespoke.reverseRail.destroy()
                TestFunctions.GetTestSurface().create_entity {name = "straight-rail", position = testDataBespoke.forwardsRailPosition, direction = defines.direction.east, force = TestFunctions.GetTestForce(), raise_built = false, create_build_effect_smoke = false}
            end

            return
        end
    end

    -- Everything has been done so wait for the 2 trains to reach their end stations.
    if testDataBespoke.endStop.get_stopped_train() ~= nil then
        -- If the forwards railw wasn't returned during the test then return it for the second train now.
        if not testDataBespoke.resumedTrain then
            testDataBespoke.resumedTrain = true
            TestFunctions.GetTestSurface().create_entity {name = "straight-rail", position = testDataBespoke.forwardsRailPosition, direction = defines.direction.east, force = TestFunctions.GetTestForce(), raise_built = false, create_build_effect_smoke = false}
        end

        if testDataBespoke.secondTrainEndStop.get_stopped_train() ~= nil then
            -- Check the first trains snapshot. The end station is backwards to the starting position, so the default for a forwards path to the station is 0.75 orientation. But some pathing changes may ahve reversed the train.
            local firstTrainsFinalSnapshot
            if testScenario.resumeForwardsPoint == ResumeForwardsPoint.none then
                -- Train will have reversed out of the tunnels and so is backwards.
                firstTrainsFinalSnapshot = TestFunctions.GetSnapshotOfTrain(testDataBespoke.endStop.get_stopped_train(), 0.25)
            else
                -- Train will have continued forwards through the tunnels evenually to the end stop.
                firstTrainsFinalSnapshot = TestFunctions.GetSnapshotOfTrain(testDataBespoke.endStop.get_stopped_train(), 0.75)
            end
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.firstTrainInitialSnapshot, firstTrainsFinalSnapshot, false) then
                TestFunctions.TestFailed(testName, "first train's snapshots didn't match upon arrival.")
                return
            end

            TestFunctions.TestCompleted(testName)
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
    local reversePointToTest  ---@type Tests_STRT_ReversePoint[]
    local resumeForwardsPointToTest  ---@type Tests_STRT_ResumeForwardsPoint[]
    local trainStartingSpeedToTest  ---@type Tests_STRT_TrainStartingSpeed[]
    if DoSpecificTests then
        -- Adhock testing option.
        reversePointToTest = TestFunctions.ApplySpecificFilterToListByKeyName(ReversePoint, SpecificReversePointFilter)
        resumeForwardsPointToTest = TestFunctions.ApplySpecificFilterToListByKeyName(ResumeForwardsPoint, SpecificResumeForwardsPointFilter)
        trainStartingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStartingSpeed, SpecificTrainStartingSpeedFilter)
    elseif DoMinimalTests then
        reversePointToTest = {ReversePoint.onPortalTrackSecond}
        resumeForwardsPointToTest = {ResumeForwardsPoint.tick1}
        trainStartingSpeedToTest = {TrainStartingSpeed.none}
    else
        -- Do whole test suite.
        reversePointToTest = ReversePoint
        resumeForwardsPointToTest = ResumeForwardsPoint
        trainStartingSpeedToTest = TrainStartingSpeed
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, reversePoint in pairs(reversePointToTest) do
        for _, resumeForwardsPoint in pairs(resumeForwardsPointToTest) do
            for _, trainStartingSpeed in pairs(trainStartingSpeedToTest) do
                ---@class Tests_STRT_TestScenario
                local scenario = {
                    reversePoint = reversePoint,
                    resumeForwardsPoint = resumeForwardsPoint,
                    trainStartingSpeed = trainStartingSpeed
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
