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

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

Test.Start = function(testName)
    local _, placedEntitiesByType = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 24, y = 0}, testName)

    -- Get the trains - Tunnel train is most north in BP - Other train is most south in BP.
    local northMostLoco, northMostLocoYPos, southMostLoco, southMostLocoYPos = nil, 100000, nil, -100000
    for _, locoEntity in pairs(placedEntitiesByType["locomotive"]) do
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
    for _, stationEntity in pairs(placedEntitiesByType["train-stop"]) do
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
            TestFunctions.TestFailed(testName, "other start station didn't have 1 train scheduled (other trian waiting) to it")
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
