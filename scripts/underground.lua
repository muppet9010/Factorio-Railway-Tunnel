local Events = require("utility.events")
local Utils = require("utility.utils")
local TunnelShared = require("scripts.tunnel-shared")
local Common = require("scripts.common")
local UndergroundSegmentEntityNames = Common.UndergroundSegmentEntityNames
local Underground = {}

---@class Underground @ The grouping object for one or more underground segments in a connected sequential row.
---@field id uint @ Unique id of the underground object.
---@field segments table<UnitNumber, UndergroundSegment> @ Segments in the underground. Key'd by the portal end entity unit_number (id).
---@field tilesLength int @ How many tiles this underground is long.
---@field force LuaForce @ The force this underground object belongs to.
---@field surface LuaSurface @ The surface this underground object is on.
---@field undergroundEndSegments UndergroundEndSegmentObject[] @ Objects with details of the segments at the 2 ends of the underground. Updated every time the underground's segments change.
---
---@field tunnel? Tunnel|null @ Ref to tunnel object if this underground is part of one. Only established once this underground is part of a valid tunnel.

---@class UndergroundSegment @ The object attached to a single underground segment's entity, or for a fakeTunnelCrossing segment.
---@field typeData UndergroundSegmentTypeData @ Ref to generic data about this type of segment.
---@field id UnitNumber|Id @ Unit_number of the placed segment entity, or a sequential Id for fakeTunnelCrossing segments.
---@field entity? LuaEntity|null @ The entity for this segment, or Nil for a fakeTunnelCrossing segment.
---@field entity_name? string|null @ Cache of the segment's entity's name, or Nil for a fakeTunnelCrossing segment.
---@field entity_position MapPosition @ Cache of the entity's position.
---@field entity_direction defines.direction @ Cache of the entity's direction.
---@field entity_orientation RealOrientation @ Cache of the entity's orientation.
---@field frontInternalPosition MapPosition @ Used as base to look for other tunnel segments' segmentSurfacePositions global object entries. These are present on each connecting end of the segment 0.5 tile in from its connecting edge center. This is to handle various shapes.
---@field rearInternalPosition MapPosition @ Used as base to look for other tunnel segments' segmentSurfacePositions global object entries. These are present on each connecting end of the segment 0.5 tile in from its connecting edge center. This is to handle various shapes.
---@field frontInternalSurfacePositionString SurfacePositionString @ Cache of the sement's frontInternalPosition as a SurfacePositionString.
---@field rearInternalSurfacePositionString SurfacePositionString @ Cache of the sement's rearInternalPosition as a SurfacePositionString.
---@field frontExternalCheckSurfacePositionString SurfacePositionString @ Cache of the front External Check position used when looking for connected tunnel parts. Is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
---@field rearExternalCheckSurfacePositionString SurfacePositionString @ Cache of the rear External Check position used when looking for connected tunnel parts. Is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
---@field surface LuaSurface @ The surface this segment object is on.
---@field surface_index uint @ Cached index of the surface this segment is on.
---@field force LuaForce @ The force this segment object belongs to.
---@field underground Underground @ Ref to the parent underground object.
---@field surfacePositionString SurfacePositionString @ Used for Fast Replacement to back match to segmentSurfacePositions global object.
---@field beingFastReplacedTick? uint|null @ The tick the segment was marked as being fast replaced or nil.
---@field tilesLength int @ How many tiles this segment is long.
---@field nonConnectedExternalSurfacePositions table<SurfacePositionString, SurfacePositionString> @ A table of this segments non connected external positions to check outside of the entity. Always exists, even if not part of a portal.
---@field builtLayerEntity? LuaEntity|null @ The built layer graphical entity that is showings its picture and hiding the main entities once placed. Is always present regardless of tunnel or not.
---
---@field tunnelRailEntities? table<UnitNumber, LuaEntity>|null @ The invisible rail entities within the tunnel segment that form part of the larger tunnel. Only established once this portal is part of a valid tunnel.
---@field topLayerEntity? LuaEntity|null @ The top layer graphical entity that is showings its picture and hiding the main entities once placed. Only established once this portal is part of a valid tunnel.

---@class StandardUndergroundSegment:UndergroundSegment @ Generic underground segment specific object.
---@field trainBlockerEntity LuaEntity @ The entity that stops you building train carriages on underground tunnel track.

---@class RailCrossingUndergroundSegment:UndergroundSegment @ Rail crossing underground segment specific object.
---@field crossingRailEntities table<UnitNumber, LuaEntity> @ The rail entities that cross the tunnel segment.
---
---@field signalEntities? table<UnitNumber, LuaEntity>|null @ The hidden signal entities within the tunnel segment. Only established once this underground segment is part of a valid tunnel.

---@class TunnelCrossingUndergroundSegment:UndergroundSegment @ Tunnel crossing underground segment specific object.
---@field trainBlockerEntity LuaEntity @ The entity that stops you building train carriages on underground tunnel track.
---@field tunnelCrossingNeighbors uint @ How many tunnel crossing type segments neighbor this segment. As a straight tunnel crossing needs 2 tunnel crossing neighbors to be complete.
---@field tunnelCrossingCompleted boolean @ If the tunnel crossing centered on this segment is complete (has enough valid neighbors).
---@field directFakeCrossingSegment? TunnelCrossingFakeUndergroundSegment|null @ The direct child fake tunnel crossing segment of this real segment. Only exists if this real segment's tunnelCrossingCompleted is TRUE.
---@field supportingFakeCrossingSegments table<Id, TunnelCrossingFakeUndergroundSegment> @ Zero or more fake crossing segments that this segment helps exist by contributing to thier direct parent's real segments tunnelCrossingCompleted. So when this segment is one of the required 3 segments for a segment to be tunnelCrossingCompleted, but no the main center one.
---@field mainArrowRenderId Id @ The Id of the main arrow render if this segment has this render currently. This goes on top of the main built layer graphics and shows the arrow for the tunnel going WITH this real segment.
---@field tunnelCrossingArrowRenderId Id @ The Id of the crossing arrow render if this segment has this render currently. This goes on top of the main built layer graphics and shows the arrow for the tunnel going ACROSS this segment (using fake segment).

---@class TunnelCrossingFakeUndergroundSegment:UndergroundSegment @ A fake tunnel crossing segment that's going across a real Tunnel crossing segment.
---@field directParentTunnelCrossingSegment TunnelCrossingUndergroundSegment @ The real tunnel crossing segment this fake segment is the direct child of. So the ones its centered on and requires to be tunnelCrossingCompleted.
---@field supportingParentTunnelCrossingSegments table<Id, TunnelCrossingUndergroundSegment> @ The real tunnel crossing segments this fake segment is supported by. So the ones that support the direct parent having tunnelCrossingCompleted.

---@class UndergroundEndSegmentObject @ Details of a segment at the end of an underground.
---@field segment UndergroundSegment
---@field externalConnectableSurfacePosition SurfacePositionString @ Where a portal could have its connection position and join to this segment's external entity border connection point.

---@class SegmentSurfacePosition
---@field id SurfacePositionString
---@field segment UndergroundSegment

---@class UndergroundSegmentTypeData @ Generic underground segment type data.
---@field name string
---@field segmentShape UndergroundSegmentShape
---@field segmentType UndergroundSegmentType
---@field tunnelBuiltLayerEntityName? string|null @ The entity to place on top of the real segment entity when its built (no tunnel required). Is used to hide the real segment's graphics once built.
---@field tunnelTopLayerEntityName? string|null @ The entity to place when the tunnel is complete to show the desired completed graphics layer.
---@field tilesLength int @ How many tiles this underground is long.
---@field undergroundTracksPositionOffset UndergroundSegmentTrackPositionOffset[] @ The type of underground track and its position offset from the center of the segment when in a 0 orientation.
---@field frontInternalPositionOffset MapPosition @ Front internal position as an offset from the segments center when orientated north.
---@field rearInternalPositionOffset MapPosition @ Rear internal position as an offset from the segments center when orientated north.

---@class StandardUndergroundSegmentTypeData:UndergroundSegmentTypeData @ Standard specific type data.

---@class RailCrossingUndergroundSegmentTypeData:UndergroundSegmentTypeData @ Rail crossing specific type data.
---@field surfaceCrossingRailsPositionOffset UndergroundSegmentTrackPositionOffset[] @ Details on the rails on the surface that cross this underground segment. May be nil if there are none.

---@class TunnelCrossingUndergroundSegmentTypeData:UndergroundSegmentTypeData @ Tunnel crossing specific type data.

---@class TunnelCrossingFakeUndergroundSegmentTypeData:UndergroundSegmentTypeData @ The type data for the fake tunnel crossing segment type used to go across the real tunnel crossing segment.

---@class UndergroundSegmentShape @ the shape of the segment part.
local SegmentShape = {
    straight = "straight", -- Short straight piece for horizontal and vertical.
    diagonal = "diagonal", -- Short diagonal piece.
    curveStart = "curveStart", -- The start of a curve, so between Straight and Diagonal.
    curveInner = "curveInner" -- The inner part of a curve that connects 2 curveStart's togeather to make a 90 degree corner.
}

---@class UndergroundSegmentType @ The type of the segment part.
local SegmentType = {
    standard = "standard",
    railCrossing = "railCrossing",
    tunnelCrossing = "tunnelCrossing",
    fakeTunnelCrossing = "fakeTunnelCrossing"
}

---@class UndergroundSegmentTrackPositionOffset @ type of track and its position offset from the center of the segment when in a 0 orientation.
---@field trackEntityName string
---@field positionOffset MapPosition
---@field baseDirection defines.direction

---@type UndergroundSegmentTypeData[]
local SegmentTypeData = {
    ---@type UndergroundSegmentTypeData
    ["railway_tunnel-underground_segment-straight"] = {
        name = "railway_tunnel-underground_segment-straight",
        segmentShape = SegmentShape.straight,
        segmentType = SegmentType.standard,
        tunnelBuiltLayerEntityName = nil,
        tunnelTopLayerEntityName = "railway_tunnel-underground_segment-straight-top_layer",
        tilesLength = 2,
        undergroundTracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            }
        },
        frontInternalPositionOffset = {x = 0, y = -0.5},
        rearInternalPositionOffset = {x = 0, y = 0.5}
    },
    ---@type RailCrossingUndergroundSegmentTypeData
    ["railway_tunnel-underground_segment-straight-rail_crossing"] = {
        name = "railway_tunnel-underground_segment-straight-rail_crossing",
        segmentShape = SegmentShape.straight,
        segmentType = SegmentType.railCrossing,
        tunnelBuiltLayerEntityName = nil,
        tunnelTopLayerEntityName = "railway_tunnel-underground_segment-straight-top_layer",
        surfaceCrossingRailsPositionOffset = {
            {
                trackEntityName = "railway_tunnel-crossing_rail-on_map",
                positionOffset = {x = -2, y = 0},
                baseDirection = defines.direction.east
            },
            {
                trackEntityName = "railway_tunnel-crossing_rail-on_map",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.east
            },
            {
                trackEntityName = "railway_tunnel-crossing_rail-on_map",
                positionOffset = {x = 2, y = 0},
                baseDirection = defines.direction.east
            }
        },
        tilesLength = 2,
        undergroundTracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            }
        },
        frontInternalPositionOffset = {x = 0, y = -0.5},
        rearInternalPositionOffset = {x = 0, y = 0.5}
    },
    ---@type TunnelCrossingUndergroundSegmentTypeData
    ["railway_tunnel-underground_segment-straight-tunnel_crossing"] = {
        name = "railway_tunnel-underground_segment-straight-tunnel_crossing",
        segmentShape = SegmentShape.straight,
        segmentType = SegmentType.tunnelCrossing,
        tunnelBuiltLayerEntityName = "railway_tunnel-underground_segment-straight-tunnel_crossing-built_layer",
        tunnelTopLayerEntityName = nil,
        tilesLength = 2,
        undergroundTracksPositionOffset = {
            {
                trackEntityName = "railway_tunnel-invisible_rail-on_map_tunnel",
                positionOffset = {x = 0, y = 0},
                baseDirection = defines.direction.north
            }
        },
        frontInternalPositionOffset = {x = 0, y = -0.5},
        rearInternalPositionOffset = {x = 0, y = 0.5}
    },
    ---@type TunnelCrossingFakeUndergroundSegmentTypeData
    ["railway_tunnel-underground_segment-straight-fake_tunnel_crossing"] = {
        name = "railway_tunnel-underground_segment-straight-fake_tunnel_crossing",
        segmentShape = SegmentShape.straight,
        segmentType = SegmentType.fakeTunnelCrossing,
        tunnelBuiltLayerEntityName = nil,
        tunnelTopLayerEntityName = nil,
        tilesLength = 6,
        undergroundTracksPositionOffset = {
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
        },
        frontInternalPositionOffset = {x = 0, y = -2.5},
        rearInternalPositionOffset = {x = 0, y = 2.5}
    }
}

Underground.CreateGlobals = function()
    global.undergrounds = global.undergrounds or {}
    global.undergrounds.nextUndergroundId = global.undergrounds.nextUndergroundId or 1 ---@type uint
    global.undergrounds.undergrounds = global.undergrounds.undergrounds or {} ---@type table<Id, Underground>
    global.undergrounds.segments = global.undergrounds.segments or {} ---@type table<UnitNumber, UndergroundSegment>
    global.undergrounds.segmentSurfacePositions = global.undergrounds.segmentSurfacePositions or {} ---@type table<SurfacePositionString, SegmentSurfacePosition> @ a lookup for underground segments by their position string.
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings = global.undergrounds.segmentInternalConnectionSurfacePositionStrings or {} ---@type table<SurfacePositionString, SegmentSurfacePosition> @ a lookup for internal positions that underground segments can be connected on. Includes the segment's frontInternalSurfacePositionString and rearInternalSurfacePositionString as keys for lookup.
    global.undergrounds.nextFakeSegmentIdNumber = global.undergrounds.nextFakeSegmentIdNumber or 1 ---@type uint @ Must have a text string added to it so that it can't conflict with unit_numbers of real segments.
end

Underground.OnLoad = function()
    local segmentEntityNames_Filter = {}
    for _, name in pairs(UndergroundSegmentEntityNames) do
        table.insert(segmentEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_pre_build, "Underground.OnPreBuild", Underground.OnPreBuild)

    MOD.Interfaces.Underground = MOD.Interfaces.Underground or {}
    MOD.Interfaces.Underground.On_PreTunnelCompleted = Underground.On_PreTunnelCompleted
    MOD.Interfaces.Underground.On_PostTunnelCompleted = Underground.On_PostTunnelCompleted
    MOD.Interfaces.Underground.On_TunnelRemoved = Underground.On_TunnelRemoved
    MOD.Interfaces.Underground.CanAnUndergroundConnectAtItsInternalPosition = Underground.CanAnUndergroundConnectAtItsInternalPosition
    MOD.Interfaces.Underground.CanUndergroundSegmentConnectToAPortal = Underground.CanUndergroundSegmentConnectToAPortal
    -- Merged event handler interfaces.
    MOD.Interfaces.Underground.UndergroundSegmentBuilt = Underground.UndergroundSegmentBuilt
    MOD.Interfaces.Underground.OnBuiltEntityGhost = Underground.OnBuiltEntityGhost
    MOD.Interfaces.Underground.OnDiedEntity = Underground.OnDiedEntity
    MOD.Interfaces.Underground.OnPreMinedEntity = Underground.OnPreMinedEntity
end

--- Called when an underground segment has been built. Event fitlering is done by calling function.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
---@param builtEntity LuaEntity
---@param builtEntity_name string
---@param segment? UndergroundSegment|null @ An existing segment object that just needs processing. Used to pass in fake tunnel crossing segments as no entity.
Underground.UndergroundSegmentBuilt = function(event, builtEntity, builtEntity_name, segment)
    -- Check the placement is on rail grid, if not then undo the placement and stop.
    if not TunnelShared.IsPlacementOnRailGrid(builtEntity) then
        local placer = Utils.GetActionerFromEvent(event)
        TunnelShared.UndoInvalidTunnelPartPlacement(builtEntity, placer, true)
        return
    end

    local builtEntity_surface, builtEntity_position = builtEntity.surface, builtEntity.position
    local builtEntity_surface_index = builtEntity_surface.index

    -- Make the new base segment object
    local surfacePositionString = Utils.FormatSurfacePositionToString(builtEntity_surface_index, builtEntity_position)
    segment = {
        id = builtEntity.unit_number,
        entity = builtEntity,
        entity_name = builtEntity_name,
        entity_position = builtEntity_position,
        entity_direction = builtEntity.direction,
        entity_orientation = builtEntity.orientation,
        typeData = SegmentTypeData[builtEntity_name],
        surface = builtEntity_surface,
        surface_index = builtEntity_surface_index,
        force = builtEntity.force,
        surfacePositionString = surfacePositionString,
        nonConnectedExternalSurfacePositions = {}
    }
    builtEntity.rotatable = false

    ---@typelist StandardUndergroundSegment, RailCrossingUndergroundSegment, TunnelCrossingUndergroundSegment
    local segment_Standard, segment_RailCrossing, segment_TunnelCrossing = segment, segment, segment

    -- Check if this is a fast replacement and if it is handle eveything special ready for standard built entity function logic later.
    -- No global data should be registered in this function before the checks in the fast replace logic as this MAY reverse the build action.
    local oldFastReplacedSegmentByPosition = global.undergrounds.segmentSurfacePositions[surfacePositionString]
    ---@typelist UndergroundSegment, StandardUndergroundSegment, RailCrossingUndergroundSegment, TunnelCrossingUndergroundSegment
    local oldFastReplacedSegment, oldFastReplacedSegment_Standard, oldFastReplacedSegment_RailCrossing, oldFastReplacedSegment_TunnelCrossing
    local fastReplacedSegmentOfSameType = false
    if oldFastReplacedSegmentByPosition ~= nil then
        -- Was a fast replacement over an existing underground segment of some type.
        oldFastReplacedSegment = oldFastReplacedSegmentByPosition.segment
        oldFastReplacedSegment_Standard, oldFastReplacedSegment_RailCrossing, oldFastReplacedSegment_TunnelCrossing = oldFastReplacedSegment, oldFastReplacedSegment, oldFastReplacedSegment

        -- Check that this is a valid fast replacement. While the current tunnel won't be affected by it, the extras the old segment provided may be in-use currently and so prevent the replacement.
        -- If its not undo its building and restore the origional segment back, then return to stop the processing of this new build.
        if oldFastReplacedSegment.typeData.segmentType == SegmentType.railCrossing then
            -- Check crossing rails can be safely removed.

            -- Check each crossing rail.
            for _, railCrossingTrackEntity in pairs(oldFastReplacedSegment_RailCrossing.crossingRailEntities) do
                if not railCrossingTrackEntity.can_be_destroyed() then
                    -- Put the old correct entity back and correct whats been done.
                    local placer = Utils.GetActionerFromEvent(event)
                    TunnelShared.EntityErrorMessage(placer, {"message.railway_tunnel-crossing_track_fast_replace_blocked_as_in_use"}, surface, oldFastReplacedSegment_RailCrossing.entity_position)
                    oldFastReplacedSegment_RailCrossing.entity = builtEntity -- Update this entity reference temporarily so that the standard replacement function works as expected.
                    Underground.RestoreSegmentEntity(oldFastReplacedSegment_RailCrossing)
                    Utils.GetBuilderInventory(placer).remove({name = oldFastReplacedSegment_RailCrossing.entity_name, count = 1})
                    Utils.GetBuilderInventory(placer).insert({name = builtEntity_name, count = 1})
                    return
                end
            end
        elseif oldFastReplacedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
            -- Check crossing tunnel can be safely removed.

            -- Get a list of all fake segments this real segment indirectly and directly supports.
            local fakeCrossingSegments = Utils.DeepCopy(oldFastReplacedSegment_TunnelCrossing.supportingFakeCrossingSegments)
            if oldFastReplacedSegment_TunnelCrossing.directFakeCrossingSegment ~= nil then
                fakeCrossingSegments[oldFastReplacedSegment_TunnelCrossing.directFakeCrossingSegment.id] = oldFastReplacedSegment_TunnelCrossing.directFakeCrossingSegment
            end

            -- Check each fake segment that's found.
            for _, fakeCrossingSegment in pairs(fakeCrossingSegments) do
                local fakeCrossingTunnelObject = fakeCrossingSegment.underground.tunnel
                if fakeCrossingTunnelObject ~= nil then
                    -- The fake crossing segment has a tunnel that will need checking.
                    if MOD.Interfaces.Tunnel.GetTunnelsUsageEntry(fakeCrossingTunnelObject) then
                        -- The crossing tunnel is in-use so undo the removal.
                        local placer = Utils.GetActionerFromEvent(event)
                        TunnelShared.EntityErrorMessage(placer, {"message.railway_tunnel-crossing_tunnel_fast_replace_blocked_as_in_use"}, oldFastReplacedSegment_TunnelCrossing.surface, oldFastReplacedSegment_TunnelCrossing.entity_position)
                        oldFastReplacedSegment_TunnelCrossing.entity = builtEntity -- Update this entity reference temporarily so that the standard replacement function works as expected.
                        Underground.RestoreSegmentEntity(oldFastReplacedSegment_TunnelCrossing)
                        Utils.GetBuilderInventory(placer).remove({name = oldFastReplacedSegment_TunnelCrossing.entity_name, count = 1})
                        Utils.GetBuilderInventory(placer).insert({name = builtEntity_name, count = 1})
                        return
                    end
                end
            end
        end

        -- Checks complete and so globals can be registered after here.

        -- Claim the generic state data and extras of the old segment.
        segment.nonConnectedExternalSurfacePositions = oldFastReplacedSegment.nonConnectedExternalSurfacePositions
        segment.tunnelRailEntities = oldFastReplacedSegment.tunnelRailEntities
        segment.underground = oldFastReplacedSegment.underground

        -- Remove the extras for the old part being replaced.
        if oldFastReplacedSegment.typeData.segmentType == SegmentType.standard then
            -- Remove the old train blocker entity.
            oldFastReplacedSegment_Standard.trainBlockerEntity.destroy {raise_destroy = false}
        elseif oldFastReplacedSegment.typeData.segmentType == SegmentType.railCrossing then
            -- Remove the old rails.
            for _, railCrossingTrackEntity in pairs(oldFastReplacedSegment_RailCrossing.crossingRailEntities) do
                railCrossingTrackEntity.destroy {raise_destroy = false}
            end
            -- Remove the old crossing track signals if there were any (as only added when part of a tunnel).
            if oldFastReplacedSegment_RailCrossing.signalEntities ~= nil then
                for _, crossingRailSignal in pairs(oldFastReplacedSegment_RailCrossing.signalEntities) do
                    crossingRailSignal.destroy {raise_destroy = false}
                end
            end
        elseif oldFastReplacedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
            -- Remove the old train blocker entity.
            oldFastReplacedSegment_TunnelCrossing.trainBlockerEntity.destroy {raise_destroy = false}

            -- Update the neighboring segments that this tunnel crossing segment is being removed.
            Underground.TunnelCrossingSegmentBuiltOrRemoved(oldFastReplacedSegment_TunnelCrossing, false)

            -- Tidy up the main and crossing arrows.
            if oldFastReplacedSegment_TunnelCrossing.mainArrowRenderId ~= nil then
                rendering.destroy(oldFastReplacedSegment_TunnelCrossing.mainArrowRenderId)
                oldFastReplacedSegment_TunnelCrossing.mainArrowRenderId = nil
            end
            if oldFastReplacedSegment_TunnelCrossing.tunnelCrossingArrowRenderId ~= nil then
                rendering.destroy(oldFastReplacedSegment_TunnelCrossing.tunnelCrossingArrowRenderId)
                oldFastReplacedSegment_TunnelCrossing.tunnelCrossingArrowRenderId = nil
            end
        elseif segment.typeData.segmentType == oldFastReplacedSegment.typeData.segmentType then
            -- Nothing to remove.
        else
            error("unsupported fast replace of new underground segment type over old underground segment type.    New built segment type: " .. segment.typeData.segmentType .. "    Old fast replaced segment type: " .. oldFastReplacedSegment.typeData.segmentType)
        end

        -- Handle any builtLayerEntity that exists.
        if segment.typeData.segmentType == oldFastReplacedSegment.typeData.segmentType then
            -- Is same type so just claim the old one (may or not exist).
            segment.builtLayerEntity = oldFastReplacedSegment.builtLayerEntity
        else
            -- Different segment type so remove the old one if it exists, with the new one bein created as part of regular segment creation later.
            if oldFastReplacedSegment.builtLayerEntity ~= nil then
                oldFastReplacedSegment.builtLayerEntity.destroy {raise_destroy = false}
            end
        end

        -- Add the extras for the new part being placed that won't be added as part of a fresh build of the segment type, i.e. things that depend upon a complete tunnel.
        if segment.typeData.segmentType == SegmentType.railCrossing then
            -- If the segment is part of a tunnel then it should have signals as well already. As these are usually handled as part of a tunnel creation, which may have already happened in this case.
            if segment_RailCrossing.underground ~= nil and segment_RailCrossing.underground.tunnel ~= nil then
                segment_RailCrossing.signalEntities = {}
                Underground.BuildSignalsForSegment(segment_RailCrossing)
            end
        elseif oldFastReplacedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
            -- The hanlding for the new;y placed entity will account for any neighboring segments and arrows. So nothing to do in this specific location.
        elseif segment.typeData.segmentType == oldFastReplacedSegment.typeData.segmentType then
            -- Is a fast replace to the same type so just blindly claim the old segment's type extras. As they won't be removed and recreated to avoid waste.
            fastReplacedSegmentOfSameType = true

            if segment.typeData.segmentType == SegmentType.standard then
                segment_Standard.trainBlockerEntity = oldFastReplacedSegment_Standard.trainBlockerEntity
            elseif segment.typeData.segmentType == SegmentType.railCrossing then
                segment_RailCrossing.crossingRailEntities = oldFastReplacedSegment_RailCrossing.crossingRailEntities
                -- May or not be populated at the time, but this is fine in both cases.
                segment_RailCrossing.signalEntities = oldFastReplacedSegment_RailCrossing.signalEntities
            elseif oldFastReplacedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
                segment_TunnelCrossing.trainBlockerEntity = oldFastReplacedSegment_TunnelCrossing.trainBlockerEntity
                segment_TunnelCrossing.tunnelCrossingNeighbors = oldFastReplacedSegment_TunnelCrossing.tunnelCrossingNeighbors
                segment_TunnelCrossing.tunnelCrossingCompleted = oldFastReplacedSegment_TunnelCrossing.tunnelCrossingCompleted
                segment_TunnelCrossing.directFakeCrossingSegment = oldFastReplacedSegment_TunnelCrossing.directFakeCrossingSegment
                segment_TunnelCrossing.supportingFakeCrossingSegments = oldFastReplacedSegment_TunnelCrossing.supportingFakeCrossingSegments
                for _, supportingFakeCrossingSegment in pairs(segment_TunnelCrossing.supportingFakeCrossingSegments) do
                    supportingFakeCrossingSegment[oldFastReplacedSegment_TunnelCrossing.id] = nil
                    supportingFakeCrossingSegment[segment_TunnelCrossing.id] = segment_TunnelCrossing
                end
                segment_TunnelCrossing.mainArrowRenderId = oldFastReplacedSegment_TunnelCrossing.mainArrowRenderId
                segment_TunnelCrossing.tunnelCrossingArrowRenderId = oldFastReplacedSegment_TunnelCrossing.tunnelCrossingArrowRenderId
            else
                error("Unsupported same type underground segment fast repalced over itself: " .. segment.typeData.segmentType)
            end
        end

        -- Handle the Underground object.
        segment.underground.segments[oldFastReplacedSegment.id] = nil
        segment.underground.segments[segment.id] = segment
        -- Update the underground's list of end segments for any references to the old segment object.
        for _, undergroundEndSegmentObject in pairs(segment.underground.undergroundEndSegments) do
            -- There may be 0, 1 or 2 entries pointing to the replaced segment, so check them all.
            if undergroundEndSegmentObject.segment.id == oldFastReplacedSegment.id then
                undergroundEndSegmentObject.segment = segment
            end
        end

        -- Handle anything that is only present if there is a parent tunnel.
        if segment.underground.tunnel ~= nil then
            -- Update the top layer entity if it needs changing due to change of entity type.
            if not fastReplacedSegmentOfSameType then
                -- Remove the old top layer.
                if oldFastReplacedSegment.topLayerEntity ~= nil and oldFastReplacedSegment.topLayerEntity.valid then
                    oldFastReplacedSegment.topLayerEntity.destroy {raise_destroy = false}
                end

                -- Create the top layer entity that has the desired graphics on it.
                if segment.typeData.tunnelTopLayerEntityName ~= nil then
                    segment.topLayerEntity = segment.surface.create_entity {name = segment.typeData.tunnelTopLayerEntityName, position = segment.entity_position, force = segment.force, direction = segment.entity_direction, raise_built = false, create_build_effect_smoke = false}
                end
            end
        end

        -- Tidy up the old removed segment.
        global.undergrounds.segments[oldFastReplacedSegment.id] = nil
    end

    -- Process the object created for the entity.
    Underground.ProcessNewUndergroundSegmentObject(segment, oldFastReplacedSegment, fastReplacedSegmentOfSameType)
end

--- Called to process a segment object once it has been created.
---@param segment UndergroundSegment
---@param oldFastReplacedSegment? UndergroundSegment|null @ The old segment that has just been fast replaced over IF a fast replacement has occured. If no fast replacement has occured then it's nil.
---@param fastReplacedSegmentOfSameType? boolean|null @ If a fast replacement has occured if it is the same segment type or not. If no fast replacement has occured then it's nil.
Underground.ProcessNewUndergroundSegmentObject = function(segment, oldFastReplacedSegment, fastReplacedSegmentOfSameType)
    ---@typelist StandardUndergroundSegment, RailCrossingUndergroundSegment, TunnelCrossingUndergroundSegment
    local segment_Standard, segment_RailCrossing, segment_TunnelCrossing = segment, segment, segment

    -- Record the connection positions for this segment based on its typeData.
    segment.frontInternalPosition = Utils.RotateOffsetAroundPosition(segment.entity_orientation, segment.typeData.frontInternalPositionOffset, segment.entity_position)
    segment.rearInternalPosition = Utils.RotateOffsetAroundPosition(segment.entity_orientation, segment.typeData.rearInternalPositionOffset, segment.entity_position)
    -- The External Check position is 1 tiles in front of our facing position, so 0.5 tiles outside the entity border.
    segment.frontExternalCheckSurfacePositionString = Utils.FormatSurfacePositionToString(segment.surface_index, Utils.RotateOffsetAroundPosition(segment.entity_orientation, {x = 0, y = -1}, segment.frontInternalPosition))
    segment.rearExternalCheckSurfacePositionString = Utils.FormatSurfacePositionToString(segment.surface_index, Utils.RotateOffsetAroundPosition(segment.entity_orientation, {x = 0, y = 1}, segment.rearInternalPosition))

    -- Register the new segment and its position for fast replace.
    global.undergrounds.segments[segment.id] = segment
    -- On fast replacement it overwrites the old entry as the position strings are identical.
    global.undergrounds.segmentSurfacePositions[segment.surfacePositionString] = {
        id = segment.surfacePositionString,
        segment = segment
    }

    -- Register the segments surfacePositionStrings for connection reverse lookup. On fast replacement it overwrites the old entry as the position strings are identical.
    local frontInternalSurfacePositionString = Utils.FormatSurfacePositionToString(segment.surface_index, segment.frontInternalPosition)
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings[frontInternalSurfacePositionString] = {
        id = frontInternalSurfacePositionString,
        segment = segment
    }
    segment.frontInternalSurfacePositionString = frontInternalSurfacePositionString
    local rearInternalSurfacePositionString = Utils.FormatSurfacePositionToString(segment.surface_index, segment.rearInternalPosition)
    global.undergrounds.segmentInternalConnectionSurfacePositionStrings[rearInternalSurfacePositionString] = {
        id = rearInternalSurfacePositionString,
        segment = segment
    }
    segment.rearInternalSurfacePositionString = rearInternalSurfacePositionString

    -- For fresh new entity and fast replacements to new segment type = add extras.
    if not fastReplacedSegmentOfSameType then
        -- If there's a built entity name for this type then add it.
        if segment.typeData.tunnelBuiltLayerEntityName ~= nil then
            segment.builtLayerEntity = segment.surface.create_entity {name = segment.typeData.tunnelBuiltLayerEntityName, position = segment.entity_position, direction = segment.entity_direction, force = segment.force, raise_built = false, create_build_effect_smoke = false}
            segment.builtLayerEntity.destructible = false
        end

        -- Type specific extras to add.
        if segment.typeData.segmentType == SegmentType.standard then
            -- Add the train blocker entity.
            segment_Standard.trainBlockerEntity = segment_Standard.surface.create_entity {name = "railway_tunnel-train_blocker_2x2", position = segment_Standard.entity_position, force = segment_Standard.force, raise_built = false, create_build_effect_smoke = false}
        elseif segment.typeData.segmentType == SegmentType.railCrossing then
            local railCrossingSegmentTypeData = segment_RailCrossing.typeData ---@type RailCrossingUndergroundSegmentTypeData

            -- Add the crossing rails.
            segment_RailCrossing.crossingRailEntities = {}
            for _, railPositionOffset in pairs(railCrossingSegmentTypeData.surfaceCrossingRailsPositionOffset) do
                local railPos = Utils.RotateOffsetAroundPosition(segment_RailCrossing.entity_orientation, railPositionOffset.positionOffset, segment_RailCrossing.entity_position)
                local placedRail = segment_RailCrossing.surface.create_entity {name = railPositionOffset.trackEntityName, position = railPos, force = segment_RailCrossing.force, direction = Utils.RotateDirectionByDirection(railPositionOffset.baseDirection, defines.direction.north, segment_RailCrossing.entity_direction), raise_built = false, create_build_effect_smoke = false}
                placedRail.destructible = false
                segment_RailCrossing.crossingRailEntities[placedRail.unit_number] = placedRail
            end
        elseif segment.typeData.segmentType == SegmentType.tunnelCrossing then
            -- Add the train blocker entity.
            segment_TunnelCrossing.trainBlockerEntity = segment_TunnelCrossing.surface.create_entity {name = "railway_tunnel-train_blocker_2x2", position = segment_TunnelCrossing.entity_position, force = segment_TunnelCrossing.force, raise_built = false, create_build_effect_smoke = false}

            -- Add the default values for tunnel crossing segment.
            segment_TunnelCrossing.tunnelCrossingNeighbors = 0
            segment_TunnelCrossing.tunnelCrossingCompleted = false
            segment_TunnelCrossing.supportingFakeCrossingSegments = {}

            -- Check the neighboring segments for other tunnel crossing type segments.
            Underground.TunnelCrossingSegmentBuiltOrRemoved(segment_TunnelCrossing, true)
        elseif segment.typeData.segmentType == SegmentType.fakeTunnelCrossing then
            -- Nothing needs creating for a fake tunnel crossing.
        else
            error("Unsupported segment type being built: " .. segment.typeData.segmentType)
        end
    end

    -- Do post activities based on if new segment or fast replacemet.
    if oldFastReplacedSegment == nil then
        -- New segments check if they complete the tunnel and handle approperiately.
        Underground.UpdateUndergroundsForNewSegment(segment)
        Underground.CheckAndHandleTunnelCompleteFromUnderground(segment.underground)

        -- Update the main and crossing arrows as required. Must be done after underground neighbors are processed.
        if segment.typeData.segmentType == SegmentType.tunnelCrossing then
            Underground.TunnelCrossingSegment_MainTunnelChanged(segment_TunnelCrossing)
            Underground.TunnelCrossingSegment_CrossingTunnelChanged(segment_TunnelCrossing)
        end
    else
        -- Was fast replacement and some activities require the segment objects creation to have been completed before being processes.

        -- Update the main and crossing arrows as required.
        if segment.typeData.segmentType == SegmentType.tunnelCrossing then
            Underground.TunnelCrossingSegment_MainTunnelChanged(segment_TunnelCrossing)
            Underground.TunnelCrossingSegment_CrossingTunnelChanged(segment_TunnelCrossing)
        end
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

--- Called when a tunnel crossing segment type has been built or removed (new or fast replaced). Checks for neighbors and updates any tunnel crossings as required.
---@param tunnelCrossingSegment TunnelCrossingUndergroundSegment
---@param beingBuilt boolean @ TRUE if the segment is being built, FALSE if its being removed.
Underground.TunnelCrossingSegmentBuiltOrRemoved = function(tunnelCrossingSegment, beingBuilt)
    -- Check for neighbouring tunnel crossing segment types.
    -- Look in the global internal position string list for any segment that is where our external check position is.

    local modifierValue
    if beingBuilt then
        modifierValue = 1
    else
        modifierValue = -1
    end

    -- Check the front connection of this segment.
    local frontSegmentPositionObject = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[tunnelCrossingSegment.frontExternalCheckSurfacePositionString]
    if frontSegmentPositionObject ~= nil then
        local frontConnectedSegment = frontSegmentPositionObject.segment
        if frontConnectedSegment ~= nil and frontConnectedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
            tunnelCrossingSegment.tunnelCrossingNeighbors = tunnelCrossingSegment.tunnelCrossingNeighbors + modifierValue
            frontConnectedSegment.tunnelCrossingNeighbors = frontConnectedSegment.tunnelCrossingNeighbors + modifierValue
            Underground.TunnelCrossingSegmentsNeighborsUpdated(frontConnectedSegment)
        end
    end

    -- Check the rear connection of this segment.
    local rearSegmentPositionObject = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[tunnelCrossingSegment.rearExternalCheckSurfacePositionString]
    if rearSegmentPositionObject ~= nil then
        local rearConnectedSegment = rearSegmentPositionObject.segment
        if rearConnectedSegment ~= nil and rearConnectedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
            tunnelCrossingSegment.tunnelCrossingNeighbors = tunnelCrossingSegment.tunnelCrossingNeighbors + modifierValue
            rearConnectedSegment.tunnelCrossingNeighbors = rearConnectedSegment.tunnelCrossingNeighbors + modifierValue
            Underground.TunnelCrossingSegmentsNeighborsUpdated(rearConnectedSegment)
        end
    end

    Underground.TunnelCrossingSegmentsNeighborsUpdated(tunnelCrossingSegment)
end

--- Called when a tunnel crossing segment type has had its neighbors updated. Can be for when
---@param tunnelCrossingSegment TunnelCrossingUndergroundSegment
Underground.TunnelCrossingSegmentsNeighborsUpdated = function(tunnelCrossingSegment)
    -- Check this segments neighbor count and react based on old and new state.
    if tunnelCrossingSegment.tunnelCrossingNeighbors == 2 then
        -- This tunnel crossing is complete.
        if not tunnelCrossingSegment.tunnelCrossingCompleted then
            -- Tunnel crossing has just been completed fresh.
            tunnelCrossingSegment.tunnelCrossingCompleted = true
            Underground.TunnelCrossingSegment_OnCompletedTunnel(tunnelCrossingSegment)
        else
            -- Tunnel crossing was already complete.
        end
    else
        -- This tunnel crossing isn't complete.
        if tunnelCrossingSegment.tunnelCrossingCompleted then
            -- Tunnel crossing was complete, but isn't now so handle its downgrade.
            tunnelCrossingSegment.tunnelCrossingCompleted = false
            Underground.TunnelCrossingSegment_OnRemovedTunnel(tunnelCrossingSegment)
        else
            -- Tunnel crossing wasn't completed before and still isn't.
        end
    end
end

--- Called when a real tunnel crossing has just been completed initially. Triggers creation of the fake crossing segment.
---@param thisTunnelCrossingSegment TunnelCrossingUndergroundSegment
Underground.TunnelCrossingSegment_OnCompletedTunnel = function(thisTunnelCrossingSegment)
    -- Get this segments neighbors. They must exist and be tunnel crossing type segments to reach this function.
    local frontConnectedSegment = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[thisTunnelCrossingSegment.frontExternalCheckSurfacePositionString].segment ---@type TunnelCrossingUndergroundSegment
    local rearConnectedSegment = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[thisTunnelCrossingSegment.rearExternalCheckSurfacePositionString].segment ---@type TunnelCrossingUndergroundSegment

    -- Create the fake crossing segment for this real segment.
    ---@type TunnelCrossingFakeUndergroundSegment
    local fakeSegment = {
        id = SegmentType.fakeTunnelCrossing .. "-" .. global.undergrounds.nextFakeSegmentIdNumber,
        entity = nil,
        entity_name = nil,
        entity_position = thisTunnelCrossingSegment.entity_position,
        entity_direction = Utils.LoopDirectionValue(thisTunnelCrossingSegment.entity_direction + 2), -- Rotate to be across the real segment.
        entity_orientation = Utils.LoopOrientationValue(thisTunnelCrossingSegment.entity_orientation + 0.25), -- Rotate to be across the real segment.
        typeData = SegmentTypeData["railway_tunnel-underground_segment-straight-fake_tunnel_crossing"],
        surface = thisTunnelCrossingSegment.surface,
        surface_index = thisTunnelCrossingSegment.surface_index,
        force = thisTunnelCrossingSegment.force,
        surfacePositionString = thisTunnelCrossingSegment.surfacePositionString .. ".1", -- Add a .1 on to the end of the surface position. So its basically in the right place, but won't over write the real segments surfacePositionString global. It's only used for lookup when mining and fast replacement which can't be done to a fake segment, so doesn't matter it will ever be found.
        nonConnectedExternalSurfacePositions = {}
    }
    global.undergrounds.nextFakeSegmentIdNumber = global.undergrounds.nextFakeSegmentIdNumber + 1

    -- Update the direct parent/child relationship for the fake and real segment objects.
    fakeSegment.directParentTunnelCrossingSegment = thisTunnelCrossingSegment
    thisTunnelCrossingSegment.directFakeCrossingSegment = fakeSegment

    -- Update the neighboring real segments so they know they are contributing to the fake segment and the fake segment to know its supporting parents.
    frontConnectedSegment.supportingFakeCrossingSegments[fakeSegment.id] = fakeSegment
    rearConnectedSegment.supportingFakeCrossingSegments[fakeSegment.id] = fakeSegment
    fakeSegment.supportingParentTunnelCrossingSegments = {
        [frontConnectedSegment.id] = frontConnectedSegment,
        [rearConnectedSegment.id] = rearConnectedSegment
    }

    -- Process the newly crated fake segment so it joins to its neighbors just like any other segment.
    Underground.ProcessNewUndergroundSegmentObject(fakeSegment, nil, nil)
end

--- Called when a real tunnel crossing has just been broken. Removes the fake crossing segment.
---@param thisTunnelCrossingSegment TunnelCrossingUndergroundSegment
Underground.TunnelCrossingSegment_OnRemovedTunnel = function(thisTunnelCrossingSegment)
    -- Get this segments neighbors. They must exist and be tunnel crossing type segments to reach this function.
    local frontConnectedSegment = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[thisTunnelCrossingSegment.frontExternalCheckSurfacePositionString].segment ---@type TunnelCrossingUndergroundSegment
    local rearConnectedSegment = global.undergrounds.segmentInternalConnectionSurfacePositionStrings[thisTunnelCrossingSegment.rearExternalCheckSurfacePositionString].segment ---@type TunnelCrossingUndergroundSegment
    local fakeSegment = thisTunnelCrossingSegment.directFakeCrossingSegment

    -- Update the direct child relationship for the removal of the fake segment object.
    thisTunnelCrossingSegment.directFakeCrossingSegment = nil

    -- Update the neighboring real segments so they know the fake segment they were contributing to is gone.
    frontConnectedSegment.supportingFakeCrossingSegments[fakeSegment.id] = nil
    rearConnectedSegment.supportingFakeCrossingSegments[fakeSegment.id] = nil

    -- Remove the fake segment object (this will trigger crossing tunnel to fire On_TunnelRemoved).
    Underground.EntityRemoved(fakeSegment, nil, nil)
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

--- Checks if an underground segment can connect at a free internal connection position. If it can it returns the objects, otherwise nil for all.
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
        Underground.BuildUndergroundRailForSegment(segment)

        -- Add signals to the underground tunnel rail for the segments with crossing rails only.
        if segment.typeData.segmentType == SegmentType.railCrossing then
            local segment_RailCrossing = segment ---@type RailCrossingUndergroundSegment
            segment_RailCrossing.signalEntities = {}
            Underground.BuildSignalsForSegment(segment_RailCrossing)
        end

        -- Create the top layer entity that has the desired graphics on it.
        local tunnelTopLayerEntityName = segment.typeData.tunnelTopLayerEntityName
        if tunnelTopLayerEntityName ~= nil then
            segment.topLayerEntity = segment.surface.create_entity {name = tunnelTopLayerEntityName, position = segment.entity_position, force = segment.force, direction = segment.entity_direction, raise_built = false, create_build_effect_smoke = false}
        end
    end
end

-- Registers and sets up the underground prior to the tunnel object being created and references created.
---@param underground Underground
Underground.On_PostTunnelCompleted = function(underground)
    for _, segment in pairs(underground.segments) do
        -- For real and fake Tunnel Crossing segments ensure the crossing rail arrow is correct for current state.
        if segment.typeData.segmentType == SegmentType.tunnelCrossing then
            Underground.TunnelCrossingSegment_MainTunnelChanged(segment)
        elseif segment.typeData.segmentType == SegmentType.fakeTunnelCrossing then
            local segment_FakeTunnelCrossing = segment ---@type TunnelCrossingFakeUndergroundSegment
            Underground.TunnelCrossingSegment_CrossingTunnelChanged(segment_FakeTunnelCrossing.directParentTunnelCrossingSegment)
            for _, supportingTunnelCrossingSegment in pairs(segment_FakeTunnelCrossing.supportingParentTunnelCrossingSegments) do
                Underground.TunnelCrossingSegment_CrossingTunnelChanged(supportingTunnelCrossingSegment)
            end
        end
    end
end

-- Add the rails to the an underground segment.
---@param segment UndergroundSegment
Underground.BuildUndergroundRailForSegment = function(segment)
    segment.tunnelRailEntities = {}
    for _, trackPositionOffset in pairs(segment.typeData.undergroundTracksPositionOffset) do
        local railPos = Utils.RotateOffsetAroundPosition(segment.entity_orientation, trackPositionOffset.positionOffset, segment.entity_position)
        local placedRail = segment.surface.create_entity {name = trackPositionOffset.trackEntityName, position = railPos, force = segment.force, direction = Utils.RotateDirectionByDirection(trackPositionOffset.baseDirection, defines.direction.north, segment.entity_direction), raise_built = false, create_build_effect_smoke = false}
        placedRail.destructible = false
        segment.tunnelRailEntities[placedRail.unit_number] = placedRail
    end
end

--- Builds crossing rail signals for the segment and caches them to the segment
---@param segment_RailCrossing RailCrossingUndergroundSegment
Underground.BuildSignalsForSegment = function(segment_RailCrossing)
    for _, orientationModifier in pairs({0, 4}) do
        local signalDirection = Utils.LoopDirectionValue(segment_RailCrossing.entity_direction + orientationModifier)
        local orientation = signalDirection / 8
        local position = Utils.RotateOffsetAroundPosition(orientation, {x = -1.5, y = 0}, segment_RailCrossing.entity_position)
        local placedSignal = segment_RailCrossing.surface.create_entity {name = "railway_tunnel-invisible_signal-not_on_map", position = position, force = segment_RailCrossing.force, direction = signalDirection, raise_built = false, create_build_effect_smoke = false}
        segment_RailCrossing.signalEntities[placedSignal.unit_number] = placedSignal
    end
end

-- If the built entity was a ghost of an underground segment then check it is on the rail grid.
---@param event on_built_entity|on_robot_built_entity|script_raised_built
---@param createdEntity LuaEntity
Underground.OnBuiltEntityGhost = function(event, createdEntity)
    -- If the ghost was on grid then nothing needs to be done.
    if not TunnelShared.IsPlacementOnRailGrid(createdEntity) then
        local placer = Utils.GetActionerFromEvent(event)
        TunnelShared.UndoInvalidTunnelPartPlacement(createdEntity, placer, false)
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

    -- Its a valid fast replace without affecting tunnel and so flag it as such.
    segmentPositionObject.segment.beingFastReplacedTick = event.tick
end

-- Runs when a player mines something, but before its removed from the map. If the mine should be blocked we destroy the entity before it can be mined, causing the mine to fail. We get all the details of the entity and replace it plus show the user a message, so it appears as if e blocked the mining.
---@param event on_pre_player_mined_item|on_robot_pre_mined
---@param minedEntity LuaEntity
Underground.OnPreMinedEntity = function(event, minedEntity)
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

    -- Segment type specific checks.
    if minedSegment.typeData.segmentType == SegmentType.railCrossing then
        -- If there's above ground crossing rails we need to check these are clear.
        local minedSegment_RailCrossing = minedSegment ---@type RailCrossingUndergroundSegment
        for _, railCrossingTrackEntity in pairs(minedSegment_RailCrossing.crossingRailEntities) do
            if not railCrossingTrackEntity.can_be_destroyed() then
                local miner = Utils.GetActionerFromEvent(event)
                TunnelShared.EntityErrorMessage(miner, {"message.railway_tunnel-crossing_track_mining_blocked_as_in_use"}, minedSegment_RailCrossing.surface, minedSegment_RailCrossing.entity_position)
                Underground.RestoreSegmentEntity(minedSegment_RailCrossing)
                return
            end
        end
    elseif minedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
        -- If there's a fake tunnel crossing segment related to this real segment we need to check this. This function will check this real segment's own tunnel if present later.
        local minedSegment_TunnelCrossing = minedSegment ---@type TunnelCrossingUndergroundSegment

        -- Get a list of all fake segments this real segment indirectly and directly supports.
        local fakeCrossingSegments = Utils.DeepCopy(minedSegment_TunnelCrossing.supportingFakeCrossingSegments)
        if minedSegment_TunnelCrossing.directFakeCrossingSegment ~= nil then
            fakeCrossingSegments[minedSegment_TunnelCrossing.directFakeCrossingSegment.id] = minedSegment_TunnelCrossing.directFakeCrossingSegment
        end

        -- Check each fake segment that's found.
        for _, fakeCrossingSegment in pairs(fakeCrossingSegments) do
            local fakeCrossingTunnelObject = fakeCrossingSegment.underground.tunnel
            if fakeCrossingTunnelObject ~= nil then
                -- The fake crossing segment has a tunnel that will need checking.
                if MOD.Interfaces.Tunnel.GetTunnelsUsageEntry(fakeCrossingTunnelObject) then
                    -- The crossing tunnel is in-use so undo the removal.
                    local miner = Utils.GetActionerFromEvent(event)
                    TunnelShared.EntityErrorMessage(miner, {"message.railway_tunnel-tunnel_part_mining_blocked_as_crossing_tunnel_in_use"}, minedSegment_TunnelCrossing.surface, minedSegment_TunnelCrossing.entity_position)
                    Underground.RestoreSegmentEntity(minedSegment)
                    return
                end
            end
        end
    end

    -- Generic checks before the entity can be removed.
    if minedSegment.underground.tunnel == nil then
        -- segment isn't in a tunnel so the entity can always be removed.
        Underground.EntityRemoved(minedSegment)
    else
        if MOD.Interfaces.Tunnel.GetTunnelsUsageEntry(minedSegment.underground.tunnel) then
            -- The main tunnel is in-use so undo the removal.
            local miner = Utils.GetActionerFromEvent(event)
            TunnelShared.EntityErrorMessage(miner, {"message.railway_tunnel-tunnel_part_mining_blocked_as_tunnel_in_use"}, minedSegment.surface, minedSegment.entity_position)
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
    minedSegmentEntity.destroy {raise_destroy = false} -- Destroy it so it can't be mined.

    -- Create the new entity and update the old segment object with it.
    local newSegmentEntity = minedSegment.surface.create_entity {name = minedSegment.entity_name, position = minedSegment.entity_position, direction = minedSegment.entity_direction, force = minedSegment.force, player = minedSegmentEntity_lastUser, raise_built = false, create_build_effect_smoke = false}
    newSegmentEntity.rotatable = false
    minedSegment.entity = newSegmentEntity
    minedSegment.id = newSegmentEntity.unit_number

    -- Remove the old globals and add the new ones as they reference by Id which will have changed.
    global.undergrounds.segments[minedSegmentEntityId] = nil
    global.undergrounds.segments[minedSegment.id] = minedSegment

    -- Update the underground as it references the segment via Id which will have changed.
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

    -- Remove a built layer entity if it exists.
    if removedSegment.builtLayerEntity ~= nil then
        removedSegment.builtLayerEntity.destroy {raise_destroy = false}
    end

    -- The standard extras the object had created without needing to be part of a tunnel need removing.
    if removedSegment.typeData.segmentType == SegmentType.standard then
        local removedSegment_Standard = removedSegment ---@type StandardUndergroundSegment
        removedSegment_Standard.trainBlockerEntity.destroy {raise_destroy = false}
    elseif removedSegment.typeData.segmentType == SegmentType.railCrossing then
        -- Remove anything on the crossing rails and the rails. If this function has been reached any mining checks have already happened.
        local removedSegment_RailCrossing = removedSegment ---@type RailCrossingUndergroundSegment
        for _, crossingRailEntity in pairs(removedSegment_RailCrossing.crossingRailEntities) do
            if crossingRailEntity.valid then
                Utils.DestroyCarriagesOnRailEntity(crossingRailEntity, killForce, killerCauseEntity, removedSegment_RailCrossing.surface)
                if not crossingRailEntity.destroy {raise_destroy = false} then
                    error("removedSegment.crossingRailEntities rail failed to be removed")
                end
            end
        end
    elseif removedSegment.typeData.segmentType == SegmentType.tunnelCrossing then
        local removedSegment_TunnelCrossing = removedSegment ---@type TunnelCrossingUndergroundSegment

        -- Remove the train blocker.
        removedSegment_TunnelCrossing.trainBlockerEntity.destroy {raise_destroy = false}

        -- Check the neighboring segments for other tunnel crossing type segments.
        Underground.TunnelCrossingSegmentBuiltOrRemoved(removedSegment_TunnelCrossing, false)

        -- Tidy up the main and crossing arrows.
        if removedSegment_TunnelCrossing.mainArrowRenderId ~= nil then
            rendering.destroy(removedSegment_TunnelCrossing.mainArrowRenderId)
            removedSegment_TunnelCrossing.mainArrowRenderId = nil
        end
        if removedSegment_TunnelCrossing.tunnelCrossingArrowRenderId ~= nil then
            rendering.destroy(removedSegment_TunnelCrossing.tunnelCrossingArrowRenderId)
            removedSegment_TunnelCrossing.tunnelCrossingArrowRenderId = nil
        end
    elseif removedSegment.typeData.segmentType == SegmentType.fakeTunnelCrossing then
        -- Fake segment doesn't have anything so nothing to remove.
    else
        error("Unsupported segment type being removed: " .. removedSegment.typeData.segmentType)
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
    -- Make each underground segment forget its parent and relevent state data so they are all ready to re-merge in to new undergrounds later.
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
                railEntity.destroy {raise_destroy = false}
            end
        end
        segment.tunnelRailEntities = nil

        if segment.typeData.segmentType == SegmentType.railCrossing then
            local segment_RailCrossing = segment ---@type RailCrossingUndergroundSegment
            for _, signalEntity in pairs(segment_RailCrossing.signalEntities) do
                if signalEntity.valid then
                    signalEntity.destroy {raise_destroy = false}
                end
            end
            segment_RailCrossing.signalEntities = nil
        elseif segment.typeData.segmentType == SegmentType.tunnelCrossing then
            Underground.TunnelCrossingSegment_MainTunnelChanged(segment)
        elseif segment.typeData.segmentType == SegmentType.fakeTunnelCrossing then
            local segment_FakeTunnelCrossing = segment ---@type TunnelCrossingFakeUndergroundSegment
            Underground.TunnelCrossingSegment_CrossingTunnelChanged(segment_FakeTunnelCrossing.directParentTunnelCrossingSegment)
            for _, supportingTunnelCrossingSegment in pairs(segment_FakeTunnelCrossing.supportingParentTunnelCrossingSegments) do
                Underground.TunnelCrossingSegment_CrossingTunnelChanged(supportingTunnelCrossingSegment)
            end
        end

        if segment.topLayerEntity ~= nil and segment.topLayerEntity.valid then
            segment.topLayerEntity.destroy {raise_destroy = false}
        end
        segment.topLayerEntity = nil
    end
end

--- Called by a main tunnel that uses a tunnel crossing segment when it is created/removed. Manages the main tunnel arrow on this real segment.
---@param tunnelCrossingSegment TunnelCrossingUndergroundSegment
Underground.TunnelCrossingSegment_MainTunnelChanged = function(tunnelCrossingSegment)
    -- If the segment's main tunnel is incomplete then there should be an arrow.
    if tunnelCrossingSegment.underground.tunnel == nil then
        -- Should be an arrow, add one if missing.
        if tunnelCrossingSegment.mainArrowRenderId == nil then
            tunnelCrossingSegment.mainArrowRenderId =
                rendering.draw_sprite {
                sprite = "railway_tunnel-underground_segment-straight-tunnel_crossing-main_arrow",
                render_layer = 27, -- One layer above the tile transition layer that the tunnelTopLayerEntityName uses.
                target = tunnelCrossingSegment.entity_position,
                orientation = tunnelCrossingSegment.entity_orientation,
                surface = tunnelCrossingSegment.surface
            }
        end
    else
        -- Shouldn't be an arrow, remove it if present.
        if tunnelCrossingSegment.mainArrowRenderId ~= nil then
            rendering.destroy(tunnelCrossingSegment.mainArrowRenderId)
            tunnelCrossingSegment.mainArrowRenderId = nil
        end
    end
end

--- Called by a crossing tunnel that uses a tunnel crossing segment when it is created/removed. Manages the crossing tunnel arrow on this real segment.
---@param tunnelCrossingSegment TunnelCrossingUndergroundSegment
Underground.TunnelCrossingSegment_CrossingTunnelChanged = function(tunnelCrossingSegment)
    -- If there's a non complete tunnel going across this segment draw the crossing arrow.
    local drawCrossingArrow = true
    if tunnelCrossingSegment.directFakeCrossingSegment ~= nil and tunnelCrossingSegment.directFakeCrossingSegment.underground.tunnel ~= nil then
        -- Is a crossing tunnel on the direct fake segment so don't draw an arrow.
        drawCrossingArrow = false
    end
    for _, supportingFakeCrossingSegment in pairs(tunnelCrossingSegment.supportingFakeCrossingSegments) do
        if supportingFakeCrossingSegment.underground.tunnel ~= nil then
            -- Is a crossing tunnel on a supported fake segment so don't draw an arrow.
            drawCrossingArrow = false
        end
    end
    if drawCrossingArrow then
        -- Should be a crossing arrow so add one if it doesn't exist.
        if tunnelCrossingSegment.tunnelCrossingArrowRenderId == nil then
            tunnelCrossingSegment.tunnelCrossingArrowRenderId =
                rendering.draw_sprite {
                sprite = "railway_tunnel-underground_segment-straight-tunnel_crossing-crossing_arrow",
                render_layer = 27, -- One layer above the tile transition layer that the tunnelTopLayerEntityName uses.
                target = tunnelCrossingSegment.entity_position,
                orientation = tunnelCrossingSegment.entity_orientation,
                surface = tunnelCrossingSegment.surface
            }
        end
    else
        -- Shouldn't be a crossing arrow so remove it if it exists.
        if tunnelCrossingSegment.tunnelCrossingArrowRenderId ~= nil then
            rendering.destroy(tunnelCrossingSegment.tunnelCrossingArrowRenderId)
            tunnelCrossingSegment.tunnelCrossingArrowRenderId = nil
        end
    end
end

-- Triggered when a monitored entity type is killed.
---@param event on_entity_died|script_raised_destroy
---@param diedEntity LuaEntity
Underground.OnDiedEntity = function(event, diedEntity)
    -- Check its a previously successfully built entity. Just incase something destroys the entity before its made a global entry.
    local segment = global.undergrounds.segments[diedEntity.unit_number]
    if segment == nil then
        return
    end

    Underground.EntityRemoved(segment, event.force, event.cause)
end

return Underground
