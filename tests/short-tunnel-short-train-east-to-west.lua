local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

Test.Start = function(testName)
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local yRailValue = 1
    local nauvisEntitiesToPlace = {}

    -- West side
    for x = -140, -71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, yRailValue}, direction = defines.direction.west})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45, yRailValue}, direction = defines.direction.west})

    -- Tunnel Segments
    for x = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {x, yRailValue}, direction = defines.direction.west})
    end

    -- East Side
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {45, yRailValue}, direction = defines.direction.east})
    for x = 71, 140, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {x, yRailValue}, direction = defines.direction.west})
    end

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopWest = nauvisSurface.create_entity {name = "train-stop", position = {-139, yRailValue - 2}, force = playerForce, direction = defines.direction.west}
    local trainStopEast = nauvisSurface.create_entity {name = "train-stop", position = {139, yRailValue + 2}, force = playerForce, direction = defines.direction.east}
    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {95, yRailValue}, force = playerForce, direction = defines.direction.west}
    loco1.insert("rocket-fuel")
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {102, yRailValue}, force = playerForce, direction = defines.direction.west}
    wagon1.insert("iron-plate")
    local loco2 = nauvisSurface.create_entity {name = "locomotive", position = {109, yRailValue}, force = playerForce, direction = defines.direction.east}
    loco2.insert("coal")
    -- Loco3 makes the train face backwards and so it drives backwards on its orders.
    local loco3 = nauvisSurface.create_entity {name = "locomotive", position = {116, yRailValue}, force = playerForce, direction = defines.direction.east}
    loco3.insert("coal")

    local train = loco1.train
    train.schedule = {
        current = 1,
        records = {
            {
                station = trainStopWest.backer_name
            },
            {
                station = trainStopEast.backer_name
            }
        }
    }
    train.manual_mode = false

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
        local trainSnapshotDifference = TestFunctions.TrainSnapshotDifference(testData.origionalTrainSnapshot, currentTrainSnapshot)
        if trainSnapshotDifference ~= nil then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences: " .. trainSnapshotDifference)
            return
        end
        game.print("train reached west station")
        testData.westStationReached = true
    end
    if eastTrain ~= nil and not testData.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        local trainSnapshotDifference = TestFunctions.TrainSnapshotDifference(testData.origionalTrainSnapshot, currentTrainSnapshot)
        if trainSnapshotDifference ~= nil then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences: " .. trainSnapshotDifference)
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
