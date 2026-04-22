# Blackbird VM — Project Guidelines

Blackbird is a Lua-only virtual machine for [ComputerCraft: Tweaked](https://tweaked.cc/). It lets one CC computer host multiple sandboxed "VMs" with their own filesystem view, computer ID, and optional custom shell. The host script is `blackbird.lua`; everything else in the repo is support data or development helpers.

## Repository layout

| Path | Purpose |
|---|---|
| `blackbird.lua` | The whole VM: menu UI, sandbox, bootloader. |
| `shells/cct.lua` | Stock CC:Tweaked shell (LicenseRef-CCPL, Daniel Ratcliffe) — available as a VM entry point. |
| `shells/klog.lua` | Custom Blackbird shell for `krawlet.cc` with `.move`/`.transfur` transfer helpers. |
| `vmdata/<name>/` | Per-VM writable data dir. Mapped to `/` inside the VM. Held at runtime as `/blackbird/vmdata/<name>/`. |
| `vmconfigs/<name>/config.lua` | Per-VM config file (Lua key=value). Held at runtime as `/blackbird/vmconfigs/<name>/config.lua`. |
| `test*.lua`, `*.bat` | Local dev scaffolding (CraftOS-PC launch / smoke tests). Not shipped with a VM. |
| `LICENSE`, `README.md` | GPLv3 license and project summary. |

### Runtime paths on the host CC computer

- `/blackbird/vmdata/<vm>/` — per-VM writable data (the VM sees this as `/`).
- `/blackbird/vmdata/<vm>/blackbirdFiles/auto.lua` — (planned) autostart marker.
- `/blackbird/vmconfigs/<vm>/config.lua` — per-VM persistent config.
- `/blackbird/shells/*.lua` — shell programs selectable as the VM's entry point.
- `/rom` — read-only, passed through from the host unchanged.
- `/disk/keys/blackbird` — optional admin-key file; contents `"someuuid"` skip the menu relaunch after VM exit.

## Config file format

`/blackbird/vmconfigs/<vm>/config.lua` is Lua source, loaded with `dofile` during Launch/Config. Keys the VM currently reads:

- `textnewID` — integer returned from the VM's `os.getComputerID()`.
- `filelaunch` — absolute path of the shell/program to launch inside the VM. If unset, defaults to `rom/programs/shell.lua`.

A minimal config:

```lua
textnewID=1
```

With a custom shell:

```lua
textnewID=7
filelaunch=blackbird/shells/klog.lua
```

> **Security note:** because config is loaded with `dofile`, anything you put in here runs as host code *before* the sandbox is installed. Treat config files as trusted.

## Main UI (host menu)

`mainUI()` uses PrimeUI (bundled inline in `blackbird.lua`, JackMacWindows). Top-level actions:

- **Create new VM** — prompts for a name, creates `/blackbird/vmdata/<name>/` and `/blackbird/vmconfigs/<name>/config.lua` seeded with `textnewID=1`.
- **Launch VM** — lists existing VMs, `dofile`s the config, sets `virfold`, falls through to sandbox install.
- **Config menu** → per-VM:
  - **Edit ID** — sets `_G.textnewID` (persisted via the final config rewrite).
  - **Set shell** — scans `/blackbird/shells/*.lua` and stores the chosen path as `filelaunch`.
  - **List data** — shows `ID:` and `seagull launchfile:`.
- **Delete VM** — removes both `/blackbird/vmdata/<name>` and `/blackbird/vmconfigs/<name>`.

After "Launch VM" the function returns; the rest of `blackbird.lua` takes over.

## VM sandbox

Once a VM is launched, `blackbird.lua` replaces selected globals:

```text
_G.fs         ← fresh table, repopulated from oldfs then overridden per-method
_G.os         ← fresh table, repopulated from oldos, getComputerID/shutdown/reboot overridden
_G.peripheral ← fresh table, repopulated from oldperipheral (no overrides currently)
_G.package    ← kept pointing at the host's package
_G.require    ← wrapper around the host require
```

All other CC:Tweaked globals (`term`, `colors`, `http`, …) are **not** replaced — they stay accessible as-is. See [Libraries available inside the VM](#libraries-available-inside-the-vm) below.

### Escape hatches (available to VM programs)

| Global | What it returns |
|---|---|
| `_G.oldfs` | real host `fs` |
| `_G.oldos` | real host `os` |
| `_G.oldperipheral` | real host `peripheral` |
| `_G.oldpackage` | real host `package` |
| `_G.getRealPeripheral()` | same as `_G.oldperipheral` |
| `_G.virfold` | current VM name (string) |
| `_G.textnewID` | current VM's configured ID |

`shells/klog.lua` uses these to reach real filesystem and real peripherals while the sandbox is active.

### Wrapped `fs` — rules

`fs_combine` is captured once; the wrapper then routes by prefix of `cleanRawPath = fs.combine(path)`:

1. Starts with `rom/` → delegated to `oldfs.X` on the raw path.
2. Contains `blackbird/shells` → delegated to `oldfs.X` on the raw path (so VM shells can be loaded).
3. `cleanRawPath == ""` (listing root) → lists the VM root and prepends `rom` (and `blackbird` if `/blackbird/shells` exists).
4. Otherwise, rewritten to `/blackbird/vmdata/<virfold>/<path>` and delegated only if `isVM(cleanPath)` returns true.

Wrapped methods: `open`, `list`, `find`, `isDir`, `copy`, `delete`, `attributes`, `getCapacity`, `getFreeSpace`, `getDrive`, `move`, `makeDir`, `isReadOnly`, `getSize`, `isDriveRoot`, `exists`.

### Wrapped `os`

- `os.getComputerID()` — returns `textnewID` (VM's configured ID).
- `os.shutdown()` — restores `fs`/`os`/`peripheral`/`package` globals, clears `virfold`, calls `mainUI()` → back to the menu.
- `os.reboot()` — restores globals, clears `virfold`, then calls the real `os.reboot()` (reboots the host computer).

Everything else on `os` is the original.

### `debug.protect`

`blackbird.lua` bundles JackMacWindows' dbprotect and applies it to every `fs` method after wrapping, plus `os.getComputerID`. This blocks `debug.getupvalue` / `getfenv` / `setfenv` against those wrappers so VM code can't reach into the closure and read/replace `oldfs`, `virfold`, or friends.

### VM boot sequence

1. User picks a VM in the menu → `virfold = <name>`, `dofile(config)` sets `textnewID`, optionally `filelaunch`.
2. Sandbox replaces `fs`/`os`/`peripheral`; escape hatches stashed.
3. Every wrapped method is passed through `debug.protect`.
4. Header printed ("blackbird VM" + `ver`).
5. If `filelaunch` is set: `os.run({}, filelaunch)`. Else: `os.run({}, "rom/programs/shell.lua")`.
6. When the shell exits, `_G.fs = oldfs`; `_G.package = oldpackage`.
7. Admin-key check against `/disk/keys/blackbird`. If not `someuuid`, `os.run({}, "blackbird/init.lua")`.

## Libraries available inside the VM

All of these come from the CC:Tweaked environment and stay available inside the sandbox. Refer to <https://tweaked.cc/> for the authoritative API docs.

### Global APIs

- `_G` — global table
- `colors` / `colours` — colour constants
- `commands` — Minecraft command invocation (command-computer only)
- `disk` — disk drives
- `fs` — filesystem (wrapped; see above)
- `gps` — positioning
- `help` — help-text lookup
- `http` — HTTP/WebSocket
- `io` — Lua-style IO
- `keys` — key codes
- `multishell` — multi-tab shell (advanced computers)
- `os` — OS (wrapped; see above)
- `paintutils` — bitmap drawing
- `parallel` — cooperative multitasking
- `peripheral` — attached peripherals (wrapped; see above)
- `pocket` — pocket-computer-only APIs
- `rednet` — wireless networking (built on modems)
- `redstone` — redstone I/O
- `settings` — persistent settings
- `shell` — shell API (per-program, not a true global)
- `term` — terminal
- `textutils` — text helpers / serialization
- `turtle` — turtle-only APIs
- `vector` — 3D vector math
- `window` — window API

### Lua standard libraries

- `coroutine`
- `debug` (hardened via `dbprotect`)
- `math`
- `string`
- `table`
- `bit32` / `bit`
- `utf8`

### `require`-able modules

- `cc.audio.dfpwm` — DFPWM audio
- `cc.completion` — completion helpers
- `cc.expect` — argument type-checking
- `cc.image.nft` — NFT image format
- `cc.pretty` — pretty-printer
- `cc.require` — `package`-style requires
- `cc.shell.completion` — shell completion helpers
- `cc.strings` — string helpers

### Peripheral types (not APIs; `peripheral.find`/`peripheral.wrap`)

- `computer`, `drive`, `modem`, `monitor`, `printer`, `speaker`
- Generic: `energy_storage`, `fluid_storage`, `inventory`

### Events (for `os.pullEvent` / `os.pullEventRaw`)

`alarm`, `char`, `computer_command`, `disk`, `disk_eject`, `file_transfer`, `http_check`, `http_failure`, `http_success`, `key`, `key_up`, `modem_message`, `monitor_resize`, `monitor_touch`, `mouse_click`, `mouse_drag`, `mouse_scroll`, `mouse_up`, `paste`, `peripheral`, `peripheral_detach`, `rednet_message`, `redstone`, `speaker_audio_empty`, `task_complete`, `term_resize`, `terminate`, `timer`, `turtle_inventory`, `websocket_closed`, `websocket_failure`, `websocket_message`, `websocket_success`.

## Shell entry points

Any Lua file under `/blackbird/shells/` ending in `.lua` can be chosen via **Config menu → Set shell**. Blackbird passes the path to `os.run({}, filelaunch)`. Bundled shells:

- `cct.lua` — stock CraftOS shell, unmodified.
- `klog.lua` — Blackbird-specific `krawlet.cc` klog CLI. Downloads `/lib/klog.lua` and friends over HTTP at first run. Uses `_G.oldfs` / `_G.oldperipheral` to bypass the VM sandbox for real-file and real-peripheral access.

## Known issues / things to watch

These are present in the current code but not critical enough to block normal use. Listed so contributors don't re-break them while fixing other things.

- **Config is Lua code.** `dofile` executes config contents; treat configs as trusted.
- **No VM-name validation.** `"../foo"` or other traversal-style names aren't rejected on create/delete; validate if exposing this to untrusted users.
- **`isVM` prefix match.** Uses `string.find("^/blackbird/vmdata/"..virfold)`, which matches `"vm1"` against `"vm12/..."` as a prefix. Either anchor with a `/` boundary or escape `virfold`'s magic characters.
- **Config-menu "Back" fall-through.** In `mainUI`, selecting "Back" calls `mainUI()` recursively but doesn't `return`, so the rest of the branch keeps executing on the way out.
- **Admin-key check bug.** The block that reads `/disk/keys/blackbird` references an undefined `f` (should be `file:readAll()`), so `data` is always `nil` and the `"someuuid"` check can never succeed.
- **`fs.exists` / `fs.list("..")`.** Don't enforce `isVM` on all branches; a malicious VM path can probe outside the VM dir.

## Development notes

- Debug-target copy is at `C:\Users\risto\AppData\Roaming\CraftOS-PC\computer\0\blackbird.lua` (see `test_blackbird.bat`).
- `test.lua`, `test_quick.lua`, `test_runner.lua` are smoke tests; they run *outside* the sandbox so API wrappers aren't exercised.
- PrimeUI is bundled rather than `require`d — keep it in sync manually if you update it.
- `ver` at the top of `blackbird.lua` is the displayed VM version string.
