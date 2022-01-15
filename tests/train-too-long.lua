-- Sends a long train at a short portal tunnel. Should be stopped with the loco at the entrance portal entry point. After it sits there for 5 seconds it then moves away from the tunnel. Confirms the alerts appear and then vanish as expected for player 1.

local Test = {}
local TestFunctions = require("scripts/test-functions")

Test.RunTime = 1000

Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
end

local blueprintString = "0eNqtWtty2jAU/Bc9QwZdLfHeb+hDJ5NxQCWeGpuxDSmT4d8rBxqSQJs9Bz0lxvaurN09Ohi9iMd6Gzdd1Qxi/iKqRdv0Yv7jRfTVqinr8bNhv4liLqohrsVENOV6POrKqn4u9w/DtmliPd203VDWD31crWMzTPshnV89DeIwEVWzjL/FXB4mEOi7W9ThfiISXDVU8Tio14P9Q7NdP8YuYb7dOfI1ibbdJLRN26db2mbkSTDTIkzEPl1tioS9rLq4OJ51E9EP5fF/8T3243AvONQXjxyb5RVKW5wow0fKhLYru+pEKq/waeoUXyHXXHKTgVxyye3t5CZwyV0GcrbmRQZyyyX3GcjZhgsZyNmGk7Pb2TXbcVJmYGdbTqoM7GzPyQxVTrNNJzOUOc13XYY6p/iuy1DoFN91GSqd4rsuQ6lTfNdlqHWK7TqVodZJtutUhlon2a5TGWqdZLtOaVYHKflS/7O8bVNf3a26Nv1Fnpk/4TbTCPiT7jKNgB13VWQaAd8HPs8I+AMIHOezNde3lzh2gdO3Fzh+4PXt9U2yfa5vb+X4tVXf3snxlxV9eyPHX1G142SL373oczn7+zjT19c1/3nd8pnkGqzHYQsCbMBhLQ5rZjisJsBKHFYSYBUM6wiSGY3DEiQzBoelSGZxWIpkDoelSAanTFGmFg6ZovgAzpgmzICFI6YJclk4YZrgLQsHTBPUsnC+NEEtC8fLUNSC02UoasHhMhS14GwZilpwtgxFLThblqCWg7NlCWo5OFuWoJaDs2UJajk4W5agloOzRVkLHJwtysLl4GxRVlkHZ4vSEjg4W5T+xcHZojRbBZwtSmdYwNmitLEFnC1Kz13A2aJ8QSjO2arbRbtuh2oXLyG9vgv6wxy0XZWgTt9oZnfjufHH5n68oWsXv+Iw/bmN9fgr0OEaL5w+T3EJnD5PcQmcPk9xCZw+T3HJOX2Lslu10+dyla69fBMzQwRtdumjtkvXNNu6vvbjJhxLTzClh2MZCObwcCwDwRxegxNe5JlweC0MBC96OI2B4EUPpzFQzAGnUc4o7vBQIZQz84WOilgJfcCfh+DLMMNhCU4JEoclWCUoHJbglQCvmVISvBIMtDHqDdPKi9eB541R38pxY9R9+mjxFJfb+rQV62zC8Tgt096/u+a4hezT5qr7EeV1x9f83a6zidjFrj/yemmKoAoTrCmsPhz+AFVR8KI="

Test.Start = function(testName)
    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 40, y = 70}, testName)

    -- Get the east portal's entry portal end entity.
    local entrancePortalEntryPortalEnd, entrancePortalEntryPortalEndXPos = nil, -100000
    for _, portalEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEntity.position.x > entrancePortalEntryPortalEndXPos then
            entrancePortalEntryPortalEnd = portalEntity
            entrancePortalEntryPortalEndXPos = portalEntity.position.x
        end
    end

    local train = placedEntitiesByGroup["locomotive"][1].train

    -- Get the East station.
    local eastTrainStop
    for _, trainStop in pairs(placedEntitiesByGroup["train-stop"]) do
        if trainStop.backer_name == "East" then
            eastTrainStop = trainStop
            break
        end
    end

    -- Get the player as we need to check their alerts.
    local player = game.connected_players[1]
    if player == nil then
        TestFunctions.TestFailed(testName, "Test requires player to check alerts on.")
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.bespoke = {
        train = train,
        entrancePortalEntryPortalEnd = entrancePortalEntryPortalEnd,
        eastTrainStop = eastTrainStop,
        player = player,
        ticksStopped = 0,
        trainStoppedAtTunnelEntrance = false,
        trainStartedFromTunnelEntrance = false
    }

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)
end

Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(event.instanceId)
    local testDataBespoke = testData.bespoke

    local train = testDataBespoke.train ---@type LuaTrain
    local entrancePortalEntryPortalEnd = testDataBespoke.entrancePortalEntryPortalEnd ---@type LuaEntity
    local eastTrainStop = testDataBespoke.eastTrainStop ---@type LuaEntity
    local player = testDataBespoke.player ---@type LuaPlayer

    -- Check the train still exists.
    if not train.valid then
        TestFunctions.TestFailed(testName, "Train entered the tunnel which it never should")
        return
    end

    -- Check if we are at the stage of the test when we look for the train at the tunnel entrance.
    if testDataBespoke.trainStartedFromTunnelEntrance == false then
        local trainFoundAtPortalEntrance = TestFunctions.GetTrainInArea({left_top = {x = entrancePortalEntryPortalEnd.position.x + 3, y = entrancePortalEntryPortalEnd.position.y}, right_bottom = {x = entrancePortalEntryPortalEnd.position.x + 4, y = entrancePortalEntryPortalEnd.position.y}})

        -- See if the train has stopped at the tunnel entrance.
        if trainFoundAtPortalEntrance ~= nil and trainFoundAtPortalEntrance.speed == 0 then
            -- On the first occurence do the setup for this stage.
            if testDataBespoke.ticksStopped == 0 then
                testDataBespoke.trainStoppedAtTunnelEntrance = true

                -- The alert should appear instantly.
                local playerAlerts = player.get_alerts {entity = entrancePortalEntryPortalEnd}
                if playerAlerts[entrancePortalEntryPortalEnd.surface.index] == nil or #playerAlerts[entrancePortalEntryPortalEnd.surface.index] == 0 or #playerAlerts[entrancePortalEntryPortalEnd.surface.index][defines.alert_type.custom] ~= 1 then
                    TestFunctions.TestFailed(testName, "Train was rejected from tunnel, but alert didn't show")
                end

                game.print("Train stopped and alert shown")
            end

            -- Every tick in this stage do the same process.
            testDataBespoke.ticksStopped = testDataBespoke.ticksStopped + 1

            -- If the train has been stopped for 5 seconds then this stage should be finished.
            if testDataBespoke.ticksStopped > 300 then
                testDataBespoke.trainStartedFromTunnelEntrance = true

                -- Send the train away from the tunnel to a train stop behind it.
                train.schedule = {
                    current = 1,
                    records = {
                        {station = eastTrainStop.backer_name}
                    }
                }
                train.manual_mode = false
            end
        end
    end

    -- Train is at the stage whre it heads away from the tunnel.
    if testDataBespoke.trainStartedFromTunnelEntrance then
        -- Check if the train has reached the station.
        if eastTrainStop.get_stopped_train() ~= nil then
            -- The alert should have vanished by now.
            local playerAlerts = player.get_alerts {entity = entrancePortalEntryPortalEnd}
            if #playerAlerts[entrancePortalEntryPortalEnd.surface.index][defines.alert_type.custom] ~= 0 then
                TestFunctions.TestFailed(testName, "Train has reached reverse station, but alert hasn't stopped")
            else
                TestFunctions.TestCompleted(testName)
            end
        end
    end
end

return Test
