local Force = {}

Force.CreateGlobals = function()
    global.force = global.force or {}
    global.force.tunnelForce = global.force.tunnelForce or nil -- The LuaForce for tunnel no player force entities.
end

Force.OnStartup = function()
    if global.force.tunnelForce == nil then
        Force.CreateTunnelForce()
    end
end

Force.CreateTunnelForce = function()
    local tunnelForce = game.forces["railway_tunnel-tunnel_force"]
    if tunnelForce == nil then
        tunnelForce = game.create_force("railway_tunnel-tunnel_force") -- If mod was removed and re-added we can't recreate the force, just reset its settings.
    end
    tunnelForce.friendly_fire = false
    for _, force in pairs(game.forces) do
        if force.index ~= tunnelForce.index then
            force.set_cease_fire(tunnelForce, true)
            tunnelForce.set_cease_fire(force, true)
        end
    end
    global.force.tunnelForce = tunnelForce
end

return Force
