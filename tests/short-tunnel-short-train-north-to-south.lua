local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

Test.Start = function(testName)
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local xRailValue = 1
    local nauvisEntitiesToPlace = {}

    -- north side
    for y = -140, -71, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {xRailValue, y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {xRailValue, -45}, direction = defines.direction.north})

    -- Tunnel Segments
    for y = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {xRailValue, y}, direction = defines.direction.north})
    end

    -- South Side
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {xRailValue, 45}, direction = defines.direction.south})
    for y = 71, 140, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {xRailValue, y}, direction = defines.direction.north})
    end

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopNorth = nauvisSurface.create_entity {name = "train-stop", position = {xRailValue + 2, -135}, force = playerForce, direction = defines.direction.north}
    local trainStopSouth = nauvisSurface.create_entity {name = "train-stop", position = {xRailValue - 2, 135}, force = playerForce, direction = defines.direction.south}
    local loco1 = nauvisSurface.create_entity {name = "locomotive", position = {xRailValue, 95}, force = playerForce, direction = defines.direction.north}
    loco1.insert("rocket-fuel")
    local wagon1 = nauvisSurface.create_entity {name = "cargo-wagon", position = {xRailValue, 102}, force = playerForce, direction = defines.direction.north}
    wagon1.insert("iron-plate")
    local loco2 = nauvisSurface.create_entity {name = "locomotive", position = {xRailValue, 109}, force = playerForce, direction = defines.direction.south}
    loco2.insert("coal")
    -- Loco3 makes the train face backwards and so it drives backwards on its orders.
    local loco3 = nauvisSurface.create_entity {name = "locomotive", position = {xRailValue, 116}, force = playerForce, direction = defines.direction.south}
    loco3.insert("coal")

    local train = loco1.train
    train.schedule = {
        current = 1,
        records = {
            {
                station = trainStopNorth.backer_name
            },
            {
                station = trainStopSouth.backer_name
            }
        }
    }
    train.manual_mode = false

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
    if testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
