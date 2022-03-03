-- A train goes through 2 tunnels in a row. Test with different train starting speeds.
-- Train runs left to right as this way it goes through the tunnel's numbered 1 and then 2. As they are numbered as built from the BP, which is top-left to bottom right.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")

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

    local blueprint = "0eNq1Wttu2kAQ/Zd9JpVnZq+89wv6WEXIAYtaMjayTVoU8e/dBRTS4KiTWYcXsL2cM96Zczxe7Yt6ag7Vvq/bUS1fVL3u2kEtf76ood62ZZPOjcd9pZaqHqudWqi23KWjvqyb3+VxNR7atmoe9l0/ls1qqLa7qh0fhjFe3/4a1Wmh6nZT/VFLOC2EoFW7eYODp8eFihz1WFeXSM8Hx1V72D1VfSR6hUtBtDGWbh8p9t0Q/9K1iTzCPHi3UMf4HeNSm7qv1peLdqGGsbz8Vj/Gsk/3cMeBjJDvKU04U75jjFjPZV9fOWGCjT476xPURkatZ6CmKWr7X2ozAzXIqG0+tQ4yajcDtZPl2s9ALSyzMAM1yaihEGmZhFoG+IjuEP2t3/Zd/L6734c0drXuu2Go2+1UOEZWboCScKYCEKocaK4AhFoH/SUJQaH+wYjKEaX5n8HqUDrzM3gdSKd5BrMDJ+Sewe1AaLRYzMAtdFqEGbhByI353ELHR5I1i0I2LWGTkuX3aNJJzfctENoW5tsWCB+WmO9aIHxQYL5pgbAvpXzPAumbV75lodCxSPSOiUIlE31FFyRtgkjP0xRKe0IyM/ELdU72K7IhfUcgJ6lEkuY+3+O0dNrzPU4L51jne5wWtqM63+O00F51fldmhPaq8xfVjLAP1vmLauLlPNHbpXTdUt9srOnW3a4b6+dqailWv+J3fR1BrpjFNxfjXXdN16ehfTpj6PyxANp70ojegLHpsbdNlzFoAGdNICrI+kJDCAg+4TydrxcUj40DchQoGNBgiytAmQYUlwHW+4hhfbxigyer0TgPaNI69FjthhTPuktL2aY4Td36zTP/seePF6Lfz+4UqOeDGjZo4IMSF9QUfFBggwKvnJz7qJzwrpzgkmxr4w8fC8e74D2mTF8LSlt02kBRoAnOF7HmnA/FuV7OBeUcGh0KIrA6DUBHmtzM1WSQPZ0usKeT+KDsEjWaD8ouUWP4oPwStXxQfonyZW/5ieLL3vITxZe9ZSfK8mVv2YmywAZl58myBcWHZMvpE7fOVtMncsQWE7+YLFtL/Kq3bCnx5WnZSuL7iGULiW94jq0jvjM7toz4jxDHlhH/Ke/YOuK3I46tI37f5Ng64jd4zrL2LlwB6a4fv+1c+J72TDzGM+tf1ebQXHdK3NqmdBzbcwNvxly2fbyDSCDnTRrLNxtFYudf9cOF1YN2AZ1Bj5rwdPoLTcSRYg=="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "End" train stop of the 2 train stops we know are in the BP.
    local endTrainStop = placedEntitiesByGroup["train-stop"][1]
    if endTrainStop.backer_name ~= "End" then
        endTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Set the trains starting speed based on the test scenario.
    local train = placedEntitiesByGroup["locomotive"][1].train ---@type LuaTrain @ All the loco's we built are part of the same train.
    local targetSpeed
    if testScenario.startingSpeed == StartingSpeed.full then
        targetSpeed = 1.4
    elseif testScenario.startingSpeed == StartingSpeed.half then
        targetSpeed = 0.7
    else
        targetSpeed = 0
    end
    if targetSpeed > 0 then
        train.manual_mode = true
        train.speed = targetSpeed
        train.manual_mode = false
        if train.speed == 0 then
            train.speed = -targetSpeed
        end
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_ST_TestScenarioBespokeData
    local testDataBespoke = {
        endTrainStop = endTrainStop ---@type LuaEntity
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

    if testDataBespoke.endTrainStop.get_stopped_train() ~= nil then
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
