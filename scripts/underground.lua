local Events = require("utility/events")
local Utils = require("utility/utils")
local TunnelShared = require("scripts/tunnel-shared")
local Common = require("scripts/common")
local UndergroundSegmentEntityNames = Common.UndergroundSegmentEntityNames
local Underground = {}

---@class Underground
---@field id uint @ unique id of the underground object.
---@field segments table<UnitNumber, UndergroundSegment> @ segments in the underground. Key'd by the portal end entity unit_number (id).
---@field tilesLength int @ how many tiles this underground is long.
---@field force LuaForce @ the force this underground object belongs to.
---@field surface LuaSurface @ the surface this underground object is on.
---@field undergroundEndSegments UndergroundEndSegmentObject[] @ objects with details of the segments at the 2 ends of the underground. Updated every time the underground's segments change.
---
---@field tunnel? Tunnel|null @ ref to tunnel object if this underground is part of one. Only established once this underground is part of a valid tunnel.

---@class UndergroundSegment
---@field id UnitNumber @ unit_number of the placed segment entity.
---@field entity LuaEntity
---@field entity_name string @ cache of the segment's entity's name.
---@field entity_position Position @ cache of the entity's position.
---@field entity_direction defines.direction @ cache of the entity's direction.
---@field entity_orientation RealOrientation @ cache of the entity's orientation.
---@field frontInternalPosition Position @ used as base to look for other tunnel segments' segmentSurfacePositions global object entries. These are present on each connecting end of the segment 0.5 tile in from its connecting edge center. This is to handle various shapes.
---@field rearInternalPosition Position  @ used as base to look for other tunnel segments' segmentSurfacePositions global object entries. These are present on each connecting end of the segment 0.5 tile in from its connecting edge center. This is to handle various shapes.
---@field frontInternalSurfacePositionString SurfacePositionString @ cache of the sement's frontInternalPosition as a SurfacePositionString.
---@field rearInternalSurfacePositionString SurfacePositionString @ cache of the sement's rearInternalPosition as a SurfacePositionString.
---@field frontExternalCheckSurfacePositionString SurfacePositionString @ cache of the front External Check position used when looking for connected tunnel parts. Is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
---@field rearExternalCheckSurfacePositionString SurfacePositionString @ cache of the rear External Check position used when looking for connected tunnel parts. Is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
---@field surface LuaSurface @ the surface this segment object is on.
---@field surface_index uint @ cached index of the surface this segment is on.
---@field force LuaForce @ the force this segment object belongs to.
---@field underground Underground @ ref to the parent underground object.
---@field crossingRailEntities table<UnitNumber, LuaEntity> @ the rail entities that cross the tunnel segment. Table only exists for entity type of "underground_segment-rail_crossing". -- OVERHAUL - this should be made in to a new sub class. Will be needed when its related data is made non hard coded.
---@field trainBlockerEntity LuaEntity @ the "railway_tunnel-train_blocker_2x2" entity of this tunnel segment if it has one currently.
---@field surfacePositionString SurfacePositionString @ used for Fast Replacement to back match to segmentSurfacePositions global object.
---@field beingFastReplacedTick uint @ the tick the segment was marked as being fast replaced or nil.
---@field tilesLength int @ how many tiles this segment is long.
---@field typeData UndergroundSegmentTypeData @ ref to generic data about this type of segment.
---@field nonConnectedExternalSurfacePositions table<SurfacePositionString, SurfacePositionString> @ a table of this segments non connected external positions to check outside of the entity. Always exists, even if not part of a portal.
---
---@field tunnelRailEntities? table<UnitNumber, LuaEntity>|null @ the invisible rail entities within the tunnel segment that form part of the larger tunnel. Only established once this portal is part of a valid tunnel.
---@field signalEntities? table<UnitNumber, LuaEntity>|null @ the hidden signal entities within the tunnel segment. Only established once this portal is part of a valid tunnel.
---@field topLayerEntity? LuaEntity|null @ the top layer graphical entity that is showings its picture and hiding the main entities once placed. Only established once this portal is part of a valid tunnel.

---@class UndergroundEndSegmentObject @ details of a segment at the end of an underground.
---@field segment UndergroundSegment
---@field externalConnectableSurfacePosition SurfacePositionString @ where a portal could have its connection position and join to this segment's external entity border connection point.

---@class SegmentSurfacePosition
---@field id SurfacePositionString
---@field segment UndergroundSegment

---@alias FastReplaceChange "'downgrade'"|"'upgrade'"|"'same'"

---@class UndergroundSegmentTypeData
---@field name string
---@field segmentShape UndergroundSegmentShape
---@field topLayerEntityName string @ the entity to place when the tunnel is complete to show the desired completed graphics layer.
---@field placeCrossingRails boolean @ if this segment type has above ground crossing rails or not.
---@field tilesLength int @ how many tiles this underground is long.
---@field undergroundTracksPositionOffset PortalPartTrackPositionOffset[] @ the type of underground track and its position offset from the center of the segment when in a 0 orientation.

---@class UndergroundSegmentShape @ the shape of the segment part.
local SegmentShape = {
    straight = "straight", -- Short straight piece for horizontal and vertical.
    diagonal = "diagonal", -- Short diagonal piece.
    curveStart = "curveStart", -- The start of a curve, so between Straight and Diagonal.
    curveInner = "curveInner" -- The inner part of a curve that connects 2 curveStart's togeather to make a 90 degree corner.
}

---@class UndergroundSegmentTrackPositionOffset @ type of track and its position offset from the center of the segment when in a 0 orientation.
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

Underground.CreateGlobals = function()
    global.undergrounds = global.undergrounds or {}
    global.undergrounds.nextUndergroundId = global.undergrounds.nextUndergroundId or 1
    global.undergrounds.undergrounds = global.undergrounds.undergrounds or {}
    global.undergrounds.segments = global.undergrounds.segments or {} ---@type table<UnitNumber, UndergroundSegment>
    global.undergrounds.segmentSurfacePositions = global.undergrounds.segmentSurfacePositions or {} ---@type table<SurfacePositionString, SegmentSurfacePosition> @ a lookup for underground segments by their position string.
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings = global.undergrounds.segmentInternalConnectionSurfacePositionStrings or {} ---@type table<SurfacePositionString, SegmentSurfacePosition> @ a lookup for internal positions that underground segments can be connected on. Includes the segment's frontInternalSurfacePositionString and rearInternalSurfacePositionString as keys for lookup.
end

Underground.OnLoad = function()
    local segmentEntityNames_Filter = {}
    for _, name in pairs(UndergroundSegmentEntityNames) do
        table.insert(segmentEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Underground.OnBuiltEntity", Underground.OnBuiltEntity, segmentEntityNames_Filter, {created_entity = {"valid", "name"}})
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Underground.OnBuiltEntity", Underground.OnBuiltEntity, segmentEntityNames_Filter, {created_entity = {"valid", "name"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Underground.OnBuiltEntity", Underground.OnBuiltEntity, segmentEntityNames_Filter, {entity = {"valid", "name"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_revive, "Underground.OnBuiltEntity", Underground.OnBuiltEntity, segmentEntityNames_Filter, {entity = {"valid", "name"}})
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "Underground.OnPreMinedEntity", Underground.OnPreMinedEntity, segmentEntityNames_Filter, nil)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "Underground.OnPreMinedEntity", Underground.OnPreMinedEntity, segmentEntityNames_Filter, nil)
    Events.RegisterHandlerEvent(defines.events.on_pre_build, "Underground.OnPreBuild", Underground.OnPreBuild, nil, nil)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Underground.OnDiedEntity", Underground.OnDiedEntity, segmentEntityNames_Filter, {entity = {"valid", "name"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "Underground.OnDiedEntity", Underground.OnDiedEntity, segmentEntityNames_Filter, {entity = {"valid", "name"}})

    local segmentEntityGhostNames_Filter = {}
    for _, name in pairs(UndergroundSegmentEntityNames) do
        table.insert(segmentEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Underground.OnBuiltEntityGhost", Underground.OnBuiltEntityGhost, segmentEntityGhostNames_Filter, {created_entity = {"valid", "type"}})
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Underground.OnBuiltEntityGhost", Underground.OnBuiltEntityGhost, segmentEntityGhostNames_Filter, {created_entity = {"valid", "type"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Underground.OnBuiltEntityGhost", Underground.OnBuiltEntityGhost, segmentEntityGhostNames_Filter, {entity = {"valid", "type"}})

    MOD.Interfaces.Underground = MOD.Interfaces.Underground or {}
    MOD.Interfaces.Underground.On_PreTunnelCompleted = Underground.On_PreTunnelCompleted
    MOD.Interfaces.Underground.On_TunnelRemoved = Underground.On_TunnelRemoved
    MOD.Interfaces.Underground.CanAnUndergroundConnectAtItsInternalPosition = Underground.CanAnUndergroundConnectAtItsInternalPosition
    MOD.Interfaces.Underground.CanUndergroundSegmentConnectToAPortal = Underground.CanUndergroundSegmentConnectToAPortal
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
---@param cachedData UtilityEvents_CachedEventData
Underground.OnBuiltEntity = function(event, cachedData)
    local createdEntityCached = cachedData.created_entity or cachedData.entity
    if not createdEntityCached.valid or UndergroundSegmentEntityNames[createdEntityCached.name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    local createdEntityNonCached = event.created_entity or event.entity
    Underground.UndergroundSegmentBuilt(createdEntityNonCached, placer, createdEntityCached.name)
end

---@param builtEntity LuaEntity
---@param placer EntityActioner
---@param builtEntity_name string
---@return boolean
Underground.UndergroundSegmentBuilt = function(builtEntity, placer, builtEntity_name)
    -- Check the placement is on rail grid, if not then undo the placement and stop.
    if not TunnelShared.IsPlacementOnRailGrid(builtEntity) then
        TunnelShared.UndoInvalidTunnelPartPlacement(builtEntity, placer, true)
        return
    end

    local builtEntity_position, force, builtEntity_direction, surface, builtEntity_orientation = builtEntity.position, builtEntity.force, builtEntity.direction, builtEntity.surface, builtEntity.orientation
    local segmentTypeData, surface_index = SegmentTypeData[builtEntity_name], surface.index

    -- Make the new base segment object
    local surfacePositionString = Utils.FormatSurfacePositionToString(surface_index, builtEntity_position)
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
        nonConnectedExternalSurfacePositions = {}
    }
    builtEntity.rotatable = false

    -- Handle the caching of specific segment type information and to their globals.
    if segmentTypeData.segmentShape == SegmentShape.straight then
        segment.frontInternalPosition = Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = -0.5}, builtEntity_position)
        segment.rearInternalPosition = Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = 0.5}, builtEntity_position)
    else
        error("unrecognised segmentTypeData.segmentShape: " .. segmentTypeData.segmentShape)
    end

    -- Check if this is a fast replacement and if it is handle eveything special ready for standard built entity function logic.
    local fastReplacedSegmentByPosition = global.undergrounds.segmentSurfacePositions[surfacePositionString]
    local fastReplacedSegment  ---@type UndergroundSegment
    local newSegmentTypeBuilt = true ---@type FastReplaceChange
    if fastReplacedSegmentByPosition ~= nil then
        fastReplacedSegment = fastReplacedSegmentByPosition.segment

        -- Work out the specific change type and deal with it accordingly.
        if segmentTypeData.placeCrossingRails and fastReplacedSegment.crossingRailEntities == nil then
            -- Upgrade from non crossing rails to crossing rails.

            -- Remove the old train blocker entity.
            -- OVERHAUL: the trainBlockerEntity doesn't need to be placed until the rails are added when the tunnel is complete. The crossing rails are needed before hand however.
            fastReplacedSegment.trainBlockerEntity.destroy()
            fastReplacedSegment.trainBlockerEntity = nil

            -- If the old segment had an signalEntities array then we need to add them for the new segment.
            if fastReplacedSegment.signalEntities ~= nil then
                segment.signalEntities = {}
                Underground.BuildSignalsForSegment(segment)
            end
        elseif not segmentTypeData.placeCrossingRails and fastReplacedSegment.crossingRailEntities ~= nil then
            -- Downgrade from crossing rails to non crossing rails.

            -- Check crossing rails can be safely removed. If they can't then undo the downgrade and stop.
            for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
                if not railCrossingTrackEntity.can_be_destroyed() then
                    -- Put the old correct entity back and correct whats been done.
                    TunnelShared.EntityErrorMessage(placer, {"message.railway_tunnel-crossing_track_fast_replace_blocked_as_in_use"}, surface, builtEntity_position)
                    fastReplacedSegment.entity = builtEntity -- Update this entity reference temporarily so that the standard replacement function works as expected.
                    Underground.RestoreSegmentEntity(fastReplacedSegment)
                    Utils.GetBuilderInventory(placer).remove({name = "railway_tunnel-underground_segment-straight-rail_crossing", count = 1})
                    Utils.GetBuilderInventory(placer).insert({name = "railway_tunnel-underground_segment-straight", count = 1})
                    return
                end
            end

            -- Remove the old rails as all safe.
            for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
                railCrossingTrackEntity.destroy()
            end
            -- Remove the old crossing track signals if there were any.
            if fastReplacedSegment.signalEntities ~= nil then
                for _, crossingRailSignal in pairs(fastReplacedSegment.signalEntities) do
                    crossingRailSignal.destroy()
                end
                segment.signalEntities = {} -- Give the new segment the empty table as it would have had it if built normally.
            end
        else
            -- Is a fast replace to the same type.
            newSegmentTypeBuilt = false

            -- Fast replacement's of the same type can just claim the old segments extras.
            if segmentTypeData.placeCrossingRails then
                segment.crossingRailEntities = fastReplacedSegment.crossingRailEntities
                segment.signalEntities = fastReplacedSegment.signalEntities -- May or not be populated at the time, but this is fine in both cases.
            else
                segment.trainBlockerEntity = fastReplacedSegment.trainBlockerEntity
            end
        end

        -- Claim the generic extras of the old segment,
        segment.tunnelRailEntities = fastReplacedSegment.tunnelRailEntities
        segment.underground = fastReplacedSegment.underground

        -- Handle the Underground object.
        segment.underground.segments[fastReplacedSegment.id] = nil
        segment.underground.segments[segment.id] = segment

        -- Handle anything that is only present if there is a parent tunnel.
        if segment.underground.tunnel ~= nil then
            -- Update the top layer entity if it needs changing due to change of entity type.
            if newSegmentTypeBuilt then
                -- Remove the old top layer.
                if fastReplacedSegment.topLayerEntity ~= nil and fastReplacedSegment.topLayerEntity.valid then
                    fastReplacedSegment.topLayerEntity.destroy()
                end

                -- Create the top layer entity that has the desired graphics on it.
                local topLayerEntityName = segmentTypeData.topLayerEntityName
                if topLayerEntityName ~= nil then
                    segment.topLayerEntity = surface.create_entity {name = topLayerEntityName, position = builtEntity_position, force = force, direction = builtEntity_direction, raise_built = false, create_build_effect_smoke = false}
                end
            end
        end

        -- Tidy up the old removed segment.
        global.undergrounds.segments[fastReplacedSegment.id] = nil
    end

    -- For new segment type being built add the type extras.
    if newSegmentTypeBuilt then
        if segmentTypeData.placeCrossingRails then
            -- OVERHAUL - move this to be type data driven and not hard coded.
            segment.crossingRailEntities = {}
            local crossignRailDirection, orientation = Utils.LoopDirectionValue(builtEntity_direction + 2), Utils.DirectionToOrientation(builtEntity_direction)
            for _, nextRailPos in pairs(
                {
                    Utils.RotateOffsetAroundPosition(orientation, {x = -2, y = 0}, builtEntity_position),
                    builtEntity_position,
                    Utils.RotateOffsetAroundPosition(orientation, {x = 2, y = 0}, builtEntity_position)
                }
            ) do
                local placedRail = surface.create_entity {name = "railway_tunnel-crossing_rail-on_map", position = nextRailPos, force = force, direction = crossignRailDirection, raise_built = false, create_build_effect_smoke = false}
                placedRail.destructible = false
                segment.crossingRailEntities[placedRail.unit_number] = placedRail
            end
        else
            segment.trainBlockerEntity = surface.create_entity {name = "railway_tunnel-train_blocker_2x2", position = builtEntity_position, force = force, raise_built = false, create_build_effect_smoke = false}
        end
    end

    -- Register the new segment and its position for fast replace.
    global.undergrounds.segments[segment.id] = segment
    global.undergrounds.segmentSurfacePositions[segment.surfacePositionString] = {
        id = segment.surfacePositionString,
        segment = segment
    }

    -- Register the segments surfacePositionStrings for connection reverse lookup.
    local frontInternalSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, segment.frontInternalPosition)
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings[frontInternalSurfacePositionString] = {
        id = frontInternalSurfacePositionString,
        segment = segment
    }
    segment.frontInternalSurfacePositionString = frontInternalSurfacePositionString
    local rearInternalSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, segment.rearInternalPosition)
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings[rearInternalSurfacePositionString] = {
        id = rearInternalSurfacePositionString,
        segment = segment
    }
    segment.rearInternalSurfacePositionString = rearInternalSurfacePositionString

    -- The External Check position is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
    segment.frontExternalCheckSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = -1}, segment.frontInternalPosition))
    segment.rearExternalCheckSurfacePositionString = Utils.FormatSurfacePositionToString(surface_index, Utils.RotateOffsetAroundPosition(builtEntity_orientation, {x = 0, y = 1}, segment.rearInternalPosition))

    -- New segments check if they complete the tunnel and handle approperiately.
    if fastReplacedSegment == nil then
        Underground.UpdateUndergroundsForNewSegment(segment)
        Underground.CheckAndHandleTunnelCompleteFromUnderground(segment.underground)
    end
end

--- Check if this segment is next to another segment on either/both sides. If it is create/add to an underground object for them.
---@param segment UndergroundSegment
Underground.UpdateUndergroundsForNewSegment = function(segment)
    local firstComplictedConnectedSegment, secondComplictedConnectedSegment = nil, nil

    -- Check for a connected viable segment in both directions from our segment.
    for _, checkDetails in pairs(
        {
            {
                internalCheckSurfacePositionString = segment.frontInternalSurfacePositionString,
                externalCheckSurfacePositionString = segment.frontExternalCheckSurfacePositionString
            },
            {
                internalCheckSurfacePositionString = segment.rearInternalSurfacePositionString,
                externalCheckSurfacePositionString = segment.rearExternalCheckSurfacePositionString
            }
        }
    ) do
        -- Look in the global internal position string list for any segment that is where our external check position is.
        local foundSegmentPositionObject = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[checkDetails.externalCheckSurfacePositionString]
        -- If a underground reference at this position is found next to this one add this segment to its/new underground.
        if foundSegmentPositionObject ~= nil then
            local connectedSegment = foundSegmentPositionObject.segment
            -- Valid underground to create connection too, just work out how to handle this. Note some scenarios are not handled in this loop.
            if segment.underground and connectedSegment.underground == nil then
                -- We have a underground and they don't, so add them to our underground.
                Underground.AddSegmentToUnderground(segment.underground, connectedSegment)
            elseif segment.underground == nil and connectedSegment.underground then
                -- We don't have a underground and they do, so add us to their underground.
                Underground.AddSegmentToUnderground(connectedSegment.underground, segment)
            else
                -- Either we both have undergrounds or neither have undergrounds. Just flag this and review after checking both directions.
                if firstComplictedConnectedSegment == nil then
                    firstComplictedConnectedSegment = connectedSegment
                else
                    secondComplictedConnectedSegment = connectedSegment
                end
            end
            -- Update ours and their nonConnectedExternalSurfacePositions as we are both now connected on this.
            segment.nonConnectedExternalSurfacePositions[checkDetails.externalCheckSurfacePositionString] = nil
            -- For the connectedSegment our internal check position is their external check position.
            connectedSegment.nonConnectedExternalSurfacePositions[checkDetails.internalCheckSurfacePositionString] = nil
        else
            segment.nonConnectedExternalSurfacePositions[checkDetails.externalCheckSurfacePositionString] = checkDetails.externalCheckSurfacePositionString
        end
    end

    -- Handle any weird situations where theres lots of undergrounds or none. Note that the scenarios handled are limited based on the logic outcomes of the direction checking logic.
    -- The logging of complicated segments was based on our state at the time of the comparison. So the second connected segment may have changed our state since we compared to the first connected segment.
    if segment.underground == nil then
        -- We always need an underground, so create one and add anyone else to it.
        local undergroundId = global.undergrounds.nextUndergroundId
        global.undergrounds.nextUndergroundId = global.undergrounds.nextUndergroundId + 1
        ---@type Underground
        local underground = {
            id = undergroundId,
            segments = {},
            tilesLength = 0,
            force = segment.force,
            surface = segment.surface
        }
        global.undergrounds.undergrounds[undergroundId] = underground
        Underground.AddSegmentToUnderground(underground, segment)
        if firstComplictedConnectedSegment ~= nil then
            Underground.AddSegmentToUnderground(underground, firstComplictedConnectedSegment)
        end
        if secondComplictedConnectedSegment ~= nil then
            Underground.AddSegmentToUnderground(underground, secondComplictedConnectedSegment)
        end
    end
    if firstComplictedConnectedSegment ~= nil then
        if segment.underground ~= nil and firstComplictedConnectedSegment.underground ~= nil then
            -- Us and the one complicated segment both have a underground.

            -- If the 2 undergrounds are different then merge them. Use whichever has more segments as new master as this is generally the best one. It can end up that both have the same underground during the connection process and in this case do nothing to the shared underground.
            if segment.underground.id ~= firstComplictedConnectedSegment.underground.id then
                if Utils.GetTableNonNilLength(segment.underground.segments) >= Utils.GetTableNonNilLength(firstComplictedConnectedSegment.underground.segments) then
                    Underground.MergeUndergroundInToOtherUnderground(firstComplictedConnectedSegment.underground, segment.underground)
                else
                    Underground.MergeUndergroundInToOtherUnderground(segment.underground, firstComplictedConnectedSegment.underground)
                end
            end
        elseif segment.underground ~= nil and firstComplictedConnectedSegment.underground == nil then
            -- We have an underground now and the other complicated connnected segment doesn't. We may have obtained one since the initial comparison. Just add them to ours now.
            Underground.AddSegmentToUnderground(segment.underground, firstComplictedConnectedSegment)
        else
            -- If a situation should be ignored add it explicitly.
            error("unexpected scenario")
        end
    end

    -- Just loop over the underground segments and find the ones with spare connection points. These are the ends.
    -- There is a more effecient but more complicated way to do this, ignore this until it shows as a noticable UPS waste. Same more complicated scneario could be applied to when an underground or portal has an entity removed from it.
    local underground = segment.underground
    underground.undergroundEndSegments = {}
    for _, thisSegment in pairs(underground.segments) do
        for _, externalConnectableSurfacePosition in pairs(thisSegment.nonConnectedExternalSurfacePositions) do
            ---@type UndergroundEndSegmentObject
            local UndergroundEndSegmentObject = {
                externalConnectableSurfacePosition = externalConnectableSurfacePosition,
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
Underground.AddSegmentToUnderground = function(underground, segment)
    segment.underground = underground
    underground.tilesLength = underground.tilesLength + segment.typeData.tilesLength
    underground.segments[segment.id] = segment
end

--- Moves the old segments to the new underground and removes the old underground object.
---@param oldUnderground Underground
---@param newUnderground Underground
Underground.MergeUndergroundInToOtherUnderground = function(oldUnderground, newUnderground)
    for id, segment in pairs(oldUnderground.segments) do
        newUnderground.segments[id] = segment
        segment.underground = newUnderground
    end
    newUnderground.tilesLength = newUnderground.tilesLength + oldUnderground.tilesLength
    global.undergrounds.undergrounds[oldUnderground.id] = nil
end

-- Checks if the tunnel is complete and if it is triggers the tunnel complete code.
---@param underground Underground
Underground.CheckAndHandleTunnelCompleteFromUnderground = function(underground)
    local portals, endPortalParts = {}, {}
    for _, UndergroundEndSegmentObject in pairs(underground.undergroundEndSegments) do
        local portal, endPortalPart = MOD.Interfaces.Portal.CanAPortalConnectAtItsInternalPosition(UndergroundEndSegmentObject.externalConnectableSurfacePosition)
        if portal then
            table.insert(portals, portal)
            table.insert(endPortalParts, endPortalPart)
        end
    end
    if #portals == 2 then
        MOD.Interfaces.Portal.PortalPartsAboutToConnectToUndergroundInNewTunnel(endPortalParts)
        MOD.Interfaces.Tunnel.CompleteTunnel(portals, underground)
    end
end

--- Checks if an underground segment can connect at a free internal connection position. If it does returns the objects, otherwise nil for all.
---@param segmentInternalSurfacePositionString SurfacePositionString
---@return Underground|null underground
---@return UndergroundSegment|null segmentAtOtherEndOfUnderground
Underground.CanAnUndergroundConnectAtItsInternalPosition = function(segmentInternalSurfacePositionString)
    -- Uses the segment position rather than some underground ends' positions as an underground is never complete to flag these. Also entities can't overlap their internal positions so no risk of getting the wrong object.
    local segmentInternalSurfacePositionObject = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[segmentInternalSurfacePositionString]
    if segmentInternalSurfacePositionObject ~= nil then
        local underground = segmentInternalSurfacePositionObject.segment.underground
        local otherEndSegment  ---@type UndergroundSegment
        if underground.undergroundEndSegments[1].segment.id == segmentInternalSurfacePositionObject.segment.id then
            otherEndSegment = underground.undergroundEndSegments[2].segment
        else
            otherEndSegment = underground.undergroundEndSegments[1].segment
        end
        return underground, otherEndSegment
    end
end

-- Checks if an underground segment can connect to a portal. Can provide a known portal to ignore, as single entity undergrounds will connect to 2 portals.
---@param segment UndergroundSegment
---@param portalToIgnore Portal
---@return Portal|null portal
---@return PortalEnd|null endPortalPart
Underground.CanUndergroundSegmentConnectToAPortal = function(segment, portalToIgnore)
    for _, segmentFreeExternalSurfacePositionString in pairs(segment.nonConnectedExternalSurfacePositions) do
        local portal, endPortalPart = MOD.Interfaces.Portal.CanAPortalConnectAtItsInternalPosition(segmentFreeExternalSurfacePositionString)
        if portal ~= nil and portal.id ~= portalToIgnore.id then
            return portal, endPortalPart
        end
    end
end

-- Registers and sets up the underground prior to the tunnel object being created and references created.
---@param underground Underground
Underground.On_PreTunnelCompleted = function(underground)
    for _, segment in pairs(underground.segments) do
        Underground.BuildRailForSegment(segment)

        -- Add signals to the underground tunnel rail for the segments with crossing rails only. The mod expects the signalEntities to exist even if empty.
        if segment.typeData.placeCrossingRails then
            segment.signalEntities = {}
            Underground.BuildSignalsForSegment(segment)
        else
            segment.signalEntities = {}
        end

        -- Create the top layer entity that has the desired graphics on it.
        local topLayerEntityName = segment.typeData.topLayerEntityName
        if topLayerEntityName ~= nil then
            segment.topLayerEntity = segment.surface.create_entity {name = topLayerEntityName, position = segment.entity_position, force = segment.force, direction = segment.entity_direction, raise_built = false, create_build_effect_smoke = false}
        end
    end
end

-- Add the rails to the an underground segment.
---@param segment UndergroundSegment
Underground.BuildRailForSegment = function(segment)
    segment.tunnelRailEntities = {}
    for _, tracksPositionOffset in pairs(segment.typeData.undergroundTracksPositionOffset) do
        local railPos = Utils.RotateOffsetAroundPosition(segment.entity_orientation, tracksPositionOffset.positionOffset, segment.entity_position)
        local placedRail = segment.surface.create_entity {name = tracksPositionOffset.trackEntityName, position = railPos, force = segment.force, direction = Utils.RotateDirectionByDirection(tracksPositionOffset.baseDirection, defines.direction.north, segment.entity_direction), raise_built = false, create_build_effect_smoke = false}
        placedRail.destructible = false
        segment.tunnelRailEntities[placedRail.unit_number] = placedRail
    end
end

--- Builds crossing rail signals for the segment and caches them to the segment
---@param segment UndergroundSegment
Underground.BuildSignalsForSegment = function(segment)
    for _, orientationModifier in pairs({0, 4}) do
        local signalDirection = Utils.LoopDirectionValue(segment.entity_direction + orientationModifier)
        local orientation = Utils.DirectionToOrientation(signalDirection)
        local position = Utils.RotateOffsetAroundPosition(orientation, {x = -1.5, y = 0}, segment.entity_position)
        local placedSignal = segment.surface.create_entity {name = "railway_tunnel-invisible_signal-not_on_map", position = position, force = segment.force, direction = signalDirection, raise_built = false, create_build_effect_smoke = false}
        segment.signalEntities[placedSignal.unit_number] = placedSignal
    end
end

-- If the built entity was a ghost of an underground segment then check it is on the rail grid.
---@param event on_built_entity|on_robot_built_entity|script_raised_built
---@param cachedData UtilityEvents_CachedEventData
Underground.OnBuiltEntityGhost = function(event, cachedData)
    local createdEntityCached = cachedData.created_entity or cachedData.entity
    local createdEntityNonCached = event.created_entity or event.entity
    if not createdEntityCached.valid or createdEntityCached.type ~= "entity-ghost" or UndergroundSegmentEntityNames[createdEntityNonCached.ghost_name] == nil then
        return
    end

    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end

    if not TunnelShared.IsPlacementOnRailGrid(createdEntityNonCached) then
        TunnelShared.UndoInvalidTunnelPartPlacement(createdEntityNonCached, placer, false)
        return
    end
end

-- This is needed so when a player is doing a fast replace by hand the OnPreMinedEntity knows can know its a fast replace and not check mining conflicts or affect the pre_mine. All other scenarios of this triggering do no harm as the beingFastReplaced attribute is either cleared or the object recreated cleanly on the follow on event.
---@param event on_pre_build
Underground.OnPreBuild = function(event)
    local player = game.get_player(event.player_index)
    local player_cursorStack = player.cursor_stack
    if not player_cursorStack.valid or not player_cursorStack.valid_for_read or UndergroundSegmentEntityNames[player_cursorStack.name] == nil then
        return
    end

    local surface = player.surface
    local surfacePositionString = Utils.FormatSurfacePositionToString(surface.index, event.position)
    local segmentPositionObject = global.undergrounds.segmentSurfacePositions[surfacePositionString]
    if segmentPositionObject == nil then
        return
    end

    -- If the direction isn't the same or opposite then this is a rotational fast replace attempt and this isn't a handled fast replace by us.
    local eventDirection = event.direction
    if segmentPositionObject.segment.entity_direction ~= eventDirection and segmentPositionObject.segment.entity_direction ~= Utils.LoopDirectionValue(eventDirection + 4) then
        return
    end

    -- Its a valid fast replace wuithout affecting tunnel and so flag it as such.
    segmentPositionObject.segment.beingFastReplacedTick = event.tick
end

-- Runs when a player mines something, but before its removed from the map. We can't stop the mine, but can get all the details and replace the mined item if the mining should be blocked.
---@param event on_pre_player_mined_item|on_robot_pre_mined
Underground.OnPreMinedEntity = function(event)
    -- Check its one of the entities this function wants to inspect.
    local minedEntity = event.entity
    if not minedEntity.valid or UndergroundSegmentEntityNames[minedEntity.name] == nil then
        return
    end

    -- Check its a successfully built entity. As invalid placements mine the entity and so they don't have a global entry.
    local minedSegment = global.undergrounds.segments[minedEntity.unit_number]
    if minedSegment == nil then
        return
    end

    if minedSegment.beingFastReplacedTick ~= nil and minedSegment.beingFastReplacedTick == event.tick then
        -- Detected that the player has pre_placed an entity at the same spot in the same tick, so the entity is being fast replaced and thus not really mined.
        return
    end

    -- The entity is part of a registered object so we need to check and handle its removal carefully.

    -- If theres above ground crossing rails we need to check these are clear.
    if minedSegment.crossingRailEntities ~= nil then
        for _, railEntity in pairs(minedSegment.crossingRailEntities) do
            if not railEntity.can_be_destroyed() then
                local miner = event.robot -- Will be nil for player mined.
                if miner == nil and event.player_index ~= nil then
                    miner = game.get_player(event.player_index)
                end
                TunnelShared.EntityErrorMessage(miner, {"message.railway_tunnel-crossing_track_mining_blocked_as_in_use"}, minedEntity.surface, minedEntity.position)
                Underground.RestoreSegmentEntity(minedSegment)
                return
            end
        end
    end

    if minedSegment.underground.tunnel == nil then
        -- segment isn't in a tunnel so the entity can always be removed.
        Underground.EntityRemoved(minedSegment)
    else
        if MOD.Interfaces.Tunnel.GetTunnelsUsageEntry(minedSegment.underground.tunnel) then
            -- Theres an in-use tunnel so undo the removal.
            local miner = event.robot -- Will be nil for player mined.
            if miner == nil and event.player_index ~= nil then
                miner = game.get_player(event.player_index)
            end
            TunnelShared.EntityErrorMessage(miner, {"message.railway_tunnel-tunnel_part_mining_blocked_as_in_use"}, minedEntity.surface, minedEntity.position)
            Underground.RestoreSegmentEntity(minedSegment)
        else
            -- Safe to mine the segment.
            Underground.EntityRemoved(minedSegment)
        end
    end
end

-- Restores the removed underground segment entity and destroys the old entity (so it can't be mined and get the item). Then relinks the new entity back in to its object.
---@param minedSegment UndergroundSegment
Underground.RestoreSegmentEntity = function(minedSegment)
    -- Destroy the old entity after caching its values.
    local minedSegmentEntity = minedSegment.entity
    local minedSegmentEntity_lastUser, minedSegmentEntityId = minedSegmentEntity.last_user, minedSegment.id
    minedSegmentEntity.destroy() -- Destroy it so it can't be mined.

    -- Create the new entity and update the old segment object with it.
    local newSegmentEntity = minedSegment.surface.create_entity {name = minedSegment.entity_name, position = minedSegment.entity_position, direction = minedSegment.entity_direction, force = minedSegment.force, player = minedSegmentEntity_lastUser, raise_built = false, create_build_effect_smoke = false}
    newSegmentEntity.rotatable = false
    minedSegment.entity = newSegmentEntity
    minedSegment.id = newSegmentEntity.unit_number

    -- Remove the old globals and add the new ones.
    global.undergrounds.segments[minedSegmentEntityId] = nil
    global.undergrounds.segments[minedSegment.id] = minedSegment

    -- Update the underground.
    local underground = minedSegment.underground
    underground.segments[minedSegmentEntityId] = nil
    underground.segments[minedSegment.id] = minedSegment
    if underground.undergroundEndSegments[minedSegmentEntityId] ~= nil then
        underground.undergroundEndSegments[minedSegmentEntityId] = nil
        underground.undergroundEndSegments[minedSegment.id] = minedSegment
    end
end

-- Called by other functions when a underground segment entity is removed and thus we need to update the underground for this change.
---@param removedSegment UndergroundSegment
---@param killForce? LuaForce|null @ Populated if the entity is being removed due to it being killed, otherwise nil.
---@param killerCauseEntity? LuaEntity|null @ Populated if the entity is being removed due to it being killed, otherwise nil.
Underground.EntityRemoved = function(removedSegment, killForce, killerCauseEntity)
    local removedUnderground = removedSegment.underground

    -- Handle the tunnel if there is one before the underground itself. As the remove tunnel function calls back to its underground and handles/removes underground fields requiring a tunnel.
    if removedUnderground.tunnel then
        MOD.Interfaces.Tunnel.RemoveTunnel(removedUnderground.tunnel, killForce, killerCauseEntity)
    end

    -- Handle the segment object.

    -- Remove anything on the crossing rails and the rails. If this function has been reached any mining checks have already happened.
    if removedSegment.crossingRailEntities ~= nil then
        for _, crossingRailEntity in pairs(removedSegment.crossingRailEntities) do
            if crossingRailEntity.valid then
                Utils.DestroyCarriagesOnRailEntity(crossingRailEntity, killForce, killerCauseEntity, removedSegment.surface)
                if not crossingRailEntity.destroy() then
                    error("removedSegment.crossingRailEntities rail failed to be removed")
                end
            end
        end
    end

    -- These are created with the segment at present, so do here for now.
    if removedSegment.trainBlockerEntity ~= nil then
        removedSegment.trainBlockerEntity.destroy()
    end

    -- Remove the old segment's globals so that the surfacePositions are removed before we re-create the remaining segment's undergrounds.
    global.undergrounds.segments[removedSegment.id] = nil
    global.undergrounds.segmentSurfacePositions[removedSegment.surfacePositionString] = nil
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings[removedSegment.frontInternalSurfacePositionString] = nil
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings[removedSegment.rearInternalSurfacePositionString] = nil

    -- Handle the underground object.
    removedUnderground.segments[removedSegment.id] = nil
    global.undergrounds.undergrounds[removedUnderground.id] = nil

    -- As we don't know the underground's segment makeup we will just disolve the underground and recreate new one(s) by checking each remaining segment. This is a bit crude, but can be reviewed if UPS impactful.
    -- Make each underground segment forget its parent so they are all ready to re-merge in to new undergrounds later.
    for _, loopingUndergroundSegment in pairs(removedUnderground.segments) do
        loopingUndergroundSegment.underground = nil
        loopingUndergroundSegment.nonConnectedExternalSurfacePositions = {}
    end
    -- Loop over each underground segment and add them back in to whatever underground they reform.
    for _, loopingUndergroundSegment in pairs(removedUnderground.segments) do
        Underground.UpdateUndergroundsForNewSegment(loopingUndergroundSegment)
    end
end

-- Called from the Tunnel Manager when a tunnel that the underground was part of has been removed.
---@param underground Underground
Underground.On_TunnelRemoved = function(underground)
    underground.tunnel = nil

    -- Update each segment to reflect the tunnel's been removed.
    for _, segment in pairs(underground.segments) do
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

-- Triggered when a monitored entity type is killed.
---@param event on_entity_died|script_raised_destroy
---@param cachedData UtilityEvents_CachedEventData
Underground.OnDiedEntity = function(event, cachedData)
    -- Check its one of the entities this function wants to inspect.
    local diedEntityCached = cachedData.entity
    local diedEntityNonCached = event.entity
    if not diedEntityCached.valid or UndergroundSegmentEntityNames[diedEntityCached.name] == nil then
        return
    end

    -- Check its a previously successfully built entity. Just incase something destroys the entity before its made a global entry.
    local segment = global.undergrounds.segments[diedEntityNonCached.unit_number]
    if segment == nil then
        return
    end

    Underground.EntityRemoved(segment, event.force, event.cause)
end

return Underground
