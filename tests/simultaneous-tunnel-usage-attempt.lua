--[[
    2 facing trains set to try and use the tunnel on the exact same tick with each train trying to path through the tunnel. One of them will be acepted for the tunnel and the other blocked. After 5 seconds of the player alert firing the test will send the blocked train backwards to unjam the tunnel exit (equivilent to manual intervention). Thus allowing the first train out of the tunnel and the second makes its journey afterwards.

    Breaks due to known non ideal behaviour regarding 2 trains simultaniously appraoching a tunnel from opposite ends at slow speed. At present the 2 trains are stopped and a GUI alert is raised for both trains and the player has to resolve it. This test currently verifies this work around situation.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

-- How the train triggers the portal first. Done by setting train's starting speed.
local PortalTriggered = {
    onPortalTrack = "onPortalTrack", -- Both trains trigger via trying to move on to the portal tracks. Meaning they are both blocking their portal's exit rail when one is chosen as being blocked from using the tunnel.
    startApproachingSlower = "startApproachingSlower", -- The slower speed to trigger this way. Both trains are blocking their portal's exit rail when one is chosen as being blocked from using the tunnel.
    startApproachingFaster = "startApproachingFaster" -- The faster speed to trigger this way. Both trains are back in their own waiting rail segments when they double reserve the tunnel and one is chosen as being blocked from using the tunnel.
}
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_TMI_TestScenario[]
Test.TestScenarios = {} -- Populated when script loaded

Test.RunTime = 3600

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
end

local blueprintString = "0eNq1Wl1v6jgQ/SurPEPlrxnbvO/+hX24qqo0ZGl0Q4KS0LtVxX9fm+QWKKaMne5LaXByjpmZMzO285491/ty11XNkK3es6pomz5b/XjP+mrT5LX/bnjbldkqq4Zymy2yJt/6qy6v6uywyKpmXf6brfhhQXrkV/72NOybpqyXu7Yb8vqpLzfbshmW/eDGNy/DGag4PC4yN1YNVTlO6njx9tTst89l51g/sP3DjcNod45v1/bukbbxM3EwS2UX2Vu2UtpBr6uuLMZBXGT9kI//Z3+Xvae+ohAfFL8nuDz+9Nss9pJFBEAlHVSTQRUdFMigQAeVZFCkg3IyqCaDSrqjzAdose9ey/VNSHWEBHYJKQOQlgapMIiIAUTOqD8d6ObknAxKdzwnqwnoIcrJagK6mDhZTUCPJk5WE0Y4Ci8S7LJ4OWbCMRUHIpU9wBRZD3A/WrkmKkCYEVVdYuoQJlFVigUhg0awMUZQ4qYNeKgEMFKZmXwG/NN0z6vMn/mNKhNXyUDeqWR//JXX9XNe/AySibiI+bCW+GytkHeFTESXn9FDjhbqTjtRNutQdE6+gSu7veZdlX/he4htX67JuU4lx28gh1Ry/Q3kMpXcfAN5ss/tfHIb5BZ3uSWbz61Tufl8bkjlFkm65ql08hbd3i09uk3Xus+r33usU09F1/Z91WyupyNTZ6NSZhNoRVL54Xv4kwMP/w9vJEtQp4RicqqT81NdcoGR8zMdt4ncan6mS67qan6mE6liV2I+d6rQlZzPnSpypeZzJ8capEhapkpaRS3JlLrZX0MIXKeBk9prdUpGdVu023aoXsvQOgRPpmm7yqFM5mAP2vEVbd12/t7Of8OYtIIDGgNWogEUaI1EJUAb7mN54+8ySjMwRgpUoDgKsBrdrW742Q8rNyYkSG4QmZbIjLRGSc+WE0j8puJQbvvjpNriZzks/9mXtfdfyAw2dtcPCMYFFrvtR0Llsft+JFQRu/FHQpW08JL2ZniJq/DSXGoBwNwf73ljUU2Bsfl6eIorZRm3KJUWElFKydgUlrPiSoTiClTszifJqhC79UlCpe/SyohojdimjYhWQ0eNiFZ6FpB0byE9Cwi6t5CeBQTdW0jPAoLuLSRv2EYEFpKlFaEBJCsrQq5IFlZEZkWyriKKAJJlFVGv0JJqAPCIDsO1CsfuwaVxrcHn8ql1OFYA6QuAspwjcq4M01wYy06thUvuKLR7Bl2mt1YzzeT8AgChAqDJ4o/oKzSPPP8hgYrI8x8SKK3+g4ko/8r7DjhjvmM0zHWQ+rd3R++P9Z2jUcK7zmqFzJ4aADM1ltoIBOkAwM7vKsPOV5GnXySTQuTpFwkUI0+/SKA68vSLBGoSTxvw83IodLKqbdpaiwRu4o6V9J1jpbMjn0c3VryU6309vTZxEpu/dos8kGf3jK97fDqjevQzvnzOZW79xXPjGxSPnv343sfq7M0St2Quu36cuOFKW6dZC0qDPBz+A7k5RdQ="

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.portalTriggered
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationWest, stationWestFallback, stationEast, stationEastFallback
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "West Fallback" then
            stationWestFallback = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
        elseif stationEntity.backer_name == "East Fallback" then
            stationEastFallback = stationEntity
        end
    end

    -- Get the 2 trains.
    local headingWestTrain, headingEastTrain
    for _, locomotive in pairs(placedEntitiesByGroup["locomotive"]) do
        if headingWestTrain == nil and locomotive.position.x > 0 then
            headingWestTrain = locomotive.train
        elseif headingEastTrain == nil and locomotive.position.x < 0 then
            headingEastTrain = locomotive.train
        end
    end

    -- Get the player as we need to check their alerts.
    local player = game.connected_players[1]
    if player == nil then
        TestFunctions.TestFailed(testName, "Test requires player to check alerts on.")
        return
    end

    -- Get the 2 portal's entry portal end entity.
    local eastPortalEntryEnd, eastPortalEntryEndXPos, westPortalEntryEnd = nil, -100000, nil
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x > eastPortalEntryEndXPos then
            westPortalEntryEnd = eastPortalEntryEnd -- May be nil if first portal end is east, but will be corrected when second portal end is checked.
            eastPortalEntryEnd = portalEntity
            eastPortalEntryEndXPos = portalEntity.position.x
        else
            westPortalEntryEnd = portalEntity
        end
    end

    -- Train speed is based on how we want to trigger the portal. Do this after all setup so train pathign and state is applied correctly.
    local trainTargetSpeed
    if testScenario.portalTriggered == PortalTriggered.onPortalTrack then
        trainTargetSpeed = 0
    elseif testScenario.portalTriggered == PortalTriggered.startApproachingSlower then
        trainTargetSpeed = 0.4
    elseif testScenario.portalTriggered == PortalTriggered.startApproachingFaster then
        trainTargetSpeed = 0.75
    else
        error("unsupported portalTriggered mode: " .. testScenario.portalTriggered)
    end
    -- Set the trains to speed and automatic. Have to start as manual to check if speed applies correctly and correct if the train is going backwards.
    -- West heading train.
    headingWestTrain.manual_mode = true
    headingWestTrain.speed = trainTargetSpeed
    headingWestTrain.manual_mode = false
    if trainTargetSpeed ~= headingWestTrain.speed then
        headingWestTrain.speed = -trainTargetSpeed
    end
    -- East heading train.
    headingEastTrain.manual_mode = true
    headingEastTrain.speed = trainTargetSpeed
    headingEastTrain.manual_mode = false
    if trainTargetSpeed ~= headingEastTrain.speed then
        headingEastTrain.speed = -trainTargetSpeed
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    --- Class name includes the abbreviation of the test name to make it unique across the mod.
    ---@class Tests_STUA_TestScenarioBespokeData
    local testDataBespoke = {
        stationEast = stationEast, ---@type LuaEntity
        stationWest = stationWest, ---@type LuaEntity
        stationEastFallback = stationEastFallback, ---@type LuaEntity
        stationWestFallback = stationWestFallback, ---@type LuaEntity
        stationEastReached = false,
        stationWestReached = false,
        headingWestTrain = headingWestTrain, ---@type LuaTrain
        headingEastTrain = headingEastTrain, ---@type LuaTrain
        trainsStartedMoving = false,
        player = player,
        eastPortalEntryEnd = eastPortalEntryEnd, ---@type LuaEntity
        westPortalEntryEnd = westPortalEntryEnd, ---@type LuaEntity
        stoppedAlertsStartedTick = nil, ---@type uint|null
        trainNamesAlerting = {} ---@type string[] @ Array of the train reference name in the testDataBespoke object.
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
    local testDataBespoke = testData.bespoke ---@type Tests_STUA_TestScenarioBespokeData

    -- If the train's haven't started moving for the first time then wait.
    if not testDataBespoke.trainsStartedMoving then
        if testDataBespoke.headingWestTrain.speed ~= 0 then
            testDataBespoke.trainsStartedMoving = true
        else
            return
        end
    end

    -- CURRENT KNOWN LIMITATION BEHAVIOUR - START
    -- Check if any trains have been stopped for the first time.
    if testDataBespoke.stoppedAlertsStartedTick == nil and (testDataBespoke.headingWestTrain.speed == 0 or testDataBespoke.headingEastTrain.speed == 0) then
        -- One ore more of the trains have been stopped, so check theres an alert somewhere.

        -- The alerts should appear instantly.
        -- The alerts are against a carriage of the train so check them all to see if any alerts for that train exist.
        local westPlayerAlertsCarriage1 = testDataBespoke.player.get_alerts {entity = testDataBespoke.headingEastTrain.carriages[1]}
        local westPlayerAlertsCarriage2 = testDataBespoke.player.get_alerts {entity = testDataBespoke.headingEastTrain.carriages[2]}
        local westPlayerAlerts = Utils.TableMerge({westPlayerAlertsCarriage1, westPlayerAlertsCarriage2})
        local westAlertSurfaceIndex = testDataBespoke.westPortalEntryEnd.surface.index
        if westPlayerAlerts[westAlertSurfaceIndex] == nil or #westPlayerAlerts[westAlertSurfaceIndex] == 0 or #westPlayerAlerts[westAlertSurfaceIndex][defines.alert_type.custom] == 1 then
            table.insert(testDataBespoke.trainNamesAlerting, "headingEastTrain")
        end
        local eastPlayerAlertsCarriage1 = testDataBespoke.player.get_alerts {entity = testDataBespoke.headingWestTrain.carriages[1]}
        local eastPlayerAlertsCarriage2 = testDataBespoke.player.get_alerts {entity = testDataBespoke.headingWestTrain.carriages[2]}
        local eastPlayerAlerts = Utils.TableMerge({eastPlayerAlertsCarriage1, eastPlayerAlertsCarriage2})
        local eastAlertSurfaceIndex = testDataBespoke.eastPortalEntryEnd.surface.index
        if eastPlayerAlerts[eastAlertSurfaceIndex] == nil or #eastPlayerAlerts[eastAlertSurfaceIndex] == 0 or #eastPlayerAlerts[eastAlertSurfaceIndex][defines.alert_type.custom] == 1 then
            table.insert(testDataBespoke.trainNamesAlerting, "headingWestTrain")
        end

        if #testDataBespoke.trainNamesAlerting == 0 then
            TestFunctions.TestFailed(testName, "One or more of the trains were rejected from the tunnel, but no alerts found")
            return
        end

        -- Flag this state as reached.
        testDataBespoke.stoppedAlertsStartedTick = event.tick
    end

    -- Wait a few seconds after the alerts started so the human can notice them. Then review whats happened and if we need to fix anything.
    if testDataBespoke.stoppedAlertsStartedTick ~= nil and event.tick == testDataBespoke.stoppedAlertsStartedTick + 300 then
        if #testDataBespoke.trainNamesAlerting == 2 then
            -- Both trains stopped, so order one of the trains out of the way and restart the other.

            -- West heading train is reversed to the EastFallback station temporarirly and then released back to head to the west station.
            local westTrainSchedule = testDataBespoke.headingWestTrain.schedule
            table.insert(westTrainSchedule.records, {station = testDataBespoke.stationEastFallback.backer_name, temporary = true})
            testDataBespoke.headingWestTrain.schedule = westTrainSchedule
            testDataBespoke.headingWestTrain.manual_mode = false

            -- East heading train is restarted and should be able to make its journey.
            testDataBespoke.headingEastTrain.manual_mode = false
        elseif #testDataBespoke.trainNamesAlerting == 1 then
            -- One train stopped so the other must be using the tunnel. Send the stopped one to the fallback station behind it to let the tunnel user leave.
            local stoppedTrainName = testDataBespoke.trainNamesAlerting[1]
            local targetStation
            if stoppedTrainName == "headingWestTrain" then
                targetStation = testDataBespoke.stationEastFallback
            elseif stoppedTrainName == "headingEastTrain" then
                targetStation = testDataBespoke.stationWestFallback
            else
                error("unrecognised trainNamesAlerting trainName: " .. tostring(stoppedTrainName))
            end
            local targetTrain = testDataBespoke[stoppedTrainName]
            local trainSchedule = targetTrain.schedule
            table.insert(trainSchedule.records, 1, {station = targetStation.backer_name, temporary = true})
            targetTrain.schedule = trainSchedule
            targetTrain.manual_mode = false
        end
    end
    -- CURRENT KNOWN LIMITATION BEHAVIOUR - END

    -- IDEAL BEHAVIOUR - START
    -- Detect when the stations have a train waiting in them and react when both completed their journey.
    if not testDataBespoke.stationEastReached and testDataBespoke.stationEast.get_stopped_train() ~= nil then
        testDataBespoke.stationEastReached = true
    end
    if not testDataBespoke.stationWestReached and testDataBespoke.stationWest.get_stopped_train() ~= nil then
        testDataBespoke.stationWestReached = true
    end
    if testDataBespoke.stationEastReached and testDataBespoke.stationWestReached then
        TestFunctions.TestCompleted(testName)
        return
    end
    -- IDEAL BEHAVIOUR - END
end

Test.GenerateTestScenarios = function()
    for _, portalTriggered in pairs(PortalTriggered) do
        ---@class Tests_TMI_TestScenario
        local scenario = {
            portalTriggered = portalTriggered
        }
        Test.RunLoopsMax = Test.RunLoopsMax + 1
        table.insert(Test.TestScenarios, scenario)
    end
end

return Test
