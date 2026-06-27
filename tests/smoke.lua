FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4

local function noop() end
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  getWindowSize = function() return 784, 316 end,
  getTextSize = function(text) return #tostring(text) * 8, 18 end,
  loadBitmap = function() return {} end,
  drawFilledCircle = noop,
  drawCircle = noop,
  invalidate = noop,
}, {__index = function() return noop end})

local registered
system = {
  registerWidget = function(widget) registered = widget end,
  getSource = function() return nil end,
  getSwitch = function() return nil end,
}
model = {name = function() return "Smoke Test" end}

local field = {decimals = noop}
local languageChoices
local formLines = {}
local sourceLines = {}
form = {
  addLine = function(label)
    formLines[#formLines + 1] = label
    return {label = label}
  end,
  addFileField = noop,
  addNumberField = function() return field end,
  addChoiceField = function(_, _, choices)
    if type(choices) == "table" and #choices == 9 then languageChoices = choices end
  end,
  addSelectField = noop,
  addSourceField = function(line)
    sourceLines[#sourceLines + 1] = line and line.label
  end,
}

local entry = assert(loadfile("main.lua"))()
entry.init()
assert(registered and registered.key == "mdash")

local widget = registered.create()
assert(type(widget) == "table")
registered.configure(widget)
assert(languageChoices and #languageChoices == 9)
for i = 1, #languageChoices do
  local value = languageChoices[i]
  local label = type(value) == "table" and value[1] or value
  assert(type(label) == "string" and label ~= "" and not label:find("[^\x20-\x7E]"))
end
local lineIndex = {}
for i = 1, #formLines do
  if lineIndex[formLines[i]] == nil then lineIndex[formLines[i]] = i end
end
assert(lineIndex["Power / Battery / Fuel"] < lineIndex["Current"])
assert(lineIndex["Current"] < lineIndex["Link"])
assert(lineIndex["Battery percentage"] == nil)
local sourceIndex = {}
for i = 1, #sourceLines do
  if sourceIndex[sourceLines[i]] == nil then sourceIndex[sourceLines[i]] = i end
end
assert(sourceIndex["Power source"] < sourceIndex["Battery/Fuel percentage"])
assert(sourceIndex["Battery/Fuel percentage"] < sourceIndex["Current"])
assert(sourceIndex["Current"] < sourceIndex["Link quality"])
assert(sourceIndex["RPM"] < sourceIndex["Telemetry 1"])
assert(sourceIndex["Telemetry 3"] < sourceIndex["Telemetry 4"])
assert(sourceIndex["Timer"] == nil)
assert(lineIndex["Flights"] < lineIndex["Power / Battery / Fuel"])
assert(lineIndex["Battery/Fuel percentage scoring"] == nil)
assert(widget.field4Mode == nil)
assert(lineIndex["Telemetry 4 scoring"] ~= nil)
assert(widget.telemetry4Mode == 1)
assert(widget.flightCount == 0)

registered.paint(widget)
widget.flightActive = true
registered.paint(widget)

widget.flightActive = false
widget.postFlight = true
widget.flightTime = 125
widget.stats = {link = {label = "RSSI", min = 87, max = 100}}
widget.statOrder = {"link"}
registered.paint(widget)

for _, code in ipairs({
  "en", "de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw",
}) do
  widget.language = code
  widget.postFlight = false
  registered.paint(widget)
end

registered.wakeup(widget)
registered.close(widget)
print("MultiDash modular smoke test OK")
