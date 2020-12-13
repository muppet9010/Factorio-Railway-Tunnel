local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Tunnel = {}

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    global.tunnel.tunnels = global.tunnel.tunnels or {} --[[
        id = unqiue id of the tunnel.
        direction = either "horizontal" or "vertical".
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the underground surface for this tunnel.
        aboveEndSignals = table of LuaEntity for the end signals of this tunnel. These are the inner locked red signals.
        aboveEntrySignals = table of LuaEntity for the entry signals of this tunnel. These are the outre ones that detect a train approaching the tunnel train path.
    ]]
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)
    Interfaces.RegisterInterface("Tunnel.RegisterTunnel", Tunnel.RegisterTunnel)
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
    Interfaces.Call("TrainManager.TrainEnteringInitial", train, signal, global.tunnel.endSignals[signal.unit_number].tunnel)
end

Tunnel.RegisterTunnel = function(aboveSurface, direction, aboveEndSignals, aboveEntrySignals)
    -- Temp function until we generate the tunnel by code
    local tunnelId = #global.tunnel.tunnels
    local undergroundSurface = game.surfaces["railway_tunnel-undeground-horizontal_surface"]
    local tunnel = {id = tunnelId, direction = direction, aboveSurface = aboveSurface, undergroundSurface = undergroundSurface, aboveEndSignals = aboveEndSignals, aboveEntrySignals = aboveEntrySignals}
    global.tunnel.tunnels[tunnelId] = tunnel

    global.tunnel.endSignals[aboveEndSignals.eastern[defines.direction.east].unit_number] = {signal = aboveEndSignals.eastern[defines.direction.east], tunnel = tunnel}

    return tunnel
end

return Tunnel
