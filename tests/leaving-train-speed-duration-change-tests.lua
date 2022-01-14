--[[
    Tests that run different train types, tunnel compositions, starting speeds and leaving track scenarios. Confirms that the mod completes the activities and provides a non tunnel identical track and train for visual speed comparison.
    Repathing back through the tunnel is handled by force-repath-back-through-tunnel-tests.lua as there are a lot of combinations for it.
--]]
--

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts/test-functions")

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
    }
}
local TunnelOversized = {
    none = "none",
    portalOnly = "portalOnly",
    undergroundOnly = "undergroundOnly",
    portalAndUnderground = "portalAndUnderground"
}
local StartingSpeeds = {
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
local SpecificStartingSpeedsFilter = {} -- Pass in an array of StartingSpeeds keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.trainComposition .. "   -   Oversized: " .. testScenario.tunnelOversized .. "   -   StartingSpeeds: " .. testScenario.startingSpeeds .. "   -   " .. testScenario.leavingTrackCondition
end

-- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
-- TrainComposition,TunnelOversized,StartingSpeeds,LeavingTrackCondition   trainComposition,tunnelOversized,startingSpeeds,leavingTrackCondition
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNqN0tsKgzAMBuB3yXW98NBV+ypjDA/BBbRKW8dE+u6rCmMwBrkqafN/pTQbNMOCsyXjQW9A7WQc6OsGjnpTD/ueX2cEDeRxBAGmHvfK1jRAEECmwxfoNNwEoPHkCc/8Uax3s4wN2tjwSTofs/3DJwchYJ5cTE1mvypKiRSwxiWNeEcW2/MsC+LHzNhmzjZztpmyzYJr8knJJfkvv3BJ/gcpLqnYZMklqz9knNNjkvXX4At4onVnQ5kWqspUUclCyTyEN9IVCHU="
    -- The building bleuprint function returns 2 lists of what it built for easy caching and future reference in the test's execution.
    local _, _ = TestFunctions.BuildBlueprintFromString(blueprint, {x = 10, y = 0}, testName)

    -- Add sample test data for use in the sample EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.randomValue = math.random(1, 2)
    testData.testScenario = testScenario

    -- Schedule the sample EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- Scheduled event function to check test state each tick.
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local testScenario = testData.testScenario
end

-- Generate the combinations of different tests required.
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local trainCompositionToTest, tunnelOversizedToTest, startingSpeedsToTest, leavingTrackConditionToTest
    if DoMinimalTests then
        trainCompositionToTest = {TrainComposition["<---->"]}
        tunnelOversizedToTest = {TunnelOversized.none}
        startingSpeedsToTest = {StartingSpeeds.none, StartingSpeeds.full}
        leavingTrackConditionToTest = {LeavingTrackCondition.clear, LeavingTrackCondition.farSignal, LeavingTrackCondition.nearStation, LeavingTrackCondition.portalSignal, LeavingTrackCondition.noPath}
    elseif DoSpecificTests then
        -- Adhock testing option.
        trainCompositionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainComposition, SpecificTrainCompositionFilter)
        tunnelOversizedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TunnelOversized, SpecificTunnelOversizedFilter)
        startingSpeedsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(StartingSpeeds, SpecificStartingSpeedsFilter)
        leavingTrackConditionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(LeavingTrackCondition, SpecificLeavingTrackConditionFilter)
    else
        -- Do whole test suite.
        trainCompositionToTest = TrainComposition
        tunnelOversizedToTest = TunnelOversized
        startingSpeedsToTest = StartingSpeeds
        leavingTrackConditionToTest = LeavingTrackCondition
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainComposition in pairs(trainCompositionToTest) do
        for _, tunnelOversized in pairs(tunnelOversizedToTest) do
            for _, startingSpeed in pairs(startingSpeedsToTest) do
                for _, leavingTrackCondition in pairs(leavingTrackConditionToTest) do
                    local scenario = {
                        trainComposition = trainComposition,
                        tunnelOversized = tunnelOversized,
                        startingSpeed = startingSpeed,
                        leavingTrackCondition = leavingTrackCondition
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
