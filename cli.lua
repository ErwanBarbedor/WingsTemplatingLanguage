--[[
#VERSION
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

-- wings.lua -i test.plume -c plume
-- Suff for use wings as a cli app

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

-- Assume that, if the first arg is "wings.lua" or "wings", we are
-- directly called from the command line
local first_arg_name = arg[0]:match('[^/\\]*$')
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
			print(result:gsub('^.-file', 'file'))
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