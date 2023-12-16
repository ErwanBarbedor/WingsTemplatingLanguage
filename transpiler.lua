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

    return "local context = wings.context\nwings:push ()\n\n" .. table.concat (self.chuncks, '') .. "\n\nreturn wings:pop ()"
end

-- All these auxiliary functions may not be calling outside Wings.transpiler.transpile

-- Utils
function Wings.transpiler:escape_string (s)
    -- Make a valid lua string
    return "'" .. s:gsub("\\", "\\\\")
                    :gsub("'", "\\'")
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
function Wings.transpiler:capture_macrocall_named_arg ()
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
        self:write_macrocall_arg_end ()
        self:decrement_indent ()
        local name = self:capture_macrocall_named_arg ()
        self:write_macrocall_arg_begin (name, #self.stack)
    
    elseif self.top.lua then
        -- this is lua code
        self:handle_lua_code (command)
    else
        -- this is wings code
        return self:handle_wings_code (command)
    end

    return false
end