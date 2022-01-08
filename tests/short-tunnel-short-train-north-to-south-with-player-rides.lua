-- Sends a short train from the south to the north. First loop player watches, second loop player rides the train.
-- Note the player being in the train after the tunnel traversal isn't checked by the test.

local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800
Test.RunLoopsMax = 2

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "0eNqtm9tu2zoQRf9Fz/aBhhJv/oi+9PEgCBSZdYTKkqFLcoIg/35IO23cZph2I/MSw7Eyw2wuDi/efC7u+jWcpm5Yit1z0bXjMBe7f5+LuTsMTZ9+tzydQrEruiUci01x17Tf11N8PzVd/9g83S7rMIR+e3m5PY3T0vS38zp9a9qwPfXx5zHE4C+bohv24b9iRy83myL+qlu6cMl1fvN0O6zHuzDFBzbF0BxTznmJWQ73yzYli8lP4xz/ahxSs1Ik5zfFU7HbOv/ysnkXR+FxLBenwuNoLk79M04KM2znZTwxQTz9DLKJGZvLZ8WXqOx9wYTVePMqrnkGj0NcHAvHsWz3OTwO230ej8N2H5V4IFZowgG3rNKEE25YqQlH3LBaU40H4sXGqTa82DjWhhcb51rzYuNga15snGzNiq1wsjUrtsLJ1qzYCie75ucAnOyaFVvhZNe82DjZNS82TnbNi42TXfFi42RXvNg42RUrdoWTXbFiVzjZFSt2hZOtWLErnGzFL29wshUvNk624sXGyVa82G9k/7ZcfV2nhmH/QVCycQW276bQXj6NQj00U/e6IiMuoftDwjkc0nJ4++P/+ih7BWf3gtkJzV6Xctk9nJzkksO9Xiu55BpOXsklh4mra0Hi4ORaLDme24jlxkW3Yrlx2uQKHD7M5MobXF+0XHHDK6uWK274pKLlihvBuGm54oZP5lquuBEOnFxxUzhwctVN4cDJlTeFA+c+s2JUeDdna9o67MN0mMb4ikwmsNymFG4BrLkh4RbAI90o4RbAHJhKtgU1POZNLdwCnEQt3AKcRCPcApxEK9wCnEQn2wKNkyhcEzVMohWuiRom0QrXRA2TaIVrooZJtMI10cAkWuGaaHAShWuiwUkUrokGJ/FTp3gW73XBPS4ut9wm18JKO7ldroWHu5Pb5Tq4z53cLtfBg9zJ7XIdDJyT2+U6HDi5Xa7DgZPb5XocOLldrseBk6twHgdO8BgPBs7LVTgPA+cFz/FKmDgveJBXwsh5wZO8EmbOCx7llTh0gl9UlDh1RvDoGqfOCmbHqfvUcR7hZ8Yedi4Q/9U1lSUeiXdAlYRHyjjgFB6Jty6VFR6Jd1OVsH2BqoziGo+UUdzgkTKKWzxSRnGHR8oojjPOG4/oylLZj+14HJfuIXwUJhX+cepinNcxGAMkY/KcnpzG9ntYtt/W0Kdv+NiE+FCoMx5OfCjwfjDCzZfEW9Toyn3ZNtNh3D42h/jHH3wfpzg9h4f4fpziA8Pa92wifKTUmQ7BR4rOsISPFJ3pWnyk6EzXeozv8xnZr/3xj74ivB2TJV+XvBkYnzAyvlLcxkkZqyvu46SM+/bKyPlXUhrzGSnxOSXjPsbdnpQxRON2T8p4tHG/J2Vs47jhk3JOdnxOyZjrccsnZfz+uOeT+BsIhJs+yWaM+vhkwd/SINz2SS6juP67iy3pyOMc5v327e2ay9dx5a+5EO4KJZfpWHwAuEzH4gMg3VW6if9xex/2a/96A+qtpKX3aV2U5o5Y9K6evFzLYu4DvRPvJiU439faXV3vinuXMM3nB5WLSwivbO11bdMs+D9ZQzgj"

Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local train = placedEntitiesByGroup["locomotive"][1].train

    -- Put the player in a carriage on the 2nd loop.
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    if testManagerEntry.runLoopsCount == 2 then
        local player = game.connected_players[1]
        if player ~= nil then
            train.carriages[2].set_driver(player)
        else
            game.print("No player found to set as driver, test continuing regardless")
        end
    end

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
