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

--- Takes generally everything that GuiElement.add() accepts in Factorio API with the below key differences:
--- - Compulsory "parent" argument of who to create the GUI element under if it isn't a child element itself.
--- - Doesn't support the "name" attribute, but offers "descriptiveName" instead. See the attributes details.
---@class UtilityGuiUtil_ElementDetails : UtilityGuiUtil_ElementDetails_LuaGuiElement.add_param
--- The GUI element this newly created element will be a child of. Not needed (ignored) if this ElementDetails is specificed as a child within another ElementDetails specification.
---@field parent LuaGuiElement|null
--- A descriptive name of the element. Will be automatically merged with the element's type and the mod name to make a semi unique reference name of type UtilityGuiUtil_GuiElementName that the GUI element will have as its "name" attribute.
---@field descriptiveName string
--- Style of the child element.
---
--- Value will be checked for starting with "muppet_" and if so automatically merged with the style-data version included in this mod to create the correct full style name. So it automatically handles the fact that muppet styling prototypes are version controlled.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field style? string|null
--- A table of LuaStyle attribute names and values (key/value) to be applied post element creation. Saves having to capture the added element and then set style attributes one at a time in calling code.
---
--- [Styling documentation](https://lua-api.factorio.com/latest/LuaStyle.html)
---@field styling? table<string, StringOrNumber|boolean|null>|null
--- Text displayed on the child element. For frames, this is their title. For other elements, like buttons or labels, this is the content. Whilst this attribute may be used on all elements, it doesn't make sense for tables and flows as they won't display it.
---
--- Passing the string "self" as the value or localised string name will be auto replaced to its unique mod auto generated name under gui-caption/gui-tooltip. This avoids having to duplicate name when defining the element's arguments.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field caption LocalisedString|null
--- Tooltip of the child element.
---
--- Passing the string "self" as the value or localised string name will be auto replaced to its unique mod auto generated name under gui-caption/gui-tooltip. This avoids having to duplicate name when defining the element's arguments.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field tooltip LocalisedString|null
--- An array of other Element Details to recursively add in this hierachy. Parent argument isn't required for children and is ignored if provided for them as it's worked out during recursive loop of creating the children.
---@field children? UtilityGuiUtil_ElementDetails[]|null
--- The optional "registerClick" passes the supplied "actionName" string, the optional "data" table and the optional disabled boolean to GuiActionsClick.RegisterGuiForClick().
---@field registerClick? UtilityGuiUtil_ElementDetails_RegisterClickOption|null
--- If TRUE will return the Gui elements created in a table of elements. Key will be the elements UtilityGuiUtil_GuiElementName and the value a reference to the element.
---
--- Defaults to FALSE if not provided.
---@field returnElement? boolean|null
--- If TRUE will mean the GUI Element is ignored and not added. To allow more natural templating as the value can be pre-calculated and then applied to a standard template being passed in to this function to not include certain elements.
---
--- Defaults to FALSE if not provided.
---@field exclude? boolean|null
--- A table of key/value pairs that is applied to the element via the API post element creation. Intended for the occasioanl adhock attributes you want to set which can't be done in the add() API function. i.e. drag_target or auto_center.
---
--- The value can be a function if you want it to be executed post element creation. Attribute example:
--- `{ drag_target = function() return GuiUtil.GetElementFromPlayersReferenceStorage(player.index, "ShopGui", "shopGuiMain", "frame") end }`
---@field attributes? table<string, any>|null

---@class UtilityGuiUtil_ElementDetails_RegisterClickOption @ Option of UtilityGuiUtil_ElementDetails for calling GuiActionsClick.RegisterGuiForClick() as part of the Gui element creation.
---@field actionName string @ The actionName of the registered function to be called when the GUI element is clicked.
---@field data table @ Any provided data will be passed through to the actionName's registered function upon the GUI element being clicked.
---@field disabled boolean If TRUE then click not registered (for use with GUI templating). Otherwise FALSE or nil will registered normally.

--- Add Gui Elements in a manner supporting short-hand features, nested GUI structures and templating features. See the param type for detailed information on its features and usage.
---@param elementDetails UtilityGuiUtil_ElementDetails
---@return table<string, LuaGuiElement> returnElements @ Provided if returnElement option is TRUE. Table of UtilityGuiUtil_GuiElementName keys to LuaGuiElement values.
GuiUtil.AddElement = function(elementDetails)
    if elementDetails.exclude == true then
        return
    end
    elementDetails.name = GuiUtil._GenerateGuiElementName(elementDetails.descriptiveName, elementDetails.type)
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
            error("GuiUtil.AddElement returnElement attribute requires element descriptiveName to be supplied.")
        else
            returnElements[elementDetails.name] = element
        end
    end
    if storeName ~= nil then
        if elementDetails.name == nil then
            error("GuiUtil.AddElement storeName attribute requires element descriptiveName to be supplied.")
        else
            GuiUtil.AddElementToPlayersReferenceStorage(element.player_index, storeName, elementDetails.name, element)
        end
    end
    if styling ~= nil then
        GuiUtil._ApplyStylingArgumentsToElement(element, styling)
    end
    if registerClick ~= nil then
        if elementDetails.name == nil then
            error("GuiUtil.AddElement registerClick attribute requires element descriptiveName to be supplied.")
        else
            GuiActionsClick.RegisterGuiForClick(elementDetails.descriptiveName, elementDetails.type, registerClick.actionName, registerClick.data, registerClick.disabled)
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
    if elementDetails.descriptiveName == nil then
        error("GuiUtil._ReplaceLocaleNameSelfWithGeneratedName called for an element with no name attribute.")
    end
    if attributeNamesValue == nil then
        attributeNamesValue = nil
    elseif attributeNamesValue == "self" then
        attributeNamesValue = {"gui-" .. attributeName .. "." .. elementDetails.descriptiveName}
    elseif type(attributeNamesValue) == "table" and attributeNamesValue[1] ~= nil and attributeNamesValue[1] == "self" then
        attributeNamesValue[1] = "gui-" .. attributeName .. "." .. elementDetails.descriptiveName
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

--- A copy of the the bsae game's LuaGuiElement.add_param, but without the following attributes as thye are included in my parent class; name, style, caption, tooltip.
---@class UtilityGuiUtil_ElementDetails_LuaGuiElement.add_param
---The kind of element to add. Has to be one of the GUI element types listed at the top of this page.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field type string
---Whether the child element is enabled. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field enabled boolean|nil
---Whether the child element is visible. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field visible boolean|nil
---Whether the child element is ignored by interaction. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field ignored_by_interaction boolean|nil
---[Tags](https://lua-api.factorio.com/latest/Concepts.html#Tags) associated with the child element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field tags Tags|nil
---Location in its parent that the child element should slot into. By default, the child will be appended onto the end.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field index uint|nil
---Where to position the child element when in the `relative` element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field anchor GuiAnchor|nil
---Applies to **"button"**: (optional)
---Which mouse buttons the button responds to. Defaults to `"left-and-right"`.
---
---Applies to **"sprite-button"**: (optional)
---The mouse buttons that the button responds to. Defaults to `"left-and-right"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field mouse_button_filter MouseButtonFlags|nil
---Applies to **"flow"**: (optional)
---The initial direction of the flow's layout. See [LuaGuiElement::direction](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.direction). Defaults to `"horizontal"`.
---
---Applies to **"frame"**: (optional)
---The initial direction of the frame's layout. See [LuaGuiElement::direction](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.direction). Defaults to `"horizontal"`.
---
---Applies to **"line"**: (optional)
---The initial direction of the line. Defaults to `"horizontal"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field direction string|nil
---Applies to **"table"**: (required)
---Number of columns. This can't be changed after the table is created.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field column_count uint
---Applies to **"table"**: (optional)
---Whether the table should draw vertical grid lines. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field draw_vertical_lines boolean|nil
---Applies to **"table"**: (optional)
---Whether the table should draw horizontal grid lines. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field draw_horizontal_lines boolean|nil
---Applies to **"table"**: (optional)
---Whether the table should draw a single horizontal grid line after the headers. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field draw_horizontal_line_after_headers boolean|nil
---Applies to **"table"**: (optional)
---Whether the content of the table should be vertically centered. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field vertical_centering boolean|nil
---Applies to **"textfield"**: (optional)
---The initial text contained in the textfield.
---
---Applies to **"text-box"**: (optional)
---The initial text contained in the text-box.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field text string|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field numeric boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field allow_decimal boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field allow_negative boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field is_password boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field lose_focus_on_confirm boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---Applies to **"text-box"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field clear_and_focus_on_right_click boolean|nil
---Applies to **"progressbar"**: (optional)
---The initial value of the progressbar, in the range [0, 1]. Defaults to `0`.
---
---Applies to **"slider"**: (optional)
---The initial value for the slider. Defaults to `minimum_value`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field value double|nil
---Applies to **"checkbox"**: (required)
---The initial checked-state of the checkbox.
---
---Applies to **"radiobutton"**: (required)
---The initial checked-state of the radiobutton.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field state boolean
---Applies to **"sprite-button"**: (optional)
---Path to the image to display on the button.
---
---Applies to **"sprite"**: (optional)
---Path to the image to display.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field sprite SpritePath|nil
---Applies to **"sprite-button"**: (optional)
---Path to the image to display on the button when it is hovered.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field hovered_sprite SpritePath|nil
---Applies to **"sprite-button"**: (optional)
---Path to the image to display on the button when it is clicked.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field clicked_sprite SpritePath|nil
---Applies to **"sprite-button"**: (optional)
---The number shown on the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field number double|nil
---Applies to **"sprite-button"**: (optional)
---Formats small numbers as percentages. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field show_percent_for_small_numbers boolean|nil
---Applies to **"sprite"**: (optional)
---Whether the widget should resize according to the sprite in it. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field resize_to_sprite boolean|nil
---Applies to **"scroll-pane"**: (optional)
---Policy of the horizontal scroll bar. Possible values are `"auto"`, `"never"`, `"always"`, `"auto-and-reserve-space"`, `"dont-show-but-allow-scrolling"`. Defaults to `"auto"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field horizontal_scroll_policy string|nil
---Applies to **"scroll-pane"**: (optional)
---Policy of the vertical scroll bar. Possible values are `"auto"`, `"never"`, `"always"`, `"auto-and-reserve-space"`, `"dont-show-but-allow-scrolling"`. Defaults to `"auto"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field vertical_scroll_policy string|nil
---Applies to **"drop-down"**: (optional)
---The initial items in the dropdown.
---
---Applies to **"list-box"**: (optional)
---The initial items in the listbox.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field items LocalisedString[]|nil
---Applies to **"drop-down"**: (optional)
---The index of the initially selected item. Defaults to 0.
---
---Applies to **"list-box"**: (optional)
---The index of the initially selected item. Defaults to 0.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field selected_index uint|nil
---Applies to **"camera"**: (required)
---The position the camera centers on.
---
---Applies to **"minimap"**: (optional)
---The position the minimap centers on. Defaults to the player's current position.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field position Position<int,int>
---Applies to **"camera"**: (optional)
---The surface that the camera will render. Defaults to the player's current surface.
---
---Applies to **"minimap"**: (optional)
---The surface the camera will render. Defaults to the player's current surface.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field surface_index uint|nil
---Applies to **"camera"**: (optional)
---The initial camera zoom. Defaults to `0.75`.
---
---Applies to **"minimap"**: (optional)
---The initial camera zoom. Defaults to `0.75`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field zoom double|nil
---Applies to **"choose-elem-button"**: (required)
---The type of the button - one of the following values.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field elem_type string
---Applies to **"choose-elem-button"**: (optional)
---If type is `"item"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field item string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"tile"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field tile string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"entity"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field entity string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"signal"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field signal SignalID|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"fluid"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field fluid string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"recipe"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field recipe string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"decorative"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field decorative string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"item-group"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field item-group string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"achievement"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field achievement string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"equipment"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field equipment string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"technology"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field technology string|nil
---Applies to **"choose-elem-button"**: (optional)
---Filters describing what to show in the selection window. See [LuaGuiElement::elem_filters](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.elem_filters).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field elem_filters PrototypeFilter[]|nil
---Applies to **"slider"**: (optional)
---The minimum value for the slider. Defaults to `0`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field minimum_value double|nil
---Applies to **"slider"**: (optional)
---The maximum value for the slider. Defaults to `30`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field maximum_value double|nil
---Applies to **"slider"**: (optional)
---The minimum value the slider can move. Defaults to `1`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field value_step double|nil
---Applies to **"slider"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field discrete_slider boolean|nil
---Applies to **"slider"**: (optional)
---Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field discrete_values boolean|nil
---Applies to **"minimap"**: (optional)
---The player index the map should use. Defaults to the current player.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field chart_player_index uint|nil
---Applies to **"minimap"**: (optional)
---The force this minimap should use. Defaults to the player's current force.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field force string|nil
---Applies to **"tab"**: (optional)
---The text to display after the normal tab text (designed to work with numbers).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field badge_text LocalisedString|nil
---Applies to **"switch"**: (optional)
---Possible values are `"left"`, `"right"`, or `"none"`. If set to "none", `allow_none_state` must be `true`. Defaults to `"left"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field switch_state string|nil
---Applies to **"switch"**: (optional)
---Whether the switch can be set to a middle state. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field allow_none_state boolean|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field left_label_caption LocalisedString|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field left_label_tooltip LocalisedString|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field right_label_caption LocalisedString|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field right_label_tooltip LocalisedString|nil

return GuiUtil
