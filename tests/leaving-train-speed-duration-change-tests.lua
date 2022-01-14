--[[
    Tests that run different train types, tunnel compositions, starting speeds and leaving track scenarios. Confirms that the mod completes the activities and provides a non tunnel identical track and train for visual speed comparison.
    Repathing back through the tunnel is handled by force-repath-back-through-tunnel-tests.lua as there are a lot of combinations for it.
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
local DoMinimalTests = false -- The minimal test to prove the concept. Just does the letter "b".

local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionFilter = {} -- Pass in an array of TrainComposition keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificTunnelOversizedFilter = {} -- Pass in an array of TunnelOversized keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificStartingSpeedFilter = {} -- Pass in an array of StartingSpeed keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificLeavingTrackConditionFilter = {} -- Pass in an array of LeavingTrackCondition keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = true -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

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

    -- Stores station and signal placement position X worked out during setup.
    local nearPositionX, farPositionX

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

        if orientationCount == 2 then
            -- Store the specific X position on the exit side of the track for these 2 possible placements.
            nearPositionX = currentPos.x + 20
            farPositionX = currentPos.x + 100
        end

        -- Place the track to the required distance
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, railCountEachEnd do
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
            tunnelEndStation = testSurface.create_entity {name = "train-stop", position = Utils.ApplyOffsetToPosition(railStopPosition, offset), direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            tunnelEndStation.backer_name = "End"
        end
    end

    -- Place the Above Track's various standard parts, starting in middle of underground and going towards train, then in middle going towards end.
    -- Set the currentXPos before and after placing each entity, so its left on the entity border between them. This means nothing special is needed between entity types.
    for orientationCount, baseOrientaton in pairs({0.25, 0.75}) do
        local baseDirection = Utils.OrientationToDirection(baseOrientaton)
        currentPos = {x = centerX, y = aboveTrackY}

        local railCount = (tunnelSegments / 2) + 3 + portalSegments + 3 + railCountEachEnd

        -- Place the track to the required distance
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        for i = 1, railCount do
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
    local rainTileLength = #testScenario.trainCarriageDetails * 7
    local trainStartXPos = -tunnelEndStation.position.x - rainTileLength -- The -tunnelEndStation.x gives us the end of the entrance rail (opposite end to the rail stop).
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
        testSurface.create_entity {name = "train-stop", position = {x = nearPositionX, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "train-stop", position = {x = nearPositionX, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
        -- Put a signal at the near position and a loco to close it just after.
        testSurface.create_entity {name = "rail-signal", position = {x = nearPositionX - 0.5, y = tunnelTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "train-stop", position = {x = nearPositionX - 7, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "rail-signal", position = {x = nearPositionX - 0.5, y = aboveTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "train-stop", position = {x = nearPositionX - 7, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Put a signal at the far position and a loco to close it just after.
        testSurface.create_entity {name = "rail-signal", position = {x = farPositionX - 0.5, y = tunnelTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "train-stop", position = {x = farPositionX - 7, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "rail-signal", position = {x = farPositionX - 0.5, y = aboveTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "train-stop", position = {x = farPositionX - 7, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario.trainComposition
    testData.tunnelEndStation = tunnelEndStation
    testData.aboveEndStation = aboveEndStation
    testData.tunnelTrainPreTunnel = tunnelTrain
    testData.aboveTrain = aboveTrain
    testData.nearPositionX = nearPositionX
    testData.farPositionX = farPositionX
    testData.tunnelTrackY = tunnelTrackY
    testData.aboveTrackY = aboveTrackY
    testData.noPath_trackRemoved = false

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- TrainComposition,TunnelOversized,StartingSpeed,LeavingTrackCondition   trainComposition,tunnelOversized,startingSpeed,leavingTrackCondition
-- Scheduled event function to check test state each tick.
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario = testData.testScenario

    -- LeavingTrackCondition.noPath only - track when to remove the rail to cause a noPath.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.noPath then
        if not testData.noPath_trackRemoved and not testData.tunnelTrain.valid then
            -- Train has entered tunnel, remove the forwards path out of the tunnel on both rails.
            testData.noPath_trackRemoved = true
            local searchBoundingBox = {
                left_top = {x = testData.nearPositionX - 0.5, y = testData.tunnelTrackY - 0.5},
                right_bottom = {x = testData.nearPositionX + 0.5, y = testData.aboveTrackY + 0.5}
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

    --TODO
    -- Get the train when it leaves the tunnel and set as testData.tunnelTrainPreTunnel . Need to add tracking of the tunnel usage events, but should be much simplier now.
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
