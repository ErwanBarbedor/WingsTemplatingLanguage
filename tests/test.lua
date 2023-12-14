-- local function copy( t )
--     local ct = {}
--     for i,v in ipairs(t) do
--         ct[i] = t[i]
--     end
--     return ct
-- end


local function test(wings_path, test_path, simplelog, fullog)
    -- local testdir  = arg[1]
    -- local wingsdir = arg[1]:gsub('[^/]*$', '')
    local testdir   = test_path :gsub('[^/]*$', '')
    local wingsdir  = wings_path:gsub('[^/]*$', '')
    local wingsname = wings_path:match('[^/]*$'):gsub('%..-$', '') 
    package.path = package.path .. ";"..wingsdir.."?.lua"..";"..testdir.."/?.lua"
    
    local Wings = require (wingsname)

    local n_test   = 0
    local n_sucess = 0

    local log = simplelog or fullog

    local list = "base scope call controls "

    if jit then
        list = list .. " error-jit"
    elseif (_VERSION == "Lua 5.1" or _VERSION == "Lua 5.2") then
        list = list .. " error-51"
    elseif (_VERSION == "Lua 5.3" or _VERSION == "Lua 5.4") then
        list = list .. " error-53"
    end

    for testname in list:gmatch('%S+') do
        local tests = io.open(test_path .. "test-" .. testname .. ".wings"):read'*a'
        for test in tests:gmatch('#%-%- TEST : .-#%-%- END') do
            local wingscode = {}
            local result    = {}
            local name = test:match ('#%-%- TEST : ([^\n]*)')
            test = test:gsub('#%-%- TEST : [^\n]*\n', ''):gsub('#%-%- END', '')

            local in_code = true
            local check_error = false

            for line in test:gmatch('[^\n]*\n?') do
                if line == '#-- RESULT\n' then
                    in_code = false
                elseif line == '#-- ERROR\n' then
                    in_code = false
                    check_error = true
                elseif in_code then
                    table.insert(wingscode, line)
                else
                    table.insert(result, line)
                end
            end

            wingscode = table.concat(wingscode, "")
            result    = table.concat(result, "")

            local wings = Wings:new ()
            local sucess, output  = pcall(wings.render, wings, wingscode, test_path)
            local soutput
            if sucess then
                soutput = output:tostring()
            elseif check_error then
                soutput = output:gsub('^.-:.-:%s*', ''):gsub('\t','    ')..'\n'
            end

            n_test = n_test + 1
            if not sucess and not check_error then
                if fullog then
                    print('Test ' .. name .. ' failed with error:' .. output)
                end
            elseif soutput ~= result then
                if fullog then
                    print('Test ' .. testname .. ' > ' .. name .. ' failed. Obtain')
                    print('[[' .. soutput .. ']]')
                    print('Instead of')
                    print('[[' .. result .. ']]')
                end
            else
                n_sucess = n_sucess + 1
            end
        end
    end

    if log then
        print(n_sucess .. '/' .. n_test .. ' tests passed.')
    end

    return n_sucess == n_test
end

local optns = {}

local i = 1
while i <= #arg do

    if arg[i] == '--wings' or arg[i] == '--test' then
        optns[arg[i]:sub(3, -1)] = arg[i+1]
        i = i+1
    else
        optns[arg[i]:sub(3, -1)] = true
    end

    i = i + 1
end

if optns.run then
    test (optns.wings, optns.test, optns.log, optns.fullog)
end