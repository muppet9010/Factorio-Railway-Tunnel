-- SAMPLE TEST FILE - Functions are populated with sample code in keeping with the other test design.
-- As a single instance test this test file is run just once.

-- Any created test has to be added to the test list at the top of test-manager.lua.
-- A single test is run at a time and if the test is successful the map is cleared and the next test started. Each test only has to manage its own activities and feed back via the listed Interfaces.
-- The referenced TestFunctions file has comments on the functions for their use.
-- Tests should only use their own blueprint items lists and any searches based off thier own tracked entities. So no getting a forces train list, etc. This is to enable future concurrent running of tests.

local Test = {}
local TestFunctions = require("scripts.test-functions")

--- How long the test runs for (ticks) before being failed as un-completed. Should be safely longer than the test should take to complete, but can otherwise be approx.
Test.RunTime = 3600

--- Any scheduled event types for the test must be Registered here. Most tests will want an event every tick to check the test progress.
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick) -- Register for enabling during Start().
    TestFunctions.RegisterRecordTunnelUsageChanges(testName) -- Have tunnel usage changes being added to the test's TestData object.
end

--- OPTIONAL, can exclude the attribute. If present it will be called when starting a test and the returned name used, otherwise the test name as defined in test-manager.lua is used.
---@param testName string
Test.GetTestDisplayName = function(testName)
    return testName
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local blueprint = "0eNq1WMtu2zAQ/JWAZykQuXz6I3rpsQgMRWYdorJk6JHWMPzvpSQ3NuJNom0UH2wL5M6Qo1lKu0f2WPZ+34SqY6sj2/i2aMK+C3XFVoyn/K5r8lDd5dXmruurypcsYaGoq5atfhxZG7ZVXg6B3WHvY0To/C7OqPLdcBVDy9/5YT1Fpvu66fJy7asNO0WUauP/sBU/JbNwrkLEjJCyLupd3YVnfxUIaOBzaLo+Ly+x04xUXEXK00PCfNWFLvhp6+PFYV31u0ffxG1gzAnb122YxDyyYeUqYQe2SnXcAqubEEHyaThLWFGXdTNMjF/ZvYLxozmX1oIUwiqu9ACwHYaFk5wbrRxABtpmkjsnuDVx/HEczyBeK8PBgAOnuOQ6OwPkw4RsmqCtjRjaxhHtLGgplLFcqGHrUdB2XE9d/PJd+rOPd3+lToOIr3YvLtoNftk+del4z94WAIWBF5jRdWnb1XsEw7xgJJHvLCD7Ft31xBBUSV4cYItTZBiOwWgqjHIYjCH5Takbv92r147jkx+0jn9s9JY1zloxmOHsOamFkYpnmVDO2Cza0liXjZYaPWeMUNJlAFzLYYIwIMF8ieEsWUWDwTgyDLoanpFxUItxTsZBPcbJ+ShRk3Eg46Ayc3IKSlxncg5KXGdyEkpcZzPjUfcmJpjo+U1ofDENRpGe8yacE5RjfPYDvtZvdzEm/berd8iBTO6WI4/4H9GJbDE64WbQ8eXozAw6sRydot5JAcuRk20k5HLknEyuPpOwnJywQr/F18f3ymbb1PH3ZsfjWbQumrptQ7V9Zz0ww2jmf1bwDuec1LXLcs5JX/eVQs9IaMg+9SiYQbDYATXjDsJix9OcnS12HKkZZIsdP+TDANRS1I5MrRczD/nMBbMYN/lhA/YTWUk/7oFaTwj0tVJSywmBvuVKajUh0JduSS0mBFoDSGotIdCSRFJLCcAlplYSgEtMLSQAl9hQYXCJqVUx4BJTXYwXR4rqYrxWU1QX46WjoroYr2QV1cV4Ya2oLsbrfEV1Md52UFQX410QZea172DCuD1dL72873WP9/IU1eJD3+chQhdPftOX597tpWU2XPPEXM2Y+trISm46jQ8D8Nh1Xl010eNDwjftOFFYLo0TRjolzSD9XyErxQk="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "South" train stop of the 2 train stops we know are in the BP.
    local southTrainStop = placedEntitiesByGroup["train-stop"][1]
    if southTrainStop.backer_name ~= "South" then
        southTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    --- Class name includes the abbreviation of the test name to make it unique across the mod.
    ---@class Tests_TSI_TestScenarioBespokeData
    local testDataBespoke = {
        announcedTunnelUsage = false, ---@type boolean
        southTrainStop = southTrainStop ---@type LuaEntity
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
    local testDataBespoke = testData.bespoke ---@type Tests_TSI_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    if tunnelUsageChanges.lastAction == "leaving" and not testDataBespoke.announcedTunnelUsage then
        testDataBespoke.announcedTunnelUsage = true
        game.print("train has completed tunnel trip")
    end

    if not testDataBespoke.southTrainStop.valid then
        TestFunctions.TestFailed(testName, "South station was removed")
        return
    end

    if testDataBespoke.southTrainStop.get_stopped_train() ~= nil then
        game.print("train reached South station, so stop test")
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
