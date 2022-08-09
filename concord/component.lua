--- A pure data container that is contained by a single entity.
-- @classmod Component
local PATH = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH .. ".components")
local Utils = require(PATH .. ".utils")

local Component = {}

Component.__mt = {__index = Component}

--- Creates a new ComponentClass.
-- @tparam function populate Function that populates a Component with values
-- @treturn Component A new ComponentClass
function Component.new(id, populate, name)
    if (type(id) ~= "number") then
        error("bad argument #1 to 'Component.new' (number expected, got " ..
                  type(id) .. ")", 2)
    end

    local populate_t = type(populate)
    if (populate_t ~= "function" and populate_t ~= "nil") then
        error(
            "bad argument #2 to 'Component.new' (function/nil expected, got " ..
                type(populate) .. ")", 2)
    end

    local name_t = type(name)
    if (name_t ~= "string" and name_t ~= "nil") then
        error(
            "bad argument #3 to 'Component.new' (string/nil expected, got " ..
                type(name) .. ")", 2)
    end

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

function Component:serialize()
    local data = Utils.shallowCopy(self, {})

    -- This values shouldn't be copied over
    data.__is_component = nil
    data.__is_component_class = nil

    return data
end

function Component:deserialize(data) Utils.shallowCopy(data, self) end

-- Internal: Creates a new Component.
-- @return A new Component
function Component:__new()
    local component = setmetatable({
        __is_component = true,
        __is_component_class = false
    }, self.__mt)

    return component
end

-- Internal: Creates and populates a new Component.
-- @param ... Varargs passed to the populate function
-- @return A new populated Component
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
    __call = function(_, id, init, name) return Component.new(id, init, name) end
})
