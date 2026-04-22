-- Blackbird Klog Shell v1.0.0
-- Custom shell for krawlet.cc klog-cli with .move and .transfur support

local ver = "1.0.0"
local apiUri = "https://api.krawlet.cc/v1/"
local updateDomain = "https://krawlet.cc/"

-- Store real filesystem functions before VM overrides
local realFs = _G.oldfs or fs
if not realFs.exists then
    realFs = {}
    for k, v in pairs(fs) do
        realFs[k] = v
    end
end

-- Store real peripheral functions before VM overrides
local realPeripheral = _G.getRealPeripheral and _G.getRealPeripheral() or _G.oldperipheral or peripheral
if not realPeripheral.find then
    realPeripheral = {}
    for k, v in pairs(peripheral) do
        realPeripheral[k] = v
    end
end

-- Debug: print what we have
term.setTextColor(colors.yellow)
print("Checking /lib/klog.lua...")
print("realFs.list(\"/\"):")
for _, v in ipairs(realFs.list("/")) do
    print("  " .. v)
end
term.setTextColor(colors.white)
if realFs.exists("/lib/klog.lua") then
    term.setTextColor(colors.green)
    print("/lib/klog.lua exists")
    term.setTextColor(colors.white)
    -- Show first line
    local f = realFs.open("/lib/klog.lua", "r")
    if f then
        print("First line: " .. f.readLine())
        f.close()
    end
else
    term.setTextColor(colors.red)
    print("/lib/klog.lua missing - downloading...")
    term.setTextColor(colors.white)
    term.setTextColor(colors.orange)
    print("Testing http...")
    term.setTextColor(colors.white)
    local resp = http.get(updateDomain .. "klog.lua")
    if resp then
        term.setTextColor(colors.green)
        print("http works! Content length: " .. #resp.readAll())
        resp.close()
        term.setTextColor(colors.white)
        downloadFile(updateDomain .. "klog.lua", "/lib/klog.lua")
    else
        term.setTextColor(colors.red)
        print("http FAILED!")
        term.setTextColor(colors.white)
    end
end

-- Setup package path
if package and package.path and not package.path:find("/lib/?.lua") then
    package.path = package.path .. ";/lib/?.lua"
end

-- Download required libraries if needed
local libraries = {
    ["/lib/klog.lua"] = updateDomain .. "klog.lua",
    ["/lib/pager.lua"] = "https://raw.githubusercontent.com/Twijn/cc-misc/main/util/pager.lua",
    ["/lib/cmd.lua"] = "https://raw.githubusercontent.com/Twijn/cc-misc/main/util/cmd.lua",
}

for path, url in pairs(libraries) do
    if not realFs.exists(path) then
        downloadFile(url, path)
    end
end

-- Auto-download self if needed
if not realFs.exists("/klog-cli.lua") then
    downloadFile(updateDomain .. "klog-cli.lua", "/klog-cli.lua")
end

-- Initialize klog
local klog = nil
local transferTargets = {}
local items = {}

local function initKlog()
    term.setTextColor(colors.orange)
    print("initKlog called")
    term.setTextColor(colors.white)

    -- Use old package
if oldpackage and not package then
    package = oldpackage
end

term.setTextColor(colors.orange)
print("package.path: " .. tostring(package.path))
term.setTextColor(colors.white)

    -- Try loading directly
    term.setTextColor(colors.orange)
    print("Trying realFs.loadfile /lib/klog.lua...")
    term.setTextColor(colors.white)
    local chunk, loadErr
    if realFs.open then
        -- Use real fs to load
        local f = realFs.open("/lib/klog.lua", "r")
        if f then
            local content = f.readAll()
            f.close()
            chunk, loadErr = loadstring(content)
            term.setTextColor(colors.green)
            print("loaded content!")
            term.setTextColor(colors.white)
        else
            term.setTextColor(colors.red)
            print("realFs.open failed")
            term.setTextColor(colors.white)
            return
        end
    else
        chunk, loadErr = loadfile("/lib/klog.lua")
    end

    if not chunk then
        term.setTextColor(colors.red)
        print("load failed: " .. tostring(loadErr))
        term.setTextColor(colors.white)
        return
    end

    local klogMod = chunk()
    if not klogMod then
        term.setTextColor(colors.red)
        print("chunk returned nil")
        term.setTextColor(colors.white)
        return
    end
    term.setTextColor(colors.green)
    print("require klog success")
    term.setTextColor(colors.white)

    local enderStorages = table.pack((_G.oldperipheral or peripheral).find("ender_storage"))
    print("enderStorages.n: " .. enderStorages.n)
    if enderStorages.n == 1 then
        local estorageName = (_G.oldperipheral or peripheral).getName(enderStorages[1])
        print("Using: " .. estorageName)
        klog = klogMod(estorageName, {
            apiKey = settings.get("klog.apiKey"),
        })
        print("klog created: " .. tostring(klog))
        transferTargets = klog.getTransferTargets() or {}

        -- Auto-save API key to VM config
        local cfgPath = "/blackbird/vmconfigs/" .. virfold .. "/config.lua"
        local f = realFs.open(cfgPath, "r")
        if f then
            local content = f.readAll()
            f.close()
            if not content:find("klog.apiKey") then
                local f2 = realFs.open(cfgPath, "a")
                if f2 then
                    f2.writeLine("settings.set(\"klog.apiKey\", \"" .. (settings.get("klog.apiKey") or "") .. "\")")
                    f2.close()
                    print("API key auto-saved to config")
                end
            end
        end
    elseif enderStorages.n > 1 then
        printError("Multiple ender storages found.")
    else
        printError("No ender storages attached")
    end
end

local ok, err = pcall(initKlog)
term.setTextColor(colors.yellow)
print("pcall done: " .. tostring(ok))
if err then print("err: " .. tostring(err)) end
term.setTextColor(colors.white)
sleep(2)

local function rescanItems()
    if not klog then return end
    local newItems = {}
    for i, chest in pairs(klog.getInputChests()) do
        local chestItems = chest.list()
        for slot, item in pairs(chestItems) do
            newItems[item.name] = (newItems[item.name] or 0) + item.count
        end
    end
    items = newItems
end

local function getItemNames()
    local itemNames = {}
    for itemName, _ in pairs(items) do
        table.insert(itemNames, itemName)
    end
    return itemNames
end

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function splitArgs(text)
    local args = {}
    for word in string.gmatch(text, "%S+") do
        args[#args + 1] = word
    end
    return args
end

local function downloadFile(url, filename)
    term.setTextColor(colors.yellow)
    print("Downloading " .. filename .. " from " .. url .. "...")
    local success, errMsg = pcall(function()
        local response = http.get(url)
        if response then
            local content = response.readAll()
            local file = realFs.open(filename, "w")
            if file then
                file.write(content)
                file.close()
                print(filename .. " downloaded successfully!")
            else
                printError("Failed to open file for writing")
            end
        else
            printError("Failed to download " .. filename .. ": No response from server.")
        end
    end)
    term.setTextColor(colors.white)
    if not success then
        printError("Error downloading " .. filename .. ": " .. errMsg)
        return
    end
end

local function getTransferFile(filename)
    local path = "/blackbird/vmdata/" .. virfold .. "/" .. filename
    if realFs.exists(path) then
        local f = realFs.open(path, "r")
        if f then
            local content = f.readAll()
            f.close()
            local func = loadstring(content)
            if func then
                local ok, result = pcall(func)
                if ok then
                    return result()
                end
            end
        end
    end
    return nil
end

local function runCommand(cmdText)
    local args = splitArgs(cmdText)
    if #args == 0 then
        return true
    end

    local cmd = args[1]

    if cmd == "help" or cmd == "?" then
        print("Klog CLI v" .. ver)
        print("")
        print("Commands:")
        print("  ls              - List files")
        print("  list            - List files")
        print("  pwd             - Print working directory")
        print("  edit <name>     - Edit/create .move file")
        print("  edittransfur <name> - Edit .transfur file")
        print("  <name>.move    - Show .move target")
        print("  <name>.transfur - Show .transfur target")
        print("  transfer <target> <item> <qty> - Transfer items")
        print("  rescan          - Rescan input chests")
        print("  list-items      - List items in input")
        print("  update          - Update klog files")
        print("  key <apikey>    - Set API key")
        print("  exit            - Exit to VM menu")
        print("  reboot          - Reboot VM")
        return true
    end

    if cmd == "key" then
        local apikey = args[2]
        if not apikey then
            printError("Usage: key <apikey>")
            return true
        end
        settings.set("klog.apiKey", apikey)
        settings.save()
        print("API key set!")
        -- Also save to VM config
        local cfgPath = "/blackbird/vmconfigs/" .. virfold .. "/config.lua"
        if realFs.exists(cfgPath) then
            local f = realFs.open(cfgPath, "r")
            if f then
                local content = f.readAll()
                f.close()
                if not content:find("klog.apiKey") then
                    local f2 = realFs.open(cfgPath, "a")
                    if f2 then
                        f2.writeLine("settings.set(\"klog.apiKey\", \"" .. apikey .. "\")")
                        f2.close()
                        print("Saved to VM config")
                    end
                end
            end
        end
        initKlog()
        return true
    end

    if cmd == "update" then
        downloadFile(updateDomain .. "klog.lua", "/lib/klog.lua")
        downloadFile(updateDomain .. "klog-cli.lua", "/klog-cli.lua")
        print("Items updated!")
        print("Please restart to apply updates.")
        return true
    end

    if cmd == "transfer" then
        if not klog then
            printError("No ender storage connected")
            return true
        end
        local target = args[2]
        local item = args[3]
        local quantity = tonumber(args[4])
        if not target or not item then
            printError("Usage: transfer <target> <item> [quantity]")
            return true
        end
        local ok, err = pcall(function()
            klog.transfer({
                to = target,
                itemName = item,
                quantity = quantity,
            })
        end)
        if ok then
            print("Transfer initiated!")
        else
            printError("Transfer failed: " .. tostring(err))
        end
        return true
    end

    if cmd == "rescan" then
        rescanItems()
        print("Rescan complete!")
        return true
    end

    if cmd == "list-items" then
        local itemNames = getItemNames()
        for _, itemName in ipairs(itemNames) do
            print(" x" .. (items[itemName] or 0) .. " - " .. itemName)
        end
        return true
    end

    if cmd == "exit" then
        return false
    end

    if cmd == "reboot" then
        os.reboot()
        return false
    end

    if cmd == "pwd" then
        print(shell.dir())
        return true
    end

    if cmd == "ls" or cmd == "list" then
        local path = args[2] or ""
        local files = realFs.list(path)
        if files then
            for _, f in ipairs(files) do
                print(f)
            end
        else
            printError("Cannot list directory")
        end
        return true
    end

    if cmd == "edit" or cmd == "e" then
        local name = args[2]
        if not name then
            printError("Usage: edit <name>")
            return true
        end

        local filename = name .. ".move"
        local path = "/blackbird/vmdata/" .. virfold .. "/" .. filename
        print("File: " .. filename)

        local current = getTransferFile(filename)
        if current then
            print("Current target: " .. current)
        end

        print("Target name (empty to delete):")
        term.setTextColor(colors.yellow)
        write("> ")
        term.setTextColor(colors.white)
        local targetName = read()

        if targetName and targetName ~= "" then
            local f = realFs.open(path, "w")
            if f then
                f.writeLine("-- " .. filename)
                f.writeLine('local function getTarget()')
                f.writeLine('  return "' .. targetName .. '"')
                f.writeLine("end")
                f.writeLine("return getTarget")
                f.close()
                print(filename .. " saved!")
            else
                printError("Failed to save")
            end
        else
            if realFs.exists(path) then
                realFs.delete(path)
                print(filename .. " deleted")
            else
                print(filename .. " not found")
            end
        end
        return true
    end

    if cmd == "edittransfur" or cmd == "et" then
        local name = args[2]
        if not name then
            printError("Usage: edittransfur <name>")
            return true
        end

        local filename = name .. ".transfur"
        local path = "/blackbird/vmdata/" .. virfold .. "/" .. filename
        print("File: " .. filename)

        local current = getTransferFile(filename)
        if current then
            print("Current target: " .. current)
        end

        print("Target name (empty to delete):")
        term.setTextColor(colors.yellow)
        write("> ")
        term.setTextColor(colors.white)
        local targetName = read()

        if targetName and targetName ~= "" then
            local f = realFs.open(path, "w")
            if f then
                f.writeLine("-- " .. filename)
                f.writeLine('local function getTarget()')
                f.writeLine('  return "' .. targetName .. '"')
                f.writeLine("end")
                f.writeLine("return getTarget")
                f.close()
                print(filename .. " saved!")
            else
                printError("Failed to save")
            end
        else
            if realFs.exists(path) then
                realFs.delete(path)
                print(filename .. " deleted")
            else
                print(filename .. " not found")
            end
        end
        return true
    end

    if cmd:match("^%w+%.move$") then
        local name = cmd:match("^(%w+)%.move$")
        local target = getTransferFile(name .. ".move")
        if target then
            print(name .. ".move -> " .. target)
        else
            print(name .. ".move is not set")
        end
        return true
    end

    if cmd:match("^%w+%.transfur$") then
        local name = cmd:match("^(%w+)%.transfur$")
        local target = getTransferFile(name .. ".transfur")
        if target then
            print(name .. ".transfur -> " .. target)
        else
            print(name .. ".transfur is not set")
        end
        return true
    end

    printError("Unknown command: " .. cmd)
    print("Type 'help' for commands")
    return true
end

clear()

term.setTextColor(colors.blue)
print("Klog CLI v" .. ver)
print("VM: " .. virfold)
term.setTextColor(colors.white)

local running = true
local history = {}
while running do
    term.setTextColor(colors.green)
    write("klog@" .. ver .. "> ")
    term.setTextColor(colors.white)

    local input = read(nil, history)

    if input then
        term.setTextColor(colors.lightGray)
        print(input)
        term.setTextColor(colors.white)
        table.insert(history, input)

        local ok, err = pcall(function()
            return runCommand(input)
        end)

        if not ok then
            term.setTextColor(colors.red)
            printError("Error: " .. tostring(err))
            term.setTextColor(colors.white)
        end

        if err == false then
            running = false
        end
    end
end