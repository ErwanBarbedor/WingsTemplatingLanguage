--[[
#VERSION
Copyright (C) 2023  Erwan Barbedor

Check https://github.com/ErwanBarbedor/LuaPlume
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

local Plume = {}

Plume._VERSION = "#VERSION"

-- <TO REMOVE
-- Utils function to split main file in chunck.
-- Only for developement purpose, will not be part of the final file.
local function include (name)
    local env = setmetatable({Plume=Plume}, {__index=_G})
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

Plume.transpiler = {}
include 'patterns'
include 'transpile'
include 'engine'
include 'token'
Plume.std = {}
include 'std'


function Plume:new ()
    -- Create Plume interpreter instance.
    -- Each instance has it's own environnement and configuration.

    local plume = Plume.utils.copy (Plume)

    -- Create a new environment
    plume.env = {
        plume=plume
    }

    -- Inherit from package.path
    plume.path=package.path:gsub('%.lua', '.plume')
    -- Stack used for managing nested constructs
    plume.stack = {}
    -- Track differents files rendered in the same instance
    plume.filestack = {}
    -- Activate/desactivate error handling by plume.
    plume.PLUME_ERROR_HANDLING = false
    
    plume.type = "plume"
    plume.transpiler:compile_patterns ()

    -- Populate plume.env with lua and plume defaut functions
    local version
    if jit then
        version = "jit"
    else
        version = _VERSION:match('[0-9]%.[0-9]$')
    end

    for name in Plume.utils.LUA_STD_FUNCTION[version]:gmatch('%S+') do
        plume.env[name] = _G[name]
    end

    for name, f in pairs(Plume.std) do
        plume.env[name] = function (...) return f (plume, ...) end
    end

    return plume
end

function Plume:render(code, filename)
    -- Transpile the code, then execute it and return the result

    local luacode = self.transpiler:transpile (code)

    table.insert(self.filestack, {filename=filename, code=code, luacode=luacode})

    if filename then
        name = filename .. ".plume"
    else
        name = '<internal-'..#self.filestack..'.plume>'
    end

    local f, err = self.utils.load (luacode, "@" .. name ,  self.env)
    if not f then
        if self.PLUME_ERROR_HANDLING then
            error(self:format_error (err), -1)
        else
            error(err)
        end
        
    end
    
    local sucess, result = xpcall(f, function(err)
        if self.PLUME_ERROR_HANDLING then
            return self:format_error (err)
        else
            return err
        end
    end)

    if not sucess then
        error(result, -1)
    end

    table.remove(self.filestack)

    result.luacode = luacode
    return result
end

function Plume:renderFile (path)
    -- Too automaticaly read the file and pass the name to render
    local file = io.open(path)

    if not file then
        error("The file '" .. path .. "' doesn't exist.")
    end

    return self:render(file:read"*a", path)
end

return Plume