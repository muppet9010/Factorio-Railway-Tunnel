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

---@class SurfacePositionString @the entities surface and position as a string.

---@class SurfaceSegmentPosition
---@field id SurfacePositionString
---@field segment Segment

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

    if not TunnelShared.IsPlacementOnRailGrid(builtEntity) then
        TunnelShared.UndoInvalidTunnelPartPlacement(builtEntity, placer, true)
        return
    end

    local placeCrossingRails
    if builtEntityName == "railway_tunnel-underground_segment-straight" then
        placeCrossingRails = false
    elseif builtEntityName == "railway_tunnel-underground_segment-straight-rail_crossing" then
        placeCrossingRails = true
    end

    local surfacePositionString = Utils.FormatSurfacePositionTableToString(surface.index, centerPos)
    local fastReplacedSegmentByPosition, fastReplacedSegment = global.undergroundSegments.surfaceSegmentPositions[surfacePositionString], nil
    if fastReplacedSegmentByPosition ~= nil then
        fastReplacedSegment = fastReplacedSegmentByPosition.segment
    end
    if not placeCrossingRails and fastReplacedSegment ~= nil then
        -- Is an attempt at a downgrade from crossing rails to non crossing rails, so check crossing rails can be safely removed.
        for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
            if not railCrossingTrackEntity.can_be_destroyed() then
                -- Put the old correct entity back and correct whats been done.
                TunnelShared.EntityErrorMessage(placer, "Can not fast replace crossing rail tunnel segment while train is on crossing track", surface, centerPos)
                local oldId = fastReplacedSegment.id
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

    local segment = {
        id = builtEntity.unit_number,
        entity = builtEntity,
        surfacePositionString = surfacePositionString
    }

    -- Place the train blocker entity on non crossing rail segments.
    if not placeCrossingRails then
        segment.trainBlockerEntity = surface.create_entity {name = "railway_tunnel-train_blocker_2x2", position = centerPos, force = force}
    end

    -- TODO: can try and fast replace entity over itself, but on different rotation. This is odd, but causes crash when crossing is fast replaced over crossing on different rotation (north > east  or north > south)
    if placeCrossingRails then
        -- Crossing rails placed. So handle their specific extras.
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
        if fastReplacedSegment ~= nil then
            -- As its an upgrade remove the train blocker entity that was present for the regular tunnel segment, but shouldn't be for a crossing rail segment.
            fastReplacedSegment.trainBlockerEntity.destroy()
            fastReplacedSegment.trainBlockerEntity = nil
        end
    elseif not placeCrossingRails and fastReplacedSegment ~= nil then
        -- Is a downgrade from crossing rails to non crossing rails, so remove them. The old global segment object referencing them will be removed later in this function.
        for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
            railCrossingTrackEntity.destroy()
        end
    end
    global.undergroundSegments.segments[segment.id] = segment
    global.undergroundSegments.surfaceSegmentPositions[segment.surfacePositionString] = {
        id = segment.surfacePositionString,
        segment = segment
    }
    if fastReplacedSegment ~= nil then
        segment.tunnelRailEntities = fastReplacedSegment.tunnelRailEntities
        segment.signalEntities = fastReplacedSegment.signalEntities
        segment.tunnel = fastReplacedSegment.tunnel
        if segment.tunnel ~= nil then
            for i, checkSegment in pairs(segment.tunnel.segments) do
                if checkSegment.id == fastReplacedSegment.id then
                    segment.tunnel.segments[i] = segment
                    break
                end
            end
        end
        global.undergroundSegments.segments[fastReplacedSegment.id] = nil
    else
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

        segment.tunnelRailEntities = {}
        local placedRail = surface.create_entity {name = "railway_tunnel-invisible_rail-on_map_tunnel", position = centerPos, force = force, direction = directionValue}
        placedRail.destructible = false
        segment.tunnelRailEntities[placedRail.unit_number] = placedRail

        segment.signalEntities = {}
        for _, orientationModifier in pairs({0, 4}) do
            local signalDirection = Utils.LoopDirectionValue(directionValue + orientationModifier)
            local orientation = Utils.DirectionToOrientation(signalDirection)
            local position = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0}))
            local placedSignal = surface.create_entity {name = "railway_tunnel-invisible_signal-not_on_map", position = position, force = force, direction = signalDirection}
            segment.signalEntities[placedSignal.unit_number] = placedSignal
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

UndergroundSegments.OnPreBuild = function(event)
    -- This is needed so when a player is doing a fast replace by hand the OnPreMinedEntity knows can know its a fast replace and not check mining conflicts or affect the pre_mine. All other scenarios of this triggering do no harm as the beingFastReplaced attribute is either cleared or the object recreated cleanly on the follow on event.
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
    segmentPositionObject.segment.beingFastReplacedTick = event.tick
end

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
        -- Detected that the player has pre_placed an entity at the same spot in the same tick, so almost certainly the entity is being fast replaced.
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
    global.undergroundSegments.surfaceSegmentPositions[segment.surfacePositionString] = nil
    global.undergroundSegments.segments[segment.id] = nil
end

---@param segment Segment
UndergroundSegments.On_TunnelRemoved = function(segment)
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
end

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
