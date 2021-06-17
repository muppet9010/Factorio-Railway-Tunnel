local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local TunnelCommon = require("scripts/tunnel-common")
local Underground = {}

---@class UndergroundSurface
---@field public alignment TunnelAlignment
---@field public surface LuaSurface
---@field public refRails LuaEntity[] @table of the rail entities on this underground that are to be cloned for each tunnel instance.
---@field public trackLengthEachSide int @the distance of the ref rails each side of 0 on this surface.
---@field public railAlignmentAxis Axis @the axis that the underground rails per tunnel are aligned upon (direction of travel).
---@field public tunnelInstanceAxis Axis @the axis that each tunnel instance is spaced along underground (rows of tunnel's tracks).

---@class UndergroundTunnel
---@field public id Id @Id is a unique list for each alignment.
---@field public alignment TunnelAlignment
---@field public tunnel Tunnel @parent tunnel.
---@field public undergroundSurface UndergroundSurface
---@field public tunnelInstanceValue int @this tunnels static value of the tunnelInstanceAxis for the copied (moving) train carriages.
---@field public undergroundOffsetFromSurface Position @position offset of the underground entities from the surface entities.
---@field public surfaceOffsetFromUnderground Position @position offset of the surface entities from the undergroud entities.
---@field public undergroundLeadInTiles int @the tiles lead in of rail from 0
---@field public undergroundSignals table<Id, UndergroundSignal>
---@field public distanceBetweenPortalCenters int @The distance from the underground tunnel center to the portal center.
---@field public tunnelRailCenterValue int @The tunnelRailCenterValue is for the railAlignmentAxis and has to be based on 1 tile offset from 0 as this is the rail grid. It does mean that odd track count tunnels are never centered around 0.

---@class UndergroundSignal
---@field public id UnitNumber @unit_number of this signal.
---@field public entity LuaEntity
---@field public aboveGroundSignalPaired PortalEndSignal @the aboveground signal thats paired with this one.
---@field public signalStateCombinator LuaEntity @the combinator controlling if this signal is forced closed or not.
---@field public signalStateCombinatorControlBehavior LuaCombinatorControlBehavior @cached reference to the ControlBehavior of this undergroundSignal's signalStateCombinator.
---@field public currentSignalStateCombinatorEnabled boolean @cached copy of if the combiantor was last enabled or not.

Underground.CreateGlobals = function()
    global.underground = global.underground or {}
    global.underground.surfaces = global.underground.surfaces or {} ---@type table<TunnelAlignment, UndergroundSurface>
    global.underground.undergroundTunnels = global.underground.undergroundTunnels or {[TunnelCommon.TunnelAlignment.horizontal] = {}, [TunnelCommon.TunnelAlignment.vertical] = {}} ---@type table<TunnelAlignment, table<Id, Tunnel>>
    global.underground.freeUndergroundTunnels = global.underground.freeUndergroundTunnels or {[TunnelCommon.TunnelAlignment.horizontal] = {}, [TunnelCommon.TunnelAlignment.vertical] = {}} -- A table with a horizontal and vertical key'd lists of underground tunnels that currently aren't assigned to an aboveground tunnel object.
end

Underground.PreOnLoad = function()
    Interfaces.RegisterInterface("Underground.AssignUndergroundTunnel", Underground.AssignUndergroundTunnel)
    Interfaces.RegisterInterface("Underground.SetUndergroundExitSignalState", Underground.SetUndergroundExitSignalState)
    Interfaces.RegisterInterface("Underground.GetForwardsEndOfRailPosition", Underground.GetForwardsEndOfRailPosition)
    Interfaces.RegisterInterface("Underground.ReleaseUndergroundTunnel", Underground.ReleaseUndergroundTunnel)
end

Underground.OnStartup = function()
    if global.underground.surfaces[TunnelCommon.TunnelAlignment.horizontal] == nil then
        global.underground.surfaces[TunnelCommon.TunnelAlignment.horizontal] = Underground.CreateUndergroundSurface(TunnelCommon.TunnelAlignment.horizontal)
    end
    if global.underground.surfaces[TunnelCommon.TunnelAlignment.vertical] == nil then
        global.underground.surfaces[TunnelCommon.TunnelAlignment.vertical] = Underground.CreateUndergroundSurface(TunnelCommon.TunnelAlignment.vertical)
    end
end

---@param alignment TunnelAlignment
---@return UndergroundSurface
Underground.CreateUndergroundSurface = function(alignment)
    local surfaceName = "railway_tunnel-undeground-" .. alignment
    if game.get_surface(surfaceName) ~= nil then
        -- Mod has been removed and after a clean load re-added. So clean out the old tunnel surfaces as anything on the main surfaces is gone anwyways.
        local existingSurface = game.get_surface(surfaceName)
        existingSurface.name = "OLD-" .. surfaceName -- Rename the surface as it takes a tick for it to be deleted.
        game.delete_surface(existingSurface)
    end
    local surface = game.create_surface(surfaceName)
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.freeze_daytime = true
    surface.show_clouds = false
    surface.request_to_generate_chunks({0, 0}, 10)

    local undergroundSurface = {
        alignment = alignment,
        surface = surface,
        refRails = {},
        trackLengthEachSide = 1000
    }

    local railDirection
    if alignment == TunnelCommon.TunnelAlignment.vertical then
        undergroundSurface.railAlignmentAxis = "y"
        undergroundSurface.tunnelInstanceAxis = "x"
        railDirection = defines.direction.north
    elseif alignment == TunnelCommon.TunnelAlignment.horizontal then
        undergroundSurface.railAlignmentAxis = "x"
        undergroundSurface.tunnelInstanceAxis = "y"
        railDirection = defines.direction.east
    else
        error("Unsupported alignment: " .. alignment)
    end

    -- Add reference rail.
    for valueVariation = -undergroundSurface.trackLengthEachSide, undergroundSurface.trackLengthEachSide, 2 do
        table.insert(undergroundSurface.refRails, surface.create_entity {name = "straight-rail", position = {[undergroundSurface.railAlignmentAxis] = valueVariation, [undergroundSurface.tunnelInstanceAxis] = 1}, force = global.force.tunnelForce, direction = railDirection})
    end

    return undergroundSurface
end

---@param tunnel Tunnel
---@return UndergroundTunnel
Underground.AssignUndergroundTunnel = function(tunnel)
    local undergroundTunnel, tunnelAlignment = nil, tunnel.alignment

    -- See if there is an existing free tunnel we can re-use of the right alignment.
    local freeUndergroundTunnelKey = Utils.GetFirstTableKey(global.underground.freeUndergroundTunnels[tunnelAlignment])
    if freeUndergroundTunnelKey ~= nil then
        -- Claim this underground tunnel
        undergroundTunnel = global.underground.freeUndergroundTunnels[tunnelAlignment][freeUndergroundTunnelKey]
        table.remove(global.underground.freeUndergroundTunnels[tunnelAlignment], freeUndergroundTunnelKey)
    end
    if undergroundTunnel == nil then
        -- Need to create a new underground tunnel.
        undergroundTunnel = Underground.CreateUndergroundTunnel(tunnel)
    end
    local undergroundSurface = undergroundTunnel.undergroundSurface

    -- Generate attributes used by other parts of mod.
    undergroundTunnel.tunnel = tunnel

    local greatestPortal, lesserPortal
    if tunnel.portals[1].entity.position[undergroundSurface.railAlignmentAxis] > tunnel.portals[2].entity.position[undergroundSurface.railAlignmentAxis] then
        greatestPortal = tunnel.portals[1]
        lesserPortal = tunnel.portals[2]
    else
        greatestPortal = tunnel.portals[2]
        lesserPortal = tunnel.portals[1]
    end
    undergroundTunnel.distanceBetweenPortalCenters = Utils.GetDistanceSingleAxis(greatestPortal.entity.position, lesserPortal.entity.position, undergroundSurface.railAlignmentAxis)
    local undergroundTunnelTiles = undergroundTunnel.distanceBetweenPortalCenters - 50
    -- Get the correct center of the underground tunnel as otherwise the portal entry signals will be on the wrong track pieces.
    if undergroundTunnelTiles % 4 == 0 then
        undergroundTunnel.tunnelRailCenterValue = 0
    else
        undergroundTunnel.tunnelRailCenterValue = 1
    end

    undergroundTunnel.undergroundOffsetFromSurface = {
        [undergroundSurface.railAlignmentAxis] = undergroundTunnel.tunnelRailCenterValue - (greatestPortal.entity.position[undergroundSurface.railAlignmentAxis] - (undergroundTunnel.distanceBetweenPortalCenters / 2)),
        [undergroundSurface.tunnelInstanceAxis] = (1 - tunnel.portals[1].entity.position[undergroundSurface.tunnelInstanceAxis]) + undergroundTunnel.tunnelInstanceValue
    }
    undergroundTunnel.surfaceOffsetFromUnderground = Utils.RotatePositionAround0(0.5, undergroundTunnel.undergroundOffsetFromSurface)

    -- Place the entrance signals from both portals
    for _, portal in pairs(tunnel.portals) do
        for _, portalSignal in pairs(portal.entrySignals) do
            local undergroundSignalPosition = Utils.ApplyOffsetToPosition(portalSignal.entity.position, undergroundTunnel.undergroundOffsetFromSurface)
            local undergroundSignalEntity = undergroundSurface.surface.create_entity {name = "rail-signal", force = global.force.tunnelForce, position = undergroundSignalPosition, direction = portalSignal.entity.direction}
            local undergroundSignal = {
                id = undergroundSignalEntity.unit_number,
                entity = undergroundSignalEntity,
                aboveGroundSignalPaired = portalSignal
            }

            if portalSignal.direction == "out" then
                local signalStateCombinatorPosition = Utils.ApplyOffsetToPosition(undergroundSignalEntity.position, Utils.RotatePositionAround0(portal.entity.orientation, {x = 0, y = 1})) -- 1 tile towards the tunnel center from the signal.
                undergroundSignal.signalStateCombinator = undergroundSurface.surface.create_entity {name = "constant-combinator", force = global.force.tunnelForce, position = signalStateCombinatorPosition}
                local signalStateCombinatorControlBehavior = undergroundSignal.signalStateCombinator.get_or_create_control_behavior() ---@type LuaConstantCombinatorControlBehavior
                undergroundSignal.signalStateCombinatorControlBehavior = signalStateCombinatorControlBehavior
                signalStateCombinatorControlBehavior.set_signal(1, {signal = {type = "virtual", name = "signal-red"}, count = 1})
                signalStateCombinatorControlBehavior.enabled = false
                undergroundSignal.currentSignalStateCombinatorEnabled = false

                undergroundSignalEntity.connect_neighbour {wire = defines.wire_type.red, target_entity = undergroundSignal.signalStateCombinator}

                local undergroundControlBehavior = undergroundSignalEntity.get_or_create_control_behavior()
                undergroundControlBehavior.read_signal = false
                undergroundControlBehavior.close_signal = true
                undergroundControlBehavior.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = ">", constant = 0}, fulfilled = true}
            end
            undergroundTunnel.undergroundSignals[undergroundSignal.id] = undergroundSignal
            portalSignal.undergroundSignalPaired = undergroundSignal
        end
    end

    return undergroundTunnel
end

---@param tunnel Tunnel
---@return UndergroundTunnel
Underground.CreateUndergroundTunnel = function(tunnel)
    local undergroundSurface = global.underground.surfaces[tunnel.alignment]
    local undergroundTunnelId = #global.underground.undergroundTunnels[tunnel.alignment] + 1
    local undergroundTunnel = {
        id = undergroundTunnelId,
        alignment = tunnel.alignment,
        undergroundSurface = undergroundSurface,
        tunnelInstanceValue = undergroundTunnelId * 4,
        undergroundSignals = {}
    }
    undergroundTunnel.undergroundLeadInTiles = undergroundSurface.trackLengthEachSide -- This will be dynamically tracked and generated in the future to cater for tunnel length. Will need to handle rail creation as part of assignment at that point.
    global.underground.undergroundTunnels[tunnel.alignment][undergroundTunnel.id] = undergroundTunnel

    -- Place the rails for this tunnel
    local cloneRailOffset = {
        [undergroundSurface.railAlignmentAxis] = 0,
        [undergroundSurface.tunnelInstanceAxis] = 0 + undergroundTunnel.tunnelInstanceValue
    }
    undergroundSurface.surface.clone_entities {entities = undergroundSurface.refRails, destination_offset = cloneRailOffset, create_build_effect_smoke = false}

    return undergroundTunnel
end

---@param undergroundSignal UndergroundSignal
---@param sourceSignalState defines.signal_state
Underground.SetUndergroundExitSignalState = function(undergroundSignal, sourceSignalState)
    local closeSignalOn
    if sourceSignalState == defines.signal_state.open then
        closeSignalOn = false
    else
        closeSignalOn = true
    end
    if undergroundSignal.currentSignalStateCombinatorEnabled ~= closeSignalOn then
        undergroundSignal.signalStateCombinatorControlBehavior.enabled = closeSignalOn
        undergroundSignal.currentSignalStateCombinatorEnabled = closeSignalOn
    end
end

---@param undergroundTunnel UndergroundTunnel
---@param trainTravelOrientation TrainTravelOrientation
---@return Position
Underground.GetForwardsEndOfRailPosition = function(undergroundTunnel, trainTravelOrientation)
    return Utils.ApplyOffsetToPosition(
        Utils.RotatePositionAround0(
            undergroundTunnel.tunnel.alignmentOrientation,
            {
                x = undergroundTunnel.tunnelInstanceValue + 1,
                y = 0
            }
        ),
        Utils.RotatePositionAround0(
            trainTravelOrientation,
            {
                x = 0,
                y = 0 - (undergroundTunnel.undergroundLeadInTiles - 1)
            }
        )
    )
end

---@param undergroundTunnel UndergroundTunnel
Underground.ReleaseUndergroundTunnel = function(undergroundTunnel)
    -- The aboveground tunnel object using this undergroundTunnel is releasing it for use by another future aboveground tunnel.
    table.insert(global.underground.freeUndergroundTunnels[undergroundTunnel.alignment], undergroundTunnel)

    -- Clear out old data on this underground tunnel so its clean for its next use.
    undergroundTunnel.tunnel = nil
    undergroundTunnel.undergroundOffsetFromSurface = nil
    undergroundTunnel.surfaceOffsetFromUnderground = nil
    undergroundTunnel.distanceBetweenPortalCenters = nil
    undergroundTunnel.tunnelRailCenterValue = nil

    -- Remove the palced underground signals and combinators.
    for _, undergroundSignal in pairs(undergroundTunnel.undergroundSignals) do
        undergroundSignal.entity.destroy()
        if undergroundSignal.signalStateCombinator then
            undergroundSignal.signalStateCombinator.destroy()
        end
    end
    undergroundTunnel.undergroundSignals = {}
end

return Underground
