--[[
    Has 5 loco's queued to reach a target with a variety of weighted routes and a tunnel for them to choose between.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "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"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationEnd
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "End" then
            stationEnd = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationEnd = stationEnd

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationEndTrain = testData.stationEnd.get_stopped_train()

    -- Check that enough trains got within 40 tiles (west) of the end station. Should be 3 of the 5 make it.
    if stationEndTrain ~= nil then
        local inspectionArea = {left_top = {x = testData.stationEnd.position.x - 40, y = testData.stationEnd.position.y - 2}, right_bottom = {x = testData.stationEnd.position.x + 2, y = testData.stationEnd.position.y + 2}}
        local locosNearBy = TestFunctions.GetTestSurface().count_entities_filtered {area = inspectionArea, name = "locomotive"}
        if locosNearBy >= 3 then
            TestFunctions.TestCompleted(testName)
            return
        end
    end
end

return Test
