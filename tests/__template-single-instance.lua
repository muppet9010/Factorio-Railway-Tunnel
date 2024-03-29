-- SAMPLE TEST FILE - Functions are populated with sample code in keeping with the other test design.
-- As a single instance test this test file is run just once.

-- Any created test has to be added to the test list at the top of test-manager.lua.
-- A single test is run at a time and if the test is successful the map is cleared and the next test started. Each test only has to manage its own activities and feed back via the listed Interfaces.
-- The referenced TestFunctions file has comments on the functions for their use.
-- Tests should only use their own blueprint items lists and any searches based off thier own tracked entities. So no getting a forces train list, etc. This is to enable future concurrent running of tests.

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

--- OPTIONAL, can exclude the attribute. If present it will be called when starting a test and the returned name used, otherwise the test name as defined in test-manager.lua is used.
---@param testName string
Test.GetTestDisplayName = function(testName)
    return testName
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local blueprint = "0eNq1WduOmzAQ/Rc/J5U942ve+w19qFYRS9wsKoEIyLbRKv9eO6SbXUFbj8vmJYCdcyacOTMGv7DH+uSPXdUMbPPCqrJterb5+sL6at8Udbw2nI+ebVg1+ANbsaY4xLOuqOofxXk7nJrG1+tj2w1Fve39/uCbYd0PYXz/NLDLilXNzv9kG3FZZYL6ZvcGBy4PKxY4qqHyY6TXk/O2OR0efReIXuFiEE2IpT0GimPbh5+0TSQPMGuh3Iqdw4ELkbFd1flyHNYr1g/FeMy++D7+iQkJJMQ8wylunNZNOJ+LrrqxihlCpN75OXaVyy6XYMdcdrUEu8hl1wuw82zdzRLsZp4d/slul2BXuexuCXbMZRc8y+POZROKPxGeQunr9l0bvid/eh3nbsuu7fuq2c8FlH3/BeQENBdCvgi4VAgiOwT5IbLY/DxRWYlps6u/WKAE2uz6KxYogSa7/ooFSqAx2ewLlECT7X/gC7BnWx/EAuzZrgf4f3adnXWAWRbX2RaHe5F7V8H+tnCe3NQ5XEXANQRcTcBVBFxDwEUCriXgCgKuS8eVBN2QE3AJuqEg4BJ0QyDgEnRDJOASdEOC35CiG8FvSNGN4Dek6EbwG1J0I/gNKboR/AYE3STBb0DQTRL8BgTdJMFvQNBNpvtNE2ST6XajdDeZ7jZKc5PpZqP0NpnuNUprk+lWo3Q2eXda3ZbtoR2qZz+D+a77tF0VYG7rHP4pLn3Ltm67OLmLV4QDobTVOhxYYbQ1ztpwFHN/HydIDUYqwTkoZyy3Fo11XMfxxyukASUdRxRaxglgUGLkKeIo5zgSWOVQW6VBO4tagjKRI77FHPyhv4bTlt/9sP528jXbqMvca6/0mkBp7Sq9JFA6u0qvCJTGrjAxDfif0wAmaaDw+tFCyKCwBLAqqPaaBOCkCMkRNEQeZORSuCCrNb+TAEaZTWih6NCp0Po1vwF8QB6kFy/K0kalFy/KykalFy/KwkalFy/KukbZtN2CV0wzeZC8bxZ8LuJmwUO4VD753am+7U/c8zaeB6sqfDNn3GyZbjhMYCPwdbtk82bLJjzY+a4fQ7FhJe7AKLAgES6XX60Og40="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    -- Get the "West" train stop of the 2 train stops we know are in the BP.
    local westTrainStop = placedEntitiesByGroup["train-stop"][1]
    if westTrainStop.backer_name ~= "West" then
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    --- Class name includes the abbreviation of the test name to make it unique across the mod.
    ---@class Tests_TSI_TestScenarioBespokeData
    local testDataBespoke = {
        announcedTunnelUsage = false, ---@type boolean
        westTrainStop = westTrainStop ---@type LuaEntity
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

    if tunnelUsageChanges.lastAction == Common.TunnelUsageAction.leaving and not testDataBespoke.announcedTunnelUsage then
        testDataBespoke.announcedTunnelUsage = true
        game.print("train has completed tunnel trip")
    end

    if not testDataBespoke.westTrainStop.valid then
        TestFunctions.TestFailed(testName, "West station was removed")
        return
    end

    if testDataBespoke.westTrainStop.get_stopped_train() ~= nil then
        game.print("train reached West station, so stop test")
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
