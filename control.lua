local EventScheduler = require("utility/event-scheduler")
local Tunnel = require("scripts/tunnel")
local Portal = require("scripts/portal")
local Underground = require("scripts/underground")
local TrainManager = require("scripts/train-manager")
local TrainManagerRemote = require("scripts/train-manager-remote")
local TestManager = require("scripts/test-manager")
local Force = require("scripts/force")
local PlayerContainer = require("scripts/player-container")
local Events = require("utility/events")
local Commands = require("utility/commands")

local function CreateGlobals()
    global.debugRelease = false -- If set to TRUE (test-manager or command) it runs key mod logic code in a try/catch and it does UPS intensive state check so makes code run slower.

    Force.CreateGlobals()
    TrainManager.CreateGlobals()
    TrainManagerRemote.CreateGlobals()
    PlayerContainer.CreateGlobals()
    Tunnel.CreateGlobals()
    Portal.CreateGlobals()
    Underground.CreateGlobals()

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
                return Tunnel.Remote_GetTunnelDetailsForId(tunnelId)
            end,
            ---@param entityUnitNumber UnitNumber
            ---@return RemoteTunnelDetails
            get_tunnel_details_for_entity_unit_number = function(entityUnitNumber)
                return Tunnel.Remote_GetTunnelDetailsForEntityUnitNumber(entityUnitNumber)
            end
        }
    )

    -- Handle the debugRelease global setting.
    Commands.Register(
        "railway_tunnel_toggle_debug_state",
        ": toggles debug handling of mod logic",
        function()
            if global.debugRelease then
                global.debugRelease = false
                game.print("Disabled Railway Tunnel mod's debug handling")
            else
                global.debugRelease = true
                game.print("Enabled Railway Tunnel mod's debug handling")
            end
        end,
        true
    )

    -- Call the module's OnLoad functions.
    TrainManager.OnLoad()
    Tunnel.OnLoad()
    Portal.OnLoad()
    Underground.OnLoad()
    PlayerContainer.OnLoad()

    -- Start the test manager last.
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

-- Mod wide function interface table creation. Means EmmyLua can support it and saves on UPS cost of old Interface function middelayer.
---@class InternalInterfaces
MOD.Interfaces = MOD.Interfaces or {} ---@type table<string, function>
--[[
    Populate and use from within module's OnLoad() functions with simple table reference structures, i.e:
        MOD.Interfaces.Tunnel = MOD.Interfaces.Tunnel or {}
        MOD.Interfaces.Tunnel.CompleteTunnel = Tunnel.CompleteTunnel
--]]
--
