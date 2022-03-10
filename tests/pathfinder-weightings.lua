--[[
    Has 5 loco's queued to reach a target with a variety of weighted routes and a tunnel for them to choose between.
    The exact number of trains that choose the top line with the blocking moving train seems partially dependant upon exactly the timing of trains through the tunnel and the distances involved. Really as long as no trains go to the other blocked rail paths all is fine.
]]
local Test = {}
local TestFunctions = require("scripts.test-functions")

Test.RunTime = 1800

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "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"

---@param testName string
Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationEnd
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        end
    end

    -- Get the left most portal end.
    local leftPortalEnd, leftPortalEndXPos = nil, 100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x < leftPortalEndXPos then
            leftPortalEnd = portalEntity
            leftPortalEndXPos = portalEntity.position.x
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_PW_TestScenarioBespokeData
    local testDataBespoke = {
        stationEnd = stationEnd, ---@type LuaEntity
        leftPortalEnd = leftPortalEnd ---@type LuaEntity
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
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke ---@type Tests_PW_TestScenarioBespokeData

    local stationEndTrain = testDataBespoke.stationEnd.get_stopped_train()

    -- Check that no trains have stopped in either bad path rail tracks.
    local badInspectionArea = {left_top = {x = testDataBespoke.leftPortalEnd.position.x - 40, y = testDataBespoke.leftPortalEnd.position.y - 15}, right_bottom = {x = testDataBespoke.leftPortalEnd.position.x, y = testDataBespoke.leftPortalEnd.position.y - 6}}
    local badLocosfound = TestFunctions.GetTestSurface().count_entities_filtered {area = badInspectionArea, name = "locomotive"}
    if badLocosfound > 0 then
        TestFunctions.TestFailed(testName, "Train used a bad middle path.")
        return
    end

    -- Check that enough trains got within 40 tiles (west) of the end station. Should be 3 or more of the 5 make it with current path finder weightings.
    if stationEndTrain ~= nil then
        local inspectionArea = {left_top = {x = testDataBespoke.stationEnd.position.x - 40, y = testDataBespoke.stationEnd.position.y - 2}, right_bottom = {x = testDataBespoke.stationEnd.position.x + 2, y = testDataBespoke.stationEnd.position.y + 2}}
        local locosNearBy = TestFunctions.GetTestSurface().count_entities_filtered {area = inspectionArea, name = "locomotive"}
        if locosNearBy == 3 then
            TestFunctions.TestCompleted(testName)
            return
        end
    end
end

return Test
