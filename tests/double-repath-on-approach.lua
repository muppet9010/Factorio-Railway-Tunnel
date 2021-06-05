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

local blueprintString = "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"

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 50, y = 60}, testName)

    -- Get the stations placed by name.
    local stationSouths, stationSouthEndViaTunnel, stationSouthEndNotTunnel, stationNorth = {}
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
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
