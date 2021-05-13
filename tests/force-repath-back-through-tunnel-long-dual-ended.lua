-- TODO: WILL BE REPLACED BY DYNAMIC TEST
--[[
    Once the train has started entering the tunnel and is committed (first carriage removed from aboveground), remove a piece of track on the exit side of the tunnel. An alternative path by reversing through the tunnel exists, and the train is a a long dual headed, so reverse engine is still in the tunnel.
]]
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Test = {}

local blueprintString =
    "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"

Test.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("Test.ForceRepathBackThroughTunnelLongDualEndedOnTick", Test.ForceRepathBackThroughTunnelLongDualEndedOnTick)
end

Test.Start = function(TestManager, testName)
    local builtEntities = TestManager.BuildBlueprintFromString(blueprintString, {x = 0, y = 246}, testName)

    local train = Utils.GetTableValueWithInnerKeyValue(builtEntities, "name", "locomotive").train -- Just get any loco in this blueprint.

    -- Find the left hand station and then get the rail 50 tiles to the right of it (between station and tunnel).
    local stations, leftStation = {}
    for _, stationEntity in pairs(Utils.GetTableValuesWithInnerKeyValue(builtEntities, "name", "train-stop")) do
        table.insert(stations, stationEntity)
    end
    if stations[1].position.x < stations[2].position.x then
        leftStation = stations[1]
    else
        leftStation = stations[2]
    end
    local leftStationRail = leftStation.connected_rail
    local trackToRemove = leftStation.surface.find_entity("straight-rail", {x = leftStationRail.position.x + 50, y = leftStationRail.position.y})

    EventScheduler.ScheduleEventEachTick("Test.ForceRepathBackThroughTunnelLongDualEndedOnTick", train.id, {trainId = train.id, train = train, trackToRemove = trackToRemove})
end

Test.ForceRepathBackThroughTunnelLongDualEndedOnTick = function(event)
    if event.data.train.valid then
        return
    end

    -- Train carriage has been removed as Lue Train object no longer is valid.
    EventScheduler.RemoveScheduledEventFromEachTick("Test.ForceRepathBackThroughTunnelLongDualEndedOnTick", event.data.trainId)
    event.data.trackToRemove.destroy()
end

return Test
