--[[
    A series of tests that has the train running out of fuel and stopping at various points in its tunnel usage. The tunnel should detect this and keep on giving it more fuel until it has fully left the tunnel. Does combinations for:
        noFuelPoint: startedEntering, fullyEntered, startedLeaving
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")

local NoFuelPoints = {
    startedEntering = "startedEntering",
    fullyEntered = "fullyEntered",
    startedLeaving = "startedLeaving"
}

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
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

Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.noFuelPoint
end

Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        end
    end

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = placedEntitiesByGroup["locomotive"][1].train

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
        TestFunctions.TestFailed(testName, "train tunnel usage terminated, train should have stopped in fullyLeft state.")
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
