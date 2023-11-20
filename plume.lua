--[[
LuaPlume v1.0.0-alpha
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

Plume._VERSION = "LuaPlume 1.0.0-alpha"

-- Lua 5.1 compatibility
local setfenv = setfenv or function () end

-- Predefined list of standard Lua variables/functions for various versions
-- These are intended to be provided as a part of sandbox environments to execute user code safely
local LUA_STD = {
    ["5.1"]="_VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall",

    ["5.2"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type unpack xpcall xpcall",

    ["5.3"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall",

    ["5.4"]="_VERSION arg assert collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 warn xpcall",

    jit="_VERSION arg assert bit collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall"
}

-- <TO REMOVE
-- Utils function to split main file in chunck.
-- Only for developement purpose, will not be part of the final file.
local function include (name)
    local env = setmetatable({Plume=Plume}, {__index=_G})
    local script, err = loadfile (debug.getinfo(2, "S").source:sub(2):gsub('[^\\/]*$', '') .. name..'.lua', "t", env)
    if not script then
        error('Include file "' .. name .. '" : \n' .. err)
    end
    setfenv (script, env)
    script ()
end
-- >

Plume.patterns = {
    escape="#",
    indent="    "
}

include 'transpile'
include 'engine'
include 'token'
include 'std'

function Plume:new ()
    local plume = {}

    for k, v in pairs(Plume) do
        plume[k] = v
    end

    -- Create a new environment
    plume.env = {
        plume=plume,
        include=function (...) return plume:include (...) end,
    }

    -- Inherit from package.path
    plume.path=package.path:gsub('%.lua', '.plume')

    -- Stack used for managing nested constructs in the templating language
    plume.stack = {}

    -- Weak table holding function argument information
    plume.function_args = setmetatable({}, {__mode="k"})

    plume.type = "plume"

    local version
    if jit then
        version = "jit"
    else
        version = _VERSION:match('[0-9]%.[0-9]$')
    end

    -- Populate plume.env with lua defaut functions
    for name in LUA_STD[version]:gmatch('%S+') do
        plume.env[name] = _G[name]
    end

    return plume
end

function Plume:render(code)
    optns = optns or {}
    local luacode = self:transpile (code, optns.keepspace)

    -- Compatibily for lua 5.1
    -- parameters are only for lua>5.2
    local f, err = (loadstring or load) (luacode, "plumecode", 't', self.env)
    if not f then
        error(err)
    end

    -- Compatibily for lua 5.1
    setfenv (f, self.env)

    local sucess, result = pcall(f)
    if not sucess then
        error(result)
    end

    result.luacode = luacode
    return result
end

return Plume