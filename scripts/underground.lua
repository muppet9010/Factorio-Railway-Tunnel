local Utils = require("utility/utils")
local Interfaces = require("utility/interfaces")
local Underground = {}

Underground.CreateGlobals = function()
    global.underground = global.underground or {}
    global.underground.horizontal = global.underground.horizontal or nil -- Vertical underground tunnel global object.
    --[[
        alignment = either "hotizontal" or "vertical"
        surface = The LuaSurface
        refRails = table of the rail entities on this underground that are to be cloned for each tunnel instance.
        trackLengthEachSide = the distance of the ref rails each side of 0 on this surface.
        railAlignmentAxis = the "x" or "y" axis the the underground rails are aligned upon per tunnel.
        tunnelInstanceAxis = the "x" or "y" axis that each tunnel's tracks are spaced along on the underground.
    --]]
    global.underground.vertical = global.underground.vertical or nil -- Vertical underground tunnel global object, same attributes as global.underground.horizontal.
end

Underground.OnLoad = function()
    Interfaces.RegisterInterface("Underground.TunnelCompleted", Underground.TunnelCompleted)
end

Underground.OnStartup = function()
    if global.underground.horizontal == nil then
        global.underground.horizontal = Underground.CreateUndergroundSurface("horizontal")
    end
    if global.underground.vertical == nil then
        global.underground.vertical = Underground.CreateUndergroundSurface("vertical")
    end
end

Underground.CreateUndergroundSurface = function(alignment)
    local surfaceName = "railway_tunnel-undeground-" .. alignment
    if game.get_surface(surfaceName) ~= nil then
        game.delete_surface(surfaceName) -- Mod has been removed and re-added so clean out the old tunnel surfaces.
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
    if alignment == "vertical" then
        undergroundSurface.railAlignmentAxis = "y"
        undergroundSurface.tunnelInstanceAxis = "x"
        railDirection = defines.direction.north
    else
        undergroundSurface.railAlignmentAxis = "x"
        undergroundSurface.tunnelInstanceAxis = "y"
        railDirection = defines.direction.east
    end

    -- Add reference rail.
    for valueVariation = -undergroundSurface.trackLengthEachSide, undergroundSurface.trackLengthEachSide, 2 do
        table.insert(undergroundSurface.refRails, surface.create_entity {name = "straight-rail", position = {[undergroundSurface.railAlignmentAxis] = valueVariation, [undergroundSurface.tunnelInstanceAxis] = 0}, force = global.force.tunnelForce, direction = railDirection})
    end

    return undergroundSurface
end

Underground.TunnelCompleted = function(tunnel)
    local railEntities, undergroundSurface = {}, global.underground[tunnel.alignment]

    local tunnelInstanceValue = tunnel.id * 4
    local cloneRailOffset = {
        [undergroundSurface.railAlignmentAxis] = 0,
        [undergroundSurface.tunnelInstanceAxis] = 0 + tunnelInstanceValue
    }
    undergroundSurface.surface.clone_entities {entities = undergroundSurface.refRails, destination_offset = cloneRailOffset, create_build_effect_smoke = false}

    local undergroundLeadInTiles = undergroundSurface.trackLengthEachSide -- This will be dynamically tracked and generated in the future to cater for tunnel length.
    local undergroundOffsetFromSurface = {
        [undergroundSurface.railAlignmentAxis] = 0 - ((tunnel.portals[1].entity.position[undergroundSurface.railAlignmentAxis] + tunnel.portals[2].entity.position[undergroundSurface.railAlignmentAxis]) / 2),
        [undergroundSurface.tunnelInstanceAxis] = (0 - tunnel.portals[1].entity.position[undergroundSurface.tunnelInstanceAxis]) + tunnelInstanceValue
    }
    local surfaceOffsetFromUnderground = Utils.RotatePositionAround0(0.5, undergroundOffsetFromSurface)

    return {undergroundSurface = undergroundSurface, railEntities = railEntities, tunnelInstanceValue = tunnelInstanceValue, undergroundLeadInTiles = undergroundLeadInTiles, undergroundOffsetFromSurface = undergroundOffsetFromSurface, surfaceOffsetFromUnderground = surfaceOffsetFromUnderground}
end

return Underground
