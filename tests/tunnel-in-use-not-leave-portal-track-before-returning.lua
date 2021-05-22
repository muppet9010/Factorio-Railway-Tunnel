--[[
    The train moves through the tunnel, but doesn't clear the portal track at one end before returning.
]]
local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNqtWduO2jAU/Bc/J1V8Dea939CHaoWywctGDU6UC1uE+PfaC1qQSMvY9Qshxsw58cwc2/GJvLaz6YfGTmR9Ik3d2ZGsf57I2Oxs1fq26dgbsibNZPYkI7ba+7uhatqP6riZZmtNm18um74bpqrdjPPwVtUm71v3uTcO+pyRxm7Nb7Km55eMuKZmaswl0ufNcWPn/asZXIevGJMLYvNx6noXt+9G95fO+owcTK5kRo7uqh30thlMfflRZWScqst38sOMPvRDCBbxGNuFHNg1h/Ihh0M1NNcs6EIC/EkCo9n5YXuaAY2MLxLF55HxZaL4seOvEsUvI+OXieLryPirVPqLFaBOlUCsAmmRKoNYDVKaKoNYFVKWKoNYHdJUhZDFCpGmKoUsWompimH0bERTlUMWrcRUBZFFKzFVSeTRSkxVE3msElmqmshjlchS1UQeq0SWqibyWCUynmZ1qpZJYM8TuJXE0S/Bd+9T7jNZWoQvDzNbQpU4qsRRFY7KcdQSR6U46gpGlRpH1TgqzhYvcFScLU5xVJwtznBUnC3OUVQdAApbSwc8P+wsHUAVbCwdoCrYVxo3AIdtRYsApjSOilMlChwV50pQHBUnSzAcFWdLwLaiFGdLCBw1gC2JowawpXDUALZKHDWALdxbLIAt3FsMZ0vevNV2dbfvpuZgliDvBrUbGodyXQsV30rHon/NOfq+Q1f/MlP+NpvWS/y8FBI3HsMFInHjMVwgEjcewwUib8arq2HX5R/VzvVdeE8j/j3q9uCausF1sXPbLkXCzchxKUrcjDxAirgZeYAucDPyAF1okEFB/5NBhU9+HFegwj0ocF0o3IMC14XiWInyZfcvQ80CS5TCZ0aBS1HhZhS4FBVuRhEgENyMAdsDhZsxYCuj8JkxYNtV4sYL2CKWuPECtrMlg47/vqiSD283bsd/3yt//Pfimup3s53b63njzXr+3i0bFL/rczn8fDxCfID1wJ9nouu7I9SMHMwwXlJZOe1rVvKylLQQ5/Mf2aTj2A=="

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local stationWest, stationEast
    for _, stationEntity in pairs(Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "train-stop", true, false)) do
        if stationEntity.backer_name == "West" then
            stationWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            stationEast = stationEntity
        end
    end

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.stationWestReached = false
    testData.stationEastReached = false
    testData.trainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.stationWest = stationWest
    testData.stationEast = stationEast

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local stationWestTrain, stationEastTrain = testData.stationWest.get_stopped_train(), testData.stationEast.get_stopped_train()

    if stationWestTrain ~= nil and not testData.stationWestReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationWestTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at west station has differences after tunnel use")
            return
        end
        game.print("train reached west station")
        testData.stationWestReached = true
    end
    if stationEastTrain ~= nil and not testData.stationEastReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(stationEastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.trainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train at east station has differences after tunnel use")
            return
        end
        game.print("train reached east station")
        testData.stationEastReached = true
    end

    if testData.stationWestReached and testData.stationEastReached then
        TestFunctions.TestCompleted(testName)
        return
    end
end

return Test
