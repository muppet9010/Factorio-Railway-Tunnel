local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
--local Logging = require("utility/logging")
local Tunnel = {}

local TunnelSetup = {
    --Tunnels distance starts from the first entrace tile.
    entranceFromCenter = 25,
    entrySignalsDistance = 0,
    endSignalsDistance = 50,
    straightRailCountFromEntrance = 21,
    invisibleRailCountFromEntrance = 4
}
local TunnelSegmentEntityNames = {["railway_tunnel-tunnel_segment_surface-placed"] = "railway_tunnel-tunnel_segment_surface-placed"}
local TunnelPortalEntityNames = {["railway_tunnel-tunnel_portal_surface-placed"] = "railway_tunnel-tunnel_portal_surface-placed"}
local TunnelSegmentAndPortalEntityNames = Utils.TableMerge({TunnelSegmentEntityNames, TunnelPortalEntityNames})

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    --[[
        [unit_number] = {
            id = unit_number of this signal.
            entity = signal entity.
            portal = the portal global object this signal is part of.
        }
    ]]
    global.tunnel.portals = global.tunnel.portals or {}
    --[[
        [unit_number] = {
            id = unit_number of the placed tunnel portal entity.
            entity = ref to the entity of the placed main tunnel portal entity.
            endSignals = table of endSignal global objects for the end signals of this portal. These are the inner locked red signals.
            entrySignalEntities = table of LuaEntity for the entry signals of this portal. These are the outer ones that detect a train approaching the tunnel train path.
            tunnel = the tunnel global object this portal is part of.
            railEntities = table of the rail entities within the portal. key'd by the rail unit_number.
        }
    ]]
    global.tunnel.tunnels = global.tunnel.tunnels or {}
    --[[
        [id] = {
            id = unqiue id of the tunnel.
            alignment = either "horizontal" or "vertical".
            aboveSurface = LuaSurface of the main world surface.
            undergroundSurface = LuaSurface of the underground surface for this tunnel.
            aboveEndSignals = table of LuaEntity for the end signals of this tunnel. These are the inner locked red signals.
            aboveEntrySignalEntities = table of LuaEntity for the entry signals of this tunnel. These are the outer ones that detect a train approaching the tunnel train path.
            portals = table of the 2 portal global objects that make up this tunnel.
            segments = table of the tunnel segment global objects on the surface.
        }
        --TODO: maybe remove references to things within a portal, like the signals.
    ]]
    global.tunnel.tunnelSegments = global.tunnel.tunnelSegments or {}
    --[[
        [unit_number] = {
            id = unit_number of the placed segment entity.
            entity = ref to the placed entity
            railEntities = table of the rail entities within the tunnel segment. key'd by the rail unit_number.
            signalEntities = table of the hidden signal entities within the tunnel segment. key'd by the signal unit_number.
            tunnel = the tunnel this portal is part of.
        }
    ]]
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)

    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}, {filter = "name", name = "railway_tunnel-tunnel_segment_surface-placement"}})
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Tunnel.OnRobotBuiltEntity", Tunnel.OnRobotBuiltEntity, "Tunnel.OnRobotBuiltEntity", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}, {filter = "name", name = "railway_tunnel-tunnel_segment_surface-placement"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Tunnel.ScriptRaisedBuilt", Tunnel.ScriptRaisedBuilt, "Tunnel.ScriptRaisedBuilt", {{filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"}, {filter = "name", name = "railway_tunnel-tunnel_segment_surface-placement"}})
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
    Interfaces.Call("TrainManager.TrainEnteringInitial", train, global.tunnel.endSignals[signal.unit_number])
end

Tunnel.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, game.get_player(event.player_index))
    elseif createdEntity.name == "railway_tunnel-tunnel_segment_surface-placement" then
        Tunnel.PlacementTunnelSegmentSurfaceBuilt(createdEntity)
    end
end

Tunnel.OnRobotBuiltEntity = function(event)
    local createdEntity = event.entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, event.robot)
    elseif createdEntity.name == "railway_tunnel-tunnel_segment_surface-placement" then
        Tunnel.PlacementTunnelSegmentSurfaceBuilt(createdEntity)
    end
end

Tunnel.ScriptRaisedBuilt = function(event)
    local createdEntity = event.entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, nil)
    elseif createdEntity.name == "railway_tunnel-tunnel_segment_surface-placement" then
        Tunnel.PlacementTunnelSegmentSurfaceBuilt(createdEntity)
    end
end

Tunnel.PlacementTunnelPortalBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface
    local orientation = directionValue / 8
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - TunnelSetup.entranceFromCenter}))

    if not Tunnel.TunnelPortalPlacementValid(placementEntity) then
        --TODO: mine the placement entity back to the placer and show a message. May be nil placer, if so just lose the item as script created.
        return
    end

    placementEntity.destroy()
    local abovePlacedPortal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
    local portal = {
        id = abovePlacedPortal.unit_number,
        entity = abovePlacedPortal,
        railEntities = {}
    }
    global.tunnel.portals[portal.id] = portal

    local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1}))
    local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
    for _ = 1, TunnelSetup.straightRailCountFromEntrance do
        local placedRail = aboveSurface.create_entity {name = "straight-rail", position = nextRailPos, force = force, direction = directionValue}
        portal.railEntities[placedRail.unit_number] = placedRail
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end

    Tunnel.CheckProcessTunnelPortalComplete(abovePlacedPortal)
end

Tunnel.CheckProcessTunnelPortalComplete = function(startingTunnelPortal)
    local centerPos, force, directionValue, aboveSurface = startingTunnelPortal.position, startingTunnelPortal.force, startingTunnelPortal.direction, startingTunnelPortal.surface
    local orientation = directionValue / 8
    local exitPos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1 + TunnelSetup.entranceFromCenter}))

    local continueChecking, nextCheckingPos, completeTunnel, tunnelPortals, tunnelSegments = true, exitPos, false, {startingTunnelPortal}, {}
    while continueChecking do
        local connectedTunnelEntities = aboveSurface.find_entities_filtered {position = nextCheckingPos, name = TunnelSegmentAndPortalEntityNames, force = force, limit = 1}
        if #connectedTunnelEntities == 0 then
            continueChecking = false
        else
            local connectedTunnelEntity = connectedTunnelEntities[1]
            if TunnelSegmentEntityNames[connectedTunnelEntity.name] then
                if connectedTunnelEntity.direction == startingTunnelPortal.direction or connectedTunnelEntity.direction == Utils.LoopDirectionValue(startingTunnelPortal.direction + 4) then
                    nextCheckingPos = Utils.ApplyOffsetToPosition(nextCheckingPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 2}))
                    table.insert(tunnelSegments, connectedTunnelEntity)
                else
                    continueChecking = false
                end
            elseif TunnelPortalEntityNames[connectedTunnelEntity.name] then
                continueChecking = false
                if connectedTunnelEntity.direction == Utils.LoopDirectionValue(startingTunnelPortal.direction + 4) then
                    completeTunnel = true
                    table.insert(tunnelPortals, connectedTunnelEntity)
                end
            end
        end
    end
    if not completeTunnel then
        return false
    end
    Tunnel.TunnelCompleted(tunnelPortals, tunnelSegments)
end

Tunnel.TunnelPortalPlacementValid = function(placementEntity)
    --TODO: check that the entrance of the tunnel portal is aligned to the rail grid correctly.
    return true
end

Tunnel.TunnelSegmentPlacementValid = function(placementEntity)
    --TODO: check that the tunnel rail is aligned to the rail grid correctly.
    return true
end

Tunnel.PlacementTunnelSegmentSurfaceBuilt = function(placementEntity)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface

    if not Tunnel.TunnelSegmentPlacementValid(placementEntity) then
        --TODO: mine the placement entity back to the placer and show a message. May be nil placer, if so just lose the item as script created.
        return
    end

    placementEntity.destroy()
    local abovePlacedTunnelSegment = aboveSurface.create_entity {name = "railway_tunnel-tunnel_segment_surface-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
    local tunnelSegment = {
        id = abovePlacedTunnelSegment.unit_number,
        entity = abovePlacedTunnelSegment
    }
    global.tunnel.tunnelSegments[tunnelSegment.id] = {
        id = tunnelSegment.unit_number,
        entity = tunnelSegment
    }

    Tunnel.CheckProcessTunnelSegmentComplete(abovePlacedTunnelSegment)
end

Tunnel.CheckProcessTunnelSegmentComplete = function(startingTunnelSegment)
    --TODO - similar to Tunnel.CheckProcessTunnelPortalComplete
end

Tunnel.TunnelCompleted = function(tunnelPortalEntities, tunnelSegmentEntities)
    local tunnelPortals, tunnelSegments = {}, {}

    for _, portalEntity in pairs(tunnelPortalEntities) do
        local portal = global.tunnel.portals[portalEntity.unit_number]
        table.insert(tunnelPortals, portal)
        local centerPos, force, directionValue, aboveSurface = portalEntity.position, portalEntity.force, portalEntity.direction, portalEntity.surface
        local orientation = directionValue / 8
        local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - TunnelSetup.entranceFromCenter}))

        local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1 + (TunnelSetup.straightRailCountFromEntrance * 2)}))
        local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
        for _ = 1, TunnelSetup.invisibleRailCountFromEntrance do
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = nextRailPos, force = force, direction = directionValue}
            portal.railEntities[placedRail.unit_number] = placedRail
            nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
        end

        portal.entrySignalEntities = {
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
                direction = Utils.LoopDirectionValue(directionValue + 4)
            }
        }
        local endSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = -0.5 + TunnelSetup.endSignalsDistance})),
            force = force,
            direction = directionValue
        }
        global.tunnel.endSignals[endSignalInEntity.unit_number] = {
            id = endSignalInEntity.unit_number,
            entity = endSignalInEntity,
            portal = portal
        }
        local endSignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = -0.5 + TunnelSetup.endSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        global.tunnel.endSignals[endSignalOutEntity.unit_number] = {
            id = endSignalOutEntity.unit_number,
            entity = endSignalOutEntity,
            portal = portal
        }
        portal.endSignals = {["in"] = endSignalInEntity, ["out"] = endSignalOutEntity}
        endSignalInEntity.connect_neighbour {wire = defines.wire_type.red, target_entity = endSignalOutEntity}
        Tunnel.SetRailSignalRed(endSignalInEntity)
        Tunnel.SetRailSignalRed(endSignalOutEntity)
    end

    for _, tunnelSegmentEntity in pairs(tunnelSegmentEntities) do
        local tunnelSegment = global.tunnel.tunnelSegments[tunnelSegmentEntity.unit_number]
        table.insert(tunnelSegments, tunnelSegment)
        local centerPos, force, directionValue, aboveSurface = tunnelSegmentEntity.position, tunnelSegmentEntity.force, tunnelSegmentEntity.direction, tunnelSegmentEntity.surface

        tunnelSegment.railEntities = {}
        local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = centerPos, force = force, direction = directionValue}
        tunnelSegment.railEntities[placedRail.unit_number] = placedRail

        tunnelSegment.signalEntities = {}
        for _, orientationModifier in pairs({0, 4}) do
            local signalDirection = Utils.LoopDirectionValue(directionValue + orientationModifier)
            local orientation = signalDirection / 8
            local position = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0}))
            local placedSignal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_rail_signal_surface", position = position, force = force, direction = signalDirection}
            tunnelSegment.signalEntities[placedSignal.unit_number] = placedSignal
        end
    end

    local tunnelId, alignment, undergroundSurface, refTunnelPortalEntity, aboveEndSignals, aboveEntrySignalEntities = #global.tunnel.tunnels, "vertical", global.underground.verticalSurface, tunnelPortals[1].entity, {}, {}
    if refTunnelPortalEntity.direction == defines.direction.east or refTunnelPortalEntity.direction == defines.direction.west then
        alignment = "horizontal"
        undergroundSurface = global.underground.horizontalSurface
    end
    local tunnel = {
        id = tunnelId,
        alignment = alignment,
        aboveSurface = refTunnelPortalEntity.surface,
        undergroundSurface = undergroundSurface,
        portals = tunnelPortals,
        segments = tunnelSegments
    }
    for _, tunnelPortal in pairs(tunnelPortals) do
        table.insert(aboveEndSignals, tunnelPortal.endSignals["in"])
        table.insert(aboveEndSignals, tunnelPortal.endSignals["out"])
        table.insert(aboveEntrySignalEntities, tunnelPortal.entrySignalEntities["in"])
        table.insert(aboveEntrySignalEntities, tunnelPortal.entrySignalEntities["out"])
    end
    tunnel.aboveEndSignals, tunnel.aboveEntrySignalEntities = aboveEndSignals, aboveEntrySignalEntities
    global.tunnel.tunnels[tunnelId] = tunnel

    for _, portal in pairs(tunnelPortals) do
        portal.tunnel = tunnel
    end
    for _, segment in pairs(tunnelSegments) do
        segment.tunnel = tunnel
    end
end

Tunnel.SetRailSignalRed = function(signal)
    local controlBehavour = signal.get_or_create_control_behavior()
    controlBehavour.read_signal = false
    controlBehavour.close_signal = true
    controlBehavour.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = "="}, constant = 0}
end

return Tunnel
