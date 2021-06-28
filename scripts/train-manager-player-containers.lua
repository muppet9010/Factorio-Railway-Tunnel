local TrainManagerPlayerContainers = {}
local Events = require("utility/events")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Common = require("scripts/common")
local RollingStockTypes = Common.RollingStockTypes
-- This is required by train-manager as its the parent file and will make a lot of interface calls in otherwise. It also directly uses the managedTrain object passed in, rather than being abstracted.

---@class PlayerContainer
---@field id UnitNumber @Unit_number of the player container entity.
---@field entity LuaEntity @The player container entity the player is sitting in.
---@field player LuaPlayer @The player the container is for.
---@field undergroundCarriageEntity LuaEntity @The underground carriage entity this container is related to.
---@field undergroundCarriageId UnitNumber @The unit_number of the underground carriage entity this container is related to.
---@field managedTrain ManagedTrain @The global.trainManager.managedTrain object this is owned by.

TrainManagerPlayerContainers.CreateGlobals = function()
    global.playerContainers = global.playerContainers or {}
    global.playerContainers.containers = global.playerContainers.playerContainers or {} ---@type table<Id, PlayerContainer>
    global.playerContainers.playerIdToPlayerContainer = global.playerContainers.playerIdToPlayerContainer or {} ---@type table<int, PlayerContainer> @Key is the player index.
    global.playerContainers.playerTryLeaveVehicle = global.playerContainers.playerTryLeaveVehicle or {} ---@type table<PlayerIndex, LuaEntity>@Key is the player index. Value is the vehicle entity the player was in before they hit the enter/exit vehicle button.
    global.playerContainers.undergroudCarriageIdsToPlayerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer or {} ---@type table<int, PlayerContainer> @Key is the underground carriage unit_number. Value is the player playerContainer related to it.
    global.playerContainers.trainManageEntriesPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers or {} ---@type table<Id, table<Id, PlayerContainer>> @Table of ManagedTrain.Id to table of player containers by their id.
end

TrainManagerPlayerContainers.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-toggle_driving", "TrainManagerPlayerContainers.OnToggleDrivingInput", TrainManagerPlayerContainers.OnToggleDrivingInput)
    Events.RegisterHandlerEvent(defines.events.on_player_driving_changed_state, "TrainManagerPlayerContainers.OnPlayerDrivingChangedState", TrainManagerPlayerContainers.OnPlayerDrivingChangedState)
    EventScheduler.RegisterScheduledEventType("TrainManagerPlayerContainers.OnToggleDrivingInputAfterChangedState", TrainManagerPlayerContainers.OnToggleDrivingInputAfterChangedState)
end

---@param event CustomInputEvent
TrainManagerPlayerContainers.OnToggleDrivingInput = function(event)
    -- Called before the game tries to change driving state. So the player.vehicle is the players state before the change. Let the game do its natural thing and then correct the outcome if needed.
    -- Function is called before this tick's on_tick event runs and so we can safely schedule tick events for the same tick in this case.
    -- If the player is in a player container or in a carriage they may be on a portal/tunnel segment and thus are blocked by default Factorio from getting out of the vehicle.
    local player = game.get_player(event.player_index)
    local playerVehicle = player.vehicle
    if playerVehicle == nil then
        return
    elseif global.playerContainers.playerTryLeaveVehicle[player.index] then
        return
    else
        local playerVehicleType = playerVehicle.type
        if playerVehicle.name == "railway_tunnel-player_container" or RollingStockTypes[playerVehicleType] ~= nil then
            global.playerContainers.playerTryLeaveVehicle[player.index] = playerVehicle
            EventScheduler.ScheduleEventOnce(-1, "TrainManagerPlayerContainers.OnToggleDrivingInputAfterChangedState", player.index)
        end
    end
end

---@param event on_player_driving_changed_state
TrainManagerPlayerContainers.OnPlayerDrivingChangedState = function(event)
    local player = game.get_player(event.player_index)
    local oldVehicle = global.playerContainers.playerTryLeaveVehicle[player.index]
    if oldVehicle == nil then
        return
    end
    if oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player as they will have jumped out of the tunnel mid length.
        TrainManagerPlayerContainers.PlayerLeaveTunnelVehicle(player, nil, oldVehicle)
    else
        -- Driving state changed from a non player_container so is base game working correctly.
        TrainManagerPlayerContainers.CancelPlayerTryLeaveTrain(player)
    end
end

---@param event ScheduledEvent
TrainManagerPlayerContainers.OnToggleDrivingInputAfterChangedState = function(event)
    -- Triggers after the OnPlayerDrivingChangedState() has run for this if it is going to.
    -- When the player is in editor mode the game announces the player entering and leaving vehicles. This doesn't happen in freeplay mode.
    local player = game.get_player(event.instanceId)
    local oldVehicle = global.playerContainers.playerTryLeaveVehicle[player.index]
    if oldVehicle == nil then
        return
    end
    if oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player.
        TrainManagerPlayerContainers.PlayerLeaveTunnelVehicle(player, nil, oldVehicle)
    elseif player.vehicle ~= nil then
        -- Was in a train carriage before trying to get out and still is, so check if its on a portal entity (blocks player getting out).
        local portalEntitiesFound = player.vehicle.surface.find_entities_filtered {position = player.vehicle.position, name = "railway_tunnel-tunnel_portal_surface-placed", limit = 1}
        if #portalEntitiesFound == 1 then
            TrainManagerPlayerContainers.PlayerLeaveTunnelVehicle(player, portalEntitiesFound[1], nil)
        end
    end
end

---@param player LuaPlayer
---@param portalEntity LuaEntity
---@param vehicle LuaEntity
TrainManagerPlayerContainers.PlayerLeaveTunnelVehicle = function(player, portalEntity, vehicle)
    local portalObject
    vehicle = vehicle or player.vehicle
    local playerContainer = global.playerContainers.containers[vehicle.unit_number]

    if portalEntity == nil then
        local managedTrain = playerContainer.managedTrain
        if Utils.GetDistanceSingleAxis(managedTrain.aboveEntrancePortal.entity.position, player.position, managedTrain.tunnel.railAlignmentAxis) < Utils.GetDistanceSingleAxis(managedTrain.aboveExitPortal.entity.position, player.position, managedTrain.tunnel.railAlignmentAxis) then
            portalObject = managedTrain.aboveEntrancePortal
        else
            portalObject = managedTrain.aboveExitPortal
        end
    else
        portalObject = global.tunnelPortals.portals[portalEntity.unit_number]
    end
    local playerPosition = player.surface.find_non_colliding_position("railway_tunnel-character_placement_leave_tunnel", portalObject.portalEntrancePosition, 0, 0.2) -- Use a rail signal to test place as it collides with rails and so we never get placed on the track.
    TrainManagerPlayerContainers.CancelPlayerTryLeaveTrain(player)
    vehicle.set_driver(nil)
    player.teleport(playerPosition)
    TrainManagerPlayerContainers.RemovePlayerContainer(global.playerContainers.playerIdToPlayerContainer[player.index])
end

---@param player LuaPlayer
TrainManagerPlayerContainers.CancelPlayerTryLeaveTrain = function(player)
    global.playerContainers.playerTryLeaveVehicle[player.index] = nil
    EventScheduler.RemoveScheduledOnceEvents("TrainManagerPlayerContainers.OnToggleDrivingInputAfterChangedState", player.index, game.tick)
end

---@param managedTrain ManagedTrain
---@param driver LuaPlayer|LuaEntity
---@param playersCarriage LuaEntity
TrainManagerPlayerContainers.PlayerInCarriageEnteringTunnel = function(managedTrain, driver, playersCarriage)
    local player  ---type LuaPlayer
    if not driver.is_player() then
        -- Is a character body player driving.
        player = driver.player
    else
        -- Is a god/spectator player dirving (no character body).
        player = driver
    end
    local cachedRidingState = driver.riding_state -- Have to transfer it to new vehicle, otherwise manaully driven trains loose player input.
    local playerContainerEntity = managedTrain.aboveSurface.create_entity {name = "railway_tunnel-player_container", position = driver.position, force = driver.force}
    playerContainerEntity.operable = false
    playerContainerEntity.destructible = false -- Stops the container being opened by the player when riding in it from the toolbar area of the GUI.
    playerContainerEntity.set_driver(player)
    -- Stick a dummy character in the passanger seat to avoid another player being able to get in the car.
    local passangerCharacterEntity = managedTrain.aboveSurface.create_entity {name = "railway_tunnel-dummy_character", position = driver.position, force = driver.force}
    playerContainerEntity.set_passenger(passangerCharacterEntity)
    driver.riding_state = cachedRidingState

    -- Record state for future updating.
    local playersUndergroundCarriage = managedTrain.enteringCarriageIdToUndergroundCarriageEntity[playersCarriage.unit_number]
    ---@type PlayerContainer
    local playerContainer = {
        id = playerContainerEntity.unit_number,
        player = player,
        entity = playerContainerEntity,
        undergroundCarriageEntity = playersUndergroundCarriage,
        undergroundCarriageId = playersUndergroundCarriage.unit_number,
        managedTrain = managedTrain
    }
    global.playerContainers.undergroudCarriageIdsToPlayerContainer[playersUndergroundCarriage.unit_number] = playerContainer
    global.playerContainers.playerIdToPlayerContainer[playerContainer.player.index] = playerContainer
    global.playerContainers.containers[playerContainer.id] = playerContainer
    global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id] = global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id] or {}
    global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id][playerContainer.id] = playerContainer
end

---@param managedTrain ManagedTrain
TrainManagerPlayerContainers.MoveATrainsPlayerContainers = function(managedTrain)
    -- Update any player containers for this specific train.
    local thisTrainsPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id]
    if thisTrainsPlayerContainers == nil then
        return
    end
    for _, playerContainer in pairs(thisTrainsPlayerContainers) do
        local playerContainerPosition = Utils.ApplyOffsetToPosition(playerContainer.undergroundCarriageEntity.position, managedTrain.tunnel.undergroundTunnel.surfaceOffsetFromUnderground)
        playerContainer.entity.teleport(playerContainerPosition)
    end
end

---@param undergroundCarriage LuaEntity
---@param placedCarriage LuaEntity
TrainManagerPlayerContainers.TransferPlayerFromContainerForClonedUndergroundCarriage = function(undergroundCarriage, placedCarriage)
    -- Handle any players riding in this placed carriage.
    if global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number] ~= nil then
        local playerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
        local player = playerContainer.player
        local cachedRidingState = player.riding_state -- Have to transfer it to new vehicle, otherwise manaully driven trains loose player input.
        placedCarriage.set_driver(player)
        player.riding_state = cachedRidingState
        TrainManagerPlayerContainers.RemovePlayerContainer(playerContainer)
    end
end

---@param playerContainer PlayerContainer
TrainManagerPlayerContainers.RemovePlayerContainer = function(playerContainer)
    if playerContainer == nil then
        -- If the carriage hasn't entered the tunnel, but the carriage is in the portal theres no PlayerContainer yet.
        return
    end
    -- Remove the dummy passenger first so it doesn't get ejected on to the map.
    local dummyPassenger = playerContainer.entity.get_passenger()
    dummyPassenger.destroy()

    playerContainer.entity.destroy()
    global.playerContainers.undergroudCarriageIdsToPlayerContainer[playerContainer.undergroundCarriageId] = nil
    global.playerContainers.playerIdToPlayerContainer[playerContainer.player.index] = nil
    global.playerContainers.containers[playerContainer.id] = nil
    local thisTrainsPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[playerContainer.managedTrain.id]
    if thisTrainsPlayerContainers ~= nil then
        thisTrainsPlayerContainers[playerContainer.id] = nil
        if #thisTrainsPlayerContainers == 0 then
            global.playerContainers.trainManageEntriesPlayerContainers[playerContainer.managedTrain.id] = nil
        end
    end
end

---@param undergroundTrain LuaTrain
TrainManagerPlayerContainers.On_TerminateTunnelTrip = function(undergroundTrain)
    for _, undergroundCarriage in pairs(undergroundTrain.carriages) do
        local playerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
        if playerContainer ~= nil then
            TrainManagerPlayerContainers.RemovePlayerContainer(playerContainer)
        end
    end
end

---@param undergroundTrain LuaTrain
TrainManagerPlayerContainers.On_TunnelRemoved = function(undergroundTrain)
    if undergroundTrain ~= nil then
        for _, undergroundCarriage in pairs(undergroundTrain.carriages) do
            local playerContainer = global.playerContainers.undergroudCarriageIdsToPlayerContainer[undergroundCarriage.unit_number]
            if playerContainer ~= nil then
                playerContainer.entity.set_driver(nil)
                local player = playerContainer.player
                if player.character ~= nil then
                    player.character.die()
                end
                TrainManagerPlayerContainers.RemovePlayerContainer(playerContainer)
            end
        end
    end
end

---@param oldManagedTrain ManagedTrain
---@param newManagedTrain ManagedTrain
TrainManagerPlayerContainers.On_TrainManagerReversed = function(oldManagedTrain, newManagedTrain)
    local trainManagerEntriesPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[oldManagedTrain.id]
    if trainManagerEntriesPlayerContainers ~= nil then
        global.playerContainers.trainManageEntriesPlayerContainers[newManagedTrain.id] = trainManagerEntriesPlayerContainers
        global.playerContainers.trainManageEntriesPlayerContainers[oldManagedTrain.id] = nil
        for _, playerContainer in pairs(trainManagerEntriesPlayerContainers) do
            playerContainer.managedTrain = newManagedTrain
        end
    end
end

return TrainManagerPlayerContainers
