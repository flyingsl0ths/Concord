-- Iterates over Entities. From these Entities
-- its get Components and modify them.
-- A System contains 1 or more Pools.
-- A System is contained by 1 World.
-- @classmod System
local PATH = (...):gsub('%.[^%.]+$', '')

local Pool = require(PATH .. ".pool")
local Utils = require(PATH .. ".utils")
local Components = require(PATH .. ".components")

local System = {ENABLE_OPTIMIZATION = true}

System.mt = {
    __index = System,
    __call = function(system_class, world)
        local system = setmetatable({
            __enabled = true,
            __world = world,
            __is_system = true,
            __is_system_class = false -- Overwrite value from system_class
        }, system_class)

        -- Optimization: We deep copy the System class into our instance
        -- of a system. This grants slightly faster access times at the
        -- cost of memory. Since there (generally) won't be many instances
        -- of worlds this is a worthwhile tradeoff
        if (System.ENABLE_OPTIMIZATION) then
            Utils.shallowCopy(system_class, system)
        end

        system.pool = Pool(system_class.__filter)

        system:init(world)

        return system
    end
}

local function makeFilter(component_id, filter)
    local ok, component_class = Components.try(component_id)

    Utils.checkComponentAccess({
        method_name = "System.new",
        throw_error = true,
        ok = ok,
        component_class = component_class
    })

    filter[#filter + 1] = component_class
end

local validateFilter = function(base_filter)
    local filter = {}

    for _, component in pairs(base_filter) do makeFilter(component, filter) end

    return filter
end

--- Creates a new SystemClass.
-- @param table filters A table containing filters (name = {components...})
-- @treturn System A new SystemClass
function System.new(id, name, filter)
    local system_class = setmetatable({
        __filter = validateFilter(filter),
        __id = id,
        __is_system_class = true,
        __name = name
    }, System.mt)
    system_class.__index = system_class

    -- Optimization: We deep copy the World class into our instance
    -- of a world.This grants slightly faster access times at the
    -- cost of memory. Since there (generally) won't be many instances
    -- of worlds this is a worthwhile tradeoff
    if (System.ENABLE_OPTIMIZATION) then
        Utils.shallowCopy(System, system_class)
    end

    return system_class
end

-- Internal: Evaluates an Entity for all the System's Pools.
-- @param e The Entity to check
-- @treturn System self
function System:__evaluate(e)
    self.pool:evaluate(e)
    return self
end

-- Internal: Removes an Entity from the System.
-- @param e The Entity to remove
-- @treturn System self
function System:__remove(e)
    local pool = self.pool

    if pool:has(e) then pool:remove(e) end

    return self
end

-- Internal: Clears all Entities from the System.
-- @treturn System self
function System:__clear()
    self.pool:clear()

    return self
end

--- Sets if the System is enabled
-- @tparam boolean enable
-- @treturn System self
function System:setEnabled(enable)
    if (not self.__enabled and enable) then
        self.__enabled = true
        self:onEnabled()
    elseif (self.__enabled and not enable) then
        self.__enabled = false
        self:onDisabled()
    end

    return self
end

--- Returns is the System is enabled
-- @treturn boolean
function System:isEnabled() return self.__enabled end

--- Returns the World the System is in.
-- @treturn World
function System:getWorld() return self.__world end

--- Returns true if the System has a name.
-- @treturn boolean
function System:hasName() return self.__name and true or false end

--- Returns the name of the System.
-- @treturn string
function System:getName() return self.__name end

--- Callbacks
-- @section Callbacks

--- Callback for system initialization.
-- @tparam World world The World the System was added to
function System:init(world) -- luacheck: ignore
end

--- Callback for when a System is enabled.
function System:onEnabled() -- luacheck: ignore
end

--- Callback for when a System is disabled.
function System:onDisabled() -- luacheck: ignore
end

return setmetatable(System, {
    __call = function(_, id, name, filter)
        return System.new(id, name, filter)
    end
})
