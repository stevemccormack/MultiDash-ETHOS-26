local i18n = assert(loadfile("i18n.lua"))()
local summaryModule
local summaryApi
local LINK_MIN_GRACE = 5
local AUDIO_PATH = "SCRIPTS:/MultiDash/audio/"
local currentFont
local pairedFooterFont
local currentFontSetting = 2
local currentTextScale = 1
local metricText, metricFont, metricW, metricH
local TEXT_SCALE_SMALL, TEXT_SCALE_MEDIUM, TEXT_SCALE_LARGE = 0.82, 1.70, 2.28
local fontS, fontL, fontXL, fontXXL = _G.FONT_S, _G.FONT_L, _G.FONT_XL, _G.FONT_XXL
local MAX_MODEL_IMAGE_BYTES = 350 * 1024
local MAX_MODEL_IMAGE_WIDTH, MAX_MODEL_IMAGE_HEIGHT = 480, 320
local MIN_MODEL_IMAGE_RAM = MAX_MODEL_IMAGE_WIDTH * MAX_MODEL_IMAGE_HEIGHT * 2 + 128 * 1024

local function preset(small, medium, large)
    return currentFontSetting == 1 and small or (currentFontSetting == 3 and large or medium)
end
local function gaugeFooterHeight() return preset(28, 36, 44) end
local T = i18n.text
local function playCue(name)
    local fn = system and system.playFile
    if type(fn) == "function" then
        pcall(fn, AUDIO_PATH .. name .. ".wav")
    end
end
local drawText = lcd.drawText
local function textMetrics(txt)
    txt = tostring(txt or "")
    if txt ~= metricText or currentFont ~= metricFont then
        metricText, metricFont = txt, currentFont
        metricW, metricH = lcd.getTextSize(txt)
    end
    return metricW or 0, metricH or 18
end
local function getTextW(txt)
    return textMetrics(txt)
end
local function getTextH(txt)
    local _, h = textMetrics(txt)
    return h
end
local function finiteNumber(v)
    if type(v) == "boolean" then return v and 1 or 0 end
    v = tonumber(v)
    return v and v == v and v ~= math.huge and v ~= -math.huge and v or nil
end
local function clamp(v, lo, hi)
    v = tonumber(v) or 0
    if lo and v < lo then
        v = lo
    end
    if hi and v > hi then
        v = hi
    end
    return v
end
local function scaleFor(w, h)
    w, h = math.floor(finiteNumber(w) or 0), math.floor(finiteNumber(h) or 0)
    if w == 472 and (h == 191 or h == 210) then
        return 0.45
    end
    local ratio = h > 0 and w / h or 0
    if w >= 460 and h >= 185 and ratio >= 1.95 and ratio <= 3.35 then
        return 0.45
    end
    return clamp(math.min(w / 800, h / 480), 0.45, 1.35)
end
local function windowSize(a, b, c, d)
    local w, h
    if type(a) == "table" then
        w = a.w or a.width or a[3]
        h = a.h or a.height or a[4]
    elseif type(c) == "number" and type(d) == "number" then
        w, h = c, d
    elseif type(a) == "number" and type(b) == "number" then
        w, h = a, b
    end
    if (not w or not h) and lcd and type(lcd.getWindowSize) == "function" then
        local ok, x, y, lw, lh = pcall(lcd.getWindowSize)
        if ok then
            if type(lw) == "number" and type(lh) == "number" then
                w, h = lw, lh
            elseif type(x) == "table" then
                w = x.w or x.width or x[3]
                h = x.h or x.height or x[4]
            else
                w, h = x, y
            end
        end
    end
    return finiteNumber(w) or 480, finiteNumber(h) or 320
end
local function isUsableWidgetSize(w, h)
    w, h = math.floor(w), math.floor(h)
    if (w == 784 and (h == 236 or h == 258 or h == 270 or h == 294 or h == 316))
        or (w == 472 and (h == 191 or h == 210))
        or (w == 630 and (h == 236 or h == 258)) then
        return true
    end
    if w < 460 or h < 185 then return false end
    local ratio = w / h
    return ratio >= 1.45 and ratio <= 3.35
end
local function railWidthFor(w)
    local ratio = preset(0.28, 0.31, 0.35)
    if w >= 900 then
        ratio = ratio + 0.01
    elseif w >= 600 and w < 760 then
        ratio = ratio - 0.01
    end
    return clamp(math.floor(w * ratio), math.floor(w * 0.27), math.floor(w * 0.36))
end
local function px(v, scale, lo, hi)
    local n = math.floor(v * scale + 0.5)
    if hi and lo and hi < lo then
        lo = hi
    end
    if lo and n < lo then n = lo end
    if hi and n > hi then n = hi end
    return n
end
local function roundPanel(x, y, w, h, fill, outline)
    if w <= 0 or h <= 0 then return end
    if outline and w > 2 and h > 2 then
        lcd.color(outline)
        lcd.drawFilledRectangle(x, y, w, h)
        lcd.color(fill)
        lcd.drawFilledRectangle(x + 1, y + 1, w - 2, h - 2)
    else
        lcd.color(fill)
        lcd.drawFilledRectangle(x, y, w, h)
    end
end
local palettes = {
    dark = {
        bg = lcd.RGB(13, 18, 23),
        panel = lcd.RGB(25, 32, 39),
        panelAlt = lcd.RGB(33, 42, 51),
        text = lcd.RGB(245, 248, 250),
        muted = lcd.RGB(148, 163, 178),
        secondary = lcd.RGB(203, 213, 225),
        neutral = lcd.RGB(226, 232, 240),
        outline = lcd.RGB(78, 96, 113),
        barFrame = lcd.RGB(91, 108, 124),
        batteryEmpty = lcd.RGB(12, 16, 20),
        good = lcd.RGB(48, 209, 133),
        warn = lcd.RGB(255, 174, 66),
        bad = lcd.RGB(255, 90, 90),
        alertBg = lcd.RGB(34, 8, 12),
        alertOutline = lcd.RGB(255, 90, 90),
        alertText = lcd.RGB(255, 235, 238),
    },
    light = {
        bg = lcd.RGB(235, 240, 245),
        panel = lcd.RGB(255, 255, 255),
        panelAlt = lcd.RGB(226, 233, 240),
        text = lcd.RGB(21, 30, 40),
        muted = lcd.RGB(78, 91, 105),
        secondary = lcd.RGB(61, 74, 88),
        neutral = lcd.RGB(42, 55, 69),
        outline = lcd.RGB(151, 165, 180),
        barFrame = lcd.RGB(120, 135, 150),
        batteryEmpty = lcd.RGB(222, 228, 235),
        good = lcd.RGB(0, 145, 91),
        warn = lcd.RGB(205, 104, 0),
        bad = lcd.RGB(200, 40, 55),
        alertBg = lcd.RGB(255, 239, 241),
        alertOutline = lcd.RGB(200, 40, 55),
        alertText = lcd.RGB(150, 18, 35),
    },
}
local function theme(widget)
    return widget and tonumber(widget.themeMode) == 2 and palettes.light or palettes.dark
end
local function setAvailableFont(a, b, c, d)
    local font = a or b or c or d
    if font == nil or font == currentFont then return end
    currentFont = font
    lcd.font(font)
end
local function setExactFont(font)
    if font == nil or font == currentFont then return end
    currentFont = font
    lcd.font(font)
end
local function setFontSize(size)
    if currentFontSetting == 1 then
        if size == "huge" then setAvailableFont(fontL, fontXL, fontXXL, fontS)
        else setAvailableFont(fontS, fontL, fontXL) end
    elseif currentFontSetting == 3 then
        if size == "huge" then setAvailableFont(fontXXL, fontXL, fontL, fontS)
        else setAvailableFont(fontXL, fontL, fontS) end
    else
        if size == "huge" then setAvailableFont(fontXL, fontXXL, fontL, fontS)
        else setAvailableFont(fontL, fontS, fontXL) end
    end
end
local function textFits(text, maxW, maxH)
    local width, height = textMetrics(text)
    return (not maxW or width <= maxW) and (not maxH or height <= maxH)
end
local function setFittingFont(size, text, maxW, maxH)
    setFontSize(size)
    if textFits(text, maxW, maxH) then return end
    if size == "huge" then
        setFontSize("small")
        if currentFontSetting == 1 or textFits(text, maxW, maxH) then return end
    end
    if currentFontSetting == 3 then
        setAvailableFont(fontL, fontS, fontXL)
        if textFits(text, maxW, maxH) then return end
    end
    setAvailableFont(fontS, fontL, fontXL, fontXXL)
end
local fitText
local function drawSizePrompt(w, c, scale, scrW, scrH)
    lcd.color(c.bg)
    lcd.drawFilledRectangle(0, 0, scrW, scrH)
    local msg = T(w, "Use Single Large Widget")
    setFittingFont("huge", msg, math.max(1, scrW - 12), math.max(1, scrH - 4))
    msg = fitText(msg, math.max(1, scrW - 12))
    local tw = getTextW(msg) or 0
    local x = math.max(0, math.floor((scrW - tw) / 2))
    local y = math.max(0, math.floor(scrH / 2) - px(18, scale, 10, 24))
    lcd.color(c.bad)
    drawText(x, y, msg)
    for i = 1, px(2, scale, 1, 3) do
        drawText(x + i, y, msg)
    end
end
local bitmapScaleSupported
local bitmapBasicSupported
local defaultIconBmp
local defaultIconAttempted = false
local function drawBitmapBox(x, y, w, h, bmp)
    if not bmp then
        return
    end
    if bitmapScaleSupported == true then
        lcd.drawBitmap(x, y, bmp, w, h)
        return
    elseif bitmapScaleSupported == nil then
        local ok = pcall(lcd.drawBitmap, x, y, bmp, w, h)
        bitmapScaleSupported = ok
        if ok then
            return
        end
    end
    local bmpW, bmpH = w, h
    if type(bmp.width) == "function" then
        local ok, value = pcall(bmp.width, bmp)
        if ok and value then bmpW = value end
    end
    if type(bmp.height) == "function" then
        local ok, value = pcall(bmp.height, bmp)
        if ok and value then bmpH = value end
    end
    local bx = x + math.max(0, math.floor((w - bmpW) / 2))
    local by = y + math.max(0, math.floor((h - bmpH) / 2))
    if type(lcd.setClipping) == "function" then
        pcall(lcd.setClipping, x, y, w, h)
    end
    if bitmapBasicSupported == true then
        lcd.drawBitmap(bx, by, bmp)
    elseif bitmapBasicSupported == nil then
        local ok = pcall(lcd.drawBitmap, bx, by, bmp)
        bitmapBasicSupported = ok
    end
    if type(lcd.setClipping) == "function" then
        pcall(lcd.setClipping)
    end
end
local function polarPoint(cx, cy, deg, radius)
    local angle = deg * 0.017453292519943
    local x, y = math.cos(angle) * radius, math.sin(angle) * radius
    x = x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
    y = y >= 0 and math.floor(y + 0.5) or math.ceil(y - 0.5)
    return cx + x, cy + y
end
local function drawHeavyLine(x1, y1, x2, y2)
    lcd.drawLine(x1, y1, x2, y2)
    lcd.drawLine(x1 + 1, y1, x2 + 1, y2)
end
local function drawHeavyText(x, y, text, weight)
    drawText(x, y, text)
    if weight and weight > 0 then drawText(x + 1, y, text) end
end
local function member(obj, key) return obj[key] end
local function safeMember(obj, key)
    local ok, value = pcall(member, obj, key)
    return ok and value or nil
end
local function getVal(src)
    if not src then
        return 0, false
    end
    local t = type(src)
    if t == "number" or t == "string" or t == "boolean" then
        local value = finiteNumber(src)
        return value or 0, value ~= nil
    end
    if t == "table" or t == "userdata" then
        local valueMember = safeMember(src, "value")
        if type(valueMember) == "function" then
            local ok, value = pcall(valueMember, src)
            value = ok and finiteNumber(value) or nil
            return value or 0, value ~= nil
        end
        if type(valueMember) == "number" or type(valueMember) == "string"
            or type(valueMember) == "boolean" then
            local value = finiteNumber(valueMember)
            return value or 0, value ~= nil
        end
    end
    local s
    if system and type(system.getSource) == "function" then
        local ok, resolved = pcall(system.getSource, src)
        if ok then s = resolved end
    end
    if s and type(s.value) == "function" then
        local ok, value = pcall(s.value, s)
        value = ok and finiteNumber(value) or nil
        return value or 0, value ~= nil
    end
    return 0, false
end
local function sourceName(src, fallback)
    local kind = type(src)
    if kind ~= "table" and kind ~= "userdata" then return fallback end
    local nameMember = src and safeMember(src, "name")
    if type(nameMember) == "function" then
        local ok, nm = pcall(nameMember, src)
        if ok and nm and nm ~= "" then
            return tostring(nm)
        end
    end
    return fallback
end
local function sourcePresent(src)
    if src == nil or src == false or src == 0 or src == "" or src == "---" then return false end
    local kind = type(src)
    if kind ~= "table" and kind ~= "userdata" then return true end
    local name = safeMember(src, "name")
    if type(name) == "function" then
        local ok
        ok, name = pcall(name, src)
        if not ok then return true end
        name = name and tostring(name) or ""
        return name ~= "" and name ~= "---"
    end
    return true
end
local function sourceUnit(src)
    local kind = type(src)
    if kind ~= "table" and kind ~= "userdata" then return "" end
    local unit = src and safeMember(src, "stringUnit")
    if type(unit) == "function" then
        local ok, value = pcall(unit, src)
        if ok and value then return tostring(value) end
    elseif unit then
        return tostring(unit)
    end
    return ""
end
local function filteredValue(w, key, raw, alpha)
    raw = finiteNumber(raw) or 0
    w._filtered = w._filtered or {}
    local previous = finiteNumber(w._filtered[key])
    local value = previous == nil and raw or previous + (raw - previous) * (alpha or 0.3)
    w._filtered[key] = value
    return value
end
local function switchBase(k)
    if not k then
        return nil
    end
    k = tostring(k)
    return k:match("S[A-H]") or k:match("s[a-h]") or nil
end
local function trySourceMethod(method, key)
    local fn = system and system[method]
    if type(fn) ~= "function" or not key then return nil end
    local ok, source = pcall(fn, key)
    return ok and source or nil
end
local function resolveSwitch(val)
    if not val or val == "" then
        return nil
    end
    local upper, lower = tostring(val):upper(), tostring(val):lower()
    local base = switchBase(val)
    local sw = trySourceMethod("getSource", val) or trySourceMethod("getSource", upper) or trySourceMethod("getSource", lower)
    if not sw and base then sw = trySourceMethod("getSource", base:upper()) or trySourceMethod("getSource", base:lower()) end
    sw = sw or trySourceMethod("getSwitch", val) or trySourceMethod("getSwitch", upper) or trySourceMethod("getSwitch", lower)
    if not sw and base then sw = trySourceMethod("getSwitch", base:upper()) or trySourceMethod("getSwitch", base:lower()) end
    if sw then return sw end
    return nil
end
local function formatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

local function timerSeconds(w)
    return (w and w.timerSource and getVal(w.timerSource)) or (w and w.flightTime) or 0
end

local function timerText(w)
    local seconds = clamp(math.floor(finiteNumber(timerSeconds(w)) or 0), 0, 359999)
    if w._timerTextSeconds ~= seconds then
        w._timerTextSeconds, w._timerText = seconds, formatTime(seconds)
    end
    return w._timerText
end

local function flightCountText(w)
    local count = clamp(math.floor(finiteNumber(w.flightCount) or 0), 0, 9999)
    if w._flightLabelCount ~= count or w._flightLabelLanguage ~= w.language then
        w._flightLabelCount, w._flightLabelLanguage = count, w.language
        w._flightLabel = tostring(count) .. " " .. T(w, "Flights")
    end
    return w._flightLabel
end

local function formatValue(v)
    if v == nil then
        return "--"
    end
    v = finiteNumber(v)
    if not v then
        return "--"
    end
    local nearest = v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
    if math.abs(v - nearest) < 0.005 then
        return tostring(nearest)
    end
    local one = v >= 0 and math.floor(v * 10 + 0.5) / 10 or math.ceil(v * 10 - 0.5) / 10
    if math.abs(v - one) < 0.005 then
        return string.format("%.1f", v)
    end
    return string.format("%.2f", v)
end
local function wholeNumber(v)
    return v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
end
local function formatAmps(v)
    v = tonumber(v) or 0
    if math.abs(v) >= 1000 then return formatValue(v / 1000) .. "kA" end
    return formatValue(v) .. "A"
end
local batteryProfiles = {
    {3.7, 3.0, 4.2, {3.0, 0, 3.58, 10, 3.66, 20, 3.72, 30, 3.77, 40, 3.81, 50,
        3.86, 60, 3.90, 70, 3.95, 80, 4.01, 90, 4.15, 100, 4.2, 100}},
    {3.8, 3.0, 4.35, {3.0, 0, 3.44, 10, 3.54, 20, 3.61, 30, 3.68, 40, 3.74, 50,
        3.82, 60, 3.90, 70, 3.98, 80, 4.05, 90, 4.30, 100, 4.35, 100}},
    {3.6, 2.85, 4.2, {2.85, 0, 3.20, 10, 3.38, 20, 3.53, 30, 3.61, 40, 3.72, 50,
        3.82, 60, 3.90, 70, 3.99, 80, 4.07, 90, 4.16, 100, 4.2, 100}},
    {3.3, 2.0, 3.6, {2.0, 0, 3.15, 10, 3.22, 20, 3.25, 30, 3.26, 40, 3.27, 50,
        3.28, 60, 3.29, 70, 3.30, 80, 3.31, 90, 3.35, 100, 3.6, 100}},
    {1.2, 1.0, 1.45, {1.0, 0, 1.16, 10, 1.20, 20, 1.22, 30, 1.24, 40, 1.25, 50,
        1.26, 60, 1.27, 70, 1.28, 80, 1.31, 90, 1.40, 100, 1.45, 100}},
}
local function batteryProfile(w)
    return batteryProfiles[clamp(math.floor(tonumber(w.batteryType) or 1), 1, #batteryProfiles)]
end
local batteryThresholds = {
    {4.15, 3.75, 3.45}, {4.25, 3.85, 3.50}, {4.10, 3.60, 3.20},
    {3.40, 3.25, 3.10}, {1.35, 1.15, 1.00},
}
local function sameThresholds(w, values)
    return math.abs((w.battHigh or 0) - values[1]) < 0.001
        and math.abs((w.battMid or 0) - values[2]) < 0.001
        and math.abs((w.battLow or 0) - values[3]) < 0.001
end
local function applyBatteryType(w, value)
    local oldType = clamp(math.floor(tonumber(w.batteryType) or 1), 1, #batteryThresholds)
    local newType = clamp(math.floor(tonumber(value) or 1), 1, #batteryThresholds)
    if sameThresholds(w, batteryThresholds[oldType]) then
        local defaults = batteryThresholds[newType]
        w.battHigh, w.battMid, w.battLow = defaults[1], defaults[2], defaults[3]
    end
    w.batteryType = newType
    w._batteryLevels = nil
end
local function applyProfile(w, value)
    local profile = clamp(math.floor(tonumber(value) or 1), 1, 5)
    w.powerProfile = profile
    w.powerSourceType = profile == 4 and 2 or 1
    w.batteryMode = profile == 2 and 2 or 1
    w.rotorwingMode = profile == 3 and 2 or 1
end

local function textPrefix(text, count, utf8Text)
    if not utf8Text then return text:sub(1, count) end
    local nextByte = utf8.offset(text, count + 1)
    return text:sub(1, nextByte and nextByte - 1 or #text)
end
fitText = function(txt, maxW)
    txt = tostring(txt or "")
    if maxW <= 0 then
        return ""
    end
    if getTextW(txt) <= maxW then
        return txt
    end
    if getTextW(".") > maxW then
        return ""
    end
    local utf8Length = utf8 and utf8.len and utf8.len(txt)
    local length = utf8Length or #txt
    local low, high = 0, length - 1
    while low < high do
        local middle = math.ceil((low + high) / 2)
        if getTextW(textPrefix(txt, middle, utf8Length) .. ".") <= maxW then low = middle
        else high = middle - 1 end
    end
    return textPrefix(txt, low, utf8Length) .. "."
end
local function fitStatusText(label, state, maxW, scale)
    local suffix = ": " .. state
    local txt = label .. suffix
    setFontSize("large")
    if getTextW(txt) <= maxW then
        return txt
    end
    setFontSize("small")
    if getTextW(txt) <= maxW then
        return txt
    end
    local suffixW = getTextW(suffix)
    if suffixW >= maxW then
        return fitText(txt, maxW)
    end
    return fitText(label, maxW - suffixW) .. suffix
end
local function armValueActive(value)
    if type(value) == "boolean" then
        return value
    end
    value = finiteNumber(value) or 0
    return value > 0
end
local function switchActive(sw, key)
    if not sw and key then
        sw = resolveSwitch(key)
    end
    if not sw then
        return false
    end
    local t = type(sw)
    if t == "number" then
        return armValueActive(sw)
    end
    if t == "string" then
        local value = tonumber(sw)
        if value then
            return armValueActive(value)
        end
        local resolved = resolveSwitch(sw)
        return resolved and resolved ~= sw and switchActive(resolved, nil) or false
    end
    if t == "table" or t == "userdata" then
        local activeMember = safeMember(sw, "active")
        if type(activeMember) == "function" then
            local ok, v = pcall(activeMember, sw)
            if ok then
                return armValueActive(v)
            end
        end
        local valueMember = safeMember(sw, "value")
        if type(valueMember) == "function" then
            local ok, v = pcall(valueMember, sw)
            if ok then
                return armValueActive(v)
            end
        end
        if type(valueMember) == "number" or type(valueMember) == "string" then
            return armValueActive(valueMember)
        end
    end
    return armValueActive(getVal(sw))
end
local function create()
    return {
        armDelay = 5,
        inFlightScreen = 1,
        cellCount = 0,
        batteryType = 1,
        language = i18n.systemDefault(),
        themeMode = 1,
        fontSize = 2,
        batteryStyle = 1,
        powerProfile = 1,
        powerSourceType = 1,
        batteryMode = 1,
        rotorwingMode = 1,
        rpmMax = 8000,
        rpmWarn = 6400,
        flightMinSeconds = 15,
        packWarn = 0.10,
        packBad = 0.20,
        fuelShowPercent = 1,
        statusMode = 1,
        battHigh = 4.15,
        battMid = 3.75,
        battLow = 3.45,
        linkHigh = 98,
        linkMid = 80,
        linkMode = 1,
        currentHigh = 60,
        currentMid = 35,
        fuelHigh = 40,
        fuelMid = 20,
        fuelMode = 1,
        field1High = 0,
        field1Mid = 0,
        field1Mode = 1,
        field2High = 0,
        field2Mid = 0,
        field2Mode = 2,
        field3High = 0,
        field3Mid = 0,
        field3Mode = 2,
        field4High = 80,
        field4Mid = 30,
        field4Mode = 1,
        telemetry4High = 80,
        telemetry4Mid = 30,
        telemetry4Mode = 1,
        flightActive = false,
        postFlight = false,
        flightStart = 0,
        flightTime = 0,
        flightCount = 0,
        dirty = false,
        dirtyAt = 0,
        nextRefresh = 0,
    }
end
local function storageCall(method, widget)
    local chunk = loadfile("storage.lua")
    if not chunk then return false end
    local ok, module = pcall(chunk)
    if not ok or type(module) ~= "table" then return false end
    local fn = module[method]
    if type(fn) ~= "function" then return false end
    return fn(widget, i18n.valid)
end
local function read(widget) return storageCall("read", widget) end
local function write(widget) return storageCall("write", widget) end
local function flush(w)
    if w and w.dirty and write(w) then
        w.dirty = false
        return true
    end
    return false
end
local function configure(widget)
    local chunk = loadfile("config.lua")
    if not chunk then return end
    local ok, module = pcall(chunk)
    if ok and module and module.configure then
        module.configure(widget, {
            clamp = clamp,
            languageCodes = i18n.codes,
            sourcePresent = sourcePresent,
            tr = i18n.text,
            applyBatteryType = applyBatteryType,
            applyProfile = applyProfile,
        })
    end
end
local function score(w, prefix, value, c)
    local high = prefix == "rpm" and (w.rpmMax or 8000) or (w[prefix .. "High"] or 0)
    local mid = prefix == "rpm" and (w.rpmWarn or 6400) or (w[prefix .. "Mid"] or 0)
    if high == 0 and mid == 0 then return c.neutral, "INFO" end
    if high < mid then
        high, mid = mid, high
    end
    if prefix == "current" then
        if value >= high then
            return c.bad, ":("
        end
        if value >= mid then
            return c.warn, ":|"
        end
        return c.good, ":)"
    end
    local mode = prefix == "rpm" and 2 or (w[prefix .. "Mode"] or 1)
    if mode == 2 then
        if value < mid then
            return c.good, ":)"
        end
        if value < high then
            return c.warn, ":|"
        end
        return c.bad, ":("
    end
    if value >= high then
        return c.good, ":)"
    end
    if value >= mid then
        return c.warn, ":|"
    end
    return c.bad, ":("
end
local function statStatus(w, key, st, c)
    if key == "battTotal" then
        return c.neutral, "INFO"
    end
    local prefix = (key == "batt1" or key == "batt2") and "batt" or key
    local mode = prefix == "rpm" and 2 or (w[prefix .. "Mode"] or 1)
    local value = (prefix == "current" or mode == 2) and st.max or st.min
    local col, face = score(w, prefix, value, c)
    if face == "INFO" then return col, face end
    if face == ":)" then
        return col, "OK :)"
    end
    if face == ":|" then
        return col, "WARN"
    end
    return col, "BAD :("
end
local function drawPostFlight(w, c, scale, scrW, scrH)
    if not summaryModule then
        local chunk = loadfile("summary.lua")
        if not chunk then return end
        local ok, module = pcall(chunk)
        if not ok or type(module) ~= "table" then return end
        summaryModule = module
        summaryApi = {
            px = px,
            getTextW = getTextW,
            getTextH = getTextH,
            setFontSize = setFontSize,
            setFittingFont = setFittingFont,
            timerText = timerText,
            flightCountText = flightCountText,
            formatValue = formatValue,
            fitText = fitText,
            statStatus = statStatus,
            roundPanel = roundPanel,
            tr = i18n.text,
        }
    end
    summaryModule.draw(w, c, scale, scrW, scrH, summaryApi)
end
local function resetStats(w)
    w.stats, w.statOrder = {}, {}
end
local function pushStat(w, key, label, value)
    if value == nil then
        return
    end
    if not w.stats then
        resetStats(w)
    end
    if not w.stats[key] then
        w.stats[key] = {
            label = label,
            min = value,
            max = value,
        }
        w.statOrder[#w.statOrder + 1] = key
    else
        local st = w.stats[key]
        st.label = label
        if value < st.min then
            st.min = value
        end
        if value > st.max then
            st.max = value
        end
    end
end
local function cellsFor(w, batt)
    batt = finiteNumber(batt) or 0
    local cells = finiteNumber(w.cellCount) or 0
    if batt <= 0 then return cells >= 1 and cells or 0 end
    if cells >= 1 then
        return cells
    end
    return 0
end
local function curvePercent(curve, voltage)
    if voltage <= curve[1] then
        return 0
    end
    for i = 3, #curve, 2 do
        local lowV, lowPct = curve[i - 2], curve[i - 1]
        local highV, highPct = curve[i], curve[i + 1]
        if voltage <= highV then
            local span = highV - lowV
            if span <= 0 then
                return highPct
            end
            return lowPct + (highPct - lowPct) * (voltage - lowV) / span
        end
    end
    return 100
end
local sourceHasValue
local function batteryFuelPercent(w, batt)
    if w.field4Source then
        local value, readable = getVal(w.field4Source)
        if sourceHasValue(w.field4Source, true, value, readable) then
            return clamp(value, 0, 100)
        end
    end
    if not w.batterySource then
        return nil
    end
    batt = finiteNumber(batt) or 0
    if (w.powerSourceType or 1) == 2 then
        return clamp(batt, 0, 100)
    end
    if batt <= 0 then
        return 0
    end
    local cells = cellsFor(w, batt)
    if cells < 1 then
        return nil
    end
    return clamp(curvePercent(batteryProfile(w)[4], batt / cells), 0, 100)
end
local function batteryIconRatio(w, perCell, batt)
    if not batt or batt <= 0 or not perCell or perCell <= 0 then
        return 0
    end
    local emptyV = w.battLow or 3.45
    local fullV = w.battHigh or 4.15
    if fullV <= emptyV then
        fullV = emptyV + 0.01
    end
    if perCell <= emptyV then
        return 0
    end
    if perCell >= fullV then
        return 1
    end
    return (perCell - emptyV) / (fullV - emptyV)
end
local function batteryIconSlicesFor(ratio, segments)
    segments = math.max(1, math.floor(tonumber(segments) or 1))
    ratio = clamp(tonumber(ratio) or 0, 0, 1)
    if ratio <= 0.03 then
        return 0
    end
    if ratio >= 0.95 then
        return segments
    end
    return clamp(math.ceil(ratio * segments), 1, segments)
end
local function batteryColor(w, c, key, perCell)
    w._batteryLevels = w._batteryLevels or {}
    local previous = w._batteryLevels[key]
    local high, mid, margin = w.battHigh or 4.15, w.battMid or 3.75, 0.03
    if high < mid then high, mid = mid, high end
    local level = perCell >= high and 3 or (perCell >= mid and 2 or 1)
    if previous == 3 and perCell >= high - margin then level = 3 end
    if previous == 2 then
        if perCell >= high + margin then level = 3
        elseif perCell >= mid - margin then level = 2 end
    end
    if previous == 1 and perCell < mid + margin then level = 1 end
    w._batteryLevels[key] = level
    return level == 3 and c.good or (level == 2 and c.warn or c.bad)
end
local function powerInfo(w, c)
    local measured, readable = getVal(w.batterySource)
    local fuelMode = (w.powerSourceType or 1) == 2
    local online = sourceHasValue(w.batterySource, fuelMode, measured, readable)
        and (fuelMode or measured > 0)
    local raw = online and filteredValue(w, "battery1", measured, 0.25) or 0
    local value = raw
    local percent
    local ratio = 0
    local perCell = 0
    local color = c.bad
    if fuelMode then
        value = batteryFuelPercent(w, raw) or raw
        percent = clamp(value, 0, 100)
        color = percent >= (w.fuelHigh or 40) and c.good or (percent >= (w.fuelMid or 20) and c.warn or c.bad)
    else
        local cells = cellsFor(w, raw)
        if raw > 0 and cells > 0 then
            perCell = raw / cells
        end
        percent = batteryFuelPercent(w, raw)
        ratio = batteryIconRatio(w, perCell, raw)
        color = batteryColor(w, c, "battery1", perCell)
    end
    local info = w._powerInfo
    if not info then info = {}; w._powerInfo = info end
    info.raw, info.value, info.percent, info.ratio = raw, value, percent, ratio
    info.perCell, info.color, info.fuelMode = perCell, color, fuelMode
    info.online, info.needsCells = online, online and not fuelMode and cellsFor(w, raw) < 1
    info.gauge = fuelMode or tonumber(w.batteryStyle) == 2
    return info
end

local function batteryPackInfo(w, c, src, slot, info)
    info = info or {}
    local measured, readable = getVal(src)
    local online = measured > 0 and sourceHasValue(src, false, measured, readable)
    local raw = online and filteredValue(w, "battery" .. slot, measured, 0.25) or 0
    local cells = cellsFor(w, raw)
    local perCell = raw > 0 and cells > 0 and raw / cells or 0
    local percent = perCell > 0 and clamp(curvePercent(batteryProfile(w)[4], perCell), 0, 100) or nil
    local color = batteryColor(w, c, "battery" .. slot, perCell)
    info.raw, info.cells, info.perCell, info.percent = raw, cells, perCell, percent
    info.ratio, info.color = batteryIconRatio(w, perCell, raw), color
    info.online, info.needsCells = online, online and cells < 1
    return info
end

local function dualPowerInfo(w, c)
    local info = w._dualPowerInfo
    if not info then info = {{}, {}}; w._dualPowerInfo = info end
    local first = batteryPackInfo(w, c, w.batterySource, 1, info[1])
    local second = batteryPackInfo(w, c, w.battery2Source, 2, info[2])
    local totalRaw, totalReadable = getVal(w.totalBatterySource)
    local measuredTotal = totalRaw > 0
        and sourceHasValue(w.totalBatterySource, false, totalRaw, totalReadable)
        and filteredValue(w, "batteryTotal", totalRaw, 0.25) or nil
    info.total = measuredTotal or (first.online and second.online and (first.raw + second.raw) or nil)
    info.totalMeasured = measuredTotal ~= nil
    info.cells = first.cells + second.cells
    info.delta = first.online and second.online and math.abs(first.raw - second.raw) or nil
    info.deltaPerCell = first.perCell > 0 and second.perCell > 0
        and math.abs(first.perCell - second.perCell) or nil
    info.color = (first.color == c.bad or second.color == c.bad) and c.bad
        or (first.color == c.warn or second.color == c.warn) and c.warn or c.good
    local packWarn, packBad = w.packWarn or 0.10, w.packBad or 0.20
    if packBad < packWarn then packWarn, packBad = packBad, packWarn end
    if info.deltaPerCell and info.deltaPerCell >= packBad then info.color = c.bad
    elseif info.deltaPerCell and info.deltaPerCell >= packWarn and info.color ~= c.bad then
        info.color = c.warn
    end
    return info
end

local function pushSourceStat(w, key, src, fallback, whole)
    if not src then return end
    local value, readable = getVal(src)
    if sourceHasValue(src, true, value, readable) then
        pushStat(w, key, sourceName(src, T(w, fallback)), whole and wholeNumber(value) or value)
    end
end

local function updateStats(w)
    local batt, battReadable = getVal(w.batterySource)
    local dualMode = (w.powerSourceType or 1) ~= 2 and (w.batteryMode or 1) == 2
    local percent = dualMode and nil or batteryFuelPercent(w, batt)
    if dualMode then
        local batt2, batt2Readable = getVal(w.battery2Source)
        local total = sourceHasValue(w.totalBatterySource) and getVal(w.totalBatterySource) or nil
        local cells1, cells2 = cellsFor(w, batt), cellsFor(w, batt2)
        if batt > 0 and cells1 > 0
            and sourceHasValue(w.batterySource, false, batt, battReadable) then
            pushStat(w, "batt1", T(w, "Battery 1/cell"), batt / cells1)
        end
        if batt2 > 0 and cells2 > 0
            and sourceHasValue(w.battery2Source, false, batt2, batt2Readable) then
            pushStat(w, "batt2", T(w, "Battery 2/cell"), batt2 / cells2)
        end
        total = total or (batt > 0 and batt2 > 0
            and sourceHasValue(w.batterySource, false, batt, battReadable)
            and sourceHasValue(w.battery2Source, false, batt2, batt2Readable)
            and (batt + batt2) or nil)
        if total then
            pushStat(w, "battTotal", T(w, "Total voltage"), total)
        end
    elseif percent ~= nil and (w.powerSourceType or 1) == 2 then
        pushStat(w, "fuel", sourceName(w.field4Source, T(w, "Fuel")), percent)
    elseif batt > 0 and sourceHasValue(w.batterySource, false, batt, battReadable) then
        local cells = cellsFor(w, batt)
        if cells > 0 then
            pushStat(w, "batt", T(w, "Battery/cell"), batt / cells)
        end
    end
    pushSourceStat(w, "link", w.rssiSource, "Link", true)
    pushSourceStat(w, "current", w.currentSource, "Current")
    pushSourceStat(w, "rpm", w.rpmSource, "RPM")
    pushSourceStat(w, "field1", w.field1Source, "Tlm 1")
    pushSourceStat(w, "field2", w.field2Source, "Tlm 2")
    pushSourceStat(w, "field3", w.field3Source, "Tlm 3")
    pushSourceStat(w, "telemetry4", w.telemetry4Source, "Tlm 4")
    if percent ~= nil and (w.powerSourceType or 1) ~= 2 then
        pushStat(w, "field4", sourceName(w.field4Source, T(w, "Battery percentage")), percent)
    end
end
local function updateFlight(w, now)
    now = now or os.clock()
    if not w.armSwitch and w.armSwitchKey and now >= (w.armResolveAt or 0) then
        w.armSwitch = resolveSwitch(w.armSwitchKey)
        w.armResolveAt = now + 2
    end
    local armed = switchActive(w.armSwitch, nil)
    if armed then
        w.postFlight = false
        if not w.armSeenAt then
            w.armSeenAt = now
        end
        if not w.flightActive and now - w.armSeenAt >= (w.armDelay or 5) then
            w.flightActive = true
            w.postFlight = false
            w.flightStart = now
            w.flightTime = 0
            w._flightSessionCounted = false
            resetStats(w)
        end
    end
    if w.flightActive then
        w.flightTime = now - (w.flightStart or now)
        updateStats(w)
    end
    if not armed then
        w.armSeenAt = nil
        if w.flightActive then
            w.flightTime = now - (w.flightStart or now)
            updateStats(w)
            w.flightActive = false
            w.postFlight = true
            if (w.flightTime or 0) >= (w.flightMinSeconds or 15) and not w._flightSessionCounted then
                w.flightCount = math.min(9999, (tonumber(w.flightCount) or 0) + 1)
                w._flightSessionCounted = true
                w.dirty = true
                w.dirtyAt = now
            end
        end
    end
    return armed
end
local function updateLinkMinimum(w, now)
    local src = w.rssiSource
    if not src then
        w.linkMin, w.linkMinSource, w.linkSeenAt = nil, nil, nil
        return
    end
    if w.linkMinSource ~= src then
        w.linkMinSource, w.linkSeenAt, w.linkMin = src, nil, nil
    end
    local measured, readable = getVal(src)
    local link = wholeNumber(measured)
    if not w.linkSeenAt then
        if sourceHasValue(src, true, measured, readable) then
            w.linkSeenAt = now
        end
        return
    end
    if now - w.linkSeenAt < LINK_MIN_GRACE then
        return
    end
    if not sourceHasValue(src, true, measured, readable) then return end
    if w.linkMin == nil or link < w.linkMin then
        w.linkMin = link
    end
end
local sourceValidityMethods = {
    "isValid",
    "valid",
    "isAvailable",
    "available",
}
local compactPairedFonts = {
    {fontS or fontL}, {fontL or fontS, fontS or fontL},
    {fontXL or fontL or fontS, fontL or fontS, fontS or fontL},
}
local widePairedFonts = {
    {fontL or fontS, fontS or fontL},
    {fontXL or fontL or fontS, fontL or fontS, fontS or fontL},
    {fontXXL or fontXL or fontL or fontS, fontXL or fontL or fontS,
        fontL or fontS, fontS or fontL},
}
sourceHasValue = function(src, allowZero, measured, readable)
    if not src then
        return false
    end
    local explicitlyValid
    local t = type(src)
    if t == "table" or t == "userdata" then
        for i = 1, #sourceValidityMethods do
            local fn = safeMember(src, sourceValidityMethods[i])
            if type(fn) == "function" then
                local ok, valid = pcall(fn, src)
                if not ok then return false end
                if ok and type(valid) == "boolean" then
                    if not valid then return false end
                    explicitlyValid = true
                    break
                end
                if ok and type(valid) == "number" then
                    if valid == 0 then return false end
                    explicitlyValid = true
                    break
                end
            elseif type(fn) == "boolean" or type(fn) == "number" then
                if fn == false or fn == 0 then return false end
                explicitlyValid = true
                break
            end
        end
    end
    if measured == nil then measured, readable = getVal(src) end
    if readable == false then return false end
    if (finiteNumber(measured) or 0) ~= 0 then
        return true
    end
    if not allowZero then
        return false
    end
    if explicitlyValid ~= nil then
        return explicitlyValid
    end
    return true
end
local function telemetryPresent(w)
    local fuelMode = (w.powerSourceType or 1) == 2
    if not fuelMode and (w.batteryMode or 1) == 2 then
        local first, firstReadable = getVal(w.batterySource)
        if first > 0 and sourceHasValue(w.batterySource, false, first, firstReadable) then return true end
        local second, secondReadable = getVal(w.battery2Source)
        return second > 0 and sourceHasValue(w.battery2Source, false, second, secondReadable)
    end
    if w.rssiSource then
        return sourceHasValue(w.rssiSource)
    end
    if w.batterySource then
        local value, readable = getVal(w.batterySource)
        return sourceHasValue(w.batterySource, fuelMode, value, readable) and (fuelMode or value > 0)
    end
    if w.currentSource then
        return sourceHasValue(w.currentSource, true)
    end
    if w.rpmSource then
        return sourceHasValue(w.rpmSource, true)
    end
    if w.field1Source then
        return sourceHasValue(w.field1Source, true)
    end
    if w.field2Source then
        return sourceHasValue(w.field2Source, true)
    end
    if w.field3Source then
        return sourceHasValue(w.field3Source, true)
    end
    if w.telemetry4Source then
        return sourceHasValue(w.telemetry4Source, true)
    end
    if w.field4Source then
        return sourceHasValue(w.field4Source, true)
    end
    return false
end
local function updateAudioCues(w, armed)
    local cue
    local armSource = w.armSwitch or w.armSwitchKey
    if sourcePresent(armSource) then
        if w._audioArmSource ~= armSource then
            w._audioArmSource, w._audioArmed = armSource, armed
        elseif w._audioArmed ~= armed then
            cue = armed and "armed" or "disarm"
            w._audioArmed = armed
        end
    else
        w._audioArmSource, w._audioArmed = nil, nil
    end
    local firstTelemetry = not w._telemetryCuePlayed and telemetryPresent(w)
    if firstTelemetry then
        w._telemetryCuePlayed = true
        if not cue then cue = "beep" end
    end
    if cue then playCue(cue) end
end
local function drawNoTelemetry(w, c, scrW, scrH)
    if math.floor(os.clock() * 2) % 2 == 0 then
        local scale = scaleFor(scrW, scrH)
        local warnH = math.max(36, math.floor(scrH * 0.18))
        local warnY = math.floor(scrH * 0.34)
        local warnX = px(8, scale, 4, 12)
        roundPanel(warnX, warnY, scrW - warnX * 2, warnH, c.alertBg, c.alertOutline)
        local msg = T(w, "NO TELEMETRY")
        setFittingFont("large", msg, scrW - warnX * 2 - 8, warnH - 4)
        local msgW = getTextW(msg) or 0
        local x = math.floor((scrW - msgW) / 2)
        local y = warnY + math.max(1, math.floor((warnH - getTextH(msg)) / 2))
        if c.alertOutline then
            local o = px(2, scale, 1, 2)
            lcd.color(c.alertOutline)
            drawText(x - o, y, msg)
            drawText(x + o, y, msg)
            drawText(x, y - o, msg)
            drawText(x, y + o, msg)
        end
        lcd.color(c.alertText)
        drawText(x, y, msg)
    end
end
local function statusActive(w)
    local value = getVal(w.statusSource)
    local mode = tonumber(w.statusMode) or 1
    if mode == 2 then
        return value < 0
    end
    return value > 0
end
local function drawStatusBar(w, c, scale, x, y, width, height)
    if not sourcePresent(w.statusSource) then
        return
    end
    local active = statusActive(w)
    local fill = active and c.good or c.bad
    local label = sourceName(w.statusSource, T(w, "Status"))
    local state = T(w, active and "On" or "Off"):upper()
    local pad = px(8, scale, 4, 12)
    local txt = fitStatusText(label, state, width - pad * 2, scale)
    roundPanel(x, y, width, height, fill, c.outline)
    setFittingFont("large", txt, width - pad * 2 - px(2, scale, 1, 2), height - 2)
    local tx = x + math.floor((width - (getTextW(txt) or 0)) / 2)
    local ty = y + math.max(1, math.floor((height - getTextH(txt)) / 2))
    local bold = px(1, scale, 1, 2)
    lcd.color(lcd.RGB(0, 0, 0))
    drawText(tx, ty, txt)
    drawText(tx + bold, ty, txt)
end
local function gaugeColor(c, value, lowGood, mid, high)
    if lowGood then
        if value >= high then return c.bad end
        if value >= mid then return c.warn end
        return c.good
    end
    if value < mid then return c.bad end
    if value < high then return c.warn end
    return c.good
end
local function drawGaugeLabel(cx, cy, text, deg, radius, mainLeft, mainW, topY, cutY, weight)
    local lx, ly = polarPoint(cx, cy, deg, radius)
    local tw, th = getTextW(text) or 0, getTextH(text)
    local tx = clamp(lx - math.floor(tw / 2), mainLeft + 3, mainLeft + mainW - tw - 3)
    local ty = clamp(ly - math.floor(th / 2), topY + 2, cutY - th - 2)
    drawHeavyText(tx, ty, text, weight)
end
local function drawFooterCurrent(w, c, scale, left, right, y, height, centerX)
    if not sourcePresent(w.currentSource) or right <= left then return end
    local maxW = right - left
    if centerX then
        maxW = math.min(maxW, math.max(1,
            math.floor(math.min(centerX - left, right - centerX) * 2 + 1)))
    end
    local text = formatAmps(filteredValue(w, "current", getVal(w.currentSource), 0.3))
    setFittingFont("small", text, maxW, height)
    text = fitText(text, maxW)
    local tw, th = getTextW(text) or 0, getTextH(text)
    local textX = left + math.floor((right - left - tw) / 2)
    if centerX then textX = clamp(centerX - math.floor(tw / 2), left, right - tw) end
    lcd.color(c.muted)
    drawText(textX, y + math.max(0, math.floor((height - th) / 2)), text)
end
local function drawFuelGauge(w, c, scale, mainLeft, mainW, topY, bottomY, fuelValue, sizeScale, centerX, centerY, batteryGauge, packVoltage, voltageColor, splitFooter, lowGood, gaugeMid, gaugeHigh, footerText, leftText, midText, rightText, halfGauge)
    local pct = clamp(tonumber(fuelValue) or 0, 0, 100)
    local verticalSide = halfGauge == "left" or halfGauge == "right"
    local largeFooter = currentTextScale >= TEXT_SCALE_LARGE
    local cx = centerX or (mainLeft + math.floor(mainW / 2))
    local showPercent = footerText ~= nil or batteryGauge or (w.fuelShowPercent or 1) ~= 2
    local showCurrent = not verticalSide and sourcePresent(w.currentSource)
    local footerSpan = math.max(1, bottomY - topY)
    local gaugeFooter = math.min(math.max(1, footerSpan - 1), gaugeFooterHeight())
    local percentReserve = showPercent and gaugeFooter
        or (showCurrent and px(34, scale, 24, 40) or px(8, scale, 4, 12))
    local gaugeBottom = math.max(topY + 1, bottomY - percentReserve)
    local areaH = math.max(1, gaugeBottom - topY)
    if verticalSide then
        cx = halfGauge == "left" and (mainLeft + mainW) or mainLeft
    end
    local cy = verticalSide and gaugeBottom or (centerY or (topY + math.floor(areaH * 0.74)))
    local hScale = verticalSide and 0.96 or 0.74
    local wScale = verticalSide and 0.96 or 0.49
    local cap = verticalSide and math.max(mainW, areaH) or px(215, scale, 132, 245)
    local r = math.floor(math.min(mainW * wScale, areaH * hScale, cap) * (sizeScale or 1))
    r = math.min(r, math.floor(areaH * (verticalSide and 0.98 or 0.76)))
    if verticalSide then
        r = math.min(r, math.max(1, mainW - 1), math.max(1, areaH - 1))
    end
    if r < px(38, scale, 24, 50) then
        lcd.color(c.text)
        local footerY = topY + math.floor(areaH / 2)
        local fallback = showPercent and (tostring(math.floor(pct + 0.5)) .. "%")
            or (showCurrent and formatAmps(filteredValue(w, "current", getVal(w.currentSource), 0.3)) or T(w, "Fuel"):upper())
        setFittingFont("large", fallback, mainW, percentReserve)
        if splitFooter and packVoltage then
            local voltageText = string.format("%.2fV", packVoltage)
            local voltageX = mainLeft
            local fallbackW = getTextW(fallback) or 0
            local fallbackX = mainLeft + mainW - fallbackW
            local footerTextH = getTextH(fallback)
            lcd.color(voltageColor or c.text)
            drawText(voltageX, footerY, voltageText)
            drawText(fallbackX, footerY, fallback)
            if not verticalSide then
                drawFooterCurrent(w, c, scale, voltageX + (getTextW(voltageText) or 0),
                    fallbackX, footerY, footerTextH, cx)
            end
        else
            drawText(mainLeft + math.floor((mainW - (getTextW(fallback) or 0)) / 2), footerY, fallback)
            if batteryGauge and packVoltage then
                local voltageText = string.format("%.2fV", packVoltage)
                lcd.color(voltageColor or c.text)
                drawText(mainLeft + math.floor((mainW - (getTextW(voltageText) or 0)) / 2), footerY + px(42, scale, 28, 50), voltageText)
            end
        end
        return
    end
    local cutDepth = verticalSide and 0 or math.floor(r * 0.3)
    cy = math.min(cy, gaugeBottom - cutDepth)
    local cutY = cy + cutDepth
    if type(lcd.setClipping) == "function" then
        lcd.setClipping(mainLeft, topY, mainW, math.max(1, cutY - topY))
    end
    local face = lcd.RGB(0, 0, 0)
    local rim = lcd.RGB(235, 240, 240)
    local red = lcd.RGB(255, 35, 25)
    local gaugeText = lcd.RGB(255, 255, 255)
    local fuelHigh = gaugeHigh or (batteryGauge and (w.field4High or 80) or (w.fuelHigh or 40))
    local fuelMid = gaugeMid or (batteryGauge and (w.field4Mid or 30) or (w.fuelMid or 20))
    if fuelHigh < fuelMid then
        fuelHigh, fuelMid = fuelMid, fuelHigh
    end
    lcd.color(face)
    lcd.drawFilledCircle(cx, cy, r)
    local innerRim = r - px(6, scale, 3, 9)
    lcd.color(rim)
    lcd.drawCircle(cx, cy, r)
    lcd.drawCircle(cx, cy, innerRim)
    local startDeg, sweepDeg = 180, 180
    if halfGauge == "left" then
        startDeg, sweepDeg = 180, 90
    elseif halfGauge == "right" then
        startDeg, sweepDeg = 360, -90
    end
    for i = 0, 4 do
        local deg = startDeg + i * (sweepDeg / 4)
        local major = i == 0 or i == 2 or i == 4
        local x1, y1 = polarPoint(cx, cy, deg, r - px(major and 10 or 8, scale, 5, 14))
        local x2, y2 = polarPoint(cx, cy, deg, r - px(major and 34 or 24, scale, 14, 40))
        local tickPct = i * 25
        lcd.color(gaugeColor(c, tickPct, lowGood, fuelMid, fuelHigh))
        drawHeavyLine(x1, y1, x2, y2)
    end
    setFontSize("small")
    lcd.color(gaugeText)
    local labelWeight = preset(1, 2, 3)
    leftText = leftText or "E"
    midText = midText or "1/2"
    rightText = rightText or "F"
    if verticalSide then
        local labelR = r - px(48, scale, 30, 62)
        drawGaugeLabel(cx, cy, leftText, startDeg, labelR, mainLeft, mainW, topY, cutY, labelWeight)
        drawGaugeLabel(cx, cy, midText, startDeg + sweepDeg / 2, labelR, mainLeft, mainW, topY, cutY, labelWeight)
        drawGaugeLabel(cx, cy, rightText, startDeg + sweepDeg, labelR, mainLeft, mainW, topY, cutY, labelWeight)
    else
        drawGaugeLabel(cx, cy, leftText, 180, r - px(56, scale, 34, 68), mainLeft, mainW, topY, cutY, labelWeight)
        drawGaugeLabel(cx, cy, midText, 270, r - px(70, scale, 44, 82), mainLeft, mainW, topY, cutY, labelWeight)
        drawGaugeLabel(cx, cy, rightText, 360, r - px(56, scale, 34, 68), mainLeft, mainW, topY, cutY, labelWeight)
    end
    local needleDeg = startDeg + pct * sweepDeg / 100
    local nx, ny = polarPoint(cx, cy, needleDeg, math.floor(r * 0.86))
    local needleLift = px(4, scale, 3, 6)
    local hubY = cy - needleLift
    ny = ny - needleLift
    lcd.color(red)
    drawHeavyLine(cx, hubY, nx, ny)
    lcd.drawFilledCircle(cx, hubY, px(9, scale, 6, 12))
    lcd.color(face)
    lcd.drawFilledCircle(cx, hubY, px(4, scale, 2, 6))
    if type(lcd.setClipping) == "function" then
        lcd.setClipping()
    end
    lcd.color(rim)
    if verticalSide then
        local seamX = halfGauge == "left" and (mainLeft + mainW - 1) or mainLeft
        drawHeavyLine(seamX, math.max(topY, cy - r + px(8, scale, 4, 12)), seamX, cutY)
        if halfGauge == "left" then
            drawHeavyLine(math.max(mainLeft, cx - r), cutY, seamX, cutY)
        else
            drawHeavyLine(seamX, cutY, math.min(mainLeft + mainW - 1, cx + r), cutY)
        end
    else
        lcd.drawLine(cx - r + px(10, scale, 5, 16), cutY, cx + r - px(10, scale, 5, 16), cutY)
    end
    if showPercent then
        local percentText = footerText or (splitFooter and (tostring(math.floor(pct + 0.5)) .. "%")
            or (T(w, batteryGauge and "Batt" or "Dash Fuel"):upper() .. " " .. tostring(math.floor(pct + 0.5)) .. "%")
        )
        local footerMaxH = math.max(12, percentReserve - 1)
        local footerOverhang = px(5, scale, 3, 7)
        local footerMaxW = verticalSide and math.min(mainW, r + footerOverhang * 2) or mainW
        if not (splitFooter and packVoltage) then
            if verticalSide and pairedFooterFont then
                setExactFont(pairedFooterFont)
            else
                setFittingFont("huge", percentText, footerMaxW, footerMaxH)
            end
        end
        local percentColor = gaugeColor(c, pct, lowGood, fuelMid, fuelHigh)
        lcd.color(percentColor)
        if splitFooter and packVoltage then
            local voltageText = string.format("%.2fV", packVoltage)
            local inset = px(12, scale, 6, 18)
            if verticalSide and pairedFooterFont then
                setExactFont(pairedFooterFont)
            else
                setFittingFont("huge",
                    voltageText .. percentText,
                    largeFooter and math.max(1, mainW - 2) or (mainW - inset * 2),
                    footerMaxH)
            end
            local voltageW = getTextW(voltageText) or 0
            local percentW = getTextW(percentText) or 0
            local footerTextH = getTextH(percentText)
            local percentY = math.max(cutY,
                bottomY - footerTextH - px(6, scale, 4, 8))
            local voltageX, percentX
            if largeFooter then
                local edgeInset = px(5, scale, 3, 6)
                voltageX = mainLeft + edgeInset
                percentX = mainLeft + mainW - percentW - edgeInset
            else
                voltageX = verticalSide and (mainLeft + px(5, scale, 3, 8)) or (mainLeft + inset)
                percentX = verticalSide and (mainLeft + mainW - percentW - px(5, scale, 3, 8))
                    or (mainLeft + mainW - inset - percentW)
            end
            lcd.color(voltageColor or percentColor)
            drawHeavyText(voltageX, percentY, voltageText, labelWeight)
            lcd.color(percentColor)
            drawHeavyText(percentX, percentY, percentText, labelWeight)
            if not verticalSide then
                local gap = px(5, scale, 3, 8)
                drawFooterCurrent(w, c, scale, voltageX + voltageW + gap,
                    percentX - gap, percentY, footerTextH, cx)
            end
        else
            local footerTextH = getTextH(percentText)
            local percentY = math.max(cutY,
                bottomY - footerTextH - px(6, scale, 4, 8))
            if verticalSide then
                local textW = getTextW(percentText) or 0
                local footerCenter = halfGauge == "left" and (cx - math.floor(r / 2))
                    or (mainLeft + math.floor(mainW / 2))
                local textX = clamp(footerCenter - math.floor(textW / 2),
                    mainLeft - footerOverhang, mainLeft + mainW - textW + footerOverhang)
                drawHeavyText(textX, percentY, percentText, labelWeight)
            else
                drawHeavyText(cx - math.floor((getTextW(percentText) or 0) / 2), percentY, percentText, labelWeight)
            end
            if batteryGauge and packVoltage then
                local voltageText = string.format("%.2fV", packVoltage)
                setFittingFont("huge", voltageText, mainW, footerMaxH)
                lcd.color(voltageColor or percentColor)
                local voltageY = percentY + px(42, scale, 28, 50)
                drawHeavyText(cx - math.floor((getTextW(voltageText) or 0) / 2), voltageY, voltageText, labelWeight)
            end
        end
    elseif showCurrent then
        drawFooterCurrent(w, c, scale, mainLeft + 1, mainLeft + mainW - 1,
            bottomY - percentReserve, percentReserve, cx)
    end
end
local function drawCardInline(c, scale, x, y, width, height, pad, label, value, color)
    local weight = currentFontSetting == 3 and 1 or 0
    setFittingFont("small", tostring(value or ""), width - pad * 2 - weight,
        math.max(1, height))
    lcd.color(color or c.text)
    value = fitText(value, width - pad * 2)
    local valueW = getTextW(value) or 0
    local textY = y + math.max(1, math.floor((height - getTextH(value)) / 2))
    drawText(x + pad, textY, fitText(label or "", math.max(0, width - pad * 3 - valueW)))
    if weight > 0 then drawHeavyText(x + width - pad - valueW - weight, textY, value, weight)
    else drawText(x + width - pad - valueW, textY, value) end
end

local function drawCardV2(c, scale, x, y, width, height, label, value, color)
    if height <= 0 or width <= 0 then return end
    local pad = px(8, scale, 4, 12)
    roundPanel(x, y, width, height, c.panel, c.outline)
    drawCardInline(c, scale, x, y, width, height, pad, label, value or "--", color)
end

local function drawCenteredText(text, x, width, y, color, weight)
    weight = weight or 0
    local extent = weight
    text = fitText(text, math.max(0, width - extent))
    lcd.color(color)
    local textX = x + math.floor((width - (getTextW(text) or 0) - extent) / 2)
    if weight > 0 then
        drawHeavyText(textX, y, text, weight)
    else
        drawText(textX, y, text)
    end
end

local function drawTimerCardV2(w, c, scale, x, y, width, height, label)
    if height <= 0 or width <= 0 then return end
    local pad = px(8, scale, 4, 12)
    roundPanel(x, y, width, height, c.panel, c.outline)
    local value = timerText(w)
    local labelText = label or T(w, "Timer")
    local weight = px(2, scale, 1, 3)
    setFontSize("small")
    local minLabelW = math.min(getTextW(labelText) or 0, math.floor(width * 0.45))
    local valueMaxW = math.max(1, width - pad * 3 - minLabelW)
    local valueMaxH = math.max(1, height - 2 - weight * 2)
    setFittingFont("huge", value, math.max(1, valueMaxW - weight), valueMaxH)
    local valueFont = currentFont
    local valueW = getTextW(value) or 0
    setFontSize("small")
    lcd.color(c.muted)
    local labelW = math.max(0, width - pad * 3 - valueW)
    drawText(x + pad, y + math.max(1, math.floor((height - getTextH(labelText)) / 2)), fitText(labelText, labelW))
    setExactFont(valueFont)
    valueW = getTextW(value) or 0
    local valueX = math.min(x + width - pad - valueW - weight, x + width - valueW - weight)
    local valueY = y + math.max(1 + weight, math.floor((height - getTextH(value)) / 2))
    lcd.color(c.text)
    drawHeavyText(valueX, valueY, value, weight)
end

local function imageWithinLimit(path)
    if not os or type(os.stat) ~= "function" then return true end
    local ok, stat = pcall(os.stat, path)
    if not ok or type(stat) ~= "table" then return true end
    local size = stat.size or stat.length or stat.fileSize or stat.filesize
    return type(size) ~= "number" or size <= MAX_MODEL_IMAGE_BYTES
end

local function bitmapMemoryAvailable()
    local fn = system and system.getMemoryUsage
    if type(fn) ~= "function" then return true end
    local ok, memory = pcall(fn)
    if not ok or type(memory) ~= "table" then return true end
    local free = tonumber(memory.luaBitmapsRamAvailable)
    return not free or free >= MIN_MODEL_IMAGE_RAM
end

local function bitmapDimensionsWithinLimit(bitmap)
    if not bitmap then return false end
    local function dimension(name)
        local fn = safeMember(bitmap, name)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, bitmap)
        return ok and tonumber(value) or nil
    end
    local width, height = dimension("width"), dimension("height")
    return (not width or width <= MAX_MODEL_IMAGE_WIDTH)
        and (not height or height <= MAX_MODEL_IMAGE_HEIGHT)
end

local function modelBitmap(w)
    if w.imageFile and w.imageFile ~= "" then
        if w.selectedFile ~= w.imageFile then
            w.selectedBmp, w.selectedFile = nil, w.imageFile
            if lcd.loadBitmap and imageWithinLimit(w.imageFile) and bitmapMemoryAvailable() then
                local ok, loaded = pcall(lcd.loadBitmap, w.imageFile)
                if ok and bitmapDimensionsWithinLimit(loaded) then w.selectedBmp = loaded end
            end
        end
        return w.selectedBmp
    else
        if w.selectedBmp then
            w.selectedBmp, w.selectedFile = nil, nil
        end
        if not defaultIconAttempted and lcd.loadBitmap then
            defaultIconAttempted = true
            local ok, loaded = pcall(lcd.loadBitmap, "SCRIPTS:/MultiDash/MultiDash.png")
            if ok then defaultIconBmp = loaded end
        end
        return defaultIconBmp
    end
end

local function drawTopStatusStripV2(w, c, scale, x, y, width, height, armed)
    if height <= 0 then return end
    roundPanel(x, y, width, height, c.panel, c.outline)
    local pad = px(5, scale, 3, 8)
    local imgPad = px(1, scale, 1, 2)
    local imgW = math.min(height - imgPad * 2, px(87, scale, 42, 90), math.floor(width * 0.28))
    drawBitmapBox(x + imgPad, y + imgPad, imgW, height - imgPad * 2, modelBitmap(w))
    setFontSize("small")
    local armedText = T(w, "ARMED")
    local pillPad = px(16, scale, 10, 22)
    local pillW = clamp((getTextW(armedText) or 0) + pillPad * 2, px(70, scale, 58, 86), math.floor(width * 0.38))
    local textX = x + imgPad + imgW + px(8, scale, 4, 12)
    local textW = math.max(0, width - (textX - x) - pad * 2 - pillW)
    if sourcePresent(w.statusSource) and textW > 0 then
        drawStatusBar(w, c, scale, textX, y + imgPad, textW, height - imgPad * 2)
    end
    if armed then
        setFittingFont("small", armedText, pillW - px(8, scale, 4, 10), height - 4)
        local pillH = clamp(getTextH(armedText) + px(8, scale, 5, 10), px(20, scale, 17, 24), height - 4)
        local pillX = x + width - pad - pillW
        local pillY = y + math.floor((height - pillH) / 2)
        roundPanel(pillX, pillY, pillW, pillH, c.warn, c.outline)
        local txt = fitText(armedText, pillW - px(8, scale, 4, 10))
        lcd.color(lcd.RGB(0, 0, 0))
        drawText(pillX + math.floor((pillW - (getTextW(txt) or 0)) / 2),
            pillY + math.max(1, math.floor((pillH - getTextH(txt)) / 2)), txt)
    end
end

local function drawLinkCardV2(w, c, scale, x, y, width, height)
    local raw = getVal(w.rssiSource)
    local link = wholeNumber(filteredValue(w, "link", raw, 0.35))
    local unit = sourceUnit(w.rssiSource)
    local linkName = string.lower(sourceName(w.rssiSource, ""))
    local percentUnit = unit == "%" or unit:lower():find("percent", 1, true) ~= nil
        or (unit == "" and (linkName:find("lq", 1, true)
            or linkName:find("rqly", 1, true) or linkName:find("quality", 1, true)
            or linkName:find("vfr", 1, true)))
    local col = w.rssiSource and score(w, "link", link, c) or c.neutral
    roundPanel(x, y, width, height, c.panel, c.outline)
    local savedScale = currentTextScale
    local pad = px(8, scale, 4, 12)
    local innerX, innerY = x + 2, y + 2
    local innerW, innerH = math.max(1, width - 4), math.max(1, height - 4)
    roundPanel(innerX, innerY, innerW, innerH, col)
    setFontSize("small")
    local label = sourceName(w.rssiSource, T(w, "Link"))
    local suffix = percentUnit and "%" or unit
    local txt = w.rssiSource and (tostring(percentUnit and clamp(link, 0, 100) or link) .. suffix) or "--"
    local minText = T(w, "Min") .. ": " .. (w.linkMin ~= nil and (tostring(wholeNumber(w.linkMin)) .. suffix) or "--")
    local maxH = math.max(1, height - 4)
    local usableX, usableW = x + pad, math.max(1, width - pad * 2)
    local sideW = math.floor(usableW * 0.30)
    local minW = math.max(1, usableW - sideW * 2)
    local linkWeight = savedScale >= TEXT_SCALE_LARGE and 1 or 0
    local linkExtent = linkWeight
    setFittingFont("large", txt, math.max(1, sideW - linkExtent), maxH)
    local textY = y + math.max(1, math.floor((height - getTextH(txt)) / 2))
    drawCenteredText(label, usableX, sideW, textY, c.muted, linkWeight)
    drawCenteredText(minText, usableX + sideW, minW, textY, lcd.RGB(255, 255, 255), linkWeight)
    drawCenteredText(txt, usableX + sideW + minW, sideW, textY, lcd.RGB(0, 0, 0), linkWeight)
end

local function drawBatteryTowerV2(w, c, scale, x, y, width, height, info)
    local pad = px(12, scale, 6, 18)
    local largeFooter = currentTextScale >= TEXT_SCALE_LARGE
    local footerH = math.min(math.max(1, height - 1), gaugeFooterHeight())
    local bodyH = math.max(1, height - footerH - pad * 2)
    local capW = px(11, scale, 7, 16)
    local capGap = px(3, scale, 2, 5)
    local batteryW = math.max(1, width - pad * 2 - capW - capGap)
    local batteryH = math.max(1, math.min(math.floor(bodyH * 0.94), math.floor(batteryW * 0.38)))
    local bx = x + pad
    local by = y + pad + math.floor((bodyH - batteryH) / 2)
    local segments = 8
    local gap = px(3, scale, 1, 5)
    local innerX, innerY = bx + 4, by + 4
    local innerW, innerH = math.max(1, batteryW - 8), math.max(1, batteryH - 8)
    local segW = math.floor((innerW - (segments - 1) * gap) / segments)
    local slices = batteryIconSlicesFor(info.ratio, segments)
    roundPanel(bx, by, batteryW, batteryH, c.bg, c.outline)
    for i = 1, segments do
        local filled = i <= slices
        lcd.color(filled and info.color or c.batteryEmpty)
        lcd.drawFilledRectangle(innerX + (i - 1) * (segW + gap), innerY, segW, innerH)
    end
    lcd.color(c.outline)
    lcd.drawFilledRectangle(bx + batteryW + capGap, by + math.floor(batteryH * 0.28), capW, math.floor(batteryH * 0.44))
    local vText = string.format("%.2fV", info.raw)
    local pText = info.needsCells and T(w, "SET CELLS")
        or (info.percent ~= nil and string.format("%d%%", math.floor(info.percent + 0.5)) or "--")
    if largeFooter then
        setFittingFont("huge", vText .. pText, width - pad * 2,
            math.max(1, footerH - px(2, scale, 1, 3)))
    else
        setFittingFont("large", vText .. pText, width - pad * 2,
            math.max(1, footerH - px(4, scale, 2, 6)))
    end
    local vW, pW = getTextW(vText) or 0, getTextW(pText) or 0
    local footerTextH = getTextH(vText)
    local footerY = largeFooter and (y + height - footerTextH - px(6, scale, 4, 8))
        or (y + height - footerH + px(4, scale, 2, 8))
    local weight = currentFontSetting == 3 and 2 or 0
    local vX, pX = x + pad, x + width - pad - pW - weight
    lcd.color(info.color)
    if weight > 0 then
        drawHeavyText(vX, footerY, vText, weight)
        drawHeavyText(pX, footerY, pText, weight)
    else
        drawText(vX, footerY, vText)
        drawText(pX, footerY, pText)
    end
    gap = px(5, scale, 3, 8)
    drawFooterCurrent(w, c, scale, vX + vW + gap, pX - gap, footerY, footerTextH,
        x + math.floor(width / 2))
end

local function drawMiniBattery(c, scale, x, y, width, height, info)
    local capW = clamp(math.floor(height * 0.18), px(5, scale, 3, 7), px(15, scale, 9, 18))
    local capGap = clamp(math.floor(height * 0.05), 1, px(4, scale, 2, 6))
    local bodyW = math.max(1, width - capW - capGap)
    roundPanel(x, y, bodyW, height, c.bg, c.outline)
    local inset = clamp(math.floor(height * 0.12), px(3, scale, 2, 4), px(7, scale, 5, 9))
    local gap = clamp(math.floor(height * 0.06), 1, px(5, scale, 3, 6))
    local segments = 8
    local innerW = math.max(1, bodyW - inset * 2)
    local segmentW = math.max(1, math.floor((innerW - gap * (segments - 1)) / segments))
    local slices = batteryIconSlicesFor(info.ratio, segments)
    for i = 1, segments do
        lcd.color(i <= slices and info.color or c.batteryEmpty)
        lcd.drawFilledRectangle(x + inset + (i - 1) * (segmentW + gap), y + inset,
            segmentW, math.max(1, height - inset * 2))
    end
    lcd.color(c.outline)
    lcd.drawFilledRectangle(x + bodyW + capGap, y + math.floor(height * 0.28),
        capW, math.max(1, math.floor(height * 0.44)))
end

local function drawDualFooterValue(scale, x, y, width, height, value, detail, color)
    local pad = px(4, scale, 2, 6)
    local gap = px(2, scale, 1, 3)
    local weight = preset(0, 1, 2)
    setFittingFont("small", detail, width - pad * 2, math.floor(height * 0.38))
    detail = fitText(detail, width - pad * 2)
    local detailFont = currentFont
    local detailH = getTextH(detail)
    local valueH = math.max(1, height - pad * 2 - gap - detailH)
    setFittingFont("huge", value, width - pad * 2 - weight, valueH)
    local valueTextH = getTextH(value)
    local top = y + math.max(pad, math.floor((height - valueTextH - gap - detailH) / 2))
    drawCenteredText(value, x + pad, width - pad * 2, top, color, weight)
    setExactFont(detailFont)
    drawCenteredText(detail, x + pad, width - pad * 2, top + valueTextH + gap, color, weight)
end

local function drawDualBatteryCockpitV2(w, c, scale, x, y, width, height)
    local info = dualPowerInfo(w, c)
    roundPanel(x, y, width, height, c.panel, c.outline)
    local pad = px(6, scale, 3, 9)
    local gap = px(8, scale, 4, 12)
    local contentY = y + pad
    local contentH = math.max(1, y + height - pad - contentY)
    local contentX, contentW = x + pad, width - pad * 2

    local footerH = math.min(math.max(1, contentH - 1), gaugeFooterHeight() + 18)
    local footerY = contentY + contentH - footerH
    local gaugeW = math.floor(contentW / 2)
    local secondW = contentW - gaugeW
    local gaugeBoxH = math.max(1, footerY - gap - contentY)
    roundPanel(contentX, contentY, contentW, gaugeBoxH, c.panelAlt, c.outline)
    lcd.color(c.outline)
    lcd.drawFilledRectangle(contentX + gaugeW, contentY + 1, 1, math.max(1, gaugeBoxH - 2))
    local labelY = contentY + pad
    setFontSize("small")
    local labelH = getTextH("BATTERY 1")
    drawCenteredText(T(w, "Battery 1"):upper(), contentX + pad, gaugeW - pad * 2,
        labelY, c.muted, px(1, scale, 1, 2))
    drawCenteredText(T(w, "Battery 2"):upper(), contentX + gaugeW + pad,
        secondW - pad * 2, labelY, c.muted, px(1, scale, 1, 2))

    local gaugeTop = labelY + labelH + px(3, scale, 2, 5)
    local gaugeBottom = contentY + gaugeBoxH - pad
    local gaugeAreaH = math.max(1, gaugeBottom - gaugeTop)
    local availableW = math.min(gaugeW, secondW) - pad * 2
    local iconH = math.max(px(20, scale, 17, 26),
        math.min(math.floor(gaugeAreaH * 0.98), math.floor(availableW * 0.47)))
    iconH = math.min(iconH, gaugeAreaH)
    local iconW = math.min(availableW, math.floor(iconH * 3.7))
    local iconY = gaugeTop + math.max(0, math.floor((gaugeAreaH - iconH) / 2))
    drawMiniBattery(c, scale, contentX + math.floor((gaugeW - iconW) / 2),
        iconY, iconW, iconH, info[1])
    drawMiniBattery(c, scale, contentX + gaugeW + math.floor((secondW - iconW) / 2),
        iconY, iconW, iconH, info[2])

    local centerW = math.floor(contentW * 0.34)
    local sideW = math.floor((contentW - centerW) / 2)
    local rightW = contentW - centerW - sideW
    local compactFooter = sideW < 115
    roundPanel(contentX, footerY, contentW, footerH, c.bg, c.outline)
    lcd.color(c.outline)
    lcd.drawFilledRectangle(contentX + sideW, footerY + 1, 1, math.max(1, footerH - 2))
    lcd.drawFilledRectangle(contentX + sideW + centerW, footerY + 1, 1, math.max(1, footerH - 2))
    lcd.color(info.color)
    lcd.drawFilledRectangle(contentX + sideW + 1, footerY + 1,
        math.max(1, centerW - 1), px(3, scale, 2, 4))

    local firstValue = info[1].online and string.format("%.2fV", info[1].raw) or "--"
    local firstDetail = info[1].needsCells and T(w, "SET CELLS") or (info[1].online
        and string.format(compactFooter and "%.2f/C %d%%" or "%.2fV/C %d%%",
            info[1].perCell, math.floor(info[1].percent + 0.5))
        or T(w, "NO SENSOR"))
    local secondValue = info[2].online and string.format("%.2fV", info[2].raw) or "--"
    local secondDetail = info[2].needsCells and T(w, "SET CELLS") or (info[2].online
        and string.format(compactFooter and "%.2f/C %d%%" or "%.2fV/C %d%%",
            info[2].perCell, math.floor(info[2].percent + 0.5))
        or T(w, "NO SENSOR"))
    local totalValue = info.total and string.format("%.2fV", info.total) or "--"
    local totalDetail = info.total
        and (compactFooter and (tostring(info.cells) .. "S " .. T(w, "Series"):upper())
            or (tostring(info.cells) .. "S " .. string.format("%.2fV/C ", info.deltaPerCell or 0)
                .. T(w, "Diff"):upper()))
        or T(w, "WAITING")
    drawDualFooterValue(scale, contentX, footerY, sideW, footerH,
        firstValue, firstDetail, info[1].online and info[1].color or c.bad)
    drawDualFooterValue(scale, contentX + sideW, footerY, centerW, footerH,
        totalValue, totalDetail, info.total and info.color or c.bad)
    drawDualFooterValue(scale, contentX + sideW + centerW, footerY, rightW, footerH,
        secondValue, secondDetail, info[2].online and info[2].color or c.bad)
end

local function drawPowerCockpitV2(w, c, scale, x, y, width, height, halfGauge, forceGauge, pairedMainW)
    local info = powerInfo(w, c)
    roundPanel(x, y, width, height, c.panel, c.outline)
    local sliced = halfGauge == "left" or halfGauge == "right"
    local pad = sliced and px(5, scale, 3, 8) or px(8, scale, 4, 12)
    setFontSize("small")
    lcd.color(c.muted)
    drawText(x + pad, y + px(5, scale, 3, 8), info.fuelMode and T(w, "Fuel") or T(w, "Battery"))
    local innerX = x + pad
    local innerY = y + (sliced and px(12, scale, 8, 16) or px(18, scale, 12, 24))
    local innerW, innerBottom = width - pad * 2, y + height - pad
    if pairedMainW then
        innerW = math.min(innerW, pairedMainW)
        if halfGauge == "left" then innerX = x + width - pad - innerW end
    end
    if info.gauge or forceGauge then
        local gaugeValue = info.fuelMode and info.value or (info.percent or 0)
        local gaugeShift = sliced and 3 or 0
        local leftText, midText, rightText
        local footerText = info.needsCells and T(w, "SET CELLS") or nil
        if not info.fuelMode then leftText, midText, rightText = "0", "50", "100" end
        drawFuelGauge(w, c, scale, innerX, innerW, innerY - gaugeShift, innerBottom - gaugeShift, gaugeValue,
            width > height and 1.22 or 1.06, x + math.floor(width / 2), innerBottom - gaugeShift,
            not info.fuelMode, info.raw, info.color, true, nil, nil, nil, footerText,
            leftText, midText, rightText, halfGauge)
    else
        drawBatteryTowerV2(w, c, scale, innerX, innerY + 10, innerW, innerBottom - innerY - 10, info)
    end
end

local function formatRpmScale(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value >= 1000 then return tostring(math.floor(value / 1000 + 0.5)) .. "K" end
    return tostring(value)
end

local function drawRpmCockpitV2(w, c, scale, x, y, width, height, halfGauge, pairedMainW)
    local rpm = w.rpmSource and math.max(0, filteredValue(w, "rpm", getVal(w.rpmSource), 0.3)) or 0
    local maxRpm = clamp(math.floor(tonumber(w.rpmMax) or 8000), 1000, 50000)
    local warnRpm = clamp(math.floor(tonumber(w.rpmWarn) or maxRpm * 0.8), 0, maxRpm)
    local pct = clamp(rpm * 100 / maxRpm, 0, 100)
    local warnPct = warnRpm * 100 / maxRpm
    local col = rpm >= maxRpm and c.bad or (rpm >= warnRpm and c.warn or c.good)
    roundPanel(x, y, width, height, c.panel, c.outline)
    local sliced = halfGauge == "left" or halfGauge == "right"
    local pad = sliced and px(5, scale, 3, 8) or px(8, scale, 4, 12)
    setFontSize("small")
    lcd.color(c.muted)
    local title = T(w, "RPM")
    drawText(x + width - pad - (getTextW(title) or 0), y + px(5, scale, 3, 8), title)
    local topPad = halfGauge == "right" and px(12, scale, 8, 16) or px(18, scale, 12, 24)
    local gaugeShift = sliced and 3 or 0
    local innerW = pairedMainW and math.min(width - pad * 2, pairedMainW) or (width - pad * 2)
    drawFuelGauge(w, c, scale, x + pad, innerW, y + topPad - gaugeShift, y + height - pad - gaugeShift,
        pct, width > height and 1.22 or 1.06, x + math.floor(width / 2), y + height - pad - gaugeShift,
        false, nil, col, false, true, warnPct, 100, formatValue(rpm) .. " " .. T(w, "RPM"),
        "0", formatRpmScale(maxRpm / 2), formatRpmScale(maxRpm), halfGauge)
end

local function drawGaugePairV2(w, c, scale, x, y, width, height)
    local gaugeW = math.floor(width / 2)
    local pad = px(5, scale, 3, 8)
    local mainW = math.max(1, math.min(gaugeW, width - gaugeW) - pad * 2)
    local span = math.max(1, height - pad - px(12, scale, 8, 16))
    local footerH = math.min(math.max(1, span - 1), gaugeFooterHeight())
    local radius = math.max(1, math.min(mainW - 1, math.floor((span - footerH) * 0.98)))
    local info = powerInfo(w, c)
    local powerValue = info.fuelMode and info.value or (info.percent or 0)
    local powerText = string.format("%.2fV", info.raw) .. tostring(math.floor(powerValue + 0.5)) .. "%"
    local rpm = w.rpmSource and math.max(0, (getVal(w.rpmSource))) or 0
    local rpmText = formatValue(rpm) .. " " .. T(w, "RPM")
    local footerMaxH = math.max(12, footerH - 1)
    local inset = math.max(px(5, scale, 3, 7), math.floor(radius * 0.06))
    local batteryMaxW = math.max(1, mainW - inset * 2)
    local rpmMaxW = math.max(1, mainW - inset * 2)
    local textSetting = currentTextScale >= TEXT_SCALE_LARGE and 3
        or (currentTextScale <= TEXT_SCALE_SMALL and 1 or 2)
    local ladders = mainW < 180 and compactPairedFonts or widePairedFonts
    for i = 1, #ladders[textSetting] do
        local font = ladders[textSetting][i]
        if font ~= nil then
            setExactFont(font)
            if getTextW(powerText) <= batteryMaxW and getTextW(rpmText) <= rpmMaxW
                and getTextH(powerText) <= footerMaxH and getTextH(rpmText) <= footerMaxH then
                pairedFooterFont = font
                break
            end
        end
    end
    if pairedFooterFont == nil then
        setAvailableFont(fontS, fontL, fontXL, fontXXL)
        pairedFooterFont = currentFont
    end
    drawPowerCockpitV2(w, c, scale, x, y, gaugeW, height, "left", true, mainW)
    drawRpmCockpitV2(w, c, scale, x + gaugeW, y, width - gaugeW, height, "right", mainW)
    pairedFooterFont = nil
end

local function flightSource(w, index)
    if index == 1 then return w.inFlight1Source, T(w, "Stat 1") end
    if index == 2 then return w.inFlight2Source, T(w, "Stat 2") end
    if index == 3 then return w.inFlight3Source, T(w, "Stat 3") end
    return w.inFlight4Source, T(w, "Stat 4")
end

local function telemetrySource(w, index)
    if index == 1 then return w.field1Source, T(w, "Tlm 1") end
    if index == 2 then return w.field2Source, T(w, "Tlm 2") end
    if index == 3 then return w.field3Source, T(w, "Tlm 3") end
    return w.telemetry4Source, T(w, "Tlm 4")
end

local function drawRailItem(w, c, scale, x, cursor, width, height, kind, label, value, color)
    if kind == "link" then
        drawLinkCardV2(w, c, scale, x, cursor, width, height)
    elseif kind == "timer" then
        drawTimerCardV2(w, c, scale, x, cursor, width, height, label)
    else
        drawCardV2(c, scale, x, cursor, width, height, label, value, color)
    end
    return cursor + height
end

local function drawRailV2(w, c, scale, x, y, width, height, flightMode)
    local compact = height < px(230, scale, 168, 250)
    local gap = compact and 1 or px(3, scale, 1, 5)
    local cursor = y
    if flightMode then
        local timerH = px(64, scale, 46, 72)
        local rowAreaH = math.max(0, height - timerH - gap)
        local rowH = math.max(px(20, scale, 17, 24), math.floor((rowAreaH - gap * 3) / 4))
        for i = 1, 4 do
            local src, label = flightSource(w, i)
            if src then drawCardV2(c, scale, x, cursor, width, rowH,
                sourceName(src, label), formatValue(getVal(src)), c.text) end
            cursor = cursor + rowH + gap
        end
        drawTimerCardV2(w, c, scale, x, y + height - timerH, width, timerH, T(w, "Timer"))
        return
    end
    local currentInRail = sourcePresent(w.currentSource)
        and ((w.rotorwingMode or 1) == 2 or (w.batteryMode or 1) == 2)
    local rpmInRail = sourcePresent(w.rpmSource)
        and (w.rotorwingMode or 1) ~= 2
    local telemetryRows = (w.field1Source and 1 or 0) + (w.field2Source and 1 or 0)
        + (w.field3Source and 1 or 0) + (w.telemetry4Source and 1 or 0)
    local count = 2 + (currentInRail and 1 or 0) + (rpmInRail and 1 or 0) + telemetryRows
    local availableH = math.max(1, height - gap * (count - 1))
    local unitH = math.max(1, math.floor(availableH / count))
    local extra = availableH - unitH * count
    local linkH = unitH + math.floor(extra / 2)
    local timerH = unitH + extra - math.floor(extra / 2)
    cursor = drawRailItem(w, c, scale, x, cursor, width, linkH, "link") + gap
    cursor = drawRailItem(w, c, scale, x, cursor, width, timerH, "timer", flightCountText(w)) + gap
    if currentInRail then
        cursor = drawRailItem(w, c, scale, x, cursor, width, unitH, "card", T(w, "Current"),
            formatAmps(filteredValue(w, "current", getVal(w.currentSource), 0.3)), c.secondary) + gap
    end
    if rpmInRail then
        cursor = drawRailItem(w, c, scale, x, cursor, width, unitH, "card",
            sourceName(w.rpmSource, T(w, "RPM")),
            formatValue(filteredValue(w, "rpm", getVal(w.rpmSource), 0.3)), c.secondary) + gap
    end
    for i = 1, 4 do
        local src, label = telemetrySource(w, i)
        if src then
            cursor = drawRailItem(w, c, scale, x, cursor, width, unitH, "card",
                sourceName(src, label), formatValue(getVal(src)), c.text) + gap
        end
    end
end

local function drawMainV2(w, c, scale, scrW, scrH, telemetryOk)
    lcd.color(c.bg)
    lcd.drawFilledRectangle(0, 0, scrW, scrH)
    local margin = px(10, scale, 5, math.floor(scrW * 0.035))
    local gap = px(7, scale, 4, 10)
    local railW = railWidthFor(scrW)
    local powerW = scrW - margin * 2 - gap - railW
    if powerW < scrW * 0.52 then
        railW = math.floor(scrW * 0.32)
        powerW = scrW - margin * 2 - gap - railW
    end
    local showRpmGauge = (w.rotorwingMode or 1) == 2
    local dualMode = (w.powerSourceType or 1) ~= 2 and (w.batteryMode or 1) == 2
    local modelH = px(preset(44, 48, 58), scale,
        preset(40, 44, 50), preset(56, 64, 74))
    local modelGap = px(5, scale, 3, 7)
    local gaugeY = margin + modelH + modelGap
    local gaugeH = scrH - margin - gaugeY
    drawTopStatusStripV2(w, c, scale, margin, margin, powerW, modelH, w.armSeenAt ~= nil)
    if dualMode then
        drawDualBatteryCockpitV2(w, c, scale, margin, gaugeY, powerW, gaugeH)
    elseif showRpmGauge then
        drawGaugePairV2(w, c, scale, margin, gaugeY, powerW, gaugeH)
    else
        drawPowerCockpitV2(w, c, scale, margin, gaugeY, powerW, gaugeH)
    end
    drawRailV2(w, c, scale, margin + powerW + gap, margin, railW, scrH - margin * 2, false)
    if not telemetryOk then drawNoTelemetry(w, c, scrW, scrH) end
end

local function drawInFlightV2(w, c, scale, scrW, scrH)
    lcd.color(c.bg)
    lcd.drawFilledRectangle(0, 0, scrW, scrH)
    local compact = scrH < px(250, scale, 190, 280)
    local margin = compact and px(7, scale, 4, 9) or px(9, scale, 4, math.floor(scrW * 0.035))
    local gap = compact and px(5, scale, 3, 7) or px(7, scale, 4, 10)
    local showRpmGauge = (w.rotorwingMode or 1) == 2
    local dualMode = (w.powerSourceType or 1) ~= 2 and (w.batteryMode or 1) == 2
    local linkH = showRpmGauge and px(preset(42, 46, 56), scale,
            preset(38, 42, 48), preset(50, 54, 68))
        or (compact and px(preset(42, 46, 56), scale,
                preset(38, 42, 48), preset(50, 52, 68))
            or px(preset(50, 58, 68), scale,
                preset(42, 44, 54), preset(62, 70, 84)))
    drawLinkCardV2(w, c, scale, margin, margin, scrW - margin * 2, linkH)
    local top = margin + linkH + gap
    local railW = railWidthFor(scrW)
    local powerW = scrW - margin * 2 - gap - railW
    local contentH = scrH - top - margin
    if dualMode then
        drawDualBatteryCockpitV2(w, c, scale, margin, top, powerW, contentH)
    elseif showRpmGauge then
        drawGaugePairV2(w, c, scale, margin, top, powerW, contentH)
    else
        drawPowerCockpitV2(w, c, scale, margin, top, powerW, contentH)
    end
    drawRailV2(w, c, scale, margin + powerW + gap, top, railW, scrH - top - margin, true)
end

local function paint(w, ...)
    currentFont = nil
    metricText, metricFont = nil, nil
    local fontSetting = clamp(math.floor(finiteNumber(w.fontSize) or 2), 1, 3)
    currentFontSetting = fontSetting
    if fontSetting == 1 then
        currentTextScale = TEXT_SCALE_SMALL
    elseif fontSetting == 3 then
        currentTextScale = TEXT_SCALE_LARGE
    else
        currentTextScale = TEXT_SCALE_MEDIUM
    end
    local scrW, scrH = windowSize(...)
    local scale = scaleFor(scrW, scrH)
    local c = theme(w)
    if not isUsableWidgetSize(scrW, scrH) then
        drawSizePrompt(w, c, scale, scrW, scrH)
        return
    end
    if w.postFlight and not w.flightActive then
        drawPostFlight(w, c, scale, scrW, scrH)
        return
    end
    local telemetryOk = telemetryPresent(w)
    if w.flightActive and tonumber(w.inFlightScreen) ~= 2 then
        drawInFlightV2(w, c, scale, scrW, scrH)
        if not telemetryOk then
            drawNoTelemetry(w, c, scrW, scrH)
        end
        return
    end
    drawMainV2(w, c, scale, scrW, scrH, telemetryOk)
end
local function wakeup(w)
    if not w then return end
    local now = os.clock()
    if now >= (w.nextRefresh or 0) then
        local armed = updateFlight(w, now)
        w._armed = armed
        updateLinkMinimum(w, now)
        updateAudioCues(w, armed)
        local visible = true
        if lcd and type(lcd.isVisible) == "function" then
            local ok, value = pcall(lcd.isVisible)
            if ok and value == false then visible = false end
        end
        local interval = not visible and 1.0 or ((armed or w.flightActive) and 0.1 or (w.postFlight and 0.5 or 0.25))
        w.nextRefresh = now + interval
        if visible and lcd and type(lcd.invalidate) == "function" then
            pcall(lcd.invalidate)
        end
    end
    if w.dirty and now - (w.dirtyAt or 0) > 0.5 then
        if not flush(w) then
            w.dirtyAt = now + 4.5
        end
    end
end
local function close(w)
    if not w then return end
    w.selectedBmp, w.selectedFile, w._powerInfo, w._dualPowerInfo = nil, nil, nil, nil
    w._filtered, w._batteryLevels, w._sourceClears = nil, nil, nil
    w._timerTextSeconds, w._timerText = nil, nil
    w._flightLabelCount, w._flightLabelLanguage, w._flightLabel = nil, nil, nil
    w._audioArmSource, w._audioArmed, w._telemetryCuePlayed = nil, nil, nil
    w.stats, w.statOrder = nil, nil
    defaultIconBmp, defaultIconAttempted = nil, false
    summaryModule, summaryApi = nil, nil
end

return {
    create = create,
    paint = paint,
    wakeup = wakeup,
    configure = configure,
    read = read,
    write = write,
    close = close,
}
