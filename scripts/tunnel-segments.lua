local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local TunnelCommon = require("scripts/common/tunnel-common")
local TunnelSegments = {}

TunnelSegments.CreateGlobals = function()
    global.tunnelSegments = global.tunnelSegments or {}
    global.tunnelSegments.tunnelSegments = global.tunnelSegments.tunnelSegments or {}
    --[[
        [unit_number] = {
            id = unit_number of the placed segment entity.
            entity = ref to the placed entity
            railEntities = table of the rail entities within the tunnel segment. Key'd by the rail unit_number.
            signalEntities = table of the hidden signal entities within the tunnel segment. Key'd by the signal unit_number.
            tunnel = the tunnel this portal is part of.
            crossingRailEntities = table of the rail entities that cross the tunnel segment. Table only exists for tunnel_segment_surface_rail_crossing. Key'd by the rail unit_number.
            positionString = the entities position as a string. used to back match to tunnelSegmentPositions global object.
        }
    ]]
    global.tunnelSegments.tunnelSegmentPositions = global.tunnelSegments.tunnelSegmentPositions or {}
    --[[
        [id] = {
            id = the position of the segment as a string
            tunnelSegments = ref to the tunnelSegment global object
        }
    ]]
end

TunnelSegments.OnLoad = function()
    local tunnelSegmentEntityNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelSegmentPlacedPlacementEntityNames) do
        table.insert(tunnelSegmentEntityNames_Filter, {filter = "name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelSegments.OnBuiltEntity", TunnelSegments.OnBuiltEntity, "TunnelSegments.OnBuiltEntity", tunnelSegmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelSegments.OnBuiltEntity", TunnelSegments.OnBuiltEntity, "TunnelSegments.OnBuiltEntity", tunnelSegmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelSegments.OnBuiltEntity", TunnelSegments.OnBuiltEntity, "TunnelSegments.OnBuiltEntity", tunnelSegmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_mined_item, "TunnelSegments.OnPreMinedEntity", TunnelSegments.OnPreMinedEntity, "TunnelSegments.OnPreMinedEntity", tunnelSegmentEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_pre_mined, "TunnelSegments.OnPreMinedEntity", TunnelSegments.OnPreMinedEntity, "TunnelSegments.OnPreMinedEntity", tunnelSegmentEntityNames_Filter)

    local tunnelSegmentEntityGhostNames_Filter = {}
    for _, name in pairs(TunnelCommon.tunnelSegmentPlacedPlacementEntityNames) do
        table.insert(tunnelSegmentEntityGhostNames_Filter, {filter = "ghost_name", name = name})
    end
    Events.RegisterHandlerEvent(defines.events.on_built_entity, "TunnelSegments.OnBuiltEntityGhost", TunnelSegments.OnBuiltEntityGhost, "TunnelSegments.OnBuiltEntityGhost", tunnelSegmentEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "TunnelSegments.OnBuiltEntityGhost", TunnelSegments.OnBuiltEntityGhost, "TunnelSegments.OnBuiltEntityGhost", tunnelSegmentEntityGhostNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "TunnelSegments.OnBuiltEntityGhost", TunnelSegments.OnBuiltEntityGhost, "TunnelSegments.OnBuiltEntityGhost", tunnelSegmentEntityGhostNames_Filter)

    Interfaces.RegisterInterface("TunnelSegments.TunnelCompleted", TunnelSegments.TunnelCompleted)
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
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface

    if not TunnelSegments.TunnelSegmentPlacementValid(placementEntity) then
        TunnelCommon.UndoInvalidPlacement(placementEntity, placer, true)
        return
    end

    local placedEntityName, placeCrossignRails
    if placementEntity.name == "railway_tunnel-tunnel_segment_surface-placement" or placementEntity.name == "railway_tunnel-tunnel_segment_surface-placed" then
        placedEntityName = "railway_tunnel-tunnel_segment_surface-placed"
        placeCrossignRails = false
    elseif placementEntity.name == "railway_tunnel-tunnel_segment_surface_rail_crossing-placement" or placementEntity.name == "railway_tunnel-tunnel_segment_surface_rail_crossing-placed" then
        placedEntityName = "railway_tunnel-tunnel_segment_surface_rail_crossing-placed"
        placeCrossignRails = true
    end
    placementEntity.destroy()

    local abovePlacedTunnelSegment = aboveSurface.create_entity {name = placedEntityName, position = centerPos, direction = directionValue, force = force, player = lastUser}
    local tunnelSegment = {
        id = abovePlacedTunnelSegment.unit_number,
        entity = abovePlacedTunnelSegment,
        positionString = Utils.FormatPositionTableToString(abovePlacedTunnelSegment.position)
    }
    local fastReplacedSegmentByPosition, fastReplacedSegment = global.tunnelSegments.tunnelSegmentPositions[tunnelSegment.positionString]
    if fastReplacedSegmentByPosition ~= nil then
        fastReplacedSegment = fastReplacedSegmentByPosition.tunnelSegment
    end

    if placeCrossignRails then
        tunnelSegment.crossingRailEntities = {}
        local crossignRailDirection, orientation = Utils.LoopDirectionValue(directionValue + 2), directionValue / 8
        for _, nextRailPos in pairs(
            {
                Utils.ApplyOffsetToPosition(abovePlacedTunnelSegment.position, Utils.RotatePositionAround0(orientation, {x = -2, y = 0})),
                abovePlacedTunnelSegment.position,
                Utils.ApplyOffsetToPosition(abovePlacedTunnelSegment.position, Utils.RotatePositionAround0(orientation, {x = 2, y = 0}))
            }
        ) do
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-internal_rail-on_map", position = nextRailPos, force = force, direction = crossignRailDirection}
            tunnelSegment.crossingRailEntities[placedRail.unit_number] = placedRail
        end
    elseif not placeCrossignRails and fastReplacedSegment ~= nil then
        --Is a downgrade from crossing rails to non crossing rails, so remove them. Their references will be removed with the old global segment later.
        for _, entity in pairs(fastReplacedSegment.crossingRailEntities) do
            local result = entity.destroy()
            if not result then
                game.print("couldn't remove track as train blocking it - TODO")
            end
            --TODO: check that we can remove the rail before doing it. If it can't be removed show text to user and revert switch or something safe...
        end
    end
    global.tunnelSegments.tunnelSegments[tunnelSegment.id] = tunnelSegment
    global.tunnelSegments.tunnelSegmentPositions[tunnelSegment.positionString] = {
        id = tunnelSegment.positionString,
        tunnelSegment = tunnelSegment
    }
    if fastReplacedSegment ~= nil then
        tunnelSegment.railEntities = fastReplacedSegment.railEntities
        tunnelSegment.signalEntities = fastReplacedSegment.signalEntities
        tunnelSegment.tunnel = fastReplacedSegment.tunnel
        if tunnelSegment.tunnel ~= nil then
            for i, checkSegment in pairs(tunnelSegment.tunnel.segments) do
                if checkSegment.id == fastReplacedSegment.id then
                    tunnelSegment.tunnel.segments[i] = tunnelSegment
                    break
                end
            end
        end
        global.tunnelSegments.tunnelSegments[fastReplacedSegment.id] = nil
    else
        local tunnelComplete, tunnelPortals, tunnelSegments = TunnelSegments.CheckTunnelCompleteFromSegment(abovePlacedTunnelSegment, placer)
        if not tunnelComplete then
            return false
        end
        Interfaces.Call("Tunnel.TunnelCompleted", tunnelPortals, tunnelSegments)
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

TunnelSegments.TunnelCompleted = function(tunnelSegmentEntities, force, aboveSurface)
    local tunnelSegments = {}

    for _, tunnelSegmentEntity in pairs(tunnelSegmentEntities) do
        local tunnelSegment = global.tunnelSegments.tunnelSegments[tunnelSegmentEntity.unit_number]
        table.insert(tunnelSegments, tunnelSegment)
        local centerPos, directionValue = tunnelSegmentEntity.position, tunnelSegmentEntity.direction

        tunnelSegment.railEntities = {}
        local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = centerPos, force = force, direction = directionValue}
        tunnelSegment.railEntities[placedRail.unit_number] = placedRail

        tunnelSegment.signalEntities = {}
        for _, orientationModifier in pairs({0, 4}) do
            local signalDirection = Utils.LoopDirectionValue(directionValue + orientationModifier)
            local orientation = signalDirection / 8
            local position = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0}))
            local placedSignal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_rail_signal_surface", position = position, force = force, direction = signalDirection}
            tunnelSegment.signalEntities[placedSignal.unit_number] = placedSignal
        end
    end

    return tunnelSegments
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
        createdEntity.destroy()
        return
    end
end

TunnelSegments.OnPreMinedEntity = function(event)
    --TODO
end

return TunnelSegments
