FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4

local draws = {}
local screenW, screenH = 784, 316
local function noop() end
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  getWindowSize = function() return screenW, screenH end,
  getTextSize = function(text) return #tostring(text) * 8, 18 end,
  loadBitmap = function() return {} end,
  drawText = function(x, y, text)
    draws[#draws + 1] = {x = x, y = y, text = tostring(text)}
  end,
  drawFilledCircle = noop,
  drawCircle = noop,
  drawAnnulusSector = noop,
  invalidate = noop,
}, {__index = function() return noop end})

local registered
system = {
  registerWidget = function(widget) registered = widget end,
  getSource = function() return nil end,
  getSwitch = function() return nil end,
}
model = {name = function() return "Layout Test" end}
form = {
  addLine = function() return {} end,
  addFileField = noop,
  addNumberField = function() return {decimals = noop} end,
  addChoiceField = noop,
  addSelectField = noop,
  addSourceField = noop,
}

local function source(label, value)
  return {
    name = function() return label end,
    value = function() return value end,
  }
end

local entry = assert(loadfile("main.lua"))()
entry.init()
local widget = registered.create()
widget.batterySource = source("RxBatt", 52.2)
widget.currentSource = source("Current", 123.4)
widget.field4Source = source("Battery percentage", 88)
widget.field1Source = source("Frame losses", 7)
widget.field2Source = source("Fades", 8)
widget.field3Source = source("Holds", 9)
widget.telemetry4Source = source("Telemetry four", 10)
widget.flightCount = 12
widget.cellCount = 12
widget.flightActive = true
registered.paint(widget)

local voltage, current, percent, timer
for i = 1, #draws do
  local item = draws[i]
  if item.text == "52.20V" then voltage = item end
  if item.text:find("123.4A", 1, true) then current = item end
  if item.text == "88%" then percent = item end
  if item.text == "00:00" then timer = item end
end

assert(voltage and voltage.x < 80, "voltage is not left aligned")
assert(current and current.x > 400, "current is not right aligned")
assert(percent and percent.x >= voltage.x + #"52.20V" * 8 + 35,
  "in-flight percentage was not shifted right")
assert(math.abs(percent.y - voltage.y) <= 5, "in-flight percentage is not aligned with voltage")
assert(timer and voltage.x + 6 * 8 < timer.x, "voltage overlaps timer")

draws = {}
widget.field4Source = nil
registered.paint(widget)
local calculatedPercent
for i = 1, #draws do
  if draws[i].text == "100%" then calculatedPercent = draws[i] end
end
assert(calculatedPercent, "in-flight percentage was not calculated from voltage")
draws = {}
widget.batterySource = nil
registered.paint(widget)
local fallbackPercent
for i = 1, #draws do
  if draws[i].text == "0%" then fallbackPercent = draws[i] end
end
assert(fallbackPercent, "in-flight percentage disappeared without voltage")
widget.batterySource = source("RxBatt", 52.2)
widget.field4Source = source("Battery percentage", 88)

draws = {}
widget.flightActive = false
widget.postFlight = false
registered.paint(widget)

local mainVoltage, mainCurrent, mainPercent, mainField1, mainField2, mainField3, mainField4
local mainCurrentDraws = 0
for i = 1, #draws do
  local item = draws[i]
  if item.text == "52.20V" then mainVoltage = item end
  if item.text:find("123.4A", 1, true) then
    mainCurrent = item
    mainCurrentDraws = mainCurrentDraws + 1
  end
  if item.text == "88%" then mainPercent = item end
  if item.text:find("Frame losses", 1, true) then mainField1 = item end
  if item.text:find("Fades", 1, true) then mainField2 = item end
  if item.text:find("Holds", 1, true) then mainField3 = item end
  if item.text:find("Telemetry four", 1, true) then mainField4 = item end
end

assert(mainVoltage and mainPercent, "main battery voltage or percentage missing")
assert(mainPercent.y >= mainVoltage.y + 25, "main percentage was not shifted down")
assert(math.abs(mainPercent.x - mainVoltage.x) < 40, "main percentage is not centered below voltage")
assert(mainPercent.x < 600, "percentage still appears in the lower-right telemetry list")
assert(mainCurrent and mainCurrent.x > 500, "main current is not in the right telemetry list")
assert(mainField1 and mainCurrent.y < mainField1.y, "main current is not above telemetry fields")
assert(mainCurrent.y < 215, "main current was not moved up a full line")
assert(mainCurrentDraws == 2, "main current is not bold")
assert(mainField2 and mainField3 and mainField4, "main screen does not show four telemetry fields")
assert(mainField1.y < mainField2.y and mainField2.y < mainField3.y and mainField3.y < mainField4.y,
  "main telemetry fields are not ordered")

draws = {}
widget.batteryStyle = 2
registered.paint(widget)

local dialVoltage, dialPercent
for i = 1, #draws do
  local item = draws[i]
  if item.text == "52.20V" then dialVoltage = item end
  if item.text == "88%" then dialPercent = item end
end

assert(dialVoltage and dialPercent, "dial voltage or percentage missing")
assert(dialPercent.y >= dialVoltage.y + 25, "dial percentage was not shifted down")
assert(math.abs(dialPercent.x - dialVoltage.x) < 40, "dial percentage is not centered below voltage")

for _, size in ipairs({{480, 272}, {784, 316}, {800, 480}, {1280, 720}}) do
  screenW, screenH = size[1], size[2]
  for _, mode in ipairs({"flight", "tower", "dial"}) do
    draws = {}
    widget.flightActive = mode == "flight"
    widget.postFlight = false
    widget.batteryStyle = mode == "dial" and 2 or 1
    registered.paint(widget)
    local foundVoltage, foundPercent, foundCurrent, foundField1, foundField4
    for i = 1, #draws do
      local item = draws[i]
      if item.text == "52.20V" then foundVoltage = item end
      if item.text == "88%" then foundPercent = item end
      if item.text:find("123.4A", 1, true) then foundCurrent = item end
      if item.text:find("Frame losses", 1, true) then foundField1 = item end
      if item.text:find("Telemetry four", 1, true) then foundField4 = item end
      assert(item.x >= -5 and item.x < screenW, mode .. " text clips horizontally")
      assert(item.y >= -10 and item.y < screenH, mode .. " text clips vertically")
    end
    assert(foundVoltage and foundPercent, mode .. " battery text missing")
    if mode == "flight" then
      assert(foundPercent.x >= foundVoltage.x + #"52.20V" * 8 + 35,
        "flight percentage was not shifted right")
      assert(math.abs(foundPercent.y - foundVoltage.y) <= 5,
        "flight percentage is not aligned with voltage")
    else
      assert(foundPercent.y >= foundVoltage.y + 25, mode .. " percentage was not shifted down")
      assert(math.abs(foundPercent.x - foundVoltage.x) < 40,
        mode .. " percentage is not centered below voltage")
    end
    if mode ~= "flight" then
      assert(foundCurrent and foundField1 and foundField4, mode .. " right-side telemetry is missing")
      assert(foundCurrent.y < foundField1.y, mode .. " current is not above telemetry fields")
      assert(foundField4.y > foundField1.y, mode .. " telemetry 4 is not below telemetry 1")
    end
  end
end
print("MultiDash battery layout smoke test OK")
