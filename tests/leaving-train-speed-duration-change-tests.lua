--[[
    Tests that run different train types, tunnel compositions, starting speeds and leaving track scenarios. Confirms that the mod completes the activities and provides a non tunnel identical track and train for visual speed comparison.
    Repathing back through the tunnel is handled by force-repath-back-through-tunnel-tests.lua as there are a lot of combinations for it.

    If the global test setting "JustLogAllTests" is enabled then the variance of each test is recorded to the generic test result output.

    Usage Note: this is a slower test to run as it places varying numbers of entities everywhere so no BP's are currently used in it. Advised to run Factorio outside of the debugger as it runs much faster.

    Code Note: this test's Start() function has been made quite messy to enable it to run much faster by reducing the amount of leaving track built. This required the train to be built mid track building so leaving track length requirements could be calculated.
--]]
--

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Utils = require("utility.utils")
local Common = require("scripts.common")

---@type table<string, TestFunctions_TrainSpecifiction> @ The key is generally the train specification composition text string with the speed if set.
---@class Tests_LTSDCT_TrainComposition
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
    ["--<>--"] = {
        composition = "--<>--"
    },
    ["<<-------->>"] = {
        composition = "<<-------->>"
    },
    ["<<<<<<<<<>"] = {
        composition = "<<<<<<<<<>"
    },
    ["<>>>>>>>>>"] = {
        composition = "<>>>>>>>>>"
    }
}
-- A non oversized tunnel is the portal length required by that train type and 4 underground segments. Oversized is the number multiplied by 4.
---@class Tests_LTSDCT_TunnelOversized
local TunnelOversized = {
    none = "none",
    portalOnly = "portalOnly"
}
---@class Tests_LTSDCT_StartingSpeed
local StartingSpeed = {
    none = "none",
    half = "half", -- Will be half the train's achievable max speed.
    full = "full" -- Will be the train's achievable max speed.
}
---@class Tests_LTSDCT_LeavingTrackCondition
local LeavingTrackCondition = {
    clear = "clear", -- Train station far away so more than braking distance.
    nearStation = "nearStation", -- A train station near to the portal so the train has to brake very aggressively leaving the portal.
    farStation = "farStation", -- A train station far to the portal so the train has to brake gently leaving the portal.
    portalSignal = "portalSignal", -- The portla exit signal will be closed so the train has to crawl out of the portal.
    nearSignal = "nearSignal", -- A signal near to the portal will be closed so the train has to brake very aggressively leaving the portal.
    farSignal = "farSignal", -- A signal far to the portal will be closed so the train has to brake gently leaving the portal.
    noPath = "noPath" -- The path from the portal is removed once the train has entered the tunnel. Doesn't get a variance score as not approperiate.
}
---@class Tests_LTSDCT_FuelType
local FuelType = {
    coal = "coal",
    nuclearFuel = "nuclear-fuel"
}

-- Test configuration.
local MaxTimeVariationPercentage = 10 -- The maximum approved time variation as a percentage of the journey time between the train using the tunnel and the train on regular tracks. Time variation applies in both directions, so is allowed to be either faster or slower than the other. Time variations greater than this will cause the test to fail. 10% passes at present for all variations. The largest variations are currently due to excess braking time for some near signals and near stations; this is caused by train-manager where we set trainAcceleratingAllApproach to true blindly every time, heavily commented code area with reasoning for this.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionFilter = {} -- Pass in an array of TrainComposition keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTunnelOversizedFilter = {} -- Pass in an array of TunnelOversized keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificStartingSpeedFilter = {} -- Pass in an array of StartingSpeed keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificLeavingTrackConditionFilter = {} -- Pass in an array of LeavingTrackCondition keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificFuelTypeFilter = {} -- Pass in an array of FuelType keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 5000 -- The large slow train "<>>>>>>>>>" takes 4k.
Test.RunLoopsMax = 0
---@type Tests_LTSDCT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainComposition.composition .. "   -   Oversized: " .. testScenario.tunnelOversized .. "   -   StartingSpeeds: " .. testScenario.startingSpeed .. "   -   " .. testScenario.leavingTrackCondition .. "   -   " .. testScenario.fuelType
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    -- Note: building the track manually is roughly the same UPS/time as using TestFunctions.BuildBlueprint() with its ghost revive.

    local tunnelTrackY, aboveTrackY, trainDataY, centerX, testSurface, testForce = -5, 5, -15, 0, TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local tunnelEndStation, aboveEndStation, currentPos, offset
    local trainFuel
    if testScenario.fuelType == FuelType.coal then
        trainFuel = {name = "coal", count = 50}
    elseif testScenario.fuelType == FuelType.nuclearFuel then
        trainFuel = {name = "nuclear-fuel", count = 1}
    else
        error("unsupported fuel type: " .. testScenario.fuelType)
    end

    -- Build a test copy of the train to get its train data. As we need this to know how long to build the entering rails for and the main trains placement.
    local trainData_railCountToBuild = math.ceil(#testScenario.trainCarriageDetails * 3.5) + 1
    local trainData_currentPosition = {x = 1, y = trainDataY}
    for i = 1, trainData_railCountToBuild do
        trainData_currentPosition.x = trainData_currentPosition.x + 1
        testSurface.create_entity {name = "straight-rail", position = trainData_currentPosition, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        trainData_currentPosition.x = trainData_currentPosition.x + 1
    end
    local trainData_train = TestFunctions.BuildTrain({x = 2, y = trainDataY}, testScenario.trainCarriageDetails, defines.direction.west, nil, 0.001, trainFuel)
    local trainData = Utils.GetTrainSpeedCalculationData(trainData_train, trainData_train.speed, nil, trainData_train.carriages)

    -- Get the train data worked out as its added in a messy way as we need the train data during setup.
    local trainStartXPos, tunnelTrain, aboveTrain  -- Populated during rail building time.
    local startingSpeedValue
    if testScenario.startingSpeed == StartingSpeed.none then
        startingSpeedValue = 0
    elseif testScenario.startingSpeed == StartingSpeed.half then
        startingSpeedValue = trainData.maxSpeed / 2
    elseif testScenario.startingSpeed == StartingSpeed.full then
        startingSpeedValue = trainData.maxSpeed
    else
        error("unrecognised StartingSpeed: " .. testScenario.startingSpeed)
    end

    -- Work out how many tunnel parts are needed.
    local tunnelSegments = 4
    local portalSegments = math.ceil(#testScenario.trainCarriageDetails * 3.5)
    if testScenario.tunnelOversized == TunnelOversized.portalOnly then
        portalSegments = portalSegments * 4
    end

    -- Work out how much rail to build at the start of the tunnel.
    -- All situations need enough room for the train plus some padding rails.
    local railCountEntranceEndOfPortal = math.ceil(#testScenario.trainCarriageDetails * 3.5) + 5
    if testScenario.startingSpeed ~= StartingSpeed.none then
        -- Add extra starting distance to cover the trains starting speed's braking distance. So that the trains don't start the test braking into or using the tunnel.
        local _, stoppingDistance = Utils.CalculateBrakingTrainTimeAndDistanceFromInitialToFinalSpeed(trainData, startingSpeedValue, 0, 0)
        railCountEntranceEndOfPortal = railCountEntranceEndOfPortal + math.ceil(stoppingDistance / 2)
    end

    -- Work out how much rail to build at the end of the tunnel.
    local nearPositionDistance, farPositionDistance = 20, 100
    local railCountLeavingEndOfPortal
    if testScenario.leavingTrackCondition == LeavingTrackCondition.clear then
        -- This is excessive still as many trains won't be going at max speed when leaving, but I don't know how to simply work out leaving speed from test starting data only.
        local _, stoppingDistance = Utils.CalculateBrakingTrainTimeAndDistanceFromInitialToFinalSpeed(trainData, trainData.maxSpeed, 0, 0)
        -- The +10 is so the train stop is safely beyond braking distance when leaving the tunnel.
        railCountLeavingEndOfPortal = math.ceil(stoppingDistance / 2) + 10
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation or testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.noPath then
        -- Far rail distance plus 10 as the max rail distance needed for any test.
        railCountLeavingEndOfPortal = (nearPositionDistance) / 2
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
        -- Far rail distance plus 10 as the max rail distance needed for any test.
        railCountLeavingEndOfPortal = (farPositionDistance) / 2
    end
    if testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Need extra distance for the locomotive to close the signal.
        railCountLeavingEndOfPortal = railCountLeavingEndOfPortal + 5
    end

    -- Stores the various placement position X's worked out during setup for use by other elements later.
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

        -- Store the specific X position on the exit side of the track for these 2 possible placements.
        if orientationCount == 2 then
            nearPositionX = currentPos.x - nearPositionDistance
            farPositionX = currentPos.x - farPositionDistance
        end

        -- Place the track to the required distance
        offset = Utils.RotatePositionAround0(baseOrientaton, {x = 0, y = -1})
        local railCountToBuild
        if orientationCount == 1 then
            railCountToBuild = railCountEntranceEndOfPortal
        else
            railCountToBuild = railCountLeavingEndOfPortal
        end
        for i = 1, railCountToBuild do
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
            testSurface.create_entity {name = "straight-rail", position = currentPos, direction = baseDirection, force = testForce, raise_built = false, create_build_effect_smoke = false}
            currentPos = Utils.ApplyOffsetToPosition(currentPos, offset)
        end

        -- Build the tunnel train on the entrance track as needed to calculate exit track length on next loop of the FOR.
        if orientationCount == 1 then
            -- Store the beginning end of the entrance rail for use later on.
            trainStartXPos = currentPos.x - (#testScenario.trainCarriageDetails * 7)

            -- Make the train as we need it present.
            tunnelTrain = TestFunctions.BuildTrain({x = trainStartXPos, y = tunnelTrackY}, testScenario.trainCarriageDetails, defines.direction.west, nil, 0.001, trainFuel)
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
        local railCountPostExitPortalEntrySignal
        if orientationCount == 1 then
            railCountPostExitPortalEntrySignal = railCountEntranceEndOfPortal
        else
            railCountPostExitPortalEntrySignal = railCountLeavingEndOfPortal
        end

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

        -- Build the train.
        if orientationCount == 1 then
            aboveTrain = TestFunctions.BuildTrain({x = trainStartXPos, y = aboveTrackY}, testScenario.trainCarriageDetails, defines.direction.west, nil, 0.001, trainFuel)
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

    -- Set up the LeavingTrackConditions that need adhock stuff adding.
    local tunnelBlockingLocomotive, aboveBlockingLocomotive
    if testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
        -- Put a loco just after the portal to close the portal's exit signal.
        tunnelBlockingLocomotive = testSurface.create_entity {name = "locomotive", position = {x = nearPositionX + 7, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        aboveBlockingLocomotive = testSurface.create_entity {name = "locomotive", position = {x = nearPositionX + 7, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Put a signal at the approperiate position and a loco just after it to close the signal.
        local xPosition
        if testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
            xPosition = nearPositionX
        else
            xPosition = farPositionX
        end
        testSurface.create_entity {name = "rail-signal", position = {x = xPosition - 0.5, y = tunnelTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        tunnelBlockingLocomotive = testSurface.create_entity {name = "locomotive", position = {x = xPosition - 7, y = tunnelTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        testSurface.create_entity {name = "rail-signal", position = {x = xPosition - 0.5, y = aboveTrackY - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        aboveBlockingLocomotive = testSurface.create_entity {name = "locomotive", position = {x = xPosition - 7, y = aboveTrackY}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    end

    -- Set the trains schedules and state last as we want the rail network all set before we get the trains to try and find their real paths.
    -- A temporary speed was set at build time just to allow functions to run correctly, so set it to its real value.
    local speedDirectionMultiplier = 1
    if tunnelTrain.speed < 0 then
        speedDirectionMultiplier = -1
    end
    tunnelTrain.speed = startingSpeedValue * speedDirectionMultiplier
    tunnelTrain.schedule = {current = 1, records = {{station = "End"}}}
    tunnelTrain.manual_mode = false
    aboveTrain.speed = startingSpeedValue * speedDirectionMultiplier
    aboveTrain.schedule = {current = 1, records = {{station = "End"}}}
    aboveTrain.manual_mode = false

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_LTSDCT_TestScenarioBespokeData
    local testDataBespoke = {
        tunnelEndStation = tunnelEndStation, ---@type LuaEntity
        aboveEndStation = aboveEndStation, ---@type LuaEntity
        tunnelTrainPreTunnel = tunnelTrain, ---@type LuaTrain
        tunnelTrainPostTunnel = nil, ---@type LuaTrain @ Will overwrite when the train leaves the tunnel.
        aboveTrain = aboveTrain, ---@type LuaTrain
        nearPositionX = nearPositionX, ---@type double
        farPositionX = farPositionX, ---@type double
        tunnelTrackY = tunnelTrackY, ---@type double
        aboveTrackY = aboveTrackY, ---@type double
        noPath_trackRemoved = false, ---@type boolean
        tunnelTrainStoppedTick = nil, ---@type Tick @ Will overwrite at run time.
        aboveTrainStoppedTick = nil, ---@type Tick @ Will overwrite at run time.
        testStartedTick = game.tick, ---@type Tick
        tunnelBlockingLocomotive = tunnelBlockingLocomotive, ---@type LuaEntity @ Populated if theres a loco thats blocking the exit somewhere.
        aboveBlockingLocomotive = aboveBlockingLocomotive ---@type LuaEntity @ Populated if theres a loco thats blocking the exit somewhere.
    }
    testData.bespoke = testDataBespoke

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick")
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_LTSDCT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_LTSDCT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Check test setup on first tick.
    if event.tick == testDataBespoke.testStartedTick then
        -- Check that no starting speed variations has caused the tunnel to be reserved/released on the first tick.
        if tunnelUsageChanges.lastAction ~= nil then
            TestFunctions.TestFailed(testName, "tunnel train triggered tunnel in first tick and is therefore bad test setup")
            return
        end

        -- Check that the non-tunnel train hasn't started braking the test braking, as if it has we will get odd results as the test is unreal for automatic trains.
        if testDataBespoke.aboveTrain.state == defines.train_state.arrive_signal or testDataBespoke.aboveTrain.state == defines.train_state.arrive_station then
            TestFunctions.TestFailed(testName, "above train started the test braking, both trains need to be furtehr away from the target.")
            return
        end
    end

    -- LeavingTrackCondition.noPath only - track when to remove the rail to cause a noPath.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.noPath then
        if not testDataBespoke.noPath_trackRemoved and not testDataBespoke.tunnelTrainPreTunnel.valid then
            -- Train has entered tunnel, remove the forwards path out of the tunnel on both rails.
            testDataBespoke.noPath_trackRemoved = true
            local railCenterX = testDataBespoke.nearPositionX + 5
            local searchBoundingBox = {
                left_top = {x = railCenterX - 0.5, y = testDataBespoke.tunnelTrackY - 0.5},
                right_bottom = {x = railCenterX + 0.5, y = testDataBespoke.aboveTrackY + 0.5}
            }

            local railsFound = TestFunctions.GetTestSurface().find_entities_filtered {area = searchBoundingBox, name = "straight-rail"}
            if #railsFound < 2 then
                error("rails not found where expected")
            else
                for _, railFound in pairs(railsFound) do
                    railFound.destroy()
                end
            end
        end
    end

    -- Capture the leaving train when it first emerges.
    if testDataBespoke.tunnelTrainPostTunnel == nil and tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving then
        testDataBespoke.tunnelTrainPostTunnel = tunnelUsageChanges.train
    end

    -- Monitor the train times when they stop.
    if testDataBespoke.tunnelTrainPostTunnel ~= nil then
        if testDataBespoke.tunnelTrainStoppedTick == nil and testDataBespoke.tunnelTrainPostTunnel.speed == 0 then
            testDataBespoke.tunnelTrainStoppedTick = event.tick
        end
        if testDataBespoke.aboveTrainStoppedTick == nil and testDataBespoke.aboveTrain.speed == 0 then
            testDataBespoke.aboveTrainStoppedTick = event.tick
        end

        -- Check that the blocking locomotives (if present) haven't been damaged/killed in the test.
        local tunnelBlockingLocomotive = testDataBespoke.tunnelBlockingLocomotive ---@type LuaEntity
        if tunnelBlockingLocomotive ~= nil then
            if not tunnelBlockingLocomotive.valid or tunnelBlockingLocomotive.get_health_ratio() ~= 1 then
                TestFunctions.TestFailed(testName, "tunnel blocking locomotive is damaged/dead")
                return
            end
            local aboveBlockingLocomotive = testDataBespoke.aboveBlockingLocomotive ---@type LuaEntity
            if not aboveBlockingLocomotive.valid or aboveBlockingLocomotive.get_health_ratio() ~= 1 then
                TestFunctions.TestFailed(testName, "above track blocking locomotive is damaged/dead")
                return
            end
        end

        -- If both trains have stopped the test is fully over.
        if testDataBespoke.tunnelTrainStoppedTick ~= nil and testDataBespoke.aboveTrainStoppedTick ~= nil then
            -- NoPath test just ends as a time variance is meaningless for it.
            if testScenario.leavingTrackCondition == LeavingTrackCondition.noPath then
                -- Do logging same as variance tests so results text is consitent syntax.
                game.print("variation precentage: NA")
                TestFunctions.LogTestDataToTestRow(",NA,")
                TestFunctions.TestCompleted(testName)
                return
            end

            -- For the other test types compare the train time differences.
            local tunnelTrainTime = testDataBespoke.tunnelTrainStoppedTick - testDataBespoke.testStartedTick
            local aboveTrainTime = testDataBespoke.aboveTrainStoppedTick - testDataBespoke.testStartedTick
            local variancePercentage = Utils.RoundNumberToDecimalPlaces(((tunnelTrainTime / aboveTrainTime) - 1) * 100, 0)

            -- Record the variance, with positive number being tunnel train slower than regular track train.
            game.print("variation precentage: " .. tostring(variancePercentage) .. "%")
            -- Log the variance for if JustLogAllTests is enabled. Its logged with a comma both sides so the text file can be imported in to excel and split on comma for value sorting. Not perfect, but good enough bodge.
            TestFunctions.LogTestDataToTestRow("," .. tostring(variancePercentage) .. "%,")

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

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local trainCompositionToTest  ---@type Tests_LTSDCT_TrainComposition
    local tunnelOversizedToTest  ---@type Tests_LTSDCT_TunnelOversized
    local startingSpeedToTest  ---@type Tests_LTSDCT_StartingSpeed
    local leavingTrackConditionToTest  ---@type Tests_LTSDCT_LeavingTrackCondition
    local fuelTypeToTest  ---@type Tests_LTSDCT_FuelType
    if DoSpecificTests then
        -- Adhock testing option.
        trainCompositionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainComposition, SpecificTrainCompositionFilter)
        tunnelOversizedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelOversized, SpecificTunnelOversizedFilter)
        startingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(StartingSpeed, SpecificStartingSpeedFilter)
        leavingTrackConditionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(LeavingTrackCondition, SpecificLeavingTrackConditionFilter)
        fuelTypeToTest = TestFunctions.ApplySpecificFilterToListByKeyName(FuelType, SpecificFuelTypeFilter)
    elseif DoMinimalTests then
        trainCompositionToTest = {TrainComposition["<---->"]}
        tunnelOversizedToTest = {TunnelOversized.none}
        startingSpeedToTest = {StartingSpeed.none, StartingSpeed.full}
        leavingTrackConditionToTest = {LeavingTrackCondition.clear, LeavingTrackCondition.farSignal, LeavingTrackCondition.nearStation, LeavingTrackCondition.portalSignal, LeavingTrackCondition.noPath}
        fuelTypeToTest = {FuelType.coal}
    else
        -- Do whole test suite.
        trainCompositionToTest = TrainComposition
        tunnelOversizedToTest = TunnelOversized
        startingSpeedToTest = StartingSpeed
        leavingTrackConditionToTest = LeavingTrackCondition
        fuelTypeToTest = FuelType
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainComposition in pairs(trainCompositionToTest) do
        for _, tunnelOversized in pairs(tunnelOversizedToTest) do
            for _, startingSpeed in pairs(startingSpeedToTest) do
                for _, leavingTrackCondition in pairs(leavingTrackConditionToTest) do
                    for _, fuelType in pairs(fuelTypeToTest) do
                        ---@class Tests_LTSDCT_TestScenario
                        local scenario = {
                            trainComposition = trainComposition,
                            tunnelOversized = tunnelOversized,
                            startingSpeed = startingSpeed,
                            leavingTrackCondition = leavingTrackCondition,
                            fuelType = fuelType,
                            trainCarriageDetails = TestFunctions.GetTrainCompositionFromTextualRepresentation(trainComposition)
                        }
                        table.insert(Test.TestScenarios, scenario)
                        Test.RunLoopsMax = Test.RunLoopsMax + 1
                    end
                end
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
