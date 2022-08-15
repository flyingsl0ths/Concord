--- A grouping of Entities with certain Components as depicted by a filter
-- @classmod Pool
local PATH = (...):gsub('%.[^%.]+$', '')

local List = require(PATH .. ".list")
local Utils = require(PATH .. ".utils")

local Pool = {}

Pool.__mt = {__index = Pool}

--- Creates a new Pool
-- @tparam table filter The table containing the required component ids
-- @treturn Pool The newly created Pool
function Pool.new(filter)
    local pool = setmetatable(List(), Pool.__mt)

    pool.__filter = filter

    pool.__is_pool = true

    return pool
end

--- Checks if an Entity is eligible to be in the Pool
-- @tparam Entity entity The entity to inspect
-- @treturn boolean
function Pool:eligible(entity)
    for i = #self.__filter, 1, -1 do
        local component_id = self.__filter[i].__id

        if not entity.__components[component_id] then return false end
    end

    return true
end

-- Adds an Entity to the Pool, if it is eligble @see Pool:eligble
-- @tparam Entity entity The Entity to be added
-- @bool bypass Instructs whether to bypass the eligibility check
-- @treturn Pool self
-- @treturn boolean Whether the entity was added or not
function Pool:add(entity, bypass)
    if not bypass and not self:eligible(entity) then return self, false end

    List.add(self, entity)
    self:onEntityAdded(entity)

    return self, true
end

-- Removes an Entity from the Pool.
-- @tparam Entity entity The entity to remove
-- @treturn Pool self
function Pool:remove(entity)
    List.remove(self, entity)
    self:onEntityRemoved(entity)

    return self
end

--- Evaluates whether an Entity should be added/removed from the Pool
-- @tparam Entity entity The Entity to be inspected
-- @treturn Pool self
function Pool:evaluate(entity)
    local has = self:has(entity)
    local eligible = self:eligible(entity)

    if not has and eligible then
        -- Bypass the check because we have already checked
        self:add(entity, true)
    elseif has and not eligible then
        self:remove(entity)
    end

    return self
end

--- Gets a read-only version of the filter associated with the Pool
-- @treturn table
function Pool:getFilter() return Utils.readOnly(self.__filter) end

--- A callback used when an Entity is added to the Pool.
-- @tparam Entity entity The entity that was added.
function Pool:onEntityAdded(entity) -- luacheck: ignore
end

-- A callback used when an Entity is removed from the Pool.
-- @tparam Entity entity The entity that was removed.
function Pool:onEntityRemoved(entity) -- luacheck: ignore
end

return setmetatable(Pool, {
    __index = List,
    __call = function(_, filter) return Pool.new(filter) end
})
