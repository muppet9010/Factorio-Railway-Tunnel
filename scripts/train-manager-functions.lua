local TrainManagerFuncs = {}
local Utils = require("utility/utils")
-- Only has self contained functions in it. Doesn't require lookup to global trainmanager's managed trains.

TrainManagerFuncs.GetLeadingWagonOfTrain = function(train, isFrontStockLeading)
    if isFrontStockLeading then
        return train.front_stock
    else
        return train.back_stock
    end
end

TrainManagerFuncs.IsTrainHealthlyState = function(train)
    if train.state == defines.train_state.no_path or train.state == defines.train_state.path_lost then
        return false
    else
        return true
    end
end

TrainManagerFuncs.CarriageIsAPushingLoco = function(carriage, trainDirection)
    return carriage.type == "locomotive" and carriage.orientation == trainDirection
end

TrainManagerFuncs.CarriageIsAReverseLoco = function(carriage, trainOrientation)
    return carriage.type == "locomotive" and carriage.orientation ~= trainOrientation
end

TrainManagerFuncs.AddPushingLocoToEndOfTrain = function(lastCarriage, trainOrientation)
    -- TODO: This should be dynmaic distance based on the rear carriage and the one we are placing.
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

TrainManagerFuncs.CreateDummyTrain = function(exitPortalEntity, sourceTrain, skipScheduling)
    skipScheduling = skipScheduling or false
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
    if not skipScheduling then
        TrainManagerFuncs.TrainSetSchedule(dummyTrain, sourceTrain.schedule, false, sourceTrain.path_end_stop)
        if dummyTrain.state == defines.train_state.destination_full then
            -- If the train ends up in one of those states something has gone wrong.
            error("dummy train has unexpected state " .. tonumber(dummyTrain.state))
        end
    end
    return dummyTrain
end

TrainManagerFuncs.DestroyTrain = function(parentObject, referenceToSelf, localObjectRef)
    local dummyTrain = localObjectRef or parentObject[referenceToSelf]
    if dummyTrain ~= nil and dummyTrain.valid then
        for _, carriage in pairs(dummyTrain.carriages) do
            carriage.destroy()
        end
    end
    if parentObject ~= nil and referenceToSelf ~= nil then
        parentObject[referenceToSelf] = nil
    end
end

TrainManagerFuncs.TrainSetSchedule = function(train, schedule, isManual, targetStop, skipStateCheck)
    train.schedule, skipStateCheck = schedule, skipStateCheck or false
    if not isManual then
        TrainManagerFuncs.SetTrainToAuto(train, targetStop)
        if not skipStateCheck and not TrainManagerFuncs.IsTrainHealthlyState(train) then
            -- Any issue on the train from the previous tick should be detected by the state check. So this should only trigger after misplaced wagons.
            error("train doesn't have positive state after setting schedule")
        end
    else
        train.manual_mode = true
    end
end

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

TrainManagerFuncs.GetFutureCopiedTrainToUndergroundFirstWagonPosition = function(sourceTrain, tunnelAlignmentOrientation, tunnelInstanceValue, trainTravelOrientation, tunnelPortalEntranceDistanceFromCenter, aboveEntrancePortalEndSignalRailUnitNumber)
    -- This is very specifc to our scenario, but is standalone code still.
    local firstCarriageDistanceFromPortalEntrance = 0
    for _, railEntity in pairs(sourceTrain.path.rails) do
        -- This doesn't account for where on the current rail entity the carriage is, but should be accurate enough. Does cause up to half a carriage difference in train on both sides of a tunnel.
        firstCarriageDistanceFromPortalEntrance = firstCarriageDistanceFromPortalEntrance + TrainManagerFuncs.GetRailEntityLength(railEntity)
        if railEntity.unit_number == aboveEntrancePortalEndSignalRailUnitNumber then
            break
        end
    end
    local tunnelInitialPosition = Utils.RotatePositionAround0(tunnelAlignmentOrientation, {x = 1 + tunnelInstanceValue, y = 0})
    local firstCarriageDistanceFromPortalCenter = Utils.RotatePositionAround0(trainTravelOrientation, {x = 0, y = firstCarriageDistanceFromPortalEntrance + tunnelPortalEntranceDistanceFromCenter})
    local firstCarriagePosition = Utils.ApplyOffsetToPosition(tunnelInitialPosition, firstCarriageDistanceFromPortalCenter)
    return firstCarriagePosition
end

TrainManagerFuncs.GetRearCarriageOfLeavingTrain = function(leavingTrain, leavingTrainPushingLoco)
    -- Get the current rear carriage of the leaving train based on if a pushing loco was added. Handles train facing either direction (+/- speed) assuming the train is leaving the tunnel.
    local leavingTrainRearCarriage, leavingTrainRearCarriageIndex, leavingTrainRearCarriagePushingIndexMod
    if (leavingTrain.speed > 0) then
        leavingTrainRearCarriageIndex = #leavingTrain.carriages
        leavingTrainRearCarriagePushingIndexMod = -1
    else
        leavingTrainRearCarriageIndex = 1
        leavingTrainRearCarriagePushingIndexMod = 1
    end
    if leavingTrainPushingLoco ~= nil then
        leavingTrainRearCarriageIndex = leavingTrainRearCarriageIndex + leavingTrainRearCarriagePushingIndexMod
    end
    leavingTrainRearCarriage = leavingTrain.carriages[leavingTrainRearCarriageIndex]

    return leavingTrainRearCarriage
end

TrainManagerFuncs.GetCarriageToAddToLeavingTrain = function(sourceTrain, leavingTrainCarriagesPlaced)
    -- Get the next carraige to be placed from the underground train.
    local currentSourceTrainCarriageIndex = leavingTrainCarriagesPlaced
    local nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
    if (sourceTrain.speed < 0) then
        currentSourceTrainCarriageIndex = #sourceTrain.carriages - leavingTrainCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex
    end
    local nextSourceCarriageEntity = sourceTrain.carriages[nextSourceTrainCarriageIndex]
    return nextSourceCarriageEntity
end

TrainManagerFuncs.MoveLeavingTrainToFallbackPosition = function(leavingTrain, fallbackTargetRail)
    -- Set the train to move to the end of the tunnel (signal segment) and then return to its preivous schedule. Makes the situation more obvious for the player and easier to access the train.
    -- This action does loose any station reservation it had, but it would have already lost its path to reach this code block.
    local newSchedule = leavingTrain.schedule
    local endOfTunnelScheduleRecord = {rail = fallbackTargetRail, temporary = true}
    table.insert(newSchedule.records, newSchedule.current, endOfTunnelScheduleRecord)
    leavingTrain.schedule = newSchedule
end

TrainManagerFuncs.GetTrackDistanceBetweenPortalExitSignalAndTargetSignal = function(sourceTrain, exitPortalSignal, targetSignal)
    local targetRails = targetSignal.get_connected_rails() -- the stopping signal can be on multiple rails at once, however, only 1 will be in our path list.
    local targetRailUnitNumberAsKeys = Utils.TableInnerValueToKey(targetRails, "unit_number")

    -- Measure the distance from the end portal signal to the target signal. Ignores trains exact position and just deals with the tracks.
    local distance = 0
    local portalSignalEntityRail = exitPortalSignal.get_connected_rails()[1] -- Only ever 1 rail as inside portal.
    local portalSignalRailReached, lastRail = false, nil
    for _, railEntity in pairs(sourceTrain.get_rails()) do
        if not portalSignalRailReached and railEntity.unit_number == portalSignalEntityRail.unit_number then
            portalSignalRailReached = true
        elseif portalSignalRailReached then
            distance = distance + TrainManagerFuncs.GetRailEntityLength(railEntity)
            lastRail = railEntity
        end
    end
    for _, railEntity in pairs(sourceTrain.path.rails) do
        if lastRail ~= nil and railEntity.unit_number == lastRail.unit_number then
            -- Rail already counted as under the train.
            lastRail = nil
        else
            distance = distance + TrainManagerFuncs.GetRailEntityLength(railEntity)
            if targetRailUnitNumberAsKeys[railEntity.unit_number] then
                -- One of the rails attached to the signal has been reached in the path.
                break
            end
        end
    end

    return distance
end

TrainManagerFuncs.GetRailEntityLength = function(railEntity)
    if railEntity.type == "straight-rail" then
        return 2
    elseif railEntity.type == "curved-rail" then
        return 7.842081225095 -- According to rail segment length.
    else
        error("not valid rail type: " .. railEntity.type)
    end
end

TrainManagerFuncs.SetUndergroundTrainScheduleToTrackAtPosition = function(undergroundTrain, position)
    undergroundTrain.schedule = {
        current = 1,
        records = {
            {
                rail = undergroundTrain.front_stock.surface.find_entity("straight-rail", position)
            }
        }
    }
end

return TrainManagerFuncs
