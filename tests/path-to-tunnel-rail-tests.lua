--[[
    A series of tests that schedules a train to a temporary stop thats part to the tunnel and then possibly on to another stop. Check that the train behaves as desired for both pulling to end of tunnel (or not) and not looping through the tunnel infinitely. Does combinations for:
        targetTunnelRail: entrancePortalMiddle, entrancePortalBlockingEnd, undergroundSegment, exitPortalBlockingEnd, exitPortalMiddle
        nextStop: none, station, rail
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")
local Common = require("scripts/common")
local TunnelRailEntityNames = Common.TunnelRailEntityNames

---@class Tests_PTTRT_TargetTunnelRail
local TargetTunnelRail = {
    entrancePortalMiddle = "entrancePortalMiddle", -- An entrance portal track after the entry detector, but before the transition detector.
    entrancePortalBlockingEnd = "entrancePortalBlockingEnd", -- An entrance portal track after the transition detector.
    undergroundSegment = "undergroundSegment", -- An underground tunnel track.
    exitPortalBlockingEnd = "exitPortalBlockingEnd", -- An exit portal track on the blocking side (inside/before) of the transition detector.
    exitPortalMiddle = "exitPortalMiddle" -- An exit portal track before the entry detector, but after the transition detector.
}
---@class Tests_PTTRT_NextStopTypes
local NextStopTypes = {
    none = "none",
    station = "station",
    rail = "rail"
}
---@class Tests_PTTRT_ExpectedTunnelStopHandling
local ExpectedTunnelStopHandling = {
    targetTunnelRail = "targetTunnelRail",
    endOfTunnel = "endOfTunnel"
}
---@class Tests_PTTRT_FinalTrainStates
local FinalTrainStates = {
    nextStopReached = "nextStopReached",
    targetRailReached = "targetRailReached"
}

local DoMinimalTests = true -- The minimal test to prove the concept. Just goes to a tunnel segment, then to end station, as this triggered the origional issue.

local DoSpecificTests = false -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificTargetTunnelRailFilter = {} -- Pass in array of TargetTunnelRail keys to do just those. Leave as nil or empty table for all train states. Only used when DoSpecificTests is TRUE.
local SpecificNextStopFilter = {} -- Pass in array of NextStopTypes keys to do just those. Leave as nil or empty table for all tunnel usage types. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

Test.RunTime = 1000
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_PTTRT_TestScenario[]
Test.TestScenarios = {} -- Populated when script loaded.
--[[
    {
        targetTunnelRail = the TargetTunnelRail of this test.
        nextStop = the NextStopTypes of this test.
        expectedTunnelStopHandling = the ExpectedTunnelStopHandling calculated for this test.
        expectedFinalTrainState = the FinalTrainStates calculated for this test. Either nextStopReached or targetRailReached based on if there is a nextStop set for this test.
    }
]]
---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
end

local blueprintString = "0eNqtnN1y2kgUhN9F18il+df4Pk+xlXJhULyqgEQJ4Y3LxbtHGNsYdsDdOroJcVL0DPN1Hw2jI79mj6tdtenqps/uX7N60Tbb7P6f12xbPzXz1eHf+pdNld1ndV+ts1n2OF/83m2Gn7t5vfpv/vLQ75qmWuXHl4dN2/Xz1cN21/2aL6p8sxr+XFeD+H6W1c2y+pPdq/3sunwzX1fv4l/eovc/Z9mgUvd1dZze2w8vD81u/Vh1g+bnOxe77rla5m8Cs2zTbof3tM1hoEEnN+UsexletfOD+rLuqsXxv/1hUhei+lN02w96T//2V2XNh2w4l9UJWYPLKkLWwrI6ErIOlw2ErMdlHSEbcFkGWYnLMsgiLKsYZKrAdRlmSuG6DDSFB00x1BSeNMVgU3jUKGx41ChqeNQoaHjUKGZ41ChkcNQYVQ0HjVkCDceM4aXhkDHm0nDEmCRoOGBUbjUcMKrMaDhgVFXUcMCoIq7hgFHXHA0HjLpCGjhh1PXcwBGjdh8Gzhi1VzJwyKidnYFTRu1DDZwybtcMp8xQyOCUGQoZnDJDIYNTZqmvDnDKLIPMwimzDDILp8wyyCycMssgs3DKHIUMTpmjkMEpcxQyOGWOQganzFHI4JR5BpmDU+YZZA5OmWeQOThlnkHm4JR56pQCTlmgkMEpCxQyOGWBQganLFDI4JQFClnEzuxKe+XIzqSOlfCjj9MV0pzrhpQuHLIyXJFVKVkNnlvaz0UoAFWDqcbiJJqSsezkrD6fnE2pOnJyl6IuJerPTo7z99PlFPS7j0TZ4s4BhgqYchluCCchlbxTTQSWIqJLYT5nbMrLGacyEAr2kN14QFWRZeBSNHkMrOm4Xq5tygzBgGaIN5Y2BS2conaYbpNv+3aTOvf7KLDmosAO/t/28+Pfsx/NMksN4lBn2NP0/eX0k8t9Hr8vd4XebwdVw4xu3Icw7n+f5nne1fPr6QnhmxG31dPhtlP+gf/WjYURw5cTDG/GDx8nGF6NHr4s5MOr8exLNcHwYfzweoLhx1uvNBMMP956pZ1geIH1nHx4gfO8fHSB8SaoeQLfTVDyBLaboOKNd12UFzzB4PJyN37do7zYjbdclJe68WmL8kI3vtBEeZkTFNkoL3OCK0wMYzaTggt6vFrZds2y6p66dngFPvPVHZX+fgpxoimY0VNQRTFm3XUQjDhBZVOC4eW1zUjWW17djBMML69vRsJeXuFMFAwvL3FWYj35Vs5KrCffy1mJ9eSbOSuwnpLv5qzAekpe9ZzAemqCHZ3Aekpe9ZzAekpe9ZzEevKq5yTWk1c9L7GevOp5ifXkVc9LrCevel5gPS2vel5gPa3G7C6DALfW/GE9dNqt8KbHLwf2kDDeWBwCJUy0FjtKGG8uvs4yKYy3FwdFCeP33TwHD+/m9xQ8vAcy9xQ8vAsy9xQ8vA8y9xQ8vBMydxQ8vBcydxw8PHmOg0e09XPw8OQ5Dh5xx5uDhyfPUvAs0U1CwcM7I3NLwcN7I3NLwbPEU2sUPLw/MjccPDx5hoPn+ecCMWG+fwvT5Ru4MF04dyXlNbxRsqTWF++ULClDuBHdJpAunLmS4oY3S0aOG5y4yHGDAxc5bnDeIscNzlvkuOEPsRUUOLxr8u3UmhBWuDCFzmtcmGLnDS5MwfPEM20cPPypNsXBw59rUxy8U+5W7aJdt339XCVUdXHn/HmXVtvVg9r71/7i7vBl9fCLA7aHt3Tt4nfV57921epAZ58cGn/6TXG+wbOpKN8EPJua8k3As6kp33xpvryNN3yHV7N4A55eTVk24OnVlG8Cnl7N+QZPr+F8E0a0kZrLgzWflC75I7uE8s+jawaV0+82mWXPVbc9fqpy2GlHHWx0Njiz3/8Fcy3KpQ=="

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.targetTunnelRail .. "     Next stop: " .. testScenario.nextStop .. "     Expected result: " .. testScenario.expectedTunnelStopHandling .. " - " .. testScenario.expectedFinalTrainState
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestMangaerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 60, y = 0}, testName)

    -- Get the stations from the blueprint
    local stationEnd
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        end
    end

    -- Get the portals.
    local entrancePortalEntryPortalEnd, entrancePortalEntryPortalEndXPos, exitPortalEntryPortalEnd, exitPortalEntryPortalEndXPos = nil, -100000, nil, 100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x > entrancePortalEntryPortalEndXPos then
            entrancePortalEntryPortalEnd = portalEntity
            entrancePortalEntryPortalEndXPos = portalEntity.position.x
        end
        if portalEntity.position.x < exitPortalEntryPortalEndXPos then
            exitPortalEntryPortalEnd = portalEntity
            exitPortalEntryPortalEndXPos = portalEntity.position.x
        end
    end

    -- Get the first tunnel segment as we just need 1.
    local undergroundSegment = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = placedEntitiesByGroup["locomotive"][1].train

    -- Create the train schedule for this specific test.
    local trainSchedule = {
        current = 1,
        records = {}
    }
    local targetTunnelRailEntities, targetTunnelRailEntity
    if testScenario.targetTunnelRail == TargetTunnelRail.entrancePortalMiddle then
        targetTunnelRailEntities =
            entrancePortalEntryPortalEnd.surface.find_entities_filtered {
            name = TunnelRailEntityNames,
            position = Utils.ApplyOffsetToPosition(entrancePortalEntryPortalEnd.position, {x = -10, y = 0})
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.entrancePortalBlockingEnd then
        targetTunnelRailEntities =
            entrancePortalEntryPortalEnd.surface.find_entities_filtered {
            name = TunnelRailEntityNames,
            position = Utils.ApplyOffsetToPosition(entrancePortalEntryPortalEnd.position, {x = -46, y = 0})
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.undergroundSegment then
        targetTunnelRailEntities =
            undergroundSegment.surface.find_entities_filtered {
            name = TunnelRailEntityNames,
            position = undergroundSegment.position
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.exitPortalBlockingEnd then
        targetTunnelRailEntities =
            entrancePortalEntryPortalEnd.surface.find_entities_filtered {
            name = TunnelRailEntityNames,
            position = Utils.ApplyOffsetToPosition(exitPortalEntryPortalEnd.position, {x = 46, y = 0})
        }
    elseif testScenario.targetTunnelRail == TargetTunnelRail.exitPortalMiddle then
        targetTunnelRailEntities =
            exitPortalEntryPortalEnd.surface.find_entities_filtered {
            name = TunnelRailEntityNames,
            position = Utils.ApplyOffsetToPosition(entrancePortalEntryPortalEnd.position, {x = -10, y = 0})
        }
    else
        error("Unsupported testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    end
    if targetTunnelRailEntities == nil or #targetTunnelRailEntities == 0 then
        error("No targetTunnelRailEntity found for testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    elseif #targetTunnelRailEntities > 1 then
        error("Too many targetTunnelRailEntity found for testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    else
        targetTunnelRailEntity = targetTunnelRailEntities[1]
        table.insert(
            trainSchedule.records,
            {
                rail = targetTunnelRailEntity,
                wait_conditions = {
                    {
                        type = "time",
                        ticks = 60,
                        compare_type = "or"
                    }
                },
                temporary = true
            }
        )
    end
    if testScenario.nextStop == NextStopTypes.rail then
        table.insert(
            trainSchedule.records,
            {
                rail = stationEnd.connected_rail,
                temporary = true
            }
        )
    elseif testScenario.nextStop == NextStopTypes.station then
        table.insert(
            trainSchedule.records,
            {
                station = stationEnd.backer_name
            }
        )
    end
    -- If nextStop is type of none then there is no second schedule record to add.
    train.schedule = trainSchedule

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_PTTRT_TestScenarioBespokeData
    local testDataBespoke = {
        stationEnd = stationEnd, ---@type LuaEntity
        entrancePortalEntryPortalEnd = entrancePortalEntryPortalEnd, ---@type LuaEntity
        exitPortalEntryPortalEnd = exitPortalEntryPortalEnd, ---@type LuaEntity
        undergroundSegment = undergroundSegment, ---@type LuaEntity
        targetTunnelRailEntity = targetTunnelRailEntity, ---@type LuaEntity
        train = train, ---@type LuaTrain
        tunnelRailReached = false, ---@type boolean
        nextStopReached = false ---@type boolean
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
    local testScenario = testData.testScenario ---@type Tests_PTTRT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PTTRT_TestScenarioBespokeData

    local train = testDataBespoke.train
    if train == nil or not train.valid then
        train = TestFunctions.GetTrainInArea({left_top = testDataBespoke.stationEnd.position, right_bottom = testDataBespoke.entrancePortalEntryPortalEnd.position})
    end
    if train == nil then
        -- Just ignore the train as we can't find it where expected right now.
        return
    end

    if not testDataBespoke.tunnelRailReached then
        -- Train hasn't reached the tunnelRail yet so keep on checking.
        if train.state == defines.train_state.wait_station then
            -- Train has stopped at a schedule record.
            if testScenario.expectedTunnelStopHandling == ExpectedTunnelStopHandling.endOfTunnel then
                -- Check its at the end of the exit portal. The train is re-scheduled to this from its random unreachable rail.
                local atrainAtExitTunnelEntryRail = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testDataBespoke.exitPortalEntryPortalEnd.position, {x = 1, y = 0}))
                if atrainAtExitTunnelEntryRail ~= nil then
                    game.print("train pulled to front of tunnel as expected for undergroud rail")
                    testDataBespoke.tunnelRailReached = true
                end
            elseif testScenario.expectedTunnelStopHandling == ExpectedTunnelStopHandling.targetTunnelRail then
                -- Check its at the expected rail.
                local atrainAtExitTunnelEntryRail = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testDataBespoke.targetTunnelRailEntity.position, {x = 2, y = 0}))
                if atrainAtExitTunnelEntryRail ~= nil then
                    game.print("train reached expected ground tunnel rail")
                    testDataBespoke.tunnelRailReached = true
                end
            end
        end
        return -- End the checking this tick regardless of the result.
    end

    if testScenario.expectedFinalTrainState == FinalTrainStates.targetRailReached then
        TestFunctions.TestCompleted(testName)
        return
    elseif testScenario.expectedFinalTrainState == FinalTrainStates.nextStopReached then
        -- Need to check for when the train reaches the next stop.
        if train.state == defines.train_state.wait_station then
            -- Train has stopped at a schedule record.
            local atrainAtNextStop = TestFunctions.GetTrainAtPosition(Utils.ApplyOffsetToPosition(testDataBespoke.stationEnd.position, {x = 2, y = 2}))
            if atrainAtNextStop ~= nil then
                -- Train has stopped just before the target station/rail, rather than some random place.
                TestFunctions.TestCompleted(testName)
                return
            end
        end
    else
        error("Unsupported testScenario.expectedFinalTrainState: " .. testScenario.expectedFinalTrainState)
    end
end

---@param testName string
Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local targetTunnelRailsToTest  ---@type Tests_PTTRT_TargetTunnelRail
    local nextStopsToTest  ---@type  Tests_PTTRT_NextStopTypes
    if DoMinimalTests then
        targetTunnelRailsToTest = {TargetTunnelRail.undergroundSegment}
        nextStopsToTest = {NextStopTypes.station}
    elseif DoSpecificTests then
        -- Adhock testing option.
        targetTunnelRailsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(TargetTunnelRail, SpecificTargetTunnelRailFilter)
        nextStopsToTest = TestFunctions.ApplySpecificFilterToListByKeyName(NextStopTypes, SpecificNextStopFilter)
    else
        -- Do whole test suite.
        targetTunnelRailsToTest = TargetTunnelRail
        nextStopsToTest = NextStopTypes
    end

    for _, targetTunnelRail in pairs(targetTunnelRailsToTest) do
        for _, nextStop in pairs(nextStopsToTest) do
            ---@class Tests_PTTRT_TestScenario
            local scenario = {
                targetTunnelRail = targetTunnelRail,
                nextStop = nextStop
            }
            scenario.expectedTunnelStopHandling, scenario.expectedFinalTrainState = Test.CalculateExpectedResults(scenario)
            Test.RunLoopsMax = Test.RunLoopsMax + 1
            table.insert(Test.TestScenarios, scenario)
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

---@param testScenario table
Test.CalculateExpectedResults = function(testScenario)
    local expectedTunnelStopHandling, expectedFinalTrainState

    if testScenario.targetTunnelRail == TargetTunnelRail.entrancePortalMiddle or testScenario.targetTunnelRail == TargetTunnelRail.exitPortalMiddle then
        expectedTunnelStopHandling = ExpectedTunnelStopHandling.targetTunnelRail
    elseif testScenario.targetTunnelRail == TargetTunnelRail.entrancePortalBlockingEnd or testScenario.targetTunnelRail == TargetTunnelRail.undergroundSegment or testScenario.targetTunnelRail == TargetTunnelRail.exitPortalBlockingEnd then
        expectedTunnelStopHandling = ExpectedTunnelStopHandling.endOfTunnel
    else
        error("unsupported testScenario.targetTunnelRail: " .. testScenario.targetTunnelRail)
    end

    if testScenario.nextStop == NextStopTypes.none then
        expectedFinalTrainState = FinalTrainStates.targetRailReached
    elseif testScenario.nextStop == NextStopTypes.station then
        expectedFinalTrainState = FinalTrainStates.nextStopReached
    elseif testScenario.nextStop == NextStopTypes.rail then
        expectedFinalTrainState = FinalTrainStates.nextStopReached
    else
        error("Unsupported testScenario.nextStop: " .. testScenario.nextStop)
    end

    return expectedTunnelStopHandling, expectedFinalTrainState
end

return Test
