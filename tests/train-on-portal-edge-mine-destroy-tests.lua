-- Checks that the expected restrictions and effects occur when a train is stopped waiting to enter a portal on the outer edge and the tunnel is mined or destroyed.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")

---@class Tests_TOPEMDT_ActionTypes
local ActionTypes = {
    mine = "mine",
    destroy = "destroy"
}

--- How long the test instance runs for (ticks) before being failed as uncompleted. Should be safely longer than the maximum test instance should take to complete, but can otherwise be approx.
Test.RunTime = 3600

--- Populated when generating test scenarios.
Test.RunLoopsMax = 0

--- The test configurations are stored in this when populated by Test.GenerateTestScenarios().
---@type Tests_TOPEMDT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios()
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.actionType
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1mN9yojAUxt8l18CYf0Z8kb3YcRyKWZtZTJwkdNdxePcN4mxtwfb0YK8Uid/vkHzfAXImT02rj97YSNZnYmpnA1n/PJNg9rZq+t/i6ajJmpioDyQjtjr0R74yzZ/qtI2ttbrJj87HqtkGvT9oG/MQ0/n9cyRdRozd6b9kTbsMKart7kaHdZuMJIaJRg+VXg5OW9senrRPoP9yfRE21eKOCXF0If3F2R6eZHKRxp3SZ6qL7IzX9XBymZEQq+E7+aFDfwkjBANUPCYyfiGOgS+VN1cknaDxr076GE1LHFo8AK1waPkAtMShlw9AI9daPQBNp9DsU/RqPrrEkcv5ZIUj0wUqyRxJo/dobeptfu9d+hxdbd6P3dbehWDsflwNcrkpwxQzxmPngj8GL5F48R1LgXWhxLhwOueftxg6v71hGyud396wtxM6v71hb6J0fn9jyJCzxXw0MuCMzkcjw83YfDTSZoxjosyRUWZvu1h+fbwe6YtVMUxlvijku9mckn3tR2863/2naAoQXYJFeQkWVXBRBRZ9bRWNq93BRfOipxRZwVb0xqTOmyR1Xa9FoeSUeAmvWEIr5gu4KAeLUrgo2AWcgUUZ2AWcw0XBLuACKvqFdQIHC+5WvgS5VbCCrtQHXs0u7+KhH+5d/VvH/Fer06u67Kag4NzBs8xXUE140+HgtAlwLgQ4bAJsDAHOmgAbQ4CjJsBrJMBJk+A1EuCgSfgaSVAopCrUxx38XiqWU6kQ4FuchDsDnDQJdwY4afKOMzYZCfWz3rXNdQ/udZb749SThLwZM2wovttW2/Qql/2/9c0eZHrm0T4MmBUVqmRKlFIoybvuH3ksAsQ="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "West" train stop as the only train stop in the BP.
    local westTrainStop = placedEntitiesByGroup["train-stop"][1]

    -- Get a random part of the underground tunnel.
    local tunnelPart = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]

    -- Get the 3 locomotives. From left (negative X) they are: stopped train, tunnel train, waiting train.
    local trainByXPos = {}
    for _, locomotive in pairs(placedEntitiesByGroup["locomotive"]) do
        trainByXPos[locomotive.position.x] = locomotive.train
    end
    table.sort(trainByXPos)
    local lastIndex = nil
    local stoppedTrain, tunnelTrain, waitingTrain
    lastIndex, stoppedTrain = next(trainByXPos, lastIndex)
    lastIndex, tunnelTrain = next(trainByXPos, lastIndex)
    _, waitingTrain = next(trainByXPos, lastIndex)

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_TOPEMDT_TestScenarioBespokeData
    local testDataBespoke = {
        westTrainStop = westTrainStop, ---@type LuaEntity
        stoppedTrain = stoppedTrain, ---@type LuaTrain
        tunnelTrain = tunnelTrain, ---@type LuaTrain
        waitingTrain = waitingTrain, ---@type LuaTrain
        tunnelPart = tunnelPart, ---@type LuaEntity
        testPrepared = false ---@type boolean
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
    local testScenario = testData.testScenario ---@type Tests_TOPEMDT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_TOPEMDT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- We have to prepare the test and give Factorio 1 tick for the destroyed carriage to fully dissapear, otherwise the tess give wrong result.
    if not testDataBespoke.testPrepared then
        -- Do nothing until the tunnel train has used the tunnel.
        if tunnelUsageChanges.lastAction ~= "leaving" then
            return
        end

        -- Do nothing until the moving trains have stopped.
        if testDataBespoke.waitingTrain.speed ~= 0 or tunnelUsageChanges.train.speed ~= 0 then
            return
        end

        -- Stop the waiting train and remove the tunnel train so it doesn't block any test actions.
        testDataBespoke.waitingTrain.manual_mode = true
        tunnelUsageChanges.train.carriages[1].destroy()
        testDataBespoke.testPrepared = true
        return
    end

    -- Do test logic based on scenario.
    if testScenario.actionType == ActionTypes.mine then
        local player = game.connected_players[1]
        local mined = player.mine_entity(testDataBespoke.tunnelPart, true)
        if not mined then
            TestFunctions.TestFailed(testName, "tunnel part should have been mined")
            return
        end
    elseif testScenario.actionType == ActionTypes.destroy then
        testDataBespoke.tunnelPart.damage(9999999, testDataBespoke.tunnelPart.force, "impact")
        if testDataBespoke.tunnelPart.valid then
            TestFunctions.TestFailed(testName, "tunnel part didn't die")
            return
        end
    else
        error("unsupported testScenario.actionType: " .. testScenario.actionType)
    end

    -- Check that the waiting train is still present.
    if testDataBespoke.waitingTrain.valid then
        TestFunctions.TestCompleted(testName)
    else
        TestFunctions.TestFailed(testName, "waiting train removed with portal tracks")
    end
end

--- Generate the combinations of different tests required.
Test.GenerateTestScenarios = function()
    local actionTypesToTest = ActionTypes ---@type Tests_TOPEMDT_ActionTypes[]
    -- Work out the combinations of the various types that we will do a test for.
    for _, actionType in pairs(actionTypesToTest) do
        ---@class Tests_TOPEMDT_TestScenario
        local scenario = {
            actionType = actionType
        }
        table.insert(Test.TestScenarios, scenario)
        Test.RunLoopsMax = Test.RunLoopsMax + 1
    end
end

return Test
