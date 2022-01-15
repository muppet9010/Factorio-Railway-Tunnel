local Events = require("utility/events")
local Utils = require("utility/utils")
local TunnelShared = require("scripts/tunnel-shared")
local Common = require("scripts/common")
local PortalEndAndSegmentEntityNames, TunnelSignalDirection, TunnelUsageParts = Common.PortalEndAndSegmentEntityNames, Common.TunnelSignalDirection, Common.TunnelUsageParts
local Portal = {}
local EventScheduler = require("utility/event-scheduler")
local PlayerAlerts = require("utility/player-alerts")

---@class Portal
---@field id uint @ unique id of the portal object.
---@field isComplete boolean @ if the portal has 2 connected portal end objects or not.
---@field portalEnds table<UnitNumber, PortalEnd> @ the portal end objects of this portal. No direction, orientation or role information implied by this array. Key'd by the portal end entity unit_number (id).
---@field portalSegments table<UnitNumber, PortalSegment> @ the portal segment objects of this portal. Key'd by the portal segment entity unit_number (id).
---@field trainWaitingAreaTilesLength uint @ how many tiles this portal has for trains to wait in it when using the tunnel.
---@field force LuaForce @ the force this portal object belongs to.
---@field surface LuaSurface @ the surface this portal part object is on.
---
---@field portalTunneExternalConnectionSurfacePositionStrings? table<SurfacePositionString, PortalTunnelConnectionSurfacePositionObject>|null @ the 2 external positions the portal should look for underground segments at. Only established on a complete portal.
---
---@field entryPortalEnd? PortalEnd|null @ the entry portal object of this portal. Only established once this portal is part of a valid tunnel.
---@field blockedPortalEnd? PortalEnd|null @ the blocked portal object of this portal. Only established once this portal is part of a valid tunnel.
---@field transitionSignals? table<TunnelSignalDirection, PortalTransitionSignal>|null @ These are the inner locked red signals that a train paths at to enter the tunnel. Only established once this portal is part of a valid tunnel.
---@field entrySignals? table<TunnelSignalDirection, PortalEntrySignal>|null @ These are the signals that are visible to the wider train network and player. The portals 2 IN entry signals are connected by red wire. Only established once this portal is part of a valid tunnel.
---@field tunnel? Tunnel|null @ ref to tunnel object if this portal is part of one. Only established once this portal is part of a valid tunnel.
---@field portalRailEntities? table<UnitNumber, LuaEntity>|null @ the rail entities that are part of the portal. Only established once this portal is part of a valid tunnel.
---@field portalOtherEntities? table<UnitNumber, LuaEntity>|null @ table of the non rail entities that are part of the portal. Will be deleted before the portalRailEntities. Only established once this portal is part of a valid tunnel.
---@field portalEntryPointPosition? Position|null @ the position of the entry point to the portal. Only established once this portal is part of a valid tunnel.
---@field enteringTrainUsageDetectorEntity? LuaEntity|null @ hidden entity on the entry point to the portal that's death signifies a train is coming on to the portal's rails. Only established once this portal is part of a valid tunnel.
---@field enteringTrainUsageDetectorPosition? Position|null @ the position of this portals enteringTrainUsageDetectorEntity. Only established once this portal is part of a valid tunnel.
---@field transitionUsageDetectorEntity? LuaEntity|null @ hidden entity on the transition point of the portal track that's death signifies a train has reached the entering tunnel stage. Only established once this portal is part of a valid tunnel.
---@field transitionUsageDetectorPosition? Position|null @ the position of this portals transitionUsageDetectorEntity. Only established once this portal is part of a valid tunnel.
---@field dummyLocomotivePosition? Position|null @ the position where the dummy locomotive should be plaed for this portal. Only established once this portal is part of a valid tunnel.
---@field entryDirection? defines.direction|null @ the direction a train would be heading if it was entering this portal. So the entry signals are at the rear of this direction. Only established once this portal is part of a valid tunnel.
---@field leavingDirection? defines.direction|null @ the direction a train would be heading if leaving the tunnel via this portal. Only established once this portal is part of a valid tunnel.

---@class PortalPart @ a generic part (entity) object making up part of a potral.
---@field id UnitNumber @ unit_number of the portal part entity.
---@field entity LuaEntity @ ref to the portal part entity.
---@field entity_name string @ cache of the portal part's entity's name.
---@field entity_position Position @ cache of the entity's position.
---@field entity_direction defines.direction @ cache of the entity's direction.
---@field entity_orientation RealOrientation @ cache of the entity's orientation.
---@field frontInternalPosition Position @ our internal position to look for other parts' portalPartSurfacePositions global object entries from. These are present on each connecting end of the part 0.5 tile in from its connecting center. This is to handle various shapes.
---@field rearInternalPosition Position @ our internal position to look for other parts' portalPartSurfacePositions global object entries. These are present on each connecting end of the part 0.5 tile in from its connecting center. This is to handle various shapes.
---@field frontInternalSurfacePositionString SurfacePositionString @ cache of the portal part's frontInternalPosition as a SurfacePositionString.
---@field rearInternalSurfacePositionString SurfacePositionString @ cache of the portal part's rearInternalPosition as a SurfacePositionString.
---@field frontExternalCheckSurfacePositionString SurfacePositionString @ cache of the front External Check position used when looking for connected tunnel parts. Is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
---@field rearExternalCheckSurfacePositionString SurfacePositionString @ cache of the rear External Check position used when looking for connected tunnel parts. Is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
---@field typeData PortalPartTypeData @ ref to generic data about this type of portal part.
---@field surface LuaSurface @ the surface this portal part object is on.
---@field surface_index uint @ cached index of the surface this portal part is on.
---@field force LuaForce @ the force this portal part object belongs to.
---@field nonConnectedInternalSurfacePositions table<SurfacePositionString, SurfacePositionString> @ a table of this end part's non connected internal positions to check inside of the entity. Always exists, even if not part of a portal.
---@field nonConnectedExternalSurfacePositions table<SurfacePositionString, SurfacePositionString> @ a table of this end part's non connected external positions to check outside of the entity. Always exists, even if not part of a portal.
---
---@field portal? Portal|null @ ref to the parent portal object. Only populated if this portal part is connected to another portal part.

---@class PortalEnd : PortalPart @ the end part of a portal.
---@field connectedToUnderground boolean @ if theres an underground segment connected to this portal on one side as part of the completed tunnel. Defaults to false on non portal connected parts.
---
---@field endPortalType? EndPortalType|null @ the type of role this end portal is providing to the parent portal. Only populated when its part of a full tunnel and thus direction within the portal is known.

---@class EndPortalType
local EndPortalType = {
    entry = "entry",
    blocker = "blocker"
}

---@class PortalSegment : PortalPart @ a middle segment of a portal.
---@field segmentShape PortalSegmentShape

---@class PortalSignal
---@field id UnitNumber @ unit_number of this signal.
---@field direction TunnelSignalDirection
---@field entity LuaEntity
---@field entity_position Position
---@field portal Portal
---@field railEntity? LuaEntity|null @ If cached the rail entity this signal is on, or null if not cached.
---@field railEntity_unitNumber? UnitNumber|null @ If cached the unit_number of the rail entity this signal is on, or null if not cached.

---@class PortalTransitionSignal : PortalSignal

---@class PortalEntrySignal : PortalSignal

---@class PortalPartSurfacePositionObject
---@field id SurfacePositionString
---@field portalPart PortalPart

---@class PortalTunnelConnectionSurfacePositionObject
---@field id SurfacePositionString
---@field portal Portal
---@field endPortalPart PortalEnd

---@class PortalPartType @ if the portal part is an End or Segment.
local PortalPartType = {
    portalEnd = "portalEnd",
    portalSegment = "portalSegment"
}

---@class PortalSegmentShape @ the shape of the segment part.
local SegmentShape = {
    straight = "straight", -- Short straight piece for horizontal and vertical.
    diagonal = "diagonal", -- Short diagonal piece.
    curveStart = "curveStart", -- The start of a curve, so between Straight and Diagonal.
    curveInner = "curveInner" -- The inner part of a curve that connects 2 curveStart's togeather to make a 90 degree corner.
}

---@class PortalPartTypeData
---@field name string
---@field partType PortalPartType
---@field trainWaitingAreaTilesLength uint @ how many tiles this part has for trains to wait in it when using the tunnel.
---@field tracksPositionOffset PortalPartTrackPositionOffset[] @the type of track and its position offset from the center of the part when in a 0 orientation.

---@class EndPortalTypeData:PortalPartTypeData

---@class SegmentPortalTypeData:PortalPartTypeData
---@field segmentShape PortalSegmentShape

---@class PortalPartTrackPositionOffset @ type of track and its position offset from the center of the part when in a 0 orientation.
---@field trackEntityName string
---@field positionOffset Position
---@field baseDirection defines.direction

---@type PortalPartTypeData[]
local PortalTypeData = {
    ---@type EndPortalTypeData
    ["railway_tunnel-portal_end"] = {
        name = "railway_tunnel-portal_end",
        partType = PortalPartType.portalEnd,
        trainWaitingAreaTilesLength = 0,
        tracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-portal_rail-on_map",
                positionOffset = {x = 0, y = -2},
                baseDirection = defines.direction.north
            },
            {
                trackEntityName = "railway_tunnel-portal_rail-on_map",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            },
            {
                trackEntityName = "railway_tunnel-portal_rail-on_map",
                positionOffset = {x = 0, y = 2},
                baseDirection = defines.direction.north
            }
        }
    },
    ---@type SegmentPortalTypeData
    ["railway_tunnel-portal_segment-straight"] = {
        name = "railway_tunnel-portal_segment-straight",
        partType = PortalPartType.portalSegment,
        segmentShape = SegmentShape.straight,
        trainWaitingAreaTilesLength = 2,
        tracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-portal_rail-on_map",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            }
        }
    }
}

-- Distances are from entry end portal position in the Portal.entryDirection direction.
local EntryEndPortalSetup = {
    trackEntryPointFromCenter = 3, -- The border of the portal on the entry side.
    entrySignalsDistance = 1.5, -- Keep this a tile away from the edge so that we don't have to worry about if there are signals directly outside of the portal tiles (as signals can't be adjacant).
    enteringTrainUsageDetectorEntityDistance = 0.5 -- Detector on the entry side of the portal. Its positioned so that a train entering the tunnel doesn't hit it until just before it triggers the signal, but a leaving train won't touch it either when waiting at the exit signals. This is a judgement call as trains can actually collide when manaully driven over signals without triggering them. Positioned to minimise UPS usage
}

-- Distances are from blocking end portal position in the Portal.entryDirection direction.
local BlockingEndPortalSetup = {
    dummyLocomotiveDistance = 1.8, -- as far back in to the end portal without touching the blocking locomotive.
    transitionUsageDetectorEntityDistance = 4.1, -- can't go further back as otherwise the entering train will release the signal and thus the tunnel.
    transitionSignalsDistance = 2.5,
    transitionSignalBlockingLocomotiveDistance = -1.3, -- As far away from entry end as possible, but can't stick out beyond the portal's collision box.
    blockedInvisibleSignalsDistance = -1.5 -- Keep this a tile away from the edge so that we don't have to worry about any signals in tunnel segments (as signals can't be adjacant).
}

Portal.CreateGlobals = function()
    global.portals = global.portals or {}
    global.portals.nextPortalId = global.portals.nextPortalId or 1
    global.portals.portals = global.portals.portals or {} ---@type table<Id, Portal> @ a list of all of the portals.
    global.portals.portalPartEntityIdToPortalPart = global.portals.portalPartEntityIdToPortalPart or {} ---@type table<UnitNumber, PortalPart> @ a lookup of portal part entity unit_number to the portal part object.
    global.portals.enteringTrainUsageDetectorEntityIdToPortal = global.portals.enteringTrainUsageDetectorEntityIdToPortal or {} ---@type table<UnitNumber, Portal> @ Used to be able to identify the portal when the entering train detection entity is killed.
    global.portals.transitionUsageDetectorEntityIdToPortal = global.portals.transitionUsageDetectorEntityIdToPortal or {} ---@type table<UnitNumber, Portal> @ Used to be able to identify the portal when the transition train detection entity is killed.
    global.portals.portalPartInternalConnectionSurfacePositionStrings = global.portals.portalPartInternalConnectionSurfacePositionStrings or {} ---@type table<SurfacePositionString, PortalPartSurfacePositionObject> @ a lookup for internal positions that portal parts can be connected on. Includes the parts's frontInternalSurfacePositionString and rearInternalSurfacePositionString as keys for lookup.
    global.portals.portalTunnelInternalConnectionSurfacePositionStrings = global.portals.portalTunnelInternalConnectionSurfacePositionStrings or {} ---@type table<SurfacePositionString, PortalTunnelConnectionSurfacePositionObject> @ a lookup for portal by internal position string for trying to connect to an underground.
end

Portal.OnLoad = function()
    local portalEntityNames_Filter = {}
    for _, name in pairs(PortalEndAndSegmentEntityNames) do
        table.insert(portalEntityNames_Filter, {filter = "name", name = name})
    end

    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Portal.OnBuiltEntity", Portal.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Portal.OnBuiltEntity", Portal.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Portal.OnBuiltEntity", Portal.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "Portal.OnBuiltEntity", Portal.OnBuiltEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "Portal.OnPreMinedEntity", Portal.OnPreMinedEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "Portal.OnPreMinedEntity", Portal.OnPreMinedEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Portal.OnDiedEntity", Portal.OnDiedEntity, portalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "Portal.OnDiedEntity", Portal.OnDiedEntity, portalEntityNames_Filter)

    local portalEntityGhostNames_Filter = {}
    for _, name in pairs(PortalEndAndSegmentEntityNames) do
        table.insert(portalEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Portal.OnBuiltEntityGhost", Portal.OnBuiltEntityGhost, portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Portal.OnBuiltEntityGhost", Portal.OnBuiltEntityGhost, portalEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Portal.OnBuiltEntityGhost", Portal.OnBuiltEntityGhost, portalEntityGhostNames_Filter)

    MOD.Interfaces.Portal = MOD.Interfaces.Portal or {}
    MOD.Interfaces.Portal.On_PreTunnelCompleted = Portal.On_PreTunnelCompleted
    MOD.Interfaces.Portal.On_TunnelRemoved = Portal.On_TunnelRemoved
    MOD.Interfaces.Portal.AddEnteringTrainUsageDetectionEntityToPortal = Portal.AddEnteringTrainUsageDetectionEntityToPortal
    MOD.Interfaces.Portal.CanAPortalConnectAtItsInternalPosition = Portal.CanAPortalConnectAtItsInternalPosition
    MOD.Interfaces.Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel = Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel
    MOD.Interfaces.Portal.On_PostTunnelCompleted = Portal.On_PostTunnelCompleted

    EventScheduler.RegisterScheduledEventType("Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled", Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled)
    EventScheduler.RegisterScheduledEventType("Portal.SetTrainToManual_Scheduled", Portal.SetTrainToManual_Scheduled)
    EventScheduler.RegisterScheduledEventType("Portal.CheckIfTooLongTrainStillStopped_Scheduled", Portal.CheckIfTooLongTrainStillStopped_Scheduled)

    local portalEntryTrainDetector1x1_Filter = {{filter = "name", name = "railway_tunnel-portal_entry_train_detector_1x1"}}
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Portal.OnDiedEntityPortalEntryTrainDetector", Portal.OnDiedEntityPortalEntryTrainDetector, portalEntryTrainDetector1x1_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "Portal.OnDiedEntityPortalEntryTrainDetector", Portal.OnDiedEntityPortalEntryTrainDetector, portalEntryTrainDetector1x1_Filter)

    local portalTransitionTrainDetector1x1_Filter = {{filter = "name", name = "railway_tunnel-portal_transition_train_detector_1x1"}}
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Portal.OnDiedEntityPortalTransitionTrainDetector", Portal.OnDiedEntityPortalTransitionTrainDetector, portalTransitionTrainDetector1x1_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "Portal.OnDiedEntityPortalTransitionTrainDetector", Portal.OnDiedEntityPortalTransitionTrainDetector, portalTransitionTrainDetector1x1_Filter)
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
Portal.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid then
        return
    end
    local createdEntity_name = createdEntity.name
    if PortalEndAndSegmentEntityNames[createdEntity_name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    Portal.TunnelPortalPartBuilt(createdEntity, placer, createdEntity_name)
end

---@param builtEntity LuaEntity
---@param placer EntityActioner
---@param builtEntity_name string
---@return boolean
Portal.TunnelPortalPartBuilt = function(builtEntity, placer, builtEntity_name)
    -- Check the placement is on rail grid, if not then undo the placement and stop.
    if not TunnelShared.IsPlacementOnRailGrid(builtEntity) then
        TunnelShared.UndoInvalidTunnelPartPlacement(builtEntity, placer, true)
        return
    end

    builtEntity.rotatable = false

    -- Get the generic attributes of the built entity needed for the object.
    local builtEntity_position, builtEntity_direction, surface, builtEntity_orientation = builtEntity.position, builtEntity.direction, builtEntity.surface, builtEntity.orientation
    local portalTypeData, surface_index = PortalTypeData[builtEntity_name], surface.index
    ---@type PortalPart
    local portalPartObject = {
        id = builtEntity.unit_number,
        entity = builtEntity,
        entity_name = builtEntity_name,
        entity_position = builtEntity_position,
        entity_direction = builtEntity_direction,
        entity_orientation = builtEntity_orientation,
        surface = surface,
        surface_index = surface_index,
        force = builtEntity.force,
        typeData = portalTypeData,
        nonConnectedInternalSurfacePositions = {},
        nonConnectedExternalSurfacePositions = {}
    }

    -- Handle the caching of specific portal part type information and to their globals.
    if portalTypeData.partType == PortalPartType.portalEnd then
        -- Placed entity is an end.
        local endPortal = portalPartObject ---@type PortalEnd
        -- Has 2 positions that other portal parts can check it for as a connection. 2.5 tiles from centre in both connecting directions (0.5 tile in from its edge).
        endPortal.frontInternalPosition = Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = -2.5}, builtEntity_position)
        endPortal.rearInternalPosition = Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = 2.5}, builtEntity_position)

        endPortal.connectedToUnderground = false
    elseif portalTypeData.partType == PortalPartType.portalSegment then
        -- Placed entity is a segment.
        local segmentPortalTypeData = portalTypeData ---@type SegmentPortalTypeData
        local segmentPortal = portalPartObject ---@type PortalSegment
        if segmentPortalTypeData.segmentShape == SegmentShape.straight then
            segmentPortal.segmentShape = segmentPortalTypeData.segmentShape
            segmentPortal.frontInternalPosition = Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = -0.5}, builtEntity_position)
            segmentPortal.rearInternalPosition = Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = 0.5}, builtEntity_position)
        else
            error("unrecognised segmentPortalTypeData.segmentShape: " .. segmentPortalTypeData.segmentShape)
        end
    else
        error("unrecognised portalTypeData.partType: " .. portalTypeData.partType)
    end

    -- Register the parts' surfacePositionStrings for reverse lookup.
    local frontInternalSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, portalPartObject.frontInternalPosition)
    global.portals.portalPartInternalConnectionSurfacePositionStrings[frontInternalSurfacePositionString] = {
        id = frontInternalSurfacePositionString,
        portalPart = portalPartObject
    }
    portalPartObject.frontInternalSurfacePositionString = frontInternalSurfacePositionString
    local rearInternalSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, portalPartObject.rearInternalPosition)
    global.portals.portalPartInternalConnectionSurfacePositionStrings[rearInternalSurfacePositionString] = {
        id = rearInternalSurfacePositionString,
        portalPart = portalPartObject
    }
    portalPartObject.rearInternalSurfacePositionString = rearInternalSurfacePositionString

    -- The External Check position is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
    portalPartObject.frontExternalCheckSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = -1}, portalPartObject.frontInternalPosition))
    portalPartObject.rearExternalCheckSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = 1}, portalPartObject.rearInternalPosition))

    -- Register the part's entity for reverse lookup.
    global.portals.portalPartEntityIdToPortalPart[portalPartObject.id] = portalPartObject

    Portal.UpdatePortalsForNewPortalPart(portalPartObject)

    if portalPartObject.portal ~= nil and portalPartObject.portal.isComplete then
        Portal.CheckAndHandleTunnelCompleteFromPortal(portalPartObject.portal)
    end
end

--- Check if this portal part is next to another portal part on either/both sides. If it is create/add to a portal object for them. A single portal part doesn't get a portal object.
---@param portalPartObject PortalPart
Portal.UpdatePortalsForNewPortalPart = function(portalPartObject)
    local firstComplictedConnectedPart, secondComplictedConnectedPart = nil, nil

    -- Check for a connected viable portal part in both directions from our portal part.
    for _, checkDetails in pairs(
        {
            {
                internalCheckSurfacePositionString = portalPartObject.frontInternalSurfacePositionString,
                externalCheckSurfacePositionString = portalPartObject.frontExternalCheckSurfacePositionString
            },
            {
                internalCheckSurfacePositionString = portalPartObject.rearInternalSurfacePositionString,
                externalCheckSurfacePositionString = portalPartObject.rearExternalCheckSurfacePositionString
            }
        }
    ) do
        -- Look in the global internal position string list for any part that is where our external check position is.
        local foundPortalPartPositionObject = global.portals.portalPartInternalConnectionSurfacePositionStrings[checkDetails.externalCheckSurfacePositionString]
        -- If a portal reference at this position is found next to this one add this part to its/new portal.
        if foundPortalPartPositionObject ~= nil then
            local connectedPortalPart = foundPortalPartPositionObject.portalPart
            -- If the connected part has a completed portal we can't join to it.
            if connectedPortalPart.portal == nil or (connectedPortalPart.portal and not connectedPortalPart.portal.isComplete) then
                -- Valid portal to create connection too, just work out how to handle this. Note some scenarios are not handled in this loop.
                if portalPartObject.portal and connectedPortalPart.portal == nil then
                    -- We have a portal and they don't, so add them to our portal.
                    Portal.AddPartToPortal(portalPartObject.portal, connectedPortalPart)
                elseif portalPartObject.portal == nil and connectedPortalPart.portal then
                    -- We don't have a portal and they do, so add us to their portal.
                    Portal.AddPartToPortal(connectedPortalPart.portal, portalPartObject)
                else
                    -- Either we both have portals or neither have portals. Just flag this and review after checking both directions.
                    if firstComplictedConnectedPart == nil then
                        firstComplictedConnectedPart = connectedPortalPart
                    else
                        secondComplictedConnectedPart = connectedPortalPart
                    end
                end
                -- Update ours and their nonConnected Internal and External SurfacePositions as we are both now connected on this connection side.
                portalPartObject.nonConnectedInternalSurfacePositions[checkDetails.internalCheckSurfacePositionString] = nil
                portalPartObject.nonConnectedExternalSurfacePositions[checkDetails.externalCheckSurfacePositionString] = nil
                -- For the connectedPortalPart the positions are flipped as the opposite perspective.
                connectedPortalPart.nonConnectedInternalSurfacePositions[checkDetails.externalCheckSurfacePositionString] = nil
                connectedPortalPart.nonConnectedExternalSurfacePositions[checkDetails.internalCheckSurfacePositionString] = nil
            else
                portalPartObject.nonConnectedInternalSurfacePositions[checkDetails.internalCheckSurfacePositionString] = checkDetails.internalCheckSurfacePositionString
                portalPartObject.nonConnectedExternalSurfacePositions[checkDetails.externalCheckSurfacePositionString] = checkDetails.externalCheckSurfacePositionString
            end
        else
            portalPartObject.nonConnectedInternalSurfacePositions[checkDetails.internalCheckSurfacePositionString] = checkDetails.internalCheckSurfacePositionString
            portalPartObject.nonConnectedExternalSurfacePositions[checkDetails.externalCheckSurfacePositionString] = checkDetails.externalCheckSurfacePositionString
        end
    end

    -- Handle any weird situations where theres lots of portals or none. Note that the scenarios handled are limited based on the logic outcomes of the direciton checking logic.
    -- The logging of complicated parts was based on our state at the time of the comparison. So the second connected part may have changed our state since we compared to the first connected part.
    if firstComplictedConnectedPart ~= nil then
        if portalPartObject.portal == nil then
            -- none has a portal, so create one for all. As if either connected part had a portal we would have one now.
            local portalId = global.portals.nextPortalId
            global.portals.nextPortalId = global.portals.nextPortalId + 1
            ---@type Portal
            local portal = {
                id = portalId,
                isComplete = false,
                portalEnds = {},
                portalSegments = {},
                trainWaitingAreaTilesLength = 0,
                force = portalPartObject.force,
                surface = portalPartObject.surface
            }
            global.portals.portals[portalId] = portal
            Portal.AddPartToPortal(portal, portalPartObject)
            Portal.AddPartToPortal(portal, firstComplictedConnectedPart)
            if secondComplictedConnectedPart ~= nil then
                Portal.AddPartToPortal(portal, secondComplictedConnectedPart)
            end
        elseif portalPartObject.portal ~= nil and firstComplictedConnectedPart.portal ~= nil then
            -- Us and the one complicated part both have a portal.

            -- If the 2 portals are different then merge them. Use whichever has more segments as new master as this is generally the best one. It can end up that both have the same portal during the connection process and in this case do nothing to the shared portal.
            if portalPartObject.portal.id ~= firstComplictedConnectedPart.portal.id then
                if Utils.GetTableNonNilLength(portalPartObject.portal.portalSegments) >= Utils.GetTableNonNilLength(firstComplictedConnectedPart.portal.portalSegments) then
                    Portal.MergePortalInToOtherPortal(firstComplictedConnectedPart.portal, portalPartObject.portal)
                else
                    Portal.MergePortalInToOtherPortal(portalPartObject.portal, firstComplictedConnectedPart.portal)
                end
            end
        elseif portalPartObject.portal ~= nil and firstComplictedConnectedPart.portal == nil then
            -- We have a portal now and the other complicated connnected part doesn't. We may have obtained one since the initial comparison. Just add them to ours now.
            Portal.AddPartToPortal(portalPartObject.portal, firstComplictedConnectedPart)
        else
            -- If a situation should be ignored add it explicitly.
            error("unexpected scenario")
        end
    end

    -- Check if portal is complete.
    if portalPartObject.portal ~= nil and Utils.GetTableNonNilLength(portalPartObject.portal.portalEnds) == 2 then
        Portal.PortalComplete(portalPartObject.portal)
    end
end

--- Add the portalPart to the portal based on its type.
---@param portal Portal
---@param portalPart PortalPart
Portal.AddPartToPortal = function(portal, portalPart)
    portalPart.portal = portal
    if portalPart.typeData.partType == PortalPartType.portalEnd then
        portal.portalEnds[portalPart.id] = portalPart
    elseif portalPart.typeData.partType == PortalPartType.portalSegment then
        portal.portalSegments[portalPart.id] = portalPart
        portal.trainWaitingAreaTilesLength = portal.trainWaitingAreaTilesLength + portalPart.typeData.trainWaitingAreaTilesLength
    else
        error("invalid portal type: " .. portalPart.typeData.partType)
    end
end

--- Moves the old partal parts to the new portal and removes the old portal object.
---@param oldPortal Portal
---@param newPortal Portal
Portal.MergePortalInToOtherPortal = function(oldPortal, newPortal)
    for id, part in pairs(oldPortal.portalEnds) do
        newPortal.portalEnds[id] = part
        part.portal = newPortal
    end
    for id, part in pairs(oldPortal.portalSegments) do
        newPortal.portalSegments[id] = part
        part.portal = newPortal
    end
    newPortal.trainWaitingAreaTilesLength = newPortal.trainWaitingAreaTilesLength + oldPortal.trainWaitingAreaTilesLength
    global.portals.portals[oldPortal.id] = nil
end

---@param portal Portal
Portal.PortalComplete = function(portal)
    portal.isComplete = true
    portal.portalTunneExternalConnectionSurfacePositionStrings = {}

    -- Work out where a tunnel could connect to the portal based on the unconnected sides of the End Portal.
    for _, endPortalPart in pairs(portal.portalEnds) do
        local undergroundInternalConnectionSurfacePositionString = next(endPortalPart.nonConnectedInternalSurfacePositions)
        global.portals.portalTunnelInternalConnectionSurfacePositionStrings[undergroundInternalConnectionSurfacePositionString] = {
            id = undergroundInternalConnectionSurfacePositionString,
            portal = portal,
            endPortalPart = endPortalPart
        }
        local undergroundExternalConnectionSurfacePositionString = next(endPortalPart.nonConnectedExternalSurfacePositions)
        portal.portalTunneExternalConnectionSurfacePositionStrings[undergroundExternalConnectionSurfacePositionString] = {
            id = undergroundExternalConnectionSurfacePositionString,
            portal = portal,
            endPortalPart = endPortalPart
        }
    end
end

-- Checks if the tunnel is complete and if it is triggers the tunnel complete code.
---@param portal Portal
Portal.CheckAndHandleTunnelCompleteFromPortal = function(portal)
    for portalExternalSurfacePositionString, portalTunnelExternalConnectionSurfacePositionObject in pairs(portal.portalTunneExternalConnectionSurfacePositionStrings) do
        local underground, otherEndSegment = MOD.Interfaces.Underground.CanAnUndergroundConnectAtItsInternalPosition(portalExternalSurfacePositionString)
        if underground ~= nil then
            local foundPortal, foundEndPortalPart = MOD.Interfaces.Underground.CanUndergroundSegmentConnectToAPortal(otherEndSegment, portal)
            if foundPortal ~= nil then
                Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel({portalTunnelExternalConnectionSurfacePositionObject.endPortalPart, foundEndPortalPart})
                MOD.Interfaces.Tunnel.CompleteTunnel({portal, foundPortal}, underground)
            end
        end
    end
end

--- Checks if a complete Portal has a connection at an internal position. If it does returns the objects, otherwise nil for all.
---@param portalInternalSurfacePositionString SurfacePositionString
---@return Portal|null portal
---@return PortalEnd|null portalEnd
Portal.CanAPortalConnectAtItsInternalPosition = function(portalInternalSurfacePositionString)
    local portalTunnelInternalConnectionSurfacePositionObject = global.portals.portalTunnelInternalConnectionSurfacePositionStrings[portalInternalSurfacePositionString]
    if portalTunnelInternalConnectionSurfacePositionObject ~= nil and portalTunnelInternalConnectionSurfacePositionObject.portal.isComplete then
        return portalTunnelInternalConnectionSurfacePositionObject.portal, portalTunnelInternalConnectionSurfacePositionObject.endPortalPart
    end
end

--- Called when a tunnel is about to be created and the 2 end portal parts that connect to the underground are known.
---@param endPortalParts PortalEnd[]
Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel = function(endPortalParts)
    endPortalParts[1].connectedToUnderground = true
    endPortalParts[2].connectedToUnderground = true
end

-- Registers and sets up the tunnel's portals prior to the tunnel object being created and references created.
---@param portals Portal[]
Portal.On_PreTunnelCompleted = function(portals)
    -- Add all the bits to each portal that only appear when the portal is part of a completed tunnel.
    for _, portal in pairs(portals) do
        -- Work out which portal end is the blocked end.
        local entryPortalEnd  ---@type PortalEnd
        local blockedPortalEnd  ---@type PortalEnd
        for _, endPortalPart in pairs(portal.portalEnds) do
            if endPortalPart.connectedToUnderground then
                blockedPortalEnd = endPortalPart
                endPortalPart.endPortalType = EndPortalType.blocker
                portal.blockedPortalEnd = blockedPortalEnd
            else
                entryPortalEnd = endPortalPart
                endPortalPart.endPortalType = EndPortalType.entry
                portal.entryPortalEnd = entryPortalEnd
            end
        end

        -- Work out which direction an entering train would be heading in to this portal. Assumes portal is built in a straight line.
        local entryDirection = Utils.GetCardinalDirectionHeadingToPosition(entryPortalEnd.entity_position, blockedPortalEnd.entity_position)
        if entryDirection < 0 then
            error("failed to calculate valid entryDirection")
        end
        local reverseEntryDirection = Utils.LoopDirectionValue(entryDirection + 4)
        portal.entryDirection, portal.leavingDirection = entryDirection, reverseEntryDirection
        local entryOrientation = Utils.DirectionToOrientation(entryDirection)
        local surface, force = portal.surface, portal.force

        Portal.BuildRailForPortalsParts(portal)

        -- Add the signals at the entry part to the tunnel.
        local entrySignalInEntityPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 1.5, y = EntryEndPortalSetup.entrySignalsDistance}, entryPortalEnd.entity_position)
        ---@type LuaEntity
        local entrySignalInEntity =
            surface.create_entity {
            name = "railway_tunnel-internal_signal-not_on_map",
            position = entrySignalInEntityPosition,
            force = force,
            direction = reverseEntryDirection
        }
        local entrySignalOutEntityPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = -1.5, y = EntryEndPortalSetup.entrySignalsDistance}, entryPortalEnd.entity_position)
        ---@type LuaEntity
        local entrySignalOutEntity =
            surface.create_entity {
            name = "railway_tunnel-internal_signal-not_on_map",
            position = entrySignalOutEntityPosition,
            force = force,
            direction = entryDirection
        }
        local entrySignalOutEntity_railEntity = entrySignalOutEntity.get_connected_rails()[1]
        portal.entrySignals = {
            [TunnelSignalDirection.inSignal] = {
                id = entrySignalInEntity.unit_number,
                entity = entrySignalInEntity,
                entity_position = entrySignalInEntityPosition,
                portal = portal,
                direction = TunnelSignalDirection.inSignal
            },
            [TunnelSignalDirection.outSignal] = {
                id = entrySignalOutEntity.unit_number,
                entity = entrySignalOutEntity,
                entity_position = entrySignalOutEntityPosition,
                portal = portal,
                direction = TunnelSignalDirection.outSignal,
                railEntity = entrySignalOutEntity_railEntity,
                railEntity_unitNumber = entrySignalOutEntity_railEntity.unit_number
            }
        }
        entrySignalInEntity.connect_neighbour {wire = defines.wire_type.green, target_entity = entrySignalOutEntity}

        -- Cache the objects details for later use.
        portal.dummyLocomotivePosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = BlockingEndPortalSetup.dummyLocomotiveDistance}, blockedPortalEnd.entity_position)
        portal.enteringTrainUsageDetectorPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = EntryEndPortalSetup.enteringTrainUsageDetectorEntityDistance}, entryPortalEnd.entity_position)
        portal.transitionUsageDetectorPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = BlockingEndPortalSetup.transitionUsageDetectorEntityDistance}, blockedPortalEnd.entity_position)

        -- Add the signals that mark the Tranisition point of the portal.
        local transitionSignalInEntityPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 1.5, y = BlockingEndPortalSetup.transitionSignalsDistance}, blockedPortalEnd.entity_position)
        ---@type LuaEntity
        local transitionSignalInEntity =
            surface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = transitionSignalInEntityPosition,
            force = force,
            direction = reverseEntryDirection
        }
        local transitionSignalOutEntityPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = -1.5, y = BlockingEndPortalSetup.transitionSignalsDistance}, blockedPortalEnd.entity_position)
        ---@type LuaEntity
        local transitionSignalOutEntity =
            surface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = transitionSignalOutEntityPosition,
            force = force,
            direction = entryDirection
        }
        portal.transitionSignals = {
            [TunnelSignalDirection.inSignal] = {
                id = transitionSignalInEntity.unit_number,
                entity = transitionSignalInEntity,
                entity_position = transitionSignalInEntityPosition,
                portal = portal,
                direction = TunnelSignalDirection.inSignal
            },
            [TunnelSignalDirection.outSignal] = {
                id = transitionSignalOutEntity.unit_number,
                entity = transitionSignalOutEntity,
                entity_position = transitionSignalOutEntityPosition,
                portal = portal,
                direction = TunnelSignalDirection.outSignal
            }
        }
        MOD.Interfaces.Tunnel.RegisterTransitionSignal(portal.transitionSignals[TunnelSignalDirection.inSignal])

        -- Add blocking loco and extra signals after where the Transition signals are at the very end of the portal. These make the Transition signals go red and stop paths being reservable across the underground track, thus leading trains to target the transitional signal.
        ---@type LuaEntity
        local blockedInvisibleSignalInEntity =
            surface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 1.5, y = BlockingEndPortalSetup.blockedInvisibleSignalsDistance}, blockedPortalEnd.entity_position),
            force = force,
            direction = reverseEntryDirection
        }
        ---@type LuaEntity
        local blockedInvisibleSignalOutEntity =
            surface.create_entity {
            name = "railway_tunnel-invisible_signal-not_on_map",
            position = Utils.RotateOffsetAroundPosition(entryOrientation, {x = -1.5, y = BlockingEndPortalSetup.blockedInvisibleSignalsDistance}, blockedPortalEnd.entity_position),
            force = force,
            direction = entryDirection
        }
        ---@type LuaEntity
        local transitionSignalBlockingLocomotiveEntity =
            surface.create_entity {
            name = "railway_tunnel-tunnel_portal_blocking_locomotive",
            position = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = BlockingEndPortalSetup.transitionSignalBlockingLocomotiveDistance}, blockedPortalEnd.entity_position),
            force = global.force.tunnelForce,
            direction = reverseEntryDirection
        }
        transitionSignalBlockingLocomotiveEntity.train.schedule = {
            current = 1,
            records = {
                {
                    rail = surface.find_entities_filtered {
                        name = Common.TunnelRailEntityNames,
                        position = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = BlockingEndPortalSetup.transitionSignalBlockingLocomotiveDistance + 3}, blockedPortalEnd.entity_position),
                        limit = 1
                    }[1]
                }
            }
        }
        transitionSignalBlockingLocomotiveEntity.train.manual_mode = false
        transitionSignalBlockingLocomotiveEntity.destructible = false
        portal.portalOtherEntities = {
            [blockedInvisibleSignalInEntity.unit_number] = blockedInvisibleSignalInEntity,
            [blockedInvisibleSignalOutEntity.unit_number] = blockedInvisibleSignalOutEntity,
            [transitionSignalBlockingLocomotiveEntity.unit_number] = transitionSignalBlockingLocomotiveEntity
        }

        --portal.portalEntryPointPosition = Utils.RotateOffsetAroundPosition(builtEntity.orientation, {x = 0, y = -math.abs(EntryEndPortalSetup.trackEntryPointFromCenter)}, portalEntity_position) -- only used by player containers and likely not suitable any more. fix when doing player containers.
    end

    portals[1].entrySignals[TunnelSignalDirection.inSignal].entity.connect_neighbour {wire = defines.wire_type.red, target_entity = portals[2].entrySignals[TunnelSignalDirection.inSignal].entity}
    Portal.LinkRailSignalsToCloseWhenOtherIsntOpen(portals[1].entrySignals[TunnelSignalDirection.inSignal].entity, "signal-1", "signal-2")
    Portal.LinkRailSignalsToCloseWhenOtherIsntOpen(portals[2].entrySignals[TunnelSignalDirection.inSignal].entity, "signal-2", "signal-1")
end

-- Add the rails to the tunnel portal's parts.
---@param portal Portal
Portal.BuildRailForPortalsParts = function(portal)
    -- The function to place rail called within this function only.
    ---@param portalPart PortalPart
    ---@param tracksPositionOffset PortalPartTrackPositionOffset
    local PlaceRail = function(portalPart, tracksPositionOffset)
        local railPos = Utils.RotateOffsetAroundPosition(portalPart.entity_orientation, tracksPositionOffset.positionOffset, portalPart.entity_position)
        local placedRail = portal.surface.create_entity {name = tracksPositionOffset.trackEntityName, position = railPos, force = portal.force, direction = Utils.RotateDirectionByDirection(tracksPositionOffset.baseDirection, defines.direction.north, portalPart.entity_direction)}
        placedRail.destructible = false
        portal.portalRailEntities[placedRail.unit_number] = placedRail
    end

    -- Loop over the portal parts and add their rails.
    portal.portalRailEntities = {}
    for _, portalEnd in pairs(portal.portalEnds) do
        for _, tracksPositionOffset in pairs(portalEnd.typeData.tracksPositionOffset) do
            PlaceRail(portalEnd, tracksPositionOffset)
        end
    end
    for _, portalSegment in pairs(portal.portalSegments) do
        for _, tracksPositionOffset in pairs(portalSegment.typeData.tracksPositionOffset) do
            PlaceRail(portalSegment, tracksPositionOffset)
        end
    end
end

-- Sets a rail signal with circuit condition to output nonGreenSignalOutputName named signal when not open and to close when recieveing closeOnSignalName named signal. Used as part of cross linking 2 signals to close when the other isn't open.
---@param railSignalEntity LuaEntity
---@param nonGreenSignalOutputName string @ Virtual signal name to be output to the cirtuit network when the signal state isn't green.
---@param closeOnSignalName string @ Virtual signal name that triggers the singal state to be closed when its greater than 0 on the circuit network.
Portal.LinkRailSignalsToCloseWhenOtherIsntOpen = function(railSignalEntity, nonGreenSignalOutputName, closeOnSignalName)
    local controlBehavior = railSignalEntity.get_or_create_control_behavior() ---@type LuaRailSignalControlBehavior
    controlBehavior.read_signal = true
    controlBehavior.red_signal = {type = "virtual", name = nonGreenSignalOutputName}
    controlBehavior.orange_signal = {type = "virtual", name = nonGreenSignalOutputName}
    controlBehavior.close_signal = true
    controlBehavior.circuit_condition = {condition = {first_signal = {type = "virtual", name = closeOnSignalName}, comparator = ">", constant = 0}, fulfilled = true}
end

-- Registers and sets up the portal elements after the tunnel has been created.
---@param portals Portal[]
Portal.On_PostTunnelCompleted = function(portals)
    for _, portal in pairs(portals) do
        -- Both of these functions require the tunnel to be present in the portal object as they are called throughout the portals lifetime.
        Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, false)
        Portal.AddTransitionUsageDetectionEntityToPortal(portal)
    end
end

-- If the built entity was a ghost of an underground segment then check it is on the rail grid.
---@param event on_built_entity|on_robot_built_entity|script_raised_built
Portal.OnBuiltEntityGhost = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or createdEntity.type ~= "entity-ghost" or PortalEndAndSegmentEntityNames[createdEntity.ghost_name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end

    if not TunnelShared.IsPlacementOnRailGrid(createdEntity) then
        TunnelShared.UndoInvalidTunnelPartPlacement(createdEntity, placer, false)
        return
    end
end

-- Runs when a player mines something, but before its removed from the map. We can't stop the mine, but can get all the details and replace the mined item if the mining should be blocked.
---@param event on_pre_player_mined_item|on_robot_pre_mined
Portal.OnPreMinedEntity = function(event)
    -- Check its one of the entities this function wants to inspect.
    local minedEntity = event.entity
    if not minedEntity.valid or PortalEndAndSegmentEntityNames[minedEntity.name] == nil then
        return
    end

    -- Check its a successfully built entity. As invalid placements mine the entity and so they don't have a global entry.
    local minedPortalPart = global.portals.portalPartEntityIdToPortalPart[minedEntity.unit_number]
    if minedPortalPart == nil then
        return
    end

    -- The entity is part of a registered object so we need to check and handle its removal carefully.
    local minedPortal = minedPortalPart.portal
    if minedPortal == nil or minedPortal.tunnel == nil then
        -- Part isn't in a portal so the entity can always be removed.
        Portal.EntityRemoved(minedPortalPart)
    else
        if MOD.Interfaces.Tunnel.GetTunnelsUsageEntry(minedPortal.tunnel) then
            -- Theres an in-use tunnel so undo the removal.
            local miner = event.robot -- Will be nil for player mined.
            if miner == nil and event.player_index ~= nil then
                miner = game.get_player(event.player_index)
            end
            TunnelShared.EntityErrorMessage(miner, {"message.railway_tunnel-tunnel_part_mining_blocked_as_in_use"}, minedEntity.surface, minedEntity.position)
            Portal.ReplacePortalPartEntity(minedPortalPart)
        else
            -- Safe to mine the part.
            Portal.EntityRemoved(minedPortalPart)
        end
    end
end

-- Places the replacement portal part entity and destroys the old entity (so it can't be mined and get the item). Then relinks the new entity back in to its object.
---@param minedPortalPart PortalPart
Portal.ReplacePortalPartEntity = function(minedPortalPart)
    -- Destroy the old entity after caching its values.
    local oldPortalPartEntity = minedPortalPart.entity
    local oldPortalPartEntity_lastUser, oldPortalPartId = oldPortalPartEntity.last_user, minedPortalPart.id
    oldPortalPartEntity.destroy()

    -- Create the new entity and update the old portal part object with it.
    local newPortalPartEntity = minedPortalPart.surface.create_entity {name = minedPortalPart.entity_name, position = minedPortalPart.entity_position, direction = minedPortalPart.entity_direction, force = minedPortalPart.force, player = oldPortalPartEntity_lastUser}
    newPortalPartEntity.rotatable = false
    minedPortalPart.entity = newPortalPartEntity
    minedPortalPart.id = newPortalPartEntity.unit_number

    -- Remove the old globals and add the new ones.
    global.portals.portalPartEntityIdToPortalPart[oldPortalPartId] = nil
    global.portals.portalPartEntityIdToPortalPart[minedPortalPart.id] = minedPortalPart

    -- If there's a portal update it.
    local portal = minedPortalPart.portal
    if portal ~= nil then
        if minedPortalPart.typeData.partType == PortalPartType.portalEnd then
            portal.portalEnds[oldPortalPartId] = nil
            portal.portalEnds[minedPortalPart.id] = minedPortalPart
        elseif minedPortalPart.typeData.partType == PortalPartType.portalSegment then
            portal.portalSegments[oldPortalPartId] = nil
            portal.portalSegments[minedPortalPart.id] = minedPortalPart
        else
            error("unrecognised portalTypeData.partType: " .. minedPortalPart.typeData.partType)
        end
    end
end

-- Called by other functions when a portal part entity is removed and thus we need to remove the portal as part of this.
---@param removedPortalPart PortalPart
---@param killForce? LuaForce|null @ Populated if the entity is being removed due to it being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity|null @ Populated if the entity is being removed due to it being killed, otherwise nil.
Portal.EntityRemoved = function(removedPortalPart, killForce, killerCauseEntity)
    -- Handle the portal part object itself so that the surfacePositions are removed before we re-create the remaining portal part's portals.
    global.portals.portalPartEntityIdToPortalPart[removedPortalPart.id] = nil
    global.portals.portalPartInternalConnectionSurfacePositionStrings[removedPortalPart.frontInternalSurfacePositionString] = nil
    global.portals.portalPartInternalConnectionSurfacePositionStrings[removedPortalPart.rearInternalSurfacePositionString] = nil

    -- Handle the portal object if there is one.
    local portal = removedPortalPart.portal
    if portal ~= nil then
        -- Handle the tunnel if there is one before the portal itself. As the remove tunnel function calls back to its 2 portals and handles/removes portal fields requiring a tunnel.
        if portal.tunnel ~= nil then
            MOD.Interfaces.Tunnel.RemoveTunnel(portal.tunnel, killForce, killerCauseEntity)
        end

        -- Handle the portal object.

        -- Remove the portal's global objects.
        for _, endPortalPart in pairs(portal.portalEnds) do
            global.portals.portalTunnelInternalConnectionSurfacePositionStrings[next(endPortalPart.nonConnectedInternalSurfacePositions)] = nil
        end
        global.portals.portals[portal.id] = nil

        -- Remove this portal part from the portals fields before we re-process the other portals parts.
        portal.portalEnds[removedPortalPart.id] = nil
        portal.portalSegments[removedPortalPart.id] = nil

        -- As we don't know the portal's parts makeup we will just disolve the portal and recreate new one(s) by checking each remaining portal part. This is a bit crude, but can be reviewed if UPS impactful.
        -- Make each portal part forget its parent so they are all ready to re-merge in to new portals later.
        for _, list in pairs({portal.portalEnds, portal.portalSegments}) do
            for _, __ in pairs(list) do
                local loopingGenericPortalPart = __ ---@type PortalPart
                loopingGenericPortalPart.portal = nil
                loopingGenericPortalPart.nonConnectedInternalSurfacePositions = {}
                loopingGenericPortalPart.nonConnectedExternalSurfacePositions = {}
                if loopingGenericPortalPart.typeData.partType == PortalPartType.portalEnd then
                    local loopingEndPortalPart = loopingGenericPortalPart ---@type PortalEnd
                    loopingEndPortalPart.connectedToUnderground = false
                    loopingEndPortalPart.endPortalType = nil
                end
            end
        end
        -- Loop over each portal part and add them back in to whatever portals they reform.
        for _, list in pairs({portal.portalEnds, portal.portalSegments}) do
            for _, __ in pairs(list) do
                local loopingGenericPortalPart = __ ---@type PortalPart
                Portal.UpdatePortalsForNewPortalPart(loopingGenericPortalPart)
            end
        end
    end
end

-- Called from the Tunnel Manager when a tunnel that the portal was part of has been removed.
---@param portals Portal[]
---@param killForce? LuaForce|null @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity|null @ Populated if the tunnel is being removed due to an entity being killed, otherwise nil.
Portal.On_TunnelRemoved = function(portals, killForce, killerCauseEntity)
    -- Cleanse the portal's fields that are only populated when they are part of a tunnel.
    for _, portal in pairs(portals) do
        portal.tunnel = nil

        for _, otherEntity in pairs(portal.portalOtherEntities) do
            if otherEntity.valid then
                otherEntity.destroy()
            end
        end
        portal.portalOtherEntities = nil
        TunnelShared.DestroyCarriagesOnRailEntityList(portal.portalRailEntities, killForce, killerCauseEntity)
        for _, railEntity in pairs(portal.portalRailEntities) do
            if railEntity.valid then
                railEntity.destroy()
            end
        end
        portal.portalRailEntities = nil

        for _, entrySignal in pairs(portal.entrySignals) do
            if entrySignal.entity.valid then
                entrySignal.entity.destroy()
            end
        end
        portal.entrySignals = nil
        for _, transitionSignal in pairs(portal.transitionSignals) do
            if transitionSignal.entity.valid then
                MOD.Interfaces.Tunnel.DeregisterTransitionSignal(transitionSignal)
                transitionSignal.entity.destroy()
            end
        end
        portal.transitionSignals = nil

        Portal.RemoveEnteringTrainUsageDetectionEntityFromPortal(portal)
        portal.enteringTrainUsageDetectorPosition = nil
        Portal.RemoveTransitionUsageDetectionEntityFromPortal(portal)
        portal.transitionUsageDetectorPosition = nil

        portal.entryPortalEnd.endPortalType = nil
        portal.entryPortalEnd = nil
        portal.blockedPortalEnd.endPortalType = nil
        portal.blockedPortalEnd = nil

        portal.portalEntryPointPosition = nil
        portal.dummyLocomotivePosition = nil
        portal.entryDirection = nil
        portal.leavingDirection = nil
    end
end

-- Triggered when a monitored entity type is killed.
---@param event on_entity_died|script_raised_destroy
Portal.OnDiedEntity = function(event)
    -- Check its one of the entities this function wants to inspect.
    local diedEntity = event.entity
    if not diedEntity.valid or PortalEndAndSegmentEntityNames[diedEntity.name] == nil then
        return
    end

    -- Check its a previously successfully built entity. Just incase something destroys the entity before its made a global entry.
    local diedPortalPart = global.portals.portalPartEntityIdToPortalPart[diedEntity.unit_number]
    if diedPortalPart == nil then
        return
    end

    Portal.EntityRemoved(diedPortalPart, event.force, event.cause)
end

-- Occurs when a train tries to pass through the border of a portal, when entering and exiting.
---@param event on_entity_died|script_raised_destroy
Portal.OnDiedEntityPortalEntryTrainDetector = function(event)
    local diedEntity, carriageEnteringPortalTrack = event.entity, event.cause
    if not diedEntity.valid or diedEntity.name ~= "railway_tunnel-portal_entry_train_detector_1x1" then
        -- Needed due to how died event handlers are all bundled togeather.
        return
    end

    local diedEntity_unitNumber = diedEntity.unit_number
    -- Tidy up the blocker reference as in all cases it has been removed.
    local portal = global.portals.enteringTrainUsageDetectorEntityIdToPortal[diedEntity_unitNumber]
    global.portals.enteringTrainUsageDetectorEntityIdToPortal[diedEntity_unitNumber] = nil
    if portal == nil then
        -- No portal any more so nothing further to do.
        return
    end
    portal.enteringTrainUsageDetectorEntity = nil

    if portal.tunnel == nil then
        -- If no tunnel then the portal won't have tracks, so nothing further to do.
        return
    end

    if carriageEnteringPortalTrack == nil then
        -- As there's no cause this should only occur when a script removes the entity. Try to return the detection entity and if the portal is being removed that will handle all scenarios.
        Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, true)
        return
    end
    local train = carriageEnteringPortalTrack.train

    -- Check the tunnel will conceptually accept the train.
    if not MOD.Interfaces.Tunnel.CanTrainUseTunnel(train, portal.tunnel) then
        Portal.StopTrainAsTooLong(train, portal, portal.entryPortalEnd.entity, event.tick)
        Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal)
        return
    end

    -- Is a scheduled train following its schedule so check if its already reserved the tunnel.
    if not train.manual_mode and train.state ~= defines.train_state.no_schedule then
        local train_id = train.id
        local trainIdToManagedTrain = MOD.Interfaces.TrainManager.GetTrainIdsManagedTrainDetails(train_id)
        if trainIdToManagedTrain ~= nil then
            -- This train has reserved a tunnel somewhere.
            local managedTrain = trainIdToManagedTrain.managedTrain
            if managedTrain.tunnel.id == portal.tunnel.id then
                -- The train has reserved this tunnel.
                if trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.enteringTrain then
                    -- Train had reserved the tunnel via signals at distance and is now trying to pass in to the tunnels entry portal track. This is healthy activity.
                    return
                elseif trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.leavingTrain then
                    -- Train has been using the tunnel and is now trying to pass out of the tunnels exit portal track. This is healthy activity.
                    return
                else
                    error("Train is crossing a tunnel portal's threshold while not in an expected state.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. managedTrain.tunnel.id)
                    return
                end
            else
                error("Train has entered one portal in automatic mode, while it has a reservation on another.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. managedTrain.tunnel.id)
                return
            end
        else
            -- This train hasn't reserved any tunnel.
            if portal.tunnel.managedTrain == nil then
                -- Portal's tunnel isn't reserved so this train can grab the portal.
                MOD.Interfaces.TrainManager.RegisterTrainOnPortalTrack(train, portal)
                return
            else
                -- Portal's tunnel is already being used so stop this train entering. Not sure how this could have happened, but just stop the new train here and restore the entering train detection entity.

                -- This will be removed when future tests functionality is added. Is just in short term as we don't expect to reach this state ever.
                error("Train has entered one portal in automatic mode, while the portal's tunnel was reserved by another train.\nthisTrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. portal.tunnel.managedTrain.tunnel.id .. "\reservedTrainId: " .. portal.tunnel.managedTrain.tunnel.managedTrain.id)

                train.speed = 0
                train.manual_mode = true
                -- OVERHAUL: this may need setting to manual mode next tick as well?
                Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal)
                rendering.draw_text {
                    text = {"message.railway_tunnel-tunnel_in_use"},
                    surface = portal.tunnel.surface,
                    target = portal.entryPortalEnd.entity,
                    time_to_live = 300,
                    forces = {portal.force},
                    color = {r = 1, g = 0, b = 0, a = 1},
                    scale_with_zoom = true
                }
                return
            end
        end
    end

    -- Train has a player in it so we assume its being actively driven. Can only detect if player input is being entered right now, not the players intention.
    if #train.passengers ~= 0 then
        -- Future support for player driven train will expand this logic as needed. For now we just assume everything is fine.
        error("suspected player driving train")
        return
    end

    -- Train is coasting so stop it and put the detection entity back.
    train.speed = 0
    Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal)
    rendering.draw_text {
        text = {"message.railway_tunnel-unpowered_trains_cant_use_tunnels"},
        surface = portal.tunnel.surface,
        target = portal.entryPortalEnd.entity,
        time_to_live = 300,
        forces = {portal.force},
        color = {r = 1, g = 0, b = 0, a = 1},
        scale_with_zoom = true
    }
end

--- Will try and place the entering train detection entity now and if not possible will keep on trying each tick until either successful or a tunnel state setting stops the attempts. Is safe to call if the entity already exists as will just abort (initally or when in per tick loop).
---@param portal Portal
---@param retry boolean @ If to retry next tick should it not be placable.
---@return LuaEntity @ The enteringTrainUsageDetectorEntity if successfully placed.
Portal.AddEnteringTrainUsageDetectionEntityToPortal = function(portal, retry)
    if portal.tunnel == nil or not portal.isComplete or portal.enteringTrainUsageDetectorEntity ~= nil then
        -- The portal has been removed, so we shouldn't add the detection entity back. Or another task has added the dector back and so we can stop.
        return
    end
    return Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled(nil, portal, retry)
end

---@param event UtilityScheduledEvent_CallbackObject
---@param portal Portal
---@param retry boolean @ If to retry next tick should it not be placable.
---@return LuaEntity @ The enteringTrainUsageDetectorEntity if successfully placed.
Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled = function(event, portal, retry)
    local eventData
    if event ~= nil then
        eventData = event.data
        portal, retry = eventData.portal, eventData.retry
    end
    if portal.tunnel == nil or not portal.isComplete or portal.enteringTrainUsageDetectorEntity ~= nil then
        -- The portal has been removed, so we shouldn't add the detection entity back. Or another task has added the dector back and so we can stop.
        return
    end

    -- The left train will initially be within the collision box of where we want to place this. So try to place it and if it fails retry a moment later. In tests 2/3 of the time it was created successfully.
    local enteringTrainUsageDetectorEntity =
        portal.surface.create_entity {
        name = "railway_tunnel-portal_entry_train_detector_1x1",
        force = global.force.tunnelForce,
        position = portal.enteringTrainUsageDetectorPosition
    }
    if enteringTrainUsageDetectorEntity ~= nil then
        portal.enteringTrainUsageDetectorEntity = enteringTrainUsageDetectorEntity
        global.portals.enteringTrainUsageDetectorEntityIdToPortal[portal.enteringTrainUsageDetectorEntity.unit_number] = portal
        return portal.enteringTrainUsageDetectorEntity
    elseif retry then
        -- Schedule this to be tried again next tick.
        local postbackData
        if eventData ~= nil then
            postbackData = eventData
        else
            postbackData = {portal = portal, retry = retry}
        end
        EventScheduler.ScheduleEventOnce(nil, "Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled", portal.id, postbackData)
    end
end

---@param portal Portal
Portal.RemoveEnteringTrainUsageDetectionEntityFromPortal = function(portal)
    if portal.enteringTrainUsageDetectorEntity ~= nil then
        if portal.enteringTrainUsageDetectorEntity.valid then
            global.portals.enteringTrainUsageDetectorEntityIdToPortal[portal.enteringTrainUsageDetectorEntity.unit_number] = nil
            portal.enteringTrainUsageDetectorEntity.destroy()
        end
        portal.enteringTrainUsageDetectorEntity = nil
    end
end

-- Occurs when a train passes through the transition point of a portal when fully entering the tunnel.
---@param event on_entity_died|script_raised_destroy
Portal.OnDiedEntityPortalTransitionTrainDetector = function(event)
    local diedEntity, carriageAtTransitionOfPortalTrack = event.entity, event.cause
    if not diedEntity.valid or diedEntity.name ~= "railway_tunnel-portal_transition_train_detector_1x1" then
        -- Needed due to how died event handlers are all bundled togeather.
        return
    end

    local diedEntity_unitNumber = diedEntity.unit_number
    -- Tidy up the blocker reference as in all cases it has been removed.
    local portal = global.portals.transitionUsageDetectorEntityIdToPortal[diedEntity_unitNumber]
    global.portals.transitionUsageDetectorEntityIdToPortal[diedEntity_unitNumber] = nil
    if portal == nil then
        -- No portal any more so nothing further to do.
        return
    end
    portal.transitionUsageDetectorEntity = nil

    if portal.tunnel == nil then
        -- if no tunnel then the portal won't have tracks, so nothing further to do.
        return
    end

    if carriageAtTransitionOfPortalTrack == nil then
        -- As there's no cause this should only occur when a script removes the entity. Try to return the detection entity and if the portal is being removed that will handle all scenarios.
        Portal.AddTransitionUsageDetectionEntityToPortal(portal)
        return
    end
    local train = carriageAtTransitionOfPortalTrack.train

    -- Check the tunnel will conceptually accept the train.
    if not MOD.Interfaces.Tunnel.CanTrainUseTunnel(train, portal.tunnel) then
        Portal.StopTrainAsTooLong(train, portal, portal.blockedPortalEnd.entity, event.tick)
        Portal.AddTransitionUsageDetectionEntityToPortal(portal)
        return
    end

    -- Is a scheduled train following its schedule so check if its already reserved the tunnel.
    if not train.manual_mode and train.state ~= defines.train_state.no_schedule then
        local train_id = train.id
        local trainIdToManagedTrain = MOD.Interfaces.TrainManager.GetTrainIdsManagedTrainDetails(train_id)
        if trainIdToManagedTrain ~= nil then
            -- This train has reserved a tunnel somewhere.
            local managedTrain = trainIdToManagedTrain.managedTrain
            if managedTrain.tunnel.id == portal.tunnel.id then
                -- The train has reserved this tunnel.
                if trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.enteringTrain then
                    -- Train had reserved the tunnel via signals at distance and is now ready to fully enter the tunnel.
                    MOD.Interfaces.TrainManager.TrainEnterTunnel(managedTrain, event.tick)
                    Portal.AddTransitionUsageDetectionEntityToPortal(portal)
                    return
                elseif trainIdToManagedTrain.tunnelUsagePart == TunnelUsageParts.leavingTrain then
                    error("Train has been using the tunnel and is now trying to pass backwards through the tunnel. This may be supported in future, but error for now.")
                    return
                else
                    error("Train is crossing a tunnel portal's transition threshold while not in an expected state.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. managedTrain.tunnel.id)
                    return
                end
            else
                error("Train has reached the transition point of one portal, while it has a reservation on another portal.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. managedTrain.tunnel.id)
                return
            end
        else
            -- This train hasn't reserved any tunnel.
            if portal.tunnel.managedTrain == nil then
                -- Portal's tunnel isn't reserved so this train can just use the tunnel to commit now.
                error("unsupported unexpected train entering tunnel without having passed through entry detector at present")
                MOD.Interfaces.TrainManager.TrainEnterTunnel(train, event.tick)
                return
            else
                -- Portal's tunnel is already being used so stop this train from using the tunnel. Not sure how this could have happened, but just stop the new train here and restore the transition detection entity.

                -- This will be removed when future tests functionality is added. Is just in short term as we don't expect to reach this state ever.
                error("Train has reached the transition of a portal in automatic mode, while the portal's tunnel was reserved by another train.\nthisTrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. portal.tunnel.managedTrain.tunnel.id .. "\reservedTrainId: " .. portal.tunnel.managedTrain.tunnel.managedTrain.id)

                train.speed = 0
                train.manual_mode = true
                -- OVERHAUL: this may need setting to manual mode next tick as well?
                Portal.AddTransitionUsageDetectionEntityToPortal(portal)
                rendering.draw_text {
                    text = {"message.railway_tunnel-tunnel_in_use"},
                    surface = portal.tunnel.surface,
                    target = portal.blockedPortalEnd.entity,
                    time_to_live = 180,
                    forces = {portal.force},
                    color = {r = 1, g = 0, b = 0, a = 1},
                    scale_with_zoom = true
                }
                return
            end
        end
    end

    -- Train has a player in it so we assume its being actively driven. Can only detect if player input is being entered right now, not the players intention.
    if #train.passengers ~= 0 then
        -- Future support for player driven train will expand this logic as needed. For now we just assume everything is fine.
        error("suspected player driving train")
        return
    end

    -- Train is coasting so stop it dead and try to put the detection entity back. This is only reachable in edge cases.
    train.speed = 0
    Portal.AddTransitionUsageDetectionEntityToPortal(portal)
    rendering.draw_text {
        text = {"message.railway_tunnel-unpowered_trains_cant_use_tunnels"},
        surface = portal.tunnel.surface,
        target = portal.blockedPortalEnd.entity,
        time_to_live = 180,
        forces = {portal.force},
        color = {r = 1, g = 0, b = 0, a = 1},
        scale_with_zoom = true
    }
end

--- Will place the transition detection entity and should only be called when the train has been cloned and removed.
---@param portal Portal
Portal.AddTransitionUsageDetectionEntityToPortal = function(portal)
    if portal.tunnel == nil or not portal.isComplete or portal.transitionUsageDetectorEntity ~= nil then
        -- The portal has been removed, so we shouldn't add the detection entity back. Or another task has added the dector back and so we can stop.
        return
    end

    local transitionUsageDetectorEntity =
        portal.surface.create_entity {
        name = "railway_tunnel-portal_transition_train_detector_1x1",
        force = global.force.tunnelForce,
        position = portal.transitionUsageDetectorPosition
    }
    if transitionUsageDetectorEntity == nil then
        error("Failed to create Portal's transition usage train detection entity")
    end
    global.portals.transitionUsageDetectorEntityIdToPortal[transitionUsageDetectorEntity.unit_number] = portal
    portal.transitionUsageDetectorEntity = transitionUsageDetectorEntity
end

---@param portal Portal
Portal.RemoveTransitionUsageDetectionEntityFromPortal = function(portal)
    if portal.transitionUsageDetectorEntity ~= nil then
        if portal.transitionUsageDetectorEntity.valid then
            global.portals.transitionUsageDetectorEntityIdToPortal[portal.transitionUsageDetectorEntity.unit_number] = nil
            portal.transitionUsageDetectorEntity.destroy()
        end
        portal.transitionUsageDetectorEntity = nil
    end
end

--- Schedule a train to be set to manual next tick. Can be needed as sometimes the Factorio game engine will restart a stopped train upon collision.
---@param train LuaTrain
---@param currentTick Tick
Portal.SetTrainToManualNextTick = function(train, currentTick)
    EventScheduler.ScheduleEventOnce(currentTick + 1, "Portal.SetTrainToManual_Scheduled", train.id, {train = train})
end

--- Set the train to manual.
---@param event UtilityScheduledEvent_CallbackObject
Portal.SetTrainToManual_Scheduled = function(event)
    local train = event.data.train ---@type LuaTrain
    if train.valid then
        train.manual_mode = true
    end
end

--- Train can't enter the portal so stop it, set it to manual and alert the players.
---@param train LuaTrain
---@param portal Portal
---@param alertEntity LuaEntity
---@param currentTick Tick
Portal.StopTrainAsTooLong = function(train, portal, alertEntity, currentTick)
    -- Stop the train.
    train.speed = 0
    train.manual_mode = true
    -- Have to set the train to be stopped next tick as the Factorio game engine will restart a stopped train upon collision.
    Portal.SetTrainToManualNextTick(train, currentTick)

    -- Show a text message at the tunnel entrance for a short period.
    rendering.draw_text {
        text = {"message.railway_tunnel-train_too_long"},
        surface = portal.tunnel.surface,
        target = alertEntity,
        time_to_live = 300,
        forces = {portal.force},
        color = {r = 1, g = 0, b = 0, a = 1},
        scale_with_zoom = true
    }

    -- Add the alert for the tunnel force.
    local alertId = PlayerAlerts.AddCustomAlertToForce(portal.tunnel.force, train.id, alertEntity, {type = "virtual", name = "railway_tunnel"}, {"message.railway_tunnel-train_too_long"}, true)

    -- Setup a schedule to detect when the issue is resolved and the alert can be removed.
    EventScheduler.ScheduleEventOnce(currentTick + 1, "Portal.CheckIfTooLongTrainStillStopped_Scheduled", train.id, {train = train, alertEntity = alertEntity, alertId = alertId})
end

--- Checks a train until it is no longer stopped and then removes the alert associated with it.
---@param event UtilityScheduledEvent_CallbackObject
Portal.CheckIfTooLongTrainStillStopped_Scheduled = function(event)
    local train = event.data.train ---@type LuaTrain
    local alertEntity = event.data.alertEntity ---@type LuaEntity
    local alertId = event.data.alertId ---@type Id
    local trainStopped = true

    if not train.valid then
        -- Train is not valid any more so alert should be removed.
        trainStopped = false
    elseif not alertEntity.valid then
        -- The alert target entity is not valid any more so alert should be removed.
        trainStopped = false
    elseif train.speed ~= 0 then
        -- The train has speed and so isn't stopped any more.
        trainStopped = false
    elseif not train.manual_mode then
        -- The train is in automatic so isn't stopped any more.
        trainStopped = false
    end

    -- Handle the stopped state.
    if not trainStopped then
        -- Train isn't stopped so remove the alert.
        PlayerAlerts.RemoveCustomAlertFromForce(alertEntity.force, alertId)
    else
        -- Train is still stopped so schedule a check for next tick.
        EventScheduler.ScheduleEventOnce(event.tick + 1, "Portal.CheckIfTooLongTrainStillStopped_Scheduled", event.instanceId, event.data)
    end
end

return Portal
