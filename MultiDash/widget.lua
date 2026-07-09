local i18n = assert(loadfile("i18n.lua"))()
local summaryModule
local summaryApi
local LINK_MIN_GRACE = 5
local currentFont
local storageModule
local function T(widget, key) return i18n.text(widget, key) end
local function getTextW(txt)
    if lcd and type(lcd.getTextSize) == "function" then
        local ok, w = pcall(lcd.getTextSize, txt or "")
        if ok then return w or 0 end
    end
    return 0
end
local function getTextH(txt)
    if lcd and type(lcd.getTextSize) == "function" then
        local ok, _, h = pcall(lcd.getTextSize, txt or "")
        if ok then return h or 18 end
    end
    return 18
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
    return tonumber(w) or 480, tonumber(h) or 320
end
local function isUsableWidgetSize(w, h)
    w, h = math.floor(w), math.floor(h)
    if (w == 784 and (h == 294 or h == 316))
        or (w == 472 and (h == 191 or h == 210))
        or (w == 630 and (h == 236 or h == 258)) then
        return true
    end
    if w < 460 or h < 185 then return false end
    local ratio = w / h
    return ratio >= 1.95 and ratio <= 3.35
end
local function px(v, scale, lo, hi)
    local n = math.floor(v * scale + 0.5)
    if hi and lo and hi < lo then
        lo = hi
    end
    return clamp(n, lo, hi)
end
local function fillRoundRect(x, y, w, h, radius, color)
    lcd.color(color)
    radius = math.max(0, math.min(radius or 0, math.floor(w / 2), math.floor(h / 2)))
    if radius < 2 or not lcd.drawFilledCircle then
        lcd.drawFilledRectangle(x, y, w, h)
        return
    end
    lcd.drawFilledRectangle(x + radius, y, w - radius * 2, h)
    lcd.drawFilledRectangle(x, y + radius, w, h - radius * 2)
    lcd.drawFilledCircle(x + radius, y + radius, radius)
    lcd.drawFilledCircle(x + w - radius - 1, y + radius, radius)
    lcd.drawFilledCircle(x + radius, y + h - radius - 1, radius)
    lcd.drawFilledCircle(x + w - radius - 1, y + h - radius - 1, radius)
end
local function roundPanel(x, y, w, h, radius, fill, outline)
    if outline then
        fillRoundRect(x, y, w, h, radius, outline)
        fillRoundRect(x + 1, y + 1, w - 2, h - 2, math.max(0, radius - 1), fill)
    else
        fillRoundRect(x, y, w, h, radius, fill)
    end
end
local palettes = {
    dark = {
        bg = lcd.RGB(20, 24, 28),
        text = lcd.RGB(255, 255, 255),
        muted = lcd.RGB(160, 160, 160),
        secondary = lcd.RGB(200, 200, 200),
        neutral = lcd.RGB(220, 220, 220),
        outline = lcd.RGB(255, 255, 255),
        barFrame = lcd.RGB(100, 100, 100),
        batteryEmpty = lcd.RGB(0, 0, 0),
        good = lcd.RGB(0, 255, 100),
        warn = lcd.RGB(255, 130, 0),
        bad = lcd.RGB(255, 50, 50),
        alertBg = lcd.RGB(255, 255, 255),
        alertText = lcd.RGB(255, 0, 0),
    },
    light = {
        bg = lcd.RGB(235, 238, 242),
        text = lcd.RGB(20, 24, 28),
        muted = lcd.RGB(80, 86, 94),
        secondary = lcd.RGB(70, 76, 84),
        neutral = lcd.RGB(45, 50, 58),
        outline = lcd.RGB(35, 40, 48),
        barFrame = lcd.RGB(95, 102, 112),
        batteryEmpty = lcd.RGB(215, 220, 226),
        good = lcd.RGB(0, 150, 80),
        warn = lcd.RGB(220, 105, 0),
        bad = lcd.RGB(210, 30, 30),
        alertBg = lcd.RGB(0, 0, 0),
        alertOutline = lcd.RGB(255, 255, 255),
        alertText = lcd.RGB(185, 0, 0),
    },
}
local function theme(widget)
    if widget and tonumber(widget.themeMode) == 2 then
        return palettes.light
    end
    return palettes.dark
end
local function setAvailableFont(...)
    if not lcd or type(lcd.font) ~= "function" then
        return
    end
    for i = 1, select("#", ...) do
        local f = _G[select(i, ...)]
        if f ~= nil then
            if f == currentFont then
                return
            end
            currentFont = f
            pcall(lcd.font, f)
            return
        end
    end
end
local function setFontSize(size, scale)
    if size == "huge" then
        if scale < 0.7 then
            setAvailableFont("FONT_L", "FONT_XL", "FONT_XXL", "FONT_S")
        elseif scale < 0.95 then
            setAvailableFont("FONT_XL", "FONT_XXL", "FONT_L", "FONT_S")
        else
            setAvailableFont("FONT_XXL", "FONT_XL", "FONT_L", "FONT_S")
        end
    elseif size == "large" then
        if scale < 0.7 then
            setAvailableFont("FONT_S", "FONT_L", "FONT_XL")
        elseif scale < 0.95 then
            setAvailableFont("FONT_L", "FONT_XL", "FONT_S")
        else
            setAvailableFont("FONT_XL", "FONT_L", "FONT_S")
        end
    else
        setAvailableFont("FONT_S", "FONT_L", "FONT_XL")
    end
end
local function drawVoltagePercentStack(centerX, y, batt, percent, color, scale)
    local vText = string.format("%.2fV", batt)
    local percentText = percent ~= nil and string.format("%d%%", math.floor(percent + 0.5)) or nil
    setFontSize("huge", scale)
    local vW = getTextW(vText) or 0
    lcd.color(color)
    lcd.drawText(centerX - math.floor(vW / 2), y, vText)
    if percentText then
        setFontSize("huge", scale * 0.95)
        lcd.drawText(centerX - math.floor((getTextW(percentText) or 0) / 2),
            y + px(38, scale, 22, 46) + 5, percentText)
    end
end
local function drawSizePrompt(w, c, scale, scrW, scrH)
    lcd.color(c.bg)
    lcd.drawFilledRectangle(0, 0, scrW, scrH)
    local msg = T(w, "Use Single Large Widget")
    setFontSize("huge", scale)
    if getTextW(msg) > scrW - 12 then
        setFontSize("large", scale)
    end
    local tw = getTextW(msg) or 0
    local x = math.max(0, math.floor((scrW - tw) / 2))
    local y = math.max(0, math.floor(scrH / 2) - px(18, scale, 10, 24))
    lcd.color(c.bad)
    lcd.drawText(x, y, msg)
    for i = 1, px(2, scale, 1, 3) do
        lcd.drawText(x + i, y, msg)
    end
end
local bitmapScaleSupported = nil
local bitmapBasicSupported = nil
local function drawBitmapBox(x, y, w, h, bmp)
    if not bmp then
        return 
    end
    if bitmapScaleSupported == true then
        lcd.drawBitmap(x, y, bmp, w, h)
        return 
    elseif bitmapScaleSupported == nil then
        local ok = pcall(function()
            lcd.drawBitmap(x, y, bmp, w, h)
        end)
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
        local ok = pcall(function()
            lcd.drawBitmap(bx, by, bmp)
        end)
        bitmapBasicSupported = ok
    end
    if type(lcd.setClipping) == "function" then
        pcall(lcd.setClipping)
    end
end
local function polarPoint(cx, cy, deg, radius)
    local angle = math.rad(deg)
    return cx + math.floor(math.cos(angle) * radius), cy + math.floor(math.sin(angle) * radius)
end
local function drawHeavyLine(x1, y1, x2, y2, weight)
    lcd.drawLine(x1, y1, x2, y2)
    for i = 1, weight do
        lcd.drawLine(x1 + i, y1, x2 + i, y2)
        lcd.drawLine(x1, y1 + i, x2, y2 + i)
    end
end
local function drawHeavyText(x, y, text, weight)
    lcd.drawText(x, y, text)
    for i = 1, weight do
        lcd.drawText(x + i, y, text)
    end
end
local function objectField(obj, key)
    local ok, value = pcall(function() return obj and obj[key] end)
    return ok and value or nil
end
local function methodValue(obj, key)
    local fn = objectField(obj, key)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, obj)
    if not ok then ok, value = pcall(fn) end
    return ok and value or nil
end
local function getVal(src)
    if not src then
        return 0
    end
    local t = type(src)
    if t == "number" then
        return src
    end
    if t == "string" then
        local direct = tonumber(src)
        if direct then
            return direct
        end
    end
    if t == "table" or t == "userdata" then
        local value = methodValue(src, "value")
        if value ~= nil then return tonumber(value) or 0 end
        value = objectField(src, "value")
        if type(value) == "number" or type(value) == "string" then
            return tonumber(value) or 0
        end
    end
    local s
    if system and type(system.getSource) == "function" then
        local ok, resolved = pcall(system.getSource, src)
        if ok then s = resolved end
    end
    local value = methodValue(s, "value")
    if value ~= nil then return tonumber(value) or 0 end
    return 0
end
local function sourceName(src, fallback)
    local nm = methodValue(src, "name")
    if nm and nm ~= "" then return nm end
    return fallback
end
local function switchBase(k)
    if not k then
        return nil
    end
    k = tostring(k)
    return k:match("S[A-Z]") or k:match("s[a-z]") or nil
end
local function sourceQuery(k)
    if not k then return nil end
    local category, member, options = tostring(k):match("^([^:]+):([^:]+):([^:]+)$")
    if not category or not member then return nil end
    return {
        category = tonumber(category) or category,
        member = tonumber(member) or member,
        options = tonumber(options) or options,
    }
end
local function resolveSwitch(val)
    if not val or val == "" then
        return nil
    end
    if system and type(system.getSource) == "function" then
        local query = sourceQuery(val)
        if query then
            local ok, sw = pcall(function() return system.getSource(query) end)
            if ok and sw then return sw end
        end
    end
    local tries = {}
    tries[#tries + 1] = val
    local text = tostring(val)
    tries[#tries + 1] = text:upper()
    tries[#tries + 1] = text:lower()
    local number = tonumber(text)
    if number then tries[#tries + 1] = number end
    local base = switchBase(text)
    if base then
        tries[#tries + 1] = base:upper()
        tries[#tries + 1] = base:lower()
    end
    for i = 1, #tries do
        local k = tries[i]
        if system and type(system.getSource) == "function" then
            local ok, sw = pcall(function()
                return system.getSource(k)
            end)
            if ok and sw then
                return sw
            end
        end
    end
    for i = 1, #tries do
        local k = tries[i]
        if system and type(system.getSwitch) == "function" then
            local ok, sw = pcall(function()
                return system.getSwitch(k)
            end)
            if ok and sw then
                return sw
            end
        end
    end
    return nil
end
local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

local function timerSeconds(w)
    return (w and w.timerSource and getVal(w.timerSource)) or (w and w.flightTime) or 0
end

local function formatValue(v)
    if v == nil then
        return "--"
    end
    v = tonumber(v)
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
local batteryProfiles = {
    {3.7, 3.2, 4.2, {
            3.2,
            0,
            3.5,
            5,
            3.65,
            10,
            3.72,
            20,
            3.77,
            30,
            3.8,
            40,
            3.83,
            50,
            3.87,
            60,
            3.92,
            70,
            3.98,
            80,
            4.08,
            90,
            4.2,
            100,
        },
    },
    {3.8, 3.2, 4.35, {
            3.2,
            0,
            3.55,
            5,
            3.7,
            10,
            3.78,
            20,
            3.83,
            30,
            3.87,
            40,
            3.91,
            50,
            3.96,
            60,
            4.02,
            70,
            4.1,
            80,
            4.22,
            90,
            4.35,
            100,
        },
    },
    {3.6, 3.0, 4.2, {
            3.0,
            0,
            3.25,
            5,
            3.4,
            10,
            3.5,
            20,
            3.58,
            30,
            3.64,
            40,
            3.7,
            50,
            3.77,
            60,
            3.84,
            70,
            3.92,
            80,
            4.02,
            90,
            4.2,
            100,
        },
    },
    {3.3, 2.8, 3.6, {
            2.8,
            0,
            3.0,
            5,
            3.15,
            10,
            3.22,
            20,
            3.25,
            30,
            3.27,
            40,
            3.29,
            50,
            3.3,
            60,
            3.31,
            70,
            3.33,
            80,
            3.36,
            90,
            3.6,
            100,
        },
    },
    {1.2, 0.95, 1.45, {
            0.95,
            0,
            1.05,
            10,
            1.1,
            20,
            1.15,
            30,
            1.18,
            40,
            1.2,
            50,
            1.22,
            60,
            1.24,
            70,
            1.27,
            80,
            1.32,
            90,
            1.45,
            100,
        },
    },
}
local function batteryProfile(w)
    return batteryProfiles[clamp(math.floor(tonumber(w.batteryType) or 1), 1, #batteryProfiles)]
end
local function fitText(txt, maxW)
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
    while #txt > 0 and getTextW(txt .. ".") > maxW do
        txt = txt:sub(1, #txt - 1)
    end
    return txt .. "."
end
local function fitStatusText(label, state, maxW, scale)
    local suffix = ": " .. state
    local txt = label .. suffix
    setFontSize("large", scale)
    if getTextW(txt) <= maxW then
        return txt
    end
    setFontSize("small", scale)
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
    value = tonumber(value) or 0
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
        return resolved and resolved ~= sw and switchActive(resolved) or false
    end
    if t == "table" or t == "userdata" then
        local v = methodValue(sw, "state")
        if v ~= nil then return armValueActive(v) end
        v = methodValue(sw, "active")
        if v ~= nil then return armValueActive(v) end
        v = methodValue(sw, "value")
        if v ~= nil then return armValueActive(v) end
        v = objectField(sw, "value")
        if type(v) == "number" or type(v) == "string" then
            return armValueActive(v)
        end
    end
    return armValueActive(getVal(sw))
end
local function create()
    return {
        armDelay = 5,
        inFlightScreen = 1,
        iconLoaded = false,
        cellCount = 0,
        batteryType = 1,
        language = i18n.default(),
        themeMode = 1,
        batteryStyle = 1,
        powerSourceType = 1,
        fuelShowPercent = 1,
        statusMode = 1,
        battHigh = 4.15,
        battMid = 3.75,
        battLow = 3.45,
        linkHigh = 98,
        linkMid = 80,
        currentHigh = 60,
        currentMid = 35,
        fuelHigh = 40,
        fuelMid = 20,
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
        telemetry4High = 80,
        telemetry4Mid = 30,
        telemetry4Mode = 1,
        linkMin = nil,
        linkMinSource = nil,
        linkSeenAt = nil,
        flightActive = false,
        postFlight = false,
        flightStart = 0,
        flightTime = 0,
        flightCount = 0,
        timerSource = nil,
        dirty = false,
        dirtyAt = 0,
        nextRefresh = 0,
    }
end
local function storageCall(method, widget)
    if not storageModule then
        local chunk = loadfile("storage.lua")
        if not chunk then return false end
        local ok, module = pcall(chunk)
        if not ok or type(module) ~= "table" then return false end
        storageModule = module
    end
    local fn = storageModule[method]
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, widget, i18n.valid)
    return ok and result or false
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
            tr = i18n.text,
        })
    end
end
local function score(w, prefix, value, c)
    local high = w[prefix .. "High"] or 0
    local mid = w[prefix .. "Mid"] or 0
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
    local mode = w[prefix .. "Mode"] or 1
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
    if key == "rpm" then
        return c.neutral, "INFO"
    end
    local mode = w[key .. "Mode"] or 1
    local value = mode == 2 and st.max or st.min
    local col, face = score(w, key, value, c)
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
            setFontSize = setFontSize,
            formatTime = formatTime,
            timerSeconds = timerSeconds,
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
    w.stats = {
    }
    w.statOrder = {
    }
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
    batt = tonumber(batt) or 0
    local cells = tonumber(w.cellCount) or 0
    local profile = batteryProfile(w)
    local reference = profile[3]
    if (w.batteryType or 1) == 5 then
        reference = profile[1]
    end
    local autoCells = math.max(1, math.min(12, math.floor(batt / reference + 0.5)))
    if cells >= 1 then
        local perCell = batt > 0 and batt / cells or 0
        if batt > 0 and (perCell > profile[3] + 0.35 or perCell < profile[2] - 0.35) then
            return autoCells
        end
        return cells
    end
    if w.detectedCells and batt > 0 then
        local detectedPerCell = batt / w.detectedCells
        if detectedPerCell >= profile[2] - 0.35 and detectedPerCell <= profile[3] + 0.35 then
            return w.detectedCells
        end
    end
    if batt > 0 then
        w.detectedCells = autoCells
    end
    return autoCells
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
local function batteryFuelPercent(w, batt)
    if w.field4Source then
        return clamp(tonumber(getVal(w.field4Source)) or 0, 0, 100)
    end
    if not w.batterySource then
        return nil
    end
    batt = tonumber(batt) or 0
    if (w.powerSourceType or 1) == 2 then
        return clamp(batt, 0, 100)
    end
    if batt <= 0 then
        return 0
    end
    local cells = cellsFor(w, batt)
    if cells < 1 then
        return 0
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
local function batteryIconSlices(ratio)
    if ratio >= 0.95 then
        return 5
    end
    if ratio >= 0.65 then
        return 4
    end
    if ratio >= 0.45 then
        return 3
    end
    if ratio >= 0.25 then
        return 2
    end
    if ratio > 0.03 then
        return 1
    end
    return 0
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
local function updateStats(w)
    local batt = getVal(w.batterySource)
    local percent = batteryFuelPercent(w, batt)
    if percent ~= nil and (w.powerSourceType or 1) == 2 then
        pushStat(w, "fuel", sourceName(w.field4Source, T(w, "Fuel")), percent or 0)
    elseif w.batterySource and batt > 0 then
        pushStat(w, "batt", T(w, "Battery/cell"), batt / cellsFor(w, batt))
    end
    if w.rssiSource then
        pushStat(w, "link", sourceName(w.rssiSource, T(w, "Link")), getVal(w.rssiSource))
    end
    if w.currentSource then
        pushStat(w, "current", sourceName(w.currentSource, T(w, "Current")), getVal(w.currentSource))
    end
    if w.rpmSource then
        pushStat(w, "rpm", sourceName(w.rpmSource, "RPM"), getVal(w.rpmSource))
    end
    if w.field1Source then
        pushStat(w, "field1", sourceName(w.field1Source, "Tlm 1"), getVal(w.field1Source))
    end
    if w.field2Source then
        pushStat(w, "field2", sourceName(w.field2Source, "Tlm 2"), getVal(w.field2Source))
    end
    if w.field3Source then
        pushStat(w, "field3", sourceName(w.field3Source, "Tlm 3"), getVal(w.field3Source))
    end
    if w.telemetry4Source then
        pushStat(w, "telemetry4", sourceName(w.telemetry4Source, "Tlm 4"), getVal(w.telemetry4Source))
    end
    if percent ~= nil and (w.powerSourceType or 1) ~= 2 then
        pushStat(w, "field4", sourceName(w.field4Source, T(w, "Battery percentage")), percent)
    end
end
local function updateFlight(w, now)
    now = now or os.clock()
    local armed = switchActive(w.armSwitch, w.armSwitchKey)
    if armed then
        if not w.armSeenAt then
            w.armSeenAt = now
        end
        if not w.flightActive and now - w.armSeenAt >= (w.armDelay or 5) then
            w.flightActive = true
            w.postFlight = false
            summaryModule, summaryApi = nil, nil
            w.flightStart = now
            w.flightTime = 0
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
            if (w.flightTime or 0) >= 15 then
                w.flightCount = (tonumber(w.flightCount) or 0) + 1
                w.dirty = true
                w.dirtyAt = now
                flush(w)
            end
        end
    end
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
    local link = clamp(tonumber(getVal(src)) or 0, 0, 100)
    if not w.linkSeenAt then
        if link > 0 then
            w.linkSeenAt = now
        end
        return
    end
    if now - w.linkSeenAt < LINK_MIN_GRACE then
        return
    end
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
local function sourceHasValue(src, allowZero)
    if not src then
        return false
    end
    if getVal(src) ~= 0 then
        return true
    end
    if not allowZero then
        return false
    end
    local t = type(src)
    if t == "table" or t == "userdata" then
        for i = 1, #sourceValidityMethods do
            local fn = objectField(src, sourceValidityMethods[i])
            if type(fn) == "function" then
                local ok, valid = pcall(fn, src)
                if ok and type(valid) == "boolean" then
                    return valid
                end
                if ok and type(valid) == "number" then
                    return valid ~= 0
                end
            end
        end
    end
    return true
end
local function telemetryPresent(w)
    local fuelMode = (w.powerSourceType or 1) == 2
    if w.rssiSource then
        return sourceHasValue(w.rssiSource)
    end
    if w.batterySource then
        return sourceHasValue(w.batterySource, fuelMode)
    end
    if w.currentSource then
        return sourceHasValue(w.currentSource)
    end
    if w.rpmSource then
        return sourceHasValue(w.rpmSource)
    end
    if w.field1Source then
        return sourceHasValue(w.field1Source)
    end
    if w.field2Source then
        return sourceHasValue(w.field2Source)
    end
    if w.field3Source then
        return sourceHasValue(w.field3Source)
    end
    if w.telemetry4Source then
        return sourceHasValue(w.telemetry4Source)
    end
    if w.field4Source then
        return sourceHasValue(w.field4Source, true)
    end
    return true
end
local function drawNoTelemetry(w, c, scrW, scrH)
    if math.floor(os.clock() * 2) % 2 == 0 then
        local scale = scaleFor(scrW, scrH)
        local warnH = math.max(36, math.floor(scrH * 0.18))
        local warnY = math.floor(scrH * 0.34)
        local warnX = px(8, scale, 4, 12)
        roundPanel(warnX, warnY, scrW - warnX * 2, warnH, px(8, scale, 4, 10), c.alertBg, c.alertOutline)
        local msg = T(w, "NO TELEMETRY")
        setFontSize("huge", scale)
        local msgW = getTextW(msg) or 0
        if msgW > scrW - 8 then
            setFontSize("large", scale)
            msgW = getTextW(msg) or 0
        end
        if msgW > scrW - 8 then
            setFontSize("small", scale)
            msgW = getTextW(msg) or 0
        end
        local x = math.floor((scrW - msgW) / 2)
        local y = warnY + math.floor(warnH * 0.3)
        if c.alertOutline then
            local o = px(2, scale, 1, 2)
            lcd.color(c.alertOutline)
            lcd.drawText(x - o, y, msg)
            lcd.drawText(x + o, y, msg)
            lcd.drawText(x, y - o, msg)
            lcd.drawText(x, y + o, msg)
        end
        lcd.color(c.alertText)
        lcd.drawText(x, y, msg)
    end
end
local function drawLinkMinText(w, scale, x, y, width, height)
    local value = w.linkMin
    local txt = T(w, "Min") .. ": " .. (value ~= nil and (tostring(math.floor(value + 0.5)) .. "%") or "--")
    if value ~= nil then
        local innerX = x + 2
        local innerW = math.max(1, width - 4)
        local markerW = px(2, scale, 1, 3)
        local markerX = innerX + math.floor(innerW * clamp(value, 0, 100) / 100)
        markerX = clamp(markerX, innerX, innerX + innerW - markerW)
        local markerY = y + 2
        local markerH = math.max(1, height - 4)
        lcd.color(lcd.RGB(0, 0, 0))
        lcd.drawFilledRectangle(markerX - 1, markerY, markerW + 2, markerH)
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawFilledRectangle(markerX, markerY, markerW, markerH)
    end
    setFontSize("small", scale)
    local tw = getTextW(txt) or 0
    if tw > width - 4 then
        return
    end
    local tx = x + math.floor((width - tw) / 2)
    local ty = y + math.max(0, math.floor((height - px(22, scale, 14, 28)) / 2) - px(5, scale, 2, 7))
    local o = px(1, scale, 1, 2)
    lcd.color(lcd.RGB(0, 0, 0))
    lcd.drawText(tx - o, ty, txt)
    lcd.drawText(tx + o, ty, txt)
    lcd.drawText(tx, ty - o, txt)
    lcd.drawText(tx, ty + o, txt)
    lcd.color(lcd.RGB(255, 255, 255))
    lcd.drawText(tx, ty, txt)
end
local function drawSourceRight(src, fallback, rightX, y, suffix)
    if not src then
        return 
    end
    local txt = string.format("%s: %s%s",
        sourceName(src, fallback), formatValue(getVal(src)), suffix or "")
    lcd.drawText(rightX - (getTextW(txt) or 0), y, txt)
end
local function drawCurrentRight(w, rightX, y, scale)
    if not w.currentSource then return end
    local txt = string.format("%s: %sA",
        sourceName(w.currentSource, T(w, "Current")), formatValue(getVal(w.currentSource)))
    local bold = px(1, scale, 1, 2)
    local x = rightX - (getTextW(txt) or 0) - bold
    lcd.drawText(x, y, txt)
    lcd.drawText(x + bold, y, txt)
end
local function statusActive(w)
    local value = getVal(w.statusSource)
    local mode = tonumber(w.statusMode) or 1
    if mode == 2 then
        return value < 0, value
    end
    return value > 0, value
end
local function drawStatusBar(w, c, scale, x, y, width, height)
    if not w.statusSource then
        return false
    end
    local active = statusActive(w)
    local fill = active and c.good or c.bad
    local label = sourceName(w.statusSource, T(w, "Status"))
    local state = active and "ON" or "OFF"
    local pad = px(8, scale, 4, 12)
    local txt = fitStatusText(label, state, width - pad * 2, scale)
    roundPanel(x, y, width, height, px(7, scale, 3, 9), fill, c.outline)
    local tx = x + math.floor((width - (getTextW(txt) or 0)) / 2)
    local ty = y + math.max(1, math.floor((height - getTextH(txt)) / 2))
    local bold = px(1, scale, 1, 2)
    lcd.color(lcd.RGB(0, 0, 0))
    lcd.drawText(tx, ty, txt)
    lcd.drawText(tx + bold, ty, txt)
    return true
end
local function statKeyForSource(w, src)
    if not src then
        return nil
    end
    if src == w.rssiSource then
        return "link"
    end
    if src == w.currentSource then
        return "current"
    end
    if src == w.field1Source then
        return "field1"
    end
    if src == w.field2Source then
        return "field2"
    end
    if src == w.field3Source then
        return "field3"
    end
    if src == w.telemetry4Source then
        return "telemetry4"
    end
    if src == w.field4Source then
        return "field4"
    end
    return nil
end
local function drawFuelGauge(w, c, scale, mainLeft, mainW, topY, bottomY, fuelValue, sizeScale, centerX, centerY, batteryGauge, packVoltage, voltageColor, splitFooter)
    local pct = clamp(tonumber(fuelValue) or 0, 0, 100)
    local cx = centerX or (mainLeft + math.floor(mainW / 2))
    local showPercent = batteryGauge or (w.fuelShowPercent or 1) ~= 2
    local percentReserve = showPercent and px(36, scale, 22, 44) or px(8, scale, 4, 12)
    local gaugeBottom = math.max(topY + 1, bottomY - percentReserve)
    local areaH = math.max(1, gaugeBottom - topY)
    local cy = centerY or (topY + math.floor(areaH * 0.74))
    local r = math.floor(math.min(mainW * 0.49, areaH * 0.74, px(215, scale, 132, 245)) * (sizeScale or 1))
    if r < px(38, scale, 24, 50) then
        setFontSize("large", scale)
        lcd.color(c.text)
        local footerY = topY + math.floor(areaH / 2)
        local fallback = showPercent and (tostring(math.floor(pct + 0.5)) .. "%") or "FUEL"
        if splitFooter and packVoltage then
            local voltageText = string.format("%.2fV", packVoltage)
            lcd.color(voltageColor or c.text)
            lcd.drawText(mainLeft, footerY, voltageText)
            lcd.drawText(mainLeft + mainW - (getTextW(fallback) or 0), footerY, fallback)
        else
            lcd.drawText(mainLeft + math.floor((mainW - (getTextW(fallback) or 0)) / 2), footerY, fallback)
            if batteryGauge and packVoltage then
                local voltageText = string.format("%.2fV", packVoltage)
                lcd.color(voltageColor or c.text)
                lcd.drawText(mainLeft + math.floor((mainW - (getTextW(voltageText) or 0)) / 2), footerY + px(42, scale, 28, 50), voltageText)
            end
        end
        return false
    end
    local cutDepth = math.floor(r * 0.3)
    cy = math.min(cy, gaugeBottom - cutDepth)
    local cutY = cy + cutDepth
    local face = lcd.RGB(0, 0, 0)
    local rim = lcd.RGB(235, 240, 240)
    local red = lcd.RGB(255, 35, 25)
    local gaugeText = lcd.RGB(255, 255, 255)
    local fuelHigh = batteryGauge and (w.field4High or 80) or (w.fuelHigh or 40)
    local fuelMid = batteryGauge and (w.field4Mid or 30) or (w.fuelMid or 20)
    if fuelHigh < fuelMid then
        fuelHigh, fuelMid = fuelMid, fuelHigh
    end
    lcd.color(face)
    if lcd.drawFilledCircle then
        lcd.drawFilledCircle(cx, cy, r)
    else
        for y = -r, r, 6 do
            local half = math.floor(math.sqrt(math.max(0, r * r - y * y)))
            lcd.drawFilledRectangle(cx - half, cy + y, half * 2 + 1, 6)
        end
    end
    local rimWeight = px(3, scale, 2, 4)
    local innerRim = r - px(6, scale, 3, 9)
    lcd.color(rim)
    if lcd.drawCircle then
        for o = 0, rimWeight - 1 do
            lcd.drawCircle(cx, cy, r - o)
            lcd.drawCircle(cx, cy, innerRim - o)
        end
    else
        drawHeavyLine(cx - r, cy, cx, cy - r, rimWeight)
        drawHeavyLine(cx, cy - r, cx + r, cy, rimWeight)
    end
    for i = 0, 8 do
        local deg = 180 + i * 22.5
        local major = i == 0 or i == 4 or i == 8
        local x1, y1 = polarPoint(cx, cy, deg, r - px(major and 10 or 8, scale, 5, 14))
        local x2, y2 = polarPoint(cx, cy, deg, r - px(major and 34 or 24, scale, 14, 40))
        local tickPct = i * 12.5
        lcd.color(tickPct < fuelMid and c.bad or (tickPct < fuelHigh and c.warn or c.good))
        drawHeavyLine(x1, y1, x2, y2, major and px(3, scale, 2, 4) or px(2, scale, 1, 3))
    end
    setFontSize("small", scale)
    lcd.color(gaugeText)
    local labelWeight = px(3, scale, 2, 3)
    local labelY = px(11, scale, 7, 15)
    local lx, ly = polarPoint(cx, cy, 180, r - px(46, scale, 28, 60))
    drawHeavyText(lx - math.floor((getTextW("E") or 0) / 2), ly - labelY, "E", labelWeight)
    lx, ly = polarPoint(cx, cy, 270, r - px(62, scale, 36, 74))
    drawHeavyText(lx - math.floor((getTextW("1/2") or 0) / 2), ly - labelY, "1/2", labelWeight)
    lx, ly = polarPoint(cx, cy, 360, r - px(46, scale, 28, 60))
    drawHeavyText(lx - math.floor((getTextW("F") or 0) / 2), ly - labelY, "F", labelWeight)
    local needleDeg = 180 + pct * 1.8
    local nx, ny = polarPoint(cx, cy, needleDeg, math.floor(r * 0.78))
    lcd.color(red)
    drawHeavyLine(cx, cy, nx, ny, px(4, scale, 3, 5))
    if lcd.drawFilledCircle then
        lcd.drawFilledCircle(cx, cy, px(11, scale, 7, 15))
        lcd.color(face)
        lcd.drawFilledCircle(cx, cy, px(5, scale, 3, 8))
    else
        lcd.drawFilledRectangle(cx - px(5, scale, 3, 8), cy - px(5, scale, 3, 8), px(10, scale, 6, 16), px(10, scale, 6, 16))
    end
    lcd.color(c.bg)
    lcd.drawFilledRectangle(cx - r - px(6, scale, 3, 10), cutY, r * 2 + px(12, scale, 6, 20), r)
    lcd.color(rim)
    lcd.drawLine(cx - r + px(10, scale, 5, 16), cutY, cx + r - px(10, scale, 5, 16), cutY)
    if showPercent then
        local percentText = splitFooter and (tostring(math.floor(pct + 0.5)) .. "%")
            or (T(w, batteryGauge and "Batt" or "Dash Fuel"):upper() .. " " .. tostring(math.floor(pct + 0.5)) .. "%")
        setFontSize("large", scale)
        local percentColor = pct < fuelMid and c.bad or (pct < fuelHigh and c.warn or c.good)
        lcd.color(percentColor)
        local percentY = cutY + px(5, scale, 3, 8)
        if splitFooter and packVoltage then
            local voltageText = string.format("%.2fV", packVoltage)
            setFontSize("huge", scale)
            local inset = px(12, scale, 6, 18)
            local voltageX = math.max(mainLeft, cx - r + inset)
            local percentW = getTextW(percentText) or 0
            local percentX = math.min(mainLeft + mainW - percentW, cx + r - inset - percentW)
            lcd.color(voltageColor or percentColor)
            drawHeavyText(voltageX, percentY, voltageText, labelWeight)
            lcd.color(percentColor)
            drawHeavyText(percentX, percentY, percentText, labelWeight)
        else
            drawHeavyText(cx - math.floor((getTextW(percentText) or 0) / 2), percentY, percentText, labelWeight)
            if batteryGauge and packVoltage then
                local voltageText = string.format("%.2fV", packVoltage)
                setFontSize("huge", scale)
                lcd.color(voltageColor or percentColor)
                local voltageY = percentY + px(42, scale, 28, 50)
                drawHeavyText(cx - math.floor((getTextW(voltageText) or 0) / 2), voltageY, voltageText, labelWeight)
            end
        end
    end
    return true
end
local function drawInFlightStat(w, c, scale, x, y, width, src, fallback, key, rowH)
    if not src then
        return y
    end
    rowH = rowH or px(108, scale, 82, 126)
    local padX = px(18, scale, 12, 24)
    local compact = rowH < px(48, scale, 42, 52)
    local padY = compact and px(3, scale, 2, 5) or px(12, scale, 8, 16)
    local valueY = compact and px(20, scale, 18, 24) or px(34, scale, 22, 40)
    local v = getVal(src)
    if not key then
        key = statKeyForSource(w, src)
    end
    local col = c.neutral
    if key then
        col = score(w, key, v, c)
    end
    local innerW = width - padX * 2
    setFontSize("small", scale)
    local label = fitText(sourceName(src, fallback), innerW)
    lcd.color(c.muted)
    lcd.drawText(x + padX, y + padY, label)
    lcd.color(col)
    setFontSize(compact and "small" or "medium", scale)
    local txt = formatValue(v)
    if key == "field4" then
        txt = txt .. "%"
    end
    lcd.drawText(x + width - padX - (getTextW(txt) or 0), y + padY + valueY, txt)
    return y + rowH
end
local function drawInFlight(w, c, scale, scrW, scrH)
    local batt = getVal(w.batterySource)
    local fuelMode = (w.powerSourceType or 1) == 2
    local batteryGauge = not fuelMode and tonumber(w.batteryStyle) == 2
    local gaugeMode = fuelMode or batteryGauge
    if fuelMode then
        batt = batteryFuelPercent(w, batt) or batt
    end
    local perCell = 0
    local ratio = 0
    local battCol = c.bad
    if not fuelMode then
        local cells = cellsFor(w, batt)
        if batt > 0 and cells > 0 then
            perCell = batt / cells
        end
        ratio = batteryIconRatio(w, perCell, batt)
        if perCell >= (w.battHigh or 4.15) then
            battCol = c.good
        elseif perCell >= (w.battMid or 3.75) then
            battCol = c.warn
        end
    end
    lcd.color(c.bg)
    lcd.drawFilledRectangle(0, 0, scrW, scrH)
    local x18Widget = scrW <= 500
    local x18ShortWidget = x18Widget and scrH < 200
    local margin = px(18, scale, 6, math.floor(scrW * 0.045))
    local rightW = px(250, scale, 150, math.floor(scrW * 0.38))
    local rightX = scrW - margin - rightW
    local topY = px(10, scale, 4, 14)
    local linkBarH = px(56, scale, 26, 62)
    local linkBarW = scrW - margin * 2
    local linkX = margin
    local linkY = topY + px(34, scale, 18, 38)
    local link = getVal(w.rssiSource)
    if link > 100 then
        link = 100
    end
    local linkCol = c.neutral
    if w.rssiSource then
        linkCol = score(w, "link", link, c)
    end
    local linkLabel = sourceName(w.rssiSource, T(w, "Link"))
    lcd.color(linkCol)
    setFontSize("large", scale)
    lcd.drawText(linkX, topY, string.format("%s: %d%%", linkLabel, math.floor(link)))
    roundPanel(linkX, linkY, linkBarW, linkBarH, px(6, scale, 3, 8), c.bg, c.barFrame)
    lcd.color(linkCol)
    local fillW = math.floor((linkBarW - 4) * clamp(link, 0, 100) / 100)
    if fillW > 0 then
        lcd.drawFilledRectangle(linkX + 2, linkY + 2, fillW, linkBarH - 4)
    end
    drawLinkMinText(w, scale, linkX, linkY, linkBarW, linkBarH)
    if gaugeMode then
        local fuelLeft = margin
        local fuelRight = rightX - px(8, scale, 4, 14)
        local fuelW = math.max(1, fuelRight - fuelLeft)
        local fuelTop = linkY + linkBarH + px(92, scale, 54, 118) + 4
        local fuelBottom = scrH - px(82, scale, 44, 94) + px(62, scale, 36, 80) + 4
        local fuelCx = fuelLeft + math.floor(fuelW * 0.38) + px(14, scale, 8, 20)
        local gaugeScale = x18ShortWidget and 2.02 or (x18Widget and 1.75 or 1.42)
        if batteryGauge then
            local percent = batteryFuelPercent(w, batt) or 0
            local drop = px(6, scale, 4, 10) - 5
            drawFuelGauge(w, c, scale, fuelLeft, fuelW, fuelTop + drop, fuelBottom + drop,
                percent, gaugeScale, fuelCx, fuelBottom + drop, true, batt, battCol, true)
        else
            drawFuelGauge(w, c, scale, fuelLeft, fuelW, fuelTop, fuelBottom, batt, gaugeScale, fuelCx, fuelBottom)
        end
        if w.currentSource then
            setFontSize("small", scale)
            lcd.color(c.secondary)
            local currentText = T(w, "Current") .. " " .. formatValue(getVal(w.currentSource)) .. "A"
            lcd.drawText(fuelRight - (getTextW(currentText) or 0), fuelTop + px(2, scale, 1, 4), currentText)
        end
    else
        local timerH = px(70, scale, 42, 86)
        local battTop = linkY + linkBarH + px(20, scale, 10, 28)
        local battBottom = scrH - timerH - px(x18Widget and 22 or 48, scale, x18Widget and 12 or 30, x18Widget and 34 or 62)
        local mainLeft = margin
        local mainRight = rightX - px(24, scale, 12, 32)
        if mainRight < mainLeft + px(220, scale, 150, 260) then
            mainRight = scrW - margin
        end
        local mainW = mainRight - mainLeft
        local battW = clamp(math.floor(mainW * 0.94), px(250, scale, 170, 340), mainW)
        local maxBattH = math.max(px(80, scale, 54, 96),
            battBottom - battTop - px(x18ShortWidget and 8 or (x18Widget and 18 or 48),
                scale, x18ShortWidget and 4 or (x18Widget and 10 or 28),
                x18ShortWidget and 14 or (x18Widget and 30 or 58)))
        local battH = clamp(math.floor(battW * 0.46), px(96, scale, 62, 118), math.min(px(190, scale, 118, 220), maxBattH))
        local bx = mainLeft + math.floor((mainW - battW) * 0.72)
        local by = math.max(battTop, battTop + math.floor((battBottom - battTop - battH) / 2))
        local battSegments = 6
        local slices = batteryIconSlicesFor(ratio, battSegments)
        local space = px(4, scale, 2, 6)
        local interiorW = battW - 6
        local segW = math.floor((interiorW - (battSegments - 1) * space) / battSegments)
        local segH = battH - 6
        roundPanel(bx, by, battW, battH, px(6, scale, 3, 8), c.bg, c.outline)
        for i = 1, battSegments do
            lcd.color(i <= slices and battCol or c.batteryEmpty)
            lcd.drawFilledRectangle(bx + 3 + (i - 1) * (segW + space), by + 3, segW, segH)
        end
        lcd.color(c.outline)
        local headW = math.max(3, math.floor(battW * 0.035))
        local headH = math.floor(battH * 0.48)
        lcd.drawFilledRectangle(bx + battW + px(2, scale, 1, 4), by + math.floor((battH - headH) / 2), headW, headH)
        local textY = by + battH + px(6, scale, 3, 10)
        local voltageScale = scale * 1.5
        setFontSize("huge", voltageScale)
        lcd.color(battCol)
        local vText = string.format("%.2fV", batt)
        local voltageX = mainLeft
        local vW = getTextW(vText) or 0
        lcd.drawText(voltageX, textY, vText)
        local percent = batteryFuelPercent(w, batt) or 0
        local percentText = string.format("%d%%", math.floor(percent + 0.5))
        setFontSize("huge", scale * 1.2)
        lcd.color(battCol)
        local percentX = voltageX + vW + px(12, scale, 6, 18) + 30
        lcd.drawText(percentX, textY + px(2, scale, 1, 4), percentText)
        local percentRight = percentX + (getTextW(percentText) or 0)
        if w.currentSource then
            local gap = px(18, scale, 10, 26)
            local textPad = px(8, scale, 4, 12)
            local currentRightX = mainRight - textPad
            local currValue = formatValue(getVal(w.currentSource)) .. "A"
            local currText = T(w, "Current") .. " " .. currValue
            local currFont = "large"
            setFontSize(currFont, scale)
            local currentLeft = math.max(voltageX + vW + gap, percentRight + gap)
            local room = currentRightX - currentLeft
            local cW = getTextW(currText) or 0
            if cW > room then
                currText = currValue
                cW = getTextW(currText) or 0
            end
            if cW > room then
                gap = px(8, scale, 4, 12)
                currentLeft = math.max(voltageX + vW + gap, percentRight + gap)
                room = currentRightX - currentLeft
            end
            if cW > room then
                currFont = "small"
                setFontSize("small", scale)
                cW = getTextW(currText) or 0
            end
            if cW > room then
                currText = fitText(currText, room)
                cW = getTextW(currText) or 0
            end
            if room <= 0 or cW > room then
                currText = ""
                cW = 0
            end
            setFontSize(currFont, scale)
            lcd.color(c.secondary)
            if currText ~= "" then
                lcd.drawText(currentRightX - cW, textY + px(8, scale, 4, 12), currText)
            end
        end
    end
    local statTop = linkY + linkBarH + px(2, scale, 1, 6)
    local statBottom = scrH - px(18, scale, 10, 26)
    local statGap = px(1, scale, 0, 3)
    local statRowH = math.floor((statBottom - statTop - statGap * 3) / 4)
    statRowH = clamp(statRowH, px(28, scale, 28, 36), px(92, scale, 70, 100))
    local statY = statTop
    statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight1Source, T(w, "Stat 1"), nil, statRowH) + statGap
    statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight2Source, T(w, "Stat 2"), nil, statRowH) + statGap
    statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight3Source, T(w, "Stat 3"), nil, statRowH) + statGap
    statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight4Source, T(w, "Stat 4"), nil, statRowH)
    local timerScale = scale * 1.5
    setFontSize("huge", timerScale)
    lcd.color(c.text)
    local timeText = formatTime(timerSeconds(w))
    local tx
    if gaugeMode then
        tx = math.max(margin, rightX - px(10, scale, 5, 16) - (getTextW(timeText) or 0))
    else
        tx = math.floor((scrW - (getTextW(timeText) or 0)) / 2)
    end
    local ty = scrH - px(82, scale, 44, 94)
    local b = px(2, timerScale, 1, 3)
    lcd.drawText(tx + b, ty, timeText)
    lcd.drawText(tx, ty, timeText)
end
local function paint(w, ...)
    currentFont = nil
    local scrW, scrH = windowSize(...)
    local scale = scaleFor(scrW, scrH)
    local x18Widget = scrW <= 500
    local visualScale = scale * 1.1
    local imageScale = scale * 1.5
    local margin = px(15, scale, 4, math.floor(scrW * 0.05))
    local gap = px(16, scale, 4, 24)
    local topMargin = px(17, scale, 3, 22)
    local rightPad = px(35, scale, 8, math.floor(scrW * 0.08))
    local imageW = px(220, imageScale, 52, math.floor(scrW * 0.45))
    local imageH = px(132, imageScale, 38, math.floor(scrH * 0.45))
    local imageX, imageY = margin, 0
    local drawImageW = math.floor(imageW * 0.8 + 0.5)
    local drawImageH = math.floor(imageH * 0.8 + 0.5)
    local drawImageX = imageX
    local drawImageY = imageY + math.floor((imageH - drawImageH) / 2)
    local lqBarW = px(180, visualScale, 66, math.floor(scrW * 0.33))
    local lqBarH = px(39, visualScale, 16, math.floor(scrH * 0.13))
    local lineGap = px(31, scale, 16, 38)
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
        drawInFlight(w, c, scale, scrW, scrH)
        if not telemetryOk then
            drawNoTelemetry(w, c, scrW, scrH)
        end
        return 
    end
    lcd.color(c.bg)
    lcd.drawFilledRectangle(0, 0, scrW, scrH)
    local drawn = false
    if w.imageFile and w.imageFile ~= "" then
        if not w.selectedBmp or w.selectedFile ~= w.imageFile then
            w.selectedBmp = nil
            w.selectedFile = w.imageFile
            if lcd.loadBitmap then
                local ok, bmp = pcall(function()
                    return lcd.loadBitmap(w.imageFile)
                end)
                if ok then
                    w.selectedBmp = bmp
                end
            end
        end
        if w.selectedBmp then
            w.iconBmp = nil
            w.iconLoaded = false
            drawBitmapBox(drawImageX, drawImageY, drawImageW, drawImageH, w.selectedBmp)
            drawn = true
        end
    end
    if not drawn and not w.iconLoaded and lcd.loadBitmap then
        w.iconLoaded = true
        local ok, bmp = pcall(function()
            return lcd.loadBitmap("SCRIPTS:/MultiDash/MultiDash.png")
        end)
        if ok then
            w.iconBmp = bmp
        end
    end
    if not drawn and w.iconBmp then
        drawBitmapBox(drawImageX, drawImageY, drawImageW, drawImageH, w.iconBmp)
    end
    local batt = getVal(w.batterySource)
    local fuelMode = (w.powerSourceType or 1) == 2
    if fuelMode then
        batt = batteryFuelPercent(w, batt) or batt
    end
    local perCell = 0
    local ratio = 0
    local slices = 0
    local battCol = c.bad
    if not fuelMode then
        local cells = cellsFor(w, batt)
        if batt > 0 and cells > 0 then
            perCell = batt / cells
        end
        ratio = batteryIconRatio(w, perCell, batt)
        slices = batteryIconSlices(ratio)
        if perCell >= (w.battHigh or 4.15) then
            battCol = c.good
        elseif perCell >= (w.battMid or 3.75) then
            battCol = c.warn
        end
    end
    local mainGaugeScale = x18Widget and 2.18 or 2.1
    if fuelMode or tonumber(w.batteryStyle) == 2 then
        local gaugeW = math.floor(scrW * 0.72)
        local gaugeLeft = math.floor((scrW - gaugeW) / 2)
        local gaugeTop = imageY + imageH + px(6, scale, 3, 10)
        local gaugeBottom = scrH - px(70, scale, 34, 84) - px(4, scale, 2, 8)
        if fuelMode then
            drawFuelGauge(w, c, scale, gaugeLeft, gaugeW, gaugeTop, gaugeBottom,
                batt, mainGaugeScale, math.floor(scrW / 2), gaugeBottom)
        else
            local percent = batteryFuelPercent(w, batt) or 0
            drawFuelGauge(w, c, scale, gaugeLeft, gaugeW, gaugeTop, gaugeBottom,
                percent, mainGaugeScale, math.floor(scrW / 2), gaugeBottom, true, batt, battCol)
        end
    else
        local leftSafe = imageX + imageW + gap
        local rightSafe = scrW - rightPad - lqBarW - gap
        local centerAreaW = rightSafe - leftSafe
        local maxBattW = math.floor(scrW * 0.36)
        if centerAreaW > 0 then
            maxBattW = math.min(maxBattW, math.floor(centerAreaW * 0.98))
        end
        local bottomReserve = px(92, scale, 48, 130)
        local by = px(34, scale, 8, 42)
        local maxBattH = scrH - by - bottomReserve
        local battH = math.min(math.floor(scrH * 0.71), maxBattH, math.floor(maxBattW / 0.6))
        battH = clamp(battH, px(120, visualScale, 78, math.floor(scrH * 0.55)), math.floor(scrH * 0.78))
        local battW = math.floor(battH * 0.6)
        local centerX = math.floor((scrW - battW) / 2)
        local maxX = scrW - rightPad - lqBarW - gap - battW
        local bx = maxX >= leftSafe and clamp(centerX, leftSafe, maxX) or clamp(centerX, margin, scrW - margin - battW)
        local space = 2
        local interiorH = battH - 4
        local segH = math.floor((interiorH - (5 - 1) * space) / 5)
        local segW = battW - 4
        roundPanel(bx, by, battW, battH, px(6, scale, 3, 8), c.bg, c.outline)
        for i = 1, 5 do
            local yOff = by + 2 + (i - 1) * (segH + space)
            if i > (5 - slices) then
                lcd.color(battCol)
            else
                lcd.color(c.batteryEmpty)
            end
            lcd.drawFilledRectangle(bx + 2, yOff, segW, segH)
        end
        lcd.color(c.outline)
        local headW = math.floor(battW * 0.4)
        local headX = bx + math.floor((battW - headW) / 2)
        local headH = math.max(2, math.floor(battH * 0.05))
        lcd.drawFilledRectangle(headX, by - headH - 2, headW, headH)
        local battCenter = bx + math.floor(battW / 2)
        local voltageY = by + battH + px(10, scale, 4, 14)
        local percent = batteryFuelPercent(w, batt)
        drawVoltagePercentStack(battCenter, voltageY, batt, percent, battCol, scale)
    end
    lcd.color(c.text)
    local timerScale = scale * 1.5
    setFontSize("huge", timerScale)
    local timerText = formatTime(timerSeconds(w))
    local timerY = scrH - px(70, scale, 34, 84)
    local statusH, statusW, statusY
    if w.statusSource then
        statusH = px(32, scale, 24, 40)
        statusW = px(220, scale, 130, math.floor(scrW * 0.36))
        local gapY = px(5, scale, 3, 8)
        local timerH = math.max(getTextH(timerText), px(44, timerScale, 28, 60))
        timerY = timerY - statusH - gapY
        statusY = math.min(scrH - statusH - px(2, scale, 1, 4), timerY + timerH + gapY)
    end
    setFontSize("small", scale)
    local flightsText = T(w, "Flights") .. ": " .. tostring(math.floor(tonumber(w.flightCount) or 0))
    local flightsY = timerY - px(34, scale, 24, 40)
    if w.statusSource then
        drawStatusBar(w, c, scale, margin, statusY, statusW, statusH)
    end
    local flightsBold = px(1, scale, 1, 2)
    lcd.color(c.secondary)
    lcd.drawText(margin, flightsY, flightsText)
    lcd.drawText(margin + flightsBold, flightsY, flightsText)
    setFontSize("huge", timerScale)
    lcd.color(c.text)
    local timerBold = px(2, timerScale, 1, 3)
    lcd.drawText(margin + timerBold, timerY, timerText)
    lcd.drawText(margin, timerY, timerText)
    local rssi = getVal(w.rssiSource)
    if rssi > 100 then
        rssi = 100
    end
    local rCol = c.neutral
    if rssi >= (w.linkHigh or 98) then
        rCol = c.good
    elseif rssi >= (w.linkMid or 80) then
        rCol = c.warn
    elseif rssi > 0 then
        rCol = c.bad
    end
    local rp = rightPad
    local ty = topMargin
    lcd.color(rCol)
    setFontSize("large", scale)
    local lqTxt = string.format("%s: %d%%", sourceName(w.rssiSource, T(w, "Link")), math.floor(rssi))
    local lqW = getTextW(lqTxt) or 0
    lcd.drawText(scrW - rp - lqW, ty, lqTxt)
    local bW2, bH2 = lqBarW, lqBarH
    local bx2 = scrW - rp - bW2
    local barY = ty + px(44, scale, 24, 50)
    roundPanel(bx2, barY, bW2, bH2, px(6, scale, 3, 8), c.bg, c.barFrame)
    lcd.color(rCol)
    local segs = 10
    local space = px(2, scale, 1, 3)
    local inset = px(2, scale, 1, 4)
    local usable = bW2 - inset * 2
    local segW = math.floor((usable - (segs - 1) * space) / segs)
    if segW < 1 then
        segW = 1
    end
    local act
    if rssi >= (w.linkHigh or 98) then
        act = segs
    else
        act = math.floor((rssi / 100) * segs)
    end
    if act < 0 then
        act = 0
    end
    if act > segs then
        act = segs
    end
    if act == segs then
        lcd.drawFilledRectangle(bx2 + inset, barY + inset, bW2 - inset * 2, bH2 - inset * 2)
    else
        for i = 0, act - 1 do
            local xOff = bx2 + inset + i * (segW + space)
            lcd.drawFilledRectangle(xOff, barY + inset, segW, bH2 - inset * 2)
        end
    end
    drawLinkMinText(w, scale, bx2, barY, bW2, bH2)
    if w.rpmSource then
        local rpm = getVal(w.rpmSource)
        local rpmTxt = "RPM: " .. formatValue(rpm)
        local rpmY = barY + bH2 + px(34, scale, 20, 42)
        setFontSize("large", scale)
        lcd.color(c.neutral)
        lcd.drawText(scrW - rp - (getTextW(rpmTxt) or 0), rpmY, rpmTxt)
    end
    local by2 = scrH - px(102, scale, 58, 118) - lineGap * 2
    lcd.color(c.muted)
    setFontSize("small", scale)
    local fieldRight = scrW - rp
    drawCurrentRight(w, fieldRight, by2 - 2, scale)
    drawSourceRight(w.field1Source, "Tlm 1", fieldRight, by2 + lineGap - 2)
    drawSourceRight(w.field2Source, "Tlm 2", fieldRight, by2 + lineGap * 2 - 2)
    drawSourceRight(w.field3Source, "Tlm 3", fieldRight, by2 + lineGap * 3 - 2)
    drawSourceRight(w.telemetry4Source, "Tlm 4", fieldRight, by2 + lineGap * 4 - 2)
    if w.armSeenAt and not w.flightActive then
        local barH = px(32, scale, 17, 38)
        local barY = imageY + imageH + px(3, scale, 1, 6)
        local barW = math.floor(drawImageW * 0.72)
        local barX = drawImageX + math.floor((drawImageW - barW) / 2)
        roundPanel(barX, barY, barW, barH, px(7, scale, 3, 9), c.warn, c.outline)
        setFontSize("small", scale)
        local txt = T(w, "ARMED")
        local txtX = barX + math.floor((barW - (getTextW(txt) or 0)) / 2)
        local txtY = barY - px(3, scale, 1, 5)
        local bold = px(1, scale, 1, 2)
        lcd.color(lcd.RGB(0, 0, 0))
        lcd.drawText(txtX, txtY, txt)
        lcd.drawText(txtX + bold, txtY, txt)
    end
    if not telemetryOk then
        drawNoTelemetry(w, c, scrW, scrH)
    end
end
local function wakeup(w)
    if not w then return end
    local now = os.clock()
    if now >= (w.nextRefresh or 0) then
        updateFlight(w, now)
        updateLinkMinimum(w, now)
        w.nextRefresh = now + 0.1
        if lcd and type(lcd.invalidate) == "function" then
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
    flush(w)
    w.selectedBmp = nil
    w.iconBmp = nil
    w.stats = nil
    w.statOrder = nil
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
