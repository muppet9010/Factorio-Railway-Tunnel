--[[
    A long train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel. The entrance signal on the exit portal is blocked in the next rail segment and the rail segment after this. Long train so only partially left the tunnel before stopping on both rail segments. After the train has fully stopped the first blocking wagon is removed opening the portal rail signal, so the train can move forwards a bit. Then it stops at the next rail signal while stil partially in the tunnel. Once stopped again this second blocking carriage is removed and the train can complete its journey.
    The second blocking carriage wagon tests that until the train has fully left the tunnel the above train does the pathing and feeds the data back to the underground train which controls the speed.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString =
    "0eNqtWl1T2zAQ/C96dhhLsiwpP6IvfewwjBvc4KljZ/wBZZj898pJStKyaryMXwBDvCfudqW7072J7/VY7ruqGcT6TVSbtunF+tub6KttU9TT74bXfSnWohrKnUhEU+ymp66o6pfi9WEYm6asV6dvD/u2G4r6oR+7H8WmXO3r8HVXBuhDIqrmsfwl1vKQzAK/ekUd7hMRUKqhKk+LOz68PjTj7nvZBcz3N/shvLt9GlZHiETs2z681TaTqQnJJOJVrFfS6MO0jn9w1DvOBNOs+qHdAxB7AUmCxeL0N/El/PNPAsBqfnkSLS+jcTKPcAyPYxFOzuMYhGN5HBg+x+NAP3saR0M/y5QHgo6WPME19LS8MHxTdNt29VJsw7v/gZF3ygSWt10VoM5MTydlPofntgsfasa6RqZ41msYVcnTXsOwSp73CseVJ77CcbV/bXmr87b4ESa/ewcKP4Z4PFZduTl9IkPAvBQUJgyvBYW3Vl4LCkZR8VqQMIpK8UAwiopnuoTOVjzTJXY2z3SJnc0zPcXO5vf4FDubZ3aKnc0zO4XO1jyzU+hsTTPbQ19rmtgeulrTvPbQ05qmtceOplntsZ9pUjvsZ5rTDvuZprTDfvbc4e7kpw72jOa7g+HMaLo7nBXTdLcwnJn+RHHzGLdyrA6ei646O1cim9kNm325neqn2UZDnnHbqFnaqJlhNF/a6Bz32qWNyhlG3cJGQ/py26hf2ugMIpl0aaMziGTk0kZnEMmopY3OIJLRCxudwSOz9IY0h0Zm0Y33KJfr+uj2AtiEALcxDJsP4K6KYdOBSJOHzW9xzylnT3vcWcvZw95AF+fsWW9w44rNbA10cX4RS91u2l07VM9lFCPP7jJtPzZTptJ+an/208e7dvOzHFY/xrKe+kfQKpsG5ziwLOlzHFiW9DkOLEv6HAeWS4Gt/E9IbibClpVGDllkWWlYGE/LSsPCeFrNcNo67MArRjfjpi6L7g+loU22QLS4jcwKw0IOWVYYuJywrDBwdWMdEw9nZuwxcyLCHh64xHOsQnBh61iF4DrbsQrBZb/T1B7jVVQiN3cYxwoDNzwcKwzcf3GsMHA7yFmG0d7f3GH+OjNxyNjTBTfEHKsK3J/zrCoi/UIvGUfKNF9mb/CKXj6kk9c0DuSTz2gcGF1v5t3+6jPIxzLjchX8tR3xVbDP6cViDllqE5JSf34X8qx6IpcJ3tM4+EIwpQWE71uCrigFqXSJbEemtIDwvVPQFQ0UuaemJaQi/5qhgSIhzjl+K/t5fof9gF51hE+0UiL3wiktlchNNT2CELs7p0cQYrf5kmZ/ZJSBHjCIDlfQ7I+Me9ADBpH5E0kPGEQGYqSkmZ1FnE0zO4s4m2Y2bm9JeqAgMlQl6YGCyPCYpAcK5NTkug95w+apfBzr82zb5SSanvMsCSV5qAJD2hwSvnBkXb1wGtQDA2gfMpH7yc5xyG59NfCXiOey648fVC5EzCurrTXhPDgcfgN7kD/x"

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyNextBlockingWagon", Test.DestroyNextBlockingWagon)
end

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the trains/wagons. The more north single carriage is the second blcking wagon, with the other single wagon the first blocking wagon.
    local firstBlockingWagon, secondBlockingWagon, movingTrain
    local wagons = Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "cargo-wagon")
    for _, wagon in pairs(wagons) do
        if #wagon.train.carriages == 1 then
            if firstBlockingWagon == nil then
                firstBlockingWagon = wagon
            else
                if wagon.position.y < firstBlockingWagon.position.y then
                    secondBlockingWagon = wagon
                else
                    secondBlockingWagon = firstBlockingWagon
                    firstBlockingWagon = wagon
                end
            end
        else
            movingTrain = wagon.train
        end
    end

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.firstBlockingWagon = firstBlockingWagon
    testData.secondBlockingWagon = secondBlockingWagon
    testData.movingTrain = movingTrain
    testData.firstBlockingWagonReached = false
    testData.secondBlockingWagonReached = false
    testData.northStationReached = false
    testData.southStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(movingTrain)
    testData.trainStopNorth = trainStopNorth
    testData.trainStopSouth = trainStopSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 400, testName, "DestroyNextBlockingWagon", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 600, testName, "DestroyNextBlockingWagon", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsOnceEvent(testName, "DestroyNextBlockingWagon", testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.DestroyNextBlockingWagon = function(event)
    -- The main train should have completed its tunnel trip north and have completely stopped at the blocking wagon at this point. The test for each blocking wagon is functionally the same.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    local blockingWagon, wagonNumberText = testData.firstBlockingWagon, "first"
    if blockingWagon == nil or not blockingWagon.valid then
        blockingWagon = testData.secondBlockingWagon
        wagonNumberText = "second"
    end

    -- The main train will have its lead loco around 30 tiles below the blocking wagon if stopped at the signal.
    local inspectionArea = {left_top = {x = blockingWagon.position.x, y = blockingWagon.position.y + 5}, right_bottom = {x = blockingWagon.position.x, y = blockingWagon.position.y + 10}}
    local carriagesInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {area = inspectionArea, name = "locomotive", "cargo-wagon", limit = 1}
    if #carriagesInInspectionArea ~= 1 then
        TestFunctions.TestFailed(testName, "1 carriage not found just below " .. wagonNumberText .. " wagon")
        return
    end
    local leadingCarriage = carriagesInInspectionArea[1]
    local mainTrain = leadingCarriage.train

    if mainTrain.state ~= defines.train_state.wait_signal then
        TestFunctions.TestFailed(testName, "train not stopped at a signal (for blocking " .. wagonNumberText .. " wagon) as expected")
        return
    end

    local trainDistanceFromBlockingWagon = Utils.GetDistanceSingleAxis(leadingCarriage.position, blockingWagon.position, "y")
    if trainDistanceFromBlockingWagon < 5 or trainDistanceFromBlockingWagon > 10 then
        TestFunctions.TestFailed(testName, "train not stopped at expected position for " .. wagonNumberText .. " blocking wagon signal")
        return
    end

    game.print("train stopped at " .. wagonNumberText .. " blocking wagon signal")
    testData[wagonNumberText .. "BlockingWagonReached"] = true

    blockingWagon.destroy()
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
    if testData.firstBlockingWagonReached and testData.firstBlockingWagonReached and testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
