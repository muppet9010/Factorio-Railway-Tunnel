local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 3600

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

Test.Start = function(testName)
    local nauvisSurface = game.surfaces["nauvis"]
    local playerForce = game.forces["player"]

    local yRailValue = 1
    local xRailValue = 0
    local startRunUp = 200
    local nauvisEntitiesToPlace = {}

    -- NorthWest side
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-71 + xRailValue, yRailValue}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-76 + xRailValue, yRailValue - 1}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-79 + xRailValue, yRailValue - 4}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-82 + xRailValue, yRailValue - 7}, direction = defines.direction.south})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-82 + xRailValue, yRailValue - 15}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-79 + xRailValue, yRailValue - 18}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-76 + xRailValue, yRailValue - 21}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-68 + xRailValue, yRailValue - 21}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-65 + xRailValue, yRailValue - 18}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-63 + xRailValue, yRailValue - 18}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-63 + xRailValue, yRailValue - 16}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-61 + xRailValue, yRailValue - 16}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-61 + xRailValue, yRailValue - 14}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-59 + xRailValue, yRailValue - 14}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-59 + xRailValue, yRailValue - 12}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-57 + xRailValue, yRailValue - 12}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-54 + xRailValue, yRailValue - 9}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-46 + xRailValue, yRailValue - 9}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-43 + xRailValue, yRailValue - 12}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {-40 + xRailValue, yRailValue - 15}, direction = defines.direction.southwest})
    for y = (-188 - startRunUp), -20, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {-39 + xRailValue, yRailValue + y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {-45 + xRailValue, yRailValue}, direction = defines.direction.west})

    -- Tunnel Segments
    for x = -19, 19, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_segment_surface-placement", position = {x + xRailValue, yRailValue}, direction = defines.direction.west})
    end

    -- SouthEast Side
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {71 + xRailValue, yRailValue}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {76 + xRailValue, yRailValue - 1}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {79 + xRailValue, yRailValue - 4}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {82 + xRailValue, yRailValue - 7}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {82 + xRailValue, yRailValue - 15}, direction = defines.direction.north})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {79 + xRailValue, yRailValue - 18}, direction = defines.direction.northeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {76 + xRailValue, yRailValue - 21}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {68 + xRailValue, yRailValue - 21}, direction = defines.direction.west})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {65 + xRailValue, yRailValue - 18}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {63 + xRailValue, yRailValue - 18}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {63 + xRailValue, yRailValue - 16}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {61 + xRailValue, yRailValue - 16}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {61 + xRailValue, yRailValue - 14}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {59 + xRailValue, yRailValue - 14}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {59 + xRailValue, yRailValue - 12}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {57 + xRailValue, yRailValue - 12}, direction = defines.direction.southeast})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {54 + xRailValue, yRailValue - 9}, direction = defines.direction.east})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {46 + xRailValue, yRailValue - 9}, direction = defines.direction.northwest})
    table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {43 + xRailValue, yRailValue - 12}, direction = defines.direction.southwest})
    table.insert(nauvisEntitiesToPlace, {name = "curved-rail", position = {40 + xRailValue, yRailValue - 15}, direction = defines.direction.south})
    for y = (-188 - startRunUp), -20, 2 do
        table.insert(nauvisEntitiesToPlace, {name = "straight-rail", position = {39 + xRailValue, yRailValue + y}, direction = defines.direction.north})
    end
    table.insert(nauvisEntitiesToPlace, {name = "railway_tunnel-tunnel_portal_surface-placement", position = {45 + xRailValue, yRailValue}, direction = defines.direction.east})

    -- Place All track bis
    for _, details in pairs(nauvisEntitiesToPlace) do
        nauvisSurface.create_entity {name = details.name, position = details.position, force = playerForce, direction = details.direction, raise_built = true}
    end

    -- Place Train and setup
    local trainStopWest = nauvisSurface.create_entity {name = "train-stop", position = {-37 + xRailValue, yRailValue - (188 + startRunUp)}, force = playerForce, direction = defines.direction.north}
    local trainStopEast = nauvisSurface.create_entity {name = "train-stop", position = {41 + xRailValue, yRailValue - (188 + startRunUp)}, force = playerForce, direction = defines.direction.north}
    local yPos, train = yRailValue - (185 + startRunUp)
    for i = 1, 4 do
        local loco = nauvisSurface.create_entity {name = "locomotive", position = {-39 + xRailValue, yPos}, force = playerForce, direction = defines.direction.north}
        loco.insert("rocket-fuel")
        yPos = yPos + 7
    end
    for i = 1, 16 do
        local wagon = nauvisSurface.create_entity {name = "cargo-wagon", position = {-39 + xRailValue, yPos}, force = playerForce, direction = defines.direction.north}
        wagon.insert("iron-plate")
        yPos = yPos + 7
    end
    for i = 1, 4 do
        local loco = nauvisSurface.create_entity {name = "locomotive", position = {-39 + xRailValue, yPos}, force = playerForce, direction = defines.direction.south}
        loco.insert("coal")
        yPos = yPos + 7
        train = loco.train
    end
    train.schedule = {
        current = 1,
        records = {
            {
                station = trainStopEast.backer_name
            },
            {
                station = trainStopWest.backer_name
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
    if eastTrain ~= nil and not testData.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences")
            return
        end
        game.print("train reached east station")
        testData.eastStationReached = true
    end
    if westTrain ~= nil and not testData.westStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences")
            return
        end
        game.print("train reached west station")
        testData.westStationReached = true
    end
    if testData.westStationReached and testData.eastStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
