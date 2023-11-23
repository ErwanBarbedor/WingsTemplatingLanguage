--[[
LuaPlume v1.0.0-alpha-1700774383
Copyright (C) 2023  Erwan Barbedor

Check https://github.com/ErwanBarbedor/LuaPlume
for documentation, tutorial or to report issues.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

local Plume = {}

Plume._VERSION = "v1.0.0-alpha-1700774383"


Plume.utils = {}

function Plume.utils.copy (t)
    local nt = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            nt[k] = Plume.utils.copy (v)
        else
            nt[k] = v
        end
    end
    return nt
end

function Plume.utils.load (s, name, env)
    -- Load string in a specified env
    -- Working for all lua versions
    if not setfenv  then
        return load (s, name, "t", env)
    end
    
    local f, err = loadstring(s, name)
    if f and env then
        setfenv(f, env)
    end

    return f, err
end

function Plume.utils.friendly_error (code, err)
    local name = err:match('^[^:]*')
    err = err:sub(#name+2, -1)
    local noline_lua = err:match('^[^:]*')
    err = err:sub(#noline_lua+2, -1)
    noline_lua = tonumber (noline_lua)
    
    local error_line     = ""
    local noline_plume   = 0
    local noline_current = 0
    for line in code:gmatch('[^\n]*\n?') do
        noline_current = noline_current + 1

        if line:match '^%s*%-%- line [0-9]+ : ' then
            noline_plume, error_line = line:match '^%s*%-%- line ([0-9]+) : ([^\n]*)'
        end

        if noline_current >= noline_lua then
            break
        end
    end

    error('#VERSION: ' .. name .. ':' .. noline_plume .. ':' .. err)
end

-- Predefined list of standard Lua variables/functions for various versions
Plume.utils.LUA_STD_FUNCTION = {
    ["5.1"]="_VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall",

    ["5.2"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type unpack xpcall xpcall",

    ["5.3"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall",

    ["5.4"]="_VERSION arg assert collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 warn xpcall",

    jit="_VERSION arg assert bit collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall"
}

Plume.transpiler = {}


-- Configuration for the transpiler.
-- Modifying these values is theoretically possible,
-- but has not yet been tested.

Plume.transpiler.patterns = {
    -- Only for output lua lisibility
    indent                 = "    ",

    -- Macro, function and argument name format
    identifier             = "[%a_][%a_0-9]*",

    -- Edit this value may break lua code.
    lua_identifier         = "[%a_][%a_0-9]*",

    -- All theses token must be one string long,
    -- the transpiler assumes that is the case.
    escape                 = "#",
    open_call              = "(",
    close_call             = ")",
    arg_separator          = ",",
    comment                = "-",
    -- A prefix for make certain name invalid for
    -- an plume identifier.
    special_name_prefix    = "!"
}

function Plume.transpiler:compile_patterns ()
    -- capture, capture_call and capture_inline_lua divide the line in 3 parts.
    -- Before the token, token itself, after the token.

    -- standard capture, only the escape char
    self.patterns.capture          = '(.-)(%' .. self.patterns.escape .. ')(.*)'

    -- if we are inside a call, check for call end or new argument
    self.patterns.capture_call     = '(.-)(['
        .. '%' .. self.patterns.escape
        .. '%' .. self.patterns.open_call
        .. '%' .. self.patterns.close_call
        .. '%' .. self.patterns.arg_separator .. '])(.*)'

    -- if we are inside lua, check only for closing.
    self.patterns.capture_inline_lua = '(.-)(['
        .. '%' .. self.patterns.open_call
        .. '%' .. self.patterns.close_call .. '])(.*)'
end


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
            self.line = firstindent .. "-- line " .. self.noline .. ' : ' .. rawline:gsub('^\t*', ''):gsub('\n', '') .. self.line .. '\n'
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

-- All 'write' functions don't modify the line 
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
    -- write the begin of a function call : give the function name,
    -- open a table brace for containing incomings arguments.
    table.insert(self.chunck, '\n' .. self.indent .. 'plume:write(' .. s .. ' {')
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

        self:handle_inside_call (command)

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

function Plume.transpiler:handle_inside_call (command)

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
            self:decrement_indent ()
            self:write_lua (',')
            self:write_functioncall_arg_begin ("['"..self.patterns.special_name_prefix.."body'] = ")
            table.insert(self.stack, {name="begin-sugar"})
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
            self:write_lua ('\n' .. self.indent .. 'plume:write (')
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

function Plume.transpiler:handle_new_function (ismacro)
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

    self:write_lua ('\n' .. self.indent.. 'function ' .. name .. ' (args)')
    self:increment_indent ()

    -- Support positional args
    if args_name:match('^%(%s*%)$') then
        self:write_lua ('\n' .. self.indent .. 'args = nil')
    else
        -- Dont polluate environnement with a new variable "args"
        self:write_lua ('\n' .. self.indent .. 'plume._args = args')
        self:write_lua ('\n' .. self.indent .. 'args = nil')

        self:write_lua ('\n' .. self.indent
                        .. 'local ' .. args_name:sub(2, -2)
                        .. ' = plume:make_args_list (plume._args, ' .. args_info ..')')
        self:write_lua ('\n' .. self.indent .. 'plume._args = nil')
    end

    if ismacro then
        self:write_lua ('\n' .. self.indent .. 'plume:push()')
        table.insert(self.stack, {name="macro", args=args_info, fname=name, line=self.noline})
    else
        table.insert(self.stack, {name="function", lua=true, args=args_info, fname=name, line=self.noline})
    end     
end

function Plume.transpiler:handle_end_keyword ()
    table.remove(self.stack)
    if self.top.name == 'macro' then
        self:write_lua ('\n' .. self.indent .. 'return plume:pop ()')
    end

    if self.top.name == "begin-sugar" then
        self:write_functioncall_arg_end ()
        self:decrement_indent ()
        self:write_functioncall_end ()
    else
        self:decrement_indent ()
        self:write_lua ('\n' .. self.indent .. 'end')
    end
end

function Plume.transpiler:handle_macro_call (command)
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

    if self.line:match('^%(%s*%)') then
        self.line = self.line:gsub('^%(%s*%)', '')
        self:write_variable (command)
    
    elseif self.line:match('^%' .. self.patterns.open_call) then
        self.line = self.line:sub(2, -1)
        self:write_functioncall_begin (command)
        
        local name = self:capture_functioncall_named_arg ()
        self:write_functioncall_arg_begin (name)

        table.insert(self.stack, {name="call", deep=1, is_begin_sugar=is_begin_sugar})
    
    -- Duplicate code with arg_separator check
    elseif is_begin_sugar then
        self:write_functioncall_begin (command)
        self:write_functioncall_arg_begin ("['"..self.patterns.special_name_prefix.."body'] = ")
        self:increment_indent ()

        table.insert(self.stack, {name="begin-sugar"})
    
    else
        self:write_variable (command)
    end
end


-- Functions used by Plume in the final code to manage text flow and macro calls.

function Plume:write (x)
    -- Add a value to the output.
    if type(x) == "table" then
        if x.type == "token" then
            table.insert(self.stack[#self.stack], x)
        else
            for _, xx in ipairs(x) do
                self:write(xx)
            end
        end
    elseif type(x) == "string" or type(x) == "number" then
        table.insert(self.stack[#self.stack], self:Token(x))
    elseif type(x) == 'function' then
       self:write(x())
    end
end

function Plume:push ()
    -- Adds a new TokenList to the stack.
    -- This TokenList will receive all output tokens from now.
    table.insert(self.stack, self:TokenList ())
end

function Plume:pop ()
    -- Removes a TokenList from the stack.
    -- It will either be written to the parent, or returned as the final value.
    -- (possibly after being passed to a function).
    return table.remove(self.stack)
end

function Plume:make_args_list (given_args, info)
    -- From a call with mixed positional and named arguments,
    -- make a lua-valid argument list.
    -- If not "info", return the positional args

    local given_args = given_args or {}
    
    -- sort positional/named
    local positional_args = {}
    local named_args = {}

    for _, v in ipairs(given_args) do
        table.insert(positional_args, v())
    end

    for k, v in pairs(given_args) do
        if not tonumber(k) then
            named_args[k] = v()
        end
    end

    if not info then
        return (unpack or table.unpack) (positional_args)
    end

    local args = {}
    -- Handle begin sugar
    -- Warning : using transpiler config after the transpilation,
    -- so a config change may break the code.
    local body = named_args[self.transpiler.patterns.special_name_prefix .. 'body']
    if body then
        table.insert(args, body)
    end

    -- First set named argument
    for name, value in pairs(named_args) do
        for i, arg_info in ipairs(info) do
            if arg_info.name == name then
                args[i] = value
            end
        end
    end

    -- Then fill the gap with positional arguments
    local first_empy = 1
    for _, value in pairs(positional_args) do

        while first_empy <= #info do
            if not args[first_empy] then
                args[first_empy] = value
                break
            end
            first_empy = first_empy + 1
            
        end
    end

    -- Finally, the remaining arguments that have a default value get it
    for i, arg_info in ipairs(info) do
        if arg_info.value and not args[i] then
            args[i] = self:render(arg_info.value)
        end
    end

    return (unpack or table.unpack) (args, 1, #info)
end

function Plume:TokenList ()
    local tl = {}
    tl.type = "tokenlist"

    function tl:tostring ()
        local result = {}
        for _, token in ipairs(self) do
            table.insert(result, token.content or "")
        end
        return table.concat(result, "")
    end

    function tl:tonumber ()
        return tonumber(self:tostring())
    end

    local mtl = {}
    function mtl.__concat (a, b)
        local result = self:TokenList ()

        if type(a) == "number" or type (a) == "string" then
            a = {self:Token(a)}
        end
        if type(b) == "number" or type (b) == "string" then
            b = {self:Token(b)}
        end
        
        for k, v in ipairs (a) do
            table.insert(result, v)
        end

        for k, v in ipairs (b) do
            table.insert(result, v)
        end

        return result
    end

    local function checknumber (a, b)
        assert(type(a) == 'number' or type(a) == 'table' and a.type == 'tokenlist')
        assert(type(b) == 'number' or type(b) == 'table' and b.type == 'tokenlist')
        if type(a) ~= 'number' then
            a = a:tonumber ()
            assert(a)
        end
        if type(b) ~= 'number' then
            b = b:tonumber ()
            assert(b)
        end
        return a, b
    end

    function mtl.__add (a, b)
        a, b = checknumber(a, b)
        return a+b
    end

    function mtl.__mul (a, b)
        a, b = checknumber(a, b)
        return a*b
    end

    function mtl.__sub (a, b)
        a, b = checknumber(a, b)
        return a-b
    end

    function mtl.__div (a, b)
        a, b = checknumber(a, b)
        return a/b
    end

    setmetatable(tl, mtl)
    return tl
end

function Plume:Token (x)
    local tk = {}
    tk.content = x
    tk.type = "token"

    local mtk = {}
    

    setmetatable(tk, mtk)
    return tk
end
Plume.std = {}


-- All std functions will be included in plume.env at 
-- plume instance creation.

function Plume.std.include(plume, args)
    -- This function work like require :
    -- Search for a file named 'name.plume' and 'execute it'
    -- In the context of plume, the file will be rendered and added to the output
    -- Unlike require, result will not be cached
    local failed_path = {}
    local file

    local name = plume:make_args_list(args)

    -- name is a TokenList, so we need to convert it
    name = name:tostring()

    for path in plume.path:gmatch('[^;]+') do
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
    local result    = plume:render(plumecode)
    
    return result
end


function Plume:new ()
    -- Create Plume interpreter instance.
    -- Each instance has it's own environnement and configuration.

    local plume = Plume.utils.copy (Plume)

    -- Create a new environment
    plume.env = {
        plume=plume
    }

    -- Inherit from package.path
    plume.path=package.path:gsub('%.lua', '.plume')

    -- Stack used for managing nested constructs in the templating language
    plume.stack = {}

    plume.type = "plume"

    plume.transpiler:compile_patterns ()

    -- Populate plume.env with lua and plume defaut functions
    local version
    if jit then
        version = "jit"
    else
        version = _VERSION:match('[0-9]%.[0-9]$')
    end

    for name in Plume.utils.LUA_STD_FUNCTION[version]:gmatch('%S+') do
        plume.env[name] = _G[name]
    end

    for name, f in pairs(Plume.std) do
        plume.env[name] = function (...) return f (plume, ...) end
    end

    return plume
end

function Plume:render(code, name)
    -- Transpile the code, then execute it and return the result

    local luacode = self.transpiler:transpile (code)

    local f, err = self.utils.load (luacode, "@" .. (name or "main") .. ".plume",  self.env)
    if not f then
        error(err)
    end

    local sucess, result = pcall(f)
    if not sucess then
        self.utils.friendly_error (luacode, result)
    end

    result.luacode = luacode
    return result
end

return Plume