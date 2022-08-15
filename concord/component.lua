--- A pure data container that is contained within a single Entity
-- @classmod Component
local PATH = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH .. ".components")
local Utils = require(PATH .. ".utils")

local Component = {}

Component.__mt = {__index = Component}

local function checkTypes(id, name, populate)
    if (type(id) ~= "number") then
        error("bad argument #1 to 'Component.new' (number expected, got " ..
                  type(id) .. ")", 2)
    end

    local name_t = type(name)
    if (name_t ~= "string" and name_t ~= "nil") then
        error(
            "bad argument #3 to 'Component.new' (string/nil expected, got " ..
                type(name) .. ")", 2)
    end

    local populate_t = type(populate)
    if (populate_t ~= "function" and populate_t ~= "nil") then
        error(
            "bad argument #2 to 'Component.new' (function/nil expected, got " ..
                type(populate) .. ")", 2)
    end
end

--- Creates a new ComponentClass.
-- @number id An identifier used to retrieve the component
-- @string name The name of the component (used for debuging purposes)
-- @tparam[opt] function populate A function that populates a
-- Component with values
-- @treturn Component
function Component.new(id, name, populate)
    checkTypes(id, name, populate)

    if (rawget(Components, id)) then
        error("ComponentClass with id '" .. id .. "' was already registered)", 2)
    end

    local component_class = setmetatable({
        __populate = populate,
        __id = id,
        __name = name,
        __is_component_class = true
    }, Component.__mt)

    component_class.__mt = {__index = component_class}

    Components[id] = component_class

    return component_class
end

-- Internal: Populates a Component with values
function Component:__populate() -- luacheck: ignore
end

--- Dumps the Component's associated data onto a table and returns it
-- @treturn table
function Component:serialize()
    local data = Utils.shallowCopy(self, {})

    -- This values shouldn't be copied over
    data.__is_component = nil
    data.__is_component_class = nil

    return data
end

--- Restores the Component's state by shallow copying the
-- given serialized data onto itself
-- No checks are performed to ensure the given data is associated
-- with the Component instance
-- @see Component:serialize
-- @tparam table data The serialized data
-- @treturn table The table containing the serialized Component's data
function Component:deserialize(data) Utils.shallowCopy(data, self) end

-- Internal: Creates a new Component instance.
-- @treturn Component A new Component
function Component:__new()
    local component = setmetatable({
        __is_component = true,
        __is_component_class = false
    }, self.__mt)

    return component
end

-- Internal: Creates and populates a new Component.
-- @param ... Arguments passed to the populate function
-- @treturn Component A new populated Component
function Component:__initialize(...)
    local component = self:__new()

    self.__populate(component, ...)

    return component
end

--- Returns true if the Component has a name.
-- @treturn boolean
function Component:hasName() return self.__name and true or false end

--- Returns the name of the Component.
-- @treturn string
function Component:getName() return self.__name end

return setmetatable(Component, {
    __call = function(_, id, name, init) return Component.new(id, name, init) end
})
