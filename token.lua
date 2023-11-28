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
function Wings:TokenList ()
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

function Wings:Token (x)
    local tk = {}
    tk.content = x
    tk.type = "token"

    local mtk = {}
    

    setmetatable(tk, mtk)
    return tk
end