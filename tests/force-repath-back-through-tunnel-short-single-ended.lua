-- TODO: WILL BE REPLACED BY DYNAMIC TEST
--[[
    Once the train has started entering the tunnel and is committed (first carriage removed from aboveground), remove a piece of track on the exit side of the tunnel. An alternative path by reversing through the tunnel exists, but the train is short and only has forward facing locomotives.
]]
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Test = {}

local blueprintString =
    "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"

Test.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Test.ForceRepathBackThroughTunnelShortSingleEndedOnTick", Test.ForceRepathBackThroughTunnelShortSingleEndedOnTick)
end

Test.Start = function(TestManager, testName)
    local builtEntities = TestManager.BuildBlueprintFromString(blueprintString, {x = 0, y = 276}, testName)

    local train = builtEntities[Utils.GetTableKeyWithInnerKeyValue(builtEntities, "name", "locomotive")].train -- Just get any loco in this blueprint.

    -- Find the left hand station and then get the rail 50 tiles to the right of it (between station and tunnel).
    local stations, leftStation = {}
    for _, stationEntityIndex in pairs(Utils.GetTableKeysWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        table.insert(stations, builtEntities[stationEntityIndex])
    end
    if stations[1].position.x < stations[2].position.x then
        leftStation = stations[1]
    else
        leftStation = stations[2]
    end
    local leftStationRail = leftStation.connected_rail
    local trackToRemove = leftStation.surface.find_entity("straight-rail", {x = leftStationRail.position.x + 50, y = leftStationRail.position.y})

    EventScheduler.ScheduleEventEachTick("Test.ForceRepathBackThroughTunnelShortSingleEndedOnTick", train.id, {trainId = train.id, train = train, trackToRemove = trackToRemove})
end

Test.ForceRepathBackThroughTunnelShortSingleEndedOnTick = function(event)
    if event.data.train.valid then
        return
    end

    -- Train carriage has been removed as Lue Train object no longer is valid.
    EventScheduler.RemoveScheduledEventFromEachTick("Test.ForceRepathBackThroughTunnelShortSingleEndedOnTick", event.data.trainId)
    event.data.trackToRemove.destroy()
end

return Test
