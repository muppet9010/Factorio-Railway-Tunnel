local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local Tunnel = {}

Tunnel.tunnelSetup = {
    --Tunnels distance starts from the first entrace tile.
    entranceFromCenter = 25,
    entrySignalsDistance = 0,
    endSignalsDistance = 49,
    straightRailCountFromEntrance = 21,
    invisibleRailCountFromEntrance = 4
}

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    global.tunnel.portals = global.tunnel.portals or {} --[[
        id = unique id of the placed portal.
        entity = ref to the entity of the placed main tunnel portal entity.
        endSignals = table of LuaEntity for the end signals of this portal. These are the inner locked red signals.
        entrySignals = table of LuaEntity for the entry signals of this portal. These are the outer ones that detect a train approaching the tunnel train path.
        tunnel = the tunnel this portal is part of, may be nul.
        rails = table of the rail entities within the portal. key'd by the rail unit_number.
    ]]
    global.tunnel.tunnels = global.tunnel.tunnels or {} --[[
        id = unqiue id of the tunnel.
        alignment = either "horizontal" or "vertical".
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the underground surface for this tunnel.
        aboveEndSignals = table of LuaEntity for the end signals of this tunnel. These are the inner locked red signals.
        aboveEntrySignals = table of LuaEntity for the entry signals of this tunnel. These are the outer ones that detect a train approaching the tunnel train path.
        portals = table of the 2 portal global objects that make up this tunnel.
        --TODO: maybe remove references to things within a portal, liek the signals.
    ]]
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)
    Interfaces.RegisterInterface("Tunnel.RegisterTunnel", Tunnel.RegisterTunnel)

    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}, {filter = "name", name = "railway_tunnel-tunnel_rail_surface-placement"}})
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Tunnel.OnRobotBuiltEntity", Tunnel.OnRobotBuiltEntity, "Tunnel.OnRobotBuiltEntity", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}, {filter = "name", name = "railway_tunnel-tunnel_rail_surface-placement"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Tunnel.ScriptRaisedBuilt", Tunnel.ScriptRaisedBuilt, "Tunnel.ScriptRaisedBuilt", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}, {filter = "name", name = "railway_tunnel-tunnel_rail_surface-placement"}})
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

Tunnel.RegisterTunnel = function(aboveSurface, alignment, aboveEndSignals, aboveEntrySignals)
    -- Temp function until we generate the tunnel by code
    local tunnelId = #global.tunnel.tunnels
    local undergroundSurface = game.surfaces["railway_tunnel-undeground-horizontal_surface"]
    local tunnel = {id = tunnelId, alignment = alignment, aboveSurface = aboveSurface, undergroundSurface = undergroundSurface, aboveEndSignals = aboveEndSignals, aboveEntrySignals = aboveEntrySignals}
    global.tunnel.tunnels[tunnelId] = tunnel

    global.tunnel.endSignals[aboveEndSignals.eastern[defines.direction.east].unit_number] = {signal = aboveEndSignals.eastern[defines.direction.east], tunnel = tunnel}

    return tunnel
end

Tunnel.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, game.get_player(event.player_index))
    elseif createdEntity.name == "railway_tunnel-tunnel_rail_surface-placement" then
        Tunnel.PlacementTunnelRailSurfaceBuilt(createdEntity)
    end
end

Tunnel.OnRobotBuiltEntity = function(event)
    local createdEntity = event.entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, event.robot)
    elseif createdEntity.name == "railway_tunnel-tunnel_rail_surface-placement" then
        Tunnel.PlacementTunnelRailSurfaceBuilt(createdEntity)
    end
end

Tunnel.ScriptRaisedBuilt = function(event)
    local createdEntity = event.entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, nil)
    elseif createdEntity.name == "railway_tunnel-tunnel_rail_surface-placement" then
        Tunnel.PlacementTunnelRailSurfaceBuilt(createdEntity)
    end
end

Tunnel.PlacementTunnelPortalBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, directionName, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, Utils.DirectionValueToName(placementEntity.direction), placementEntity.surface
    local orientation = directionValue / 8
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - Tunnel.tunnelSetup.entranceFromCenter}))

    if not Tunnel.TunnelPortalPlacementValid(placementEntity) then
        --TODO: mine the placement entity back to the placer and show a message. May be nil placer, if so just lose the item as script created.
        return
    end

    placementEntity.destroy()
    local abovePlacedPortal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed-" .. directionName, position = centerPos, force = force, player = lastUser}
    local portal = {
        id = #global.tunnel.portals,
        entity = abovePlacedPortal,
        rails = {}
    }
    global.tunnel.portals[#global.tunnel.portals] = portal

    local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1}))
    local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
    for _ = 1, Tunnel.tunnelSetup.straightRailCountFromEntrance do
        local placedRail = aboveSurface.create_entity {name = "straight-rail", position = nextRailPos, force = force, direction = directionValue}
        portal.rails[placedRail.unit_number] = placedRail
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end

    portal.entrySignals = {
        ["in"] = aboveSurface.create_entity {
            name = "rail-signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0.5})),
            force = force,
            direction = directionValue
        },
        ["out"] = aboveSurface.create_entity {
            name = "rail-signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = 0.5})),
            force = force,
            direction = Utils.LoopIntValueWithinRange(directionValue + 4, 0, 7)
        }
    }
    portal.endSignals = {
        ["in"] = aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = -0.5 + Tunnel.tunnelSetup.endSignalsDistance})),
            force = force,
            direction = directionValue
        },
        ["out"] = aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = -0.5 + Tunnel.tunnelSetup.endSignalsDistance})),
            force = force,
            direction = Utils.LoopIntValueWithinRange(directionValue + 4, 0, 7)
        }
    }
    portal.endSignals["in"].connect_neighbour {wire = defines.wire_type.red, target_entity = portal.endSignals["out"]}
    Tunnel.SetRailSignalRed(portal.endSignals["in"])
    Tunnel.SetRailSignalRed(portal.endSignals["out"])
end

Tunnel.SetRailSignalRed = function(signal)
    local controlBehavour = signal.get_or_create_control_behavior()
    controlBehavour.read_signal = false
    controlBehavour.close_signal = true
    controlBehavour.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = "="}, constant = 0}
end

Tunnel.TunnelPortalPlacementValid = function(placementEntity)
    --TODO: check that the entrance of the tunnel portal is aligned to the rail grid correctly.
    return true
end

Tunnel.TunnelRailPlacementValid = function(placementEntity)
    --TODO: check that the tunnel rail is aligned to the rail grid correctly.
    return true
end

Tunnel.PlacementTunnelRailSurfaceBuilt = function(placementEntity)
    local centerPos, force, lastUser, directionValue, directionName, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, Utils.DirectionValueToName(placementEntity.direction), placementEntity.surface
    local orientation = directionValue / 8
    local alignmentName = "northsouth"
    if directionValue == defines.direction.east or directionValue == defines.direction.west then
        alignmentName = "eastwest"
    end

    if not Tunnel.TunnelRailPlacementValid(placementEntity) then
        --TODO: mine the placement entity back to the placer and show a message. May be nil placer, if so just lose the item as script created.
        return
    end

    placementEntity.destroy()
    local abovePlacedTunnelRail = aboveSurface.create_entity {name = "railway_tunnel-tunnel_rail_surface-placed-" .. alignmentName, position = centerPos, force = force, player = lastUser}

    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - Tunnel.tunnelSetup.entranceFromCenter}))
end

return Tunnel
