local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Underground = {}

Underground.CreateGlobals = function()
    global.underground = global.underground or {}
    -- global.underground.horizontalSurface = The surface for horizontal tunnel underground bits.
    -- global.underground.verticalSurface = The surface for vertical tunnel undergound bits.
end

Underground.OnLoad = function()
    Interfaces.RegisterInterface("Underground.TunnelCompleted", Underground.TunnelCompleted)
end

Underground.OnStartup = function()
    if global.underground.horizontalSurface == nil then
        global.underground.horizontalSurface = Underground.CreateSurface("railway_tunnel-undeground-horizontal")
    end
    if global.underground.verticalSurface == nil then
        global.underground.verticalSurface = Underground.CreateSurface("railway_tunnel-undeground-vertical")
    end
end

Underground.CreateSurface = function(surfaceName)
    if game.get_surface(surfaceName) ~= nil then
        game.delete_surface(surfaceName) -- Mod has been removed and re-added so clean out the old tunnel surfaces.
    end
    local surface = game.create_surface(surfaceName)
    surface.generate_with_lab_tiles = true
    surface.always_day = true
    surface.freeze_daytime = true
    surface.show_clouds = false
    surface.request_to_generate_chunks({0, 0}, 10)
    return surface
end

Underground.TunnelCompleted = function(tunnel, refTunnelPortalEntity)
    -- TODO: Change this to become a self contain object. Possibly relocate some other bits of code here at the time.
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
    undergroundModifiers.undergroundLeadInTiles = 1000 -- In a future task this will be extended based on train lenth.
    local offsetTrackDistance = undergroundModifiers.distanceFromCenterToPortalEntrySignals + undergroundModifiers.undergroundLeadInTiles
    -- Place the tracks underground that the train will be copied on to and run on.
    for valueVariation = -offsetTrackDistance, offsetTrackDistance, 2 do
        table.insert(undergroundRailEntities, tunnel.undergroundSurface.create_entity {name = "straight-rail", position = {[undergroundModifiers.railAlignmentAxis] = valueVariation, [undergroundModifiers.tunnelInstanceAxis] = undergroundModifiers.tunnelInstanceValue}, force = refTunnelPortalEntity.force, direction = refTunnelPortalEntity.direction})
    end

    undergroundModifiers.undergroundOffsetFromSurface = {
        [undergroundModifiers.railAlignmentAxis] = 0 - ((tunnel.portals[1].entity.position[undergroundModifiers.railAlignmentAxis] + tunnel.portals[2].entity.position[undergroundModifiers.railAlignmentAxis]) / 2),
        [undergroundModifiers.tunnelInstanceAxis] = (0 - tunnel.portals[1].entity.position[undergroundModifiers.tunnelInstanceAxis]) + undergroundModifiers.tunnelInstanceValue
    }
    undergroundModifiers.surfaceOffsetFromUnderground = Utils.RotatePositionAround0(0.5, undergroundModifiers.undergroundOffsetFromSurface)
    return undergroundRailEntities, undergroundModifiers
end

return Underground
