--- A Container for registered ComponentClasses
-- @module Components
local Components = {}

--- Returns true if the containter has the ComponentClass with
-- the specified id
-- @number component_id The assigned id of the ComponentClass to search for
-- @treturn boolean
function Components.has(component_id)
    return rawget(Components, component_id) and true or false
end

--- Returns the status of the retrieval and the ComponentClass if one was
-- registered with the specified id
-- @number component_id The assigned id of the ComponentClass to search for
-- @treturn boolean
-- @treturn ?Component
function Components.try(component_id)
    if type(component_id) ~= "number" then return false, nil end

    local value = rawget(Components, component_id)

    return true, value
end

--- Returns the ComponentClass with the specified id or errors
-- if not found
-- @number component_id The assigned id of the ComponentClass to retrieve
-- @treturn Component
function Components.get(component_id)
    local ok, component = Components.try(component_id)

    if not ok then
        error("Invalid argument to expected number got" .. type(component), 2)
    elseif component == false then
        error("Component with id: " .. component_id .. " does not exist", 2)
    end

    return component
end

return setmetatable(Components, {
    __index = function(_, component_id) return Components.get(component_id) end
})
