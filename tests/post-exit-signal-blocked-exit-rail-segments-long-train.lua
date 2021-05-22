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
    "0eNqtWl1zo0YQ/C88I9XOAvuhH5GXPKZcLk7mZCoIVIB8cbn037NIysmJe0+0wotd+KBnb6Z7dmd2PpJvzbE69HU7JpuPpN527ZBs/vhIhnrXls30t/H9UCWbpB6rfZImbbmfnvqybn6U78/jsW2rZnX59Xzo+rFsnodj/73cVqtDE37uqwB9SpO6fan+SjZySmeBf/pEn57SJKDUY11dFnd+eH9uj/tvVR8wf345jOHb3eu4OkOkyaEbwlddO5majGdp8p5sVlJkp2kd/8HRP3EmmHY1jN0BgBQ3kDRYLC//lvwW/vOvCYDN+OUJWl5O4+Qe4RQ8jkU4hscpEI7lcWD4HI8D/expnAz6WRQPBB0tPMEz6Gm5MXxb9rtu9aPchW9/ASNrXQSWd30doK5MV5My38Jz14eX2mPTIFM86zMYVeFpn8GwCs97jePKE1/juNp/pbzVNS1+hcnX/+QcbdZTPF7qvtpe3sgRMC8FjQnDa0Hj1MprQcMoal4LAqOoNQ8Eo6h5pgt0tuaZLtjZPNMFO5tnusLO5nO8ws52ZAZTsrZOHkximqe/gqHNePorGNqMp7+Coc1o+nsY2Yxmv4eBzXI2F3o7JxVmtBY8jqDhiOfV2uWZfYx3GS0Xj9lC7wMek4XWgYNkyWkZOEiWXFiyuFn7Zk6LwkGy5LQoHIxfTu8IDlcOtAgsjp95oAB8iVs5V1BvZV9fxSHIpr1jc6h2U40522g4i9036pY2Wsww6pc2OsO9hVraqMwwKgsbDUe8+0b10kZnEKnIljY6g0hFvrTROUQqljY6h0hmYaNzeLR0QppDI7do4j3L5fNeeH8B7AkAt3oMewCIdJ7YUzBuhBl2u8d9OcPu9rj7aNjNvsAuZvf6AruYLf0K7OKbWJpu2+27sX6rohgmX8Mz83SKm1rEw/R6323/rMbV92PVTD02aJU99xocWJb0BgbWsqQ3uE3Kkt7AwFquB2jlFyG5W8hYVhoGssiy0rAwnpaVhsXxNAynrVvH6kCC0ZatCC3mECsMiznECgOXE44VBq5unDDxcMUyOcaxmwcu8RyrEFxxOlYhuLB2rEJwne+4ZonX64dbJY4VBu5wOFYYuOHiWGHgZpNXDKO9XyLDeHZ7wX08z8oCtxU9K4tIm9PnjCdFmWWSgy/o5UM+eUPjYEJZGgdH1827IpcryNc643Zf/nt3xPfl3tOLjdy/KioNiWSP56HAP3bV+M5FlKaB8MWpojWE76VEcSLSaol8FJhMLx/fsipaRBLhE60iHQmxo4EiIfYcw7X9Hwyn5xlil8r0PEPs/lxoqURu9OlphdiMAT2tEJt6oKcVYiMf9LRCdAiFZn9kLIaeTojM6Qg9nRAZHBJ6OiEyyST0dEJktEro6YTIrJfQ0wmR4TOhpxMiQ3ZCTyfI1Oh6CkeH7Wv1cmyuM4C3nWh6NjYNZXmoBMPROZz5wpb16YPLQCMY1PtyGHma7JyHETefBiPT5K3qh/OL2oWIeW0za4tg5HT6G17Km4s="

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyNextBlockingWagon", Test.DestroyNextBlockingWagon)
end

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the trains/wagons. The blocking wagons are the single carriage trains sorted south to north.
    local movingTrain, blockingWagons = nil, {}
    local wagonEntities = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "cargo-wagon", true, false)
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
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
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
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 600, testName, "DestroyNextBlockingWagon", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 800, testName, "DestroyNextBlockingWagon", testName)
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
