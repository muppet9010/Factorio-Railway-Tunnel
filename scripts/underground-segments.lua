local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelShared = require("scripts/tunnel-shared")
local Common = require("scripts/common")
local UndergroundSegmentEntityNames = Common.UndergroundSegmentEntityNames
local UndergroundSegments = {}

---@class Underground
---@field id uint @unique id of the underground object.
---@field segments table<UnitNumber, UndergroundSegment> @segments in the underground. Key'd by the portal end entity unit_number (id).
---@field tilesLength int @how many tiles this underground is long.
---@field force LuaForce @the force this underground object belongs to.
---@field surface LuaSurface @the surface this underground object is on.
---@field undergroundEndSegments UndergroundEndSegmentObject[] @objects with details of the segments at the 2 ends of the underground. Updated every time the underground's segments change.
---@field tunnel Tunnel @ref to tunnel object if this underground is part of one. Only established once this underground is part of a valid tunnel.

---@class UndergroundSegment
---@field id UnitNumber @unit_number of the placed segment entity.
---@field entity LuaEntity
---@field entity_name string @cache of the segment's entity's name.
---@field entity_position Position @cache of the entity's position.
---@field entity_direction defines.direction @cache of the entity's direction.
---@field entity_orientation RealOrientation @cache of the entity's orientation.
---@field frontPosition Position @used as base to look for other tunnel segments' segmentSurfacePositions global object entries. These are present on each connecting end of the segment 0.5 tile in from its connecting edge center. This is to handle various shapes.
---@field rearPosition Position  @used as base to look for other tunnel segments' segmentSurfacePositions global object entries. These are present on each connecting end of the segment 0.5 tile in from its connecting edge center. This is to handle various shapes.
---@field surface LuaSurface @the surface this segment object is on.
---@field surface_index uint @cached index of the surface this segment is on.
---@field force LuaForce @the force this segment object belongs to.
---@field underground Underground @ref to the parent underground object.
---@field tunnelRailEntities table<UnitNumber, LuaEntity> @the invisible rail entities within the tunnel segment that form part of the larger tunnel.
---@field signalEntities table<UnitNumber, LuaEntity> @the hidden signal entities within the tunnel segment.
---@field crossingRailEntities table<UnitNumber, LuaEntity> @the rail entities that cross the tunnel segment. Table only exists for entity type of "underground_segment-rail_crossing".
---@field surfacePositionString SurfacePositionString @used for Fast Replacement to back match to segmentSurfacePositions global object.
---@field beingFastReplacedTick uint @the tick the segment was marked as being fast replaced or nil.
---@field trainBlockerEntity LuaEntity @the "railway_tunnel-train_blocker_2x2" entity of this tunnel segment if it has one currently.
---@field topLayerEntity LuaEntity @the top layer graphical entity that is showings its picture and hiding the main entities once placed.
---@field tilesLength int @how many tiles this segment is long.
---@field typeData UndergroundSegmentTypeData @ref to generic data about this type of segment.
---@field nonConnectedSurfacePositions table<SurfacePositionString, SurfacePositionString> @a table of this segments non connected points.

---@class UndergroundEndSegmentObject @details of a segment at the end of an underground.
---@field segment UndergroundSegment
---@field connectableSurfacePosition SurfacePositionString @where a portal could have its connection position and join to this segment's external entity border connection points.

---@class SegmentSurfacePosition
---@field id SurfacePositionString
---@field segment UndergroundSegment

---@alias FastReplaceChange "'downgrade'"|"'upgrade'"|"'same'"

---@class UndergroundSegmentTypeData
---@field name string
---@field segmentShape UndergroundSegmentShape
---@field topLayerEntityName string @the entity to place when the tunnel is complete to show the desired completed graphics layer.
---@field placeCrossingRails boolean @if this segment type has above ground crossing rails or not.
---@field tilesLength int @how many tiles this underground is long.
---@field undergroundTracksPositionOffset PortalPartTrackPositionOffset[] @the type of underground track and its position offset from the center of the part when in a 0 orientation.

---@class UndergroundSegmentShape @the shape of the segment part.
local SegmentShape = {
    straight = "straight", -- Short straight piece for horizontal and vertical.
    diagonal = "diagonal", -- Short diagonal piece.
    curveStart = "curveStart", -- The start of a curve, so between Straight and Diagonal.
    curveInner = "curveInner" -- The inner part of a curve that connects 2 curveStart's togeather to make a 90 degree corner.
}

---@class UndergroundSegmentTrackPositionOffset @type of track and its position offset from the center of the part when in a 0 orientation.
---@field trackEntityName string
---@field positionOffset Position
---@field baseDirection defines.direction

---@type UndergroundSegmentTypeData[]
local SegmentTypeData = {
    ["railway_tunnel-underground_segment-straight"] = {
        name = "railway_tunnel-underground_segment-straight",
        segmentShape = SegmentShape.straight,
        topLayerEntityName = "railway_tunnel-underground_segment-straight-top_layer",
        placeCrossingRails = false,
        tilesLength = 2,
        undergroundTracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            }
        }
    },
    ["railway_tunnel-underground_segment-straight-rail_crossing"] = {
        name = "railway_tunnel-underground_segment-straight-rail_crossing",
        segmentShape = SegmentShape.straight,
        topLayerEntityName = nil,
        placeCrossingRails = true,
        tilesLength = 2,
        undergroundTracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            }
        }
    }
}

UndergroundSegments.CreateGlobals = function()
    global.undergroundSegments = global.undergroundSegments or {}
    global.undergroundSegments.nextUndergroundId = global.tunnelPortals.nextUndergroundId or 1
    global.undergroundSegments.undergrounds = global.undergroundSegments.undergrounds or {}
    global.undergroundSegments.segments = global.undergroundSegments.segments or {} ---@type table<UnitNumber, UndergroundSegment>
    global.undergroundSegments.segmentSurfacePositions = global.undergroundSegments.segmentSurfacePositions or {} ---@type table<Id, SegmentSurfacePosition> @a lookup for underground segments by their position string. Saves searching for entities on the map via API.
    global.undergroundSegments.segmentConnectionSurfacePositions = global.undergroundSegments.segmentConnectionSurfacePositions or {} ---@type table<Id, SegmentSurfacePosition> @a lookup for positions that underground segment parts can connect to each other on. It is 0.5 tiles within the edge of their connection border. Saves searching for entities on the map via API.
end

UndergroundSegments.OnLoad = function()
    local segmentEntityNames_Filter = {}
    for _, name in pairs(UndergroundSegmentEntityNames) do
        table.insert(segmentEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "UndergroundSegments.OnBuiltEntity", UndergroundSegments.OnBuiltEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "UndergroundSegments.OnBuiltEntity", UndergroundSegments.OnBuiltEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "UndergroundSegments.OnBuiltEntity", UndergroundSegments.OnBuiltEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "UndergroundSegments.OnBuiltEntity", UndergroundSegments.OnBuiltEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "UndergroundSegments.OnPreMinedEntity", UndergroundSegments.OnPreMinedEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "UndergroundSegments.OnPreMinedEntity", UndergroundSegments.OnPreMinedEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_build, "UndergroundSegments.OnPreBuild", UndergroundSegments.OnPreBuild)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "UndergroundSegments.OnDiedEntity", UndergroundSegments.OnDiedEntity, segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "UndergroundSegments.OnDiedEntity", UndergroundSegments.OnDiedEntity, segmentEntityNames_Filter)

    local segmentEntityGhostNames_Filter = {}
    for _, name in pairs(UndergroundSegmentEntityNames) do
        table.insert(segmentEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "UndergroundSegments.OnBuiltEntityGhost", UndergroundSegments.OnBuiltEntityGhost, segmentEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "UndergroundSegments.OnBuiltEntityGhost", UndergroundSegments.OnBuiltEntityGhost, segmentEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "UndergroundSegments.OnBuiltEntityGhost", UndergroundSegments.OnBuiltEntityGhost, segmentEntityGhostNames_Filter)

    Interfaces.RegisterInterface("UndergroundSegments.On_PreTunnelCompleted", UndergroundSegments.On_PreTunnelCompleted)
    Interfaces.RegisterInterface("UndergroundSegments.On_TunnelRemoved", UndergroundSegments.On_TunnelRemoved)
    Interfaces.RegisterInterface("UndergroundSegments.CanAnUndergroundConnectAtPosition", UndergroundSegments.CanAnUndergroundConnectAtPosition)
    Interfaces.RegisterInterface("UndergroundSegments.DoesUndergroundSegmentConnectToAPortal", UndergroundSegments.DoesUndergroundSegmentConnectToAPortal)
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
UndergroundSegments.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid then
        return
    end
    local createdEntity_name = createdEntity.name
    if UndergroundSegmentEntityNames[createdEntity_name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    UndergroundSegments.UndergroundSegmentBuilt(createdEntity, placer, createdEntity_name)
end

---@param builtEntity LuaEntity
---@param placer EntityActioner
---@param builtEntity_name string
---@return boolean
UndergroundSegments.UndergroundSegmentBuilt = function(builtEntity, placer, builtEntity_name)
    -- Check the placement is on rail grid, if not then undo the placement and stop.
    if not TunnelShared.IsPlacementOnRailGrid(builtEntity) then
        TunnelShared.UndoInvalidTunnelPartPlacement(builtEntity, placer, true)
        return
    end

    local builtEntity_position, force, lastUser, builtEntity_direction, surface, builtEntity_orientation = builtEntity.position, builtEntity.force, builtEntity.last_user, builtEntity.direction, builtEntity.surface, builtEntity.orientation
    local segmentTypeData, surface_index = SegmentTypeData[builtEntity_name], surface.index
    local placeCrossingRails = segmentTypeData.placeCrossingRails
    local surfacePositionString = Utils.FormatSurfacePositionTableToString(surface_index, builtEntity_position)

    -- Check if this is a fast replacement or not.
    local fastReplacedSegmentByPosition = global.undergroundSegments.segmentSurfacePositions[surfacePositionString]
    ---@typelist UndergroundSegment, FastReplaceChange
    local fastReplacedSegment, fastReplaceChange
    if fastReplacedSegmentByPosition ~= nil then
        fastReplacedSegment = fastReplacedSegmentByPosition.segment
        if placeCrossingRails and fastReplacedSegment.crossingRailEntities == nil then
            -- Upgrade from non crossing rails to crossing rails.
            fastReplaceChange = "upgrade"
        elseif not placeCrossingRails and fastReplacedSegment.crossingRailEntities ~= nil then
            -- Downgrade from crossing rails to non crossing rails.
            fastReplaceChange = "downgrade"
        else
            -- Is a fast replace to the same type
            fastReplaceChange = "same"
        end
    end

    -- If its an attempt to downgrade then check crossing rails can be safely removed. If they can't undo the change and stop.
    if fastReplaceChange == "downgrade" then
        for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
            if not railCrossingTrackEntity.can_be_destroyed() then
                -- Put the old correct entity back and correct whats been done.
                TunnelShared.EntityErrorMessage(placer, "Can not fast replace crossing rail tunnel segment while train is on crossing track", surface, builtEntity_position)
                local oldId = fastReplacedSegment.id
                builtEntity.destroy()
                fastReplacedSegment.entity = surface.create_entity {name = "railway_tunnel-underground_segment-straight-rail_crossing", position = builtEntity_position, direction = builtEntity_direction, force = force, player = lastUser}
                local newId = fastReplacedSegment.entity.unit_number
                fastReplacedSegment.id = newId
                global.undergroundSegments.segments[newId] = fastReplacedSegment
                global.undergroundSegments.segments[oldId] = nil
                Utils.GetBuilderInventory(placer).remove({name = "railway_tunnel-underground_segment-straight-rail_crossing", count = 1})
                Utils.GetBuilderInventory(placer).insert({name = "railway_tunnel-underground_segment-straight", count = 1})
                return
            end
        end
    end

    ---@type UndergroundSegment
    local segment = {
        id = builtEntity.unit_number,
        entity = builtEntity,
        entity_name = builtEntity_name,
        entity_position = builtEntity_position,
        entity_direction = builtEntity_direction,
        entity_orientation = builtEntity_orientation,
        typeData = segmentTypeData,
        surface = surface,
        surface_index = surface_index,
        force = builtEntity.force,
        surfacePositionString = surfacePositionString,
        nonConnectedSurfacePositions = {}
    }

    -- Handle the caching of specific segment part type information and to their globals.
    if segmentTypeData.segmentShape == SegmentShape.straight then
        segment.frontPosition = Utils.ApplyOffsetToPosition(builtEntity_position, Utils.RotatePositionAround0(builtEntity_orientation, {x = 0, y = -0.5}))
        segment.rearPosition = Utils.ApplyOffsetToPosition(builtEntity_position, Utils.RotatePositionAround0(builtEntity_orientation, {x = 0, y = 0.5}))
    else
        error("unrecognised segmentTypeData.segmentShape: " .. segmentTypeData.segmentShape)
    end

    -- If it's a fast replace and there is a type change then remove the old bits first.
    -- TODO: the trainBlockerEntity doesn't need to be placed until the rails are added when the tunnel is complete. The crossing rails are needed before hand however.
    if fastReplaceChange == "upgrade" then
        fastReplacedSegment.trainBlockerEntity.destroy()
        fastReplacedSegment.trainBlockerEntity = nil
    elseif fastReplaceChange == "downgrade" then
        for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
            railCrossingTrackEntity.destroy()
        end
    end

    -- Handle the type specific bits.
    if fastReplaceChange ~= "same" then
        -- Non fast replacements and fast replacements of change type other than "same" will need the new type extras adding.
        if placeCrossingRails then
            -- OVERHAUL - move this to be type data driven and not hard coded.
            segment.crossingRailEntities = {}
            local crossignRailDirection, orientation = Utils.LoopDirectionValue(builtEntity_direction + 2), Utils.DirectionToOrientation(builtEntity_direction)
            for _, nextRailPos in pairs(
                {
                    Utils.ApplyOffsetToPosition(builtEntity_position, Utils.RotatePositionAround0(orientation, {x = -2, y = 0})),
                    builtEntity_position,
                    Utils.ApplyOffsetToPosition(builtEntity_position, Utils.RotatePositionAround0(orientation, {x = 2, y = 0}))
                }
            ) do
                local placedRail = surface.create_entity {name = "railway_tunnel-crossing_rail-on_map", position = nextRailPos, force = force, direction = crossignRailDirection}
                placedRail.destructible = false
                segment.crossingRailEntities[placedRail.unit_number] = placedRail
            end
        else
            segment.trainBlockerEntity = surface.create_entity {name = "railway_tunnel-train_blocker_2x2", position = builtEntity_position, force = force}
        end
    else
        -- Fast replacement's of the same type can just claim the old segments extras.
        if placeCrossingRails then
            segment.crossingRailEntities = fastReplacedSegment.crossingRailEntities
        else
            segment.trainBlockerEntity = fastReplacedSegment.trainBlockerEntity
        end
    end

    -- Register the new segment and its position for fast replace.
    global.undergroundSegments.segments[segment.id] = segment
    global.undergroundSegments.segmentSurfacePositions[segment.surfacePositionString] = {
        id = segment.surfacePositionString,
        segment = segment
    }

    -- Register the segments surfacePositionStrings for connection reverse lookup.
    local frontSurfacePositionString = Utils.FormatSurfacePositionTableToString(surface_index, segment.frontPosition)
    global.undergroundSegments.segmentConnectionSurfacePositions[frontSurfacePositionString] = {
        id = frontSurfacePositionString,
        segment = segment
    }
    local rearSurfacePositionString = Utils.FormatSurfacePositionTableToString(surface_index, segment.rearPosition)
    global.undergroundSegments.segmentConnectionSurfacePositions[rearSurfacePositionString] = {
        id = rearSurfacePositionString,
        segment = segment
    }

    -- Update other parts of the mod and handle any generic extras.
    if fastReplacedSegment ~= nil then
        -- Its a fast replacement.

        -- Claim the generic extras of the old segment,
        segment.tunnelRailEntities = fastReplacedSegment.tunnelRailEntities
        segment.signalEntities = fastReplacedSegment.signalEntities
        segment.underground = fastReplacedSegment.underground

        -- Handle the Underground object.
        local underground = fastReplacedSegment.underground
        if underground ~= nil then
            underground.segments[fastReplacedSegment.id] = nil
            underground.segments[segment.id] = segment
        end

        -- Handle anything that is only present if there is a parent tunnel.
        if segment.underground.tunnel ~= nil then
            -- Update the top layer entity if it needs changing due to change of entity type.
            if fastReplaceChange ~= "same" then
                -- Remove the old top layer.
                if fastReplacedSegment.topLayerEntity ~= nil and fastReplacedSegment.topLayerEntity.valid then
                    fastReplacedSegment.topLayerEntity.destroy()
                end

                -- Create the top layer entity that has the desired graphics on it.
                local topLayerEntityName = segmentTypeData.topLayerEntityName
                if topLayerEntityName ~= nil then
                    segment.topLayerEntity = surface.create_entity {name = topLayerEntityName, position = builtEntity_position, force = force, direction = builtEntity_direction}
                end
            end
        end
        global.undergroundSegments.segments[fastReplacedSegment.id] = nil
    else
        -- New segments just check if they complete the tunnel and handle approperiately.
        UndergroundSegments.UpdateUndergroundsForNewSegment(segment)
        UndergroundSegments.CheckAndHandleTunnelCompleteFromUnderground(segment.underground)
    end
end

--- Check if this segment is next to another segment on either/both sides. If it is create/add to an underground object for them.
---@param segment UndergroundSegment
UndergroundSegments.UpdateUndergroundsForNewSegment = function(segment)
    local firstComplictedConnectedSegment, secondComplictedConnectedSegment = nil, nil

    -- Check for a connected viable segment in both directions from our segment.
    for _, checkDetails in pairs(
        {
            {
                refPos = segment.frontPosition,
                refOrientation = segment.entity_orientation
            },
            {
                refPos = segment.rearPosition,
                refOrientation = Utils.LoopOrientationValue(segment.entity_orientation + 0.5)
            }
        }
    ) do
        local checkPos = Utils.ApplyOffsetToPosition(checkDetails.refPos, Utils.RotatePositionAround0(checkDetails.refOrientation, {x = 0, y = -1})) -- The position 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
        local checkSurfacePositionString = Utils.FormatSurfacePositionTableToString(segment.surface_index, checkPos)
        local foundPortalPartPositionObject = global.undergroundSegments.segmentConnectionSurfacePositions[checkSurfacePositionString]
        -- If a underground reference at this position is found next to this one add this part to its/new underground.
        if foundPortalPartPositionObject ~= nil then
            local connectedSegment = foundPortalPartPositionObject.segment
            local connectedSegmentsPositionNowConnected = Utils.FormatSurfacePositionTableToString(segment.surface_index, checkDetails.refPos) -- This is the connected segment's external checking position.
            -- Valid underground to create connection too, just work out how to handle this. Note some scenarios are not handled in this loop.
            if segment.underground and connectedSegment.underground == nil then
                -- We have a underground and they don't, so add them to our underground.
                UndergroundSegments.AddSegmentToUnderground(segment.underground, connectedSegment)
            elseif segment.underground == nil and connectedSegment.underground then
                -- We don't have a underground and they do, so add us to their underground.
                UndergroundSegments.AddSegmentToUnderground(connectedSegment.underground, segment)
            else
                -- Either we both have undergrounds or neither have undergrounds. Just flag this and review after checking both directions.
                if firstComplictedConnectedSegment == nil then
                    firstComplictedConnectedSegment = connectedSegment
                else
                    secondComplictedConnectedSegment = connectedSegment
                end
            end
            -- Update our and their nonConnectedSurfacePositions as we are both now connected on this.
            segment.nonConnectedSurfacePositions[checkSurfacePositionString] = nil
            connectedSegment.nonConnectedSurfacePositions[connectedSegmentsPositionNowConnected] = nil
        else
            local segmentsPositionNotConnected = Utils.FormatSurfacePositionTableToString(segment.surface_index, checkDetails.refPos)
            segment.nonConnectedSurfacePositions[checkSurfacePositionString] = segmentsPositionNotConnected
        end
    end

    -- Handle any weird situations where theres lots of undergrounds or none. Note that the scenarios handled are limited based on the logic outcomes of the direction checking logic.
    if segment.underground == nil then
        -- none has a underground, so create one for all.
        local undergroundId = global.undergroundSegments.nextUndergroundId
        global.undergroundSegments.nextUndergroundId = global.undergroundSegments.nextUndergroundId + 1
        ---@type Underground
        local underground = {
            id = undergroundId,
            segments = {},
            tilesLength = 0,
            force = segment.force,
            surface = segment.surface
        }
        global.undergroundSegments.undergrounds[undergroundId] = underground
        UndergroundSegments.AddSegmentToUnderground(underground, segment)
        if firstComplictedConnectedSegment ~= nil then
            UndergroundSegments.AddSegmentToUnderground(underground, firstComplictedConnectedSegment)
        end
        if secondComplictedConnectedSegment ~= nil then
            UndergroundSegments.AddSegmentToUnderground(underground, secondComplictedConnectedSegment)
        end
    end
    if firstComplictedConnectedSegment ~= nil then
        -- Us and the one complicated part both have an underground, so merge them. Use whichever has more segments as new master as this is generally the best one. We may have merged with an existing portal already, so its not possible for there to be 2 complicated connections needing portals merged.
        if Utils.GetTableNonNilLength(segment.underground.segments) >= Utils.GetTableNonNilLength(firstComplictedConnectedSegment.underground.segments) then
            UndergroundSegments.MergeUndergroundInToOtherUnderground(firstComplictedConnectedSegment.underground, segment.underground)
        else
            UndergroundSegments.MergeUndergroundInToOtherUnderground(segment.underground, firstComplictedConnectedSegment.underground)
        end
    end

    -- Just loop over the underground segments and find the ones with spare connection points. These are the ends.
    -- OVERHAUL - there is a more effecient but more complicated way to do this; ignore this until it shows as a noticable UPS waste.
    local underground = segment.underground
    underground.undergroundEndSegments = {}
    for _, thisSegment in pairs(underground.segments) do
        for _, surfacePositionString in pairs(thisSegment.nonConnectedSurfacePositions) do
            ---@type UndergroundEndSegmentObject
            local UndergroundEndSegmentObject = {
                connectableSurfacePosition = surfacePositionString,
                segment = thisSegment
            }
            table.insert(underground.undergroundEndSegments, UndergroundEndSegmentObject)
            if #underground.undergroundEndSegments == 2 then
                break
            end
        end
    end
end

--- Add the new segment to the existing underground.
---@param underground Underground
---@param segment UndergroundSegment
UndergroundSegments.AddSegmentToUnderground = function(underground, segment)
    segment.underground = underground
    underground.tilesLength = underground.tilesLength + segment.typeData.tilesLength
    underground.segments[segment.id] = segment
end

--- Moves the old segments to the new underground and removes the old underground object.
---@param oldUnderground Underground
---@param newUnderground Underground
UndergroundSegments.MergeUndergroundInToOtherUnderground = function(oldUnderground, newUnderground)
    for id, segment in pairs(oldUnderground.segments) do
        newUnderground.segments[id] = segment
        segment.underground = newUnderground
    end
    newUnderground.tilesLength = newUnderground.tilesLength + oldUnderground.tilesLength
    global.undergroundSegments.undergrounds[oldUnderground.id] = nil
end

-- Checks if the tunnel is complete and if it is triggers the tunnel complete code.
---@param underground Underground
UndergroundSegments.CheckAndHandleTunnelCompleteFromUnderground = function(underground)
    local portals, endPortalParts = {}, {}
    for _, UndergroundEndSegmentObject in pairs(underground.undergroundEndSegments) do
        local portal, endPortalPart = Interfaces.Call("TunnelPortals.CanAPortalConnectAtPosition", UndergroundEndSegmentObject.connectableSurfacePosition)
        if portal then
            table.insert(portals, portal)
            table.insert(endPortalParts, endPortalPart)
        end
    end
    if #portals == 2 then
        Interfaces.Call("TunnelPortals.PortalPartsAboutToBeInNewTunnel", endPortalParts)
        Interfaces.Call("Tunnel.CompleteTunnel", portals, underground)
    end
end

--- Checks if an underground has a connection at a set point. If it does returns the objects, otherwise nil for all.
---@param surfacePositionString SurfacePositionString
---@return Underground|null underground
---@return UndergroundSegment|null segmentAtOtherEndOfUnderground
UndergroundSegments.CanAnUndergroundConnectAtPosition = function(surfacePositionString)
    local segmentSurfacePositionObject = global.undergroundSegments.segmentConnectionSurfacePositions[surfacePositionString]
    if segmentSurfacePositionObject ~= nil then
        local underground = segmentSurfacePositionObject.segment.underground
        local otherEndSegment  ---@type UndergroundSegment
        if underground.undergroundEndSegments[1].segment.id == segmentSurfacePositionObject.segment.id then
            otherEndSegment = underground.undergroundEndSegments[2].segment
        else
            otherEndSegment = underground.undergroundEndSegments[1].segment
        end
        return underground, otherEndSegment
    end
end

-- Checks if an underground segment connects to a portal. Can provide a known portal to ignore, as single entity undergrounds will connect to 2 portals.
---@param segment UndergroundSegment
---@param portalToIgnore Portal
---@return Portal|null portal
---@return PortalEnd|null endPortalPart
UndergroundSegments.DoesUndergroundSegmentConnectToAPortal = function(segment, portalToIgnore)
    for _, checkPosString in pairs(segment.nonConnectedSurfacePositions) do
        local portal, endPortalPart = Interfaces.Call("TunnelPortals.CanAPortalConnectAtPosition", checkPosString)
        if portal ~= nil and portal.id ~= portalToIgnore.id then
            return portal, endPortalPart
        end
    end
end

-- Registers and sets up the underground prior to the tunnel object being created and references created.
---@param underground Underground
UndergroundSegments.On_PreTunnelCompleted = function(underground)
    for _, segment in pairs(underground.segments) do
        local refPos, force, surface, directionValue = segment.entity_position, underground.force, underground.surface, segment.entity_direction

        UndergroundSegments.BuildRailForSegment(segment)

        -- Add the singals to the underground tunnel rail.
        segment.signalEntities = {}
        for _, orientationModifier in pairs({0, 4}) do
            local signalDirection = Utils.LoopDirectionValue(directionValue + orientationModifier)
            local orientation = Utils.DirectionToOrientation(signalDirection)
            local position = Utils.ApplyOffsetToPosition(refPos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0}))
            local placedSignal = surface.create_entity {name = "railway_tunnel-invisible_signal-not_on_map", position = position, force = force, direction = signalDirection}
            segment.signalEntities[placedSignal.unit_number] = placedSignal
        end

        -- Create the top layer entity that has the desired graphics on it.
        local topLayerEntityName = segment.typeData.topLayerEntityName
        if topLayerEntityName ~= nil then
            segment.topLayerEntity = surface.create_entity {name = topLayerEntityName, position = refPos, force = force, direction = directionValue}
        end
    end
end

-- Add the rails to the an underground segment.
---@param segment UndergroundSegment
UndergroundSegments.BuildRailForSegment = function(segment)
    segment.tunnelRailEntities = {}
    for _, tracksPositionOffset in pairs(segment.typeData.undergroundTracksPositionOffset) do
        local railPos = Utils.ApplyOffsetToPosition(segment.entity_position, Utils.RotatePositionAround0(segment.entity_orientation, tracksPositionOffset.positionOffset))
        local placedRail = segment.surface.create_entity {name = tracksPositionOffset.trackEntityName, position = railPos, force = segment.force, direction = Utils.RotateDirectionByDirection(tracksPositionOffset.baseDirection, defines.direction.north, segment.entity_direction)}
        placedRail.destructible = false
        segment.tunnelRailEntities[placedRail.unit_number] = placedRail
    end
end

-- If the built entity was a ghost of an underground segment then check it is on the rail grid.
---@param event on_built_entity|on_robot_built_entity|script_raised_built
UndergroundSegments.OnBuiltEntityGhost = function(event)
    --TODO: move this to somewhere central and merge with underground check as identical code. Save UPS in event functions triggered within mod.
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or createdEntity.type ~= "entity-ghost" or UndergroundSegmentEntityNames[createdEntity.ghost_name] == nil then
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

-- TODO - checked up to here
-- This is needed so when a player is doing a fast replace by hand the OnPreMinedEntity knows can know its a fast replace and not check mining conflicts or affect the pre_mine. All other scenarios of this triggering do no harm as the beingFastReplaced attribute is either cleared or the object recreated cleanly on the follow on event.
---@param event on_pre_build
UndergroundSegments.OnPreBuild = function(event)
    local player = game.get_player(event.player_index)
    if not player.cursor_stack.valid or not player.cursor_stack.valid_for_read or UndergroundSegmentEntityNames[player.cursor_stack.name] == nil then
        return
    end

    local surface = player.surface
    local surfacePositionString = Utils.FormatSurfacePositionTableToString(surface.index, event.position)
    local segmentPositionObject = global.undergroundSegments.segmentSurfacePositions[surfacePositionString]
    if segmentPositionObject == nil then
        return
    end

    -- If the direction isn't the same or opposite then this is a rotational fast replace attempt and this isn't a handled fast replace by us.
    if segmentPositionObject.segment.entity.direction ~= event.direction and segmentPositionObject.segment.entity.direction ~= Utils.LoopDirectionValue(event.direction + 4) then
        return
    end

    -- Its a valid fast replace wuithout affecting tunnel and so flag it as such.
    segmentPositionObject.segment.beingFastReplacedTick = event.tick
end

---@param event on_pre_player_mined_item|on_robot_pre_mined
UndergroundSegments.OnPreMinedEntity = function(event)
    local minedEntity = event.entity
    if not minedEntity.valid or UndergroundSegmentEntityNames[minedEntity.name] == nil then
        return
    end
    local segment = global.undergroundSegments.segments[minedEntity.unit_number]
    if segment == nil then
        return
    end

    if segment.beingFastReplacedTick ~= nil and segment.beingFastReplacedTick == event.tick then
        -- Detected that the player has pre_placed an entity at the same spot in the same tick, so the entity is being fast replaced and thus not really mined.
        return
    end

    local miner = event.robot -- Will be nil for player mined.
    if miner == nil and event.player_index ~= nil then
        miner = game.get_player(event.player_index)
    end
    if segment.crossingRailEntities ~= nil then
        for _, railEntity in pairs(segment.crossingRailEntities) do
            if not railEntity.can_be_destroyed() then
                TunnelShared.EntityErrorMessage(miner, "Can not mine tunnel segment while train is on crossing track", minedEntity.surface, minedEntity.position)
                UndergroundSegments.ReplaceSegmentEntity(segment)
                return
            end
        end
    end
    if segment.tunnel == nil then
        UndergroundSegments.EntityRemoved(segment)
    else
        if Interfaces.Call("Tunnel.GetTunnelsUsageEntry", segment.tunnel) then
            TunnelShared.EntityErrorMessage(miner, "Can not mine tunnel segment while train is using tunnel", minedEntity.surface, minedEntity.position)
            UndergroundSegments.ReplaceSegmentEntity(segment)
        else
            Interfaces.Call("Tunnel.RemoveTunnel", segment.tunnel)
            UndergroundSegments.EntityRemoved(segment)
        end
    end
end

---@param oldSegment UndergroundSegment
UndergroundSegments.ReplaceSegmentEntity = function(oldSegment)
    local centerPos, force, lastUser, directionValue, surface, entityName = oldSegment.entity.position, oldSegment.entity.force, oldSegment.entity.last_user, oldSegment.entity.direction, oldSegment.entity.surface, oldSegment.entity.name
    oldSegment.entity.destroy()

    local newSegmentEntity = surface.create_entity {name = entityName, position = centerPos, direction = directionValue, force = force, player = lastUser} ---@type LuaEntity
    ---@type UndergroundSegment
    local newSegment = {
        id = newSegmentEntity.unit_number, ---@type UnitNumber
        entity = newSegmentEntity,
        tunnelRailEntities = oldSegment.tunnelRailEntities,
        signalEntities = oldSegment.signalEntities,
        tunnel = oldSegment.tunnel,
        crossingRailEntities = oldSegment.crossingRailEntities,
        surfacePositionString = Utils.FormatSurfacePositionTableToString(newSegmentEntity.surface.index, newSegmentEntity.position)
    }
    global.undergroundSegments.segments[newSegment.id] = newSegment
    global.undergroundSegments.segmentSurfacePositions[newSegment.surfacePositionString].segment = newSegment
    global.undergroundSegments.segments[oldSegment.id] = nil
    Interfaces.Call("Tunnel.On_SegmentReplaced", newSegment.tunnel, oldSegment, newSegment)
end

---@param segment UndergroundSegment
---@param killForce LuaForce
---@param killerCauseEntity LuaEntity
UndergroundSegments.EntityRemoved = function(segment, killForce, killerCauseEntity)
    if segment.crossingRailEntities ~= nil then
        TunnelShared.DestroyCarriagesOnRailEntityList(segment.crossingRailEntities, killForce, killerCauseEntity)
        for _, crossingRailEntity in pairs(segment.crossingRailEntities) do
            if crossingRailEntity.valid then
                crossingRailEntity.destroy()
            end
        end
    end
    if segment.trainBlockerEntity ~= nil then
        segment.trainBlockerEntity.destroy()
    end
    if segment.topLayerEntity ~= nil and segment.topLayerEntity.valid then
        segment.topLayerEntity.destroy()
    end
    global.undergroundSegments.segmentSurfacePositions[segment.surfacePositionString] = nil
    global.undergroundSegments.segments[segment.id] = nil
end

---@param segments UndergroundSegment[]
UndergroundSegments.On_TunnelRemoved = function(segments)
    for _, segment in pairs(segments) do
        segment.tunnel = nil

        for _, railEntity in pairs(segment.tunnelRailEntities) do
            if railEntity.valid then
                railEntity.destroy()
            end
        end
        segment.tunnelRailEntities = nil

        for _, signalEntity in pairs(segment.signalEntities) do
            if signalEntity.valid then
                signalEntity.destroy()
            end
        end
        segment.signalEntities = nil

        if segment.topLayerEntity ~= nil and segment.topLayerEntity.valid then
            segment.topLayerEntity.destroy()
        end
        segment.topLayerEntity = nil
    end
end

---@param event on_entity_died|script_raised_destroy
UndergroundSegments.OnDiedEntity = function(event)
    local diedEntity, killerForce, killerCauseEntity = event.entity, event.force, event.cause -- The killer variables will be nil in some cases.
    if not diedEntity.valid or UndergroundSegmentEntityNames[diedEntity.name] == nil then
        return
    end
    local segment = global.undergroundSegments.segments[diedEntity.unit_number]
    if segment == nil then
        return
    end

    if segment.tunnel == nil then
        UndergroundSegments.EntityRemoved(segment, killerForce, killerCauseEntity)
    else
        Interfaces.Call("Tunnel.RemoveTunnel", segment.tunnel)
        UndergroundSegments.EntityRemoved(segment, killerForce, killerCauseEntity)
    end
end

return UndergroundSegments
