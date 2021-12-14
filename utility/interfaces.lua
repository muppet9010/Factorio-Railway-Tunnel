--[[
	Library to allow registering functions as interfaces internally within the mod to support modualr mod design.
--]]
local Interfaces = {}
MOD = MOD or {}
MOD.interfaces = MOD.interfaces or {} ---@type table<string, function>

--- Called from OnLoad() from each script file. Registers a uniquely named function for calling from anywhere later.
---@param interfaceName string
---@param interfaceFunction function
---@return string
Interfaces.RegisterInterface = function(interfaceName, interfaceFunction)
    MOD.interfaces[interfaceName] = interfaceFunction
    return interfaceName
end

--- Called when needed.
---@param interfaceName string
---@vararg any
---@return any
Interfaces.Call = function(interfaceName, ...)
    if MOD.interfaces[interfaceName] ~= nil then
        return MOD.interfaces[interfaceName](...)
    else
        error("WARNING: interface called that doesn't exist: " .. interfaceName)
    end
end

--- Used to get a reference to a named interface function. Way to cache a frequently used interface (OnLoad order matters between the 2 classes).
---@param interfaceName string
---@return function
Interfaces.GetNamedFunction = function(interfaceName)
    return MOD.interfaces[interfaceName]
end

return Interfaces
