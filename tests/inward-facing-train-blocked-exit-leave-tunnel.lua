--[[
    A train that has its locomotive facing inwards, so can't path on its own when it emerges from the tunnel. The entrance signal on the exit portal is blocked in the next rail segment. Short train so fully leaves the tunnel before stopping. After the train has fully stopped the blocking wagon is removed so the train can compete its journey.
]]
local Utils = require("utility/utils")
local TestFunctions = require("scripts/test-functions")
local Test = {}

Test.RunTime = 1800

local blueprintString = "0eNqtW9tu4kgQ/Zd+hsjVVzcfMS/7uIoiB3qINcZGvmQ2ivLv2w7sBO1UZ6qUegEZzDmm6vSxCx9e1WO3pPPY9rPavap2P/ST2v39qqb22Dfd+tr8ck5qp9o5ndRGPTb7H8s5b49N2/1sXh7mpe9Tt708PZyHcW66h2kZvzf7tD13+fGUMvjbRrX9If2jdvB2v1H5pXZu04XrfePloV9Oj2nMO2xU35xWzmnOLMenebuSZfLzMOVPDf16WBnJuo16UbttjG9vm99g9C+YFaXfTvNwRjDCL4xN5msub6lv+Xs8KQTVsA8uYAdn2TAOg3FsGIPBeDYMYDCBC1OjjavZMGiJIxsGLTFUbBy0xsCWdY0WGTQXJ6BVBraSA1pmYEs54HVmazngdWaLOeB1ZqvZ43Vmy9njdWbr2aN11mw9e7TO+kPP+2Y8DtufzTF/tIji4p2LJvd+o4axzWBXq63WE8Nz3h7GvFu/dB1Gxha9R5uq2aJ3+LmFLXqHNlWzRe/wprJF7/CmskXv8DqzRW/xOrNFb9E6G7boLVpnwzZxi9bZfOj5f9dR1wuo1B/KmGa9Vnluxva6hABjMH9gmNJxvTDb/vc9PqFzBDorR2cIdE6ODgh0XoxOU3oX5OgCga6Wo6NIJcrREaRiKzk6glQsiNEBQSpWy9ERpGLlXAUIUrFyrgIUqci5ClCkIucqFKXImQpFKHKeQtGJnKUQZOLkHIWgEidmKBQyMTuh1NF84SKIoEFXdI+lP6TxOA75mVE+Sv2cLCWlil6WkrDcXJClpPSylqUkGKaLopSUiwdfyVIS5ONBlpIgH69lKQny8UaWkiAfL+s+lDHFy7oPZRDzsu5DGTW9rPsYinxk3Ycyv3tZ97EE+QRZ97EE+QRZ97EE+YSv/PRiCZ0LYjOSo1RQbERylOKJTUiOsOyC2IDkKH0TG5A8ZbGJDUieohKxAckTVFKLDUieoJJabEDyBJXUYhNSIKikFvOSQFBJLeYlgaISMS8JFJWIeUmgqETMS2qKSsS8pKaoRMxLaoJKopiX1ASVRDEvqQkqiWJeEgkqiV/5uSVSWsW9KYrndiL3nihU6D3I6Nk46L26GNg46L3DWLNx8FxLZOPgwYSKe1MUAE9KVMAGwqMblWYDFTI7hg2Ehy4qywYqFJutal0oNlvWulBstq51odhsYetCsT+U3Q374TTM7XP65MdRfWexQMldfn9NK07r/uOw/5Hm7fcldSsDnsxiLwSNN5md8QKDN5kd8gJTCJ2xF4LBm3wT86LEfcDET5rzx7wPsNNgYHBNseNg+chxIPZysYXespeLLfQ28lpiPd4SUkPYsTHAEzSg2WsEj/QAOxMGeMYIbkJhFNtxplhGjumwI2TgCnlQ9lLBs1/ADpGBK7SYvVRcocXspeIKLWZfM+H5QbgJkn2aKjdXlHWeOrRj2l/etLcZ87+GBc+YAztmBnhGEwx7jeChUTDs88iaYr3PX3f/lA5Ld036f6yvdXs94efVd7PX5a8HSAr/t6rdr+Dv/0nY3fyFIc8oaZzed9R1No6og43OhlXx/wKoxJcr"

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    TestFunctions.RegisterTestsScheduledEventType(testName, "DestroyBlockingWagon", Test.DestroyBlockingWagon)
end

---@param testName string
Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the trains/wagons
    local blockingWagon, movingTrain
    for _, wagon in pairs(placedEntitiesByGroup["cargo-wagon"]) do
        if #wagon.train.carriages == 1 then
            blockingWagon = wagon
        else
            movingTrain = wagon.train
        end
    end

    -- Get the stations placed by name.
    local trainStopNorth, trainStopSouth
    for _, stationEntity in pairs(placedEntitiesByGroup["train-stop"]) do
        if stationEntity.backer_name == "North" then
            trainStopNorth = stationEntity
        elseif stationEntity.backer_name == "South" then
            trainStopSouth = stationEntity
        end
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    ---@class Tests_IFTBELT_TestScenarioBespokeData
    local testDataBespoke = {
        blockingWagon = blockingWagon, ---@type LuaEntity
        movingTrain = movingTrain, ---@type LuaTrain
        blockingWagonReached = false, ---@type boolean
        northStationReached = false, ---@type boolean
        southStationReached = false, ---@type boolean
        origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(movingTrain),
        trainStopNorth = trainStopNorth, ---@type LuaEntity
        trainStopSouth = trainStopSouth ---@type LuaEntity
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
    TestFunctions.ScheduleTestsOnceEvent(game.tick + 600, testName, "DestroyBlockingWagon", testName)
end

---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsOnceEvent(testName, "DestroyBlockingWagon", testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param event UtilityScheduledEvent_CallbackObject
Test.DestroyBlockingWagon = function(event)
    -- The main train should have completed its tunnel trip north and have completely stopped at the blocking wagon at this point.
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke ---@type Tests_IFTBELT_TestScenarioBespokeData

    -- The main train will have its lead loco around 30 tiles below the blocking wagon if stopped at the signal.
    local inspectionArea = {left_top = {x = testDataBespoke.blockingWagon.position.x, y = testDataBespoke.blockingWagon.position.y + 25}, right_bottom = {x = testDataBespoke.blockingWagon.position.x, y = testDataBespoke.blockingWagon.position.y + 35}}
    local locosInInspectionArea = TestFunctions.GetTestSurface().find_entities_filtered {area = inspectionArea, name = "locomotive", limit = 1}
    if #locosInInspectionArea ~= 1 then
        TestFunctions.TestFailed(testName, "1 loco not found around expected point")
        return
    end
    local leadingCarriage = locosInInspectionArea[1]
    local mainTrain = locosInInspectionArea[1].train

    if mainTrain.state ~= defines.train_state.wait_signal then
        TestFunctions.TestFailed(testName, "train not stopped at a signal (for blocking wagon) as expected")
        return
    end

    if Utils.GetDistanceSingleAxis(leadingCarriage.position, testDataBespoke.blockingWagon.position, "y") > 25 then
        TestFunctions.TestFailed(testName, "train not stopped at expected position for blocking wagon signal")
        return
    end

    game.print("train stopped at blocking wagon signal")
    testDataBespoke.blockingWagonReached = true

    testDataBespoke.blockingWagon.destroy()
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke ---@type Tests_IFTBELT_TestScenarioBespokeData

    local northTrain, southTrain = testDataBespoke.trainStopNorth.get_stopped_train(), testDataBespoke.trainStopSouth.get_stopped_train()

    if northTrain ~= nil and not testDataBespoke.northStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(northTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached north station, but with train differences")
            return
        end
        game.print("train reached north station")
        testDataBespoke.northStationReached = true
    end
    if southTrain ~= nil and not testDataBespoke.southStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(southTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testDataBespoke.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached south station, but with train differences")
            return
        end
        game.print("train reached south station")
        testDataBespoke.southStationReached = true
    end
    if testDataBespoke.blockingWagonReached and testDataBespoke.northStationReached and testDataBespoke.southStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
