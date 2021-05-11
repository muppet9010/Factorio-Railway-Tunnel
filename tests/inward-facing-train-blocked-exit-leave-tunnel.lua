--[[
    A train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel. The entrance signal on the exit portal is blocked in the next rail segment. Short train so fully leaves the tunnel before stopping. After the train has fully stopped the blocking wagon is removed so the train can compete its journey.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString =
    "0eNqtWl1v4jAQ/C9+JlVsx7HNj7iXezxVKA0ujS4kKB/toYr/fg5UpVKn4LX8UhQwM2F2duNd9509tbM7DE03sfU7a+q+G9n6zzsbm11Xtct70/Hg2Jo1k9uzFeuq/XI1VE37Vh0309x1rs0uL5tDP0xVuxnn4bmqXXZo/d+989CnFWu6rfvH1vz0uGL+rWZq3IXpfHHcdPP+yQ1+wSfHOHmW3cuULWSe+tCP/lt9t9yUR8oKv/ToX7lSp9PqG5D4BFpwumyc+gNAkfaKsvKc1eVD9sv/lhcGcGXEDUp0g0UEEEdAig5UWARURgBpBKQjgGAQTQQQFNtGAEGxeU5HklBtHmF1CeXmIgIJ6s0j3C2h4DzC3hIrHuFvgRWPMLjAikc4XGDFIywusOIRHhdQcRHhcQ4VF1eP19Ww67O3aue/fAtHPSgr9VKM+6HxcB8FOV8eIa/+uh/8um5uW0QXkQgcBlhEJALHz6GIROAwwCIiETgOcEQi5DjAEYmQY8UjEiHHikckQg4VlxGJkEPFJb3YWyi4FBGbsO0NGi19qr1WQ/ORaByRyjuko9stG71wVr9vuM9aJGdVAawqOWuIwmVyVh7AqlOz+q3OfVaTnDXETTY5a4Cbijw5a4CbCp6cNcBNhUjNKgLcVCSvTSLATUXy2iRC3JS8NokQNyWvTSLETclrEw9xU/LaxEPclLw28QA3qeS1iQe4SSWvTTzATSp5bQowk5Jp92pnK22bwdWXD4v7d0BuPvD4RJFbDzzPUeTGAw+YFLntwBMvRW46fhjBkVsOPBMsyQ0HHn6W5HZDQZ1LckOt8GSR3E6XUOeS7OcS60z2c4l1Jvu5xDqT/Vxincl+1ljnq5/bvu73/dS8uhsg5UOBZjYPXubl4GBc1g99/ddN2fPs2mWMCufGZPtrGF5Ntr+G4dVk+2s8DyfbX8Pw6oI2TjPyRlzuTtM0OUkMNJMmJ4nBUSUnicFRJSeJwVG1tGjYHEcjJBaGnBkGOsiQM8PCmBpyZlgYUyNJhcbqHyUklBlDfopYfDpFThALjWTICYJng4acID9MK42hA+HwWjoQlNrmYce5yzTgjPJ9q3w92/3dz/hs13L67cKIWkEHgiG15CfHeeT/6H9u/eK2c/txyn5NruXaP96N/LLmcuQPzr6/afa4QJ//F2D95V8HfB/ihvG8UBheaCu01FrxvDid/gPlMsdE"

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyBlockingWagon", Test.DestroyBlockingWagon)
end

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the trains/wagons
    local blockingWagon, movingTrain
    local wagonKeys = Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "cargo-wagon")
    for _, wagonKey in pairs(wagonKeys) do
        local wagon = builtEntities[wagonKey]
        if #wagon.train.carriages == 1 then
            blockingWagon = wagon
        else
            movingTrain = wagon.train
        end
    end

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        local stationEntity = builtEntities[stationEntityIndex]
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.blockingWagon = blockingWagon
    testData.movingTrain = movingTrain
    testData.blockingWagonReached = false
    testData.northStationReached = false
    testData.southStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(movingTrain)
    testData.trainStopNorth = trainStopNorth
    testData.trainStopSouth = trainStopSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 600, testName, "DestroyBlockingWagon", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsOnceEvent(testName, "DestroyBlockingWagon", testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.DestroyBlockingWagon = function(event)
    -- The main train should have completed its tunnel trip north and have completely stopped at the blocking wagon at this point.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    local mainTrain
    local trains = TestFunctions.GetTestForce().get_trains(TestFunctions.GetTestSurface())
    for _, train in pairs(trains) do
        if #train.carriages > 1 then
            mainTrain = train
            break
        end
    end

    if mainTrain.state ~= defines.train_state.wait_signal then
        TestFunctions.TestFailed(testName, "train not stopped at a signal (for blocking wagon) as expected")
        return
    end

    local northestCarriage, northestCarriageYPos = nil, 100000
    for _, carriage in pairs(mainTrain.carriages) do
        if carriage.position.y < northestCarriageYPos then
            northestCarriage = carriage
            northestCarriageYPos = carriage.position.y
        end
    end
    if Utils.GetDistanceSingleAxis(northestCarriage.position, testData.blockingWagon.position, "y") > 25 then
        TestFunctions.TestFailed(testName, "train not stopped at expected position for blocking wagon signal")
        return
    end

    game.print("train stopped at blocking wagon signal")
    testData.blockingWagonReached = true

    testData.blockingWagon.destroy()
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local northTrain, southTrain = testData.trainStopNorth.get_stopped_train(), testData.trainStopSouth.get_stopped_train()
    if northTrain ~= nil and not testData.northStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(northTrain)
        local trainSnapshotDifference = TestFunctions.TrainSnapshotDifference(testData.origionalTrainSnapshot, currentTrainSnapshot)
        if trainSnapshotDifference ~= nil then
            TestFunctions.TestFailed(testName, "train reached north station, but with train differences: " .. trainSnapshotDifference)
            return
        end
        game.print("train reached north station")
        testData.northStationReached = true
    end
    if southTrain ~= nil and not testData.southStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(southTrain)
        local trainSnapshotDifference = TestFunctions.TrainSnapshotDifference(testData.origionalTrainSnapshot, currentTrainSnapshot)
        if trainSnapshotDifference ~= nil then
            TestFunctions.TestFailed(testName, "train reached south station, but with train differences: " .. trainSnapshotDifference)
            return
        end
        game.print("train reached south station")
        testData.southStationReached = true
    end
    if testData.blockingWagonReached and testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
