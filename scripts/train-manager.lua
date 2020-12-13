local EventScheduler = require("utility/event-scheduler")
local TrainManager = {}
local Interfaces = require("utility/interfaces")
local Events = require("utility/events")
local Utils = require("utility/utils")

TrainManager.CreateGlobals = function()
    global.trainManager = global.trainManager or {}
    global.trainManager.managedTrains = global.trainManager.managedTrains or {} --[[
        id = uniqiue id of this managed train passing through the tunnel.
        aboveTrainEntering = LuaTrain of the entering train on the world surface.
        endSignal = LuaEntity of the rail signal at the end of the tunnel entrance track (forced closed signal).
        tunnel = ref to the global tunnel object.
        origTrainSchedule = copy of the origional train schedule table made when triggered the managed train process.
        undergroundTrain = LuaTrain of the train created in the underground surface.
        aboveTrainLeaving = LuaTrain of the train created leaving the tunnel on the world surface.
    ]]
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface("TrainManager.TrainEnteringInitial", TrainManager.TrainEnteringInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEnteringOngoing", TrainManager.TrainEnteringOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainEnteringOngoing_OnTrainCreated", TrainManager.TrainEnteringOngoing_OnTrainCreated)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUndergroundOngoing", TrainManager.TrainUndergroundOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingInitial", TrainManager.TrainLeavingInitial)
end

TrainManager.TrainEnteringInitial = function(trainEntering, endSignal, tunnel)
    local trainManagerId = #global.trainManager.managedTrains + 1
    global.trainManager.managedTrains[trainManagerId] = {id = trainManagerId, aboveTrainEntering = trainEntering, endSignal = endSignal, tunnel = tunnel, origTrainSchedule = Utils.DeepCopy(trainEntering.schedule)}
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerId]
    global.trainManager.enteringTrainIdToManagedTrain[trainEntering.id] = trainManagerEntry

    local refTrain, targetSurface = trainManagerEntry.aboveTrainEntering, trainManagerEntry.tunnel.undergroundSurface
    local oldTrainEntities = refTrain.carriages
    local refTrainCarriage1 = oldTrainEntities[1]
    local rails = refTrain.get_rails()
    refTrainCarriage1.surface.clone_entities {entities = rails, destination_offset = {0, 0}, destination_surface = targetSurface}
    refTrainCarriage1.surface.clone_entities {entities = oldTrainEntities, destination_offset = {0, 0}, destination_surface = targetSurface}
    local trains = refTrainCarriage1.force.get_trains(targetSurface)
    local undergroundTrain = trains[#trains]
    undergroundTrain.speed = refTrain.speed

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

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerId)
    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerId)
end

TrainManager.TrainEnteringOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    trainManagerEntry.aboveTrainEntering.manual_mode = true
    local nextStockAttributeName
    if (trainManagerEntry.undergroundTrain.speed > 0 and trainManagerEntry.aboveTrainEntering.speed > 0) or (trainManagerEntry.undergroundTrain.speed < 0 and trainManagerEntry.aboveTrainEntering.speed < 0) then
        trainManagerEntry.aboveTrainEntering.speed = trainManagerEntry.undergroundTrain.speed
        nextStockAttributeName = "front_stock"
    else
        trainManagerEntry.aboveTrainEntering.speed = 0 - trainManagerEntry.undergroundTrain.speed
        nextStockAttributeName = "back_stock"
    end

    if Utils.GetDistance(trainManagerEntry.aboveTrainEntering[nextStockAttributeName].position, trainManagerEntry.endSignal.position) < 10 then
        trainManagerEntry.aboveTrainEntering[nextStockAttributeName].destroy()
    end
    if trainManagerEntry.aboveTrainEntering ~= nil and trainManagerEntry.aboveTrainEntering.valid and #trainManagerEntry.aboveTrainEntering[nextStockAttributeName] ~= nil then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    else
        trainManagerEntry.aboveTrainEntering = nil
    end
end

TrainManager.TrainEnteringOngoing_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end
    local managedTrain = global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1]
    if managedTrain == nil then
        return
    end
    managedTrain.aboveTrainEntering = event.train
    global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] = nil
    global.trainManager.enteringTrainIdToManagedTrain[event.train.id] = managedTrain
end

TrainManager.TrainUndergroundOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    if Utils.GetDistance(trainManagerEntry.undergroundTrain.carriages[1].position, {-40, 1}) > 10 then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainUndergroundOngoing", trainManagerEntry.id)
    else
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingInitial", trainManagerEntry.id)
    end
end

TrainManager.TrainLeavingInitial = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    --TODO: lift CloneTrain code out as needs to be unique and looping.
    local aboveTrainLeaving = TrainManager.CloneTrain(trainManagerEntry.undergroundTrain, trainManagerEntry.tunnel.aboveSurface)
    trainManagerEntry.aboveTrainLeaving = aboveTrainLeaving
    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    aboveTrainLeaving.manual_mode = false

    trainManagerEntry.undergroundTrain.carriages[1].destroy()
end

TrainManager.CloneTrain = function(refTrain, targetSurface, includeRails)
    local oldTrainEntities = refTrain.carriages
    local refTrainCarriage1 = oldTrainEntities[1]
    if includeRails then
        local rails = refTrain.get_rails()
        refTrainCarriage1.surface.clone_entities {entities = rails, destination_offset = {0, 0}, destination_surface = targetSurface}
    end

    refTrainCarriage1.surface.clone_entities {entities = oldTrainEntities, destination_offset = {0, 0}, destination_surface = targetSurface}

    local trains = refTrainCarriage1.force.get_trains(targetSurface)
    local newTrain = trains[#trains]
    newTrain.speed = refTrain.speed
    return newTrain
end

return TrainManager
