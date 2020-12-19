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
        aboveTrainEnteringId = The LuaTrain ID of the above Train Entering.
        aboveTrainLeaving = LuaTrain of the train created leaving the tunnel on the world surface.
        aboveTrainLeavingId = The LuaTrain ID of the above Train Leaving.
        trainDirection = defines.direction the train is heading in.
        entryEndSignal = LuaEntity of the rail signal at the end of the tunnel entrance track (forced closed signal).
        exitEndSignal = LuaEntity of the rail signal at the end of the tunnel exit track (forced closed signal).
        tunnel = ref to the global tunnel object.
        origTrainSchedule = copy of the origional train schedule table made when triggered the managed train process.
        undergroundTrain = LuaTrain of the train created in the underground surface.
        aboveSurface = LuaSurface of the main world surface.
        undergroundSurface = LuaSurface of the specific underground surface.
        aboveTrainLeavingCarriagesPlaced = count of how many carriages placed so far in the above train while its leaving.
    ]]
    global.trainManager.enteringTrainIdToManagedTrain = global.trainManager.enteringTrainIdToManagedTrain or {}
    global.trainManager.leavingTrainIdToManagedTrain = global.trainManager.leavingTrainIdToManagedTrain or {}
end

TrainManager.OnLoad = function()
    Interfaces.RegisterInterface("TrainManager.TrainEnteringInitial", TrainManager.TrainEnteringInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainEnteringOngoing", TrainManager.TrainEnteringOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainEnteringOngoing_OnTrainCreated", TrainManager.TrainEnteringOngoing_OnTrainCreated)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainUndergroundOngoing", TrainManager.TrainUndergroundOngoing)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingInitial", TrainManager.TrainLeavingInitial)
    EventScheduler.RegisterScheduledEventType("TrainManager.TrainLeavingOngoing", TrainManager.TrainLeavingOngoing)
    Events.RegisterHandlerEvent(defines.events.on_train_created, "TrainManager.TrainLeavingOngoing_OnTrainCreated", TrainManager.TrainLeavingOngoing_OnTrainCreated)
end

TrainManager.TrainEnteringInitial = function(trainEntering, entryEndSignal, tunnel)
    local trainManagerId = #global.trainManager.managedTrains + 1
    global.trainManager.managedTrains[trainManagerId] = {id = trainManagerId, aboveTrainEntering = trainEntering, aboveTrainEnteringId = trainEntering.id, entryEndSignal = entryEndSignal, tunnel = tunnel, origTrainSchedule = Utils.DeepCopy(trainEntering.schedule), trainDirection = Utils.LoopIntValueWithinRange(entryEndSignal.direction + 4, 0, 7)}
    local trainManagerEntry = global.trainManager.managedTrains[trainManagerId]

    --TODO: only handles single direction on the horizontal
    local exitEndSignal = tunnel.aboveEndSignals["eastern"][entryEndSignal.direction]
    if exitEndSignal.unit_number == entryEndSignal.unit_number then
        -- This should probably be done from the trains direction to track or some such thing?
        exitEndSignal = tunnel.aboveEndSignals["western"][entryEndSignal.direction]
    end
    trainManagerEntry.exitEndSignal = exitEndSignal

    trainManagerEntry.aboveSurface = trainManagerEntry.tunnel.aboveSurface
    trainManagerEntry.undergroundSurface = trainManagerEntry.tunnel.undergroundSurface
    global.trainManager.enteringTrainIdToManagedTrain[trainEntering.id] = trainManagerEntry

    local sourceTrain = trainManagerEntry.aboveTrainEntering
    local oldTrainEntities = sourceTrain.carriages
    --TODO: don't place the wagons on corners, place them straight - need to work out their real directionto the train, etc. Just extend the rails under the wagons if neeeded. Placing on corners leads them to not all be joined in to the same train on the underground.
    local rails = sourceTrain.get_rails()
    trainManagerEntry.aboveSurface.clone_entities {entities = rails, destination_offset = {0, 0}, destination_surface = trainManagerEntry.undergroundSurface}
    trainManagerEntry.aboveSurface.clone_entities {entities = oldTrainEntities, destination_offset = {0, 0}, destination_surface = trainManagerEntry.undergroundSurface}
    local trains = oldTrainEntities[1].force.get_trains(trainManagerEntry.undergroundSurface)
    local undergroundTrain = trains[#trains]
    undergroundTrain.speed = sourceTrain.speed

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

    if Utils.GetDistance(trainManagerEntry.aboveTrainEntering[nextStockAttributeName].position, trainManagerEntry.entryEndSignal.position) < 10 then
        trainManagerEntry.aboveTrainEntering[nextStockAttributeName].destroy()
    end
    if trainManagerEntry.aboveTrainEntering ~= nil and trainManagerEntry.aboveTrainEntering.valid and #trainManagerEntry.aboveTrainEntering[nextStockAttributeName] ~= nil then
        EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainEnteringOngoing", trainManagerEntry.id)
    else
        global.trainManager.enteringTrainIdToManagedTrain[trainManagerEntry.aboveTrainEnteringId] = nil
        trainManagerEntry.aboveTrainEntering = nil
    end
end

TrainManager.TrainEnteringOngoing_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end
    local managedTrain = global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] or global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_2]
    if managedTrain == nil then
        return
    end
    managedTrain.aboveTrainEntering = event.train
    managedTrain.aboveTrainEnteringId = event.train.id
    if global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] ~= nil then
        global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_1] = nil
    end
    if global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_2] ~= nil then
        global.trainManager.enteringTrainIdToManagedTrain[event.old_train_id_2] = nil
    end
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

    local sourceTrain, nextStockAttributeName = trainManagerEntry.undergroundTrain
    if (sourceTrain.speed > 0) then
        nextStockAttributeName = "front_stock"
    else
        nextStockAttributeName = "back_stock"
    end
    trainManagerEntry.undergroundSurface.clone_entities {entities = {sourceTrain[nextStockAttributeName]}, destination_offset = {0, 0}, destination_surface = trainManagerEntry.aboveSurface}
    trainManagerEntry.aboveTrainLeavingCarriagesPlaced = 1

    local trains = sourceTrain[nextStockAttributeName].force.get_trains(trainManagerEntry.aboveSurface)
    local aboveTrainLeaving, speed = trains[#trains]
    trainManagerEntry.aboveTrainLeaving, trainManagerEntry.aboveTrainLeavingId = aboveTrainLeaving, aboveTrainLeaving.id
    global.trainManager.leavingTrainIdToManagedTrain[aboveTrainLeaving.id] = trainManagerEntry
    if aboveTrainLeaving[nextStockAttributeName].orientation == trainManagerEntry.trainDirection * (1 / 8) then
        speed = sourceTrain.speed
    else
        speed = 0 - sourceTrain.speed
    end
    aboveTrainLeaving.speed = speed
    aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
    aboveTrainLeaving.manual_mode = false

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingOngoing = function(event)
    local trainManagerEntry = global.trainManager.managedTrains[event.instanceId]
    local aboveTrainLeaving, sourceTrain, nextSourceTrainCarriageIndex, currentSourceTrainCarriageIndex, speed = trainManagerEntry.aboveTrainLeaving, trainManagerEntry.undergroundTrain
    if (trainManagerEntry.undergroundTrain.speed > 0 and aboveTrainLeaving.speed > 0) or (trainManagerEntry.undergroundTrain.speed < 0 and aboveTrainLeaving.speed < 0) then
        speed = trainManagerEntry.undergroundTrain.speed
        currentSourceTrainCarriageIndex = trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
    else
        speed = 0 - trainManagerEntry.undergroundTrain.speed
        currentSourceTrainCarriageIndex = #sourceTrain.carraiges - trainManagerEntry.aboveTrainLeavingCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex - 1
    end

    local currentSourceCarriageEntity, nextSourceCarriageEntity = sourceTrain.carriages[currentSourceTrainCarriageIndex], sourceTrain.carriages[nextSourceTrainCarriageIndex]
    if nextSourceCarriageEntity == nil then
        -- All wagons placed so remove the underground train

        -- TODO: This won't handle long trains or ones with wrong facing loco's, etc.
        aboveTrainLeaving.schedule = trainManagerEntry.origTrainSchedule
        aboveTrainLeaving.manual_mode = false

        for _, carriage in pairs(trainManagerEntry.undergroundTrain.carriages) do
            carriage.destroy()
        end
        trainManagerEntry.undergroundTrain = nil
        return
    end
    if Utils.GetDistance(currentSourceCarriageEntity.position, trainManagerEntry.exitEndSignal.position) > 15 then
        --TODO: this is hard coded in direction and distance
        local nextCarriagePosition = Utils.ApplyOffsetToPosition(currentSourceCarriageEntity.position, {x = 7, y = 0})
        nextSourceCarriageEntity.clone {position = nextCarriagePosition, surface = trainManagerEntry.aboveSurface}
        trainManagerEntry.aboveTrainLeavingCarriagesPlaced = trainManagerEntry.aboveTrainLeavingCarriagesPlaced + 1

        -- LuaTrain has been replaced and updated by adding a wagon, so obtain it again.
        aboveTrainLeaving = trainManagerEntry.aboveTrainLeaving
    end
    aboveTrainLeaving.speed = speed

    EventScheduler.ScheduleEvent(game.tick + 1, "TrainManager.TrainLeavingOngoing", trainManagerEntry.id)
end

TrainManager.TrainLeavingOngoing_OnTrainCreated = function(event)
    if event.old_train_id_1 == nil then
        return
    end
    local managedTrain = global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_1] or global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_2]
    if managedTrain == nil then
        return
    end
    managedTrain.aboveTrainLeaving = event.train
    managedTrain.aboveTrainLeavingId = event.train.id
    if global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_1] ~= nil then
        global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_1] = nil
    end
    if global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_2] ~= nil then
        global.trainManager.leavingTrainIdToManagedTrain[event.old_train_id_2] = nil
    end
    global.trainManager.leavingTrainIdToManagedTrain[event.train.id] = managedTrain
end

return TrainManager
