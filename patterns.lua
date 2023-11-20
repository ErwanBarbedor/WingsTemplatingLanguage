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