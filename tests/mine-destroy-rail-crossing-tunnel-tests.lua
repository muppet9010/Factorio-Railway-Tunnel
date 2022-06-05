-- Tries to mine and destroy a tunnel with a crossing rail with a train on and off the crossing rail.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")
local TableUtils = require("utility.table-utils")

-- Internal test types.
---@class Tests_MDRCTT_ActionTypes
local ActionTypes = {
    mine = "mine",
    destroy = "destroy"
}
---@class Tests_MDRCTT_SegmentsToRemove
local SegmentsToRemove = {
    crossingRail = "crossingRail",
    portalEnd = "portalEnd"
}
---@class Tests_MDRCTT_BlockingTrainTypes
local BlockingTrainTypes = {
    none = "none",
    onCrossingRail = "onCrossingRail"
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificActionTypesFilter = {} -- Pass in an array of ActionTypes keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificBlockingTrainTypesFilter = {} -- Pass in an array of BlockingTrainTypes keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificSegmentsToRemoveFilter = {} -- Pass in an array of SegmentsToRemove keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

--- How long the test instance runs for (ticks) before being failed as uncompleted. Should be safely longer than the maximum test instance should take to complete, but can otherwise be approx.
Test.RunTime = 3600

--- Populated when generating test scenarios.
Test.RunLoopsMax = 0

--- The test configurations are stored in this when populated by Test.GenerateTestScenarios().
---@type Tests_MDRCTT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.actionType .. "    -    segmentToRemove: " .. testScenario.segmentToRemove .. "    -    blockingTrain: " .. testScenario.blockingTrainType
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local surface, force = TestFunctions.GetTestSurface(), TestFunctions.GetTestForce()

    local blueprint = "0eNqllN1qhTAMgN8l1xVWf+bRVxlDejS4gkZp6zYR331Rbw6TwVm8KmnSfPlrFrh3E47OUoByAVsP5KF8W8Dblky33YV5RCjBBuxBAZl+k5yx3ZeZqzARYReNgwumq5AaWBVYavAbSr0qoR+PbY8UIh9Y336EB6fx+q6AdTZYPCLdhbmiqb+jY+oTMSoYB88eBtoCY6+R5mcznwmTGuuwPpSxgk/jrDmkPaFfuPi/qZzZuRCdXEdnQnR6HZ0I0Zmkv9Luvv4Fm3gaXesGPk/JRpttVbvBe0vtORhp0XNJ5oUQdrvcYS3tcHEdLS2xfrnOln5nLdpc8XOjzUtzX7zlw75nE3T+ML/pNC/iPC2yNM+Sdf0BKsEbFQ=="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local allBuiltEntities, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 1, y = 1}, testName)

    -- Get the crossing tunnel segment
    local crossingTunnelSegment = TableUtils.GetTableValueWithInnerKeyValue(allBuiltEntities, "name", "railway_tunnel-underground_segment-straight-rail_crossing", false, false) --- @type LuaEntity

    -- Get a portal end, any will do
    local portalEnd = placedEntitiesByGroup["railway_tunnel-portal_end"][1]

    -- If the test needs a train add it.
    local blockingLocomotive  ---@type LuaEntity
    if testScenario.blockingTrainType == BlockingTrainTypes.onCrossingRail then
        blockingLocomotive = surface.create_entity {name = "locomotive", position = crossingTunnelSegment.position, orientation = 0, force = force, raise_built = false, create_build_effect_smoke = false}
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_MDRCTT_TestScenarioBespokeData
    local testDataBespoke = {
        crossingTunnelSegment = crossingTunnelSegment, ---@type LuaEntity
        portalEnd = portalEnd, ---@type LuaEntity
        blockingLocomotive = blockingLocomotive ---@type LuaEntity|null
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
    local testScenario = testData.testScenario ---@type Tests_MDRCTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_MDRCTT_TestScenarioBespokeData

    local entityToRemove, entityPrintFriendlyName
    if testScenario.segmentToRemove == SegmentsToRemove.crossingRail then
        entityToRemove = testDataBespoke.crossingTunnelSegment
        entityPrintFriendlyName = "tunnel crossing segment"
    elseif testScenario.segmentToRemove == SegmentsToRemove.portalEnd then
        entityToRemove = testDataBespoke.portalEnd
        entityPrintFriendlyName = "portal end"
    end

    if testScenario.actionType == ActionTypes.mine then
        local player = game.connected_players[1]
        local mined = player.mine_entity(entityToRemove, true)
        if testScenario.segmentToRemove == SegmentsToRemove.crossingRail and testScenario.blockingTrainType == BlockingTrainTypes.onCrossingRail then
            if mined then
                -- With a blocking train the crossing segment shouldn't have been mined.
                TestFunctions.TestFailed(testName, "tunnel crossing segment shouldn't have been mined")
            else
                TestFunctions.TestCompleted(testName)
            end
        elseif not mined then
            TestFunctions.TestFailed(testName, entityPrintFriendlyName .. " should have been mined")
        else
            TestFunctions.TestCompleted(testName)
        end
        return
    elseif testScenario.actionType == ActionTypes.destroy then
        entityToRemove.damage(9999999, entityToRemove.force, "impact")
        if testScenario.segmentToRemove == SegmentsToRemove.crossingRail and testScenario.blockingTrainType == BlockingTrainTypes.onCrossingRail then
            -- This is a special case as the locomotive should be removed from this.
            if testDataBespoke.blockingLocomotive.valid then
                TestFunctions.TestFailed(testName, "locomotive on crossing tracks should have been removed with crossing rail segment")
            else
                TestFunctions.TestCompleted(testName)
            end
        else
            -- Some test scenarios don't have a blocking locomotive, so only check its not been removed from these non specific tests when it exists.
            if testDataBespoke.blockingLocomotive ~= nil and not testDataBespoke.blockingLocomotive.valid then
                TestFunctions.TestFailed(testName, "locomotive on crossing tracks should NOT have been removed with tunnel")
            else
                TestFunctions.TestCompleted(testName)
            end
        end
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
    local actionTypesToTest  ---@type Tests_MDRCTT_ActionTypes[]
    local blockingTrainTypesToTest  ---@type Tests_MDRCTT_BlockingTrainTypes[]
    local segmentsToRemoveToTest  ---@type Tests_MDRCTT_SegmentsToRemove[]
    if DoSpecificTests then
        -- Adhock testing option.
        actionTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(ActionTypes, SpecificActionTypesFilter)
        segmentsToRemoveToTest = TestFunctions.ApplySpecificFilterToListByKeyName(SegmentsToRemove, SpecificSegmentsToRemoveFilter)
        blockingTrainTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(BlockingTrainTypes, SpecificBlockingTrainTypesFilter)
    elseif DoMinimalTests then
        actionTypesToTest = ActionTypes
        segmentsToRemoveToTest = SegmentsToRemove
        blockingTrainTypesToTest = {BlockingTrainTypes.onCrossingRail}
    else
        -- Do whole test suite.
        actionTypesToTest = ActionTypes
        segmentsToRemoveToTest = SegmentsToRemove
        blockingTrainTypesToTest = BlockingTrainTypes
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, actionType in pairs(actionTypesToTest) do
        for _, segmentToRemove in pairs(segmentsToRemoveToTest) do
            for _, blockingTrainType in pairs(blockingTrainTypesToTest) do
                ---@class Tests_MDRCTT_TestScenario
                local scenario = {
                    actionType = actionType,
                    segmentToRemove = segmentToRemove,
                    blockingTrainType = blockingTrainType
                }
                table.insert(Test.TestScenarios, scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

return Test
