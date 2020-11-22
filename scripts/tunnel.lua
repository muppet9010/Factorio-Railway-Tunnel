local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Tunnel = {}

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    global.tunnel.tunnels = global.tunnel.tunnels or {}
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.OnTrainChangedState", Tunnel.OnTrainChangedState)
    Interfaces.RegisterInterface("Tunnel.RegisterTunnel", Tunnel.RegisterTunnel)
    Interfaces.RegisterInterface("Tunnel.GetTunnelBySignalId", Tunnel.GetTunnelBySignalId)
end

Tunnel.OnTrainChangedState = function(event)
    local train = event.train
    if train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.tunnel.endSignals[signal.unit_number] == nil then
        return
    end
    Interfaces.Call("TrainManager.TrainFirstEntering", train, signal, global.tunnel.endSignals[signal.unit_number].tunnel)
end

Tunnel.RegisterTunnel = function(aboveSurface, direction, aboveEndSignals, aboveEntrySignals)
    -- Temp function until we generate the tunnel by code
    local tunnelId = #global.tunnel.tunnels
    local undergroundSurface = game.surfaces["railway_tunnel-undeground-horizontal_surface"]
    local tunnel = {id = tunnelId, direction = direction, aboveSurface = aboveSurface, undergroundSurface = undergroundSurface, aboveEndSignals = aboveEndSignals, aboveEntrySignals = aboveEntrySignals}
    global.tunnel.tunnels[tunnelId] = tunnel

    global.tunnel.endSignals[aboveEndSignals.eastern.east.unit_number] = {signal = aboveEndSignals.eastern.east, tunnel = tunnel}

    return tunnel
end

Tunnel.GetTunnelBySignalId = function(signalId)
    if global.tunnel.endSignals[signalId] ~= nil then
        return global.tunnel.endSignals[signalId].tunnel
    else
        return nil
    end
end

return Tunnel
