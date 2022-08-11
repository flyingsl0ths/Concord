-- An object that exists in a world. An entity
-- contains components which are processed by systems.
-- @classmod Entity
local PATH = (...):gsub('%.[^%.]+$', '')

local Components = require(PATH .. ".components")
local Type = require(PATH .. ".type")
local Utils = require(PATH .. ".utils")

local Entity = {}

Entity.__mt = {__index = Entity}

--- Creates a new Entity. Optionally adds it to a World.
-- @tparam[opt] World world World to add the entity to
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

--- Gives an Entity a Component.
-- If the Component already exists, it's overridden by this new Component
-- @tparam Component componentClass ComponentClass to add an instance of
-- @param ... additional arguments to pass to the Component's populate function
-- @treturn Entity self
function Entity:give(component_id, ...)
    local ok, component_class = Components.try(component_id)

    Utils.checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:give",
        component_id = component_id
    })

    return give(self, component_id, component_class, ...)
end

--- Ensures an Entity to have a Component.
-- If the Component already exists, no action is taken
-- @tparam Component componentClass ComponentClass to add an instance of
-- @param ... additional arguments to pass to the Component's populate function
-- @treturn Entity self
function Entity:ensure(component_id, ...)
    local ok, component_class = Components.try(component_id)

    Utils.checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:ensure",
        component_id = component_id
    })

    if self.__components[component_id] then return self end

    return give(self, component_id, component_class, ...)
end

--- Removes a Component from an Entity.
-- @tparam Component componentClass ComponentClass of the Component to remove
-- @treturn Entity self
function Entity:remove(component_id)
    local ok, component_class = Components.try(component_id)

    Utils.checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:remove",
        component_id = component_id,
        throw_error = true
    })

    if self.__components[component_id] == nil then return self end

    self.__components[component_id] = nil

    return self:__dirty()
end

--- Assembles an Entity.
-- @tparam function assemblage Function that will assemble an entity
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

--- Destroys the Entity.
-- Removes the Entity from its World if it's in one.
-- @return self
function Entity:destroy()
    if self.__world then self.__world:removeEntity(self) end

    return self
end

-- Internal: Tells the World it's in that this Entity is dirty.
-- @return self
function Entity:__dirty()
    if self.__world then self.__world:__dirtyEntity(self) end

    return self
end

--- Returns true if the Entity has a Component.
-- @tparam Component componentClass ComponentClass of the Component to check
-- @treturn boolean
function Entity:has(component_id)
    local ok, component_class = Components.try(component_id)

    Utils.checkComponentAccess({
        ok = ok,
        component_class = component_class,
        method_name = "Entity:has",
        component_id = component_id
    })

    return self.__components[component_id] and true or false
end

--- Gets a Component from the Entity.
-- @tparam Component componentClass ComponentClass of the Component to get
-- @treturn table
function Entity:get(component_id, skip_check)
    local ok, component_class = Components.try(component_id)

    if skip_check then
        Utils.checkComponentAccess({
            ok = ok,
            component_class = component_class,
            method_name = "Entity:get",
            component_id = component_id
        })
    end

    return self.__components[component_id]
end

--- Returns a read-only table of all Components the Entity has.
-- @treturn table Table of all Components the Entity has
function Entity:getComponents() return Utils.readOnly(self.__components) end

--- Returns true if the Entity is in a World.
-- @treturn boolean
function Entity:inWorld() return self.__world and true or false end

--- Returns the World the Entity is in.
-- @treturn World
function Entity:getWorld() return self.__world end

local function serializeComponent(component)
    local component_data = component:serialize()

    if component_data == nil then return nil end

    component_data.__id = component.__id
    component_data.__name = component.__name

    return component_data
end

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

function Entity:deserialize(data)
    for i = 1, #data do
        local current = data[i]
        local data_id = onPreDeserialization(current)

        onDeserialization(self, data_id, current)
    end

    return self
end

return setmetatable(Entity,
                    {__call = function(_, world) return Entity.new(world) end})
