-- Update Blackbird's bundled shells in /blackbird/shells/.
--
-- Install this on the CC computer as /blackbird/update-shells.lua and run it
-- from the shell (or from inside a VM - it deliberately uses _G.oldfs when
-- available so it writes to the real host fs, not into the VM's data dir).
--
-- Usage:
--   update-shells              -- refresh every known shell
--   update-shells klog         -- just klog
--   update-shells klog cct     -- several by name
--   update-shells list         -- print available updaters
--
-- To add a new updater, extend the `updaters` table below.

local SHELL_DIR = "/blackbird/shells"

-- Use the host's real fs if we're inside a Blackbird VM. The sandbox already
-- treats /blackbird/shells paths specially, but makeDir doesn't - going
-- through the real fs sidesteps that and keeps behavior the same either way.
local realFs = _G.oldfs or fs

local updaters = {
    klog = {
        description = "krawlet.cc klog CLI",
        source = "https://krawlet.cc/klog-cli.lua",
        target = SHELL_DIR .. "/klog.lua",
        kind = "http",
    },
    cct = {
        description = "stock CraftOS:Tweaked shell",
        source = "/rom/programs/shell.lua",
        target = SHELL_DIR .. "/cct.lua",
        kind = "fs",
    },
}

local function ensureDir(path)
    if realFs.exists(path) then
        if not realFs.isDir(path) then
            error(path .. " exists but is not a directory", 0)
        end
        return
    end
    realFs.makeDir(path)
end

local function fetchHttp(url)
    local resp, err = http.get(url)
    if not resp then
        return nil, tostring(err or "no response")
    end
    local body = resp.readAll()
    resp.close()
    if not body or body == "" then
        return nil, "empty response"
    end
    return body
end

local function fetchFs(path)
    if not realFs.exists(path) then
        return nil, path .. " does not exist"
    end
    local f = realFs.open(path, "r")
    if not f then return nil, "failed to open " .. path end
    local body = f.readAll()
    f.close()
    if not body or body == "" then
        return nil, "empty file " .. path
    end
    return body
end

local function writeFile(path, body)
    local f, err = realFs.open(path, "w")
    if not f then return false, tostring(err) end
    f.write(body)
    f.close()
    return true
end

local function updateOne(name)
    local entry = updaters[name]
    if not entry then
        term.setTextColor(colors.red)
        print("Unknown shell: " .. tostring(name))
        term.setTextColor(colors.white)
        return false
    end

    term.setTextColor(colors.lightGray)
    io.write("[" .. name .. "] ")
    term.setTextColor(colors.white)

    ensureDir(SHELL_DIR)

    local body, err
    if entry.kind == "http" then
        body, err = fetchHttp(entry.source)
    elseif entry.kind == "fs" then
        body, err = fetchFs(entry.source)
    else
        err = "unknown kind: " .. tostring(entry.kind)
    end
    if not body then
        term.setTextColor(colors.red)
        print("FAIL " .. tostring(err))
        term.setTextColor(colors.white)
        return false
    end

    local ok, werr = writeFile(entry.target, body)
    if not ok then
        term.setTextColor(colors.red)
        print("FAIL cannot write " .. entry.target .. ": " .. tostring(werr))
        term.setTextColor(colors.white)
        return false
    end

    term.setTextColor(colors.green)
    print("OK")
    term.setTextColor(colors.lightGray)
    print("      " .. entry.target .. "  (" .. #body .. " bytes)")
    term.setTextColor(colors.white)
    return true
end

local function usage()
    print("Usage: update-shells [all|list|<name>...]")
    print("Available shells:")
    local names = {}
    for n in pairs(updaters) do names[#names + 1] = n end
    table.sort(names)
    for _, name in ipairs(names) do
        print("  " .. name .. " - " .. updaters[name].description)
    end
end

local args = { ... }
local targets
if #args == 0 or args[1] == "all" then
    targets = {}
    for n in pairs(updaters) do targets[#targets + 1] = n end
    table.sort(targets)
elseif args[1] == "list" or args[1] == "help" or args[1] == "-h" or args[1] == "--help" then
    usage()
    return
else
    targets = args
end

local failed = 0
for _, name in ipairs(targets) do
    if not updateOne(name) then failed = failed + 1 end
end

if failed > 0 then
    term.setTextColor(colors.red)
    print(failed .. " update(s) failed.")
    term.setTextColor(colors.white)
    error("update-shells: " .. failed .. " failed", 0)
end
