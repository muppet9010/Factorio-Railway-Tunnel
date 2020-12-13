local Tunnel = require("scripts/tunnel")
local EventScheduler = require("utility/event-scheduler")
local Underground = require("scripts/underground")
local TrainManager = require("scripts/train-manager")
local TestManager = require("scripts/test-manager")

local function CreateGlobals()
    TrainManager.CreateGlobals()
    Tunnel.CreateGlobals()
    Underground.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    TrainManager.OnLoad()
    Tunnel.OnLoad()
    Underground.OnLoad()
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

    TestManager.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
--script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
