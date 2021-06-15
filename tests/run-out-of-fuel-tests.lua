--[[
    A series of tests that has the train running out of fuel and stopping at various points in its tunnel usage. The tunnel should detect this and keep on giving it more fuel until it has fully left the tunnel. Does combinations for:
        noFuelPoint: startedEntering, fullyEntered, startedLeaving
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificNoFuelPointFilter = {} -- Pass in array of NoFuelPoints keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.

Test.RunTime = 10000
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        noFuelPoint = the TargetTunnelRail of this test.
    }
]]
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
    TestFunctions.RegisterTestsEventHandler(testName, remote.call("railway_tunnel", "get_tunnel_usage_changed_event_id"), "Test.TunnelUsageChanged", Test.TunnelUsageChanged)
end

local blueprintString = "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"

local NoFuelPoints = {
    startedEntering = "startedEntering",
    fullyEntered = "fullyEntered",
    startedLeaving = "startedLeaving"
}

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.noFuelPoint
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        end
    end

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive", false, false).train

    -- Set starting fuel based on desired no fuel stopping point.
    local woodCount
    if testScenario.noFuelPoint == NoFuelPoints.startedEntering then
        woodCount = 7
    elseif testScenario.noFuelPoint == NoFuelPoints.fullyEntered then
        woodCount = 8
    elseif testScenario.noFuelPoint == NoFuelPoints.startedLeaving then
        woodCount = 9
    else
        error("Unsupported testScenario.noFuelPoint: " .. testScenario.noFuelPoint)
    end
    -- Locomotive we want to fuel is the only one heading west (orientation 0.75)
    for _, carriage in pairs(train.carriages) do
        if carriage.orientation == 0.75 then
            carriage.insert({name = "wood", count = woodCount})
            break
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationEnd = stationEnd
    testData.train = train
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.testScenario = testScenario
    testData.actions = {}
    --[[
        A list of actions and how many times they have occured. Populated as the events come in.
        [actionName] = {
            name = the action name string, same as the key in the table.
            count = how many times the event has occured.
            recentChangeReason = the last change reason text for this action if there was one. Only occurs on single fire actions.
        }
    --]]
    testData.lastAction = nil -- Populated during test with the last action name.
    testData.tunnelUsageEntry = nil -- Populated during test: {enteringTrain, undergroundTrain, leavingTrain}
    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.TunnelUsageChanged = function(event)
    local testData = TestFunctions.GetTestDataObject(event.testName)

    -- Record the action for later reference.
    local actionListEntry = testData.actions[event.action]
    if actionListEntry then
        actionListEntry.count = actionListEntry.count + 1
        actionListEntry.recentChangeReason = event.changeReason
    else
        testData.actions[event.action] = {
            name = event.action,
            count = 1,
            recentChangeReason = event.changeReason
        }
    end

    testData.lastAction = event.action
    testData.tunnelUsageEntry = {enteringTrain = event.enteringTrain, undergroundTrain = event.undergroundTrain, leavingTrain = event.leavingTrain}
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    -- Check the leaving train for when it stops, otherise ignore it.
    if testData.tunnelUsageEntry == nil then
        return
    end
    local leavingTrain = testData.tunnelUsageEntry.leavingTrain
    if leavingTrain == nil or leavingTrain.speed ~= 0 then
        return
    end

    -- If stopped it should have fully pulled out of the tunnel and be complete.
    if testData.actions["fullyLeft"] == nil then
        TestFunctions.TestFailed(testName, "train stopped, but hasn't fully left tunnel yet.")
        return
    end
    if testData.actions["terminated"] ~= nil then
        TestFunctions.TestFailed(testName, "train tunnel usage terminated, trian should have stopped in fullyLeft state.")
        return
    end
    local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(leavingTrain)
    if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot, false) then
        TestFunctions.TestFailed(testName, "train not identical to starting, but is stopped.")
        return
    end
    TestFunctions.TestCompleted(testName)
end

Test.GenerateTestScenarios = function()
    local noFuelPointsToTest

    if DoSpecificTests then
        -- Adhock testing option.
        noFuelPointsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NoFuelPoints, SpecificNoFuelPointFilter)
    else
        -- Do whole test suite.
        noFuelPointsToTest = NoFuelPoints
    end

    for _, noFuelPoint in pairs(noFuelPointsToTest) do
        local scenario = {
            noFuelPoint = noFuelPoint
        }
        Test.RunLoopsMax = Test.RunLoopsMax + 1
        table.insert(Test.TestScenarios, scenario)
    end
end

return Test
