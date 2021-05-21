--[[
    Does a range of tests for the different situations of a train trying to reverse down a tunnel when a piece of track after the tunnel is removed:
        - Train types (heading west): <, <----, ----<, <>, <-->, <>----, ----<>
        - Leaving track removed: before committed, once committed (full train still), as each carriage enters the tunnel, when train fully in tunnel, after each carriage leaves the tunnel, when the full trian has left the tunel.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

local DoSpecificTrainTests = true -- If enabled does the below specific train tests, rather than the full test suite. used for adhock testing.
local SpecificTrainTypesFilter = {"<>", "><"} -- Pass in array of TrainTypes text (--<--) to do just those. Leave as nil or empty table for all train types. Only used when DoSpecificTrainTests is true.
local SpecificTunnelUsageTypesFilter = {
    --"beforeCommitted",
    "onceCommitted",
    "carriageEntering",
    "fullyUnderground",
    "carriageLeaving",
    "leftTunnel"
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
    onceCommitted = {name = "onceCommitted", perCarriage = false},
    carriageEntering = {name = "carriageEntering", perCarriage = true}, -- This can overlap with carriageLeaving.
    fullyUnderground = {name = "fullyUnderground", perCarriage = false}, -- This may not be a reachable state for tests with trains longer than the tunnel.
    carriageLeaving = {name = "carriageLeaving", perCarriage = true}, -- This can overlap with carriageEntering.
    leftTunnel = {name = "leftTunnel", perCarriage = false}
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
    local stationEnd, stationStart
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        elseif stationEntity.backer_name == "Start" then
            stationStart = stationEntity
        end
    end

    -- Get the portals.
    local enteringPortal, enteringPortalXPos, leavingPortal, leavingPortalXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "railway_tunnel-tunnel_portal_surface-placed")) do
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
    testData.trackToRemove = trackToRemove
    testData.trackRemoved = false
    testData.enteringPortal = enteringPortal
    testData.leavingPortal = leavingPortal
    testData.train = train
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.managedTrainId = 0 -- Tracks current managed train id for tunnel usage.
    testData.oldManagedTrainId = 0 -- Tracks any old (replaced) managed train id's for ignoring their events (not erroring as unexpected).
    testData.testScenario = testScenario
    testData.lastTrainAction = nil -- Populated by the last TunnelUsageChanged action.
    testData.lastTrainChangeReason = nil -- Populated by the last TunnelUsageChanged changeReason.

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

    -- TODO: these tests should check the trainTunnelDetails last action and match up train ids. Needs the main mod code to be working better for this. Current code should be good enough for a rough start of testing.
    local tunnelUsageDetails = remote.call("railway_tunnel", "get_train_tunnel_usage_details", testData.managedTrainId)
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
        if testData.lastTrainAction == "Terminated" and testData.lastTrainChangeReason == "AbortedApproach" then
            TestFunctions.TestCompleted(testName)
        else
            TestFunctions.TestFailed(testName, "last tunnel usage state wasn't AbortedApproach")
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
            -- TODO: check the carriages that have come out match up to 1 end of the origional train. First 4/5 carriages ?
            TestFunctions.TestCompleted(testName)
        elseif endStationTrain ~= nil then
            TestFunctions.TestFailed(testName, "train reached end station")
        end
    elseif testData.testScenario.expectedResult == ResultStates.ReachStation then
        if endStationTrain ~= nil then
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
        testData.managedTrainId = event.trainTunnelUsageId
    end
    if testData.managedTrainId ~= event.trainTunnelUsageId then
        if event.replacedTrainTunnelUsageId ~= nil and testData.managedTrainId == event.replacedTrainTunnelUsageId then
            -- Train tunnel usage entry has been replaced by another one.
            testData.managedTrainId = event.trainTunnelUsageId
            testData.oldManagedTrainId = event.replacedTrainTunnelUsageId
        elseif testData.oldManagedTrainId == event.trainTunnelUsageId then
            -- This old managed train id is expected and can be ignored entirely.
            return
        else
            TestFunctions.TestFailed(testName, "unexpected train tunnel id event received")
        end
    end
    local testTunnelUsageType = testData.testScenario.tunnelUsageType
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
    elseif testTunnelUsageType.name == TunnelUsageType.onceCommitted.name then
        if event.action ~= "CommittedToTunnel" then
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
    elseif testTunnelUsageType.name == TunnelUsageType.fullyUnderground.name then
        if event.action ~= "FullyEntered" then
            return
        end
    elseif testTunnelUsageType.name == TunnelUsageType.carriageLeaving.name then
        if event.action ~= "LeavingCarriageAdded" then
            return
        else
            if (testData.testScenario.reverseOnCarriageNumber) ~= #event.leavingTrain.carriages then
                return
            end
        end
    elseif testTunnelUsageType.name == TunnelUsageType.leftTunnel.name then
        if event.action ~= "FullyLeft" then
            return
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

            local doTest = true
            if tunnelUsageType.name == TunnelUsageType.fullyUnderground.name and maxCarriageCount > 10 then
                -- If it is the underground test and the train is longer than tunnel (10 carraiges) don't do this test.
                doTest = false
            end
            if doTest then
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
end

Test.BuildTrain = function(buildStation, carriagesDetails, scheduleStation)
    -- Build the train from the station heading west. Give each loco fuel, set target schedule and to automatic.
    local placedCarriage
    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local placementPosition = Utils.ApplyOffsetToPosition(buildStation.position, {x = 3, y = 2})
    for i, carriageDetails in pairs(carriagesDetails) do
        placedCarriage = surface.create_entity {name = carriageDetails.name, position = placementPosition, direction = Utils.OrientationToDirection(carriageDetails.orientation), force = force}
        if carriageDetails.name == "locomotive" then
            placedCarriage.insert({name = "rocket-fuel", count = 10})
        elseif carriageDetails.name == "cargo-wagon" then
            placedCarriage.insert({name = "iron-plate", count = i})
        end
        -- TODO: handle gap between carriages dynamically.
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

Test.CalculateExpectedResult = function(testScenario)
    if testScenario.tunnelUsageType.name == TunnelUsageType.beforeCommitted.name then
        -- Train hasn't committed to using the tunnel. So no other checks are needed.
        return ResultStates.NotReachTunnel
    end

    if testScenario.backwardsLocoCarriageNumber == 0 then
        -- No reversing loco in train. So no other checks are needed.
        return ResultStates.PullToFrontOfTunnel
    end

    if testScenario.tunnelUsageType.name == TunnelUsageType.leftTunnel.name then
        -- Train has has left tunnel so nothing can be underground or entering. So no other checks are needed.
        return ResultStates.ReachStation
    end
    if testScenario.tunnelUsageType.name == TunnelUsageType.fullyUnderground.name then
        -- Train has fully entered. So no other checks are needed.
        return ResultStates.ReachStation
    end

    -- The backest safe carriage position is 5 carraiges to enter the tunnel or a carriage position 25 tiles from the portal position.
    local enteringTrainLengthAtReverseTime
    if testScenario.tunnelUsageType.name == TunnelUsageType.onceCommitted.name then
        -- No part of the train has entered yet.
        enteringTrainLengthAtReverseTime = #testScenario.carriages
    elseif testScenario.tunnelUsageType.name == TunnelUsageType.carriageEntering.name then
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
