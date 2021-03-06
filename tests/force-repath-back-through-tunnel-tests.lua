--[[
    Does a range of tests for the different situations of when a train tries to reverse down a tunnel when a piece of track in its forwards path is removed:
        - Train types (heading west): <, <----, ----<, <>, <-->, <>----, ----<>
        - Leaving track removed: before committed, once committed (full train still), as each carriage enters the tunnel, when train fully in tunnel, after each carriage leaves the tunnel, when the full trian has left the tunel.
        - Reverse track path being present at start, added after a delay or never.
        - Forwards track being returned after a delay or never.
        - Player riding in no carriage, first carriage or last carriage.
    After the correct reaction state for the fowards track removal occurs, a piece of track (either forwards or behind) is added and this resulting state checked. This way we know the train recovers from the loss of initial path correctly as well.
    Theres a second train trying to path to the same station with a train limit of 1. This second train should never move if the reservation isn't lost. Some tests it is expected to move.

    Note: don't run the whole tets suite or large numbers of tests with debuigger attached as it will take a while to start.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")
local TrainManagerFuncs = require("scripts/train-manager-functions")
local Colors = require("utility/colors")

local ExcludeNonPositiveOutcomes = true -- If TRUE skips some believed non positive outcome tests where the result is expected to be the same as others (redundant). These should be run occasioanlly, but shouldn't be needed for smaller code changes. Skips all player riding tests as these concepts are included in some other tests.
local DoPlayerInCarriageTests = false -- If true then player riding in carriage tests are done. Normally FALSE as needing to test a player riding in carriages is a specific test requirement and adds a lot of pointless tests otherwise.

local DoSpecificTrainTests = false -- If enabled does the below specific train tests, rather than the full test suite. used for adhock testing.
local SpecificTrainTypesFilter = {} -- Pass in array of TrainTypes text (---<---) to do just those. Leave as nil or empty table for all train types. Only used when DoSpecificTrainTests is true.
local SpecificTunnelUsageTypesFilter = {} -- Pass in array of TunnelUsageTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTrainTests is true.
local SpecificReverseOnCarriageNumberFilter = {} -- Pass in an array of carriage numbers to reverse on to do just those specific carriage tests. Leave as nil or empty table for all carriages in train. Only used when DoSpecificTrainTests is true.
local SpecificForwardsPathingOptionAfterTunnelTypesFilter = {} -- Pass in array of ForwardsPathingOptionAfterTunnelTypes keys to do just those specific forwards pathing option tests. Leave as nil or empty table for all forwards pathing tests. Only used when DoSpecificTrainTests is true.
local SpecificBackwardsPathingOptionAfterTunnelTypesFilter = {} -- Pass in array of BackwardsPathingOptionAfterTunnelTypes keys to do just those specific backwards pathing option tests. Leave as nil or empty table for all backwards pathing tests. Only used when DoSpecificTrainTests is true.
local SpecificStationReservationCompetitorTrainExists = {} -- Pass in array of true/false to do just those specific reservation competitor train exists tests. Leave as nil or empty table for both combinations of the reservation competitor existing tests. Only used when DoSpecificTrainTests is true.
local SpecificPlayerInCarriageTypesFilter = {} -- Pass in array of PlayerInCarriageTypes keys to do just those. Leave as nil or empty table it will honour the main "DoPlayerInCarriageTests" setting to dictate if player riding in train tests are done. This specific setting is only used when DoSpecificTrainTests is true.

local DebugOutputTestScenarioDetails = false -- If true writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainText = trainType.text so the train makeup in symbols.
        carriages = fully populated list of carriage requirements from trainType.carriages.
        tunnelUsageType = TunnelUsageTypes object reference for the test.
        reverseOnCarriageNumber = the carriage number to reverse the train on. For non perCarriage tests (TunnelUsageType) this value will be ignored.
        backwardsLocoCarriageNumber = the carriage number of the backwards facing loco. Will be 0 for trains with no backwards locos.
        playerInCarriageNumber = the carriage number that the player is riding in, or nil for none.
        forwardsPathingOptionAfterTunnelType = the forwards pathing option after track removal option of this test.
        backwardsPathingOptionAfterTunnelType = the backwards pathing option after track removal option of this test.
        stationReservationCompetitorTrainExist = if theres a competitor train for the single train stop reservation slot (TRUE/FALSE).
        afterTrackRemovedResult = the expected result of this test (ResultStates) after the track is removed.
        afterTrackReturnedResult = the expected result of this test (ResultStates) after the track is returned (if it is).
        startingSpeed = the starting speed of the train in the test. Some trains need to start moving to reach the tunnel in the desired state.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

-- Blueprint is just track, tunnel and stations. No train as these are dynamicly placed.
local blueprintString = "0eNqtnN1y2kgUhN9F1yilM//j29S+wO7llosioCSqAKIk4awrxbuvhAjGRJhuoZsEY/NxUE9LmkPP/Eq+rPf5riq2TfL0KymW5bZOnv79ldTFt+1i3T3XvO7y5CkpmnyTzJLtYtP9VC2KdXKYJcV2lf+XPMlhBr3k5+J13uy323yd9v/Nd2XVLNbzel99XSzzdLdu/93kbTVvcHV4niXtU0VT5H1xxx9e59v95ktete9+fo/lvnrJV+mxulmyK+v2NeW2K6nlaDVLXpOnmLXoVVHly/53rqv9iqgwoskGiXqAqM/Eumlh3743N5gq9kz9nukHmAZlGj3IlAGmhev0PdPer9OxTH3/eHpQIdcT3WGAEeC6bE/x9z9rZJn2/meVDIaehI73CxVhoR6oVMFQOUIlE6BUTVKvP/9gqbB7JJ5KBSwplqYKUKujRrtk5j3TDjE9XKk/UQGrS6CpgNkFdpXYExWwqspoKmBWBV6NpL92iFxdPNQQE7aV6OHPP1ippq5yWKXm3fU+Pd0T/MmUT2elPtn7lyVlyWsddgTefNVBt2ndlLublyXJrk4r7avrZtE/Tv7artpXbhbbfXs7c6TV83WxKZobH8iDB8qcD1S8PlCDAgSMK6JIcATBKnJgnUEiiBFAhX/6R3/ndV69HB9+Lje7vH3Dsmp/V3X3lX9WAFo29eHkBHX/FlLDnk39aciKAEdL41ghsPDVMHWRwFoc6wmsw7GWwHocy0gWcCwjGXxRTC0hmclwLCGZERxLSGZwl1lCMoO7zBKSGdxlhpEMd5lhJMNdZhjJcJcZRjLcZYaRDHeZJiSzuMs0IZnFXaYJySzuMk1IZnGXaUIyi7tMMZLhLlOMZLjLFCMZ7jLFSIa7TDGS4S4TQjKHu0wIyRzuMiEkc7jLhJDM4S4TQjKHu4xRDDcZIxjuMUYv3GKMXLjDGLXwDgoO9bC9iM/vYXMRUnlFtqAxKtvUx6iwsZiLooeNxVzBPWws5nbDw8Zi7o08bCzmRs7DxmLuOkPGtrsgKmwt5n4+wN5iJh8B9hYzUwqwt5hpXYC9xcxBA+wtZsIcYG8xs/sAe4tpRQTYW0zfJMLeYpo8EfYW05GKsLeY9lmEvcX0+iLsLaYxGWFvMV3UCHvLM2rB3vKMWrC3PKMW7K1AqCUZbK6gGSzsrmAZLGyv4Bks7K8QGSxssEhJBjssUpLBFouUZLDHIiUZbLJISYZPuzJGMzwRchyMOFdwLqOaKPRL8RvfsA2mAvBcyHHY4NXi0ZCMGQ1EOESo0eBwLjUa8IiIUKMBD4kIpRvuNqaLKERQhGl6isLdxvRohYiLMC1lUbjfmDaKKNxvitIN95umdMP9pindcL9pSjfcb5rSDfcb01KRi0TIulyWm7IpXvKhRIi5gJZV0XJOOZDsU3ff3uWP6+6Pq3L5I2/Sr/t83Z2zD4NvipuR6eQIngMRppcjeBBEmG6O4EkQYfo5gkdBxFCDBTejpXTDzWgp3XAzWko3IiPJ6EbkQc4zRSQoehEI+TBPlupzUK2LrN0PXslFJuROBE5uk4cjw5q/gQPCjXKRC/k4gBZ+n/ECQrXgTbe8UQc5+Ldnv2ffSg+T+BvKW6RAHjF1dcTMIDWSR+yaOhi0tryDtCBcNraoDRJgZ6dq19TBs4jlnaORYLw1I9YXrT74Rl3bP9KlL4uqWHzgs4tgyHANdf6tW9J0t4hHanBT1WDH1+CnqsGPryFMVUMcX0OcqIbfk8kRNVwkXx6sYfyYdDJVDePHpFNT1TB+TF4EcB6sYfyYdGaiGvQDY3Kq86R+YExOdZ7UD4zJqc6T+oExOdV5Uj8wJqc6T5rxY9JPdZ4048ekn+o8acaPST/VedKMH5N+qvOkGT8m/VTnSfvAmLTT3NP6G1IooARsYdy5Pa/1x2uyhtddCR70Oq+R0sCKMsGjXudFUhg30qukIC4e9zovk8K4Qq+TwriKXiiFcTW9UgrjGnqpFMa19FopjOvoxVIY19OrpTBuoJdLYdxIr5eCuHgELDWMbngILDWMbngMLDWMbngQLDWMbngULNWUbpaOPWBcR8ceMK6nAwoYN9ABBYwb+S4dsnQcT4WJaIYrdD8Z4yo6oIBxNR1QwLiGDihgXEsHFDCuowMKGNfTAQWMG+iAAsaNdEAB4hLxMM3oRsTDNKObKDqggHE1HVDAuIbOCmBcS2cFMK6jswIY19NZAYwb6KwAxo10VgDiMjsJMboRATFmHqCIgBgzb1FEQIyZZykiIOYo3XC/OUo33G+O0g33m6N0w/3mKN1wvzF9GKVxvzF9I0VkwDyjG5EB84xuRAbMM7oRGbBA6Yb7LVC64X4LlG643wKlG+63QOmG+y0yuuEZMImMbvimQBIZ3fBdgSQyuhH5r8johu8LpDJKN3w314zSDd/RNaN08ziX0g3f6TWjdMN3e6X6JXhiTFH9Enx7IEX1Syyx7etN3Z5nSb38nq/269Muz2/Z7+5n0dnFX/R7VBPb/s2Sn4uimS/L7epYT/8W7RvsFlU+P21YXVbt350eN8Wmy5w3xfJH3e0kc3g+7nH9br/H9rnnPmbePvG2kfYsecmruv9YoZ35ROV1zJx4dzj8Dz2fA5s="

-- Orientation 0.75 is forwards, 0.25 is backwards. As the trains are all heading east to west (left).
-- Long trains should be 6+ carriages long as otherwise when entering they never go longer than the backwards track points.
-- startingSpeed is optional and generally not needed, so leave as nil.
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
        text = "<------",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 6
            }
        }
    },
    {
        text = "------<",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 6
            },
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = "---<---",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 3
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 3
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
        text = "<------>",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 6
            },
            {
                name = "locomotive",
                orientation = 0.25
            }
        }
    },
    {
        text = "<>------",
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
                count = 6
            }
        }
    },
    {
        text = "------<>",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 6
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
        text = "---<>---",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 3
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
                count = 3
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
        text = ">------<",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "cargo-wagon",
                orientation = 0.25,
                count = 6
            },
            {
                name = "locomotive",
                orientation = 0.75
            }
        }
    },
    {
        text = "><------",
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
                orientation = 0.25,
                count = 6
            }
        }
    },
    {
        text = "------><",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 6
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
        text = "---><---",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 3
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
                orientation = 0.25,
                count = 3
            }
        }
    },
    {
        text = "<------------>",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 12
            },
            {
                name = "locomotive",
                orientation = 0.25,
                none = "none"
            }
        },
        startingSpeed = 0.3 -- Needed so the before committed state is triggered before the first carriage is removed.
    },
    {
        text = ">------------<",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.25
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 12
            },
            {
                name = "locomotive",
                orientation = 0.75,
                none = "none"
            }
        },
        startingSpeed = 0.3 -- Needed so the before committed state is triggered before the first carriage is removed.
    },
    {
        text = "<>------------",
        carriages = {
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25,
                none = "none"
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 12
            }
        },
        startingSpeed = 0.3 -- Needed so the before committed state is triggered before the first carriage is removed.
    },
    {
        text = "------------<>",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 12
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25,
                none = "none"
            }
        },
        startingSpeed = 0.3 -- Needed so the before committed state is triggered before the first carriage is removed.
    },
    {
        text = "------<>------",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.25,
                count = 6
            },
            {
                name = "locomotive",
                orientation = 0.75
            },
            {
                name = "locomotive",
                orientation = 0.25,
                none = "none"
            },
            {
                name = "cargo-wagon",
                orientation = 0.75,
                count = 6
            }
        },
        startingSpeed = 0.3 -- Needed so the before committed state is triggered before the first carriage is removed.
    }
}
local TunnelUsageTypes = {
    beforeCommitted = {name = "beforeCommitted", perCarriage = false},
    carriageEntering = {name = "carriageEntering", perCarriage = true}, -- This can overlap with carriageLeaving.
    carriageLeaving = {name = "carriageLeaving", perCarriage = true} -- This can overlap with carriageEntering.
}
local PlayerInCarriageTypes = {
    none = "none",
    first = "first",
    last = "last"
}
local ForwardsPathingOptionAfterTunnelTypes = {
    none = "none",
    delayed = "delayed"
}
local BackwardsPathingOptionAfterTunnelTypes = {
    none = "none",
    immediate = "immediate",
    delayed = "delayed"
}
local StationReservationCompetitorTrainExists = {
    [true] = true,
    [false] = false
}
local ResultStates = {
    notReachTunnel = "notReachTunnel",
    pullToFrontOfTunnel = "pullToFrontOfTunnel",
    reachStation = "reachStation",
    stopPostTunnel = "stopPostTunnel", -- is leaving/left the tunnel when path removed and can't get back to station. Its beyond the front of portal position so just stops where it is. May or not have fully left the tunnel when this occurs.
    beforeCommittedUnknownOutcome = "beforeCommittedUnknownOutcome" -- Is a variable result as we can't calculate which one before run time.
}

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local carriageText = ""
    if testScenario.tunnelUsageType.perCarriage then
        carriageText = " " .. testScenario.reverseOnCarriageNumber
    end
    local playerInCarriageText = ""
    if testScenario.playerInCarriageNumber ~= nil then
        playerInCarriageText = "      player in carriage " .. testScenario.playerInCarriageNumber
    end
    local reservationCompetitorText
    if testScenario.stationReservationCompetitorTrainExist then
        reservationCompetitorText = "    competing train"
    else
        reservationCompetitorText = "    only train"
    end

    local displayName = testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainText .. "     " .. testScenario.tunnelUsageType.name .. carriageText .. "    forwards path " .. testScenario.forwardsPathingOptionAfterTunnelType .. "    backwards path " .. testScenario.backwardsPathingOptionAfterTunnelType .. reservationCompetitorText .. playerInCarriageText .. "    Expected results: " .. testScenario.afterTrackRemovedResult .. " - " .. testScenario.afterTrackReturnedResult

    return displayName
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd, stationStart, stationReservationCompetitorStart
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        elseif stationEntity.backer_name == "Start" then
            stationStart = stationEntity
        elseif stationEntity.backer_name == "StationReservationCompetitorStart" then
            stationReservationCompetitorStart = stationEntity
        end
    end

    -- Get the portals.
    local enteringPortal, enteringPortalXPos, leavingPortal, leavingPortalXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "railway_tunnel-tunnel_portal_surface-placed", true, false)) do
        if portalEntity.position.x > enteringPortalXPos then
            enteringPortal = portalEntity
            enteringPortalXPos = portalEntity.position.x
        end
        if portalEntity.position.x < leavingPortalXPos then
            leavingPortal = portalEntity
            leavingPortalXPos = portalEntity.position.x
        end
    end

    local forwardsTrackToRemove = stationEnd.surface.find_entity("straight-rail", {x = leavingPortal.position.x, y = leavingPortal.position.y - 24}) -- Allows really 23 carriages to be out of the tunnel. Easily enough for current tests.
    local forwardsTrackToAddPosition = forwardsTrackToRemove.position
    local backwardsTrackToRemove = stationEnd.surface.find_entity("straight-rail", {x = enteringPortal.position.x + 38, y = enteringPortal.position.y - 12})
    local backwardsTrackToAddPosition = backwardsTrackToRemove.position

    local train = Test.BuildTrain(stationStart, testScenario.carriages, stationEnd, testScenario.playerInCarriageNumber, testScenario.startingSpeed)

    -- Remove the backwards track for non immediate BackwardsPathingOptionAfterTunnelTypes tests. As we want the other tests to have the option to use it (expected or not).
    if testScenario.backwardsPathingOptionAfterTunnelType ~= BackwardsPathingOptionAfterTunnelTypes.immediate then
        backwardsTrackToRemove.destroy()
    end

    local reservationCompetitorTrain = stationReservationCompetitorStart.get_train_stop_trains()[1]
    local reservationCompetitorTrainCarriage1StartingPosition = reservationCompetitorTrain.carriages[1].position
    -- Remove the station reservation competitor train based on testScenario.
    if not testScenario.stationReservationCompetitorTrainExist then
        reservationCompetitorTrain.carriages[1].destroy()
        reservationCompetitorTrain = nil
        reservationCompetitorTrainCarriage1StartingPosition = nil
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationStart = stationStart
    testData.stationEnd = stationEnd
    testData.stationReservationCompetitorStart = stationReservationCompetitorStart
    testData.forwardsTrackToRemove = forwardsTrackToRemove
    testData.forwardsTrackRemoved = false
    testData.forwardsTrackToAddPosition = forwardsTrackToAddPosition
    testData.backwardsTrackToAddPosition = backwardsTrackToAddPosition
    testData.trackAdded = false
    testData.enteringPortal = enteringPortal
    testData.leavingPortal = leavingPortal
    testData.train = train
    testData.reservationCompetitorTrain = reservationCompetitorTrain
    testData.reservationCompetitorTrainCarriage1StartingPosition = reservationCompetitorTrainCarriage1StartingPosition
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.managedTrainId = 0 -- Tracks current managed train id for tunnel usage.
    testData.oldManagedTrainId = 0 -- Tracks any old (replaced) managed train id's for ignoring their events (not erroring as unexpected).
    testData.testScenario = testScenario
    testData.actions = {}
    --[[
        A list of actions and how many times they have occured. Populated as the events come in.
        [actionName] = {
            name = the action name string, same as the key in the table.
            count = how many times the event has occured.
            recentChangeReason = the last change reason text for this action if there was one. Only occurs on single fire actions.
        }
    --]]
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.TunnelUsageChanged = function(event)
    local testName, testData = event.testName, TestFunctions.GetTestDataObject(event.testName)

    if testData.managedTrainId == 0 and event.action == "startApproaching" then
        -- Keep hold of managed train id.
        testData.managedTrainId = event.tunnelUsageId
    end
    if testData.managedTrainId ~= event.tunnelUsageId then
        if event.replacedtunnelUsageId ~= nil and testData.managedTrainId == event.replacedtunnelUsageId then
            -- Tracked tunnel usage entry has been replaced by another one. Update tracked id and flag old id for ignoring.
            testData.managedTrainId = event.tunnelUsageId
            testData.oldManagedTrainId = event.replacedtunnelUsageId
            testData.actions = {}
        elseif testData.oldManagedTrainId == event.tunnelUsageId then
            -- This old managed train id is expected and can be ignored entirely.
            return
        else
            TestFunctions.TestFailed(testName, "tunnel event for unexpected train id received")
        end
    end

    -- Record the action and tunnel usage entry for later reference.
    local actionListEntry = testData.actions[event.action]
    if actionListEntry then
        actionListEntry.count = actionListEntry.count + 1
        actionListEntry.recentChangeReason = event.changeReason
    else
        testData.actions[event.action] = {
            name = event.action,
            count = 1,
            recentChangeReason = event.changeReason
        }
    end
    testData.tunnelUsageEntry = {enteringTrain = event.enteringTrain, leavingTrain = event.leavingTrain}
end

Test.ResetTunnelUsageDetails = function(testData)
    -- Called once a tunnel usage is confirmed ended (Terminated) ad the state check has completed its use of the data.
    testData.managedTrainId = 0
    testData.oldManagedTrainId = nil
    testData.tunnelUsageEntry = nil
    testData.actions = {}
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario = testData.testScenario

    if not testData.forwardsTrackRemoved then
        if Test.ShouldForwardsRailBeRemoved(testData) then
            -- This is the correct state to remove the rail.

            -- Handle the unknown expected state if needed before the track is removed.
            if testScenario.afterTrackRemovedResult == ResultStates.beforeCommittedUnknownOutcome or testScenario.afterTrackReturnedResult == ResultStates.beforeCommittedUnknownOutcome then
                Test.HandleBeforeCommittedUnknownOutcome(testData.tunnelUsageEntry, testData)
            end

            game.print("train reached track removal state")
            testData.forwardsTrackToRemove.destroy()
            testData.forwardsTrackRemoved = true
        end
        return -- End the tick loop here every time we check for the track removal. Regardless of if its removed or not.
    end

    local endStationTrain = testData.stationEnd.get_stopped_train()

    if not testData.trackAdded then
        -- Check state for when track should be added every tick. Intentionally wait a tick after adding before the next check.
        local trackShouldBeAddedNow = Test.CheckTrackRemovedState(endStationTrain, testData.testScenario.afterTrackRemovedResult, testData, testName)

        if trackShouldBeAddedNow then
            -- The main train has reched the expected state after the forwards track was removed. We now add any track back in to let the train try and recover. Done after the second state check so the main trian has a tick to change its state before inspection.
            local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
            testData.trackAdded = true
            if testData.testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed then
                surface.create_entity({name = "straight-rail", position = testData.forwardsTrackToAddPosition, direction = defines.direction.east, force = force})
            end
            if testData.testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.delayed then
                surface.create_entity({name = "straight-rail", position = testData.backwardsTrackToAddPosition, direction = defines.direction.north, force = force})
            end
            game.print("after track REMOVED result reached: " .. testData.testScenario.afterTrackRemovedResult)
        end
    else
        -- Check state every tick after track is added for the final state being reached.
        if Test.CheckTrackAddedState(endStationTrain, testData.testScenario.afterTrackReturnedResult, testData, testName) then
            game.print("after track ADDED result reached: " .. testData.testScenario.afterTrackReturnedResult)
            TestFunctions.TestCompleted(testName)
        end
    end
end

Test.ShouldForwardsRailBeRemoved = function(testData)
    -- Funcition is only safe to be called repeatedly before it returns true. Once true it should never be called again as it will likely just re-trigger every tick.
    local testScenario, testTunnelUsageType = testData.testScenario, testData.testScenario.tunnelUsageType

    -- Check test type and usage change type to see if the desired state has been reached.
    if testTunnelUsageType.name == TunnelUsageTypes.beforeCommitted.name then
        if testData.actions["startApproaching"] ~= nil and testData.actions["startApproaching"].count == 1 then
            return true
        else
            return false
        end
    elseif testTunnelUsageType.name == TunnelUsageTypes.carriageEntering.name then
        if testData.actions["enteringCarriageRemoved"] ~= nil and testData.actions["enteringCarriageRemoved"].count == testScenario.reverseOnCarriageNumber then
            return true
        else
            return false
        end
    elseif testTunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name then
        if testData.actions["leavingCarriageAdded"] ~= nil and testData.actions["leavingCarriageAdded"].count == testScenario.reverseOnCarriageNumber then
            return true
        else
            return false
        end
    end

    return true
end

Test.CheckTrackRemovedState = function(endStationTrain, expectedResult, testData, testName)
    -- Initial state monitoring after the the forwards track was removed and before any track added back.

    if expectedResult == ResultStates.notReachTunnel then
        -- This outcome can be checked instantly after the path out of tunnel broken. As the train never entered the tunnel the old testData.train reference should be valid still.
        -- Depending on exactly where the train stopped its makeup and its length it may/not be able to reach the end station. So can't check this at present.
        if testData.train == nil or not testData.train.valid then
            TestFunctions.TestFailed(testName, "train reference should still exist from test start")
            return false
        else
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(testData.train)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "train has differences")
                return false
            end
        end
        -- See if we have moved past the start approaching action on to another action. If not moved passed start approaching then continue the test.
        if testData.actions["startApproaching"] ~= nil then
            -- Check latest action is the expected one.
            if testData.actions["terminated"] ~= nil and testData.actions["terminated"].recentChangeReason == "abortedApproach" then
                Test.ResetTunnelUsageDetails(testData)
                return true
            else
                TestFunctions.TestFailed(testName, "last tunnel usage state wasn't abortedApproach")
                return false
            end
        end
    elseif expectedResult == ResultStates.pullToFrontOfTunnel then
        local inspectionArea = {left_top = {x = testData.leavingPortal.position.x - 20, y = testData.leavingPortal.position.y}, right_bottom = {x = testData.leavingPortal.position.x - 18, y = testData.leavingPortal.position.y}} -- Inspection area needs to find trains that have pulled to the end of the tunnel.
        local trainFound = TestFunctions.GetTrainInArea(inspectionArea)
        if not trainFound then
            return false
        end
        if testData.reservationCompetitorTrain ~= nil then
            -- Reservation should be taken by other train.
            if trainFound.state == defines.train_state.destination_full and trainFound.speed == 0 then
                -- The reservation competitor train will have taken the reservation and so the main train is in the reservation queue when it stops. The main train won't realise its going to no path until it tries to get a reservation which it never will as the target train stop will always be fully reserved.
                if testData.reservationCompetitorTrain ~= nil and testData.reservationCompetitorTrain.state == defines.train_state.destination_full then
                    TestFunctions.TestFailed(testName, "reservation competitor train should have got a reservation to the end station as the main train lost its")
                    return
                end
                return true
            elseif endStationTrain ~= nil then
                if endStationTrain.id ~= testData.reservationCompetitorTrain.id then
                    -- If a train other than the reservation competitor train reaches the end station something has gone wrong. The reservation competitor train can move in this test as the main train's path and reservation is expected to be lost.
                    TestFunctions.TestFailed(testName, "train reached end station")
                    return false
                end
            end
        else
            -- No train getting reservation.
            if endStationTrain ~= nil then
                -- Nothing should reach the end station.
                TestFunctions.TestFailed(testName, "train reached end station")
                return false
            end
            if testData.actions["reversedDuringUse"] ~= nil and trainFound.speed == 0 and testData.testScenario.afterTrackReturnedResult == ResultStates.reachStation then
                -- The train has been reversed and has 0 speed when found at/straddling the end of the portal track. If the next action is to arrive at the station then this current state is the train having pulled to the end of the track and instantly is heading to the station (has a path).
                return true
            elseif (trainFound.state == defines.train_state.no_path or trainFound.state == defines.train_state.path_lost) and trainFound.speed == 0 then
                -- The main train has stopped at the end of the portal track after pulling forwards. It is no pathing, rather than waiting on reservation, as theres no competiton to get a new reservation.
                return true
            end
        end
    elseif expectedResult == ResultStates.reachStation then
        if endStationTrain ~= nil then
            if testData.reservationCompetitorTrain ~= nil then
                -- Extra tests if there was a competitor train.
                if not Utils.ArePositionsTheSame(testData.reservationCompetitorTrain.carriages[1].position, testData.reservationCompetitorTrainCarriage1StartingPosition) then
                    TestFunctions.TestFailed(testName, "reservation competitor train wasn't where it started")
                    return false
                end
                if testData.reservationCompetitorTrain.state ~= defines.train_state.destination_full then
                    TestFunctions.TestFailed(testName, "reservation competitor train wasn't in desitination full state")
                    return false
                end
            end
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(endStationTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "train reached station, but with train differences")
                return false
            end

            -- The train reached the station on its first event, so no need to do any later part of the test.
            game.print("after track ADDED result reached: " .. testData.testScenario.afterTrackReturnedResult)
            TestFunctions.TestCompleted(testName)
        end
    elseif expectedResult == ResultStates.stopPostTunnel then
        local inspectionArea = {left_top = {x = testData.leavingPortal.position.x + 5, y = testData.leavingPortal.position.y}, right_bottom = {x = testData.leavingPortal.position.x + 10, y = testData.leavingPortal.position.y}} -- Inspection area needs to find trains that were fully left and then just stopped dead. So a carraige will be right after leaving the portal if the train stopped at this time.
        local trainFound = TestFunctions.GetTrainInArea(inspectionArea)
        if not trainFound then
            return false
        end
        if testData.reservationCompetitorTrain ~= nil then
            if trainFound.state == defines.train_state.destination_full and trainFound.speed == 0 then
                -- The reservation competitor train will have taken the reservation and so the main train is in the reservation queue when it stops. The main train won't realise its going to no path until it tries to get a reservation which it never will as the target train stop will always be fully reserved.
                if testData.reservationCompetitorTrain.state == defines.train_state.destination_full then
                    TestFunctions.TestFailed(testName, "reservation competitor train should have got a reservation to the end station as the main train lost its")
                    return false
                end
                return true
            elseif endStationTrain ~= nil then
                if endStationTrain.id ~= testData.reservationCompetitorTrain.id then
                    -- If a train other than the reservation competitor train reaches the end station something has gone wrong. The reservation competitor train can move in this test as the main train's path and reservation is expected to be lost.
                    TestFunctions.TestFailed(testName, "train reached end station")
                    return
                end
            end
        else
            if trainFound.state == defines.train_state.no_path and trainFound.speed == 0 then
                -- The main train will no path as it is able to get a reservation without any competition for the station.
                return true
            end
        end
    else
        error("unsupported expectedResult: " .. expectedResult)
    end
end

Test.CheckTrackAddedState = function(endStationTrain, expectedResult, testData, testName)
    -- Initial state monitoring after some track is added back.
    if expectedResult == ResultStates.notReachTunnel then
        -- This outcome can be checked instantly after the track is added back. As the train never entered the tunnel the old testData.train reference should be valid still.
        if testData.train == nil or not testData.train.valid then
            TestFunctions.TestFailed(testName, "train reference should still exist from test start")
            return false
        else
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(testData.train)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "train has differences")
                return false
            end
        end

        -- Check that no action has been started. We should still be sitting idle before the tunnel never moving based on this expected state for after track added.
        if testData.managedTrainId ~= 0 then
            TestFunctions.TestFailed(testName, "train shouldn't have started using tunnel")
            return
        elseif testData.train.state == defines.train_state.no_path or testData.train.state == defines.train_state.destination_full then
            return true
        else
            -- The train shouldn't get in a moving state based on this expected end result.
            TestFunctions.TestFailed(testName, "train shouldn't have started moving")
            return false
        end
    elseif expectedResult == ResultStates.pullToFrontOfTunnel then
        -- Same logic as when forwards track removed, so just call that.
        return Test.CheckTrackRemovedState(endStationTrain, expectedResult, testData, testName)
    elseif expectedResult == ResultStates.stopPostTunnel then
        -- Same logic as when forwards track removed, so just call that.
        return Test.CheckTrackRemovedState(endStationTrain, expectedResult, testData, testName)
    elseif expectedResult == ResultStates.reachStation then
        -- Same logic as when forwards track removed, so just call that.
        return Test.CheckTrackRemovedState(endStationTrain, expectedResult, testData, testName)
    else
        error("unsupported expectedResult: " .. expectedResult)
    end
end

Test.GenerateTestScenarios = function()
    local trainTypesToTest, tunnelUsageTypesToTest, playerInCarriagesTypesToTest, forwardsPathingOptionAfterTunnelTypesToTest, backwardsPathingOptionAfterTunnelTypesToTest, stationReservationCompetitorTrainExistsToTest

    -- Player riding in carriage has extra on/off variable so handle first.
    local limitedplayerInCarriagesTypes
    if DoPlayerInCarriageTests then
        -- Do all the player in train tests.
        limitedplayerInCarriagesTypes = PlayerInCarriageTypes
    else
        -- Just do the no player in train test in this situation.
        limitedplayerInCarriagesTypes = {none = "none"}
    end

    if DoSpecificTrainTests then
        -- Adhock testing option.
        if Utils.IsTableEmpty(SpecificTrainTypesFilter) then
            trainTypesToTest = TrainTypes
        else
            trainTypesToTest = {}
            for _, traintext in pairs(SpecificTrainTypesFilter) do
                for _, trainType in pairs(TrainTypes) do
                    if trainType.text == traintext then
                        table.insert(trainTypesToTest, trainType)
                        break
                    end
                end
            end
        end
        if Utils.IsTableEmpty(SpecificTunnelUsageTypesFilter) then
            tunnelUsageTypesToTest = TunnelUsageTypes
        else
            tunnelUsageTypesToTest = {}
            for _, usageTypeName in pairs(SpecificTunnelUsageTypesFilter) do
                tunnelUsageTypesToTest[usageTypeName] = TunnelUsageTypes[usageTypeName]
            end
        end
        if Utils.IsTableEmpty(SpecificPlayerInCarriageTypesFilter) then
            playerInCarriagesTypesToTest = limitedplayerInCarriagesTypes
        else
            playerInCarriagesTypesToTest = {}
            for _, playerInCarriageType in pairs(SpecificPlayerInCarriageTypesFilter) do
                playerInCarriagesTypesToTest[playerInCarriageType] = PlayerInCarriageTypes[playerInCarriageType]
            end
        end
        if Utils.IsTableEmpty(SpecificForwardsPathingOptionAfterTunnelTypesFilter) then
            forwardsPathingOptionAfterTunnelTypesToTest = ForwardsPathingOptionAfterTunnelTypes
        else
            forwardsPathingOptionAfterTunnelTypesToTest = {}
            for _, forwardsPathingOptionAfterTunnelType in pairs(SpecificForwardsPathingOptionAfterTunnelTypesFilter) do
                forwardsPathingOptionAfterTunnelTypesToTest[forwardsPathingOptionAfterTunnelType] = ForwardsPathingOptionAfterTunnelTypes[forwardsPathingOptionAfterTunnelType]
            end
        end
        if Utils.IsTableEmpty(SpecificBackwardsPathingOptionAfterTunnelTypesFilter) then
            backwardsPathingOptionAfterTunnelTypesToTest = BackwardsPathingOptionAfterTunnelTypes
        else
            backwardsPathingOptionAfterTunnelTypesToTest = {}
            for _, backwardsPathingOptionAfterTunnelType in pairs(SpecificBackwardsPathingOptionAfterTunnelTypesFilter) do
                backwardsPathingOptionAfterTunnelTypesToTest[backwardsPathingOptionAfterTunnelType] = BackwardsPathingOptionAfterTunnelTypes[backwardsPathingOptionAfterTunnelType]
            end
        end

        if Utils.IsTableEmpty(SpecificStationReservationCompetitorTrainExists) then
            stationReservationCompetitorTrainExistsToTest = StationReservationCompetitorTrainExists
        else
            stationReservationCompetitorTrainExistsToTest = {}
            for _, stationReservationCompetitorTrainExist in pairs(SpecificStationReservationCompetitorTrainExists) do
                stationReservationCompetitorTrainExistsToTest[stationReservationCompetitorTrainExist] = StationReservationCompetitorTrainExists[stationReservationCompetitorTrainExist]
            end
        end
    else
        -- Full testing suite.
        trainTypesToTest = TrainTypes
        tunnelUsageTypesToTest = TunnelUsageTypes
        forwardsPathingOptionAfterTunnelTypesToTest = ForwardsPathingOptionAfterTunnelTypes
        backwardsPathingOptionAfterTunnelTypesToTest = BackwardsPathingOptionAfterTunnelTypes
        stationReservationCompetitorTrainExistsToTest = StationReservationCompetitorTrainExists
        playerInCarriagesTypesToTest = limitedplayerInCarriagesTypes
    end

    -- Do each iteration of train type, tunnel usage, forward pathing and backwards pathing options. Each wagon entering/leaving the tunnel is a test.
    for _, trainType in pairs(trainTypesToTest) do
        -- Get the full carraige details from the shorthand and find the last backwards facing loco.
        local fullCarriageArray, backwardsLocoCarriageNumber = {}, 0
        for _, carriage in pairs(trainType.carriages) do
            carriage.count = carriage.count or 1
            for i = 1, carriage.count do
                table.insert(fullCarriageArray, {name = carriage.name, orientation = carriage.orientation})
                if carriage.name == "locomotive" and carriage.orientation == 0.25 then
                    backwardsLocoCarriageNumber = #fullCarriageArray
                end
            end
        end
        for _, tunnelUsageType in pairs(tunnelUsageTypesToTest) do
            for _, forwardsPathingOptionAfterTunnelType in pairs(forwardsPathingOptionAfterTunnelTypesToTest) do
                for _, backwardsPathingOptionAfterTunnelType in pairs(backwardsPathingOptionAfterTunnelTypesToTest) do
                    for _, stationReservationCompetitorTrainExist in pairs(stationReservationCompetitorTrainExistsToTest) do
                        local maxCarriageCount
                        if not tunnelUsageType.perCarriage then
                            -- Simple 1 test for whole train.
                            maxCarriageCount = 1
                        else
                            maxCarriageCount = #fullCarriageArray
                        end

                        -- Handle if SpecificReverseOnCarriageNumberFilter is set
                        local carriageNumbersToTest = {}
                        if not DoSpecificTrainTests or Utils.IsTableEmpty(SpecificReverseOnCarriageNumberFilter) then
                            -- Do all carriage numbers in this train.
                            for carriageCount = 1, maxCarriageCount do
                                table.insert(carriageNumbersToTest, carriageCount)
                            end
                        else
                            for _, carriageCount in pairs(SpecificReverseOnCarriageNumberFilter) do
                                if carriageCount <= maxCarriageCount then
                                    table.insert(carriageNumbersToTest, carriageCount)
                                end
                            end
                        end

                        -- 1 test per carriage in train.
                        for _, carriageCount in pairs(carriageNumbersToTest) do
                            -- 1 test per playerInCarriage state for each carriage.
                            for _, playerInCarriage in pairs(playerInCarriagesTypesToTest) do
                                local playerCarriageNumber
                                if playerInCarriage == PlayerInCarriageTypes.none then
                                    playerCarriageNumber = nil
                                elseif playerInCarriage == PlayerInCarriageTypes.first then
                                    playerCarriageNumber = 1
                                elseif playerInCarriage == PlayerInCarriageTypes.last then
                                    playerCarriageNumber = #fullCarriageArray
                                end

                                local scenario = {
                                    trainText = trainType.text,
                                    carriages = fullCarriageArray,
                                    tunnelUsageType = tunnelUsageType,
                                    reverseOnCarriageNumber = carriageCount, -- On non perCarriage tests this value will be ignored.
                                    backwardsLocoCarriageNumber = backwardsLocoCarriageNumber,
                                    playerInCarriageNumber = playerCarriageNumber,
                                    forwardsPathingOptionAfterTunnelType = forwardsPathingOptionAfterTunnelType,
                                    backwardsPathingOptionAfterTunnelType = backwardsPathingOptionAfterTunnelType,
                                    stationReservationCompetitorTrainExist = stationReservationCompetitorTrainExist,
                                    startingSpeed = trainType.startingSpeed or 0
                                }
                                scenario.afterTrackRemovedResult, scenario.afterTrackReturnedResult, scenario.isNonPositiveTest = Test.CalculateExpectedResults(scenario)

                                -- If we are excluding non positive tests then this test entry is ignored and not recorded.
                                if not ExcludeNonPositiveOutcomes or (ExcludeNonPositiveOutcomes and not scenario.isNonPositiveTest) then
                                    Test.RunLoopsMax = Test.RunLoopsMax + 1
                                    table.insert(Test.TestScenarios, scenario)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Write out all tests to csv as debug.
    Test.WriteTestScenariosToFile()
end

Test.BuildTrain = function(buildStation, carriagesDetails, scheduleStation, playerInCarriageNumber, startingSpeed)
    -- Build the train from the station heading west. Give each loco fuel, set target schedule and to automatic.
    local placedCarriage
    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local placementPosition = Utils.ApplyOffsetToPosition(buildStation.position, {x = -0.5, y = 2}) -- offset to position first carriage correctly.
    for carriageNumber, carriageDetails in pairs(carriagesDetails) do
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = TrainManagerFuncs.GetCarriagePlacementDistance(carriageDetails.name), y = 0}) -- Move placement position on by the front distance of the carriage to be placed, prior to its placement.
        placedCarriage = surface.create_entity {name = carriageDetails.name, position = placementPosition, direction = Utils.OrientationToDirection(carriageDetails.orientation), force = force}
        if carriageDetails.name == "locomotive" then
            placedCarriage.insert({name = "rocket-fuel", count = 10})
        end
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = TrainManagerFuncs.GetCarriagePlacementDistance(carriageDetails.name), y = 0}) -- Move placement position on by the back distance of the carriage thats just been placed. Then ready for the next carriage and its unique distance.

        -- Place the player in this carriage if set.
        if playerInCarriageNumber ~= nil and playerInCarriageNumber == carriageNumber then
            local player = game.connected_players[1]
            if player ~= nil then
                placedCarriage.set_driver(player)
            else
                game.print("No player found to set as driver, test continuing regardless")
            end
        end
    end

    local train = placedCarriage.train
    train.schedule = {
        current = 1,
        records = {
            {station = scheduleStation.backer_name}
        }
    }
    train.manual_mode = false
    TestFunctions.MakeCarriagesUnique(train.carriages)
    train.speed = startingSpeed

    return train
end

Test.CalculateExpectedResults = function(testScenario)
    local afterTrackRemovedResult, afterTrackReturnedResult

    -- Handle some Before Committed states as they are special logic.
    if testScenario.tunnelUsageType.name == TunnelUsageTypes.beforeCommitted.name then
        -- The before committed tunnel usage type trains are a special case.
        if testScenario.backwardsLocoCarriageNumber == 0 then
            -- Can't go backwards so always stop where they are.
            afterTrackRemovedResult = ResultStates.notReachTunnel
        else
            if testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.immediate then
                -- If they can reverse they can't have their carriages positions simply calculated, so flag to do at run time.
                afterTrackRemovedResult = ResultStates.beforeCommittedUnknownOutcome
            else
                -- No track to reverse on at this point.
                afterTrackRemovedResult = ResultStates.notReachTunnel
            end
        end
    end

    -- In most cases the afterTrackRemovedResult needs calculating.
    if afterTrackRemovedResult == nil then
        -- Work out if the train can reverse at its path broken state.
        local canTrainReverseAtTrackRemoved
        if testScenario.backwardsLocoCarriageNumber == 0 then
            -- No reverse locos so can never reverse.
            canTrainReverseAtTrackRemoved = false
        else
            -- The non before committed tunnel usage type trains can have their carriages simply calculated.
            -- The backest safe carriage position is 5 carriages to enter the tunnel or a carriage position 25 tiles from the portal position.
            local enteringTrainLengthAtReverseTime
            if testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageEntering.name then
                enteringTrainLengthAtReverseTime = #testScenario.carriages - (testScenario.reverseOnCarriageNumber - 1) -- While it occurs on the carriages removal, the entering train is in the same position as before the carraige was removed. Thus -1 from the number removed.
            elseif testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name then
                -- The tunnel is 10 carriages long.
                enteringTrainLengthAtReverseTime = (#testScenario.carriages - 10) - testScenario.reverseOnCarriageNumber
            else
                error("unsupported testScenario.tunnelUsageType.name: " .. testScenario.tunnelUsageType.name)
            end
            if enteringTrainLengthAtReverseTime >= 6 then
                canTrainReverseAtTrackRemoved = false
            else
                canTrainReverseAtTrackRemoved = true
            end
        end

        -- Apply the trains stopped position in working out expected state.
        if canTrainReverseAtTrackRemoved and testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.immediate then
            -- The train can get a path backwards as it can reverse in its current state and there is backwards track for it now.
            afterTrackRemovedResult = ResultStates.reachStation
        else
            -- The train can't get a path backwards.
            if testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name and testScenario.reverseOnCarriageNumber == #testScenario.carriages then
                -- Train has fully left and with no reverse loco it just stops here.
                afterTrackRemovedResult = ResultStates.stopPostTunnel
            elseif testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name and testScenario.reverseOnCarriageNumber >= 5 then
                -- 5+ carriages have left and so the lead carriage is past the point it would pull to end of portal. So with no reverse loco's the train just stops here
                afterTrackRemovedResult = ResultStates.stopPostTunnel
            else
                -- The train is leaving and hasn't reached the end of portal yet or hasn't started leavign yet, so pull forwards.
                afterTrackRemovedResult = ResultStates.pullToFrontOfTunnel
            end
        end
    end

    -- Work out if the train can conceptually path to the end station when track is added back (forwards or backwards) track. This doesn't account for if the train reached the station when the track was initially removed and so this second state result may be incompatible with some first state results.
    local conceptuallyCanReachEndStationWhenTrackAdded
    if afterTrackRemovedResult == ResultStates.reachStation then
        -- If it reached station on first check then it will still be there.
        afterTrackReturnedResult = ResultStates.reachStation
    elseif afterTrackRemovedResult == ResultStates.beforeCommittedUnknownOutcome then
        -- The first state couldn't be calculated, so neither can the second.
        afterTrackReturnedResult = ResultStates.beforeCommittedUnknownOutcome
    elseif testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed then
        -- Train can always pull forwards.
        conceptuallyCanReachEndStationWhenTrackAdded = true
    elseif testScenario.tunnelUsageType.name == TunnelUsageTypes.beforeCommitted.name then
        -- Before Committed is a special case.
        if testScenario.backwardsLocoCarriageNumber == 0 then
            -- No reverse locos so can never reverse.
            conceptuallyCanReachEndStationWhenTrackAdded = false
        elseif testScenario.backwardsPathingOptionAfterTunnelType ~= BackwardsPathingOptionAfterTunnelTypes.delayed then
            -- Never a route to reverse.
            conceptuallyCanReachEndStationWhenTrackAdded = false
        else
            -- Depending on where the train stopped it may be able to use the backwards rail.
            if testScenario.stationReservationCompetitorTrainExist then
                -- Competitor train exists and will have taken the end station reservation. So main train will be stuck in old state.
                afterTrackReturnedResult = afterTrackRemovedResult
            else
                -- No reservation competitor so main train could reach end station if its in the right place.
                afterTrackReturnedResult = ResultStates.beforeCommittedUnknownOutcome
            end
        end
    elseif testScenario.backwardsPathingOptionAfterTunnelType ~= BackwardsPathingOptionAfterTunnelTypes.none then
        -- Work out if the train can reverse when track is available. This is normally for delayed backwards track, but a long train entering may have to pull forwards to use the backwards route.
        if testScenario.backwardsLocoCarriageNumber == 0 then
            -- No reverse locos so can never reverse.
            conceptuallyCanReachEndStationWhenTrackAdded = false
        else
            -- The backest safe carriage position is 5 carriages to enter the tunnel or a carriage position 25 tiles from the portal position.
            local enteringTrainLengthAtTrackAddedTime
            if afterTrackRemovedResult == ResultStates.stopPostTunnel or afterTrackRemovedResult == ResultStates.notReachTunnel then
                -- Train will still be where it stopped earlier.
                if testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageEntering.name then
                    enteringTrainLengthAtTrackAddedTime = #testScenario.carriages - (testScenario.reverseOnCarriageNumber - 1) -- While it occurs on the carriages removal, the entering train is in the same position as before the carraige was removed. Thus -1 from the number removed.
                elseif testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name then
                    -- The tunnel is 10 carriages long.
                    enteringTrainLengthAtTrackAddedTime = (#testScenario.carriages - 10) - testScenario.reverseOnCarriageNumber
                end
            elseif afterTrackRemovedResult == ResultStates.pullToFrontOfTunnel then
                -- 4 full carriages will have left, work out unique train last carriage position from this.
                enteringTrainLengthAtTrackAddedTime = #testScenario.carriages - (4 + 10) -- This is likely a negative number as train has pulled to front of exit portal. But a very very long train could still be beyond reverse position.
            else
                error("shouldn't reach this state ever")
            end
            if enteringTrainLengthAtTrackAddedTime >= 6 then
                conceptuallyCanReachEndStationWhenTrackAdded = false
            else
                conceptuallyCanReachEndStationWhenTrackAdded = true
            end
        end
    end

    if afterTrackReturnedResult == nil then
        -- Work out post track added state based on type of track added back.
        if conceptuallyCanReachEndStationWhenTrackAdded then
            -- Train can get a path to end station if reservation can be re-obtained.
            if testScenario.stationReservationCompetitorTrainExist then
                -- Competitor train exists and wil have taken the end station reservation. So main train will be stuck in old state.
                afterTrackReturnedResult = afterTrackRemovedResult
            else
                -- No reservation competitor so main train should reach end station.
                afterTrackReturnedResult = ResultStates.reachStation
            end
        else
            -- No possible path back so will just stay as is.
            afterTrackReturnedResult = afterTrackRemovedResult
        end
    end

    -- Try to identify non positive tests.
    local isNonPositiveTest = false
    if (testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed and testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.delayed) or (testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.none and testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.none) then
        -- The forward and backwards added paths are both the same and so the overall test is redundant.
        isNonPositiveTest = true
    elseif testScenario.backwardsLocoCarriageNumber == 0 then
        -- No backwards carriage tests are often non positive outcomes.
        if testScenario.forwardsPathingOptionAfterTunnelType ~= ForwardsPathingOptionAfterTunnelTypes.delayed then
            -- no backwards locos and no forwards track is added so train can't go anywhere.
            isNonPositiveTest = true
        else
            -- Look through tests for duplicates on delayed forwards.
            for _, otherTest in pairs(Test.TestScenarios) do
                if otherTest.trainText == testScenario.trainText and otherTest.tunnelUsageType.name == testScenario.tunnelUsageType.name and otherTest.forwardsPathingOptionAfterTunnelType == testScenario.forwardsPathingOptionAfterTunnelType and otherTest.afterTrackRemovedResult == afterTrackRemovedResult and otherTest.afterTrackReturnedResult == afterTrackReturnedResult then
                    isNonPositiveTest = true
                    break
                end
            end
        end
    elseif testScenario.tunnelUsageType.name ~= TunnelUsageTypes.beforeCommitted.name then
        -- For reversable train tests look through other tests for duplicates outcomes when only difference is the reverse on carriage count.
        for _, otherTest in pairs(Test.TestScenarios) do
            local differenceOtherThanCarriageCount = false
            for otherTestKey in pairs(otherTest) do
                if otherTestKey == "reverseOnCarriageNumber" or otherTestKey == "carriages" or otherTestKey == "isNonPositiveTest" then
                    -- Ignore these keys as invlaid to compare.
                    differenceOtherThanCarriageCount = false
                elseif otherTestKey == "afterTrackRemovedResult" then
                    -- Check local variable as not recorded to test.
                    if afterTrackRemovedResult ~= otherTest[otherTestKey] then
                        differenceOtherThanCarriageCount = true
                        break
                    end
                elseif otherTestKey == "afterTrackReturnedResult" then
                    -- Check local variable as not recorded to test.
                    if afterTrackReturnedResult ~= otherTest[otherTestKey] then
                        differenceOtherThanCarriageCount = true
                        break
                    end
                elseif otherTestKey == "tunnelUsageType" then
                    -- Have to gets its name attribute for comparison.
                    if testScenario[otherTestKey].name ~= otherTest[otherTestKey].name then
                        differenceOtherThanCarriageCount = true
                        break
                    end
                elseif testScenario[otherTestKey] ~= otherTest[otherTestKey] then
                    -- Is a stadnard key/value and can just compare.
                    differenceOtherThanCarriageCount = true
                    break
                end
            end
            if not differenceOtherThanCarriageCount then
                isNonPositiveTest = true
                break
            end
        end
    end
    if testScenario.playerInCarriageNumber ~= nil then
        -- All player riding duplicate tests are low priority.
        isNonPositiveTest = true
    end

    return afterTrackRemovedResult, afterTrackReturnedResult, isNonPositiveTest
end

Test.HandleBeforeCommittedUnknownOutcome = function(tunnelUsageEntry, testData)
    -- Handle the weird case when the final state couldn't be calculated in advance. So look at where the train is as initial track is removed and then update its expected result to compare against. This result will only be present for Abort Before Committed trains and the train test allows reversing.
    local testScenario = testData.testScenario

    local rearCarriage
    if tunnelUsageEntry.enteringTrain.speed > 0 then
        rearCarriage = tunnelUsageEntry.enteringTrain.back_stock
    else
        rearCarriage = tunnelUsageEntry.enteringTrain.front_stock
    end

    -- Some tests have a known initial track removed expected result, but then not the track added expected result.
    if testScenario.afterTrackRemovedResult == ResultStates.beforeCommittedUnknownOutcome then
        -- The backest safe carriage position is 5 carriages to enter the tunnel or a carriage position 25 tiles from the portal position.
        if rearCarriage.position.x > (testData.enteringPortal.position.x + 25) then
            -- Rear of train position prevents use of reversing track.
            testScenario.afterTrackRemovedResult = ResultStates.notReachTunnel
        else
            -- Train can use reversing track.
            if testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.immediate then
                -- The reversing track is present.
                testScenario.afterTrackRemovedResult = ResultStates.reachStation
                testScenario.afterTrackReturnedResult = ResultStates.reachStation
            else
                testScenario.afterTrackRemovedResult = ResultStates.notReachTunnel
            end
        end
    end

    -- Work out the post track added state if not set properly.
    if testScenario.afterTrackReturnedResult == ResultStates.beforeCommittedUnknownOutcome then
        local trainHasPathAfterTrackAdded
        if testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed then
            trainHasPathAfterTrackAdded = true
        elseif testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.delayed then
            if rearCarriage.position.x > (testData.enteringPortal.position.x + 25) then
                -- Rear of train position prevents use of reversing track.
                trainHasPathAfterTrackAdded = false
            else
                -- Train can use reversing track.
                trainHasPathAfterTrackAdded = true
            end
        end

        if not trainHasPathAfterTrackAdded then
            testScenario.afterTrackReturnedResult = ResultStates.notReachTunnel
        else
            if testScenario.stationReservationCompetitorTrainExist then
                -- Station reservation lost to other train.
                testScenario.afterTrackReturnedResult = ResultStates.notReachTunnel
            else
                testScenario.afterTrackReturnedResult = ResultStates.reachStation
            end
        end
    end

    game.print("newly calculated expected results: " .. testScenario.afterTrackRemovedResult .. " - " .. testScenario.afterTrackReturnedResult, Colors.cyan)
end

Test.WriteTestScenariosToFile = function()
    -- A debug function to write out the tests list to a csv for checking in excel.
    if not DebugOutputTestScenarioDetails or game == nil then
        -- game will be nil on loading a save.
        return
    end

    -- Ignores playerInCarriageNumber
    local fileName = "TestScenarios.csv"
    game.write_file(fileName, "#,train,tunnelUsage,reverseNumber,lastBackwardsLoco,forwardsPathingOption,backwardsPathingOption,competitorTrain,afterTrackRemovedResult,afterTrackReturnedResult" .. "\r\n", false)

    for testIndex, test in pairs(Test.TestScenarios) do
        game.write_file(fileName, tostring(testIndex) .. "," .. tostring(test.trainText) .. "," .. tostring(test.tunnelUsageType.name) .. "," .. tostring(test.reverseOnCarriageNumber) .. "," .. tostring(test.backwardsLocoCarriageNumber) .. "," .. tostring(test.forwardsPathingOptionAfterTunnelType) .. "," .. tostring(test.backwardsPathingOptionAfterTunnelType) .. "," .. tostring(test.stationReservationCompetitorTrainExist) .. "," .. tostring(test.afterTrackRemovedResult) .. "," .. tostring(test.afterTrackReturnedResult) .. "\r\n", true)
    end
end

return Test
