local name = "MultiDash"
local function sanitize(n)
return (n or "default"):gsub("%W", "_")
end
local function getTextW(txt)
if lcd and lcd.getTextSize then
local w, h = lcd.getTextSize(txt or "")
return w or 0
end
return 0
end
local function clamp(v, lo, hi)
if lo and v < lo then v = lo end
if hi and v > hi then v = hi end
return v
end
local function scaleFor(w, h)
return clamp(math.min(w / 800, h / 480), 0.45, 1.35)
end
local function windowSize()
local w, h = lcd.getWindowSize()
return tonumber(w) or 480, tonumber(h) or 320
end
local function px(v, scale, lo, hi)
local n = math.floor(v * scale + 0.5)
if hi and lo and hi < lo then lo = hi end
return clamp(n, lo, hi)
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
if widget and tonumber(widget.themeMode) == 2 then return palettes.light end
return palettes.dark
end
local fontsHugeSmall = {"FONT_L", "FONT_XL", "FONT_XXL", "FONT_S"}
local fontsHugeMed = {"FONT_XL", "FONT_XXL", "FONT_L", "FONT_S"}
local fontsHuge = {"FONT_XXL", "FONT_XL", "FONT_L", "FONT_S"}
local fontsLargeSmall = {"FONT_S", "FONT_L", "FONT_XL"}
local fontsLargeMed = {"FONT_L", "FONT_XL", "FONT_S"}
local fontsLarge = {"FONT_XL", "FONT_L", "FONT_S"}
local fontsSmall = {"FONT_S", "FONT_L", "FONT_XL"}
local function setAvailableFont(names)
for i = 1, #names do
local f = _G[names[i]]
if f ~= nil then lcd.font(f); return end
end
end
local function setFontSize(size, scale)
if size == "huge" then
if scale < 0.70 then setAvailableFont(fontsHugeSmall)
elseif scale < 0.95 then setAvailableFont(fontsHugeMed)
else setAvailableFont(fontsHuge) end
elseif size == "large" then
if scale < 0.70 then setAvailableFont(fontsLargeSmall)
elseif scale < 0.95 then setAvailableFont(fontsLargeMed)
else setAvailableFont(fontsLarge) end
else
setAvailableFont(fontsSmall)
end
end
local bitmapScaleSupported = nil
local bitmapBasicSupported = nil
local function drawBitmapBox(x, y, w, h, bmp)
if not bmp then return end
if bitmapScaleSupported == true then
lcd.drawBitmap(x, y, bmp, w, h)
return
elseif bitmapScaleSupported == nil then
local ok = pcall(function() lcd.drawBitmap(x, y, bmp, w, h) end)
bitmapScaleSupported = ok
if ok then return end
end
local bmpW, bmpH = w, h
if type(bmp.width) == "function" then bmpW = bmp:width() or w end
if type(bmp.height) == "function" then bmpH = bmp:height() or h end
local bx = x + math.max(0, math.floor((w - bmpW) / 2))
local by = y + math.max(0, math.floor((h - bmpH) / 2))
if type(lcd.setClipping) == "function" then
lcd.setClipping(x, y, w, h)
end
if bitmapBasicSupported == true then
lcd.drawBitmap(bx, by, bmp)
elseif bitmapBasicSupported == nil then
local ok = pcall(function() lcd.drawBitmap(bx, by, bmp) end)
bitmapBasicSupported = ok
end
if type(lcd.setClipping) == "function" then
lcd.setClipping()
end
end
local annulusSupported = nil
local function drawAnnulusSweep(cx, cy, inner, outer, startAngle, endAngle, color)
lcd.color(color)
local sweep = endAngle - startAngle
if sweep <= 180 then
lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, endAngle)
return
end
local mid = startAngle + sweep / 2
lcd.drawAnnulusSector(cx, cy, inner, outer, startAngle, mid)
lcd.drawAnnulusSector(cx, cy, inner, outer, mid, endAngle)
end
local function drawArc(cx, cy, radius, thickness, startAngle, endAngle, color)
if not lcd.drawAnnulusSector or annulusSupported == false then return false end
if math.abs(startAngle - endAngle) < 1 then return true end
local outer = radius
local inner = math.max(1, radius - thickness)
startAngle = startAngle % 360
endAngle = endAngle % 360
if endAngle <= startAngle then endAngle = endAngle + 360 end
if annulusSupported == nil then
local ok = pcall(drawAnnulusSweep, cx, cy, inner, outer, startAngle, endAngle, color)
annulusSupported = ok
return ok
end
drawAnnulusSweep(cx, cy, inner, outer, startAngle, endAngle, color)
return true
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
for i = 1, weight do lcd.drawText(x + i, y, text) end
end
local function getVal(src)
if not src then return 0 end
local t = type(src)
if t == "table" or t == "userdata" then
if type(src.value) == "function" then return src:value() or 0 end
if type(src.value) == "number" then return src.value end
end
local s = system.getSource(src)
if s and type(s.value) == "function" then
return s:value() or 0
end
return 0
end
local function getStr(src)
if not src then return "00:00" end
local t = type(src)
if t == "table" or t == "userdata" then
if type(src.stringValue) == "function" then return src:stringValue() or "00:00" end
end
local s = system.getSource(src)
if s and type(s.stringValue) == "function" then
return s:stringValue() or "00:00"
end
return "00:00"
end
local function sourceName(src, fallback)
if src and type(src.name) == "function" then
local ok, nm = pcall(src.name, src)
if ok and nm and nm ~= "" then return nm end
end
return fallback
end
local objectProps = {"name", "id", "label", "toString", "stringValue"}
local function objectKey(obj)
local t = type(obj)
if t == "string" or t == "number" then return tostring(obj) end
if not obj then return "" end
for i = 1, #objectProps do
local f = obj[objectProps[i]]
if type(f) == "function" then
local ok, v = pcall(f, obj)
if ok and v ~= nil and tostring(v) ~= "" then return tostring(v) end
elseif type(f) == "string" or type(f) == "number" then
return tostring(f)
end
end
local s = tostring(obj)
return (s and s:match("S[A-H]")) or ""
end
local function switchKey(sw, fallback)
local k = objectKey(sw)
if k ~= "" then return k end
return fallback or ""
end
local function switchBase(k)
if not k then return nil end
k = tostring(k)
return k:match("S[A-H]") or k:match("s[a-h]") or nil
end
local function assignSource(widget, key, val)
if not val or val == "" then
widget[key] = nil
return
end
local ok, src = pcall(function() return system.getSource(val) end)
widget[key] = ok and src or nil
end
local function resolveSwitch(val)
if not val or val == "" then return nil end
local tries = {}
tries[#tries + 1] = val
tries[#tries + 1] = tostring(val):upper()
tries[#tries + 1] = tostring(val):lower()
local base = switchBase(val)
if base then
tries[#tries + 1] = base:upper()
tries[#tries + 1] = base:lower()
end
for i = 1, #tries do
local k = tries[i]
if system and type(system.getSwitch) == "function" then
local ok, sw = pcall(function() return system.getSwitch(k) end)
if ok and sw then return sw end
end
end
for i = 1, #tries do
local k = tries[i]
if system and type(system.getSource) == "function" then
local ok, sw = pcall(function() return system.getSource(k) end)
if ok and sw then return sw end
end
end
return nil
end
local function assignSwitch(widget, key, val)
if not val or val == "" then
widget[key] = nil
widget[key .. "Key"] = nil
return
end
widget[key .. "Key"] = tostring(val)
widget[key] = resolveSwitch(val)
end
local write
local function markDirty(w)
if w then
w.dirty = true
w.dirtyAt = os.clock()
end
end
local armSwitchChoices = {"Off", "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH"}
local function armSwitchIndex(w)
local key = switchBase(w.armSwitchKey or switchKey(w.armSwitch)) or ""
key = key:upper()
for i = 1, #armSwitchChoices do
if armSwitchChoices[i] == key then return i end
end
return 1
end
local function setArmSwitchIndex(w, v)
local idx = clamp(math.floor(tonumber(v) or 1), 1, #armSwitchChoices)
local key = armSwitchChoices[idx]
if key == "Off" then
w.armSwitchKey = nil
w.armSwitch = nil
else
w.armSwitchKey = key
w.armSwitch = resolveSwitch(key)
end
end
local function formatTime(seconds)
seconds = math.max(0, math.floor(seconds or 0))
local m = math.floor(seconds / 60)
local s = seconds % 60
return string.format("%02d:%02d", m, s)
end
local function formatValue(v)
if v == nil then return "--" end
v = tonumber(v)
if not v then return "--" end
local nearest = v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
if math.abs(v - nearest) < 0.005 then return tostring(nearest) end
local one = v >= 0 and math.floor(v * 10 + 0.5) / 10 or math.ceil(v * 10 - 0.5) / 10
if math.abs(v - one) < 0.005 then return string.format("%.1f", v) end
return string.format("%.2f", v)
end
local batteryTypeChoices = {"LiPo", "LiHV", "Li-ion", "LiFe", "NiCd"}
local batteryProfiles = {
{nominal = 3.70, min = 3.20, max = 4.20, curve = {3.20, 0, 3.50, 5, 3.65, 10, 3.72, 20, 3.77, 30, 3.80, 40, 3.83, 50, 3.87, 60, 3.92, 70, 3.98, 80, 4.08, 90, 4.20, 100}},
{nominal = 3.80, min = 3.20, max = 4.35, curve = {3.20, 0, 3.55, 5, 3.70, 10, 3.78, 20, 3.83, 30, 3.87, 40, 3.91, 50, 3.96, 60, 4.02, 70, 4.10, 80, 4.22, 90, 4.35, 100}},
{nominal = 3.60, min = 3.00, max = 4.20, curve = {3.00, 0, 3.25, 5, 3.40, 10, 3.50, 20, 3.58, 30, 3.64, 40, 3.70, 50, 3.77, 60, 3.84, 70, 3.92, 80, 4.02, 90, 4.20, 100}},
{nominal = 3.30, min = 2.80, max = 3.60, curve = {2.80, 0, 3.00, 5, 3.15, 10, 3.22, 20, 3.25, 30, 3.27, 40, 3.29, 50, 3.30, 60, 3.31, 70, 3.33, 80, 3.36, 90, 3.60, 100}},
{nominal = 1.20, min = 0.95, max = 1.45, curve = {0.95, 0, 1.05, 10, 1.10, 20, 1.15, 30, 1.18, 40, 1.20, 50, 1.22, 60, 1.24, 70, 1.27, 80, 1.32, 90, 1.45, 100}},
}
local function batteryProfile(w)
return batteryProfiles[clamp(math.floor(tonumber(w.batteryType) or 1), 1, #batteryProfiles)]
end
local function fitText(txt, maxW)
txt = tostring(txt or "")
if maxW <= 0 then return "" end
if getTextW(txt) <= maxW then return txt end
if getTextW(".") > maxW then return "" end
while #txt > 0 and getTextW(txt .. ".") > maxW do
txt = txt:sub(1, #txt - 1)
end
return txt .. "."
end
local function switchActive(sw, key)
if not sw and key then sw = resolveSwitch(key) end
if not sw then return false end
local t = type(sw)
if t == "string" or t == "number" then
return switchActive(resolveSwitch(sw), sw)
end
if t == "table" or t == "userdata" then
if type(sw.active) == "function" then
local ok, v = pcall(function() return sw:active() end)
if ok then return v and true or false end
end
if type(sw.value) == "function" then
local ok, v = pcall(function() return sw:value() end)
if ok then return (tonumber(v) or 0) > 0 end
end
if type(sw.value) == "number" then return sw.value > 0 end
end
return getVal(sw) > 0
end
local function create()
return {
batterySource = nil,
rssiSource = nil,
field1Source = nil,
field2Source = nil,
field3Source = nil,
field4Source = nil,
inFlight1Source = nil,
inFlight2Source = nil,
inFlight3Source = nil,
inFlight4Source = nil,
timerSource = nil,
currentSource = nil,
rpmSource = nil,
armSwitch = nil,
armSwitchKey = nil,
armSwitchReverse = 1,
armDelay = 5,
telemetryMode = 1,
inFlightScreen = 1,
armSeenAt = nil,
imageFile = nil,
selectedBmp = nil,
selectedFile = nil,
iconBmp = nil,
iconLoaded = false,
cellCount = 0,
batteryType = 1,
detectedCells = nil,
themeMode = 1,
batteryStyle = 1,
powerSourceType = 1,
fuelShowPercent = 1,
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
field4Mode = 1,
flightActive = false,
postFlight = false,
flightStart = 0,
flightTime = 0,
stats = nil,
statOrder = nil,
dirty = false,
dirtyAt = 0,
}
end
write = function(widget)
if not widget then return true end
local modelName = (model and type(model.name) == "function") and model.name() or "default"
local key = sanitize(modelName)
local filePath = string.format("SCRIPTS:/MultiDash/models/%s.cfg", key)
local f = io.open(filePath, "w")
if not f then return false end
local ok = pcall(function()
f:write("battery=", objectKey(widget.batterySource), "\n")
f:write("link=", objectKey(widget.rssiSource), "\n")
f:write("field1=", objectKey(widget.field1Source), "\n")
f:write("field2=", objectKey(widget.field2Source), "\n")
f:write("field3=", objectKey(widget.field3Source), "\n")
f:write("field4=", objectKey(widget.field4Source), "\n")
f:write("inFlight1=", objectKey(widget.inFlight1Source), "\n")
f:write("inFlight2=", objectKey(widget.inFlight2Source), "\n")
f:write("inFlight3=", objectKey(widget.inFlight3Source), "\n")
f:write("inFlight4=", objectKey(widget.inFlight4Source), "\n")
f:write("timer=", objectKey(widget.timerSource), "\n")
f:write("current=", objectKey(widget.currentSource), "\n")
f:write("rpm=", objectKey(widget.rpmSource), "\n")
f:write("arm=", widget.armSwitchKey or switchKey(widget.armSwitch), "\n")
f:write("armReverse=", tostring(widget.armSwitchReverse or 1), "\n")
f:write("armDelay=", tostring(widget.armDelay or 5), "\n")
f:write("inFlightScreen=", tostring(widget.inFlightScreen or 1), "\n")
f:write("image=", widget.imageFile or "", "\n")
f:write("cells=", tostring(widget.cellCount or 0), "\n")
f:write("batteryType=", tostring(widget.batteryType or 1), "\n")
f:write("theme=", tostring(widget.themeMode or 1), "\n")
f:write("batteryStyle=", tostring(widget.batteryStyle or 1), "\n")
f:write("powerSourceType=", tostring(widget.powerSourceType or 1), "\n")
f:write("fuelShowPercent=", tostring(widget.fuelShowPercent or 1), "\n")
local keys = {"batt", "fuel", "link", "current", "field1", "field2", "field3", "field4"}
for i = 1, #keys do
local k = keys[i]
if widget[k .. "High"] ~= nil then f:write(k, "High=", tostring(widget[k .. "High"]), "\n") end
if widget[k .. "Mid"] ~= nil then f:write(k, "Mid=", tostring(widget[k .. "Mid"]), "\n") end
if widget[k .. "Low"] ~= nil then f:write(k, "Low=", tostring(widget[k .. "Low"]), "\n") end
if widget[k .. "Mode"] then f:write(k, "Mode=", tostring(widget[k .. "Mode"]), "\n") end
end
end)
pcall(function() f:close() end)
return ok
end
local function normalizeThresholds(widget)
if widget.battHigh == 3.90 and widget.battMid == 3.70 and widget.battLow == 3.50 then
widget.battHigh = 4.15
widget.battMid = 3.75
widget.battLow = 3.45
end
widget.battHigh = clamp(widget.battHigh or 4.15, 0, 4.35)
widget.battMid = clamp(widget.battMid or 3.75, 0, 4.35)
widget.battLow = clamp(widget.battLow or 3.45, 0, 4.35)
widget.fuelHigh = clamp(widget.fuelHigh or 40, 0, 100)
widget.fuelMid = clamp(widget.fuelMid or 20, 0, 100)
if (widget.field4High or 0) == 0 and (widget.field4Mid or 0) == 0 then
widget.field4High = 80
widget.field4Mid = 30
end
end
local function read(widget)
if not widget then return true end
local modelName = (model and type(model.name) == "function") and model.name() or "default"
local key = sanitize(modelName)
local filePath = string.format("SCRIPTS:/MultiDash/models/%s.cfg", key)
local f = io.open(filePath, "r")
if not f then
filePath = string.format("SCRIPTS:/MultiDash_%s.cfg", key)
f = io.open(filePath, "r")
end
if f then
while true do
local ok, line = pcall(f.read, f, "*l")
if not ok or not line then break end
local var, val = line:match("^(%w+)%=(.*)$")
if var then
val = val:gsub("^%s+", ""):gsub("%s+$", "")
if val == "" then val = nil end
if var == "battery" then
assignSource(widget, "batterySource", val)
elseif var == "link" then
assignSource(widget, "rssiSource", val)
elseif var == "field1" then
assignSource(widget, "field1Source", val)
elseif var == "field2" then
assignSource(widget, "field2Source", val)
elseif var == "field3" then
assignSource(widget, "field3Source", val)
elseif var == "field4" then
assignSource(widget, "field4Source", val)
elseif var == "inFlight1" then
assignSource(widget, "inFlight1Source", val)
elseif var == "inFlight2" then
assignSource(widget, "inFlight2Source", val)
elseif var == "inFlight3" then
assignSource(widget, "inFlight3Source", val)
elseif var == "inFlight4" then
assignSource(widget, "inFlight4Source", val)
elseif var == "timer" then
assignSource(widget, "timerSource", val)
elseif var == "current" then
assignSource(widget, "currentSource", val)
elseif var == "rpm" then
assignSource(widget, "rpmSource", val)
elseif var == "arm" then
assignSwitch(widget, "armSwitch", val)
elseif var == "armReverse" then
local r = tonumber(val)
if r then widget.armSwitchReverse = r == 2 and 2 or 1 end
elseif var == "armDelay" then
local d = tonumber(val)
if d then widget.armDelay = clamp(d, 0, 60) end
elseif var == "inFlightScreen" then
local s = tonumber(val)
if s then widget.inFlightScreen = s == 2 and 2 or 1 end
elseif var == "image" then
widget.imageFile = val
elseif var == "cells" then
local c = tonumber(val)
if c then widget.cellCount = c end
elseif var == "batteryType" then
local t = tonumber(val)
if t then widget.batteryType = clamp(math.floor(t), 1, #batteryProfiles) end
elseif var == "theme" then
local t = tonumber(val)
if t then widget.themeMode = t == 2 and 2 or 1 end
elseif var == "batteryStyle" then
local s = tonumber(val)
if s then widget.batteryStyle = s == 2 and 2 or 1 end
elseif var == "powerSourceType" then
local s = tonumber(val)
if s then widget.powerSourceType = s == 2 and 2 or 1 end
elseif var == "fuelShowPercent" then
local s = tonumber(val)
if s then widget.fuelShowPercent = s == 2 and 2 or 1 end
else
local n = tonumber(val)
if n and widget[var] ~= nil then widget[var] = n end
end
end
end
pcall(function() f:close() end)
end
normalizeThresholds(widget)
widget.selectedBmp = nil
widget.selectedFile = nil
widget.iconBmp = nil
widget.iconLoaded = false
return true
end
local currentConfigWidget = nil
local function addNumber(label, min, max, get, set, decimals)
local setter = set
set = function(v)
setter(v)
markDirty(currentConfigWidget)
end
if form.addNumberField then
local places = decimals or 0
local factor = 1
for i = 1, places do factor = factor * 10 end
local fieldMin, fieldMax, fieldGet, fieldSet = min, max, get, set
if places > 0 then
local function toField(v)
return math.floor((tonumber(v) or 0) * factor + 0.5)
end
fieldMin = toField(min)
fieldMax = toField(max)
fieldGet = function() return toField(get()) end
fieldSet = function(v) set((tonumber(v) or 0) / factor) end
end
local line = form.addLine(label)
local field = form.addNumberField(line, nil, fieldMin, fieldMax, fieldGet, fieldSet)
if field and type(field.decimals) == "function" then field:decimals(places) end
end
end
local function addChoice(label, choices, get, set)
local setter = set
set = function(v)
setter(v)
markDirty(currentConfigWidget)
end
local valueChoices = {}
for i = 1, #choices do
valueChoices[i] = {choices[i], i}
end
local line
if form.addChoiceField then
line = form.addLine(label)
local ok = pcall(function()
form.addChoiceField(line, nil, valueChoices, get, set)
end)
if ok then return end
ok = pcall(function()
form.addChoiceField(line, nil, choices, get, set)
end)
if ok then return end
ok = pcall(function()
form.addChoiceField(line, valueChoices, get, set)
end)
if ok then return end
ok = pcall(function()
form.addChoiceField(line, choices, get, set)
end)
if ok then return end
end
if form.addSelectField then
if not line then line = form.addLine(label) end
local ok = pcall(function()
form.addSelectField(line, nil, valueChoices, get, set)
end)
if ok then return end
ok = pcall(function()
form.addSelectField(line, nil, choices, get, set)
end)
if ok then return end
ok = pcall(function()
form.addSelectField(line, valueChoices, get, set)
end)
if ok then return end
ok = pcall(function()
form.addSelectField(line, choices, get, set)
end)
if ok then return end
end
addNumber(label, 1, #choices, get, setter, 0)
end
local function addSourceLine(label, get, set)
local line = form.addLine(label)
form.addSourceField(line, nil, get, set)
end
local function addThreshold(w, prefix, label, decimals, maxValue)
local max = maxValue or 10000
addNumber(label .. " " .. "high", 0, max, function() return w[prefix .. "High"] end, function(v) w[prefix .. "High"] = clamp(tonumber(v) or 0, 0, max) end, decimals)
addNumber(label .. " " .. "mid", 0, max, function() return w[prefix .. "Mid"] end, function(v) w[prefix .. "Mid"] = clamp(tonumber(v) or 0, 0, max) end, decimals)
if prefix == "batt" then
addNumber(label .. " " .. "low", 0, max, function() return w[prefix .. "Low"] end, function(v) w[prefix .. "Low"] = clamp(tonumber(v) or 0, 0, max) end, decimals)
end
if w[prefix .. "Mode"] ~= nil then
addChoice(label .. " " .. "scoring", {"High is good", "Low is good"}, function() return w[prefix .. "Mode"] end, function(v) w[prefix .. "Mode"] = tonumber(v) == 2 and 2 or 1 end)
end
end
local function addCurrentThreshold(w)
addNumber("Current high", 0, 10000, function() return w.currentHigh end, function(v) w.currentHigh = clamp(tonumber(v) or 0, 0, 10000) end, 1)
addNumber("Current mid", 0, 10000, function() return w.currentMid end, function(v) w.currentMid = clamp(tonumber(v) or 0, 0, 10000) end, 1)
end
local function configure(w)
currentConfigWidget = w
do
local line = form.addLine("Image")
if form.addFileField then
form.addFileField(line, nil, "BITMAPS:/models", "image+ext",
function() return w.imageFile and w.imageFile:match("[^/]+$") or "" end,
function(newVal)
w.imageFile = (newVal and newVal ~= "") and ("BITMAPS:/models/" .. newVal) or nil
w.selectedBmp = nil
w.selectedFile = nil
markDirty(w)
end
)
end
end
form.addLine("Display / Arm")
addChoice("Theme", {"Dark", "Light"}, function() return w.themeMode or 1 end, function(v) w.themeMode = tonumber(v) == 2 and 2 or 1 end)
addChoice("Arm switch", {"Off", "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH"},
function() return armSwitchIndex(w) end,
function(v) setArmSwitchIndex(w, v) end)
addChoice("Arm switch direction", {"Normal", "Reversed"},
function() return w.armSwitchReverse or 1 end,
function(v) w.armSwitchReverse = tonumber(v) == 2 and 2 or 1 end)
addNumber("Arming delay", 0, 60, function() return w.armDelay or 5 end, function(v) w.armDelay = clamp(tonumber(v) or 0, 0, 60) end, 0)
form.addLine("Power / Battery / Fuel")
addChoice("Power Source Type", {"Battery", "Fuel"}, function() return w.powerSourceType or 1 end, function(v) w.powerSourceType = tonumber(v) == 2 and 2 or 1 end)
addSourceLine("Power source", function() return w.batterySource end, function(v) w.batterySource = v; w.detectedCells = nil; markDirty(w) end)
if (w.powerSourceType or 1) == 2 then
addChoice("Fuel percentage", {"On", "Off"}, function() return w.fuelShowPercent or 1 end, function(v) w.fuelShowPercent = tonumber(v) == 2 and 2 or 1 end)
addThreshold(w, "fuel", "Fuel", 0, 100)
else
addNumber("Cells", 0, 12, function() return w.cellCount or 0 end, function(v) w.cellCount = clamp(tonumber(v) or 0, 0, 12); w.detectedCells = nil end, 0)
addChoice("Battery type", batteryTypeChoices, function() return w.batteryType or 1 end, function(v) w.batteryType = clamp(math.floor(tonumber(v) or 1), 1, #batteryProfiles); w.detectedCells = nil end)
addChoice("Battery style", {"Tower", "Dial"}, function() return w.batteryStyle or 1 end, function(v) w.batteryStyle = tonumber(v) == 2 and 2 or 1 end)
addThreshold(w, "batt", "Battery/cell", 2, 4.35)
addThreshold(w, "field4", "Battery/Fuel percentage", 0, 100)
end
form.addLine("Link")
addSourceLine("Link quality", function() return w.rssiSource end, function(v) w.rssiSource = v; markDirty(w) end)
addThreshold(w, "link", "Link quality", 0)
form.addLine("Telemetry / Engine")
addSourceLine("Telemetry 1", function() return w.field1Source end, function(v) w.field1Source = v; markDirty(w) end)
addThreshold(w, "field1", "Telemetry 1", 0)
addSourceLine("Telemetry 2", function() return w.field2Source end, function(v) w.field2Source = v; markDirty(w) end)
addThreshold(w, "field2", "Telemetry 2", 0)
addSourceLine("Telemetry 3", function() return w.field3Source end, function(v) w.field3Source = v; markDirty(w) end)
addThreshold(w, "field3", "Telemetry 3", 0)
addSourceLine("Battery/Fuel percentage", function() return w.field4Source end, function(v) w.field4Source = v; markDirty(w) end)
addSourceLine("Current", function() return w.currentSource end, function(v) w.currentSource = v; markDirty(w) end)
addCurrentThreshold(w)
addSourceLine("RPM", function() return w.rpmSource end, function(v) w.rpmSource = v; markDirty(w) end)
form.addLine("In-flight screen")
addChoice("In-flight screen", {"On", "Off"}, function() return w.inFlightScreen or 1 end, function(v) w.inFlightScreen = tonumber(v) == 2 and 2 or 1 end)
addSourceLine("Timer", function() return w.timerSource end, function(v) w.timerSource = v; markDirty(w) end)
addSourceLine("In-flight stat 1", function() return w.inFlight1Source end, function(v) w.inFlight1Source = v; markDirty(w) end)
addSourceLine("In-flight stat 2", function() return w.inFlight2Source end, function(v) w.inFlight2Source = v; markDirty(w) end)
addSourceLine("In-flight stat 3", function() return w.inFlight3Source end, function(v) w.inFlight3Source = v; markDirty(w) end)
addSourceLine("In-flight stat 4", function() return w.inFlight4Source end, function(v) w.inFlight4Source = v; markDirty(w) end)
end
local function score(w, prefix, value, c)
local high = w[prefix .. "High"] or 0
local mid = w[prefix .. "Mid"] or 0
if high < mid then high, mid = mid, high end
if prefix == "current" then
if value >= high then return c.bad, ":(" end
if value >= mid then return c.warn, ":|" end
return c.good, ":)"
end
local mode = w[prefix .. "Mode"] or 1
if mode == 2 then
if value < mid then return c.good, ":)" end
if value < high then return c.warn, ":|" end
return c.bad, ":("
end
if value >= high then return c.good, ":)" end
if value >= mid then return c.warn, ":|" end
return c.bad, ":("
end
local function statStatus(w, key, st, c)
if key == "rpm" then return c.neutral, "INFO" end
local mode = w[key .. "Mode"] or 1
local value = mode == 2 and st.max or st.min
local col, face = score(w, key, value, c)
if face == ":)" then return col, "OK :)" end
if face == ":|" then return col, "WARN" end
return col, "BAD :("
end
local function resetStats(w)
w.stats = {}
w.statOrder = {}
end
local function pushStat(w, key, label, value)
if value == nil then return end
if not w.stats then resetStats(w) end
if not w.stats[key] then
w.stats[key] = {label = label, min = value, max = value}
w.statOrder[#w.statOrder + 1] = key
else
local st = w.stats[key]
st.label = label
if value < st.min then st.min = value end
if value > st.max then st.max = value end
end
end
local function cellsFor(w, batt)
batt = tonumber(batt) or 0
local cells = tonumber(w.cellCount) or 0
local profile = batteryProfile(w)
local reference = profile.max
if (w.batteryType or 1) == 5 then reference = profile.nominal end
local autoCells = math.max(1, math.min(12, math.floor(batt / reference + 0.5)))
if cells >= 1 then
local perCell = batt > 0 and batt / cells or 0
if batt > 0 and (perCell > profile.max + 0.35 or perCell < profile.min - 0.35) then
return autoCells
end
return cells
end
if w.detectedCells and batt > 0 then
local detectedPerCell = batt / w.detectedCells
if detectedPerCell >= profile.min - 0.35 and detectedPerCell <= profile.max + 0.35 then
return w.detectedCells
end
end
if batt > 0 then w.detectedCells = autoCells end
return autoCells
end
local function curvePercent(curve, voltage)
if voltage <= curve[1] then return 0 end
for i = 3, #curve, 2 do
local lowV, lowPct = curve[i - 2], curve[i - 1]
local highV, highPct = curve[i], curve[i + 1]
if voltage <= highV then
local span = highV - lowV
if span <= 0 then return highPct end
return lowPct + (highPct - lowPct) * (voltage - lowV) / span
end
end
return 100
end
local function batteryFuelPercent(w, batt)
if w.field4Source then
return clamp(tonumber(getVal(w.field4Source)) or 0, 0, 100)
end
if not w.batterySource then return nil end
batt = tonumber(batt) or 0
if (w.powerSourceType or 1) == 2 then return clamp(batt, 0, 100) end
if batt <= 0 then return 0 end
local cells = cellsFor(w, batt)
if cells < 1 then return 0 end
return clamp(curvePercent(batteryProfile(w).curve, batt / cells), 0, 100)
end
local function batteryIconRatio(w, perCell, batt)
if not batt or batt <= 0 or not perCell or perCell <= 0 then return 0 end
local emptyV = w.battLow or 3.45
local fullV = w.battHigh or 4.15
if fullV <= emptyV then fullV = emptyV + 0.01 end
if perCell <= emptyV then return 0 end
if perCell >= fullV then return 1 end
return (perCell - emptyV) / (fullV - emptyV)
end
local function batteryIconSlices(ratio)
if ratio >= 0.95 then return 5 end
if ratio >= 0.65 then return 4 end
if ratio >= 0.45 then return 3 end
if ratio >= 0.25 then return 2 end
if ratio > 0.03 then return 1 end
return 0
end
local function batteryIconSlicesFor(ratio, segments)
segments = math.max(1, math.floor(tonumber(segments) or 1))
ratio = clamp(tonumber(ratio) or 0, 0, 1)
if ratio <= 0.03 then return 0 end
if ratio >= 0.95 then return segments end
return clamp(math.ceil(ratio * segments), 1, segments)
end
local function updateStats(w)
local batt = getVal(w.batterySource)
local percent = batteryFuelPercent(w, batt)
if percent ~= nil and (w.powerSourceType or 1) == 2 then
pushStat(w, "fuel", sourceName(w.field4Source, "Fuel"), percent or 0)
elseif w.batterySource and batt > 0 then
pushStat(w, "batt", "Battery/cell", batt / cellsFor(w, batt))
end
if w.rssiSource then pushStat(w, "link", sourceName(w.rssiSource, "Link"), getVal(w.rssiSource)) end
if w.currentSource then pushStat(w, "current", sourceName(w.currentSource, "Current"), getVal(w.currentSource)) end
if w.rpmSource then pushStat(w, "rpm", sourceName(w.rpmSource, "RPM"), getVal(w.rpmSource)) end
if w.field1Source then pushStat(w, "field1", sourceName(w.field1Source, "Telemetry 1"), getVal(w.field1Source)) end
if w.field2Source then pushStat(w, "field2", sourceName(w.field2Source, "Telemetry 2"), getVal(w.field2Source)) end
if w.field3Source then pushStat(w, "field3", sourceName(w.field3Source, "Telemetry 3"), getVal(w.field3Source)) end
if percent ~= nil and (w.powerSourceType or 1) ~= 2 then
pushStat(w, "field4", sourceName(w.field4Source, "Battery percentage"), percent)
end
end
local function updateFlight(w)
local armed = switchActive(w.armSwitch, w.armSwitchKey)
if w.armSwitchKey and (w.armSwitchReverse or 1) == 2 then armed = not armed end
if armed then
if not w.armSeenAt then w.armSeenAt = os.clock() end
if not w.flightActive and os.clock() - w.armSeenAt >= (w.armDelay or 5) then
w.flightActive = true
w.postFlight = false
w.flightStart = os.clock()
w.flightTime = 0
resetStats(w)
end
end
if w.flightActive then
w.flightTime = os.clock() - (w.flightStart or os.clock())
updateStats(w)
end
if not armed then
w.armSeenAt = nil
if w.flightActive then
w.flightActive = false
w.postFlight = true
end
end
end
local function drawPostFlight(w, c, scale, scrW, scrH)
lcd.color(c.bg)
lcd.drawFilledRectangle(0, 0, scrW, scrH)
local light = tonumber(w.themeMode) == 2
local panel = light and lcd.RGB(224, 229, 236) or lcd.RGB(29, 34, 40)
local panel2 = light and lcd.RGB(214, 221, 230) or lcd.RGB(39, 46, 54)
local rowAlt = light and lcd.RGB(232, 236, 241) or lcd.RGB(24, 29, 35)
local grid = light and lcd.RGB(150, 160, 172) or lcd.RGB(72, 84, 96)
local margin = px(8, scale, 4, math.floor(scrW * 0.030))
local pad = px(10, scale, 5, 14)
local headerY = px(6, scale, 2, 10)
local headerH = px(58, scale, 40, 68)
local width = scrW - margin * 2
local bold = px(1, scale, 1, 2)
local function drawBold(txt, x, y, color)
if color then lcd.color(color) end
lcd.drawText(x, y, txt)
lcd.drawText(x + bold, y, txt)
end
local function drawBoldRight(txt, rightX, y, color)
drawBold(txt, rightX - (getTextW(txt) or 0), y, color)
end
local function drawCentered(txt, x, y, w, color)
if color then lcd.color(color) end
lcd.drawText(x + math.floor((w - (getTextW(txt) or 0)) / 2), y, txt)
end
lcd.color(panel)
lcd.drawFilledRectangle(margin, headerY, width, headerH)
lcd.color(grid)
lcd.drawRectangle(margin, headerY, width, headerH)
setFontSize("large", scale)
local titleTxt = "FLIGHT SUMMARY"
local titleY = headerY + px(7, scale, 3, 10)
local titleX = margin + math.floor((width - (getTextW(titleTxt) or 0)) / 2)
drawBold(titleTxt, titleX, titleY, c.text)
local timeTxt = formatTime(w.flightTime or 0)
setFontSize("huge", scale)
local timeY = headerY + px(3, scale, 1, 8)
drawBoldRight(timeTxt, scrW - margin - pad, timeY, c.text)
if not w.statOrder or #w.statOrder == 0 then
setFontSize("large", scale)
drawBold("No flight stats captured", margin + pad, headerY + headerH + px(28, scale, 16, 38), c.muted)
return
end
local tableY = headerY + headerH + px(6, scale, 4, 10)
local bottom = scrH - px(4, scale, 2, 8)
local headerRowH = px(32, scale, 22, 38)
local rows = #w.statOrder
local usableRowsH = bottom - tableY - headerRowH
if usableRowsH < rows then return end
local rowH = math.floor(usableRowsH / rows)
if rowH < 20 then rowH = 20 end
local tableH = headerRowH + rowH * rows
local statusW = px(138, scale, 108, math.floor(width * 0.26))
local valueW = px(124, scale, 78, math.floor(width * 0.22))
local xName = margin + pad + px(8, scale, 4, 10)
local xStatus = margin + width - statusW
local xMax = xStatus - valueW
local xMin = xMax - valueW
local nameW = xMin - xName - pad
lcd.color(panel2)
lcd.drawFilledRectangle(margin, tableY, width, headerRowH)
lcd.color(grid)
lcd.drawRectangle(margin, tableY, width, tableH)
setFontSize("small", scale)
drawBold("Sensor", xName, tableY + px(8, scale, 3, 10), c.text)
drawBoldRight("Min", xMin + valueW - pad, tableY + px(8, scale, 3, 10), c.text)
drawBoldRight("Max", xMax + valueW - pad, tableY + px(8, scale, 3, 10), c.text)
drawBold("Status", xStatus + pad, tableY + px(8, scale, 3, 10), c.text)
local y = tableY + headerRowH
local rowIndex = 0
local function drawRow(key)
local st = w.stats[key]
if not st then return end
rowIndex = rowIndex + 1
if rowIndex % 2 == 0 then
lcd.color(rowAlt)
lcd.drawFilledRectangle(margin + 1, y, width - 2, rowH)
end
local col, status = statStatus(w, key, st, c)
local inset = px(4, scale, 2, 6)
local stripW = px(7, scale, 4, 10)
local txtH = px(22, scale, 14, 28)
local txtY = y + math.max(1, math.floor((rowH - txtH) / 2))
lcd.color(col)
lcd.drawFilledRectangle(margin + 1, y + 1, stripW, rowH - 1)
if rowH >= px(31, scale, 22, 36) then setFontSize("large", scale) else setFontSize("small", scale) end
drawBold(fitText(st.label, nameW), xName, txtY, c.text)
local minTxt = formatValue(st.min)
local maxTxt = formatValue(st.max)
if key == "fuel" or key == "field4" then
minTxt = minTxt .. "%"
maxTxt = maxTxt .. "%"
end
if getTextW(maxTxt) > valueW - pad or getTextW(minTxt) > valueW - pad then setFontSize("small", scale) end
drawBoldRight(minTxt, xMin + valueW - pad, txtY, c.text)
drawBoldRight(maxTxt, xMax + valueW - pad, txtY, c.text)
if rowH >= px(31, scale, 22, 36) then setFontSize("large", scale) else setFontSize("small", scale) end
lcd.color(col)
lcd.drawRectangle(xStatus + inset, y + inset, statusW - inset * 2, rowH - inset * 2)
status = fitText(status, statusW - pad * 2)
drawCentered(status, xStatus + inset, txtY - px(7, scale, 4, 9), statusW - inset * 2, col)
lcd.color(grid)
lcd.drawFilledRectangle(margin + 1, y + rowH - 1, width - 2, 1)
y = y + rowH
end
for i = 1, #w.statOrder do
local key = w.statOrder[i]
if key ~= "rpm" then drawRow(key) end
end
if w.stats.rpm then drawRow("rpm") end
end
local function drawBatteryDial(w, c, scale, scrW, scrH, batt, ratio, battCol)
if not lcd.drawAnnulusSector then return false end
local radius = math.floor(math.min(scrH * 0.47, scrW * 0.34))
local minRadius = px(96, scale, 68, 126)
if radius < minRadius then radius = minRadius end
radius = math.min(radius, math.floor(scrH * 0.49), math.floor(scrW * 0.45))
local cx = math.floor(scrW / 2)
local cy = math.floor(scrH / 2)
local thickness = clamp(math.floor(radius * 0.21), px(20, scale, 14, 34), math.floor(radius * 0.30))
if not drawArc(cx, cy, radius, thickness, 225, 135, c.barFrame) then return false end
if ratio > 0.01 then
drawArc(cx, cy, radius, thickness, 225, 225 + ratio * 270, battCol)
end
lcd.color(battCol)
setFontSize("huge", scale)
local vText = string.format("%.2fV", batt)
lcd.drawText(cx - math.floor((getTextW(vText) or 0) / 2), cy - px(28, scale, 12, 34), vText)
setFontSize("small", scale)
lcd.color(c.secondary)
local battLabel = "Batt"
lcd.drawText(cx - math.floor((getTextW(battLabel) or 0) / 2), cy + px(26, scale, 12, 34), battLabel)
if w.currentSource then
local txt = "Curr" .. " " .. formatValue(getVal(w.currentSource)) .. "A"
lcd.drawText(cx - math.floor((getTextW(txt) or 0) / 2), cy + px(54, scale, 28, 62), txt)
end
return true
end
local sourceValidityMethods = {"isValid", "valid", "isAvailable", "available"}
local function sourceHasValue(src, allowZero)
if not src then return false end
if getVal(src) ~= 0 then return true end
if not allowZero then return false end
local t = type(src)
if t == "table" or t == "userdata" then
for i = 1, #sourceValidityMethods do
local fn = src[sourceValidityMethods[i]]
if type(fn) == "function" then
local ok, valid = pcall(fn, src)
if ok and type(valid) == "boolean" then return valid end
if ok and type(valid) == "number" then return valid ~= 0 end
end
end
end
return true
end
local function telemetryPresent(w)
local fuelMode = (w.powerSourceType or 1) == 2
if w.rssiSource then return sourceHasValue(w.rssiSource) end
if w.batterySource then return sourceHasValue(w.batterySource, fuelMode) end
if w.currentSource then return sourceHasValue(w.currentSource) end
if w.rpmSource then return sourceHasValue(w.rpmSource) end
if w.field1Source then return sourceHasValue(w.field1Source) end
if w.field2Source then return sourceHasValue(w.field2Source) end
if w.field3Source then return sourceHasValue(w.field3Source) end
if w.field4Source then return sourceHasValue(w.field4Source, true) end
return true
end
local function drawNoTelemetry(c, scrW, scrH)
if math.floor(os.clock() * 2) % 2 == 0 then
local scale = scaleFor(scrW, scrH)
local warnH = math.max(36, math.floor(scrH * 0.18))
local warnY = math.floor(scrH * 0.34)
lcd.color(c.alertBg)
lcd.drawFilledRectangle(0, warnY, scrW, warnH)
local msg = "NO TELEMETRY"
setFontSize("huge", scale)
if getTextW(msg) > scrW - 8 then setFontSize("large", scale) end
if getTextW(msg) > scrW - 8 then setFontSize("small", scale) end
local x = math.floor((scrW - (getTextW(msg) or 0)) / 2)
local y = warnY + math.floor(warnH * 0.30)
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
local function drawSourceRight(src, fallback, rightX, y)
if not src then return end
local txt = string.format("%s: %s", sourceName(src, fallback), formatValue(getVal(src)))
lcd.drawText(rightX - (getTextW(txt) or 0), y, txt)
end
local function drawPercentRight(w, rightX, y)
local percent = batteryFuelPercent(w, getVal(w.batterySource))
if percent == nil then return end
local fallback = (w.powerSourceType or 1) == 2 and "Fuel" or "Battery"
local txt = string.format("%s: %d%%", sourceName(w.field4Source, fallback), math.floor(percent + 0.5))
lcd.drawText(rightX - (getTextW(txt) or 0), y, txt)
end
local function statKeyForSource(w, src)
if not src then return nil end
if src == w.rssiSource then return "link" end
if src == w.currentSource then return "current" end
if src == w.field1Source then return "field1" end
if src == w.field2Source then return "field2" end
if src == w.field3Source then return "field3" end
if src == w.field4Source then return "field4" end
return nil
end
local function drawFuelGauge(w, c, scale, mainLeft, mainW, topY, bottomY, fuelValue, sizeScale, centerX, centerY)
local pct = clamp(tonumber(fuelValue) or 0, 0, 100)
local cx = centerX or (mainLeft + math.floor(mainW / 2))
local showPercent = (w.fuelShowPercent or 1) ~= 2
local percentReserve = showPercent and px(36, scale, 22, 44) or px(8, scale, 4, 12)
local dialBottom = math.max(topY + 1, bottomY - percentReserve)
local areaH = math.max(1, dialBottom - topY)
local cy = centerY or (topY + math.floor(areaH * 0.74))
local r = math.floor(math.min(mainW * 0.49, areaH * 0.74, px(215, scale, 132, 245)) * (sizeScale or 1))
if r < px(38, scale, 24, 50) then
setFontSize("large", scale)
lcd.color(c.text)
local fallback = showPercent and (tostring(math.floor(pct + 0.5)) .. "%") or "FUEL"
lcd.drawText(mainLeft + math.floor((mainW - (getTextW(fallback) or 0)) / 2), topY + math.floor(areaH / 2), fallback)
return false
end
local cutDepth = math.floor(r * 0.30)
cy = math.min(cy, dialBottom - cutDepth)
local cutY = cy + cutDepth
local face = lcd.RGB(0, 0, 0)
local rim = lcd.RGB(205, 210, 210)
local red = lcd.RGB(255, 35, 25)
local gaugeText = lcd.RGB(255, 255, 255)
local fuelHigh = w.fuelHigh or 40
local fuelMid = w.fuelMid or 20
if fuelHigh < fuelMid then fuelHigh, fuelMid = fuelMid, fuelHigh end
lcd.color(face)
if lcd.drawFilledCircle then
lcd.drawFilledCircle(cx, cy, r)
else
for y = -r, r, 6 do
local half = math.floor(math.sqrt(math.max(0, r * r - y * y)))
lcd.drawFilledRectangle(cx - half, cy + y, half * 2 + 1, 6)
end
end
lcd.color(rim)
if lcd.drawCircle then
lcd.drawCircle(cx, cy, r)
lcd.drawCircle(cx, cy, r - 1)
lcd.drawCircle(cx, cy, r - px(4, scale, 2, 8))
lcd.drawCircle(cx, cy, r - px(4, scale, 2, 8) - 1)
else
lcd.drawLine(cx - r, cy, cx, cy - r)
lcd.drawLine(cx, cy - r, cx + r, cy)
end
for i = 0, 8 do
local deg = 180 + i * 22.5
local major = i == 0 or i == 4 or i == 8
local x1, y1 = polarPoint(cx, cy, deg, r - px(major and 10 or 8, scale, 5, 14))
local x2, y2 = polarPoint(cx, cy, deg, r - px(major and 34 or 24, scale, 14, 40))
local tickPct = i * 12.5
lcd.color(tickPct < fuelMid and c.bad or (tickPct < fuelHigh and c.warn or c.good))
drawHeavyLine(x1, y1, x2, y2, major and 2 or 1)
end
setFontSize("small", scale)
lcd.color(gaugeText)
local labelWeight = px(2, scale, 1, 2)
local lx, ly = polarPoint(cx, cy, 180, r - px(28, scale, 16, 38))
drawHeavyText(lx - math.floor((getTextW("E") or 0) / 2), ly - px(10, scale, 6, 14), "E", labelWeight)
lx, ly = polarPoint(cx, cy, 270, r - px(42, scale, 24, 54))
drawHeavyText(lx - math.floor((getTextW("1/2") or 0) / 2), ly - px(10, scale, 6, 14), "1/2", labelWeight)
lx, ly = polarPoint(cx, cy, 360, r - px(28, scale, 16, 38))
drawHeavyText(lx - math.floor((getTextW("F") or 0) / 2), ly - px(10, scale, 6, 14), "F", labelWeight)
local needleDeg = 180 + pct * 1.80
local nx, ny = polarPoint(cx, cy, needleDeg, math.floor(r * 0.78))
lcd.color(red)
drawHeavyLine(cx, cy, nx, ny, px(3, scale, 2, 4))
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
local percentText = "FUEL " .. tostring(math.floor(pct + 0.5)) .. "%"
setFontSize("large", scale)
local percentColor = pct < fuelMid and c.bad or (pct < fuelHigh and c.warn or c.good)
lcd.color(percentColor)
local percentY = cutY + px(5, scale, 3, 8)
drawHeavyText(cx - math.floor((getTextW(percentText) or 0) / 2), percentY, percentText, labelWeight)
end
return true
end
local function drawInFlightStat(w, c, scale, x, y, width, src, fallback, key, rowH)
if not src then return y end
rowH = rowH or px(108, scale, 82, 126)
local padX = px(18, scale, 12, 24)
local padY = px(12, scale, 8, 16)
local v = getVal(src)
if not key then key = statKeyForSource(w, src) end
local col = c.neutral
if key then col = score(w, key, v, c) end
local innerW = width - padX * 2
local label = fitText(sourceName(src, fallback), innerW)
lcd.color(c.muted)
setFontSize("small", scale)
lcd.drawText(x + padX, y + padY, label)
lcd.color(col)
setFontSize("medium", scale)
local txt = formatValue(v)
if key == "field4" then txt = txt .. "%" end
lcd.drawText(x + width - padX - (getTextW(txt) or 0), y + padY + px(34, scale, 22, 40), txt)
return y + rowH
end
local function drawInFlight(w, c, scale, scrW, scrH)
local batt = getVal(w.batterySource)
local fuelMode = (w.powerSourceType or 1) == 2
if fuelMode then batt = batteryFuelPercent(w, batt) or batt end
local perCell = 0
local ratio = 0
local battCol = c.bad
if not fuelMode then
local cells = cellsFor(w, batt)
if batt > 0 and cells > 0 then perCell = batt / cells end
ratio = batteryIconRatio(w, perCell, batt)
if perCell >= (w.battHigh or 4.15) then battCol = c.good
elseif perCell >= (w.battMid or 3.75) then battCol = c.warn end
end
lcd.color(c.bg)
lcd.drawFilledRectangle(0, 0, scrW, scrH)
local margin = px(18, scale, 6, math.floor(scrW * 0.045))
local rightW = px(250, scale, 150, math.floor(scrW * 0.38))
local rightX = scrW - margin - rightW
local topY = px(10, scale, 4, 14)
local linkBarH = px(56, scale, 26, 62)
local linkBarW = scrW - margin * 2
local linkX = margin
local linkY = topY + px(34, scale, 18, 38)
local link = getVal(w.rssiSource)
if link > 100 then link = 100 end
local linkCol = c.neutral
if w.rssiSource then linkCol = score(w, "link", link, c) end
lcd.color(linkCol)
setFontSize("large", scale)
local linkLabel = sourceName(w.rssiSource, "Link")
lcd.drawText(linkX, topY, string.format("%s: %d%%", linkLabel, math.floor(link)))
lcd.color(c.barFrame)
lcd.drawRectangle(linkX, linkY, linkBarW, linkBarH)
lcd.color(linkCol)
local fillW = math.floor((linkBarW - 4) * clamp(link, 0, 100) / 100)
if fillW > 0 then lcd.drawFilledRectangle(linkX + 2, linkY + 2, fillW, linkBarH - 4) end
if fuelMode then
local fuelLeft = margin
local fuelRight = rightX - px(8, scale, 4, 14)
local fuelW = math.max(1, fuelRight - fuelLeft)
local fuelTop = linkY + linkBarH + px(92, scale, 54, 118) + 4
local fuelBottom = scrH - px(82, scale, 44, 94) + px(62, scale, 36, 80) + 4
local fuelCx = fuelLeft + math.floor(fuelW * 0.38)
drawFuelGauge(w, c, scale, fuelLeft, fuelW, fuelTop, fuelBottom, batt, 1.42, fuelCx, fuelBottom)
if w.currentSource then
setFontSize("small", scale)
lcd.color(c.secondary)
local currentText = "Curr " .. formatValue(getVal(w.currentSource)) .. "A"
lcd.drawText(fuelRight - (getTextW(currentText) or 0), fuelTop + px(2, scale, 1, 4), currentText)
end
else
local timerH = px(70, scale, 42, 86)
local battTop = linkY + linkBarH + px(20, scale, 10, 28)
local battBottom = scrH - timerH - px(48, scale, 30, 62)
local mainLeft = margin
local mainRight = rightX - px(24, scale, 12, 32)
if mainRight < mainLeft + px(220, scale, 150, 260) then mainRight = scrW - margin end
local mainW = mainRight - mainLeft
local battW = clamp(math.floor(mainW * 0.94), px(250, scale, 170, 340), mainW)
local maxBattH = math.max(px(80, scale, 54, 96), battBottom - battTop - px(48, scale, 28, 58))
local battH = clamp(math.floor(battW * 0.46), px(96, scale, 62, 118), math.min(px(190, scale, 118, 220), maxBattH))
local bx = mainLeft + math.floor((mainW - battW) * 0.72)
local by = math.max(battTop, battTop + math.floor((battBottom - battTop - battH) / 2))
local battSegments = 6
local slices = batteryIconSlicesFor(ratio, battSegments)
local space = px(4, scale, 2, 6)
local interiorW = battW - 6
local segW = math.floor((interiorW - (battSegments - 1) * space) / battSegments)
local segH = battH - 6
for i = 1, battSegments do
lcd.color(i <= slices and battCol or c.batteryEmpty)
lcd.drawFilledRectangle(bx + 3 + (i - 1) * (segW + space), by + 3, segW, segH)
end
lcd.color(c.outline)
lcd.drawRectangle(bx, by, battW, battH)
local headW = math.max(3, math.floor(battW * 0.035))
local headH = math.floor(battH * 0.48)
lcd.drawFilledRectangle(bx + battW + px(2, scale, 1, 4), by + math.floor((battH - headH) / 2), headW, headH, c.outline)
local battCenter = bx + math.floor(battW / 2)
local textY = by + battH + px(12, scale, 6, 16)
local voltageScale = scale * 1.50
setFontSize("huge", voltageScale)
lcd.color(battCol)
local vText = string.format("%.2fV", batt)
if w.currentSource then
local vW = getTextW(vText) or 0
local gap = px(18, scale, 10, 26)
local textPad = px(8, scale, 4, 12)
local voltageX = bx + textPad
local currentRightX = bx + battW - textPad
local currValue = formatValue(getVal(w.currentSource)) .. "A"
local currText = "Curr" .. " " .. currValue
local currFont = "large"
setFontSize(currFont, scale)
local room = currentRightX - (voltageX + vW + gap)
local cW = getTextW(currText) or 0
if cW > room then
currText = currValue
cW = getTextW(currText) or 0
end
if cW > room then
gap = px(8, scale, 4, 12)
room = currentRightX - (voltageX + vW + gap)
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
setFontSize("huge", voltageScale)
lcd.color(battCol)
lcd.drawText(voltageX, textY, vText)
setFontSize(currFont, scale)
lcd.color(c.secondary)
if currText ~= "" then
lcd.drawText(currentRightX - cW, textY + px(8, scale, 4, 12), currText)
end
else
lcd.drawText(battCenter - math.floor((getTextW(vText) or 0) / 2), textY, vText)
end
end
local statTop = linkY + linkBarH + px(2, scale, 1, 6)
local statBottom = scrH - px(18, scale, 10, 26)
local statGap = px(1, scale, 0, 3)
local statRowH = math.floor((statBottom - statTop - statGap * 3) / 4)
statRowH = clamp(statRowH, px(62, scale, 48, 70), px(92, scale, 70, 100))
local statY = statTop
statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight1Source, "Stat 1", nil, statRowH) + statGap
statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight2Source, "Stat 2", nil, statRowH) + statGap
statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight3Source, "Stat 3", nil, statRowH) + statGap
statY = drawInFlightStat(w, c, scale, rightX, statY, rightW, w.inFlight4Source, "Stat 4", nil, statRowH)
local timerScale = scale * 1.50
setFontSize("huge", timerScale)
lcd.color(c.text)
local timeText = formatTime(w.flightTime or 0)
local tx
if fuelMode then
tx = math.max(margin, rightX - px(10, scale, 5, 16) - (getTextW(timeText) or 0))
else
tx = math.floor((scrW - (getTextW(timeText) or 0)) / 2)
end
local ty = scrH - px(82, scale, 44, 94)
local b = px(2, timerScale, 1, 3)
lcd.drawText(tx + b, ty, timeText)
lcd.drawText(tx, ty, timeText)
end
local function paint(w)
local scrW, scrH = windowSize()
local scale = scaleFor(scrW, scrH)
local visualScale = scale * 1.10
local imageScale = scale * 1.50
local margin = px(15, scale, 4, math.floor(scrW * 0.05))
local gap = px(16, scale, 4, 24)
local topMargin = px(17, scale, 3, 22)
local rightPad = px(35, scale, 8, math.floor(scrW * 0.08))
local imageW = px(220, imageScale, 52, math.floor(scrW * 0.45))
local imageH = px(132, imageScale, 38, math.floor(scrH * 0.45))
local lqBarW = px(180, visualScale, 66, math.floor(scrW * 0.33))
local lqBarH = px(39, visualScale, 16, math.floor(scrH * 0.13))
local lineGap = px(31, scale, 16, 38)
local imageX, imageY = margin, 0
local c = theme(w)
updateFlight(w)
local telemetryOk = telemetryPresent(w)
if w.postFlight and not w.flightActive then
drawPostFlight(w, c, scale, scrW, scrH)
return
end
if w.flightActive and tonumber(w.inFlightScreen) ~= 2 then
drawInFlight(w, c, scale, scrW, scrH)
if not telemetryOk then drawNoTelemetry(c, scrW, scrH) end
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
local ok, bmp = pcall(function() return lcd.loadBitmap(w.imageFile) end)
if ok then w.selectedBmp = bmp end
end
end
if w.selectedBmp then
w.iconBmp = nil
w.iconLoaded = false
drawBitmapBox(imageX, imageY, imageW, imageH, w.selectedBmp)
drawn = true
end
end
if not drawn and not w.iconLoaded and lcd.loadBitmap then
w.iconLoaded = true
local ok, bmp = pcall(function() return lcd.loadBitmap("SCRIPTS:/MultiDash/MultiDash.png") end)
if ok then w.iconBmp = bmp end
end
if not drawn and w.iconBmp then
drawBitmapBox(imageX, imageY, imageW, imageH, w.iconBmp)
end
local batt = getVal(w.batterySource)
local fuelMode = (w.powerSourceType or 1) == 2
if fuelMode then batt = batteryFuelPercent(w, batt) or batt end
local perCell = 0
local ratio = 0
local slices = 0
local battCol = c.bad
if not fuelMode then
local cells = cellsFor(w, batt)
if batt > 0 and cells > 0 then perCell = batt / cells end
ratio = batteryIconRatio(w, perCell, batt)
slices = batteryIconSlices(ratio)
if perCell >= (w.battHigh or 4.15) then battCol = c.good
elseif perCell >= (w.battMid or 3.75) then battCol = c.warn end
end
if fuelMode then
local gaugeW = math.floor(scrW * 0.72)
local gaugeLeft = math.floor((scrW - gaugeW) / 2)
local gaugeTop = imageY + imageH + px(6, scale, 3, 10)
local gaugeBottom = scrH - px(70, scale, 34, 84) - px(4, scale, 2, 8)
drawFuelGauge(w, c, scale, gaugeLeft, gaugeW, gaugeTop, gaugeBottom, batt, 2.10, math.floor(scrW / 2), gaugeBottom)
if w.currentSource then
local curr = getVal(w.currentSource)
setFontSize("small", scale)
lcd.color(c.secondary)
local txt = "Curr " .. formatValue(curr) .. "A"
lcd.drawText(margin, gaugeTop + px(58, scale, 34, 74), txt)
end
else
local leftSafe = imageX + imageW + gap
local rightSafe = scrW - rightPad - lqBarW - gap
local centerAreaW = rightSafe - leftSafe
local maxBattW = math.floor(scrW * 0.36)
if centerAreaW > 0 then maxBattW = math.min(maxBattW, math.floor(centerAreaW * 0.98)) end
local drewDial = tonumber(w.batteryStyle) == 2 and drawBatteryDial(w, c, scale, scrW, scrH, batt, ratio, battCol)
if not drewDial then
local bottomReserve = px(w.currentSource and 120 or 92, scale, 48, 130)
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
lcd.drawRectangle(bx, by, battW, battH)
local headW = math.floor(battW * 0.4)
local headX = bx + math.floor((battW - headW) / 2)
local headH = math.max(2, math.floor(battH * 0.05))
lcd.drawFilledRectangle(headX, by - headH - 2, headW, headH, c.outline)
local battCenter = bx + math.floor(battW / 2)
lcd.color(c.text)
setFontSize("huge", scale)
local vText = string.format("%.2fV", batt)
local vW = getTextW(vText) or 0
lcd.drawText(battCenter - math.floor(vW / 2), by + battH + px(10, scale, 4, 14), vText)
if w.currentSource then
local curr = getVal(w.currentSource)
setFontSize("small", scale)
lcd.color(c.secondary)
local txt = "Curr" .. " " .. formatValue(curr) .. "A"
local cW = getTextW(txt) or 0
lcd.drawText(battCenter - math.floor(cW / 2), by + battH + px(58, scale, 28, 64), txt)
end
end
end
lcd.color(c.text)
local timerScale = scale * 1.50
setFontSize("huge", timerScale)
local timerText = w.flightActive and formatTime(w.flightTime) or getStr(w.timerSource)
local timerY = scrH - px(70, scale, 34, 84)
local timerBold = px(2, timerScale, 1, 3)
lcd.drawText(margin + timerBold, timerY, timerText)
lcd.drawText(margin, timerY, timerText)
local rssi = getVal(w.rssiSource)
if rssi > 100 then rssi = 100 end
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
local lqTxt = string.format("%s: %d%%", sourceName(w.rssiSource, "Link"), math.floor(rssi))
local lqW = getTextW(lqTxt) or 0
lcd.drawText(scrW - rp - lqW, ty, lqTxt)
local bW2, bH2 = lqBarW, lqBarH
local bx2 = scrW - rp - bW2
local barY = ty + px(44, scale, 24, 50)
lcd.color(c.barFrame)
lcd.drawRectangle(bx2, barY, bW2, bH2)
lcd.color(rCol)
local segs = 10
local space = px(2, scale, 1, 3)
local inset = px(2, scale, 1, 4)
local usable = bW2 - inset * 2
local segW = math.floor((usable - (segs - 1) * space) / segs)
if segW < 1 then segW = 1 end
local act
if rssi >= (w.linkHigh or 98) then
act = segs
else
act = math.floor((rssi / 100) * segs)
end
if act < 0 then act = 0 end
if act > segs then act = segs end
if act == segs then
lcd.drawFilledRectangle(bx2 + inset, barY + inset, bW2 - inset * 2, bH2 - inset * 2)
else
for i = 0, act - 1 do
local xOff = bx2 + inset + i * (segW + space)
lcd.drawFilledRectangle(xOff, barY + inset, segW, bH2 - inset * 2)
end
end
if w.rpmSource then
local rpm = getVal(w.rpmSource)
local rpmTxt = "RPM: " .. formatValue(rpm)
local rpmY = barY + bH2 + px(34, scale, 20, 42)
setFontSize("large", scale)
lcd.color(c.neutral)
lcd.drawText(scrW - rp - (getTextW(rpmTxt) or 0), rpmY, rpmTxt)
end
local by2 = scrH - px(102, scale, 58, 118) - lineGap
lcd.color(c.muted)
setFontSize("small", scale)
local fieldRight = scrW - rp
drawSourceRight(w.field1Source, "Telemetry 1", fieldRight, by2 - 2)
drawSourceRight(w.field2Source, "Telemetry 2", fieldRight, by2 + lineGap - 2)
drawSourceRight(w.field3Source, "Telemetry 3", fieldRight, by2 + lineGap * 2 - 2)
drawPercentRight(w, fieldRight, by2 + lineGap * 3 - 2)
if w.armSeenAt and not w.flightActive then
local barH = px(32, scale, 17, 38)
local barY = imageY + imageH + px(3, scale, 1, 6)
local barW = math.floor(imageW * 0.72)
local barX = imageX + math.floor((imageW - barW) / 2)
lcd.color(c.warn)
lcd.drawFilledRectangle(barX, barY, barW, barH)
lcd.color(c.outline)
lcd.drawRectangle(barX, barY, barW, barH)
setFontSize("small", scale)
local txt = "ARMED"
local txtX = barX + math.floor((barW - (getTextW(txt) or 0)) / 2)
local txtY = barY - px(3, scale, 1, 5)
local bold = px(1, scale, 1, 2)
lcd.color(lcd.RGB(0, 0, 0))
lcd.drawText(txtX, txtY, txt)
lcd.drawText(txtX + bold, txtY, txt)
end
if not telemetryOk then drawNoTelemetry(c, scrW, scrH) end
end
local function wakeup(w)
if w then
updateFlight(w)
if w.dirty and os.clock() - (w.dirtyAt or 0) > 0.5 then
local saved = write(w)
if saved then
w.dirty = false
else
w.dirtyAt = os.clock() + 4.5
end
end
end
lcd.invalidate()
end
local function init()
system.registerWidget({
key = "mdash",
name = name,
create = create,
paint = paint,
configure = configure,
read = read,
write = write,
wakeup = wakeup,
title = false,
})
end
return { init = init }
