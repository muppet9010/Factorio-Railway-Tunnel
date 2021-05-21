--[[
    A long train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel.
    Blocked initially at a signal just after the exit portal's entrance signal. Causes the train to stop while still in the tunnel.
    Second blocking at a signal after this causing the train to again stop while in the tunnel.
    Third blocking at a signal once the train has left the tunnel, but still within the portals rail tracks.
    After the train has fully stopped at each blocking waggon the blocking wagon is removed opening the rail signal, so the train can move forwards a bit.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString =
    "0eNqtWsty2zgQ/BeeKRUeJB76iFz2uOVyMTIjs0KRKj6cdbn07wtKiuXEjYit8GKbttgDY7oBzKDfkq/1WB66qhmSzVtSbdumTzb/viV9tWuKevrd8Hook01SDeU+SZOm2E9PXVHVP4rXx2FsmrJenb89HtpuKOrHfuy+FdtydajD130ZoI9pUjVP5X/JRh7TWeAfXlHHhzQJKNVQlefBnR5eH5tx/7XsAub7m/0Q3t09D6sTRJoc2j681TZTqCl4niavyWYlc32cxvEbjnrHmWCaVT+0BwBiryBpiFic/5Z8Cf/8cwJgNT88iYaX0TiZRzg5j2MRjuFxcoRjeRyYPsfjwHn2NI6G8ywFDwQnWvIE13Cm5ZXh26LbtasfxS68+wcYuVZ5YHnbVQHqwnQxKfMlPLdd+FAz1jUKxbNew6xKnvYaplXyvFc4rzzxFc6r/WXJW12Wxc8wZv0OFH4M+XiqunJ7/kSGgHkpKEwYXgsKL628FhTMouK1IGEWleKBYBYVz3QJJ1vxTJd4snmmSzzZPNMFnmx+jRd4sh25ggm5tk7euYgpnv4Cplbz9BcwtZqnv4Cp1TT9PcysptnvYWJ1xq6F3s5ZCjWtBY8zaDjiebF2mbb38U7TcvGYLfQ+4DFZaB04SJaMloGDZMkkSxY3a9/MaFE4SJaMFoWD+cvoHcHhyoEWgcX5M3cUgE/xKKcK6qXoqos4JIppb8Tsy91UY84OGs5it4O6pYPmM4L6pYPOmN5cLB1UzggqFw4ajni3g6qlg84gUq6XDjqDSHm2dNA5RMqXDjqHSGbhoHN4tPSCNIdGbtGF9ySXj3vh7QGwJwDc6jHsASDSeWJPwbgRZtjtHvflDLvb4+6jYTf7HE8xu9fneIrZ0i/HU3wVS91u2307VC9lFMNka3hmnk5xU4u4nz7etdvv5bD6Npb11GODUdlzr8GJZUlvYGItS3qD26Qs6Q1MrOV6gFb+ISU3CxnLSsNAFllWGhbm07LSsDifhuG0detYHfiT0c24rcui+0lpGJOtCC3mECsMiznECgOXE44VBq5unGTy4fIZa8yMjDh288AlnmMVgitOxyoEF9aOVQiu8x3XLPFqfXerxLHCwB0OxwoDN1wcKwzcbPKCYbT3N1eYX/ZMmDLP7i64jedZVeCuomdVEely+oyZSCnMMmuDz+nhQzp5Q+NgPlkaB2fXzbsh1xeQz2XG9br8n3bE1+Xe04ONXL8KahWSUt+/DAX+saPGVy5SKBoI35sKWkP4WkoKTkRKLHHgCUymh48vWQUtIhnhE60iFfnXHA0USbHnGK7sXzCctjPE7pRpO0Ps+lzSUolc6NNmhZjFgDYrxEwPtFkh5vigzQpRDwrN/ogrhjYnRGw6kjYnRHxDkjYnRIxMkjYnRJxVkjYnRKxekjYnRLxnkjYnRDx2kjYnyKnP9RCODtvn8mmsLxbA6040PRubhqo8FILh5BzOfGHL+vDC2c8IfHqfDiMPU5yTF3HzwReZJi9l158+qFzImFdWW5uHIMfj/7hnnSU="

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyNextBlockingWagon", Test.DestroyNextBlockingWagon)
end

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the trains/wagons. The blocking wagons are the single carriage trains sorted south to north.
    local movingTrain, blockingWagons = nil, {}
    local wagonEntities = Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "cargo-wagon")
    for _, wagonEntity in pairs(wagonEntities) do
        if #wagonEntity.train.carriages == 1 then
            table.insert(blockingWagons, wagonEntity)
        else
            movingTrain = wagonEntity.train
        end
    end
    table.sort(
        blockingWagons,
        function(a, b)
            return a.position.y > b.position.y
        end
    )

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
    testData.blockingWagons = blockingWagons
    testData.movingTrain = movingTrain
    testData.blockingWagonsReached = {false, false, false}
    testData.northStationReached = false
    testData.southStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(movingTrain)
    testData.trainStopNorth = trainStopNorth
    testData.trainStopSouth = trainStopSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 400, testName, "DestroyNextBlockingWagon", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 700, testName, "DestroyNextBlockingWagon", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 1000, testName, "DestroyNextBlockingWagon", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsOnceEvent(testName, "DestroyNextBlockingWagon", testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.DestroyNextBlockingWagon = function(event)
    -- The main train should have completed its tunnel trip north and have completely stopped at the blocking wagon at this point. The test for each blocking wagon is functionally the same.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    local blockingWagonEntity, blockingWagonNumber
    for i = 1, 3 do
        if testData.blockingWagons[i].valid then
            blockingWagonNumber = i
            blockingWagonEntity = testData.blockingWagons[i]
            break
        end
    end

    -- The main train will have its lead loco around 30 tiles below the blocking wagon if stopped at the signal.
    local inspectionArea = {left_top = {x = blockingWagonEntity.position.x, y = blockingWagonEntity.position.y + 5}, right_bottom = {x = blockingWagonEntity.position.x, y = blockingWagonEntity.position.y + 10}}
    local carriagesInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {area = inspectionArea, name = "locomotive", "cargo-wagon", limit = 1}
    if #carriagesInInspectionArea ~= 1 then
        TestFunctions.TestFailed(testName, "1 carriage not found just below " .. blockingWagonNumber .. " wagon")
        return
    end
    local leadingCarriage = carriagesInInspectionArea[1]
    local mainTrain = leadingCarriage.train

    if mainTrain.state ~= defines.train_state.wait_signal then
        TestFunctions.TestFailed(testName, "train not stopped at a signal (for blocking " .. blockingWagonNumber .. " wagon) as expected")
        return
    end

    local trainDistanceFromBlockingWagon = Utils.GetDistanceSingleAxis(leadingCarriage.position, blockingWagonEntity.position, "y")
    if trainDistanceFromBlockingWagon < 5 or trainDistanceFromBlockingWagon > 10 then
        TestFunctions.TestFailed(testName, "train not stopped at expected position for " .. blockingWagonNumber .. " blocking wagon signal")
        return
    end

    game.print("train stopped at " .. blockingWagonNumber .. " blocking wagon signal")
    testData.blockingWagonsReached[blockingWagonNumber] = true

    blockingWagonEntity.destroy()
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
    if testData.blockingWagonsReached[1] and testData.blockingWagonsReached[2] and testData.blockingWagonsReached[3] and testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
