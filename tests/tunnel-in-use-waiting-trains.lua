--[[
    Multiple trains looping round waiting to go through the tunnel. They are going in opposite and the same directions.

    Train set to wait for green signal at train stop. As this green signal is fed by circuit logic on a train arriving this leads to a 1 tick wai before moving off.
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
