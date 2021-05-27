--[[
    Does a range of tests for the different situations of a train trying to reverse down a tunnel when a piece of track after the tunnel is removed:
        - Train types (heading west): <, <----, ----<, <>, <-->, <>----, ----<>
        - Leaving track removed: before committed, once committed (full train still), as each carriage enters the tunnel, when train fully in tunnel, after each carriage leaves the tunnel, when the full trian has left the tunel.
        - Reverse track path being present at start, added after a delay or never. Forwards track being returned after a delay or never.
        - Player riding in no carriage, first carriage or last carriage.
    Theres a second train trying to path to the same station with a train limit of 1. This second train should never move if the reservation isn't lost. Some tests it is expected to move.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")
local TrainManagerFuncs = require("scripts/train-manager-functions")

local ExcludeNonPositiveOutcomes = true -- If TRUE Skips some believed non positive outcome tests where the result is expected to be the same as others (redundant). These should be run occasioanlly, but shouldn't be needed for smaller code changes. Examples include reverse tests for trains with no backwards locos or per carriage tests when the expected outcome is the same.
local DoSpecificTrainTests = true -- If enabled does the below specific train tests, rather than the full test suite. used for adhock testing.
local SpecificTrainTypesFilter = {"<", "<>", "<------", "<>------"} -- Pass in array of TrainTypes text (--<--) to do just those. Leave as nil or empty table for all train types. Only used when DoSpecificTrainTests is true.
local SpecificTunnelUsageTypesFilter = {
    "beforeCommitted",
    "carriageEntering",
    "carriageLeaving"
} -- Pass in array of TunnelUsageTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTrainTests is true.
local SpecificReverseOnCarriageNumberFilter = {} -- Pass in an array of carriage numbers to reverse on to do just those specific carriage tests. Leave as nil or empty table for all carriages in train. Only used when DoSpecificTrainTests is true.
local SpecificPlayerInCarriageTypesFilter = {"none"} -- Pass in array of PlayerInCarriageTypes keys to do just those. Leave as nil or empty table for all player riding scenarios. Only used when DoSpecificTrainTests is true.
local SpecificForwardsPathingOptionAfterTunnelTypesFilter = {} -- Pass in array of ForwardsPathingOptionAfterTunnelTypes keys to do just those specific forwards pathing option tests. Leave as nil or empty table for all forwards pathing tests. Only used when DoSpecificTrainTests is true.
local SpecificBackwardsPathingOptionAfterTunnelTypesFilter = {} -- Pass in array of BackwardsPathingOptionAfterTunnelTypes keys to do just those specific backwards pathing option tests. Leave as nil or empty table for all backwards pathing tests. Only used when DoSpecificTrainTests is true.
local SpecificStationReservationCompetitorTrainExists = {} -- Pass in array of true/fale to do just those specific reservation competitor train exists tests. Leave as nil or empty table for both combinations of the reservation competitor existing tests. Only used when DoSpecificTrainTests is true.

Test.RunTime = 1200
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
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

-- Blueprint is just track, tunnel and stations. No train as these are dynamicly placed.
local blueprintString = "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"

-- Orientation 0.75 is forwards, 0.25 is backwards.
-- Trains should be 6+ carriages long as otherwise when entering they never go longer than the backwards track points.
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
                orientation = 0.75,
                count = 6
            }
        }
    },
    {
        text = "------><",
        carriages = {
            {
                name = "cargo-wagon",
                orientation = 0.25,
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
                orientation = 0.25,
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
                orientation = 0.75,
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
        }
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
    stopPostTunnel = "stopPostTunnel" -- has left the tunnel when path removed and can't get back to station, so just stops where it is.
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

    local displayName = testName .. "     " .. testScenario.trainText .. "     " .. testScenario.tunnelUsageType.name .. carriageText .. "    forwards path " .. testScenario.forwardsPathingOptionAfterTunnelType .. "    backwards path " .. testScenario.backwardsPathingOptionAfterTunnelType .. reservationCompetitorText .. playerInCarriageText .. "    Expected results: " .. testScenario.afterTrackRemovedResult .. " - " .. testScenario.afterTrackReturnedResult

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

    local forwardsTrackToRemove = stationEnd.surface.find_entity("straight-rail", {x = leavingPortal.position.x - 72, y = leavingPortal.position.y - 12})
    local forwardsTrackToAddPosition = forwardsTrackToRemove.position
    local backwardsTrackToRemove = stationEnd.surface.find_entity("straight-rail", {x = enteringPortal.position.x + 38, y = enteringPortal.position.y - 12})
    local backwardsTrackToAddPosition = backwardsTrackToRemove.position

    local train = Test.BuildTrain(stationStart, testScenario.carriages, stationEnd, testScenario.playerInCarriageNumber)

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
    testData.lastTrainAction = nil -- Populated by the last TunnelUsageChanged action.
    testData.lastTrainChangeReason = nil -- Populated by the last TunnelUsageChanged changeReason.
    testData.previousTrainAction = nil -- Populated by the previous (last + 1) TunnelUsageChanged action.
    testData.previousTrainChangeReason = nil -- Populated by the previous (last + 1) TunnelUsageChanged changeReason.

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    if testData.managedTrainId == 0 then
        -- No tunnel use yet so just skip.
        return
    end
    if not testData.forwardsTrackRemoved then
        -- Only check for states after track removed.
        return
    end

    local endStationTrain = testData.stationEnd.get_stopped_train()
    local trackShouldBeAddedNow = false
    if not testData.trackAdded then
        -- Initial state monitoring after the the forwards track was removed and before any track added back.
        if testData.testScenario.afterTrackRemovedResult == ResultStates.notReachTunnel then
            -- This outcome can be checked instantly after the path out of tunnel broken. As the train never entered the tunnel the old testData.train reference should be valid still.
            -- Depending on exactly where the train stopped its makeup and its length it may/not be able to reach the end station. So can't check this at present.
            if testData.train == nil or not testData.train.valid then
                TestFunctions.TestFailed(testName, "train reference should still exist from test start")
                return
            else
                local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(testData.train)
                if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
                    TestFunctions.TestFailed(testName, "train has differences")
                    return
                end
            end
            -- See if we have moved past the start approaching action on to another action. If not moved passed start approaching then continue the test.
            if testData.previousTrainAction == "startApproaching" then
                -- Check latest action is the expected one.
                if testData.lastTrainAction == "terminated" and testData.lastTrainChangeReason == "abortedApproach" then
                    trackShouldBeAddedNow = true
                else
                    TestFunctions.TestFailed(testName, "last tunnel usage state wasn't abortedApproach")
                end
            end
        elseif testData.testScenario.afterTrackRemovedResult == ResultStates.pullToFrontOfTunnel then
            local inspectionArea = {left_top = {x = testData.leavingPortal.position.x - 20, y = testData.leavingPortal.position.y}, right_bottom = {x = testData.leavingPortal.position.x - 18, y = testData.leavingPortal.position.y}} -- Inspection area needs to find trains that have pulled to the end of the tunnel.
            local trainFound = TestFunctions.GetTrainInArea(inspectionArea)
            if not trainFound then
                return
            end
            if testData.reservationCompetitorTrain ~= nil then
                -- Reservation should be taken by other train.
                if trainFound.state == defines.train_state.destination_full and trainFound.speed == 0 then
                    -- The reservation competitor train will have taken the reservation and so the main train is in the reservation queue when it stops. The main train won't realise its going to no path until it tries to get a reservation which it never will as the target train stop will always be fully reserved.
                    if testData.reservationCompetitorTrain ~= nil and testData.reservationCompetitorTrain.state == defines.train_state.destination_full then
                        TestFunctions.TestFailed(testName, "reservation competitor train should have got a reservation to the end station as the main train lost its")
                    end
                    trackShouldBeAddedNow = true
                elseif endStationTrain ~= nil then
                    if endStationTrain.id ~= testData.reservationCompetitorTrain.id then
                        -- If a train other than the reservation competitor train reaches the end station something has gone wrong. The reservation competitor train can move in this test as the main train's path and reservation is expected to be lost.
                        TestFunctions.TestFailed(testName, "train reached end station")
                    end
                end
            else
                -- No competition for reservation.
                if endStationTrain ~= nil then
                    -- Nothing should reach the end station.
                    TestFunctions.TestFailed(testName, "train reached end station")
                end
                if trainFound.state == defines.train_state.no_path and trainFound.speed == 0 then
                    -- The main train no paths as it can try to path after getting back its reservation.
                    trackShouldBeAddedNow = true
                end
            end
        elseif testData.testScenario.afterTrackRemovedResult == ResultStates.reachStation then
            if endStationTrain ~= nil then
                if testData.reservationCompetitorTrain ~= nil and not Utils.ArePositionsTheSame(testData.reservationCompetitorTrain.carriages[1].position, testData.reservationCompetitorTrainCarriage1StartingPosition) then
                    TestFunctions.TestFailed(testName, "reservation competitor train wasn't where it started")
                    return
                end
                if testData.reservationCompetitorTrain ~= nil and testData.reservationCompetitorTrain.state ~= defines.train_state.destination_full then
                    TestFunctions.TestFailed(testName, "reservation competitor train wasn't in desitination full state")
                    return
                end
                local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(endStationTrain)
                if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
                    TestFunctions.TestFailed(testName, "train reached station, but with train differences")
                    return
                end
                trackShouldBeAddedNow = true
            end
        elseif testData.testScenario.afterTrackRemovedResult == ResultStates.stopPostTunnel then
            local inspectionArea = {left_top = {x = testData.leavingPortal.position.x + 5, y = testData.leavingPortal.position.y}, right_bottom = {x = testData.leavingPortal.position.x + 10, y = testData.leavingPortal.position.y}} -- Inspection area needs to find trains that were fully left and then just stopped dead. So a carraige will be right after leaving the portal if the train stopped at this time.
            local trainFound = TestFunctions.GetTrainInArea(inspectionArea)
            if not trainFound then
                return
            end
            if testData.reservationCompetitorTrain ~= nil then
                if trainFound.state == defines.train_state.destination_full and trainFound.speed == 0 then
                    -- The reservation competitor train will have taken the reservation and so the main train is in the reservation queue when it stops. The main train won't realise its going to no path until it tries to get a reservation which it never will as the target train stop will always be fully reserved.
                    if testData.reservationCompetitorTrain.state == defines.train_state.destination_full then
                        TestFunctions.TestFailed(testName, "reservation competitor train should have got a reservation to the end station as the main train lost its")
                    end
                    trackShouldBeAddedNow = true
                elseif endStationTrain ~= nil then
                    if endStationTrain.id ~= testData.reservationCompetitorTrain.id then
                        -- If a train other than the reservation competitor train reaches the end station something has gone wrong. The reservation competitor train can move in this test as the main train's path and reservation is expected to be lost.
                        TestFunctions.TestFailed(testName, "train reached end station")
                    end
                end
            else
                if trainFound.state == defines.train_state.no_path and trainFound.speed == 0 then
                    -- The main train will no path as it is able to get a reservation without any competition for the station.
                    trackShouldBeAddedNow = true
                end
            end
        else
            error("unsupported testScenario.afterTrackRemovedResult: " .. testData.testScenario.afterTrackRemovedResult)
        end
    end

    if testData.trackAdded then
        if 1 == 1 then
            -- TODO: needs populating. Also first states aren't extensively tested.
            game.print("after track ADDED result reached: " .. testData.testScenario.afterTrackReturnedResult)
            TestFunctions.TestCompleted(testName)
        end
    end

    if trackShouldBeAddedNow then
        -- Once the main train has reched the expected state after the forwards track was removed we then add any track back in to let the train recover. Done after the second state check so the main trian has a tick to change its state before inspection.
        local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
        testData.trackAdded = true
        if testData.testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed then
            surface.create_entity({name = "straight-rail", position = testData.forwardsTrackToAddPosition, direction = defines.direction.north, force = force})
        end
        if testData.testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.delayed then
            surface.create_entity({name = "straight-rail", position = testData.backwardsTrackToAddPosition, direction = defines.direction.north, force = force})
        end
        game.print("after track REMOVED result reached: " .. testData.testScenario.afterTrackRemovedResult)
    end
end

Test.TunnelUsageChanged = function(event)
    local testName, testData = event.testName, TestFunctions.GetTestDataObject(event.testName)
    if testData.managedTrainId == 0 and event.action == "startApproaching" and testData.train.id == event.enteringTrain.id then
        -- Keep hold of managed train id.
        testData.managedTrainId = event.tunnelUsageId
    end
    if testData.managedTrainId ~= event.tunnelUsageId then
        if event.replacedtunnelUsageId ~= nil and testData.managedTrainId == event.replacedtunnelUsageId then
            -- Train tunnel usage entry has been replaced by another one.
            testData.managedTrainId = event.tunnelUsageId
            testData.oldManagedTrainId = event.replacedtunnelUsageId
        elseif testData.oldManagedTrainId == event.tunnelUsageId then
            -- This old managed train id is expected and can be ignored entirely.
            return
        else
            TestFunctions.TestFailed(testName, "tunnel event for unexpected train id received")
        end
    end
    local testTunnelUsageType = testData.testScenario.tunnelUsageType
    testData.previousTrainAction, testData.previousTrainChangeReason = testData.lastTrainAction, testData.lastTrainChangeReason
    testData.lastTrainAction, testData.lastTrainChangeReason = event.action, event.changeReason

    if testData.forwardsTrackRemoved then
        -- This change can never lead to track removal state and the last action and change reason have been recorded.
        return
    end

    -- Check test type and usage change type to see if the desired state has been reached.
    if testTunnelUsageType.name == TunnelUsageTypes.beforeCommitted.name then
        if event.action ~= "startApproaching" then
            return
        end
    elseif testTunnelUsageType.name == TunnelUsageTypes.carriageEntering.name then
        if event.action ~= "enteringCarriageRemoved" then
            return
        else
            -- reverseOnCarriageNumber counts the carriage number manipulated, but enteringTrain is post carriage removal.
            local trainCarriageCount
            if event.enteringTrain ~= nil then
                trainCarriageCount = #testData.testScenario.carriages - #event.enteringTrain.carriages
            else
                trainCarriageCount = #testData.testScenario.carriages
            end
            if (testData.testScenario.reverseOnCarriageNumber) ~= trainCarriageCount then
                return
            end
        end
    elseif testTunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name then
        if event.action ~= "leavingCarriageAdded" then
            return
        else
            local carriagesToIgnore = remote.call("railway_tunnel", "get_temporary_carriage_names")
            local leavingTrainFakeCarriages = Utils.GetTableValueWithInnerKeyValue(event.leavingTrain.carriages, "name", carriagesToIgnore, true, true)
            if (testData.testScenario.reverseOnCarriageNumber) ~= (#event.leavingTrain.carriages - #leavingTrainFakeCarriages) then
                return
            end
        end
    end

    -- If not returned then this is the correct state to remove the rail.
    game.print("train reached track removal state")
    testData.forwardsTrackToRemove.destroy()
    testData.forwardsTrackRemoved = true
end

Test.GenerateTestScenarios = function()
    local trainTypesToTest, tunnelUsageTypesToTest, playerInCarriagesTypesToTest, forwardsPathingOptionAfterTunnelTypesToTest, backwardsPathingOptionAfterTunnelTypesToTest, stationReservationCompetitorTrainExistsToTest

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
            playerInCarriagesTypesToTest = PlayerInCarriageTypes
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
        playerInCarriagesTypesToTest = PlayerInCarriageTypes
        forwardsPathingOptionAfterTunnelTypesToTest = ForwardsPathingOptionAfterTunnelTypes
        backwardsPathingOptionAfterTunnelTypesToTest = BackwardsPathingOptionAfterTunnelTypes
        stationReservationCompetitorTrainExistsToTest = StationReservationCompetitorTrainExists
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
                        if Utils.IsTableEmpty(SpecificReverseOnCarriageNumberFilter) then
                            -- Do all carriage numbers in this train.
                            for carriageCount = 1, maxCarriageCount do
                                table.insert(carriageNumbersToTest, carriageCount)
                            end
                        else
                            carriageNumbersToTest = SpecificReverseOnCarriageNumberFilter
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
                                    stationReservationCompetitorTrainExist = stationReservationCompetitorTrainExist
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
end

Test.BuildTrain = function(buildStation, carriagesDetails, scheduleStation, playerInCarriageNumber)
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

    return train
end

Test.CalculateExpectedResults = function(testScenario)
    local afterTrackRemovedResult, afterTrackReturnedResult

    -- Work out if the train can reverse at its path broken state.
    local canTrainReverseAtTrackRemoved
    if testScenario.backwardsLocoCarriageNumber == 0 then
        -- No reverse locos so can never reverse.
        canTrainReverseAtTrackRemoved = false
    elseif testScenario.tunnelUsageType.name ~= TunnelUsageTypes.beforeCommitted.name then
        -- The non before committed tunnel usage type trains can have their carriages simply calculated.
        -- The backest safe carriage position is 5 carriages to enter the tunnel or a carriage position 25 tiles from the portal position.
        local enteringTrainLengthAtReverseTime
        if testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageEntering.name then
            enteringTrainLengthAtReverseTime = #testScenario.carriages - testScenario.reverseOnCarriageNumber
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
    else
        -- The before committed tunnel usage type trains can't have their carriages simply calculated.
        canTrainReverseAtTrackRemoved = false -- TODO: This is wrong, but don't know how to calculate it.
    end

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

    -- Work out if the train can conceptually path to the end station when track is added back (forwards or backwards) track.
    local conceptuallyCanReachEndStationWhenTrackAdded
    if testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed then
        conceptuallyCanReachEndStationWhenTrackAdded = true
    elseif testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.delayed then
        -- Work out if the train can reverse when track is added back.
        if testScenario.backwardsLocoCarriageNumber == 0 then
            -- No reverse locos so can never reverse.
            conceptuallyCanReachEndStationWhenTrackAdded = false
        else
            -- The backest safe carriage position is 5 carriages to enter the tunnel or a carriage position 25 tiles from the portal position.
            -- TODO: work out where the train would have stopped based on afterTrackRemovedResult and then use that below. At present this code gives irrelevnt outcome.
            local enteringTrainLengthAtTrackAddedTime
            if testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageEntering.name then
                enteringTrainLengthAtTrackAddedTime = #testScenario.carriages - testScenario.reverseOnCarriageNumber
            elseif testScenario.tunnelUsageType.name == TunnelUsageTypes.carriageLeaving.name then
                -- The tunnel is 10 carriages long.
                enteringTrainLengthAtTrackAddedTime = (#testScenario.carriages - 10) - testScenario.reverseOnCarriageNumber
            end
            if enteringTrainLengthAtTrackAddedTime >= 6 then
                conceptuallyCanReachEndStationWhenTrackAdded = false
            else
                conceptuallyCanReachEndStationWhenTrackAdded = true
            end
        end
    end

    if conceptuallyCanReachEndStationWhenTrackAdded then
        -- Train can get a path to end station if reservation can be re-obtained.
        if testScenario.stationReservationCompetitorTrainExist ~= nil then
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

    -- Try to identify pointless tests.
    local isNonPositiveTest = false
    if (testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.delayed and testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.delayed) or (testScenario.forwardsPathingOptionAfterTunnelType == ForwardsPathingOptionAfterTunnelTypes.none and testScenario.backwardsPathingOptionAfterTunnelType == BackwardsPathingOptionAfterTunnelTypes.none) then
        -- The forward and backwards added paths are both the same and so the overall test is redundant.
        isNonPositiveTest = true
    elseif testScenario.backwardsLocoCarriageNumber == 0 then
        -- No backwards carriage tests are ideal as non positive outcomes.
        if testScenario.forwardsPathingOptionAfterTunnelType ~= ForwardsPathingOptionAfterTunnelTypes.delayed then
            -- no backwards locos and no forwards track is added so train can't go anywhere.
            isNonPositiveTest = true
        else
            -- Look through tests for duplicates on delayed forwards.
            for _, otherTest in pairs(Test.TestScenarios) do
                -- and otherTest.xxx == testScenario.xxx
                if otherTest.trainText == testScenario.trainText and otherTest.tunnelUsageType.name == testScenario.tunnelUsageType.name and otherTest.forwardsPathingOptionAfterTunnelType == testScenario.forwardsPathingOptionAfterTunnelType then
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

    return afterTrackRemovedResult, afterTrackReturnedResult, isNonPositiveTest
end

return Test
