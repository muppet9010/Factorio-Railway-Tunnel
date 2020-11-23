local Underground = {}

Underground.CreateGlobals = function()
    global.underground = global.underground or {}
    global.underground.horizontalSurface = global.underground.horizontalSurface or Underground.CreateSurface("railway_tunnel-undeground-horizontal_surface")
end

Underground.OnLoad = function()
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

return Underground
