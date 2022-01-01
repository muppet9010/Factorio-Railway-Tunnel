local EventScheduler = require("utility/event-scheduler")
local TunnelManager = require("scripts/tunnel-manager")
local TunnelPortals = require("scripts/tunnel-portals")
local UndergroundSegments = require("scripts/underground-segments")
local TrainManager = require("scripts/train-manager")
local TrainManagerRemote = require("scripts/train-manager-remote")
local TestManager = require("scripts/test-manager")
local Force = require("scripts/force")
local TrainManagerPlayerContainers = require("scripts/train-manager-player-containers")
local Events = require("utility/events")

local function CreateGlobals()
    global.debugRelease = true -- If TRUE it runs key code in a try/catch and it does UPS intensive state check so makes code run slower.
    global.strictStateHandling = true -- If TRUE unexpected edge cases will raise an error, otherwise they just print to the screen and are handled in some rought manner. -- OVERHAUL - these scenarios should be removed and made to behave in a standard supported manner.

    Force.CreateGlobals()
    TrainManager.CreateGlobals()
    TrainManagerRemote.CreateGlobals()
    TrainManagerPlayerContainers.CreateGlobals()
    TunnelManager.CreateGlobals()
    TunnelPortals.CreateGlobals()
    UndergroundSegments.CreateGlobals()

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
            ---@param managedTrainId Id
            ---@return TunnelUsageEntry
            get_tunnel_usage_entry_for_id = function(managedTrainId)
                return TrainManagerRemote.GetTunnelUsageEntry(managedTrainId)
            end,
            ---@param trainId Id
            ---@return TunnelUsageEntry
            get_tunnel_usage_entry_for_train = function(trainId)
                return TrainManagerRemote.GetATrainsTunnelUsageEntry(trainId)
            end,
            ---@return table<string, string>
            get_temporary_carriage_names = function()
                return TrainManagerRemote.GetTemporaryCarriageNames()
            end,
            ---@param tunnelId Id
            ---@return RemoteTunnelDetails
            get_tunnel_details_for_id = function(tunnelId)
                return TunnelManager.Remote_GetTunnelDetailsForId(tunnelId)
            end,
            ---@param entityUnitNumber UnitNumber
            ---@return RemoteTunnelDetails
            get_tunnel_details_for_entity_unit_number = function(entityUnitNumber)
                return TunnelManager.Remote_GetTunnelDetailsForEntityUnitNumber(entityUnitNumber)
            end
        }
    )

    TrainManager.OnLoad()
    TunnelManager.OnLoad()
    TunnelPortals.OnLoad()
    UndergroundSegments.OnLoad()
    TrainManagerPlayerContainers.OnLoad()

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

    TestManager.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
