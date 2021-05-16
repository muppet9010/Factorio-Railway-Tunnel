-- Sends a single loco from the east to the west and loops back again through the tunnel the opposite way.

local Test = {}
local TestFunctions = require("scripts/test-functions")
local Utils = require("utility/utils")

Test.RunTime = 1800

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString =
    "0eNqtm91u4kgQhd/F17Bydbu73dzvM+zFKkIe8GSsBRsZk5koyruPDWTyV1nOafkmCQQ+ijp1+s/lp+zb7lQf+qYdstVT1my69pit/n3Kjs19W+2m54bHQ52tsmao99kia6v99Kivmt3P6nE9nNq23i0vv9aHrh+q3fp46r9Xm3p52I0/9/WIfl5kTbutf2UreV5A8DdvMc93i2ykNENTX4I7P3hct6f9t7ofmX/euTn1D/V2eQYsskN3HN/TtdMHjZylGL/IHrNVObK3TV9vLv/0U0gfkAZFSqkhrYK0GFJcgQZZgERv0BjdH+JxGGH3P4avcxnPUJH31KBQPU4Vp1JFoQaUKk7gUEsY6vFII1pM9iKUFLeZkhNJtWqoTsMKj7VAtAbOaxFVqiaWWJoqtz0gsK3KF7U0CmElEfUrq/p4HusAfXAzFUGlqvqUNNUC+kQ8BXlUg9Uya3IeG25n1gieA6dStcwaQ1Pd7cwaS6QgqMGqmS14bAQy6/AcWJWqZtbT1ABkNpBTgDHvoYUGLYm8OjUDqlyRxhpgErQ5nlhRqZpcVljqxxSoSzXDTQEf1dLSahlzWTUBKrbgscCEbXFz2ahSVbU8TQUmbBuIFIgarJrZkscCU62NeA6CStUyW+Q0FZhqC6H3AwaYagtDbthMCWQA91ckQgUXg8tIROrA0eVlLvjANBqTcJZTv72qf+B2mFCk9BYLivTVVRO0XR6H7qBW1NWpHybtMX3Hobr8nf1TH6cji8+74zzh/GOrRGGuFoyfgnio+qb6evBwciOCY30/HbjcDkFSIzAzRZAcgJ0pAJsaQDFTAC41ADdTAMlV6GcKIKYGEOYqwuQqLOeKILkM41wRpNahz+eKILUQ/VzDoaRWop9rODSplejnGg9NaiX6uQZEk1yJc42IyROzn2tINMmVONeYaJMrca4x0SZX4lxjok2txDDXmGhTKzHIPItUr4tgbgdgiE2jXmvaviEQ5ydfDOcqljg/+WKeUrGOvuYFYT19eQbCBvqqAoQt6SN1CBvp82QEW+b8uSeCFf6ADsEa/nQKwfKnKAgVN1kkBMM9Fgm9cItFQi7cYZFQCzdYSaiF+6vE1Yq4vUpcrYi7q8TViri5SlytiHsr4GpF3FuBUAv3ViDUwr0VCLVwbwVCLdxbnlAL95bH1ZIcN5d3BBZ3l7cEFreXFwKL+8tFAosbzDGS4Q5zjGS4xRwjGeyxkkkt7LHI1AHsMWICF7zhilhsCN5vRSyMBG+3IhZxQrRbEStOkQLHMnrhV7BzRjD8QlvOKIY3YOWMZK8G23Wbbt8NzUOtHYO/SWzXNyPmusHP/5qm96k99zi9tu82/9XD8vup3o21o/a94e1ZzFZS8PYsZuMrRHsWsU0Xoj+LOFQQvEGLOQIRvEGLObARokHLMJLhDjSMZLgDDSMZfrnbMJIRXSSEZESTliUkI7q0LCGZNXTTC4S1dJcShC3oBjgIS7dBYljPdphiWLrRGMOWbCc4ho3sPQYQlmjWYtboeLeWMDuKAncZs/9506/1fx07L0wrn65DvDbs/F1NDTt341ObH/X2tLveJvS65Jkej4uhN6+43OT0vuVnkf2smmG96drtOYQLZWQcqr5eX29V6vrxdde/6/1heBw/+HxP0/to0ll30xc53xC1enNz1iJ7qPvj5auXozeiCTYEN+5On59/Ax0Q1M4="

Test.Start = function(testName)
    local builtEntities = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the stations placed by name.
    local trainStopWest, trainStopEast
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        if stationEntity.backer_name == "West" then
            trainStopWest = stationEntity
        elseif stationEntity.backer_name == "East" then
            trainStopEast = stationEntity
        end
    end

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.westStationReached = false
    testData.eastStationReached = false
    testData.origionalTrainSnapshot = TestFunctions.GetSnapshotOfTrain(train)
    testData.trainStopWest = trainStopWest
    testData.trainStopEast = trainStopEast

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName, testData = event.instanceId, TestFunctions.GetTestDataObject(event.instanceId)
    local westTrain, eastTrain = testData.trainStopWest.get_stopped_train(), testData.trainStopEast.get_stopped_train()
    if westTrain ~= nil and not testData.westStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(westTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached west station, but with train differences")
            return
        end
        game.print("train reached west station")
        testData.westStationReached = true
    end
    if eastTrain ~= nil and not testData.eastStationReached then
        local currentTrainSnapshot = TestFunctions.GetSnapshotOfTrain(eastTrain)
        if not TestFunctions.AreTrainSnapshotsIdentical(testData.origionalTrainSnapshot, currentTrainSnapshot) then
            TestFunctions.TestFailed(testName, "train reached east station, but with train differences")
            return
        end
        game.print("train reached east station")
        testData.eastStationReached = true
    end
    if testData.westStationReached and testData.eastStationReached then
        TestFunctions.TestCompleted(testName)
    end
end

return Test
