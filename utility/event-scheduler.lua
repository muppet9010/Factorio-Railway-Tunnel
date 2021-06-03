--[[
    This event scheduler is used by calling the RegisterScheduler() function once in root of control.lua. You then call RegisterScheduledEventType() from the OnLoad stage for each function you want to register for future triggering. The triggering is then done by using the Once or Each Tick functions to add and remove registrations of functions and data against Factorio events. Each Tick events are optional for use when the function will be called for multiple ticks in a row with the same reference data.
]]
local Utils = require("utility/utils")
local Events = require("utility/events")
local EventScheduler = {}
MOD = MOD or {}
MOD.scheduledEventNames =
    MOD.scheduledEventNames or
    {
        ["EventScheduler.GamePrint"] = function(event)
            -- Builtin game.print delayed function, needed for 0 tick logging (startup) writing to screen activites.
            game.print(event.data.message)
        end
    }

--------------------------------------------------------------------------------------------
--                                    Setup Functions
---------------------------------------------------------------------------------------------

-- Called from the root of Control.lua
EventScheduler.RegisterScheduler = function()
    Events.RegisterHandlerEvent(defines.events.on_tick, "EventScheduler._OnSchedulerCycle", EventScheduler._OnSchedulerCycle)
end

-- Called from OnLoad() from each script file.
-- When eventFunction is triggered eventData argument passed: {tick = tick, name = eventName, instanceId = instanceId, data = scheduledFunctionData}
EventScheduler.RegisterScheduledEventType = function(eventName, eventFunction)
    if eventName == nil or eventFunction == nil then
        error("EventScheduler.RegisterScheduledEventType called with missing arguments")
    end
    MOD.scheduledEventNames[eventName] = eventFunction
end

--------------------------------------------------------------------------------------------
--                                    Schedule Once Functions
---------------------------------------------------------------------------------------------

-- Called from OnStartup() or from some other event or trigger to schedule an event.
-- Doesn't have any protection or auto increments any more as wastes UPS.
EventScheduler.ScheduleEventOnce = function(eventTick, eventName, instanceId, eventData)
    if eventName == nil or eventTick == nil then
        error("EventScheduler.ScheduleEventOnce called with missing arguments")
    end
    instanceId = instanceId or ""
    eventData = eventData or {}
    global.UTILITYSCHEDULEDFUNCTIONS = global.UTILITYSCHEDULEDFUNCTIONS or {}
    global.UTILITYSCHEDULEDFUNCTIONS[eventTick] = global.UTILITYSCHEDULEDFUNCTIONS[eventTick] or {}
    global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName] = global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName] or {}
    if global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName][instanceId] ~= nil then
        error("WARNING: Overridden schedule event: '" .. eventName .. "' id: '" .. instanceId .. "' at tick: " .. eventTick)
    end
    global.UTILITYSCHEDULEDFUNCTIONS[eventTick][eventName][instanceId] = eventData
end

-- Called whenever required.
EventScheduler.IsEventScheduledOnce = function(targetEventName, targetInstanceId, targetTick)
    if targetEventName == nil then
        error("EventScheduler.IsEventScheduledOnce called with missing arguments")
    end
    local result = EventScheduler._ParseScheduledOnceEvents(targetEventName, targetInstanceId, targetTick, EventScheduler._IsEventScheduledOnceInTickEntry)
    if result ~= true then
        result = false
    end
    return result
end

-- Called whenever required.
EventScheduler.RemoveScheduledOnceEvents = function(targetEventName, targetInstanceId, targetTick)
    if targetEventName == nil then
        error("EventScheduler.RemoveScheduledOnceEvents called with missing arguments")
    end
    EventScheduler._ParseScheduledOnceEvents(targetEventName, targetInstanceId, targetTick, EventScheduler._RemoveScheduledOnceEventsFromTickEntry)
end

-- Called whenever required.
EventScheduler.GetScheduledOnceEvents = function(targetEventName, targetInstanceId, targetTick)
    if targetEventName == nil then
        error("EventScheduler.GetScheduledOnceEvents called with missing arguments")
    end
    local _, results = EventScheduler._ParseScheduledOnceEvents(targetEventName, targetInstanceId, targetTick, EventScheduler._GetScheduledOnceEventsFromTickEntry)
    return results
end

--------------------------------------------------------------------------------------------
--                                    Schedule For Each Tick Functions
---------------------------------------------------------------------------------------------

-- Called from OnStartup() or from some other event or trigger to schedule an event to fire every tick from now on until cancelled.
EventScheduler.ScheduleEventEachTick = function(eventName, instanceId, eventData)
    if eventName == nil then
        error("EventScheduler.ScheduleEventEachTick called with missing arguments")
    end
    instanceId = instanceId or ""
    eventData = eventData or {}
    global.UTILITYSCHEDULEDFUNCTIONSPERTICK = global.UTILITYSCHEDULEDFUNCTIONSPERTICK or {}
    global.UTILITYSCHEDULEDFUNCTIONSPERTICK[eventName] = global.UTILITYSCHEDULEDFUNCTIONSPERTICK[eventName] or {}
    if global.UTILITYSCHEDULEDFUNCTIONSPERTICK[eventName][instanceId] ~= nil then
        error("WARNING: Overridden schedule event per tick: '" .. eventName .. "' id: '" .. instanceId .. "'")
    end
    global.UTILITYSCHEDULEDFUNCTIONSPERTICK[eventName][instanceId] = eventData
end

-- Called whenever required.
EventScheduler.IsEventScheduledEachTick = function(targetEventName, targetInstanceId)
    if targetEventName == nil then
        error("EventScheduler.IsEventScheduledEachTick called with missing arguments")
    end
    local result = EventScheduler._ParseScheduledEachTickEvents(targetEventName, targetInstanceId, EventScheduler._IsEventScheduledInEachTickList)
    if result ~= true then
        result = false
    end
    return result
end

-- Called whenever required.
EventScheduler.RemoveScheduledEventFromEachTick = function(targetEventName, targetInstanceId)
    if targetEventName == nil then
        error("EventScheduler.RemoveScheduledEventsFromEachTick called with missing arguments")
    end
    EventScheduler._ParseScheduledEachTickEvents(targetEventName, targetInstanceId, EventScheduler._RemoveScheduledEventFromEachTickList)
end

-- Called whenever required.
EventScheduler.GetScheduledEachTickEvent = function(targetEventName, targetInstanceId)
    if targetEventName == nil then
        error("EventScheduler.GetScheduledEachTickEvent called with missing arguments")
    end
    local _, results = EventScheduler._ParseScheduledEachTickEvents(targetEventName, targetInstanceId, EventScheduler._GetScheduledEventFromEeachTickList)
    return results
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
---------------------------------------------------------------------------------------------

EventScheduler._OnSchedulerCycle = function(event)
    local tick = event.tick
    if global.UTILITYSCHEDULEDFUNCTIONS ~= nil and global.UTILITYSCHEDULEDFUNCTIONS[tick] ~= nil then
        for eventName, instances in pairs(global.UTILITYSCHEDULEDFUNCTIONS[tick]) do
            for instanceId, scheduledFunctionData in pairs(instances) do
                local eventData = {tick = tick, name = eventName, instanceId = instanceId, data = scheduledFunctionData}
                if MOD.scheduledEventNames[eventName] ~= nil then
                    MOD.scheduledEventNames[eventName](eventData)
                else
                    error("WARNING: schedule event called that doesn't exist: '" .. eventName .. "' id: '" .. instanceId .. "' at tick: " .. tick)
                end
            end
        end
        global.UTILITYSCHEDULEDFUNCTIONS[tick] = nil
    end
    if global.UTILITYSCHEDULEDFUNCTIONSPERTICK ~= nil then
        -- Prefetch the next table entry as we will likely remove the inner instance entry and its parent eventName while in the loop. Advised solution by Factorio discord.
        local eventName, instances = next(global.UTILITYSCHEDULEDFUNCTIONSPERTICK)
        while eventName do
            local nextEventName, nextInstances = next(global.UTILITYSCHEDULEDFUNCTIONSPERTICK, eventName)
            for instanceId, scheduledFunctionData in pairs(instances) do
                local eventData = {tick = tick, name = eventName, instanceId = instanceId, data = scheduledFunctionData}
                if MOD.scheduledEventNames[eventName] ~= nil then
                    MOD.scheduledEventNames[eventName](eventData)
                else
                    error("WARNING: schedule event called that doesn't exist: '" .. eventName .. "' id: '" .. instanceId .. "' at tick: " .. tick)
                end
            end
            eventName, instances = nextEventName, nextInstances
        end
    end
end

EventScheduler._ParseScheduledOnceEvents = function(targetEventName, targetInstanceId, targetTick, actionFunction)
    targetInstanceId = targetInstanceId or ""
    local result, results = nil, {}
    if global.UTILITYSCHEDULEDFUNCTIONS ~= nil then
        if targetTick == nil then
            for tick, events in pairs(global.UTILITYSCHEDULEDFUNCTIONS) do
                local outcome = actionFunction(events, targetEventName, targetInstanceId, tick)
                if outcome ~= nil then
                    result = outcome.result
                    if outcome.results ~= nil then
                        table.insert(results, outcome.results)
                    end
                    if result then
                        break
                    end
                end
            end
        else
            local events = global.UTILITYSCHEDULEDFUNCTIONS[targetTick]
            if events ~= nil then
                local outcome = actionFunction(events, targetEventName, targetInstanceId, targetTick)
                if outcome ~= nil then
                    result = outcome.result
                    if outcome.results ~= nil then
                        table.insert(results, outcome.results)
                    end
                end
            end
        end
    end
    return result, results
end

EventScheduler._IsEventScheduledOnceInTickEntry = function(events, targetEventName, targetInstanceId)
    if events[targetEventName] ~= nil and events[targetEventName][targetInstanceId] ~= nil then
        return {result = true}
    end
end

EventScheduler._RemoveScheduledOnceEventsFromTickEntry = function(events, targetEventName, targetInstanceId, tick)
    if events[targetEventName] ~= nil then
        events[targetEventName][targetInstanceId] = nil
        if Utils.GetTableNonNilLength(events[targetEventName]) == 0 then
            events[targetEventName] = nil
        end
    end
    if Utils.GetTableNonNilLength(events) == 0 then
        global.UTILITYSCHEDULEDFUNCTIONS[tick] = nil
    end
end

EventScheduler._GetScheduledOnceEventsFromTickEntry = function(events, targetEventName, targetInstanceId, tick)
    if events[targetEventName] ~= nil and events[targetEventName][targetInstanceId] ~= nil then
        local scheduledEvent = {
            tick = tick,
            eventName = targetEventName,
            instanceId = targetInstanceId,
            eventData = events[targetEventName][targetInstanceId]
        }
        return {results = scheduledEvent}
    end
end

EventScheduler._ParseScheduledEachTickEvents = function(targetEventName, targetInstanceId, actionFunction)
    targetInstanceId = targetInstanceId or ""
    local result, results = nil, {}
    if global.UTILITYSCHEDULEDFUNCTIONSPERTICK ~= nil then
        local outcome = actionFunction(global.UTILITYSCHEDULEDFUNCTIONSPERTICK, targetEventName, targetInstanceId)
        if outcome ~= nil then
            result = outcome.result
            if outcome.results ~= nil then
                table.insert(results, outcome.results)
            end
        end
    end
    return result, results
end

EventScheduler._IsEventScheduledInEachTickList = function(events, targetEventName, targetInstanceId)
    if events[targetEventName] ~= nil and events[targetEventName][targetInstanceId] ~= nil then
        return {result = true}
    end
end

EventScheduler._RemoveScheduledEventFromEachTickList = function(events, targetEventName, targetInstanceId)
    if events[targetEventName] ~= nil then
        events[targetEventName][targetInstanceId] = nil
        if Utils.GetTableNonNilLength(events[targetEventName]) == 0 then
            events[targetEventName] = nil
        end
    end
end

EventScheduler._GetScheduledEventFromEeachTickList = function(events, targetEventName, targetInstanceId)
    if events[targetEventName] ~= nil and events[targetEventName][targetInstanceId] ~= nil then
        local scheduledEvent = {
            eventName = targetEventName,
            instanceId = targetInstanceId,
            eventData = events[targetEventName][targetInstanceId]
        }
        return {results = scheduledEvent}
    end
end

return EventScheduler
