-- SAMPLE TEST FILE - Functions are populated with sample code in keeping with the other test design.
-- As a multi instance test this test file is run multiple times with each instance having different variations.

-- Any created test has to be added to the test list at the top of test-manager.lua.
-- A single test is run at a time and if the test is successful the map is cleared and the next test started. Each test only has to manage its own activities and feed back via the listed Interfaces.
-- The referenced TestFunctions file has comments on the functions for their use.
-- Tests should only use their own blueprint items lists and any searches based off thier own tracked entities. So no getting a forces train list, etc. This is to enable future concurrent running of tests.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

-- Internal test types.
--- Class name includes the abbreviation of the test name to make it unique across the mod.
---@class Tests_TMI_FirstLetterTypes
local FirstLetterTypes = {
    a = "a", -- For the letter a.
    b = "b" -- For the letter b.
}
---@class Tests_TMI_TrainStartingSpeeds
local TrainStartingSpeeds = {
    none = "none", -- 0 speed
    full = "full" -- 1.2 speed is the max of this train type and fuel type in the BP.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificFirstLetterFilter = {FirstLetterTypes.a} -- Pass in an array of FirstLetterTypes keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificTrainStartingSpeedFilter = {TrainStartingSpeeds.none} -- Pass in an array of TrainStartingSpeeds keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

--- How long the test instance runs for (ticks) before being failed as uncompleted. Should be safely longer than the maximum test instance should take to complete, but can otherwise be approx.
Test.RunTime = 3600

--- Populated when generating test scenarios.
Test.RunLoopsMax = 0

--- The test configurations are stored in this when populated by Test.GenerateTestScenarios().
---@type Tests_TMI_TestScenario[]
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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      letter: " .. testScenario.firstLetter .. "    -    Speed: " .. testScenario.trainStartingSpeed
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1md1y2jAQhd9F19CRdvXLfZ+hF50M4xgN8YyxGdukZTK8eyVMAq1Ju5JpbvCPcj6ho7MW8ht7rg9+31XNwFZvrCrbpmer72+sr7ZNUcdrw3Hv2YpVg9+xBWuKXTzriqr+URzXw6FpfL3ct91Q1Oveb3e+GZb9EO5vXwZ2WrCq2fifbCVOi0xR32xudOD0tGCBUQ2VH3t6Pjmum8Pu2XcB9CEXO9GEvrT7gNi3ffiXtonwILPUasGO4VMF6U3V+XK8qResH4rxmH3zffwKEwQQejwlwoWIE+Jr0VUXpriDw9RRv8MWmWw5ny1cJls9gG0y2foB7Fy/zQPYeJcN/2TbB7BFJtvNZ7tMtOBZkVa5OPEZ7hCqXLft2vA5+b7L2HZddm3fV8323sjndgdyujPtQDYfH8PPnfRC/g87sieHypmLuUVWzK90nxQbAnt+pcsusmJ+pct+uIj5lU7kVjrgs9mQm3MQ89m5GQeYz86da4A5iYbcSMO1nP1Wq/6yCv5zOO+pKroq0lU1XVXQVQ1ZVTm6qqWrGrqqo6vS3UJOV6W7hYKuSncLgawq6W4h0lXpbiE9WzLBLXq2ZIJb9GzJBLfo2cIEt+jZwgS36NlCuluSni2kuyXp2UK6W5KeLaC7JcnZShkAcrRSvCInK2FaSXKwEhIgyblKCKskxyqhrshrquq2bHftUL36O4o3A9p2VRC5rFn4FxNcKdu67WLTLl4RDoTSVutwYIXR1jhrw1FcdWxjA6nBSCU4B+WM5daisY7reP/5LGlASccRhZaxARiUGDlFvMs5jgCrHGqrNGhnUUtQJjLi9uLgd33sTtnGHUrFT/d2pMjJTyj+ihz8hOeUIuc+4ZGqkGS8kp8aDxPjFZ7/tBAyeCoBrAo+fdgOToowHYJryINxXAoXjLTm3XYYjTUCDTp0Skih+UXgoc6Ti1PCwkeRi1PCGk2Ri1PCclKRi1PCyldZ0lb9u6KY/OS77tR/LeJO/VO4VL74zaG+vBq4ztJ4Hma6wps243uO6W7/RDYKn99UrG7eloSfYb7rx65YIY0Do8CCRDidfgFDkmRv"
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "West" train stop of the 2 train stops we know are in the BP.
    local westTrainStop = placedEntitiesByGroup["train-stop"][1]
    if westTrainStop.backer_name ~= "West" then
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Set the trains starting speed based on the test scenario.
    -- Tests that set the train speed need to consider the train's fuel type used in their test. As very fast acceleration may nullify slower starting speeds.
    local train = placedEntitiesByGroup["locomotive"][1].train -- All the loco's we built are part of the same train.
    if testScenario.trainStartingSpeed == TrainStartingSpeeds.full then
        train.speed = -1.2 -- Train is moving backwards for Factorio reasons.
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    --- Class name includes the abbreviation of the test name to make it unique across the mod.
    ---@class Tests_TMI_TestScenarioBespokeData
    local testDataBespoke = {
        announcedTunnelUsage = false, ---@type boolean
        westTrainStop = westTrainStop ---@type LuaEntity
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
    local testScenario = testData.testScenario ---@type Tests_TMI_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_TMI_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    if tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving and not testDataBespoke.announcedTunnelUsage then
        testDataBespoke.announcedTunnelUsage = true
        game.print("train has completed tunnel trip")
    end

    if not testDataBespoke.westTrainStop.valid then
        TestFunctions.TestFailed(testName, "West station was removed")
        return
    end

    if testDataBespoke.westTrainStop.get_stopped_train() ~= nil then
        game.print("train reached West station, so stop test")
        game.print("test letter: " .. testScenario.firstLetter)
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
    local firstLettersToTest  ---@type Tests_TMI_FirstLetterTypes[]
    local trainStartingSpeedToTest  ---@type Tests_TMI_TrainStartingSpeeds[]
    if DoSpecificTests then
        -- Adhock testing option.
        firstLettersToTest = TestFunctions.ApplySpecificFilterToListByKeyName(FirstLetterTypes, SpecificFirstLetterFilter)
        trainStartingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainStartingSpeeds, SpecificTrainStartingSpeedFilter)
    elseif DoMinimalTests then
        firstLettersToTest = {FirstLetterTypes.b}
        trainStartingSpeedToTest = {TrainStartingSpeeds.none, TrainStartingSpeeds.full}
    else
        -- Do whole test suite.
        firstLettersToTest = FirstLetterTypes
        trainStartingSpeedToTest = TrainStartingSpeeds
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, firstLetter in pairs(firstLettersToTest) do
        for _, trainStartingSpeed in pairs(trainStartingSpeedToTest) do
            --- Class name includes the abbreviation of the test name to make it unique across the mod.
            ---@class Tests_TMI_TestScenario
            local scenario = {
                firstLetter = firstLetter,
                trainStartingSpeed = trainStartingSpeed
            }
            table.insert(Test.TestScenarios, scenario)
            Test.RunLoopsMax = Test.RunLoopsMax + 1
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
