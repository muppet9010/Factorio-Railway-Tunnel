-- Sends a single loco from the east to the west and loops back again through the tunnel the opposite way.

local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

---@param testName string
Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 60}, testName)

    -- Get the stations placed by name.
    local trainStopWest, trainStopEast
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "West" then
            trainStopWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            trainStopEast = stationEntity
        end
    end

    local train = placedEntitiesByGroup["locomotive"][1].train

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_STSLETW_TestScenarioBespokeData
    local testDataBespoke = {
        westStationReached = false, ---@type boolean
        eastStationReached = false, ---@type boolean
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train),
        trainStopWest = trainStopWest, ---@type LuaEntity
        trainStopEast = trainStopEast ---@type LuaEntity
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
    local testDataBespoke = testData.bespoke ---@type Tests_STSLETW_TestScenarioBespokeData

    local westTrain, eastTrain = testDataBespoke.trainStopWest.get_stopped_train(), testDataBespoke.trainStopEast.get_stopped_train()

    if westTrain ~= nil and not testDataBespoke.westStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences")
            return
        end
        game.print("train reached west station")
        testDataBespoke.westStationReached = true
    end
    if eastTrain ~= nil and not testDataBespoke.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences")
            return
        end
        game.print("train reached east station")
        testDataBespoke.eastStationReached = true
    end
    if testDataBespoke.westStationReached and testDataBespoke.eastStationReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
