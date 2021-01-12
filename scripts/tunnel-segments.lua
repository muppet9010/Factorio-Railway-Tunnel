local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelCommon = require("scripts/common/tunnel-common")
local TunnelSegments = {}

TunnelSegments.CreateGlobals = function()
    global.tunnelSegments = global.tunnelSegments or {}
    global.tunnelSegments.segments = global.tunnelSegments.segments or {}
    --[[
        [id] = {
            id = unit_number of the placed segment entity.
            entity = ref to the placed entity
            railEntities = table of the rail entities within the tunnel segment. Key'd by the rail unit_number.
            signalEntities = table of the hidden signal entities within the tunnel segment. Key'd by the signal unit_number.
            tunnel = the tunnel this portal is part of.
            crossingRailEntities = table of the rail entities that cross the tunnel segment. Table only exists for tunnel_segment_surface_rail_crossing. Key'd by the rail unit_number.
            positionString = the entities position as a string with surface. Used to back match to segmentPositions global object.
            beingFastReplacedTick = the tick the segment was marked as being fast replaced.
        }
    ]]
    global.tunnelSegments.segmentPositions = global.tunnelSegments.segmentPositions or {}
    --[[
        [id] = {
            id = the position of the segment as a string with surface
            segment = ref to the segment global object
        }
    ]]
end

TunnelSegments.OnLoad = function()
    local segmentEntityNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelSegmentPlacedPlacementEntityNames) do
        table.insert(segmentEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelSegments.OnBuiltEntity", TunnelSegments.OnBuiltEntity, "TunnelSegments.OnBuiltEntity", segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelSegments.OnBuiltEntity", TunnelSegments.OnBuiltEntity, "TunnelSegments.OnBuiltEntity", segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelSegments.OnBuiltEntity", TunnelSegments.OnBuiltEntity, "TunnelSegments.OnBuiltEntity", segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "TunnelSegments.OnPreMinedEntity", TunnelSegments.OnPreMinedEntity, "TunnelSegments.OnPreMinedEntity", segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "TunnelSegments.OnPreMinedEntity", TunnelSegments.OnPreMinedEntity, "TunnelSegments.OnPreMinedEntity", segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_build, "TunnelSegments.OnPreBuild", TunnelSegments.OnPreBuild)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "TunnelSegments.OnDiedEntity", TunnelSegments.OnDiedEntity, "TunnelSegments.OnDiedEntity", segmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "TunnelSegments.OnDiedEntity", TunnelSegments.OnDiedEntity, "TunnelSegments.OnDiedEntity", segmentEntityNames_Filter)

    local segmentEntityGhostNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelSegmentPlacedPlacementEntityNames) do
        table.insert(segmentEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelSegments.OnBuiltEntityGhost", TunnelSegments.OnBuiltEntityGhost, "TunnelSegments.OnBuiltEntityGhost", segmentEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelSegments.OnBuiltEntityGhost", TunnelSegments.OnBuiltEntityGhost, "TunnelSegments.OnBuiltEntityGhost", segmentEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelSegments.OnBuiltEntityGhost", TunnelSegments.OnBuiltEntityGhost, "TunnelSegments.OnBuiltEntityGhost", segmentEntityGhostNames_Filter)

    Interfaces.RegisterInterface("TunnelSegments.TunnelCompleted", TunnelSegments.TunnelCompleted)
    Interfaces.RegisterInterface("TunnelSegments.TunnelRemoved", TunnelSegments.TunnelRemoved)
end

TunnelSegments.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or TunnelCommon.tunnelSegmentPlacedPlacementEntityNames[createdEntity.name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end
    TunnelSegments.PlacementTunnelSegmentSurfaceBuilt(createdEntity, placer)
end

TunnelSegments.PlacementTunnelSegmentSurfaceBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface, placementEntityName = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface, placementEntity.name

    if not TunnelSegments.TunnelSegmentPlacementValid(placementEntity) then
        TunnelCommon.UndoInvalidPlacement(placementEntity, placer, true)
        return
    end
    placementEntity.destroy()

    local placedEntityName, placeCrossingRails
    if placementEntityName == "railway_tunnel-tunnel_segment_surface-placement" or placementEntityName == "railway_tunnel-tunnel_segment_surface-placed" then
        placedEntityName = "railway_tunnel-tunnel_segment_surface-placed"
        placeCrossingRails = false
    elseif placementEntityName == "railway_tunnel-tunnel_segment_surface_rail_crossing-placement" or placementEntityName == "railway_tunnel-tunnel_segment_surface_rail_crossing-placed" then
        placedEntityName = "railway_tunnel-tunnel_segment_surface_rail_crossing-placed"
        placeCrossingRails = true
    end

    local positionString = Utils.FormatSurfacePositionTableToString(aboveSurface.index, centerPos)
    local fastReplacedSegmentByPosition, fastReplacedSegment = global.tunnelSegments.segmentPositions[positionString]
    if fastReplacedSegmentByPosition ~= nil then
        fastReplacedSegment = fastReplacedSegmentByPosition.segment
    end
    if not placeCrossingRails and fastReplacedSegment ~= nil then
        -- Is a downgrade from crossing rails to non crossing rails, so remove them. The old global segment object referencing them will be removed later in this function.
        for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
            if not railCrossingTrackEntity.can_be_destroyed() then
                -- Put the old correct entity back and correct whats been done.
                TunnelCommon.EntityErrorMessage(placer, "Can not fast replace crossing rail tunnel segment while train is on crossing track", aboveSurface, centerPos)
                local oldId = fastReplacedSegment.id
                fastReplacedSegment.entity = aboveSurface.create_entity {name = "railway_tunnel-tunnel_segment_surface_rail_crossing-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
                local newId = fastReplacedSegment.entity.unit_number
                fastReplacedSegment.id = newId
                global.tunnelSegments.segments[newId] = fastReplacedSegment
                global.tunnelSegments.segments[oldId] = nil
                Utils.GetBuilderInventory(placer).remove({name = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement", count = 1})
                Utils.GetBuilderInventory(placer).insert({name = "railway_tunnel-tunnel_segment_surface-placement", count = 1})
                return
            end
        end
    end

    local abovePlacedTunnelSegment = aboveSurface.create_entity {name = placedEntityName, position = centerPos, direction = directionValue, force = force, player = lastUser}
    local segment = {
        id = abovePlacedTunnelSegment.unit_number,
        entity = abovePlacedTunnelSegment,
        positionString = positionString
    }

    if placeCrossingRails then
        segment.crossingRailEntities = {}
        local crossignRailDirection, orientation = Utils.LoopDirectionValue(directionValue + 2), directionValue / 8
        for _, nextRailPos in pairs(
            {
                Utils.ApplyOffsetToPosition(abovePlacedTunnelSegment.position, Utils.RotatePositionAround0(orientation, {x = -2, y = 0})),
                abovePlacedTunnelSegment.position,
                Utils.ApplyOffsetToPosition(abovePlacedTunnelSegment.position, Utils.RotatePositionAround0(orientation, {x = 2, y = 0}))
            }
        ) do
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-internal_rail-on_map", position = nextRailPos, force = force, direction = crossignRailDirection}
            segment.crossingRailEntities[placedRail.unit_number] = placedRail
        end
    elseif not placeCrossingRails and fastReplacedSegment ~= nil then
        -- Is a downgrade from crossing rails to non crossing rails, so remove them. The old global segment object referencing them will be removed later in this function.
        for _, railCrossingTrackEntity in pairs(fastReplacedSegment.crossingRailEntities) do
            railCrossingTrackEntity.destroy()
        end
    end
    global.tunnelSegments.segments[segment.id] = segment
    global.tunnelSegments.segmentPositions[segment.positionString] = {
        id = segment.positionString,
        segment = segment
    }
    if fastReplacedSegment ~= nil then
        segment.railEntities = fastReplacedSegment.railEntities
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
        global.tunnelSegments.segments[fastReplacedSegment.id] = nil
    else
        local tunnelComplete, tunnelPortals, tunnelSegments = TunnelSegments.CheckTunnelCompleteFromSegment(abovePlacedTunnelSegment, placer)
        if not tunnelComplete then
            return false
        end
        Interfaces.Call("Tunnel.CompleteTunnel", tunnelPortals, tunnelSegments)
    end
end

TunnelSegments.TunnelSegmentPlacementValid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

TunnelSegments.CheckTunnelCompleteFromSegment = function(startingTunnelSegment, placer)
    local directionComplete
    local tunnelPortals, tunnelSegments, directionValue = {}, {startingTunnelSegment}, startingTunnelSegment.direction
    for _, checkingDirection in pairs({directionValue, Utils.LoopDirectionValue(directionValue + 4)}) do
        -- Check "forwards" and then "backwards".
        directionComplete = TunnelCommon.CheckTunnelPartsInDirection(startingTunnelSegment, startingTunnelSegment.position, tunnelPortals, tunnelSegments, checkingDirection, placer)
        if not directionComplete then
            break
        end
    end
    if not directionComplete then
        -- If last direction checked was good then tunnel is complete, as we reset it each loop.
        return false, tunnelPortals, tunnelSegments
    end
    return true, tunnelPortals, tunnelSegments
end

TunnelSegments.TunnelCompleted = function(segmentEntities, force, aboveSurface)
    local segments = {}

    for _, segmentEntity in pairs(segmentEntities) do
        local segment = global.tunnelSegments.segments[segmentEntity.unit_number]
        table.insert(segments, segment)
        local centerPos, directionValue = segmentEntity.position, segmentEntity.direction

        segment.railEntities = {}
        local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = centerPos, force = force, direction = directionValue}
        segment.railEntities[placedRail.unit_number] = placedRail

        segment.signalEntities = {}
        for _, orientationModifier in pairs({0, 4}) do
            local signalDirection = Utils.LoopDirectionValue(directionValue + orientationModifier)
            local orientation = signalDirection / 8
            local position = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0}))
            local placedSignal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_rail_signal_surface", position = position, force = force, direction = signalDirection}
            segment.signalEntities[placedSignal.unit_number] = placedSignal
        end
    end

    return segments
end

TunnelSegments.OnBuiltEntityGhost = function(event)
    local createdEntity = event.created_entity or event.entity
    if not createdEntity.valid or createdEntity.type ~= "entity-ghost" or TunnelCommon.tunnelSegmentPlacedPlacementEntityNames[createdEntity.ghost_name] == nil then
        return
    end
    local placer = event.robot -- Will be nil for player or script placed.
    if placer == nil and event.player_index ~= nil then
        placer = game.get_player(event.player_index)
    end

    if not TunnelSegments.TunnelSegmentPlacementValid(createdEntity) then
        TunnelCommon.UndoInvalidPlacement(createdEntity, placer, false)
        return
    end
end

TunnelSegments.OnPreBuild = function(event)
    -- This is needed so when a player is doing a fast replace by hand the OnPreMinedEntity knows can know its a fast replace and not check mining conflicts or affect the pre_mine. All other scenarios of this triggering do no harm as the beingFastReplaced attribute is either cleared or the object recreated cleanly on the follow on event.
    local surface = game.get_player(event.player_index).surface
    local positionString = Utils.FormatSurfacePositionTableToString(surface.index, event.position)
    local segmentPositionObject = global.tunnelSegments.segmentPositions[positionString]
    if segmentPositionObject == nil then
        return
    end
    segmentPositionObject.segment.beingFastReplacedTick = event.tick
end

TunnelSegments.OnPreMinedEntity = function(event)
    local minedEntity = event.entity
    if not minedEntity.valid or TunnelCommon.tunnelSegmentPlacedPlacementEntityNames[minedEntity.name] == nil then
        return
    end
    local segment = global.tunnelSegments.segments[minedEntity.unit_number]
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
                TunnelCommon.EntityErrorMessage(miner, "Can not mine tunnel segment while train is on crossing track", minedEntity.surface, minedEntity.position)
                TunnelSegments.ReplaceSegmentEntity(segment)
                return
            end
        end
    end
    if segment.tunnel == nil then
        TunnelSegments.EntityRemoved(segment)
    else
        if Interfaces.Call("TrainManager.IsTunnelInUse", segment.tunnel) then
            TunnelCommon.EntityErrorMessage(miner, "Can not mine tunnel segment while train is using tunnel", minedEntity.surface, minedEntity.position)
            TunnelSegments.ReplaceSegmentEntity(segment)
        else
            Interfaces.Call("Tunnel.RemoveTunnel", segment.tunnel)
            TunnelSegments.EntityRemoved(segment)
        end
    end
end

TunnelSegments.ReplaceSegmentEntity = function(oldSegment)
    local centerPos, force, lastUser, directionValue, aboveSurface, entityName = oldSegment.entity.position, oldSegment.entity.force, oldSegment.entity.last_user, oldSegment.entity.direction, oldSegment.entity.surface, oldSegment.entity.name
    oldSegment.entity.destroy()

    local newSegmentEntity = aboveSurface.create_entity {name = entityName, position = centerPos, direction = directionValue, force = force, player = lastUser}
    local newSegment = {
        id = newSegmentEntity.unit_number,
        entity = newSegmentEntity,
        railEntities = oldSegment.railEntities,
        signalEntities = oldSegment.signalEntities,
        tunnel = oldSegment.tunnel,
        crossingRailEntities = oldSegment.crossingRailEntities,
        positionString = Utils.FormatSurfacePositionTableToString(newSegmentEntity.surface.index, newSegmentEntity.position)
    }
    global.tunnelSegments.segments[newSegment.id] = newSegment
    global.tunnelSegments.segmentPositions[newSegment.positionString].segment = newSegment
    if newSegment.tunnel ~= nil then
        for i, segment in pairs(newSegment.tunnel.segments) do
            if segment.id == oldSegment.id then
                segment.tunnel.segments[i] = newSegment
                break
            end
        end
    end
    global.tunnelSegments.segments[oldSegment.id] = nil
end

TunnelSegments.EntityRemoved = function(segment, killForce, killerCauseEntity)
    if segment.crossingRailEntities ~= nil then
        TunnelCommon.DestroyCarriagesOnRailEntityList(segment.crossingRailEntities, killForce, killerCauseEntity)
        for _, crossingRailEntity in pairs(segment.crossingRailEntities) do
            crossingRailEntity.destroy()
        end
    end
    global.tunnelSegments.segmentPositions[segment.positionString] = nil
    global.tunnelSegments.segments[segment.id] = nil
end

TunnelSegments.TunnelRemoved = function(segment)
    segment.tunnel = nil
    for _, railEntity in pairs(segment.railEntities) do
        railEntity.destroy()
    end
    segment.railEntities = nil
    for _, signalEntity in pairs(segment.signalEntities) do
        signalEntity.destroy()
    end
    segment.signalEntities = nil
end

TunnelSegments.OnDiedEntity = function(event)
    local diedEntity, killerForce, killerCauseEntity = event.entity, event.force, event.cause -- The killer variables will be nil in some cases.
    if not diedEntity.valid or TunnelCommon.tunnelSegmentPlacedPlacementEntityNames[diedEntity.name] == nil then
        return
    end
    local segment = global.tunnelSegments.segments[diedEntity.unit_number]
    if segment == nil then
        return
    end

    if segment.tunnel == nil then
        TunnelSegments.EntityRemoved(segment, killerForce, killerCauseEntity)
    else
        Interfaces.Call("Tunnel.RemoveTunnel", segment.tunnel)
        TunnelSegments.EntityRemoved(segment, killerForce, killerCauseEntity)
    end
end

return TunnelSegments
