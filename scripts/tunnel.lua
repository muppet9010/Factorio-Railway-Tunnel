local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")

local Tunnel = {}

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.entrySignals = global.tunnel.entrySignals or {}
    global.tunnel.trains = global.tunnel.trains or {}

    -- Test Data
    global.tunnel.entrySignals[492] = game.surfaces[1].find_entity("rail-signal", {x = 168.5, y = -42.5})
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.OnTrainChangedState", Tunnel.OnTrainChangedState)
    EventScheduler.RegisterScheduledEventType("Tunnel.TrainEntering", Tunnel.TrainEntering)
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
    global.tunnel.trains[#global.tunnel.trains] = {id = #global.tunnel.trains, enteringTrain = train, enteringSignal = signal}
    EventScheduler.ScheduleEvent(game.tick + 1, "Tunnel.TrainEntering", #global.tunnel.trains)
end

Tunnel.TrainEntering = function(event)
    local data = global.tunnel.trains[event.instanceId]
    EventScheduler.ScheduleEvent(game.tick + 1, "Tunnel.TrainEntering", data.id)
end

return Tunnel
