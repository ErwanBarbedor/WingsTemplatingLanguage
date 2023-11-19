local Plume = {}

-- Empty function used as a placeholder for compatibility
local function dummy () end

-- Predefined list of standard Lua variables/functions for various versions
-- These are intended to be provided as a part of sandbox environments to execute user code safely
-- Note that dofile and require arn't included
local LUA_STD = {
    ["5.1"]="_VERSION arg assert collectgarbage coroutine debug error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset select setfenv setmetatable string table tonumber tostring type unpack xpcall",

    ["5.2"]="_VERSION arg assert bit32 collectgarbage coroutine debug error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset select setmetatable string table tonumber tostring type unpack xpcall xpcall",

    ["5.3"]="_VERSION arg assert bit32 collectgarbage coroutine debug error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall",

    ["5.4"]="_VERSION arg assert collectgarbage coroutine debug error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset select setmetatable string table tonumber tostring type utf8 warn xpcall",

    jit="_VERSION arg assert bit collectgarbage coroutine debug error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset select setfenv setmetatable string table tonumber tostring type unpack xpcall"
}

Plume.patterns = {
    escape="#",
    indent="    "
}

function Plume:new ()
    local plume = {}

    for k, v in pairs(Plume) do
        plume[k] = v
    end

    -- Create a new empty environment
    plume.env = {plume=plume}

    -- Stack used for managing nested constructs in the templating language
    plume.stack = {}

    -- Weak table holding function argument information
    plume.function_args = setmetatable({}, {__mode="k"})

    local version
    if jit then
        version = "jit"
    else
        version = _VERSION:match('[0-9]%.[0-9]$')
    end

    -- Populate plume.env with lua defaut functions
    for name in LUA_STD[version]:gmatch('%S+') do
        plume.env[name] = _G[name]
    end

    return plume
end

function Plume:transpile (code)
    -- Define a method to transpile Plume code into Lua

    -- Table to hold code chuncks, one chunck by Plume line.
    local chuncks = {}
    -- Current chunck being processed
    local chunck  = {}
    -- Stack to manage code blocks and control structures
    local stack   = {{}}
    -- Track output indentation, for lisibility
    local indent  = ""
    local function incindent () indent = indent .. self.patterns.indent end
    local function decindent () indent = indent:gsub(self.patterns.indent .. '$', '') end

    local function writetext(s)
        if #s > 0 then
            table.insert(chunck, '\n'..indent .. "plume:write '" .. s:gsub("'", "\\'"):gsub('\n', '\\n'):gsub('\t', '\\t') .. "'")
        end
    end

    local function writelua(s, toindent)
        if toindent then
            s = indent .. s
        end
        table.insert(chunck, s)
    end

    local function writevariable(s)
        if #s > 0 then
            table.insert(chunck, '\n'..indent .. "plume:write (" .. s .. ")")
        end
    end

    local function writebeginfcall(s)
        table.insert(chunck, '\n' .. indent .. 'plume:call(' .. s .. ', {')
    end

    local function writeendfcall()
        table.insert(chunck, '\n' .. indent .. '})')
    end

    local function writenamedarg (line)
        local name = line:match('^%s*%w+=')
        if name then
            line = line:sub(#name+1, -1)
            table.insert(chunck, '\n' .. indent .. name .. 'function()')
            incindent ()
            table.insert(chunck, '\n' .. indent .. 'plume:push()')
            decindent ()
        else
            table.insert(chunck, '\n' .. indent .. 'function()')
            incindent ()
            table.insert(chunck, '\n' .. indent .. 'plume:push()')
            decindent ()
        end
        return line
    end

    local function writebeginarg ()
        table.insert(chunck, '\n' .. indent .. 'function()\n' .. indent .. '\tplume:push()')
    end

    local function writeendarg ()
        table.insert(chunck, '\n' .. indent .. 'return plume:pop()')
        decindent ()
        table.insert(chunck, '\n' .. indent .. 'end')
        incindent ()
    end

    local function extract_args(args)
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

    local noline = 0
    for line in code:gmatch('[^\n]*\n?') do
        chunck = {}
        noline = noline + 1

        local is_last_line = not line:match('\n$')

        -- Trim line if not inside lua code
        if not (stack[#stack] or {}).lua then
            line = line:gsub('^%s*', ''):gsub('%s*$', '')
        end

        -- write \n only if the line contain text
        line = line:gsub('\n$', '')
        local pure_lua_line = true

        local rawline = line
        while #line > 0 do
            local top = stack[#stack]
            local before, capture

            -- Detect the next signifiant token.
            -- In most of case it will be the escape token,
            -- but can be '(', ')' or ',' if we are inside a function call
            if top.lua then
                if top.name == "lua-inline" then
                    before, capture, after = line:match('(.-)([#%(%)])(.*)')
                else
                    before, capture, after = line:match('(.-)(#)(.*)')
                end
            elseif top.name == "call" then
                before, capture, after = line:match('(.-)([#,%(%)])(.*)')
            else
                before, capture, after = line:match('(.-)(#)(.*)')
            end

            -- Add texte before the signifiant token to the output
            -- If no token, add whole line
            if top.lua then
                writelua((before or line))
            elseif #(before or line)>0 then
                pure_lua_line = false
                writetext(before or line)
            end

            -- Manage signifiants tokens
            if capture then
                line = after

                -- The command could be keyword, a commentary or '('.
                local command
                if capture == '#' then
                    command = line:match '^%w+' or line:match '^%-%-' or line:match '^%('
                    line = line:sub(#command+1, -1)
                else
                    command = capture
                end

                -- Manage call first
                if (command == "(" or command == ')') and (top.name == 'call' or top.name == "lua-inline") then
                    if command == '(' then
                        top.deep = top.deep+1
                    else
                        top.deep = top.deep-1
                    end

                    if top.deep > 0 then
                        -- This brace isn't closing the call
                        if top.lua then
                            writelua(command)
                        else
                            writetext(command)
                        end
                    elseif top.name == 'call' then
                        -- This is the end of call
                        -- In case of struct, we'll now capture next code.
                        if top.is_struct then
                            writeendarg ()
                            decindent ()
                            writelua(',')
                            writebeginarg ()
                            incindent()
                            table.insert(stack, {name="struct"})
                        else
                            writeendarg ()
                            decindent ()
                            decindent ()
                            writeendfcall ()
                        end
                    else
                        -- This is the end of a lua-inline chunck
                        table.remove(stack)
                        decindent ()

                        if not top.declaration then
                            writelua(')')
                        end
                    end
                elseif command == ',' and top.name == 'call' then
                    -- Inside a call, push a new argument
                    writeendarg ()
                    decindent ()
                    writelua(',')
                    line = writenamedarg (line)
                    incindent()
                elseif top.lua then
                    -- We are inside lua code. The only keyword allowed are "do, then, end" and
                    -- are closing.
                    if command == "end" and top.name == "lua" then
                        table.remove(stack)
                        writelua('\n' .. indent .. '-- End raw lua code\n', true)

                    elseif command == "end" and top.name == "function" then
                        table.remove(stack)
                        decindent ()
                        writelua('\n' .. indent .. 'end')

                        writelua('\n' .. indent .. 
                                'plume.function_args[' .. top.fname .. '] = ' .. top.args)

                    elseif command == "do" and (top.name == "for" or top.name == "while") then
                        table.remove(stack)
                        table.insert(stack, {name="for"})
                        writelua('do')
                        incindent ()

                    elseif command == "then" and (top.name == "if" or top.name == "elseif") then
                        table.remove(stack)
                        table.insert(stack, {name=top.name})
                        writelua('then')
                        incindent ()

                    else
                        writelua(command)
                    end
                else
                    -- We are inside Plume code and no call to manage.
                    -- Manage each of allowed keyword and macro/function call
                    if command == "lua" then
                        -- Open raw lua code chunck
                        table.insert(stack, {lua=true, name="lua"})
                        writelua('\n' .. indent .. '-- Begin raw lua code\n', true)

                    elseif command == "function" then
                        -- Declare a new function and open a lua code chunck
                        local space, name = line:match('^(%s*)(%w+)')
                        line = line:sub((#space+#name)+1, -1)
                        local args = line:match('%b()')
                        if args then
                            line = line:sub(#args+1, -1)
                        else
                            args = "()"
                        end

                        local args_name, args_info = extract_args (args)

                        writelua('\n' .. indent.. 'function ' .. name .. ' ' .. args_name)
                        incindent ()

                        table.insert(stack, {name="function", lua=true, args=args_info, fname=name})

                    elseif command == "macro" then
                        -- Declare a new function
                        local space, name = line:match('^(%s*)(%w+)')
                        line = line:sub((#space+#name)+1, -1)
                        local args = line:match('^%b()')
                        if args then
                            line = line:sub(#args+1, -1)
                        else
                            args = "()"
                        end

                        local args_name, args_info = extract_args (args)

                        writelua('\n' .. indent.. 'function ' .. name .. ' ' .. args_name)
                        incindent ()
                        writelua('\n' .. indent .. 'plume:push()')
                        table.insert(stack, {name="macro", args=args_info, fname=name})
                        
                    elseif (command == "for" or command == "while") or command == "if" or command == "elseif" then
                        -- Open a lua chunck for iterator / condition
                        table.insert(stack, {lua=true, name=command})
                        writelua('\n'..indent..command)

                    elseif command == "else" then
                        decindent()
                        writelua('\n'..indent..command)
                        incindent()

                    elseif command == "end" then
                        table.remove(stack)
                        if top.name == 'macro' then
                            writelua('\n' .. indent .. 'return plume:pop ()')

                        end

                        if top.name == "struct" then
                            writeendarg ()
                            decindent ()
                            decindent ()
                            writeendfcall ()
                        else
                            decindent ()
                            writelua('\n' .. indent .. 'end')
                        end

                        if top.name == 'macro' then
                            writelua('\n' .. indent .. 
                                'plume.function_args[' .. top.fname .. '] = ' .. top.args)
                        end

                    elseif command == "(" then
                        -- Enter lua-inline
                        local declaration = line:match('^%s*local%s+%w+%s*=%s*') or line:match('^%s*%w+%s*=%s*')
                        
                        if declaration then
                            line = line:sub(#declaration+1, -1)
                            writelua(declaration)
                        else
                            writelua('\n' .. indent .. 'plume:write (')
                            pure_lua_line = false
                        end
                        
                        table.insert(stack, {name="lua-inline", lua=true, deep=1, declaration=declaration})
                        
                        incindent ()

                    elseif command == "--" then
                        break

                    else--call macro/function
                        
                        local is_struct
                        if command == "begin" then
                            is_struct = true
                            line = line:gsub('^%s*', '')
                            command = line:match('^%w+')
                            line = line:sub(#command+1, -1)
                        end

                        if not is_struct then
                            pure_lua_line = false
                        end

                        if line:match('^%(%s*%)') then
                            line = line:gsub('^%(%s*%)', '')
                            writevariable(command)
                        
                        elseif line:match('^%(') then
                            line = line:gsub('^%(', '')
                            writebeginfcall (command)
                            incindent ()
                            line = writenamedarg(line)
                            incindent ()

                            table.insert(stack, {name="call", deep=1, is_struct=is_struct})
                        
                        elseif is_struct then
                            writebeginfcall (command)
                            incindent ()
                            writebeginarg ()
                            incindent ()

                            table.insert(stack, {name="struct"})
                        
                        else
                            writevariable(command)
                        end
                    end
                end

            else
                break
            end
            
        end
        if (not pure_lua_line or keepspace ) and not is_last_line then
            writetext('\n')
        end

        local line = table.concat(chunck, "")
        if #rawline > 1 and rawline ~= line then
            if line:sub(1, 1) ~= "\n" then
                line = "\n" .. indent .. line
            end
            local firstindent = line:match('\n%s*')
            line = firstindent .. "-- Line " .. noline .. ' : ' .. rawline:gsub('^\t*', ''):gsub('\n', '') .. line .. '\n'

        end
        table.insert(chuncks, line)
    end

    return "plume:push ()\n\n" .. table.concat (chuncks, '') .. "\n\nreturn plume:pop ()"
end

function Plume:write (x)
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
        return self:call(x)
    end
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

function Plume:push ()
    table.insert(self.stack, self:TokenList ())
end

function Plume:pop ()
    return table.remove(self.stack)
end

function Plume:call (f, given_args)
    -- Manage positional and named arguments
    -- but only for function declared inside plume.
    -- If not, all named arguments will be put in a table
    -- and given as the last argument.
    local given_args = given_args or {}

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

    local info = self.function_args[f]

    if not info then
        self:write(
            f( (unpack or table.unpack) (positional_args), named_args)
        )
        return
    end

    local args = {}
    for i, arg_info in ipairs(info) do
        local value
        if arg_info.value then
            if named_args[arg_info.name] then
                value = named_args[arg_info.name]
            else
                value = self:render(arg_info.value)
            end
        else
            value = positional_args[i]
        end
        table.insert(args, value)
    end

    self:write(
        -- Compatibily for lua 5.1
        f( (unpack or table.unpack) (args))
    )
end

function Plume:render(code, optns)
    optns = optns or {}
    local luacode = self:transpile (code, optns.keepspace)

    if optns.saveluacode then
        local f = io.open(optns.saveluacode .. ".lua", 'w')
        f:write(luacode)
        f:close()
    end

    -- Compatibily for lua 5.1
    local f, err = (loadstring or load) (luacode, (optns.saveluacode or "plumecode"), 't', self.env)
    if not f then
        error(err)
    end

    -- Compatibily for lua 5.1
    (setfenv or dummy) (f, self.env)

    local sucess, result = pcall(f)
    if not sucess then
        error(result)
    end

    result.luacode = luacode
    return result
end

return Plume