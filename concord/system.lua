--- Represents a system that operates on a collection of Entities as specified
-- by it's assigned filter
-- A System contains only a single Pool.
-- A System is contained by a single World.
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

    if not ok then error("bad argument #1 to 'System.makeFilter'", 2) end

    if component_class == nil then
        error("Component with the given id: " .. component_id ..
                  " does not exist", 2)
    end

    filter[#filter + 1] = component_class
end

local validateFilter = function(base_filter)
    local filter = {}

    for _, component in pairs(base_filter) do makeFilter(component, filter) end

    return filter
end

--- Creates a new SystemClass.
-- @number id The id used to by associated World
-- @string name The name of the system
-- @tparam table filter A table containing the ids of the allowable components
-- @treturn System
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

-- Internal: Calls @see Pool:evaluate on the given Entity
-- @tparam Entity entity The Entity to evaluate
-- @treturn System self
function System:__evaluate(entity)
    self.pool:evaluate(entity)
    return self
end

-- Internal: Removes an Entity from the System if possible.
-- @tparam Entity entity The entity to remove
-- @treturn System self
function System:__remove(entity)
    local pool = self.pool

    if pool:has(entity) then pool:remove(entity) end

    return self
end

-- Internal: Clears all Entities from the System.
-- @treturn System self
function System:__clear()
    self.pool:clear()

    return self
end

--- Enables/disables the system
-- @bool enable
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

--- Checks if the System is enabled
-- @treturn bool
function System:isEnabled() return self.__enabled end

--- Returns the World the System is in.
-- @treturn ?World
function System:getWorld() return self.__world end

--- Returns true if the System has a name.
-- @treturn boolean
function System:hasName() return self.__name and true or false end

--- Returns the name of the System.
-- @treturn string
function System:getName() return self.__name end

--- Callbacks
-- @section Callbacks

--- Callback used during system initialization.
-- @tparam World world The World the System was added to
function System:init(world) -- luacheck: ignore
end

--- Callback used for when a System is enabled.
function System:onEnabled() -- luacheck: ignore
end

--- Callback used for when a System is disabled.
function System:onDisabled() -- luacheck: ignore
end

return setmetatable(System, {
    __call = function(_, id, name, filter)
        return System.new(id, name, filter)
    end
})
