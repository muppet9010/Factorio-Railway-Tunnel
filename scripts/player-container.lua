-- Controls when a player is in a train and it goes underground in a tunnel.

local PlayerContainer = {}
local Events = require("utility.events")
local Utils = require("utility.utils")
local EventScheduler = require("utility.event-scheduler")
local Common = require("scripts.common")
local RollingStockTypes = Common.RollingStockTypes

---@class PlayerContainer
---@field id UnitNumber @ Unit_number of the player container entity.
---@field entity LuaEntity @ The player container entity the player is sitting in.
---@field entityPositionLastTick Position @ The position of the player container entity last tick. As we only ever get the old position and add the new movement too it, before applying it and caching it for the next tick.
---@field playerIndex PlayerIndex
---@field player LuaPlayer @ The player the container is for.
---@field leavingCarriage LuaEntity @ The leaving train carriage entity this player will end up in.
---@field managedTrain ManagedTrain @ The global.trainManager.managedTrain object this is owned by.

PlayerContainer.CreateGlobals = function()
    global.playerContainers = global.playerContainers or {}
    global.playerContainers.playerIdToPlayerContainer = global.playerContainers.playerIdToPlayerContainer or {} ---@type table<PlayerIndex, PlayerContainer> @ A mapping of a player index to their container object (if they have one).
    global.playerContainers.playerTryLeaveVehicle = global.playerContainers.playerTryLeaveVehicle or {} ---@type table<PlayerIndex, LuaEntity> @ A mapping of the player index and the vehicle entity the player was in before they hit the enter/exit vehicle button.
    global.playerContainers.trainManageEntriesPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers or {} ---@type table<Id, table<UnitNumber, PlayerContainer>> @ Table of ManagedTrain.Id to a table of player containers, key'd by their UnitNumbers.
end

PlayerContainer.OnLoad = function()
    Events.RegisterHandlerCustomInput("railway_tunnel-toggle_driving", "PlayerContainer.OnToggleDrivingInput", PlayerContainer.OnToggleDrivingInput)
    Events.RegisterHandlerEvent(defines.events.on_player_driving_changed_state, "PlayerContainer.OnPlayerDrivingChangedState", PlayerContainer.OnPlayerDrivingChangedState)
    EventScheduler.RegisterScheduledEventType("PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled", PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled)

    MOD.Interfaces.PlayerContainer = MOD.Interfaces.PlayerContainer or {}
    MOD.Interfaces.PlayerContainer.PlayerInCarriageEnteringTunnel = PlayerContainer.PlayerInCarriageEnteringTunnel
    MOD.Interfaces.PlayerContainer.MoveATrainsPlayerContainers = PlayerContainer.MoveATrainsPlayerContainers
    MOD.Interfaces.PlayerContainer.TransferPlayersFromContainersToLeavingCarriages = PlayerContainer.TransferPlayersFromContainersToLeavingCarriages
    MOD.Interfaces.PlayerContainer.On_TunnelRemoved = PlayerContainer.On_TunnelRemoved
end

--- Called by the custom event before the game tries to change driving state. We don't block the default game behavor and only suppliment it if the player is in a tunnel player container and failed to get out at the time.
---
--- This special handling is needed as if the player is in a player container or in a railway carriage and they are on a portal/tunnel segment, they may be blocked from getting out of the vehicle by default Factorio due to the hitboxes and distance Factorio looks to eject the player within.
---@param event CustomInputEvent
PlayerContainer.OnToggleDrivingInput = function(event)
    local player = game.get_player(event.player_index)
    -- So the player.vehicle is the players state before the bse Factorio game tries to react to the key press.
    local playerVehicle = player.vehicle
    if playerVehicle == nil then
        -- Player is trying to get in to a vehicle and we don't ever care about this.
        return
    elseif global.playerContainers.playerTryLeaveVehicle[event.player_index] then
        -- We've already scheduled this player to try and get out of a player container next tick so ignore the event.
        return
    else
        -- Player is trying to get out of a current vehicle, so check if its a player container or train carriage.
        if playerVehicle.name == "railway_tunnel-player_container" or RollingStockTypes[playerVehicle.type] ~= nil then
            -- Vehicle is one we care about so schedule a check for next tick to see if the player got out of their vehicle ok. If they didn't then the mod will handle this then.
            global.playerContainers.playerTryLeaveVehicle[event.player_index] = playerVehicle
            -- Function is called before this tick's on_tick event runs and so we can safely schedule tick events for the same tick in this case.
            EventScheduler.ScheduleEventOnce(-1, "PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled", event.player_index, {playerIndex = event.player_index})
        end
    end
end

-- Called every time a player changes their driving state.
-- TOOD: not sure if we actually need this or can just do it on the Scheduled event...
---@param event on_player_driving_changed_state
PlayerContainer.OnPlayerDrivingChangedState = function(event)
    -- Check if the player was previously trying to get out of a potentially blocked vehicle or not. If there wasn't a recorded potentially blocked vehcile exit attempt just ignore the event.
    local oldVehicle = global.playerContainers.playerTryLeaveVehicle[event.player_index]
    if oldVehicle == nil then
        return
    end

    local player = game.get_player(event.player_index)
    if oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player as they will have jumped out of the tunnel mid length.
        PlayerContainer.PlayerLeaveTunnelVehicle(event.player_index, player, nil, oldVehicle)
    else
        -- Driving state changed from a non player_container so is base game working correctly.
        PlayerContainer.CancelPlayerTryLeaveTrain(event.player_index)
    end
end

--- Scheduled event to check if a player successfully got out of a potentially blocked vehicle type. If they didn't then do a modded eject from the vehicle if appropreiate.
---
--- Note: When the player is in editor mode the game announces the player entering and leaving vehicles. This doesn't happen in freeplay mode.
---@param event UtilityScheduledEvent_CallbackObject
PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled = function(event)
    -- Triggers after the OnPlayerDrivingChangedState() has run for this if it is going to.

    -- Check if the player still needs to have their ejection checked, or if it just worked already.
    --TODO: this is where I suspect the PlayerContainer.OnPlayerDrivingChangedState() contents should go and we can avoid the state changed event entirely.
    local playerIndex = event.data.playerIndex
    local oldVehicle = global.playerContainers.playerTryLeaveVehicle[playerIndex]
    if oldVehicle == nil then
        return
    end

    local player = game.get_player(playerIndex)
    if oldVehicle.name == "railway_tunnel-player_container" then
        -- In a player container so always handle the player.
        PlayerContainer.PlayerLeaveTunnelVehicle(playerIndex, player, nil, oldVehicle)
    else
        local player_vehicle = player.vehicle
        if player_vehicle ~= nil then
            -- Was in a train carriage before trying to get out and still is, so check if the carriage is ontop of a portal entity (blocks player getting out).
            -- Have to check within a small radius of the carriage as if the carriage is centered directly between 2 portal parts its position check would fail.
            local portalEntitiesFound = player_vehicle.surface.find_entities_filtered {position = player_vehicle.position, radius = 0.5, name = Common.PortalEndAndSegmentEntityNames, limit = 1}
            if #portalEntitiesFound == 1 then
                -- Carriage is on top of a portal part.
                PlayerContainer.PlayerLeaveTunnelVehicle(playerIndex, player, portalEntitiesFound[1], nil)
            end
        end

        -- Make sure we always remove this flag in all cases of this function being called.
        global.playerContainers.playerTryLeaveVehicle[playerIndex] = nil
    end
end

--- Eject the player from the vehcile and find them a place at the end of the nearest portal.
---@param playerIndex PlayerIndex
---@param player LuaPlayer
---@param portalEntity LuaEntity
---@param vehicle LuaEntity
PlayerContainer.PlayerLeaveTunnelVehicle = function(playerIndex, player, portalEntity, vehicle)
    local portalObject
    vehicle = vehicle or player.vehicle
    local playerContainer = global.playerContainers.playerIdToPlayerContainer[playerIndex]

    if portalEntity == nil then
        local managedTrain = playerContainer.managedTrain
        local player_position = player.position
        if Utils.GetDistance(managedTrain.entrancePortal.portalEntryPointPosition, player_position) < Utils.GetDistance(managedTrain.exitPortal.portalEntryPointPosition, player_position) then
            portalObject = managedTrain.entrancePortal
        else
            portalObject = managedTrain.exitPortal
        end
    else
        portalObject = global.portals.portalPartEntityIdToPortalPart[portalEntity.unit_number]
    end

    local playerPosition = player.surface.find_non_colliding_position("railway_tunnel-character_placement_leave_tunnel", portalObject.portalEntryPointPosition, 0, 0.2) -- Collides with rails and so we never get placed on the track.
    PlayerContainer.CancelPlayerTryLeaveTrain(playerIndex)
    vehicle.set_driver(nil)
    player.teleport(playerPosition)
    PlayerContainer.RemovePlayerContainer(global.playerContainers.playerIdToPlayerContainer[playerIndex])
end

--- Cancels any future scheduled event to check if the player has left the vehicle and removes their cached state of trying to leave their vehicle.
---@param playerIndex PlayerIndex
PlayerContainer.CancelPlayerTryLeaveTrain = function(playerIndex)
    global.playerContainers.playerTryLeaveVehicle[playerIndex] = nil
    EventScheduler.RemoveScheduledOnceEvents("PlayerContainer.OnToggleDrivingInputAfterChangedState_Scheduled", playerIndex, game.tick)
end

---@param managedTrain ManagedTrain
---@param driver LuaPlayer|LuaEntity
---@param playersLeavingCarriage LuaEntity
PlayerContainer.PlayerInCarriageEnteringTunnel = function(managedTrain, driver, playersLeavingCarriage)
    local player  ---type LuaPlayer
    if not driver.is_player() then
        -- Is a character body player driving.
        player = driver.player
    else
        -- Is a god/spectator player dirving (no character body).
        player = driver
    end
    local playerContainerEntity = managedTrain.surface.create_entity {name = "railway_tunnel-player_container", position = driver.position, force = driver.force}
    playerContainerEntity.operable = false -- Stops the container being opened by the player when riding in it from the toolbar area of the GUI.
    playerContainerEntity.destructible = false
    playerContainerEntity.set_driver(player)

    -- Record state for future updating.
    ---@type PlayerContainer
    local playerContainer = {
        id = playerContainerEntity.unit_number,
        playerIndex = player.index,
        player = player,
        entity = playerContainerEntity,
        entityPositionLastTick = playerContainerEntity.position,
        leavingCarriage = playersLeavingCarriage,
        managedTrain = managedTrain
    }
    global.playerContainers.playerIdToPlayerContainer[playerContainer.playerIndex] = playerContainer
    global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id] = global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id] or {}
    global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id][playerContainer.id] = playerContainer
end

--- Called each tick for a managedTrain if there is one or more players riding in it.
---@param managedTrain ManagedTrain
---@param speedAbs double @ The absolute speed of the train this tick.
PlayerContainer.MoveATrainsPlayerContainers = function(managedTrain, speedAbs)
    -- Update any player containers for this specific train.

    -- Just works for straight tunnels at present. This could in theory be cached, but once we add in curves it can't be and will be low concurrent calls per tick.
    local positionMovement = Utils.RotatePositionAround0(managedTrain.trainTravelOrientation, {x = 0, y = -speedAbs})

    local thisTrainsPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id]
    for _, playerContainer in pairs(thisTrainsPlayerContainers) do
        local playerContainerNewPosition = Utils.ApplyOffsetToPosition(playerContainer.entityPositionLastTick, positionMovement)
        playerContainer.entity.teleport(playerContainerNewPosition)
        playerContainer.entityPositionLastTick = playerContainerNewPosition
    end
end

-- Handle any players that were riding in this train when it was underground. Move them to the leaving train carriages and remove their player containers.
---@param managedTrain ManagedTrain
PlayerContainer.TransferPlayersFromContainersToLeavingCarriages = function(managedTrain)
    local thisTrainsPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id]
    for _, playerContainer in pairs(thisTrainsPlayerContainers) do
        playerContainer.leavingCarriage.set_driver(playerContainer.player)
        PlayerContainer.RemovePlayerContainer(playerContainer)
    end
end

-- Remove the player container and its globals.
---@param playerContainer PlayerContainer
PlayerContainer.RemovePlayerContainer = function(playerContainer)
    playerContainer.entity.destroy()
    global.playerContainers.playerIdToPlayerContainer[playerContainer.playerIndex] = nil
    local thisTrainsPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[playerContainer.managedTrain.id]
    if thisTrainsPlayerContainers ~= nil then
        thisTrainsPlayerContainers[playerContainer.id] = nil
        if #thisTrainsPlayerContainers == 0 then
            global.playerContainers.trainManageEntriesPlayerContainers[playerContainer.managedTrain.id] = nil
            playerContainer.managedTrain.undergroundTrainHasPlayersRiding = false
        end
    end
end

--- Called when the tunnel is removed and there's an active train using it with players underground. Kills the player whereveer they happened to be at the time.
---@param managedTrain ManagedTrain
---@param killForce? LuaForce|null @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity|null @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
PlayerContainer.On_TunnelRemoved = function(managedTrain, killForce, killerCauseEntity)
    local thisTrainsPlayerContainers = global.playerContainers.trainManageEntriesPlayerContainers[managedTrain.id]
    for _, playerContainer in pairs(thisTrainsPlayerContainers) do
        playerContainer.entity.set_driver(nil)
        local player = playerContainer.player
        local player_character = player.character
        if player_character ~= nil then
            player_character.die(killForce, killerCauseEntity)
        end
        PlayerContainer.RemovePlayerContainer(playerContainer)
    end
end

return PlayerContainer
