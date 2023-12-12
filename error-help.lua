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

-- For certains errors, give hint to new users

Wings.utils.ERROR_HELP = {
	["attempt to call a nil value %(.- '([%w_]+)'%)"] = function (m)
		print('Hints:')
		print('\t- Check if "' .. m .. '" is spelled correctly.')
		print('\t- If "' .. m .. '" is part of an external code, check if you have loaded the required library with "import" or "require".')
		print('\t- Else, make sure you have defined "' .. m .. '" as macro or a function.')
	end
}