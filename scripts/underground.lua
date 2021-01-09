local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local TunnelCommon = require("scripts/common/tunnel-common")
local Underground = {}

Underground.CreateGlobals = function()
    global.underground = global.underground or {}
    global.underground.horizontalSurface = global.underground.horizontalSurface or Underground.CreateSurface("railway_tunnel-undeground-horizontal")
    global.underground.verticalSurface = global.underground.verticalSurface or Underground.CreateSurface("railway_tunnel-undeground-vertical")
end

Underground.OnLoad = function()
    Interfaces.RegisterInterface("Underground.TunnelCompleted", Underground.TunnelCompleted)
end

Underground.OnStartup = function()
end

Underground.CreateSurface = function(surfaceName)
    local surface = game.create_surface(surfaceName)
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.freeze_daytime = true
    surface.show_clouds = false
    surface.request_to_generate_chunks({0, 0}, 10)
    return surface
end

Underground.TunnelCompleted = function(tunnel, refTunnelPortalEntity)
    local undergroundRailEntities, undergroundModifiers = {}, {}
    if tunnel.alignment == "vertical" then
        undergroundModifiers.railAlignmentAxis = "y"
        undergroundModifiers.tunnelInstanceAxis = "x"
        undergroundModifiers.tunnelInstanceValue = tunnel.id * 10
    else
        undergroundModifiers.railAlignmentAxis = "x"
        undergroundModifiers.tunnelInstanceAxis = "y"
        undergroundModifiers.tunnelInstanceValue = tunnel.id * 10
    end
    undergroundModifiers.tunnelInstanceClonedTrainValue = undergroundModifiers.tunnelInstanceValue + 4
    undergroundModifiers.distanceFromCenterToPortalEntrySignals = Utils.GetDistanceSingleAxis(tunnel.portals[1].entrySignals["in"].entity.position, tunnel.portals[2].entrySignals["in"].entity.position, undergroundModifiers.railAlignmentAxis) / 2
    undergroundModifiers.distanceFromCenterToPortalEndSignals = Utils.GetDistanceSingleAxis(tunnel.portals[1].endSignals["in"].entity.position, tunnel.portals[2].endSignals["in"].entity.position, undergroundModifiers.railAlignmentAxis) / 2
    local offsetTrackDistance = undergroundModifiers.distanceFromCenterToPortalEntrySignals + TunnelCommon.setupValues.undergroundLeadInTiles
    -- Place the tracks underground that the train will be copied on to and run on.
    for valueVariation = -offsetTrackDistance, offsetTrackDistance, 2 do
        table.insert(undergroundRailEntities, tunnel.undergroundSurface.create_entity {name = "straight-rail", position = {[undergroundModifiers.railAlignmentAxis] = valueVariation, [undergroundModifiers.tunnelInstanceAxis] = undergroundModifiers.tunnelInstanceValue}, force = refTunnelPortalEntity.force, direction = refTunnelPortalEntity.direction})
    end
    return undergroundRailEntities, undergroundModifiers
end

return Underground
