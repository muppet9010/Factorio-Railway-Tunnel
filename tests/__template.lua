-- SAMPLE TEST FILE - MANDATORY FUNCTIONS ARE INCLUDED
-- Any created test has to be added to the test list at the top of test-manager.lua.
-- A single test is run at a time and if the test is successful the map is cleared and the next test started. Each test only has to manage its own activities and feed back via the listed Interfaces.
-- The referenced TestFunctions file has comments on the public functions for their use.

local Test = {}
local TestFunctions = require("scripts/test-functions")

-- How long the test runs for (ticks) before being failed as un-completed. Should be safely longer than the test should take to complete, but can otherwise be approx.
Test.RunTime = 3600

-- Any scheduled event types for the test must be Registered here. Most tests have an event every tick to check the test progress.
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

-- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
-- Setup test including building any blueprints via calling interface "TestManager.BuildBlueprintFromString".
Test.Start = function(testName)
    -- Add sample test data for use in the sample EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.randomValue = math.random(1, 2)

    -- Schedule the sample EveryTick() to run each game tick.
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

-- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", nil)
end

-- Example empty scheduled event function to check test state each tick.
Test.EveryTick = function(event)
    -- Get testData object and testName from the event data.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    if game.tick > 120 then
        if testData.randomValue == 1 then
            TestFunctions.TestCompleted(testName)
        else
            TestFunctions.TestFailed(testName, "abstract reason")
        end
    end
end

return Test
