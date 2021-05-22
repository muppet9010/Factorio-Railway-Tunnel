--[[
    Multiple trains looping round waiting to go through the tunnel. They are going in opposite and the same directions.

    Train set to wait for empty will stop at a station for 1 tick before moving off.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "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"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationWest, stationEast
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
        end
    end

    -- Get the trains. The trains have 1 loco ach and then 1-4 carriages in variable order below.
    local trainHeadingEast1, trainHeadingEast2, trainHeadingWest1, trainHeadingWest2
    local locos = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive", true, false)
    for _, loco in pairs(locos) do
        if #loco.train.carriages == 2 then
            trainHeadingEast1 = loco.train
        elseif #loco.train.carriages == 3 then
            trainHeadingEast2 = loco.train
        elseif #loco.train.carriages == 4 then
            trainHeadingWest1 = loco.train
        elseif #loco.train.carriages == 5 then
            trainHeadingWest2 = loco.train
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationEast1Reached = false
    testData.stationEast2Reached = false
    testData.stationWest1Reached = false
    testData.stationWest2Reached = false
    testData.trainHeadingEast1Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingEast1)
    testData.trainHeadingEast2Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingEast2)
    testData.trainHeadingWest1Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingWest1)
    testData.trainHeadingWest2Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingWest2)
    testData.stationEast = stationEast
    testData.stationWest = stationWest

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationEastTrain, stationWestTrain = testData.stationEast.get_stopped_train(), testData.stationWest.get_stopped_train()

    -- Tracked trains should arrive to their expected station in order before any other train gets to reach its second station.
    if stationEastTrain ~= nil then
        if not testData.stationEast1Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainHeadingEast1Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached east station before first train: trainHeadingEast1")
                return
            end
            game.print("trainHeadingEast1 reached east station")
            testData.stationEast1Reached = true
        elseif not testData.stationEast2Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainHeadingEast2Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached east station before second train: trainHeadingEast2")
                return
            end
            game.print("trainHeadingEast2 reached east station")
            testData.stationEast2Reached = true
        end
    end
    if stationWestTrain ~= nil then
        if not testData.stationWest1Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainHeadingWest1Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached west station before first train: trainHeadingWest1")
                return
            end
            game.print("trainHeadingWest1 reached west station")
            testData.stationWest1Reached = true
        elseif not testData.stationWest2Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainHeadingWest2Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached west station before second train:  trainHeadingWest2")
                return
            end
            game.print("trainHeadingWest2 reached west station")
            testData.stationWest2Reached = true
        end
    end

    if testData.stationEast1Reached and testData.stationEast2Reached and testData.stationWest1Reached and testData.stationWest2Reached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
