--- An object that exists in a world. An entity
-- contains Components which are processed by Systems.
-- @classmod Entity
local PATH = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH .. ".components")
local Type = require(PATH .. ".type")
local Utils = require(PATH .. ".utils")

local Entity = {}

Entity.__mt = {__index = Entity}

local function checkComponentAccess(status)
    local component_class = status.component_class

    if not status.ok then
        error("bad argument #1 to '" .. status.method_name .. "'", 2)
    end

    if component_class ~= nil then return end

    local message = "Component with the given id: " .. status.component_id ..
                        " does not exist"

    if status.throw_error then
        error(message, 2)
    else
        print(message)
    end
end

--- Creates a new Entity (and optionally adds it to a World)
-- @tparam[opt] World world The world to add the entity to
-- @treturn Entity A new Entity
function Entity.new(world)
    if (world ~= nil and not Type.isWorld(world)) then
        error("bad argument #1 to 'Entity.new' (world/nil expected, got " ..
                  type(world) .. ")", 2)
    end

    local e = setmetatable({
        __world = nil,
        __components = {},
        __is_entity = true
    }, Entity.__mt)

    if (world) then world:addEntity(e) end

    return e
end

local function give(e, component_id, component_class, ...)
    local component = component_class:__initialize(...)

    e.__components[component_id] = component

    return e:__dirty()
end

--- Attempts to give an Entity a Component.
-- If the Component already exists, it's overridden
-- by this new Component.
-- This performs similar checks as Entity:get
-- @see Entity:get
-- @number component_id The id of the component to give
-- @param ... Additional arguments to pass to the Component's populate function
-- @treturn Entity self
function Entity:give(component_id, ...)
    local ok, component_class = Components.try(component_id)

    checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:give",
        component_id = component_id,
        throw_error = true
    })

    return give(self, component_id, component_class, ...)
end

--- Ensures the Entity does not already have the requested Component before
-- adding an instance to it. This performs similar checks as Entity:get
-- @see Entity:get
-- @number component_id The id of the CompnentClass to create an instance of
-- @param ... additional arguments to pass to the Component's populate function
-- @treturn Entity self
function Entity:ensure(component_id, ...)
    local ok, component_class = Components.try(component_id)

    checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:ensure",
        component_id = component_id,
        throw_error = true
    })

    if self.__components[component_id] then return self end

    return give(self, component_id, component_class, ...)
end

--- Attempts to remove a Component from an Entity.
-- This performs similar checks as Entity:has
-- @see Entity:has
-- @number component_id The id of the ComponentClass of the Component to remove
-- @treturn Entity self
function Entity:remove(component_id)
    if not self:has(component_id) then return end

    if self.__components[component_id] == nil then return self end

    self.__components[component_id] = nil

    return self:__dirty()
end

--- Assembles an Entity.
-- @tparam function assemblage A function that will assemble an entity
-- @param ... additional arguments to pass to the assemblage function.
-- @treturn Entity self
function Entity:assemble(assemblage, ...)
    if type(assemblage) ~= "function" then
        error("bad argument #1 to 'Entity:assemble' (function expected, got " ..
                  type(assemblage) .. ")")
    end

    assemblage(self, ...)

    return self
end

--- Removes the Entity from its World if it's attached to one
-- @treturn Entity self
function Entity:destroy()
    if self.__world then self.__world:removeEntity(self) end

    return self
end

--- Internal: Informs the World it's in (if any) that this
-- Entity is marked as "dirty"
-- @treturn Entity self
function Entity:__dirty()
    if self.__world then self.__world:__dirtyEntity(self) end

    return self
end

--- Returns true if the Entity has the requested Component.
-- This will only error if the component id is not of the required
-- type
-- @number component_id The id of the ComponentClass of the Component to check
-- @treturn boolean
function Entity:has(component_id)
    local ok, _ = Components.try(component_id)

    if not ok then error("bad argument #1 to '" .. "Entity:has" .. "'", 2) end

    return self.__components[component_id] and true or false
end

--- Attempts to get a Component from the Entity and performs
-- additional checks to ensure the component id is of the required
-- type as well as if the ComponentClass exists
-- (an error is thrown if it does not)
-- @number component_id The id of the ComponentClass of the Component to get
-- @treturn Component
function Entity:get_s(component_id)
    local ok, component_class = Components.try(component_id)

    checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:get",
        component_id = component_id,
        throw_error = true
    })

    return self.__components[component_id]
end

--- Gets the Component from the Entity without
-- performing any checks
-- @see Entity:get
-- @number component_id The assigned id of the of the Component to get
-- @treturn Component
function Entity:get(component_id) return self.__components[component_id] end

--- Returns a read-only table of all Components the Entity has.
-- @treturn table
function Entity:getComponents() return Utils.readOnly(self.__components) end

--- Returns true if the Entity is in a World
-- @treturn boolean
function Entity:inWorld() return self.__world and true or false end

--- Returns the World the Entity is in
-- @treturn[opt] World
function Entity:getWorld() return self.__world end

local function serializeComponent(component)
    local component_data = component:serialize()

    if component_data == nil then return nil end

    component_data.__id = component.__id
    component_data.__name = component.__name

    return component_data
end

--- Calls Component:serialize on all Components associated
-- with this Entity and returns the results
-- @treturn table
function Entity:serialize()
    local data = {}

    for _, component in pairs(self.__components) do
        if component.__id then
            local component_data = serializeComponent(component)
            if component_data ~= nil then
                data[#data + 1] = component_data
            end
        end
    end

    return data
end

local function onPreDeserialization(component_data)
    local component_id = component_data.__id
    local component_name = component_data.__name

    component_data.__id = nil
    component_data.__name = nil

    if (not Components.has(component_id)) then
        error("ComponentClass '" .. component_name .. "' has yet to be loaded")
    end

    return component_id
end

local function onDeserialization(entity, component_id, component_data)
    local component_class = Components[component_id]

    local component = component_class:__new()

    component:deserialize(component_data)

    entity.__components[component_id] = component

    entity:__dirty()
end

--- Restores an Entity to the state depicted by the given serialized data
-- @tparam table components_data The serialized data
-- @see Entity:serialize
-- @treturn Entity self
function Entity:deserialize(components_data)
    for _, component_data in ipairs(components_data) do
        onDeserialization(self, onPreDeserialization(component_data),
                          component_data)
    end

    return self
end

return setmetatable(Entity,
                    {__call = function(_, world) return Entity.new(world) end})
