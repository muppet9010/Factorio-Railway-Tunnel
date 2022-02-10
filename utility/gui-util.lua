-- Library to support making, storing and accessing GUI elements. Allows making GUIs via a templating layout with GuiUtil.AddElement().
-- Requires the utility "constants" file to be populated within the root of the mod.

local GuiUtil = {}
local Utils = require("utility.utils")
local GuiActionsClick = require("utility.gui-actions-click")
local Logging = require("utility.logging")
local Constants = require("constants")
local StyleDataStyleVersion = require("utility.style-data").styleVersion

---@alias UtilityGuiUtil_StoreName string @ A named container that GUI elements have their references saved within under the GUI elements name and type. Used to provide logical seperation of GUI elements stored. Typically used for different GUis or major sections of a GUI, as the destroy GUI element functions can handle whole StoreNames automatically.
---@alias UtilityGuiUtil_GuiElementName string @ A generally unique string made by combining an elements name and type with mod name. However if storing references to the created elements within the libraries player element reference storage we need never obtian the GUI element by name and thus it doesn't have to be unique. Does need to be unique within the StoreName however.

-- TODO: EmmyLua this function and class
---@class UtilityGuiUtil_ElementDetails
---@field name string @ The name of the element. When automatically merged with the element's type and the mod name makes a semi unique reference name of type UtilityGuiUtil_GuiElementName.
--[[
    - elementDetails takes everything that GuiElement.add() accepts in Factorio API. Plus compulsory "parent" argument of who to create the GUI element under if it isn't a child element.
    - The "name" argument will be merged with the mod name and type to try and ensure a unique name is given to the GUI element in Factorio API.
    - The "style" argument will be checked for starting with "muppet_" and if so merged with the style-data version to handle the style prototype version control.
    - The optional "children" argument is an array of other elements detail's arrays, to recursively add in this hierachy. Parent argument isn't required and is ignored for children, as it is worked out during recursive loop.
    - Passing the string "self" as the caption/tooltip value or localised string name will be auto replaced to its unique mod auto generated name under gui-caption/gui-tooltip. This avoids having to duplicate name when defining the element's arguments.
    - The optional "styling" argument of a table of style attributes to be applied post element creation. Saves having to capture local reference to do this with at element declaration point.
    - The optional "registerClick" passes the supplied "actionName" string, the optional "data" table and the optional disabled boolean to GuiActionsClick.RegisterGuiForClick().
    - The optional "returnElement" if true will return the element in a table of elements. Key will be the elements name..type and the value a reference to the element.
    - The optional "exclude" if true will mean the GUI Element is ignored. To allow more natural templating.
    - The optional "attributes" is a table of k v pairs that is applied to the element via the API post element creation. V can be a return function wrapped around another function if you want it to be executed post element creation. i.e. function() return MyMainFunction("bob") end. Intended for the occasioanl adhock attributes you want to set which can't be done in the add() API function. i.e. drag_target or auto_center.
]]
GuiUtil.AddElement = function(elementDetails)
    if elementDetails.exclude == true then
        return
    end
    local rawName = elementDetails.name
    elementDetails.name = GuiUtil._GenerateGuiElementName(elementDetails.name, elementDetails.type)
    elementDetails.caption = GuiUtil._ReplaceLocaleNameSelfWithGeneratedName(elementDetails, "caption")
    elementDetails.tooltip = GuiUtil._ReplaceLocaleNameSelfWithGeneratedName(elementDetails, "tooltip")
    if elementDetails.style ~= nil and string.sub(elementDetails.style, 1, 7) == "muppet_" then
        elementDetails.style = elementDetails.style .. StyleDataStyleVersion
    end
    local returnElements = {}
    local attributes, returnElement, storeName, styling, registerClick, children = elementDetails.attributes, elementDetails.returnElement, elementDetails.storeName, elementDetails.styling, elementDetails.registerClick, elementDetails.children
    elementDetails.attributes, elementDetails.returnElement, elementDetails.storeName, elementDetails.styling, elementDetails.registerClick, elementDetails.children = nil, nil, nil, nil, nil, nil
    local element = elementDetails.parent.add(elementDetails)
    if returnElement then
        if elementDetails.name == nil then
            error("GuiUtil.AddElement returnElement attribute requires element name to be supplied.")
        else
            returnElements[elementDetails.name] = element
        end
    end
    if storeName ~= nil then
        if elementDetails.name == nil then
            error("GuiUtil.AddElement storeName attribute requires element name to be supplied.")
        else
            GuiUtil.AddElementToPlayersReferenceStorage(element.player_index, storeName, elementDetails.name, element)
        end
    end
    if styling ~= nil then
        GuiUtil._ApplyStylingArgumentsToElement(element, styling)
    end
    if registerClick ~= nil then
        if elementDetails.name == nil then
            error("GuiUtil.AddElement registerClick attribute requires element name to be supplied.")
        else
            GuiActionsClick.RegisterGuiForClick(rawName, elementDetails.type, registerClick.actionName, registerClick.data, registerClick.disabled)
        end
    end
    if attributes ~= nil then
        for k, v in pairs(attributes) do
            if type(v) == "function" then
                v = v()
            end
            element[k] = v
        end
    end
    if children ~= nil then
        for _, child in pairs(children) do
            if type(child) ~= "table" then
                error("GuiUtil.AddElement children not supplied as an array of child details in their own table.")
            else
                child.parent = element
                local childReturnElements = GuiUtil.AddElement(child)
                if childReturnElements ~= nil then
                    returnElements = Utils.TableMergeCopies({returnElements, childReturnElements})
                end
            end
        end
    end
    if Utils.GetTableNonNilLength(returnElements) then
        return returnElements
    else
        return nil
    end
end

--- Add a LuaGuiElement to a player's reference storage that was created manually, not via GuiUtil.AddElement().
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param guiElementName UtilityGuiUtil_GuiElementName
---@param element LuaGuiElement
GuiUtil.AddElementToPlayersReferenceStorage = function(playerIndex, storeName, guiElementName, element)
    GuiUtil._CreatePlayersElementReferenceStorage(playerIndex, storeName)
    global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][guiElementName] = element
end

--- Get a LuaGuiElement from a player's reference storage.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param elementName string
---@param elementType string
GuiUtil.GetElementFromPlayersReferenceStorage = function(playerIndex, storeName, elementName, elementType)
    GuiUtil._CreatePlayersElementReferenceStorage(playerIndex, storeName)
    return global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][GuiUtil._GenerateGuiElementName(elementName, elementType)]
end

-- TODO: EmmyLua this function
-- Similar options as AddElement where arguments exist. Some don't make sense for updating and so not supported.
GuiUtil.UpdateElementFromPlayersReferenceStorage = function(playerIndex, storeName, elementName, elementType, arguments, ignoreMissingElement)
    ignoreMissingElement = ignoreMissingElement or false
    local element = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, storeName, elementName, elementType)
    if element ~= nil then
        if not element.valid then
            Logging.LogPrint("WARNING: Muppet GUI - A mod tried to update a GUI, buts the GUI is invalid. This is either a bug, or another mod deleted this GUI. Hopefully closing the affected GUI and re-opening it will resolve this. GUI details: player: '" .. game.get_player(playerIndex).name .. "', storeName: '" .. storeName .. "', element Name: '" .. elementName .. "', element Type: '" .. elementType .. "'")
            return
        end
        local generatedName = GuiUtil._GenerateGuiElementName(elementName, elementType)
        if arguments.styling ~= nil then
            GuiUtil._ApplyStylingArgumentsToElement(element, arguments.styling)
            arguments.styling = nil
        end
        if arguments.registerClick ~= nil then
            GuiActionsClick.RegisterGuiForClick(elementName, elementType, arguments.registerClick.actionName, arguments.registerClick.data, arguments.registerClick.disabled)
            arguments.registerClick = nil
        end
        if arguments.storeName ~= nil then
            error("GuiUtil.UpdateElementFromPlayersReferenceStorage doesn't support storeName for element name '" .. elementName .. "' and type '" .. elementType .. "'")
            arguments.storeName = nil
        end
        if arguments.returnElement ~= nil then
            error("GuiUtil.UpdateElementFromPlayersReferenceStorage doesn't support returnElement for element name '" .. elementName .. "' and type '" .. elementType .. "'")
            arguments.returnElement = nil
        end
        if arguments.children ~= nil then
            error("GuiUtil.UpdateElementFromPlayersReferenceStorage doesn't support children for element name '" .. elementName .. "' and type '" .. elementType .. "'")
            arguments.children = nil
        end
        if arguments.attributes ~= nil then
            for k, v in pairs(arguments.attributes) do
                if type(v) == "function" then
                    v = v()
                end
                element[k] = v
            end
            arguments.attributes = nil
        end

        for argName, argValue in pairs(arguments) do
            if argName == "caption" or argName == "tooltip" then
                argValue = GuiUtil._ReplaceLocaleNameSelfWithGeneratedName({name = generatedName, [argName] = argValue}, argName)
            end
            element[argName] = argValue
        end
    elseif not ignoreMissingElement then
        error("GuiUtil.UpdateElementFromPlayersReferenceStorage didn't find a GUI element for name '" .. elementName .. "' and type '" .. elementType .. "'")
    end
    return element
end

--- Destroys a Gui element found within a players reference storage and removes the reference from the player storage.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param elementName string
---@param elementType string
GuiUtil.DestroyElementInPlayersReferenceStorage = function(playerIndex, storeName, elementName, elementType)
    local elementName = GuiUtil._GenerateGuiElementName(elementName, elementType)
    if global.GUIUtilPlayerElementReferenceStorage ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex] ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][elementName] ~= nil then
        if global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][elementName].valid then
            global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][elementName].destroy()
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][elementName] = nil
    end
end

--- Destroys all GUI elements within a players reference storage and removes the reference storage space for them.
---@param playerIndex Id
---@param storeName? UtilityGuiUtil_StoreName|nil @ If provided filters the removal to that storeName, otherwise does all storeNames for this player.
GuiUtil.DestroyPlayersReferenceStorage = function(playerIndex, storeName)
    if global.GUIUtilPlayerElementReferenceStorage == nil or global.GUIUtilPlayerElementReferenceStorage[playerIndex] == nil then
        return
    end
    if storeName == nil then
        for _, store in pairs(global.GUIUtilPlayerElementReferenceStorage[playerIndex]) do
            for _, element in pairs(store) do
                if element.valid then
                    element.destroy()
                end
            end
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex] = nil
    else
        if global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] == nil then
            return
        end
        for _, element in pairs(global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName]) do
            if element.valid then
                element.destroy()
            end
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] = nil
    end
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Create a global state store for this player's GUI elements within the scope of this mod.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
GuiUtil._CreatePlayersElementReferenceStorage = function(playerIndex, storeName)
    global.GUIUtilPlayerElementReferenceStorage = global.GUIUtilPlayerElementReferenceStorage or {}
    global.GUIUtilPlayerElementReferenceStorage[playerIndex] = global.GUIUtilPlayerElementReferenceStorage[playerIndex] or {}
    global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] = global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] or {}
end

--- Applies an array of styling options to an existing Gui element.
---@param element LuaGuiElement
---@param stylingArgs table<LuaStyle, any> @ A table of LuaStyle options to be applied. Table key is the style name, with the table value as the styles value to set.
GuiUtil._ApplyStylingArgumentsToElement = function(element, stylingArgs)
    if element == nil or (not element.valid) then
        return
    end
    if stylingArgs.column_alignments ~= nil then
        for k, v in pairs(stylingArgs.column_alignments) do
            element.style.column_alignments[k] = v
        end
        stylingArgs.column_alignments = nil
    end
    for k, v in pairs(stylingArgs) do
        element.style[k] = v
    end
end

--- Returns the specified attributeName's locale string from the elementDetails, while replacing the string "self" if found with an autogenerated locale string. The auto generated string is in the form: "gui-" + TYPE + "." + NAME attribute value. i.e. "gui-caption.firstLabel". So it matches if a standard locale naming scheme is in use.
---@param elementDetails UtilityGuiUtil_ElementDetails
---@param attributeName "'caption'"|"''tooltip"
---@return string
GuiUtil._ReplaceLocaleNameSelfWithGeneratedName = function(elementDetails, attributeName)
    local attributeNamesValue = elementDetails[attributeName]
    local elementName = elementDetails.name
    if elementName == nil then
        error("GuiUtil._ReplaceLocaleNameSelfWithGeneratedName called for an element with no name attribute.")
    end
    if attributeNamesValue == nil then
        attributeNamesValue = nil
    elseif attributeNamesValue == "self" then
        attributeNamesValue = {"gui-" .. attributeName .. "." .. elementName}
    elseif type(attributeNamesValue) == "table" and attributeNamesValue[1] ~= nil and attributeNamesValue[1] == "self" then
        attributeNamesValue[1] = "gui-" .. attributeName .. "." .. elementName
    end
    return arg
end

--- Makes a UtilityGuiUtil_GuiElementName by combining the element's name and type.
--- Just happens to be the same as in GuiActionsClick, but not a requirement.
---@param elementName string
---@param elementType string
---@return string UtilityGuiUtil_GuiElementName
GuiUtil._GenerateGuiElementName = function(elementName, elementType)
    if elementName == nil or elementType == nil then
        return nil
    else
        return Constants.ModName .. "-" .. elementName .. "-" .. elementType
    end
end

return GuiUtil
