--[[This file is part of Wings Script.

Wings Script is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Wings Script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Wings Script. If not, see <https://www.gnu.org/licenses/>.
]]

-- All std functions will be included in wings.env at 
-- wings instance creation.

function Wings.std.import(wings, args)
    -- This function work like require :
    -- Search for a file named 'name.wings' and 'execute it'
    -- In the context of wings, the file will be rendered and added to the output
    -- Unlike require, result will not be cached
    local failed_path = {}
    local file

    local name = wings:make_args_list(args)

    -- name is a TokenList, so we need to convert it
    name = name:tostring()

    for path in wings.path:gmatch('[^;]+') do
        local path = path:gsub('?', name)
        file = io.open(path)
        if file then
            break
        else
            table.insert(failed_path, path)
        end
    end

    if not file then
        error ("wings file '" .. name .. "' not found:\n    no file " .. table.concat(failed_path, '\n    no file '))
    end

    local wingscode = file:read "*a"
    local result    = wings:render(wingscode)
    
    return result
end

function Wings.std.include (wings, args)
    -- include a file in the document, without execute it
    -- the path must be relative to the current file
    local name = wings:make_args_list(args)

    local path = wings:dirname () .. name:tostring ()

    local file = io.open(path)
    if not file then
        error("The file '" .. path .. "' doesn't exist.")
    end

    return file:read '*a'
end