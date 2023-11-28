--[[This file is part of Wings.

Wings is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Wings is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Wings. If not, see <https://www.gnu.org/licenses/>.
]]

print("Creating wings.lua...")
-- Merge all wings code into a single standalone file
local wings   = io.open 'main.lua':read '*a'
local version = 'Wings v0.1'
local alpha   = false

if alpha then
    version = version .. "-alpha-" .. os.time ()
end

wings = wings:gsub('\n%-%- <TO REMOVE.-%-%- TO REMOVE>\n', '')
wings = wings:gsub('#VERSION', version)
wings = wings:gsub('include \'(%w+)\'', function(m)
    return io.open(m .. '.lua'):read '*a':gsub('^.-%]%]', '')
end)

io.open('dist/wings.lua', 'w'):write(wings)
print("Done with sucess")