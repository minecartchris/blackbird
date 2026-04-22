print("Hello! welcome to the blackbird installer.")
sleep(2)
term.clear()

if not fs.exists("/blackbird/") then
    shell.run("mkdir /blackbird/")
    shell.run("mkdir /blackbird/shells/") 
end

print("what shells do you want installed?")
print("1. cc tweeked (default)")
print("2. klog-cli")
print("3. all shells")
local shellC = io.read()

if shellC == 1 then
    if fs.exists("/shells/cct.lua") then
        print("cc tweeked is already installed, do you want to redownload it?")
        print("1. Yes")
        print("2. No")
        local redownload = io.read()
        if redownload == 1 then
            fs.remove("/blackbird/shells/cct.lua")
        end
    end
    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/cct.lua /blackbird/shells/cct.lua")
elseif shellC == 2 then
    if fs.exists("/shells/klog.lua") then
        print("klog-cli is already installed, do you want to redownload it?")
        print("1. Yes")
        print("2. No")
        local redownload = io.read()
        if redownload == 1 then
            fs.remove("/blackbird/shells/klog.lua")
        end
    end
    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/klog.lua /blackbird/shells/klog.lua")
else
    if fs.exists("/shells/cct.lua") then
        print("cc tweeked is already installed, do you want to redownload it?")
        print("1. Yes")
        print("2. No")
        local redownload = io.read()
        if redownload == 1 then
            fs.remove("/blackbird/shells/cct.lua")
        end
    end

    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/cct.lua /blackbird/shells/cct.lua")

    if fs.exists("/shells/klog.lua") then
        print("klog-cli is already installed, do you want to redownload it?")
        print("1. Yes")
        print("2. No")
        local redownload = io.read()
        if redownload == 1 then
            fs.remove("/blackbird/shells/klog.lua")
        end
    end

    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/klog.lua /blackbird/shells/klog.lua")
end
shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/blackbird.lua")

term.clear()

if not fs.exists("/startup.lua") then
    print("do you waant a startup file made to auto boot into blackbird?")
    print("1. Yes")
    print("2. No")
    local startupF = io.read()
    if startupF == 1 then
        local file = fs.open("/startup.lua", "w")
        file.write('shell.run("/blackbird.lua")')
        file.close()
    end
end


term.clear()

print("Thank you for installing blackbird")
print("your computer will reboot in ")

local t = 10
while t > 1 do
    print(t.." Seconds")
    sleep(1)
    t = t - 1
end
os.reboot()