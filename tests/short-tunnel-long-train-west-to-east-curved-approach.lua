local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 3600

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "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"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = -100}, testName)

    -- Get the stations placed by name.
    local trainStopWest, trainStopEast
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "West" then
            trainStopWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            trainStopEast = stationEntity
        end
    end

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.westStationReached = false
    testData.eastStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.trainStopWest = trainStopWest
    testData.trainStopEast = trainStopEast

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local westTrain, eastTrain = testData.trainStopWest.get_stopped_train(), testData.trainStopEast.get_stopped_train()
    if eastTrain ~= nil and not testData.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences")
            return
        end
        game.print("train reached east station")
        testData.eastStationReached = true
    end
    if westTrain ~= nil and not testData.westStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences")
            return
        end
        game.print("train reached west station")
        testData.westStationReached = true
    end
    if testData.westStationReached and testData.eastStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
