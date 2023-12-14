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
-- All 'write' functions don't modify the line 
function Wings.transpiler:write_text (s)
    -- Handle text that may be added to the output by Wings
    if #s > 0 then
        table.insert(
            self.chunck, 
            '\n'.. self.indent
                .. "wings:write "
                .. self:escape_string (s)
        )
    end
end

function Wings.transpiler:write_lua (s, toindent)
    -- Handle text that are raw lua code
    if toindent then
        s = self.indent .. s
    end
    table.insert(self.chunck, s)
end

function Wings.transpiler:write_variable(s)
    -- Handle variable that may be added to the output by Wings
    if #s > 0 then
        table.insert(self.chunck, '\n'.. self.indent .. "wings:write (" .. s .. ")")
    end
end

function Wings.transpiler:write_macrodef_info (name, info, isstruct)
    -- store function args names and defauts values
    table.insert(self.chunck, '\n'..self.indent..'wings.macro_info[' .. name .. '] = {args=' .. info .. ', ')
    if isstruct then
        table.insert(self.chunck, ('kind = "struct"}'))
    else
        table.insert(self.chunck, ('kind = "macro"}'))
    end
end

function Wings.transpiler:write_macrocall_begin (name, stack_len, isstruct)
    if isstruct then
        -- Check if the macro is a struct
        table.insert(self.chunck, '\n' .. self.indent .. 'if (wings.macro_info['..name..'] or {}).kind ~= "struct" then')
        table.insert(self.chunck, '\n' .. self.indent .. '    error("Try use '..name..', a macro, as a struct.")')
        table.insert(self.chunck, '\n' .. self.indent .. 'end')
    else
        -- Check if the macro isn't a struct
        table.insert(self.chunck, '\n' .. self.indent .. 'if (wings.macro_info['..name..'] or {}).kind == "struct" then')
        table.insert(self.chunck, '\n' .. self.indent .. '    error("Try to call '..name..', a struct value.")')
        table.insert(self.chunck, '\n' .. self.indent .. 'end')
    end
    -- Create the table used to store function arguments
    table.insert(self.chunck, '\n' .. self.indent .. 'wings._args' .. stack_len .. ' = {}\n')
end

function Wings.transpiler:write_macrocall_end (s, stack_len, direct)
    -- Call the function and write the result.
    -- Handle named argument and defaut values.
    -- direct : called without argument.

    if direct then
        table.insert(self.chunck, '\n' .. self.indent
            .. 'wings:write(' .. s .. '(wings:make_args_list ('.. s ..', {})))')
    else
        table.insert(self.chunck, '\n' .. self.indent
            .. 'wings:write(' .. s .. '(wings:make_args_list ('.. s ..', wings._args' .. stack_len .. ')))')
    end
end

function Wings.transpiler:write_macrocall_arg_begin (name, stack_len)
    -- write the begining of a argument : a function to encompass the argument body.
    -- name must be a valid lua key following by a '='
    if name then
        table.insert(self.chunck, '\n' .. self.indent .. 'wings._args' .. stack_len .. '["' .. name .. '"] = ((function()')
    else
        table.insert(self.chunck, '\n' .. self.indent .. 'table.insert (wings._args' .. stack_len .. ', (function()')
    end
    self:increment_indent ()
    table.insert(self.chunck, '\n' .. self.indent .. 'wings:push()')
end

function Wings.transpiler:write_macrocall_arg_end (isstruct)
    -- Closing args function
    table.insert(self.chunck, '\n' .. self.indent .. 'return wings:pop()')
    self:decrement_indent ()
    -- If closing a struct, do not call the function
    if isstruct then
        table.insert(self.chunck, '\n' .. self.indent .. 'end))')
    else
        table.insert(self.chunck, '\n' .. self.indent .. 'end)())')
    end
end