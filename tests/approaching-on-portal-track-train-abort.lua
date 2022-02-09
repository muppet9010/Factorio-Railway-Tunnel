-- This test runs a train at a tunnel and reserves the tunnel via signal. Then shortly after crossing on to the portal tracks it stops and reverses out of the portal. This is a downgrade from approaching to onPortalTrack. The whole time there is a second train from the other end of the tunnel waiting to enter. The test is completed once the first train aborted and left the portal and the second train can enter the tunnel.

local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

Test.RunTime = 3600

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local blueprint = "0eNq1WNty2jAQ/Rc9Q0ar1ZX3fkMfOhnGAZV6aizGNmmZDP9eCdNAgpuuZZKX+CKds9bZPSv0wp6qvd81Zd2xxQsrV6Fu2eLbC2vLTV1U6Vl32Hm2YGXnt2zG6mKb7pqirH4Vh2W3r2tfzXeh6Ypq2frN1tfdvO3i+82Pjh1nrKzX/jdbwHGWCerr9RWOOD7OWOQou9L3kZ5uDst6v33yTSR6hUtB1DGWsIsUu9DGKaFO5BFmrtSMHSIcRuh12fhV/1LPWNsV/TX76tv0CTcUghDxLSNiz6huGJ+LpjxzwgAdjl31W27hMrnlHbhNJre6A7fK5NZ34M7V29yBGwa5xX+57XRucJnc7g7cJpMbeFZNA+bywb/49tHnmk0T4v+bL56nsctVE9q2rDcD8eQuPYiccAYCyF5/vFMAKjcA+SmCZOeHyslHyHQcmG53uUYL090ut7/AdLPLbasw3esg1+IFn86dm9YCpnPnVrgQ07lzU01gTjmL3HoWFzN741Qf7IPfL+cQ6sWTqrAK29CVz34Ikj9oa65wQ1NGqHO8/CHhpI1/myasQvpBoPhxiFDTPwPpn2HoqEBHtWRU6eiojo5qyKjI6aj09ECgo9LVQkFHpauFSEZFulpILzscoZaioooRYpFLS4yIlFxZYsSikgsLR+hPriukp6oklxXShZJAMt3rLH1nt8mJV6EKTRrapCfgBChttY4XFkw0a2dtvEr5s0kDpBZGKuBcKGcstxaNdVyn908nSCOUdBwRtEwDhEGJiadIbznHnsAqh9oqLbSzqKVQJnEcr9y/Caufvpt/3/vUBIZ6gCTX/4iSkuTyH1H9klz9I4xK0nqu1B9227fyKzz9aQAZlZVCWBXVehVfOAkxKaJ2yKN8XIKLcp4a+kl80ctrAA06dAokaH4G+AT9yUY1oqlIslGN6H+SbFQjWrUkG9WIXYXipDPSv4jmZqd9OSL9UqQj0sf4aPXDr/fV+Uz2kqvpXqirAf3p8nuAFOXbSbFI5Afz+rPZx0R9OkReXB1kx/2xb9o+WAvSOGFihgPquMv8Aw+fngg="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    local surface = TestFunctions.GetTestSurface()

    -- Get the "East" train stop of the 2 train stops we know are in the BP.
    local eastTrainStop = placedEntitiesByGroup["train-stop"][1]
    if eastTrainStop.backer_name ~= "East" then
        eastTrainStop = placedEntitiesByGroup["train-stop"][2]
    end

    -- Get the primary (right) train and set its starting speed.
    local primaryTrain = placedEntitiesByGroup["locomotive"][2].train
    primaryTrain.speed = 0.75

    -- Get the secondary (left) train.
    local secondaryTrain = placedEntitiesByGroup["locomotive"][1].train

    -- Get the outside ends of entrance portals.
    local entrancePortalPart, entrancePortalXPos = nil, -100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x > entrancePortalXPos then
            entrancePortalPart = portalEntity
            entrancePortalXPos = portalEntity.position.x
        end
    end

    -- Get the entrance portal's entry train detector.
    local entrancePortalTrainDetector = surface.find_entities_filtered {area = {top_left = {x = entrancePortalPart.position.x - 3, y = entrancePortalPart.position.y - 3}, right_bottom = {x = entrancePortalPart.position.x + 3, y = entrancePortalPart.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1", limit = 1}[1]

    -- Add test data for use in the EveryTick().
    local testData = TestFunctions.GetTestDataObject(testName)
    --- Class name includes the abbreviation of the test name to make it unique across the mod.
    ---@class Tests_AOPTTA_TestScenarioBespokeData
    local testDataBespoke = {
        eastTrainStop = eastTrainStop, ---@type LuaEntity
        primaryTrain = primaryTrain, ---@type LuaTrain
        secondaryTrain = secondaryTrain, ---@type LuaTrain
        entrancePortalTrainDetector = entrancePortalTrainDetector, ---@type LuaEntity
        startedApproaching = false, ---@type boolean
        waitTickAfterOnPortalTrack = nil ---@type Tick
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
    local testDataBespoke = testData.bespoke ---@type Tests_AOPTTA_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    -- Check initial events occur in expected order.
    if not testDataBespoke.startedApproaching then
        if tunnelUsageChanges.lastAction ~= nil then
            if tunnelUsageChanges.lastAction == Common.TunnelUsageAction.startApproaching then
                testDataBespoke.startedApproaching = true
            else
                TestFunctions.TestFailed(testName, "first tunnel state should have been startApproaching")
            end
        end
        return
    end

    -- Wait until the entry train detector triggers to know when the train is on the portal track and then set a desired future tick to resume processing.
    if testDataBespoke.waitTickAfterOnPortalTrack == nil then
        if not testDataBespoke.entrancePortalTrainDetector.valid then
            testDataBespoke.waitTickAfterOnPortalTrack = event.tick + 10
        end
        return
    end

    -- Wait for the desired tick.
    if event.tick < testDataBespoke.waitTickAfterOnPortalTrack then
        if not testDataBespoke.secondaryTrain.valid then
            -- The secondary train entered the tunnel at some prior point incorrectly, but just check here as we don't want to check it after this point.
            TestFunctions.TestFailed(testName, "secondary train should have not entered the tunnel before the primary train has finished with it")
        end
        return
    elseif event.tick == testDataBespoke.waitTickAfterOnPortalTrack then
        -- 10 ticks after train triggered onPortalTrack.
        testDataBespoke.primaryTrain.schedule = {
            current = 1,
            records = {
                {
                    station = testDataBespoke.eastTrainStop.backer_name
                }
            }
        }
        if testDataBespoke.primaryTrain.speed ~= 0 then
            TestFunctions.TestFailed(testName, "train speed should be 0 after setting schedule behind it")
            return
        end
        return
    end

    -- When train reaches the East train stop and the secondary train has entered the tunnel the test is done.
    if testDataBespoke.eastTrainStop.get_stopped_train() ~= nil and not testDataBespoke.secondaryTrain.valid then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
