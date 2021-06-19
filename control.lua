local EventScheduler = require("utility/event-scheduler")
local TunnelManager = require("scripts/tunnel-manager")
local TunnelPortals = require("scripts/tunnel-portals")
local TunnelSegments = require("scripts/tunnel-segments")
local Underground = require("scripts/underground")
local TrainManager = require("scripts/train-manager")
local TestManager = require("scripts/test-manager")
local Force = require("scripts/force")
local PlayerContainers = require("scripts/player-containers")
local Events = require("utility/events")

---@class Id:int|string @id attribute of this thing.
---@class UnitNumber:int @unit_number of the related entity.
---@alias Axis "'x'"|"'y'"
---@class PlayerIndex:int @Player index attribute.
---@alias EntityBuildPlacer LuaPlayer|LuaEntity|nil @The placer of a built entity: either player, construction robot or script(nil).
---@class Ticks:int
---@class Seconds:int

local function CreateGlobals()
    global.debugRelease = true -- If TRUE it runs key code in a try/catch. Makes code run slower technically.

    Force.CreateGlobals()
    TrainManager.CreateGlobals()
    TunnelManager.CreateGlobals()
    TunnelPortals.CreateGlobals()
    TunnelSegments.CreateGlobals()
    Underground.CreateGlobals()
    PlayerContainers.CreateGlobals()

    TestManager.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    remote.remove_interface("railway_tunnel")
    local tunnelUsageChangedEventId = Events.RegisterCustomEventName("RailwayTunnel.TunnelUsageChanged")
    remote.add_interface(
        "railway_tunnel",
        {
            ---@return defines.events
            get_tunnel_usage_changed_event_id = function()
                return tunnelUsageChangedEventId
            end,
            ---@param managedTrainId ManagedTrainId
            ---@return TunnelUsageEntry
            get_tunnel_usage_entry_for_id = function(managedTrainId)
                return TrainManager.Remote_GetTunnelUsageEntry(managedTrainId)
            end,
            ---@param trainId Id
            ---@return TunnelUsageEntry
            get_tunnel_usage_entry_for_train = function(trainId)
                return TrainManager.Remote_GetATrainsTunnelUsageEntry(trainId)
            end,
            ---@return table<string, string>
            get_temporary_carriage_names = function()
                return TrainManager.Remote_GetTemporaryCarriageNames()
            end,
            ---@param tunnelId Id
            ---@return TunnelDetails
            get_tunnel_details_for_id = function(tunnelId)
                return TunnelManager.Remote_GetTunnelDetailsForId(tunnelId)
            end,
            ---@param entityUnitNumber UnitNumber
            ---@return TunnelDetails
            get_tunnel_details_for_entity = function(entityUnitNumber)
                return TunnelManager.Remote_GetTunnelDetailsForEntity(entityUnitNumber)
            end
        }
    )

    Underground.PreOnLoad() -- Do things that other OnLoad()s need.

    TrainManager.OnLoad()
    TunnelManager.OnLoad()
    TunnelPortals.OnLoad()
    TunnelSegments.OnLoad()
    PlayerContainers.OnLoad()

    TestManager.OnLoad()
end

--local function OnSettingChanged(event)
--if event == nil or event.setting == "xxxxx" then
--	local x = tonumber(settings.global["xxxxx"].value)
--end
--end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    --OnSettingChanged(nil)
    Force.OnStartup()
    Underground.OnStartup()

    TestManager.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
