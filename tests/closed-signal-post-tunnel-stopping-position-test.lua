-- Purpose: to check that a train leaving a tunnel in to a closed signal stops at the correct location and doesn't overshoot or have weird train orders.
-- Test: a train is trying to path through a red signal on the far side of a tunnel as part of going through a station just beyond the tunnel non-stop. The signal is on a curved rail and the leaving train gets a temporary stop target applide by the tunnel of past the station and rail signal. Once the red signal opens the train pulls up to its temporary stop target and finds its real target station is behind it, thus the train no-paths. Test completes when the slow second train that made the red signal has reached the north station, which is ample time for the no-path state to be reached.
-- Found on a congested train network that was found to have the trains leaving the tunnel overshooting the target station in some cases; resulting in No-Path state. Target station was just before a corner with a rail signal that may have been red at time of train leaving tunnel.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

--- How long the test runs for (ticks) before being failed as un-completed. Should be safely longer than the test should take to complete, but can otherwise be approx.
Test.RunTime = 3600

--- Any scheduled event types for the test must be Registered here. Most tests will want an event every tick to check the test progress.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    TestFunctions.RegisterRecordTunnelUsageChanges(testName) -- Have tunnel usage changes being added to the test's TestData object.
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local blueprint = "0eNq1mk1z4kgMhv+Lz0D190eO8wP2soc9bKUoBrwZ14BNGZPZVCr/fdtgEgJq0DvxnhICeVpSv1Kbll6L7+t9uW2ruiseXotq2dS74uHv12JXPdWLdf+37mVbFg9F1ZWbYlLUi03/ql1U61+Ll3m3r+tyPd02bbdYz3fl06asu+muS+8//eiKt0lR1avy3+JBvk1+E1rWqzOOenucFGmNqqvKo6WHFy/zer/5XrZpoXfculk2m6arnsu0xLbZpX9p6n7xhLEyfe6leJgak9hNWyXK4vi+mBzM2vWfbJvlz7Kb/rMv170LvQ8Xy6n35U5OT3s3bq3oKY5+5/SYOoWw2VIQ/Q6ZpBUHk4s/Uqh+FATW4OZZyjyLczTFcTiHDLvHdln7q12eWWifA2y4jhQn4hxSL1LgIHJnpcRB5NbKj1RY7tvncpXFiCNGhbQpq6otl8d3LQXVuHXk/kk8ExS5gRJPBUXvID8XhB9A+nPEPIX1ONZ+xmoKiyeAovXGzwBhB5C877YSOFbfd1vJT6fTdDjBCGicvWNnpOMKPyoUmWiKnxNiOC5kZETQwNjLjSEjaBnnez4El5YnI58XbTVUcUktCOTVaRHPCI/HsZERnsAVmDkJTCap3a+cip1nJsYBbO+HQQsc6++HQUs+dqhaklEMtcKxjGKoNfogfEPgFhW4NnynTpJhVFBtcSyjgmo3Yqz69e5Fx/PdGMoYozjqAFMlozjqOGJw5P3gGCB7ByyjNBoJUxmV0ajxYhMZoWGfqiYMhY1RLo2BqYxqaex4ofFo+TGO79JQUxmV2niYyijUJowXKLhOm8j7QmSCOawgPi9AIa0Yzx+N+mPlV57kJLwc/+wOx5JL31xkz+p9vSrbp7ZJP6/idlhpvmyb3a6qn/Je2fuFxRrUD/LrorW/40fecs+w3KGWk9+YrR/XckYxtwG1XJK3Bjb+n+LhnNhOwJ7QF29fS16Gzh2cr5JMWKdhDpkwDs47ScrXjXfYSoZ0HZx0ipSu86OZrTg6hTOOvtxw4z0RK8a3BQ+nF32r5eV4ZsMPGh7OPPpG0o/3tVbBj5UeTlf6ftaPl64KvnvycPLSt9V+vOTV8IOXh1OZbgj4+JUjR8NpEOBcpjsiQcIcMp0CnJZ0yyjAPZAMB84wuvcW4A5IhgMnC91TDB62h+bAuqd7pQHu8dGcCOuZbi1HuMOX4cB6NnQLFNZzhgPr2ZI6jLCeMxxYz5bUYYT1nOHAera0DmE90xwpYEHbTO8bVnQOhN8x0E1hAWs6B4JF7eh+t4BVnQPBsnb0fICAdZ0DwcJ2GUHCys6AJKxsRwsSn8bIgWBlO1qQUvMalCacGpTuqj9pSDA8kZGz0MIXbLTSJTydlAN52CJa6WdTF7fGwkywJ8r5VNi3dT/W1P61qLqCpMPyz5ipYPl7Oo/Oxi1ujsGJeKJcfkf48P7PZk/PxEl8EiNnrsZu+INg5MXZHAZrjuoSSo5RXUxhMOZYvJtlnIb7P0FzLPTMWMbBbceYhTqbrrgdS2FIqCKhEZ2wCow+uTybrLg50yjUzCZwOOzpweaZsV5oebg4uhhyVMJrZ5WKXtmgvRfeymj14X/fpx+XTT+UawW53Zo3UGuinTkj3IdRMToRtSeM8lZIa40JUWrrjZLB881R6JRC8Iw91RodFOFhDTotc419TEVt+aNc7dfDwPPHNvSv5cSffeI4u03MBV/Vxcf+rxeoJMG033nc+YEyKX6lH/NlU68OfhxtS7jtoi3nw3x306bPDb931abXTVctf+76eUJxNOHK2Mfe48Ng+MPZcPqkeC7b3TEkQRofVVKyldolmfwHc3RylQ=="
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    local northStation
    if placedEntitiesByGroup["train-stop"][1].backer_name == "North" then
        northStation = placedEntitiesByGroup["train-stop"][1]
    else
        northStation = placedEntitiesByGroup["train-stop"][2]
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_S1_TestScenarioBespokeData
    local testDataBespoke = {
        northStation = northStation, ---@type LuaEntity
        tunnelTrain = nil ---@type LuaTrain[]
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
    local testDataBespoke = testData.bespoke ---@type Tests_S1_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Track when a train has left the tunnel.
    if testDataBespoke.tunnelTrain == nil then
        if tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving then
            testDataBespoke.tunnelTrain = tunnelUsageChanges.train
        else
            -- Nothing to do yet.
            return
        end
    end

    --Check the trains that left the tunnel doesn't no-path.
    if testDataBespoke.tunnelTrain.state == defines.train_state.no_path then
        TestFunctions.TestFailed(testName, "train is no pathing")
        return
    end

    -- Once a train reaches the north station after the tunnel has been used the test is over.
    if testDataBespoke.northStation.get_stopped_train() ~= nil then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
