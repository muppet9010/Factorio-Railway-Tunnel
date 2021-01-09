local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelCommon = require("scripts/tunnel-common")
local TunnelPortals = {}

TunnelPortals.CreateGlobals = function()
    global.tunnelPortals = global.tunnelPortals or {}
    global.tunnelPortals.portals = global.tunnelPortals.portals or {}
    --[[
        [unit_number] = {
            id = unit_number of the placed tunnel portal entity.
            entity = ref to the entity of the placed main tunnel portal entity.
            endSignals = table of endSignal global objects for the end signals of this portal. These are the inner locked red signals. Key'd as "in" and "out".
            entrySignals = table of entrySignal global objects for the entry signals of this portal. These are the outer ones that detect a train approaching the tunnel train path. Key'd as "in" and "out".
            tunnel = the tunnel global object this portal is part of.
            railEntities = table of the rail entities within the portal. key'd by the rail unit_number.
        }
    ]]
end

TunnelPortals.OnLoad = function()
    local tunnelPortalEntityNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelPortalPlacedPlacementEntityNames) do
        table.insert(tunnelPortalEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", tunnelPortalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", tunnelPortalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", tunnelPortalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "TunnelPortals.OnPreMinedEntity", TunnelPortals.OnPreMinedEntity, "TunnelPortals.OnPreMinedEntity", tunnelPortalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "TunnelPortals.OnPreMinedEntity", TunnelPortals.OnPreMinedEntity, "TunnelPortals.OnPreMinedEntity", tunnelPortalEntityNames_Filter)

    local tunnelPortalEntityGhostNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelPortalPlacedPlacementEntityNames) do
        table.insert(tunnelPortalEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, "TunnelPortals.OnBuiltEntityGhost", tunnelPortalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, "TunnelPortals.OnBuiltEntityGhost", tunnelPortalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, "TunnelPortals.OnBuiltEntityGhost", tunnelPortalEntityGhostNames_Filter)

    Interfaces.RegisterInterface("TunnelPortals.TunnelCompleted", TunnelPortals.TunnelCompleted)
end

TunnelPortals.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or TunnelCommon.tunnelPortalPlacedPlacementEntityNames[createdEntity.name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    TunnelPortals.PlacementTunnelPortalBuilt(createdEntity, placer)
end

TunnelPortals.PlacementTunnelPortalBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface
    local orientation = directionValue / 8
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - TunnelCommon.setupValues.entranceFromCenter}))

    if not TunnelPortals.TunnelPortalPlacementValid(placementEntity) then
        TunnelCommon.UndoInvalidPlacement(placementEntity, placer, true)
        return
    end

    placementEntity.destroy()
    local abovePlacedPortal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
    local portal = {
        id = abovePlacedPortal.unit_number,
        entity = abovePlacedPortal,
        railEntities = {}
    }
    global.tunnelPortals.portals[portal.id] = portal

    local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1}))
    local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
    for _ = 1, TunnelCommon.setupValues.straightRailCountFromEntrance do
        local placedRail = aboveSurface.create_entity {name = "railway_tunnel-internal_rail-on_map", position = nextRailPos, force = force, direction = directionValue}
        portal.railEntities[placedRail.unit_number] = placedRail
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end

    local tunnelComplete, tunnelPortals, tunnelSegments = TunnelPortals.CheckTunnelCompleteFromPortal(abovePlacedPortal, placer)
    if not tunnelComplete then
        return false
    end
    Interfaces.Call("Tunnel.TunnelCompleted", tunnelPortals, tunnelSegments)
end

TunnelPortals.TunnelPortalPlacementValid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

TunnelPortals.CheckTunnelCompleteFromPortal = function(startingTunnelPortal, placer)
    local tunnelPortals, tunnelSegments, directionValue, orientation = {startingTunnelPortal}, {}, startingTunnelPortal.direction, startingTunnelPortal.direction / 8
    local startingTunnelPartPoint = Utils.ApplyOffsetToPosition(startingTunnelPortal.position, Utils.RotatePositionAround0(orientation, {x = 0, y = -1 + TunnelCommon.setupValues.entranceFromCenter}))
    return TunnelCommon.CheckTunnelPartsInDirection(startingTunnelPortal, startingTunnelPartPoint, tunnelPortals, tunnelSegments, directionValue, placer), tunnelPortals, tunnelSegments
end

TunnelPortals.TunnelCompleted = function(tunnelPortalEntities, force, aboveSurface)
    local tunnelPortals = {}

    for _, portalEntity in pairs(tunnelPortalEntities) do
        local portal = global.tunnelPortals.portals[portalEntity.unit_number]
        table.insert(tunnelPortals, portal)
        local centerPos, directionValue = portalEntity.position, portalEntity.direction
        local orientation = directionValue / 8
        local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - TunnelCommon.setupValues.entranceFromCenter}))

        local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1 + (TunnelCommon.setupValues.straightRailCountFromEntrance * 2)}))
        local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
        for _ = 1, TunnelCommon.setupValues.invisibleRailCountFromEntrance do
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = nextRailPos, force = force, direction = directionValue}
            portal.railEntities[placedRail.unit_number] = placedRail
            nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
        end

        local entrySignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-internal_signal-on_map",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0.5 + TunnelCommon.setupValues.entrySignalsDistance})),
            force = force,
            direction = directionValue
        }
        global.tunnel.entrySignals[entrySignalInEntity.unit_number] = {
            id = entrySignalInEntity.unit_number,
            entity = entrySignalInEntity,
            portal = portal
        }
        local entrySignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-internal_signal-on_map",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = 0.5 + TunnelCommon.setupValues.entrySignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        global.tunnel.entrySignals[entrySignalOutEntity.unit_number] = {
            id = entrySignalOutEntity.unit_number,
            entity = entrySignalOutEntity,
            portal = portal
        }
        portal.entrySignals = {["in"] = global.tunnel.entrySignals[entrySignalInEntity.unit_number], ["out"] = global.tunnel.entrySignals[entrySignalOutEntity.unit_number]}

        local endSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = -0.5 + TunnelCommon.setupValues.endSignalsDistance})),
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
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = -0.5 + TunnelCommon.setupValues.endSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        global.tunnel.endSignals[endSignalOutEntity.unit_number] = {
            id = endSignalOutEntity.unit_number,
            entity = endSignalOutEntity,
            portal = portal
        }
        portal.endSignals = {["in"] = global.tunnel.endSignals[endSignalInEntity.unit_number], ["out"] = global.tunnel.endSignals[endSignalOutEntity.unit_number]}
        endSignalInEntity.connect_neighbour {wire = defines.wire_type.red, target_entity = endSignalOutEntity}
        TunnelPortals.SetRailSignalRed(endSignalInEntity)
        TunnelPortals.SetRailSignalRed(endSignalOutEntity)
    end

    return tunnelPortals
end

TunnelPortals.SetRailSignalRed = function(signal)
    local controlBehavour = signal.get_or_create_control_behavior()
    controlBehavour.read_signal = false
    controlBehavour.close_signal = true
    controlBehavour.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = "="}, constant = 0}
end

TunnelPortals.OnBuiltEntityGhost = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or createdEntity.type ~= "entity-ghost" or TunnelCommon.tunnelPortalPlacedPlacementEntityNames[createdEntity.ghost_name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end

    if not TunnelPortals.TunnelPortalPlacementValid(createdEntity) then
        TunnelCommon.UndoInvalidPlacement(createdEntity, placer, false)
        createdEntity.destroy()
        return
    end
end

TunnelPortals.OnPreMinedEntity = function(event)
    local minedEntity = event.entity
    if not minedEntity.valid then
        return
    end
    local miner = event.robot -- Will be nil for player mined.
    if miner == nil and event.player_index ~= nil then
        miner = game.get_player(event.player_index)
    end

    local existingObject = global.tunnel.portals[minedEntity.unit_number] or global.tunnel.tunnelSegment[minedEntity.unit_number]
    if existingObject.tunnel == nil then
        -- Just do removed entity tidyup and let mine happen naturatly.
    else
        if Interfaces.Call("TrainManager.IsTunnelIdInUse", existingObject.tunnel.id) then
        -- TODO: Tunnel in use, prevent this.
        end
    end
end

return TunnelPortals
