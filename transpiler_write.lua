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

function Wings.transpiler:write_variable_or_function(s)
    -- Handle variable that may be added to the output by Wings
    -- Handle implicit function call. (not inside wings:write() to keep
    -- the function name in case of error.)
    if #s > 0 then
        table.insert(self.chunck, '\n'.. self.indent .. 'if type(' .. s .. ') == "function" then')
        table.insert(self.chunck, '\n'.. self.indent .. "\twings:write (" .. s .. "(wings:make_args_list (".. s ..", {})))")
        table.insert(self.chunck, '\n'.. self.indent .. 'else')
        table.insert(self.chunck, '\n'.. self.indent .. "\twings:write (" .. s .. ")")
        table.insert(self.chunck, '\n'.. self.indent .. 'end')
    end
end

function Wings.transpiler:write_functiondef_info (name, info)
    -- store function args names and defauts values
    table.insert(self.chunck, '\n'..self.indent..'wings.function_args_info[' .. name .. '] = ' .. info)
end

function Wings.transpiler:write_functioncall_begin (stack_len)
    -- Create the table used to store function arguments
    table.insert(self.chunck, '\n' .. self.indent .. 'wings._args' .. stack_len .. ' = {}\n')
end

function Wings.transpiler:write_functioncall_end (s, stack_len, direct)
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

function Wings.transpiler:write_functioncall_arg_begin (name, stack_len)
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

function Wings.transpiler:write_functioncall_arg_end ()
    -- Closing args function
    table.insert(self.chunck, '\n' .. self.indent .. 'return wings:pop()')
    self:decrement_indent ()
    table.insert(self.chunck, '\n' .. self.indent .. 'end)())')
    self:increment_indent ()
end