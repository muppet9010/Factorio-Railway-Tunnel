local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local Common = require("scripts/common")
local TunnelPortalPlacedPlacementEntityNames, TunnelSignalDirection, TunnelPortalPlacedEntityNames, TunnelUsageParts = Common.TunnelPortalPlacedPlacementEntityNames, Common.TunnelSignalDirection, Common.TunnelPortalPlacedEntityNames, Common.TunnelUsageParts
local TunnelPortals = {}
local Colors = require("utility/colors")
local EventScheduler = require("utility/event-scheduler")

local SetupValues = {
    -- Tunnels distances are from the portal position (center).
    entranceFromCenter = -25,
    entranceUsageDetectorEntityDistance = -24, -- Perfect distance that it isn't triggered if the train stops at the signals naturally.
    entrySignalsDistance = -23.5,
    entrySignalBlockingLocomotiveDistance = -21.5,
    enteringTunnelDetectorEntityDistance = 9.5, -- When the collision box of a standard train goes off the end of visible track at its current value.
    endSignalsDistance = 19.5,
    endSignalBlockingLocomotiveDistance = 20.5,
    farInvisibleSignalsDistance = 23.5,
    invisibleRailCountFromEntrance = 8,
    straightRailCountFromEntrance = 17
}

---@class Portal
---@field id uint @unit_number of the placed tunnel portal entity.
---@field entity LuaEntity @
---@field entityDirection defines.direction @the expected direction of the portal. Can't block Editor users from rotating the portal entity so need to be able to check if its changed.
---@field endSignals table<TunnelSignalDirection, PortalEndSignal> @These are the inner locked red signals that a train paths at to enter the tunnel.
---@field entrySignals table<TunnelSignalDirection, PortalEntrySignal> @These are the signals that are visible to the wider train network and player. The portals 2 IN entry signals are connected by red wire. The portals OUT direction signals are synced with their corrisponding underground OUT signals every tick.
---@field tunnel Tunnel
---@field portalRailEntities table<UnitNumber, LuaEntity> @table of the rail entities that are part of the portal itself.
---@field tunnelRailEntities table<UnitNumber, LuaEntity> @table of the rail entities that are part of the connected tunnel for the portal.
---@field tunnelOtherEntities table<UnitNumber, LuaEntity> @table of the non rail entities that are part of the connected tunnel for the portal. Will be deleted before the tunnelRailEntities.
---@field entranceDistanceFromCenter uint @the distance in tiles of the entrance from the portal center.
---@field portalEntrancePosition Position @the position of the entrance to the portal.
---@field entranceUsageDetectorEntity LuaEntity @hidden entity on the entrance to the portal that's death signifies a train is coming on to the portal's rails unexpectedly.
---@field enteringTunnelDetectorEntity LuaEntity @hidden entity towards the back of the portal that's death signifies a train is at the point of entering the tunnel now.

---@class PortalSignal
---@field id uint @unit_number of this signal.
---@field direction TunnelSignalDirection
---@field entity LuaEntity
---@field portal Portal

---@class PortalEndSignal : PortalSignal

---@class PortalEntrySignal : PortalSignal
---@field undergroundSignalPaired UndergroundSignal @the underground signal thats paired with this one.

TunnelPortals.CreateGlobals = function()
    global.tunnelPortals = global.tunnelPortals or {}
    global.tunnelPortals.portals = global.tunnelPortals.portals or {} ---@type table<int,Portal>
    global.tunnelPortals.entranceUsageDetectorEntityIdToPortal = global.tunnelPortals.entranceUsageDetectorEntityIdToPortal or {} ---@type table<UnitNumber, Portal> @Used to be able to identify the portal when the entrance entity is killed.
    global.tunnelPortals.enteringTunnelDetectorEntityIdToPortal = global.tunnelPortals.enteringTunnelDetectorEntityIdToPortal or {} ---@type table<UnitNumber, Portal> @Used to be able to identify the portal when the entering tunnel entity is killed.
end

TunnelPortals.OnLoad = function()
    local portalEntityNames_Filter = {}
    for _, name in pairs(TunnelPortalPlacedPlacementEntityNames) do
        table.insert(portalEntityNames_Filter, {filter = "name", name = name})
    end

    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "TunnelPortals.OnBuiltEntity", TunnelPortals.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "TunnelPortals.OnPreMinedEntity", TunnelPortals.OnPreMinedEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "TunnelPortals.OnPreMinedEntity", TunnelPortals.OnPreMinedEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "TunnelPortals.OnDiedEntity", TunnelPortals.OnDiedEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "TunnelPortals.OnDiedEntity", TunnelPortals.OnDiedEntity, portalEntityNames_Filter)

    local portalEntityGhostNames_Filter = {}
    for _, name in pairs(TunnelPortalPlacedPlacementEntityNames) do
        table.insert(portalEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelPortals.OnBuiltEntityGhost", TunnelPortals.OnBuiltEntityGhost, portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_player_rotated_entity, "TunnelPortals.OnPlayerRotatedEntity", TunnelPortals.OnPlayerRotatedEntity)

    Interfaces.RegisterInterface("TunnelPortals.On_PreTunnelCompleted", TunnelPortals.On_PreTunnelCompleted)
    Interfaces.RegisterInterface("TunnelPortals.On_TunnelRemoved", TunnelPortals.On_TunnelRemoved)
    Interfaces.RegisterInterface("TunnelPortals.RemoveEntranceUsageDetectorEntityFromPortal", TunnelPortals.RemoveEntranceUsageDetectorEntityFromPortal)
    Interfaces.RegisterInterface("TunnelPortals.AddEntranceUsageDetectorEntityToPortal", TunnelPortals.AddEntranceUsageDetectorEntityToPortal)
    Interfaces.RegisterInterface("TunnelPortals.AddEnteringTunnelDetectorEntityToPortal", TunnelPortals.AddEnteringTunnelDetectorEntityToPortal)

    local trainBlocker1x1_Filter = {{filter = "name", name = "railway_tunnel-train_blocker_1x1"}}
    EventScheduler.RegisterScheduledEventType("TunnelPortals.TryCreateEntranceUsageDetectorEntityAtPosition", TunnelPortals.TryCreateEntranceUsageDetectorEntityAtPosition)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "TunnelPortals.OnDiedEntityTrainBlocker", TunnelPortals.OnDiedEntityTrainBlocker, trainBlocker1x1_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "TunnelPortals.OnDiedEntityTrainBlocker", TunnelPortals.OnDiedEntityTrainBlocker, trainBlocker1x1_Filter)
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
TunnelPortals.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or TunnelPortalPlacedPlacementEntityNames[createdEntity.name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    TunnelPortals.PlacementTunnelPortalBuilt(createdEntity, placer)
end

---@param placementEntity LuaEntity
---@param placer EntityActioner
---@return boolean
TunnelPortals.PlacementTunnelPortalBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface
    local orientation = Utils.DirectionToOrientation(directionValue)
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.entranceFromCenter}))

    if not Common.IsPlacementOnRailGrid(placementEntity) then
        Common.UndoInvalidTunnelPartPlacement(placementEntity, placer, true)
        return
    end

    placementEntity.destroy()
    local portalEntity = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
    portalEntity.rotatable = false -- Only stops players from rotating the placed entity, not editor mode. We track for editor use.
    ---@type Portal
    local portal = {
        id = portalEntity.unit_number,
        entity = portalEntity,
        entityDirection = directionValue,
        portalRailEntities = {},
        entranceDistanceFromCenter = math.abs(SetupValues.entranceFromCenter),
        portalEntrancePosition = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(portalEntity.orientation, {x = 0, y = 0 - math.abs(SetupValues.entranceFromCenter)}))
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

    -- Add the signals at the entrance to the tunnel.
    ---@type LuaEntity
    local entrySignalInEntity =
        aboveSurface.create_entity {
        name = "railway_tunnel-internal_signal-not_on_map",
        position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = -1.5, y = SetupValues.entrySignalsDistance})),
        force = force,
        direction = directionValue
    }
    entrySignalInEntity.destructible = false
    ---@type LuaEntity
    local entrySignalOutEntity =
        aboveSurface.create_entity {
        name = "railway_tunnel-internal_signal-not_on_map",
        position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 1.5, y = SetupValues.entrySignalsDistance})),
        force = force,
        direction = Utils.LoopDirectionValue(directionValue + 4)
    }
    portal.entrySignals = {
        [TunnelSignalDirection.inSignal] = {
            id = entrySignalInEntity.unit_number,
            entity = entrySignalInEntity,
            portal = portal,
            direction = TunnelSignalDirection.inSignal
        },
        [TunnelSignalDirection.outSignal] = {
            id = entrySignalOutEntity.unit_number,
            entity = entrySignalOutEntity,
            portal = portal,
            direction = TunnelSignalDirection.outSignal
        }
    }
    -- Set the portal to be closed signals initially.
    entrySignalInEntity.connect_neighbour {wire = defines.wire_type.green, target_entity = entrySignalOutEntity}
    TunnelPortals.ClosePortalEntrySignalAsNoTunnel(entrySignalInEntity)

    -- We want to stop trains driving on to a portal when there is no tunnel.
    TunnelPortals.AddEntranceUsageDetectorEntityToPortal(portal, false)

    local tunnelComplete, tunnelPortals, tunnelSegments = TunnelPortals.CheckTunnelCompleteFromPortal(portalEntity, placer, portal)
    if not tunnelComplete then
        return
    end

    Interfaces.Call("Tunnel.CompleteTunnel", tunnelPortals, tunnelSegments)
end

---@param entrySignalInEntity LuaEntity
TunnelPortals.ClosePortalEntrySignalAsNoTunnel = function(entrySignalInEntity)
    local controlBehavior = entrySignalInEntity.get_or_create_control_behavior() ---@type LuaRailSignalControlBehavior
    controlBehavior.read_signal = false
    controlBehavior.close_signal = true
    controlBehavior.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-0"}, comparator = "=", constant = 0}, fulfilled = true}
end

---@param startingTunnelPortalEntity LuaEntity
---@param placer EntityActioner
---@param portal Portal
---@return boolean @Direction is completed successfully.
---@return LuaEntity[] @Tunnel portal entities.
---@return LuaEntity[] @Tunnel segment entities.
TunnelPortals.CheckTunnelCompleteFromPortal = function(startingTunnelPortalEntity, placer, portal)
    local tunnelPortalEntities, tunnelSegmentEntities, directionValue, orientation = {}, {}, startingTunnelPortalEntity.direction, Utils.DirectionToOrientation(startingTunnelPortalEntity.direction)
    local startingTunnelPartPoint = Utils.ApplyOffsetToPosition(startingTunnelPortalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = -1 + portal.entranceDistanceFromCenter}))
    local directionComplete = Common.CheckTunnelPartsInDirectionAndGetAllParts(startingTunnelPortalEntity, startingTunnelPartPoint, directionValue, placer, tunnelPortalEntities, tunnelSegmentEntities)
    return directionComplete, tunnelPortalEntities, tunnelSegmentEntities
end

---@param portalEntities LuaEntity[]
---@param force LuaForce
---@param aboveSurface LuaSurface
---@return Portal[]
TunnelPortals.On_PreTunnelCompleted = function(portalEntities, force, aboveSurface)
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
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail-on_map_tunnel", position = nextRailPos, force = force, direction = directionValue} ---@type LuaEntity
            placedRail.destructible = false
            portal.tunnelRailEntities[placedRail.unit_number] = placedRail
            nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
        end

        -- Add the signals that mark the END of the usable portal.
        ---@type LuaEntity
        local endSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = -1.5, y = SetupValues.endSignalsDistance})),
            force = force,
            direction = directionValue
        }
        ---@type LuaEntity
        local endSignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 1.5, y = SetupValues.endSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        portal.endSignals = {
            [TunnelSignalDirection.inSignal] = {
                id = endSignalInEntity.unit_number,
                entity = endSignalInEntity,
                portal = portal,
                direction = TunnelSignalDirection.inSignal
            },
            [TunnelSignalDirection.outSignal] = {
                id = endSignalOutEntity.unit_number,
                entity = endSignalOutEntity,
                portal = portal,
                direction = TunnelSignalDirection.outSignal
            }
        }
        Interfaces.Call("Tunnel.RegisterEndSignal", portal.endSignals[TunnelSignalDirection.inSignal])

        -- Add blocking loco and extra signals after where the END signals are at the very end of the portal. These make the END signals go red and stop paths reserving across the track.
        ---@type LuaEntity
        local farInvisibleSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = -1.5, y = SetupValues.farInvisibleSignalsDistance})),
            force = force,
            direction = directionValue
        }
        ---@type LuaEntity
        local farInvisibleSignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 1.5, y = SetupValues.farInvisibleSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        ---@type LuaEntity
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

        -- Add the entering tunnel detector entity.
        TunnelPortals.AddEnteringTunnelDetectorEntityToPortal(portal)
    end

    portals[1].entrySignals[TunnelSignalDirection.inSignal].entity.connect_neighbour {wire = defines.wire_type.red, target_entity = portals[2].entrySignals[TunnelSignalDirection.inSignal].entity}
    TunnelPortals.LinkRailSignalsToCloseWhenOtherIsntOpen(portals[1].entrySignals[TunnelSignalDirection.inSignal].entity, "signal-1", "signal-2")
    TunnelPortals.LinkRailSignalsToCloseWhenOtherIsntOpen(portals[2].entrySignals[TunnelSignalDirection.inSignal].entity, "signal-2", "signal-1")

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

---@param event on_built_entity|on_robot_built_entity|script_raised_built
TunnelPortals.OnBuiltEntityGhost = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or createdEntity.type ~= "entity-ghost" or TunnelPortalPlacedPlacementEntityNames[createdEntity.ghost_name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end

    if not Common.IsPlacementOnRailGrid(createdEntity) then
        Common.UndoInvalidTunnelPartPlacement(createdEntity, placer, false)
        return
    end
end

---@param event on_pre_player_mined_item|on_robot_pre_mined
TunnelPortals.OnPreMinedEntity = function(event)
    local minedEntity = event.entity
    if not minedEntity.valid or TunnelPortalPlacedPlacementEntityNames[minedEntity.name] == nil then
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
            Common.EntityErrorMessage(miner, "Can not mine tunnel portal while train is using tunnel", minedEntity.surface, minedEntity.position)
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
        entranceUsageDetectorEntity = oldPortal.entranceUsageDetectorEntity,
        enteringTunnelDetectorEntity = oldPortal.enteringTunnelDetectorEntity,
        entranceDistanceFromCenter = oldPortal.entranceDistanceFromCenter,
        portalEntrancePosition = oldPortal.portalEntrancePosition
    }

    -- Update the signals ref back to portal if the signals exist.
    if newPortal.endSignals ~= nil then
        newPortal.endSignals[TunnelSignalDirection.inSignal].portal = newPortal
        newPortal.endSignals[TunnelSignalDirection.outSignal].portal = newPortal
        newPortal.entrySignals[TunnelSignalDirection.inSignal].portal = newPortal
        newPortal.entrySignals[TunnelSignalDirection.outSignal].portal = newPortal
    end
    global.tunnelPortals.portals[newPortal.id] = newPortal
    global.tunnelPortals.portals[oldPortal.id] = nil
    Interfaces.Call("Tunnel.On_PortalReplaced", newPortal.tunnel, oldPortal, newPortal)
end

---@param portal Portal
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
TunnelPortals.EntityRemoved = function(portal, killForce, killerCauseEntity)
    TunnelPortals.RemoveEntranceUsageDetectorEntityFromPortal(portal)
    Common.DestroyCarriagesOnRailEntityList(portal.portalRailEntities, killForce, killerCauseEntity)
    for _, entrySignal in pairs(portal.entrySignals) do
        if entrySignal.entity.valid then
            entrySignal.entity.destroy()
        end
    end
    portal.entrySignals = nil
    for _, railEntity in pairs(portal.portalRailEntities) do
        if railEntity.valid then
            railEntity.destroy()
        end
    end
    portal.portalRailEntities = nil
    global.tunnelPortals.portals[portal.id] = nil
end

---@param portal Portal
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
TunnelPortals.On_TunnelRemoved = function(portal, killForce, killerCauseEntity)
    Common.DestroyCarriagesOnRailEntityList(portal.tunnelRailEntities, killForce, killerCauseEntity)
    portal.tunnel = nil
    for _, otherEntity in pairs(portal.tunnelOtherEntities) do
        if otherEntity.valid then
            otherEntity.destroy()
        end
    end
    portal.tunnelOtherEntities = nil
    for _, railEntity in pairs(portal.tunnelRailEntities) do
        if railEntity.valid then
            railEntity.destroy()
        end
    end
    portal.tunnelRailEntities = nil
    for _, endSignal in pairs(portal.endSignals) do
        if endSignal.entity.valid then
            Interfaces.Call("Tunnel.DeregisterEndSignal", endSignal)
            endSignal.entity.destroy()
        end
    end
    portal.endSignals = nil
    TunnelPortals.RemoveEnteringTunnelDetectorEntityFromPortal(portal)

    -- Close the entrance signals for the portals.
    if portal.entrySignals[TunnelSignalDirection.inSignal].entity.valid then
        TunnelPortals.ClosePortalEntrySignalAsNoTunnel(portal.entrySignals[TunnelSignalDirection.inSignal].entity)
    end
end

---@param event on_entity_died|script_raised_destroy
TunnelPortals.OnDiedEntity = function(event)
    local diedEntity, killerForce, killerCauseEntity = event.entity, event.force, event.cause -- The killer variables will be nil in some cases.
    if not diedEntity.valid or TunnelPortalPlacedPlacementEntityNames[diedEntity.name] == nil then
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

-- Occurs when a train tries to pass through the border of a portal, when entering and exiting.
---@param event on_entity_died|script_raised_destroy
TunnelPortals.OnDiedEntityTrainBlocker = function(event)
    local diedEntity, carriageEnteringPortalTrack = event.entity, event.cause -- carriageEnteringPortalTrack can be nil for non train ramming deaths.
    if not diedEntity.valid or diedEntity.name ~= "railway_tunnel-train_blocker_1x1" then
        return
    end

    local entranceUsageDetectorEntityPortal = global.tunnelPortals.entranceUsageDetectorEntityIdToPortal[diedEntity.unit_number]
    if entranceUsageDetectorEntityPortal ~= nil then
        TunnelPortals.EntranceUsageDetectorEntityDied(diedEntity, carriageEnteringPortalTrack, entranceUsageDetectorEntityPortal)
        return
    end

    local enteringTunnelDetectorEntityPortal = global.tunnelPortals.enteringTunnelDetectorEntityIdToPortal[diedEntity.unit_number]
    if enteringTunnelDetectorEntityPortal ~= nil then
        TunnelPortals.EnteringTunnelDetectorEntityDied(diedEntity, carriageEnteringPortalTrack, enteringTunnelDetectorEntityPortal)
        return
    end
end

---@param diedEntity LuaEntity
---@param carriageEnteringPortalTrack LuaEntity|nil
---@param portal Portal
TunnelPortals.EntranceUsageDetectorEntityDied = function(diedEntity, carriageEnteringPortalTrack, portal)
    -- Tidy up the entrance usage detector reference as in all cases it has been removed.
    portal.entranceUsageDetectorEntity = nil
    global.tunnelPortals.entranceUsageDetectorEntityIdToPortal[diedEntity.unit_number] = nil

    if carriageEnteringPortalTrack == nil then
        -- As there's no cause this should only occur when a script removes the entity. Try to return the detection entity and if the portal is being removed that will handle all scenarios.
        TunnelPortals.AddEntranceUsageDetectorEntityToPortal(portal, true)
        return
    end
    local train = carriageEnteringPortalTrack.train

    -- If no tunnel then portal is always closed.
    if portal.tunnel == nil then
        train.speed = 0
        TunnelPortals.AddEntranceUsageDetectorEntityToPortal(portal, true)
        rendering.draw_text {text = "No tunnel to utilise", surface = portal.entity.surface, target = portal.entrySignals[TunnelSignalDirection.inSignal].entity.position, time_to_live = 180, forces = {portal.entity.force}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
        return
    end

    -- Get any existing Managed Trains related to this train Id.
    local trainIdToManagedTrain = Interfaces.Call("TrainManagerStateFuncs.GetTrainIdsManagedTrainDetails", train.id) ---@type TrainIdToManagedTrain
    local managedTrain
    if trainIdToManagedTrain ~= nil then
        managedTrain = trainIdToManagedTrain.managedTrain
    end

    -- This train has reserved a tunnel somewhere so check if its this one.
    if managedTrain ~= nil then
        if managedTrain.tunnel.id == portal.tunnel.id then
            -- The train has reserved this tunnel.
            if trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.enteringTrain then
                -- Train had reserved the tunnel and is now trying to pass in to the tunnels entrance portal track. This is healthy activity.
                return
            elseif trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.leavingTrain or trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.leftTrain then
                -- Train has been using the tunnel and is now trying to pass out of the tunnels exit portal track. This is healthy activity.
                return
            else
                error("Train is crossing a tunnel portal's threshold while not in an expected state.\ntrainId: " .. train.id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. managedTrain.tunnel.id)
                return
            end
        else
            error("Train has entered one portal while it has a reservation on another.\ntrainId: " .. train.id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. managedTrain.tunnel.id)
            return
        end
    end

    -- There's already a train using this tunnel. So stop all trains at the entrance.
    if portal.tunnel.managedTrain ~= nil then
        train.speed = 0
        TunnelPortals.AddEntranceUsageDetectorEntityToPortal(portal, true)
        rendering.draw_text {text = "Tunnel in use", surface = portal.tunnel.aboveSurface, target = portal.entrySignals[TunnelSignalDirection.inSignal].entity.position, time_to_live = 180, forces = {portal.entity.force}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
        return
    end

    -- Is a scheduled train following its schedule, tunnel is free and this train has no tunnel reservations.
    if not train.manual_mode and train.state ~= defines.train_state.no_schedule then
        -- Portal's tunnel isn't reserved so this train can grab the portal.
        Interfaces.Call("TrainManager.RegisterTrainOnPortalTrack", train, portal)
        return
    end

    -- Train has a player in it so we assume its being actively driven, vs a coasting train with a player in it. We could only detect current player input, not the players intention.
    if #train.passengers ~= 0 then
        -- Tunnel is free so claim the portal tracks.
        Interfaces.Call("TrainManager.RegisterTrainOnPortalTrack", train, portal)
        return
    end

    -- Train is coasting so stop it at the border and put the detection entity back.
    train.speed = 0
    TunnelPortals.AddEntranceUsageDetectorEntityToPortal(portal, true)
    rendering.draw_text {text = "Unpowered trains can't use tunnels", surface = portal.tunnel.aboveSurface, target = portal.entrySignals[TunnelSignalDirection.inSignal].entity.position, time_to_live = 180, forces = {portal.entity.force}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
end

---@param diedEntity LuaEntity
---@param carriageEnteringPortalTrack LuaEntity|nil
---@param portal Portal
TunnelPortals.EnteringTunnelDetectorEntityDied = function(diedEntity, carriageEnteringPortalTrack, portal)
    -- Tidy up the entering tunnel detector reference as in all cases it has been removed.
    portal.enteringTunnelDetectorEntity = nil
    global.tunnelPortals.enteringTunnelDetectorEntityIdToPortal[diedEntity.unit_number] = nil

    if carriageEnteringPortalTrack == nil then
        -- As there's no cause this should only occur when a script removes the entity. Try to return the detection entity and if the portal is being removed that will handle all scenarios.
        TunnelPortals.AddEnteringTunnelDetectorEntityToPortal(portal)
        return
    end

    -- If no tunnel then this entity doesn't need to exist, so just ignore its death
    if portal.tunnel == nil then
        return
    end

    local train = carriageEnteringPortalTrack.train
    local trainIdToManagedTrain = Interfaces.Call("TrainManagerStateFuncs.GetTrainIdsManagedTrainDetails", train.id) ---@type TrainIdToManagedTrain
    local enteringManagedTrain = nil
    if trainIdToManagedTrain ~= nil then
        -- This train has reserved a tunnel somewhere, so get the ManagedTrain object.
        enteringManagedTrain = trainIdToManagedTrain.managedTrain
    end

    -- If the tunnel is already in use then this dictates outcome options.
    if portal.tunnel.managedTrain ~= nil then
        if enteringManagedTrain ~= nil and enteringManagedTrain.id == portal.tunnel.managedTrain.id then
            if trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.enteringTrain then
                -- This train is already entering the tunnel and has just overshot the end spot as going fast or something. This is fine.
                return
            elseif trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.portalTrackTrain then
                -- This is an upgrade from OnPortalTrack to Entering, skipping the approaching state.
                Interfaces.Call("TrainManager.TrainStartedEntering", train, portal)
                return
            end
        else
            -- Another train is using the tunnel, so stop this one as its a bad state.
            train.speed = 0
            train.manual_mode = true
            TunnelPortals.AddEnteringTunnelDetectorEntityToPortal(portal, true)
            rendering.draw_text {text = "Tunnel already in use", surface = portal.tunnel.aboveSurface, target = portal.entrySignals[TunnelSignalDirection.inSignal].entity.position, time_to_live = 180, forces = {portal.entity.force}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
            return
        end
    end

    -- Coasting trains are stopped from using the tunnel.
    if train.manual_mode and #train.passengers == 0 then
        train.speed = 0
        TunnelPortals.AddEnteringTunnelDetectorEntityToPortal(portal, true)
        rendering.draw_text {text = "Unpowered trains can't use tunnels", surface = portal.tunnel.aboveSurface, target = portal.entrySignals[TunnelSignalDirection.inSignal].entity.position, time_to_live = 180, forces = {portal.entity.force}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
        return
    end

    -- The train hasn't reserved the portal, but has ended up entering the tunnel regardless.
    Interfaces.Call("TrainManager.TrainStartedEntering", train, portal)
end

--- Will try and place the entrance detection entity now and if not possible will keep on trying each tick until either successful or a tunnel state setting stops the attempts. Is safe to call if the entity already exists as will just abort (initally or when in per tick loop).
---@param portal Portal
---@param retry boolean @If to retry next tick should it not be placable.
---@return LuaEntity @The entranceUsageDetectorEntity if successfully placed.
TunnelPortals.AddEntranceUsageDetectorEntityToPortal = function(portal, retry)
    local portalEntity = portal.entity
    if portalEntity == nil or not portalEntity.valid or portal.entranceUsageDetectorEntity ~= nil then
        return
    end
    local aboveSurface, directionValue = portal.entity.surface, portalEntity.direction
    local orientation = Utils.DirectionToOrientation(directionValue)
    local position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.entranceUsageDetectorEntityDistance}))
    return TunnelPortals.TryCreateEntranceUsageDetectorEntityAtPosition(nil, portal, aboveSurface, position, retry)
end

---@param event ScheduledEvent
---@param portal Portal
---@param aboveSurface LuaSurface
---@param position Position
---@param retry boolean @If to retry next tick should it not be placable.
---@return LuaEntity @The entranceUsageDetectorEntity if successfully placed.
TunnelPortals.TryCreateEntranceUsageDetectorEntityAtPosition = function(event, portal, aboveSurface, position, retry)
    local eventData
    if event ~= nil then
        eventData = event.data
        portal, aboveSurface, position, retry = eventData.portal, eventData.aboveSurface, eventData.position, eventData.retry
    end
    local portalEntity = portal.entity
    if portalEntity == nil or not portalEntity.valid or portal.entranceUsageDetectorEntity ~= nil then
        -- The portal has been removed, so we shouldn't add the detection entity back. Or another task has added the dector back and so we can stop.
        return
    end

    -- The left train will initially be within the collision box of where we want to place this. So check if it can be placed. For odd reasons the entity will "create" on top of a train and instantly be killed, so have to explicitly check.
    if aboveSurface.can_place_entity {name = "railway_tunnel-train_blocker_1x1", force = global.force.tunnelForce, position = position} then
        portal.entranceUsageDetectorEntity = aboveSurface.create_entity {name = "railway_tunnel-train_blocker_1x1", force = global.force.tunnelForce, position = position}
        global.tunnelPortals.entranceUsageDetectorEntityIdToPortal[portal.entranceUsageDetectorEntity.unit_number] = portal
        return portal.entranceUsageDetectorEntity
    elseif retry then
        -- Schedule this to be tried again next tick.
        local postbackData
        if eventData ~= nil then
            postbackData = eventData
        else
            postbackData = {portal = portal, aboveSurface = aboveSurface, position = position, retry = retry}
        end
        EventScheduler.ScheduleEventOnce(nil, "TunnelPortals.TryCreateEntranceUsageDetectorEntityAtPosition", portal.id, postbackData)
    end
end

---@param portal Portal
TunnelPortals.RemoveEntranceUsageDetectorEntityFromPortal = function(portal)
    if portal.entranceUsageDetectorEntity ~= nil then
        if portal.entranceUsageDetectorEntity.valid then
            global.tunnelPortals.entranceUsageDetectorEntityIdToPortal[portal.entranceUsageDetectorEntity.unit_number] = nil
            portal.entranceUsageDetectorEntity.destroy()
        end
        portal.entranceUsageDetectorEntity = nil
    end
end

---@param portal Portal
TunnelPortals.AddEnteringTunnelDetectorEntityToPortal = function(portal)
    local portalEntity = portal.entity
    if portalEntity == nil or not portalEntity.valid or portal.enteringTunnelDetectorEntity ~= nil then
        return
    end
    local aboveSurface, directionValue = portal.entity.surface, portalEntity.direction
    local orientation = Utils.DirectionToOrientation(directionValue)
    local position = Utils.ApplyOffsetToPosition(portalEntity.position, Utils.RotatePositionAround0(orientation, {x = 0, y = SetupValues.enteringTunnelDetectorEntityDistance}))
    portal.enteringTunnelDetectorEntity = aboveSurface.create_entity {name = "railway_tunnel-train_blocker_1x1", force = global.force.tunnelForce, position = position}
    global.tunnelPortals.enteringTunnelDetectorEntityIdToPortal[portal.enteringTunnelDetectorEntity.unit_number] = portal
end

---@param portal Portal
TunnelPortals.RemoveEnteringTunnelDetectorEntityFromPortal = function(portal)
    if portal.enteringTunnelDetectorEntity ~= nil then
        if portal.enteringTunnelDetectorEntity.valid then
            global.tunnelPortals.enteringTunnelDetectorEntityIdToPortal[portal.enteringTunnelDetectorEntity.unit_number] = nil
            portal.enteringTunnelDetectorEntity.destroy()
        end
        portal.enteringTunnelDetectorEntity = nil
    end
end

---@param event on_player_rotated_entity
TunnelPortals.OnPlayerRotatedEntity = function(event)
    -- Just check if the player (editor mode) rotated a placed portal entity.
    if TunnelPortalPlacedEntityNames[event.entity.name] == nil then
        return
    end
    -- Reverse the rotation so other code logic still works. Also would mess up the graphics if not reversed.
    event.entity.direction = event.previous_direction
    game.get_player(event.player_index).print("Don't try and rotate placed rail tunnel portals.", Colors.red)
end

return TunnelPortals
