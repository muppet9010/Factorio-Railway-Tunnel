-- A train that goes through 2 tunnels in a row, but reverses back and forwards due to different rail path changes at different times.
-- The train is longer than the gap between the 2 tunnel portal tracks so that it will straddle the 2 at one point.

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
    half = "half", -- 0.7 speed
    full = "full" -- 1.4 speed
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

--TODO
local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificReversePointFilter = {"onPortalTrackSecondPlus10"} -- Pass in an array of ReversePoint keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificResumeForwardsPointFilter = {"tick120"} -- Pass in an array of ResumeForwardsPoint keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTrainStartingSpeedFilter = {"full"} -- Pass in an array of TrainStartingSpeed keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

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

    local blueprint = "0eNq1W9tuo0gQ/ReenRXV1de8z37AvK5WkWMjD5INEeDMRpH/fcGXXHHmVEHykjjgUwWnzummu3jO7rf74qEpqy67fc7KVV212e0/z1lbbqrldvhf9/RQZLdZ2RW7bJFVy93wqVmW2+ywyMpqXfyX3dJhAX3l9/LprttXVbG9eaibbrm9a4vNrqi6m7brj29+dW9AzeHfRdYfK7uyOCV1/PB0V+1390XTR33BXu2bx2J9c8xqkT3Ubf+duhpS6XFuYr7InobfPfa6bIrV6aAfkv4AaV4gLwldAw3uBJreg5oRUMZBGQa1OCjBoA4G9QkG9ThogEEDDooTFXFQnKiEg+JEUQ6jOpwpIhwVp4pwUTmcK8JV5XCyCJeVE7CF68oK2MKFZQVs4cqyArZwaVkBW7i2LM6WwbXFOFsG1xbjbBlcW4yzZXBtMc6WwbXFArZwbRkBW7i2jIAtXFtGwBauLSNgC9eWwdliXFuEs8W4tghni3FtkWAyiGuLcLYY1xYJ2MK1JSALl5aAK1xZAqpwYQmYwnWFE2VhWQkwYVEJHlpgSeEsWVhQeDlZWE543VtYTAKFWlhMAjOxsJgEvmdhMQks2sJiEowmDhaTYOBzsJoEY7SD5SSYTjhYT4KZj4MFJZikOVhRgvmkgxUlmPq6gC1VDSPOyEoVj0Hig1M8J+reo4Yx1FdBDaDVTdvVD9cvPXy49EWfy/L0d/azeCyatvh5Win8vCoEq+zy6PYhfRoDhZcE/QnTAJiwyOz4fXZjoCwFZSBTWGSXJ3cGMnVSUAIyhUV2WbkgINMgBEUShVV2XrhB8kxCTID6kMsK37+HtGOQ8Ih1XgkDiikYISag+QBL6bwOCMgzWCFmAPKEhXReBQ1Anl6ImYA8g3RgSUCiUbZXQ+bPY1WAdXRerAbyjKCOPJ5mpD9sgRXV+vquDfGnIfZx2ZTL6/xFI91yu7oRowjOMwR3o8H9n4PbGYKzNribIThpg/vpwc/7RArOwwzB1QUXZwjutMGTStpOK+2UX4u3r9ZFs2nq/venKz5a2N2qqdu2rDbXd4fkZZdIk8/1nSRFBmauDLS6T/w9nGitIFlVTbK6BmbwPVbf/Bl8j9V3egbfM0kbfAbfM1rTTWmG4FrTpTyfITqro9MM0Ukd3ajUTUEdkHV2oo43fQ6nv7nTrUxrZJRPdzKnjj3dyII69nQfS2q+p9sYqYuNprsYqVVGqmdSvYuQ+Y5JktGO3EQ8z7TRqPVOdqYM1Kon9y2cqJ2AvKYmWV8D012P9Td/uu2x/k5P9z3WzlvJTPc9qzZdM33yZtWma6YvzFn1pNlMX5izavs3qmdSp6f51dq29are1V35WIw1LfnXCHVT9jBn1PyvYbV+VW/rZji3Gf7j+Pjje+uOka0x0ZHzQ6jNcNgk21uKd4k5Zx9zSykZigPO/fF4zv1nF4gDJ06OLPn8DLAcTshPJ/gYewwf+yM+RfbWuBD7Kxrei+iKXTvks6qH9yxcfhi9eLy/Kl2ZOo3C4tsCKQhg8W3s5ASweJdVYhz2Tfvil4UV09XCMp8Ki060e9//EfsSiiHFaCK9lJb1JljXP/cal0LM++oLMeXHyjmWVgjG2ZQzk7fDCSaw5TB3XQmaLBMJbineZRkF5Spos4yCchX0WUZBuQoaLaOkXHEriBLKcCsIEspwKwgSypL0nS4I1ubSPl4MlqSNvBisEXbyYqgsbOXFUK1wUxtDdcLdYgwV34CX3FdYYF5SA7C+vKRgYXl5AVt4D6YXsIU3YXoBW3gXZhCwhbdhBgFbeB+mxAvxRkyJceOdmJJRxsHakgyJeDemZPwGuzEvhuW+6Mb8u25+L5v1tW5MetOO+VWoS/ZfhfrRP8wNr263q1/Fer89v7v9Ol8ePg+T2342/eas01vnH0AGmONb5Ldv3lPvn/+Kpj3Fjb1XJhOcicayORz+B4uu2Ik="
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the train stops from the BP and the related rails taht we want to remove.
    ---@typelist LuaEntity, LuaEntity, LuaEntity, Position, Position
    local endStop, forwardsRail, reverseRail, forwardsRailPosition, reverseRailPosition
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
        end
    end

    -- Get the train detector entity of the entry entrance portal end of the 2nd tunnel (5th portal end from the left).
    local secondTunnelEntranceTrainDetector
    -- Portal ends a rebuild top-left to bottom-right, so we can just count them for this messy requirement.
    local fifthPortalEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][5] ---@type LuaEntity
    local trainDetectorsFound = fifthPortalEnd.surface.find_entities_filtered {area = {{fifthPortalEnd.position.x - 3, fifthPortalEnd.position.y - 3}, {fifthPortalEnd.position.x + 3, fifthPortalEnd.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1"}
    secondTunnelEntranceTrainDetector = trainDetectorsFound[1]

    -- Set the trains starting speed based on the test scenario.
    local train = placedEntitiesByGroup["locomotive"][1].train -- All the loco's we built are part of the same train.
    local targetSpeed
    if testScenario.trainStartingSpeed == TrainStartingSpeed.full then
        targetSpeed = 1.4
    elseif testScenario.trainStartingSpeed == TrainStartingSpeed.half then
        targetSpeed = 0.7
    else
        targetSpeed = 0
    end
    if targetSpeed > 0 then
        train.manual_mode = true
        train.speed = targetSpeed
        train.manual_mode = false
        if train.speed == 0 then
            train.speed = -targetSpeed
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
        secondTunnelEntranceTrainDetector = secondTunnelEntranceTrainDetector ---@type LuaEntity
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

    if testScenario.resumeForwardsPoint == ResumeForwardsPoint.none then
        -- Wait for the train to reach the End stop.
        if testDataBespoke.endStop.get_stopped_train() ~= nil then
            TestFunctions.TestCompleted(testName)
        end
        return
    else
        -- Doing a tick delay before resuming the forwards path.

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

        -- Resume has been done so wait for the train to reach the End station.
        if testDataBespoke.endStop.get_stopped_train() ~= nil then
            TestFunctions.TestCompleted(testName)
        end
        return
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
