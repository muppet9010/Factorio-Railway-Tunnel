--[[
    A long train that has a number of stations imediately after the tunnel. Causes the train to stop at each station for a second while still in the tunnel.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString = "0eNqtWlty4jAQvIu+IWXJenKAvcDu31aKckAhqjU2ZZtkUynuvlJg82KoqBP9EAyiW5nukcYaP7Gbdu93Q+gmtnhiYdV3I1v8fmJj2HRNmz6bHneeLViY/JbNWNds09XQhPaheVxO+67z7fz4Z7nrh6lpl+N+uG1Wfr5r4+vWR+jDjIVu7f+yBT9cz1j8KEzBH5meLx6X3X5744c44IVjnCLL5m6aJ7JIvevH+Ku+S5OKSG7GHtlizoU7HGZnMOIFJqF083Hqd+cYnL+CzCJhc/yO/boLw5oRsDU8O0PNTsIwioJRMExNweh3ss5P0p8Hq7pS/3HElYoBW4fBr44jJIFr4OlxanoWheGkIxwMQ0rHK8xZEeWts376mGKktTjsfE6aggsYh3QFh73OSfm4hO2V3n5uLw7bvyKNwTWMQzsD9ntFC2gxh1XqncN+hGGcSIPBGVCRxhAVjEMaQ6CGd/RKL76wK60vkpg6RvO+GcIpnpyirD+hHP0m7Xu5nNJkcMrCnCqDUxXmzImtLszJMzhNWc7aZXDawpw5HnKFOTM8VFeFOTM8VPPCnBkeqkVZTpHhobrwOiQyPFQXXodEjocKr0Mix0OF1yGR46HC6xDP8VDhdYjneKjwOsQzPCSrkmUC5x/q08/5wWqnpm8cweK+JksmCZb2kqzfJHgXK8lqUr7m9qoZNv38odnEH17CMFfcmiR3P4SIdAp4lc4X7uN1P8RB3b5tKSawzpdkdS7BKl/SOoI3tZLW0SGxU/LrsVNgza9IxygwBxTpGAXmgKLPTsAcUKSOSiIKaP4NBcC7XUU6RoE5oGkdwRzQtI4Wip39RuzAO19NOkaDOaBJx2gwBzSpowZzwJA66tccaPtVv+2ncO8vQihagHRqkw6HxzR66Fd//DS/3fs2neiQpOC2YegzSzAdDC0pmA6GltQgRrbi60bW4LZhaPOA6WBJ8xgwHSypowHTwZI6GgEp4L6ugAG3DUs6xoA5YEkdDZgDjtZRA4uA0xdDBywBBtw/HG0dMBkcbR0wGRwpqAWTgT7KtGAyXDhYtQKFIeNraxSGDLCVKAwdYYXC0CEGV/wLTQ1rUBg6xBaFoUPsUBgyxK5CYehGG+piuu3nUBfTzU2HuphutTrUxXTj16ms3o45YbizU4Y3ncR+P91RfR6HWjx10K8j9OrOr/ftqS3/uhek61gpGv1mzPEZgQ89pxl7aMK0TA3OZ5YjUITZNYNfnp4j6Ic47vR+Ctu000xh9WdM9fXhOv07Z83S4rjH9n756R4VuU7BfH5cYvHm6YoZu/fD+DxQWC6NE6Y2RvFKHg7/AKJOQAI="

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

Test.Start = function(testName)
    local builtEntities, placedEntitiesByType = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the train.
    local movingTrain = placedEntitiesByType["locomotive"][1].train

    -- Get the stations placed by name.
    local trainStopFirst, trainStopSecond, trainStopThird, trainStopSouth
    for _, stationEntity in pairs(placedEntitiesByType["train-stop"]) do
        if stationEntity.backer_name == "First" then
            trainStopFirst = stationEntity
        elseif stationEntity.backer_name == "Second" then
            trainStopSecond = stationEntity
        elseif stationEntity.backer_name == "Third" then
            trainStopThird = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.movingTrain = movingTrain
    testData.firstStationReached = false
    testData.secondStationReached = false
    testData.thirdStationReached = false
    testData.southStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(movingTrain)
    testData.trainStopFirst = trainStopFirst
    testData.trainStopSecond = trainStopSecond
    testData.trainStopThird = trainStopThird
    testData.trainStopSouth = trainStopSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local firstStationTrain, secondStationTrain, thirdStationTrain, southStationTrain = testData.trainStopFirst.get_stopped_train(), testData.trainStopSecond.get_stopped_train(), testData.trainStopThird.get_stopped_train(), testData.trainStopSouth.get_stopped_train()
    if firstStationTrain ~= nil and not testData.firstStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(firstStationTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, true) then
            TestFunctions.TestFailed(testName, "train reached first station, but with train differences in the emerged train so far")
            return
        end
        game.print("train reached first station")
        testData.firstStationReached = true
    end
    if secondStationTrain ~= nil and not testData.secondStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(secondStationTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, true) then
            TestFunctions.TestFailed(testName, "train reached second station, but with train differences in the emerged train so far")
            return
        end
        game.print("train reached second station")
        testData.secondStationReached = true
    end
    if thirdStationTrain ~= nil and not testData.thirdStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(thirdStationTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, false) then
            TestFunctions.TestFailed(testName, "train reached third station, but with train differences in the full train")
            return
        end
        game.print("train reached third station")
        testData.thirdStationReached = true
    end
    if southStationTrain ~= nil and not testData.southStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(southStationTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, false) then
            TestFunctions.TestFailed(testName, "train reached south station, but with train differences")
            return
        end
        game.print("train reached south station")
        testData.southStationReached = true
    end
    if testData.firstStationReached and testData.secondStationReached and testData.thirdStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
