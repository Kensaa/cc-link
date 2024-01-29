function removeEndSlash(string)
    if string.sub(string, -1) == '/' then
        return string.sub(string, 1, -2)
    else
        return string
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

local DEFAULT_URL = removeEndSlash("$$URL$$")

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
shell.run('wget '..DEFAULT_URL..'/client startup.lua')
os.reboot()

