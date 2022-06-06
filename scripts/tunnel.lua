local Events = require("utility.events")
local Tunnel = {}
local TunnelShared = require("scripts.tunnel-shared")
local Common = require("scripts.common")
local TunnelRailEntityNames, UndergroundSegmentAndAllPortalEntityNames = Common.TunnelRailEntityNames, Common.UndergroundSegmentAndAllPortalEntityNames
local EventUtils = require("utility.event-utils")
local PositionUtils = require("utility.position-utils")

---@class Tunnel @ the tunnel object that managed trains can pass through.
---@field id Id @ unqiue id of the tunnel.
---@field surface LuaSurface
---@field force LuaForce
---@field portals Portal[]
---@field underground Underground
---@field managedTrain ManagedTrain @ one is currently using this tunnel.
---@field tunnelRailEntities table<UnitNumber, LuaEntity> @ the underground rail entities (doesn't include above ground crossing rails).
---@field portalRailEntities table<UnitNumber, LuaEntity> @ the rail entities that are part of the portals.
---@field maxTrainLengthTiles uint @ the max train length in tiles this tunnel supports.
---@field guiOpenedByPlayers table<PlayerIndex, LuaPlayer> @ A table of player Id's to LuaPlayer's who have a GUI opened on this tunnel.

---@class RemoteTunnelDetails @ used by remote interface calls only.
---@field tunnelId Id @ Id of the tunnel.
---@field portals RemotePortalDetails[] @ the 2 portals in this tunnel.
---@field undergroundSegmentEntities  table<UnitNumber, LuaEntity> @ array of all the underground segments making up the underground section of the tunnel.
---@field tunnelUsageId Id @ the managed train using the tunnel if any.

---@class RemotePortalDetails
---@field portalId Id @ unique id of the portal object.
---@field portalPartEntities table<UnitNumber, LuaEntity> @ array of all the parts making up the portal.

Tunnel.CreateGlobals = function()
    global.tunnels = global.tunnels or {}
    global.tunnels.nextTunnelId = global.tunnels.nextTunnelId or 1
    global.tunnels.tunnels = global.tunnels.tunnels or {} ---@type table<Id, Tunnel>
    global.tunnels.transitionSignals = global.tunnels.transitionSignals or {} ---@type table<UnitNumber, PortalTransitionSignal> @ the tunnel's portal's "inSignal" transitionSignal objects. Is used as a quick lookup for trains stopping at this signal and reserving the tunnel.
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)
    Events.RegisterHandlerEvent(defines.events.on_player_rotated_entity, "Tunnel.OnPlayerRotatedEntity", Tunnel.OnPlayerRotatedEntity)

    MOD.Interfaces.Tunnel = MOD.Interfaces.Tunnel or {}
    MOD.Interfaces.Tunnel.CompleteTunnel = Tunnel.CompleteTunnel
    MOD.Interfaces.Tunnel.RegisterTransitionSignal = Tunnel.RegisterTransitionSignal
    MOD.Interfaces.Tunnel.DeregisterTransitionSignal = Tunnel.DeregisterTransitionSignal
    MOD.Interfaces.Tunnel.RemoveTunnel = Tunnel.RemoveTunnel
    MOD.Interfaces.Tunnel.TrainReservedTunnel = Tunnel.TrainReservedTunnel
    MOD.Interfaces.Tunnel.TrainFinishedEnteringTunnel = Tunnel.TrainFinishedEnteringTunnel
    MOD.Interfaces.Tunnel.TrainReleasedTunnel = Tunnel.TrainReleasedTunnel
    MOD.Interfaces.Tunnel.AreTunnelsPartsInUse = Tunnel.AreTunnelsPartsInUse
    MOD.Interfaces.Tunnel.CanTrainFitInTunnel = Tunnel.CanTrainFitInTunnel
    -- Merged event handler interfaces.
    MOD.Interfaces.Tunnel.OnTrainCarriageEntityBuilt = Tunnel.OnTrainCarriageEntityBuilt
    MOD.Interfaces.Tunnel.OnTrainCarriageGhostBuilt = Tunnel.OnTrainCarriageGhostBuilt
end

-- Needed so we detect when a train is targetting the transition signal of a tunnel and has a path reserved to it. Naturally the train would start to slow down at this point, but we want to control it instead.
---@param event on_train_changed_state
Tunnel.TrainEnteringTunnel_OnTrainChangedState = function(event)
    local train = event.train
    if not train.valid or train.state ~= defines.train_state.arrive_signal then
        return
    end
    local transitionSignal = global.tunnels.transitionSignals[train.signal.unit_number]
    if transitionSignal == nil then
        return
    end

    -- Check the tunnel can be reserved by this train. Same as the train detectors do before calling the TrainManager.
    -- In certain edge cases 2 trains can reserve the the tunnel's 2 transition signals simultaneously and the portal entry signal circuitry doesn't have time to react to prevent it.
    -- A train that doesn't leave the portal before turning around will also need to have its request allowed through to the TrainManager.
    ---@typelist Tunnel, Id
    local tunnel, train_id = transitionSignal.portal.tunnel, train.id
    if tunnel.managedTrain ~= nil and tunnel.managedTrain.trainId ~= train_id then
        -- Tunnel already reserved so this reservation is bad.
        TunnelShared.StopTrainFromEnteringTunnel(train, train_id, train.carriages[1], event.tick, {"message.railway_tunnel-tunnel_in_use"})
        return
    end

    MOD.Interfaces.TrainManager.RegisterTrainApproachingPortalSignal(train, train_id, transitionSignal)
end

---@param portals Portal[]
---@param underground Underground
Tunnel.CompleteTunnel = function(portals, underground)
    -- Call any other modules before the tunnel object is created.
    MOD.Interfaces.Portal.On_PreTunnelCompleted(portals)
    MOD.Interfaces.Underground.On_PreTunnelCompleted(underground)

    -- Create the tunnel global object.
    local refPortal = portals[1]
    ---@type Tunnel
    local tunnel = {
        id = global.tunnels.nextTunnelId,
        surface = refPortal.surface,
        portals = portals,
        force = refPortal.force,
        underground = underground,
        tunnelRailEntities = {},
        portalRailEntities = {},
        guiOpenedByPlayers = {}
    }
    global.tunnels.tunnels[tunnel.id] = tunnel
    global.tunnels.nextTunnelId = global.tunnels.nextTunnelId + 1

    -- Loop over the parts of the tunnel and update them and us.
    for _, portal in pairs(portals) do
        portal.tunnel = tunnel
        for portalRailEntity_unitNumber, portalRailEntity in pairs(portal.portalRailEntities) do
            tunnel.portalRailEntities[portalRailEntity_unitNumber] = portalRailEntity
        end
        if tunnel.maxTrainLengthTiles == nil then
            tunnel.maxTrainLengthTiles = portal.trainWaitingAreaTilesLength
        else
            tunnel.maxTrainLengthTiles = math.min(tunnel.maxTrainLengthTiles, portal.trainWaitingAreaTilesLength)
        end

        -- Handle any open GUIs on the portals.
        for _, portalPart in pairs(portal.guiOpenedByParts) do
            for playerIndex, player in pairs(portalPart.guiOpenedByPlayers) do
                tunnel.guiOpenedByPlayers[playerIndex] = player
                MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged(portalPart, playerIndex, false)
            end
        end
    end
    underground.tunnel = tunnel
    for _, segment in pairs(underground.segments) do
        for tunnelRailEntity_unitNumber, tunnelRailEntity in pairs(segment.tunnelRailEntities) do
            tunnel.tunnelRailEntities[tunnelRailEntity_unitNumber] = tunnelRailEntity
        end
    end

    -- Call any other modules after the tunnel object is created.
    MOD.Interfaces.Portal.On_PostTunnelCompleted(portals)
    MOD.Interfaces.Underground.On_PostTunnelCompleted(underground)
end

---@param tunnel Tunnel
---@param killForce? LuaForce|nil @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity|nil @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
Tunnel.RemoveTunnel = function(tunnel, killForce, killerCauseEntity)
    MOD.Interfaces.TrainManager.On_TunnelRemoved(tunnel, killForce, killerCauseEntity)
    MOD.Interfaces.Portal.On_TunnelRemoved(tunnel.portals, killForce, killerCauseEntity)
    MOD.Interfaces.Underground.On_TunnelRemoved(tunnel.underground)
    global.tunnels.tunnels[tunnel.id] = nil
end

---@param transitionSignal PortalTransitionSignal
Tunnel.RegisterTransitionSignal = function(transitionSignal)
    global.tunnels.transitionSignals[transitionSignal.id] = transitionSignal
end

---@param transitionSignal PortalTransitionSignal
Tunnel.DeregisterTransitionSignal = function(transitionSignal)
    global.tunnels.transitionSignals[transitionSignal.id] = nil
end

---@param managedTrain ManagedTrain
Tunnel.TrainReservedTunnel = function(managedTrain)
    managedTrain.tunnel.managedTrain = managedTrain
end

---@param managedTrain ManagedTrain
Tunnel.TrainFinishedEnteringTunnel = function(managedTrain)
    MOD.Interfaces.Portal.AddEnteringTrainUsageDetectionEntityToPortal(managedTrain.entrancePortal, true, false)
end

---@param managedTrain ManagedTrain
Tunnel.TrainReleasedTunnel = function(managedTrain)
    MOD.Interfaces.Portal.AddEnteringTrainUsageDetectionEntityToPortal(managedTrain.entrancePortal, true, false)
    MOD.Interfaces.Portal.AddEnteringTrainUsageDetectionEntityToPortal(managedTrain.exitPortal, true, false)
    if managedTrain.tunnel.managedTrain ~= nil and managedTrain.tunnel.managedTrain.id == managedTrain.id then
        managedTrain.tunnel.managedTrain = nil
    end
end

-- Checks if any of the tunnel parts are in use. This includes using the tunnel states (approaching, onPortalTrack, leaving, etc) or if the portal's rails have a train on them.
---@param tunnelToCheck Tunnel
---@return boolean
Tunnel.AreTunnelsPartsInUse = function(tunnelToCheck)
    -- Check if tunnel in use due to state.
    if tunnelToCheck.managedTrain ~= nil then
        return true
    end

    -- Check if tunnel's portal's entry end's outside rails are occupied. As a train can be beyond the entry train detector and still be on these rails.
    for _, portal in pairs(tunnelToCheck.portals) do
        if not portal.entrySignals[Common.TunnelSignalDirection.outSignal].railEntity.can_be_destroyed() then
            -- A train is on the end rail.
            return true
        end
    end

    -- Nothing found so tunnel must be fully free.
    return false
end

---@class RemoteTunnelDetails @ used by remote interface calls only.
---@field tunnelId Id @ Id of the tunnel.
---@field portals RemotePortalDetails[] @ the 2 portals in this tunnel.
---@field tunnelUsageId Id @ the managed train using the tunnel if any.

---@class RemotePortalDetails
---@field portalId Id @ unique id of the portal object.
---@field portalPartEntities table<UnitNumber, LuaEntity> @ array of all the parts making up the portal.

---@param tunnel Tunnel
---@return RemoteTunnelDetails
Tunnel.Remote_GetTunnelDetails = function(tunnel)
    -- Get the details for the underground segments.
    local undergroundSegmentEntities = {}
    for undergroundSegmentId, undergroundSegmentObject in pairs(tunnel.underground.segments) do
        undergroundSegmentEntities[undergroundSegmentId] = undergroundSegmentObject.entity
    end

    -- Get the details for the 2 portals.
    local portal1PartEntities = {}
    for portalEndPartId, portalEndPartObject in pairs(tunnel.portals[1].portalEnds) do
        portal1PartEntities[portalEndPartId] = portalEndPartObject.entity
    end
    for portalSegmentPartId, portalSegmentPartObject in pairs(tunnel.portals[1].portalSegments) do
        portal1PartEntities[portalSegmentPartId] = portalSegmentPartObject.entity
    end
    local portal2PartEntities = {}
    for portalEndPartId, portalEndPartObject in pairs(tunnel.portals[2].portalEnds) do
        portal2PartEntities[portalEndPartId] = portalEndPartObject.entity
    end
    for portalSegmentPartId, portalSegmentPartObject in pairs(tunnel.portals[2].portalSegments) do
        portal2PartEntities[portalSegmentPartId] = portalSegmentPartObject.entity
    end

    -- Get the tunnel usage ID if the tunnel is in use.
    local tunnelUsageId
    if tunnel.managedTrain ~= nil then
        tunnelUsageId = tunnel.managedTrain.id
    end

    ---@type RemoteTunnelDetails
    local tunnelDetails = {
        tunnelId = tunnel.id,
        portals = {
            {
                portalId = tunnel.portals[1].id,
                portalPartEntities = portal1PartEntities
            },
            {
                portalId = tunnel.portals[2].id,
                portalPartEntities = portal2PartEntities
            }
        },
        undergroundSegmentEntities = undergroundSegmentEntities,
        tunnelUsageId = tunnelUsageId
    }
    return tunnelDetails
end

---@param tunnelId Id
---@return RemoteTunnelDetails
Tunnel.Remote_GetTunnelDetailsForId = function(tunnelId)
    local tunnel = global.tunnels.tunnels[tunnelId]
    if tunnel == nil then
        return nil
    end
    return Tunnel.Remote_GetTunnelDetails(tunnel)
end

---@param entityUnitNumber UnitNumber
---@return RemoteTunnelDetails
Tunnel.Remote_GetTunnelDetailsForEntityUnitNumber = function(entityUnitNumber)
    for _, tunnel in pairs(global.tunnels.tunnels) do
        for _, portal in pairs(tunnel.portals) do
            for portalEndId, _ in pairs(portal.portalEnds) do
                if portalEndId == entityUnitNumber then
                    return Tunnel.Remote_GetTunnelDetails(tunnel)
                end
            end
            for portalSegmentId, _ in pairs(portal.portalSegments) do
                if portalSegmentId == entityUnitNumber then
                    return Tunnel.Remote_GetTunnelDetails(tunnel)
                end
            end
        end
        for segmentId, _ in pairs(tunnel.underground.segments) do
            if segmentId == entityUnitNumber then
                return Tunnel.Remote_GetTunnelDetails(tunnel)
            end
        end
    end
    return nil
end

-- Checks for any real train carriages being built on the portal or tunnel segments.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
---@param createdEntity LuaEntity
Tunnel.OnTrainCarriageEntityBuilt = function(event, createdEntity)
    local train = createdEntity.train

    local createdEntity_unitNumber = createdEntity.unit_number
    -- Look at the train and work out where the placed wagon fits in it. Then check the approperiate ends of the train's rails.
    local trainFrontStockIsPlacedEntity, trainBackStockIsPlacedEntity = false, false
    if train.front_stock.unit_number == createdEntity_unitNumber then
        trainFrontStockIsPlacedEntity = true
    end
    if train.back_stock.unit_number == createdEntity_unitNumber then
        trainBackStockIsPlacedEntity = true
    end
    if trainFrontStockIsPlacedEntity and trainBackStockIsPlacedEntity then
        -- Both ends of the train is this carriage so its a train of 1.
        if TunnelRailEntityNames[train.front_rail.name] == nil and TunnelRailEntityNames[train.back_rail.name] == nil then
            -- If train (single carriage) doesn't have a tunnel rail at either end of it then its not on a tunnel, so ignore it.
            return
        end
    elseif trainFrontStockIsPlacedEntity then
        -- Placed carriage is front of train
        if TunnelRailEntityNames[train.front_rail.name] == nil then
            -- Ignore if train doesn't have a tunnel rail at the end the carriage was just placed at. We assume the other end is fine.
            return
        end
    elseif trainBackStockIsPlacedEntity then
        -- Placed carriage is rear of train
        if TunnelRailEntityNames[train.back_rail.name] == nil then
            -- Ignore if train doesn't have a tunnel rail at the end the carriage was just placed at. We assume the other end is fine.
            return
        end
    else
        -- Placed carriage is part of an existing train that isn't managed for tunnel usage. The placed carriage isn't on either end of the train so no need to check it.
        return
    end

    local placer = EventUtils.GetActionerFromEvent(event)
    TunnelShared.UndoInvalidPlacement(createdEntity, placer, true, false, {"message.railway_tunnel-rolling_stock_blocked_on_tunnel_track"}, "rolling stock")
end

-- Checks for any ghost train carriages being built on the portal or tunnel segments.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
---@param createdEntity LuaEntity
---@param createdEntity_ghostName string
Tunnel.OnTrainCarriageGhostBuilt = function(event, createdEntity, createdEntity_ghostName)
    -- Is a ghost so check it approperiately. This isn't perfect, but if it misses an invalid case the real entity being placed will catch it. Nicer to warn the player at the ghost stage however.

    -- Known limitation that you can't place a single carriage ghost on a tunnel crossing segment in most positions as this detects the tunnel rails underneath the regular rails. Edge case and just slightly over protective.

    -- Have to check what rails are at the approximate ends of the ghost carriage.
    local createdEntity_position, createdEntity_orientation = createdEntity.position, createdEntity.orientation
    local carriageLengthFromCenter, surface, tunnelRailFound = Common.CarriagePlacementDistances[createdEntity_ghostName], createdEntity.surface, false
    local frontRailPosition, backRailPosition = PositionUtils.GetPositionForOrientationDistance(createdEntity_position, carriageLengthFromCenter, createdEntity_orientation), PositionUtils.GetPositionForOrientationDistance(createdEntity_position, carriageLengthFromCenter, createdEntity_orientation - 0.5)
    local frontRailsFound = surface.find_entities_filtered {type = {"straight-rail", "curved-rail"}, position = frontRailPosition}
    -- Check the rails found both ends individaully: if theres a regular rail then ignore any tunnel rails, otherwise flag any tunnel rails.
    for _, railEntity in pairs(frontRailsFound) do
        if TunnelRailEntityNames[railEntity.name] ~= nil then
            tunnelRailFound = true
        else
            tunnelRailFound = false
            break
        end
    end
    if not tunnelRailFound then
        local backRailsFound = surface.find_entities_filtered {type = {"straight-rail", "curved-rail"}, position = backRailPosition}
        for _, railEntity in pairs(backRailsFound) do
            if TunnelRailEntityNames[railEntity.name] ~= nil then
                tunnelRailFound = true
            else
                tunnelRailFound = false
                break
            end
        end
    end
    if not tunnelRailFound then
        return
    end

    local placer = EventUtils.GetActionerFromEvent(event)
    TunnelShared.UndoInvalidPlacement(createdEntity, placer, false, false, {"message.railway_tunnel-rolling_stock_blocked_on_tunnel_track"}, "rolling stock")
end

-- Triggered when a player rotates a monitored entity type. This should only be possible in Editor mode as we make all parts un-rotatable to regular players.
---@param event on_player_rotated_entity
Tunnel.OnPlayerRotatedEntity = function(event)
    local rotatedEntity = event.entity
    -- Just check if the player (editor mode) rotated a portal or underground entity.
    if UndergroundSegmentAndAllPortalEntityNames[rotatedEntity.name] == nil then
        return
    end
    -- Reverse the rotation so other code logic still works. Also would mess up the graphics if not reversed.
    rotatedEntity.direction = event.previous_direction
    TunnelShared.EntityErrorMessage(game.get_player(event.player_index), {"message.railway_tunnel-dont_rotate_tunnel_parts"}, rotatedEntity.surface, rotatedEntity.position)
end

-- Checks if the train can fit within the tunnel's max allowed length.
---@param train LuaTrain
---@param train_id Id
---@param tunnel Tunnel
---@return boolean
Tunnel.CanTrainFitInTunnel = function(train, train_id, tunnel)
    local cachedTrain = MOD.Interfaces.TrainCachedData.GetCreateTrainCache(train, train_id)

    -- If theres no cached train length for this train calculate and cache it.
    if cachedTrain.trainLength == nil then
        local trainLength = 0
        local carriage_name

        -- Get the length for each carriage.
        for i, carriageData in pairs(cachedTrain.carriagesCachedData) do
            -- Get the value and cache if not held.
            carriage_name = carriageData.prototypeName
            if carriage_name == nil then
                carriage_name = carriageData.entity.name
                carriageData.prototypeName = carriage_name
            end

            -- Add the carriages connected length (main body and joint distance to one other carriage) to the train length.
            trainLength = trainLength + Common.CarriageConnectedLengths[carriage_name]

            -- Remove the first carriages front gap as nothing will be connected to it.
            if i == 1 then
                trainLength = trainLength - Common.CarriagesOwnOffsetFromOtherConnectedCarriage[carriage_name]
            end
        end

        -- Remove the last carriages rear gap as nothing will be connected to it.
        cachedTrain.trainLength = trainLength - Common.CarriagesOwnOffsetFromOtherConnectedCarriage[carriage_name]
    end

    -- Check if the train can fit.
    if cachedTrain.trainLength > tunnel.maxTrainLengthTiles then
        return false
    else
        return true
    end
end

return Tunnel
