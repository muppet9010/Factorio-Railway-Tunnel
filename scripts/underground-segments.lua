local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelShared = require("scripts/tunnel-shared")
local Common = require("scripts/common")
local UndergroundSegmentEntityNames = Common.UndergroundSegmentEntityNames
local UndergroundSegments = {}

---@class Segment
---@field id UnitNumber @unit_number of the placed segment entity.
---@field entity LuaEntity
---@field tunnelRailEntities table<UnitNumber, LuaEntity> @the invisible rail entities within the tunnel segment that form part of the larger tunnel.
---@field signalEntities table<UnitNumber, LuaEntity> @the hidden signal entities within the tunnel segment.
---@field tunnel Tunnel
---@field crossingRailEntities table<UnitNumber, LuaEntity> @the rail entities that cross the tunnel segment. Table only exists for entity type of "underground_segment-rail_crossing".
---@field surfacePositionString SurfacePositionString @used to back match to surfaceSegmentPositions global object.
---@field beingFastReplacedTick uint @the tick the segment was marked as being fast replaced or nil.
---@field trainBlockerEntity LuaEntity @the "railway_tunnel-train_blocker_2x2" entity of this tunnel segment if it has one currently.
---@field topLayerEntity LuaEntity @the top layer graphical entity that is showings its picture and hiding the main entities once placed.

---@class SurfacePositionString @the entities surface and position as a string.

---@class SurfaceSegmentPosition
---@field id SurfacePositionString
---@field segment Segment

---@alias FastReplaceChange "'downgrade'"|"'upgrade'"|"'same'"

local UndergroundSegmentTypeData = {
    ["railway_tunnel-underground_segment-straight"] = {
        entityName = "railway_tunnel-underground_segment-straight",
        baseType = "railway_tunnel-underground_segment-straight",
        topLayerEntityName = "railway_tunnel-underground_segment-straight-top_layer",
        placeCrossingRails = false
    },
    ["railway_tunnel-underground_segment-straight-rail_crossing"] = {
        entityName = "railway_tunnel-underground_segment-straight-rail_crossing",
        baseType = "railway_tunnel-underground_segment-straight",
        topLayerEntityName = nil,
        placeCrossingRails = true
    }
}

UndergroundSegments.CreateGlobals = function()
    global.undergroundSegments = global.undergroundSegments or {}
    global.undergroundSegments.segments = global.undergroundSegments.segments or {} ---@type table<Id, Segment>
    global.undergroundSegments.surfaceSegmentPositions = global.undergroundSegments.surfaceSegmentPositions or {} ---@type table<Id, SurfaceSegmentPosition>
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
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive
UndergroundSegments.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or UndergroundSegmentEntityNames[createdEntity.name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    UndergroundSegments.UndergroundSegmentBuilt(createdEntity, placer)
end

---@param builtEntity LuaEntity
---@param placer EntityActioner
---@return boolean
UndergroundSegments.UndergroundSegmentBuilt = function(builtEntity, placer)
    local centerPos, force, lastUser, directionValue, surface, builtEntityName = builtEntity.position, builtEntity.force, builtEntity.last_user, builtEntity.direction, builtEntity.surface, builtEntity.name

    -- Check the placement is on rail grid, if not then undo the placement and stop.
    if not TunnelShared.IsPlacementOnRailGrid(builtEntity) then
        TunnelShared.UndoInvalidTunnelPartPlacement(builtEntity, placer, true)
        return
    end

    local builtSegmentTypeData = UndergroundSegmentTypeData[builtEntityName]
    local placeCrossingRails = builtSegmentTypeData.placeCrossingRails

    -- Check if this is a fast replacement or not.
    local surfacePositionString = Utils.FormatSurfacePositionTableToString(surface.index, centerPos)
    local fastReplacedSegmentByPosition = global.undergroundSegments.surfaceSegmentPositions[surfacePositionString]
    ---@typelist Segment, FastReplaceChange
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
                TunnelShared.EntityErrorMessage(placer, "Can not fast replace crossing rail tunnel segment while train is on crossing track", surface, centerPos)
                local oldId = fastReplacedSegment.id
                builtEntity.destroy()
                fastReplacedSegment.entity = surface.create_entity {name = "railway_tunnel-underground_segment-straight-rail_crossing", position = centerPos, direction = directionValue, force = force, player = lastUser}
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

    ---@type Segment
    local segment = {
        id = builtEntity.unit_number,
        entity = builtEntity,
        surfacePositionString = surfacePositionString
    }

    -- If it's a fast replace and there is a type change then remove the old bits first.
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
            segment.crossingRailEntities = {}
            local crossignRailDirection, orientation = Utils.LoopDirectionValue(directionValue + 2), Utils.DirectionToOrientation(directionValue)
            for _, nextRailPos in pairs(
                {
                    Utils.ApplyOffsetToPosition(builtEntity.position, Utils.RotatePositionAround0(orientation, {x = -2, y = 0})),
                    builtEntity.position,
                    Utils.ApplyOffsetToPosition(builtEntity.position, Utils.RotatePositionAround0(orientation, {x = 2, y = 0}))
                }
            ) do
                local placedRail = surface.create_entity {name = "railway_tunnel-crossing_rail-on_map", position = nextRailPos, force = force, direction = crossignRailDirection}
                placedRail.destructible = false
                segment.crossingRailEntities[placedRail.unit_number] = placedRail
            end
        else
            segment.trainBlockerEntity = surface.create_entity {name = "railway_tunnel-train_blocker_2x2", position = centerPos, force = force}
        end
    else
        -- Fast replacement's of the same type can just claim the old segments extras.
        if placeCrossingRails then
            segment.crossingRailEntities = fastReplacedSegment.crossingRailEntities
        else
            segment.trainBlockerEntity = fastReplacedSegment.trainBlockerEntity
        end
    end

    -- Register the new segment.
    global.undergroundSegments.segments[segment.id] = segment
    global.undergroundSegments.surfaceSegmentPositions[segment.surfacePositionString] = {
        id = segment.surfacePositionString,
        segment = segment
    }

    -- Update other parts of the mod and handle any generic extras.
    if fastReplacedSegment ~= nil then
        -- Its a fast replacement,

        -- Claim the generic extras of the old segment,
        segment.tunnelRailEntities = fastReplacedSegment.tunnelRailEntities
        segment.signalEntities = fastReplacedSegment.signalEntities
        segment.tunnel = fastReplacedSegment.tunnel

        -- Handle anything that is only present if there is a parent tunnel.
        if segment.tunnel ~= nil then
            -- Update the tunnel's reference to the fast replaced segment.
            for i, checkSegment in pairs(segment.tunnel.segments) do
                if checkSegment.id == fastReplacedSegment.id then
                    segment.tunnel.segments[i] = segment
                    break
                end
            end

            -- Update the top layer entity if it needs changing due to change of entity type.
            if fastReplaceChange ~= "same" then
                -- Remove the old top layer.
                if fastReplacedSegment.topLayerEntity ~= nil and fastReplacedSegment.topLayerEntity.valid then
                    fastReplacedSegment.topLayerEntity.destroy()
                end

                -- Create the top layer entity that has the desired graphics on it.
                local topLayerEntityName = builtSegmentTypeData.topLayerEntityName
                if topLayerEntityName ~= nil then
                    segment.topLayerEntity = surface.create_entity {name = topLayerEntityName, position = centerPos, force = force, direction = directionValue}
                end
            end
        end
        global.undergroundSegments.segments[fastReplacedSegment.id] = nil
    else
        -- New segments just check if they complete the tunnel and handle approperiately.
        local tunnelComplete, tunnelPortals, undergroundSegments = UndergroundSegments.CheckTunnelCompleteFromSegment(builtEntity, placer)
        if not tunnelComplete then
            return false
        end
        Interfaces.Call("Tunnel.CompleteTunnel", tunnelPortals, undergroundSegments)
    end
end

---@param startingUndergroundSegment LuaEntity
---@param placer EntityActioner
---@return boolean @Direction is completed successfully.
---@return LuaEntity[] @Tunnel portal entities.
---@return LuaEntity[] @Tunnel segment entities.
UndergroundSegments.CheckTunnelCompleteFromSegment = function(startingUndergroundSegment, placer)
    local tunnelPortalEntities, tunnelSegmentEntities, directionValue = {}, {}, startingUndergroundSegment.direction
    for _, checkingDirection in pairs({directionValue, Utils.LoopDirectionValue(directionValue + 4)}) do
        -- Check "forwards" and then "backwards".
        local directionComplete = TunnelShared.CheckTunnelPartsInDirectionAndGetAllParts(startingUndergroundSegment, startingUndergroundSegment.position, checkingDirection, placer, tunnelPortalEntities, tunnelSegmentEntities)
        if not directionComplete then
            return false, tunnelPortalEntities, tunnelSegmentEntities
        end
    end
    return true, tunnelPortalEntities, tunnelSegmentEntities
end

-- Registers and sets up the tunnel's segments prior to the tunnel object being created and references created.
---@param segmentEntities LuaEntity[]
---@param force LuaForce
---@param surface LuaSurface
---@return Segment[]
UndergroundSegments.On_PreTunnelCompleted = function(segmentEntities, force, surface)
    local segments = {}

    for _, segmentEntity in pairs(segmentEntities) do
        local segment = global.undergroundSegments.segments[segmentEntity.unit_number]
        table.insert(segments, segment)
        local centerPos, directionValue = segmentEntity.position, segmentEntity.direction

        -- Create the underground tunnel rail.
        segment.tunnelRailEntities = {}
        local placedRail = surface.create_entity {name = "railway_tunnel-invisible_rail-on_map_tunnel", position = centerPos, force = force, direction = directionValue}
        placedRail.destructible = false
        segment.tunnelRailEntities[placedRail.unit_number] = placedRail

        -- Add the singals to the underground tunnel rail.
        segment.signalEntities = {}
        for _, orientationModifier in pairs({0, 4}) do
            local signalDirection = Utils.LoopDirectionValue(directionValue + orientationModifier)
            local orientation = Utils.DirectionToOrientation(signalDirection)
            local position = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0}))
            local placedSignal = surface.create_entity {name = "railway_tunnel-invisible_signal-not_on_map", position = position, force = force, direction = signalDirection}
            segment.signalEntities[placedSignal.unit_number] = placedSignal
        end

        -- Create the top layer entity that has the desired graphics on it.
        local builtSegmentTypeData = UndergroundSegmentTypeData[segmentEntity.name]
        local topLayerEntityName = builtSegmentTypeData.topLayerEntityName
        if topLayerEntityName ~= nil then
            segment.topLayerEntity = surface.create_entity {name = topLayerEntityName, position = centerPos, force = force, direction = directionValue}
        end
    end

    return segments
end

---@param event on_built_entity|on_robot_built_entity|script_raised_built
UndergroundSegments.OnBuiltEntityGhost = function(event)
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

-- This is needed so when a player is doing a fast replace by hand the OnPreMinedEntity knows can know its a fast replace and not check mining conflicts or affect the pre_mine. All other scenarios of this triggering do no harm as the beingFastReplaced attribute is either cleared or the object recreated cleanly on the follow on event.
---@param event on_pre_build
UndergroundSegments.OnPreBuild = function(event)
    local player = game.get_player(event.player_index)
    if not player.cursor_stack.valid or not player.cursor_stack.valid_for_read or UndergroundSegmentEntityNames[player.cursor_stack.name] == nil then
        return
    end

    local surface = player.surface
    local surfacePositionString = Utils.FormatSurfacePositionTableToString(surface.index, event.position)
    local segmentPositionObject = global.undergroundSegments.surfaceSegmentPositions[surfacePositionString]
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

---@param oldSegment Segment
UndergroundSegments.ReplaceSegmentEntity = function(oldSegment)
    local centerPos, force, lastUser, directionValue, surface, entityName = oldSegment.entity.position, oldSegment.entity.force, oldSegment.entity.last_user, oldSegment.entity.direction, oldSegment.entity.surface, oldSegment.entity.name
    oldSegment.entity.destroy()

    local newSegmentEntity = surface.create_entity {name = entityName, position = centerPos, direction = directionValue, force = force, player = lastUser} ---@type LuaEntity
    ---@type Segment
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
    global.undergroundSegments.surfaceSegmentPositions[newSegment.surfacePositionString].segment = newSegment
    global.undergroundSegments.segments[oldSegment.id] = nil
    Interfaces.Call("Tunnel.On_SegmentReplaced", newSegment.tunnel, oldSegment, newSegment)
end

---@param segment Segment
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
    global.undergroundSegments.surfaceSegmentPositions[segment.surfacePositionString] = nil
    global.undergroundSegments.segments[segment.id] = nil
end

---@param segments Segment[]
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
