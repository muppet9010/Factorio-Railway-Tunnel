--[[
    Have a player riding in a train and monitor the players position to ensure its smooth. Test various train entering and leaving speeds.
    Can only test the players view never moves backwards. Trying to track the forward movement between ticks triggered on un-avoidable irregular forwards variation when the unerground train changes to leaving.
    If the global test setting "JustLogAllTests" is enabled then the variance of each test is recorded to the generic test result output. A jump of 0% is ideal, with more/less than 100% indicating an excess tick. At present some braking situations can exceed 100% as I want to avoid overly complicated logic in the mod to try and smooth it out.
    Usage Note: this is a slower test to run as it places varying numbers of entities everywhere so no BP's are currently used in it. Advised to run Factorio outside of the debugger as it runs much faster.
--]]
--

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")
local Utils = require("utility.utils")

---@class Tests_PRSMT_TrainComposition
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
    ["<>>>>>>>>>"] = {
        composition = "<>>>>>>>>>"
    }
}
-- A non oversized tunnel is the portal length required by that train type and 4 underground segments. Oversized is the number multiplied by 4.
---@class Tests_PRSMT_TunnelOversized
local TunnelOversized = {
    none = "none",
    portalOnly = "portalOnly",
    undergroundOnly = "undergroundOnly",
    portalAndUnderground = "portalAndUnderground"
}

---@class Tests_PRSMT_LeavingTrackCondition
local LeavingTrackCondition = {
    clear = "clear", -- Train station far away so more than breaking distance.
    nearStation = "nearStation", -- A train station near to the portal so the train has to brake very aggressively leaving the portal.
    farStation = "farStation", -- A train station far to the portal so the train has to brake gently leaving the portal.
    portalSignal = "portalSignal", -- The portla exit signal will be closed so the train has to crawl out of the portal.
    nearSignal = "nearSignal", -- A signal near to the portal will be closed so the train has to brake very aggressively leaving the portal.
    farSignal = "farSignal", -- A signal far to the portal will be closed so the train has to brake gently leaving the portal.
    noPath = "noPath" -- The path from the portal is removed once the train has entered the tunnel.
}
---@class Tests_PRSMT_TrainStartingSpeed
local TrainStartingSpeed = {
    none = "none",
    half = "half", --0.7
    full = "full" -- 1.4 Vanailla locomotives max speed.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionFilter = {} -- Pass in an array of TrainComposition keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTunnelOversizedFilter = {} -- Pass in an array of TunnelOversized keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificLeavingTrackConditionFilter = {} -- Pass in an array of LeavingTrackCondition keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTrainStartingSpeedFilter = {} -- Pass in an array of TrainStartingSpeed keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 5000
Test.RunLoopsMax = 0
---@type Tests_PRSMT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName) -- Have tunnel usage changes being added to the test's TestData object.
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainComposition.composition .. "   -   Oversized: " .. testScenario.tunnelOversized .. "   -   " .. testScenario.leavingTrackCondition .. "   -   StartingSpeed: " .. testScenario.trainStartingSpeed
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local trackYPosition = 1
    local surface, testForce = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local currentRailBuildPosition

    -- Work out how many tunnel parts are needed.
    local tunnelSegmentsCount = 4
    if testScenario.tunnelOversized == TunnelOversized.undergroundOnly or testScenario.tunnelOversized == TunnelOversized.portalAndUnderground then
        tunnelSegmentsCount = tunnelSegmentsCount * 4
    end
    local portalSegmentsCount = math.ceil(#testScenario.trainCarriageDetails * 3.5)
    if testScenario.tunnelOversized == TunnelOversized.portalOnly or testScenario.tunnelOversized == TunnelOversized.portalAndUnderground then
        portalSegmentsCount = portalSegmentsCount * 4
    end

    -- Create the tunnel and portals. Build tunnel center east for the entrance and then tunnel center west for exit.
    ---@typelist LuaEntity, double, LuaEntity, double
    local entrancePortalPart, entrancePortalPartX, exitPortalPart, exitPortalPartX
    for _, directionData in pairs({{direction = defines.direction.east, xPosModifier = 1}, {direction = defines.direction.west, xPosModifier = -1}}) do
        -- Reset the building loction to the center of the tunnele each time.
        currentRailBuildPosition = {x = 0, y = trackYPosition}

        -- Build the tunnel sections.
        for i = 1, tunnelSegmentsCount / 2 do
            currentRailBuildPosition.x = currentRailBuildPosition.x + (1 * directionData.xPosModifier)
            surface.create_entity {name = "railway_tunnel-underground_segment-straight", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
            currentRailBuildPosition.x = currentRailBuildPosition.x + (1 * directionData.xPosModifier)
        end

        -- Build the blocked end of portal.
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)
        surface.create_entity {name = "railway_tunnel-portal_end", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)

        -- Build the portal sections.
        for i = 1, portalSegmentsCount do
            currentRailBuildPosition.x = currentRailBuildPosition.x + (1 * directionData.xPosModifier)
            surface.create_entity {name = "railway_tunnel-portal_segment-straight", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
            currentRailBuildPosition.x = currentRailBuildPosition.x + (1 * directionData.xPosModifier)
        end

        -- Build the entry end of portal.
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)
        local portalBuilt = surface.create_entity {name = "railway_tunnel-portal_end", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)

        -- Log the entry end of the portal for use later.
        if directionData.direction == defines.direction.east then
            entrancePortalPart = portalBuilt
            entrancePortalPartX = portalBuilt.position.x
        else
            exitPortalPart = portalBuilt
            exitPortalPartX = portalBuilt.position.x
        end
    end

    -- Work out how much rail to build at the start of the tunnel before the train and its track.
    local railCountEntranceEndOfPortal
    if testScenario.trainStartingSpeed == TrainStartingSpeed.full then
        -- Start the train far enough away from the portal so its starting abstract high speed doesn't trigger the tunnel and then instantly release it when Factorio clamps to train max speed in first tick. The train isn't going to go any faster so greater starting distances don't really matter.
        railCountEntranceEndOfPortal = 100
    elseif testScenario.trainStartingSpeed == TrainStartingSpeed.half then
        -- Start the train far enough away from the portal so its starting abstract high speed doesn't trigger the tunnel and then instantly release it when Factorio clamps to train max speed in first tick. The train isn't going to go any faster so greater starting distances don't really matter.
        railCountEntranceEndOfPortal = 30
    else
        -- Start the train very close to the portal so its speed hasn't climbed much from the starting speed.
        railCountEntranceEndOfPortal = 10
    end

    -- Build the pre tunnel rail, includes rails for the train to be placed on.
    local trainRailsNeeded = math.ceil(#testScenario.trainCarriageDetails * 3.5)
    currentRailBuildPosition.x = entrancePortalPartX + 3
    for i = 1, railCountEntranceEndOfPortal + trainRailsNeeded do
        currentRailBuildPosition.x = currentRailBuildPosition.x + 1
        surface.create_entity {name = "straight-rail", position = currentRailBuildPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x + 1
    end

    -- Build the train, have to use a fake constant speed to generate acceleration data.
    local train = TestFunctions.BuildTrain({x = currentRailBuildPosition.x - (#testScenario.trainCarriageDetails * 7), y = trackYPosition}, testScenario.trainCarriageDetails, defines.direction.west, 1, 0.1, {name = "rocket-fuel", count = 10})

    -- Add the post tunnel parts.
    local nearPositionDistance, farPositionDistance = 20, 100
    local nearPositionX, farPositionX = exitPortalPartX - nearPositionDistance, exitPortalPartX - farPositionDistance

    -- Work out how much track is needed.
    local railCountLeavingEndOfPortal
    if testScenario.leavingTrackCondition == LeavingTrackCondition.clear then
        -- Its a clear exit test then work out the railCountLeavingEndOfPortal length from the built train after building the entrance side of the portal.
        local trainData = Utils.GetTrainSpeedCalculationData(train, train.speed, train.carriages)
        local _, stoppingDistance = Utils.CalculateBrakingTrainTimeAndDistanceFromInitialToFinalSpeed(trainData, trainData.maxSpeed, 0, 0)
        railCountLeavingEndOfPortal = math.ceil(stoppingDistance / 2) + 10 -- This is excessive still as many trains won't be going at max speed when leaving, but I don't know how to simply work out leaving speed from test starting data only.
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation or testScenario.leavingTrackCondition == LeavingTrackCondition.noPath or testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
        -- Build the shorter rail length plus 10 tiles for a blocking loco if needed.
        railCountLeavingEndOfPortal = (nearPositionDistance + 10) / 2
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
        -- Build the far rail length plus 10 tiles for a blocking loco if needed.
        railCountLeavingEndOfPortal = (farPositionDistance + 10) / 2
    end

    -- Build the post tunnel rail.
    currentRailBuildPosition.x = exitPortalPartX - 3
    for i = 1, railCountLeavingEndOfPortal do
        currentRailBuildPosition.x = currentRailBuildPosition.x - 1
        surface.create_entity {name = "straight-rail", position = currentRailBuildPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x - 1
    end

    -- Add the station.
    local railStopPosition
    if testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation then
        railStopPosition = {x = nearPositionX + 1, y = trackYPosition - 2}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
        railStopPosition = {x = farPositionX + 1, y = trackYPosition - 2}
    else
        -- All other cases just add the station to the end of exit track built.
        railStopPosition = {x = currentRailBuildPosition.x + 1, y = trackYPosition - 2}
    end
    endStation = surface.create_entity {name = "train-stop", position = railStopPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    endStation.backer_name = "End"

    -- Set up the LeavingTrackConditions that need adhock stuff adding.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
        -- Put a loco just after the portal to close the portal's exit signal.
        surface.create_entity {name = "locomotive", position = {x = nearPositionX, y = trackYPosition}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
        -- Put a signal at the near position and a loco to close it just after.
        surface.create_entity {name = "rail-signal", position = {x = nearPositionX - 0.5, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        surface.create_entity {name = "locomotive", position = {x = nearPositionX - 7, y = trackYPosition}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Put a signal at the far position and a loco to close it just after.
        surface.create_entity {name = "rail-signal", position = {x = farPositionX - 0.5, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        surface.create_entity {name = "locomotive", position = {x = farPositionX - 7, y = trackYPosition}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    end

    -- Set the trains starting speed based on the test scenario.
    if testScenario.trainStartingSpeed == TrainStartingSpeed.full then
        train.speed = 1.4
    elseif testScenario.trainStartingSpeed == TrainStartingSpeed.half then
        train.speed = 0.7
    else
        train.speed = 0
    end

    -- Give the train its orders
    train.schedule = {current = 1, records = {{station = "End"}}}
    train.manual_mode = false

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_PRSMT_TestScenarioBespokeData
    local testDataBespoke = {
        testStartedTick = game.tick, ---@type Tick
        endStation = endStation, ---@type LuaEntity
        lastPlayerXPos = nil, ---@type double
        lastPlayerXMovement = nil, ---@type double
        lastPlayerXMovementPercentage = nil, ---@type double
        leavingTrain = nil ---@type LuaTrain
    }
    testData.bespoke = testDataBespoke

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
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
    local testScenario = testData.testScenario ---@type Tests_PRSMT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PRSMT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Special stuff on first tick.
    if event.tick == testDataBespoke.testStartedTick then
        -- Check that no starting speed variations has caused the tunnel to be reserved/released on the first tick.
        if tunnelUsageChanges.lastAction ~= nil then
            TestFunctions.TestFailed(testName, "train triggered tunnel in first tick and is therefore bad test setup")
        end

        -- Just end on first tick as thigns can be a little odd.
        return
    end

    -- Only check the trains acceleration once it has entered, as the entry jump will be odd due to the mod having to fight the trains speed just before the entry. So its per tick variation looks large.
    if tunnelUsageChanges.actions[Common.TunnelUsageAction.entered] == nil then
        return
    end

    -- If its a noPath test then on entry remove the endStation.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.noPath then
        if testDataBespoke.endStation.valid then
            testDataBespoke.endStation.destroy()
        end
    end

    -- Store the leavingTrain is approperiate
    local trainLeftThisTick = false
    if testDataBespoke.leavingTrain == nil and tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving then
        testDataBespoke.leavingTrain = tunnelUsageChanges.train
        trainLeftThisTick = true
    end

    -- Get players position.
    local player = game.get_player(1)
    if testDataBespoke.lastPlayerXPos == nil then
        testDataBespoke.lastPlayerXPos = player.position.x
        return
    end

    -- Get players position movement.
    local newPlayerXMovement = testDataBespoke.lastPlayerXPos - player.position.x
    -- Handle initial missing values.
    if testDataBespoke.lastPlayerXMovement == nil then
        -- It can take a tick or so for the player position to start moving.
        if newPlayerXMovement ~= 0 then
            testDataBespoke.lastPlayerXMovement = newPlayerXMovement
        end
        return
    end
    local newPlayerXMovementPercentage = Utils.RoundNumberToDecimalPlaces((newPlayerXMovement / testDataBespoke.lastPlayerXMovement) * 100, 0)

    -- Log and check the change in players movement difference for transition from underground to leaving train. Will always be a little erratic as I can't line up 2 independent speeds and positions, so this is just to provide reviewable data.
    if trainLeftThisTick then
        -- A diff between the old and new percentages of 0 is ideal. More or less than 100 indicates that a tick has been exceed.
        local diffOfPlayerXMovementPercentage = Utils.RoundNumberToDecimalPlaces(((1 / (testDataBespoke.lastPlayerXMovementPercentage / newPlayerXMovementPercentage) - 1) * 100), 0)
        game.print("leaving player difference: " .. tostring(newPlayerXMovementPercentage) .. "%")
        game.print("underground player difference: " .. tostring(testDataBespoke.lastPlayerXMovementPercentage) .. "%")
        game.print("jump in difference: " .. tostring(diffOfPlayerXMovementPercentage) .. "%")
        TestFunctions.LogTestDataToTestRow("jump: " .. tostring(diffOfPlayerXMovementPercentage) .. "% from " .. tostring(testDataBespoke.lastPlayerXMovementPercentage) .. "% to " .. tostring(newPlayerXMovementPercentage) .. "%")

        if diffOfPlayerXMovementPercentage >= 100 or diffOfPlayerXMovementPercentage <= -100 then
            TestFunctions.TestFailed(testName, "Player screen jumpped more than double the preivous tick.")
            return
        end
    end

    -- Check movement is not backwards.
    if newPlayerXMovement < 0 then
        TestFunctions.TestFailed(testName, "player movement less than 0, so going backwards.")
        return
    end

    -- Store the old movement value as we're done comparing.
    testDataBespoke.lastPlayerXPos = player.position.x
    testDataBespoke.lastPlayerXMovement = newPlayerXMovement
    testDataBespoke.lastPlayerXMovementPercentage = newPlayerXMovementPercentage

    -- If the leaving train reaches 0 speed then its stopped and the test is over.
    if testDataBespoke.leavingTrain ~= nil and testDataBespoke.leavingTrain.speed == 0 then
        TestFunctions.TestCompleted(testName)
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
    local leavingTrackConditionToTest  ---@type Tests_PRSMT_LeavingTrackCondition
    local trainStartingSpeedToTest  ---@type Tests_PRSMT_TrainStartingSpeed[]
    if DoSpecificTests then
        -- Adhock testing option.
        trainCompositionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainComposition, SpecificTrainCompositionFilter)
        tunnelOversizedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelOversized, SpecificTunnelOversizedFilter)
        leavingTrackConditionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(LeavingTrackCondition, SpecificLeavingTrackConditionFilter)
        trainStartingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStartingSpeed, SpecificTrainStartingSpeedFilter)
    elseif DoMinimalTests then
        trainCompositionToTest = {TrainComposition["<---->"]}
        tunnelOversizedToTest = {TunnelOversized.none}
        leavingTrackConditionToTest = LeavingTrackCondition
        trainStartingSpeedToTest = {TrainStartingSpeed.none, TrainStartingSpeed.full}
    else
        -- Do whole test suite.
        trainCompositionToTest = TrainComposition
        tunnelOversizedToTest = TunnelOversized
        leavingTrackConditionToTest = LeavingTrackCondition
        trainStartingSpeedToTest = TrainStartingSpeed
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainComposition in pairs(trainCompositionToTest) do
        for _, tunnelOversized in pairs(tunnelOversizedToTest) do
            for _, leavingTrackCondition in pairs(leavingTrackConditionToTest) do
                for _, trainStartingSpeed in pairs(trainStartingSpeedToTest) do
                    ---@class Tests_PRSMT_TestScenario
                    local scenario = {
                        trainComposition = trainComposition,
                        tunnelOversized = tunnelOversized,
                        leavingTrackCondition = leavingTrackCondition,
                        trainStartingSpeed = trainStartingSpeed,
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
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
