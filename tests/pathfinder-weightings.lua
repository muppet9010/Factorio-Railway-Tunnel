--[[
    Has 5 loco's queued to reach a target with a variety of weighted routes and a tunnel for them to choose between.
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

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_PW_TestScenarioBespokeData
    local testDataBespoke = {
        stationEnd = stationEnd ---@type LuaEntity
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

    -- Check that enough trains got within 40 tiles (west) of the end station. Should be 4 of the 5 make it with current path finder weightings.
    if stationEndTrain ~= nil then
        local inspectionArea = {left_top = {x = testDataBespoke.stationEnd.position.x - 40, y = testDataBespoke.stationEnd.position.y - 2}, right_bottom = {x = testDataBespoke.stationEnd.position.x + 2, y = testDataBespoke.stationEnd.position.y + 2}}
        local locosNearBy = TestFunctions.GetTestSurface().count_entities_filtered {area = inspectionArea, name = "locomotive"}
        if locosNearBy == 4 then
            TestFunctions.TestCompleted(testName)
            return
        end
    end
end

return Test
