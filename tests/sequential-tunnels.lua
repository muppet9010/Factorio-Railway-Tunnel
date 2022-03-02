-- A train goes through 2 tunnels in a row. Test with different train starting speeds.
-- Train runs left to right as this way it goes through the tunnel's numbered 1 and then 2. As they are numbered as built from the BP, which is top-left to botom right.

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

    local blueprint = "0eNq1WtuO2jAQ/Rc/Q5Xx+Mp7v6CP1Qpl2ZSNGhKUhG3Rin+vndCyu9B2PAm8QGJzzmQuJ2PLr+KxOhT7tqx7sXoV5aapO7H6+iq6clvnVbzXH/eFWImyL3ZiIep8F6/avKx+5Md1f6jrolrum7bPq3VXbHdF3S+7Poxvn3txWoiyfip+ihWcFkzQon56gyNPDwsROMq+LEZLh4vjuj7sHos2EP2Bi0bUwZZmHyj2TRf+0tSRPMAsnV2IY4DDAP1UtsVmHDQL0fX5+Ft86fM2PsMVhySYfE2p/Uip31MGsJe8Lc+kcIMOU91+g1szudUM3HiT2/yXW8/ADUxuM51beSa3nYHbMuPtZuDm5pqfgRuZ3JCxahq5NQ3wN75DELp22zbh++qJl3HuetM2XVfW21v2aGbOgeTYc8sCbrUDzmUBt+ZB3SUmkqsDoFk5Kdk5MIPoSbbzZ1A9YHt6BtkDyyWfQfeAq7kym4GcK7oSZiAHLrmcTs5Vf4m8DpJLpzh0bLbpfRvbr9MVDLgCJqcLGHDfnXK6fgH3rSGnyxdwu1Wcrl7AXpVNFy/J1S5krUAlt6IR79EYsfsiVPN0iuxGEfVMBnDrHc09AsJePKDlpCOy4z9d7RTb89PVTnHdrKarneI2qWq62imu0qrpnZrmKq2avvmmue2xmr75xt/3Y6092Vuc6iJoVbNpdk1fvhS3tm3VhaBpy4ByBs0+2WDxpqmaNs5t4x2Nw8cAKOdQSek0aBPfgts4LL0CsEZ7xAyNyxR4L8FFnMdhPMNwrS2gRY9egwKTnQHyOCEbJxjnAoZxYcR4h0ZJbR0MJsb97W6wp9l8L/rlt0NRBS+dbnngoqHv9Pofe9cfvXwL1dFRNR3V01GRjKozOirQUYGWWdb+NbPkVWbBGHdjwg8XcshZ75yMQT/nljLSKg1ZJrW3LgvpZ53PhtQZcstaqZXPEMGoOEFaVGjvklhakt1qPd2tSEelp6tWdFR6umpNR01IV0NHTUhXugyYhGjRZcAkRIsuA4YeLUOXAUOPlgEyKj1YhlxaCZjkwkp5enJdpQSKXFYJOWXIVZWQ/oZcVAmVasg1lSAqhlxSCfpnyRWVINWWXFAJbxVLLqiEDsCSKyqhWbHkikroqyy5ohJaQGtIJyJ+I9qr1v1yIOJzPIrxEO5snounQ3U+gHFpq+J16OQ1vJkznib5ABFBhrMfqzfnT8IioWi7kdWBsl5aLZ1UKE+nX2LEpl8="
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
