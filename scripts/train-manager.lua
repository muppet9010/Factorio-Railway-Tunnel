local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local TrainManager = {}
local Interfaces = require("utility/interfaces")

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.trains = global.trainManager.trains or {}
end

TrainManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEnteringScheduledEvent", TrainManager.TrainEnteringScheduledEvent)
    Interfaces.RegisterInterface("TrainManager.TrainEntering", TrainManager.TrainEnteringInterface)
    Interfaces.RegisterInterface("TrainManager.GetManagedTrainById", TrainManager.GetManagedTrainById)
end

TrainManager.TrainEnteringInterface = function(train, signal)
    global.trainManager.trains[#global.trainManager.trains] = {id = #global.trainManager.trains, enteringTrain = train, enteringSignal = signal}
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringScheduledEvent", #global.trainManager.trains)
end

TrainManager.TrainEnteringScheduledEvent = function(event)
    local data = global.trainManager.trains[event.instanceId]
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringScheduledEvent", data.id)
end

TrainManager.GetManagedTrainById = function(trainId)
    return global.trainManager.trains[trainId]
end

return TrainManager
