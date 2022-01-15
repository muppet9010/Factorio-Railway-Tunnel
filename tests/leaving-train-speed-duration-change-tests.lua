--[[
    Tests that run different train types, tunnel compositions, starting speeds and leaving track scenarios. Confirms that the mod completes the activities and provides a non tunnel identical track and train for visual speed comparison.
    Repathing back through the tunnel is handled by force-repath-back-through-tunnel-tests.lua as there are a lot of combinations for it.
    Note: this is a slower test to run as it places varying numbers of entities everywhere so no BP's are currently used in it. Advised to run logging results to text file when all iterations are used and run Facotrio outside of the debugger so its much faster.
--]]
--

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

-- Internal test types.
---@type table<string, TestFunctions_TrainSpecifiction> @ The key is generally the train specification composition text string with the speed if set.
local TrainComposition = {
    ["<"] = {
        composition = "<"
    },
    ["<>"] = {
        composition = "<>"
    },
    ["<---->"] = {
        composition = "<---->"
    },
    ["<<<<<<<<<>"] = {
        composition = "<<<<<<<<<>"
    },
    ["<<-------->>"] = {
        composition = "<<-------->>"
    }
}
-- A non oversized tunnel is the portal length required by that train type and 4 underground segments. Oversized is the number multiplied by 4.
local TunnelOversized = {
    none = "none",
    portalOnly = "portalOnly",
    undergroundOnly = "undergroundOnly",
    portalAndUnderground = "portalAndUnderground"
}
local StartingSpeed = {
    none = "none",
    half = "half", -- Will be set to 0.6 as an approximate half speed.
    full = "full" -- Will be set to 2 as this will drop to the trains real max after 1 tick.
}
local LeavingTrackCondition = {
    clear = "clear", -- Train station far away so more than breaking distance.
    nearStation = "nearStation", -- A train station near to the portal so the train has to brake very aggressively leaving the portal.
    farStation = "farStation", -- A train station far to the portal so the train has to brake gently leaving the portal.
    portalSignal = "portalSignal", -- The portla exit signal will be closed so the train has to crawl out of the portal.
    nearSignal = "nearSignal", -- A signal near to the portal will be closed so the train has to brake very aggressively leaving the portal.
    farSignal = "farSignal", -- A signal far to the portal will be closed so the train has to brake gently leaving the portal.
    noPath = "noPath" -- The path from the portal doesn't exist any more.
}

-- Test configuration.
local MaxTimeVariationPercentage = 30 -- The maximum approved time variation as a percentage of the journey time between the train using the tunnel the train on regualr tracks. Time variation applies in both directions, so either is allowed to be faster than the other. Time variations greater than this will cause the test to fail. 30% passes at present for all variations, but the current larger variations do indicate future improvement areas.
local DoMinimalTests = true -- The minimal test to prove the concept. Just does the letter "b".

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionFilter = {} -- Pass in an array of TrainComposition keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificTunnelOversizedFilter = {} -- Pass in an array of TunnelOversized keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificStartingSpeedFilter = {} -- Pass in an array of StartingSpeed keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificLeavingTrackConditionFilter = {} -- Pass in an array of LeavingTrackCondition keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

-- How long the test instance runs for (ticks) before being failed as uncompleted. Should be safely longer than the maximum test instance should take to complete, but can otherwise be approx.
Test.RunTime = 3600

-- Populated when generating test scenarios.
Test.RunLoopsMax = 0

-- The test configurations are stored in this when populated by Test.GenerateTestScenarios().
Test.TestScenarios = {}

-- Any scheduled event types for the test must be Registered here.
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

-- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainComposition.composition .. "   -   Oversized: " .. testScenario.tunnelOversized .. "   -   StartingSpeeds: " .. testScenario.startingSpeed .. "   -   " .. testScenario.leavingTrackCondition
end

-- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local tunnelTrackY, aboveTrackY, centerX, testSurface, testForce = -5, 5, 0, TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local tunnelEndStation, aboveEndStation, currentPos, offset

    -- Work out how many tunnel parts are needed.
    local tunnelSegments = 4
    if testScenario.tunnelOversized == TunnelOversized.undergroundOnly or testScenario.tunnelOversized == TunnelOversized.portalAndUnderground then
        tunnelSegments = tunnelSegments * 4
    end
    local portalSegments = math.ceil(#testScenario.trainCarriageDetails * 3.5)
    if testScenario.tunnelOversized == TunnelOversized.portalOnly or testScenario.tunnelOversized == TunnelOversized.portalAndUnderground then
        portalSegments = portalSegments * 4
    end
    local railCountEachEnd = math.ceil(#testScenario.trainCarriageDetails * 3.5) * 40 -- Seems that 40 is safely far away at max speed for "clear" LeavingTrackCondition.

    -- Stores the various placement position X's worked out during setup for use by other elements later.
    local nearPositionX, farPositionX, beginningEntranceRailPositionX

    -- Place the Tunnel Track's various standard parts, starting in middle of underground and going towards train, then in middle going towards end.
    -- Set the currentXPos before and after placing each entity, so its left on the entity border between them. This means nothing special is needed between entity types.
    for orientationCount, baseOrientaton in pairs({0.25, 0.75}) do
        local baseDirection = Utils.OrientationToDirection(baseOrientaton)
        currentPos = {x = centerX, y = tunnelTrackY}

        -- Place the underground segments.
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, tunnelSegments / 2 do
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
            testSurface.create_entity {name = "railway_tunnel-underground_segment-straight", position = currentPos, direction = baseDirection, force = testForce, raise_built = true, create_build_effect_smoke = false}
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        end

        -- Place the blocked end portal part.
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -3})
        currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        testSurface.create_entity {name = "railway_tunnel-portal_end", position = currentPos, direction = baseDirection, force = testForce, raise_built = true, create_build_effect_smoke = false}
        currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)

        -- Place the portal segments.
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, portalSegments do
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
            testSurface.create_entity {name = "railway_tunnel-portal_segment-straight", position = currentPos, direction = baseDirection, force = testForce, raise_built = true, create_build_effect_smoke = false}
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        end

        -- Place the entry end portal part.
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -3})
        currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        testSurface.create_entity {name = "railway_tunnel-portal_end", position = currentPos, direction = baseDirection, force = testForce, raise_built = true, create_build_effect_smoke = false}
        currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)

        -- Store the specific X position on the exit side of the track for these 2 possible placements.
        if orientationCount == 2 then
            nearPositionX = currentPos.x - 20
            farPositionX = currentPos.x - 100
        end

        -- Place the track to the required distance
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, railCountEachEnd do
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
            testSurface.create_entity {name = "straight-rail", position = currentPos, direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        end

        -- Store the beginning end of the entrance rail for use later on.
        if orientationCount == 1 then
            beginningEntranceRailPositionX = currentPos.x
        end

        -- Place the station on the exit side of the track.
        if orientationCount == 2 then
            local railStopPosition
            if testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation then
                railStopPosition = {x = nearPositionX, y = currentPos.y}
            elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
                railStopPosition = {x = farPositionX, y = currentPos.y}
            else
                -- Don't change the currentPosition, just built the rail stop to the side of the middle of the last rail.
                railStopPosition = currentPos
            end
            offset = Utils.RotatePositionAround0(baseOrientaton, {x = 2, y = 1})
            tunnelEndStation = testSurface.create_entity {name = "train-stop", position = Utils.ApplyOffsetToPosition(railStopPosition, offset), direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            tunnelEndStation.backer_name = "End"
        end
    end

    -- Place the Above Track's various standard parts, starting in middle of underground and going towards train, then in middle going towards end.
    -- Set the currentXPos before and after placing each entity, so its left on the entity border between them. This means nothing special is needed between entity types.
    for orientationCount, baseOrientaton in pairs({0.25, 0.75}) do
        local baseDirection = Utils.OrientationToDirection(baseOrientaton)
        currentPos = {x = centerX, y = aboveTrackY}

        local portalEndRailLength = 3
        local railCountPreExitPortalEntrySignal = (tunnelSegments / 2) + portalEndRailLength + portalSegments + portalEndRailLength
        local railCountPostExitPortalEntrySignal = railCountEachEnd

        -- Place the track up to the required distance up to the portal entry signal points.
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, railCountPreExitPortalEntrySignal do
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
            testSurface.create_entity {name = "straight-rail", position = currentPos, direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        end

        -- Place the exit portal entry signals as some tests require it.
        if orientationCount == 2 then
            -- Don't change the currentPos as the signal is to the side of the track and we don't want a gap for it.
            testSurface.create_entity {name = "rail-signal", position = {x = currentPos.x + 1.5, y = currentPos.y - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        end

        -- Place the track after the portal entry signal points.
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, railCountPostExitPortalEntrySignal do
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
            testSurface.create_entity {name = "straight-rail", position = currentPos, direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        end

        -- Place the station on the exit side of the track.
        if orientationCount == 2 then
            local railStopPosition
            if testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation then
                railStopPosition = {x = nearPositionX, y = currentPos.y}
            elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
                railStopPosition = {x = farPositionX, y = currentPos.y}
            else
                -- Don't change the currentPosition, just built the rail stop to the side of the middle of the last rail.
                railStopPosition = currentPos
            end
            offset = Utils.RotatePositionAround0(baseOrientaton, {x = 2, y = 1})
            aboveEndStation = testSurface.create_entity {name = "train-stop", position = Utils.ApplyOffsetToPosition(railStopPosition, offset), direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            aboveEndStation.backer_name = "End"
        end
    end

    -- Add trains to both tracks.
    local trainTileLength = #testScenario.trainCarriageDetails * 7
    local trainStartXPos = beginningEntranceRailPositionX - trainTileLength
    local startingSpeedValue
    if testScenario.startingSpeed == StartingSpeed.none then
        startingSpeedValue = 0
    elseif testScenario.startingSpeed == StartingSpeed.half then
        startingSpeedValue = 0.6
    elseif testScenario.startingSpeed == StartingSpeed.full then
        startingSpeedValue = 2
    else
        error("unrecognised StartignSpeed: " .. testScenario.startingSpeed)
    end
    local trainFuel = {name = "rocket-fuel", count = 10}
    local tunnelTrain = TestFunctions.BuildTrain({x = trainStartXPos, y = tunnelTrackY}, testScenario.trainCarriageDetails, defines.direction.west, nil, startingSpeedValue, trainFuel)
    tunnelTrain.schedule = {current = 1, records = {{station = "End"}}}
    tunnelTrain.manual_mode = false
    local aboveTrain = TestFunctions.BuildTrain({x = trainStartXPos, y = aboveTrackY}, testScenario.trainCarriageDetails, defines.direction.west, nil, startingSpeedValue, trainFuel)
    aboveTrain.schedule = {current = 1, records = {{station = "End"}}}
    aboveTrain.manual_mode = false

    -- Set up the LeavingTrackConditions that need adhock stuff adding.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
        -- Put a loco just after the protal to close the portal's exit signal.
        testSurface.create_entity {name = "locomotive", position = {x = nearPositionX, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "locomotive", position = {x = nearPositionX, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
        -- Put a signal at the near position and a loco to close it just after.
        testSurface.create_entity {name = "rail-signal", position = {x = nearPositionX - 0.5, y = tunnelTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "locomotive", position = {x = nearPositionX - 7, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "rail-signal", position = {x = nearPositionX - 0.5, y = aboveTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "locomotive", position = {x = nearPositionX - 7, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Put a signal at the far position and a loco to close it just after.
        testSurface.create_entity {name = "rail-signal", position = {x = farPositionX - 0.5, y = tunnelTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "locomotive", position = {x = farPositionX - 7, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "rail-signal", position = {x = farPositionX - 0.5, y = aboveTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "locomotive", position = {x = farPositionX - 7, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    testData.bespoke = {
        tunnelEndStation = tunnelEndStation,
        aboveEndStation = aboveEndStation,
        tunnelTrainPreTunnel = tunnelTrain,
        tunnelTrainPostTunnel = nil, -- Will overwrite when the train leaves the tunnel.
        aboveTrain = aboveTrain,
        nearPositionX = nearPositionX,
        farPositionX = farPositionX,
        tunnelTrackY = tunnelTrackY,
        aboveTrackY = aboveTrackY,
        noPath_trackRemoved = false,
        tunnelTrainStoppedTick = nil, -- Will overwrite at run time.
        aboveTrainStoppedTick = nil, -- Will overwrite at run time.
        testStartedTick = game.tick
    }

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick")
end

-- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- TrainComposition,TunnelOversized,StartingSpeed,LeavingTrackCondition   trainComposition,tunnelOversized,startingSpeed,leavingTrackCondition
-- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario, testDataBespoke = testData.testScenario, testData.bespoke

    -- LeavingTrackCondition.noPath only - track when to remove the rail to cause a noPath.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.noPath then
        if not testDataBespoke.noPath_trackRemoved and not testDataBespoke.tunnelTrainPreTunnel.valid then
            -- Train has entered tunnel, remove the forwards path out of the tunnel on both rails.
            testDataBespoke.noPath_trackRemoved = true
            local railCenterX = testDataBespoke.nearPositionX - 1
            local searchBoundingBox = {
                left_top = {x = railCenterX - 0.5, y = testDataBespoke.tunnelTrackY - 0.5},
                right_bottom = {x = railCenterX + 0.5, y = testDataBespoke.aboveTrackY + 0.5}
            }

            local railsFound = TestFunctions.GetTestSurface().find_entities_filtered {area = searchBoundingBox, name = "straight-rail"}
            if #railsFound ~= 2 then
                error("rails not found where expected")
            else
                for _, railFound in pairs(railsFound) do
                    railFound.destroy()
                end
            end
        end
    end

    -- Capture the leaving train when it first emerges.
    if testDataBespoke.tunnelTrainPostTunnel == nil and testData.lastAction == "leaving" then
        testDataBespoke.tunnelTrainPostTunnel = testData.tunnelUsageEntry.leavingTrain
    end

    -- Monitor the train times when they stop.
    if testDataBespoke.tunnelTrainPostTunnel ~= nil then
        if testDataBespoke.tunnelTrainStoppedTick == nil and testDataBespoke.tunnelTrainPostTunnel.speed == 0 then
            testDataBespoke.tunnelTrainStoppedTick = event.tick
        end
        if testDataBespoke.aboveTrainStoppedTick == nil and testDataBespoke.aboveTrain.speed == 0 then
            testDataBespoke.aboveTrainStoppedTick = event.tick
        end

        -- If both trains have stopped compare their time difference and the test is over.
        if testDataBespoke.tunnelTrainStoppedTick ~= nil and testDataBespoke.aboveTrainStoppedTick ~= nil then
            local tunnelTrainTime = testDataBespoke.tunnelTrainStoppedTick - testDataBespoke.testStartedTick
            local aboveTrainTime = testDataBespoke.aboveTrainStoppedTick - testDataBespoke.testStartedTick
            local variancePercentage = Utils.RoundNumberToDecimalPlaces(((tunnelTrainTime / aboveTrainTime) - 1) * 100, 0)

            -- Record the variance, with positive number being tunnel train slower than regular track train.
            game.print("variation precentage: " .. tostring(variancePercentage) .. "%")
            TestFunctions.LogTestDataToTestRow(tostring(variancePercentage) .. "%")

            -- Times should be within the set MaxTimeVariationPercentage value.
            if variancePercentage < -MaxTimeVariationPercentage or variancePercentage > MaxTimeVariationPercentage then
                TestFunctions.TestFailed(testName, "train times should be within " .. tostring(MaxTimeVariationPercentage) .. "% of each other")
            else
                TestFunctions.TestCompleted(testName)
            end
            return
        end
    end

    -- If both trains reach the end station the test is over.
    if testDataBespoke.tunnelEndStation.get_stopped_train() ~= nil and testDataBespoke.aboveEndStation.get_stopped_train() ~= nil then
        if testScenario.leavingTrackCondition == LeavingTrackCondition.clear or testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation or testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
            TestFunctions.TestCompleted(testName)
        else
            TestFunctions.TestFailed(testName, "train shouldn't have reached end statin in this test")
        end
        return
    end
end

-- Generate the combinations of different tests required.
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local trainCompositionToTest, tunnelOversizedToTest, startingSpeedToTest, leavingTrackConditionToTest
    if DoMinimalTests then
        trainCompositionToTest = {TrainComposition["<---->"]}
        tunnelOversizedToTest = {TunnelOversized.none}
        startingSpeedToTest = {StartingSpeed.none, StartingSpeed.full}
        leavingTrackConditionToTest = {LeavingTrackCondition.clear, LeavingTrackCondition.farSignal, LeavingTrackCondition.nearStation, LeavingTrackCondition.portalSignal, LeavingTrackCondition.noPath}
    elseif DoSpecificTests then
        -- Adhock testing option.
        trainCompositionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainComposition, SpecificTrainCompositionFilter)
        tunnelOversizedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelOversized, SpecificTunnelOversizedFilter)
        startingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(StartingSpeed, SpecificStartingSpeedFilter)
        leavingTrackConditionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(LeavingTrackCondition, SpecificLeavingTrackConditionFilter)
    else
        -- Do whole test suite.
        trainCompositionToTest = TrainComposition
        tunnelOversizedToTest = TunnelOversized
        startingSpeedToTest = StartingSpeed
        leavingTrackConditionToTest = LeavingTrackCondition
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainComposition in pairs(trainCompositionToTest) do
        for _, tunnelOversized in pairs(tunnelOversizedToTest) do
            for _, startingSpeed in pairs(startingSpeedToTest) do
                for _, leavingTrackCondition in pairs(leavingTrackConditionToTest) do
                    local scenario = {
                        trainComposition = trainComposition,
                        tunnelOversized = tunnelOversized,
                        startingSpeed = startingSpeed,
                        leavingTrackCondition = leavingTrackCondition,
                        trainCarriageDetails = TestFunctions.GetTrainCompositionFromTextualRepresentation(trainComposition)
                    }
                    table.insert(Test.TestScenarios, scenario)
                    Test.RunLoopsMax = Test.RunLoopsMax + 1
                end
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, {"firstLetter", "secondLetter"}, Test.TestScenarios)
    end
end

return Test
