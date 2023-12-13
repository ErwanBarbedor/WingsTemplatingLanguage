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
-- Handle all transpiler behaviors
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
    local args, spaces = self.line:match('^(%b())(%s*)')
    if args then
        self.line = self.line:sub(#args+#spaces+1, -1)
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
    
    -- "command" may be a variable, or an implicit function call
    else
        self:write_variable_or_function (command)
    end
end