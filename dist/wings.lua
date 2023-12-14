--[[
Wings v1.0.0-dev (build 2343)
Copyright (C) 2023  Erwan Barbedor

Check https://github.com/ErwanBarbedor/WingsTemplatingLanguage
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

local cli_help = [=[
Usage :
    WINGS -h --help
        Show this help
    WINGS -v --version
    	Show the wings version
    WINGS -i --input input [-o --output output] [-s --savelua path]
        input: file to handle
        output: if provided, save wings output in this location. If not, print the result.
        savelua: if provided, save transpiled code in given directory
]=]

local Wings = {}

Wings._VERSION = "Wings v1.0.0-dev (build 2343)"

Wings.config = {}
Wings.config.extensions = {'wings'}


Wings.utils = {}

function Wings.utils.copy (t)
    local nt = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            nt[k] = Wings.utils.copy (v)
        else
            nt[k] = v
        end
    end
    return nt
end

function Wings.utils.load (s, name, env)
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

function Wings.utils.convert_noline (filestack, line)
    local indent, filename, noline, message = line:match('^(%s*)([^:]*):([^:]*):(.*)')

    if not filename then
        return line
    end

    -- Assume that filename ending with @wings are wings files.
    if filename:match('@wings$') then
        local code
        for _, file in ipairs(filestack) do
            if file.filename == filename then
                code = file.luacode
                break
            end
        end

        -- "@wings" isn't part of the filename
        filename = filename:gsub('@wings$', '')
        -- Dont needed
        filename = filename:gsub('^%./', '')
        

        local noline_lua     = tonumber(noline)
        local error_line     = ""
        local noline_wings   = 0
        local noline_current = 0

        for line in code:gmatch('[^\n]*\n?') do
            noline_current = noline_current + 1

            if line:match '^%s*%-%- line [0-9]+ : ' then
                noline_wings, error_line = line:match '^%s*%-%- line ([0-9]+) : ([^\n]*)'
            end

            if noline_current >= noline_lua then
                break
            end
        end

        return indent .. 'file "' .. filename .. '", line ' .. noline_wings .. " (lua "..noline..") :" .. message
    else
        return line
    end
end

-- Predefined list of standard Lua variables/functions for various versions
Wings.utils.LUA_STD_FUNCTION = {
    ["5.1"]="_VERSION arg assert collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall",

    ["5.2"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type unpack xpcall xpcall",

    ["5.3"]="_VERSION arg assert bit32 collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall",

    ["5.4"]="_VERSION arg assert collectgarbage coroutine debug dofile error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 warn xpcall",

    jit="_VERSION arg assert bit collectgarbage coroutine debug dofile error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset require select setfenv setmetatable string table tonumber tostring type unpack xpcall"
}

Wings.transpiler = {}


-- Configuration for the transpiler.
-- Modifying these values is theoretically possible,
-- but has not yet been tested.

Wings.transpiler.patterns = {
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
    -- an wings identifier.
    special_name_prefix    = "!"
}

function Wings.transpiler:compile_patterns ()
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

function Wings.transpiler:write_functioncall_arg_end (isstruct)
    -- Closing args function
    table.insert(self.chunck, '\n' .. self.indent .. 'return wings:pop()')
    -- self:decrement_indent ()
    -- If closing a struct, do not call the function
    if isstruct then
        table.insert(self.chunck, '\n' .. self.indent .. 'end))')
    else
        table.insert(self.chunck, '\n' .. self.indent .. 'end)())')
    end
    self:increment_indent ()
end

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
    -- In case of begin struct, we'll now capture next code.
    elseif self.top.name == 'call' then
        
        if self.top.is_begin_struct then
            self:write_functioncall_arg_end ()
            self:write_functioncall_arg_begin (self.patterns.special_name_prefix.."body", #self.stack)
            
            table.remove(self.stack)
            table.insert(self.stack, {name="begin-struct", macro=self.top.macro})
        else
            self:write_functioncall_arg_end ()
            self:write_functioncall_end (self.top.macro, #self.stack)

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

    if self.top.name == "begin-struct" then
        self:write_functioncall_arg_end (true)
        self:write_functioncall_end (self.top.macro, #self.stack+1)
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
    local is_begin_struct
    if command == "begin" then
        is_begin_struct = true
        self.line = self.line:gsub('^%s*', '')
        command = self.line:match('^' .. self.patterns.identifier)
        self.line = self.line:sub(#command+1, -1)
    end

    if not is_begin_struct then
        self.pure_lua_line = false
    end

    if self.line:match('^%(%s*%)') and not is_begin_struct then
        self.line = self.line:gsub('^%(%s*%)', '')
        self:write_functioncall_end (command, #self.stack, true)
    
    elseif self.line:match('^%' .. self.patterns.open_call) then
        self.line = self.line:sub(2, -1)
        
        table.insert(self.stack, {name="call", deep=1, is_begin_struct=is_begin_struct, macro=command})
        
        local name = self:capture_functioncall_named_arg ()
        self:write_functioncall_begin (#self.stack) -- pass stack len to create a unique id 
        self:write_functioncall_arg_begin (name, #self.stack)

    -- Duplicate code with arg_separator check
    elseif is_begin_struct then
        self:write_functioncall_begin (#self.stack)
        self:write_functioncall_arg_begin (self.patterns.special_name_prefix.."body", #self.stack)

        table.insert(self.stack, {name="begin-struct", macro=command})
    
    -- "command" may be a variable, or an implicit function call
    else
        self:write_variable_or_function (command)
    end
end



-- Functions used by Wings in the final code to manage text flow and macro calls.

function Wings:write (x)
    -- Add a value to the output.
    if type(x) == "table" then
        if x.type == "WingsToken" then
            table.insert(self.stack[#self.stack], x)
        else
            for _, xx in ipairs(x) do
                self:write(xx)
            end
        end
    elseif type(x) == "string" or type(x) == "number" then
        table.insert(self.stack[#self.stack], self:Token(x))
    end
end

function Wings:push ()
    -- Adds a new TokenList to the stack.
    -- This TokenList will receive all output tokens from now.
    table.insert(self.stack, self:TokenList ())
end

function Wings:pop ()
    -- Removes a TokenList from the stack.
    -- It will either be written to the parent, or returned as the final value.
    -- (possibly after being passed to a function).
    return table.remove(self.stack)
end

function Wings:make_args_list (f, given_args)
    -- From a call with mixed positional and named arguments,
    -- make a lua-valid argument list.

    
    local given_args = given_args or {}
    
    -- sort positional/named
    local positional_args = {}
    local named_args = {}

    for _, v in ipairs(given_args) do
        table.insert(positional_args, v)
    end

    for k, v in pairs(given_args) do
        if not tonumber(k) then
            named_args[k] = v
        end
    end

    -- Check if we have informations about f.
    -- If not return the positional args
    local info = self.function_args_info[f]

    if not info then
        return (unpack or table.unpack) (positional_args)
    end

    local args = {}
    -- Handle begin struct
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

function Wings:format_error (err)
    -- Clean traceback from intern wings call
    -- Convert the line number from the internal lua file
    -- that is executed to the original wings file
    local err_msg   = err
    local traceback = debug.traceback()

    -- Remove 3 first line
    traceback = traceback:gsub('^[^\n]*\n[^\n]*\n[^\n]*\n', '')
    -- Make err the first line:
    traceback = err .. '\n' .. traceback
    -- Remove everything after the first 'xpcall' call
    traceback = traceback:gsub('%s*%[C%]: in function \'xpcall\'.-$', '')

    traceback = traceback:gsub('[^\n]*\n?', function (...)
        return self.utils.convert_noline (self.filestack, ...)
    end)

    return traceback
end

function Wings:filename ()
    local top = self.filestack[#self.filestack]
    if not top then
        error ("Not file running.")
    end
    return top.filename
end

function Wings:dirname ()
    local filename = self:filename ()
    return filename and filename:gsub('[^/]*$', '')
end

function Wings:TokenList ()
    local tl = {}
    tl.type = "WingsTokenList"

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
        assert(type(a) == 'number' or type(a) == 'table' and a.type == 'WingsTokenList')
        assert(type(b) == 'number' or type(b) == 'table' and b.type == 'WingsTokenList')
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

function Wings:Token (x)
    local tk = {}
    tk.content = x
    tk.type = "WingsToken"

    local mtk = {}
    

    setmetatable(tk, mtk)
    return tk
end
Wings.std = {}


-- All std functions will be included in wings.env at 
-- wings instance creation.

function Wings.std.import(wings, name)
    -- This function work like require :
    -- Search for a file named 'name.wings' and 'execute it'
    -- In the context of wings, the file will be rendered and added to the output
    -- Unlike require, result will not be cached
    local failed_path = {}
    local file, file_path

    -- name is a TokenList, so we need to convert it
    name = name:tostring()

    for _, path in ipairs(wings.package.path) do
        local path = path:gsub('?', name)
        file = io.open(path)
        if file then
            file_path = path
            file:close ()
            break
        else
            table.insert(failed_path, path)
        end
    end

    if not file then
        error ("wings file '" .. name .. "' not found:\n    no file " .. table.concat(failed_path, '\n    no file '))
    end

    local result = wings:renderFile(file_path)
    
    return result
end

function Wings.std.include (wings, name)
    -- include a file in the document, without execute it
    -- the path must be relative to the current file

    local path = wings:dirname () .. name:tostring ()

    local file = io.open(path)
    if not file then
        error("The file '" .. path .. "' doesn't exist.")
    end

    return file:read '*a'
end


function Wings:new ()
    -- Create Wings interpreter instance.
    -- Each instance has it's own environnement and configuration.

    local wings = Wings.utils.copy (Wings)

    -- Create a new environment
    wings.env = {
        wings=wings
    }

    -- Inherit from package.path
    wings.package = {}
    wings.package.path= {}
    for path in package.path:gmatch('[^;]+') do
        for _, ext in ipairs(wings.config.extensions) do
            local path = path:gsub('%.lua$', '.' .. ext)
            table.insert(wings.package.path, path)
        end
    end
    
    -- Stack used for managing nested constructs
    wings.stack = {}
    -- Track differents files rendered in the same instance
    wings.filestack = {}
    -- Activate/desactivate error handling by wings.
    wings.WINGS_ERROR_HANDLING = true
    -- Path to save transpiled code
    wings.SAVE_LUACODE_DIR = false
    
    -- Store function information
    wings.function_args_info = setmetatable({}, {__mode="k"})
    
    wings.type = "wings"
    wings.transpiler:compile_patterns ()

    -- Populate wings.env with lua and wings defaut functions
    local version
    if jit then
        version = "jit"
    else
        version = _VERSION:match('[0-9]%.[0-9]$')
    end

    for name in Wings.utils.LUA_STD_FUNCTION[version]:gmatch('%S+') do
        wings.env[name] = _G[name]
    end

    for name, f in pairs(Wings.std) do
        wings.env[name] = function (...) return f (wings, ...) end
    end

    return wings
end

function Wings:render(code, filename)

    -- Transpile the code, then execute it and return the result
    local luacode = self.transpiler:transpile (code)

    if filename then
        name = filename .. "@wings"
    else
        name = '<internal-'..#self.filestack..'>@wings'
    end

    table.insert(self.filestack, {filename=name, code=code, luacode=luacode})

    if self.SAVE_LUACODE_DIR then
        filename = (filename or name:gsub('[<>]', '_')):gsub('@wings$', ''):gsub('/', '___')
        local path = self.SAVE_LUACODE_DIR .. '/' .. filename .. '.lua'
        local file = io.open(path, "w")
        if file then
            file:write(luacode)
            file:close ()
        else
            error("Cannot write the file '" .. path .. "'")
        end
    end

    local f, err = self.utils.load (luacode, "@" .. name ,  self.env)
    if not f then
        if self.WINGS_ERROR_HANDLING then
            error(self:format_error (err), -1)
        else
            error(err)
        end
        
    end
    
    local sucess, result = xpcall(f, function(err)
        -- --To debug error handling...
        -- local sucess, result = pcall(self.format_error, self, err)
        -- if not sucess then
        --     print(result)
        -- end
        if self.WINGS_ERROR_HANDLING then
            return self:format_error (err)
        else
            return err
        end
    end)

    if not sucess then
        error(result)
    end

    result.luacode = luacode
    return result
end

function Wings:renderFile (path)
    -- Too automaticaly read the file and pass the name to render
    local file = io.open(path)

    if not file then
        error("The file '" .. path .. "' doesn't exist.")
    end

    return self:render(file:read"*a", path)
end



-- wings.lua -i test.plume -c plume
-- Suff for use wings as a cli app



-- Assume that, if the first arg is "wings.lua" or "wings", we are
-- directly called from the command line
local first_arg_name = arg[0]:match('[^/]*$')
if first_arg_name == 'wings.lua' or first_arg_name == 'wings' then

	local cli_parameters = {
		input=true,
		output=true,
		config=true,
		luacode=true,
		help=true,
		version=true
	}
	local cli_args = {}
	-- parse args
	local i = 0
	local err

	while i < #arg do
		i = i + 1
		local argname, argvalue
		if arg[i]:match('^%-%-') then
			argname = arg[i]:sub(3, -1)
			
		elseif arg[i]:match('^%-') then
			if #arg[i] > 2 then
				err = "Malformed argument '" .. arg[i] .. "'. Do yo mean '-" .. arg[i] .. "'?"
				break
			end

			for name, _ in pairs(cli_parameters) do
				if name:sub(1, 1) == arg[i]:sub(2, 2) then
					argname = name
					break
				end
			end

			argname = argname or arg[i]:sub(2, 2)
		else
			err = "Malformed argument '" .. arg[i] .. "'. Maybe parameter name is missing."
			break
		end

		if not cli_parameters[argname] then
			err = "Unknow parameter '" .. argname .. "'"
			break
		end

		if argname == 'help' or argname == 'version' then
			argvalue = ""
		else
			i = i + 1
			argvalue = arg[i]
		end

		if not argvalue or argvalue:match('^%-') then
			err = "No value for parameter '" .. argname .. "'"
			break
		end

		cli_args[argname] = argvalue
	end

	if err then
		print(err .. "\nUsage :" .. cli_help)
	end

	if cli_args.help then
		local help
		if first_arg_name == 'wings.lua' then
			help = cli_help:gsub('WINGS', 'lua wings.lua')
		else
			help = cli_help:gsub('WINGS', 'wings')
		end
		print(help)
	elseif cli_args.version then
		print(Wings._VERSION)
	elseif not cli_args.input then
		print("No input file provided")
	else
		wings = Wings:new ()
		wings.SAVE_LUACODE_DIR = cli_args.luacode
		local sucess, result = pcall (wings.renderFile, wings, cli_args.input)

		if not sucess then
			print(result)
			os.exit ()
		end

		result = result:tostring ()

		if cli_args.output then
			if #result > 0 then
				local file = io.open(cli_args.output, 'w')
				if file then
					file:write(result)
					file:close ()
				else
					error("Cannot write the file '" .. cli_args.output .. "'")
				end
			end
		else
			print(result)
		end
	end

end

return Wings