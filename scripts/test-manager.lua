local TestManager = {}
local Events = require("utility/events")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")

local doDemo = false -- Does the demo rather than any enabled tests.
local doTests = true -- Does the enabled tests below.
local doAllTests = false -- Does all the tests regardless of their enabled state below.

local testsToRun
if doTests then
    testsToRun = {
        shortTunnelShortTrainEastToWest = {enabled = true, testScript = require("tests/short-tunnel-short-train-east-to-west")},
        shortTunnelShortTrainWestToEast = {enabled = false, testScript = require("tests/short-tunnel-short-train-west-to-east")},
        shortTunnelShortTrainNorthToSouth = {enabled = false, testScript = require("tests/short-tunnel-short-train-north-to-south")},
        shortTunnelLongTrainWestToEastCurvedApproach = {enabled = false, testScript = require("tests/short-tunnel-long-train-west-to-east-curved-approach")},
        repathOnApproach = {enabled = false, testScript = require("tests/repath-on-approach")},
        doubleRepathOnApproach = {enabled = false, testScript = require("tests/double-repath-on-approach")},
        pathingKeepReservation = {enabled = false, testScript = require("tests/pathing-keep-reservation")},
        pathingKeepReservationNoGap = {enabled = false, testScript = require("tests/pathing-keep-reservation-no-gap")},
        tunnelInUseNotLeavePortal = {enabled = false, testScript = require("tests/tunnel-in-use-not-leave-portal")},
        tunnelInUseWaitingTrains = {enabled = false, testScript = require("tests/tunnel-in-use-waiting-trains")},
        pathfinderWeightings = {enabled = false, testScript = require("tests/pathfinder-weightings")},
        inwardFacingTrain = {enabled = false, testScript = require("tests/inward-facing-train")},
        inwardFacingTrainBlockedExitLeaveTunnel = {enabled = false, testScript = require("tests/inward-facing-train-blocked-exit-leave-tunnel")},
        inwardFacingTrainBlockedExitDoesntLeaveTunnel = {enabled = false, testScript = require("tests/inward-facing-train-blocked-exit-doesnt-leave-tunnel")}
    }
end

TestManager.CreateGlobals = function()
    global.testManager = global.testManager or {}
    global.testManager.testsRun = global.testManager.testsRun or false -- Used to flag when a save was started with tests already.
    global.testManager.testSurface = global.testManager.testSurface or nil
    global.testManager.playerForce = global.testManager.playerForce or nil
end

TestManager.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("TestManager.RunTests", TestManager.RunTests)
    Events.RegisterHandlerEvent(defines.events.on_player_created, "TestManager.OnPlayerCreated", TestManager.OnPlayerCreated)
    EventScheduler.RegisterScheduledEventType("TestManager.OnPlayerCreatedMakeCharacter", TestManager.OnPlayerCreatedMakeCharacter)
end

TestManager.OnStartup = function()
    if ((not doTests) and (not doDemo)) or global.testManager.testsRun then
        return
    end
    global.testManager.testsRun = true

    global.testManager.testSurface = game.surfaces[1]
    global.testManager.playerForce = game.forces["player"]
    local playerForce = global.testManager.playerForce

    playerForce.character_running_speed_modifier = 10
    playerForce.character_build_distance_bonus = 100
    playerForce.character_reach_distance_bonus = 100

    local testSurface = global.testManager.testSurface
    testSurface.generate_with_lab_tiles = true
    testSurface.always_day = true
    testSurface.freeze_daytime = true
    testSurface.show_clouds = false

    for chunk in testSurface.get_chunks() do
        testSurface.delete_chunk({x = chunk.x, y = chunk.y})
    end

    Utils.SetStartingMapReveal(500) --Generate tiles around spawn, needed for blueprints to be placed in this area.
    EventScheduler.ScheduleEventOnce(game.tick + 120, "TestManager.RunTests") -- Have to give it time to chart the revealed area.
end

TestManager.RunTests = function()
    game.tick_paused = true

    -- Do the demo and not any tests if it is enabled.
    if doDemo then
        testsToRun = {
            demo = {enabled = true, testScript = require("tests/demo")}
        }
    end

    for testName, test in pairs(testsToRun) do
        if test.enabled or doAllTests then
            test.testScript.Start(TestManager, testName)
        end
    end

    global.testManager.playerForce.chart_all(global.testManager.testSurface)
end

TestManager.OnPlayerCreated = function(event)
    if ((not doTests) and (not doDemo)) then
        return
    end
    local player = game.get_player(event.player_index)
    if player.controller_type == defines.controllers.cutscene then
        player.exit_cutscene()
    end

    TestManager.OnPlayerCreatedMakeCharacter({instanceId = player.index})
end

TestManager.OnPlayerCreatedMakeCharacter = function(event)
    -- Add a character since it was lost in surface destruction. Then go to Map Editor, that way if we leave map editor we have a character to return to.
    local player = game.get_player(event.instanceId)
    if player.character == nil then
        local characterCreated = player.create_character()
        if characterCreated == false then
            -- Character can't create yet, try again later.
            EventScheduler.ScheduleEventOnce(game.tick + 1, "TestManager.OnPlayerCreatedMakeCharacter", player.index)
            return
        end
    end
    local tickWasPaused = game.tick_paused
    player.toggle_map_editor()
    game.tick_paused = tickWasPaused
end

TestManager.BuildBlueprintFromString = function(blueprintString, position, testName)
    -- Utility function to build a blueprint from a string on the test surface.
    -- Makes sure that trains in the blueprint are properly built, their fuel requests are fulfilled and the trains are set to automatic.
    local testSurface = global.testManager.testSurface
    local player = game.connected_players[1]
    local itemStack = player.cursor_stack

    itemStack.clear()
    if itemStack.import_stack(blueprintString) ~= 0 then
        error("Error importing blueprint string for test: " .. testName)
    end
    if Utils.IsTableEmpty(itemStack.cost_to_build) then
        error("Blank blueprint used in test: " .. testName)
    end

    local ghosts =
        itemStack.build_blueprint {
        surface = testSurface,
        force = global.testManager.playerForce,
        position = position,
        by_player = player
    }
    if #ghosts == 0 then
        error("Blueprint in test failed to place, likely outside of generated/revealed area. Test: " .. testName)
    end
    itemStack.clear()

    local pass2Ghosts = {}
    local fuelProxies = {}

    for _, ghost in pairs(ghosts) do
        local r, _, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if r == nil then
            -- train ghosts can't be revived before the rail underneath
            -- them, so save failed ghosts for a second pass
            table.insert(pass2Ghosts, ghost)
        end
        if fuelProxy ~= nil then
            table.insert(fuelProxies, fuelProxy)
        end
    end

    for _, ghost in pairs(pass2Ghosts) do
        local r, _, fuelProxy = ghost.silent_revive({raise_revive = true, return_item_request_proxy = true})
        if r == nil then
            error("only 2 rounds of ghost reviving supported. Test: " .. testName)
        end
        if fuelProxy ~= nil then
            table.insert(fuelProxies, fuelProxy)
        end
    end

    for _, fuelProxy in pairs(fuelProxies) do
        for item, count in pairs(fuelProxy.item_requests) do
            fuelProxy.proxy_target.insert({name = item, count = count})
        end
        fuelProxy.destroy()
    end

    for _, train in pairs(testSurface.get_trains()) do
        train.manual_mode = false
    end
end

return TestManager
