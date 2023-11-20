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
        return self:call(x)
    end
end

function Plume:push ()
    table.insert(self.stack, self:TokenList ())
end

function Plume:pop ()
    return table.remove(self.stack)
end

function Plume:call (f, given_args)
    -- Manage positional and named arguments, but only for function declared inside plume.
    -- If not, all named arguments will be ignored.
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

            f( (unpack or table.unpack) (positional_args) )
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