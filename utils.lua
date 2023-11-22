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
    
    local f, err = loadstring(s)
    if f and env then
        setfenv(f, env)
    end

    return f, err
end