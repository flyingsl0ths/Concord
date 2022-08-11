-- Type
-- Helper module to do easy type checking for Concord types
local Type = {}

--- Returns if object is an Entity.
-- @param t Object to check
-- @treturn boolean
function Type.isEntity(t) return type(t) == "table" and t.__is_entity or false end

--- Returns if object is a ComponentClass.
-- @param t Object to check
-- @treturn boolean
function Type.isComponentClass(t)
    return type(t) == "table" and t.__is_component_class or false
end

--- Returns if object is a Component.
-- @param t Object to check
-- @treturn boolean
function Type.isComponent(t)
    return type(t) == "table" and t.__is_component or false
end

--- Returns if object is a SystemClass.
-- @param t Object to check
-- @treturn boolean
function Type.isSystemClass(t)
    return type(t) == "table" and t.__is_system_class or false
end

--- Returns if object is a System.
-- @param t Object to check
-- @treturn boolean
function Type.isSystem(t) return type(t) == "table" and t.__is_system or false end

--- Returns if object is a Pool.
-- @param t Object to check
-- @treturn boolean
function Type.isPool(t) return type(t) == "table" and t.__is_pool or false end

--- Returns if object is a World.
-- @param t Object to check
-- @treturn boolean
function Type.isWorld(t) return type(t) == "table" and t.__is_world or false end

return Type
