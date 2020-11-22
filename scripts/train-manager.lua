local EventScheduler = require("utility/event-scheduler")
local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.trains = global.trainManager.trains or {}
end

TrainManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEntering", TrainManager.TrainEntering)
    Interfaces.RegisterInterface("TrainManager.TrainFirstEntering", TrainManager.TrainFirstEntering)
    Interfaces.RegisterInterface("TrainManager.GetManagedTrainById", TrainManager.GetManagedTrainById)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUnderground", TrainManager.TrainUnderground)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainFirstLeaving", TrainManager.TrainFirstLeaving)
end

TrainManager.TrainFirstEntering = function(trainEntering, endSignal, tunnel)
    local trainManagerId = #global.trainManager.trains + 1
    global.trainManager.trains[trainManagerId] = {id = trainManagerId, aboveTrainEntering = trainEntering, endSignal = endSignal, tunnel = tunnel, origTrainSchedule = Utils.DeepCopy(trainEntering.schedule)}
    TrainManager.CloneEnteringTrainToUnderground(global.trainManager.trains[trainManagerId])
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEntering", trainManagerId)
end

TrainManager.TrainEntering = function(event)
    local trainManagerEntry = global.trainManager.trains[event.instanceId]
    trainManagerEntry.aboveTrainEntering.manual_mode = true
    trainManagerEntry.aboveTrainEntering.speed = trainManagerEntry.undergroundTrain.speed
    if Utils.GetDistance(trainManagerEntry.aboveTrainEntering.carriages[1].position, trainManagerEntry.endSignal.position) > 10 then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEntering", trainManagerEntry.id)
    else
        trainManagerEntry.aboveTrainEntering.carriages[1].destroy()
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUnderground", trainManagerEntry.id)
    end
end

TrainManager.TrainUnderground = function(event)
    local trainManagerEntry = global.trainManager.trains[event.instanceId]
    if Utils.GetDistance(trainManagerEntry.undergroundTrain.carriages[1].position, {-40, 1}) > 10 then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUnderground", trainManagerEntry.id)
    else
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainFirstLeaving", trainManagerEntry.id)
    end
end

TrainManager.TrainFirstLeaving = function(event)
    local trainManagerEntry = global.trainManager.trains[event.instanceId]
    local aboveTrainLeaving = TrainManager.CloneTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.tunnel.aboveSurface)
    trainManagerEntry.aboveTrainLeaving = aboveTrainLeaving
    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    aboveTrainLeaving.manual_mode = false

    trainManagerEntry.undergroundTrain.carriages[1].destroy()
end

TrainManager.CloneEnteringTrainToUnderground = function(trainManagerEntry)
    local undergroundTrain = TrainManager.CloneTrain(trainManagerEntry.aboveTrainEntering, trainManagerEntry.tunnel.undergroundSurface)
    trainManagerEntry.undergroundTrain = undergroundTrain
    undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                rail = trainManagerEntry.tunnel.undergroundSurface.find_entity("straight-rail", {x = -99, y = 1})
            }
        }
    }
    undergroundTrain.manual_mode = false
end

TrainManager.CloneTrain = function(refTrain, targetSurface)
    local newTrainEntities = {}
    for _, carriage in pairs(refTrain.carriages) do
        table.insert(newTrainEntities, targetSurface.create_entity {name = carriage.name, position = carriage.position, force = carriage.force, direction = Utils.OrientationToDirection(carriage.orientation)})
    end
    newTrainEntities[1].insert("rocket-fuel")
    local newTrain = newTrainEntities[1].train
    newTrain.speed = refTrain.speed
    return newTrain
end

TrainManager.GetManagedTrainById = function(trainId)
    return global.trainManager.trains[trainId]
end

return TrainManager
