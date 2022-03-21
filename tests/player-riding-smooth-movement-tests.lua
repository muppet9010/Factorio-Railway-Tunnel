--[[
    Have a player riding in a train.
    For forwards completed journeys (non reversed) it monitors the players position to ensure its smooth. Test various train entering and leaving speeds changes. Check the players view never moves backwards. Also that the forward movement variation between ticks isn't too extreme. This is a fully automated test of player experience.
    It does test if the train has to reverse and no path, but it can't monitor player movement smoothness at all as these tests will have sudden changes. So they are for hard error detection and can be visually watched. These tests aren't run by default, see the "PlayerWatchingTests" config setting for details if being manually watched.

    If the global test setting "JustLogAllTests" is enabled then the variance of each test is recorded to the generic test result output. A jump of 0% is ideal, with more/less than 100% indicating an excess tick. At present some braking situations can exceed 100% as I want to avoid overly complicated logic in the mod to try and smooth it out.

    Usage Note: this is a slower test to run as it places varying numbers of entities everywhere so no BP's are currently used in it. Advised to run Factorio outside of the debugger as it runs much faster.
    Without "PlayerWatchingTests" being enable theres 288 tests, with it theres 3,888. So this setting should only be enabled in rare cases, but generally a specific subset of these tests to be run.
--]]
--

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")
local Utils = require("utility.utils")
local Colors = require("utility.colors")

---@class Tests_PRSMT_TrainComposition
local TrainComposition = {
    ["<"] = {
        -- Skips all reverse type tests as trian can't go backwards.
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
    portalOnly = "portalOnly"
}

---@class Tests_PRSMT_LeavingTrackCondition
local LeavingTrackCondition = {
    clear = "clear", -- Train station far away so more than braking distance.
    nearStation = "nearStation", -- A train station near to the portal so the train has to brake very aggressively leaving the portal.
    farStation = "farStation", -- A train station far to the portal so the train has to brake gently leaving the portal.
    portalSignal = "portalSignal", -- The portla exit signal will be closed so the train has to crawl out of the portal.
    nearSignal = "nearSignal", -- A signal near to the portal will be closed so the train has to brake very aggressively leaving the portal.
    farSignal = "farSignal" -- A signal far to the portal will be closed so the train has to brake gently leaving the portal.
}
---@class Tests_PRSMT_ReverseBehaviour
local ReverseBehaviour = {
    none = "none", -- Complete the main LeavingTrackCondition.
    noPath = "noPath", -- The path from the portal is removed and theres no secondary path.
    reverseSameStation = "reverseSameStation", -- The forwards path is lost, but theres a second path to the origional station behind the tunnel entrance the train should switch too.
    reverseDifferentStation = "reverseDifferentStation" -- The forwards path is lost, but theres a second schedule station behind the train it should switch too.
}
---@class Tests_PRSMT_ReverseTime @ Ignored if ReverseBehaviour is "none" as it will never be checked. The distances are approximate.
local ReverseTime = {
    entered = "entered",
    firstQuarter = "firstQuarter", -- When the player's position has passed 25% the distance between the 2 transition portal end and the leaving portal end.
    half = "half", -- When the player's position has passed 50% the distance between the 2 transition portal end and the leaving portal end.
    finalQuarter = "finalQuarter", -- When the player's position has passed 75% the distance between the 2 transition portal end and the leaving portal end.
    leaving = "leaving"
}
---@class Tests_PRSMT_TrainStartingSpeed
local TrainStartingSpeed = {
    none = "none",
    half = "half", -- Will be half the train's achievable max speed.
    full = "full" -- Will be the train's achievable max speed.
}
---@class Tests_PRSMT_FuelType
local FuelType = {
    coal = "coal",
    nuclearFuel = "nuclearFuel"
}
---@class Tests_PRSMT_BrakingForce
local BrakingForce = {
    none = "none", -- Default starting level.
    max = "max" -- 1 is vanilla game's max research level.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local PlayerWatchingTests = false -- Only applies when DoSpecificTests is FALSE. If PlayerWatchingTests is TRUE then all the reverse tests will be run. If it's FALSE then only the automatic validated tests will be run (all forwards tests). No reverse tests are known to cause a hard error and as theres no test validation on players view for them, running them unwatched will achieve nothing and generate a lot of excessive test runs (1000's). These are included as much for issue investigation, rather than proactive testing.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainCompositionFilter = {} -- Pass in an array of TrainComposition keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTunnelOversizedFilter = {} -- Pass in an array of TunnelOversized keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificLeavingTrackConditionFilter = {} -- Pass in an array of LeavingTrackCondition keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificReverseBehaviourFilter = {} -- Pass in an array of ReverseBehaviour keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificReverseTimeFilter = {} -- Pass in an array of ReverseTime keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTrainStartingSpeedFilter = {} -- Pass in an array of TrainStartingSpeed keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificFuelTypeFilter = {} -- Pass in an array of FuelType keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificBrakingForceFilter = {} -- Pass in an array of BrakingForce keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainComposition.composition .. "   -   Oversized: " .. testScenario.tunnelOversized .. "   -   " .. testScenario.leavingTrackCondition .. "   -   ReverseBehaviour: " .. testScenario.reverseBehaviour .. "   -   ReverseTime: " .. testScenario.reverseTime .. "   -   StartingSpeed: " .. testScenario.trainStartingSpeed .. "   -   " .. testScenario.fuelType .. "   -   BrakingBonus: " .. testScenario.brakingForce
end

local ReverseEastTrackBP = "0eNqV0tsKgzAMANB/yXMHa+tl66+MMZyGLaBV2ioT6b+v6hi7OJiPveQkJBngXLbYGNIO1ACU19qCOgxg6aKzcrxzfYOggBxWwEBn1XgyGZXgGZAu8AaK+yMD1I4c4Rw/HfqTbqszmvDhGZm3psNiMwEMmtqGmFqPiYIjEwY9qI3YBrsgg/n8KD37IsWTtC5ol6v7he5nlKfvKF9A5X91RuJBRn4BidYhyXtZ8YIYr2rfR/PEApisbZ78HEgY+LQS6mWDGHRo7Jx0x6N0L9KYx1wmW+/vqcHKZA=="

local ReverseWestTrackBP = "0eNqV1d1qhDAQBeB3messOIma1VcppbgatgGNi8alIr57/QlLay2ZXEnUfDkKJ5ngVg/q0WljIZ9Al63pIX+boNd3U9TrPTs+FOSgrWqAgSmaddQVuoaZgTaV+oIc53cGylhttdrnb4PxwwzNTXXLC6+Z5dA9VXXZAAaPtl/mtGZdaHEuGDMYlyuPFrzSnSr3p+nM/pj8ZfZ24e6f9l9V7irK36o8UQVdzZya+NU4XD1kFSdqQlY5OlX4s6bhauLPKumqcCr6s17DVeHPmtHVZFczf1SMgtXjHzjLikhnXQ0ILUAerGaErPRycVcDQrcwDlYJ3UJ6uYSrAaFbmAarhG6hJG6vIt3Mw+bKz0h6s4Q4/XyxngnbqZH/OGQYPFXX78teMZYZlwkmKNJonr8BvLgj1g=="

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local trackYPosition, trainDataYPosition = 1, -15
    local surface, testForce = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()
    local currentRailBuildPosition

    -- Set the braking force before anything else as it will affect some train speed data generation.
    if testScenario.brakingForce == BrakingForce.none then
        testForce.train_braking_force_bonus = 0
    elseif testScenario.brakingForce == BrakingForce.max then
        testForce.train_braking_force_bonus = 1
    else
        error("Unsupported brakingForce: " .. testScenario.brakingForce)
    end

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
    local trainData_currentPosition = {x = 1, y = trainDataYPosition}
    for i = 1, trainData_railCountToBuild do
        trainData_currentPosition.x = trainData_currentPosition.x + 1
        surface.create_entity {name = "straight-rail", position = trainData_currentPosition, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        trainData_currentPosition.x = trainData_currentPosition.x + 1
    end
    local trainData_train = TestFunctions.BuildTrain({x = 2, y = trainDataYPosition}, testScenario.trainCarriageDetails, defines.direction.west, nil, 0.001, trainFuel)
    local trainData = Utils.GetTrainSpeedCalculationData(trainData_train, trainData_train.speed, nil, trainData_train.carriages)

    -- Get the train data worked out as its added in a messy way as we need the train data during setup.
    local startingSpeedValue
    if testScenario.trainStartingSpeed == TrainStartingSpeed.none then
        startingSpeedValue = 0
    elseif testScenario.trainStartingSpeed == TrainStartingSpeed.half then
        startingSpeedValue = trainData.maxSpeed / 2
    elseif testScenario.trainStartingSpeed == TrainStartingSpeed.full then
        startingSpeedValue = trainData.maxSpeed
    else
        error("unrecognised StartingSpeed: " .. testScenario.trainStartingSpeed)
    end

    -- Work out how many tunnel parts are needed.
    local tunnelSegmentsCount = 4
    local portalSegmentsCount = math.ceil(#testScenario.trainCarriageDetails * 3.5)
    if testScenario.tunnelOversized == TunnelOversized.portalOnly then
        portalSegmentsCount = portalSegmentsCount * 4
    end

    -- Create the tunnel and portals. Build tunnel center east for the entrance and then tunnel center west for exit.
    ---@typelist double, double, double, LuaEntity
    local entranceEntryPortalPartX, entranceBlockedPortalPartX, exitEntryPortalPartX, portalBuilt
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
        portalBuilt = surface.create_entity {name = "railway_tunnel-portal_end", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)

        -- Log the blocked end of the entrance portal for use later.
        if directionData.direction == defines.direction.east then
            entranceBlockedPortalPartX = portalBuilt.position.x
        end

        -- Build the portal sections.
        for i = 1, portalSegmentsCount do
            currentRailBuildPosition.x = currentRailBuildPosition.x + (1 * directionData.xPosModifier)
            surface.create_entity {name = "railway_tunnel-portal_segment-straight", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
            currentRailBuildPosition.x = currentRailBuildPosition.x + (1 * directionData.xPosModifier)
        end

        -- Build the entry end of portal.
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)
        portalBuilt = surface.create_entity {name = "railway_tunnel-portal_end", position = currentRailBuildPosition, direction = directionData.direction, force = testForce, raise_built = true, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x + (3 * directionData.xPosModifier)

        -- Log the entry end of each portal for use later.
        if directionData.direction == defines.direction.east then
            entranceEntryPortalPartX = portalBuilt.position.x
        else
            exitEntryPortalPartX = portalBuilt.position.x
        end
    end

    -- Work out how much rail to build at the start of the tunnel.
    -- All situations need enough room for the train plus some padding rails.
    local railCountEntranceEndOfPortal = math.ceil(#testScenario.trainCarriageDetails * 3.5) + 5
    if testScenario.trainStartingSpeed ~= TrainStartingSpeed.none then
        -- Add extra starting distance to cover the trains starting speed's braking distance. So that the trains don't start the test braking into or using the tunnel.
        local _, stoppingDistance = Utils.CalculateBrakingTrainTimeAndDistanceFromInitialToFinalSpeed(trainData, startingSpeedValue, 0, 0)
        railCountEntranceEndOfPortal = railCountEntranceEndOfPortal + math.ceil(stoppingDistance / 2)
    end

    -- Build the pre tunnel rail, includes rails for the train to be placed on.
    currentRailBuildPosition.x = entranceEntryPortalPartX + 3
    for i = 1, railCountEntranceEndOfPortal do
        currentRailBuildPosition.x = currentRailBuildPosition.x + 1
        surface.create_entity {name = "straight-rail", position = currentRailBuildPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        currentRailBuildPosition.x = currentRailBuildPosition.x + 1
    end

    -- Build the train, have to use a fake constant speed to generate acceleration data.
    local train = TestFunctions.BuildTrain({x = currentRailBuildPosition.x - (#testScenario.trainCarriageDetails * 7), y = trackYPosition}, testScenario.trainCarriageDetails, defines.direction.west, 1, 0.1, trainFuel)

    -- Add the post tunnel parts.
    local nearPositionDistance, farPositionDistance = 20, 100
    local nearPositionX, farPositionX = exitEntryPortalPartX - nearPositionDistance, exitEntryPortalPartX - farPositionDistance

    -- Work out how much post tunneltrack is needed.
    local railCountLeavingEndOfPortal
    if testScenario.leavingTrackCondition == LeavingTrackCondition.clear then
        -- Its a clear exit test then work out the railCountLeavingEndOfPortal length from the built train after building the entrance side of the portal.
        local _, stoppingDistance = Utils.CalculateBrakingTrainTimeAndDistanceFromInitialToFinalSpeed(trainData, trainData.maxSpeed, 0, 0)
        railCountLeavingEndOfPortal = math.ceil(stoppingDistance / 2) + 10 -- This is excessive still as many trains won't be going at max speed when leaving, but I don't know how to simply work out leaving speed from test starting data only.
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation or testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
        -- Build the shorter rail length plus 30 tiles for a blocking loco if needed. 10 was for regular tests, but the reverse loop tests needs the 30.
        railCountLeavingEndOfPortal = (nearPositionDistance + 30) / 2
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal or testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
        -- Build the far rail length plus 30 tiles for a blocking loco if needed. 10 was for regular tests, but the reverse loop tests needs the 30.
        railCountLeavingEndOfPortal = (farPositionDistance + 30) / 2
    else
        error("unsupported testScenario.leavingTrackCondition: " .. testScenario.leavingTrackCondition)
    end

    -- Build the post tunnel rail.
    ---@typelist double, LuaEntity,LuaEntity
    local farLeftBuildPositionX, firstLeavingRailEntity, builtRail
    currentRailBuildPosition.x = exitEntryPortalPartX - 3
    for i = 1, railCountLeavingEndOfPortal do
        currentRailBuildPosition.x = currentRailBuildPosition.x - 1
        builtRail = surface.create_entity {name = "straight-rail", position = currentRailBuildPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        if firstLeavingRailEntity == nil then
            firstLeavingRailEntity = builtRail
        end
        currentRailBuildPosition.x = currentRailBuildPosition.x - 1
        farLeftBuildPositionX = currentRailBuildPosition.x
    end

    -- Add the station.
    local railStopPosition
    if testScenario.leavingTrackCondition == LeavingTrackCondition.nearStation then
        railStopPosition = {x = nearPositionX + 1, y = trackYPosition - 2}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farStation then
        railStopPosition = {x = farPositionX + 1, y = trackYPosition - 2}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
        -- Needs the extra space the loop back tests.
        railStopPosition = {x = nearPositionX - 29, y = trackYPosition - 2}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Needs the extra space the loop back tests.
        railStopPosition = {x = farPositionX - 29, y = trackYPosition - 2}
    else
        -- All other cases just add the station to the end of exit track built.
        railStopPosition = {x = farLeftBuildPositionX + 1, y = trackYPosition - 2}
    end
    local endStation = surface.create_entity {name = "train-stop", position = railStopPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
    endStation.backer_name = "End"

    -- Set up the LeavingTrackConditions that need adhock stuff adding.
    if testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
        -- Put a loco just after the portal to close the portal's exit signal.
        surface.create_entity {name = "locomotive", position = {x = nearPositionX + 10, y = trackYPosition}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        -- Add a signal after the loco for the reverse loop tests. Won't do any harm for the others.
        surface.create_entity {name = "rail-signal", position = {x = nearPositionX + 4, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
        -- Put a signal at the near position and a loco to close it just after.
        surface.create_entity {name = "rail-signal", position = {x = nearPositionX - 0.5, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        surface.create_entity {name = "locomotive", position = {x = nearPositionX - 5, y = trackYPosition}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        -- Add a signal after the loco for the reverse loop tests. Won't do any harm for the others.
        surface.create_entity {name = "rail-signal", position = {x = nearPositionX - 11, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
    elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
        -- Put a signal at the far position and a loco to close it just after.
        surface.create_entity {name = "rail-signal", position = {x = farPositionX - 0.5, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        surface.create_entity {name = "locomotive", position = {x = farPositionX - 5, y = trackYPosition}, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
        -- Add a signal after the loco for the reverse loop tests. Won't do any harm for the others.
        surface.create_entity {name = "rail-signal", position = {x = farPositionX - 11, y = trackYPosition - 1.5}, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
    end

    -- Add the reverse loop track back to the origional station if approperiate for test.
    if testScenario.reverseBehaviour == ReverseBehaviour.reverseSameStation then
        -- Add the entrance portal side loopback track.
        TestFunctions.BuildBlueprintFromString(ReverseEastTrackBP, {x = entranceEntryPortalPartX + 9, y = trackYPosition - 12}, testName)

        -- Add straight track the length of the portals and tunnels. Technically this is longer than needed, but won't do any harm.
        local loopbackRailBuildPosition = {x = entranceEntryPortalPartX + 2, y = trackYPosition - 22}
        local loopbackRailCount
        if testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
            loopbackRailCount = ((entranceEntryPortalPartX - nearPositionX) / 2) + 2
        elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
            loopbackRailCount = ((entranceEntryPortalPartX - farPositionX) / 2) + 2
        else
            loopbackRailCount = ((entranceEntryPortalPartX - exitEntryPortalPartX) / 2) + 2
        end
        for i = 1, loopbackRailCount do
            loopbackRailBuildPosition.x = loopbackRailBuildPosition.x - 1
            surface.create_entity {name = "straight-rail", position = loopbackRailBuildPosition, direction = defines.direction.west, force = testForce, raise_built = false, create_build_effect_smoke = false}
            loopbackRailBuildPosition.x = loopbackRailBuildPosition.x - 1
        end

        -- Add the merge track to get the loop back on to the main track on the exit portal side so that it can reach the origional station.
        local exitSideXPos
        if testScenario.leavingTrackCondition == LeavingTrackCondition.portalSignal then
            exitSideXPos = exitEntryPortalPartX - 12
        elseif testScenario.leavingTrackCondition == LeavingTrackCondition.nearSignal then
            exitSideXPos = nearPositionX - 8
        elseif testScenario.leavingTrackCondition == LeavingTrackCondition.farSignal then
            exitSideXPos = farPositionX - 8
        else
            -- Other non special cases we can just put it close to the exit tunnel.
            exitSideXPos = exitEntryPortalPartX + 2
        end
        TestFunctions.BuildBlueprintFromString(ReverseWestTrackBP, {x = exitSideXPos, y = trackYPosition - 12}, testName)
    end

    -- Add the reverse station if approperiate for test.
    local reverseStation
    if testScenario.reverseBehaviour == ReverseBehaviour.reverseDifferentStation then
        -- Put the station 10 tiles beyond the entrance portal plus the trains length. There will always be track to this distance.
        local reverseRailStopPosition = {x = entranceEntryPortalPartX + 10 + (#testScenario.trainCarriageDetails * 7), y = trackYPosition + 2}
        reverseStation = surface.create_entity {name = "train-stop", position = reverseRailStopPosition, direction = defines.direction.east, force = testForce, raise_built = false, create_build_effect_smoke = false}
        reverseStation.backer_name = "ReverseEnd"
    end

    -- Set the trains starting speed to the value preiovusly worked out for the test scenario.
    train.speed = startingSpeedValue

    -- Give the train its orders
    local trainSchedule = {current = 1, records = {{station = "End"}}}
    if reverseStation ~= nil then
        table.insert(trainSchedule.records, {station = "ReverseEnd"})
    end
    train.schedule = trainSchedule
    train.manual_mode = false

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_PRSMT_TestScenarioBespokeData
    local testDataBespoke = {
        testStartedTick = game.tick, ---@type Tick
        endStation = endStation, ---@type LuaEntity
        reverseStation = reverseStation, ---@type LuaEntity
        firstLeavingRailEntity = firstLeavingRailEntity, ---@type LuaEntity
        entranceEntryPortalPartX = entranceEntryPortalPartX, ---@type double
        entranceBlockedPortalPartX = entranceBlockedPortalPartX, ---@type double
        exitEntryPortalPartX = exitEntryPortalPartX, ---@type double
        lastPlayerXPos = nil, ---@type double
        lastPlayerXMovement = nil, ---@type double
        lastPlayerXMovementPercentage = nil, ---@type double
        leavingTrain = nil, ---@type LuaTrain
        reverseActionDone = false ---@type boolean
    }
    testData.bespoke = testDataBespoke

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Stop = function(testName)
    -- Return the force bonuses back to default.
    TestFunctions.GetTestForce().train_braking_force_bonus = 0

    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

--- Scheduled event function to check test state each tick.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_PRSMT_TestScenario

    --Work out which tick handler function to run for the test.
    if testScenario.reverseBehaviour == ReverseBehaviour.none then
        Test.EveryTick_StraightThrough(event)
    else
        Test.EveryTick_Reverse(event)
    end
end

--- The checks if the test is a straight through run.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick_StraightThrough = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_PRSMT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PRSMT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    local player = game.get_player(1)
    local player_position = player.position

    -- Special stuff on first tick.
    if event.tick == testDataBespoke.testStartedTick then
        -- Check that no starting speed variations has caused the tunnel to be reserved/released on the first tick.
        if tunnelUsageChanges.lastAction ~= nil then
            TestFunctions.TestFailed(testName, "train triggered tunnel in first tick and is therefore bad test setup")
        end

        -- Just end on first tick as things can be a little odd.
        return
    end

    -- Only do anything once the train has entered. As the entry jump will be odd due to the mod having to fight the trains speed just before the entry. So its per tick variation looks large. Also we don't have any reverse action that needs to trigger before then and it makes the maths simplier.
    if tunnelUsageChanges.actions[Common.TunnelUsageAction.entered] == nil then
        return
    end

    -- Store the leavingTrain is approperiate
    local trainLeftThisTick = false
    if testDataBespoke.leavingTrain == nil and tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving then
        testDataBespoke.leavingTrain = tunnelUsageChanges.train
        trainLeftThisTick = true
    end

    -- Get players position.
    if testDataBespoke.lastPlayerXPos == nil then
        testDataBespoke.lastPlayerXPos = player_position.x
        return
    end

    -- Get players position movement.
    local newPlayerXMovement = testDataBespoke.lastPlayerXPos - player_position.x
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
        -- Log the variance for if JustLogAllTests is enabled. Its logged with a comma both sides so the text file can be imported in to excel and split on comma for value sorting. Not perfect, but good enough bodge.
        TestFunctions.LogTestDataToTestRow(",jump: ," .. tostring(diffOfPlayerXMovementPercentage) .. "%, from ," .. tostring(testDataBespoke.lastPlayerXMovementPercentage) .. "%, to ," .. tostring(newPlayerXMovementPercentage) .. "%,")

        if diffOfPlayerXMovementPercentage > 100 or diffOfPlayerXMovementPercentage < -100 then
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
    testDataBespoke.lastPlayerXPos = player_position.x
    testDataBespoke.lastPlayerXMovement = newPlayerXMovement
    testDataBespoke.lastPlayerXMovementPercentage = newPlayerXMovementPercentage

    -- If the leaving train reaches 0 speed then its stopped and the test is over.
    if testDataBespoke.leavingTrain ~= nil and testDataBespoke.leavingTrain.speed == 0 then
        TestFunctions.TestCompleted(testName)
        return
    end
end

--- The checks if the test is a reverse run.
---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick_Reverse = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_PRSMT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PRSMT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    local player = game.get_player(1)
    local player_position = player.position

    -- Special stuff on first tick.
    if event.tick == testDataBespoke.testStartedTick then
        -- Check that no starting speed variations has caused the tunnel to be reserved/released on the first tick.
        if tunnelUsageChanges.lastAction ~= nil then
            TestFunctions.TestFailed(testName, "train triggered tunnel in first tick and is therefore bad test setup")
        end

        -- Just end on first tick as things can be a little odd.
        return
    end

    -- Only do anything once the train has entered. As the entry jump will be odd due to the mod having to fight the trains speed just before the entry. So its per tick variation looks large. Also we don't have any reverse action that needs to trigger before then and it makes the maths simplier.
    if tunnelUsageChanges.actions[Common.TunnelUsageAction.entered] == nil then
        return
    end

    -- We only do the reverse action once and until its done check nothing further.
    if not testDataBespoke.reverseActionDone then
        -- Track the player containers progress between the start and end points.
        local progressThroughTunnelPercent  ---@type double
        if tunnelUsageChanges.actions[Common.TunnelUsageAction.entered] ~= nil then
            local distanceInFromEntrance = testDataBespoke.entranceBlockedPortalPartX - player_position.x
            local tunnelLength = (testDataBespoke.entranceBlockedPortalPartX - testDataBespoke.exitEntryPortalPartX)
            progressThroughTunnelPercent = (distanceInFromEntrance / tunnelLength) * 100
        end

        -- Work out if to do the reverse action now.
        local doAction = false
        if testScenario.reverseTime == ReverseTime.entered then
            doAction = true
        elseif testScenario.reverseTime == ReverseTime.leaving then
            if tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving] ~= nil then
                doAction = true
            end
        elseif testScenario.reverseTime == ReverseTime.firstQuarter then
            if progressThroughTunnelPercent >= 25 then
                doAction = true
            end
        elseif testScenario.reverseTime == ReverseTime.half then
            if progressThroughTunnelPercent >= 50 then
                doAction = true
            end
        elseif testScenario.reverseTime == ReverseTime.finalQuarter then
            if progressThroughTunnelPercent >= 75 then
                doAction = true
            end
        else
            error("unsupported testScenario.reverseTime: " .. testScenario.reverseTime)
        end

        -- If the action should be done now do the right one.
        if doAction then
            testDataBespoke.reverseActionDone = true

            if testScenario.reverseBehaviour == ReverseBehaviour.noPath or testScenario.reverseBehaviour == ReverseBehaviour.reverseDifferentStation then
                if testDataBespoke.endStation.valid then
                    testDataBespoke.endStation.destroy {raise_destroy = false}
                end
            elseif testScenario.reverseBehaviour == ReverseBehaviour.reverseSameStation then
                if testDataBespoke.firstLeavingRailEntity.valid then
                    testDataBespoke.firstLeavingRailEntity.destroy {raise_destroy = false}
                end
            else
                error("unsupported testScenario.reverseBehaviour: " .. testScenario.reverseBehaviour)
            end
        end

        -- Check nothing else this tick.
        return
    end

    -- Store the leavingTrain is approperiate
    if testDataBespoke.leavingTrain == nil and tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving then
        testDataBespoke.leavingTrain = tunnelUsageChanges.train
    end

    -- If theres no leaving train yet then the test can't have been completed.
    if testDataBespoke.leavingTrain == nil then
        return
    end

    -- Work out if the test is completed.
    if testScenario.reverseBehaviour == ReverseBehaviour.noPath then
        if testDataBespoke.leavingTrain.speed == 0 then
            TestFunctions.TestCompleted(testName)
            return
        end
    elseif testScenario.reverseBehaviour == ReverseBehaviour.reverseDifferentStation then
        if testDataBespoke.reverseStation.get_stopped_train() ~= nil then
            TestFunctions.TestCompleted(testName)
            return
        end
    elseif testScenario.reverseBehaviour == ReverseBehaviour.reverseSameStation then
        if testDataBespoke.endStation.get_stopped_train() ~= nil then
            TestFunctions.TestCompleted(testName)
            return
        end
    else
        error("unsupported testScenario.reverseBehaviour: " .. testScenario.reverseBehaviour)
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
    local trainCompositionToTest  ---@type Tests_LTSDCT_TrainComposition[]
    local tunnelOversizedToTest  ---@type Tests_LTSDCT_TunnelOversized[]
    local leavingTrackConditionToTest  ---@type Tests_PRSMT_LeavingTrackCondition[]
    local reverseBehaviourToTest  ---@type Tests_PRSMT_ReverseBehaviour[]
    local reverseTimeToTest  ---@type Tests_PRSMT_ReverseTime[]
    local trainStartingSpeedToTest  ---@type Tests_PRSMT_TrainStartingSpeed[]
    local fuelTypeToTest  ---@type Tests_PRSMT_FuelType
    local brakingForceToTest  ---@type Tests_PRSMT_BrakingForce
    if DoSpecificTests then
        -- Adhock testing option.
        trainCompositionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainComposition, SpecificTrainCompositionFilter)
        tunnelOversizedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelOversized, SpecificTunnelOversizedFilter)
        leavingTrackConditionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(LeavingTrackCondition, SpecificLeavingTrackConditionFilter)
        reverseBehaviourToTest = TestFunctions.ApplySpecificFilterToListByKeyName(ReverseBehaviour, SpecificReverseBehaviourFilter)
        reverseTimeToTest = TestFunctions.ApplySpecificFilterToListByKeyName(ReverseTime, SpecificReverseTimeFilter)
        trainStartingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStartingSpeed, SpecificTrainStartingSpeedFilter)
        fuelTypeToTest = TestFunctions.ApplySpecificFilterToListByKeyName(FuelType, SpecificFuelTypeFilter)
        brakingForceToTest = TestFunctions.ApplySpecificFilterToListByKeyName(BrakingForce, SpecificBrakingForceFilter)
    elseif DoMinimalTests then
        trainCompositionToTest = {TrainComposition["<---->"]}
        tunnelOversizedToTest = {TunnelOversized.none}
        leavingTrackConditionToTest = LeavingTrackCondition
        reverseBehaviourToTest = {ReverseBehaviour.none, ReverseBehaviour.reverseDifferentStation}
        reverseTimeToTest = {ReverseTime.half}
        trainStartingSpeedToTest = {TrainStartingSpeed.half}
        fuelTypeToTest = {FuelType.coal}
        brakingForceToTest = {BrakingForce.max}
    else
        -- Do whole test suite.
        trainCompositionToTest = TrainComposition
        tunnelOversizedToTest = TunnelOversized
        leavingTrackConditionToTest = LeavingTrackCondition
        if PlayerWatchingTests then
            reverseBehaviourToTest = ReverseBehaviour
            reverseTimeToTest = ReverseTime
        else
            reverseBehaviourToTest = {ReverseBehaviour.none}
            reverseTimeToTest = {ReverseTime.entered}
        end
        trainStartingSpeedToTest = TrainStartingSpeed
        fuelTypeToTest = FuelType
        brakingForceToTest = BrakingForce
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainComposition in pairs(trainCompositionToTest) do
        for _, tunnelOversized in pairs(tunnelOversizedToTest) do
            for _, leavingTrackCondition in pairs(leavingTrackConditionToTest) do
                for _, trainStartingSpeed in pairs(trainStartingSpeedToTest) do
                    for _, fuelType in pairs(fuelTypeToTest) do
                        for _, brakingForce in pairs(brakingForceToTest) do
                            -- Don't put any non reverse related tests deeper within this FOR loop as in some cases only 1 iteration of this loop ha a test added for it.
                            local reverseBehaviourNone_singleTestAdded = false
                            for _, reverseBehaviour in pairs(reverseBehaviourToTest) do
                                for _, reverseTime in pairs(reverseTimeToTest) do
                                    local addTest = true

                                    -- Just allow 1 reverseTime test to be added if theres no reverse behaviour. The value of reverseTime will be ignored anyways, but no point repeating the same test over and over.
                                    if reverseBehaviour == ReverseBehaviour.none then
                                        if not reverseBehaviourNone_singleTestAdded then
                                            reverseBehaviourNone_singleTestAdded = true
                                        else
                                            addTest = false
                                        end
                                    end

                                    -- If its the single forwards loco test "<" skip all reverse type tests as they will just sit there.
                                    if trainComposition == TrainComposition["<"] then
                                        if reverseBehaviour == ReverseBehaviour.reverseSameStation or reverseBehaviour == ReverseBehaviour.reverseDifferentStation then
                                            addTest = false
                                        end
                                    end

                                    if addTest then
                                        ---@class Tests_PRSMT_TestScenario
                                        local scenario = {
                                            trainComposition = trainComposition,
                                            tunnelOversized = tunnelOversized,
                                            leavingTrackCondition = leavingTrackCondition,
                                            reverseBehaviour = reverseBehaviour,
                                            reverseTime = reverseTime,
                                            trainStartingSpeed = trainStartingSpeed,
                                            fuelType = fuelType,
                                            brakingForce = brakingForce,
                                            trainCarriageDetails = TestFunctions.GetTrainCompositionFromTextualRepresentation(trainComposition)
                                        }
                                        table.insert(Test.TestScenarios, scenario)
                                        Test.RunLoopsMax = Test.RunLoopsMax + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- If there are no tests due to the exclusions write it to the screen.
    if #Test.TestScenarios == 0 then
        game.print("No tests after invalid combinations filtered out.", Colors.red)
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
