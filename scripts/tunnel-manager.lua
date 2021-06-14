local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Tunnel = {}
local TunnelCommon = require("scripts/tunnel-common")
local Utils = require("utility/utils")

--[[
    Notes: We have to handle the "placed" versions being built as this is what blueprints get and when player is in the editor in "entity" mode and pipette's a placed entity. All other player modes select the placement item with pipette.
]]
Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.nextTunnelId = global.tunnel.nextTunnelId or 1
    global.tunnel.tunnels = global.tunnel.tunnels or {}
    --[[
        [id] = {
            id = unqiue id of the tunnel.
            alignment = either "horizontal" or "vertical".
            alignmentOrientation = the orientation value of either 0.25 (horizontal) or 0 (vertical), no concept of direction though.
            railAlignmentAxis = the "x" or "y" axis the the underground rails are aligned upon per tunnel. Ref to the undergroundSurface global objects attribute.
            tunnelAlignmentAxis = the other axis from railAlignmentAxis.
            aboveSurface = LuaSurface of the main world surface.
            undergroundTunnel = reference to the underground tunnel global object.
            portals = table of the 2 portal global objects that make up this tunnel.
            segments = table of the segment global objects on the surface.
            trainManagerEntry = a reference to the global.trainManager.managedTrains object that is currently using this tunnel.
            tunnelRailEntities = table of all the rail entities of the tunnel (invisible rail) on the surface. Key'd by unit_number.
        }
    ]]
    global.tunnel.endSignals = global.tunnel.endSignals or {} --  Reference to the "in" endSignal object in global.tunnelPortals.portals[id].endSignals. Is used as a way to check for trains stopping at this signal.
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)

    Interfaces.RegisterInterface("Tunnel.CompleteTunnel", Tunnel.CompleteTunnel)
    Interfaces.RegisterInterface("Tunnel.RegisterEndSignal", Tunnel.RegisterEndSignal)
    Interfaces.RegisterInterface("Tunnel.DeregisterEndSignal", Tunnel.DeregisterEndSignal)
    Interfaces.RegisterInterface("Tunnel.RemoveTunnel", Tunnel.RemoveTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainReservedTunnel", Tunnel.TrainReservedTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainFinishedEnteringTunnel", Tunnel.TrainFinishedEnteringTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainStartedExitingTunnel", Tunnel.TrainStartedExitingTunnel)
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
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", rollingStockFilter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", rollingStockFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", rollingStockFilter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", rollingStockFilter)
end

Tunnel.TrainEnteringTunnel_OnTrainChangedState = function(event)
    local train = event.train
    if not train.valid or train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.tunnel.endSignals[signal.unit_number] == nil then
        return
    end
    Interfaces.Call("TrainManager.RegisterTrainApproaching", train, global.tunnel.endSignals[signal.unit_number])
end

Tunnel.CompleteTunnel = function(tunnelPortalEntities, tunnelSegmentEntities)
    local force, aboveSurface, refTunnelPortalEntity = tunnelPortalEntities[1].force, tunnelPortalEntities[1].surface, tunnelPortalEntities[1]

    local tunnelPortals = Interfaces.Call("TunnelPortals.On_TunnelCompleted", tunnelPortalEntities, force, aboveSurface)
    local tunnelSegments = Interfaces.Call("TunnelSegments.On_TunnelCompleted", tunnelSegmentEntities, force, aboveSurface)

    -- Create the tunnel global object.
    local alignment, alignmentOrientation = "vertical", 0
    if refTunnelPortalEntity.direction == defines.direction.east or refTunnelPortalEntity.direction == defines.direction.west then
        alignment = "horizontal"
        alignmentOrientation = 0.25
    end
    local tunnel = {
        id = global.tunnel.nextTunnelId,
        alignment = alignment,
        alignmentOrientation = alignmentOrientation,
        aboveSurface = refTunnelPortalEntity.surface,
        portals = tunnelPortals,
        segments = tunnelSegments,
        tunnelRailEntities = {}
    }
    global.tunnel.tunnels[tunnel.id] = tunnel
    global.tunnel.nextTunnelId = global.tunnel.nextTunnelId + 1
    for _, portal in pairs(tunnelPortals) do
        portal.tunnel = tunnel
        for tunnelRailEntityUnitNumber, tunnelRailEntity in pairs(portal.tunnelRailEntities) do
            tunnel.tunnelRailEntities[tunnelRailEntityUnitNumber] = tunnelRailEntity
        end
    end
    for _, segment in pairs(tunnelSegments) do
        segment.tunnel = tunnel
        for tunnelRailEntityUnitNumber, tunnelRailEntity in pairs(segment.tunnelRailEntities) do
            tunnel.tunnelRailEntities[tunnelRailEntityUnitNumber] = tunnelRailEntity
        end
    end

    tunnel.undergroundTunnel = Interfaces.Call("Underground.AssignUndergroundTunnel", tunnel)
    tunnel.railAlignmentAxis = tunnel.undergroundTunnel.undergroundSurface.railAlignmentAxis
    tunnel.tunnelAlignmentAxis = tunnel.undergroundTunnel.undergroundSurface.tunnelInstanceAxis
end

Tunnel.RemoveTunnel = function(tunnel)
    Interfaces.Call("TrainManager.On_TunnelRemoved", tunnel)
    for _, portal in pairs(tunnel.portals) do
        Interfaces.Call("TunnelPortals.On_TunnelRemoved", portal)
    end
    for _, segment in pairs(tunnel.segments) do
        Interfaces.Call("TunnelSegments.On_TunnelRemoved", segment)
    end
    Interfaces.Call("Underground.ReleaseUndergroundTunnel", tunnel.undergroundTunnel)
    global.tunnel.tunnels[tunnel.id] = nil
end

Tunnel.RegisterEndSignal = function(endSignal)
    global.tunnel.endSignals[endSignal.entity.unit_number] = endSignal
end

Tunnel.DeregisterEndSignal = function(endSignal)
    global.tunnel.endSignals[endSignal.entity.unit_number] = nil
end

Tunnel.TrainReservedTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.CloseEntranceSignalForTrainManagerEntry", trainManagerEntry.aboveExitPortal, trainManagerEntry)
    trainManagerEntry.tunnel.trainManagerEntry = trainManagerEntry
end

Tunnel.TrainFinishedEnteringTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.CloseEntranceSignalForTrainManagerEntry", trainManagerEntry.aboveEntrancePortal, trainManagerEntry)
end

Tunnel.TrainStartedExitingTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.OpenEntranceSignalForTrainManagerEntry", trainManagerEntry.aboveExitPortal, trainManagerEntry)
end

Tunnel.TrainReleasedTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.OpenEntranceSignalForTrainManagerEntry", trainManagerEntry.aboveEntrancePortal, trainManagerEntry)
    Interfaces.Call("TunnelPortals.OpenEntranceSignalForTrainManagerEntry", trainManagerEntry.aboveExitPortal, trainManagerEntry)
    if trainManagerEntry.tunnel.trainManagerEntry ~= nil and trainManagerEntry.tunnel.trainManagerEntry.id == trainManagerEntry.id then
        -- In some edge cases the call from a newly reversing train manager entry comes in before the old one is terminated, so handle this scenario.
        trainManagerEntry.tunnel.trainManagerEntry = nil
    end
end

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

Tunnel.GetTunnelsUsageEntry = function(tunnelToCheck)
    -- Just checks if the tunnel is in use, i.e. if another train can start to use it or not.
    return tunnelToCheck.trainManagerEntry
end
--[[- tunnelId = Id of the tunnel (INT).
- portals = Array of the 2 portal entities in this tunnel.
- segments = Array of the tunnel segment entities in this tunnel.
- tunnel usage id = Id (INT) of the tunnel usage entry using this tunnel if one is currently active. Can use the get_tunnel_usage_entry_for_id remote interface to get details of the tunnel usage entry.]]
Tunnel.Remote_GetTunnelDetails = function(tunnel)
    local tunnelSegments = {}
    for _, segment in pairs(tunnel.segments) do
        table.insert(tunnelSegments, segment.entity)
    end
    local tunnelDetails = {
        tunnelId = tunnel.id,
        portals = {tunnel.portals[1].entity, tunnel.portals[2].entity},
        segments = tunnelSegments,
        tunnelUsageId = tunnel.trainManagerEntry.id
    }
    return tunnelDetails
end

Tunnel.Remote_GetTunnelDetailsForId = function(tunnelId)
    local tunnel = global.tunnel.tunnels[tunnelId]
    if tunnel == nil then
        return nil
    end
    return Tunnel.Remote_GetTunnelDetails(tunnel)
end

Tunnel.Remote_GetTunnelDetailsForEntity = function(entityUnitNumber)
    for _, tunnel in pairs(global.tunnel.tunnels) do
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

Tunnel.OnBuiltEntity = function(event)
    -- Check for any train carriages (real or ghost) being built on the portal or tunnel segments. Ghost placing train carriages doesn't raise the on_built_event for some reason.
    -- Known limitation that you can't place a single carriage on a tunnel crossing segment in most positions as this detects the tunnel rails underneath the regular rails. Edge case and just slightly over protective.
    local createdEntity = event.created_entity or event.entity
    if (not createdEntity.valid or (not (createdEntity.type ~= "entity-ghost" and TunnelCommon.RollingStockTypes[createdEntity.type] ~= nil) and not (createdEntity.type == "entity-ghost" and TunnelCommon.RollingStockTypes[createdEntity.ghost_type] ~= nil))) then
        return
    end

    if createdEntity.type ~= "entity-ghost" then
        -- Is a real entity so check it approperiately.

        -- If its part of a multi carriage train then ignore it in this function. As other logic for handling manipulation of trains using tunnels will catch it. This is intended to purely catch single carriages being built on tunnels.
        local train = createdEntity.train
        if #createdEntity.train.carriages ~= 1 then
            return
        end

        -- If train (single carriage) doesn't have a tunnel rail at either end of it then its not on a tunnel, so ignore it.
        if TunnelCommon.tunnelSurfaceRailEntityNames[train.front_rail.name] == nil and TunnelCommon.tunnelSurfaceRailEntityNames[train.back_rail.name] == nil then
            return
        end
    else
        -- Is a ghost so check it approperiately. This isn't perfect, but if it misses an invalid case the real entity being placed will catch it. Nicer to warn the player at the ghost stage however.

        -- Have to check what rails are at the approximate ends of the ghost carriage.
        local carriageLengthFromCenter, surface, tunnelRailFound = TunnelCommon.GetCarriagePlacementDistance(createdEntity.name), createdEntity.surface, false
        local frontRailPosition, backRailPosition = Utils.GetPositionForOrientationDistance(createdEntity.position, carriageLengthFromCenter, createdEntity.orientation), Utils.GetPositionForOrientationDistance(createdEntity.position, carriageLengthFromCenter, createdEntity.orientation - 0.5)
        if #surface.find_entities_filtered {name = TunnelCommon.tunnelSurfaceRailEntityNames, position = frontRailPosition} ~= 0 then
            tunnelRailFound = true
        elseif #surface.find_entities_filtered {name = TunnelCommon.tunnelSurfaceRailEntityNames, position = backRailPosition} ~= 0 then
            tunnelRailFound = true
        end
        if not tunnelRailFound then
            return
        end
    end

    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    TunnelCommon.UndoInvalidPlacement(createdEntity, placer, createdEntity.type ~= "entity-ghost", false, "Rolling stock can't be built on tunnels", "rolling stock")
end

return Tunnel
