-- Creates the situations to trigger each tunnel usage changed event's action and change reason to confirm they all appear when and only when expected.
-- Will duplicate some other tests scenarios, but this test confirms explicitly that the Event's the mod raises are correct.

-- Requires and this tests class object.
local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")
local TunnelUsageAction, TunnelUsageChangeReason = Common.TunnelUsageAction, Common.TunnelUsageChangeReason

---@class Tests_TUCE_FinalActionChangeReasons
local FinalActionChangeReasons = {
    terminated_completedTunnelUsage = "terminated_completedTunnelUsage",
    terminated_abortedApproach = "terminated_abortedApproach", -- Appraoching train aborts when not on portal rails.
    terminated_portalTrackReleased = "terminated_portalTrackReleased", -- Train on just portal rails (not approaching) aborts.
    terminated_tunnelRemoved = "terminated_tunnelRemoved",
    terminated_reversedAfterLeft = "terminated_reversedAfterLeft",
    onPortalTrack_abortedApproach = "onPortalTrack_abortedApproach" -- Train approaching is already on portal rails when it aborts. So this is reporting the downgrade in usage status and its new monitoring level.
    --terminated_invalidTrain is not included as all of its generation cases and explicit state checking is done within the "invalid_train_tests" test.
}

-- Test configuration.
local DoMinimalTests = true -- The minimal test to prove the concept.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificFinalActionChangeReasonsFilter = {} -- Pass in an array of FinalActionChangeReasons keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 3600
Test.RunLoopsMax = 0

---@type Tests_TUCE_TestScenario[]
Test.TestScenarios = {}

--- Any scheduled event types for the test must be Registered here.
---@param testName string
Test.OnLoad = function(testName)
    Test.GenerateTestScenarios(testName)
    TestFunctions.RegisterTunnelUsageChangesToTestFunction(testName, Test.OnTunnelUsageChangeEvent)
end

--- Returns the desired test name for use in display and reporting results. Should be a unique name for each iteration of the test run.
---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.finalActionChangeReason
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local blueprint = "0eNq1mN1u2kAQhd9lr6Hamdlf7vsMvagQcmBLrBob2SYtinj37mIa0piokzXJDf7L+cY+c8bWPouH6hD2bVn3YvEsynVTd2Lx/Vl05bYuqnSsP+6DWIiyDzsxE3WxS3ttUVa/iuOqP9R1qOb7pu2LatWF7S7U/bzr4/ntYy9OM1HWm/BbLOA0yxQN9eaVDp6WMxEZZV+GodLzznFVH3YPoY2gF7lURB1rafYRsW+6+C9NneBRZq7sTBzjb6xLbMo2rIeTZia6vhi2xbfQpVsYIZBR8ZiIcCaOgU9FW16QcINGH33oYzTYPLS6A1rnofUd0JSHNndAZ3ptp6P9LTL+l+ymk20e2U8n6zwyyKwgQyYN3qMd4mhrt20Tf0d3O0/XrtZt03VlvR1XQ5nFYE4xY3zuk6f74DNbDtRnWJGZPNA5XZg73GD6dMt9m8D06QY+Ez19vOW+vmH6fMPMkKOcjs4MOMJ0dGa4EaejM9sMKSfKlBllvE6xf0bU+1+7b5/lLVHNF9VsUcMXJbao5YsCW9SxRcmzRT1flG0USb4o2ygCvijbKEK+KNsoIrYoso0ifqKQbxQ/Ucg3ip2oD3QUO1D81id2nvgZJXac+MNEsdPEn3qKHSb+eFbXLFXNutk1ffkUbnyWXx9m05ZR4/IakV9sLH/dVE2brmzTEfAI2jhj4oYDa5z1zsWt1IzbdIEyaJUGKVF766RzZJ2XJp1/OEta1MpLIjAqXYCWFCVOkc5KSQPAaU/GaYPGOzIKtU2MtLLTh113LqdZ/wz9/MchVPEWTrdun516xW5RxQ69ZreoYmde81vU8Kx371mPI+s1nf8MgIquKkSno1MvxqNXEBsi+kYyWicV+Gils3+Nx8FaC2TJk9egwMiLwCd4zx5Pmh9R9njS/Iiyx5Nm96hmjyfD7lHNWym9CNLoM/y6Tvq1SOuky3ho/Rg2h+qyMHvt0rQfJ5cyr64ZVpnfrLUuk8p5UXjxamE6fgmHthu4DpT1aGOfAhl5Ov0Bd/6Uow=="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    if testScenario.finalActionChangeReason == FinalActionChangeReasons.terminated_abortedApproach then
        -- Needs to approach and abort before onPortalTrack so has a high starting speed
        local train = placedEntitiesByGroup["locomotive"][1].train
        train.speed = 1.2
    end

    -- Get the East station
    local eastStation
    if placedEntitiesByGroup["train-stop"][1].backer_name == "East" then
        eastStation = placedEntitiesByGroup["train-stop"][1]
    else
        eastStation = placedEntitiesByGroup["train-stop"][2]
    end

    -- Get any underground segment
    local undergroundSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_TUCE_TestScenarioBespokeData
    local testDataBespoke = {
        eastStation = eastStation, ---@type LuaEntity
        nextExpectedActionChangeIndex = 1, ---@type uint
        undergroundSegment = undergroundSegment, ---@type LuaEntity
        finished = false ---@type boolean
    }
    testData.bespoke = testDataBespoke
end

--- Any scheduled events for the test must be Removed here so they stop running. Most tests have an event every tick to check the test progress.---@param testName string
Test.Stop = function(testName)
    local testData = TestFunctions.GetTestDataObject(testName)
    local testDataBespoke = testData.bespoke ---@type Tests_TUCE_TestScenarioBespokeData
    testDataBespoke.finished = true
end

---@param event TestFunctions_RemoteTunnelUsageChangedEvent
Test.OnTunnelUsageChangeEvent = function(event)
    -- Get testData object and testName from the event data.
    local testName = event.testName
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_TUCE_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_TUCE_TestScenarioBespokeData

    -- We have to stop reacting to train events once the test is completed and Test.Stop()  was called otherwise when the game continues to run events we don't expect will occur and the test will fail.
    if testDataBespoke.finished == true then
        return
    end

    -- Check that the event matches the next expected action change.
    local expectedActionChange = testScenario.expectedActionChanges[testDataBespoke.nextExpectedActionChangeIndex]
    if expectedActionChange.action ~= event.action then
        TestFunctions.TestFailed(testName, "action doesn't match expected")
        return
    end
    if expectedActionChange.reason ~= event.changeReason then
        TestFunctions.TestFailed(testName, "change reason doesn't match expected")
        return
    end
    if (expectedActionChange.replacedTunnelUsageIdPopulated == true and event.replacedTunnelUsageId == nil) or (expectedActionChange.replacedTunnelUsageIdPopulated == nil and event.replacedTunnelUsageId ~= nil) then
        TestFunctions.TestFailed(testName, "replacedTunnelUsageId doesn't match expected")
        return
    end
    if testDataBespoke.nextExpectedActionChangeIndex == #testScenario.expectedActionChanges then
        TestFunctions.TestCompleted(testName)
        return
    end
    testDataBespoke.nextExpectedActionChangeIndex = testDataBespoke.nextExpectedActionChangeIndex + 1

    -- Special test scenarios game manipulation required.
    if testScenario.finalActionChangeReason == FinalActionChangeReasons.terminated_abortedApproach then
        if event.action == TunnelUsageAction.startApproaching then
            if not Test.ReverseTrain(event.train, testName) then
                return
            end
        end
        return
    end
    if testScenario.finalActionChangeReason == FinalActionChangeReasons.terminated_portalTrackReleased then
        if event.action == TunnelUsageAction.onPortalTrack then
            if not Test.ReverseTrain(event.train, testName) then
                return
            end
        end
        return
    end
    if testScenario.finalActionChangeReason == FinalActionChangeReasons.onPortalTrack_abortedApproach then
        if event.action == TunnelUsageAction.startApproaching then
            if not Test.ReverseTrain(event.train, testName) then
                return
            end
        end
        return
    end
    if testScenario.finalActionChangeReason == FinalActionChangeReasons.terminated_tunnelRemoved then
        if event.action == TunnelUsageAction.entered then
            testDataBespoke.undergroundSegment.die()
        end
        return
    end
    if testScenario.finalActionChangeReason == FinalActionChangeReasons.terminated_reversedAfterLeft then
        if event.action == TunnelUsageAction.leaving then
            if not Test.ReverseTrain(event.train, testName) then
                return
            end
        end
        return
    end
end

--- Reverses the provided train back to the East station.
---@param train LuaTrain
---@return boolean trainReversedSuccessfully @ If false TestFailed() will have been called, but caller still needs to end function porcessing.
Test.ReverseTrain = function(train, testName)
    local testData = TestFunctions.GetTestDataObject(testName)
    local testDataBespoke = testData.bespoke ---@type Tests_TUCE_TestScenarioBespokeData

    train.schedule = {
        current = 1,
        records = {
            {
                station = testDataBespoke.eastStation.backer_name
            }
        }
    }
    if train.speed ~= 0 then
        TestFunctions.TestFailed(testName, "train didn't stop and reverse when requested")
        return false
    end
    return true
end

--- Generate the combinations of different tests required.
---@param testName string
Test.GenerateTestScenarios = function(testName)
    -- Global test setting used for when wanting to do all variations of lots of test files.
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    -- Work out what specific instances of each type to do.
    local finalActionChangeReasonsToTest  ---@type Tests_TUCE_FinalActionChangeReasons[]
    if DoSpecificTests then
        -- Adhock testing option.
        finalActionChangeReasonsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(FinalActionChangeReasons, SpecificFinalActionChangeReasonsFilter)
    elseif DoMinimalTests then
        finalActionChangeReasonsToTest = FinalActionChangeReasons
    else
        -- Do whole test suite.
        finalActionChangeReasonsToTest = FinalActionChangeReasons
    end

    -- Work out the combinations of the various types that we will do a test for.
    for _, finalActionChangeReason in pairs(finalActionChangeReasonsToTest) do
        --- Class name includes the abbreviation of the test name to make it unique across the mod.
        ---@class Tests_TUCE_TestScenario
        local scenario = {
            finalActionChangeReason = finalActionChangeReason,
            expectedActionChanges = Test.CalculateExpectedActionChanges(finalActionChangeReason)
        }
        table.insert(Test.TestScenarios, scenario)
        Test.RunLoopsMax = Test.RunLoopsMax + 1
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

---@class Tests_TUCE_expectedActionChange
---@field action TunnelUsageAction
---@field reason TunnelUsageChangeReason
---@field replacedTunnelUsageIdPopulated boolean

--- Works out the actions and change reasons in order for this specific finalActionChangeReason.
---@param finalActionChangeReason Tests_TUCE_FinalActionChangeReasons
---@return Tests_TUCE_expectedActionChange[] expectedActionChanges @ Array of expectedActionChanges.
Test.CalculateExpectedActionChanges = function(finalActionChangeReason)
    -- onPortalTrack, startApproaching, entered, leaving, terminated

    -- Handle special case.
    if finalActionChangeReason == FinalActionChangeReasons.terminated_abortedApproach then
        -- Needs to approach and abort before onPortalTrack. Train has a fast starting speed set to achive this.
        return {
            {
                action = TunnelUsageAction.startApproaching,
                reason = nil
            },
            {
                action = TunnelUsageAction.terminated,
                reason = TunnelUsageChangeReason.abortedApproach
            }
        }
    end

    -- Default train speed is slow so always onPortalTrack first.
    ---@type Tests_TUCE_expectedActionChange[]
    local expectedActionChanges = {
        {
            action = TunnelUsageAction.onPortalTrack,
            reason = nil
        }
    }

    if finalActionChangeReason == FinalActionChangeReasons.terminated_portalTrackReleased then
        table.insert(
            expectedActionChanges,
            {
                action = TunnelUsageAction.terminated,
                reason = TunnelUsageChangeReason.portalTrackReleased
            }
        )
        return expectedActionChanges
    end

    table.insert(
        expectedActionChanges,
        {
            action = TunnelUsageAction.startApproaching,
            reason = nil
        }
    )

    if finalActionChangeReason == FinalActionChangeReasons.onPortalTrack_abortedApproach then
        table.insert(
            expectedActionChanges,
            {
                action = TunnelUsageAction.onPortalTrack,
                reason = TunnelUsageChangeReason.abortedApproach
            }
        )
        return expectedActionChanges
    end

    table.insert(
        expectedActionChanges,
        {
            action = TunnelUsageAction.entered,
            reason = nil
        }
    )

    if finalActionChangeReason == FinalActionChangeReasons.terminated_tunnelRemoved then
        table.insert(
            expectedActionChanges,
            {
                action = TunnelUsageAction.terminated,
                reason = TunnelUsageChangeReason.tunnelRemoved
            }
        )
        return expectedActionChanges
    end

    table.insert(
        expectedActionChanges,
        {
            action = TunnelUsageAction.leaving,
            reason = nil
        }
    )

    if finalActionChangeReason == FinalActionChangeReasons.terminated_reversedAfterLeft then
        table.insert(
            expectedActionChanges,
            {
                action = TunnelUsageAction.terminated,
                reason = TunnelUsageChangeReason.reversedAfterLeft
            }
        )
        table.insert(
            expectedActionChanges,
            {
                action = TunnelUsageAction.startApproaching,
                reason = nil,
                replacedTunnelUsageIdPopulated = true
            }
        )
        return expectedActionChanges
    end

    if finalActionChangeReason == FinalActionChangeReasons.terminated_completedTunnelUsage then
        table.insert(
            expectedActionChanges,
            {
                action = TunnelUsageAction.terminated,
                reason = TunnelUsageChangeReason.completedTunnelUsage
            }
        )
        return expectedActionChanges
    end
end

return Test
