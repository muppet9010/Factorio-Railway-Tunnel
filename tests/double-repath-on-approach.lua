--[[
    The train approaches the tunnel and when it passes and triggers the first circuit connected signal to red, the active target station changes. The station after the tunnel is turned off and the station on the siding below is activated, both with the same name.
    Then when the train passes in to (triggers) the second circuit connected signal the stations switch back, routing the train back through the tunnel.
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
    local stationSouths, stationSouthEndViaTunnel, stationSouthEndNotTunnel, stationNorth = {}
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "South" then
            table.insert(stationSouths, stationEntity)
        elseif stationEntity.backer_name == "North" then
            stationNorth = stationEntity
        end
    end
    if stationSouths[1].position.x < stationSouths[2].position.x then
        stationSouthEndViaTunnel = stationSouths[1]
        stationSouthEndNotTunnel = stationSouths[2]
    else
        stationSouthEndViaTunnel = stationSouths[2]
        stationSouthEndNotTunnel = stationSouths[1]
    end

    local repathTrain = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationSouthReached = false
    testData.stationNorthReached = false
    testData.repathTrain = repathTrain
    testData.repathTrainSnapshot = TestFunctions.GetSnapshotOfTrain(repathTrain)
    testData.stationSouthEndViaTunnel = stationSouthEndViaTunnel
    testData.stationSouthEndNotTunnel = stationSouthEndNotTunnel
    testData.stationNorth = stationNorth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationSouthEndViaTunnelTrain, stationSouthEndNotTunnelTrain, stationNorthTrain = testData.stationSouthEndViaTunnel.get_stopped_train(), testData.stationSouthEndNotTunnel.get_stopped_train(), testData.stationNorth.get_stopped_train()

    if stationSouthEndViaTunnelTrain ~= nil and not testData.stationSouthReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationSouthEndViaTunnelTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.repathTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at south station has differences")
            return
        end
        game.print("train reached tunnel usage south station")
        testData.stationSouthReached = true
    end
    if stationSouthEndNotTunnelTrain ~= nil then
        -- The train should never reach this specific station as it should use the tunnel.
        TestFunctions.TestFailed(testName, "train didn't use tunnel and reached wrong south station")
        return
    end
    if stationNorthTrain ~= nil and not testData.stationNorthReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationNorthTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.repathTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at north station has differences")
            return
        end
        game.print("train reached north station")
        testData.stationNorthReached = true
    end

    if testData.stationSouthReached and testData.stationNorthReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
