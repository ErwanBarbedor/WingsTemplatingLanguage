--[[
LuaPlume #VERSION
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

    -- Stack used for managing nested constructs in the templating language
    plume.stack = {}

    -- Weak tables holding function argument information
    plume.function_args = setmetatable({}, {__mode="k"})
    plume.function_line = setmetatable({}, {__mode="k"})

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

function Plume:render(code, name)
    -- Transpile the code, then execute it and return the result

    local luacode = self.transpiler:transpile (code)

    local f, err = self.utils.load (luacode, "@" .. (name or "main") .. ".plume",  self.env)
    if not f then
        error(err)
    end

    local sucess, result = pcall(f)
    if not sucess then
        self.utils.friendly_error (luacode, result)
    end

    result.luacode = luacode
    return result
end

return Plume