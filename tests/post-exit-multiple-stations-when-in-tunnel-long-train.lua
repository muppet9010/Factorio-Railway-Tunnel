--[[
    A long train that has a number of stations imediately after the tunnel. Causes the train to stop at each station for a second while still in the tunnel.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString =
    "0eNqtWu1y2joUfBf/hoxlfVk8QF+g99+dDOOCSjw1NmObpJkM714pcBtus0y1if4QTMSuObtH0tHxS/GtO/rD2PZzsXop2s3QT8Xq35diand908XP5ueDL1ZFO/t9sSj6Zh+vxqbtnprn9Xzse98tz3/Wh2Gcm249HcfvzcYvD1143fsAfVoUbb/1P4uVON0vivBRO7f+zPR68bzuj/tvfgwDfnNMc2DZPczLSBaoD8MUvjX08aYiUhj5XKyWQsrTafEOp/qNE2H65TQPBwAi30AWgbE5/6/456EdtwWAlfztCXR7isapHMLRPI5FOOZ/0i4v8r9Hqe70fzjmToeYbdvRb84jFMC1/P1pdH81jwNt4XgcqJ8oOX8FlGt/ffUh06DBBJ8AAjpDVDwQtIbgPS+ghkLRJhMqxWSCzwIB3SEMD4Ttwfu+xCrWnM8CyrXPvrTjNEOb8YlQQndUJQ8E3VHxxi/xzF99YJna3qaxNoT0sRnbS1AF4pR/4Zz8Lq6EyaRaJJCqzKTKJZDq3KQp4TW5SXUCqc1NKhNI69ykKUZymUllgpFkmZs0wUhS5CZNMJKscpMmGEnmnpFkgpFk7hmpSjFS7hmpSjFS7hmpSjFS7hmpSjFS7hmpSjFS7hlJJBhJlVk3DvaPjevf+d8mp27YDPthbh/9TXhp7kRto2uGsQ1IF+DwG2KpPsXB47D54efl96PvYsUC61C2SsDVtmJrBAn3gIotiyXckyq2HpBw763ecnzTjLth+dTswjdvgSh5U5D+MVwPYxjUH7sOUbH1gsKnCmyZrLCabHGgoJq6pOKny4/HT7PFg4LG0Ww2KHwow2aDhmpqNhs0VFNrTgb7CRnY+llj47DZoLGabDZorKaj4mfUx+Nn2GLaQOMYNhsMNI5hs8FANQ2bDQafUCpmdbQCqxBPlpj10bBLiYEeMmxiWCwsmxgWC1tTjrb1JxzNLiUWesiyiWGhhyybGBaqadnEqKGaVlIy1PrjMlh2KamhcSybDTVWk82GGqvJZkON1WSXCYfVZJ3uYIhr1ukO90tYpzsY4pp1uoMhrtklQJQwxrWicXCQNY2Do2xoHBxmS+PgOLNWvtG+qB2Ng7ttJY0D4+wEjQPj7CoaB8bZ0X7GXURH+/lGV1MndYncBUO/O5m46kwOx/kBdYwc7fXYyb0P2JsHvz12l3b/294tXiuxMOpqzPnZgz/aV4viqWnndeyYvtKcgQLMoRn9+vJ8wjCGcZf3c7uPO8O53fyY4qb6dB9/z7vua3bc81MDOWDvY+BeH7lYXT2hsSge/Ti9clW1UNZVVlqrRalOp18qpEcC"

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
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
    if testData.blockingWagonsReached[1] and testData.blockingWagonsReached[2] and testData.blockingWagonsReached[3] and testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
