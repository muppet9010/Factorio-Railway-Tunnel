local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Tunnel = {}
local TunnelShared = require("scripts/tunnel-shared")
local Common = require("scripts/common")
local TunnelAlignment, RollingStockTypes, TunnelSurfaceRailEntityNames, TunnelAlignmentOrientation = Common.TunnelAlignment, Common.RollingStockTypes, Common.TunnelSurfaceRailEntityNames, Common.TunnelAlignmentOrientation
local Utils = require("utility/utils")

---@class Tunnel
---@field id Id @unqiue id of the tunnel.
---@field alignment TunnelAlignment
---@field alignmentOrientation TunnelAlignmentOrientation
---@field alignmentAxis Axis
---@field surface LuaSurface
---@field portals Portal[]
---@field segments Segment[]
---@field managedTrain ManagedTrain @one is currently using this tunnel.
---@field tunnelRailEntities table<UnitNumber, LuaEntity> @the invisible rail entities of the whole tunnel (portal and segments).
---@field portalRailEntities table<UnitNumber, LuaEntity> @the visible rail entities that are part of the portal (visible rails).
---@field tunnelLength int @the length of the tunnel segments in tiles.

---@class TunnelDetails
---@field tunnelId Id @Id of the tunnel.
---@field portals LuaEntity[] @Not in any special order.
---@field segments LuaEntity[] @Not in any special order.
---@field tunnelUsageId Id

Tunnel.CreateGlobals = function()
    global.tunnels = global.tunnels or {}
    global.tunnels.nextTunnelId = global.tunnels.nextTunnelId or 1
    global.tunnels.tunnels = global.tunnels.tunnels or {} ---@type table<Id, Tunnel>
    global.tunnels.transitionSignals = global.tunnels.transitionSignals or {} ---@type table<UnitNumber, PortalTransitionSignal> @the tunnel's portal's "inSignal" transitionSignal objects. Is used as a quick lookup for trains stopping at this signal and reserving the tunnel.
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)

    Interfaces.RegisterInterface("Tunnel.CompleteTunnel", Tunnel.CompleteTunnel)
    Interfaces.RegisterInterface("Tunnel.RegisterTransitionSignal", Tunnel.RegisterTransitionSignal)
    Interfaces.RegisterInterface("Tunnel.DeregisterTransitionSignal", Tunnel.DeregisterTransitionSignal)
    Interfaces.RegisterInterface("Tunnel.RemoveTunnel", Tunnel.RemoveTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainReservedTunnel", Tunnel.TrainReservedTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainFinishedEnteringTunnel", Tunnel.TrainFinishedEnteringTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainReleasedTunnel", Tunnel.TrainReleasedTunnel)
    Interfaces.RegisterInterface("Tunnel.On_PortalReplaced", Tunnel.On_PortalReplaced)
    Interfaces.RegisterInterface("Tunnel.On_SegmentReplaced", Tunnel.On_SegmentReplaced)
    Interfaces.RegisterInterface("Tunnel.GetTunnelsUsageEntry", Tunnel.GetTunnelsUsageEntry)

    local rollingStockFilter = {
        {filter = "rolling-stock"}, -- Just gets real entities, not ghosts.
        {filter = "ghost_type", type = "locomotive"},
        {filter = "ghost_type", type = "cargo-wagon"},
        {filter = "ghost_type", type = "fluid-wagon"},
        {filter = "ghost_type", type = "artillery-wagon"}
    }
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, rollingStockFilter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, rollingStockFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, rollingStockFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, rollingStockFilter)
end

-- Needed so we detect when a train is targetting the transition signal of a tunnel and has a path reserved to it. Naturally the train would start to slow down at this point, but we want to control it instead.
---@param event on_train_changed_state
Tunnel.TrainEnteringTunnel_OnTrainChangedState = function(event)
    local train = event.train
    if not train.valid or train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.tunnels.transitionSignals[signal.unit_number] == nil then
        return
    end
    Interfaces.Call("TrainManager.RegisterTrainApproachingPortalSignal", train, global.tunnels.transitionSignals[signal.unit_number])
end

---@param tunnelPortalEntities LuaEntity[]
---@param tunnelSegmentEntities LuaEntity[]
Tunnel.CompleteTunnel = function(tunnelPortalEntities, tunnelSegmentEntities)
    ---@typelist LuaForce, LuaSurface, LuaEntity
    local force, surface, refTunnelPortalEntity = tunnelPortalEntities[1].force, tunnelPortalEntities[1].surface, tunnelPortalEntities[1]
    local refTunnelPortalEntity_direction = refTunnelPortalEntity.direction

    -- Call any other modules before the tunnel object is created.
    local tunnelPortals = Interfaces.Call("TunnelPortals.On_PreTunnelCompleted", tunnelPortalEntities, force, surface) ---@type table<int,Portal>
    local undergroundSegments = Interfaces.Call("UndergroundSegments.On_PreTunnelCompleted", tunnelSegmentEntities, force, surface) ---@type table<int,Segment>

    -- Create the tunnel global object.
    local alignment, alignmentOrientation, alignmentAxis
    if refTunnelPortalEntity_direction == defines.direction.north or refTunnelPortalEntity_direction == defines.direction.south then
        alignment = TunnelAlignment.vertical
        alignmentOrientation = TunnelAlignmentOrientation.vertical
        alignmentAxis = "y"
    elseif refTunnelPortalEntity_direction == defines.direction.east or refTunnelPortalEntity_direction == defines.direction.west then
        alignment = TunnelAlignment.horizontal
        alignmentOrientation = TunnelAlignmentOrientation.horizontal
        alignmentAxis = "x"
    else
        error("Unsupported refTunnelPortalEntity.direction: " .. refTunnelPortalEntity_direction)
    end
    local tunnel = {
        id = global.tunnels.nextTunnelId,
        alignment = alignment,
        alignmentOrientation = alignmentOrientation,
        alignmentAxis = alignmentAxis,
        surface = surface,
        portals = tunnelPortals,
        segments = undergroundSegments,
        tunnelRailEntities = {},
        portalRailEntities = {},
        tunnelLength = #tunnelSegmentEntities * 2
    }
    global.tunnels.tunnels[tunnel.id] = tunnel
    global.tunnels.nextTunnelId = global.tunnels.nextTunnelId + 1
    for _, portal in pairs(tunnelPortals) do
        portal.tunnel = tunnel
        for tunnelRailEntity_unitNumber, tunnelRailEntity in pairs(portal.tunnelRailEntities) do
            tunnel.tunnelRailEntities[tunnelRailEntity_unitNumber] = tunnelRailEntity
        end
        for portalRailEntity_unitNumber, portalRailEntity in pairs(portal.portalRailEntities) do
            tunnel.portalRailEntities[portalRailEntity_unitNumber] = portalRailEntity
        end
    end
    for _, segment in pairs(undergroundSegments) do
        segment.tunnel = tunnel
        for tunnelRailEntity_unitNumber, tunnelRailEntity in pairs(segment.tunnelRailEntities) do
            tunnel.tunnelRailEntities[tunnelRailEntity_unitNumber] = tunnelRailEntity
        end
    end
end

---@param tunnel Tunnel
Tunnel.RemoveTunnel = function(tunnel)
    Interfaces.Call("TrainManager.On_TunnelRemoved", tunnel)
    for _, portal in pairs(tunnel.portals) do
        Interfaces.Call("TunnelPortals.On_TunnelRemoved", portal)
    end
    for _, segment in pairs(tunnel.segments) do
        Interfaces.Call("UndergroundSegments.On_TunnelRemoved", segment)
    end
    global.tunnels.tunnels[tunnel.id] = nil
end

---@param transitionSignal PortalTransitionSignal
Tunnel.RegisterTransitionSignal = function(transitionSignal)
    global.tunnels.transitionSignals[transitionSignal.entity.unit_number] = transitionSignal
end

---@param transitionSignal PortalTransitionSignal
Tunnel.DeregisterTransitionSignal = function(transitionSignal)
    global.tunnels.transitionSignals[transitionSignal.entity.unit_number] = nil
end

---@param managedTrain ManagedTrain
Tunnel.TrainReservedTunnel = function(managedTrain)
    managedTrain.tunnel.managedTrain = managedTrain
end

---@param managedTrain ManagedTrain
Tunnel.TrainFinishedEnteringTunnel = function(managedTrain)
    Interfaces.Call("TunnelPortals.AddEnteringTrainUsageDetectionEntityToPortal", managedTrain.entrancePortal, true)
end

---@param managedTrain ManagedTrain
Tunnel.TrainReleasedTunnel = function(managedTrain)
    Interfaces.Call("TunnelPortals.AddEnteringTrainUsageDetectionEntityToPortal", managedTrain.entrancePortal, true)
    Interfaces.Call("TunnelPortals.AddEnteringTrainUsageDetectionEntityToPortal", managedTrain.exitPortal, true)
    if managedTrain.tunnel.managedTrain ~= nil and managedTrain.tunnel.managedTrain.id == managedTrain.id then
        -- In some edge cases the call from a newly reversing train manager entry comes in before the old one is terminated, so handle this scenario.
        managedTrain.tunnel.managedTrain = nil
    end
end

---@param tunnel Tunnel
---@param oldPortal Portal
---@param newPortal Portal
Tunnel.On_PortalReplaced = function(tunnel, oldPortal, newPortal)
    if tunnel == nil then
        return
    end
    -- Updated the cached portal object reference as they have bene recreated.
    for i, portal in pairs(tunnel.portals) do
        if portal.id == oldPortal.id then
            tunnel.portals[i] = newPortal
            break
        end
    end
    Interfaces.Call("TrainManager.On_PortalReplaced", tunnel, newPortal)
end

---@param tunnel Tunnel
---@param oldSegment Segment
---@param newSegment Segment
Tunnel.On_SegmentReplaced = function(tunnel, oldSegment, newSegment)
    if tunnel == nil then
        return
    end
    -- Updated the cached segment object reference as they have bene recreated.
    for i, segment in pairs(tunnel.segments) do
        if segment.id == oldSegment.id then
            tunnel.segments[i] = newSegment
            break
        end
    end
end

---@param tunnelToCheck Tunnel
---@return ManagedTrain
Tunnel.GetTunnelsUsageEntry = function(tunnelToCheck)
    -- Just checks if the tunnel is in use, i.e. if another train can start to use it or not.
    return tunnelToCheck.managedTrain
end

---@param tunnel Tunnel
---@return TunnelDetails
Tunnel.Remote_GetTunnelDetails = function(tunnel)
    local undergroundSegments = {}
    for _, segment in pairs(tunnel.segments) do
        table.insert(undergroundSegments, segment.entity)
    end
    local tunnelDetails = {
        tunnelId = tunnel.id,
        portals = {tunnel.portals[1].entity, tunnel.portals[2].entity},
        segments = undergroundSegments,
        tunnelUsageId = tunnel.managedTrain.id
    }
    return tunnelDetails
end

---@param tunnelId Id
---@return TunnelDetails
Tunnel.Remote_GetTunnelDetailsForId = function(tunnelId)
    local tunnel = global.tunnels.tunnels[tunnelId]
    if tunnel == nil then
        return nil
    end
    return Tunnel.Remote_GetTunnelDetails(tunnel)
end

---@param entityUnitNumber UnitNumber
---@return TunnelDetails
Tunnel.Remote_GetTunnelDetailsForEntity = function(entityUnitNumber)
    for _, tunnel in pairs(global.tunnels.tunnels) do
        for _, portal in pairs(tunnel.portals) do
            if portal.id == entityUnitNumber then
                return Tunnel.Remote_GetTunnelDetails(tunnel)
            end
        end
        for _, segment in pairs(tunnel.segments) do
            if segment.id == entityUnitNumber then
                return Tunnel.Remote_GetTunnelDetails(tunnel)
            end
        end
    end
    return nil
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
Tunnel.OnBuiltEntity = function(event)
    -- Check for any train carriages (real or ghost) being built on the portal or tunnel segments. Ghost placing train carriages doesn't raise the on_built_event for some reason.
    -- Known limitation that you can't place a single carriage on a tunnel crossing segment in most positions as this detects the tunnel rails underneath the regular rails. Edge case and just slightly over protective.
    local createdEntity = event.created_entity or event.entity
    local createdEntity_type = createdEntity.type
    if (not createdEntity.valid or (not (createdEntity_type ~= "entity-ghost" and RollingStockTypes[createdEntity_type] ~= nil) and not (createdEntity_type == "entity-ghost" and RollingStockTypes[createdEntity.ghost_type] ~= nil))) then
        return
    end

    if createdEntity_type ~= "entity-ghost" then
        -- Is a real entity so check it approperiately.
        local train = createdEntity.train
        local createdEntity_unitNumber = createdEntity.unit_number

        if Interfaces.Call("TrainManager.GetTrainIdsManagedTrainDetails", train.id) then
            -- Carriage was built on a managed train, so this will be handled by seperate train manipulation tracking logic.
            return
        end

        -- Look at the train and work out where the placed wagon fits in it. Then chck the approperiate ends of the trains rails.
        local trainFrontStockIsPlacedEntity, trainBackStockIsPlacedEntity = false, false
        if train.front_stock.unit_number == createdEntity_unitNumber then
            trainFrontStockIsPlacedEntity = true
        end
        if train.back_stock.unit_number == createdEntity_unitNumber then
            trainBackStockIsPlacedEntity = true
        end
        if trainFrontStockIsPlacedEntity and trainBackStockIsPlacedEntity then
            -- Both ends of the train is this carriage so its a train of 1.
            if TunnelSurfaceRailEntityNames[train.front_rail.name] == nil and TunnelSurfaceRailEntityNames[train.back_rail.name] == nil then
                -- If train (single carriage) doesn't have a tunnel rail at either end of it then its not on a tunnel, so ignore it.
                return
            end
        elseif trainFrontStockIsPlacedEntity then
            -- Placed carriage is front of train
            if TunnelSurfaceRailEntityNames[train.front_rail.name] == nil then
                -- Ignore if train doesn't have a tunnel rail at the end the carraige was just placed at. We assume the other end is fine.
                return
            end
        elseif trainBackStockIsPlacedEntity then
            -- Placed carriage is rear of train
            if TunnelSurfaceRailEntityNames[train.back_rail.name] == nil then
                -- Ignore if train doesn't have a tunnel rail at the end the carraige was just placed at. We assume the other end is fine.
                return
            end
        else
            -- Placed carriage is part of an existing train that isn't managed for tunnel usage. The placed carriage isn't on either end of the train so no need to check it.
            return
        end
    else
        -- Is a ghost so check it approperiately. This isn't perfect, but if it misses an invalid case the real entity being placed will catch it. Nicer to warn the player at the ghost stage however.

        -- Have to check what rails are at the approximate ends of the ghost carriage.
        local createdEntity_position, createdEntity_orientation = createdEntity.position, createdEntity.orientation
        local carriageLengthFromCenter, surface, tunnelRailFound = Common.GetCarriagePlacementDistance(createdEntity.name), createdEntity.surface, false
        local frontRailPosition, backRailPosition = Utils.GetPositionForOrientationDistance(createdEntity_position, carriageLengthFromCenter, createdEntity_orientation), Utils.GetPositionForOrientationDistance(createdEntity_position, carriageLengthFromCenter, createdEntity_orientation - 0.5)
        local frontRailsFound = surface.find_entities_filtered {type = {"straight-rail", "curved-rail"}, position = frontRailPosition}
        -- Check the rails found both ends individaully: if theres a regular rail then ignore any tunnel rails, otherwise flag any tunnel rails.
        for _, railEntity in pairs(frontRailsFound) do
            if TunnelSurfaceRailEntityNames[railEntity.name] ~= nil then
                tunnelRailFound = true
            else
                tunnelRailFound = false
                break
            end
        end
        if not tunnelRailFound then
            local backRailsFound = surface.find_entities_filtered {type = {"straight-rail", "curved-rail"}, position = backRailPosition}
            for _, railEntity in pairs(backRailsFound) do
                if TunnelSurfaceRailEntityNames[railEntity.name] ~= nil then
                    tunnelRailFound = true
                else
                    tunnelRailFound = false
                    break
                end
            end
        end
        if not tunnelRailFound then
            return
        end
    end

    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    TunnelShared.UndoInvalidPlacement(createdEntity, placer, createdEntity_type ~= "entity-ghost", false, "Rolling stock can't be built on tunnels", "rolling stock")
end

return Tunnel
