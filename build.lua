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

print("Creating plume.lua...")
-- Merge all plume code into a single standalone file
local plume = io.open 'main.lua':read '*a'

plume = plume:gsub('%-%- #INCLUDE : (%w+)', function(m)
    return io.open(m .. '.lua'):read '*a':gsub('^.-%]%]', '')
end)

io.open('dist/plume.lua', 'w'):write(plume)
print("Done with sucess")