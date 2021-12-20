local Utils = require("utility/utils")
local Common = {}

-- Make the entity lists.
---@typelist table<string, string>, table<string, string>, table<string, string>, table<string, string>
Common.PortalEndEntityNames = {["railway_tunnel-portal_end"] = "railway_tunnel-portal_end"}
Common.PortalSegmentEntityNames = {["railway_tunnel-portal_segment-straight"] = "railway_tunnel-portal_segment-straight"}
Common.UndergroundSegmentEntityNames = {["railway_tunnel-underground_segment-straight"] = "railway_tunnel-underground_segment-straight", ["railway_tunnel-underground_segment-straight-rail_crossing"] = "railway_tunnel-underground_segment-straight-rail_crossing"}
Common.PortalEndAndSegmentEntityNames = Utils.TableMerge({Common.PortalEndEntityNames, Common.PortalSegmentEntityNames}) ---@type table<string, string>
Common.UndergroundSegmentAndAllPortalEntityNames = Utils.TableMerge({Common.UndergroundSegmentEntityNames, Common.PortalEndAndSegmentEntityNames}) ---@type table<string, string>

---@class TunnelSurfaceRailEntityNames
Common.TunnelSurfaceRailEntityNames = {
    -- Doesn't include the tunnel crossing rail as this isn't deemed part of the tunnel's rails.
    ["railway_tunnel-portal_rail-on_map"] = "railway_tunnel-portal_rail-on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-internal_rail-not_on_map"] = "railway_tunnel-internal_rail-not_on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-internal_rail-on_map_tunnel"] = "railway_tunnel-internal_rail-on_map_tunnel", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-invisible_rail-not_on_map"] = "railway_tunnel-invisible_rail-not_on_map", ---@type TunnelSurfaceRailEntityNames
    ["railway_tunnel-invisible_rail-on_map_tunnel"] = "railway_tunnel-invisible_rail-on_map_tunnel" ---@type TunnelSurfaceRailEntityNames
}

---@class RollingStockTypes
Common.RollingStockTypes = {
    ["locomotive"] = "locomotive", ---@type RollingStockTypes
    ["cargo-wagon"] = "cargo-wagon", ---@type RollingStockTypes
    ["fluid-wagon"] = "fluid-wagon", ---@type RollingStockTypes
    ["artillery-wagon"] = "artillery-wagon" ---@type RollingStockTypes
}

-- Gets the distance from the center of the carriage to the end of it for when placing carriages.
---@param carriageEntityName string @The entity name.
---@return double
Common.GetCarriagePlacementDistance = function(carriageEntityName)
    -- For now we assume all unknown carriages have a gap of 7 as we can't get the connection and joint distance via API. Can hard code custom values in future if needed.
    if carriageEntityName ~= nil then
        return 3.5 -- Half of vanilla carriages 7 joint and connection distance.
    end
end

---@class TunnelAlignment
Common.TunnelAlignment = {
    vertical = "vertical",
    horizontal = "horizontal"
}

---@class TunnelAlignmentOrientation
Common.TunnelAlignmentOrientation = {
    vertical = 0,
    horizontal = 0.25
}

---@class TunnelSignalDirection
Common.TunnelSignalDirection = {
    inSignal = "inSignal",
    outSignal = "outSignal"
}

-- The managed train's state. Finished is for when the tunnel trip is completed.
---@class PrimaryTrainState
Common.PrimaryTrainState = {
    portalTrack = "portalTrack", ---@type PrimaryTrainState
    approaching = "approaching", ---@type PrimaryTrainState
    underground = "underground", ---@type PrimaryTrainState
    leaving = "leaving", ---@type PrimaryTrainState
    finished = "finished" ---@type PrimaryTrainState
}

-- A specific LuaTrain's role within its parent managed train object.
---@class TunnelUsageParts
Common.TunnelUsageParts = {
    enteringTrain = "enteringTrain", ---@type TunnelUsageParts
    leavingTrain = "leavingTrain", ---@type TunnelUsageParts
    portalTrackTrain = "portalTrackTrain", ---@type TunnelUsageParts
    dummyTrain = "dummyTrain" ---@type TunnelUsageParts
}

-- The train's state - Used by the train manager remote for state notifications to remote interface calls.
---@class TunnelUsageAction
Common.TunnelUsageAction = {
    startApproaching = "startApproaching", ---@type TunnelUsageAction
    terminated = "terminated", ---@type TunnelUsageAction
    entered = "entered", ---@type TunnelUsageAction
    leaving = "leaving", ---@type TunnelUsageAction
    onPortalTrack = "onPortalTrack" ---@type TunnelUsageAction
}

-- The train's state change reason - Used by the train manager remote for state notifications to remote interface calls.
---@class TunnelUsageChangeReason
Common.TunnelUsageChangeReason = {
    reversedAfterLeft = "reversedAfterLeft", ---@type TunnelUsageChangeReason
    abortedApproach = "abortedApproach", ---@type TunnelUsageChangeReason
    completedTunnelUsage = "completedTunnelUsage", ---@type TunnelUsageChangeReason
    tunnelRemoved = "tunnelRemoved", ---@type TunnelUsageChangeReason
    portalTrackReleased = "portalTrackReleased" ---@type TunnelUsageChangeReason
}

---@class SurfacePositionString @the entities surface and position as a string: "surfaceId_x,y"

return Common
