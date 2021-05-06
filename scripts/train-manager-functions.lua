local TrainManagerFuncs = {}
local Utils = require("utility/utils")

local ForceValidPathLeavingTunnel = false -- Defaults false - DEBUG SETTING when true to make a leaving train have a valid path.

TrainManagerFuncs.GetLeadingWagonOfTrain = function(train, isFrontStockLeading)
    if isFrontStockLeading then
        return train.front_stock
    else
        return train.back_stock
    end
end

TrainManagerFuncs.ConfirmMovingLeavingTrainState = function(train)
    -- Check a moving trains (non 0 speed) got a happy state. For use after manipulating the train and so assumes the train was in a happy state before we did this.
    if train.state == defines.train_state.on_the_path or train.state == defines.train_state.arrive_signal or train.state == defines.train_state.arrive_station then
        return true
    else
        return false
    end
end

TrainManagerFuncs.CarriageIsAPushingLoco = function(carriage, trainDirection)
    return carriage.type == "locomotive" and carriage.orientation == trainDirection
end

TrainManagerFuncs.AddPushingLocoToEndOfTrain = function(lastCarriage, trainOrientation)
    local pushingLocoPlacementPosition = Utils.ApplyOffsetToPosition(lastCarriage.position, Utils.RotatePositionAround0(trainOrientation, {x = 0, y = 4}))
    local pushingLocomotiveEntity = lastCarriage.surface.create_entity {name = "railway_tunnel-tunnel_portal_pushing_locomotive", position = pushingLocoPlacementPosition, force = lastCarriage.force, direction = Utils.OrientationToDirection(trainOrientation)}
    pushingLocomotiveEntity.destructible = false
    return pushingLocomotiveEntity
end

TrainManagerFuncs.CopyCarriage = function(targetSurface, refCarriage, newPosition, newDirection, refCarriageGoingForwards)
    local placedCarriage = refCarriage.clone {position = newPosition, surface = targetSurface, create_build_effect_smoke = false}
    if Utils.OrientationToDirection(placedCarriage.orientation) ~= newDirection then
        local wrongFrontOfTrain, correctFrontOfTrain
        if refCarriageGoingForwards then
            wrongFrontOfTrain, correctFrontOfTrain = defines.rail_direction.back, defines.rail_direction.front
        else
            wrongFrontOfTrain, correctFrontOfTrain = defines.rail_direction.front, defines.rail_direction.back
        end
        placedCarriage.disconnect_rolling_stock(wrongFrontOfTrain)
        placedCarriage.rotate()
        placedCarriage.connect_rolling_stock(correctFrontOfTrain)
    end
    return placedCarriage
end

TrainManagerFuncs.SetTrainAbsoluteSpeed = function(train, speed)
    if train.speed > 0 then
        train.speed = speed
    elseif train.speed < 0 then
        train.speed = -1 * speed
    elseif speed ~= 0 then
        -- this shouldn't be possible to reach, so throw an error for now
        error "unable to determine train direction"
    end
end

TrainManagerFuncs.SetTrainToAuto = function(train, targetStop)
    if targetStop ~= nil and targetStop.valid then
        -- Train limits on the original target train stop of the train going through the tunnel might prevent the exiting (dummy or real) train from pathing there, so we have to ensure that the original target stop has a slot open before setting the train to auto.
        local oldLimit = targetStop.trains_limit
        targetStop.trains_limit = targetStop.trains_count + 1
        train.manual_mode = false
        targetStop.trains_limit = oldLimit
    else
        -- There was no target stop, so no special handling needed.
        train.manual_mode = false
    end
end

TrainManagerFuncs.CreateDummyTrain = function(exitPortalEntity, sourceTrain)
    local locomotive =
        exitPortalEntity.surface.create_entity {
        name = "railway_tunnel-tunnel_exit_dummy_locomotive",
        position = exitPortalEntity.position,
        direction = exitPortalEntity.direction,
        force = exitPortalEntity.force,
        raise_built = false,
        create_build_effect_smoke = false
    }
    locomotive.destructible = false
    locomotive.burner.currently_burning = "coal"
    locomotive.burner.remaining_burning_fuel = 4000000
    local dummyTrain = locomotive.train
    dummyTrain.schedule = sourceTrain.schedule
    TrainManagerFuncs.SetTrainToAuto(dummyTrain, sourceTrain.path_end_stop)
    if (dummyTrain.state == defines.train_state.path_lost or dummyTrain.state == defines.train_state.no_path or dummyTrain.state == defines.train_state.destination_full) then
        -- If the train ends up in one of those states something has gone wrong.
        error("dummy train has unexpected state " .. tonumber(dummyTrain.state))
    end
    return dummyTrain
end

TrainManagerFuncs.DestroyTrain = function(parentObject, referenceToSelf)
    local dummyTrain = parentObject[referenceToSelf]
    if dummyTrain ~= nil and dummyTrain.valid then
        for _, carriage in pairs(dummyTrain.carriages) do
            carriage.destroy()
        end
    end
    parentObject[referenceToSelf] = nil
end

TrainManagerFuncs.IsSpeedGovernedByLeavingTrain = function(aboveTrainLeaving)
    if aboveTrainLeaving and aboveTrainLeaving.valid and aboveTrainLeaving.state ~= defines.train_state.on_the_path then
        return true
    else
        return false
    end
end

TrainManagerFuncs.GetTrainSpeed = function(aboveTrainLeaving, undergroundTrain)
    if TrainManagerFuncs.IsSpeedGovernedByLeavingTrain(aboveTrainLeaving) then
        return math.abs(aboveTrainLeaving.speed)
    else
        return math.abs(undergroundTrain.speed)
    end
end

TrainManagerFuncs.LeavingTrainSetSchedule = function(aboveTrainLeaving, schedule, isManual, targetStop, fallbackTargetRail)
    aboveTrainLeaving.schedule = schedule
    if not isManual then
        TrainManagerFuncs.SetTrainToAuto(aboveTrainLeaving, targetStop)

        -- Handle if the train doesn't have the desired state of moving away from tunnel.
        if not TrainManagerFuncs.ConfirmMovingLeavingTrainState(aboveTrainLeaving) then
            if ForceValidPathLeavingTunnel then
                -- In strict debug mode so flag undesired state.
                error("reemerging train should have positive movement state")
            end
            -- Set the train to move to the end of the tunnel (signal segment) as chance it can auto turn around and if not is far easier to access the train.
            local newSchedule = Utils.DeepCopy(aboveTrainLeaving.schedule)
            local endOfTunnelScheduleRecord = {rail = fallbackTargetRail, temporary = true}
            table.insert(newSchedule.records, newSchedule.current, endOfTunnelScheduleRecord)
            aboveTrainLeaving.schedule = newSchedule
        end
    end
end
--
TrainManagerFuncs.CopyTrain = function(refTrain, targetSurface, trainTravelOrientation, refTrainFacingForwards, trainTravelDirection, firstCarriagePosition)
    local nextCarriagePosition = firstCarriagePosition
    local trainCarriagesOffset = Utils.RotatePositionAround0(trainTravelOrientation, {x = 0, y = 7})
    local trainCarriagesForwardDirection = trainTravelDirection
    if not refTrainFacingForwards then
        trainCarriagesForwardDirection = Utils.LoopDirectionValue(trainCarriagesForwardDirection + 4)
    end

    local minCarriageIndex, maxCarriageIndex, carriageIterator = 1, #refTrain.carriages, 1
    if (refTrain.speed < 0) then
        minCarriageIndex, maxCarriageIndex, carriageIterator = #refTrain.carriages, 1, -1
    end
    local carriageIdToEntityList = {}
    local placedCarriage = nil
    for currentSourceTrainCarriageIndex = minCarriageIndex, maxCarriageIndex, carriageIterator do
        local refCarriage = refTrain.carriages[currentSourceTrainCarriageIndex]
        local carriageDirection = trainCarriagesForwardDirection
        if refCarriage.speed ~= refTrain.speed then
            carriageDirection = Utils.LoopDirectionValue(carriageDirection + 4)
        end
        local refCarriageGoingForwards = true
        if refCarriage.speed < 0 then
            refCarriageGoingForwards = false
        end
        placedCarriage = TrainManagerFuncs.CopyCarriage(targetSurface, refCarriage, nextCarriagePosition, carriageDirection, refCarriageGoingForwards)
        carriageIdToEntityList[refCarriage.unit_number] = placedCarriage

        nextCarriagePosition = Utils.ApplyOffsetToPosition(nextCarriagePosition, trainCarriagesOffset)
    end
    return placedCarriage.train, carriageIdToEntityList
end

TrainManagerFuncs.GetFutureCopiedTrainToUndergroundFirstWagonPosition = function(sourceTrain, tunnelAlignmentOrientation, tunnelInstanceValue, trainTravelOrientation, tunnelPortalEntranceDistanceFromCenter, surfaceEntrancePortalEndSignalRailUnitNumber)
    -- This is very specifc to our scenario, but is standalone code still.
    local firstCarriageDistanceFromPortalEntrance = 0
    for _, railEntity in pairs(sourceTrain.path.rails) do
        -- This doesn't account for where on the current rail entity the carriage is, but should be accurate enough. Does cause up to half a carriage difference in train on both sides of a tunnel.
        local thisRailLength = 2
        if railEntity.type == "curved-rail" then
            thisRailLength = 7 -- Estimate
        end
        firstCarriageDistanceFromPortalEntrance = firstCarriageDistanceFromPortalEntrance + thisRailLength
        if railEntity.unit_number == surfaceEntrancePortalEndSignalRailUnitNumber then
            break
        end
    end
    local tunnelInitialPosition = Utils.RotatePositionAround0(tunnelAlignmentOrientation, {x = 1 + tunnelInstanceValue, y = 0})
    local firstCarriageDistanceFromPortalCenter = Utils.RotatePositionAround0(trainTravelOrientation, {x = 0, y = firstCarriageDistanceFromPortalEntrance + tunnelPortalEntranceDistanceFromCenter})
    local firstCarriagePosition = Utils.ApplyOffsetToPosition(tunnelInitialPosition, firstCarriageDistanceFromPortalCenter)
    return firstCarriagePosition
end

return TrainManagerFuncs
