local Utils = require("utility.utils")
local Common = {}

-- Make the entity lists.
---@typelist table<string, string>, table<string, string>, table<string, string>, table<string, string>
Common.PortalEndEntityNames = {["railway_tunnel-portal_end"] = "railway_tunnel-portal_end"}
Common.PortalSegmentEntityNames = {
    ["railway_tunnel-portal_segment-straight"] = "railway_tunnel-portal_segment-straight",
    ["railway_tunnel-portal_segment-curved-regular"] = "railway_tunnel-portal_segment-curved-regular",
    ["railway_tunnel-portal_segment-curved-flipped"] = "railway_tunnel-portal_segment-curved-flipped"
}
Common.UndergroundSegmentEntityNames = {
    ["railway_tunnel-underground_segment-straight"] = "railway_tunnel-underground_segment-straight",
    ["railway_tunnel-underground_segment-straight-rail_crossing"] = "railway_tunnel-underground_segment-straight-rail_crossing",
    ["railway_tunnel-underground_segment-straight-tunnel_crossing"] = "railway_tunnel-underground_segment-straight-tunnel_crossing",
    ["railway_tunnel-underground_segment-curved-regular"] = "railway_tunnel-underground_segment-curved-regular",
    ["railway_tunnel-underground_segment-curved-flipped"] = "railway_tunnel-underground_segment-curved-flipped",
    ["railway_tunnel-underground_segment-diagonal-regular"] = "railway_tunnel-underground_segment-diagonal-regular",
    ["railway_tunnel-underground_segment-diagonal-flipped"] = "railway_tunnel-underground_segment-diagonal-flipped",
    ["railway_tunnel-underground_segment-corner"] = "railway_tunnel-underground_segment-corner"
}
Common.PortalEndAndSegmentEntityNames = Utils.TableMergeCopies({Common.PortalEndEntityNames, Common.PortalSegmentEntityNames}) ---@type table<string, string>
Common.UndergroundSegmentAndAllPortalEntityNames = Utils.TableMergeCopies({Common.UndergroundSegmentEntityNames, Common.PortalEndAndSegmentEntityNames}) ---@type table<string, string>
Common.RealTunnelPartNameToFakeTunnelPartName = {
    ["railway_tunnel-underground_segment-curved-regular"] = "railway_tunnel-underground_segment-curved-flipped",
    ["railway_tunnel-portal_segment-curved-regular"] = "railway_tunnel-portal_segment-curved-flipped",
    ["railway_tunnel-underground_segment-diagonal-regular"] = "railway_tunnel-underground_segment-diagonal-flipped"
}
Common.FakeTunnelPartNameToRealTunnelPartName = {
    ["railway_tunnel-underground_segment-curved-flipped"] = "railway_tunnel-underground_segment-curved-regular",
    ["railway_tunnel-portal_segment-curved-flipped"] = "railway_tunnel-portal_segment-curved-regular",
    ["railway_tunnel-underground_segment-diagonal-flipped"] = "railway_tunnel-underground_segment-diagonal-regular"
}
Common.FakeAndRealTunnelPartNames = {
    ["railway_tunnel-underground_segment-curved-regular"] = "railway_tunnel-underground_segment-curved-regular",
    ["railway_tunnel-underground_segment-curved-flipped"] = "railway_tunnel-underground_segment-curved-flipped",
    ["railway_tunnel-portal_segment-curved-regular"] = "railway_tunnel-portal_segment-curved-regular",
    ["railway_tunnel-portal_segment-curved-flipped"] = "railway_tunnel-portal_segment-curved-flipped",
    ["railway_tunnel-underground_segment-diagonal-regular"] = "railway_tunnel-underground_segment-diagonal-regular",
    ["railway_tunnel-underground_segment-diagonal-flipped"] = "railway_tunnel-underground_segment-diagonal-flipped"
}

---@class TunnelRailEntityNames
Common.TunnelRailEntityNames = {
    -- Doesn't include the tunnel crossing rail as this isn't deemed part of the tunnel's rails.
    ["railway_tunnel-portal_rail-on_map"] = "railway_tunnel-portal_rail-on_map",
    ["railway_tunnel-internal_rail-not_on_map"] = "railway_tunnel-internal_rail-not_on_map",
    ["railway_tunnel-internal_rail-on_map_tunnel"] = "railway_tunnel-internal_rail-on_map_tunnel",
    ["railway_tunnel-invisible_rail-straight-on_map_tunnel"] = "railway_tunnel-invisible_rail-straight-on_map_tunnel",
    ["railway_tunnel-invisible_rail-curved-on_map_tunnel"] = "railway_tunnel-invisible_rail-curved-on_map_tunnel"
}

---@class RollingStockTypes
Common.RollingStockTypes = {
    ["locomotive"] = "locomotive",
    ["cargo-wagon"] = "cargo-wagon",
    ["fluid-wagon"] = "fluid-wagon",
    ["artillery-wagon"] = "artillery-wagon"
}

--- The distance from the center of the carriage to the end of it for when placing carriages. This is half the combined connection and joint distance of the carriage.
---
--- Hardcoded values as can't get the connection and joint distance via API.
---@class CarriagePlacementDistances
Common.CarriagePlacementDistances = {
    ["locomotive"] = 3.5,
    ["cargo-wagon"] = 3.5,
    ["fluid-wagon"] = 3.5,
    ["artillery-wagon"] = 3.5
}

--- Gets the combined connection and joint distance of the carriage.
---
--- Hardcoded values as can't get the connection and joint distance via API.
---@class CarriageConnectedLengths
Common.CarriageConnectedLengths = {
    ["locomotive"] = 7,
    ["cargo-wagon"] = 7,
    ["fluid-wagon"] = 7,
    ["artillery-wagon"] = 7
}

--- Gets the gap that the carriage has at one end of its entity when it connects to another carriage.
---
--- Hardcoded values as can't get the connection and joint distance via API.
---
--- This is the: (carriages connected length - double connection distance) / 2 as only 1 end of the entities total gap.
---
--- vanilla wagons: ( (3+4) - (3*2) ) / 2
---@class CarriageInterConnectionGaps
Common.CarriagesOwnOffsetFromOtherConnectedCarriage = {
    ["locomotive"] = 0.5,
    ["cargo-wagon"] = 0.5,
    ["fluid-wagon"] = 0.5,
    ["artillery-wagon"] = 0.5
}

--- Gets the carriages collision box length.
---
--- Hardcoded as we have to hardcoded other values and it saves having to obtain these specially during the right data lifecycle stage (control.lua when this file is loaded doesn't allow game or data access).
Common.CarriagesCollisionBoxLength = {
    ["locomotive"] = 5.2,
    ["cargo-wagon"] = 4.8,
    ["fluid-wagon"] = 4.8,
    ["artillery-wagon"] = 4.8
}

---@class TunnelSignalDirection
Common.TunnelSignalDirection = {
    inSignal = "inSignal",
    outSignal = "outSignal"
}

--- The managed train's state. Finished is for when the tunnel trip is completed.
---@class TunnelUsageState
Common.TunnelUsageState = {
    portalTrack = "portalTrack",
    approaching = "approaching",
    underground = "underground",
    leaving = "leaving",
    finished = "finished"
}

--- The train's action to new state - Used by the train manager remote for state notifications to remote interface calls.
---@class TunnelUsageAction
Common.TunnelUsageAction = {
    startApproaching = "startApproaching",
    onPortalTrack = "onPortalTrack",
    entered = "entered",
    leaving = "leaving",
    terminated = "terminated"
}

--- The train's state change reason - Used by the train manager remote for state notifications to remote interface calls.
---@class TunnelUsageChangeReason
Common.TunnelUsageChangeReason = {
    reversedAfterLeft = "reversedAfterLeft",
    abortedApproach = "abortedApproach",
    completedTunnelUsage = "completedTunnelUsage",
    tunnelRemoved = "tunnelRemoved",
    portalTrackReleased = "portalTrackReleased",
    invalidTrain = "invalidTrain"
}

return Common
