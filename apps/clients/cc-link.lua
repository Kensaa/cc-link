local DEFAULT_URL = "$$URL$$"

local configFields = {
    url = 'string',
    fileIDs = 'table',
    root = 'string',
    entrypoint = 'string'
}

local wrongConfigMenu = {
    prompt = 'Your config file is invalid, please choose an action',
    options = {
        {
            name = 'Re-Run the setup script (will wipe current config)',
            action = setup
        },
        {
            name = 'Exit program and fix config manually',
            action = function() end
        }
    }

}

function connect(url, retry)
    retry = retry or 0
    if retry > 5 then
        print('Server is not reachable, shutting down.')
        os.shutdown()
    end
    local ws = http.websocket(url)
    if not ws then
        print('Unable to connect to server, retrying in 5 seconds')
        sleep(5)
        return connect(url, retry + 1)
    else
        print('Connected !')
        return ws
    end
end

function setup()
    term.clear()
    term.setCursorPos(1,1)
    print("Welcome to CC-link setup script !")
    print("Please note that this script will delete any startup.lua file already existing on this computer")
    print("Press Enter to continue")
    read()
    print("Please enter the ids of the files you want to sync")
    local fileIDs = stringToNumberArray(stringInput())
    print("Please enter the root directory of the files you want to sync, leave empty for the root directory of the computer")
    local root = removeEndSlash(stringInput(1)[1])
    print("Please enter the file you want to to be ran at startup, leave empty for auto-detection (startup.lua or the first lua file in the root directory)")
    local entrypoint = removeEndSlash(stringInput(1)[1])
    local config = {
        url = DEFAULT_URL,
        fileIDs = fileIDs,
        root = root,
        entrypoint = entrypoint
    }
    local configRaw = textutils.serializeJSON(config)
    fs.open('./cc-link.conf', 'w').write(configRaw)

    if not fs.exists(root) then
        fs.makeDir(root)
    end

    if(fs.exists('./startup.lua')) then
        fs.delete('./startup.lua')
    end
    shell.run('wget '..DEFAULT_URL..' startup.lua')
    os.reboot()
end

function sync(config)
    local ws = connect(httpToWsAddress(config['url']))
    ws.send(textutils.serializeJSON({
        type = 'register',
        fileIDs = config['fileIDs']
    }))

    local root = config['root']
    local entrypoint = config['entrypoint']

    if entrypoint == '' then
        local files = fs.list(root)
        -- if there is a startup_0.lua file, use it as entrypoint
        for i, file in ipairs(files) do
            if file == 'startup_0.lua' then
                entrypoint = file
                break
            else
                local fileExt = string.sub(file, -4)
                if fileExt == '.lua' then
                    if file ~= 'startup.lua' then
                        entrypoint = file
                        break
                    end
                end
            end
        end
    end

    if entrypoint == '' then
        print('No file suitable for entrypoint found, still waiting for updates')
    else
        local entrypointPath = root..'/'..entrypoint
        print('Starting entrypoint at '..entrypointPath)
        local tabID = shell.openTab(root..'/'..entrypoint)
        shell.switchTab(tabID)
        print("Entrypoint started")
    end
    
    
    print('waiting for updates...')
    while true do
        local responseString, isBinary = ws.receive()
        if not isBinary then
            local response = textutils.unserializeJSON(responseString)
            if response['type'] == 'fileUpdate' then
                print('Received update')
                local files = response['files']

                local lastUpdate = {}
                if(fs.exists('./cc-link.lastUpdate')) then
                    local lastUpdateString = fs.open('./cc-link.lastUpdate', 'r')
                    lastUpdate = textutils.unserializeJSON(lastUpdateString.readAll())
                end

                local fileUpdated = false
                for i, file in ipairs(files) do
                    local id = file['id']
                    local name = file['name']
                    local content = file['content']
                    local updatedAt = file['updatedAt']

                    if lastUpdate[id] ~= nil and lastUpdate[id] == updatedAt then
                        print('File '..name..' is already up to date')
                    else
                        print('Updating file '..name..'...')

                        if name == 'startup.lua' or name == 'startup' then
                            name = 'startup_0.lua'
                        end

                        local path = root..'/'..name

                        local fileHandle = fs.open(path, 'w')
                        for i,line in ipairs(splitLines(content)) do
                            fileHandle.writeLine(line)
                        end
                        fileHandle.close()
                        fileUpdated = true
                        lastUpdate[id] = updatedAt
                    end
                end
                print('Update finished')
                if fileUpdated then
                    local lastUpdateString = textutils.serializeJSON(lastUpdate)
                    fs.open('./cc-link.lastUpdate', 'w').write(lastUpdateString)
                    print('Rebooting...')
                    os.reboot()
                end
            end
        end
    end

end

function showMenu(menu)
    local prompt = menu['prompt']
    local options = menu['options']
    while true do
        print(prompt)
        for i, option in ipairs(options) do
            print(i .. '. ' .. option['name'])
        end
        local input = tonumber(read())
        if input == nil or input < 1 or input > #options then
            print('Invalid input, please try again')
        else
            term.clear()
            term.setCursorPos(1,1)
            local passed, returnValue = pcall(options[input]['action'])
            if not passed then
                print('An error has occured while executing action: ' .. returnValue)
            else 
                return returnValue
            end
        end
    end
end

function stringInput(count)
    local output = {}
    if count ~= nil then
        for i = 1, count do
            table.insert(output, read())
        end
    else
        while true do
            local input = read()
            if input == '' then
                break
            end
            table.insert(output, input)
        end
    end

    return output
end

function stringToNumberArray(arr)
    local output = {}
    for i, v in ipairs(arr) do
        local num = tonumber(v)
        if num ~= nil then
            table.insert(output, tonumber(v))
        end
    end
    return output
end

function removeEndSlash(string)
    if string.sub(string, -1) == '/' then
        return string.sub(string, 1, -2)
    else
        return string
    end
end

function httpToWsAddress(url)
    return 'ws'..string.sub(url, 5)
end

function splitLines(str)
    local lines = {}
    for s in string.gmatch(str,"[^\r\n]+") do
        table.insert(lines, s)
    end
    return lines
end



if fs.exists('./cc-link.conf') then
    local configRaw = fs.open('./cc-link.conf', 'r').readAll()
    local config = textutils.unserializeJSON(configRaw)

    local isConfigValid = true
    for k, v in pairs(configFields) do
        if config[k] == nil then
            print('Missing field ' .. k .. ' in config file')
            isConfigValid = false
        elseif type(config[k]) ~= v then
            print('Field ' .. k .. ' is not of type ' .. v)
            isConfigValid = false
        end
    end

    if isConfigValid then
        sync(config)
    else
        showMenu(wrongConfigMenu)
    end
else
    setup()
end
