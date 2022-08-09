--- Container for registered ComponentClasses
-- @module Components
local Components = {}

--- Returns true if the containter has the ComponentClass with
-- the specified name
-- @string name Name of the ComponentClass to check
-- @treturn boolean
function Components.has(component_id)
    return rawget(Components, component_id) and true or false
end

--- Returns true and the ComponentClass if one was registered with the specified
-- name or false and an error otherwise
-- @string name Name of the ComponentClass to check
-- @treturn boolean
-- @treturn Component or error string
function Components.try(component_id)
    if type(component_id) ~= "number" then return false, nil end

    local value = rawget(Components, component_id)

    return true, value
end

--- Returns the ComponentClass with the specified name
-- @string name Name of the ComponentClass to get
-- @treturn Component
function Components.get(component_id)
    local ok, component = Components.try(component_id)

    if not ok then
        error("Component with id: " .. component_id .. " does not exist", 2)
    end

    return component
end

return setmetatable(Components, {
    __index = function(_, component_id) return Components.get(component_id) end
})
