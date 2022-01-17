--[[
    2 facing trains set to try and use the tunnel on the exact same tick. Each train paths just to a station on the other side of the tunnel.
    Confirms that one gets the tunnel and the other has to wait.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Common = require("scripts/common")

-- How the train triggers the portal first. Done by setting train's starting speed.
local PortalTriggered = {
    startApproaching = Common.TunnelUsageAction.startApproaching,
    onPortalTrack = Common.TunnelUsageAction.onPortalTrack
}
Test.RunLoopsMax = 0 -- Populated when script loaded.
Test.TestScenarios = {} -- Populated when script loaded.

Test.RunTime = 3600

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios() -- Call here so its always populated.
end

local blueprintString = "0eNq1Wsty6jgQ/RevIaVWSy2J/f2GWUylUg54iGvApmyTuakU/34lTF4gkpbMbEJA1jlyP47aLb8Wj5t9tevqZigWr0W9bJu+WPz9WvT1uik34bfhZVcVi6Ieqm0xK5pyG751Zb0pDrOiblbV72IBhxlryn/ly8Owb5pqM9+13VBuHvpqva2aYd4Pfnz9NHwClYf7WeHH6qGuxkUdv7w8NPvtY9V51nfsMLnxGO3O8+3a3k9pm7ASDzPXela8hE8Pvaq7ajkO0qzoh3L8v/ir6gP1BYV8p3hb4Px469dZ8CuLjIAiHxTZoIoPCmxQzQZVjg1KfFDDBjV8UL6j7Dvoct89V6urkGKElF8hMQLpeJBXECmCCIJ76wl3DsAG5fsI2NmUEE3AzqaEuAd2NiVkKLCzKUFLgL4I7Hz5dFTCUYovIxXp7oQNd/rnaAXDzABUR9SzcDUxSGZSxRGjJnApJvjGAhDbAARrk3nzGJwt9/Me86u8ssdAmgvt6QbE+fpj5pYyD/zCODHLS/xhd6+aVYREjpKBF/vxc9nV5Te+UKnFRIQbM7n1Dbghk5umc4PL5DY34M71t70Bt45xy5+53Q24MY8bxQ24IZMbslLaZLLJa2x7/wzQrbvWf17c7nHHeFh2bd/XzTqmYpmrwZzVxIyfya9uw59Lr/8PZ+T6gnLiMFNocLrIQaa243SNg8wtDadLXFxdf6ZW0xUOMiVHwXRql0ktJ1PLzNxWOJ06M8yUysnk3BpR6aSHgau1tI5hUxY2q5RWHxK0aZftth3q5yrWvJHvdmm72oOcbCHujGdbtpu2C5d24Rch0EnQZK12SFaTJGeRlNTGQiho1+Eqq4zQ1qIkpRWQ1M6Qv9QPP4Zh5cckagRLJAySsOiswsBWMkhCO2+otv1xUe3y32qY/7OvNsF5MSvY1H4bpzPmUvttnM6YSO23cUAhtd/GAZW8yFL6WmTJi8gygEZqLfyf4HTrSJ1iYv398CmklBPgCJWRSISIQpwiclJIyVhIaUxtN3JsqlLbjRzQhG4rP04Tuq38OOV3W5Efp/zcR76j+LmPbEcRP/eR7Sji5z6yHUXsjmsCJjuhEm6enU8JXmKnEz+ciJ1N/LgndjLxE5QsS/OvS/5lMeGrgmOh4GXbGB20+1QlHBUfg+ArB0AEoKwwIK0TH1WEF3OSxs8hr+zOGWEEThd8HRN8Yqc8X0VN6hkLBzP1iIWDydvrrxeRl1u9Cn7TIEQoDK3whaJ58+zo+XEvB7JKBrc5o0i4j83enupHYyVp9ADaTS8eo443mHi8xDGoSjxd4mDqxMMlDiYlni1xME3e0YE6f96JnVoam/UsFcG+nxX98qla7TentwQ+Ij9898mj5adrxrcbzg5l7sMKv87zEmq+mTe+MHAf2I+vOSw+vUjhH1Krrh/takEZ5zPIaWU0Hg5/AOsp8Xc="

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
    local stationWest, stationEast
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
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

    -- Train speed is based on how we want to trigger the portal.
    local trainTargetSpeed
    if testScenario.portalTriggered == Common.TunnelUsageAction.startApproaching then
        trainTargetSpeed = 0.75
    elseif testScenario.portalTriggered == Common.TunnelUsageAction.onPortalTrack then
        trainTargetSpeed = 0
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
    testData.bespoke = {
        stationEast = stationEast,
        stationWest = stationWest,
        stationEastReached = false,
        stationWestReached = false,
        headingWestTrain = headingWestTrain,
        headingEastTrain = headingEastTrain
    }

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
    local testDataBespoke = testData.bespoke

    -- Detect when the stations have a train waiting in them.
    if not testDataBespoke.stationEastReached and testDataBespoke.stationEast.get_stopped_train() ~= nil then
        testDataBespoke.stationEastReached = true
    end
    if not testDataBespoke.stationWestReached and testDataBespoke.stationWest.get_stopped_train() ~= nil then
        testDataBespoke.stationWestReached = true
    end

    if testDataBespoke.stationEastReached and testDataBespoke.stationWestReached then
        TestFunctions.TestCompleted(testName)
    end
end

Test.GenerateTestScenarios = function()
    for _, portalTriggered in pairs(PortalTriggered) do
        local scenario = {
            portalTriggered = portalTriggered
        }
        Test.RunLoopsMax = Test.RunLoopsMax + 1
        table.insert(Test.TestScenarios, scenario)
    end
end

return Test
