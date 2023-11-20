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
function Plume:include(name)
    -- This function work like require :
    -- Search for a file named 'name.plume' and 'execute it'
    -- In the context of plume, the file will be rendered and added to the output
    -- Unlike require, result will not be cached
    local failed_path = {}
    local file

    -- name is a TokenList, so we need to convert it
    name = name:tostring()

    for path in self.path:gmatch('[^;]+') do
        local path = path:gsub('?', name)
        file = io.open(path)
        if file then
            break
        else
            table.insert(failed_path, path)
        end
    end

    if not file then
        error ("plume file '" .. name .. "' not found:\n    no file " .. table.concat(failed_path, '\n    no file '))
    end

    local plumecode = file:read "*a"
    local result    = self:render(plumecode)
    
    return result
end