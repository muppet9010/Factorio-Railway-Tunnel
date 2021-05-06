local EventScheduler = require("utility/event-scheduler")
local TunnelManager = require("scripts/tunnel-manager")
local TunnelPortals = require("scripts/tunnel-portals")
local TunnelSegments = require("scripts/tunnel-segments")
local Underground = require("scripts/underground")
local TrainManager = require("scripts/train-manager")
local TestManager = require("scripts/test-manager")
local Force = require("scripts/force")
local PlayerContainers = require("scripts/player-containers")

local function CreateGlobals()
    TrainManager.CreateGlobals()
    TunnelManager.CreateGlobals()
    TunnelPortals.CreateGlobals()
    TunnelSegments.CreateGlobals()
    Underground.CreateGlobals()
    Force.CreateGlobals()
    PlayerContainers.CreateGlobals()

    TestManager.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    TrainManager.OnLoad()
    TunnelManager.OnLoad()
    TunnelPortals.OnLoad()
    TunnelSegments.OnLoad()
    Underground.OnLoad()
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
    Underground.OnStartup()
    Force.OnStartup()
    TrainManager.OnStartup()

    TestManager.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
