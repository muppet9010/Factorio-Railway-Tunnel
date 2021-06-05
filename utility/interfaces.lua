local Interfaces = {}
MOD = MOD or {}
MOD.interfaces = MOD.interfaces or {}

-- Called from OnLoad() from each script file.
Interfaces.RegisterInterface = function(interfaceName, interfaceFunction)
    MOD.interfaces[interfaceName] = interfaceFunction
    return interfaceName
end

-- Called when needed.
Interfaces.Call = function(interfaceName, ...)
    if MOD.interfaces[interfaceName] ~= nil then
        return MOD.interfaces[interfaceName](...)
    else
        error("WARNING: interface called that doesn't exist: " .. interfaceName)
    end
end

-- Used to get a reference to a named interface function. Way to cache a frequently used interface (OnLoad order matters between the 2 classes).
Interfaces.GetNamedFunction = function(interfaceName)
    return MOD.interfaces[interfaceName]
end

return Interfaces
