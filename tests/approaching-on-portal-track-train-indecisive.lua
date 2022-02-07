-- This test runs a train at a tunnel and reserves the tunnel via signal. Then shortly after crossing on to the portal tracks it stops and reverses a bit out of the portal. Before leaving the portal tracks it re-commits to using the tunnel and completes its journey. This is a downgrade from approaching to onPortalTrack and then upgrades back. The whole time there is a second train from the other end of the tunnel waiting to enter. Once the second train is  able to enter the portal after the first train completed its traversal the test is completed.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Common = require("scripts/common")

Test.RunTime = 3600

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

--- This is run to setup and start the test including scheduling any events required. Most tests have an event every tick to check the test progress.
---@param testName string
Test.Start = function(testName)
    local blueprint = "0eNq1mN1y2jAQhd9F19DRavXLfZ6hF50M44BKPDU2Y5u0TIZ3r4RpoMFpVzLhBtsy55N1tMdCr+yp2vtdW9Y9W7yyctXUHVt8e2VduamLKl7rDzvPFqzs/ZbNWF1s41lblNXP4rDs93Xtq/muafuiWnZ+s/V1P+/60L557tlxxsp67X+xBRxnmaK+Xl/piOPjjAVG2Zd+6Onp5LCs99sn3wbQm1zsRB360uwCYtd04SdNHeFBZi7djB3CNwbpddn61dCoZ6zri+GYffVdfIQbhCD0+JYozECEG+JL0ZZnJozgMHXUR9iYyZZ3YEMmW01ng8tk6zuwc/02d2CrUbb4L9vegY2ZbHcHNmSygWfVtMnFwUe4fYi5dtM24fvmgefx3uWqbbqurDcj3ckdeRA53Rkb/9wO4H06kM2Xn+FHth0qZzLmxg1MzzrIjXiYnnWQ+2qD6Vn3QcwS2NOzDnKzR/DpbJfLhslskVvjQkxn5841gTkVnb1iFJc4+yur/rEOfj+cY6qKrmroqpququiqhq6KdFVLVwW6qiOrIt0t5HRVulsIdFW6WyjoqnS3EOmqdLeQXFspouTSSnl+cmWlWEUurJRZRa6rlAIgl1VCrcpLVVXNqtk2ffniRxSvBrRpyyByTmv+xYSmVVM1bby1jVfACVDaah0OLBhtjbM2HMW83cQbpBZGKuBcKGcstxaNdVzH9qeTpBFKOo4IWsYbhEGJkVPEVs5xAFjlUFulhXYWtRTKREbcWun9tjt1p1n98P38+95X4e/3cez5yfWfEKuSXP4JbwBJrv6El5WUJPuV+NB+cWO/wtNHA8jgrBTCquDWm/nCSQiTIniHPNjHJbhgpzV/zBeDvQbQoEOnQILmZ4FP8J8cVAkLC0kOKpVQqeSgUgkzlRxUKmGmOtKW5Vnxdt172bB8KOKG5WO4tHr263113iG9TNV4HiJMyqt7hu3ed5uej1HltDu7uNohDgtP33YD14I0TpgwVwE1Px5/A07GZa4="
    -- The building bleuprint function returns lists of what it built for easy caching and future reference in the test's execution.
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprint, {x = 0, y = 0}, testName)

    local surface = TestFunctions.GetTestSurface()

    -- Get the "East" and "West" train stops.
    local eastTrainStop, westTrainStop
    if placedEntitiesByGroup["train-stop"][1].backer_name == "East" then
        eastTrainStop = placedEntitiesByGroup["train-stop"][1]
        westTrainStop = placedEntitiesByGroup["train-stop"][2]
    else
        eastTrainStop = placedEntitiesByGroup["train-stop"][2]
        westTrainStop = placedEntitiesByGroup["train-stop"][1]
    end

    -- Get the primary (right) train and set its starting speed.
    local primaryTrain = placedEntitiesByGroup["locomotive"][2].train
    primaryTrain.speed = 0.75

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
        westTrainStop = westTrainStop, ---@type LuaEntity
        primaryTrain = primaryTrain, ---@type LuaTrain
        entrancePortalTrainDetector = entrancePortalTrainDetector, ---@type LuaEntity
        startedApproaching = false, ---@type boolean
        tickToReverseOn = nil, ---@type Tick
        tickToResumeOn = nil ---@type Tick
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
    if testDataBespoke.tickToReverseOn == nil then
        if not testDataBespoke.entrancePortalTrainDetector.valid then
            testDataBespoke.tickToReverseOn = event.tick + 10
            game.print("train on portal tracks")
        end
        return
    end

    -- Wait for the desired reverse tick.
    if event.tick < testDataBespoke.tickToReverseOn then
        return
    elseif event.tick == testDataBespoke.tickToReverseOn then
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
        testDataBespoke.tickToResumeOn = event.tick + 50
        game.print("train reversed away from tunnel")
        return
    end

    -- Wait for the desired resume tick.
    if event.tick < testDataBespoke.tickToResumeOn then
        return
    elseif event.tick == testDataBespoke.tickToResumeOn then
        -- 10 ticks after train started reversing, it should still be on the portal tracks at this point.
        testDataBespoke.primaryTrain.schedule = {
            current = 1,
            records = {
                {
                    station = testDataBespoke.westTrainStop.backer_name
                }
            }
        }
        if testDataBespoke.primaryTrain.speed ~= 0 then
            TestFunctions.TestFailed(testName, "train speed should be 0 after setting schedule infront of it")
            return
        end
        game.print("train resumed tunnel usage")
        return
    end

    -- When train reaches the West train stop the test is done.
    if testDataBespoke.westTrainStop.get_stopped_train() ~= nil then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
