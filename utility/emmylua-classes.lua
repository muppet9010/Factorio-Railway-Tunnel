--[[
    Generic EmmyLua classes. You don't need to require this file anywhere, EmyyLua will discover it within the workspace.
--]]
---@meta
---@diagnostic disable
---
---
---
---@class Id : uint @id attribute of this thing.
---
---@class UnitNumber : uint @unit_number of the related entity.
---
---@alias Axis "'x'"|"'y'"
---
---@class PlayerIndex:uint @Player index attribute.
---
---@class Tick : int
---
---@class Second : int
---
---@class CustomInputEvent
---@field player_index uint
---@field input_name string
---@field cursor_position Position
---@field selected_prototype SelectedPrototypeData
---
---@class Sprite
---@field direction_count uint
---@field filename string
---@field width uint
---@field height uint
---@field repeat_count uint
---
---@alias EntityActioner LuaPlayer|LuaEntity|null @The placer of a built entity: either player, construction robot or script (nil).
---@class LuaBaseClass @Used as a fake base class, only supports checking defined attributes.
---@field valid boolean
---
---@class StringOrNumber @A string or number (int/double).
---
---@class null @Alias for nil value. Workaround for EmmyLua not handling nil in multi type lists correctly.
