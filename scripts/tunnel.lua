local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Tunnel = {}

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.entrySignals = global.tunnel.entrySignals or {}

    -- Test Data
    global.tunnel.entrySignals[492] = game.surfaces[1].find_entity("rail-signal", {x = 168.5, y = -42.5})
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.OnTrainChangedState", Tunnel.OnTrainChangedState)
end

Tunnel.OnTrainChangedState = function(event)
    local train = event.train
    if train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.tunnel.entrySignals[signal.unit_number] == nil then
        return
    end
    Interfaces.Call("TrainManager.TrainEntering", train, signal)
end

return Tunnel
