print("Hello! welcome to the blackbird installer.")
term.clear()
print("what shells do you want installed?")
print("1. cc tweeked (default)")
print("2. klog-cli")
print("3. all shells")
local shell = io.read()

shell.run("mkdir /blackbird/")
shell.run("mkdir /blackbird/shells/")

if shell == 1 then
    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/cct.lua /blackbird/shells/cct.lua")
elseif shell == 2 then
    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/klog.lua /blackbird/shells/klog.lua")
else then
    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/cct.lua /blackbird/shells/cct.lua")
    shell.run("wget https://github.com/minecartchris/blackbird/raw/refs/heads/main/shells/klog.lua /blackbird/shells/klog.lua")
end
term.clear()
print("Thank you for installing blackbird")
print("your computer will reboot in ")

local t = 10
while t > 1 do
    print(t.." Seconds")
    os.sleep(1)
    t = t - 1
end
os.reboot()