--[[
    Events is used to register one or more functions to be run when a script.event occurs.
    It supports defines.events and custom events. Also offers a raise event method.
    Intended for use with a modular script design to avoid having to link to each modulars functions in a centralised event handler.
]]
--

local Utils = require("utility/utils")

local Events = {}
MOD = MOD or {}
MOD.eventsById = MOD.eventsById or {} ---@type UtilityEvents_EventIdHandlers
MOD.eventsByActionName = MOD.eventsByActionName or {} ---@type UtilityEvents_EventActionNameHandlers
MOD.customEventNameToId = MOD.customEventNameToId or {} ---@type table<string, int>
MOD.eventFilters = MOD.eventFilters or {} ---@type table<int, table<string, table>>

---@class UtilityEvents_EventData : EventData @ The class is the minimum with any custom fields included in it being passed through to the recieveing event handler function.
---@field input_name? string|null @ Used by custom input event handlers registered with Events.RegisterHandlerCustomInput() as the actionName.

---@alias UtilityEvents_CachedEventData table<string, UtilityEvents_CachedEventDataField> @ A cache of this event's data fields as requested across the whole mod. Key'd by the field name. Will include fields requested by other functions on this event as its a shared cache for all.

---@alias UtilityEvents_CachedEventDataField table<string, any> @ A cache of the specific event data field's attributes. A nil value attribute will appear missing from the table, but it can be read out naturally by calling function still. If the field is not "valid" then no other attributes will be populated. If the thing is invalidated during an event handler function then the other handler function's will need to check this at execution time themselves, as this is unsual event handler function logic in most use cases.

--- Called from OnLoad() from each script file. Registers the event in Factorio and the handler function for all event types and custom events.
---@param eventName defines.events|string @ Either Factorio event or a custom modded event name.
---@param handlerName string @ Unique name of this event handler instance. Used to avoid duplicate handler registration and if removal is required.
---@param handlerFunction function @ The function that is called when the event triggers.
---@param thisFilterData? EventFilter[]|null @ List of Factorio EventFilters the mod should recieve this eventName occurances for or nil for all occurances. If an empty table (not nil) is passed in then nothing is registered for this handler (silently rejected). Filtered events have to expect to recieve results outside of their own filters. As a Factorio event type can only be subscribed to one time with a combined Filter list of all desires across the mod.
---@param fieldCachedData? table<string, string[]> @ Any fields on the event data that you want attributes to be centerally cached and returned to the handlerFunction. Should only have fields and attributes added when multiple handler functions of the same event will want the same attributes for the same event instance. Ideal for caching attributes used in multiple handlre functions on an event to identify whihc handler function actually needs to process the event with the others terminating their function. If populated the handler function will recieve a second argument of cachedData of type UtilityEvents_CachedEventData, in addition to the first argument of the events default data.
---@return uint @ Useful for custom event names when you need to store the eventId to return via a remote interface call.
Events.RegisterHandlerEvent = function(eventName, handlerName, handlerFunction, thisFilterData, fieldCachedData)
    if eventName == nil or handlerName == nil or handlerFunction == nil then
        error("Events.RegisterHandlerEvent called with missing arguments")
    end
    local eventId = Events._RegisterEvent(eventName, handlerName, thisFilterData)
    if eventId == nil then
        return nil
    end

    -- If this is the first function for the event then create its object.
    MOD.eventsById[eventId] =
        MOD.eventsById[eventId] or
        {
            handlers = {}
        }

    -- Record the handler name and function.
    MOD.eventsById[eventId].handlers[handlerName] = handlerFunction

    -- Process any fieldDataCache for this function.
    if fieldCachedData ~= nil then
        if next(fieldCachedData) == nil then
            error("Events.RegisterHandlerEvent called with empty fieldCachedData table. Should be either nil or populated table.")
        end

        -- Create the requested data cache object if needed.
        local requestedDataCache = MOD.eventsById[eventId].requestedDataCache
        if requestedDataCache == nil then
            MOD.eventsById[eventId].requestedDataCache = {}
            requestedDataCache = MOD.eventsById[eventId].requestedDataCache
        end

        -- Process over the requested fields and then attributes and record them to the requested data cache object.
        for fieldName, attributeNames in pairs(fieldCachedData) do
            if next(attributeNames) == nil then
                error("Events.RegisterHandlerEvent called with empty attributes list for field '" .. tostring(fieldName) .. "' in fieldCachedData table. Should either be not listed as a field or populated with attribute names.")
            end

            requestedDataCache[fieldName] = requestedDataCache[fieldName] or {}

            for _, attributeName in pairs(attributeNames) do
                -- We track how many functions request the attribute so we can stop caching them later if all functions are removed.
                if requestedDataCache[fieldName][attributeName] == nil then
                    requestedDataCache[fieldName][attributeName] = 1
                else
                    requestedDataCache[fieldName][attributeName] = requestedDataCache[fieldName][attributeName] + 1
                end
            end
        end
    end

    return eventId
end

--- Called from OnLoad() from each script file. Registers the custom inputs (key bindings) as their names in Factorio and the handler function for all just custom inputs. These are handled specially in Factorio.
---@param actionName string @ custom input name (key binding).
---@param handlerName string @ Unique handler name.
---@param handlerFunction function @ Function to be triggered on action.
Events.RegisterHandlerCustomInput = function(actionName, handlerName, handlerFunction)
    if actionName == nil then
        error("Events.RegisterHandlerCustomInput called with missing arguments")
    end
    script.on_event(actionName, Events._HandleEvent)

    -- If this is the first function for the event then create its object.
    MOD.eventsByActionName[actionName] =
        MOD.eventsByActionName[actionName] or
        {
            handlers = {}
        }

    -- Record the handler name and function.
    MOD.eventsByActionName[actionName].handlers[handlerName] = handlerFunction
end

--- Called from OnLoad() from the script file. Registers the custom event name and returns an event ID for use by other mods in subscribing to custom events.
---@param eventName string
---@return uint eventId @ Bespoke event id for this custom event.
Events.RegisterCustomEventName = function(eventName)
    if eventName == nil then
        error("Events.RegisterCustomEventName called with missing arguments")
    end
    local eventId
    if MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = script.generate_event_name()
        MOD.customEventNameToId[eventName] = eventId
    end
    return eventId
end

--- Called when needed. Removes a registered handlerName from beign called when the specified event triggers.
---@param eventName defines.events|string @ Either a default Factorio event or a custom input action name.
---@param handlerName string @ The unique handler name to remove from this eventName.
Events.RemoveHandler = function(eventName, handlerName)
    if eventName == nil or handlerName == nil then
        error("Events.RemoveHandler called with missing arguments")
    end
    if MOD.eventsById[eventName] ~= nil then
        MOD.eventsById[eventName].handlers[handlerName] = nil
    elseif MOD.eventsByActionName[eventName] ~= nil then
        MOD.eventsByActionName[eventName].handlers[handlerName] = nil
    end
end

--- Called when needed, but not before tick 0 as they are ignored. Can either raise a custom registered event registered by Events.RegisterCustomEventName(), or one of the limited events defined in the API: https://lua-api.factorio.com/latest/LuaBootstrap.html#LuaBootstrap.raise_event.
--- Older Factorio versions allowed for raising any base Factorio event yourself, so review on upgrade.
---@param eventData UtilityEvents_EventData
Events.RaiseEvent = function(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if type(eventName) == "number" then
        script.raise_event(eventName, eventData)
    elseif MOD.customEventNameToId[eventName] ~= nil then
        local eventId = MOD.customEventNameToId[eventName]
        script.raise_event(eventId, eventData)
    else
        error("WARNING: raise event called that doesn't exist: " .. eventName)
    end
end

--- Called from anywhere, including OnStartup in tick 0. This won't be passed out to other mods however, only run within this mod.
--- This calls this mod's event handler bypassing the Factorio event system.
---@param eventData UtilityEvents_EventData
Events.RaiseInternalEvent = function(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if type(eventName) == "number" then
        Events._HandleEvent(eventData)
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventData.name = MOD.customEventNameToId[eventName]
        Events._HandleEvent(eventData)
    else
        error("WARNING: raise event called that doesn't exist: " .. eventName)
    end
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Runs when an event is triggered and calls all of the approperiate registered functions.
--- Each function called will need to check that any fields are still valid if a previous function in the same mod could have invalidated them.
---@param eventData UtilityEvents_EventData
Events._HandleEvent = function(eventData)
    if eventData.input_name == nil then
        -- All non custom input events (majority).

        local cachedData = {} ---@type UtilityEvents_CachedEventData
        local eventHandlers = MOD.eventsById[eventData.name]

        -- If there is requestedDataCache for this event then build up the cache.
        if eventHandlers.requestedDataCache ~= nil then
            for fieldName, attributes in pairs(eventHandlers.requestedDataCache) do
                local field = eventData[fieldName]

                -- Construct the results container if doesn't already exist.
                local cachedDataFieldName = cachedData[fieldName]
                if cachedDataFieldName == nil then
                    cachedData[fieldName] = {
                        valid = field.valid
                    }
                    cachedDataFieldName = cachedData[fieldName]
                end

                -- Check over each requested attribute for this field if it is valid.
                if cachedDataFieldName.valid then
                    for attributeName in pairs(attributes) do
                        -- If the attribute isn't cached get it and add it.
                        if cachedDataFieldName[attributeName] == nil then
                            cachedDataFieldName[attributeName] = field[attributeName]
                        end
                    end
                end
            end
        end

        -- Call each handler for this event.
        for _, handlerFunction in pairs(eventHandlers.handlers) do
            handlerFunction(eventData, cachedData)
        end
    else
        -- Custom Input type event.
        -- TODO: does this need data cacheing, don't believe so?
        for _, handlerFunction in pairs(MOD.eventsByActionName[eventData.input_name].handlers) do
            handlerFunction(eventData)
        end
    end
end

--- Registers the function in to the mods event to function matrix. Handles merging filters between multiple functions on the same event.
---@param eventName string
---@param thisFilterName string @ The handler name.
---@param thisFilterData? table|null
---@return uint|null
Events._RegisterEvent = function(eventName, thisFilterName, thisFilterData)
    if eventName == nil then
        error("Events.RegisterEvent called with missing arguments")
    end
    local eventId  ---@type uint
    local filterData  ---@type table
    thisFilterData = Utils.DeepCopy(thisFilterData) -- Deepcopy it so if a persisted or shared table is passed in we don't cause changes to source table.
    if type(eventName) == "number" then
        eventId = eventName
        if thisFilterData ~= nil then
            if Utils.IsTableEmpty(thisFilterData) then
                -- filter isn't nil, but has no data, so as this won't register to any filters just drop it.
                return nil
            end
            MOD.eventFilters[eventId] = MOD.eventFilters[eventId] or {}
            MOD.eventFilters[eventId][thisFilterName] = thisFilterData
            local currentFilter, currentHandler = script.get_event_filter(eventId), script.get_event_handler(eventId)
            if currentHandler ~= nil and currentFilter == nil then
                -- an event is registered already and has no filter, so already fully lienent.
                return eventId
            else
                -- add new filter to any existing old filter and let it be re-applied.
                filterData = {}
                for _, filterTable in pairs(MOD.eventFilters[eventId]) do
                    filterTable[1].mode = "or"
                    for _, filterEntry in pairs(filterTable) do
                        table.insert(filterData, filterEntry)
                    end
                end
            end
        end
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = script.generate_event_name()
        MOD.customEventNameToId[eventName] = eventId
    end
    script.on_event(eventId, Events._HandleEvent, filterData)
    return eventId
end

return Events

---@alias UtilityEvents_EventIdHandlers table<uint, UtilityEvents_EventHandlers>
---@alias UtilityEvents_EventActionNameHandlers table<string, UtilityEvents_EventHandlers>

---@class UtilityEvents_EventHandlers
---@field handlers function[]
---@field requestedDataCache? table<string, table<string, uint>>|null @ A table key'd by field name with its value a table of attribute names and how many times they were registered for that field. If they want the actual thing that is obtainable from the raw event data.
