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
local plume   = io.open 'plume.lua':read '*a'
local version = 'v1.0.#BUILD-alpha'
local build   = 7

plume = plume:gsub('\n%-%- <TO REMOVE.-%-%- >\n', '')
plume = plume:gsub('#VERSION', version:gsub('#BUILD', build))
plume = plume:gsub('include \'(%w+)\'', function(m)
    return io.open(m .. '.lua'):read '*a':gsub('^.-%]%]', '')
end)

io.open('dist/plume.lua', 'w'):write(plume)
print("Done with sucess")

-- incremente build number
local f = io.open('build.lua')
local code = f:read('*a'):gsub('local build   = 7', 'local build   = ' .. (build+1))
f:close ()
local f = io.open('build.lua', 'w')
f:write(code)
f:close()