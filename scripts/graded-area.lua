local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")

local GradedArea = {}

GradedArea.CreateGlobals = function()
    global.gradedArea = global.gradedArea or {}
    global.gradedArea.entrySignals = global.gradedArea.entrySignals or {}
    global.gradedArea.trains = global.gradedArea.trains or {}

    -- Test Data
    global.gradedArea.entrySignals[492] = game.surfaces[1].find_entity("rail-signal", {x = 168.5, y = 42.5})
end

GradedArea.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "GradedArea.OnTrainChangedState", GradedArea.OnTrainChangedState)
    EventScheduler.RegisterScheduledEventType("TrainEntering", GradedArea.TrainEntering)
end

GradedArea.OnTrainChangedState = function(event)
    local train = event.train
    if train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.gradedArea.entrySignals[signal.unit_number] == nil then
        return
    end
    global.gradedArea.trains[#global.gradedArea.trains] = {id = #global.gradedArea.trains, enteringTrain = train, enteringSignal = signal}
    EventScheduler.ScheduleEvent(game.tick + 1, "GradedArea.TrainEntering", #global.gradedArea.trains)
end

GradedArea.TrainEntering = function(event)
    local data = global.gradedArea.trains[event.instance_id]
    EventScheduler.ScheduleEvent(game.tick + 1, "GradedArea.TrainEntering", data.id)
end

return GradedArea
