local function copy( t )
	local ct = {}
	for i,v in ipairs(t) do
		ct[i] = t[i]
	end
	return ct
end

local function string_diff (a, b)
	local deltas = {
		{a=1, b=1, insert=0, remove=0}
	}

	local open = 1
	while open > 0 do
		open = 0
		for _, delta in ipairs(deltas) do
			local new_deltas = {}
			if delta.a <= #a and delta.b <= #b then
				local ia = delta.a
				local ib = delta.b

				if a:sub(ia, ia) ~= b:sub(ib, ib) then
					local delta_rm = copy(delta)

					table.insert(delta, {"insert", b:sub(ib, ib)})

					delta.a = ia
					delta.b = ib+1
					delta.insert = delta.insert + 1

					table.insert(delta_rm, {"remove", a:sub(ib, ib)})
					delta_rm.a = ia+1
					delta_rm.b = ib
					delta_rm.remove = delta.remove + 1
					delta_rm.insert = delta.insert

					table.insert (new_deltas, delta)
					table.insert (new_deltas, delta_rm)
				else
					table.insert(delta, {"pass", b:sub(ib, ib)})

					delta.a = ia+1
					delta.b = ib+1
				end
				open = open + 1
			else
				table.insert (new_deltas, delta)
			end
		end
	end

	for _, delta in ipairs(deltas) do
		if delta.a <= #a and delta.b > #b then
			table.insert(delta, {"remove", a:sub(delta.a, -1)})
		elseif delta.a > #a and delta.b <= #b then 
			table.insert(delta, {"insert", b:sub(delta.b, -1)})
		end
	end

	local diff = deltas[1]

	for _, delta in ipairs(deltas) do
		if delta.remove + delta.insert < diff.insert + diff.remove then
			diff = delta
		end
	end

	return diff
end

local function print_diff (a, b)
	local diff = string_diff(a, b)

	local mode = 'pass'
	for _, v in ipairs(diff) do
		if v[1] == 'pass' then
			if mode ~= 'pass' then
				io.write('\27[0m')
			end
			io.write(v[2])
		elseif v[1] == 'remove' then
			if mode ~= 'remove' then
				io.write('\27[41m')
			end
			local v2 = v[2]:gsub('\n', '\\n\27[0m\n\27[41m'):gsub('\t', '\\t')
			io.write(v2)

		elseif v[1] == 'insert' then
			if mode ~= 'insert' then
				io.write('\27[42m')
			end
			local v2 = v[2]:gsub('\n', '\\n\27[0m\n\27[42m'):gsub('\t', '\\t\t')
			io.write(v2)
		end

		mode = v[1]
	end
	io.write '\27[0m\n'
end

package.path = package.path .. ";../?.lua"
local plume = require "plume"
local tests = io.open('test.plume'):read'*a'

local n_test   = 0
local n_sucess = 0


local show_error = (arg[1] == "show") or true

for test in tests:gmatch('#%-%- TEST : .-#%-%- END') do
	local plumecode = {}
	local result    = {}
	local name = test:match ('#%-%- TEST : ([^\n]*)')
	test = test:gsub('#%-%- TEST : [^\n]*\n', ''):gsub('#%-%- END', '')

	local in_code = true

	for line in test:gmatch('[^\n]*\n?') do
		if line == '#-- RESULT\n' then
			in_code = false
		elseif in_code then
			table.insert(plumecode, line)
		else
			table.insert(result, line)
		end
	end

	plumecode = table.concat(plumecode, "")
	result    = table.concat(result, "")

	plume:init ()
	local output  = plume:render(plumecode)
	local soutput = output:tostring()

	n_test = n_test + 1
	if soutput ~= result then
		if show_error then
			print('Test ' .. name .. ' failed :')
			print_diff (result, soutput)
		end
		-- print('---')
		-- print(output.luacode)
	else
		n_sucess = n_sucess + 1
	end
end

print(n_sucess .. '/' .. n_test .. ' tests passed.')