--[[
    A series of tests that changes the trains order when it starts leaving the tunnel. Only valid train direction and target direction combinations are tested.
    Tests the below combinations end in an expected outcome:
        - Train type: shortForwards, longForwards, shortDual, longDual. Short train is 2 carriages so its just leaving and underground when orders changed. Long train is 10 carriages long so it is leaving, underground and entering when orders changed.
        - Target type: trainStop, rail.
        - Target direction: fowards, backwards.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")
local Common = require("scripts/common")

local TrainTypes = {
    shortForwards = "shortForwards",
    longFowards = "longForwards",
    shortDual = "shortDual",
    longDual = "longDual"
}
local TargetTypes = {
    trainStop = "trainStop",
    rail = "rail"
}
local TargetDirections = {
    forwards = "forwards",
    backwards = "backwards"
}

local DoMinimalTests = true -- If TRUE does minimal tests just to check the general mining and destroying behavior. Intended for regular use as part of all tests. If FALSE does the whole test suite and follows DoSpecificTests.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainTypeFilter = {} -- Pass in array of TrainTypes keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificTargetTypeFilter = {} -- Pass in array of TargetTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.
local SpecificTargetDirectionFilter = {} -- Pass in array of TargetDirections keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1200
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainType = the TrainTypes of this test.
        targetType = the TargetTypes of this test.
        targetDirection = the TargetDirections of this test.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

local blueprintString = "0eNqtm89u20YchN9lzxLA35LcPzr20GsfoAgMRmJdojIlkJQTw9C7hzLTxG5Y95ugF5uSwW9XGA+0Ozt8dh+Pl/Y8dP3kds+u25/60e1+f3Zjd983x9t709O5dTvXTe2D27i+ebi9Gpru+Kl5upsufd8et8uvu/NpmJrj3XgZ/mj27fZ8nH8+tDP6unFdf2g/u51dNwj+6hZ//bBxM6WbunaZ3MuLp7v+8vCxHWbmtzun+dZ+O06n80w7n8b5llN/G2fGbK3KG/c0X9Qz+9AN7X75a9i4cWqWa/frafjUDIfR3eb5j3H8t3HG20D3f07bl6m+M1T5dii/Qi0FasTUSqDWmFoL1BJTg0A1TI2cWnK1kkDlamWBytWyQsByucwELNfLBHt5LpgJ/vJcMRMM5gXJBId5QTLBYl6QTPCYCZIJJjNBMsFlxiXzgsuMS+YFlxmXzAsuK7hkXnBZwSXzgssKQTLBZYUgmeCyQpCMuywLinGTZUEw7rHM9Sq5xTKXq+QOy1ytkhssCYtE7q/E1Sq5vZKgFndXEtTi5kqCWtxbUVCLeysKanFvRa5Wxb0VuVrVd2/tL8Nje/g3ZkgL079llmtM7qywfH57C7U1KDdWKNeg9Rq0UqElmCm3VbA16OpMA9SpXnQKb5FxDRm17fh7u/Hfhu5+vmqOa9vxKv1EHHFYmcnX9Xn8YSKPzdA17yiS/58JrI/v/3P8upADiQj2+CYHEoTq5UCCUEs5kCDUSg4kCLWWAwlCDXIgQahRDiQINcl5BKFmOY4A1FDIaQShmhxGEKqXswhCLeUoglArOYkg1FoOIgg1yDkEoUY5hiDUJKcQhJrlEAJQYyFnEIRqcgRBqF5OIAi1lAMIQq3k/IFQazV+INCgpg8EGtXwgUCTmj0QaFajBwBNhZo8EKipwQOBejV3INBSjR0ItFJTBwKt1dCBQIOaORBoVCMHAk1q4kCgQjiChcrcUQELlbmjAhYqy9kIgcrZCIFWaoxBoNxRNReKO6rmQnFH1Vwo7qiaC8UdVWOhrMCWUqDYUvzjW4EtxYV6WcxBaORQbCn+z/+ymGXQIAiFLRUEobClgiAUtlQQhMKW4l8nxlse/IvPeMeDf0Ubb3jwxYTxfgdf9hhvd0RBKOyoJAiFHZUEobCjkiAUdlQShMKO4lse440Ovjkz3ufg20jjbQ6+4TXe5eBbc+NNjiwIhR0l5B3GaxxCNmO8xSHkSMZbHELmZbzFIeRzxlscQpZovMUh5J7GWxxCRmu8xSHkycZbHEL2bbzFIeT0xlscwpmC8RaHcP5hvMUhnNUYb3EI50rGWxzCGZhV3Fv8vM54j0M4WzRe5BDOQY03OYQzW+NVDuF82V51Od4rXvw90fxD3eB77+KXZv/X18cgPmyWpzN2r54U2bjHdhiX25JVMftY5iJYDNfrFzquhcI="

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainType .. "     " .. testScenario.targetType .. "     " .. testScenario.targetDirection
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationOrigional, stationForwards, stationBackwards
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "Origional" then
            stationOrigional = stationEntity
        elseif stationEntity.backer_name == "Forwards" then
            stationForwards = stationEntity
        elseif stationEntity.backer_name == "Backwards" then
            stationBackwards = stationEntity
        end
    end

    -- Build the train for this test and set its orders.
    local train = Test.BuildTrain(stationBackwards, testScenario.trainType, stationOrigional, testScenario.targetType)

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    testData.bespoke = {
        stationForwards = stationForwards,
        stationBackwards = stationBackwards,
        train = train,
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train),
        trainOrdersChanged = false
    }
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.TunnelUsageChanged = function(event)
    -- OVERHAUL - this is now functionised at base level.
    local testData = TestFunctions.GetTestDataObject(event.testName)
    local testScenario, testDataBespoke = testData.testScenario, testData.bespoke

    if not testDataBespoke.trainOrdersChanged and event.action == "startedLeaving" then
        local leavingTrain = event.leavingTrain
        local schedule, newRecord, targetStation = leavingTrain.schedule, nil, nil
        if testScenario.targetDirection == TargetDirections.forwards then
            targetStation = testDataBespoke.stationForwards
        elseif testScenario.targetDirection == TargetDirections.backwards then
            targetStation = testDataBespoke.stationBackwards
        else
            error("Unsupported testScenario.targetDirection: " .. testScenario.targetDirection)
        end
        if testScenario.targetType == TargetTypes.trainStop then
            newRecord = {
                station = targetStation.backer_name,
                wait_conditions = {
                    {
                        type = "time",
                        ticks = 60,
                        compare_type = "or"
                    }
                }
            }
        elseif testScenario.targetType == TargetTypes.rail then
            newRecord = {
                rail = targetStation.connected_rail,
                wait_conditions = {
                    {
                        type = "time",
                        ticks = 60,
                        compare_type = "or"
                    }
                },
                temporary = true
            }
        else
            error("Unsupported testScenario.targetType: " .. testScenario.targetType)
        end
        table.insert(schedule.records, newRecord)
        schedule.current = 2
        leavingTrain.schedule = schedule

        game.print("train leaving, so orders changed")
        testDataBespoke.trainOrdersChanged = true
    end
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario, testDataBespoke = testData.testScenario, testData.bespoke

    local targetStationRail
    if testScenario.targetDirection == TargetDirections.forwards then
        targetStationRail = testDataBespoke.stationForwards.connected_rail
    elseif testScenario.targetDirection == TargetDirections.backwards then
        targetStationRail = testDataBespoke.stationBackwards.connected_rail
    end

    -- Check for the train in the right state at the track of the target station. This detects both targetType of station and rail.
    local inspectionArea = {left_top = {x = targetStationRail.position.x - 2, y = targetStationRail.position.y}, right_bottom = {x = targetStationRail.position.x + 2, y = targetStationRail.position.y}} -- Inspection area needs to find trains that have stopped very close to this station's rail.
    local trainFound = TestFunctions.GetTrainInArea(inspectionArea)
    if trainFound and trainFound.state == defines.train_state.wait_station then
        -- Train has stopped fully at this spot, so is arrived as we want.
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(trainFound)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot, false) then
            TestFunctions.TestFailed(testName, "train arrived at new orders, but not identical")
            return
        end
        TestFunctions.TestCompleted(testName)
    end
end

Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local trainTypesToTest, targetTypesToTest, targetDirectionsToTest
    if DoMinimalTests then
        -- Minimal tests.
        trainTypesToTest = {TrainTypes.longDual}
        targetTypesToTest = {TargetTypes.trainStop}
        targetDirectionsToTest = {TargetDirections.forwards, TargetDirections.backwards}
    elseif DoSpecificTests then
        -- Adhock testing option.
        trainTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainTypes, SpecificTrainTypeFilter)
        targetTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TargetTypes, SpecificTargetTypeFilter)
        targetDirectionsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TargetDirections, SpecificTargetDirectionFilter)
    else
        -- Do whole test suite.
        trainTypesToTest = TrainTypes
        targetTypesToTest = TargetTypes
        targetDirectionsToTest = TargetDirections
    end

    for _, trainType in pairs(trainTypesToTest) do
        for _, targetType in pairs(targetTypesToTest) do
            for _, targetDirection in pairs(targetDirectionsToTest) do
                local skipTest = false
                if targetDirection == TargetDirections.backwards and (trainType == TrainTypes.longFowards or trainType == TrainTypes.shortForwards) then
                    skipTest = true
                end
                if not skipTest then
                    local scenario = {
                        trainType = trainType,
                        targetType = targetType,
                        targetDirection = targetDirection
                    }
                    Test.RunLoopsMax = Test.RunLoopsMax + 1
                    table.insert(Test.TestScenarios, scenario)
                end
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, {"trainType", "targetType", "targetDirection"}, Test.TestScenarios)
    end
end

Test.BuildTrain = function(buildStation, trainType, origionalStation, targetType)
    -- Build the train backwards from the station heading west. Give each loco fuel, set target schedule and to automatic.

    -- Work out the train composition from its trainType.
    local carriagesDetails
    if trainType == TrainTypes.shortForwards then
        carriagesDetails = {
            {name = "cargo-wagon", orientation = 0.75},
            {name = "locomotive", orientation = 0.75}
        }
    elseif trainType == TrainTypes.shortDual then
        carriagesDetails = {
            {name = "locomotive", orientation = 0.25},
            {name = "locomotive", orientation = 0.75}
        }
    elseif trainType == TrainTypes.longFowards then
        carriagesDetails = {
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "locomotive", orientation = 0.75}
        }
    elseif trainType == TrainTypes.longDual then
        carriagesDetails = {
            {name = "locomotive", orientation = 0.25},
            {name = "cargo-wagon", orientation = 0.25},
            {name = "cargo-wagon", orientation = 0.25},
            {name = "cargo-wagon", orientation = 0.25},
            {name = "cargo-wagon", orientation = 0.25},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "cargo-wagon", orientation = 0.75},
            {name = "locomotive", orientation = 0.75}
        }
    end

    local placedCarriage
    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local placementPosition = Utils.ApplyOffsetToPosition(buildStation.position, {x = 0.5, y = -2}) -- offset to position first carriage correctly.
    for _, carriageDetails in pairs(carriagesDetails) do
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = 0 - Common.GetCarriagePlacementDistance(carriageDetails.name), y = 0}) -- Move placement position on by the front distance of the carriage to be placed, prior to its placement.
        placedCarriage = surface.create_entity {name = carriageDetails.name, position = placementPosition, direction = Utils.OrientationToDirection(carriageDetails.orientation), force = force, raise_built = false, create_build_effect_smoke = false}
        if carriageDetails.name == "locomotive" then
            placedCarriage.insert({name = "rocket-fuel", count = 10})
        end
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = 0 - Common.GetCarriagePlacementDistance(carriageDetails.name), y = 0}) -- Move placement position on by the back distance of the carriage thats just been placed. Then ready for the next carriage and its unique distance.
    end

    local train = placedCarriage.train
    if targetType == TargetTypes.trainStop then
        train.schedule = {
            current = 1,
            records = {
                {
                    station = origionalStation.backer_name,
                    wait_conditions = {
                        {
                            type = "time",
                            ticks = 60,
                            compare_type = "or"
                        }
                    }
                }
            }
        }
    elseif targetType == TargetTypes.rail then
        train.schedule = {
            current = 1,
            records = {
                {
                    rail = origionalStation.connected_rail,
                    wait_conditions = {
                        {
                            type = "time",
                            ticks = 60,
                            compare_type = "or"
                        }
                    },
                    temporary = true
                }
            }
        }
    else
        error("Unsupported targetType: " .. targetType)
    end
    train.manual_mode = false
    TestFunctions.MakeCarriagesUnique(train.carriages)

    return train
end

return Test
