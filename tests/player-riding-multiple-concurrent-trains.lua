-- Have 3 trains running at once to make sure the player stays in the right train for the tunnel ride both directions.

local Test = {}
local TestFunctions = require("scripts.test-functions")

---@class Tests_PRMCT_TrainToRide
local TrainToRide = {
    first = "first",
    second = "second",
    third = "third"
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTrainToRideFilter = {} -- Pass in an array of TrainToRide keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_PRMCT_TestScenario[]
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
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      trainToRide: " .. testScenario.trainToRide
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "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"
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the train stops.
    ---@typelist LuaEntity, LuaEntity, LuaEntity, LuaEntity, LuaEntity, LuaEntity
    local west1TrainStop, west2TrainStop, west3TrainStop, east1TrainStop, east2TrainStop, east3TrainStop
    for _, trainStop in pairs(placedEntitiesByGroup["train-stop"]) do
        if trainStop.backer_name == "West 1" then
            west1TrainStop = trainStop
        elseif trainStop.backer_name == "West 2" then
            west2TrainStop = trainStop
        elseif trainStop.backer_name == "West 3" then
            west3TrainStop = trainStop
        elseif trainStop.backer_name == "East 1" then
            east1TrainStop = trainStop
        elseif trainStop.backer_name == "East 2" then
            east2TrainStop = trainStop
        elseif trainStop.backer_name == "East 3" then
            east3TrainStop = trainStop
        else
            error("unrecognised trainstop name: " .. trainStop.backer_name)
        end
    end

    -- Get the player.
    local player = game.connected_players[1]
    if player == nil then
        error("No player 1 found to set as driver")
    end

    -- Put the player in the train.
    ---@typelist LuaTrain, LuaEntity
    local train, finishTrainStop
    if testScenario.trainToRide == TrainToRide.first then
        train = west1TrainStop.get_train_stop_trains()[1]
        finishTrainStop = east1TrainStop
    elseif testScenario.trainToRide == TrainToRide.second then
        train = west2TrainStop.get_train_stop_trains()[1]
        finishTrainStop = east2TrainStop
    elseif testScenario.trainToRide == TrainToRide.third then
        train = west3TrainStop.get_train_stop_trains()[1]
        finishTrainStop = east3TrainStop
    else
        error("unsupported TrainToRide: " .. testScenario.trainToRide)
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_PRMCT_TestScenarioBespokeData
    local testDataBespoke = {
        west1TrainStop = west1TrainStop, ---@type LuaEntity
        west3TrainStop = west2TrainStop, ---@type LuaEntity
        west2TrainStop = west3TrainStop, ---@type LuaEntity
        east1TrainStop = east1TrainStop, ---@type LuaEntity
        east2TrainStop = east2TrainStop, ---@type LuaEntity
        east3TrainStop = east3TrainStop, ---@type LuaEntity
        playerYPos = nil, ---@type double
        finishTrainStop = finishTrainStop, ---@type LuaEntity
        train = train ---@type LuaTrain
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
    local testDataBespoke = testData.bespoke ---@type Tests_PRMCT_TestScenarioBespokeData

    local player = game.get_player(1)

    -- If the player isn't in a vehicle yet then something special is happening.
    if player.vehicle == nil then
        if testDataBespoke.playerYPos == nil then
            -- Is start of test and so move the player in to the vehicle. Takes a tick for the player's position to update.
            testDataBespoke.train.front_stock.set_driver(player)
            return
        else
            -- Isn't start of the test so something has goen wrong.
            TestFunctions.TestFailed(testName, "Player isn't in vehicle after the test has started.")
            return
        end
    end

    -- If the player has just got in a vehicle for the first time capture the Y Pos to track from now on.
    if testDataBespoke.playerYPos == nil then
        testDataBespoke.playerYPos = player.position.y
    end

    if player.position.y ~= testDataBespoke.playerYPos then
        TestFunctions.TestFailed(testName, "Player Y pos didn't remain steady during train tunnel usage.")
        return
    end

    if testDataBespoke.finishTrainStop.get_stopped_train() ~= nil then
        TestFunctions.TestCompleted(testName)
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
    local trainToRideToTest  ---@type Tests_PRMCT_TrainToRide[]
    if DoSpecificTests then
        -- Adhock testing option.
        trainToRideToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TrainToRide, SpecificTrainToRideFilter)
    elseif DoMinimalTests then
        trainToRideToTest = {TrainToRide.second}
    else
        -- Do whole test suite.
        trainToRideToTest = TrainToRide
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, trainToRide in pairs(trainToRideToTest) do
        ---@class Tests_PRMCT_TestScenario
        local scenario = {
            trainToRide = trainToRide
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
