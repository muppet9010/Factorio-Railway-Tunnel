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

TrainManagerFuncs.CarriageIsAPushingLoco = function(carriage, trainOrientation)
    return carriage.type == "locomotive" and carriage.orientation == trainOrientation
end

TrainManagerFuncs.CarriageIsAReverseLoco = function(carriage, trainOrientation)
    return carriage.type == "locomotive" and carriage.orientation ~= trainOrientation
end

TrainManagerFuncs.DoesTrainHaveAPushingLoco = function(train, trainOrientation)
    for _, carriage in pairs(train.carriages) do
        if TrainManagerFuncs.CarriageIsAPushingLoco(carriage, trainOrientation) then
            return true
        end
    end
    return false
end

TrainManagerFuncs.AddPushingLocoToEndOfTrain = function(lastCarriage, trainOrientation)
    local pushingLocoEntityName = "railway_tunnel-tunnel_portal_pushing_locomotive"
    local pushingLocoPlacementPosition = TrainManagerFuncs.GetNextCarriagePlacementPosition(trainOrientation, lastCarriage, pushingLocoEntityName)
    local pushingLocomotiveEntity = lastCarriage.surface.create_entity {name = pushingLocoEntityName, position = pushingLocoPlacementPosition, force = lastCarriage.force, direction = Utils.OrientationToDirection(trainOrientation)}
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

TrainManagerFuncs.GetRearCarriageOfLeavingTrain = function(leavingTrain, leavingTrainPushingLoco)
    -- Get the current rear carriage of the leaving train based on if a pushing loco was added. Handles train facing either direction (+/- speed) assuming the train is leaving the tunnel.
    local leavingTrainRearCarriage, leavingTrainRearCarriageIndex, leavingTrainRearCarriagePushingIndexMod
    if (leavingTrain.speed > 0) then
        leavingTrainRearCarriageIndex = #leavingTrain.carriages
        leavingTrainRearCarriagePushingIndexMod = -1
    elseif (leavingTrain.speed < 0) then
        leavingTrainRearCarriageIndex = 1
        leavingTrainRearCarriagePushingIndexMod = 1
    else
        error("TrainManagerFuncs.GetRearCarriageOfLeavingTrain() doesn't support 0 speed")
    end
    if leavingTrainPushingLoco ~= nil then
        leavingTrainRearCarriageIndex = leavingTrainRearCarriageIndex + leavingTrainRearCarriagePushingIndexMod
    end
    leavingTrainRearCarriage = leavingTrain.carriages[leavingTrainRearCarriageIndex]

    return leavingTrainRearCarriage
end

TrainManagerFuncs.GetCarriageToAddToLeavingTrain = function(sourceTrain, leavingTrainCarriagesPlaced)
    -- Get the next carriage to be placed from the underground train.
    local currentSourceTrainCarriageIndex, nextSourceTrainCarriageIndex
    if (sourceTrain.speed > 0) then
        currentSourceTrainCarriageIndex = leavingTrainCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex + 1
    elseif (sourceTrain.speed < 0) then
        currentSourceTrainCarriageIndex = #sourceTrain.carriages - leavingTrainCarriagesPlaced
        nextSourceTrainCarriageIndex = currentSourceTrainCarriageIndex
    else
        error("TrainManagerFuncs.GetCarriageToAddToLeavingTrain() doesn't support 0 speed sourceTrain")
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

TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetsRail = function(train, targetEntity, trainGoingForwards)
    -- This measures to the nearest edge of the target's rail, so doesn't include any of the target's rail's length.

    local targetRails
    if targetEntity.type == "train-stop" then
        targetRails = {targetEntity.connected_rail} -- A station as the stopping target can only be on 1 rail at a time.
    elseif targetEntity.type == "rail-signal" or targetEntity.type == "rail-chain-signal" then
        targetRails = targetEntity.get_connected_rails() -- A signal as the stopping target can be on multiple rails at once, however, only 1 will be in our path list.
    else
        error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetsRail() doesn't support targetEntity type: " .. targetEntity.type)
    end
    local targetRailUnitNumberAsKeys = Utils.TableInnerValueToKey(targetRails, "unit_number")

    -- Measure the distance from the train to the target entity. Ignores trains exact position and just deals with the tracks. The first rail isn't included here as we get the remaining part of the rail's distance later in function.
    local distance = 0
    for i, railEntity in pairs(train.path.rails) do
        if i > 1 then
            if targetRailUnitNumberAsKeys[railEntity.unit_number] then
                -- One of the rails attached to the target entity has been reached in the path, so stop before we count it.
                break
            end
            distance = distance + TrainManagerFuncs.GetRailEntityLength(railEntity.type)
        end
    end

    -- Add the remaining part of the first rail being used by the lead carriage. Carriage uses the lead joint as when it is "on" a rail piece. This isn't quite perfect when carriage is on a corner, but far closer than just the whole rail. In testing up to 0.5 tiles wrong for curves, but trains drift during tunnel use from speed as well so...
    local leadCarriage = TrainManagerFuncs.GetLeadingWagonOfTrain(train, trainGoingForwards)
    local leadCarriageForwardOrientation
    if leadCarriage.speed > 0 then
        leadCarriageForwardOrientation = leadCarriage.orientation
    elseif leadCarriage.speed < 0 then
        leadCarriageForwardOrientation = Utils.BoundFloatValueWithinRange(leadCarriage.orientation + 0.5, 0, 1)
    else
        error("TrainManagerFuncs.GetTrackDistanceBetweenTrainAndTargetsRail() doesn't support 0 speed train")
    end
    local leadCarriageEdgePositionOffset = Utils.RotatePositionAround0(leadCarriageForwardOrientation, {x = 0, y = 0 - TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)})
    local firstRailLeadCarriageUsedPosition = Utils.ApplyOffsetToPosition(leadCarriage.position, leadCarriageEdgePositionOffset)
    local firstRail = train.path.rails[1]
    local firstRailFarEndPosition = TrainManagerFuncs.GetRailFarEndPosition(firstRail, leadCarriageForwardOrientation)
    local distanceRemainingOnRail = Utils.GetDistance(firstRailLeadCarriageUsedPosition, firstRailFarEndPosition)
    if firstRail.type == "curved-rail" then
        distanceRemainingOnRail = distanceRemainingOnRail * 1.0663824640154573798004974128959 -- Rough conversion for the straight line distance (7.3539105243401) to curved arc distance (7.842081225095).
    end
    distance = distance + distanceRemainingOnRail

    -- Add the joint distance to the result to get the center position of the carriage.
    local distanceForCarriageCenter = distance + TrainManagerFuncs.GetCarriageJointDistance(leadCarriage.name)

    return distanceForCarriageCenter
end

TrainManagerFuncs.GetRailFarEndPosition = function(railEntity, forwardsOrientation)
    local railFarEndPosition
    if railEntity.type == "straight-rail" then
        railFarEndPosition = Utils.ApplyOffsetToPosition(railEntity.position, Utils.RotatePositionAround0(forwardsOrientation, {x = 0, y = -1}))
    elseif railEntity.type == "curved-rail" then
        -- Curved end offset position based on that a diagonal straight rail is 2 long and this sets where the curved end points must be.
        local directionDetails = {
            [defines.direction.north] = {
                straightEndOffset = {x = 1, y = 4},
                straightEndOrientation = 0.5,
                curvedEndOffset = {x = -1.8, y = -2.8},
                curvedEndOrientation = 0.875
            },
            [defines.direction.northeast] = {
                straightEndOffset = {x = -1, y = 4},
                straightEndOrientation = 0.5,
                curvedEndOffset = {x = 1.8, y = -2.8},
                curvedEndOrientation = 0.125
            },
            [defines.direction.east] = {
                straightEndOffset = {x = -4, y = 1},
                straightEndOrientation = 0.75,
                curvedEndOffset = {x = 2.8, y = -1.8},
                curvedEndOrientation = 0.125
            },
            [defines.direction.southeast] = {
                straightEndOffset = {x = -4, y = -1},
                straightEndOrientation = 0.75,
                curvedEndOffset = {x = 2.8, y = 1.8},
                curvedEndOrientation = 0.375
            },
            [defines.direction.south] = {
                straightEndOffset = {x = -1, y = -4},
                straightEndOrientation = 1,
                curvedEndOffset = {x = 1.8, y = 2.8},
                curvedEndOrientation = 0.375
            },
            [defines.direction.southwest] = {
                straightEndOffset = {x = 1, y = -4},
                straightEndOrientation = 0,
                curvedEndOffset = {x = -1.8, y = 2.8},
                curvedEndOrientation = 0.625
            },
            [defines.direction.west] = {
                straightEndOffset = {x = 4, y = -1},
                straightEndOrientation = 0.25,
                curvedEndOffset = {x = -2.8, y = 1.8},
                curvedEndOrientation = 0.625
            },
            [defines.direction.northwest] = {
                straightEndOffset = {x = 4, y = 1},
                straightEndOrientation = 0.25,
                curvedEndOffset = {x = -2.8, y = -1.8},
                curvedEndOrientation = 0.875
            }
        }
        local endoffset
        local thisTrackDirectionDetails = directionDetails[railEntity.direction]
        -- Rails specifically have 0 or 1 to avoid having to check for 0/1 wrapping. As the carriage on a specific curve has a very limited orientation range.
        if math.abs(forwardsOrientation - thisTrackDirectionDetails.straightEndOrientation) < math.abs(forwardsOrientation - thisTrackDirectionDetails.curvedEndOrientation) then
            -- Closer aligned to straight orientation.
            endoffset = thisTrackDirectionDetails.straightEndOffset
        else
            -- Closer aligned to curved orientation.
            endoffset = thisTrackDirectionDetails.curvedEndOffset
        end

        -- Mark on map end of rail locations for debugging.
        --rendering.draw_circle {color = {0, 0, 1, 1}, radius = 0.1, filled = true, target = railEntity, surface = railEntity.surface}
        --rendering.draw_circle {color = {0, 1, 0, 1}, radius = 0.1, filled = true, target = Utils.ApplyOffsetToPosition(railEntity.position, thisTrackDirectionDetails.straightEndOffset), surface = railEntity.surface}
        --rendering.draw_circle {color = {1, 0, 0, 1}, radius = 0.1, filled = true, target = Utils.ApplyOffsetToPosition(railEntity.position, thisTrackDirectionDetails.curvedEndOffset), surface = railEntity.surface}

        railFarEndPosition = Utils.ApplyOffsetToPosition(railEntity.position, endoffset)
    else
        error("not valid rail type: " .. railEntity.type)
    end

    return railFarEndPosition
end

TrainManagerFuncs.GetRailEntityLength = function(railEntityType)
    if railEntityType == "straight-rail" then
        return 2
    elseif railEntityType == "curved-rail" then
        return 7.842081225095
    else
        error("not valid rail type: " .. railEntityType)
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

TrainManagerFuncs.GetNextCarriagePlacementPosition = function(trainOrientation, lastCarriageEntity, nextCarriageEntityName)
    local carriagesDistance = TrainManagerFuncs.GetCarriagePlacementDistance(lastCarriageEntity.name) + TrainManagerFuncs.GetCarriagePlacementDistance(nextCarriageEntityName)
    local nextCarriageOffset = Utils.RotatePositionAround0(trainOrientation, {x = 0, y = carriagesDistance})
    return Utils.ApplyOffsetToPosition(lastCarriageEntity.position, nextCarriageOffset)
end

TrainManagerFuncs.GetCarriagePlacementDistance = function(carriageEntityName)
    -- For now we assume all unknown carriages have a gap of 7 as we can't get the connection and joint distance via API. Can hard code custom values in future if needed.
    if carriageEntityName == "railway_tunnel-tunnel_portal_pushing_locomotive" then
        return 0.5
    else
        return 3.5 -- Half of vanilla carriages 7 joint and connection distance.
    end
end

TrainManagerFuncs.GetCarriageJointDistance = function(carriageEntityName)
    -- For now we assume all unknown carriages have a joint of 4 as we can't get the joint distance via API. Can hard code custom values in future if needed.
    if carriageEntityName == "test" then
        return 0 -- Placeholder to stop syntax warnings on function variable. Will be needed when we support mods with custom train lengths.
    else
        return 2 -- Half of vanilla carriages 4 joint distance.
    end
end

TrainManagerFuncs.GetForwardPositionFromCurrentForDistance = function(undergroundTrain, distance)
    -- Applies the target distance to the train's leading carriage for the train direction on a straight track.
    local leadCarriage
    if undergroundTrain.speed > 0 then
        leadCarriage = undergroundTrain.front_stock
    elseif undergroundTrain.speed < 0 then
        leadCarriage = undergroundTrain.back_stock
    else
        error("TrainManagerFuncs.GetForwardPositionFromCurrentForDistance() doesn't support 0 speed underground train.")
    end
    local undergroundTrainOrientation
    if leadCarriage.speed > 0 then
        undergroundTrainOrientation = leadCarriage.orientation
    elseif leadCarriage.speed < 0 then
        undergroundTrainOrientation = Utils.BoundFloatValueWithinRange(leadCarriage.orientation + 0.5, 0, 1)
    else
        error("TrainManagerFuncs.GetForwardPositionFromCurrentForDistance() doesn't support 0 speed underground train")
    end
    return Utils.ApplyOffsetToPosition(
        leadCarriage.position,
        Utils.RotatePositionAround0(
            undergroundTrainOrientation,
            {
                x = 0,
                y = 0 - distance
            }
        )
    )
end

return TrainManagerFuncs
