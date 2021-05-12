--[[
    Train limit on the left station is set to 1.
    When both trains reach their respective right stations the upper train starts going towards the left station.
    When it reaches the signal before the tunnel portal the lower train is released to travel left as well, but should stay still with a message "Destination full".
    Only once the upper train has reached the left station and starts driving back to the right, the lower train
    should start moving as the left station is now free.
    Once the lower train returns to its left station the upper train starts again.

    Purpose of the test is to ensure that the reservation on the target station is held continuously without any gaps while the train is traveling through the tunnel, so that no other train can start moving towards the target station if it is full
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

    -- Get the trains - Tunnel train is most north in BP - Other train is most south in BP.
    local northMostLoco, northMostLocoYPos, southMostLoco, southMostLocoYPos = nil, 100000, nil, -100000
    for _, locoEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "locomotive")) do
        local locoEntity = builtEntities[locoEntityIndex]
        if locoEntity.position.y < northMostLocoYPos then
            northMostLoco = locoEntity
            northMostLocoYPos = locoEntity.position.y
        end
        if locoEntity.position.y > southMostLocoYPos then
            southMostLoco = locoEntity
            southMostLocoYPos = locoEntity.position.y
        end
    end
    local tunnelTrain, otherTrain = northMostLoco.train, southMostLoco.train

    local stationEnd, otherStationStart
    for _, stationEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        local stationEntity = builtEntities[stationEntityIndex]
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        elseif stationEntity.backer_name == "Bottom Start" then
            otherStationStart = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.otherTrain = otherTrain
    testData.tunnelTrainSnapshot = TestFunctions.GetSnapshotOfTrain(tunnelTrain)
    testData.stationEnd = stationEnd
    testData.otherStationStart = otherStationStart

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationEndTrain = testData.stationEnd.get_stopped_train(testData.stationEnd)

    if stationEndTrain ~= nil then
        if stationEndTrain.id == testData.otherTrain.id then
            TestFunctions.TestFailed(testName, "other train reached end station before tunnel train")
            return
        end
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEndTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.tunnelTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "tunnel train has differences after tunnel use")
            return
        end
        if testData.otherStationStart.trains_count ~= 1 then
            TestFunctions.TestFailed(testName, "other start station didn't have 1 train (other trian) waiting at it")
            return
        end
        if testData.otherTrain.state ~= defines.train_state.destination_full then
            TestFunctions.TestFailed(testName, "other train wasn't in desitination full state")
            return
        end
        game.print("train reached target station")
        TestFunctions.TestCompleted(testName)
    end
end

return Test
