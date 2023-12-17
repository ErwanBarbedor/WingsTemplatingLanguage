--[[
#VERSION
Copyright (C) 2023  Erwan Barbedor

Check https://github.com/ErwanBarbedor/WingsTemplatingLanguage
for documentation, tutorial or to report issues.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

--<CLI HELP>

local Wings = {}

Wings._VERSION = "#VERSION"

Wings.config = {}
Wings.config.extensions = {'wings'}

-- <TO REMOVE
-- Utils function to split main file in chunck.
-- Only for developement purpose, will not be part of the final file.
local function include (name)
    local env = setmetatable({Wings=Wings}, {__index=_G})
    local script, err = loadfile (debug.getinfo(2, "S").source:sub(2):gsub('[^\\/]*$', '') .. name..'.lua', "t", env)
    if not script then
        error('Include file "' .. name .. '" : \n' .. err)
    end
    if setfenv then
        setfenv (script, env)
    end
    script ()
end
-- TO REMOVE>

include 'utils'

Wings.transpiler = {}
include 'patterns'
include 'transpiler'
include 'transpiler_write'
include 'transpiler_handle'

include 'engine'
include 'token'
Wings.std = {}
include 'std'


function Wings:new ()
    -- Create Wings interpreter instance.
    -- Each instance has it's own environnement and configuration.

    local wings = Wings.utils.copy (Wings)

    -- Create a new environment
    wings.env = {
        wings=wings
    }

    -- Inherit from package.path
    wings.package = {}
    wings.package.path= {}
    for path in package.path:gmatch('[^;]+') do
        path = path:gsub('%.lua$', '.ext')
        table.insert(wings.package.path, path)
    end
    
    -- Stack used for managing nested constructs
    wings.stack = {}
    -- Manage "context", a custom kind of local variable
    wings.context = setmetatable({{}}, wings.context_mt)
    -- Track differents files rendered in the same instance
    wings.filestack = {}
    -- Activate/desactivate error handling by wings.
    wings.WINGS_ERROR_HANDLING = true
    -- Path to save transpiled code
    wings.SAVE_LUACODE_DIR = false
    
    -- Store macro information
    wings.macro_info = setmetatable({}, {__mode="k"})
    
    wings.type = "wings"
    wings.transpiler:compile_patterns ()

    -- Populate wings.env with lua and wings defaut functions
    local version
    if jit then
        version = "jit"
    else
        version = _VERSION:match('[0-9]%.[0-9]$')
    end

    for name in Wings.utils.LUA_STD_FUNCTION[version]:gmatch('%S+') do
        wings.env[name] = _G[name]
    end

    for name, f in pairs(Wings.std) do
        wings.env[name] = function (...) return f (wings, ...) end
    end

    return wings
end

function Wings:render(code, filename)

    -- Transpile the code, then execute it and return the result
    local luacode = self.transpiler:transpile (code)

    if filename then
        name = filename .. "@wings"
    else
        name = '<internal-'..#self.filestack..'>@wings'
    end

    table.insert(self.filestack, {filename=name, code=code, luacode=luacode})

    if self.SAVE_LUACODE_DIR then
        filename = (filename or name:gsub('[<>]', '_')):gsub('@wings$', ''):gsub('/', '___')
        local path = self.SAVE_LUACODE_DIR .. '/' .. filename .. '.lua'
        local file = io.open(path, "w")
        if file then
            file:write(luacode)
            file:close ()
        else
            error("Cannot write the file '" .. path .. "'")
        end
    end

    local f, err = self.utils.load (luacode, "@" .. name ,  self.env)
    if not f then
        if self.WINGS_ERROR_HANDLING then
            error(self:format_error (err), -1)
        else
            error(err)
        end
        
    end
    
    local sucess, result = xpcall(f, function(err)
        -- --To debug error handling...
        -- local sucess, result = pcall(self.format_error, self, err)
        -- if not sucess then
        --     print(result)
        -- end
        if self.WINGS_ERROR_HANDLING then
            return self:format_error (err)
        else
            return err
        end
    end)

    if not sucess then
        error(result)
    end

    result.luacode = luacode
    return result
end

function Wings:renderFile (path)
    -- Too automaticaly read the file and pass the name to render
    local file = io.open(path)

    if not file then
        error("The file '" .. path .. "' doesn't exist.")
    end

    return self:render(file:read"*a", path)
end

include 'cli'

return Wings