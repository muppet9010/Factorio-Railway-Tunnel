--[[
    Does a range of tests for the different situations of a train trying to reverse down a tunnel when a piece of track after the tunnel is removed:
        - Train types (heading west): <, <----, ----<, <>, <-->, <>----, ----<>
        - Leaving track removed: before committed, once committed (full train still), as each carriage enters the tunnel, when train fully in tunnel, after each carriage leaves the tunnel, when the full trian has left the tunel.
    Theres a second train trying to path to the same station with a train limit of 1. This second train should never move if the reservation isn't lost.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")
local TrainManagerFuncs = require("scripts/train-manager-functions")

local DoSpecificTrainTests = true -- If enabled does the below specific train tests, rather than the full test suite. used for adhock testing.
local SpecificTrainTypesFilter = {"><"} -- Pass in array of TrainTypes text (--<--) to do just those. Leave as nil or empty table for all train types. Only used when DoSpecificTrainTests is true.
local SpecificTunnelUsageTypesFilter = {
    --"beforeCommitted",
    --"carriageEntering",
    "carriageLeaving"
} -- Pass in array of TunnelUsageType keys to do just those. Leave as nil or empty table for all tests. Only used when DoSpecificTrainTests is true.

Test.RunTime = 1200
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        trainText = trainType.text so the train makeup in symbols.
        carriages = fully populated list of carriage requirements from trainType.carriages.
        tunnelUsageType = TunnelUsageType object reference for the test.
        reverseOnCarriageNumber = the carriage number to reverse the train on. For non perCarriage tests (TunnelUsageType) this value will be ignored.
        backwardsLocoCarriageNumber = the carriage number of the backwards facing loco. Will be 0 for trains with no backwards locos.
        expectedResult = the expected result of this test (ResultStates).
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

-- Blueprint is just track, tunnel and stations. No train as these are dynamicly placed.
local blueprintString =
    "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"

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
                orientation = 0.25
            }
        }
    }
}
local TunnelUsageType = {
    beforeCommitted = {name = "beforeCommitted", perCarriage = false},
    carriageEntering = {name = "carriageEntering", perCarriage = true}, -- This can overlap with carriageLeaving.
    carriageLeaving = {name = "carriageLeaving", perCarriage = true} -- This can overlap with carriageEntering.
}
local ResultStates = {
    NotReachTunnel = "NotReachTunnel",
    PullToFrontOfTunnel = "PullToFrontOfTunnel",
    ReachStation = "ReachStation"
}

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local carriageText = ""
    if testScenario.tunnelUsageType.perCarriage then
        carriageText = "     carriage " .. testScenario.reverseOnCarriageNumber
    end
    local displayName = testName .. "     " .. testScenario.trainText .. "     " .. testScenario.tunnelUsageType.name .. carriageText

    return displayName
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd, stationStart, stationStayHere
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        elseif stationEntity.backer_name == "Start" then
            stationStart = stationEntity
        elseif stationEntity.backer_name == "StayHere" then
            stationStayHere = stationEntity
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

    local trackToRemove = stationEnd.surface.find_entity("straight-rail", {x = leavingPortal.position.x - 60, y = leavingPortal.position.y})

    local train = Test.BuildTrain(stationStart, testScenario.carriages, stationEnd)

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationStart = stationStart
    testData.stationEnd = stationEnd
    testData.stationStayHere = stationStayHere
    testData.trackToRemove = trackToRemove
    testData.trackRemoved = false
    testData.enteringPortal = enteringPortal
    testData.leavingPortal = leavingPortal
    testData.train = train
    testData.stayHereTrain = stationStayHere.get_train_stop_trains()[1]
    testData.stayHereTrainCarriage1StartingPosition = testData.stayHereTrain.carriages[1].position
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.managedTrainId = 0 -- Tracks current managed train id for tunnel usage.
    testData.oldManagedTrainId = 0 -- Tracks any old (replaced) managed train id's for ignoring their events (not erroring as unexpected).
    testData.testScenario = testScenario
    testData.lastTrainAction = nil -- Populated by the last TunnelUsageChanged action.
    testData.lastTrainChangeReason = nil -- Populated by the last TunnelUsageChanged changeReason.
    testData.previousTrainAction = nil -- Populated by the previous (last + 1) TunnelUsageChanged action.
    testData.previousTrainChangeReason = nil -- Populated by the previous (last + 1) TunnelUsageChanged changeReason.

    game.print("Expected test result: " .. testData.testScenario.expectedResult)

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
    if not testData.trackRemoved then
        -- Only check for states after track removed.
        return
    end

    local endStationTrain = testData.stationEnd.get_stopped_train()
    if testData.testScenario.expectedResult == ResultStates.NotReachTunnel then
        -- This outcome can be checked instantly after the path out of tunnel broken. As the train never entered the tunnel the old testData.train reference should be valid still.
        -- Depending on exactly where the train stopped and its length it may/not be able to reach the end station. So can't check this at present.
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
        if testData.previousTrainAction == "StartApproaching" then
            -- Check latest action is the expected one.
            if testData.lastTrainAction == "Terminated" and testData.lastTrainChangeReason == "AbortedApproach" then
                TestFunctions.TestCompleted(testName)
            else
                TestFunctions.TestFailed(testName, "last tunnel usage state wasn't AbortedApproach")
            end
        end
    elseif testData.testScenario.expectedResult == ResultStates.PullToFrontOfTunnel then
        local inspectionArea = {left_top = {x = testData.leavingPortal.position.x - 20, y = testData.leavingPortal.position.y}, right_bottom = {x = testData.leavingPortal.position.x - 18, y = testData.leavingPortal.position.y}}
        local carriagesInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {area = inspectionArea, name = {"locomotive", "cargo-wagon"}, limit = 1}
        local carriageFound, trainFound = carriagesInInspectionArea[1], nil
        if carriageFound ~= nil then
            trainFound = carriageFound.train
        end
        if trainFound == nil then
            return
        end
        if trainFound.state == defines.train_state.path_lost then
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(endStationTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, false) then
                TestFunctions.TestFailed(testName, "train pulled to front of tunnel, but with train differences in the emerged train so far")
                return
            end
            TestFunctions.TestCompleted(testName)
        elseif endStationTrain ~= nil then
            TestFunctions.TestFailed(testName, "train reached end station")
        end
    elseif testData.testScenario.expectedResult == ResultStates.ReachStation then
        if endStationTrain ~= nil then
            if not Utils.ArePositionsTheSame(testData.stayHereTrain.carriages[1].position, testData.stayHereTrainCarriage1StartingPosition) then
                TestFunctions.TestFailed(testName, "Stay Here train wasn't where it started")
                return
            end
            if testData.stayHereTrain.state ~= defines.train_state.destination_full then
                TestFunctions.TestFailed(testName, "Stay Here train wasn't in desitination full state")
                return
            end
            local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(endStationTrain)
            if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
                TestFunctions.TestFailed(testName, "train reached station, but with train differences")
                return
            end
            TestFunctions.TestCompleted(testName)
        end
    end
end

Test.TunnelUsageChanged = function(event)
    local testName, testData = event.testName, TestFunctions.GetTestDataObject(event.testName)
    if testData.managedTrainId == 0 and event.action == "StartApproaching" and testData.train.id == event.enteringTrain.id then
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

    if testData.trackRemoved then
        -- This change can never lead to track removal state and the last action and change reason have been recorded.
        return
    end

    -- Check test type and usage change type to see if the desired state has been reached.
    if testTunnelUsageType.name == TunnelUsageType.beforeCommitted.name then
        if event.action ~= "StartApproaching" then
            return
        end
    elseif testTunnelUsageType.name == TunnelUsageType.carriageEntering.name then
        if event.action ~= "EnteringCarriageRemoved" then
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
    elseif testTunnelUsageType.name == TunnelUsageType.carriageLeaving.name then
        if event.action ~= "LeavingCarriageAdded" then
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
    testData.trackToRemove.destroy()
    testData.trackRemoved = true
end

Test.GenerateTestScenarios = function()
    local trainTypesToTest, tunnelUsageTypesToTest

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
            tunnelUsageTypesToTest = TunnelUsageType
        else
            tunnelUsageTypesToTest = {}
            for _, usageTypeName in pairs(SpecificTunnelUsageTypesFilter) do
                tunnelUsageTypesToTest[usageTypeName] = TunnelUsageType[usageTypeName]
            end
        end
    else
        -- Full testing suite.
        trainTypesToTest = TrainTypes
        tunnelUsageTypesToTest = TunnelUsageType
    end

    -- Do each iteration of train type and tunnel usage. Each wagon entering/leaving the tunnel is a test.
    for _, trainType in pairs(trainTypesToTest) do
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
                    reverseOnCarriageNumber = carriageCount, -- On non perCarriage tests this value will be ignored.
                    backwardsLocoCarriageNumber = backwardsLocoCarriageNumber
                }
                scenario.expectedResult = Test.CalculateExpectedResult(scenario)

                Test.RunLoopsMax = Test.RunLoopsMax + 1
                table.insert(Test.TestScenarios, scenario)
            end
        end
    end
end

Test.BuildTrain = function(buildStation, carriagesDetails, scheduleStation)
    -- Build the train from the station heading west. Give each loco fuel, set target schedule and to automatic.
    local placedCarriage
    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local placementPosition = Utils.ApplyOffsetToPosition(buildStation.position, {x = -0.5, y = 2}) -- offset to position first carriage correctly.
    for i, carriageDetails in pairs(carriagesDetails) do
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = TrainManagerFuncs.GetCarriagePlacementDistance(carriageDetails.name), y = 0}) -- Move placement position on by the front distance of the carriage to be placed, prior to its placement.
        placedCarriage = surface.create_entity {name = carriageDetails.name, position = placementPosition, direction = Utils.OrientationToDirection(carriageDetails.orientation), force = force}
        if carriageDetails.name == "locomotive" then
            placedCarriage.insert({name = "rocket-fuel", count = 10})
        end
        placementPosition = Utils.ApplyOffsetToPosition(placementPosition, {x = TrainManagerFuncs.GetCarriagePlacementDistance(carriageDetails.name), y = 0}) -- Move placement position on by the back distance of the carriage thats just been placed. Then ready for the next carriage and its unique distance.
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

Test.CalculateExpectedResult = function(testScenario)
    if testScenario.tunnelUsageType.name == TunnelUsageType.beforeCommitted.name then
        -- Train hasn't committed to using the tunnel. So no other checks are needed.
        return ResultStates.NotReachTunnel
    end

    if testScenario.backwardsLocoCarriageNumber == 0 then
        -- No reversing loco in train. So no other checks are needed.
        return ResultStates.PullToFrontOfTunnel
    end

    -- The backest safe carriage position is 5 carriages to enter the tunnel or a carriage position 25 tiles from the portal position.
    local enteringTrainLengthAtReverseTime
    if testScenario.tunnelUsageType.name == TunnelUsageType.carriageEntering.name then
        enteringTrainLengthAtReverseTime = #testScenario.carriages - testScenario.reverseOnCarriageNumber
    elseif testScenario.tunnelUsageType.name == TunnelUsageType.carriageLeaving.name then
        -- The tunnel is 10 carriages long.
        enteringTrainLengthAtReverseTime = (#testScenario.carriages - 10) - testScenario.reverseOnCarriageNumber
    end
    if enteringTrainLengthAtReverseTime > 5 then
        -- Rear of train is right (wrong) side of reverse curve.
        return ResultStates.PullToFrontOfTunnel
    else
        -- Rear of train is left (happy) side of reverse curve.
        return ResultStates.ReachStation
    end
end

return Test
