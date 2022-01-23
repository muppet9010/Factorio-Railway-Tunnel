--[[
    The train moves through the tunnel, but doesn't clear the portal track at one end before returning.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "0eNqtW9tS2zAU/Bc/J53oZll57zf0ocMwJojgwbEzvoQyTP69MqEkFANHq/NCiOPsSj67a0lWnrObevT7rmqGbP2cVZu26bP17+esr7ZNWU/Hhqe9z9ZZNfhdtshuys3DuA/vu7KqH8un62FsGl8vTy/X+7Ybyvq6H7u7cuOX+zr83fkAflxkVXPr/2RrcbxaZOFQNVT+xPXy5um6GXc3vgsnLLKm3E2cQyBplv3Q7gPzvu3DV9pmalOAWbpw3lN4tQH6tur85vRhvsj6oTz9n/3y/UT9gUK+UfzXjdf2++Z2htGqE6N5zxjADmVXvXKKGTr1DV3vt9NFCj0Nn2/vhxnu3IHcmoHbgtyGgduA3DkDN1pvy8AtQO4indugWnMM3KjWxIqBHBWbEAzkqNqEZCBH5SYYsk2jehMM4aZhwTGkm4YFxxBvGhYcQ75pWHAMAadgwTEknEIFJxkSTqGCkwwJp1DBSYaEU6jgpIIGixIu86ehNoYBdLft2vBK6bGEL7fhagF8zXOmFgjU6dJytQDWQcHVAtjzjqsF8MRpxdUCVIlKMLUAFaKSTA1AdagUUwNQGSquQIRVyJWHsAiZ4hDmZwpDuABMUQgrkCkIUQtqphiE15CYQhBOYQ0t2ME3Pp0+qYUHHjp9TgsPu3T6lBYedOr0Ga2E650+oYWH+zp9PithraVPZ+FplUmfzcLzSZM+mYUn0iZ9LguvIJj0XIOXTkx6rsFrRiY91+DFMpOea/AqoUnPNXh51KTnGrwubNJzDV4Qz9NzDX4SkKfnGvwIJE/PNfjZTw4t0cGP2PJzlP3rzHLinZv1f1LKOVRDRxV01JyMWjg6qqWjWjpqQUc1dFRHR6VXy67oqPRqWUFGtfRqWUlHpVfLKipqTi+WJVsrj2gp2Vl5xEUlG8tG1J/sKxshVbKtbEShyK6KkFRBNlWE+guypyKMWpAtFZEpBdlREfFXkB0VkdQF2VERN5WC7KiI+19BdlTErbogO8pFFIrsKEcvlDs7qm437a4dqoOfWa1aXVzRtqsCyuv4Z/VjCoVp818/ndu1mwc/LO9GX0/fOs5Rkv3m6NpwZL+968p3qIqOSleHOztuU3bbdvlYbsO5M5jF1xe9OYRDbRdOaca6nmMy9PbThehyOmqEEi0dNUIXZCcKEaELR6zg5QozVEGxWtE7QJfgiwmosCYClm5DYSNgFS2lpn0gn1xuGZlSYqXpXXERXaFbUooIWLonZYxM6KaUMTKhu1LGyMTRYSNKJugWVBElE3QLqoiSXez2/Gp7/Fu91IfVjfP2+J/ltD3+Khza3PvbsX7dj3/24PQ+DCGCQS9OOv0+4OMe+w+4E/LLzwbWF78yWGQH3/WnthRCWyetdkZbo47Hv7MXfdI="

---@param testName string
Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 30, y = 0}, testName)

    -- Get the stations placed by name.
    local stationWest, stationEast
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
        end
    end

    local train = placedEntitiesByGroup["locomotive"][1].train

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_TIUNLPTBR_TestScenarioBespokeData
    local testDataBespoke = {
        stationWestReached = false, ---@type boolean
        stationEastReached = false, ---@type boolean
        trainSnapshot = TestFunctions.GetSnapshotOfTrain(train),
        stationWest = stationWest, ---@type LuaEntity
        stationEast = stationEast ---@type LuaEntity
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
    local testDataBespoke = testData.bespoke ---@type Tests_TIUNLPTBR_TestScenarioBespokeData

    local stationWestTrain, stationEastTrain = testDataBespoke.stationWest.get_stopped_train(), testDataBespoke.stationEast.get_stopped_train()

    if stationWestTrain ~= nil and not testDataBespoke.stationWestReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at west station has differences after tunnel use")
            return
        end
        game.print("train reached west station")
        testDataBespoke.stationWestReached = true
    end
    if stationEastTrain ~= nil and not testDataBespoke.stationEastReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at east station has differences after tunnel use")
            return
        end
        game.print("train reached east station")
        testDataBespoke.stationEastReached = true
    end

    if testDataBespoke.stationWestReached and testDataBespoke.stationEastReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
