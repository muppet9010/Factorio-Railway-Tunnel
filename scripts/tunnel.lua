local Events = require("utility/events")
local Interfaces = require("utility/interfaces")
local Utils = require("utility/utils")
local Tunnel = {}

Tunnel.setupValues = {
    entranceFromCenter = 25,
    --Tunnels distance starts from the first entrace tile.
    entrySignalsDistance = 1,
    endSignalsDistance = 49,
    straightRailCountFromEntrance = 21,
    invisibleRailCountFromEntrance = 4,
    undergroundLeadInTiles = 100 -- hard coded for now just cos
}
local TunnelSegmentEntityNames = {["railway_tunnel-tunnel_segment_surface-placed"] = "railway_tunnel-tunnel_segment_surface-placed", ["railway_tunnel-tunnel_segment_surface_rail_crossing-placed"] = "railway_tunnel-tunnel_segment_surface_rail_crossing-placed"}
local TunnelPortalEntityNames = {["railway_tunnel-tunnel_portal_surface-placed"] = "railway_tunnel-tunnel_portal_surface-placed"}
local TunnelSegmentAndPortalEntityNames = Utils.TableMerge({TunnelSegmentEntityNames, TunnelPortalEntityNames})

Tunnel.CreateGlobals = function()
    global.tunnel = global.tunnel or {}
    global.tunnel.endSignals = global.tunnel.endSignals or {}
    --[[
        [unit_number] = {
            id = unit_number of this signal.
            entity = signal entity.
            portal = the portal global object this signal is part of.
        }
    ]]
    global.tunnel.entrySignals = global.tunnel.entrySignals or {}
    --[[
        [unit_number] = {
            id = unit_number of this signal.
            entity = signal entity.
            portal = the portal global object this signal is part of.
        }
    ]]
    global.tunnel.portals = global.tunnel.portals or {}
    --[[
        [unit_number] = {
            id = unit_number of the placed tunnel portal entity.
            entity = ref to the entity of the placed main tunnel portal entity.
            endSignals = table of endSignal global objects for the end signals of this portal. These are the inner locked red signals. Key'd as "in" and "out".
            entrySignals = table of entrySignal global objects for the entry signals of this portal. These are the outer ones that detect a train approaching the tunnel train path. Key'd as "in" and "out".
            tunnel = the tunnel global object this portal is part of.
            railEntities = table of the rail entities within the portal. key'd by the rail unit_number.
        }
    ]]
    global.tunnel.tunnels = global.tunnel.tunnels or {}
    --[[
        [id] = {
            id = unqiue id of the tunnel.
            alignment = either "horizontal" or "vertical".
            alignmentOrientation = the orientation value of either 0.25 (horizontal) or 0 (vertical), no concept of direction though.
            aboveSurface = LuaSurface of the main world surface.
            undergroundSurface = LuaSurface of the underground surface for this tunnel.
            portals = table of the 2 portal global objects that make up this tunnel.
            segments = table of the tunnelSegments global objects on the surface.
            undergroundRailEntities = table of rail LuaEntity.
            undergroundModifiers = {
                railAlignmentAxis = the "x" or "y" axis that the tunnels underground rails are aligned along.
                tunnelInstanceAxis = the "x" or "y" that each tunnel instance is spaced out along.
                tunnelInstanceValue = this tunnels static value of the tunnelInstanceAxis for the copied (moving) train carriages.
                distanceFromCenterToPortalEntrySignals = the number of tiles between the centre of the underground and the portal entry signals.
                distanceFromCenterToPortalEndSignals = the number of tiles between the centre of the underground and the portal end signals.
                tunnelInstanceClonedTrainValue = this tunnels static value of the tunnelInstanceAxis for the cloned (stationary) train carriages.
            }
        }
    ]]
    global.tunnel.tunnelSegments = global.tunnel.tunnelSegments or {}
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
    global.tunnel.tunnelSegmentPositions = global.tunnel.tunnelSegmentPositions or {}
    --[[
        [id] = {
            id = the position of the segment as a string
            tunnelSegments = ref to the tunnelSegment global object
        }
    ]]
end

Tunnel.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_train_changed_state, "Tunnel.TrainEnteringTunnel_OnTrainChangedState", Tunnel.TrainEnteringTunnel_OnTrainChangedState)

    local tunnelSegmentAndPortalEntityNames_Filter = {
        {filter = "name", name = "railway_tunnel-tunnel_portal_surface-placement"},
        {filter = "name", name = "railway_tunnel-tunnel_segment_surface-placement"},
        {filter = "name", name = "railway_tunnel-tunnel_segment_surface_rail_crossing-placement"}
    }

    Events.RegisterHandlerEvent(defines.events.on_built_entity, "Tunnel.OnBuiltEntity", Tunnel.OnBuiltEntity, "Tunnel.OnBuiltEntity", tunnelSegmentAndPortalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.on_robot_built_entity, "Tunnel.OnRobotBuiltEntity", Tunnel.OnRobotBuiltEntity, "Tunnel.OnRobotBuiltEntity", tunnelSegmentAndPortalEntityNames_Filter)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Tunnel.ScriptRaisedBuilt", Tunnel.ScriptRaisedBuilt, "Tunnel.ScriptRaisedBuilt", tunnelSegmentAndPortalEntityNames_Filter)

    Interfaces.RegisterInterface(
        "Tunnel.GetSetupValues",
        function()
            return Tunnel.setupValues
        end
    )
end

Tunnel.TrainEnteringTunnel_OnTrainChangedState = function(event)
    local train = event.train
    if train.state ~= defines.train_state.arrive_signal then
        return
    end
    local signal = train.signal
    if signal == nil or global.tunnel.endSignals[signal.unit_number] == nil then
        return
    end
    Interfaces.Call("TrainManager.TrainEnteringInitial", train, global.tunnel.endSignals[signal.unit_number])
end

Tunnel.OnBuiltEntity = function(event)
    local createdEntity = event.created_entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, game.get_player(event.player_index))
    elseif createdEntity.name == "railway_tunnel-tunnel_segment_surface-placement" or createdEntity.name == "railway_tunnel-tunnel_segment_surface_rail_crossing-placement" then
        Tunnel.PlacementTunnelSegmentSurfaceBuilt(createdEntity, game.get_player(event.player_index))
    end
end

Tunnel.OnRobotBuiltEntity = function(event)
    local createdEntity = event.entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, event.robot)
    elseif createdEntity.name == "railway_tunnel-tunnel_segment_surface-placement" or createdEntity.name == "railway_tunnel-tunnel_segment_surface_rail_crossing-placement" then
        Tunnel.PlacementTunnelSegmentSurfaceBuilt(createdEntity, event.robot)
    end
end

Tunnel.ScriptRaisedBuilt = function(event)
    local createdEntity = event.entity
    if createdEntity.name == "railway_tunnel-tunnel_portal_surface-placement" then
        Tunnel.PlacementTunnelPortalBuilt(createdEntity, nil)
    elseif createdEntity.name == "railway_tunnel-tunnel_segment_surface-placement" or createdEntity.name == "railway_tunnel-tunnel_segment_surface_rail_crossing-placement" then
        Tunnel.PlacementTunnelSegmentSurfaceBuilt(createdEntity, nil)
    end
end

Tunnel.PlacementTunnelPortalBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface
    local orientation = directionValue / 8
    local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - Tunnel.setupValues.entranceFromCenter}))

    if not Tunnel.TunnelPortalPlacementValid(placementEntity) then
        Tunnel.UndoInvalidPlacement(placementEntity, placer)
        return
    end

    placementEntity.destroy()
    local abovePlacedPortal = aboveSurface.create_entity {name = "railway_tunnel-tunnel_portal_surface-placed", position = centerPos, direction = directionValue, force = force, player = lastUser}
    local portal = {
        id = abovePlacedPortal.unit_number,
        entity = abovePlacedPortal,
        railEntities = {}
    }
    global.tunnel.portals[portal.id] = portal

    local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1}))
    local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
    for _ = 1, Tunnel.setupValues.straightRailCountFromEntrance do
        local placedRail = aboveSurface.create_entity {name = "railway_tunnel-internal_rail-on_map", position = nextRailPos, force = force, direction = directionValue}
        portal.railEntities[placedRail.unit_number] = placedRail
        nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
    end

    local tunnelComplete, tunnelPortals, tunnelSegments = Tunnel.CheckTunnelCompleteFromPortal(abovePlacedPortal, placer)
    if not tunnelComplete then
        return false
    end
    Tunnel.TunnelCompleted(tunnelPortals, tunnelSegments)
end

Tunnel.TunnelPortalPlacementValid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

Tunnel.CheckTunnelCompleteFromPortal = function(startingTunnelPortal, placer)
    local tunnelPortals, tunnelSegments, directionValue, orientation = {startingTunnelPortal}, {}, startingTunnelPortal.direction, startingTunnelPortal.direction / 8
    local startingTunnelPartPoint = Utils.ApplyOffsetToPosition(startingTunnelPortal.position, Utils.RotatePositionAround0(orientation, {x = 0, y = -1 + Tunnel.setupValues.entranceFromCenter}))
    return Tunnel.CheckTunnelPartsInDirection(startingTunnelPortal, startingTunnelPartPoint, tunnelPortals, tunnelSegments, directionValue, placer), tunnelPortals, tunnelSegments
end

Tunnel.PlacementTunnelSegmentSurfaceBuilt = function(placementEntity, placer)
    local centerPos, force, lastUser, directionValue, aboveSurface = placementEntity.position, placementEntity.force, placementEntity.last_user, placementEntity.direction, placementEntity.surface

    if not Tunnel.TunnelSegmentPlacementValid(placementEntity) then
        Tunnel.UndoInvalidPlacement(placementEntity, placer)
        return
    end

    local placedEntityName, placeCrossignRails
    if placementEntity.name == "railway_tunnel-tunnel_segment_surface-placement" then
        placedEntityName = "railway_tunnel-tunnel_segment_surface-placed"
        placeCrossignRails = false
    elseif placementEntity.name == "railway_tunnel-tunnel_segment_surface_rail_crossing-placement" then
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
    local fastReplacedSegmentByPosition, fastReplacedSegment = global.tunnel.tunnelSegmentPositions[tunnelSegment.positionString]
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
    global.tunnel.tunnelSegments[tunnelSegment.id] = tunnelSegment
    global.tunnel.tunnelSegmentPositions[tunnelSegment.positionString] = {
        id = tunnelSegment.positionString,
        tunnelSegment = tunnelSegment
    }
    if fastReplacedSegment ~= nil then
        --TODO: if go from crossing back remove the crossing rails.
        tunnelSegment.railEntities = fastReplacedSegment.railEntities
        tunnelSegment.signalEntities = fastReplacedSegment.signalEntities
        tunnelSegment.tunnel = fastReplacedSegment.tunnel
        for i, checkSegment in pairs(tunnelSegment.tunnel.segments) do
            if checkSegment.id == fastReplacedSegment.id then
                tunnelSegment.tunnel.segments[i] = tunnelSegment
                break
            end
        end
        global.tunnel.tunnelSegments[fastReplacedSegment.id] = nil
    else
        local tunnelComplete, tunnelPortals, tunnelSegments = Tunnel.CheckTunnelCompleteFromSegment(abovePlacedTunnelSegment, placer)
        if not tunnelComplete then
            return false
        end
        Tunnel.TunnelCompleted(tunnelPortals, tunnelSegments)
    end
end

Tunnel.TunnelSegmentPlacementValid = function(placementEntity)
    if placementEntity.position.x % 2 == 0 or placementEntity.position.y % 2 == 0 then
        return false
    else
        return true
    end
end

Tunnel.CheckTunnelCompleteFromSegment = function(startingTunnelSegment, placer)
    local directionComplete
    local tunnelPortals, tunnelSegments, directionValue = {}, {startingTunnelSegment}, startingTunnelSegment.direction
    for _, checkingDirection in pairs({directionValue, Utils.LoopDirectionValue(directionValue + 4)}) do
        -- Check "forwards" and then "backwards".
        directionComplete = Tunnel.CheckTunnelPartsInDirection(startingTunnelSegment, startingTunnelSegment.position, tunnelPortals, tunnelSegments, checkingDirection, placer)
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

Tunnel.CheckTunnelPartsInDirection = function(startingTunnelPart, startingTunnelPartPoint, tunnelPortals, tunnelSegments, checkingDirection, placer)
    local orientation = checkingDirection / 8
    local continueChecking = true
    local nextCheckingPos = startingTunnelPartPoint
    while continueChecking do
        nextCheckingPos = Utils.ApplyOffsetToPosition(nextCheckingPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 2}))
        local connectedTunnelEntities = startingTunnelPart.surface.find_entities_filtered {position = nextCheckingPos, name = TunnelSegmentAndPortalEntityNames, force = startingTunnelPart.force, limit = 1}
        if #connectedTunnelEntities == 0 then
            continueChecking = false
        else
            local connectedTunnelEntity = connectedTunnelEntities[1]
            if connectedTunnelEntity.position.x ~= startingTunnelPart.position.x and connectedTunnelEntity.position.y ~= startingTunnelPart.position.y then
                local textAudience = Utils.GetRenderPlayersForcesFromActioner(placer)
                rendering.draw_text {text = "Tunnel parts must be in a straight line", surface = connectedTunnelEntity.surface, target = connectedTunnelEntity.position, time_to_live = 180, players = textAudience.players, forces = textAudience.forces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
                continueChecking = false
            elseif TunnelSegmentEntityNames[connectedTunnelEntity.name] then
                if connectedTunnelEntity.direction == startingTunnelPart.direction or connectedTunnelEntity.direction == Utils.LoopDirectionValue(startingTunnelPart.direction + 4) then
                    table.insert(tunnelSegments, connectedTunnelEntity)
                else
                    local textAudience = Utils.GetRenderPlayersForcesFromActioner(placer)
                    rendering.draw_text {text = "Tunnel segments must be in the same direction; horizontal or vertical", surface = connectedTunnelEntity.surface, target = connectedTunnelEntity.position, time_to_live = 180, players = textAudience.players, forces = textAudience.forces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
                    continueChecking = false
                end
            elseif TunnelPortalEntityNames[connectedTunnelEntity.name] then
                continueChecking = false
                if connectedTunnelEntity.direction == Utils.LoopDirectionValue(checkingDirection + 4) then
                    table.insert(tunnelPortals, connectedTunnelEntity)
                    return true
                else
                    local textAudience = Utils.GetRenderPlayersForcesFromActioner(placer)
                    rendering.draw_text {text = "Tunnel portal facing wrong direction", surface = connectedTunnelEntity.surface, target = connectedTunnelEntity.position, time_to_live = 180, players = textAudience.players, forces = textAudience.forces, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
                end
            else
                error("unhandled railway_tunnel entity type")
            end
        end
    end
    return false
end

Tunnel.UndoInvalidPlacement = function(placementEntity, placer)
    if placer ~= nil then
        local result
        if placer.is_player() then
            rendering.draw_text {text = "Tunnel must be placed on the rail grid", surface = placementEntity.surface, target = placementEntity.position, time_to_live = 180, players = {placer}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
            result = placer.mine_entity(placementEntity, true)
        else
            -- Is construction bot
            rendering.draw_text {text = "Tunnel must be placed on the rail grid", surface = placementEntity.surface, target = placementEntity.position, time_to_live = 180, forces = {placer.force}, color = {r = 1, g = 0, b = 0, a = 1}, scale_with_zoom = true}
            result = placementEntity.mine({inventory = placer.get_inventory(defines.inventory.robot_cargo), force = true, raise_destroyed = false, ignore_minable = true})
        end
        if result ~= true then
            error("couldn't mine invalidly placed tunnel placement entity")
        end
    end
end

Tunnel.TunnelCompleted = function(tunnelPortalEntities, tunnelSegmentEntities)
    local tunnelPortals, tunnelSegments, refTunnelPortalEntity = {}, {}, tunnelPortalEntities[1]
    local force, aboveSurface = tunnelPortalEntities[1].force, tunnelPortalEntities[1].surface

    -- Handle the portal entities.
    for _, portalEntity in pairs(tunnelPortalEntities) do
        local portal = global.tunnel.portals[portalEntity.unit_number]
        table.insert(tunnelPortals, portal)
        local centerPos, directionValue = portalEntity.position, portalEntity.direction
        local orientation = directionValue / 8
        local entracePos = Utils.ApplyOffsetToPosition(centerPos, Utils.RotatePositionAround0(orientation, {x = 0, y = 0 - Tunnel.setupValues.entranceFromCenter}))

        local nextRailPos = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 0, y = 1 + (Tunnel.setupValues.straightRailCountFromEntrance * 2)}))
        local railOffsetFromEntrancePos = Utils.RotatePositionAround0(orientation, {x = 0, y = 2}) -- Steps away from the entrance position by rail placement
        for _ = 1, Tunnel.setupValues.invisibleRailCountFromEntrance do
            local placedRail = aboveSurface.create_entity {name = "railway_tunnel-invisible_rail", position = nextRailPos, force = force, direction = directionValue}
            portal.railEntities[placedRail.unit_number] = placedRail
            nextRailPos = Utils.ApplyOffsetToPosition(nextRailPos, railOffsetFromEntrancePos)
        end

        local entrySignalInEntity =
            aboveSurface.create_entity {
            name = "rail-signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = 0.5 + Tunnel.setupValues.entrySignalsDistance})),
            force = force,
            direction = directionValue
        }
        global.tunnel.entrySignals[entrySignalInEntity.unit_number] = {
            id = entrySignalInEntity.unit_number,
            entity = entrySignalInEntity,
            portal = portal
        }
        local entrySignalOutEntity =
            aboveSurface.create_entity {
            name = "rail-signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = 0.5 + Tunnel.setupValues.entrySignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        global.tunnel.entrySignals[entrySignalOutEntity.unit_number] = {
            id = entrySignalOutEntity.unit_number,
            entity = entrySignalOutEntity,
            portal = portal
        }
        portal.entrySignals = {["in"] = global.tunnel.entrySignals[entrySignalInEntity.unit_number], ["out"] = global.tunnel.entrySignals[entrySignalOutEntity.unit_number]}

        local endSignalInEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = -1.5, y = -0.5 + Tunnel.setupValues.endSignalsDistance})),
            force = force,
            direction = directionValue
        }
        global.tunnel.endSignals[endSignalInEntity.unit_number] = {
            id = endSignalInEntity.unit_number,
            entity = endSignalInEntity,
            portal = portal
        }
        local endSignalOutEntity =
            aboveSurface.create_entity {
            name = "railway_tunnel-tunnel_portal_end_rail_signal",
            position = Utils.ApplyOffsetToPosition(entracePos, Utils.RotatePositionAround0(orientation, {x = 1.5, y = -0.5 + Tunnel.setupValues.endSignalsDistance})),
            force = force,
            direction = Utils.LoopDirectionValue(directionValue + 4)
        }
        global.tunnel.endSignals[endSignalOutEntity.unit_number] = {
            id = endSignalOutEntity.unit_number,
            entity = endSignalOutEntity,
            portal = portal
        }
        portal.endSignals = {["in"] = global.tunnel.endSignals[endSignalInEntity.unit_number], ["out"] = global.tunnel.endSignals[endSignalOutEntity.unit_number]}
        endSignalInEntity.connect_neighbour {wire = defines.wire_type.red, target_entity = endSignalOutEntity}
        Tunnel.SetRailSignalRed(endSignalInEntity)
        Tunnel.SetRailSignalRed(endSignalOutEntity)
    end

    --Handle the tunnel segment entities.
    for _, tunnelSegmentEntity in pairs(tunnelSegmentEntities) do
        local tunnelSegment = global.tunnel.tunnelSegments[tunnelSegmentEntity.unit_number]
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

    -- Create the tunnel global object.
    local tunnelId, alignment, alignmentOrientation, undergroundSurface = #global.tunnel.tunnels, "vertical", 0, global.underground.verticalSurface
    if refTunnelPortalEntity.direction == defines.direction.east or refTunnelPortalEntity.direction == defines.direction.west then
        alignment = "horizontal"
        alignmentOrientation = 0.25
        undergroundSurface = global.underground.horizontalSurface
    end
    local tunnel = {
        id = tunnelId,
        alignment = alignment,
        alignmentOrientation = alignmentOrientation,
        aboveSurface = refTunnelPortalEntity.surface,
        undergroundSurface = undergroundSurface,
        portals = tunnelPortals,
        segments = tunnelSegments
    }
    global.tunnel.tunnels[tunnelId] = tunnel
    for _, portal in pairs(tunnelPortals) do
        portal.tunnel = tunnel
    end
    for _, segment in pairs(tunnelSegments) do
        segment.tunnel = tunnel
    end

    -- Create the underground entities for this tunnel.
    tunnel.undergroundRailEntities, tunnel.undergroundModifiers = {}, {}
    if alignment == "vertical" then
        tunnel.undergroundModifiers.railAlignmentAxis = "y"
        tunnel.undergroundModifiers.tunnelInstanceAxis = "x"
        tunnel.undergroundModifiers.tunnelInstanceValue = tunnel.id * 10
    else
        tunnel.undergroundModifiers.railAlignmentAxis = "x"
        tunnel.undergroundModifiers.tunnelInstanceAxis = "y"
        tunnel.undergroundModifiers.tunnelInstanceValue = tunnel.id * 10
    end
    tunnel.undergroundModifiers.tunnelInstanceClonedTrainValue = tunnel.undergroundModifiers.tunnelInstanceValue + 4
    tunnel.undergroundModifiers.distanceFromCenterToPortalEntrySignals = Utils.GetDistanceSingleAxis(tunnel.portals[1].entrySignals["in"].entity.position, tunnel.portals[2].entrySignals["in"].entity.position, tunnel.undergroundModifiers.railAlignmentAxis) / 2
    tunnel.undergroundModifiers.distanceFromCenterToPortalEndSignals = Utils.GetDistanceSingleAxis(tunnel.portals[1].endSignals["in"].entity.position, tunnel.portals[2].endSignals["in"].entity.position, tunnel.undergroundModifiers.railAlignmentAxis) / 2
    local offsetTrackDistance = tunnel.undergroundModifiers.distanceFromCenterToPortalEntrySignals + Tunnel.setupValues.undergroundLeadInTiles
    -- Place the tracks underground that the train will be copied on to and run on.
    for valueVariation = -offsetTrackDistance, offsetTrackDistance, 2 do
        table.insert(tunnel.undergroundRailEntities, tunnel.undergroundSurface.create_entity {name = "straight-rail", position = {[tunnel.undergroundModifiers.railAlignmentAxis] = valueVariation, [tunnel.undergroundModifiers.tunnelInstanceAxis] = tunnel.undergroundModifiers.tunnelInstanceValue}, force = force, direction = refTunnelPortalEntity.direction})
    end
end

Tunnel.SetRailSignalRed = function(signal)
    local controlBehavour = signal.get_or_create_control_behavior()
    controlBehavour.read_signal = false
    controlBehavour.close_signal = true
    controlBehavour.circuit_condition = {condition = {first_signal = {type = "virtual", name = "signal-red"}, comparator = "="}, constant = 0}
end

return Tunnel
