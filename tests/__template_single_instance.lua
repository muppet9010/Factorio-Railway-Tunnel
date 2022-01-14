-- SAMPLE TEST FILE - Functions are populated with sample code in keeping with the other test design.
-- As a single instance test this test file is run just once.
-- Any created test has to be added to the test list at the top of test-manager.lua.
-- A single test is run at a time and if the test is successful the map is cleared and the next test started. Each test only has to manage its own activities and feed back via the listed Interfaces.
-- The referenced TestFunctions file has comments on the functions for their use.
-- Tests should only use thier own blueprint items lists and any searched based off thier own tracked entities. SO no getting a forces train list, etc. This is to enable future concurrent running of tests.

local Test = {}
local TestFunctions = require("scripts/test-functions")

-- How long the test runs for (ticks) before being failed as un-completed. Should be safely longer than the test should take to complete, but can otherwise be approx.
Test.RunTime = 3600

-- Any scheduled event types for the test must be Registered here. Most tests will want an event every tick to check the test progress.
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

-- OPTIONAL, can exclude the attribute. If present it will be called when starting a test and the returned name used, otherwise the test name as defined in test-manager.lua is used.
Test.GetTestDisplayName = function(testName)
    return testName
end

-- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
Test.Start = function(testName)
    local blueprint = "0eNqN0tsKgzAMBuB3yXW98NBV+ypjDA/BBbRKW8dE+u6rCmMwBrkqafN/pTQbNMOCsyXjQW9A7WQc6OsGjnpTD/ueX2cEDeRxBAGmHvfK1jRAEECmwxfoNNwEoPHkCc/8Uax3s4wN2tjwSTofs/3DJwchYJ5cTE1mvypKiRSwxiWNeEcW2/MsC+LHzNhmzjZztpmyzYJr8knJJfkvv3BJ/gcpLqnYZMklqz9knNNjkvXX4At4onVnQ5kWqspUUclCyTyEN9IVCHU="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, _ = TestFunctions.BuildBlueprintFromString(blueprint, {x = 10, y = 0}, testName)

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.randomValue = math.random(1, 2)

    -- Schedule the EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- EXAMPLE - scheduled event function to check test state each tick.
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    if game.tick > 300 then
        game.print("Test Data Random Number: " .. testData.randomValue)
        if testData.randomValue > 0 then
            TestFunctions.TestCompleted(testName)
        else
            TestFunctions.TestFailed(testName, "abstract reason")
        end
    end
end

return Test
