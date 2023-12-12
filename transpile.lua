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

function Wings.transpiler:check_lua_identifier ()
end

function Wings.transpiler:transpile (code)
    -- Define a method to transpile Wings code into Lua

    -- Table to hold code chuncks, one chunck by Wings line.
    self.chuncks = {}

    -- Current chunck being processed
    self.chunck  = {}

    -- stack to manage code blocks and control structures
    self.stack   = {{}}

    -- Track output indentation, for lisibility
    self.indent  = ""

    self.noline = 0
    for line in code:gmatch('[^\n]*\n?') do
        self.line = line
        self.chunck = {}
        self.noline = self.noline + 1

        local is_last_line = not self.line:match('\n$')

        -- Trim line if not inside lua code
        if not (self.stack[#self.stack] or {}).lua then
            self.line = self.line:gsub('^%s*', ''):gsub('%s*$', '')
        end

        -- write \n only if the line contain text
        self.line = self.line:gsub('\r?\n$', '')
        self.pure_lua_line = true



        local rawline = self.line
        while #self.line > 0 do
            self.top = self.stack[#self.stack]

            -- Detect the next signifiant token.
            -- In most of case it will be the escape token,
            -- but can be open_call , closing_call or arg_separator if we are inside a function call
            local before, capture, after = self:split_line()
            

            -- Add texte before the signifiant token to the output
            -- If no token, add whole line
            if self.top.lua then
                self:write_lua ((before or self.line))
            elseif #(before or self.line)>0 then
                self.pure_lua_line = false
                self:write_text (before or self.line)
            end

            -- Manage signifiants tokens
            local to_break
            if capture then
                self.line = after
                to_break = self:capture_syntax_feature (capture)
            end

            if not capture or to_break then
                break
            end
            
        end
        
        if (not self.pure_lua_line or keepspace ) and not is_last_line then
            self:write_text ('\n')
        end

        self.line = table.concat(self.chunck, "")

        -- write comment for debug purpose
        if #rawline > 1 and rawline ~= self.line then
            if self.line:sub(1, 1) ~= "\n" then
                self.line = "\n" .. self.indent .. self.line
            end
            local firstindent = self.line:match('\n%s*')
            self.line = firstindent .. "-- line " .. self.noline .. ' : ' .. rawline:gsub('^\t*', ''):gsub('\n', '') .. self.line .. '\n'
        end

        table.insert(self.chuncks, self.line)
    end

    return "wings:push ()\n\n" .. table.concat (self.chuncks, '') .. "\n\nreturn wings:pop ()"
end

-- All these auxiliary functions may not be calling outside Wings.transpiler.transpile

-- Utils
function Wings.transpiler:escape_string (s)
    -- Make a valid lua string
    return "'" .. s:gsub("'", "\\'")
                   :gsub("\n", "\\n") .. "'"
end

function Wings.transpiler:extract_args (args)
    -- when declaring a function or a macro, extract postional and named arguments informations.
    args = args:sub(2, -2)
    
    local names = {}
    local infos = {}
    
    for arg in args:gmatch('[^,]+') do
        arg = arg:gsub('^%s', ''):gsub('%s$', '')
        local name = arg:match('^%w+=')
        if name then
            value = arg:sub(#name+1, -1):gsub('^%s', '')
            name = name:sub(1, -2)

            table.insert(names, name)
            table.insert(infos, "{name='" .. name .. "', value=[[" .. value .. "]]}")
        else
            table.insert(names, arg)
            table.insert(infos, "{name='" .. arg .. "'}")
        end
    end

    return 
        '(' .. table.concat(names, ', ') .. ')',
        '{' .. table.concat(infos, ', ') .. '}'
end

function Wings.transpiler:split_line ()
    local before, capture, after
    if self.top.lua then
        if self.top.name == "lua-inline" then
            before, capture, after = self.line:match(self.patterns.capture_inline_lua)
        else
            before, capture, after = self.line:match(self.patterns.capture)
        end
    elseif self.top.name == "call" then
        before, capture, after = self.line:match(self.patterns.capture_call)
    else
        before, capture, after = self.line:match(self.patterns.capture)
    end
    return before, capture, after
end

-- Indentation
function Wings.transpiler:increment_indent ()
    self.indent = self.indent .. self.patterns.indent
end

function Wings.transpiler:decrement_indent ()
    self.indent = self.indent:gsub(self.patterns.indent .. '$', '')
end

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

function Wings.transpiler:write_functiondef_info (name, info)
    -- store function args names and defauts values
    table.insert(self.chunck, '\n'..self.indent..'wings.function_args_info[' .. name .. '] = ' .. info)
end

function Wings.transpiler:write_functioncall_init (stack_len)
    -- Create the table used to store function arguments
    table.insert(self.chunck, '\n' .. self.indent .. 'wings._args' .. stack_len .. ' = {}\n')
end

function Wings.transpiler:write_functioncall_final (s, stack_len, direct)
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

-- capture function modify the line
function Wings.transpiler:capture_functioncall_named_arg ()
    -- In the begining of an argument, check if it is a named argument.

    local name = self.line:match('^%s*%w+=')

    if name then
        self.line = self.line:sub(#name+1, -1)
    end

    return (name or ''):match('%w+')
end

function Wings.transpiler:capture_syntax_feature (capture)
    -- Handle Wings syntax.
    -- Return true is the line loop must be stop

    -- The command could be keyword, a commentary or an opening.
    local command
    if capture == self.patterns.escape then
        command = self.line:match ('^'  .. self.patterns.identifier)
               or self.line:match ('^'  .. self.patterns.comment)
               or self.line:match ('^%' .. self.patterns.open_call)

        self.line = self.line:sub(#command+1, -1)
    else
        command = capture
    end

    -- Manage call first
    if  (command == self.patterns.open_call or command == self.patterns.close_call)
        and
        (self.top.name == 'call' or self.top.name == "lua-inline") then

        self:handle_inside_call (command)

    elseif command == self.patterns.arg_separator and self.top.name == 'call' then
        -- Inside a call, push a new argument
        self:write_functioncall_arg_end ()
        self:decrement_indent ()
        local name = self:capture_functioncall_named_arg ()
        self:write_functioncall_arg_begin (name, #self.stack)
    
    elseif self.top.lua then
        -- this is lua code
        self:handle_lua_code (command)
    else
        -- this is wings code
        return self:handle_wings_code (command)
    end

    return false
end

function Wings.transpiler:handle_inside_call (command)

    -- check brace nested deep
    if command == self.patterns.open_call then
        self.top.deep = self.top.deep+1
    elseif command == self.patterns.close_call then
        self.top.deep = self.top.deep-1
    end

    -- This brace isn't closing the call
    if self.top.deep > 0 then
        
        if self.top.lua then
            self:write_lua (command)
        else
            self:write_text (command)
        end

    -- This is the end of call
    -- In case of begin sugar, we'll now capture next code.
    elseif self.top.name == 'call' then
        
        if self.top.is_begin_sugar then
            self:write_functioncall_arg_end ()
            self:write_functioncall_arg_begin (self.patterns.special_name_prefix.."body", #self.stack)
            
            table.remove(self.stack)
            table.insert(self.stack, {name="begin-sugar", macro=self.top.macro})
        else
            self:write_functioncall_arg_end ()
            self:write_functioncall_final (self.top.macro, #self.stack)

            table.remove(self.stack)
        end
    
    -- This is the end of a lua-inline chunck
    else
        table.remove(self.stack)
        self:decrement_indent ()

        if not self.top.declaration then
            self:write_lua (')')
        end
    end
end

function Wings.transpiler:handle_lua_code (command)
    -- We are inside lua code. The only keyword allowed are "do, then, end" and
    -- are closing.
    if command == "end" and self.top.name == "lua" then
        table.remove(self.stack)
        self:write_lua ('\n' .. self.indent .. '-- End raw lua code\n', true)

    elseif command == "end" and self.top.name == "function" then
        table.remove(self.stack)
        self:decrement_indent ()
        self:write_lua ('\n' .. self.indent .. 'end')

        -- save function arguments info
        self:write_functiondef_info (self.top.fname, self.top.args)

    elseif command == "do" and (self.top.name == "for" or self.top.name == "while") then
        table.remove(self.stack)
        table.insert(self.stack, {name="for"})
        self:write_lua ('do')
        self:increment_indent ()

    elseif command == "then" and (self.top.name == "if" or self.top.name == "elseif") then
        table.remove(self.stack)
        table.insert(self.stack, {name=self.top.name})
        self:write_lua ('then')
        self:increment_indent ()

    else
        self:write_lua (command)
    end
end

function Wings.transpiler:handle_wings_code (command)
    -- We are inside Wings code and no call to manage.
    -- Manage each of allowed keyword and macro/function call
    
    -- Open raw lua code chunck
    if command == "lua" then
        
        table.insert(self.stack, {lua=true, name="lua"})
        self:write_lua ('\n' .. self.indent .. '-- Begin raw lua code\n', true)

    -- New function
    elseif command == "function" or command == "macro" then
        self:handle_new_function (command == "macro")
        
    -- Open a lua chunck for iterator / condition
    elseif (command == "for" or command == "while") or command == "if" or command == "elseif" then
        table.insert(self.stack, {lua=true, name=command})
        self:write_lua ('\n'.. self.indent..command)

    -- Just write "else" to the output
    elseif command == "else" then
        self:decrement_indent()
        self:write_lua ('\n'.. self.indent..command)
        self:increment_indent()

    -- Close function/macro declaration, lua chunck or for/if/while structure
    elseif command == "end" then
        self:handle_end_keyword ()

   -- Enter lua-inline
    elseif command == self.patterns.open_call then 
        local declaration = self.line:match('^%s*local%s+%w+%s*=%s*') or self.line:match('^%s*%w+%s*=%s*')
        
        if declaration then
            self.line = self.line:sub(#declaration+1, -1)
            self:write_lua (declaration)
        else
            self:write_lua ('\n' .. self.indent .. 'wings:write (')
            self.pure_lua_line = false
        end
        
        table.insert(self.stack, {name="lua-inline", lua=true, deep=1, declaration=declaration})
        self:increment_indent ()

    -- It is a comment, do nothing and break line
    elseif command == self.patterns.comment then
        return true

    -- If the command it isn't a keyword, it is a macro call
    else
       self:handle_macro_call (command) 
    end
end

function Wings.transpiler:handle_new_function (ismacro)
    -- Declare a new function. If is not a macro, open a lua code chunck
    local space, name = self.line:match('^(%s*)('..self.patterns.identifier..')')
    self.line = self.line:sub((#space+#name)+1, -1)
    local args = self.line:match('^%b()')
    if args then
        self.line = self.line:sub(#args+1, -1)
    else
        args = "()"
    end

    local args_name, args_info = self:extract_args (args)

    self:write_lua ('\n' .. self.indent.. 'function ' .. name .. args_name )
    self:increment_indent ()

    if ismacro then
        self:write_lua ('\n' .. self.indent .. 'wings:push()')
        table.insert(self.stack, {name="macro", args=args_info, fname=name, line=self.noline})
    else
        table.insert(self.stack, {name="function", lua=true, args=args_info, fname=name, line=self.noline})
    end     
end

function Wings.transpiler:handle_end_keyword ()
    table.remove(self.stack)
    if self.top.name == 'macro' then
        self:write_lua ('\n' .. self.indent .. 'return wings:pop ()')
    end

    if self.top.name == "begin-sugar" then
        self:write_functioncall_arg_end ()
        self:write_functioncall_final (self.top.macro, #self.stack+1)
    else
        self:decrement_indent ()
        self:write_lua ('\n' .. self.indent .. 'end')
    end

    -- save macro arguments info
    if self.top.name == 'macro' then
        self:write_functiondef_info (self.top.fname, self.top.args)
    end
end

function Wings.transpiler:handle_macro_call (command)
    local is_begin_sugar
    if command == "begin" then
        is_begin_sugar = true
        self.line = self.line:gsub('^%s*', '')
        command = self.line:match('^' .. self.patterns.identifier)
        self.line = self.line:sub(#command+1, -1)
    end

    if not is_begin_sugar then
        self.pure_lua_line = false
    end

    if self.line:match('^%(%s*%)') and not is_begin_sugar then
        self.line = self.line:gsub('^%(%s*%)', '')
        self:write_functioncall_final (command, #self.stack, true)
    
    elseif self.line:match('^%' .. self.patterns.open_call) then
        self.line = self.line:sub(2, -1)
        
        table.insert(self.stack, {name="call", deep=1, is_begin_sugar=is_begin_sugar, macro=command})
        
        local name = self:capture_functioncall_named_arg ()
        self:write_functioncall_init (#self.stack) -- pass stack len to create a unique id 
        self:write_functioncall_arg_begin (name, #self.stack)

    -- Duplicate code with arg_separator check
    elseif is_begin_sugar then
        self:write_functioncall_init (#self.stack)
        self:write_functioncall_arg_begin (self.patterns.special_name_prefix.."body", #self.stack)

        table.insert(self.stack, {name="begin-sugar", macro=command})
    
    -- "command" must be a variable, so write it
    else
        self:write_variable (command)
    end
end