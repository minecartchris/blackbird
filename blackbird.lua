-- yabastar, main dev
-- JackMacWindows, major bug fixes, PrimeUI
-- RyanT, fixed an annoying bug JMW and I couldn't fix, selection menu
-- minerobber, fixed a minor selection menu bug, fixed a bug that occured from fs.combine

local ver = "v1.0.0 bata"

local expect = require "cc.expect".expect

--PrimeUI by JMW
-- Initialization code
local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    --- Adds a task to run in the main loop.
    ---@param func function The function to run, usually an `os.pullEvent` loop
    function PrimeUI.addTask(func)
        expect(1, func, "function")
        coros[#coros+1] = {coro = coroutine.create(func)}
    end

    --- Sends the provided arguments to the run loop, where they will be returned.
    ---@param ... any The parameters to send
    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    --- Clears the screen and resets all components. Do not use any previously
    --- created components after calling this function.
    function PrimeUI.clear()
        -- Reset the screen.
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        -- Reset the task list and cursor restore function.
        coros = {}
        restoreCursor = nil
    end

    --- Sets or clears the window that holds where the cursor should be.
    ---@param win window|nil The window to set as the active window
    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    --- Gets the absolute position of a coordinate relative to a window.
    ---@param win window The window to check
    ---@param x number The relative X position of the point
    ---@param y number The relative Y position of the point
    ---@return number x The absolute X position of the window
    ---@return number y The absolute Y position of the window
    function PrimeUI.getWindowPos(win, x, y)
        if win == term then return x, y end
        while win ~= term.native() and win ~= term.current() do
            if not win.getPosition then return x, y end
            local wx, wy = win.getPosition()
            x, y = x + wx - 1, y + wy - 1
            _, win = debug.getupvalue(win.isColor, 1) -- gets the parent window through an upvalue
        end
        return x, y
    end

    --- Runs the main loop, returning information on an action.
    ---@return any ... The result of the coroutine that exited
    function PrimeUI.run()
        while true do
            -- Restore the cursor and wait for the next event.
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            -- Run all coroutines.
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    -- Resume the coroutine, passing the current event.
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    -- If the call failed, bail out. Coroutines should never exit.
                    if not res[1] then error(res[2], 2) end
                    -- If the coroutine resolved, return its values.
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    -- Set the next event filter.
                    v.filter = res[2]
                end
            end
        end
    end
end

--- Draws a thin border around a screen region.
---@param win window The window to draw on
---@param x number The X coordinate of the inside of the box
---@param y number The Y coordinate of the inside of the box
---@param width number The width of the inner box
---@param height number The height of the inner box
---@param fgColor color|nil The color of the border (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.borderBox(win, x, y, width, height, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.black
    -- Draw the top-left corner & top border.
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    win.setCursorPos(x - 1, y - 1)
    win.write("\x9C" .. ("\x8C"):rep(width))
    -- Draw the top-right corner.
    win.setBackgroundColor(fgColor)
    win.setTextColor(bgColor)
    win.write("\x93")
    -- Draw the right border.
    for i = 1, height do
        win.setCursorPos(win.getCursorPos() - 1, y + i - 1)
        win.write("\x95")
    end
    -- Draw the left border.
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    for i = 1, height do
        win.setCursorPos(x - 1, y + i - 1)
        win.write("\x95")
    end
    -- Draw the bottom border and corners.
    win.setCursorPos(x - 1, y + height)
    win.write("\x8D" .. ("\x8C"):rep(width) .. "\x8E")
end

--- Creates a clickable button on screen with text.
---@param win window The window to draw on
---@param x number The X position of the button
---@param y number The Y position of the button
---@param text string The text to draw on the button
---@param action function|string A function to call when clicked, or a string to send with a `run` event
---@param fgColor color|nil The color of the button text (defaults to white)
---@param bgColor color|nil The color of the button (defaults to light gray)
---@param clickedColor color|nil The color of the button when clicked (defaults to gray)
function PrimeUI.button(win, x, y, text, action, fgColor, bgColor, clickedColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, text, "string")
    expect(5, action, "function", "string")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.gray
    clickedColor = expect(8, clickedColor, "number", "nil") or colors.lightGray
    -- Draw the initial button.
    win.setCursorPos(x, y)
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    win.write(" " .. text .. " ")
    -- Get the screen position and add a click handler.
    local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
    PrimeUI.addTask(function()
        local buttonDown = false
        while true do
            local event, button, clickX, clickY = os.pullEvent()
            if event == "mouse_click" and button == 1 and clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                -- Initiate a click action (but don't trigger until mouse up).
                buttonDown = true
                -- Redraw the button with the clicked background color.
                win.setCursorPos(x, y)
                win.setBackgroundColor(clickedColor)
                win.setTextColor(fgColor)
                win.write(" " .. text .. " ")
            elseif event == "mouse_up" and button == 1 and buttonDown then
                -- Finish a click event.
                if clickX >= screenX and clickX < screenX + #text + 2 and clickY == screenY then
                    -- Trigger the action.
                    if type(action) == "string" then PrimeUI.resolve("button", action)
                    else action() end
                end
                -- Redraw the original button state.
                win.setCursorPos(x, y)
                win.setBackgroundColor(bgColor)
                win.setTextColor(fgColor)
                win.write(" " .. text .. " ")
            end
        end
    end)
end

--- Creates a list of entries with toggleable check boxes.
---@param win window The window to draw on
---@param x number The X coordinate of the inside of the box
---@param y number The Y coordinate of the inside of the box
---@param width number The width of the inner box
---@param height number The height of the inner box
---@param selections {string: string|boolean} A list of entries to show, where the value is whether the item is pre-selected (or `"R"` for required/forced selected)
---@param action function|string|nil A function or `run` event that's called when a selection is made
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.checkSelectionBox(win, x, y, width, height, selections, action, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, selections, "table")
    expect(7, action, "function", "string", "nil")
    fgColor = expect(8, fgColor, "number", "nil") or colors.white
    bgColor = expect(9, bgColor, "number", "nil") or colors.black
    -- Calculate how many selections there are.
    local nsel = 0
    for _ in pairs(selections) do nsel = nsel + 1 end
    -- Create the outer display box.
    local outer = window.create(win, x, y, width, height)
    outer.setBackgroundColor(bgColor)
    outer.clear()
    -- Create the inner scroll box.
    local inner = window.create(outer, 1, 1, width - 1, nsel)
    inner.setBackgroundColor(bgColor)
    inner.setTextColor(fgColor)
    inner.clear()
    -- Draw each line in the window.
    local lines = {}
    local nl, selected = 1, 1
    for k, v in pairs(selections) do
        inner.setCursorPos(1, nl)
        inner.write((v and (v == "R" and "[-] " or "[\xD7] ") or "[ ] ") .. k)
        lines[nl] = {k, not not v}
        nl = nl + 1
    end
    -- Draw a scroll arrow if there is scrolling.
    if nsel > height then
        outer.setCursorPos(width, height)
        outer.setBackgroundColor(bgColor)
        outer.setTextColor(fgColor)
        outer.write("\31")
    end
    -- Set cursor blink status.
    inner.setCursorPos(2, selected)
    inner.setCursorBlink(true)
    PrimeUI.setCursorWindow(inner)
    -- Get screen coordinates & add run task.
    local screenX, screenY = PrimeUI.getWindowPos(win, x, y)
    PrimeUI.addTask(function()
        local scrollPos = 1
        while true do
            -- Wait for an event.
            local ev = table.pack(os.pullEvent())
            -- Look for a scroll event or a selection event.
            local dir
            if ev[1] == "key" then
                if ev[2] == keys.up then dir = -1
                elseif ev[2] == keys.down then dir = 1
                elseif ev[2] == keys.space and selections[lines[selected][1]] ~= "R" then
                    -- (Un)select the item.
                    lines[selected][2] = not lines[selected][2]
                    inner.setCursorPos(2, selected)
                    inner.write(lines[selected][2] and "\xD7" or " ")
                    -- Call the action if passed; otherwise, set the original table.
                    if type(action) == "string" then PrimeUI.resolve("checkSelectionBox", action, lines[selected][1], lines[selected][2])
                    elseif action then action(lines[selected][1], lines[selected][2])
                    else selections[lines[selected][1]] = lines[selected][2] end
                    -- Redraw all lines in case of changes.
                    for i, v in ipairs(lines) do
                        local vv = selections[v[1]] == "R" and "R" or v[2]
                        inner.setCursorPos(2, i)
                        inner.write((vv and (vv == "R" and "-" or "\xD7") or " "))
                    end
                    inner.setCursorPos(2, selected)
                end
            elseif ev[1] == "mouse_scroll" and ev[3] >= screenX and ev[3] < screenX + width and ev[4] >= screenY and ev[4] < screenY + height then
                dir = ev[2]
            end
            -- Scroll the screen if required.
            if dir and (selected + dir >= 1 and selected + dir <= nsel) then
                selected = selected + dir
                if selected - scrollPos < 0 or selected - scrollPos >= height then
                    scrollPos = scrollPos + dir
                    inner.reposition(1, 2 - scrollPos)
                end
                inner.setCursorPos(2, selected)
            end
            -- Redraw scroll arrows and reset cursor.
            outer.setCursorPos(width, 1)
            outer.write(scrollPos > 1 and "\30" or " ")
            outer.setCursorPos(width, height)
            outer.write(scrollPos < nsel - height + 1 and "\31" or " ")
            inner.restoreCursor()
        end
    end)
end

--- Draws a block of text inside a window with word wrapping, optionally resizing the window to fit.
---@param win window The window to draw in
---@param text string The text to draw
---@param resizeToFit boolean|nil Whether to resize the window to fit the text (defaults to false). This is useful for scroll boxes.
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
---@return number lines The total number of lines drawn
function PrimeUI.drawText(win, text, resizeToFit, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, text, "string")
    expect(3, resizeToFit, "boolean", "nil")
    fgColor = expect(4, fgColor, "number", "nil") or colors.white
    bgColor = expect(5, bgColor, "number", "nil") or colors.black
    -- Set colors.
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    -- Redirect to the window to use print on it.
    local old = term.redirect(win)
    -- Draw the text using print().
    local lines = print(text)
    -- Redirect back to the original terminal.
    term.redirect(old)
    -- Resize the window if desired.
    if resizeToFit then
        -- Get original parameters.
        local x, y = win.getPosition()
        local w = win.getSize()
        -- Resize the window.
        win.reposition(x, y, w, lines)
    end
    return lines
end

--- Draws a horizontal line at a position with the specified width.
---@param win window The window to draw on
---@param x number The X position of the left side of the line
---@param y number The Y position of the line
---@param width number The width/length of the line
---@param fgColor color|nil The color of the line (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.horizontalLine(win, x, y, width, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    -- Use drawing characters to draw a thin line.
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(("\x8C"):rep(width))
end

--- Creates a text input box.
---@param win window The window to draw on
---@param x number The X position of the left side of the box
---@param y number The Y position of the box
---@param width number The width/length of the box
---@param action function|string A function or `run` event to call when the enter key is pressed
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
---@param replacement string|nil A character to replace typed characters with
---@param history string[]|nil A list of previous entries to provide
---@param completion function|nil A function to call to provide completion
---@param default string|nil A string to return if the box is empty
function PrimeUI.inputBox(win, x, y, width, action, fgColor, bgColor, replacement, history, completion, default)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, action, "function", "string")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.black
    expect(8, replacement, "string", "nil")
    expect(9, history, "table", "nil")
    expect(10, completion, "function", "nil")
    expect(11, default, "string", "nil")
    -- Create a window to draw the input in.
    local box = window.create(win, x, y, width, 1)
    box.setTextColor(fgColor)
    box.setBackgroundColor(bgColor)
    box.clear()
    -- Call read() in a new coroutine.
    PrimeUI.addTask(function()
        -- We need a child coroutine to be able to redirect back to the window.
        local coro = coroutine.create(read)
        -- Run the function for the first time, redirecting to the window.
        local old = term.redirect(box)
        local ok, res = coroutine.resume(coro, replacement, history, completion, default)
        term.redirect(old)
        -- Run the coroutine until it finishes.
        while coroutine.status(coro) ~= "dead" do
            -- Get the next event.
            local ev = table.pack(os.pullEvent())
            -- Redirect and resume.
            old = term.redirect(box)
            ok, res = coroutine.resume(coro, table.unpack(ev, 1, ev.n))
            term.redirect(old)
            -- Pass any errors along.
            if not ok then error(res) end
        end
        -- Send the result to the receiver.
        if type(action) == "string" then PrimeUI.resolve("inputBox", action, res)
        else action(res) end
        -- Spin forever, because tasks cannot exit.
        while true do os.pullEvent() end
    end)
end

--- Adds an action to trigger when a key is pressed.
---@param key key The key to trigger on, from `keys.*`
---@param action function|string A function to call when clicked, or a string to use as a key for a `run` return event
function PrimeUI.keyAction(key, action)
    expect(1, key, "number")
    expect(2, action, "function", "string")
    PrimeUI.addTask(function()
        while true do
            local _, param1 = os.pullEvent("key") -- wait for key
            if param1 == key then
                if type(action) == "string" then PrimeUI.resolve("keyAction", action)
                else action() end
            end
        end
    end)
end

--- Adds an action to trigger when a key is pressed with modifier keys.
---@param key key The key to trigger on, from `keys.*`
---@param withCtrl boolean Whether Ctrl is required
---@param withAlt boolean Whether Alt is required
---@param withShift boolean Whether Shift is required
---@param action function|string A function to call when clicked, or a string to use as a key for a `run` return event
function PrimeUI.keyCombo(key, withCtrl, withAlt, withShift, action)
    expect(1, key, "number")
    expect(2, withCtrl, "boolean")
    expect(3, withAlt, "boolean")
    expect(4, withShift, "boolean")
    expect(5, action, "function", "string")
    PrimeUI.addTask(function()
        local heldCtrl, heldAlt, heldShift = false, false, false
        while true do
            local event, param1, param2 = os.pullEvent() -- wait for key
            if event == "key" then
                -- check if key is down, all modifiers are correct, and that it's not held
                if param1 == key and heldCtrl == withCtrl and heldAlt == withAlt and heldShift == withShift and not param2 then
                    if type(action) == "string" then PrimeUI.resolve("keyCombo", action)
                    else action() end
                -- activate modifier keys
                elseif param1 == keys.leftCtrl or param1 == keys.rightCtrl then heldCtrl = true
                elseif param1 == keys.leftAlt or param1 == keys.rightAlt then heldAlt = true
                elseif param1 == keys.leftShift or param1 == keys.rightShift then heldShift = true end
            elseif event == "key_up" then
                -- deactivate modifier keys
                if param1 == keys.leftCtrl or param1 == keys.rightCtrl then heldCtrl = false
                elseif param1 == keys.leftAlt or param1 == keys.rightAlt then heldAlt = false
                elseif param1 == keys.leftShift or param1 == keys.rightShift then heldShift = false end
            end
        end
    end)
end

--- Draws a line of text at a position.
---@param win window The window to draw on
---@param x number The X position of the left side of the line
---@param y number The Y position of the line
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.label(win, x, y, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, text, "string")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

--- Creates a progress bar, which can be updated by calling the returned function.
---@param win window The window to draw on
---@param x number The X position of the left side of the bar
---@param y number The Y position of the bar
---@param width number The width of the bar
---@param fgColor color|nil The color of the activated part of the bar (defaults to white)
---@param bgColor color|nil The color of the inactive part of the bar (defaults to black)
---@param useShade boolean|nil Whether to use shaded areas for the inactive part (defaults to false)
---@return function redraw A function to call to update the progress of the bar, taking a number from 0.0 to 1.0
function PrimeUI.progressBar(win, x, y, width, fgColor, bgColor, useShade)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    expect(7, useShade, "boolean", "nil")
    local function redraw(progress)
        expect(1, progress, "number")
        if progress < 0 or progress > 1 then error("bad argument #1 (value out of range)", 2) end
        -- Draw the active part of the bar.
        win.setCursorPos(x, y)
        win.setBackgroundColor(bgColor)
        win.setBackgroundColor(fgColor)
        win.write((" "):rep(math.floor(progress * width)))
        -- Draw the inactive part of the bar, using shade if desired.
        win.setBackgroundColor(bgColor)
        win.setTextColor(fgColor)
        win.write((useShade and "\x7F" or " "):rep(width - math.floor(progress * width)))
    end
    redraw(0)
    return redraw
end

--- Creates a scrollable window, which allows drawing large content in a small area.
---@param win window The parent window of the scroll box
---@param x number The X position of the box
---@param y number The Y position of the box
---@param width number The width of the box
---@param height number The height of the outer box
---@param innerHeight number The height of the inner scroll area
---@param allowArrowKeys boolean|nil Whether to allow arrow keys to scroll the box (defaults to true)
---@param showScrollIndicators boolean|nil Whether to show arrow indicators on the right side when scrolling is available, which reduces the inner width by 1 (defaults to false)
---@param fgColor number|nil The color of scroll indicators (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
---@return window inner The inner window to draw inside
function PrimeUI.scrollBox(win, x, y, width, height, innerHeight, allowArrowKeys, showScrollIndicators, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, innerHeight, "number")
    expect(7, allowArrowKeys, "boolean", "nil")
    expect(8, showScrollIndicators, "boolean", "nil")
    fgColor = expect(9, fgColor, "number", "nil") or colors.white
    bgColor = expect(10, bgColor, "number", "nil") or colors.black
    if allowArrowKeys == nil then allowArrowKeys = true end
    -- Create the outer container box.
    local outer = window.create(win == term and term.current() or win, x, y, width, height)
    outer.setBackgroundColor(bgColor)
    outer.clear()
    -- Create the inner scrolling box.
    local inner = window.create(outer, 1, 1, width - (showScrollIndicators and 1 or 0), innerHeight)
    inner.setBackgroundColor(bgColor)
    inner.clear()
    -- Draw scroll indicators if desired.
    if showScrollIndicators then
        outer.setBackgroundColor(bgColor)
        outer.setTextColor(fgColor)
        outer.setCursorPos(width, height)
        outer.write(innerHeight > height and "\31" or " ")
    end
    -- Get the absolute position of the window.
    x, y = PrimeUI.getWindowPos(win, x, y)
    -- Add the scroll handler.
    PrimeUI.addTask(function()
        local scrollPos = 1
        while true do
            -- Wait for next event.
            local ev = table.pack(os.pullEvent())
            -- Update inner height in case it changed.
            innerHeight = select(2, inner.getSize())
            -- Check for scroll events and set direction.
            local dir
            if ev[1] == "key" and allowArrowKeys then
                if ev[2] == keys.up then dir = -1
                elseif ev[2] == keys.down then dir = 1 end
            elseif ev[1] == "mouse_scroll" and ev[3] >= x and ev[3] < x + width and ev[4] >= y and ev[4] < y + height then
                dir = ev[2]
            end
            -- If there's a scroll event, move the window vertically.
            if dir and (scrollPos + dir >= 1 and scrollPos + dir <= innerHeight - height) then
                scrollPos = scrollPos + dir
                inner.reposition(1, 2 - scrollPos)
            end
            -- Redraw scroll indicators if desired.
            if showScrollIndicators then
                outer.setBackgroundColor(bgColor)
                outer.setTextColor(fgColor)
                outer.setCursorPos(width, 1)
                outer.write(scrollPos > 1 and "\30" or " ")
                outer.setCursorPos(width, height)
                outer.write(scrollPos < innerHeight - height and "\31" or " ")
            end
        end
    end)
    return inner
end

--- Creates a list of entries that can each be selected with the Enter key.
---@param win window The window to draw on
---@param x number The X coordinate of the inside of the box
---@param y number The Y coordinate of the inside of the box
---@param width number The width of the inner box
---@param height number The height of the inner box
---@param entries string[] A list of entries to show, where the value is whether the item is pre-selected (or `"R"` for required/forced selected)
---@param action function|string A function or `run` event that's called when a selection is made
---@param selectChangeAction function|string|nil A function or `run` event that's called when the current selection is changed
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.selectionBox(win, x, y, width, height, entries, action, selectChangeAction, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, entries, "table")
    expect(7, action, "function", "string")
    expect(8, selectChangeAction, "function", "string", "nil")
    fgColor = expect(9, fgColor, "number", "nil") or colors.white
    bgColor = expect(10, bgColor, "number", "nil") or colors.black
    -- Check that all entries are strings.
    if #entries == 0 then error("bad argument #6 (table must not be empty)", 2) end
    for i, v in ipairs(entries) do
        if type(v) ~= "string" then error("bad item " .. i .. " in entries table (expected string, got " .. type(v), 2) end
    end
    -- Create container window.
    local entrywin = window.create(win, x, y, width - 1, height)
    local selection, scroll = 1, 1
    -- Create a function to redraw the entries on screen.
    local function drawEntries()
        -- Clear and set invisible for performance.
        entrywin.setVisible(false)
        entrywin.setBackgroundColor(bgColor)
        entrywin.clear()
        -- Draw each entry in the scrolled region.
        for i = scroll, scroll + height - 1 do
            -- Get the entry; stop if there's no more.
            local e = entries[i]
            if not e then break end
            -- Set the colors: invert if selected.
            entrywin.setCursorPos(2, i - scroll + 1)
            if i == selection then
                entrywin.setBackgroundColor(fgColor)
                entrywin.setTextColor(bgColor)
            else
                entrywin.setBackgroundColor(bgColor)
                entrywin.setTextColor(fgColor)
            end
            -- Draw the selection.
            entrywin.clearLine()
            entrywin.write(#e > width - 1 and e:sub(1, width - 4) .. "..." or e)
        end
        -- Draw scroll arrows.
        entrywin.setCursorPos(width, 1)
        entrywin.write(scroll > 1 and "\30" or " ")
        entrywin.setCursorPos(width, height)
        entrywin.write(scroll < #entries - height + 1 and "\31" or " ")
        -- Send updates to the screen.
        entrywin.setVisible(true)
    end
    -- Draw first screen.
    drawEntries()
    -- Add a task for selection keys.
    PrimeUI.addTask(function()
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.down and selection < #entries then
                -- Move selection down.
                selection = selection + 1
                if selection > scroll + height - 1 then scroll = scroll + 1 end
                -- Send action if necessary.
                if type(selectChangeAction) == "string" then PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                elseif selectChangeAction then selectChangeAction(selection) end
                -- Redraw screen.
                drawEntries()
            elseif key == keys.up and selection > 1 then
                -- Move selection up.
                selection = selection - 1
                if selection < scroll then scroll = scroll - 1 end
                -- Send action if necessary.
                if type(selectChangeAction) == "string" then PrimeUI.resolve("selectionBox", selectChangeAction, selection)
                elseif selectChangeAction then selectChangeAction(selection) end
                -- Redraw screen.
                drawEntries()
            elseif key == keys.enter then
                -- Select the entry: send the action.
                if type(action) == "string" then PrimeUI.resolve("selectionBox", action, entries[selection])
                else action(entries[selection]) end
            end
        end
    end)
end

--- Creates a text box that wraps text and can have its text modified later.
---@param win window The parent window of the text box
---@param x number The X position of the box
---@param y number The Y position of the box
---@param width number The width of the box
---@param height number The height of the box
---@param text string The initial text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
---@return function redraw A function to redraw the window with new contents
function PrimeUI.textBox(win, x, y, width, height, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, text, "string")
    fgColor = expect(7, fgColor, "number", "nil") or colors.white
    bgColor = expect(8, bgColor, "number", "nil") or colors.black
    -- Create the box window.
    local box = window.create(win, x, y, width, height)
    -- Override box.getSize to make print not scroll.
    function box.getSize()
        return width, math.huge
    end
    -- Define a function to redraw with.
    local function redraw(_text)
        expect(1, _text, "string")
        -- Set window parameters.
        box.setBackgroundColor(bgColor)
        box.setTextColor(fgColor)
        box.clear()
        box.setCursorPos(1, 1)
        -- Redirect and draw with `print`.
        local old = term.redirect(box)
        print(_text)
        term.redirect(old)
    end
    redraw(text)
    return redraw
end

--- Draws a line of text, centering it inside a box horizontally.
---@param win window The window to draw on
---@param x number The X position of the left side of the box
---@param y number The Y position of the box
---@param width number The width of the box to draw in
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.centerLabel(win, x, y, width, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, text, "string")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.black
    assert(#text <= width, "string is too long")
    win.setCursorPos(x + math.floor((width - #text) / 2), y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

--- Runs a function or action after the specified time period, with optional canceling.
---@param time number The amount of time to wait for, in seconds
---@param action function|string The function to call when the timer completes, or a `run` event to send
---@return function cancel A function to cancel the timer
function PrimeUI.timeout(time, action)
    expect(1, time, "number")
    expect(2, action, "function", "string")
    -- Start the timer.
    local timer = os.startTimer(time)
    -- Add a task to wait for the timer.
    PrimeUI.addTask(function()
        while true do
            -- Wait for a timer event.
            local _, tm = os.pullEvent("timer")
            if tm == timer then
                -- Fire the timer action.
                if type(action) == "string" then PrimeUI.resolve("timeout", action)
                else action() end
            end
        end
    end)
    -- Return a function to cancel the timer.
    return function() os.cancelTimer(timer) end
end

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function starts(start, num)
    return string.sub(start,1,num)
end

clear()

if fs.exists("/blackbird/vmdata") then
    vms = fs.list("/blackbird/vmdata")
else
    fs.makeDir("/blackbird/vmdata")
    vms = fs.list("/blackbird/vmdata")
end

mainUI = function()
PrimeUI.clear()
PrimeUI.label(term.current(), 3, 2, "blackbird VM")
PrimeUI.horizontalLine(term.current(), 3, 3, #("blackbird VM") + 2)
local entries2 = {
    "Create new VM",
    "Launch VM",
    "Config menu",
    "Delete VM"
}

local entries2_descriptions = {
    "Create a new VM",
    "Load into a VM",
    "Open the configuration menu",
    "Delete a VM"
}

local redraw = PrimeUI.textBox(term.current(), 3, 15, 40, 3, entries2_descriptions[1])
PrimeUI.borderBox(term.current(), 4, 6, 40, 8)
PrimeUI.selectionBox(term.current(), 4, 6, 40, 8, entries2, "done", function(option) redraw(entries2_descriptions[option]) end)
local _, _, selection = PrimeUI.run()

PrimeUI.clear()

clear()

if selection == "Create new VM" then
	PrimeUI.label(term.current(), 3, 5, "Enter VM name")
	PrimeUI.borderBox(term.current(), 4, 7, 40, 1)
	PrimeUI.inputBox(term.current(), 4, 7, 40, "result")
	local _, _, text = PrimeUI.run()
	if fs.exists("/blackbird/vmdata/"..text) then
		PrimeUI.clear()
		clear()
		print("VM with same name was already found. Rebooting")
		sleep(2)
		os.reboot()
	else
		PrimeUI.clear()
		clear()
		fs.makeDir("/blackbird/vmdata/"..text)
        fs.makeDir("/blackbird/vmconfigs/"..text)
        local startconfig = fs.open("/blackbird/vmconfigs/"..text.."/config.lua","w")
        startconfig.write("textnewID=1")
        startconfig.close()
	end
    mainUI()
elseif selection == "Launch VM" then
    vms = fs.list("/blackbird/vmdata")
    local vmname = {}
    for _,v in ipairs(vms) do
        table.insert(vmname,1,v)
    end

    local vmdesc = {}
    for _,_ in ipairs(vmname) do
        table.insert(vmdesc,1,"Load VM")
    end
    table.insert(vmname, #vmname+1, "Back")
    table.insert(vmdesc, #vmdesc+1, "Back")
    local redraw = PrimeUI.textBox(term.current(), 3, 15, 40, 3, vmdesc[1])
    PrimeUI.borderBox(term.current(), 4, 6, 40, 8)
    PrimeUI.selectionBox(term.current(), 4, 6, 40, 8, vmname, "done", function(option) redraw(vmdesc[option]) end)
    local _, _, selection = PrimeUI.run()
    if selection == "Back" then
        mainUI()
    elseif type(selection) == "string" then
        local cfgPath = "/blackbird/vmconfigs/" .. selection .. "/config.lua"
        if fs.exists(cfgPath) then
            local ok, err = pcall(dofile, cfgPath)
            if not ok then
                printError("Config error: " .. tostring(err))
            end
        end
        virfold = selection
        _G.virfold = virfold
        _ENV.virfold = virfold
    else
        mainUI()
    end
elseif selection == "Config menu" then
    vms = fs.list("/blackbird/vmdata")
    local vmname = {}
    for _,v in ipairs(vms) do
        table.insert(vmname,1,v)
    end

    local vmdesc = {}
    for _,_ in ipairs(vmname) do
        table.insert(vmdesc,1,"Config VM")
    end
    table.insert(vmname, #vmname+1, "Back")
    table.insert(vmdesc, #vmdesc+1, "Back")
    local redraw = PrimeUI.textBox(term.current(), 3, 15, 40, 3, vmdesc[1])
    PrimeUI.borderBox(term.current(), 4, 6, 40, 8)
    PrimeUI.selectionBox(term.current(), 4, 6, 40, 8, vmname, "done", function(option) redraw(vmdesc[option]) end)
    local _, _, selection = PrimeUI.run()
    if selection == "Back" then
        mainUI()
    end
    local configname = {
        "Edit ID",
        "Set shell",
        "List data"
    }

    local configdesc = {
        "Edit the computer's ID",
        "Set the shell to use",
        "List config data"
    }
    table.insert(configname, #configname+1, "Back")
    table.insert(configdesc, #configdesc+1, "Back")
    PrimeUI.clear()
    local redraw = PrimeUI.textBox(term.current(), 3, 15, 40, 3, configdesc[1])
    PrimeUI.borderBox(term.current(), 4, 6, 40, 8)
    PrimeUI.selectionBox(term.current(), 4, 6, 40, 8, configname, "done", function(option) redraw(configdesc[option]) end)
    local _, _, selection2 = PrimeUI.run()

    if selection2 == "Edit ID" then
        PrimeUI.clear()
        PrimeUI.label(term.current(), 3, 5, "Enter a new ID (number)")
        PrimeUI.borderBox(term.current(), 4, 7, 40, 1)
        PrimeUI.inputBox(term.current(), 4, 7, 40, "result")
local _, _, idResult = PrimeUI.run()

        if idResult and idResult ~= "" then
            _G.textnewID = tonumber(idResult) or idResult
        end
    elseif selection2 == "Set shell" then
        PrimeUI.clear()
        local shells = fs.list("/blackbird/shells")
        local shellnames = {}
        local shelldesc = {}
        for _, s in ipairs(shells) do
            if s:match("%.lua$") then
                local name = s:sub(1, -5)
                table.insert(shellnames, name)
                table.insert(shelldesc, "Use " .. name .. " shell")
            end
        end
        table.insert(shellnames, #shellnames+1, "Back")
        table.insert(shelldesc, #shelldesc+1, "Back")
        local redraw = PrimeUI.textBox(term.current(), 3, 15, 40, 3, shelldesc[1])
        PrimeUI.borderBox(term.current(), 4, 6, 40, 8)
        PrimeUI.selectionBox(term.current(), 4, 6, 40, 8, shellnames, "done", function(option) redraw(shelldesc[option]) end)
        local _, _, shellsel = PrimeUI.run()
        if not shellsel or shellsel == "Back" or type(shellsel) ~= "string" then
            mainUI()
            return
        end
        local shellPath = "blackbird/shells/" .. tostring(shellsel) .. ".lua"
        if fs.exists(shellPath) then
            _G.filelaunch = shellPath
            print("Shell set to: " .. _G.filelaunch)
        else
            printError("Shell file not found: " .. shellPath)
            mainUI()
            return
        end
    elseif selection2 == "Back" then
        mainUI()
    elseif selection2 == "List data" then
        PrimeUI.clear()
        clear()
        local cfgPath = "/blackbird/vmconfigs/" .. tostring(selection) .. "/config.lua"
        textnewID = textnewID or 1
        filelaunch = nil
        if fs.exists(cfgPath) then
            local oldID = textnewID
            local oldLaunch = filelaunch
            dofile(cfgPath)
            textnewID = textnewID or oldID
            filelaunch = filelaunch or oldLaunch
        end
        if filelaunch then
            iftruelaunch = "seagull launchfile: "..filelaunch
        else
            iftruelaunch = "No seagull launchfile"
        end

        local textdata = "ID: "..(textnewID or 1).."\n"..iftruelaunch
        
        PrimeUI.borderBox(term.current(), 4, 6, 40, 10)
        local scroller = PrimeUI.scrollBox(term.current(), 4, 6, 40, 10, 9000, true, true)
        PrimeUI.drawText(scroller, textdata, true)
        PrimeUI.button(term.current(), 3, 18, "Done", "done")
        PrimeUI.keyAction(keys.enter, "done")
        PrimeUI.run()
        mainUI()
    end

    local configdata = fs.open("/blackbird/vmconfigs/" .. tostring(selection) .. "/config.lua", "w")
    local idToSave = textnewID or 1
    configdata.write("textnewID=" .. tostring(idToSave))
    if filelaunch and type(filelaunch) == "string" then
        configdata.write("\nfilelaunch=" .. filelaunch)
    end
    configdata.close()
    mainUI()
elseif selection == "Delete VM" then
    vms = fs.list("/blackbird/vmdata/")
    local vmname = {}
    for _,v in ipairs(vms) do
        table.insert(vmname,1,v)
    end

    local vmdesc = {}
    for _,_ in ipairs(vmname) do
        table.insert(vmdesc,1,"Config VM")
    end
    table.insert(vmname, #vmname+1, "Back")
    table.insert(vmdesc, #vmdesc+1, "Back")
    local redraw = PrimeUI.textBox(term.current(), 3, 15, 40, 3, vmdesc[1])
    PrimeUI.borderBox(term.current(), 4, 6, 40, 8)
    PrimeUI.selectionBox(term.current(), 4, 6, 40, 8, vmname, "done", function(option) redraw(vmdesc[option]) end)
    local _, _, selection = PrimeUI.run()
    if selection == "Back" then
        mainUI()
    else
        fs.delete("/blackbird/vmdata/"..selection)
        fs.delete("/blackbird/vmconfigs/"..selection)
        mainUI()
    end
end
end
mainUI()

PrimeUI.clear()

local fs_combine = fs.combine
local oldfs = fs
local oldos = os
local oldrequire = require
local oldperipheral = peripheral
local oldpackage = package
_G.oldfs = oldfs
_G.oldperipheral = oldperipheral
_G.oldpackage = oldpackage
_G.fs = {}
_G.os = {}
_G.peripheral = {}
_G.package = oldpackage
for k, v in pairs(oldfs) do fs[k] = v end
for k, v in pairs(oldos) do os[k] = v end
for k, v in pairs(oldperipheral) do peripheral[k] = v end

local function wrappedRequire(modname)
    return oldrequire(modname)
end
_G.require = wrappedRequire
_ENV.require = wrappedRequire
_G.virfold = virfold
_ENV.virfold = virfold
_G.textnewID = textnewID or 1
_ENV.textnewID = textnewID or 1
_G.oldperipheral = oldperipheral
_G.oldfs = oldfs
_G.oldos = oldos
_G.oldpackage = oldpackage
local function getRealPeripheral()
    return oldperipheral
end
_ENV.getRealPeripheral = getRealPeripheral

local function isVM(path)
    if not virfold then return false end
    return string.find(path, "^/blackbird/vmdata/"..virfold) == 1
end

_ENV.os.getComputerID = function()
    return textnewID
end

_ENV.os.shutdown = function()
    _G.fs = oldfs
    _G.package = oldpackage
    _G.os = {}
    for k, v in pairs(oldos) do os[k] = v end
    _G.peripheral = oldperipheral
    _G.virfold = nil
    mainUI()
end

_ENV.os.reboot = function()
    _G.fs = oldfs
    _G.package = oldpackage
    _G.os = {}
    for k, v in pairs(oldos) do os[k] = v end
    _G.peripheral = oldperipheral
    _G.virfold = nil
    os.reboot()
end

_ENV.fs.open = function(path, mode)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs.combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.open(cleanRawPath, mode)
    elseif string.find(cleanRawPath, "blackbird/shells") then
        return oldfs.open(cleanRawPath, mode)
    else
        if isVM(cleanPath) == true then
            return oldfs.open(cleanPath, mode)
        else
            return nil
        end
    end
end

_ENV.fs.list = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs.combine(path)

    if starts(cleanRawPath,4) == "rom" then
        return oldfs.list(cleanRawPath) or {}
    elseif string.find(cleanRawPath, "blackbird/shells") then
        return oldfs.list(cleanRawPath) or {}
    elseif cleanRawPath == "" then
        local data = oldfs.list(cleanPath) or {}
        table.insert(data,1,"rom")
        if fs.exists("/blackbird/shells") then
            table.insert(data,1,"blackbird")
        end
        return data
    else
        if isVM(cleanPath) == true then
            return oldfs.list(cleanPath) or {}
        else
            return oldfs.list(cleanRawPath) or {}
        end
    end
end

_ENV.fs.find = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs.combine(path)
    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.find(cleanRawPath) or {}
    elseif string.find(cleanRawPath, "blackbird/shells") then
        return oldfs.find(cleanRawPath) or {}
    else
        local foundFiles = oldfs.find(cleanPath) or {}
        local modifiedPaths = {}

        for _, foundPath in ipairs(foundFiles) do
            local modifiedPath = string.gsub(foundPath, "^/blackbird/vmdata/"..virfold, "")
            table.insert(modifiedPaths, modifiedPath)
        end

        return modifiedPaths
    end
end

_ENV.fs.isDir = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs.combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.isDir(cleanRawPath) or false
    elseif cleanRawPath == "rom" or cleanRawPath == "blackbird" then
        return true
    elseif isVM(cleanPath) == true then
        return oldfs.isDir(cleanPath) or false
else
        return false
    end
end

_ENV.fs.copy = function(path,dest)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanDest = fs_combine("/blackbird/vmdata/"..virfold, dest)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.copy(cleanRawPath,cleanDest)
    else
        if isVM(cleanPath) == true then
            return oldfs.copy(cleanPath, cleanDest)
        else
            return nil
        end
    end
end

_ENV.fs.delete = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        print(cleanRawPath)
        return oldfs.delete(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.delete(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.attributes = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.attributes(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.attributes(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.getCapacity = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.getCapacity(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.getCapacity(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.getFreeSpace = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.getFreeSpace(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.getFreeSpace(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.getDrive = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.getDrive(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.getDrive(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.move = function(path,dest)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanDest = fs_combine("/blackbird/vmdata/"..virfold, dest)
    local cleanRawPath = fs_combine(path)

    if isVM(cleanPath) == true then
        if isVM(cleanDest) == true then
            oldfs.move(cleanPath,cleanDest)
        else
            return nil
        end
    elseif cleanRawPath == "rom/" then
        if isVM(cleanDest) then
            return oldfs.move(cleanRawPath,cleanDest)
        else
            return nil
        end
    else
        return nil
    end
end

_ENV.fs.makeDir = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.makeDir(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.makeDir(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.isReadOnly = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.isReadOnly(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.isReadOnly(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.getSize = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.getSize(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.getSize(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.isDriveRoot = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs_combine(path)

    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.isDriveRoot(cleanRawPath)
    else
        if isVM(cleanPath) == true then
            return oldfs.isDriveRoot(cleanPath)
        else
            return nil
        end
    end
end

_ENV.fs.exists = function(path)
    local cleanPath = fs_combine("/blackbird/vmdata/"..virfold, path)
    local cleanRawPath = fs.combine(path)
    if starts(cleanRawPath,4) == "rom/" then
        return oldfs.exists(cleanRawPath) or false
    elseif starts(cleanRawPath,9) == "/blackbird" then
        return oldfs.exists(cleanRawPath) or false
    else
        return oldfs.exists(cleanPath) or false
    end
end

-- dbprotect.lua - Protect your functions from the debug library
-- By JackMacWindows
-- Licensed under CC0, though I'd appreciate it if this notice was left in place.

-- Simply run this file in some fashion, then call `debug.protect` to protect a function.
-- It takes the function as the first argument, as well as a list of functions
-- that are still allowed to access the function's properties.
-- Once protected, access to the function's environment, locals, and upvalues is
-- blocked from all Lua functions. A function *can not* be unprotected without
-- restarting the Lua state.
-- The debug library itself is protected too, so it's not possible to remove the
-- protection layer after being installed.
-- It's also not possible to add functions to the whitelist after protecting, so
-- make sure everything that needs to access the function's properties are added.

if not dbprotect then
    local protectedObjects
    local n_getfenv, n_setfenv, d_getfenv, getlocal, getupvalue, d_setfenv, setlocal, setupvalue, upvaluejoin =
        getfenv, setfenv, debug.getfenv, debug.getlocal, debug.getupvalue, debug.setfenv, debug.setlocal, debug.setupvalue, debug.upvaluejoin

    local error, getinfo, running, select, setmetatable, type, tonumber = error, debug.getinfo, coroutine.running, select, setmetatable, type, tonumber

    local superprotected

    local function keys(t, v, ...)
        if v then t[v] = true end
        if select("#", ...) > 0 then return keys(t, ...)
        else return t end
    end

    local function superprotect(v, ...)
        if select("#", ...) > 0 then return superprotected[v or ""] or v, superprotect(...)
        else return superprotected[v or ""] or v end
    end

    function debug.getinfo(thread, func, what)
        if type(thread) ~= "thread" then what, func, thread = func, thread, running() end
        local retval
        if tonumber(func) then retval = getinfo(thread, func+1, what)
        else retval = getinfo(thread, func, what) end
        if retval and retval.func then retval.func = superprotected[retval.func] or retval.func end
        return retval
    end

    function debug.getlocal(thread, level, loc)
        if loc == nil then loc, level, thread = level, thread, running() end
        local k, v
        if type(level) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[level] and not (caller and protectedObjects[level][caller.func]) then return nil end
            k, v = superprotect(getlocal(level, loc))
        elseif tonumber(level) then
            local info = getinfo(thread, level + 1, "f")
            local caller = getinfo(2, "f")
            if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then return nil end
            k, v = superprotect(getlocal(thread, level + 1, loc))
        else k, v = superprotect(getlocal(thread, level, loc)) end
        return k, v
    end

    function debug.getupvalue(func, up)
        if type(func) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[func] and not (caller and protectedObjects[func][caller.func]) then return nil end
        end
        local k, v = superprotect(getupvalue(func, up))
        return k, v
    end

    function debug.setlocal(thread, level, loc, value)
        if loc == nil then loc, level, thread = level, thread, running() end
        if tonumber(level) then
            local info = getinfo(thread, level + 1, "f")
            local caller = getinfo(2, "f")
            if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then error("attempt to set local of protected function", 2) end
            setlocal(thread, level + 1, loc, value)
        else setlocal(thread, level, loc, value) end
    end

    function debug.setupvalue(func, up, value)
        if type(func) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[func] and not (caller and protectedObjects[func][caller.func]) then error("attempt to set upvalue of protected function", 2) end
        end
        setupvalue(func, up, value)
    end

    function _G.getfenv(f)
        local v
        if f == nil then v = n_getfenv(2)
        elseif tonumber(f) and tonumber(f) > 0 then
            local info = getinfo(f + 1, "f")
            local caller = getinfo(2, "f")
            if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then return nil end
            v = n_getfenv(f+1)
        elseif type(f) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[f] and not (caller and protectedObjects[f][caller.func]) then return nil end
            v = n_getfenv(f)
        else v = n_getfenv(f) end
        return v
    end

    function _G.setfenv(f, tab)
        if tonumber(f) then
            local info = getinfo(f + 1, "f")
            local caller = getinfo(2, "f")
            if info and protectedObjects[info.func] and not (caller and protectedObjects[info.func][caller.func]) then error("attempt to set environment of protected function", 2) end
            n_setfenv(f+1, tab)
        elseif type(f) == "function" then
            local caller = getinfo(2, "f")
            if protectedObjects[f] and not (caller and protectedObjects[f][caller.func]) then error("attempt to set environment of protected function", 2) end
        end
        n_setfenv(f, tab)
    end

    if d_getfenv then
        function debug.getfenv(o)
            if type(o) == "function" then
                local caller = getinfo(2, "f")
                if protectedObjects[o] and not (caller and protectedObjects[o][caller.func]) then return nil end
            end
            local v = d_getfenv(o)
            return v
        end

        function debug.setfenv(o, tab)
            if type(o) == "function" then
                local caller = getinfo(2, "f")
                if protectedObjects[o] and not (caller and protectedObjects[o][caller.func]) then error("attempt to set environment of protected function", 2) end
            end
            d_setfenv(o, tab)
        end
    end

    if upvaluejoin then
        function debug.upvaluejoin(f1, n1, f2, n2)
            if type(f1) == "function" and type(f2) == "function" then
                local caller = getinfo(2, "f")
                if protectedObjects[f1] and not (caller and protectedObjects[f1][caller.func]) then error("attempt to get upvalue of protected function", 2) end
                if protectedObjects[f2] and not (caller and protectedObjects[f2][caller.func]) then error("attempt to set upvalue of protected function", 2) end
            end
            upvaluejoin(f1, n1, f2, n2)
        end
    end

    function debug.protect(func, ...)
        if type(func) ~= "function" then error("bad argument #1 (expected function, got " .. type(func) .. ")", 2) end
        if protectedObjects[func] then error("attempt to protect a protected function", 2) end
        protectedObjects[func] = keys(setmetatable({}, {__mode = "k"}), ...)
    end

    superprotected = {
        [n_getfenv] = _G.getfenv,
        [n_setfenv] = _G.setfenv,
        [d_getfenv] = debug.getfenv,
        [d_setfenv] = debug.setfenv,
        [getlocal] = debug.getlocal,
        [setlocal] = debug.setlocal,
        [getupvalue] = debug.getupvalue,
        [setupvalue] = debug.setupvalue,
        [upvaluejoin] = debug.upvaluejoin,
        [getinfo] = debug.getinfo,
        [superprotect] = function() end,
    }

    protectedObjects = keys(setmetatable({}, {__mode = "k"}),
        getfenv,
        setfenv,
        debug.getfenv,
        debug.setfenv,
        debug.getlocal,
        debug.setlocal,
        debug.getupvalue,
        debug.setupvalue,
        debug.upvaluejoin,
        debug.getinfo,
        superprotect,
        debug.protect
    )
    for k,v in pairs(protectedObjects) do protectedObjects[k] = {} end
end

for functionName, func in pairs(fs) do
    term.setTextColor(colors.lightGray)
    io.write("[")
    term.setTextColor(colors.yellow)
    io.write("LOAD")
    term.setTextColor(colors.lightGray)
    io.write("] ")
    term.setTextColor(colors.white)
    io.write(functionName)
    print("")
    local function trytoprotect()
        debug.protect(func)
    end
    local v, message = pcall(trytoprotect)
    if v == true then
        term.setTextColor(colors.lightGray)
        io.write("[")
        term.setTextColor(colors.green)
        io.write("OK")
        term.setTextColor(colors.lightGray)
        io.write("] ")
        term.setTextColor(colors.white)
        io.write(functionName)
        print("")
    else
        term.setTextColor(colors.lightGray)
        io.write("[")
        term.setTextColor(colors.red)
        io.write("FAIL")
        term.setTextColor(colors.lightGray)
        io.write("] ")
        term.setTextColor(colors.white)
        io.write(functionName)
        print("")
    end
end

debug.protect(os.getComputerID)

-- Expose all CC:Tweaked libraries to the VM. See https://tweaked.cc/ for the
-- authoritative API docs. Most of these are already global in CC (we only
-- replaced fs/os/peripheral above); this block makes exposure explicit and
-- surfaces any missing library at boot instead of at first use.
local ccLibraries = {
    "colors", "colours", "commands", "disk", "gps", "help", "http", "io",
    "keys", "multishell", "paintutils", "parallel", "pocket", "rednet",
    "redstone", "settings", "term", "textutils", "turtle", "vector", "window",
}
for _, libName in ipairs(ccLibraries) do
    local host = rawget(_G, libName)
    if host == nil then host = _ENV[libName] end
    if host ~= nil then
        _G[libName] = host
        _ENV[libName] = host
        term.setTextColor(colors.lightGray)
        io.write("[")
        term.setTextColor(colors.green)
        io.write("API ")
        term.setTextColor(colors.lightGray)
        io.write("] ")
        term.setTextColor(colors.white)
        print(libName)
    else
        term.setTextColor(colors.lightGray)
        io.write("[")
        term.setTextColor(colors.yellow)
        io.write("skip")
        term.setTextColor(colors.lightGray)
        io.write("] ")
        term.setTextColor(colors.white)
        print(libName .. " (not available on this host)")
    end
end

-- Pre-load require-able cc.* modules so they're cached and guaranteed to
-- resolve from within the sandbox.
local ccModules = {
    "cc.audio.dfpwm", "cc.completion", "cc.expect", "cc.image.nft",
    "cc.pretty", "cc.require", "cc.shell.completion", "cc.strings",
}
for _, modName in ipairs(ccModules) do
    local ok = pcall(oldrequire, modName)
    term.setTextColor(colors.lightGray)
    io.write("[")
    if ok then
        term.setTextColor(colors.green)
        io.write(" OK ")
    else
        term.setTextColor(colors.yellow)
        io.write("skip")
    end
    term.setTextColor(colors.lightGray)
    io.write("] ")
    term.setTextColor(colors.white)
    print(modName)
end

sleep(2)

clear()

term.setTextColor(colors.yellow)
print("blackbird VM")
print(ver)

if filelaunch then
    os.run({}, filelaunch)
else
    os.run({}, "rom/programs/shell.lua")
end
_G.fs = oldfs
    _G.package = oldpackage
local data
if fs.exists("/disk/keys/blackbird") then
    file = fs.open("/disk/keys/blackbird", "r")
    data = f
end
if data ~= "someuuid" then
    os.run({}, "blackbird/init.lua")
end
print("admin found exiting blackbird VM")