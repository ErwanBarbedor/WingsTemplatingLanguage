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

    local function writebeginarg (prefix)
        table.insert(chunck, '\n' .. indent .. (prefix or "") .. 'function()\n' .. indent .. '\tplume:push()')
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
            -- but can be open_call , closing_call or arg_separator if we are inside a function call
            if top.lua then
                if top.name == "lua-inline" then
                    before, capture, after = line:match(self.patterns.capture_inline_lua)
                else
                    before, capture, after = line:match(self.patterns.capture)
                end
            elseif top.name == "call" then
                before, capture, after = line:match(self.patterns.capture_call)
            else
                before, capture, after = line:match(self.patterns.capture)
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

                -- The command could be keyword, a commentary or an opening.
                local command
                if capture == self.patterns.escape then
                    command = line:match ('^'  .. self.patterns.identifier)
                           or line:match ('^'  .. self.patterns.comment)
                           or line:match ('^%' .. self.patterns.open_call)

                    line = line:sub(#command+1, -1)
                else
                    command = capture
                end

                -- Manage call first
                if (command == self.patterns.open_call or command == self.patterns.close_call)
                    and (top.name == 'call' or top.name == "lua-inline") then
                    if command == self.patterns.open_call then
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
                            writebeginarg ("['"..self.patterns.special_name_prefix.."body'] = ")
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
                elseif command == self.patterns.arg_separator and top.name == 'call' then
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
                        local space, name = line:match('^(%s*)('..self.patterns.identifier..')')
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
                        local space, name = line:match('^(%s*)(' .. self.patterns.identifier .. ')')
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

                    elseif command == self.patterns.open_call then
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

                    elseif command == self.patterns.comment then
                        break

                    else--call macro/function
                        
                        local is_struct
                        if command == "begin" then
                            is_struct = true
                            line = line:gsub('^%s*', '')
                            command = line:match('^' .. self.patterns.identifier)
                            line = line:sub(#command+1, -1)
                        end

                        if not is_struct then
                            pure_lua_line = false
                        end

                        if line:match('^%(%s*%)') then
                            line = line:gsub('^%(%s*%)', '')
                            writevariable(command)
                        
                        elseif line:match('^%' .. self.patterns.open_call) then
                            line = line:sub(2, -1)
                            writebeginfcall (command)
                            incindent ()
                            line = writenamedarg(line)
                            incindent ()

                            table.insert(stack, {name="call", deep=1, is_struct=is_struct})
                        
                        -- Rename is_struct to begin_sugar
                        -- Duplicate code with arg_separator check
                        elseif is_struct then
                            writebeginfcall (command)
                            incindent ()

                            writebeginarg ("['"..self.patterns.special_name_prefix.."body'] = ")
                            
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