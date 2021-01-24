local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
--local Utils = require("utility/utils")
--local TunnelCommon = require("scripts/common/tunnel-common")
local Tunnel = {}

--[[
    Notes: We have to handle the "placed" versions being built as this is what blueprints get and when player is in the editor in "entity" mode and pipette's a placed entity. All other player modes select the placement item with pipette.
]]
Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.tunnels = global.tunnel.tunnels or {}
    --[[
        [id] = {
            id = unqiue id of the tunnel.
            alignment = either "horizontal" or "vertical".
            alignmentOrientation = the orientation value of either 0.25 (horizontal) or 0 (vertical), no concept of direction though.
            aboveSurface = LuaSurface of the main world surface.
            undergroundSurface = LuaSurface of the underground surface for this tunnel.
            portals = table of the 2 portal global objects that make up this tunnel.
            segments = table of the segment global objects on the surface.
            undergroundRailEntities = table of rail LuaEntity.
            undergroundModifiers = {
                railAlignmentAxis = the "x" or "y" axis that the tunnels underground rails are aligned along.
                tunnelInstanceAxis = the "x" or "y" that each tunnel instance is spaced out along.
                tunnelInstanceValue = this tunnels static value of the tunnelInstanceAxis for the copied (moving) train carriages.
                tunnelInstanceClonedTrainValue = this tunnels static value of the tunnelInstanceAxis for the cloned (stationary) train carriages.
                undergroundOffsetFromSurface = position offset of the underground entities from the surface entities.
                surfaceOffsetFromUnderground = position offset of the surface entities from the undergroud entities.
                undergroundLeadInTiles = the tiles lead in of rail from 0
            }
        }
    ]]
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    --[[
        [unit_number] = {
            id = unit_number of this signal.
            entity = signal entity.
            portal = the portal global object this signal is part of.
        }
    ]]
    global.tunnel.entryInnerSignals = global.tunnel.entryInnerSignals or {}
    --[[
        [unit_number] = {
            id = unit_number of this signal.
            entity = signal entity.
            portal = the portal global object this signal is part of.
        }
    ]]
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)
    Interfaces.RegisterInterface("Tunnel.CompleteTunnel", Tunnel.CompleteTunnel)
    Interfaces.RegisterInterface("Tunnel.RegisterEntryInnerSignalEntity", Tunnel.RegisterEntrySignalEntity)
    Interfaces.RegisterInterface("Tunnel.DeregisterEntryInnerSignal", Tunnel.DeregisterEntrySignal)
    Interfaces.RegisterInterface("Tunnel.RegisterEndSignalEntity", Tunnel.RegisterEndSignalEntity)
    Interfaces.RegisterInterface("Tunnel.DeregisterEndSignal", Tunnel.DeregisterEndSignal)
    Interfaces.RegisterInterface("Tunnel.RemoveTunnel", Tunnel.RemoveTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainReservedTunnel", Tunnel.TrainReservedTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainFinishedEnteringTunnel", Tunnel.TrainFinishedEnteringTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainStartedExitingTunnel", Tunnel.TrainStartedExitingTunnel)
    Interfaces.RegisterInterface("Tunnel.TrainReleasedTunnel", Tunnel.TrainReleasedTunnel)
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

Tunnel.CompleteTunnel = function(tunnelPortalEntities, tunnelSegmentEntities)
    local force, aboveSurface, refTunnelPortalEntity = tunnelPortalEntities[1].force, tunnelPortalEntities[1].surface, tunnelPortalEntities[1]

    local tunnelPortals = Interfaces.Call("TunnelPortals.TunnelCompleted", tunnelPortalEntities, force, aboveSurface)
    local tunnelSegments = Interfaces.Call("TunnelSegments.TunnelCompleted", tunnelSegmentEntities, force, aboveSurface)

    -- Create the tunnel global object.
    local tunnelId, alignment, alignmentOrientation, undergroundSurface = #global.tunnel.tunnels + 1, "vertical", 0, global.underground.verticalSurface
    if refTunnelPortalEntity.direction == defines.direction.east or refTunnelPortalEntity.direction == defines.direction.west then
        alignment = "horizontal"
        alignmentOrientation = 0.25
        undergroundSurface = global.underground.horizontalSurface
    end
    local tunnel = {
        id = tunnelId,
        alignment = alignment,
        alignmentOrientation = alignmentOrientation,
        aboveSurface = refTunnelPortalEntity.surface,
        undergroundSurface = undergroundSurface,
        portals = tunnelPortals,
        segments = tunnelSegments
    }
    global.tunnel.tunnels[tunnelId] = tunnel
    for _, portal in pairs(tunnelPortals) do
        portal.tunnel = tunnel
    end
    for _, segment in pairs(tunnelSegments) do
        segment.tunnel = tunnel
    end

    tunnel.undergroundRailEntities, tunnel.undergroundModifiers = Interfaces.Call("Underground.TunnelCompleted", tunnel, refTunnelPortalEntity)
end

Tunnel.RemoveTunnel = function(tunnel)
    Interfaces.Call("TrainManager.TunnelRemoved", tunnel)
    for _, portal in pairs(tunnel.portals) do
        Interfaces.Call("TunnelPortals.TunnelRemoved", portal)
    end
    for _, segment in pairs(tunnel.segments) do
        Interfaces.Call("TunnelSegments.TunnelRemoved", segment)
    end
    for _, undergroundRailEntity in pairs(tunnel.undergroundRailEntities) do
        undergroundRailEntity.destroy()
    end
    global.tunnel.tunnels[tunnel.id] = nil
end

Tunnel.RegisterEntryInnerSignalEntity = function(entryInnerSignalEntity, portal)
    global.tunnel.entryInnerSignals[entryInnerSignalEntity.unit_number] = {
        id = entryInnerSignalEntity.unit_number,
        entity = entryInnerSignalEntity,
        portal = portal
    }
    return global.tunnel.entryInnerSignals[entryInnerSignalEntity.unit_number]
end

Tunnel.DeregisterEntryInnerSignal = function(entryInnerSignal)
    global.tunnel.entryInnerSignals[entryInnerSignal.entity.unit_number] = nil
end

Tunnel.RegisterEndSignalEntity = function(endSignalEntity, portal)
    global.tunnel.endSignals[endSignalEntity.unit_number] = {
        id = endSignalEntity.unit_number,
        entity = endSignalEntity,
        portal = portal
    }
    return global.tunnel.endSignals[endSignalEntity.unit_number]
end

Tunnel.DeregisterEndSignal = function(endSignal)
    global.tunnel.endSignals[endSignal.entity.unit_number] = nil
end

Tunnel.TrainReservedTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.CloseEntranceSignalForTrainManagerEntry", trainManagerEntry.surfaceExitPortal, trainManagerEntry)
end

Tunnel.TrainFinishedEnteringTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.CloseEntranceSignalForTrainManagerEntry", trainManagerEntry.surfaceEntrancePortal, trainManagerEntry)
end

Tunnel.TrainStartedExitingTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.OpenEntranceSignalForTrainManagerEntry", trainManagerEntry.surfaceExitPortal, trainManagerEntry)
end

Tunnel.TrainReleasedTunnel = function(trainManagerEntry)
    Interfaces.Call("TunnelPortals.OpenEntranceSignalForTrainManagerEntry", trainManagerEntry.surfaceEntrancePortal, trainManagerEntry)
    Interfaces.Call("TunnelPortals.OpenEntranceSignalForTrainManagerEntry", trainManagerEntry.surfaceExitPortal, trainManagerEntry)
end

return Tunnel
