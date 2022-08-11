-- A collection of Systems and Entities.
-- A world emits to let Systems iterate.
-- A World contains any amount of Systems.
-- A World contains any amount of Entities.
-- @classmod World
local PATH = (...):gsub('%.[^%.]+$', '')

local Entity = require(PATH .. ".entity")
local Type = require(PATH .. ".type")
local List = require(PATH .. ".list")
local Utils = require(PATH .. ".utils")

local World = {}

World.__mt = {__index = World}

--- Creates a new World.
-- @treturn World The new World
function World.new()
    local world = setmetatable({
        __entities = List(),
        __systems = List(),

        __events = {},
        __emit_sdepth = 0,

        __added = List(),
        __back_added = List(),
        __removed = List(),
        __back_removed = List(),
        __dirty = List(),
        __back_dirty = List(),

        __system_lookup = {},

        __name = nil,
        __is_world = true
    }, World.__mt)

    return world
end

--- Adds an Entity to the World.
-- @tparam Entity e Entity to add
-- @treturn World self
function World:addEntity(e)
    if not Type.isEntity(e) then
        error("bad argument #1 to 'World:addEntity' (Entity expected, got " ..
                  type(e) .. ")", 2)
    end

    if e.__world then
        error([[
	           bad argument #1 to 'World:addEntity'
			   (Entity was already added to a world)
		]], 2)
    end

    e.__world = self
    self.__added:add(e)

    return self
end

--- Removes an Entity from the World.
-- @tparam Entity e Entity to remove
-- @treturn World self
function World:removeEntity(e)
    if not Type.isEntity(e) then
        error(
            "bad argument #1 to 'World:removeEntity' (Entity expected, got " ..
                type(e) .. ")", 2)
    end

    self.__removed:add(e)

    return self
end

-- Internal: Marks an Entity as dirty.
-- @param e Entity to mark as dirty
function World:__dirtyEntity(e)
    if not self.__dirty:has(e) then self.__dirty:add(e) end
end

local function swapEntityBuffers(world)
    world.__added, world.__back_added = world.__back_added, world.__added

    world.__removed, world.__back_removed = world.__back_removed,
                                            world.__removed

    world.__dirty, world.__back_dirty = world.__back_dirty, world.__dirty
end

local function processBuffer(world, buffer, process)
    local entity_buffer = world[buffer]

    for i = 1, entity_buffer.size do
        local entity = entity_buffer[i]
        if entity.__world == world then process(entity, world) end
    end

    entity_buffer:clear()
end

-- Internal: Flushes all changes to Entities.
-- This processes all entities. Adding and removing entities,
-- as well as reevaluating dirty entities.
-- @treturn World self
function World:__flush()
    if (self.__added.size == 0 and self.__removed.size == 0 and
        self.__dirty.size == 0) then return self end

    swapEntityBuffers(self)

    processBuffer(self, "__back_added", function(entity, world)
        world.__entities:add(entity)

        for j = 1, world.__systems.size do
            world.__systems[j]:__evaluate(entity)
        end

        world:onEntityAdded(entity)
    end)

    processBuffer(self, "__back_removed", function(entity, world)
        entity.__world = nil
        world.__entities:remove(entity)

        for j = 1, self.__systems.size do
            world.__systems[j]:__remove(entity)
        end

        world:onEntityRemoved(entity)
    end)

    processBuffer(self, "__back_dirty", function(entity, world)
        for j = 1, world.__systems.size do
            world.__systems[j]:__evaluate(entity)
        end
    end)

    return self
end

-- These functions won't be seen as callbacks that will be emitted to.
local blacklisted_system_functions = {"init", "onEnabled", "onDisabled"}

local function updateListeners(world, callback_name, system, callback)
    -- Skip callback if its blacklisted
    if blacklisted_system_functions[callback_name] then return end

    -- Make container for all listeners of the
    -- callback if it does not exist yet
    if (not world.__events[callback_name]) then
        world.__events[callback_name] = {}
    end

    -- Add callback to listeners
    local listeners = world.__events[callback_name]
    listeners[#listeners + 1] = {system = system, callback = callback}
end

local function tryAddSystem(world, system_class)
    if (not Type.isSystemClass(system_class)) then
        return false, "SystemClass expected, got " .. type(system_class)
    end

    if (world.__system_lookup[system_class.__id]) then
        return false, "SystemClass was already added to World"
    end

    -- Create instance of system
    local system = system_class(world)

    world.__system_lookup[system_class.__id] = system
    world.__systems:add(system)

    for callback_name, callback in pairs(system_class) do
        updateListeners(world, callback_name, system, callback)
    end

    -- Evaluate all existing entities
    for j = 1, world.__entities.size do
        system:__evaluate(world.__entities[j])
    end

    return true
end

--- Adds a System to the World.
-- Callbacks are registered automatically
-- Entities added before are added to the System retroactively
-- @see World:emit
-- @tparam System systemClass SystemClass of System to add
-- @treturn World self
function World:addSystem(systemClass)
    local ok, err = tryAddSystem(self, systemClass)

    if not ok then
        error("bad argument #1 to 'World:addSystem' (" .. err .. ")", 2)
    end

    return self
end

--- Adds multiple Systems to the World.
-- Callbacks are registered automatically
-- @see World:addSystem
-- @see World:emit
-- @param ... SystemClasses of Systems to add
-- @treturn World self
function World:addSystems(...)
    for i = 1, select("#", ...) do self:addSystem(select(i, ...)) end

    return self
end

--- Returns if the World has a System.
-- @tparam System systemClass SystemClass of System to check for
-- @treturn boolean
function World:hasSystem(system_class)
    if not Type.isSystemClass(system_class) then
        error(
            "bad argument #1 to 'World:getSystem' (SystemClass expected, got " ..
                type(system_class) .. ")", 2)
    end

    return self.__system_lookup[system_class.__id] and true or false
end

--- Gets a System from the World.
-- @tparam System systemClass SystemClass of System to get
-- @treturn System System to get
function World:getSystem(systemClass)
    if not Type.isSystemClass(systemClass) then
        error(
            "bad argument #1 to 'World:getSystem' (SystemClass expected, got " ..
                type(systemClass) .. ")", 2)
    end

    return self.__system_lookup[systemClass.__id]
end

--- Emits a callback in the World.
-- Calls all functions with the functionName of added Systems
-- @string functionName Name of functions to call.
-- @param ... Parameters passed to System's functions
-- @treturn World self
function World:emit(function_name, ...)
    if not function_name or type(function_name) ~= "string" then
        error("bad argument #1 to 'World:emit' (String expected, got " ..
                  type(function_name) .. ")")
    end

    local should_flush = self.__emit_sdepth == 0

    self.__emit_sdepth = self.__emit_sdepth + 1

    local listeners = self.__events[function_name]

    if not listeners then return self end

    for i = 1, #listeners do
        local listener = listeners[i]

        if (listener.system.__enabled) then
            if (should_flush) then self:__flush() end

            listener.callback(listener.system, ...)
        end
    end

    self.__emit_sdepth = self.__emit_sdepth - 1

    return self
end

--- Removes all entities from the World
-- @treturn World self
function World:clear()
    for i = 1, self.__entities.size do self:removeEntity(self.__entities[i]) end

    for i = 1, self.__added.size do self.__added[i].__world = nil end

    self.__added:clear()

    self:__flush()

    return self
end

--- Returns a readonly list of all entities in the World
-- @treturn World self
function World:getEntities() return Utils.readOnly(self.__entities) end

--- Returns a readonly list of all systems in the World
-- @treturn World self
function World:getSystems() return Utils.readOnly(self.__systems) end

function World:serialize()
    self:__flush()

    local data = {}

    for i = 1, self.__entities.size do
        data[i] = self.__entities[i]:serialize()
    end

    return data
end

function World:deserialize(data, append)
    if (not append) then self:clear() end

    for i = 1, #data do self:addEntity(Entity():deserialize(data[i])) end

    self:__flush()
end

--- Returns true if the World has a name.
-- @treturn boolean
function World:hasName() return self.__name and true or false end

--- Returns the name of the World.
-- @treturn string
function World:getName() return self.__name end

--- Callback for when an Entity is added to the World.
-- @tparam Entity e The Entity that was added
function World:onEntityAdded(e) -- luacheck: ignore
end

--- Callback for when an Entity is removed from the World.
-- @tparam Entity e The Entity that was removed
function World:onEntityRemoved(e) -- luacheck: ignore
end

return setmetatable(World, {__call = function() return World.new() end})
