-- Sends a short train from the south to the north.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNqtWttu4jAU/Jc8wypO4tjmI/ZlH1cVSoNLow0JyqUtqvj3taFbqmUQnl2/tAo4M2Y8PjnHJ+/JYzvb/dB0U7J6T5q678Zk9fM9GZttV7X+s+mwt8kqaSa7SxZJV+381VA17Wt1WE9z19l2ef633vfDVLXrcR6eqtou9637u7MO+rhImm5j35KVOD4sEvdRMzX2zHS6OKy7efdoBzfgk2OcHMv2eVp6Mke970d3V9/5Sb2dBh6S1VLk5nhcXMFkNIxCMDkNIxFM8QnjUbrlOPX7a4z8grFwfNX5q+S7U/U5AaiSnlyOJlfSMALBKBYmgwunaRi4cIaGgQsnUhoHaixoW2dQZEH7WkCVBW1sAWUWBY2Ddaa9LLDOtJkF1pl2c4p1pu2cYp1pP6dQ54z2cwp1zmg/p1DnjPWzwdGetbOBKmesmw0WmTWzwRqzXjZYYtbKGkvMOlljiVkjayhxzvpYQ4lz1sYaSpyzLlZQ4px1scI5C+tihSVmXaywxKyLFZZY/UPuublJUvgU66Uamo8kSyBKfYdytFuf3YZyuifxfU4TmVPd5yzSyJwB2hYiMmcewJlF5hQBnHlczgALFUVcyhAHybiUIQYq41KG+EdF9k8AZdwQFMIYNwAFyCrjhp8A78i4wSdgg8i4oScgCsi4gSck1sm4gSckpMu4gSfkySXjBp6QB7SMG3hC8hCpY6Zbp2xr0wy2Pn9V3OcnywScNJZklYAz2JIsEnA6XZI1As7tS7JEwIVGSVYIuOopyQIBl2AlWR/gerAki1xcnJZkjYsr5ZL0Li7b1cW7bV/3u35qXuxNCL/B+qFxGB+byt3tT+xHP2zo6192Wj7NtvXPDkRGWhwfWCjS4vj0RJEWx0c56mLxuhq2/fK12robb4XENEMCdi/uuh/cgG5uW8RCbgF8eqXILXDjLE0pFgavomZh8DIawr/+9PRv/b/JLxaue9+MkinsGKTshKFjtGBhcP+C3AQ3DqB1zsgnyv+Qr2AnDG2jJQsDbaPZvYD7EprdC7hNotm9gLs22rAwUGLDGh33tAxr9BsdNtbouN9nyHB/o/toWBfjXqiRQZ3a5R+Q68T20rf90c+4b2tYj+OmsmE9jlvchvW4b7g/uB9aP9vN3H508S9Byl+75MXFf51/GXZ+qwA0ta8Ee/Dop9cNVl/eTnAlgx3G08BMi0KZTOVKSZEWx+Nv5AsEOQ=="

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.northStationReached = false
    testData.southStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.trainStopNorth = trainStopNorth
    testData.trainStopSouth = trainStopSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local northTrain, southTrain = testData.trainStopNorth.get_stopped_train(), testData.trainStopSouth.get_stopped_train()
    if northTrain ~= nil and not testData.northStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(northTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached north station, but with train differences")
            return
        end
        game.print("train reached north station")
        testData.northStationReached = true
    end
    if southTrain ~= nil and not testData.southStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(southTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached south station, but with train differences")
            return
        end
        game.print("train reached south station")
        testData.southStationReached = true
    end
    if testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
