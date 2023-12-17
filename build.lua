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

-- Merge all wings code into a single standalone file
-- Quite dirty, but do the job

print("Creating wings.lua...")

local wings   = io.open 'wings.lua':read '*a'
local version = 'Wings v1.0.0'
local dev   = true
local devn = 2514

-- If in developpement, make the version number unic.
if dev then
    version = version .. "-dev (build " .. devn .. ')'
    local f = io.open('build.lua')
    local build = f:read('*a'):gsub('local devn = [0-9]+', 'local devn = ' .. (devn+1))
    f:close ()
    io.open('build.lua', 'w'):write(build)
end

wings = wings:gsub('#VERSION', version)

-- Replace include with file content
wings = wings:gsub('\n%-%- <TO REMOVE.-%-%- TO REMOVE>\n', '')
wings = wings:gsub('include \'([%w%-_]+)\'', function(m)
    return io.open(m .. '.lua'):read '*a':gsub('^.-%]%]', '')
end)

-- Place cli help at the top of the file
local cli_help_pattern = 'local cli_help = %[=%[.*%]=%]'
local cli_help = wings:match(cli_help_pattern)
wings = wings:gsub(cli_help_pattern, '')
wings = wings:gsub('%-%-<CLI HELP>', cli_help)

io.open('dist/wings.lua', 'w'):write(wings)
print("Done with sucess")