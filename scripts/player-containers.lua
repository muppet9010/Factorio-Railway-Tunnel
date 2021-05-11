local PlayerContainers = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
-- This is required by train-manager as its the parent file and will make a lot of interface calls in otherwise. It also directly uses the trainManagerEntry object passed in, rather than being abstracted.

PlayerContainers.CreateGlobals = function()
    global.playerContainers = global.playerContainers or {}
    global.playerContainers.containers = global.playerContainers.playerContainers or {}
    --[[
        [id] = {
            id = unit_number of the player container entity.
            entity = the player container entity the player is sitting in.
            player = LuaPlayer.
            undergroundCarriageEntity = the underground carriage entity this container is related to.
            undergroundCarriageId = the unit_number of the underground carriage entity this container is related to.
            trainManagerEntry = the global.trainManager.trainManagerEntry object this is owned by.
        }
    ]]
    global.playerContainers.playerIdToPlayerContainer = global.playerContainers.playerIdToPlayerContainer or {}
    global.playerContainers.playerTryLeaveVehicle = global.playerContainers.playerTryLeaveVehicle or {}
    --[[
        [id] = {
            id = player index.
            oldVehicle = the vehicle entity the player was in before they hit the enter/exit vehicle button.
        }
    ]]
    global.playerContainers.undergroudCarriageIdsToPlayerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer or {} -- Table for each underground carriage with a player container related to it. Key'd by underground carraige unit number.
end

PlayerContainers.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-toggle_driving", "PlayerContainers.OnToggleDrivingInput", PlayerContainers.OnToggleDrivingInput)
    Events.RegisterHandlerEvent(defines.events.on_player_driving_changed_state, "PlayerContainers.OnPlayerDrivingChangedState", PlayerContainers.OnPlayerDrivingChangedState)
    EventScheduler.RegisterScheduledEventType("PlayerContainers.OnToggleDrivingInputAfterChangedState", PlayerContainers.OnToggleDrivingInputAfterChangedState)
end

PlayerContainers.OnToggleDrivingInput = function(event)
    -- Called before the game tries to change driving state. So the player.vehicle is the players state before the change. Let the game do its natural thing and then correct the outcome if needed.
    -- Function is called before this tick's on_tick event runs and so we can safely schedule tick events for the same tick in this case.
    local player = game.get_player(event.player_index)
    local playerVehicle = player.vehicle
    if playerVehicle == nil then
        return
    elseif playerVehicle.name == "railway_tunnel-player_container" or playerVehicle.type == "locomotive" or playerVehicle.type == "cargo-wagon" or playerVehicle.type == "fluid-wagon" or playerVehicle.type == "artillery-wagon" then
        global.playerContainers.playerTryLeaveVehicle[player.index] = {id = player.index, oldVehicle = playerVehicle}
        EventScheduler.ScheduleEventOnce(game.tick, "PlayerContainers.OnToggleDrivingInputAfterChangedState", player.index)
    end
end

PlayerContainers.OnPlayerDrivingChangedState = function(event)
    local player = game.get_player(event.player_index)
    local details = global.playerContainers.playerTryLeaveVehicle[player.index]
    if details == nil then
        return
    end
    if details.oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player as they will have jumped out of the tunnel mid length.
        PlayerContainers.PlayerLeaveTunnelVehicle(player, nil, details.oldVehicle)
    else
        -- Driving state changed from a non player_container so is base game working correctly.
        PlayerContainers.CancelPlayerTryLeaveTrain(player)
    end
end

PlayerContainers.OnToggleDrivingInputAfterChangedState = function(event)
    -- Triggers after the OnPlayerDrivingChangedState() has run for this if it is going to.
    local player = game.get_player(event.instanceId)
    local details = global.playerContainers.playerTryLeaveVehicle[player.index]
    if details == nil then
        return
    end
    if details.oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player.
        PlayerContainers.PlayerLeaveTunnelVehicle(player, nil, details.oldVehicle)
    elseif player.vehicle ~= nil then
        -- Was in a train carriage before trying to get out and still is, so check if its on a portal entity (blocks player getting out).
        local portalEntitiesFound = player.vehicle.surface.find_entities_filtered {position = player.vehicle.position, name = "railway_tunnel-tunnel_portal_surface-placed", limit = 1}
        if #portalEntitiesFound == 1 then
            PlayerContainers.PlayerLeaveTunnelVehicle(player, portalEntitiesFound[1], nil)
        end
    end
end

PlayerContainers.PlayerLeaveTunnelVehicle = function(player, portalEntity, vehicle)
    local portalObject
    vehicle = vehicle or player.vehicle
    local playerContainer = global.playerContainers.containers[vehicle.unit_number]

    if portalEntity == nil then
        local trainManagerEntry = playerContainer.trainManagerEntry
        if Utils.GetDistanceSingleAxis(trainManagerEntry.aboveEntrancePortal.entity.position, player.position, trainManagerEntry.tunnel.railAlignmentAxis) < Utils.GetDistanceSingleAxis(trainManagerEntry.aboveExitPortal.entity.position, player.position, trainManagerEntry.tunnel.railAlignmentAxis) then
            portalObject = trainManagerEntry.aboveEntrancePortal
        else
            portalObject = trainManagerEntry.aboveExitPortal
        end
    else
        portalObject = global.tunnelPortals.portals[portalEntity.unit_number]
    end
    local playerPosition = player.surface.find_non_colliding_position("railway_tunnel-character_placement_leave_tunnel", portalObject.portalEntrancePosition, 0, 0.2) -- Use a rail signal to test place as it collides with rails and so we never get placed on the track.
    PlayerContainers.CancelPlayerTryLeaveTrain(player)
    vehicle.set_driver(nil)
    player.teleport(playerPosition)
    PlayerContainers.RemovePlayerContainer(global.playerContainers.playerIdToPlayerContainer[player.index])
end

PlayerContainers.CancelPlayerTryLeaveTrain = function(player)
    global.playerContainers.playerTryLeaveVehicle[player.index] = nil
    EventScheduler.RemoveScheduledOnceEvents("PlayerContainers.OnToggleDrivingInputAfterChangedState", player.index, game.tick)
end

PlayerContainers.PlayerInCarriageEnteringTunnel = function(trainManagerEntry, driver, playersCarriage)
    local player
    if not driver.is_player() then
        -- Is a character player driving.
        player = driver.player
    else
        player = driver
    end
    local playerContainerEntity = trainManagerEntry.aboveSurface.create_entity {name = "railway_tunnel-player_container", position = driver.position, force = driver.force}
    playerContainerEntity.destructible = false
    playerContainerEntity.set_driver(player)

    -- Record state for future updating.
    local playersUndergroundCarriage = trainManagerEntry.enteringCarriageIdToUndergroundCarriageEntity[playersCarriage.unit_number]
    local playerContainer = {
        id = playerContainerEntity.unit_number,
        player = player,
        entity = playerContainerEntity,
        undergroundCarriageEntity = playersUndergroundCarriage,
        undergroundCarriageId = playersUndergroundCarriage.unit_number,
        trainManagerEntry = trainManagerEntry
    }
    global.playerContainers.undergroudCarriageIdsToPlayerContainer[playersUndergroundCarriage.unit_number] = playerContainer
    global.playerContainers.playerIdToPlayerContainer[playerContainer.player.index] = playerContainer
    global.playerContainers.containers[playerContainer.id] = playerContainer
end

PlayerContainers.MoveTrainsPlayerContainers = function(trainManagerEntry)
    -- Update any player containers for the train.
    for _, playerContainer in pairs(global.playerContainers.undergroudCarriageIdsToPlayerContainer) do
        local playerContainerPosition = Utils.ApplyOffsetToPosition(playerContainer.undergroundCarriageEntity.position, trainManagerEntry.tunnel.undergroundTunnel.surfaceOffsetFromUnderground)
        playerContainer.entity.teleport(playerContainerPosition)
    end
end

PlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage = function(undergroundCarriage, placedCarriage)
    -- Handle any players riding in this placed carriage.
    if global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number] ~= nil then
        local playerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
        placedCarriage.set_driver(playerContainer.player)
        PlayerContainers.RemovePlayerContainer(playerContainer)
    end
end

PlayerContainers.RemovePlayerContainer = function(playerContainer)
    if playerContainer == nil then
        -- If the carriage hasn't entered the tunnel, but the carriage is in the portal theres no PlayerContainer yet.
        return
    end
    playerContainer.entity.destroy()
    global.playerContainers.undergroudCarriageIdsToPlayerContainer[playerContainer.undergroundCarriageId] = nil
    global.playerContainers.playerIdToPlayerContainer[playerContainer.player.index] = nil
    global.playerContainers.containers[playerContainer.id] = nil
end

PlayerContainers.On_TerminateTunnelTrip = function(undergroundTrain)
    for _, undergroundCarriage in pairs(undergroundTrain.carriages) do
        local playerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
        if playerContainer ~= nil then
            PlayerContainers.RemovePlayerContainer(playerContainer)
        end
    end
end

PlayerContainers.On_TunnelRemoved = function(undergroundTrain)
    if undergroundTrain ~= nil then
        for _, undergroundCarriage in pairs(undergroundTrain.carriages) do
            local playerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
            if playerContainer ~= nil then
                playerContainer.player.destroy()
                PlayerContainers.RemovePlayerContainer(playerContainer)
            end
        end
    end
end

return PlayerContainers
