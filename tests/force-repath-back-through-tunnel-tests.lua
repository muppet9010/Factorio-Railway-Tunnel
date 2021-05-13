--[[
    Does a range of tests for the different situations of a train trying to reverse down a tunnel when a piece of track after the tunnel is removed:
        - Train types (heading west): <, <----, ----<, <>, <-->, <>----, ----<>
        - Leaving track removed: before committed, once committed (full train still), as each carriage enters the tunnel, when train fully in tunnel, after each carriage leaves the tunnel, when the full trian has left the tunel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainText = trainType.text so the train makeup in symbols.
        carriages = fully populated list of carriage requirements from trainType.carriages.
        tunnelUsageType = TunnelUsageType object reference for the test.
        reverseOnCarriageNumber = the carriage number to reverse the train on. For non perCarriage tests (TunnelUsageType) this value will be ignored.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

-- Blueprint is just track, tunnel and stations. No train as these are dynamicly placed.
-- Station names:   west station: ForceRepathBackThroughTunnelTests-End     east station: ForceRepathBackThroughTunnelTests-Start
local blueprintString =
    "0eNqtnN1u4zYQhd9F1zag4Y8o5r5PsJfFIvDGamrAkQ1bSRsEfvfKaydNUqX7HUI3+dnEZ0c+/MjhcJiX6sf2sdsfNv1Q3bxUm7tdf6xufn+pjpv7frU9/9vwvO+qm2ozdA/VoupXD+fvDqvN9q/V8+3w2Pfddnn5dLvfHYbV9vb4ePhjddct99vx40M3Sp8W1aZfd39XN3ZaIPF3L3Gn74tqVNkMm+4S3M9vnm/7x4cf3WHUfHvl3ePhqVsvfwosqv3uOL5m15//o1FnmepF9Tx+DqP2enPo7i4/bM4hfZJ0b5LHYVS7/3P4SrSJF9H4UdRNiHou6rFo4KKGRSMWjRmLNlw0YdHERblRLRflRmUuyo2yGqsG7pQZV+VWGYcqcK+MUxW4WcaxCoJbnCsvuMXB8oJbnCwvuMXR8oJbnC3P3XKcLcfdcpwtx91ynC3H3XKcLcfdcpwtJ7jF2TLBLc6WCW5xtkxwi7NlglucLeNuec4WN8tztLhXnpMlZIIcLO6U51wJRmGsBE0MlfDwGCnBJQyUMJwwTnzcBwyTQGjAMAmTScAwCfNewDAJU3TAMAmrScAwCQtfwDQJa3TAOAnpRMA8CZlPwEAJSVrERAn5ZMRECalvxEQJWXrERAkbioiJEvY+ERMlbNMiJkrYUUZMlLD5jZgoYZ8eMVFCSaHBRAnVjwYTJdRpGkyUUFFqMFFC7avBRClVOkyUUE9sMFFC5bPBRAk12gYT1QhGYaIablTCRCVuVMJEJW5UwkQlblTCRCWhmoyJSoJRmKhWMAoT1QpGYaJawShMVCsYhYlquVEtJipzo1pMVOZGtZioLJx6YKIyN6rFRGXBKF6UqAWnGnaOaHUzeY7opzR5pe91QrWPqmlKteXPnydVbUqVV/qu8zQINdeq6OdQp97WDI987Xzm9Hy2e0qEV/auS4gHz+tVUfK4vLJ3XZciiDSqoh5Eyuvl18UugUiTKhpBpLxafl1BM4g0q6Lp15FaXWuj3eqPonFSlBfLr4u9AdytdqpsJu8Ap+qaRJgnwQZZ1ki0ETak5KtfDTnoF8jKk2/BdKxJW/RYrPL6xGL9l66zar88Drv91OnGq+inaWB8guOwunxd/davq8nWh7qgyWn99cmdpf8E8bQ6bFZfr8P2rv1iOoRjd39uq/plDNdyf0kIbq4QfHEIfq4Qyo0Ic4WQikOIc4WQi0NoZgrBlQ/HNFcI5cOxnSuE8uGY5wqheDi6eq4Qioejm2t29MXD0c01O/ri4ejmmh198XB0c82Ovnw4zjU7+vLhONfsGMqH41yzYygfjnPNjqF8OM41O4bi4ejnmh1D8XD0Nk/6mqZ9cCACh7J0e03L/i9J/zasDsNkmi50UL1tBxLpJhaaqOok6ArtiXUUdIUGxdoLukKLYm2CLi+7ZMU2XnjJgmtBaFMUTOO9VcsseMa7q5ZZsCx4ufKAZPXiC5KNcl0LyTZqZY/JyqVNJtuqtV0mm+XiNpGN8hkBkzX17IXJCscGgmVRuB0mWBaF+2GKZVG9IMdkG/WKHJNN6iU5Jtuq1+SYbFYvyiFZ3oH1elWOyZp6WY7JOvW6HJP16n05JhvUC3NMNqo35phso16ZY7JJvTPHZFv1sJ/JZi4rvAm8K0tK83lflrQr4Z1Z0iaK92aZCZbx7iwzxTLeTWKKZQ2XVSxLXFaxjFPmFMs4ZU6wjHdqmRMs471a5gTLeLeWOcEy3q9lXrCMd2yZVyzjlHnFMk6ZVyzjlHnFMk6ZskTyzi1TFnTeu2VK+pE5ZUqyxNu5TEnteEOXKYkob+kyJW3mTV2mJPm8rcuULQlv7DJlA8Vbu0zZ7vHmLhM2p67mlAlbacf7u0zY+Dve32Vflim+Ly5/8Ofm3R8fWlRP3eF4+YV25D675FOKVofT6R/zmwBM"

local TrainTypes = {
    {
        text = "<",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = "<----",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 4
            }
        }
    },
    {
        text = "----<",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 4
            },
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = "--<--",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 2
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 2
            }
        }
    },
    {
        text = "<>",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25
            }
        }
    },
    {
        text = "<---->",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 4
            },
            {
                name = "locomotive",
                orientation = 0.25
            }
        }
    },
    {
        text = "<>----",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 4
            }
        }
    },
    {
        text = "----<>",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 4
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25
            }
        }
    },
    {
        text = "--<>--",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 2
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 2
            }
        }
    },
    {
        text = "><",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = ">----<",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "cargo-wagon",
                orientation = 0.25,
                count = 4
            },
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = "><----",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 4
            }
        }
    },
    {
        text = "----><",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.25,
                count = 4
            },
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = "--<>--",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.25,
                count = 2
            },
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 2
            }
        }
    }
}
local TunnelUsageType = {
    beforeCommitted = {name = "beforeCommitted", perCarriage = false},
    onceCommitted = {name = "onceCommitted", perCarriage = false},
    carriageEntering = {name = "carriageEntering", perCarriage = true},
    fullyUnderground = {name = "fullyUnderground", perCarriage = false},
    carriageLeaving = {name = "carriageLeaving", perCarriage = true},
    leftTunnel = {name = "leftTunnel", perCarriage = false}
}

-- Do each iteration of train type and tunnel usage. Each wagon entering/leaving the tunnel is a test.
for _, trainType in pairs(TrainTypes) do
    local fullCarriageArray = {}
    for _, carriage in pairs(trainType.carriages) do
        carriage.count = carriage.count or 1
        for i = 1, carriage.count do
            table.insert(fullCarriageArray, {name = carriage.name, orientation = carriage.orientation})
        end
    end
    for _, tunnelUsageType in pairs(TunnelUsageType) do
        local maxCarriageCount
        if not tunnelUsageType.perCarriage then
            -- Simple 1 test for whole train.
            maxCarriageCount = 1
        else
            maxCarriageCount = #fullCarriageArray
        end
        -- 1 test per carriage in train.
        for carriageCount = 1, maxCarriageCount do
            local scenario = {
                trainText = trainType.text,
                carriages = fullCarriageArray,
                tunnelUsageType = tunnelUsageType,
                reverseOnCarriageNumber = carriageCount -- On non perCarriage tests this value will be ignored.
            }

            Test.RunLoopsMax = Test.RunLoopsMax + 1
            table.insert(Test.TestScenarios, scenario)
        end
    end
end

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local carriageText = ""
    if testScenario.tunnelUsageType.perCarriage then
        carriageText = "     carriage " .. testScenario.reverseOnCarriageNumber
    end
    local displayName = testScenario.trainText .. "     " .. testScenario.tunnelUsageType.name .. carriageText

    return displayName
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd, stationStart
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        elseif stationEntity.backer_name == "Start" then
            stationStart = stationEntity
        end
    end
    local stationEndRail = stationEnd.connected_rail
    local trackToRemove = stationEnd.surface.find_entity("straight-rail", {x = stationEndRail.position.x + 20, y = stationEndRail.position.y})

    -- Place the train for this run.
    local train = Test.BuildTrain(stationStart, testScenario.carriages, stationEnd)

    -- TODO: need to establish & record expected outcome based on this test scenario.

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationStart = stationStart
    testData.stationEnd = stationEnd
    testData.trackToRemove = trackToRemove
    testData.train = train
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.startingTick = game.tick

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    -- TODO: need to check if expected outcome based on test scenario is reached.

    --if game.tick > testData.startingTick + 1000 then
    if testData.stationEnd.get_stopped_train() ~= nil then
        TestFunctions.TestCompleted(testName)
    end
end

Test.BuildTrain = function(buildStation, carriagesDetails, scheduleStation)
    -- Build the train from the station heading west. Give each loco fuel, set target schedule and to automatic.
    local placedCarriage
    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local placementPosition = Utils.ApplyOffsetToPosition(buildStation.position, {x = 3, y = 2})
    for _, carriageDetails in pairs(carriagesDetails) do
        placedCarriage = surface.create_entity {name = carriageDetails.name, position = placementPosition, direction = Utils.OrientationToDirection(carriageDetails.orientation), force = force}
        if carriageDetails.name == "locomotive" then
            placedCarriage.insert({name = "rocket-fuel", count = 10})
        end
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = 7, y = 0})
    end

    local train = placedCarriage.train
    train.schedule = {
        current = 1,
        records = {
            {station = scheduleStation.backer_name}
        }
    }
    train.manual_mode = false

    return train
end

return Test
