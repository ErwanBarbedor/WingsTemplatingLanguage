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

function Plume.transpiler:check_lua_identifier ()
end

function Plume.transpiler:transpile (code)
    -- Define a method to transpile Plume code into Lua

    -- Table to hold code chuncks, one chunck by Plume line.
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
        self.line = self.line:gsub('\n$', '')
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
            self.line = firstindent .. "-- self.line " .. self.noline .. ' : ' .. rawline:gsub('^\t*', ''):gsub('\n', '') .. self.line .. '\n'
        end

        table.insert(self.chuncks, self.line)
    end

    return "plume:push ()\n\n" .. table.concat (self.chuncks, '') .. "\n\nreturn plume:pop ()"
end

-- All these auxiliary functions may not be calling outside Plume.transpiler.transpile

-- Utils
function Plume.transpiler:escape_string (s)
    -- Make a valid lua string
    return "'" .. s:gsub("'", "\\'")
                   :gsub("\n", "\\n") .. "'"
end

function Plume.transpiler:extract_args (args)
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

function Plume.transpiler:split_line ()
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
function Plume.transpiler:increment_indent ()
    self.indent = self.indent .. self.patterns.indent
end

function Plume.transpiler:decrement_indent ()
    self.indent = self.indent:gsub(self.patterns.indent .. '$', '')
end

-- All 'write' functions don't modify the self.line 
function Plume.transpiler:write_text (s)
    -- Handle text that may be added to the output by Plume
    if #s > 0 then
        table.insert(
            self.chunck, 
            '\n'.. self.indent
                .. "plume:write "
                .. self:escape_string (s)
        )
    end
end

function Plume.transpiler:write_lua (s, toindent)
    -- Handle text that are raw lua code
    if toindent then
        s = self.indent .. s
    end
    table.insert(self.chunck, s)
end

function Plume.transpiler:write_variable(s)
    -- Handle variable that may be added to the output by Plume
    if #s > 0 then
        table.insert(self.chunck, '\n'.. self.indent .. "plume:write (" .. s .. ")")
    end
end

-- Manage function call
function Plume.transpiler:write_functioncall_begin (s)
    -- write the begin of a function call : 'plume:call', give the function name,
    -- open a table brace for containing incomings arguments.
    table.insert(self.chunck, '\n' .. self.indent .. 'plume:call(' .. s .. ', {')
    self:increment_indent ()
end

function Plume.transpiler:write_functioncall_end ()
    -- write the end of a function call : closing braces
    self:decrement_indent ()
    table.insert(self.chunck, '\n' .. self.indent .. '})')
end

function Plume.transpiler:write_functioncall_arg_begin (name)
    -- write the begining of a argument : a function to encompass the argument body.
    -- name must be a valid lua key following by a '='
    table.insert(self.chunck, '\n' .. self.indent .. (name or '') .. 'function()')
    self:increment_indent ()
    table.insert(self.chunck, '\n' .. self.indent .. 'plume:push()')
end

function Plume.transpiler:write_functioncall_arg_end ()
    -- Closing args function
    table.insert(self.chunck, '\n' .. self.indent .. 'return plume:pop()')
    self:decrement_indent ()
    table.insert(self.chunck, '\n' .. self.indent .. 'end')
    self:increment_indent ()
end

-- capture function modify the line
function Plume.transpiler:capture_functioncall_named_arg ()
    -- In the begining of an argument, check if it is a named argument.

    local name = self.line:match('^%s*%w+=')

    if name then
        self.line = self.line:sub(#name+1, -1)
    end

    return name
end

function Plume.transpiler:capture_syntax_feature (capture)
    -- Handle Plume syntax.
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

        self:handle_call (command)

    elseif command == self.patterns.arg_separator and self.top.name == 'call' then
        -- Inside a call, push a new argument
        self:write_functioncall_arg_end ()
        self:decrement_indent ()
        self:write_lua (',')
        local name = self:capture_functioncall_named_arg ()
        self:write_functioncall_arg_begin (name)
    
    elseif self.top.lua then
        -- this is lua code
        self:handle_lua_code (command)
    else
        -- this is plume code
        self:handle_plume_code (command)
    end

    return false
end

function Plume.transpiler:handle_call (command)

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
        
        if self.top.is_struct then
            self:write_functioncall_arg_end ()
            self:decrement_indent ()
            self:write_lua (',')
            self:write_functioncall_arg_begin ("['"..self.patterns.special_name_prefix.."body'] = ")
            table.insert(self.stack, {name="struct"})
        else
            self:write_functioncall_arg_end ()
            self:decrement_indent ()
            
            self:write_functioncall_end ()
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

function Plume.transpiler:handle_lua_code (command)
    -- We are inside lua code. The only keyword allowed are "do, then, end" and
    -- are closing.
    if command == "end" and self.top.name == "lua" then
        table.remove(self.stack)
        self:write_lua ('\n' .. self.indent .. '-- End raw lua code\n', true)

    elseif command == "end" and self.top.name == "function" then
        table.remove(self.stack)
        self:decrement_indent ()
        self:write_lua ('\n' .. self.indent .. 'end')

        self:write_lua ('\n' .. self.indent .. 
                'plume.function_args[' .. self.top.fname .. '] = ' .. self.top.args)

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

function Plume.transpiler:handle_plume_code (command)
    -- We are inside Plume code and no call to manage.
    -- Manage each of allowed keyword and macro/function call
    if command == "lua" then
        -- Open raw lua code self.chunck
        table.insert(self.stack, {lua=true, name="lua"})
        self:write_lua ('\n' .. self.indent .. '-- Begin raw lua code\n', true)

    elseif command == "function" then
        -- Declare a new function and open a lua code self.chunck
        local space, name = self.line:match('^(%s*)('..self.patterns.identifier..')')
        self.line = self.line:sub((#space+#name)+1, -1)
        local args = self.line:match('%b()')
        if args then
            self.line = self.line:sub(#args+1, -1)
        else
            args = "()"
        end

        local args_name, args_info = self:extract_args (args)

        self:write_lua ('\n' .. self.indent.. 'function ' .. name .. ' ' .. args_name)
        self:increment_indent ()

        table.insert(self.stack, {name="function", lua=true, args=args_info, fname=name})

    elseif command == "macro" then
        -- Declare a new function
        local space, name = self.line:match('^(%s*)(' .. self.patterns.identifier .. ')')
        self.line = self.line:sub((#space+#name)+1, -1)
        local args = self.line:match('^%b()')
        if args then
            self.line = self.line:sub(#args+1, -1)
        else
            args = "()"
        end

        local args_name, args_info = self:extract_args (args)

        self:write_lua ('\n' .. self.indent.. 'function ' .. name .. ' ' .. args_name)
        self:increment_indent ()
        self:write_lua ('\n' .. self.indent .. 'plume:push()')
        table.insert(self.stack, {name="macro", args=args_info, fname=name})
        
    elseif (command == "for" or command == "while") or command == "if" or command == "elseif" then
        -- Open a lua self.chunck for iterator / condition
        table.insert(self.stack, {lua=true, name=command})
        self:write_lua ('\n'.. self.indent..command)

    elseif command == "else" then
        self:decrement_indent()
        self:write_lua ('\n'.. self.indent..command)
        self:increment_indent()

    elseif command == "end" then
        table.remove(self.stack)
        if self.top.name == 'macro' then
            self:write_lua ('\n' .. self.indent .. 'return plume:pop ()')

        end

        if self.top.name == "struct" then
            self:write_functioncall_arg_end ()
            self:decrement_indent ()
            self:write_functioncall_end ()
        else
            self:decrement_indent ()
            self:write_lua ('\n' .. self.indent .. 'end')
        end

        if self.top.name == 'macro' then
            self:write_lua ('\n' .. self.indent .. 
                'plume.function_args[' .. self.top.fname .. '] = ' .. self.top.args)
        end

    elseif command == self.patterns.open_call then
        -- Enter lua-inline
        local declaration = self.line:match('^%s*local%s+%w+%s*=%s*') or self.line:match('^%s*%w+%s*=%s*')
        
        if declaration then
            self.line = self.line:sub(#declaration+1, -1)
            self:write_lua (declaration)
        else
            self:write_lua ('\n' .. self.indent .. 'plume:write (')
            self.pure_lua_line = false
        end
        
        table.insert(self.stack, {name="lua-inline", lua=true, deep=1, declaration=declaration})
        
        self:increment_indent ()

    elseif command == self.patterns.comment then
        return true

    else--call macro/function
        
        local is_struct
        if command == "begin" then
            is_struct = true
            self.line = self.line:gsub('^%s*', '')
            command = self.line:match('^' .. self.patterns.identifier)
            self.line = self.line:sub(#command+1, -1)
        end

        if not is_struct then
            self.pure_lua_line = false
        end

        if self.line:match('^%(%s*%)') then
            self.line = self.line:gsub('^%(%s*%)', '')
            self:write_variable (command)
        
        elseif self.line:match('^%' .. self.patterns.open_call) then
            self.line = self.line:sub(2, -1)
            self:write_functioncall_begin (command)
            
            local name = self:capture_functioncall_named_arg ()
            self:write_functioncall_arg_begin (name)

            table.insert(self.stack, {name="call", deep=1, is_struct=is_struct})
        
        -- Rename is_struct to begin_sugar
        -- Duplicate code with arg_separator check
        elseif is_struct then
            self:write_functioncall_begin (command)

            self:write_functioncall_arg_begin ("['"..self.patterns.special_name_prefix.."body'] = ")
            
            self:increment_indent ()

            table.insert(self.stack, {name="struct"})
        
        else
            self:write_variable (command)
        end
    end
end