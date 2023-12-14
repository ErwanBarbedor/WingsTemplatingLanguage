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
    elseif type(x) == "function" then
        local implicit_call = x
        table.insert(self.stack[#self.stack], implicit_call(self:make_args_list(x, {})))
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
    local info = self.function_info[f]

    if not info then
        return (unpack or table.unpack) (positional_args)
    end

    info = info.args

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