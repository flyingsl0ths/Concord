--- A helper module for misc operations
-- @module Utils
local Utils = {}

--- Creates a read-only instance of the given table
-- @tparam table source The table to make read-only
function Utils.readOnly(source)
    local mt = {
        __index = source,
        __newindex = function()
            error("attempt to update a read-only table", 2)
        end
    }

    return setmetatable({}, mt)
end

--- Performs a shallow copy of the source table onto the destination table
-- @tparam table source The table to copy
-- @tparam table destination The table to append to
function Utils.shallowCopy(source, destination)
    for key, value in pairs(source) do destination[key] = value end

    return destination
end

local function search_in_path(source, namespace)
    local info = love.filesystem.getInfo(source) -- luacheck: ignore

    if (info == nil or info.type ~= "directory") then
        error("bad argument #1 to 'loadNamespace' (path '" .. source ..
                  "' not found)", 2)
    end

    local files = love.filesystem.getDirectoryItems(source)

    for _, file in ipairs(files) do
        local name = file:sub(1, #file - 4)
        local path = source .. "." .. name

        local value = require(path)
        if namespace then namespace[name] = value end
    end

end

local function search_in_paths(paths, namespace)
    for _, path in ipairs(paths) do
        if (type(path) ~= "string") then
            error("bad argument #2 to 'loadNamespace'" ..
                      "(string/table of strings expected," ..
                      " got table containing " .. type(path) .. ")", 2)
        end

        local name = path

        local dotIndex, slashIndex = path:match("^.*()%."),
                                     path:match("^.*()%/")

        if (dotIndex or slashIndex) then
            name = path:sub((dotIndex or slashIndex) + 1)
        end

        local value = require(path)
        if namespace then namespace[name] = value end
    end

end

--- Requires files and places the results in a table.
-- @tparam string|table pathOrFiles The table of paths or a path to a directory.
-- @tparam table namespace A table that will hold the results of the
-- required files
-- @treturn table
function Utils.loadNamespace(pathOrFiles, namespace)
    if (type(pathOrFiles) ~= "string" and type(pathOrFiles) ~= "table") then
        error("bad argument #1 to 'loadNamespace'" ..
                  "(string/table of strings expected, got " .. type(pathOrFiles) ..
                  ")", 2)
    end

    local search_method = type(pathOrFiles)

    if (search_method == "string") then
        search_in_path(pathOrFiles, namespace)
    elseif (search_method == "table") then
        search_in_paths(pathOrFiles, namespace)
    end

    return namespace
end

local function onInvalidComponentClass(status)
    local message = "Component with the given id: " .. status.component_id ..
                        " does not exist"

    if status.throw_error then
        error(message, 2)
    else
        print(message)
    end
end

-- Checks if the component class was successfully retrieved and
-- if it exists @see Components.try
-- @tab status A table of the form
-- @bool ok The status of the retrieval
-- @string method_name The name of the method where the check occurred
-- @tparam Component
-- @bool throw_error Used to indicate whether to throw or print an error
function Utils.checkComponentAccess(status)
    local component_class = status.component_class

    if not status.ok then
        error("bad argument #1 to '" .. status.method_name .. "'", 2)
    end

    if component_class == nil then onInvalidComponentClass(status) end
end

return Utils
