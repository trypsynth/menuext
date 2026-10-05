local MenuExt = {}

MenuExt.name = "Menu Extras Helper"
MenuExt.version = "1.1"
MenuExt.author = "Quin Marilyn <quin.marilyn05@gmail.com>"
MenuExt.license = "MIT"

local synth = hs.speech.new()

local function speak(text)
    if hs.application.get("VoiceOver") ~= nil then
        hs.osascript.applescript(
            "tell application \"VoiceOver\" to output \""
                .. text:gsub("\"", "\\\"")
                .. "\""
        )
    else
        synth:speak(text)
    end
end

-- Friendly names for macOS's own menu extras. On recent macOS these are
-- unlabelled groups owned by "MenuBarAgent", with the real item, identified as
-- com.apple.menuextra.<name>, inside. Unknown ones are named from the
-- identifier ("screen-mirroring" becomes "Screen mirroring").
local systemNames = {
    ["airdrop"] = "AirDrop",
    ["battery"] = "Battery",
    ["bluetooth"] = "Bluetooth",
    ["clock"] = "Clock",
    ["controlcenter"] = "Control Center",
    ["display"] = "Display",
    ["focusmodes"] = "Focus",
    ["now-playing"] = "Now Playing",
    ["screenmirroring"] = "Screen Mirroring",
    ["siri"] = "Siri",
    ["sound"] = "Sound",
    ["spotlight"] = "Spotlight",
    ["textinput"] = "Input menu",
    ["timemachine"] = "Time Machine",
    ["user"] = "Fast User Switching",
    ["vpn"] = "VPN",
    ["wifi"] = "Wi-Fi",
}

-- Apps whose name is all there is to go on, and isn't much use.
local appNames = {
    ["TextInputMenuAgent"] = "Input menu",
}

local function systemName(identifier)
    local key = identifier:match("^com%.apple%.menuextra%.(.+)$")
    if not key then
        return nil
    end
    if systemNames[key] then
        return systemNames[key]
    end
    local words = key:gsub("[-_.]", " ")
    return words:sub(1, 1):upper() .. words:sub(2)
end

-- What to call a menu extra, and the element to press to open it. Text from
-- several attributes is joined, skipping blanks and repeats (many extras give
-- the same text as both title and description).
local function describe(application, extra)
    local parts, seen = {}, {}
    local function add(value)
        if type(value) ~= "string" then
            return
        end
        value = value:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        if value ~= "" and not seen[value] then
            seen[value] = true
            table.insert(parts, value)
        end
    end
    local target = extra
    for _, attr in ipairs({ "AXTitle", "AXDescription", "AXValue", "AXHelp" }) do
        add(extra[attr])
    end
    if #parts == 0 then
        for _, child in ipairs(extra.AXChildren or {}) do
            local name = child.AXIdentifier and systemName(child.AXIdentifier)
            if name then
                add(name)
                add(child.AXDescription)
                add(child.AXValue)
                target = child
                break
            end
        end
    end
    if #parts == 0 then
        add(appNames[application:name()] or application:name())
    end
    return table.concat(parts, ", "), target
end

local function getMenuExtras()
    local extras = {}
    for _, application in ipairs(hs.application.runningApplications()) do
        local element = hs.axuielement.applicationElement(application)
        local appExtras = element and element.AXExtrasMenuBar
        for appIndex, extra in ipairs(appExtras or {}) do
            local label, target = describe(application, extra)
            local position = extra.AXPosition
            table.insert(extras, {
                application = application,
                target = target,
                label = label,
                x = position and position.x or math.huge,
                order = #extras,
                appIndex = appIndex,
            })
        end
    end
    -- Left to right; items without a position (hidden) go last.
    table.sort(extras, function(first, second)
        if first.x ~= second.x then
            return first.x < second.x
        end
        return first.order < second.order
    end)
    return extras
end

-- Ten items per page: the modifiers (see MenuExt.modifiers) with 1 to 9 and 0
-- are slots 1 to 10 of the current page. With equals (the last key of the
-- number row) they move to the next page, and with grave (the first) to the
-- previous one; otherwise the page stays put.
local pageSize = 10
local page = 1

-- Press a slot's key once to hear it, twice in quick succession to open it.
local doublePressTime = 0.5
local lastSlot, lastPressTime = nil, 0

local function open(item)
    if item.application:pid() == hs.processInfo.processID then
        -- Hammerspoon's own items: asking itself to press one would wait on
        -- itself, so a separate process clicks it instead.
        hs.task.new("/usr/bin/osascript", nil, {
            "-e",
            "tell application \"System Events\" to click menu bar item "
                .. item.appIndex
                .. " of menu bar 2 of (first process whose unix id is "
                .. hs.processInfo.processID
                .. ")",
        }):start()
    else
        item.target:performAction("AXPress")
    end
end

-- The menu extras, left to right, as {label = ..., application = ...} tables,
-- for use from other scripts.
function MenuExt.menuExtras()
    return getMenuExtras()
end

local function slotPressed(key)
    local slot = (page - 1) * pageSize + (key == 0 and 10 or key)
    local now = hs.timer.secondsSinceEpoch()
    local doublePress = slot == lastSlot and now - lastPressTime < doublePressTime
    lastSlot, lastPressTime = slot, now

    local extras = getMenuExtras()
    local item = extras[slot]
    if not item then
        speak("No menu extra " .. slot .. ". There are " .. #extras .. ".")
        return
    end
    if doublePress then
        lastSlot = nil
        open(item)
    else
        speak(item.label)
    end
end

local function nextPage()
    local count = #getMenuExtras()
    local pages = math.max(1, math.ceil(count / pageSize))
    if page >= pages then
        speak("No more menu extras. Page " .. page .. " of " .. pages .. ".")
        return
    end
    page = page + 1
    local first = (page - 1) * pageSize + 1
    speak("Page " .. page .. ", menu extras " .. first .. " to " .. math.min(count, page * pageSize) .. ".")
end

local function previousPage()
    if page <= 1 then
        speak("Already on page 1.")
        return
    end
    page = page - 1
    local first = (page - 1) * pageSize + 1
    speak("Page " .. page .. ", menu extras " .. first .. " to " .. page * pageSize .. ".")
end

-- The modifier keys held with the number row. Set this before calling
-- start(), as a list or a single string:
--   spoon.MenuExt.modifiers = {"ctrl", "opt"}
--   spoon.MenuExt.modifiers = "CTRL+OPT"
-- Names (any case): CTRL, OPT, CMD, SHIFT (CONTROL, CTL, OPTION, ALT and
-- COMMAND also work). Put L or R in front for one side only, e.g. ROPT, LCMD,
-- RCTRL (or RCTL). Option-Shift, the default, types a character with a number
-- on most layouts, which can't then be typed; Control-Option doesn't, but is
-- VoiceOver's modifier unless you've moved that to Caps Lock.
MenuExt.modifiers = { "opt", "shift" }

local log = hs.logger.new("MenuExt")

local modifierNames = {
    ctrl = "ctrl", control = "ctrl", ctl = "ctrl",
    opt = "alt", option = "alt", alt = "alt",
    cmd = "cmd", command = "cmd",
    shift = "shift",
}

-- Each modifier's left and right bits in a key event's raw flags (IOLLEvent.h).
local sideBits = {
    ctrl = { left = 0x00000001, right = 0x00002000 },
    shift = { left = 0x00000002, right = 0x00000004 },
    cmd = { left = 0x00000008, right = 0x00000010 },
    alt = { left = 0x00000020, right = 0x00000040 },
}

-- {{name = "ctrl"|"alt"|"cmd"|"shift", side = nil|"left"|"right"}, ...}, or
-- nil and a message if a name isn't recognised.
local function parseModifiers(spec)
    local tokens = {}
    if type(spec) == "string" then
        for token in spec:gmatch("[^%s+,]+") do
            table.insert(tokens, token)
        end
    else
        tokens = spec or {}
    end
    local parsed = {}
    for _, token in ipairs(tokens) do
        local lower = tostring(token):lower()
        local name, side = modifierNames[lower], nil
        if not name then
            local prefix, rest = lower:match("^([lr])(.+)$")
            if prefix and modifierNames[rest] then
                name, side = modifierNames[rest], prefix == "l" and "left" or "right"
            end
        end
        if not name then
            return nil, "unknown modifier \"" .. tostring(token) .. "\""
        end
        table.insert(parsed, { name = name, side = side })
    end
    return parsed
end

MenuExt.parseModifiers = parseModifiers

local hotkeys = {}
local sidedTap
local pendingAction
local warmUp

local function keyActions()
    local actions = {}
    for i = 0, 9 do
        actions[tostring(i)] = function()
            slotPressed(i)
        end
    end
    actions["="] = nextPage
    actions["`"] = previousPage
    return actions
end

-- Ordinary modifiers: Hammerspoon hotkeys.
local function bindHotkeys(modifiers)
    local names = {}
    for _, modifier in ipairs(modifiers) do
        table.insert(names, modifier.name)
    end
    for key, action in pairs(keyActions()) do
        local hotkey = hs.hotkey.new(names, key, action)
        hotkey:enable()
        table.insert(hotkeys, hotkey)
    end
end

-- One-sided modifiers: hotkeys can't tell left from right, so watch key
-- presses on the number row and check the raw flags.
local function watchSidedKeys(modifiers)
    local wanted = {}
    for _, modifier in ipairs(modifiers) do
        wanted[modifier.name] = true
    end
    local actions = {}
    for key, action in pairs(keyActions()) do
        actions[hs.keycodes.map[key]] = action
    end
    local autorepeat = hs.eventtap.event.properties.keyboardEventAutorepeat
    sidedTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local action = actions[event:getKeyCode()]
        if not action then
            return false
        end
        local flags = event:getFlags()
        for _, name in ipairs({ "ctrl", "alt", "cmd", "shift" }) do
            if (flags[name] or false) ~= (wanted[name] or false) then
                return false
            end
        end
        local raw = event:rawFlags()
        for _, modifier in ipairs(modifiers) do
            if modifier.side and raw & sideBits[modifier.name][modifier.side] == 0 then
                return false
            end
        end
        if event:getProperty(autorepeat) == 0 then
            -- Not inside the tap: looking up menu extras can take a moment.
            pendingAction = hs.timer.doAfter(0, action)
        end
        return true
    end)
    sidedTap:start()
end

function MenuExt.start()
    MenuExt.stop()
    local modifiers, problem = parseModifiers(MenuExt.modifiers)
    if not modifiers then
        log.e(problem .. "; using Option-Shift")
        modifiers = parseModifiers({ "opt", "shift" })
    end
    local sided = false
    for _, modifier in ipairs(modifiers) do
        sided = sided or modifier.side ~= nil
    end
    if sided then
        watchSidedKeys(modifiers)
    else
        bindHotkeys(modifiers)
    end
    -- The first look at each app's menu extras is slow (a second or two in
    -- all); do it shortly after starting rather than on the first key press.
    warmUp = hs.timer.doAfter(5, getMenuExtras)
end

function MenuExt.stop()
    for _, hotkey in ipairs(hotkeys) do
        hotkey:delete()
    end
    hotkeys = {}
    if sidedTap then
        sidedTap:stop()
        sidedTap = nil
    end
    if warmUp then
        warmUp:stop()
    end
end

return MenuExt
