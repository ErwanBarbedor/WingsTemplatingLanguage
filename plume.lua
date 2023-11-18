local plume = {}

local function dummy () end

-- Standard function to provide to the sandbox environnement.
local LUA_STD = {
	["5.1"]="_VERSION arg assert collectgarbage coroutine debug error gcinfo getfenv getmetatable io ipairs load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset select setfenv setmetatable string table tonumber tostring type unpack xpcall",

	["5.2"]="_VERSION arg assert bit32 collectgarbage coroutine debug error getmetatable io ipairs load loadfile loadstring math module next os package pairs pcall print rawequal rawget rawlen rawset select setmetatable string table tonumber tostring type unpack xpcall xpcall",

	["5.3"]="_VERSION arg assert bit32 collectgarbage coroutine debug error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset require select setmetatable string table tonumber tostring type utf8 xpcall",

	["5.4"]="_VERSION arg assert collectgarbage coroutine debug error getmetatable io ipairs load loadfile math next os package pairs pcall print rawequal rawget rawlen rawset select setmetatable string table tonumber tostring type utf8 warn xpcall",

	jit="_VERSION arg assert bit collectgarbage coroutine debug error gcinfo getfenv getmetatable io ipairs jit load loadfile loadstring math module newproxy next os package pairs pcall print rawequal rawget rawset select setfenv setmetatable string table tonumber tostring type unpack xpcall"
}

function plume:init ()
	plume.env = {}
	plume.env.plume = plume
	plume.stack = {}

	local version
	if jit then
		version = "jit"
	else
		version = _VERSION:match('[0-9]%.[0-9]$')
	end

	for name in LUA_STD[version]:gmatch('%S+') do
		plume.env[name] = _G[name]
	end
end

function plume:transpile (code, keepspace)
	local chuncks = {}
	local chunck  = {}
	local stack   = {{}}
	local acc     = {}
	local indent  = ""

	local function incindent ()
		indent = indent .. "\t"
	end
	local function decindent ()
		indent = indent:sub(2, -1)
	end

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
		table.insert(chunck, '\n' .. indent .. 'plume:write(' .. s .. '(')
	end

	local function writeendfcall()
		table.insert(chunck, '\n' .. indent .. '))')
	end

	local function writebeginarg ()
		table.insert(chunck, '\n' .. indent .. '(function()\n' .. indent .. '\tplume:push()')
	end

	local function writeendarg ()
		table.insert(chunck, '\n' .. indent .. 'return plume:pop()\n' .. indent:sub(1, -2) .. 'end)()')
	end

	local noline = 0
	for line in code:gmatch('[^\n]*\n?') do
		chunck = {}
		noline = noline + 1


		if not keepspace and not (stack[#stack] or {}).lua then
			line = line:gsub('^' .. indent, '')
		end

		-- write \n only if the line contain text
		line = line:gsub('\n$', '')
		local pure_lua_line = true

		local rawline = line
		while #line > 0 do
			local top = stack[#stack]
			local before, capture

			if top.lua then
				if top.name == "lua-inline" then
					before, capture, after = line:match('(.-)([#%(%)])(.*)')
				else
					before, capture, after = line:match('(.-)(#)(.*)')
				end
			elseif top.name == "call" then
				before, capture, after = line:match('(.-)([#,%(%)])(.*)')
			else
				-- before, capture, after = line:match('(.-)%s?\t*(#)(.*)')
				before, capture, after = line:match('(.-)(#)(.*)')
			end

			if top.lua then
				writelua((before or line))
			elseif #(before or line)>0 then
				pure_lua_line = false
				writetext(before or line)
			end

			if capture then
				line = after

				local command
				if capture == '#' then
					command = line:match '^%w+' or line:match '^%-%-' or line:match '^%('
					line = line:sub(#command+1, -1)
				else
					command = capture
				end

				if (command == "(" or command == ')') and (top.name == 'call' or top.name == "lua-inline") then
					if command == '(' then
						top.deep = top.deep+1
					else
						top.deep = top.deep-1
					end

					if top.deep > 0 then
						if top.lua then
							writelua(command)
						else
							writetext(command)
						end
					elseif top.name == 'call' then
						writeendarg ()
						decindent ()
						decindent ()
						writeendfcall ()
					else-- lua-inline
						table.remove(stack)
						decindent ()

						if not top.declaration then
							writelua(')')
						end
					end
				elseif command == ',' and top.name == 'call' then
					writeendarg ()
					decindent ()
					writelua(',')
					writebeginarg ()
					incindent()
				elseif top.lua then
					if command == "end" and top.name == "lua" then
						table.remove(stack)
						writelua('\n' .. indent .. '-- End raw lua code\n', true)

					elseif command == "end" and top.name == "function" then
						table.remove(stack)
						decindent ()
						writelua('\n' .. indent .. 'end')

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
					-- line = line:gsub('^%s', '')
					if command == "lua" then
						table.insert(stack, {lua=true, name="lua"})
						writelua('\n' .. indent .. '-- Begin raw lua code\n', true)

					elseif command == "function" then
						table.insert(stack, {name="function", lua=true})
						local space, name = line:match('^(%s*)(%w+)')
						line = line:sub((#space+#name)+1, -1)
						local args = line:match('%b()')
						if args then
							line = line:sub(#args+1, -1)
						else
							args = "()"
						end

						writelua('\n' .. indent.. 'function ' .. name .. ' ' .. args)
						incindent ()

					elseif command == "macro" then
						table.insert(stack, {name="macro"})
						local space, name = line:match('^(%s*)(%w+)')
						line = line:sub((#space+#name)+1, -1)
						local args = line:match('^%b()')
						if args then
							line = line:sub(#args+1, -1)
						else
							args = "()"
						end

						writelua('\n' .. indent.. 'function ' .. name .. ' ' .. args)
						incindent ()
						writelua('\n' .. indent .. 'plume:push()')
						
					elseif (command == "for" or command == "while") or command == "if" or command == "elseif" then
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
						decindent ()
						writelua('\n' .. indent .. 'end')

					elseif command == "(" then
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
						pure_lua_line = false
						if line:match('^%(%s*%)') then
							line = line:gsub('^%(%s*%)', '')
							writevariable(command)
						elseif line:match('^%(') then
							line = line:gsub('^%(', '')
							writebeginfcall (command)
							incindent ()
							writebeginarg ()
							incindent ()

							table.insert(stack, {name="call", deep=1})
						else
							writevariable(command)
						end
					end
				end

			else
				break
			end
			
		end
		if not pure_lua_line or keepspace then
			writetext('\n')
		end

		local line = table.concat(chunck, "")
		if #rawline > 1 and rawline ~= line then
			if line:sub(1, 1) ~= "\n" then
				line = "\n" .. indent .. line
			end
			local firstindent = line:match('\n\t*')
			line = firstindent .. "-- Line " .. noline .. ' : ' .. rawline:gsub('^\t*', ''):gsub('\n', '') .. line .. '\n'

		end
		table.insert(chuncks, line)
	end

	return "plume:push ()\n\n" .. table.concat (chuncks, '') .. "\n\nreturn plume:pop ()"
end

function plume:write (x)
	if type(x) == "table" then
		if x.type == "token" then
			table.insert(self.stack[#self.stack], x)
		else
			for _, xx in ipairs(x) do
				plume:write(xx)
			end
		end
	elseif type(x) == "string" or type(x) == "number" then
		table.insert(self.stack[#self.stack], self:Token(x))
	elseif type(x) == 'function' then
		return plume:write(x())
	end
end

function plume:TokenList ()
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
		local result = plume:TokenList ()

		if type(a) == "number" or type (a) == "string" then
			a = {plume:Token(a)}
		end
		if type(b) == "number" or type (b) == "string" then
			b = {plume:Token(b)}
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

function plume:Token (x)
	local tk = {}
	tk.content = x
	tk.type = "token"

	local mtk = {}
	

	setmetatable(tk, mtk)
	return tk
end

function plume:push ()
	table.insert(self.stack, self:TokenList ())
end

function plume:pop ()
	return table.remove(self.stack)
end

function plume:render(code, optns)
	optns = optns or {}
	local luacode = plume:transpile (code, optns.keepspace)

	if optns.saveluacode then
		local f = io.open(optns.saveluacode .. ".lua", 'w')
		f:write(luacode)
		f:close()
	end

	-- Compatibily for lua 5.1
	local f, err = (loadstring or load) (luacode, (optns.saveluacode or "plumecode"), 't', plume.env)
	if not f then
		error(err)
	end

	-- Compatibily for lua 5.1
	(setfenv or dummy) (f, plume.env)

	local sucess, result = pcall(f)
	if not sucess then
		error(result)
	end

	result.luacode = luacode
	return result
end

return plume