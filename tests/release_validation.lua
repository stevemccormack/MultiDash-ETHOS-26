local realOpen = io.open
local testFiles = {}
io.open = function(path, mode)
  if not tostring(path):match("^SCRIPTS:/MultiDash/models/") then
    return realOpen and realOpen(path, mode)
  end
  if mode == "w" then testFiles[path] = "" end
  if mode == "r" and testFiles[path] == nil then return nil end
  local position = 1
  return {
    write = function(_, ...)
      local values = {...}
      for i = 1, #values do testFiles[path] = testFiles[path] .. tostring(values[i]) end
      return true
    end,
    read = function()
      local text = testFiles[path] or ""
      if position > #text then return nil end
      local ending = text:find("\n", position, true)
      local line = text:sub(position, ending and ending - 1 or #text)
      position = ending and ending + 1 or #text + 1
      return line
    end,
    close = function() return true end,
  }
end

FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4
local font = FONT_S
local fontMetrics = {
  [FONT_S] = {6, 12},
  [FONT_L] = {9, 18},
  [FONT_XL] = {12, 24},
  [FONT_XXL] = {16, 32},
}

local screenW, screenH = 800, 480
local clipX, clipY, clipW, clipH = 0, 0, screenW, screenH
local drawnTexts = {}
local drawnTextFonts = {}
local drawColor, maxGaugeRadius, maxBatteryFillHeight = 0, 0, 0
local goodColor = 48 * 65536 + 209 * 256 + 133
local function number(value)
  assert(type(value) == "number" and value == value and value > -math.huge and value < math.huge)
end
local function box(x, y, w, h)
  number(x); number(y); number(w); number(h)
  assert(w >= 0 and h >= 0)
  assert(x >= -screenW and y >= -screenH and x <= screenW * 2 and y <= screenH * 2)
end
local function textSize(text)
  local metric = fontMetrics[font] or fontMetrics[FONT_S]
  text = tostring(text or "")
  if utf8 and utf8.codes then
    local width = 0
    for _, codepoint in utf8.codes(text) do
      width = width + (codepoint >= 0x2E80 and metric[2] or metric[1])
    end
    return width, metric[2]
  end
  return #text * metric[1], metric[2]
end
local function setScreen(width, height)
  screenW, screenH = width, height
  clipX, clipY, clipW, clipH = 0, 0, width, height
end

lcd = {
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  color = function(value) drawColor = value end,
  font = function(value) font = value end,
  getTextSize = textSize,
  drawText = function(x, y, text)
    number(x); number(y)
    local width, height = textSize(text)
    assert(x >= clipX - 4 and y >= clipY - 4)
    assert(x + width <= clipX + clipW + 4 and y + height <= clipY + clipH + 4)
    text = tostring(text)
    drawnTexts[#drawnTexts + 1] = text
    drawnTextFonts[text] = math.max(drawnTextFonts[text] or 0, tonumber(font) or 0)
  end,
  drawFilledRectangle = function(x, y, w, h)
    box(x, y, w, h)
    if drawColor == goodColor and w > h then maxBatteryFillHeight = math.max(maxBatteryFillHeight, h) end
  end,
  drawLine = function(x1, y1, x2, y2) number(x1); number(y1); number(x2); number(y2) end,
  drawFilledCircle = function(x, y, r)
    number(x); number(y); number(r); assert(r >= 0)
    maxGaugeRadius = math.max(maxGaugeRadius, r)
  end,
  drawCircle = function(x, y, r) number(x); number(y); number(r); assert(r >= 0) end,
  setClipping = function(...)
    if select("#", ...) > 0 then
      box(...)
      clipX, clipY, clipW, clipH = ...
    else
      clipX, clipY, clipW, clipH = 0, 0, screenW, screenH
    end
  end,
  drawBitmap = function(x, y, _, w, h)
    number(x); number(y)
    if w ~= nil then number(w); number(h); assert(w >= 0 and h >= 0) end
  end,
  loadBitmap = function()
    return {
      width = function() return 200 end,
      height = function() return 100 end,
    }
  end,
  invalidate = function() end,
  getWindowSize = function() return 0, 0, screenW, screenH end,
}

local registered
local playedAudio = {}
system = {
  registerWidget = function(widget) registered = widget end,
  playFile = function(path) playedAudio[#playedAudio + 1] = path end,
  getLocale = function() return "en-US" end,
  getMemoryUsage = function() return {luaBitmapsRamAvailable = 1024 * 1024} end,
  getSource = function(value)
    if type(value) == "table" then value = value.member or value.category or 0 end
    return {
      key = value,
      value = function(self) return tonumber(self.key) or 1 end,
      name = function(self) return tostring(self.key) end,
    }
  end,
  getSwitch = function(value) return system.getSource(value) end,
}
model = {name = function() return "MultiDash Release Test" end}

local formLabels = {}
local formDecimals = {}
local formSourceSetters = {}
form = {
  addLine = function(label) formLabels[#formLabels + 1] = label; return {label = label} end,
  addHeader = function(label) formLabels[#formLabels + 1] = label end,
  addNumberField = function(line)
    return {decimals = function(_, places)
      if type(line) == "table" then formDecimals[line.label] = places end
    end}
  end,
  addChoiceField = function() end,
  addBooleanField = function() end,
  addSourceField = function(line, slot, get, set)
    if type(slot) == "function" then get, set = slot, get end
    if type(line) == "table" and type(set) == "function" then formSourceSetters[line.label] = set end
  end,
  addSwitchField = function() end,
  addFileField = function() end,
}

local main = assert(loadfile("main.lua"))()
assert(main and main.init)
main.init()
assert(registered and registered.key == "mdash")

local widget = assert(loadfile("widget.lua"))()
local sizes = {
  {472, 191}, {472, 210}, {630, 236}, {630, 258},
  {784, 236}, {784, 258}, {784, 270}, {784, 294}, {784, 316},
  {480, 320}, {640, 360}, {800, 480}, {1024, 600},
}

local w = widget.create()
w.powerProfile, w.batteryMode, w.cellCount = 2, 2, 6
w.batterySource, w.battery2Source = 25.08, 24.96
w.totalBatterySource = 49.85
w.rssiSource, w.armSwitch, w.statusSource = 99, 1, 1
widget.configure(w)
local hasTotalSourceSetting = false
for _, label in ipairs(formLabels) do
  if label == "Total Pack Voltage Source" then hasTotalSourceSetting = true end
end
assert(hasTotalSourceSetting, "dual profile is missing the optional total-pack source")
w._filtered, w._batteryLevels, w.linkMin = {link = 99}, {battery1 = 3}, 98
assert(formSourceSetters.LQ, "link source setter was not registered")
formSourceSetters.LQ(97)
assert(not w._filtered and not w._batteryLevels and w.linkMin == nil,
  "changing a telemetry source retained incompatible filter state")
for i = 1, 4 do
  assert(formDecimals["Tlm " .. i .. " high"] == 1, "telemetry high threshold must use tenths")
  assert(formDecimals["Tlm " .. i .. " mid"] == 1, "telemetry mid threshold must use tenths")
end
for _, label in ipairs(formLabels) do assert(label ~= "Audio", "audio must not be configurable") end
local fullForm, fallbackLabels = form, {}
form = {
  addLine = function(label) fallbackLabels[#fallbackLabels + 1] = label; return {label = label} end,
  addNumberField = function() return {decimals = function() end} end,
  addSelectField = function() end,
  addSourceField = function() end,
}
widget.configure(widget.create())
assert(#fallbackLabels > 20, "ETHOS form API fallbacks did not build the configuration page")
form = fullForm
for _, size in ipairs(sizes) do
  setScreen(size[1], size[2])
  widget.paint(w, screenW, screenH)
end
for _, size in ipairs({{460, 185}, {460, 317}, {619, 185}, {1024, 306}, {459, 320}, {800, 600}}) do
  setScreen(size[1], size[2])
  widget.paint(w, screenW, screenH)
end

local fontProbe = widget.create()
fontProbe.powerProfile, fontProbe.batteryMode, fontProbe.cellCount = 2, 2, 6
fontProbe.batterySource, fontProbe.battery2Source = 25.08, 24.96
fontProbe.totalBatterySource = 49.85
fontProbe.rssiSource, fontProbe.statusSource = 99, 1
fontProbe.field1Source = 72
local fontMaxima, sideFontMaxima = {}, {}
setScreen(800, 480)
for setting = 1, 3 do
  fontProbe.fontSize, drawnTextFonts = setting, {}
  widget.paint(fontProbe, screenW, screenH)
  fontMaxima[setting] = assert(drawnTextFonts["25.08V"], "battery telemetry value not drawn")
  sideFontMaxima[setting] = assert(drawnTextFonts["72"], "side telemetry value not drawn")
  assert(drawnTextFonts["49.85V"], "selected total-pack telemetry value not drawn")
end
assert(fontMaxima[1] < fontMaxima[2] and fontMaxima[2] < fontMaxima[3],
  "font presets must increase visibly: " .. table.concat(fontMaxima, ","))
assert(sideFontMaxima[1] < sideFontMaxima[2] and sideFontMaxima[2] < sideFontMaxima[3],
  "side telemetry presets must increase visibly: " .. table.concat(sideFontMaxima, ","))

local gaugeProbe = widget.create()
gaugeProbe.cellCount, gaugeProbe.batterySource = 6, 25.08
local batteryHeights, dialRadii = {}, {}
for setting = 1, 3 do
  gaugeProbe.fontSize, gaugeProbe.batteryStyle = setting, 1
  maxBatteryFillHeight = 0
  widget.paint(gaugeProbe, screenW, screenH)
  batteryHeights[setting] = maxBatteryFillHeight
  gaugeProbe.batteryStyle, maxGaugeRadius = 2, 0
  widget.paint(gaugeProbe, screenW, screenH)
  dialRadii[setting] = maxGaugeRadius
end
assert(batteryHeights[3] >= batteryHeights[2] * 0.85,
  "Large text shrank the battery gauge too far: " .. table.concat(batteryHeights, ","))
assert(dialRadii[3] >= dialRadii[2] * 0.85,
  "Large text shrank the dial gauge too far: " .. table.concat(dialRadii, ","))

local function stressSource(name, unit, value)
  return {
    name = function() return name end,
    stringUnit = function() return unit end,
    value = function() return value end,
    isValid = function() return true end,
  }
end
local paintStress = widget.create()
paintStress.fontSize, paintStress.batteryStyle, paintStress.cellCount = 3, 2, 6
paintStress.batterySource = stressSource("FLVSS", "V", 25.08)
paintStress.rssiSource = stressSource("LQ", "%", 99)
paintStress.statusSource = stressSource("Status", "", 1)
paintStress.currentSource = stressSource("Current", "A", 35)
paintStress.rpmSource = stressSource("RPM", "rpm", 6400)
paintStress.field1Source = stressSource("Altitude", "m", 101)
paintStress.field2Source = stressSource("Temperature", "C", 102)
paintStress.field3Source = stressSource("Speed", "km/h", 103)
paintStress.telemetry4Source = stressSource("Consumption", "mAh", 104)
local telemetryFonts = {FONT_S, FONT_L, FONT_XL}
for setting = 1, 3 do
  paintStress.fontSize = setting
  for _, size in ipairs(sizes) do
    drawnTextFonts = {}
    setScreen(size[1], size[2])
    widget.paint(paintStress, screenW, screenH)
    local expected = assert(drawnTextFonts["101"], "Telemetry 1 value not drawn")
    assert(expected == telemetryFonts[setting],
      "telemetry preset did not scale at setting " .. setting .. " on " .. size[1] .. "x" .. size[2])
    assert(drawnTextFonts["102"] == expected and drawnTextFonts["103"] == expected
        and drawnTextFonts["104"] == expected,
      "telemetry fonts differ at setting " .. setting .. " on " .. size[1] .. "x" .. size[2])
  end
end
paintStress.fontSize = 3
setScreen(800, 480)
local function instructionCount(fn)
  local count = 0
  debug.sethook(function() count = count + 100 end, "", 100)
  local ok, result = pcall(fn)
  debug.sethook()
  assert(ok, result)
  return count
end
local paintInstructions = instructionCount(function() widget.paint(paintStress, screenW, screenH) end)
paintStress.nextRefresh = 0
local wakeupInstructions = instructionCount(function() widget.wakeup(paintStress) end)
local writeInstructions = instructionCount(function() assert(widget.write(paintStress)) end)
local readProbe = widget.create()
local readInstructions = instructionCount(function() assert(widget.read(readProbe)) end)
formLabels = {}
local configInstructions = instructionCount(function() widget.configure(paintStress) end)
local maxPaintInstructions = paintInstructions
local maxPaintCase = "en 800x480"
for _, language in ipairs({"en", "de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw"}) do
  paintStress.language = language
  for _, size in ipairs(sizes) do
    setScreen(size[1], size[2])
    local instructions = instructionCount(function() widget.paint(paintStress, screenW, screenH) end)
    if instructions > maxPaintInstructions then
      maxPaintInstructions = instructions
      maxPaintCase = language .. " " .. size[1] .. "x" .. size[2]
    end
  end
end
local summaryStress = widget.create()
summaryStress.fontSize, summaryStress.postFlight = 3, true
summaryStress.flightTime, summaryStress.flightCount = 359999, 9999
summaryStress.stats, summaryStress.statOrder = {}, {
  "batt", "battTotal", "link", "current", "rpm", "field1", "field2", "field3", "telemetry4", "field4",
}
for _, key in ipairs(summaryStress.statOrder) do
  summaryStress.stats[key] = {label = "Telemetry " .. key, min = 10, max = 20}
end
setScreen(800, 480)
local summaryInstructions = instructionCount(function() widget.paint(summaryStress, screenW, screenH) end)
for _, language in ipairs({"en", "de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw"}) do
  summaryStress.language = language
  for fontSize = 1, 3 do
    summaryStress.fontSize = fontSize
    for _, size in ipairs(sizes) do
      setScreen(size[1], size[2])
      widget.paint(summaryStress, screenW, screenH)
    end
  end
end
print(string.format("callback instructions: paint=%d matrixMax=%d (%s) summary=%d wakeup=%d write=%d read=%d configure=%d",
  paintInstructions, maxPaintInstructions, maxPaintCase, summaryInstructions, wakeupInstructions,
  writeInstructions, readInstructions, configInstructions))
assert(paintInstructions < 25000 and wakeupInstructions < 25000 and writeInstructions < 25000
    and readInstructions < 25000 and configInstructions < 25000
    and maxPaintInstructions < 25000 and summaryInstructions < 25000,
  "callback instruction budget exceeded")

local officialRadioTargets = {
  "T14", "TWXLITE", "TWXLITEP", "TWXLITERII", "TWXLITES", "V15", "V20", "V20PRO", "VX10",
  "X14", "X14RS", "X14S", "X18", "X18R", "X18RS", "X18S", "X20", "X20HD", "X20PRO",
  "X20PROAW", "X20R", "X20RS", "X20S", "X20SHD", "XE", "XERS", "XES",
}
assert(#officialRadioTargets == 27)
local officialScreens = {{480, 320}, {640, 360}, {800, 480}}
local cellOptions = {0, 1, 6, 12}
for profile = 1, 5 do
  local profiled = widget.create()
  profiled.powerProfile = profile
  profiled.powerSourceType = profile == 4 and 2 or 1
  profiled.batteryMode = profile == 2 and 2 or 1
  profiled.rotorwingMode = profile == 3 and 2 or 1
  profiled.cellCount = 6
  profiled.batterySource, profiled.battery2Source = 25.08, 24.96
  profiled.field4Source, profiled.rssiSource = 72, 98
  profiled.currentSource, profiled.rpmSource = 35, 6400
  widget.configure(profiled)
  for fontSize = 1, 3 do
    profiled.fontSize = fontSize
    for _, size in ipairs(sizes) do
      setScreen(size[1], size[2])
      widget.paint(profiled, screenW, screenH)
    end
  end
  for themeMode = 1, 2 do
    for batteryStyle = 1, 2 do
      for statusMode = 1, 2 do
        for inFlightScreen = 1, 2 do
          for fontSize = 1, 3 do
            profiled.themeMode, profiled.batteryStyle = themeMode, batteryStyle
            profiled.statusMode, profiled.inFlightScreen = statusMode, inFlightScreen
            profiled.fontSize = fontSize
            profiled.batteryType = ((profile + themeMode + batteryStyle + fontSize) % 5) + 1
            profiled.cellCount = cellOptions[((statusMode + inFlightScreen + fontSize) % #cellOptions) + 1]
            profiled.fuelShowPercent = (themeMode + fontSize) % 2 + 1
            local edge = (profile + themeMode + batteryStyle + statusMode + inFlightScreen + fontSize) % 2
            profiled.battHigh, profiled.battMid, profiled.battLow = edge == 0 and 0 or 4.35,
              edge == 0 and 4.35 or 0, edge == 0 and 0 or 4.35
            profiled.packWarn, profiled.packBad = edge, 1 - edge
            profiled.linkHigh, profiled.linkMid = edge == 0 and -65 or 10000, edge == 0 and -90 or -200
            profiled.currentHigh, profiled.currentMid = edge == 0 and 0 or 10000, edge == 0 and 10000 or 0
            profiled.rpmMax, profiled.rpmWarn = edge == 0 and 1000 or 50000, edge == 0 and 0 or 50000
            for _, prefix in ipairs({"field1", "field2", "field3", "field4", "telemetry4"}) do
              profiled[prefix .. "High"], profiled[prefix .. "Mid"] = edge == 0 and 0 or 50000,
                edge == 0 and 50000 or 0
              profiled[prefix .. "Mode"] = edge + 1
            end
            for _, size in ipairs(officialScreens) do
              setScreen(size[1], size[2])
              widget.paint(profiled, screenW, screenH)
            end
          end
        end
      end
    end
  end
  widget.close(profiled)
end

local memorySupported, memoryBefore = pcall(collectgarbage, "count")
for i = 1, 1000 do
  local instance = widget.create()
  instance.powerProfile, instance.batteryMode, instance.cellCount = 2, 2, 6
  instance.batterySource, instance.battery2Source = 25.08, 24.96
  local size = sizes[(i - 1) % #sizes + 1]
  setScreen(size[1], size[2])
  widget.paint(instance, screenW, screenH)
  widget.wakeup(instance)
  widget.close(instance)
end
if memorySupported then
  collectgarbage("collect")
  local memoryGrowth = collectgarbage("count") - memoryBefore
  assert(memoryGrowth < 32, "lifecycle memory growth: " .. tostring(memoryGrowth) .. " KB")
  print(string.format("lifecycle memory growth after 1000 cycles: %.1f KB", memoryGrowth))
end
local closed = widget.create()
closed.selectedBmp, closed.selectedFile, closed._powerInfo = {}, "image.png", {}
closed._dualPowerInfo, closed._filtered, closed._batteryLevels = {}, {}, {}
closed._sourceClears, closed._timerTextSeconds, closed._timerText = {}, 0, "00:00"
closed._flightLabelCount, closed._flightLabelLanguage, closed._flightLabel = 1, "en", "1 Flight"
closed._audioArmSource, closed._audioArmed, closed._telemetryCuePlayed = {}, true, true
closed.stats, closed.statOrder = {}, {}
widget.close(closed)
assert(not closed.selectedBmp and not closed.selectedFile and not closed._powerInfo
    and not closed._dualPowerInfo and not closed._filtered and not closed._batteryLevels
    and not closed._sourceClears and not closed._timerTextSeconds and not closed._timerText
    and not closed._flightLabelCount and not closed._flightLabelLanguage and not closed._flightLabel
    and not closed._audioArmSource and not closed._audioArmed and not closed._telemetryCuePlayed
    and not closed.stats and not closed.statOrder,
  "close retained runtime caches")

assert(widget.write(w))
local restored = widget.create()
assert(widget.read(restored))
assert(restored.batteryMode == 2 and restored.cellCount == 6)
assert(restored.powerProfile == 2)
assert(restored.batterySource and restored.battery2Source)
assert(restored.totalBatterySource)
restored.battery2Source = nil
restored._sourceClears = {battery2Source = true}
restored.dirty = true
assert(widget.write(restored))
local cleared = widget.create()
assert(widget.read(cleared))
assert(cleared.battery2Source == nil)

model.name = function() return "Structured Source" end
local structured = widget.create()
structured.rssiSource = {
  category = function() return 9 end,
  member = function() return 42 end,
  options = function() return 3 end,
  name = function() return "RQly" end,
  value = function() return 99 end,
}
assert(widget.write(structured))
local structuredRestored = widget.create()
assert(widget.read(structuredRestored))
assert(structuredRestored.rssiSource and structuredRestored.rssiSource.key == 42,
  "structured ETHOS source identity did not survive a save and reload")

model.name = function() return "Bound Model A" end
local bound = widget.create()
assert(widget.read(bound))
assert(bound._modelName == "Bound Model A")
model.name = function() return "Bound Model B" end
assert(widget.write(bound))
local wroteA, wroteB = false, false
for path in pairs(testFiles) do
  if path:find("Bound_Model_A_", 1, true) then wroteA = true end
  if path:find("Bound_Model_B_", 1, true) then wroteB = true end
end
assert(wroteA and not wroteB, "model switch save crossed the widget's model boundary")
widget.close(bound)

model.name = function() return "Legacy Model" end
testFiles["SCRIPTS:/MultiDash/models/Legacy_Model.cfg"] =
  "battery=25.2\nbattery2=24.9\ncells=6\nbatteryMode=2\nfontSize=2\n"
local legacy = widget.create()
assert(widget.read(legacy))
assert(legacy.batteryMode == 2 and legacy.cellCount == 6)
assert(legacy.batterySource and legacy.battery2Source)

model.name = function() return "Corrupt Model" end
testFiles["SCRIPTS:/MultiDash/models/Corrupt_Model.cfg"] =
  "schema=2\nfontSize=1e999\ncells=1e999\nbatteryType=1e999\nrpmMax=1e999\nflightCount=1e999\n"
  .. "linkHigh=-65.6\nlinkMid=-90.4\n"
local corrupt = widget.create()
assert(widget.read(corrupt))
assert(corrupt.fontSize == 2 and corrupt.cellCount == 0 and corrupt.batteryType == 1
  and corrupt.rpmMax == 8000 and corrupt.flightCount == 0
  and corrupt.linkHigh == -66 and corrupt.linkMid == -90,
  "non-finite saved settings were not rejected")
corrupt.fontSize, corrupt.cellCount, corrupt.batteryType = math.huge, 0 / 0, -math.huge
corrupt.rpmMax, corrupt.rpmWarn, corrupt.flightCount = math.huge, 0 / 0, math.huge
corrupt.battHigh, corrupt.battMid, corrupt.battLow = math.huge, 0 / 0, -math.huge
assert(widget.write(corrupt), "non-finite live settings prevented a safe save")
assert(corrupt.fontSize == 2 and corrupt.cellCount == 0 and corrupt.batteryType == 1
  and corrupt.rpmMax == 8000 and corrupt.flightCount == 0,
  "non-finite live settings were not normalized")
model.name = function() return "MultiDash Release Test" end

local cycles = widget.create()
cycles.armDelay, cycles.armSwitch, cycles.nextRefresh = 0, 1, 0
widget.wakeup(cycles)
assert(cycles.flightActive and not cycles.postFlight)
cycles.flightStart, cycles.armSwitch, cycles.nextRefresh = os.clock() - 20, 0, 0
widget.wakeup(cycles)
assert(cycles.flightCount == 1 and cycles.postFlight)
cycles.armSwitch, cycles.nextRefresh = 1, 0
widget.wakeup(cycles)
assert(cycles.flightActive and not cycles.postFlight)
cycles.flightStart, cycles.armSwitch, cycles.nextRefresh = os.clock() - 20, 0, 0
widget.wakeup(cycles)
assert(cycles.flightCount == 2, "consecutive flights must both count")

local function testSwitch()
  return {
    state = 0,
    name = function() return "Arm" end,
    value = function(self) return self.state end,
  }
end

local audio = widget.create()
local audioArm = testSwitch()
audio.armDelay, audio.armSwitch, audio.cellCount = 60, audioArm, 6
audio.audioEnabled = 2
audio.batterySource = 25.2
playedAudio = {}
widget.wakeup(audio)
assert(#playedAudio == 1 and playedAudio[1]:find("beep.wav", 1, true),
  "first valid telemetry must play beep.wav once")
audio.nextRefresh = 0
widget.wakeup(audio)
assert(#playedAudio == 1, "steady telemetry replayed beep.wav")
audioArm.state, audio.nextRefresh = 1, 0
widget.wakeup(audio)
assert(#playedAudio == 2 and playedAudio[2]:find("armed.wav", 1, true),
  "arming must play only armed.wav")
audioArm.state, audio.nextRefresh = 0, 0
widget.wakeup(audio)
assert(#playedAudio == 3 and playedAudio[3]:find("disarm.wav", 1, true),
  "disarming must play disarm.wav")
audio.batterySource, audio.nextRefresh = 0, 0
widget.wakeup(audio)
audio.batterySource, audio.nextRefresh = 25.2, 0
widget.wakeup(audio)
assert(#playedAudio == 3, "telemetry reacquisition replayed beep.wav")

local warningAudio = widget.create()
local warningArm = testSwitch()
warningAudio.armDelay, warningAudio.armSwitch, warningAudio.cellCount = 60, warningArm, 6
warningAudio.batterySource = 21
playedAudio = {}
widget.wakeup(warningAudio)
assert(#playedAudio == 1 and playedAudio[1]:find("beep.wav", 1, true),
  "low-voltage telemetry must still get one acquisition cue")
warningArm.state, warningAudio.nextRefresh = 1, 0
widget.wakeup(warningAudio)
assert(#playedAudio == 2 and playedAudio[2]:find("armed.wav", 1, true),
  "arming must not replay the telemetry cue")
for _ = 1, 30 do warningAudio.nextRefresh = 0; widget.wakeup(warningAudio) end
assert(#playedAudio == 2, "low voltage caused repeated telemetry beeps")

local missingAudio = widget.create()
local missingArm = testSwitch()
missingAudio.armDelay, missingAudio.armSwitch, missingAudio.cellCount = 60, missingArm, 6
local missingSensor = {
  online = false,
  reading = 0,
  name = function() return "FLVSS" end,
  value = function(self) return self.reading end,
  isValid = function(self) return self.online end,
}
missingAudio.batterySource = missingSensor
playedAudio = {}
widget.wakeup(missingAudio)
assert(#playedAudio == 0, "missing telemetry played the acquisition cue")
missingArm.state, missingAudio.nextRefresh = 1, 0
widget.wakeup(missingAudio)
assert(#playedAudio == 1 and playedAudio[1]:find("armed.wav", 1, true),
  "arming voice cue was not isolated")
missingSensor.online, missingSensor.reading, missingAudio.nextRefresh = true, 25.2, 0
widget.wakeup(missingAudio)
assert(#playedAudio == 2 and playedAudio[2]:find("beep.wav", 1, true),
  "telemetry received after arming did not beep once")
missingAudio.nextRefresh = 0
widget.wakeup(missingAudio)
assert(#playedAudio == 2, "received telemetry replayed beep.wav")

local simultaneousAudio = widget.create()
local simultaneousArm = testSwitch()
simultaneousAudio.armDelay, simultaneousAudio.armSwitch = 60, simultaneousArm
local simultaneousSensor = {
  online = false,
  name = function() return "Current" end,
  value = function() return 0 end,
  isValid = function(self) return self.online end,
}
simultaneousAudio.currentSource = simultaneousSensor
playedAudio = {}
widget.wakeup(simultaneousAudio)
simultaneousArm.state, simultaneousSensor.online, simultaneousAudio.nextRefresh = 1, true, 0
widget.wakeup(simultaneousAudio)
simultaneousAudio.nextRefresh = 0
widget.wakeup(simultaneousAudio)
assert(#playedAudio == 1 and playedAudio[1]:find("armed.wav", 1, true),
  "telemetry arriving with arming queued an extra beep")

local validityError = widget.create()
validityError.currentSource = {
  name = function() return "Broken validity" end,
  value = function() return 0 end,
  isValid = function() error("validity failed") end,
}
playedAudio = {}
widget.wakeup(validityError)
assert(#playedAudio == 0, "a failed sensor validity check was treated as telemetry")

local function sensor(name, unit, value)
  return {
    name = function() return name end,
    stringUnit = function() return unit end,
    value = function() return value end,
    isValid = function() return true end,
  }
end
local manualCells = widget.create()
manualCells.powerProfile, manualCells.batteryMode = 2, 2
manualCells.batterySource, manualCells.battery2Source = 22.2, 22.1
setScreen(480, 320)
widget.paint(manualCells, screenW, screenH)
assert(manualCells.cellCount == 0,
  "cell count must remain an explicit pilot setting")

local savedMemoryUsage, savedLoadBitmap = system.getMemoryUsage, lcd.loadBitmap
local imageLoads = 0
lcd.loadBitmap = function(...)
  imageLoads = imageLoads + 1
  return savedLoadBitmap(...)
end
system.getMemoryUsage = function() return {luaBitmapsRamAvailable = 400 * 1024} end
local lowMemoryImage = widget.create()
lowMemoryImage.imageFile = "BITMAPS:/models/large.png"
widget.paint(lowMemoryImage, screenW, screenH)
assert(imageLoads == 0, "custom image loaded without enough decoded-bitmap RAM headroom")
system.getMemoryUsage = function() return {luaBitmapsRamAvailable = 1024 * 1024} end
lowMemoryImage.selectedFile = nil
widget.paint(lowMemoryImage, screenW, screenH)
assert(imageLoads == 1, "safe custom image did not load when memory was available")
lcd.loadBitmap, system.getMemoryUsage = savedLoadBitmap, savedMemoryUsage
widget.close(lowMemoryImage)

local hostileReaders = {
  function() return 0 / 0 end,
  function() return math.huge end,
  function() return -math.huge end,
  function() return nil end,
  function() error("sensor read failed") end,
}
for _, reader in ipairs(hostileReaders) do
  local hostileSource = {
    name = function() return "Broken sensor" end,
    stringUnit = function() return "V" end,
    value = reader,
    isValid = function() return true end,
  }
  local hostile = widget.create()
  hostile.powerProfile, hostile.batteryMode, hostile.cellCount = 2, 2, 6
  hostile.batterySource, hostile.battery2Source, hostile.totalBatterySource = hostileSource, hostileSource, hostileSource
  hostile.rssiSource, hostile.currentSource, hostile.rpmSource = hostileSource, hostileSource, hostileSource
  hostile.field1Source, hostile.field2Source = hostileSource, hostileSource
  hostile.field3Source, hostile.telemetry4Source = hostileSource, hostileSource
  hostile.timerSource, hostile.statusSource = hostileSource, {value = function() return true end}
  playedAudio, drawnTexts = {}, {}
  for _, size in ipairs(officialScreens) do
    setScreen(size[1], size[2])
    widget.paint(hostile, screenW, screenH)
  end
  hostile.nextRefresh = 0
  widget.wakeup(hostile)
  assert(#playedAudio == 0, "invalid telemetry played the acquisition cue")
  for _, text in ipairs(drawnTexts) do
    text = text:lower()
    assert(not text:find("nan", 1, true) and not text:find("inf", 1, true),
      "non-finite telemetry reached the display")
  end
  local hostileFuel = widget.create()
  hostileFuel.powerProfile, hostileFuel.powerSourceType = 4, 2
  hostileFuel.batterySource, hostileFuel.nextRefresh = hostileSource, 0
  playedAudio = {}
  widget.wakeup(hostileFuel)
  assert(#playedAudio == 0, "invalid zero-capable telemetry played the acquisition cue")
end

local emptyFuel = widget.create()
emptyFuel.powerProfile, emptyFuel.powerSourceType = 4, 2
emptyFuel.batterySource = sensor("Fuel", "%", 0)
playedAudio = {}
widget.wakeup(emptyFuel)
assert(#playedAudio == 1 and playedAudio[1]:find("beep.wav", 1, true),
  "a valid zero-percent fuel source was treated as missing")

local stringAndBoolean = widget.create()
stringAndBoolean.cellCount = 6
stringAndBoolean.batterySource = sensor("VFAS", "V", "25.20")
stringAndBoolean.statusSource = {value = function() return true end}
drawnTexts = {}
setScreen(800, 480)
widget.paint(stringAndBoolean, screenW, screenH)
local stringVoltageDrawn = false
for _, text in ipairs(drawnTexts) do
  if text:find("25.2", 1, true) then stringVoltageDrawn = true end
end
assert(stringVoltageDrawn, "numeric-string telemetry was not accepted")

local extreme = widget.create()
extreme.powerProfile, extreme.batteryMode, extreme.cellCount = 2, 2, 12
extreme.batterySource, extreme.battery2Source = sensor("Pack A", "V", 1e100), sensor("Pack B", "V", -1e100)
extreme.totalBatterySource, extreme.rssiSource = sensor("Total", "V", 1e100), sensor("LQ", "%", 1e100)
extreme.currentSource, extreme.rpmSource = sensor("Current", "A", 1e100), sensor("RPM", "rpm", 1e100)
extreme.field1Source, extreme.field2Source = sensor("High", "", 1e100), sensor("Low", "", -1e100)
extreme.timerSource = sensor("Timer", "s", 1e100)
for _, size in ipairs(officialScreens) do
  setScreen(size[1], size[2])
  widget.paint(extreme, screenW, screenH)
end
extreme.nextRefresh = 0
widget.wakeup(extreme)

local function containsText(value)
  for _, text in ipairs(drawnTexts) do if text == value then return true end end
  return false
end

local linkSource = {
  online = true,
  reading = 98.76,
  name = function() return "LQ" end,
  stringUnit = function() return "%" end,
  value = function(self) return self.reading end,
  isValid = function(self) return self.online end,
}
local linkProbe = widget.create()
linkProbe.cellCount, linkProbe.batterySource, linkProbe.rssiSource = 6, 25.2, linkSource
linkProbe.armDelay, linkProbe.armSwitch, linkProbe.nextRefresh = 0, 1, 0
drawnTexts = {}
setScreen(800, 480)
widget.paint(linkProbe, screenW, screenH)
assert(containsText("99%"), "link quality was not displayed as a whole number")
widget.wakeup(linkProbe)
linkSource.reading, linkProbe.nextRefresh = 97.24, 0
widget.wakeup(linkProbe)
assert(linkProbe.stats.link.min == 97 and linkProbe.stats.link.max == 99,
  "link statistics retained decimal values")
linkSource.reading, linkSource.stringUnit = -72.6, function() return "dBm" end
linkProbe.linkSeenAt, linkProbe.linkMin, linkProbe.nextRefresh = os.clock() - 10, nil, 0
widget.wakeup(linkProbe)
assert(linkProbe.linkMin == -73, "negative-dBm minimum was not rounded or tracked")
drawnTexts, linkProbe._filtered = {}, nil
widget.paint(linkProbe, screenW, screenH)
assert(containsText("-73dBm"), "negative-dBm link value was not displayed as a whole number")
linkSource.online, linkSource.reading, linkProbe.nextRefresh = false, 0, 0
widget.wakeup(linkProbe)
assert(linkProbe.linkMin == -73, "an invalid link sample contaminated the tracked minimum")

for _, case in ipairs({
  {"VFR", "", 97.6, "98%"},
  {"RQly", "", 98.2, "98%"},
  {"LQ", "%", 99.1, "99%"},
  {"RSSI", "dBm", -72.6, "-73dBm"},
  {"RSSI", "", -72.6, "-73"},
}) do
  local protocolProbe = widget.create()
  protocolProbe.cellCount, protocolProbe.batterySource = 6, 25.2
  protocolProbe.rssiSource = sensor(case[1], case[2], case[3])
  drawnTexts = {}
  widget.paint(protocolProbe, screenW, screenH)
  assert(containsText(case[4]), case[1] .. " link formatting failed for unit '" .. case[2] .. "'")
end

local staleSource = {
  online = true,
  reading = 42,
  name = function() return "Telemetry" end,
  value = function(self) return self.reading end,
  isValid = function(self) return self.online end,
}
local staleStats = widget.create()
staleStats.armDelay, staleStats.armSwitch, staleStats.field1Source = 0, 1, staleSource
widget.wakeup(staleStats)
assert(staleStats.stats.field1.min == 42 and staleStats.stats.field1.max == 42)
staleSource.online, staleSource.reading, staleStats.nextRefresh = false, 0, 0
widget.wakeup(staleStats)
assert(staleStats.stats.field1.min == 42 and staleStats.stats.field1.max == 42,
  "an invalid telemetry sample contaminated post-flight statistics")

local computedTotal = widget.create()
computedTotal.powerProfile, computedTotal.batteryMode, computedTotal.cellCount = 2, 2, 6
computedTotal.batterySource, computedTotal.battery2Source = 25.08, 24.96
drawnTexts = {}
setScreen(800, 480)
widget.paint(computedTotal, screenW, screenH)
assert(containsText("50.04V"), "dual-pack sum fallback missing")
computedTotal.totalBatterySource = 49.85
drawnTexts = {}
widget.paint(computedTotal, screenW, screenH)
assert(containsText("49.85V") and not containsText("50.04V"), "total-pack sensor did not override the sum")
local fuelDial = widget.create()
fuelDial.powerProfile, fuelDial.powerSourceType, fuelDial.batteryStyle = 4, 2, 2
fuelDial.batterySource, fuelDial.field4Source, fuelDial.rssiSource = 72, 72, 98
drawnTexts = {}
setScreen(800, 480)
widget.paint(fuelDial, screenW, screenH)
assert(containsText("E") and containsText("1/2") and containsText("F"), "fuel lettering changed")
local batteryDial = widget.create()
batteryDial.powerProfile, batteryDial.batteryStyle, batteryDial.cellCount = 1, 2, 6
batteryDial.batterySource, batteryDial.rssiSource = 25.08, 98
drawnTexts = {}
widget.paint(batteryDial, screenW, screenH)
assert(containsText("0") and containsText("50") and containsText("100"), "battery dial lettering missing")

local postTimer = widget.create()
postTimer.postFlight, postTimer.flightActive, postTimer.flightTime, postTimer.flightCount = true, false, 5999, 9999
for fontSize = 1, 3 do
  postTimer.fontSize = fontSize
  for _, size in ipairs(sizes) do
    drawnTexts, drawnTextFonts = {}, {}
    setScreen(size[1], size[2])
    widget.paint(postTimer, screenW, screenH)
    assert(containsText("99:59") and containsText("9999 Flights") and containsText("FLIGHT SUMMARY"),
      "post-flight header clipped at font " .. fontSize .. " on " .. size[1] .. "x" .. size[2])
    local expectedFont = math.min(fontSize + 1, size[2] < 250 and FONT_XL or FONT_XXL)
    if fontSize == 3 and size[1] == 480 and size[2] == 320 then expectedFont = FONT_XL end
    assert(drawnTextFonts["99:59"] == expectedFont
        and drawnTextFonts["9999 Flights"] == expectedFont
        and drawnTextFonts["FLIGHT SUMMARY"] == expectedFont,
      "post-flight header fonts: " .. tostring(drawnTextFonts["99:59"]) .. ","
        .. tostring(drawnTextFonts["9999 Flights"]) .. ","
        .. tostring(drawnTextFonts["FLIGHT SUMMARY"]) .. " expected " .. expectedFont
        .. " on " .. size[1] .. "x" .. size[2])
  end
end
widget.close(postTimer)

w.postFlight, w.flightActive = true, false
w.flightTime, w.flightCount = 83, 2
w.stats = {batt1 = {label = "Battery 1/cell", min = 3.72, max = 4.18}}
w.statOrder = {"batt1"}
setScreen(800, 480)
drawnTexts = {}
widget.paint(w, screenW, screenH)
local hasEmoticon = false
for _, text in ipairs(drawnTexts) do if text:find(":)", 1, true) or text:find(":(", 1, true) then hasEmoticon = true end end
assert(hasEmoticon, "post-flight emoticons were removed")
widget.close(w)

local i18n = assert(loadfile("i18n.lua"))()
system.getLocale = function() return "zh-TW" end
assert(i18n.systemDefault() == "zh_tw")
system.getLocale = function() return "zh-CN" end
assert(i18n.systemDefault() == "zh_cn")
system.getLocale = function() return "pt-BR" end
assert(i18n.systemDefault() == "pt")
system.getLocale = function() return "en-US" end
for _, code in ipairs(i18n.codes) do
  assert(i18n.valid(code) == code)
  assert(type(i18n.text({language = code}, "Battery")) == "string")
  local localized = widget.create()
  localized.language = code
  localized.powerProfile, localized.batteryMode, localized.cellCount = 2, 2, 6
  localized.batterySource, localized.battery2Source = 25.08, 24.96
  localized.rssiSource, localized.statusSource = 99, 1
  formLabels = {}
  widget.configure(localized)
  assert(#formLabels > 20)
  for _, label in ipairs(formLabels) do assert(type(label) == "string" and label ~= "") end
  for fontSize = 1, 3 do
    localized.fontSize = fontSize
    localized.flightActive, localized.postFlight = false, false
    for _, size in ipairs(sizes) do
      setScreen(size[1], size[2])
      localized.armSeenAt = nil
      widget.paint(localized, screenW, screenH)
      localized.armSeenAt = 1
      widget.paint(localized, screenW, screenH)
    end
    localized.flightActive = true
    for _, size in ipairs(sizes) do
      setScreen(size[1], size[2])
      widget.paint(localized, screenW, screenH)
    end
    localized.flightActive, localized.postFlight = false, true
    localized.flightTime, localized.flightCount = 83, 2
    localized.stats = {batt1 = {label = i18n.text(localized, "Battery 1/cell"), min = 3.72, max = 4.18}}
    localized.statOrder = {"batt1"}
    for _, size in ipairs(sizes) do
      drawnTexts = {}
      setScreen(size[1], size[2])
      widget.paint(localized, screenW, screenH)
      assert(containsText("2 " .. i18n.text(localized, "Flights"))
          and containsText(i18n.text(localized, "Flight summary"):upper())
          and containsText("01:23"),
        code .. " post-flight header clipped at font " .. fontSize
          .. " on " .. size[1] .. "x" .. size[2])
    end
  end
  widget.close(localized)
end

local expectedKeys
for _, code in ipairs({"de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw"}) do
  local labels = assert(loadfile("lang/" .. code .. ".lua"))()
  assert(labels["Electric Dual Battery"], code .. " is missing the corrected profile name")
  assert(labels["Electrix Dual Battery"] == nil and labels.Audio == nil,
    code .. " retained an obsolete label")
  local count = 0
  for key, value in pairs(labels) do
    count = count + 1
    assert(type(value) == "string" and value ~= "", code .. " has an empty translation: " .. key)
    if expectedKeys then assert(expectedKeys[key], code .. " has an unexpected key: " .. key) end
  end
  if not expectedKeys then expectedKeys = labels
  else
    for key in pairs(expectedKeys) do assert(labels[key], code .. " is missing: " .. key) end
  end
  assert(count == 96, code .. " translation count changed: " .. count)
end

print("runtime validation passed: all profiles and settings, manual cross-protocol telemetry, whole-number link quality, dropout-safe stats, one-time audio, hostile input handling, post-flight fitting, 1000 lifecycle cycles, 9 languages, 3 font sizes, 13 release sizes, 27 official radio targets, and layout boundaries")
