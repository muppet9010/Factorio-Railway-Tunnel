--[[
    A series of tests that schedules a train to a temporary stop thats part to the tunnel and then possibly on to another stop. Check that the train behaves as desired for both pulling to end of tunnel (or not) and not looping through the tunnel infinitely. Does combinations for:
        targetTunnelRail: tunnelEntranceAboveGround, tunnelEntranceUnderground, tunnelSegment, tunnelExitUnderground, tunnelExitAboveGround
        nextStop: none, station, rail
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

local DoMinimalTests = true -- The minimal test to prove the concept. Just goes to a tunnel segment, then to end station, as this triggered the origional issue.

--TODO: at present tunnelEntranceUnderground and tunnelExitUnderground give unexpected results as they aren't officially entering the tunnel as they haven't pathed to the END signal. Will be handled by future coasting/manaul driven train logic and then the tests can be checked here. Not included in minimal tests or full testing done presently via DoSpecificTests.
local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTargetTunnelRailFilter = {"tunnelEntranceAboveGround", "tunnelSegment", "tunnelExitAboveGround"} -- Pass in array of TargetTunnelRail keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificNextStopFilter = {} -- Pass in array of NextStopTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1000
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        targetTunnelRail = the TargetTunnelRail of this test.
        nextStop = the NextStopTypes of this test.
        expectedTunnelStopHandling = the ExpectedTunnelStopHandling calculated for this test.
        expectedFinalTrainState = the FinalTrainStates calculated for this test. Either nextStopReached or targetRailReached based on if there is a nextStop set for this test.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
end

local blueprintString = "0eNqtmt9O20gcRt/F10nl+W9zv0+xqpCbuNRqYke2wy5Cefe1SRYKNeV8ETeEQPzNyGdOZubnecy+7Y71oW/aMbt5zJpN1w7Zzd+P2dDctdVu/tv4cKizm6wZ6322ytpqP7/rq2b3T/VwOx7btt6tzy+3h64fq93tcOy/V5t6fdhNP/f1FH1aZU27rf/NbsxphcJ/ucSevq6yKaUZm/rcuac3D7ftcf+t7qfM5ys3x/6+3q6fAlbZoRuma7p2bmjKWYdilT1MrzafwrdNX2/O/41zn95k2ufMYZzi7n6M76a6S6p5nWoXUh1PNTzV41Rf8tTAUxNPjTw18NTEUwVaBU8VaJU41Qm0TM5jBVzG8FiBl+F6OQGY4X45gZjhglkFGTfMKsi4YlZBxh2zCjIumVWQccuMgMxyy4yAzHLLjIDMcsuMgMxyy4yAzHLLFGJcMgUYd0zhxRVTcHHDFFpYMCHUYb2UNReWS0DlsFrCqHJYLEEAh7VSZHVYK+WbxWGtlK9Bh7VSvrMd1kqZYBzWSpkNPfZKmbo9FktZZ3hslrIo8lgtZQXnsVvKctNjt5S1scduKQt5j91Sdh0eu6VskTx2S9nOBeyWsvUM2C1lmxywW8qWPmC3pPIDdksplQTsllLWCditoNDCbgWFFnYrKLRKVoOLfrkE55ZKRXyzFS9DwKTXsWkpFqsV03KqWUq1sAj5/x0wHoQ6Fpry58ylFC92Lb7umV/KDFrP3kSGpcgo43YgNWnF4RwMoEIa6zkoipbqkHQf65Ne9Jkz2/UwdoelzfRF8zeWTzSGsTr/nv3VbrOlJswVDwS279e3fu/CfdU31fuCJPtBB4b6bn4A8XEPzJUdcJ/UgWvb95/Uvruy/fBJ7Ycr24+fMwLd4v23H7fPSzYXz8jTDF6xKRMO5RXRMtDQgk/RpcOhvBpaGhzKa6EFBlXwSmiBQRW8DlpwULwMWnBQfMYuOChuVOKguFGJg+JGJQyq5EYlDKrkRiUMquRGRQyq5EZFDKrkRkUOihsVOSh5DUxCuVGBg+JGBQ6KGxUwKJPn6lkOlGrE3TkKteLmHIVip/iYMjl2Kgr3FDsVBfxR3FyhUOxUFEBhp5IACjvF5xPDT5vwmc/wsyZ8jjb8pAlfTRh+zoSveww/ZVIIoLBRhQAKG1UIoLBRhQAKG1UKoLBRfM9j+MkSvjszv5wr2XWbbt+NzX29UHvI8y8h2pfcrm+mqMu2N/8yOzyf0Bzmz/fd5mc9rr8f69185WmxXSwd378afuyE77QNP3TyNOHTVP50PBeGSIQ00x9pWpkmf36eC2OTPz/PhUHCj6XkfJTwcynGvDNKvp5v+pTwcuB6ld3X/XD+QGF8Km1yZR5NiqfTfx1cAJI="

local TargetTunnelRail = {
    tunnelEntranceAboveGround = "tunnelEntranceAboveGround",
    tunnelEntranceUnderground = "tunnelEntranceUnderground",
    tunnelSegment = "tunnelSegment",
    tunnelExitUnderground = "tunnelExitUnderground",
    tunnelExitAboveGround = "tunnelExitAboveGround"
}
local NextStopTypes = {
    none = "none",
    station = "station",
    rail = "rail"
}
local ExpectedTunnelStopHandling = {
    targetTunnelRail = "targetTunnelRail",
    endOfTunnel = "endOfTunnel"
}
local FinalTrainStates = {
    nextStopReached = "nextStopReached",
    targetRailReached = "targetRailReached"
}

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.targetTunnelRail .. "     Next stop: " .. testScenario.nextStop .. "     Expected result: " .. testScenario.expectedTunnelStopHandling .. " - " .. testScenario.expectedFinalTrainState
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        end
    end

    -- Get the portals.
    local entrancePortal, entrancePortalXPos, exitPortal, exitPortalXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "railway_tunnel-tunnel_portal_surface-placed", true, false)) do
        if portalEntity.position.x > entrancePortalXPos then
            entrancePortal = portalEntity
            entrancePortalXPos = portalEntity.position.x
        end
        if portalEntity.position.x < exitPortalXPos then
            exitPortal = portalEntity
            exitPortalXPos = portalEntity.position.x
        end
    end

    -- Get the first tunnel segment as we just need 1.
    local tunnelSegment = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "railway_tunnel-tunnel_segment_surface-placed", false, false)

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive", false, false).train

    -- Create the train schedule for this specific test.
    local trainSchedule = {
        current = 1,
        records = {}
    }
    local targetTunnelRailEntities, targetTunnelRailEntity
    if testScenario.targetTunnelRail == TargetTunnelRail.tunnelEntranceAboveGround then
        targetTunnelRailEntities =
            entrancePortal.surface.find_entities_filtered {
            name = "railway_tunnel-portal_rail-on_map",
            position = Utils.ApplyOffsetToPosition(entrancePortal.position, {x = 8, y = 0})
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.tunnelEntranceUnderground then
        targetTunnelRailEntities =
            entrancePortal.surface.find_entities_filtered {
            name = "railway_tunnel-invisible_rail-on_map_tunnel",
            position = Utils.ApplyOffsetToPosition(entrancePortal.position, {x = -16, y = 0})
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.tunnelSegment then
        targetTunnelRailEntities =
            tunnelSegment.surface.find_entities_filtered {
            name = "railway_tunnel-invisible_rail-on_map_tunnel",
            position = tunnelSegment.position
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.tunnelExitUnderground then
        targetTunnelRailEntities =
            entrancePortal.surface.find_entities_filtered {
            name = "railway_tunnel-invisible_rail-on_map_tunnel",
            position = Utils.ApplyOffsetToPosition(exitPortal.position, {x = 16, y = 0})
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.tunnelExitAboveGround then
        targetTunnelRailEntities =
            exitPortal.surface.find_entities_filtered {
            name = "railway_tunnel-portal_rail-on_map",
            position = Utils.ApplyOffsetToPosition(exitPortal.position, {x = -8, y = 0})
        }
    else
        error("Unsupported testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    end
    if targetTunnelRailEntities == nil or #targetTunnelRailEntities == 0 then
        error("No targetTunnelRailEntity found for testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    elseif #targetTunnelRailEntities > 1 then
        error("Too many targetTunnelRailEntity found for testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    else
        targetTunnelRailEntity = targetTunnelRailEntities[1]
        table.insert(
            trainSchedule.records,
            {
                rail = targetTunnelRailEntity,
                wait_conditions = {
                    {
                        type = "time",
                        ticks = 60,
                        compare_type = "or"
                    }
                },
                temporary = true
            }
        )
    end
    if testScenario.nextStop == NextStopTypes.rail then
        table.insert(
            trainSchedule.records,
            {
                rail = stationEnd.connected_rail,
                temporary = true
            }
        )
    elseif testScenario.nextStop == NextStopTypes.station then
        table.insert(
            trainSchedule.records,
            {
                station = stationEnd.backer_name
            }
        )
    end
    -- If nextStop is type of none then there is no second schedule record to add.
    train.schedule = trainSchedule

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationEnd = stationEnd
    testData.entrancePortal = entrancePortal
    testData.exitPortal = exitPortal
    testData.tunnelSegment = tunnelSegment
    testData.targetTunnelRailEntity = targetTunnelRailEntity
    testData.train = train
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.tunnelRailReached = false
    testData.nextStopReached = false
    testData.testScenario = testScenario
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario = testData.testScenario

    local train = testData.train
    if train == nil or not train.valid then
        train = TestFunctions.GetTrainInArea({left_top = testData.stationEnd.position, right_bottom = testData.entrancePortal.position})
    end
    if train == nil then
        -- Just ignore the train as we can't find it where expected right now.
        return
    end

    if not testData.tunnelRailReached then
        -- Train hasn't reached the tunnelRail yet so keep on checking.
        if train.state == defines.train_state.wait_station then
            -- Train has stopped at a schedule record.
            if testScenario.expectedTunnelStopHandling == ExpectedTunnelStopHandling.endOfTunnel then
                -- Check its at the end of the exit portal. The train is re-scheduled to this from its random unreachable rail.
                local atrainAtExitTunnelEntryRail = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testData.exitPortal.position, {x = -22, y = 0}))
                if atrainAtExitTunnelEntryRail ~= nil then
                    game.print("train pulled to front of tunnel as expected for undergroud rail")
                    testData.tunnelRailReached = true
                end
            elseif testScenario.expectedTunnelStopHandling == ExpectedTunnelStopHandling.targetTunnelRail then
                -- Check its at the expected rail.
                local atrainAtExitTunnelEntryRail = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testData.targetTunnelRailEntity.position, {x = 2, y = 0}))
                if atrainAtExitTunnelEntryRail ~= nil then
                    game.print("train reached expected above ground tunnel rail")
                    testData.tunnelRailReached = true
                end
            end
        end
        return -- End the checking this tick regardless of the result.
    end

    if testScenario.expectedFinalTrainState == FinalTrainStates.targetRailReached then
        TestFunctions.TestCompleted(testName)
        return
    elseif testScenario.expectedFinalTrainState == FinalTrainStates.nextStopReached then
        -- Need to check for when the train reaches the next stop.
        if train.state == defines.train_state.wait_station then
            -- Train has stopped at a schedule record.
            local atrainAtNextStop = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testData.stationEnd.position, {x = 2, y = 2}))
            if atrainAtNextStop ~= nil then
                -- Train has stopped just before the target station/rail, rather than some random place.
                TestFunctions.TestCompleted(testName)
                return
            end
        end
    else
        error("Unsupported testScenario.expectedFinalTrainState: " .. testScenario.expectedFinalTrainState)
    end
end

Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local targetTunnelRailsToTest, nextStopsToTest
    if DoMinimalTests then
        targetTunnelRailsToTest = {TargetTunnelRail.tunnelSegment}
        nextStopsToTest = {NextStopTypes.station}
    elseif DoSpecificTests then
        -- Adhock testing option.
        targetTunnelRailsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TargetTunnelRail, SpecificTargetTunnelRailFilter)
        nextStopsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NextStopTypes, SpecificNextStopFilter)
    else
        -- Do whole test suite.
        targetTunnelRailsToTest = TargetTunnelRail
        nextStopsToTest = NextStopTypes
    end

    for _, targetTunnelRail in pairs(targetTunnelRailsToTest) do
        for _, nextStop in pairs(nextStopsToTest) do
            local scenario = {
                targetTunnelRail = targetTunnelRail,
                nextStop = nextStop
            }
            scenario.expectedTunnelStopHandling, scenario.expectedFinalTrainState = Test.CalculateExpectedResults(scenario)
            Test.RunLoopsMax = Test.RunLoopsMax + 1
            table.insert(Test.TestScenarios, scenario)
        end
    end

    -- Write out all tests to csv as debug.
    Test.WriteTestScenariosToFile(testName)
end

Test.CalculateExpectedResults = function(testScenario)
    local expectedTunnelStopHandling, expectedFinalTrainState

    if testScenario.targetTunnelRail == TargetTunnelRail.tunnelEntranceAboveGround or testScenario.targetTunnelRail == TargetTunnelRail.tunnelExitAboveGround then
        expectedTunnelStopHandling = ExpectedTunnelStopHandling.targetTunnelRail
    elseif testScenario.targetTunnelRail == TargetTunnelRail.tunnelEntranceUnderground or testScenario.targetTunnelRail == TargetTunnelRail.tunnelSegment or testScenario.targetTunnelRail == TargetTunnelRail.tunnelExitUnderground then
        expectedTunnelStopHandling = ExpectedTunnelStopHandling.endOfTunnel
    else
        error("unsupported testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    end

    if testScenario.nextStop == NextStopTypes.none then
        expectedFinalTrainState = FinalTrainStates.targetRailReached
    elseif testScenario.nextStop == NextStopTypes.station then
        expectedFinalTrainState = FinalTrainStates.nextStopReached
    elseif testScenario.nextStop == NextStopTypes.rail then
        expectedFinalTrainState = FinalTrainStates.nextStopReached
    else
        error("Unsupported testScenario.nextStop: " .. testScenario.nextStop)
    end

    return expectedTunnelStopHandling, expectedFinalTrainState
end

Test.WriteTestScenariosToFile = function(testName)
    -- A debug function to write out the tests list to a csv for checking in excel.
    if not DebugOutputTestScenarioDetails or game == nil then
        -- game will be nil on loading a save.
        return
    end

    local fileName = testName .. "-TestScenarios.csv"
    game.write_file(fileName, "#,targetTunnelRail,nextStop,expectedTunnelStopHandling,expectedFinalTrainState" .. "\r\n", false)

    for testIndex, test in pairs(Test.TestScenarios) do
        game.write_file(fileName, tostring(testIndex) .. "," .. tostring(test.targetTunnelRail) .. "," .. tostring(test.nextStop) .. "," .. tostring(test.expectedTunnelStopHandling) .. "," .. tostring(test.expectedFinalTrainState) .. "\r\n", true)
    end
end

return Test
