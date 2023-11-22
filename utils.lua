--[[This file is part of LuaPlume.

LuaPlume is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

LuaPlume is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with LuaPlume. If not, see <https://www.gnu.org/licenses/>.
]]
Plume.utils = {}

function Plume.utils.copy (t)
    local nt = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            nt[k] = Plume.utils.copy (v)
        else
            nt[k] = v
        end
    end
    return nt
end

function Plume.utils.load (s, name, env)
    -- Load string in a specified env
    -- Working for all lua versions
    if not setfenv  then
        return load (s, name, "t", env)
    end
    
    local f, err = loadstring(s, name)
    if f and env then
        setfenv(f, env)
    end

    return f, err
end

function Plume.utils.friendly_error (code, err)
    local name = err:match('^[^:]*')
    err = err:sub(#name+2, -1)
    local noline_lua = err:match('^[^:]*')
    err = err:sub(#noline_lua+2, -1)
    noline_lua = tonumber (noline_lua)
    
    local error_line     = ""
    local noline_plume   = 0
    local noline_current = 0
    for line in code:gmatch('[^\n]*\n?') do
        noline_current = noline_current + 1

        if line:match '^%s*%-%- line [0-9]+ : ' then
            noline_plume, error_line = line:match '^%s*%-%- line ([0-9]+) : ([^\n]*)'
        end

        if noline_current >= noline_lua then
            break
        end
    end

    error('#VERSION: ' .. name .. ':' .. noline_plume .. ':' .. err)
end

-- Predefined list of standard Lua variables/functions for various versions
Plume.utils.LUA_STD_FUNCTION = {
    ["5.1"]="_VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall",

    ["5.2"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type unpack xpcall xpcall",

    ["5.3"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall",

    ["5.4"]="_VERSION arg assert collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 warn xpcall",

    jit="_VERSION arg assert bit collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall"
}