local Utils = require("utility.utils")
local TunnelShared = require("scripts.tunnel-shared")
local Common = require("scripts.common")
local TunnelSignalDirection, TunnelUsageState = Common.TunnelSignalDirection, Common.TunnelUsageState
local Portal = {}
local EventScheduler = require("utility.event-scheduler")

---@class Portal
---@field id uint @ unique id of the portal object.
---@field isComplete boolean @ if the portal has 2 connected portal end objects or not.
---@field portalParts table<UnitNumber, PortalPart> @ The portal end and portal segment objects. No direction, orientation or role information implied by this array. Key'd by the portal end entity unit_number (id).
---@field portalEnds table<UnitNumber, PortalEnd> @ the portal end objects of this portal. No direction, orientation or role information implied by this array. Key'd by the portal end entity unit_number (id).
---@field portalSegments table<UnitNumber, PortalSegment> @ the portal segment objects of this portal. Key'd by the portal segment entity unit_number (id).
---@field trainWaitingAreaTilesLength uint @ how many tiles this portal has for trains to wait in it when using the tunnel.
---@field force LuaForce @ the force this portal object belongs to.
---@field surface LuaSurface @ the surface this portal part object is on.
---@field guiOpenedByParts table<Id, PortalPart> @ A table of portal part Id's to PortalParts that have a GUI opened on this portal for one or more players.
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
---@field portalEntryPointPosition? Position|null @ the position of the entry point to the portal. Is the middle of the rail track where they meet the portal edge. Only established once this portal is part of a valid tunnel.
---@field enteringTrainUsageDetectorEntity? LuaEntity|null @ hidden entity on the entry point to the portal that's death signifies a train is coming on to the portal's rails. Only established once this portal is part of a valid tunnel.
---@field enteringTrainUsageDetectorPosition? Position|null @ the position of this portals enteringTrainUsageDetectorEntity. Only established once this portal is part of a valid tunnel.
---@field transitionUsageDetectorEntity? LuaEntity|null @ hidden entity on the transition point of the portal track that's death signifies a train has reached the entering tunnel stage. Only established once this portal is part of a valid tunnel.
---@field transitionUsageDetectorPosition? Position|null @ the position of this portals transitionUsageDetectorEntity. Only established once this portal is part of a valid tunnel.
---@field dummyLocomotivePosition? Position|null @ the position where the dummy locomotive should be plaed for this portal. Only established once this portal is part of a valid tunnel.
---@field entryDirection? defines.direction|null @ the direction a train would be heading if it was entering this portal. So the entry signals are at the rear of this direction. Only established once this portal is part of a valid tunnel.
---@field leavingDirection? defines.direction|null @ the direction a train would be heading if leaving the tunnel via this portal. Only established once this portal is part of a valid tunnel.
---@field leavingTrainFrontPosition? Position|null @ The position of the leaving train's lead carriage, 2 tiles back from the entry signal position. Only established once this portal is part of a valid tunnel.

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
---@field nonConnectedInternalSurfacePositionStrings table<SurfacePositionString, SurfacePositionString> @ a table of this end part's non connected internal positions to check inside of the entity. Always exists, even if not part of a portal.
---@field nonConnectedExternalSurfacePositionStrings table<SurfacePositionString, SurfacePositionString> @ a table of this end part's non connected external positions to check outside of the entity. Always exists, even if not part of a portal.
---@field graphicRenderIds Id[] @ a table of all render Id's that are associated with this portal part.
---@field guiOpenedByPlayers table<PlayerIndex, LuaPlayer> @ A table of player Id's to LuaPlayer's who have a GUI opened on this portal part.
---
---@field portal? Portal|null @ ref to the parent portal object. Only populated if this portal part is connected to another portal part.
---
---@field portalFacingOrientation? RealOrientation|null @ The orientation for this entity's relationship to the larger portal from the inside of the portal heading outside. Only populated when the portal is Complete.

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
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = -2},
                baseDirection = defines.direction.north
            },
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            },
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
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
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
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
    enteringTrainUsageDetectorEntityDistance = 1.95, -- Detector on the entry side of the portal. Its positioned so that a train entering the tunnel doesn't hit it until its passed the entry signal and a leaving train won't hit it when waiting at the exit signals. Its placed on the outside of the entry signals so that when a train is blocked/stopped from entering a portal upon contact with it, a seperate train that arrives in that portal from traversing the tunnel from the opposite direction doesn't connect to te stopped train. Also makes sure the entry signals don't trigger for the blocked train. It can't trigger for trains that pull right up to the entry signal, although these are on the portal tracks. It also must be blocked by a leaving Train when the entry signals change and the mod starts to try and replace this, we don't want it placed between the leaving trains carriages and re-triggering. This is less UPS effecient for the train leaving ongoing than being positioned further inwards, but that let the edge cases of 2 trains listed above for blocked trains connect and would have required more complicated pre tunnel part mining logic as the train could be on portal tracks and not using the tunnel thus got destroyed). Note: this value can not be changed without full testing as a 0.1 change will likely break some behaviour.
    leavingTrainFrontPosition = -1 -- Has to balance being far enough back so the graphics that are often 0.5 longer than the collision box don't pertrude, but not so far back that on a single loco and 3 portal parts the carriage hits the transition train detector. Currently the collision box start is 1 tile back from the opening.
}

-- Distances are from blocking end portal position in the Portal.entryDirection direction.
local BlockingEndPortalSetup = {
    dummyLocomotiveDistance = 2.2, -- as far back in to the end portal without touching the blocking locomotive.
    transitionUsageDetectorEntityDistance = 4.5, -- Some rail carriages have shorter collision boxes than others. Found 4.3 needed over 4.1 to safely trigger on cargo wagons before they stop before the transition signal, as they're smaller than locomotives. 4.5 is still safe for trains entering and leaving.
    transitionSignalsDistance = 2.5,
    transitionSignalBlockingLocomotiveDistance = -0.9, -- As far away from entry end as possible, but can't stick out beyond the blockedInvisibleSignal as otherwise will affect tunnel track block.
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

    --- The layer to draw graphics at that hide the train. Debug options can lower this so that trains appear on top of it for visual inspection.
    --- Shadows don't appear over other graphics and so we can use this layer for shadows as well as long as we add the shadow render after the main image render.
    global.portalGraphicsLayerOverTrain = 130 -- Infront of main "object" layer.
    global.portalGraphicsLayerUnderTrain = 128 -- Behind main "object" layer.
end

Portal.OnLoad = function()
    MOD.Interfaces.Portal = MOD.Interfaces.Portal or {}
    MOD.Interfaces.Portal.On_PreTunnelCompleted = Portal.On_PreTunnelCompleted
    MOD.Interfaces.Portal.On_TunnelRemoved = Portal.On_TunnelRemoved
    MOD.Interfaces.Portal.AddEnteringTrainUsageDetectionEntityToPortal = Portal.AddEnteringTrainUsageDetectionEntityToPortal
    MOD.Interfaces.Portal.CanAPortalConnectAtItsInternalPosition = Portal.CanAPortalConnectAtItsInternalPosition
    MOD.Interfaces.Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel = Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel
    MOD.Interfaces.Portal.On_PostTunnelCompleted = Portal.On_PostTunnelCompleted
    MOD.Interfaces.Portal.GuiOpenedOnPortalPart = Portal.GuiOpenedOnPortalPart
    MOD.Interfaces.Portal.GuiClosedOnPortalPart = Portal.GuiClosedOnPortalPart

    -- Merged event handler interfaces.
    MOD.Interfaces.Portal.OnBuiltEntity = Portal.OnBuiltEntity
    MOD.Interfaces.Portal.OnBuiltEntityGhost = Portal.OnBuiltEntityGhost
    MOD.Interfaces.Portal.OnDiedEntity = Portal.OnDiedEntity
    MOD.Interfaces.Portal.OnDiedEntityPortalEntryTrainDetector = Portal.OnDiedEntityPortalEntryTrainDetector
    MOD.Interfaces.Portal.OnDiedEntityPortalTransitionTrainDetector = Portal.OnDiedEntityPortalTransitionTrainDetector
    MOD.Interfaces.Portal.OnPreMinedEntity = Portal.OnPreMinedEntity

    EventScheduler.RegisterScheduledEventType("Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled", Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled)
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
---@param createdEntity LuaEntity
---@param createdEntity_name string
Portal.OnBuiltEntity = function(event, createdEntity, createdEntity_name)
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
        graphicRenderIds = {},
        guiOpenedByPlayers = {}
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

    -- Record this portal part object's non connected positions as both front and back to start.
    portalPartObject.nonConnectedInternalSurfacePositionStrings = {[portalPartObject.frontInternalSurfacePositionString] = portalPartObject.frontInternalSurfacePositionString, [portalPartObject.rearInternalSurfacePositionString] = portalPartObject.rearInternalSurfacePositionString}
    portalPartObject.nonConnectedExternalSurfacePositionStrings = {[portalPartObject.frontExternalCheckSurfacePositionString] = portalPartObject.frontExternalCheckSurfacePositionString, [portalPartObject.rearExternalCheckSurfacePositionString] = portalPartObject.rearExternalCheckSurfacePositionString}

    -- Register the part's entity for reverse lookup.
    global.portals.portalPartEntityIdToPortalPart[portalPartObject.id] = portalPartObject

    -- Join this portal part to a portal if approperiate. This will check and update the Portal.isComplete attribute used below.
    Portal.UpdatePortalsForNewPortalPart(portalPartObject)

    -- If the portal is complete then check if we've just connected to underground parts.
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
                -- Update ours nonConnected Internal and External SurfacePositions as we are now connected on this connection side.
                portalPartObject.nonConnectedInternalSurfacePositionStrings[checkDetails.internalCheckSurfacePositionString] = nil
                portalPartObject.nonConnectedExternalSurfacePositionStrings[checkDetails.externalCheckSurfacePositionString] = nil
                -- Update their nonConnected Internal and External SurfacePositions, but our surface position string text is flipped as recording to their perspective.
                connectedPortalPart.nonConnectedInternalSurfacePositionStrings[checkDetails.externalCheckSurfacePositionString] = nil
                connectedPortalPart.nonConnectedExternalSurfacePositionStrings[checkDetails.internalCheckSurfacePositionString] = nil
            else
                -- Record our free connected point as not in use. May have been removed before in an edge case so update it back as free (confirmed called in edge cases when not existing before).
                portalPartObject.nonConnectedInternalSurfacePositionStrings[checkDetails.internalCheckSurfacePositionString] = checkDetails.internalCheckSurfacePositionString
                portalPartObject.nonConnectedExternalSurfacePositionStrings[checkDetails.externalCheckSurfacePositionString] = checkDetails.externalCheckSurfacePositionString
            end
        else
            -- Record our free connected point as not in use. May have been removed before in an edge case so update it back as free (confirmed called in edge cases when not existing before).
            portalPartObject.nonConnectedInternalSurfacePositionStrings[checkDetails.internalCheckSurfacePositionString] = checkDetails.internalCheckSurfacePositionString
            portalPartObject.nonConnectedExternalSurfacePositionStrings[checkDetails.externalCheckSurfacePositionString] = checkDetails.externalCheckSurfacePositionString
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
                portalParts = {},
                portalEnds = {},
                portalSegments = {},
                trainWaitingAreaTilesLength = 0,
                force = portalPartObject.force,
                surface = portalPartObject.surface,
                guiOpenedByParts = {}
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

        -- Something was done to this portal so update any open GUIs on any parts it has.
        -- This will lead to an open GUI being refreshed multiple times for re-created portals as each part is added to the portal. But we need the last value and is pretty edge case.
        for _, portalPart in pairs(portalPartObject.portal.portalParts) do
            for playerIndex in pairs(portalPart.guiOpenedByPlayers) do
                MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged(portalPart, playerIndex, false)
            end
        end
    else
        -- If this part was open in a GUI already then update it as its likely been part of a portal and is now orphaned.
        for playerIndex in pairs(portalPartObject.guiOpenedByPlayers) do
            MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged(portalPartObject, playerIndex, false)
        end
    end

    -- Check if portal is complete for the first time. Can be triggered multiple times for the same portal when a neighbouring invalid portal part to a valid portal is removed and so all members of the old portal (now valid) are triggered to review their state.
    if portalPartObject.portal ~= nil and Utils.GetTableNonNilLength(portalPartObject.portal.portalEnds) == 2 and not portalPartObject.portal.isComplete then
        local portalPartsDisowned = Portal.ClensePortalsExcessParts(portalPartObject.portal)
        Portal.PortalComplete(portalPartObject.portal)
        if next(portalPartsDisowned) ~= nil then
            Portal.RecalculatePortalPartsParentPortal(portalPartsDisowned)
        end
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
    portal.portalParts[portalPart.id] = portalPart

    -- Check for any already open GUIs on the portalPart and if so update portal to know of the part.
    if next(portalPart.guiOpenedByPlayers) ~= nil then
        portal.guiOpenedByParts[portalPart.id] = portalPart
    end
end

--- Moves the old partal parts to the new portal and removes the old portal object.
---@param oldPortal Portal
---@param newPortal Portal
Portal.MergePortalInToOtherPortal = function(oldPortal, newPortal)
    -- Move over all portal parts to the new portal's lists.
    for id, part in pairs(oldPortal.portalEnds) do
        newPortal.portalEnds[id] = part
        part.portal = newPortal
    end
    for id, part in pairs(oldPortal.portalSegments) do
        newPortal.portalSegments[id] = part
        part.portal = newPortal
    end
    for id, part in pairs(oldPortal.portalParts) do
        newPortal.portalParts[id] = part
    end

    -- Update the train waiting area length to be the sum of the 2 portals as this is updated as each part is added to a portal.
    newPortal.trainWaitingAreaTilesLength = newPortal.trainWaitingAreaTilesLength + oldPortal.trainWaitingAreaTilesLength

    -- Forget the old portal from globals as nothing should reference it now.
    global.portals.portals[oldPortal.id] = nil

    -- Move across any open GUIs.
    for portalPartId, portalPart in pairs(oldPortal.guiOpenedByParts) do
        newPortal.guiOpenedByParts[portalPartId] = portalPart
    end
end

--- A complete portal is 2 ends with some segments between. If a portal end part has segments both sides it must have the excess trimmed as the PortalComplete() logic requires portal end's with 1 used and 1 free connection.
---@param portal Portal
---@return table<UnitNumber, PortalPart> portalPartsDisowned @ The portal parts that were dropped from this portal. As after the Portal is completed they will need to be regnerated due to their portal and connected point states being messed up by our cleanse here.
Portal.ClensePortalsExcessParts = function(portal)
    local portalPartsDisowned = {} ---@type table<UnitNumber, PortalPart>
    for portalEndPart_id, portalEndPart in pairs(portal.portalEnds) do
        -- If theres no free connection points then the portal end has segments on both sides.
        if next(portalEndPart.nonConnectedInternalSurfacePositionStrings) == nil then
            -- This is a very rare scenario so doesn't need to be overly optimised.

            -- Get the other portal as this is our target.
            local targetPortalEnd
            if portalEndPart_id == next(portal.portalEnds) then
                -- This is first in table, so other end is the second.
                targetPortalEnd = portal.portalEnds[next(portal.portalEnds, portalEndPart_id)]
            else
                -- This is the second in the table, so other end is the first.
                targetPortalEnd = portal.portalEnds[next(portal.portalEnds)]
            end

            -- Walk down the connected portal part in the front direction until we hit the other portal end or have walked the full line.
            local frontConnectedPortalPartSurfacePositionObject = global.portals.portalPartInternalConnectionSurfacePositionStrings[portalEndPart.frontExternalCheckSurfacePositionString] -- Is always found as otherwise this would be a non connected point.
            local frontOtherEndFound, frontPartsWalked = Portal.WalkConnectedPortalParts(frontConnectedPortalPartSurfacePositionObject.portalPart, portalEndPart.frontExternalCheckSurfacePositionString, targetPortalEnd)
            -- If the other end isn't found then the front is the bad direction walked list.
            if not frontOtherEndFound then
                -- Release our end part's connection point we found the bad parts down.
                portalEndPart.nonConnectedInternalSurfacePositionStrings = {[portalEndPart.frontInternalSurfacePositionString] = portalEndPart.frontInternalSurfacePositionString}
                portalEndPart.nonConnectedExternalSurfacePositionStrings = {[portalEndPart.frontExternalCheckSurfacePositionString] = portalEndPart.frontExternalCheckSurfacePositionString}

                -- Remove the offending parts walked over from this portal before its marked as complete. The parts themselves will be tiedup up in the calling function.
                for _, partWalked in pairs(frontPartsWalked) do
                    portal.portalSegments[partWalked.id] = nil
                    portalPartsDisowned[partWalked.id] = partWalked
                end
            end

            -- If the other end was found then we've gone the good direction, so repeat in the rear to find the bad parts
            if frontOtherEndFound then
                -- Walk down the connected portal part in the rear direction until we hit the other portal end or have walked the full line.
                local rearConnectedPortalPartSurfacePositionObject = global.portals.portalPartInternalConnectionSurfacePositionStrings[portalEndPart.rearExternalCheckSurfacePositionString] -- Is always found as otherwise this would be a non connected point.
                local _, rearPartsWalked = Portal.WalkConnectedPortalParts(rearConnectedPortalPartSurfacePositionObject.portalPart, portalEndPart.rearExternalCheckSurfacePositionString, targetPortalEnd)

                -- Release our end part's connection point we found the bad parts down.
                portalEndPart.nonConnectedInternalSurfacePositionStrings = {[portalEndPart.rearInternalSurfacePositionString] = portalEndPart.rearInternalSurfacePositionString}
                portalEndPart.nonConnectedExternalSurfacePositionStrings = {[portalEndPart.rearExternalCheckSurfacePositionString] = portalEndPart.rearExternalCheckSurfacePositionString}

                -- Remove the offending parts walked over from this portal before its marked as complete. The parts themselves will be tiedup up in the calling function.
                for _, partWalked in pairs(rearPartsWalked) do
                    portal.portalSegments[partWalked.id] = nil
                    portalPartsDisowned[partWalked.id] = partWalked
                end
            end
        end
    end

    return portalPartsDisowned
end

--- Walks down a line of connected portal parts from a starting part in a single direction, until either a specific portal part is reached or the end of the line is reached. Returns an array of all the portal parts it went through as well as if it found the specific part.
---@param initialPortalPart PortalPart @ The portal part to start the checking at.
---@param internalSurfacePositionString SurfacePositionString @ The direction to enter the initialPortalPart from and its checks away from this.
---@param targetPortalPart PortalPart @ Stop if this portal part is reached.
---@return boolean targetPortalPartFound
---@return PortalPart[] portalPartsSteppedThrough
Portal.WalkConnectedPortalParts = function(initialPortalPart, internalSurfacePositionString, targetPortalPart)
    -- This is a bit crude, but can be reviewed if UPS impactful. Would require more neighbour tracking at all times to replace the lookups.
    local thisPortalPart, thisInternalSurfacePositionString = initialPortalPart, internalSurfacePositionString
    local endtargetPortalPartFound, portalPartsSteppedThrough = nil, {initialPortalPart}

    -- Recursively walk through the connected parts in this direction.
    while endtargetPortalPartFound == nil do
        -- Find the next surface position string to check for.
        local nextExternalSurfacePosition
        if thisPortalPart.frontInternalSurfacePositionString == thisInternalSurfacePositionString then
            nextExternalSurfacePosition = thisPortalPart.rearExternalCheckSurfacePositionString
        else
            nextExternalSurfacePosition = thisPortalPart.frontExternalCheckSurfacePositionString
        end

        -- Get the next object if part of this tunnel
        local nextPortalPartSurfacePositionObject = global.portals.portalPartInternalConnectionSurfacePositionStrings[nextExternalSurfacePosition]
        if nextPortalPartSurfacePositionObject == nil then
            -- No part found so reached the end of the line.
            endtargetPortalPartFound = false
        else
            -- Part found so inspect it.
            local nextPortalPart = nextPortalPartSurfacePositionObject.portalPart
            if nextPortalPart.portal.id ~= thisPortalPart.portal.id then
                -- Part found isn't the same portal, so reached the end of the line.
                endtargetPortalPartFound = false
            else
                -- Part found is the same portal.
                table.insert(portalPartsSteppedThrough, nextPortalPart)
                if nextPortalPart.id == targetPortalPart.id then
                    -- Found the target part, so stop.
                    endtargetPortalPartFound = true
                else
                    -- Not the part we are looking for, so setup variables for another loop.
                    thisPortalPart = nextPortalPart
                    thisInternalSurfacePositionString = nextExternalSurfacePosition -- old part's external is new part's internal
                end
            end
        end
    end

    return endtargetPortalPartFound, portalPartsSteppedThrough
end

-- The portal is found to be complete so do the approperiate processing.
---@param portal Portal
Portal.PortalComplete = function(portal)
    portal.isComplete = true
    portal.portalTunneExternalConnectionSurfacePositionStrings = {}

    -- Work out where a tunnel could connect to the portal based on the unconnected sides of the End Portal.
    for _, endPortalPart in pairs(portal.portalEnds) do
        local undergroundInternalConnectionSurfacePositionString = next(endPortalPart.nonConnectedInternalSurfacePositionStrings)
        global.portals.portalTunnelInternalConnectionSurfacePositionStrings[undergroundInternalConnectionSurfacePositionString] = {
            id = undergroundInternalConnectionSurfacePositionString,
            portal = portal,
            endPortalPart = endPortalPart
        }
        local undergroundExternalConnectionSurfacePositionString = next(endPortalPart.nonConnectedExternalSurfacePositionStrings)
        portal.portalTunneExternalConnectionSurfacePositionStrings[undergroundExternalConnectionSurfacePositionString] = {
            id = undergroundExternalConnectionSurfacePositionString,
            portal = portal,
            endPortalPart = endPortalPart
        }
    end

    -- Work out and cache which side of each end portal is the inside of this portal. This is the end part's orientation as part of the wider portal from the inside of the portal heading outside.
    for _, endPortalPart in pairs(portal.portalEnds) do
        -- The front internal is in the orientation of this entity, the rear is in its backwards orientation.
        -- Comparing the non connected internal position to the front and back we can work out the parts portal facing orientation.
        local portalFacingOrientation
        if next(endPortalPart.nonConnectedInternalSurfacePositionStrings) == endPortalPart.frontInternalSurfacePositionString then
            portalFacingOrientation = endPortalPart.entity_orientation
        else
            portalFacingOrientation = Utils.LoopFloatValueWithinRangeMaxExclusive(endPortalPart.entity_orientation + 0.5, 0, 1)
        end
        endPortalPart.portalFacingOrientation = portalFacingOrientation
    end

    -- Add the graphics with closed ends to the portal end.
    for _, endPortalPart in pairs(portal.portalEnds) do
        table.insert(
            endPortalPart.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-closed_end-0_" .. tostring(endPortalPart.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerOverTrain,
                target = endPortalPart.entity_position,
                surface = endPortalPart.surface
            }
        )
        table.insert(
            endPortalPart.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-closed_end-shadow-0_" .. tostring(endPortalPart.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerOverTrain,
                target = endPortalPart.entity_position,
                surface = endPortalPart.surface
            }
        )
    end

    -- Add the portal segment's graphics.
    for _, portalSegment in pairs(portal.portalSegments) do
        local segmentPortalTypeData = portalSegment.typeData ---@type SegmentPortalTypeData
        if segmentPortalTypeData.segmentShape == SegmentShape.straight then
            table.insert(
                portalSegment.graphicRenderIds,
                rendering.draw_sprite {
                    sprite = "railway_tunnel-portal_graphics-portal_complete-middle-0_" .. tostring(portalSegment.entity_orientation * 100),
                    render_layer = global.portalGraphicsLayerOverTrain,
                    target = portalSegment.entity_position,
                    surface = portalSegment.surface
                }
            )
            table.insert(
                portalSegment.graphicRenderIds,
                rendering.draw_sprite {
                    sprite = "railway_tunnel-portal_graphics-portal_complete-middle-shadow-0_" .. tostring(portalSegment.entity_orientation * 100),
                    render_layer = global.portalGraphicsLayerOverTrain,
                    target = portalSegment.entity_position,
                    surface = portalSegment.surface
                }
            )
        else
            error("unsupported segment shape: " .. segmentPortalTypeData.segmentShape)
        end
    end

    -- Update any open GUIs on this portal as its state has now changed.
    for _, portalPart in pairs(portal.portalParts) do
        for playerIndex in pairs(portalPart.guiOpenedByPlayers) do
            MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged(portalPart, playerIndex, false)
        end
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
                return -- Only need to find a valid tunnel once, no point checking after this.
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
        local entryOrientation = entryDirection / 8
        local reverseEntryOrientation = Utils.LoopFloatValueWithinRangeMaxExclusive(entryOrientation + 0.5, 0, 1)
        local surface, force = portal.surface, portal.force

        Portal.BuildRailForPortalsParts(portal)

        -- Add the signals at the entry part to the tunnel.
        local entrySignalInEntityPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 1.5, y = EntryEndPortalSetup.entrySignalsDistance}, entryPortalEnd.entity_position)
        ---@type LuaEntity
        local entrySignalInEntity =
            surface.create_entity {
            name = "railway_tunnel-portal_entry_signal",
            position = entrySignalInEntityPosition,
            force = force,
            direction = reverseEntryDirection
        }
        local entrySignalOutEntityPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = -1.5, y = EntryEndPortalSetup.entrySignalsDistance}, entryPortalEnd.entity_position)
        ---@type LuaEntity
        local entrySignalOutEntity =
            surface.create_entity {
            name = "railway_tunnel-portal_entry_signal",
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

        -- Cache the portalEntryPosition.
        portal.portalEntryPointPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = EntryEndPortalSetup.trackEntryPointFromCenter}, entryPortalEnd.entity_position)

        -- Cache the objects details for later use.
        portal.leavingTrainFrontPosition = Utils.RotateOffsetAroundPosition(entryOrientation, {x = 0, y = EntryEndPortalSetup.leavingTrainFrontPosition}, entryPortalEnd.entity_position)
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

        -- Remove the entry end's old closed graphics and add new open ones.
        for _, oldGraphicRenderId in pairs(portal.entryPortalEnd.graphicRenderIds) do
            rendering.destroy(oldGraphicRenderId)
        end
        portal.entryPortalEnd.graphicRenderIds = {}
        table.insert(
            portal.entryPortalEnd.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-open_end-near-0_" .. tostring(portal.entryPortalEnd.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerOverTrain,
                target = portal.entryPortalEnd.entity_position,
                surface = portal.entryPortalEnd.surface
            }
        )
        table.insert(
            portal.entryPortalEnd.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-open_end-far-0_" .. tostring(portal.entryPortalEnd.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerUnderTrain,
                target = portal.entryPortalEnd.entity_position,
                surface = portal.entryPortalEnd.surface
            }
        )
        table.insert(
            portal.entryPortalEnd.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-near-0_" .. tostring(portal.entryPortalEnd.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerOverTrain,
                target = portal.entryPortalEnd.entity_position,
                surface = portal.entryPortalEnd.surface
            }
        )
        table.insert(
            portal.entryPortalEnd.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-open_end-shadow-far-0_" .. tostring(portal.entryPortalEnd.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerUnderTrain,
                target = portal.entryPortalEnd.entity_position,
                surface = portal.entryPortalEnd.surface
            }
        )
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
    ---@param entityNameOverride? string|null @ If set this entity name is placed rather than the one defined in the tracksPositionOffset argument.
    local PlaceRail = function(portalPart, tracksPositionOffset, entityNameOverride)
        local railPos = Utils.RotateOffsetAroundPosition(portalPart.entity_orientation, tracksPositionOffset.positionOffset, portalPart.entity_position)
        local placedRail = portal.surface.create_entity {name = entityNameOverride or tracksPositionOffset.trackEntityName, position = railPos, force = portal.force, direction = Utils.RotateDirectionByDirection(tracksPositionOffset.baseDirection, defines.direction.north, portalPart.entity_direction)}
        placedRail.destructible = false
        portal.portalRailEntities[placedRail.unit_number] = placedRail
    end

    --Will populate during the internal function.
    portal.portalRailEntities = {}

    -- Force the entry portal to have on-map rails.
    for _, tracksPositionOffset in pairs(portal.entryPortalEnd.typeData.tracksPositionOffset) do
        PlaceRail(portal.entryPortalEnd, tracksPositionOffset, "railway_tunnel-portal_rail-on_map")
    end

    -- Loop over the remaining portal parts and add their "underground" rails.
    for _, tracksPositionOffset in pairs(portal.blockedPortalEnd.typeData.tracksPositionOffset) do
        PlaceRail(portal.blockedPortalEnd, tracksPositionOffset)
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
        Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, false, false)
        Portal.AddTransitionUsageDetectionEntityToPortal(portal)
    end
end

-- If the built entity was a ghost of an underground segment then check it is on the rail grid.
---@param event on_built_entity|on_robot_built_entity|script_raised_built
---@param createdEntity LuaEntity
Portal.OnBuiltEntityGhost = function(event, createdEntity)
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
---@param minedEntity LuaEntity
Portal.OnPreMinedEntity = function(event, minedEntity)
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

-- Places the replacement portal part entity and destroys the old entity (so it can't be mined and get the item). Then updates the existing object with the new entity, so no other objects require updating.
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
        -- No need to update the GUI opened lists for anything other than the removedPart as the tunnel and portal object will be destroyed and re-created as approperiate. This process will trigger their GUIs to update.

        -- Handle the tunnel if there is one before the portal itself. As the remove tunnel function calls back to its 2 portals and handles/removes portal fields requiring a tunnel.
        if portal.tunnel ~= nil then
            MOD.Interfaces.Tunnel.RemoveTunnel(portal.tunnel, killForce, killerCauseEntity)
        end

        -- Handle the portal object.

        -- Remove the portal's graphic parts. When the portal parts are remade in to a portal they will gain their graphics back if approperiate.
        for _, portalPart in pairs(portal.portalParts) do
            for _, graphicRenderId in pairs(portalPart.graphicRenderIds) do
                rendering.destroy(graphicRenderId)
            end
            portalPart.graphicRenderId = {}
        end

        -- Remove the portal's global objects. The portal object itself will be garbage collected as by the end of this function nothing will reference it.
        for _, endPortalPart in pairs(portal.portalEnds) do
            local nonConnectedInternalSurfacePosition = next(endPortalPart.nonConnectedInternalSurfacePositionStrings)
            if nonConnectedInternalSurfacePosition ~= nil then
                global.portals.portalTunnelInternalConnectionSurfacePositionStrings[nonConnectedInternalSurfacePosition] = nil
            end
        end
        global.portals.portals[portal.id] = nil

        -- Remove this portal part from the portals fields before we re-process the other portals parts.
        portal.portalEnds[removedPortalPart.id] = nil
        portal.portalSegments[removedPortalPart.id] = nil
        portal.portalParts[removedPortalPart.id] = nil

        -- As we don't know the portal's parts makeup we will just disolve the portal and recreate new one(s) by checking each remaining portal part. This is a bit crude, but can be reviewed if UPS impactful.
        Portal.RecalculatePortalPartsParentPortal(portal.portalParts)
    end

    -- If this part had an open GUI then alert the GUI class that there's been a change.
    for playerIndex in pairs(removedPortalPart.guiOpenedByPlayers) do
        MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged(removedPortalPart, playerIndex, true)
    end
end

--- Make a list of portal parts forget their portal and connections. Then recalculate the portal and connections again.
---
--- Useful for when breaking a portal up or removing parts from a portal.
---@param portalParts table<UnitNumber, PortalPart>
Portal.RecalculatePortalPartsParentPortal = function(portalParts)
    -- Make each portal part forget its parent so they are all ready to re-merge in to new portals later.
    for _, portalPart in pairs(portalParts) do
        portalPart.portal = nil

        -- Populate these back to their full lists as the entity may be connected prematurely when all the portal parts are re-scanned en-mass.
        portalPart.nonConnectedInternalSurfacePositionStrings = {[portalPart.frontInternalSurfacePositionString] = portalPart.frontInternalSurfacePositionString, [portalPart.rearInternalSurfacePositionString] = portalPart.rearInternalSurfacePositionString}
        portalPart.nonConnectedExternalSurfacePositionStrings = {[portalPart.frontExternalCheckSurfacePositionString] = portalPart.frontExternalCheckSurfacePositionString, [portalPart.rearExternalCheckSurfacePositionString] = portalPart.rearExternalCheckSurfacePositionString}

        if portalPart.typeData.partType == PortalPartType.portalEnd then
            local endPortalPart = portalPart ---@type PortalEnd
            endPortalPart.connectedToUnderground = false
            endPortalPart.endPortalType = nil
            endPortalPart.portalFacingOrientation = nil
        end
    end

    -- Loop over each portal part and add them back in to whatever portals they reform in to.
    for _, portalPart in pairs(portalParts) do
        Portal.UpdatePortalsForNewPortalPart(portalPart)
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

        -- Remove the entry end's old open graphics and add a closed one back.
        for _, oldGraphicRenderId in pairs(portal.entryPortalEnd.graphicRenderIds) do
            rendering.destroy(oldGraphicRenderId)
        end
        portal.entryPortalEnd.graphicRenderIds = {}
        table.insert(
            portal.entryPortalEnd.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-closed_end-0_" .. tostring(portal.entryPortalEnd.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerOverTrain,
                target = portal.entryPortalEnd.entity_position,
                surface = portal.entryPortalEnd.surface
            }
        )
        table.insert(
            portal.entryPortalEnd.graphicRenderIds,
            rendering.draw_sprite {
                sprite = "railway_tunnel-portal_graphics-portal_complete-closed_end-shadow-0_" .. tostring(portal.entryPortalEnd.portalFacingOrientation * 100),
                render_layer = global.portalGraphicsLayerOverTrain,
                target = portal.entryPortalEnd.entity_position,
                surface = portal.entryPortalEnd.surface
            }
        )

        -- Remove the tunnel related entities of this portal.
        for _, otherEntity in pairs(portal.portalOtherEntities) do
            if otherEntity.valid then
                otherEntity.destroy()
            end
        end
        portal.portalOtherEntities = nil
        for _, railEntity in pairs(portal.portalRailEntities) do
            if railEntity.valid then
                Utils.DestroyCarriagesOnRailEntity(railEntity, killForce, killerCauseEntity, portal.surface)
                if not railEntity.destroy() then
                    error("portal.portalRailEntities rail failed to be removed")
                end
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

        -- Clear the end part's state that relates to the tunnel.
        portal.entryPortalEnd.endPortalType = nil
        portal.entryPortalEnd = nil
        portal.blockedPortalEnd.endPortalType = nil
        portal.blockedPortalEnd = nil

        -- Clear the portal's tunnel related state data.
        portal.portalEntryPointPosition = nil
        portal.dummyLocomotivePosition = nil
        portal.entryDirection = nil
        portal.leavingDirection = nil

        -- If any part of this portal had an open GUI then alert the GUI class that there's been a change.
        for _, portalPart in pairs(portal.guiOpenedByParts) do
            for playerIndex in pairs(portalPart.guiOpenedByPlayers) do
                MOD.Interfaces.PortalTunnelGui.On_PortalPartChanged(portalPart, playerIndex, false)
            end
        end
    end
end

-- Triggered when a monitored entity type is killed.
---@param event on_entity_died|script_raised_destroy
---@param diedEntity LuaEntity
Portal.OnDiedEntity = function(event, diedEntity)
    -- Check its a previously successfully built entity. Just incase something destroys the entity before its made a global entry.
    local diedPortalPart = global.portals.portalPartEntityIdToPortalPart[diedEntity.unit_number]
    if diedPortalPart == nil then
        return
    end

    Portal.EntityRemoved(diedPortalPart, event.force, event.cause)
end

-- Occurs when a train tries to pass through the border of a portal, when entering and exiting.
---@param event on_entity_died|script_raised_destroy
---@param diedEntity LuaEntity
Portal.OnDiedEntityPortalEntryTrainDetector = function(event, diedEntity)
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

    local carriageEnteringPortalTrack = event.cause
    if carriageEnteringPortalTrack == nil then
        -- As there's no cause this should only occur when a script removes the entity. Try to return the detection entity and if the portal is being removed that will handle all scenarios.
        Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, true, false)
        return
    end
    local train = carriageEnteringPortalTrack.train
    local train_id = train.id

    -- Check and handle if train can't fit in the tunnel's length.
    if not MOD.Interfaces.Tunnel.CanTrainFitInTunnel(train, train_id, portal.tunnel) then
        -- Note that we call this on a leaving train when we don't need to, but would be messy code to delay this check in to all of the branches.
        TunnelShared.StopTrainFromEnteringTunnel(train, train_id, portal.entryPortalEnd.entity, event.tick, {"message.railway_tunnel-train_too_long"})
        Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, false, true)
        return
    end

    -- Is a scheduled train following its schedule so check if its already reserved a tunnel.
    if not train.manual_mode and train.state ~= defines.train_state.no_schedule then
        -- Check tunnels that this train is leaving. Check first as a train leaving a tunnel should be handled before it checks if its entering a different tunnel.
        local leavingManagedTrain = global.trainManager.leavingTrainIdToManagedTrain[train_id]
        if leavingManagedTrain ~= nil then
            -- This train is leaving a tunnel somewhere, so check if its this tunnel or another one and handle.

            if leavingManagedTrain.tunnel.id == portal.tunnel.id then
                -- The train is leaving this tunnel.

                -- Train has been leaving the tunnel and is now trying to pass out of the tunnel's exit portal track. This is healthy activity.
                return
            else
                -- The train is leaving another tunnel.
                -- This isn't a leaving train state we want to react to, and we don't want to stop further processing (no return).
            end
        end

        -- Check tunnels that this train is actively using (approaching, traversing).
        local activelyUsingManagedTrain = global.trainManager.activelyUsingTrainIdToManagedTrain[train_id]
        if activelyUsingManagedTrain ~= nil then
            -- This train is using a tunnel somewhere, so check if its this tunnel or another one and handle.

            if activelyUsingManagedTrain.tunnel.id == portal.tunnel.id then
                -- The train is using this tunnel.

                if activelyUsingManagedTrain.tunnelUsageState == TunnelUsageState.approaching then
                    -- Train had reserved the tunnel via signals at distance and is now trying to pass in to the tunnels entry portal track. This is healthy activity.
                    MOD.Interfaces.TrainManager.RegisterTrainOnPortalTrack(train, portal, activelyUsingManagedTrain)
                    return
                else
                    error("Train is crossing a tunnel portal's transition threshold while registered as actively using this tunnel, but not in the approaching state.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. activelyUsingManagedTrain.tunnel.id)
                    return
                end
            else
                -- The train is using another tunnel.

                -- If the train was actively using another tunnel and has just reversed. If it had reached the portal track (regardless of approaching or not) it will have been downgraded on that tunnel to just onPortalTrack.
                if activelyUsingManagedTrain.tunnelUsageState == TunnelUsageState.portalTrack then
                    -- The train is flipping its active direction and current tunnel usage.
                    MOD.Interfaces.TrainManager.EnteringTrainReversedIntoOtherTunnel(leavingManagedTrain, activelyUsingManagedTrain, train, portal)
                    return
                end

                -- All other cases of this scenario are an error.
                error("Train has entered one portal in automatic mode, while it is has an active usage registered for another tunnel.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. activelyUsingManagedTrain.tunnel.id)
                return
            end
        end

        -- This train isn't using any tunnel.
        if portal.tunnel.managedTrain == nil then
            -- Portal's tunnel isn't reserved so this train can grab the portal.
            MOD.Interfaces.TrainManager.RegisterTrainOnPortalTrack(train, portal, nil)
            return
        else
            -- Portal's tunnel is already being used, so stop this train entering. Stop the new train here and restore the entering train detection entity.
            -- This can be caused by the known non ideal behaviour regarding 2 trains simultaniously appraoching a tunnel from opposite ends at slow speed.

            TunnelShared.StopTrainFromEnteringTunnel(train, train_id, train.carriages[1], event.tick, {"message.railway_tunnel-tunnel_in_use"})
            Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, false, true)
            return
        end
    end

    -- Train has a player in it so we assume its being actively driven. Can only detect if player input is being entered right now, not the players intention.
    if #train.passengers ~= 0 then
        -- Future support for player driven train will expand this logic as needed. This state shouldn't be reachable at present.
        error("suspected player driving train")
        return
    end

    -- Train is coasting so stop it and put the detection entity back.
    train.speed = 0
    Portal.AddEnteringTrainUsageDetectionEntityToPortal(portal, false, true)
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

--- Will try and place the entering train detection entity now and if not possible will keep on trying each tick until either successful or a tunnel state setting stops the attempts.
---
--- Is safe to call if the entity already exists as will just abort (initally or when in per tick loop).
---@param portal Portal
---@param retry boolean @ If to retry next tick should it not be placable.
---@param justplaceIt boolean @ If true the detector is built without a check first. Some weird edge cases whre the train has rammed the detector and stopped right next to it will blocks its build check, but it will work fine once just placed.
---@return LuaEntity @ The enteringTrainUsageDetectorEntity if successfully placed.
Portal.AddEnteringTrainUsageDetectionEntityToPortal = function(portal, retry, justplaceIt)
    -- The try function has all the protection against incorrect calling.
    return Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled(nil, portal, retry, justplaceIt)
end

---@param event UtilityScheduledEvent_CallbackObject
---@param portal Portal
---@param retry boolean @ If to retry next tick should it not be placable.
---@param justplaceIt boolean @ If true the detector is built without a check first. Some weird edge cases whre the train has rammed the detector and stopped right next to it will blocks its build check, but it will work fine once just placed.
---@return LuaEntity @ The enteringTrainUsageDetectorEntity if successfully placed on first attempt. Retries in later ticks will not return the entity to the calling function.
Portal.TryCreateEnteringTrainUsageDetectionEntityAtPosition_Scheduled = function(event, portal, retry, justplaceIt)
    local eventData
    if event ~= nil then
        eventData = event.data
        portal, retry, justplaceIt = eventData.portal, eventData.retry, eventData.justplaceIt
    end
    if portal.tunnel == nil or not portal.isComplete or portal.enteringTrainUsageDetectorEntity ~= nil then
        -- The portal has been removed, so we shouldn't add the detection entity back. Or another task has added the dector back and so we can stop.
        return
    end

    -- When the train is leaving the left train will initially be within the collision box of where we want to place this. So try to place it and if it fails retry a moment later. In tests 2/3 of the time it was created successfully.
    -- The entity can be created on top of a train and if that trains moving it will instantly be killed, so have to explicitly do a build check first in some cases.
    -- In cases where the detector was killed by a train that is then immediately stopped the build check will fail, but it can be placed back there and we need to force it with "justPlaceIt".
    local enteringTrainUsageDetectorEntity
    if justplaceIt or portal.surface.can_place_entity {name = "railway_tunnel-portal_entry_train_detector_1x1", force = global.force.tunnelForce, position = portal.enteringTrainUsageDetectorPosition} then
        enteringTrainUsageDetectorEntity =
            portal.surface.create_entity {
            name = "railway_tunnel-portal_entry_train_detector_1x1",
            force = global.force.tunnelForce,
            position = portal.enteringTrainUsageDetectorPosition
        }
    end
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
            postbackData = {portal = portal, retry = retry, justplaceIt = justplaceIt}
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
---@param diedEntity LuaEntity
Portal.OnDiedEntityPortalTransitionTrainDetector = function(event, diedEntity)
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

    local carriageAtTransitionOfPortalTrack = event.cause
    if carriageAtTransitionOfPortalTrack == nil then
        -- As there's no cause this should only occur when a script removes the entity. Try to return the detection entity and if the portal is being removed that will handle all scenarios.
        Portal.AddTransitionUsageDetectionEntityToPortal(portal)
        return
    end
    local train = carriageAtTransitionOfPortalTrack.train
    local train_id = train.id

    -- Check and handle if train can't fit in the tunnel's length.
    if not MOD.Interfaces.Tunnel.CanTrainFitInTunnel(train, train_id, portal.tunnel) then
        TunnelShared.StopTrainFromEnteringTunnel(train, train_id, portal.blockedPortalEnd.entity, event.tick, {"message.railway_tunnel-train_too_long"})
        Portal.AddTransitionUsageDetectionEntityToPortal(portal)
        return
    end

    -- Is a scheduled train following its schedule so check if its already reserved the tunnel.
    if not train.manual_mode and train.state ~= defines.train_state.no_schedule then
        -- Presently we don't want to react to any scenario in relation to if the train is leaving at present either this tunnel or another.
        -- So no need to check for a leaving train glboal at all. situation where

        -- Check tunnels that this train is actively using (approaching, traversing).
        local activelyUsingManagedTrain = global.trainManager.activelyUsingTrainIdToManagedTrain[train_id]
        if activelyUsingManagedTrain ~= nil then
            -- This train has reserved a tunnel somewhere, so check if its this or another one and handle.

            if activelyUsingManagedTrain.tunnel.id == portal.tunnel.id then
                -- The train has reserved this tunnel.

                if activelyUsingManagedTrain.tunnelUsageState == TunnelUsageState.approaching then
                    -- Train had reserved the tunnel via signals at distance and is now ready to fully enter the tunnel.
                    MOD.Interfaces.TrainManager.TrainEnterTunnel(activelyUsingManagedTrain, event.tick)
                    Portal.AddTransitionUsageDetectionEntityToPortal(portal)
                    return
                else
                    error("Train is crossing a tunnel portal's transition threshold while registered as actively using this tunnel, but not in the approaching state.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. activelyUsingManagedTrain.tunnel.id)
                    return
                end
            else
                error("Train has reached the transition point of one portal, while it is registered as actively using another portal.\ntrainId: " .. train_id .. "\nenteredPortalId: " .. portal.id .. "\nreservedTunnelId: " .. activelyUsingManagedTrain.tunnel.id)
                return
            end
        end

        -- This train hasn't reserved any tunnel.
        if portal.tunnel.managedTrain == nil then
            -- Portal's tunnel isn't reserved so this train can just use the tunnel to commit now. But is none standard as the train didn't pass through the entity detector.
            if global.debugRelease then
                error("unexpected train entering tunnel without having passed through entry detector")
            end
            TunnelShared.PrintWarningAndReportToModAuthor("Train entering tunnel without having passed through entry detector. Mod will try and continue.")
            MOD.Interfaces.TrainManager.TrainEnterTunnel(train, event.tick)
            return
        else
            -- Portal's tunnel is already being used, so stop this train entering. Stop the new train here and restore the transition train detection entity.
            -- This can be caused by the known non ideal behaviour regarding 2 trains simultaniously appraoching a tunnel from opposite ends at slow speed.

            TunnelShared.StopTrainFromEnteringTunnel(train, train_id, train.carriages[1], event.tick, {"message.railway_tunnel-tunnel_in_use"})
            Portal.AddTransitionUsageDetectionEntityToPortal(portal)
            return
        end
    end

    -- Train has a player in it so we assume its being actively driven. Can only detect if player input is being entered right now, not the players intention.
    if #train.passengers ~= 0 then
        -- Future support for player driven train will expand this logic as needed. This state shouldn't be reachable at present.
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

    -- The entity will fail a build check where a train carriage was desotryed in the same tick. But it will create on top of where something is still. So as the usage case for returning this detector is simple it can always be put back, no checking first required. So this detector must be different logic to the entering detector.
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

--- Mark this portal part as having a GUI opened on it.
---@param portalPart PortalPart
---@param playerIndex Id
---@param player LuaPlayer
Portal.GuiOpenedOnPortalPart = function(portalPart, playerIndex, player)
    portalPart.guiOpenedByPlayers[playerIndex] = player
    if portalPart.portal ~= nil then
        portalPart.portal.guiOpenedByParts[portalPart.id] = portalPart
        if portalPart.portal.tunnel ~= nil then
            portalPart.portal.tunnel.guiOpenedByPlayers[playerIndex] = player
        end
    end
end

--- Mark this portal part as having a GUI closed on it.
---@param portalPart PortalPart
---@param playerIndex Id
Portal.GuiClosedOnPortalPart = function(portalPart, playerIndex)
    portalPart.guiOpenedByPlayers[playerIndex] = nil
    if next(portalPart.guiOpenedByPlayers) == nil then
        -- No other players have this part open so inform the portal
        if portalPart.portal ~= nil then
            portalPart.portal.guiOpenedByParts[portalPart.id] = nil
            if portalPart.portal.tunnel ~= nil then
                portalPart.portal.tunnel.guiOpenedByPlayers[playerIndex] = nil
            end
        end
    end
end

return Portal
