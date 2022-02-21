--[[
    A series of tests that destroys the tunnel parts during various states of use by a train with a player riding in it.
    If the player is underground then they are killed, otherwise they are ejected from the carriage on to the surface.
    Does have a down side that the player dies and I haven't found a way to avoid the respawn screen. Tried creating a character post death and changing the controller type.
]]
local Test = {}
local TestFunctions = require("scripts.test-functions")
local Common = require("scripts.common")

---@class Tests_PRDTT_DestroyOnTunnelAction
local DestroyOnTunnelAction = {
    startApproaching = Common.TunnelUsageAction.startApproaching,
    partiallyOnPortalTrack = "partiallyOnPortalTrack", -- Removal occurs when the entry train detector is killed. No published event for this as we have reserved the track from distance already.
    entered = Common.TunnelUsageAction.entered,
    underground = "underground",
    leaving = Common.TunnelUsageAction.leaving
}
---@class Tests_PRDTT_PlayerController
local PlayerController = {
    character = "character",
    editor = "editor"
}
---@class Tests_PRDTT_PlayerInEndOfTrain
local PlayerInEndOfTrain = {
    front = "front",
    rear = "rear"
}

local DoMinimalTests = true -- If TRUE does minimal tests just to check the general mining and destroying behavior. Intended for regular use as part of all tests. If FALSE does the whole test suite and follows DoSpecificTests.

local DoSpecificTests = true -- If TRUE does the below specific tests, rather than all the combinations. Used for adhock testing.
local SpecificDestroyOnTunnelActionFilter = {"underground"} -- Pass in array of DestroyOnTunnelAction keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificPlayerControllerFilter = {} -- Pass in array of PlayerController keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.
local SpecificPlayerInEndOfTrainFilter = {} -- Pass in array of PlayerInEndOfTrain keys to do just those. Leave as nil or empty table for all. Only used when DoSpecificTests is TRUE.

local DebugOutputTestScenarioDetails = false -- If TRUE writes out the test scenario details to a csv in script-output for inspection in Excel.

---@class Tests_PRDTT_FinalPlayerState
local FinalPlayerState = {
    inVehicle = "inVehicle",
    aliveOutOfVehicle = "aliveOutOfVehicle",
    dead = "dead"
}

Test.RunTime = 1800
Test.RunLoopsMax = 0 -- Populated when script loaded.
---@type Tests_PRDTT_TestScenario[]
Test.TestScenarios = {}

---@param testName string
Test.OnLoad = function(testName)
    TestFunctions.RegisterTestsScheduledEventType(testName, "EveryTick", Test.EveryTick)
    Test.GenerateTestScenarios(testName) -- Call here so its always populated.
    TestFunctions.RegisterRecordTunnelUsageChanges(testName)
end

local blueprintString = "0eNq1ms1y2jAUhd9Fa8hYkiVZ7PsMXXQyjAMq8dTYjG3SMhnevTakJQ1O+6G4K359juyj7yJf9Cweyn3YNUXVicWzKFZ11YrFl2fRFpsqL4f3usMuiIUourAVM1Hl2+FVkxfl9/yw7PZVFcr5rm66vFyGai2OM1FU6/BDLORxhnReHaKO9zMRqq7oinAex+nFYVnttw+h6TV/H9n1h1bztqt3vdqubvtD6mrw6WXmmZ+JQ//YD0Gsiyaszh/amWi7/PxcfA5tJ4YhvrFQ4CSvHdOz47XhU94UL5ZyxE3/w60Nm21/SH+i/eebx27M2sRZpxNY6zhrM4G1jLO2H7fWkVm7CazdmLX6p3U2gbWJs/YTWOs4a5lEsax8pJ18z27fl7dm09T949X5zofvLldN3bZFtRkbTuSFlypmOGMDiL38eqoByMgBpP8lEBk7P0zUdJSR9V1OUOpkZJWVE9S6yCorJ6h1LtJ6gloXCbtKJiizkdZygnkWaa0+bB05wZWOYTmSZHWpY38UqfdXvm+v5Jio4aIOi1ouarCo46Iai2ZcVGJRj0UdDkonXBQHpSUXxUFpxUVxUFpzURyU5kRZHhQnyvKgOFGWB8WJsjwoTpTlQXGiDA4q5UQZHFTKiTI4qJQTZXBQKSaKX1HMk8TRpxgnyU8d0yR5RhgmyScTZknyjDBKCmdkMEkKZ2QwSApnZDBHCmdkMEYKZ2QwR5pnhDnSPCPMkeYZYY40zwhzpHlGmKMUZ2QxRynOyGKOUpyRxRylOCOLOUpxRhZzZHhGmCP+U2wxR3zNYDFHfHFjMUd8FWYxR3y56DBHfF3rMEd8Ae4wR/xOwWGO+C2Nwxzxey+HOeI3iQ5zxO9mHeaI33Y7zBHvDzjMEW9kZJgj3nHJMEe8NZRhjngPK8Mc8WZbhjnyPCPMkecZYY48zwhz5HlGmCPPM8IcyQSH5BMuilPykovimLziojgnr7koDsrf0GzgQfFuA283eN5u4P0Gz/sNvOHgecOBdxz8haiyXtXbuiuewoii0neJ169+meum6KVe/hFJ7oZPhn1D7XBAU6++hW7+dR/KYdYcR//359TxXseJeqqquSrnjvc7TsWEXHqd/P3Sq5svPYeTt1pOZYyqeq7K8dQ3TBPOp75hmnBA9Q3ThP/m8aaLlBw/3naRkm3++zVQffVn8mXv36d82Pt337+1egzrffmy2fBCyvC6r149Rq++dN4Yeb2B8Ep3UD7tc1y82l45E0+hac9jyWTqvHKpN6kz+nj8CeO13jU="

---@param testName string
Test.GetTestDisplayName = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    return testName .. " (" .. testManagerEntry.runLoopsCount .. "):      " .. testScenario.destroyOnTunnelAction .. "     " .. testScenario.playerController .. "     " .. testScenario.playerInEndOfTrain .. "     Expected result: " .. testScenario.expectedPlayerState
end

---@param testName string
Test.Start = function(testName)
    local testManagerEntry = TestFunctions.GetTestManagerObject(testName)
    local testScenario = Test.TestScenarios[testManagerEntry.runLoopsCount]
    local surface = TestFunctions.GetTestSurface()

    local _, placedEntitiesByGroup = TestFunctions.BuildBlueprintFromString(blueprintString, {x = 0, y = 0}, testName)

    -- Get the portals, we will just use the 2 most extreme end parts. Entrance portal is easten one.
    local entrancePortalPart, entrancePortalXPos = nil, -100000
    for _, portalEndEntity in pairs(placedEntitiesByGroup["railway_tunnel-portal_end"]) do
        if portalEndEntity.position.x > entrancePortalXPos then
            entrancePortalPart = portalEndEntity
            entrancePortalXPos = portalEndEntity.position.x
        end
    end

    -- Get any tunnel segment.
    local tunnelSegmentToRemove = placedEntitiesByGroup["railway_tunnel-underground_segment-straight"][1]

    -- Get the entrancePortal's entry train detector.
    local entrancePortalTrainDetector = surface.find_entities_filtered {area = {top_left = {x = entrancePortalPart.position.x - 3, y = entrancePortalPart.position.y - 3}, right_bottom = {x = entrancePortalPart.position.x + 3, y = entrancePortalPart.position.y + 3}}, name = "railway_tunnel-portal_entry_train_detector_1x1", limit = 1}[1]

    -- Get the player.
    local player = game.connected_players[1]
    if player == nil then
        error("No player 1 found to set as driver")
    end

    -- Set the player in the right mode so they have a character as required.
    if (testScenario.playerController == PlayerController.character and player.controller_type ~= defines.controllers.character) or (testScenario.playerController == PlayerController.editor and player.controller_type ~= defines.controllers.editor) then
        player.toggle_map_editor()
    end

    -- Get the train from any locomotive as only 1 train is placed in this test.
    local train = placedEntitiesByGroup["locomotive"][1].train

    -- Put the player in the correct end of the train.
    ---@typelist LuaEntity, double, LuaEntity, double
    local westCarriage, westCarriageX, eastCarriage, eastCarriageX = nil, 9999999, nil, -99999999
    for _, carriage in pairs(train.carriages) do
        if carriage.position.x < westCarriageX then
            westCarriage = carriage
            westCarriageX = carriage.position.x
        end
        if carriage.position.x > eastCarriageX then
            eastCarriage = carriage
            eastCarriageX = carriage.position.x
        end
    end
    if testScenario.playerInEndOfTrain == PlayerInEndOfTrain.front then
        westCarriage.set_driver(player)
    else
        eastCarriage.set_driver(player)
    end

    local testData = TestFunctions.GetTestDataObject(testName)
    testData.testScenario = testScenario
    ---@class Tests_PRDTT_TestScenarioBespokeData
    local testDataBespoke = {
        entrancePortalPart = entrancePortalPart, ---@type LuaEntity
        entrancePortalTrainDetector = entrancePortalTrainDetector, ---@type LuaEntity
        tunnelSegmentToRemove = tunnelSegmentToRemove, ---@type LuaEntity
        tunnelPartRemoved = false, ---@type boolean
        tickEnteredTunnel = nil ---@type Tick
    }
    testData.bespoke = testDataBespoke

    TestFunctions.ScheduleTestsEveryTickEvent(testName, "EveryTick", testName)
end

---@param testName string
Test.Stop = function(testName)
    TestFunctions.RemoveTestsEveryTickEvent(testName, "EveryTick", testName)

    -- Put the player back in to editor mode.
    local player = game.connected_players[1]
    if player.controller_type ~= defines.controllers.editor then
        player.toggle_map_editor()
    end
end

---@param event UtilityScheduledEvent_CallbackObject
Test.EveryTick = function(event)
    local testName = event.instanceId
    local testData = TestFunctions.GetTestDataObject(testName)
    local testScenario = testData.testScenario ---@type Tests_PRDTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PRDTT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    if testDataBespoke.tickEnteredTunnel == nil and tunnelUsageChanges.lastAction == Common.TunnelUsageAction.entered then
        testDataBespoke.tickEnteredTunnel = event.tick
    end

    if not testDataBespoke.tunnelPartRemoved then
        if Test.ShouldTunnelPartBeRemoved(testData, event.tick) then
            -- This is the correct state to remove the tunnel part.
            game.print("train reached tunnel part removal state")
            local entityToDestroy = testDataBespoke.tunnelSegmentToRemove
            local otherTunnelEntity = testDataBespoke.entrancePortalPart
            entityToDestroy.damage(9999999, entityToDestroy.force, "impact", otherTunnelEntity)
            testDataBespoke.tunnelPartRemoved = true

            local playerState
            local player = game.get_player(1)
            if player.vehicle ~= nil then
                playerState = FinalPlayerState.inVehicle
            elseif player.character ~= nil then
                playerState = FinalPlayerState.aliveOutOfVehicle
            elseif testScenario.playerController == PlayerController.editor then
                playerState = FinalPlayerState.aliveOutOfVehicle
            else
                playerState = FinalPlayerState.dead
                --Make respawn instant. Can't stop the respawn screen so have to click through it as the player.
                player.ticks_to_respawn = nil
            end

            if testScenario.expectedPlayerState == playerState then
                TestFunctions.TestCompleted(testName)
            else
                TestFunctions.TestFailed(testName, "expected player state " .. testScenario.expectedPlayerState .. " but got " .. playerState)
            end
        end
        return -- End the tick loop here every time we check for the tunnel part removal. Regardless of if its removed or not.
    end
end

---@param testData TestManager_TestData
---@param currentTick Tick
---@return boolean
Test.ShouldTunnelPartBeRemoved = function(testData, currentTick)
    local testScenario = testData.testScenario ---@type Tests_PRDTT_TestScenario
    local testDataBespoke = testData.bespoke ---@type Tests_PRDTT_TestScenarioBespokeData
    local tunnelUsageChanges = testData.tunnelUsageChanges

    if testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.partiallyOnPortalTrack then
        -- Check if the portaltrain detector has been collided with yet to know if the train has reached the portal.
        if not testDataBespoke.entrancePortalTrainDetector.valid then
            return true
        else
            return false
        end
    elseif testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.underground then
        -- When the trai is roughly half way through the tunnel destroy it.
        if testDataBespoke.tickEnteredTunnel ~= nil and currentTick == testDataBespoke.tickEnteredTunnel + 15 then
            return true
        else
            return false
        end
    else
        -- All other train states check if they have been reported as being reached yet.
        if tunnelUsageChanges.actions[testScenario.destroyOnTunnelAction] ~= nil and tunnelUsageChanges.actions[testScenario.destroyOnTunnelAction].count == 1 then
            return true
        else
            return false
        end
    end
end

---@param testName string
Test.GenerateTestScenarios = function(testName)
    if global.testManager.forceTestsFullSuite then
        DoMinimalTests = false
    end

    local destroyOnTunnelActionToTest  ---@type Tests_PRDTT_DestroyOnTunnelAction
    local playerControllerToTest  ---@type Tests_PRDTT_PlayerController
    local playerInEndOfTrainToTest  ---@type Tests_PRDTT_PlayerInEndOfTrain
    if DoSpecificTests then
        -- Adhock testing option.
        destroyOnTunnelActionToTest = TestFunctions.ApplySpecificFilterToListByKeyName(DestroyOnTunnelAction, SpecificDestroyOnTunnelActionFilter)
        playerControllerToTest = TestFunctions.ApplySpecificFilterToListByKeyName(PlayerController, SpecificPlayerControllerFilter)
        playerInEndOfTrainToTest = TestFunctions.ApplySpecificFilterToListByKeyName(PlayerInEndOfTrain, SpecificPlayerInEndOfTrainFilter)
    elseif DoMinimalTests then
        -- Minimal tests.
        destroyOnTunnelActionToTest = {[DestroyOnTunnelAction.partiallyOnPortalTrack] = DestroyOnTunnelAction.partiallyOnPortalTrack}
        playerControllerToTest = PlayerController
        playerInEndOfTrainToTest = PlayerInEndOfTrain
    else
        -- Do whole test suite.
        destroyOnTunnelActionToTest = DestroyOnTunnelAction
        playerControllerToTest = PlayerController
        playerInEndOfTrainToTest = PlayerInEndOfTrain
    end

    for _, destroyOnTunnelAction in pairs(destroyOnTunnelActionToTest) do
        for _, playerController in pairs(playerControllerToTest) do
            for _, playerInEndOfTrain in pairs(playerInEndOfTrainToTest) do
                ---@class Tests_PRDTT_TestScenario
                local scenario = {
                    destroyOnTunnelAction = destroyOnTunnelAction,
                    playerController = playerController,
                    playerInEndOfTrain = playerInEndOfTrain
                }
                scenario.expectedPlayerState = Test.CalculateExpectedResults(scenario)
                Test.RunLoopsMax = Test.RunLoopsMax + 1
                table.insert(Test.TestScenarios, scenario)
            end
        end
    end

    -- Write out all tests to csv as debug if approperiate.
    if DebugOutputTestScenarioDetails then
        TestFunctions.WriteTestScenariosToFile(testName, Test.TestScenarios)
    end
end

---@param testScenario Tests_PRDTT_TestScenario
---@return Tests_PRDTT_FinalPlayerState
Test.CalculateExpectedResults = function(testScenario)
    local expectedPlayerState

    -- Work out expected player state.
    if testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.startApproaching then
        -- Player not on portal/tunnel.
        expectedPlayerState = FinalPlayerState.inVehicle
    elseif testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.partiallyOnPortalTrack then
        -- Players carraige may be destroyed.
        if testScenario.playerInEndOfTrain == PlayerInEndOfTrain.front then
            expectedPlayerState = FinalPlayerState.aliveOutOfVehicle
        else
            expectedPlayerState = FinalPlayerState.inVehicle
        end
    elseif testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.leaving then
        -- Player in regular carriage and not in player container.
        expectedPlayerState = FinalPlayerState.aliveOutOfVehicle
    elseif testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.entered or testScenario.destroyOnTunnelAction == DestroyOnTunnelAction.underground then
        -- Player is in a player carriage as in the tunnel.
        if testScenario.playerController == PlayerController.character then
            expectedPlayerState = FinalPlayerState.dead
        else
            -- Editor mode so can't die.
            expectedPlayerState = FinalPlayerState.aliveOutOfVehicle
        end
    else
        error("invalid testScenario.removalAction: " .. testScenario.destroyOnTunnelAction)
    end

    return expectedPlayerState
end

return Test
