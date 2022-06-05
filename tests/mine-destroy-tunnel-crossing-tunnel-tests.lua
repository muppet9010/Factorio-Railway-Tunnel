-- Tries to mine and destroy a tunnel with tunnel crossing rails with the crossing tunnel in-use and free. Other situations are handled as part of a standard tunnel mine/destroy test.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")
local TableUtils = require("utility.table-utils")
local Common = require("scripts.common")

-- Internal test types.
---@class Tests_MDTCTT_ActionTypes
local ActionTypes = {
    mine = "mine",
    destroy = "destroy"
}
---@class Tests_MDTCTT_SegmentToRemove
local SegmentToRemove = {
    crossingTunnelSegmentDirect = "crossingTunnelSegmentDirect", -- The direct tunnel crossing segment of the fake crossing segment on the corring tunnel.
    crossingTunnelSegmentSupporting = "crossingTunnelSegmentSupporting" -- A supporting tunnel crossing segment of the fake crossing segment on the corring tunnel.
}
---@class Tests_MDTCTT_CrossingTunnelUsage
local CrossingTunnelUsage = {
    none = "none",
    inUse = "inUse"
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificActionTypesFilter = {} -- Pass in an array of ActionTypes keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificCrossingTunnelUsageFilter = {} -- Pass in an array of CrossingTunnelUsage keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificSegmentToRemoveFilter = {} -- Pass in an array of SegmentToRemove keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

--- How long the test instance runs for (ticks) before being failed as uncompleted. Should be safely longer than the maximum test instance should take to complete, but can otherwise be approx.
Test.RunTime = 3600

--- Populated when generating test scenarios.
Test.RunLoopsMax = 0

--- The test configurations are stored in this when populated by Test.GenerateTestScenarios().
---@type Tests_MDTCTT_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.actionType .. "    -    SegmentToRemove: " .. testScenario.segmentToRemove .. "    -    CrossingTunnelUsage: " .. testScenario.crossingTunnelUsage
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1l01ugzAQhe8ya5BiHH6XlXqKqopIYlFLYJBt2qKIu9dAlCahKYMhK2QM75th7Mf4BPu8ZpXkQkNyAn4ohYLk7QSKZyLNu3u6qRgkwDUrwAGRFt1Ipjz/SpudroVguVuVUqf5jokjtA5wcWTfkJDWsdRRLCuY0K7SZj770FeiXvvugJnjmrMh0n7Q7ERd7Jk0VESMDlSlMgql6AIzqtSBBhKXxAZ05JIdhrmtA5+p5Okw6vO5o3lzM3mI9ttJGF0NRqdh29VgZBrmLyhaOC0fXOS7YIWJuazGeq7nD4r0dhWYt5U+q8Nrv8RHhNAmAVP08ye6BXqTCUWLi2PKYsmOl7NjSzTZLGeHtmwrY3GpLe6hs9TGCGUmS3Md5esOz+wOslSKi+zhpkEYAKE2CVuXdrnfEOtv7S9n2+5kEixnWy9pK9fybI2DRCgbxrjwS83zP32Y/LrTZU90uf3j9vd5/PWX3+BVKV6V4FUJXtVDq5IYr0qfakeIFsHbYvOaU1gfLRriRQO06IwChFhROmOtRM+sKqaosX3jh2mYNys1sTGCRVZiYfpluta5A3MSoNS+SGTUnZvjW38ETK5OnuYRJtWwTCOyDWMv9Km5BFHb/gD2+gK3"
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local allBuiltEntities, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 1, y = 1}, testName)

    -- Get the segment we will remove.
    local segmentToRemove  --- @type LuaEntity
    if testScenario.segmentToRemove == SegmentToRemove.crossingTunnelSegmentDirect then
        segmentToRemove = TableUtils.GetTableValueWithInnerKeyValue(allBuiltEntities, "name", "railway_tunnel-underground_segment-straight-tunnel_crossing", true, false)[2] -- Second down is the middle one.
    elseif testScenario.segmentToRemove == SegmentToRemove.crossingTunnelSegmentSupporting then
        segmentToRemove = TableUtils.GetTableValueWithInnerKeyValue(allBuiltEntities, "name", "railway_tunnel-underground_segment-straight-tunnel_crossing", true, false)[1] -- First down is an edge one.
    else
        error("unsupported segmentToRemove: " .. testScenario.segmentToRemove)
    end

    -- If the test needs a train add it.
    local crossingTunnelLocomotive
    if testScenario.crossingTunnelUsage == CrossingTunnelUsage.inUse then
        -- Only 2 train stops in the test.
        local buildStation, endStation
        if placedEntitiesByGroup["train-stop"][1].backer_name == "Build" then
            buildStation = placedEntitiesByGroup["train-stop"][1]
            endStation = placedEntitiesByGroup["train-stop"][2]
        else
            buildStation = placedEntitiesByGroup["train-stop"][2]
            endStation = placedEntitiesByGroup["train-stop"][1]
        end
        local crossingTunnelTrain = TestFunctions.BuildTrain({x = buildStation.position.x, y = buildStation.position.y + 2}, {{prototypeName = "locomotive", facingForwards = true}}, defines.direction.west, nil, nil, {name = "rocket-fuel", count = 10})
        crossingTunnelTrain.schedule = {current = 1, records = {{station = endStation.backer_name}}}
        crossingTunnelTrain.manual_mode = false
        crossingTunnelLocomotive = crossingTunnelTrain.front_stock
    end

    -- Get a portal end for each tunnel.
    local mainTunnelPortalPart = placedEntitiesByGroup["railway_tunnel-portal_end"][3] -- first and second will be the crossing tunnel, with 3rd being northest main tunnel.
    local mainTunnelId = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", mainTunnelPortalPart.unit_number).tunnelId
    local crossingTunnelPortalPart = placedEntitiesByGroup["railway_tunnel-portal_end"][1] -- left most will be crossing tunnel.
    local crossingTunnelId = remote.call("railway_tunnel", "get_tunnel_details_for_entity_unit_number", crossingTunnelPortalPart.unit_number).tunnelId

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_MDTCTT_TestScenarioBespokeData
    local testDataBespoke = {
        segmentToRemove = segmentToRemove, ---@type LuaEntity
        crossingTunnelLocomotive = crossingTunnelLocomotive, ---@type LuaEntity|nil
        mainTunnelId = mainTunnelId, ---@type Id
        crossingTunnelId = crossingTunnelId ---@type Id
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
    local testScenario = testData.testScenario ---@type Tests_MDTCTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_MDTCTT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- If theres a train using the crossing the tunnel wait for it to start using the tunnel before we attempt to do any removal action. We wait for it to be on the portal track so that the train will be destroyed if the segment is destroyed or mined when it shouldn't.
    if testScenario.crossingTunnelUsage == CrossingTunnelUsage.inUse then
        if tunnelUsageChanges.actions[Common.TunnelUsageAction.onPortalTrack] == nil then
            return
        end
    end

    -- Mining the target.
    if testScenario.actionType == ActionTypes.mine then
        local player = game.connected_players[1]
        if player == nil then
            TestFunctions.TestFailed(testName, "no player found for test")
            return
        end
        local mined = player.mine_entity(testDataBespoke.segmentToRemove, true)

        if testScenario.crossingTunnelUsage == CrossingTunnelUsage.inUse then
            -- Tunnel in use so nothing should change.

            -- Train should still exist.
            if not testDataBespoke.crossingTunnelLocomotive.valid then
                TestFunctions.TestFailed(testName, "train using crossing tunnel should still be present")
                return
            end

            -- Mining should fail.
            if mined then
                TestFunctions.TestFailed(testName, "segment shouldn't have been mined")
                return
            end

            -- Check the 2 tunnel's final state.
            if remote.call("railway_tunnel", "get_tunnel_details_for_id", testDataBespoke.mainTunnelId) == nil then
                TestFunctions.TestFailed(testName, "main tunnel shouldn't have been removed")
                return
            end
            if remote.call("railway_tunnel", "get_tunnel_details_for_id", testDataBespoke.crossingTunnelId) == nil then
                TestFunctions.TestFailed(testName, "crossing tunnel shouldn't have been removed")
                return
            end

            TestFunctions.TestCompleted(testName)
            return
        else
            -- Tunnel not in use so should be mined successfully.

            if not mined then
                TestFunctions.TestFailed(testName, "segment should have been mined")
                return
            end

            -- Check the 2 tunnel's final state.
            if remote.call("railway_tunnel", "get_tunnel_details_for_id", testDataBespoke.mainTunnelId) ~= nil then
                TestFunctions.TestFailed(testName, "main tunnel should have been removed")
                return
            end
            if remote.call("railway_tunnel", "get_tunnel_details_for_id", testDataBespoke.crossingTunnelId) ~= nil then
                TestFunctions.TestFailed(testName, "crossing tunnel should have been removed")
                return
            end

            TestFunctions.TestCompleted(testName)
            return
        end
    end

    -- Destroying the target.
    if testScenario.actionType == ActionTypes.destroy then
        testDataBespoke.segmentToRemove.damage(9999999, testDataBespoke.segmentToRemove.force, "impact")

        if testScenario.crossingTunnelUsage == CrossingTunnelUsage.inUse then
            -- As the crossign train exists it should have been destroyed as on portal tracks.
            if testDataBespoke.crossingTunnelLocomotive.valid then
                TestFunctions.TestFailed(testName, "train using crossing tunnel should have been removed")
                return
            end
        end

        -- Check the 2 tunnel's final state.
        if remote.call("railway_tunnel", "get_tunnel_details_for_id", testDataBespoke.mainTunnelId) ~= nil then
            TestFunctions.TestFailed(testName, "main tunnel should have been removed")
            return
        end
        if remote.call("railway_tunnel", "get_tunnel_details_for_id", testDataBespoke.crossingTunnelId) ~= nil then
            TestFunctions.TestFailed(testName, "crossing tunnel should have been removed")
            return
        end

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
    local actionTypesToTest  ---@type Tests_MDTCTT_ActionTypes[]
    local crossingTunnelUsagesToTest  ---@type Tests_MDTCTT_CrossingTunnelUsage[]
    local segmentsToRemoveToTest  ---@type Tests_MDTCTT_SegmentToRemove[]
    if DoSpecificTests then
        -- Adhock testing option.
        actionTypesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(ActionTypes, SpecificActionTypesFilter)
        segmentsToRemoveToTest = TestFunctions.ApplySpecificFilterToListByKeyName(SegmentToRemove, SpecificSegmentToRemoveFilter)
        crossingTunnelUsagesToTest = TestFunctions.ApplySpecificFilterToListByKeyName(CrossingTunnelUsage, SpecificCrossingTunnelUsageFilter)
    elseif DoMinimalTests then
        actionTypesToTest = ActionTypes
        segmentsToRemoveToTest = SegmentToRemove
        crossingTunnelUsagesToTest = {CrossingTunnelUsage.inUse}
    else
        -- Do whole test suite.
        actionTypesToTest = ActionTypes
        segmentsToRemoveToTest = SegmentToRemove
        crossingTunnelUsagesToTest = CrossingTunnelUsage
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, actionType in pairs(actionTypesToTest) do
        for _, segmentToRemove in pairs(segmentsToRemoveToTest) do
            for _, crossingTunnelUsage in pairs(crossingTunnelUsagesToTest) do
                ---@class Tests_MDTCTT_TestScenario
                local scenario = {
                    actionType = actionType,
                    segmentToRemove = segmentToRemove,
                    crossingTunnelUsage = crossingTunnelUsage
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
