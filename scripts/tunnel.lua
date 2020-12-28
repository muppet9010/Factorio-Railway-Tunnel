local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local Tunnel = {}

Tunnel.tunnelSetup = {
    --Tunnels distance starts from the first entrace tile.
    lengthFromCenter = 25,
    entrySignalsDistance = 0,
    endSignalsDistance = 50,
    straightRailCountFromEntrance = 22,
    invisibleRailCountFromEntrance = 3
}

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    global.tunnel.tunnels = global.tunnel.tunnels or {} --[[
        id = unqiue id of the tunnel.
        direction = either "horizontal" or "vertical".
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the underground surface for this tunnel.
        aboveEndSignals = table of LuaEntity for the end signals of this tunnel. These are the inner locked red signals.
        aboveEntrySignals = table of LuaEntity for the entry signals of this tunnel. These are the outre ones that detect a train approaching the tunnel train path.
    ]]
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)
    Interfaces.RegisterInterface("Tunnel.RegisterTunnel", Tunnel.RegisterTunnel)

    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Tunnel.PlacementTunnelPortalBuilt_OnBuiltEntity", Tunnel.PlacementTunnelPortalBuilt_OnBuiltEntity, "Tunnel.PlacementTunnelPortalBuilt_OnBuiltEntity", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}})
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Tunnel.PlacementTunnelPortalBuilt_OnRobotBuiltEntity", Tunnel.PlacementTunnelPortalBuilt_OnRobotBuiltEntity, "Tunnel.PlacementTunnelPortalBuilt_OnRobotBuiltEntity", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Tunnel.PlacementTunnelPortalBuilt_ScriptRaisedBuilt", Tunnel.PlacementTunnelPortalBuilt_ScriptRaisedBuilt, "Tunnel.PlacementTunnelPortalBuilt_ScriptRaisedBuilt", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}})
end

Tunnel.TrainEnteringTunnel_OnTrainChangedState = function(event)
    local train = event.train
    if train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.tunnel.endSignals[signal.unit_number] == nil then
        return
    end
    Interfaces.Call("TrainManager.TrainEnteringInitial", train, signal, global.tunnel.endSignals[signal.unit_number].tunnel)
end

Tunnel.RegisterTunnel = function(aboveSurface, direction, aboveEndSignals, aboveEntrySignals)
    -- Temp function until we generate the tunnel by code
    local tunnelId = #global.tunnel.tunnels
    local undergroundSurface = game.surfaces["railway_tunnel-undeground-horizontal_surface"]
    local tunnel = {id = tunnelId, direction = direction, aboveSurface = aboveSurface, undergroundSurface = undergroundSurface, aboveEndSignals = aboveEndSignals, aboveEntrySignals = aboveEntrySignals}
    global.tunnel.tunnels[tunnelId] = tunnel

    global.tunnel.endSignals[aboveEndSignals.eastern[defines.direction.east].unit_number] = {signal = aboveEndSignals.eastern[defines.direction.east], tunnel = tunnel}

    return tunnel
end

Tunnel.PlacementTunnelPortalBuilt_OnBuiltEntity = function(event)
    local createdEntity = event.created_entity
    if createdEntity.name ~= "railway_tunnel-tunnel_portal_surface-placement" then
        return
    end
    Tunnel.PlacementTunnelPortalBuilt(createdEntity)
end

Tunnel.PlacementTunnelPortalBuilt_OnRobotBuiltEntity = function(event)
    local createdEntity = event.entity
    if createdEntity.name ~= "railway_tunnel-tunnel_portal_surface-placement" then
        return
    end
    Tunnel.PlacementTunnelPortalBuilt(createdEntity)
end

Tunnel.PlacementTunnelPortalBuilt_ScriptRaisedBuilt = function(event)
    local createdEntity = event.entity
    if createdEntity.name ~= "railway_tunnel-tunnel_portal_surface-placement" then
        return
    end
    Tunnel.PlacementTunnelPortalBuilt(createdEntity)
end

Tunnel.PlacementTunnelPortalBuilt = function(placementEntity)
    local centerPos, force, lastUser, directionValue, directionName, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, Utils.DirectionValueToName(placementEntity.direction), placementEntity.surface
    local orientation = directionValue / 8
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - Tunnel.tunnelSetup.lengthFromCenter}))
    placementEntity.destroy()

    local abovePlacedPortal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed-" .. directionName, position = centerPos, force = force, player = lastUser}
    local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1}))
    local placedRails = {}
    local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
    for _ = 1, Tunnel.tunnelSetup.straightRailCountFromEntrance do
        table.insert(placedRails, aboveSurface.create_entity {name = "straight-rail", position = nextRailPos, force = force, direction = directionValue})
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end
    for _ = 1, Tunnel.tunnelSetup.invisibleRailCountFromEntrance do
        table.insert(placedRails, aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = nextRailPos, force = force, direction = directionValue})
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end
end

return Tunnel
