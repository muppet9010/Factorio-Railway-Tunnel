--[[
    When the train going from right (Station "Reset") to left (Station "Target") reaches the circuit connected set of signals, an RS latch triggers and the train limit on the target station is set to zero. Train should continue through the tunnel and to the target station as the existing slot reservation that it has is transferred across.
    When the train returns to the reset station, the RS latch resets and the train limit on target station is set to 1 again. Ready for another test loop.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

Test.Start = function(testName)
    local _, placedEntitiesByType = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 30, y = 0}, testName)

    local train = placedEntitiesByType["locomotive"][1].train

    local stationTarget
    for _, stationEntity in pairs(placedEntitiesByType["train-stop"]) do
        if stationEntity.backer_name == "Target" then
            stationTarget = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.train = train
    testData.trainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.stationTarget = stationTarget

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationTargetTrain = testData.stationTarget.get_stopped_train()

    if stationTargetTrain ~= nil then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationTargetTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train has differences after tunnel use")
            return
        end
        game.print("train reached target station")
        TestFunctions.TestCompleted(testName)
    end
end

return Test
