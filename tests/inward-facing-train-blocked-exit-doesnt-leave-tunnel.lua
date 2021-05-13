--[[
    A train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel. The entrance signal on the exit portal is blocked in the next rail segment. Long train so only partially left the tunnel before stopping.After the train has fully stopped the blocking wagon is removed so the train can compete its journey.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString =
    "0eNqtWttu4jAU/Bc/QxXb8Y2P2Jd9XFUoBZdGGxKUS7uo4t/XgapU6rT4uH4BBcIcM2fm2D7OK3toJn/o63Zkq1dWb7p2YKs/r2yod23VzJ+Nx4NnK1aPfs8WrK3281Vf1c1LdVyPU9v6Znl5Wx+6fqya9TD1j9XGLw9NeN37AH1asLrd+n9sxU/3CxY+qsfaXyKdL47rdto/+D7c8B5jGEOU3dO4nIOF0IduCL/q2nlQAWmp3IIdwztX6nRafAIS70AzTrscxu6AUMwVZRFiVpcv2a/wX54YwJUJA5RogGUCEEdAig5UOgSkE4AMAjIJQDCJNgEIku0SgCDZvKAjScg2T5C6hHRzkYAE+eYJ6paQcJ4gb4kZT9C3wIwnCFxgxhMULjDjCRIXmPEEjQvIuEjQOIeMi6vGN1W/65Yv1S78+DscdaecNHMx7vo6wL0V5GKeQp7DddeH+9qpaVC4BCNwmGCRYASO56EEI3CYYJFgBI4TnGCEAic4wQgFZjzBCAVmPMEIBWRcJhihgIxLerF3kHApEhZh22/CGBms9lz19ZvROAoqbwQd/G5e6MVHDeuG21HL7FFVRFSVPWoMwzp7VB4R1eSOGpY6t6Pa7FFj1OSyR41QU1lkjxqhppJnjxqhplLkjioi1FRmr00iQk1l9tokYtSUvTaJGDVlr00iRk3ZaxOPUVP22sRj1JS9NvEINanstYlHqEllr008Qk0qe22KEJOSeddqZylt695vLl+Wt0dA3nzg9okibz1wP0eRNx64waTI2w7c8VLkTccXLTjylgP3BDV5w4Gbn5q83VCQZ321TdNtun031s/+axAt7kq0d78L8pkbyMN8f99t/vpx+Tj5Zm6nwbDk3bfCDU2y/DVMrybLX+P0kuWvcXoNra2i3Td5udlV0WSTaCwmskk0zKohm8TArBqySQzMqhG0bBj9k2wYsjcM1JAhe8PgXj/ZGwZnVdNYtPJHLJInEIs1RPaGxRoie8PiAxOyNyzMqiU2bl2BsxGTC0vu2lqoIEt2hoM5tWRnOJhTq0iTpzNfUkiYOi15inFYSGSDOCwkskFw39OSDfJFJ9YVdCB8pMjpQJBqF3lUPS/qziiftwHXc+vf3YTPrZ2kDxdm1JV0IJhSR545zscZ9+Hvbp78dmreniC4mmu+DktWqz7cc3mcAZzrf+LsfoY+P+ew+vBYRNhj+X443ygsL40TRhqjeFGeTv8BSx8SWQ=="

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyBlockingWagon", Test.DestroyBlockingWagon)
end

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the trains/wagons
    local blockingWagon, movingTrain
    local wagons = Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "cargo-wagon")
    for _, wagon in pairs(wagons) do
        if #wagon.train.carriages == 1 then
            blockingWagon = wagon
        else
            movingTrain = wagon.train
        end
    end

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.blockingWagon = blockingWagon
    testData.movingTrain = movingTrain
    testData.blockingWagonReached = false
    testData.northStationReached = false
    testData.southStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(movingTrain)
    testData.trainStopNorth = trainStopNorth
    testData.trainStopSouth = trainStopSouth

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 700, testName, "DestroyBlockingWagon", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsOnceEvent(testName, "DestroyBlockingWagon", testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.DestroyBlockingWagon = function(event)
    -- The main train should have completed its tunnel trip north and have completely stopped at the blocking wagon at this point.
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)

    -- The main train will have its lead loco around 30 tiles below the blocking wagon if stopped at the signal.
    local inspectionArea = {left_top = {x = testData.blockingWagon.position.x, y = testData.blockingWagon.position.y + 25}, right_bottom = {x = testData.blockingWagon.position.x, y = testData.blockingWagon.position.y + 35}}
    local locosInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {area = inspectionArea, name = "locomotive", limit = 1}
    if #locosInInspectionArea ~= 1 then
        TestFunctions.TestFailed(testName, "1 loco not found around expected point")
        return
    end
    local mainTrain = locosInInspectionArea[1].train

    if mainTrain.state ~= defines.train_state.wait_signal then
        TestFunctions.TestFailed(testName, "train not stopped at a signal (for blocking wagon) as expected")
        return
    end

    local northestCarriage, northestCarriageYPos = nil, 100000
    for _, carriage in pairs(mainTrain.carriages) do
        if carriage.position.y < northestCarriageYPos then
            northestCarriage = carriage
            northestCarriageYPos = carriage.position.y
        end
    end
    if Utils.GetDistanceSingleAxis(northestCarriage.position, testData.blockingWagon.position, "y") > 25 then
        TestFunctions.TestFailed(testName, "train not stopped at expected position for blocking wagon signal")
        return
    end

    game.print("train stopped at blocking wagon signal")
    testData.blockingWagonReached = true

    testData.blockingWagon.destroy()
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local northTrain, southTrain = testData.trainStopNorth.get_stopped_train(), testData.trainStopSouth.get_stopped_train()
    if northTrain ~= nil and not testData.northStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(northTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached north station, but with train differences")
            return
        end
        game.print("train reached north station")
        testData.northStationReached = true
    end
    if southTrain ~= nil and not testData.southStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(southTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached south station, but with train differences")
            return
        end
        game.print("train reached south station")
        testData.southStationReached = true
    end
    if testData.blockingWagonReached and testData.northStationReached and testData.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
