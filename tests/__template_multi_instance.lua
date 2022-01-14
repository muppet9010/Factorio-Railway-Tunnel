-- SAMPLE TEST FILE - Functions are populated with sample code in keeping with the other test design.
-- As a multi instance test this test file is run multiple times with each instance having different variations.
-- Any created test has to be added to the test list at the top of test-manager.lua.
-- A single test is run at a time and if the test is successful the map is cleared and the next test started. Each test only has to manage its own activities and feed back via the listed Interfaces.
-- The referenced TestFunctions file has comments on the functions for their use.
-- Tests should only use their own blueprint items lists and any searched based off thier own tracked entities. SO no getting a forces train list, etc. This is to enable future concurrent running of tests.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts/test-functions")

-- Internal test types.
local FirstLetterTypes = {
    a = "a", -- For the letter a.
    b = "b", -- For the letter b.
    c = "c" -- For the letter c.
}
local SecondLetterTypes = {
    n = "n", -- For the letter a.
    o = "o" -- For the letter b.
}

-- Test configuration.
local DoMinimalTests = false -- The minimal test to prove the concept. Just does the letter "b".

local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificFirstLetterFilter = {FirstLetterTypes.a, FirstLetterTypes.b} -- Pass in an array of FirstLetterTypes keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificSecondLetterFilter = {SecondLetterTypes.o} -- Pass in an array of SecondLetterTypes keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.firstLetter .. " - " .. testScenario.secondLetter
end

-- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNqN0tsKgzAMBuB3yXW98NBV+ypjDA/BBbRKW8dE+u6rCmMwBrkqafN/pTQbNMOCsyXjQW9A7WQc6OsGjnpTD/ueX2cEDeRxBAGmHvfK1jRAEECmwxfoNNwEoPHkCc/8Uax3s4wN2tjwSTofs/3DJwchYJ5cTE1mvypKiRSwxiWNeEcW2/MsC+LHzNhmzjZztpmyzYJr8knJJfkvv3BJ/gcpLqnYZMklqz9knNNjkvXX4At4onVnQ5kWqspUUclCyTyEN9IVCHU="
    -- The building bleuprint function returns 2 lists of what it built for easy caching and future reference in the test's execution.
    local _, _ = TestFunctions.BuildBlueprintFromString(blueprint, {x = 10, y = 0}, testName)

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.randomValue = math.random(1, 2)
    testData.testScenario = testScenario

    -- Schedule the EveryTick() to run each game tick.
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

    if game.tick > 300 then
        game.print("Test Scenario First Letter: " .. testScenario.firstLetter)
        game.print("Test Scenario Second Letter: " .. testScenario.secondLetter)
        game.print("Test Data Random Number: " .. testData.randomValue)
        if testData.randomValue > 0 then
            TestFunctions.TestCompleted(testName)
        else
            TestFunctions.TestFailed(testName, "abstract reason")
        end
    end
end

-- Generate the combinations of different tests required.
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local firstLettersToTest, secondLettersToTest
    if DoMinimalTests then
        firstLettersToTest = {FirstLetterTypes.b}
        secondLettersToTest = {SecondLetterTypes.n}
    elseif DoSpecificTests then
        -- Adhock testing option.
        firstLettersToTest = TestFunctions.ApplySpecificFilterToListByKeyName(FirstLetterTypes, SpecificFirstLetterFilter)
        secondLettersToTest = TestFunctions.ApplySpecificFilterToListByKeyName(SecondLetterTypes, SpecificSecondLetterFilter)
    else
        -- Do whole test suite.
        firstLettersToTest = FirstLetterTypes
        secondLettersToTest = SecondLetterTypes
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, firstLetter in pairs(firstLettersToTest) do
        for _, secondLetter in pairs(secondLettersToTest) do
            local scenario = {
                firstLetter = firstLetter,
                secondLetter = secondLetter
            }
            table.insert(Test.TestScenarios, scenario)
            Test.RunLoopsMax = Test.RunLoopsMax + 1
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, {"firstLetter", "secondLetter"}, Test.TestScenarios)
    end
end

return Test
