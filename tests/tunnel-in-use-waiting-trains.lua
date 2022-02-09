--[[
    Multiple trains looping round waiting to go through the tunnel. They are going in opposite and the same directions. They will have a staggered start.

    Train set to wait for green signal at train stop. As this green signal is fed by circuit logic on a train arriving this leads to a 1 tick wai before moving off.
]]
local Test = {}
local TestFunctions = require("scripts.test-functions")

Test.RunTime = 3600

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

---@param testName string
Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationWest, stationEast
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
        end
    end

    -- Get the trains. The trains have 1 loco ach and then 1-4 carriages in variable order below.
    local trainHeadingEast1, trainHeadingEast2, trainHeadingWest1, trainHeadingWest2
    for _, loco in pairs(placedEntitiesByGroup["locomotive"]) do
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
    ---@class Tests_TIUWT_TestScenarioBespokeData
    local testDataBespoke = {
        stationEast1Reached = false, ---@type boolean
        stationEast2Reached = false, ---@type boolean
        stationWest1Reached = false, ---@type boolean
        stationWest2Reached = false, ---@type boolean
        trainHeadingEast1Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingEast1, 0.25),
        trainHeadingEast2Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingEast2, 0.25),
        trainHeadingWest1Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingWest1, 0.75),
        trainHeadingWest2Snapshot = TestFunctions.GetSnapshotOfTrain(trainHeadingWest2, 0.75),
        stationEast = stationEast, ---@type LuaEntity
        stationWest = stationWest ---@type LuaEntity
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
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke ---@type Tests_TIUWT_TestScenarioBespokeData

    local stationEastTrain, stationWestTrain = testDataBespoke.stationEast.get_stopped_train(), testDataBespoke.stationWest.get_stopped_train()

    -- Tracked trains should arrive to their expected station in order before any other train gets to reach its second station.
    if stationEastTrain ~= nil then
        if not testDataBespoke.stationEast1Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain, 0.75)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.trainHeadingEast1Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached east station before first train: trainHeadingEast1")
                return
            end
            game.print("trainHeadingEast1 reached east station")
            testDataBespoke.stationEast1Reached = true
        elseif not testDataBespoke.stationEast2Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain, 0.75)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.trainHeadingEast2Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached east station before second train: trainHeadingEast2")
                return
            end
            game.print("trainHeadingEast2 reached east station")
            testDataBespoke.stationEast2Reached = true
        end
    end
    if stationWestTrain ~= nil then
        if not testDataBespoke.stationWest1Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain, 0.25)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.trainHeadingWest1Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached west station before first train: trainHeadingWest1")
                return
            end
            game.print("trainHeadingWest1 reached west station")
            testDataBespoke.stationWest1Reached = true
        elseif not testDataBespoke.stationWest2Reached then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain, 0.25)
            if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.trainHeadingWest2Snapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "unexpected train reached west station before second train:  trainHeadingWest2")
                return
            end
            game.print("trainHeadingWest2 reached west station")
            testDataBespoke.stationWest2Reached = true
        end
    end

    if testDataBespoke.stationEast1Reached and testDataBespoke.stationEast2Reached and testDataBespoke.stationWest1Reached and testDataBespoke.stationWest2Reached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
