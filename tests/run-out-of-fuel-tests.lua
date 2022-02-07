--[[
    A series of tests that has the train running out of fuel and stopping at various points in its tunnel usage. Does combinations for:
        noFuelPoint: onPortalTrack, asEntering, asLeaving
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Common = require("scripts/common")

---@class Tests_ROOFT_NoFuelPoints
local NoFuelPoints = {
    onPortalTrack = "onPortalTrack",
    asEntering = "asEntering",
    asLeaving = "asLeaving"
}

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificNoFuelPointFilter = {} -- Pass in array of NoFuelPoints keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.

Test.RunTime = 10000
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_ROOFT_TestScenario[]
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        noFuelPoint = the TargetTunnelRail of this test.
    }
]]
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

local blueprintString = "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"

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.noFuelPoint
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 30, y = 0}, testName)

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
    if testScenario.noFuelPoint == NoFuelPoints.onPortalTrack then
        woodCount = 7
    elseif testScenario.noFuelPoint == NoFuelPoints.asEntering then
        woodCount = 8
    elseif testScenario.noFuelPoint == NoFuelPoints.asLeaving then
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
    testData.testScenario = testScenario
    ---@class Tests_ROOFT_TestScenarioBespokeData
    local testDataBespoke = {
        stationEnd = stationEnd, ---@type LuaEntity
        enteringtrain = train, ---@type LuaTrain
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train, 0.75),
        trainhasStartedMoving = false ---@type boolean
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_ROOFT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_ROOFT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- The train starts stationary, so we only want to start checking its state and if its stopped after it has started moving first.
    if not testDataBespoke.trainhasStartedMoving then
        if testDataBespoke.enteringtrain.speed ~= 0 then
            testDataBespoke.trainhasStartedMoving = true
        else
            return
        end
    end

    if testScenario.noFuelPoint == NoFuelPoints.onPortalTrack then
        -- Train should stop on the entrance portal tracks.
        if testDataBespoke.enteringtrain == nil or not testDataBespoke.enteringtrain.valid then
            TestFunctions.TestFailed(testName, "train traversed through tunnel, but should have stopped short on the protal tracks.")
        elseif testDataBespoke.enteringtrain.speed == 0 then
            if tunnelUsageChanges.lastAction == nil then
                TestFunctions.TestFailed(testName, "train should have reserved tunnel when crossing on to portal tracks.")
            elseif tunnelUsageChanges.lastAction == Common.TunnelUsageAction.onPortalTrack then
                TestFunctions.TestCompleted(testName)
            else
                TestFunctions.TestFailed(testName, "train shouldn't have used the tunnel in any any way than be on portal tracks.")
            end
        end
        -- If train is still moving then wait until later.
        return
    end

    -- Wait for when the train has started leaving the tunnel.
    if tunnelUsageChanges.actions[Common.TunnelUsageAction.leaving] == nil then
        return
    end

    -- Wait for when the leaving train stops.
    local leavingTrain = tunnelUsageChanges.train
    if leavingTrain == nil or leavingTrain.speed ~= 0 then
        return
    end

    -- At present if a train reaches the transition point of the entrance portal with no fuel it is treated equally to a train that has fuel for the transition. So the results for running nout of fuel as entering and as leaving are currently equal.
    local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(leavingTrain, 0.75)
    if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot, false) then
        TestFunctions.TestFailed(testName, "train not identical to starting, but is stopped.")
    else
        TestFunctions.TestCompleted(testName)
    end
end

Test.GenerateTestScenarios = function()
    local noFuelPointsToTest  ---@type Tests_ROOFT_NoFuelPoints

    if DoSpecificTests then
        -- Adhock testing option.
        noFuelPointsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NoFuelPoints, SpecificNoFuelPointFilter)
    else
        -- Do whole test suite.
        noFuelPointsToTest = NoFuelPoints
    end

    for _, noFuelPoint in pairs(noFuelPointsToTest) do
        ---@class Tests_ROOFT_TestScenario
        local scenario = {
            noFuelPoint = noFuelPoint
        }
        Test.RunLoopsMax = Test.RunLoopsMax + 1
        table.insert(Test.TestScenarios, scenario)
    end
end

return Test
