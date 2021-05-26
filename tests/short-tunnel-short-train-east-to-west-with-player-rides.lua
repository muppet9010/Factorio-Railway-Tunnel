-- Sends a short train from the east to the west. First loop player watches, second loop player rides the train.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800
Test.RunLoopsMax = 2

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNqtml1v2jAUhv9LrmGK82Wb+/2GXUwVSoNLo4UEJYEOVfz3OaUbqETtY883haThPYe85zk2jl+jx+Zg9n3djtHqNaqrrh2i1c/XaKi3bdlM58bT3kSrqB7NLlpEbbmbjvqybl7K03o8tK1plpeX9b7rx7JZD4f+qazMct/Yvztjpc+LqG435ne0EueHRWRP1WNtLpHeDk7r9rB7NL294F+M0QZpl8PY7W3cfTfYj3TtlJGVWYpUL6LT9MZqb+reVJf/FotoGMvL++iHGabYdzESj++xmUkiy99yuE/hWPb1exJiJn76RfzBbKfb9nUCQvslkAVLQPolkAdLwNOCIlgCqV8CMlgCwi8BFSoBzxrUoeJ7lqCIQyXgWYJChErAswRFEqwGPRMI1Qh944fqg74GhGqDvhUYqgv6IhiqCXq2IBGqB/r2YBGqCfqOQkmoJug7DiehmqDvTCQJ1QR952JJGmY2Oj8ZTb6Of22CwzTl3j6PyymRTybdH2PMqeYOqhKrFg6qOVaVDqopVlUOqgKraq6aYLfS2EEVu5UKB1XsVpo4qGK30tRBFbuVOrAluFsObAnulgNbgrvlwJbgbjmwJbhbDmzF2K3Mga0Yu5U5sBVjtzIHtmLsVubAVozdyjhbmpvF0dLcK06W5lZxsDR3inOluVEcK4WNyjlVChuVc6gUNirnTClsVM6RUtionBMluVGcKMmN4kRJbhQnSnKjOFGSG4WJ4poFBop/+QLzxF0qME68nApME6/7AsPEAS0wS7yTFBgl3vIKTBLvzQUGiQ8iBeaIj3byylHTVd2uG+ujmRG83syur63G+y/0+NuEwvSwbZiu7LvqlxmXTwfT2M+c5+Jhxvg0QGLG+HxFYsb4xEpeGavKftstX8qtvfZ+aSZOPr3b7dGe6np7RXtomrlAGDw+1ZQYPIdJsZRclJeD4qK8HjTi5PaH1gfrkltQqm56Wp3Hc4iomOePa08JLoprQmHwHH7WqpTd6elpwP/e6Yznj8tP5VwUl5/i9PElFMXp46s9itPHF6aU5qLYKM0548t9mnPGVyY154wvomo8wjms92pOFF+a1pwovoquOVF8wV9zovizCa3QHqO/iundE5XrDqPv5bTD6MGeqp7N5tC872m69tnp2E4J7Win0pvLLnus7jcq3SlP2m9br1Y3O7UW0dH0wyUbJTKpE5lKmYs4O5//ALwlrMw="

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 45, y = 70}, testName)

    -- Get the stations placed by name.
    local trainStopWest, trainStopEast
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "West" then
            trainStopWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            trainStopEast = stationEntity
        end
    end

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

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
    testData.westStationReached = false
    testData.eastStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.trainStopWest = trainStopWest
    testData.trainStopEast = trainStopEast

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local westTrain, eastTrain = testData.trainStopWest.get_stopped_train(), testData.trainStopEast.get_stopped_train()
    if westTrain ~= nil and not testData.westStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences")
            return
        end
        game.print("train reached west station")
        testData.westStationReached = true
    end
    if eastTrain ~= nil and not testData.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences")
            return
        end
        game.print("train reached east station")
        testData.eastStationReached = true
    end
    if testData.westStationReached and testData.eastStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
