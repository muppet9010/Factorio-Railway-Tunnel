-- Destroys a train carriage during each stage of a train's tunnel usage to check the mod handles invalid LuaTrain's. Will remove the carriage on a state being reached and a few ticks afterwards to let things settle each time. After a few seconds the remaining train carriage will be pathed to a train stop it can reach to "manually" clear the issue. There is a second train waiting to use the tunnel that confirms the tunnel has been left in a healthy state whe it reaches its target station.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")
local TunnelUsageAction, TunnelUsageChangeReason = Common.TunnelUsageAction, Common.TunnelUsageChangeReason

---@class Tests_ITT_StateToRemoveOn
local StateToRemoveOn = {
    onPortalTrack = TunnelUsageAction.onPortalTrack,
    startApproaching = TunnelUsageAction.startApproaching,
    entered = TunnelUsageAction.entered,
    leaving = TunnelUsageAction.leaving
}
---@class Tests_ITT_CarriageToRemove
local CarriageToRemove = {
    front = "front",
    rear = "rear"
}
---@class Tests_ITT_Delay
local Delay = {
    none = 0,
    one = 1,
    ten = 10
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificStateToRemoveOnFilter = {} -- Pass in an array of StateToRemoveOn keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificCarriageToRemoveFilter = {} -- Pass in an array of CarriageToRemove keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.
local SpecificDelayFilter = {} -- Pass in an array of Delay keys to do just those. Leave as nil or empty table for all letters. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_ITT_TestScenario[]
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

    local blueprint = "0eNq1Wt1y8jYQfRdfQ0bS6pf77wl60YtOJkOMSjwFm7FN2kyGd69kAwkgmoOgVwRkn7PW2V3tevNZvK62ftNWdV/MPouqbOqumP3xWXTVsp6v4m/9x8YXs6Lq/bqYFPV8Hb+182pV7CZFVS/8P8WM7ybQLX/PP176bV371XTTtP189dL55drX/bTrw/ryrf8GKnbPkyKsVX3lR6OGLx8v9Xb96tvAesQ+3D0d7JoUm6YLdzV1NCYgTZWaFB/hk/NdtPQMRxxxIkwdbGk2KRA6gkwC43xcK373XbT6ApVQ6/7bOAkZp0zStl/ztG3qCFpu23e/uLpvcoTVAXVRtb4cF2UCUmOQVxBVAtHg8vIRlH4GteCTSztAslNEk0B0Jx4+3UdBAtE97YUWT+oUlhKwnGGWpg0VKUQ4Xq7sZ9JM8UOA+3qR2AwaY4mfEgQfep+31d57eYqObs0nl9zCZXLLB3CbTG71AG6Vya0fwJ2rt3kAN09xi5+57f3c3GVyuwdwmzxuwbJCmlMmHb9Gtw11QLtsm/B58bxD5nop26brqnqZMCdz44XIsSbBn7v59CB+lckv/xc1cn1D5bgiz8s14v48l5lhxf1ZLvNcEffnuMzTVNyf4XhmYid2P3WmQxO/nzozskncT53pZUQ5YSwy45hOU9i0fBv6pit1ueKHspydl+WpIpoUVu4rcYDl57CptoQ03OzotP4pULyD0gSDWhyUw6AO7/UcCioZDmpg0JtfOiCgAgeFhZJ0W6srzuIsBSlvbckROxUMKnHt8XiSuPZ4PElcezyeJK49Hk8SFkrh8USwUAqPJ4KFUnA8CVgnBb/PE7idcDwJfEPhcCJceTiaCHZRBQcT4Rp9xdKqKZt101fvPgH4tZlNWwWMfTHBnkygKptV08Yr2/iLNFYSJ0OWpGbOWUWKKx39ZjncoaVhyjpNxihN0uhx8TUuWnIiXOyUVZYxbph1AS2SzOMyY+O6tcqRtuFG7SxpKZSxXMSqIb5B7wZbmvIv30//3PpVLCBSzw6HPB5HGo54POA1HPB4ZtIC0j0eCmndxYXuTirmLJNCWhv+4FIq4kfV+SCbFkFtpZjmJBmRYOMVg/QsLErFg+jSWWeC1Dz4kLDDFY9XX8PZCT9ENJyd8NNOw9kJP5Y1nJ3w+kGbG9+VI5hYdlL6acwRaIriTrOYpaSyWgkZUhEZ69hXjrLRFUPuYtpoa5w9uOHgqIYPKSwkL0XMaG64vTtBJQdZGk5QeI1r2I1DNgQTH5PALmrgggRvbwwc8ngfZm4u8NXPAzIDtszTYyt+MSBLtflG3zbEtACkASfBe+HP5mPy++j1N1829SI1fDX25haSdnEW3pVvfrFd7YfhXzkkfg+ljxbfrhmH+GdD6udozel92l6/6fAIz5F8GObPvv27wKR49203ulI4H40TJlRGnDTb7f4F4gimGg=="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the stations.
    local westStation, eastStation, secondStation
    for _, station in pairs(placedEntitiesByGroup["train-stop"]) do
        if station.backer_name == "West" then
            westStation = station
        elseif station.backer_name == "East" then
            eastStation = station
        elseif station.backer_name == "Second" then
            secondStation = station
        end
    end

    -- Work out where to send the first train after it has a carriage removed.
    local firstTrainTargetStation
    if testScenario.carriageToRemove == CarriageToRemove.front then
        firstTrainTargetStation = eastStation
    else
        firstTrainTargetStation = westStation
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_ITT_TestScenarioBespokeData
    local testDataBespoke = {
        westStation = westStation, ---@type LuaEntity
        eastStation = eastStation, ---@type LuaEntity
        firstTrainTargetStation = firstTrainTargetStation, ---@type LuaEntity
        secondStation = secondStation, ---@type LuaEntity
        preRemovedTrainCarriages = nil, ---@type LuaEntity[] @ Populated during EveryTick().
        removeOnTick = nil, ---@type Tick @ Populated during EveryTick().
        carriageRemoved = false, ---@type boolean
        restartTrainOnTick = nil, ---@type Tick @ Populated during EveryTick().
        firstTrainReachedStation = false ---@type boolean
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
    local testScenario = testData.testScenario ---@type Tests_ITT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_ITT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- If populated then do the train restart logic rather than anything else.
    if testDataBespoke.restartTrainOnTick ~= nil then
        if event.tick == testDataBespoke.restartTrainOnTick then
            -- Restart the train.

            -- Get the remaining train part from the train carriages that existed just before carriage removal.
            local train
            for _, carriage in pairs(testDataBespoke.preRemovedTrainCarriages) do
                if carriage.valid then
                    train = carriage.train
                end
            end

            train.schedule = {
                current = 1,
                records = {
                    {
                        station = testDataBespoke.firstTrainTargetStation.backer_name
                    }
                }
            }
            train.manual_mode = false
        elseif event.tick > testDataBespoke.restartTrainOnTick then
            -- Trains should be running, so wait for both stations have a train stopped in them.
            if not testDataBespoke.firstTrainReachedStation and testDataBespoke.firstTrainTargetStation.get_stopped_train() then
                testDataBespoke.firstTrainReachedStation = true
                game.print("first train reached station post carriage removal and restart")
            end
            if testDataBespoke.firstTrainReachedStation and testDataBespoke.secondStation.get_stopped_train() then
                TestFunctions.TestCompleted(testName)
            end
        end
        -- Otherwise just wait.
        return
    end

    -- If the carriage has been removed already then do specific handling first.
    if testDataBespoke.carriageRemoved then
        if testScenario.stateToRemoveOn == TunnelUsageAction.entered then
            -- Entered state doesn't have anything active to detect the invalid train immediately so have to wait for next action to check if it realised.
            if tunnelUsageChanges.lastAction == TunnelUsageAction.entered then
                -- Mod hasn't tried to do any processing yet.
                return
            end
            if tunnelUsageChanges.lastAction ~= TunnelUsageAction.terminated or tunnelUsageChanges.lastChangeReason ~= TunnelUsageChangeReason.invalidTrain then
                TestFunctions.TestFailed(testName, "last action not 'terminated' on next processing after carriage removal")
                return false
            end
        else
            -- Tunnel state has per tick events so will realise by now (1 tick after removal) that something has happened.
            if tunnelUsageChanges.lastAction ~= TunnelUsageAction.terminated or tunnelUsageChanges.lastChangeReason ~= TunnelUsageChangeReason.invalidTrain then
                TestFunctions.TestFailed(testName, "last action not 'terminated' immediately after carriage removal")
                return false
            end
        end
        testDataBespoke.restartTrainOnTick = event.tick + 180
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
        if tunnelUsageChanges.lastAction == testScenario.stateToRemoveOn then
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
        -- Cache the train carriages before we invalidate the managed train.
        testDataBespoke.preRemovedTrainCarriages = tunnelUsageChanges.train.carriages

        local carriageIndex
        if testScenario.carriageToRemove == CarriageToRemove.front then
            carriageIndex = 1
        else
            carriageIndex = 2
        end
        tunnelUsageChanges.train.carriages[carriageIndex].destroy()
        if tunnelUsageChanges.train.valid then
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
    local stateToRemoveOnToTest  ---@type Tests_ITT_StateToRemoveOn[]
    local delayToTest  ---@type Tests_ITT_Delay[]
    local carriageToRemoveToTest  ---@type Tests_ITT_CarriageToRemove[]
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
                ---@class Tests_ITT_TestScenario
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
