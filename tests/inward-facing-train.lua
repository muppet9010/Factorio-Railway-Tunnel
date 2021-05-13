--[[
    A train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNqtWdtu4jAU/Bc/QxUn8SV8xL7s4wqhNLg02pCgXNpFFf++DlSlUidbz8ovoAQz44zHJz7nvInHZnKnvm5HsXkTddW1g9j8ehNDfWjLZr43nk9ObEQ9uqNYibY8zld9WTev5Xk3Tm3rmvXta3fq+rFsdsPUP5WVW58a/3l0HvqyEnW7d3/ERl62K+Fv1WPtbkzXi/OunY6PrvcDPjiG0bMcnsf1TOapT93g/9W186Q8UuZHnsVmLTNzuay+4KQfODNMux7G7gRAsjvIyjOWt9/ED/8kzwLAZvz0FJpezuNkCEfxOBLhaBonLRCO4XHg8lkeB+pc8DhQZ5nwQFBoyRtcQqVlygNBqSXvaQm1lrypJRabd7XEYvO2TrDYvK8TLDZv7ASLzTs7gWKnvLMTKHZKO7uAWqe0sQv8BqB9XUClU9rWBRaadnWBdaZNbbHOtKct1pm2tMU60462UOeMNrSFOmfyP447+2UWpfwR46Xs6/dDhkSc6TecgzvMJ6pgUv+W/p40i01qAkjz2KQh8qrYpFkAqY5NKgNITWRSGWIkG5s0xEhFbNIAI+VJbNIAI+UyNmmAkfLYESnAR3nsgBRgozx2PApxUexwFGKi2NEoxEORg1EIZeRQFKJs5EAUYCAVOQwF7BMVOQgFhAOVRj2IZbOw+7p31e23/PsJsJmEhgdKxSYSGpd82DxCw+O2YtMIDU//is0iNExGFJtEGCwxm0MYKLFmUwgDJdZsRmygxJpNiA2UWLMuxmmRZl2MszTNuhgnjZp1Mc5hNetinFLru4ubruqO3Vi/uOXQlz/kmZmjUdfXHuk9AiUPXpq53D7Mw/uu+u3G9dPkmrkKCVlZ0+O6gmFNj8schjU9rroY1vS4CGTupq/K/tCtX8uD/+fiySKR/1iT9sXf6Xo/rp2aBrGxewNXwAy7NxYqckbTOHhJDY2D19SSi2HxYgQtRUHPGTciEhoHrqllt8VCSdumTIiRUi1KSEQYm9GTh0ayOY0DjWTpDYJbH5beILgXY+kNgptD1tI4WOciqPs5V1yvIF9PxPdW6M9uwq3Qgt4ZCy06emfglmGR0jh+Mbf+Watnt5+a9370fVfN1/6NbtNPY27NcdAn/iLYdoa+ds03n5rsPtdw/XAdmFqZmyI1mTFKJvnl8heGUJCA"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationNorth, stationSouth
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "North" then
            stationNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            stationSouth = stationEntity
        end
    end

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationNorthReached = false
    testData.stationSouthReached = false
    testData.trainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.stationNorth = stationNorth
    testData.stationSouth = stationSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationNorthTrain, stationSouthTrain = testData.stationNorth.get_stopped_train(), testData.stationSouth.get_stopped_train()

    if stationNorthTrain ~= nil and not testData.stationNorthReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationNorthTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached north station with differences")
            return
        end
        game.print("train reached north station")
        testData.stationNorthReached = true
    end
    if stationSouthTrain ~= nil and not testData.stationSouthReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationSouthTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached south station with differences")
            return
        end
        game.print("train reached south station")
        testData.stationSouthReached = true
    end

    if testData.stationNorthReached and testData.stationSouthReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
