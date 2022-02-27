-- A train goes through 2 tunnels in a row. Test with different train starting speeds.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

-- Internal test types.
--- Class name includes the abbreviation of the test name to make it unique across the mod.
---@class Tests_ST_StartingSpeed
local StartingSpeed = {
    none = "none",
    half = "half", --0.7
    full = "full" -- 1.4 Vanailla locomotives max speed.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificStartingSpeedFilter = {} -- Pass in an array of StartingSpeed keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0
---@type Tests_ST_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    Test.GenerateTestScenarios(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.startingSpeed
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1Wtty2jAQ/Rc9Q0er1ZX3fkMfOhnGISrx1NiMbdJmMvx7JUiTtNBWu1V4wRdxztpn9+iCnsRtd4j7se1nsXoS7WboJ7H6/CSmdts3Xb42P+6jWIl2jjuxEH2zy2dj03bfmsf1fOj72C33wzg33XqK213s5+U0p/vb+1kcF6Lt7+J3sYLjggka+7s3OOp4sxCJo53beI70dPK47g+72zgmohe4HESfYhn2iWI/TOknQ5/JE8xSybAQj+nApcjEXTvGzfm2XYhpbs7H4lOc8kNckKiCmC85wcOZ04YLzodmbJ9Z4QohUt/8FXbnuOy6Brvhspsa7MhltzXY2bq7Cuw2XGdX/2T3Ndgdlz3UYDdcdpC8GrfAZoQ/MR6S943bcUjfF0+9zG3Xm3GYprbfXovIsBUAxYnoagx8HbBaDMiOQb+TMvxcMbzs1Ow+AGoYoWbbMNRwQs32YahhhRjY9DW8ENk+oGQNerYFKKhBz65+pWrQs1NPIa/UFbvUleYxAp+xxhgP2Oaiangb8BWu4W2SbS6qhrdJvvY1vE2yzQVreJtkmwvW8DbJHkcgbyYb2F0J4rsMpQJfAF1pfBn4IphKIXj2TA/tu8ji+XniWInp2X0AVnBBx/ZgrGCC/7G+U8ED+es7uoIFOnb96wqjO8cufV1hYY+/vqMrLOxZftbx5rCWXeL61eR+cbC/LQ9fvNRruI6A6wi4noBrCLiBgIvluEYScIGAC8W4EAi6GUXAJehmkIBL0M1oAi5FN0PApehWXm/gKbo5Ai5FN0/ApehWXm+gCLpZScAl6GbL680QZLPl5WYIqtnyajME0Wx5sRmKZuW1ZiiSlZeapkj2WmndsBl2w9w+xGuYb1/sMLYJ5rkflh/ywHAzdMOYG4/5CgQFxnpr04EHZ70L3qejvAq0zQ20VU4bkFKZ4Lz0Hp0P0ub7tydIp4wOEhGszg2UQ42Zp8l3pcQzgTcBrTdW2eDRamVc5sj/Jc9xN53CGTZf47z8cohdKtPjtTdQ7gmakrTllqAJSevKHUETktZBWRrkOdSf0kBdpIHB08cC6KSwVsqbpNpLEqigISVH0hBlklHq1Ler5Oc/k0CdZXaADgMGAxqsfAaonweu3Lw0oW5duXkhoW5duXkhIWtduXkhJWtt2Z6NF0x3MdF53bLxsclbNm7Spc19vDt0z7tEXvM2nydfc/CmzXnLy2/bPm4yymmHyurNLpk0y4jjdOb1oF1QziivNKrj8Qetq8c1"
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "West" train stop of the 2 train stops we know are in the BP.
    local westTrainStop = placedEntitiesByGroup["train-stop"][1]
    if westTrainStop.backer_name ~= "West" then
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Set the trains starting speed based on the test scenario.
    local train = placedEntitiesByGroup["locomotive"][1].train -- All the loco's we built are part of the same train.
    if testScenario.startingSpeed == StartingSpeed.full then
        train.speed = 1.4
    elseif testScenario.startingSpeed == StartingSpeed.half then
        train.speed = 0.7
    else
        train.speed = 0
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_ST_TestScenarioBespokeData
    local testDataBespoke = {
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
    local testScenario = testData.testScenario ---@type Tests_ST_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_ST_TestScenarioBespokeData

    if testDataBespoke.westTrainStop.get_stopped_train() ~= nil then
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
    local startingSpeedToTest  ---@type Tests_ST_StartingSpeed[]
    if DoSpecificTests then
        -- Adhock testing option.
        startingSpeedToTest = TestFunctions.ApplySpecificFilterToListByKeyName(StartingSpeed, SpecificStartingSpeedFilter)
    elseif DoMinimalTests then
        startingSpeedToTest = {StartingSpeed.none}
    else
        -- Do whole test suite.
        startingSpeedToTest = StartingSpeed
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, startingSpeed in pairs(startingSpeedToTest) do
        --- Class name includes the abbreviation of the test name to make it unique across the mod.
        ---@class Tests_ST_TestScenario
        local scenario = {
            startingSpeed = startingSpeed
        }
        table.insert(Test.TestScenarios, scenario)
        Test.RunLoopsMax = Test.RunLoopsMax + 1
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
