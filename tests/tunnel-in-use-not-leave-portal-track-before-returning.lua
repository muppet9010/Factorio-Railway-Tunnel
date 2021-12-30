--[[
    The train moves through the tunnel, but doesn't clear the portal track at one end before returning.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "0eNqtW9tS2zAU/Bc/J53oZll57zf0ocMwJojgwbEzvoQyTP69MqEkFANHq/NCiOPsSj67a0lWnrObevT7rmqGbP2cVZu26bP17+esr7ZNWU/Hhqe9z9ZZNfhdtshuys3DuA/vu7KqH8un62FsGl8vTy/X+7Ybyvq6H7u7cuOX+zr83fkAflxkVXPr/2RrcbxaZOFQNVT+xPXy5um6GXc3vgsnLLKm3E2cQyBplv3Q7gPzvu3DV9pmalOAWbpw3lN4tQH6tur85vRhvsj6oTz9n/3y/UT9gUK+UfzXjdf2++Z2htGqE6N5zxjADmVXvXKKGTr1DV3vt9NFCj0Nn2/vhxnu3IHcmoHbgtyGgduA3DkDN1pvy8AtQO4indugWnMM3KjWxIqBHBWbEAzkqNqEZCBH5SYYsk2jehMM4aZhwTGkm4YFxxBvGhYcQ75pWHAMAadgwTEknEIFJxkSTqGCkwwJp1DBSYaEU6jgpIIGixIu86ehNoYBdLft2vBK6bGEL7fhagF8zXOmFgjU6dJytQDWQcHVAtjzjqsF8MRpxdUCVIlKMLUAFaKSTA1AdagUUwNQGSquQIRVyJWHsAiZ4hDmZwpDuABMUQgrkCkIUQtqphiE15CYQhBOYQ0t2ME3Pp0+qYUHHjp9TgsPu3T6lBYedOr0Ga2E650+oYWH+zp9PithraVPZ+FplUmfzcLzSZM+mYUn0iZ9LguvIJj0XIOXTkx6rsFrRiY91+DFMpOea/AqoUnPNXh51KTnGrwubNJzDV4Qz9NzDX4SkKfnGvwIJE/PNfjZTw4t0cGP2PJzlP3rzHLinZv1f1LKOVRDRxV01JyMWjg6qqWjWjpqQUc1dFRHR6VXy67oqPRqWUFGtfRqWUlHpVfLKipqTi+WJVsrj2gp2Vl5xEUlG8tG1J/sKxshVbKtbEShyK6KkFRBNlWE+guypyKMWpAtFZEpBdlREfFXkB0VkdQF2VERN5WC7KiI+19BdlTErbogO8pFFIrsKEcvlDs7qm437a4dqoOfWa1aXVzRtqsCyuv4Z/VjCoVp818/ndu1mwc/LO9GX0/fOs5Rkv3m6NpwZL+968p3qIqOSleHOztuU3bbdvlYbsO5M5jF1xe9OYRDbRdOaca6nmMy9PbThehyOmqEEi0dNUIXZCcKEaELR6zg5QozVEGxWtE7QJfgiwmosCYClm5DYSNgFS2lpn0gn1xuGZlSYqXpXXERXaFbUooIWLonZYxM6KaUMTKhu1LGyMTRYSNKJugWVBElE3QLqoiSXez2/Gp7/Fu91IfVjfP2+J/ltD3+Khza3PvbsX7dj3/24PQ+DCGCQS9OOv0+4OMe+w+4E/LLzwbWF78yWGQH3/WnthRCWyetdkZbo47Hv7MXfdI="

Test.Start = function(testName)
    local _, placedEntitiesByType = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 30, y = 0}, testName)

    -- Get the stations placed by name.
    local stationWest, stationEast
    for _, stationEntity in pairs(placedEntitiesByType["train-stop"]) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
        end
    end

    local train = placedEntitiesByType["locomotive"][1].train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationWestReached = false
    testData.stationEastReached = false
    testData.trainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.stationWest = stationWest
    testData.stationEast = stationEast

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationWestTrain, stationEastTrain = testData.stationWest.get_stopped_train(), testData.stationEast.get_stopped_train()

    if stationWestTrain ~= nil and not testData.stationWestReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at west station has differences after tunnel use")
            return
        end
        game.print("train reached west station")
        testData.stationWestReached = true
    end
    if stationEastTrain ~= nil and not testData.stationEastReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at east station has differences after tunnel use")
            return
        end
        game.print("train reached east station")
        testData.stationEastReached = true
    end

    if testData.stationWestReached and testData.stationEastReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
