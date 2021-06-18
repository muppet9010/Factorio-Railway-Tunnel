local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelCommon = require("scripts/tunnel-common")
local TunnelPortals = {}
local Colors = require("utility/colors")

local SetupValues = {
    -- Tunnels distances are from the portal position (center).
    entranceFromCenter = -25,
    entrySignalsDistance = -23.5,
    entrySignalBlockingLocomotiveDistance = -21.5,
    farInvisibleSignalsDistance = 23.5,
    endSignalBlockingLocomotiveDistance = 20.5,
    endSignalsDistance = 19.5,
    straightRailCountFromEntrance = 17,
    invisibleRailCountFromEntrance = 8
}

---@class Portal
---@field public id int @unit_number of the placed tunnel portal entity.
---@field public entity LuaEntity
---@field public entityDirection defines.direction @the expected direction of the portal. Can't block Editor users from rotating the portal entity so need to be able to check if its changed.
---@field public endSignals table<InOutDirection,PortalEndSignal> @These are the inner locked red signals that a train paths at to enter the tunnel.
---@field public entrySignals table<InOutDirection,PortalEntrySignal> @These are the signals that are visible to the wider train network and player. The portals 2 IN entry signals are connected by red wire. The portals OUT direction signals are synced with their corrisponding underground OUT signals every tick.
---@field public tunnel Tunnel
---@field public portalRailEntities table<UnitNumber, LuaEntity> @table of the rail entities that are part of the portal itself.
---@field public tunnelRailEntities table<UnitNumber, LuaEntity> @table of the rail entities that are part of the connected tunnel for the portal.
---@field public tunnelOtherEntities table<UnitNumber, LuaEntity> @table of the non rail entities that are part of the connected tunnel for the portal. Will be deleted before the tunnelRailEntities.
---@field public trainManagersClosingEntranceSignal table<Id, ManagedTrain> @table of TrainManager global objects that currently state this entrance should be closed. -- TODO: can this ever be more than 1?
---@field public entranceSignalBlockingTrainEntity LuaEntity @the locomotive entity thats blocking the entrance signal.
---@field public entranceDistanceFromCenter int @the distance in tiles of the entrance from the portal center.
---@field public portalEntrancePosition Position @the position of the entrance to the portal.
---@field public entranceUsageDetectorEntity LuaEntity @a hidden entity on the entrance to the portal that's death signifies a train is coming on to the portal's rails unexpectedly.

---@class PortalSignal
---@field public id int @unit_number of this signal.
---@field public direction InOutDirection
---@field public entity LuaEntity
---@field public portal Portal

---@class PortalEndSignal:PortalSignal

---@class PortalEntrySignal:PortalSignal
---@field public undergroundSignalPaired UndergroundSignal @the underground signal thats paired with this one.

---@alias InOutDirection "'in'"|"'out'"

TunnelPortals.CreateGlobals = function()
    global.tunnelPortals = global.tunnelPortals or {}
    global.tunnelPortals.portals = global.tunnelPortals.portals or {} ---@type table<int,Portal>
end

TunnelPortals.OnLoad = function()
    local portalEntityNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelPortalPlacedPlacementEntityNames) do
        table.insert(portalEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, "TunnelPortals.OnBuiltEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "TunnelPortals.OnPreMinedEntity", TunnelPortals.OnPreMinedEntity, "TunnelPortals.OnPreMinedEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "TunnelPortals.OnPreMinedEntity", TunnelPortals.OnPreMinedEntity, "TunnelPortals.OnPreMinedEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "TunnelPortals.OnDiedEntity", TunnelPortals.OnDiedEntity, "TunnelPortals.OnDiedEntity", portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "TunnelPortals.OnDiedEntity", TunnelPortals.OnDiedEntity, "TunnelPortals.OnDiedEntity", portalEntityNames_Filter)

    local portalEntityGhostNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelPortalPlacedPlacementEntityNames) do
        table.insert(portalEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, "TunnelPortals.OnBuiltEntityGhost", portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, "TunnelPortals.OnBuiltEntityGhost", portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, "TunnelPortals.OnBuiltEntityGhost", portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_player_rotated_entity, "TunnelPortals.OnPlayerRotatedEntity", TunnelPortals.OnPlayerRotatedEntity)

    Interfaces.RegisterInterface("TunnelPortals.On_TunnelCompleted", TunnelPortals.On_TunnelCompleted)
    Interfaces.RegisterInterface("TunnelPortals.On_TunnelRemoved", TunnelPortals.On_TunnelRemoved)
    Interfaces.RegisterInterface("TunnelPortals.CloseEntranceSignalForManagedTrain", TunnelPortals.CloseEntranceSignalForManagedTrain)
    Interfaces.RegisterInterface("TunnelPortals.OpenEntranceSignalForManagedTrain", TunnelPortals.OpenEntranceSignalForManagedTrain)
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

---@param placementEntity LuaEntity
---@param placer EntityBuildPlacer
---@return boolean
TunnelPortals.PlacementTunnelPortalBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface
    local orientation = Utils.DirectionToOrientation(directionValue)
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.entranceFromCenter}))

    if not TunnelCommon.IsPlacementOnRailGrid(placementEntity) then
        TunnelCommon.UndoInvalidTunnelPartPlacement(placementEntity, placer, true)
        return
    end

    placementEntity.destroy()
    local abovePlacedPortal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
    abovePlacedPortal.rotatable = false -- Only stops players from rotating the placed entity, not editor mode. We track for editor use.
    local portal = {
        id = abovePlacedPortal.unit_number,
        entity = abovePlacedPortal,
        entityDirection = directionValue,
        portalRailEntities = {},
        entranceDistanceFromCenter = math.abs(SetupValues.entranceFromCenter),
        portalEntrancePosition = Utils.ApplyOffsetToPosition(abovePlacedPortal.position, Utils.RotatePositionAround0(abovePlacedPortal.orientation, {x = 0, y = 0 - math.abs(SetupValues.entranceFromCenter)}))
    }
    global.tunnelPortals.portals[portal.id] = portal

    local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1}))
    local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
    for _ = 1, SetupValues.straightRailCountFromEntrance do
        local placedRail = aboveSurface.create_entity {name = "railway_tunnel-portal_rail-on_map", position = nextRailPos, force = force, direction = directionValue}
        placedRail.destructible = false
        portal.portalRailEntities[placedRail.unit_number] = placedRail
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end

    local tunnelComplete, tunnelPortals, tunnelSegments = TunnelPortals.CheckTunnelCompleteFromPortal(abovePlacedPortal, placer, portal)
    if not tunnelComplete then
        return
    end

    Interfaces.Call("Tunnel.CompleteTunnel", tunnelPortals, tunnelSegments)
end

---@param startingTunnelPortalEntity LuaEntity
---@param placer EntityBuildPlacer
---@param portal Portal
---@return boolean, LuaEntity[], LuaEntity[]
TunnelPortals.CheckTunnelCompleteFromPortal = function(startingTunnelPortalEntity, placer, portal)
    local directionValue, orientation = startingTunnelPortalEntity.direction, Utils.DirectionToOrientation(startingTunnelPortalEntity.direction)
    local startingTunnelPartPoint = Utils.ApplyOffsetToPosition(startingTunnelPortalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = -1 + portal.entranceDistanceFromCenter}))
    return TunnelCommon.CheckTunnelPartsInDirectionAndGetAllParts(startingTunnelPortalEntity, startingTunnelPartPoint, directionValue, placer)
end

---@param portalEntities LuaEntity[]
---@param force LuaForce
---@param aboveSurface LuaSurface
---@return Portal[]
TunnelPortals.On_TunnelCompleted = function(portalEntities, force, aboveSurface)
    local portals = {}

    for _, portalEntity in pairs(portalEntities) do
        local portal = global.tunnelPortals.portals[portalEntity.unit_number]
        table.insert(portals, portal)
        local directionValue = portalEntity.direction
        local orientation = Utils.DirectionToOrientation(directionValue)

        -- Add the invisble rails to connect the tunnel portal's normal rails to the adjoining tunnel segment.
        local entracePos = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.entranceFromCenter}))
        local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1 + (SetupValues.straightRailCountFromEntrance * 2)}))
        local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement.
        portal.tunnelRailEntities = {}
        for _ = 1, SetupValues.invisibleRailCountFromEntrance do
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail-on_map_tunnel", position = nextRailPos, force = force, direction = directionValue}
            placedRail.destructible = false
            portal.tunnelRailEntities[placedRail.unit_number] = placedRail
            nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
        end

        -- Add the signals at the entrance to the tunnel.
        local entrySignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-internal_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = -1.5, y = SetupValues.entrySignalsDistance})),
            force = force,
            direction = directionValue
        }
        entrySignalInEntity.destructible = false
        local entrySignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-internal_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 1.5, y = SetupValues.entrySignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        portal.entrySignals = {
            ["in"] = {
                id = entrySignalInEntity.unit_number,
                entity = entrySignalInEntity,
                portal = portal,
                direction = "in"
            },
            ["out"] = {
                id = entrySignalOutEntity.unit_number,
                entity = entrySignalOutEntity,
                portal = portal,
                direction = "out"
            }
        }

        -- Add the signals that mark the end of the usable portal.
        local endSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = -1.5, y = SetupValues.endSignalsDistance})),
            force = force,
            direction = directionValue
        }
        local endSignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 1.5, y = SetupValues.endSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        portal.endSignals = {
            ["in"] = {
                id = endSignalInEntity.unit_number,
                entity = endSignalInEntity,
                portal = portal,
                direction = "in"
            },
            ["out"] = {
                id = endSignalOutEntity.unit_number,
                entity = endSignalOutEntity,
                portal = portal,
                direction = "out"
            }
        }
        Interfaces.Call("Tunnel.RegisterEndSignal", portal.endSignals["in"])

        -- Add blocking loco and extra signals after where the END signals are at the very end of the portal. These make the END signals go red and stop paths reserving across the track.
        local farInvisibleSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = -1.5, y = SetupValues.farInvisibleSignalsDistance})),
            force = force,
            direction = directionValue
        }
        local farInvisibleSignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 1.5, y = SetupValues.farInvisibleSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        local endSignalBlockingLocomotiveEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_blocking_locomotive",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.endSignalBlockingLocomotiveDistance})),
            force = global.force.tunnelForce,
            direction = Utils.LoopDirectionValue(directionValue + 2)
        }
        endSignalBlockingLocomotiveEntity.train.schedule = {
            current = 1,
            records = {
                {
                    rail = aboveSurface.find_entity("railway_tunnel-invisible_rail-on_map_tunnel", Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.endSignalBlockingLocomotiveDistance + 1.5})))
                }
            }
        }
        endSignalBlockingLocomotiveEntity.train.manual_mode = false
        endSignalBlockingLocomotiveEntity.destructible = false
        portal.tunnelOtherEntities = {
            [farInvisibleSignalInEntity.unit_number] = farInvisibleSignalInEntity,
            [farInvisibleSignalOutEntity.unit_number] = farInvisibleSignalOutEntity,
            [endSignalBlockingLocomotiveEntity.unit_number] = endSignalBlockingLocomotiveEntity
        }

        -- Add the entranceUsageDetectorEntity to the entrance end of the portal. This is directly in line with the signals and will never quote be touched by a train stopping at the signal if approaching.
        --portal.entranceUsageDetectorEntity = aboveSurface.create_entity() --TODO: this is where the blocker WIP got up to.

        portal.trainManagersClosingEntranceSignal = {}
    end

    portals[1].entrySignals["in"].entity.connect_neighbour {wire = defines.wire_type.red, target_entity = portals[2].entrySignals["in"].entity}
    TunnelPortals.LinkRailSignalsToCloseWhenOtherIsntOpen(portals[1].entrySignals["in"].entity, "signal-1", "signal-2")
    TunnelPortals.LinkRailSignalsToCloseWhenOtherIsntOpen(portals[2].entrySignals["in"].entity, "signal-2", "signal-1")

    return portals
end

---@param railSignalEntity LuaEntity
---@param nonGreenSignalOutputName string @Virtual signal name to be output to the cirtuit network when the signal state isn't green.
---@param closeOnSignalName string @Virtual signal name that triggers the singal state to be closed when its greater than 0 on the circuit network.
TunnelPortals.LinkRailSignalsToCloseWhenOtherIsntOpen = function(railSignalEntity, nonGreenSignalOutputName, closeOnSignalName)
    local controlBehavior = railSignalEntity.get_or_create_control_behavior() ---@type LuaRailSignalControlBehavior
    controlBehavior.read_signal = true
    controlBehavior.red_signal = {type = "virtual", name = nonGreenSignalOutputName}
    controlBehavior.orange_signal = {type = "virtual", name = nonGreenSignalOutputName}
    controlBehavior.close_signal = true
    controlBehavior.circuit_condition = {condition = {first_signal = {type = "virtual", name = closeOnSignalName}, comparator = ">", constant = 0}, fulfilled = true}
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

    if not TunnelCommon.IsPlacementOnRailGrid(createdEntity) then
        TunnelCommon.UndoInvalidTunnelPartPlacement(createdEntity, placer, false)
        return
    end
end

TunnelPortals.OnPreMinedEntity = function(event)
    local minedEntity = event.entity
    if not minedEntity.valid or TunnelCommon.tunnelPortalPlacedPlacementEntityNames[minedEntity.name] == nil then
        return
    end
    local portal = global.tunnelPortals.portals[minedEntity.unit_number]
    if portal == nil then
        return
    end

    local miner = event.robot -- Will be nil for player mined.
    if miner == nil and event.player_index ~= nil then
        miner = game.get_player(event.player_index)
    end

    if portal.tunnel == nil then
        TunnelPortals.EntityRemoved(portal)
    else
        if Interfaces.Call("Tunnel.GetTunnelsUsageEntry", portal.tunnel) then
            TunnelCommon.EntityErrorMessage(miner, "Can not mine tunnel portal while train is using tunnel", minedEntity.surface, minedEntity.position)
            TunnelPortals.ReplacePortalEntity(portal)
        else
            Interfaces.Call("Tunnel.RemoveTunnel", portal.tunnel)
            TunnelPortals.EntityRemoved(portal)
        end
    end
end

---@param oldPortal Portal
TunnelPortals.ReplacePortalEntity = function(oldPortal)
    local centerPos, force, lastUser, directionValue, aboveSurface, entityName = oldPortal.entity.position, oldPortal.entity.force, oldPortal.entity.last_user, oldPortal.entity.direction, oldPortal.entity.surface, oldPortal.entity.name
    oldPortal.entity.destroy()

    local newPortalEntity = aboveSurface.create_entity {name = entityName, position = centerPos, direction = directionValue, force = force, player = lastUser}
    local newPortal = {
        id = newPortalEntity.unit_number,
        entityDirection = oldPortal.entityDirection,
        entity = newPortalEntity,
        endSignals = oldPortal.endSignals,
        entrySignals = oldPortal.entrySignals,
        tunnel = oldPortal.tunnel,
        portalRailEntities = oldPortal.portalRailEntities,
        tunnelRailEntities = oldPortal.tunnelRailEntities,
        tunnelOtherEntities = oldPortal.tunnelOtherEntities,
        trainManagersClosingEntranceSignal = oldPortal.trainManagersClosingEntranceSignal,
        entranceSignalBlockingTrainEntity = oldPortal.entranceSignalBlockingTrainEntity,
        entranceDistanceFromCenter = oldPortal.entranceDistanceFromCenter,
        portalEntrancePosition = oldPortal.portalEntrancePosition
    }

    -- Update the signals ref back to portal if the signals exist.
    if newPortal.endSignals ~= nil then
        newPortal.endSignals["in"].portal = newPortal
        newPortal.endSignals["out"].portal = newPortal
        newPortal.entrySignals["in"].portal = newPortal
        newPortal.entrySignals["out"].portal = newPortal
    end
    global.tunnelPortals.portals[newPortal.id] = newPortal
    global.tunnelPortals.portals[oldPortal.id] = nil
    Interfaces.Call("Tunnel.On_PortalReplaced", newPortal.tunnel, oldPortal, newPortal)
end

---@param portal Portal
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
TunnelPortals.EntityRemoved = function(portal, killForce, killerCauseEntity)
    TunnelCommon.DestroyCarriagesOnRailEntityList(portal.portalRailEntities, killForce, killerCauseEntity)
    for _, railEntity in pairs(portal.portalRailEntities) do
        railEntity.destroy()
    end
    global.tunnelPortals.portals[portal.id] = nil
end

---@param portal Portal
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
TunnelPortals.On_TunnelRemoved = function(portal, killForce, killerCauseEntity)
    TunnelCommon.DestroyCarriagesOnRailEntityList(portal.tunnelRailEntities, killForce, killerCauseEntity)
    portal.tunnel = nil
    if portal.entranceSignalBlockingTrainEntity ~= nil then
        portal.entranceSignalBlockingTrainEntity.destroy()
        portal.entranceSignalBlockingTrainEntity = nil
    end
    for _, otherEntity in pairs(portal.tunnelOtherEntities) do
        otherEntity.destroy()
    end
    portal.tunnelOtherEntities = nil
    for _, railEntity in pairs(portal.tunnelRailEntities) do
        railEntity.destroy()
    end
    portal.tunnelRailEntities = nil
    for _, entrySignal in pairs(portal.entrySignals) do
        entrySignal.entity.destroy()
    end
    portal.entrySignals = nil
    for _, endSignal in pairs(portal.endSignals) do
        Interfaces.Call("Tunnel.DeregisterEndSignal", endSignal)
        endSignal.entity.destroy()
    end
    portal.endSignals = nil
    portal.trainManagersClosingEntranceSignal = nil
end

TunnelPortals.OnDiedEntity = function(event)
    local diedEntity, killerForce, killerCauseEntity = event.entity, event.force, event.cause -- The killer variables will be nil in some cases.
    if not diedEntity.valid or TunnelCommon.tunnelPortalPlacedPlacementEntityNames[diedEntity.name] == nil then
        return
    end
    local portal = global.tunnelPortals.portals[diedEntity.unit_number]
    if portal == nil then
        return
    end

    if portal.tunnel ~= nil then
        Interfaces.Call("Tunnel.RemoveTunnel", portal.tunnel)
    end
    TunnelPortals.EntityRemoved(portal, killerForce, killerCauseEntity)
end

---@param portal Portal
---@return LuaEntity @The placed blocking locomotive entity.
TunnelPortals.AddEntranceSignalBlockingLocomotive = function(portal)
    -- Place a blocking loco just inside the portal. Have a valid path and without fuel to avoid path finding penalties.
    local portalEntity = portal.entity
    local aboveSurface, directionValue = portal.tunnel.aboveSurface, portalEntity.direction
    local orientation = Utils.DirectionToOrientation(directionValue)
    local entranceSignalBlockingTrainEntity =
        aboveSurface.create_entity {
        name = "railway_tunnel-tunnel_portal_blocking_locomotive",
        position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.entrySignalBlockingLocomotiveDistance})),
        force = global.force.tunnelForce,
        direction = Utils.LoopDirectionValue(directionValue + 4)
    }
    local pos = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.entrySignalBlockingLocomotiveDistance + 1.5}))
    entranceSignalBlockingTrainEntity.train.schedule = {
        current = 1,
        records = {
            {
                rail = aboveSurface.find_entity("railway_tunnel-portal_rail-on_map", pos)
            }
        }
    }
    entranceSignalBlockingTrainEntity.train.manual_mode = false
    entranceSignalBlockingTrainEntity.destructible = false -- This will stop unexpected trains entering the tunnel. Suitable in the short term.
    return entranceSignalBlockingTrainEntity
end

---@param portal Portal
---@param managedTrain ManagedTrain
TunnelPortals.CloseEntranceSignalForManagedTrain = function(portal, managedTrain)
    -- This function should handle multiple trains at one time using the tunnel, should it occur. Thats what the checking complexity is for.
    if portal.trainManagersClosingEntranceSignal[managedTrain.id] ~= nil then
        return
    end

    -- Record if we will need to create the entity before we record this managedTrain
    local blockingLocoAlreadyExists = false
    if not Utils.IsTableEmpty(portal.trainManagersClosingEntranceSignal) then
        blockingLocoAlreadyExists = true
    end
    portal.trainManagersClosingEntranceSignal[managedTrain.id] = managedTrain
    if blockingLocoAlreadyExists then
        return
    end

    local entranceSignalBlockingTrainEntity = TunnelPortals.AddEntranceSignalBlockingLocomotive(portal)
    portal.entranceSignalBlockingTrainEntity = entranceSignalBlockingTrainEntity
end

---@param portal Portal
---@param managedTrain ManagedTrain
TunnelPortals.OpenEntranceSignalForManagedTrain = function(portal, managedTrain)
    -- This function should handle multiple trains at one time using the tunnel, should it occur. Thats what the checking complexity is for.
    if portal.trainManagersClosingEntranceSignal[managedTrain.id] == nil then
        return
    end
    portal.trainManagersClosingEntranceSignal[managedTrain.id] = nil
    if Utils.IsTableEmpty(portal.trainManagersClosingEntranceSignal) then
        portal.entranceSignalBlockingTrainEntity.destroy()
        portal.entranceSignalBlockingTrainEntity = nil
    end
end

TunnelPortals.OnPlayerRotatedEntity = function(event)
    -- Just check if the player (editor mode) rotated a placed portal entity.
    if TunnelCommon.tunnelPortalPlacedEntityNames[event.entity.name] == nil then
        return
    end
    -- Reverse the rotation so other code logic still works. Also would mess up the graphics if not reversed.
    event.entity.direction = event.previous_direction
    game.get_player(event.player_index).print("Don't try and rotate placed rail tunnel portals.", Colors.red)
end

return TunnelPortals
