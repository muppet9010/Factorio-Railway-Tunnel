-- Destroys a train carriage during each stage of a train's tunnel usage to check the mod handles invalid LuaTrain's. Will remove the carriage on a state being reached and a few ticks afterwards to let things settle each time.
-- Test is unlikely to fail but more liekly to cause the mod to error/crash in unhandled situations.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Common = require("scripts/common")
local TunnelUsageAction, TunnelUsageChangeReason = Common.TunnelUsageAction, Common.TunnelUsageChangeReason

---@class Tests_TICT_StateToRemoveOn
local StateToRemoveOn = {
    onPortalTrack = TunnelUsageAction.onPortalTrack,
    startApproaching = TunnelUsageAction.startApproaching,
    entered = TunnelUsageAction.entered,
    leaving = TunnelUsageAction.leaving
}
---@class Tests_TICT_Delay
local Delay = {
    none = 0,
    one = 1,
    ten = 10
}
---@class Tests_TICT_CarriageToRemove
local CarriageToRemove = {
    front = "front",
    rear = "rear"
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificStateToRemoveOnFilter = {} -- Pass in an array of StateToRemoveOn keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificDelayFilter = {} -- Pass in an array of Delay keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificCarriageToRemoveFilter = {} -- Pass in an array of CarriageToRemove keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_TICT_TestScenario[]
Test.TestScenarios = {}

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.stateToRemoveOn .. "    -    " .. testScenario.carriageToRemove .. "    -    delay: " .. testScenario.delay
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1mNty2jAQht9F19CRVmdepBedDOMYlXhqLEa20zIZ3r2SIeSAMl1kmhswUr5/pV+7svRCHtvR7UPTDWT1Qpradz1Z/XghfbPtqjb9Nhz2jqxIM7gdWZCu2qWnUDXt7+qwHsauc+1y78NQtevebXeuG5b9ENu3TwM5LkjTbdwfsmLHRSHUdZt3HDg+LEjUaIbGnSKdHg7rbtw9uhCFLrjXKJaJG1X2vo//5bukH0lLGbse0ucxxfYJAxdMonRxSH6fYQj7ylhEverURL67Po39Csov0HoMz27zZWR0otII3TTB1ac2kSEK9GiFnpj8I1NmmBIZpRATUX0k6gxRISy+5nM58fVHfmQ9V6E5TzXLqOlbV2lGmpVJm/nSYMuk7R2kdZk0o3fQLjSbsTto85w2/Fsb7qDNCrX5fG1mC7VFUT4zWSgnv5Ib454QtsHHz6vxTlVrXQff9023zYVTOvOqJJxMAKWzr++krwv1zX+xo3Rx2LK1WFZtYH6l44XK8+tcYYWF+VWucF+B+TWuMMdAzFYuLS8g50sX7meg5kuXLjJdksas8F0JDPq1WeVtzEEt/uRhsVBO8VCNht5wRpJoKOChHA3lt57mMNAbDk14o+StJzEMVOGheKM0Hoo3Cp9RAm8UPqM42iiBzihAj16gEwrQNgl0PgF6PQl0OgF+PtHZxNHGC3QycbxHb7nU+trv/NA8uwzwbTJ9aCLjvI3QbzoGVfvWh9QzpF+YBSaVUSp+MUwro60x8VsyeZs6CAVaSEYpSKsNNYZrY6lK7Y8TUoMUlnLOlEgdQHPBk06VWinlJwEjLVdGKlDWcCVA6qSR7sQGt+uncHz9yw3Ln6Nr051ObvjorOf4JYpOeo5fouicx6e8pCjrz/dZGevhynrJpz/FmIiuCgAjo1MX48EKFhdE9I3TaB0VzEYrjX41Hk7WasY1t9xKJpiiZ8D9vZfo8oSvzRJdnvCbiESXJ/xuJ9Hl6att+WFB+vrJbcb2fOH8tobSc6wrkr7rc7o9/3QV/JAo02X36t2Fe3xPdaE/yRgmtAUdVxHjih6PfwHeNduO"
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, _ = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_TICT_TestScenarioBespokeData
    local testDataBespoke = {
        removeOnTick = nil, ---@type Tick @ Populated during EveryTick().
        carriageRemoved = false ---@type boolean
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
    local testScenario = testData.testScenario ---@type Tests_TICT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_TICT_TestScenarioBespokeData

    -- If the carriage has been removed already then do specific handling first.
    if testDataBespoke.carriageRemoved then
        if testScenario.stateToRemoveOn == TunnelUsageAction.entered then
            -- Entered state doesn't have anything active to detect the invalid train immediately so have to wait for next action to check if it realised.
            if testData.lastAction == TunnelUsageAction.entered then
                -- Mod hasn't tried to do any processing yet.
                return
            end
            if testData.lastAction ~= TunnelUsageAction.terminated or testData.lastChangeReason ~= TunnelUsageChangeReason.invalidTrain then
                TestFunctions.TestFailed(testName, "last action not 'terminated' on next processing after carriage removal")
                return false
            end
        else
            -- Tunnel state has per tick events so will realise by now (1 tick after removal) that something has happened.
            if testData.lastAction ~= TunnelUsageAction.terminated or testData.lastChangeReason ~= TunnelUsageChangeReason.invalidTrain then
                TestFunctions.TestFailed(testName, "last action not 'terminated' immediately after carriage removal")
                return false
            end
        end
        TestFunctions.TestCompleted(testName)
        return
    end

    -- If the action has occured and we are waiting for the delay tick then just check that.
    local doRemovalThisTick = false
    if testDataBespoke.removeOnTick ~= nil then
        if event.tick == testDataBespoke.removeOnTick then
            -- Set to remove the train carriage now
            doRemovalThisTick = true
        else
            -- Keep on waiting.
            return
        end
    end

    -- If we're not doing the removal this tick and its not waiting for a tick then check the last action state to see if we've reached our desired state yet.
    if not doRemovalThisTick then
        local scheduleRemovalTick = false

        -- Check if the action is the one we want to react to. Do like this as may want to add more complciated trigering logic in future.
        if testData.lastAction == testScenario.stateToRemoveOn then
            scheduleRemovalTick = true
        end

        if scheduleRemovalTick then
            -- Is our action point, so check delay and schedule.
            if testScenario.delay == Delay.none then
                doRemovalThisTick = true
            else
                testDataBespoke.removeOnTick = event.tick + testScenario.delay
                return
            end
        else
            -- Not our action yet so continue to wait.
            return
        end
    end

    if doRemovalThisTick then
        local carriageIndex
        if testScenario.carriageToRemove == CarriageToRemove.front then
            carriageIndex = 1
        else
            carriageIndex = 2
        end
        testData.train.carriages[carriageIndex].destroy()
        if testData.train.valid then
            TestFunctions.TestFailed(testName, "carriage not removed when expected")
            return
        end
        testDataBespoke.carriageRemoved = true
    end
end

---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local stateToRemoveOnToTest  ---@type Tests_TICT_StateToRemoveOn[]
    local delayToTest  ---@type Tests_TICT_Delay[]
    local carriageToRemoveToTest  ---@type Tests_TICT_CarriageToRemove[]
    if DoMinimalTests then
        stateToRemoveOnToTest = StateToRemoveOn
        delayToTest = {Delay.none}
        carriageToRemoveToTest = {CarriageToRemove.front}
    elseif DoSpecificTests then
        -- Adhock testing option.
        stateToRemoveOnToTest = TestFunctions.ApplySpecificFilterToListByKeyName(StateToRemoveOn, SpecificStateToRemoveOnFilter)
        delayToTest = TestFunctions.ApplySpecificFilterToListByKeyName(Delay, SpecificDelayFilter)
        carriageToRemoveToTest = TestFunctions.ApplySpecificFilterToListByKeyName(CarriageToRemove, SpecificCarriageToRemoveFilter)
    else
        -- Do whole test suite.
        stateToRemoveOnToTest = StateToRemoveOn
        delayToTest = Delay
        carriageToRemoveToTest = CarriageToRemove
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, stateToRemoveOn in pairs(stateToRemoveOnToTest) do
        for _, delay in pairs(delayToTest) do
            for _, carriageToRemove in pairs(carriageToRemoveToTest) do
                ---@class Tests_TICT_TestScenario
                local scenario = {
                    stateToRemoveOn = stateToRemoveOn,
                    delay = delay,
                    carriageToRemove = carriageToRemove
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
