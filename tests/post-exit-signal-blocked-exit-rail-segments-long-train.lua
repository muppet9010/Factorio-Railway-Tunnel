--[[
    A long train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel.
    Blocked initially at a signal just after the exit portal's entrance signal. Causes the train to stop while still in the tunnel.
    Second blocking at a signal after this causing the train to again stop while in the tunnel.
    Third blocking at a signal once the train has left the tunnel, but still within the portals rail tracks.
    After the train has fully stopped at each blocking waggon the blocking wagon is removed opening the rail signal, so the train can move forwards a bit.
    There is a second (competitor) train (single loco) that waits 1 second and then also tries to reach the North station. North station has a limit of 1 train and so this competitor train should never leave its waiting station and stay in Destination Full state.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString = "0eNqtW9tu4zgM/Rc/J4GoiyXlI/Zhd4F9WBSBJ/G0xjh2YDvpFkX+faUk06QdKjE5fplOWvuQsc6hKJJ+z77V+3LXVc2QLd+zat02fbb89z3rq+emqOPvhrddmS2zaii32Sxrim381BVV/Vq8rYZ905T1/PxjtWu7oahX/b77XqzL+a4O/27LAH2cZVWzKf/LlnCcjQK/uUUen2ZZQKmGqjw7d/rwtmr2229lFzA/7uyHcO/zyzA/QcyyXduHu9ommorGZbj0LVvOwZhjdOQLkPwAijjNvB/aHYairiizYLM4/zH7I3z9l3D9tmj24TGcMPpVXW2r4fLFv9hTDMcV5rj+AFrvu0O5ScLIC4x2wfNN1ZXr8581AmoY3gHmXU4H0h4DsgwgiwE5BhDKGD8eyFyBPj16g8CCYOCqz7gY4YAhFY0yDuRYyrmfOALFYWhAoywDTUdSKM2AwXyF8gzyT0Ftfgl8v+Iosfi5jipfmMfihKsW1kX33M5fi+dw7T0P1UJG4LarAtYlZokYZQ/hc9uFi5p9XWO2GHJRqFyAoBd/F0kKhk8okyUwfMKRJMMnlMtSMXzCkRiqkKgqpBnJZSk/uCzdGC7LnP5tEz4ydgiJKlc6hk84kmf4hHJeCYZPOBJjH5Ao55Vk+IQjMXYCiXJeaYZPOBJjJwCUmYrB8QQSg+OAMlMxOJ5AYnAcUGZqBscTSAyOA55dMzieQGJwHFBmagbHE0gMjguUmZrB8QQSObsRamEdMBMczUhwBCoEzUhwcCTDSHAEKgTDSHASSIwER6BCMFch1O263bZDdSjvOiSwlR3KbR8v7dr1j3KYf9+XdTw8oRYZgkn4bsaVCdTNI7gtE/xZ9mV3OH36O97/T1HFCsmvdhjnZoFK3FjGd8eR6ErxqMKNJ2eT3o9JJnP6BoJ7mNP3D48qOadvHwkgRYyKXi6cVpYXFHP6ycGjUSM39O+PA9EF4VEF5/QUyuOVLbocHE42uhzcqLOVpW8jDiWfpcvBoato6ZuIQ1fR0pMph66i1Yy69uaOmVNd+FB0VZEuxVnzwGhfPsfa+Xir4Uj82Go+uVU7wqqd3OqYJ+wmt6pGWPWTW4XHVp2Y2iqMYJODya2OYJOTk1sdwSanJrc6gk1OT251DJsmj01jyJRPG4VPVLrdHR97QE4L8N6II2cFeHPJkasqeLfLk3MAvP3mySkA3g/05AwA73p6cgKAt309OdM1+HM2Iw+1Z5BcLtDkPCZ4lJOtJ6fFBl9eMv1zfHnJ9M/x5SXTP8ebTkLQzk25v7Mwj7tlgiyTHG8eCrJOcryfKchCsXiLVWgSw22+SB0/CfwGQa5QWrxnLchKsQlGkaViE0tM1opNLLEnrYxT08QeAPLegp/BgD6agJ8KAciqwc+pQB9NwE/OcDOZMCr+eLFgV22APryAVyQAyGLxiZUli8UnVtaROO7tJNEHyNsQXr0C+sgCXgYESZYKXuGEm4GFMQ80hP+JooYkSytRjwb6fEOiqg/S0JESC52PaxCAv8D8elK5dgv+avfDS4aasXSHE4RytAAVgvVvRCj6QESiSwiKrKhEDxToAxGJDi8ooqbATRKl6NMTibY5KLqi8KEAoE9PJEYeQJH3osRAByhiZzmEhd+gunJ0vxO0oosGH/0BTRcNPtgE9AmLxNgWaHLOlhh3A/qERWKYDzRdB4mhR/qERWqcVNN1kBhx1fTNIzV2S+d4YqRY0zmOF86APjyRGBQHQ+e4TgwV0zmOl8/A0DkeC2hPIa1Yv5SbfX15jeK6P8XPRt1ccH4H5P7Iwix7DT9W67bZnGyeQQPkrujK1eXNjrYL113+P1TbuBMO1fpHHxv1x6fTyyBf3p84//azb97MYu0hnnLjKSAmrmGjTft7QfqEfkmknuJzOL1vsrx592WWHcquP10oXeCCl1Z5kYPNj8f/AY7xvx4="

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyNextBlockingWagon", Test.DestroyNextBlockingWagon)
end

Test.Start = function(testName)
    local _, placedEntitiesByType = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 24}, testName)

    -- Get the trains/wagons. The blocking wagons are the single carriage trains sorted south to north.
    local movingTrain, blockingWagons = nil, {}
    for _, wagonEntity in pairs(placedEntitiesByType["cargo-wagon"]) do
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

    -- Get the competitor train, the single loco train.
    local competitorTrain
    for _, locoEntity in pairs(placedEntitiesByType["locomotive"]) do
        if #locoEntity.train.carriages == 1 then
            competitorTrain = locoEntity.train
        end
    end

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntity in pairs(placedEntitiesByType["train-stop"]) do
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.blockingWagons = blockingWagons
    testData.movingTrain = movingTrain
    testData.competitorTrain = competitorTrain
    testData.competitorTrainStartingPosition = competitorTrain.front_stock.position
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
        if not Utils.ArePositionsTheSame(testData.competitorTrain.front_stock.position, testData.competitorTrainStartingPosition) then
            TestFunctions.TestFailed(testName, "competitor train not stayed in starting position")
            return
        end
        if testData.competitorTrain.state ~= defines.train_state.destination_full then
            TestFunctions.TestFailed(testName, "competitor train not in expected Desitination Full state")
            return
        end
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
