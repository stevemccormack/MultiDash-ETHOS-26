FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4

local now = 0
local armed = false
local function noop() end
os.clock = function() return now end
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  getWindowSize = function() return 784, 316 end,
  getTextSize = function(text) return #tostring(text) * 8, 18 end,
  loadBitmap = function() return {} end,
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
model = {name = function() return "Flight Count Test" end}
form = {}

local function source(label, value)
  return {
    name = function() return label end,
    value = function() return value end,
  }
end

local entry = assert(loadfile("main.lua"))()
entry.init()
local widget = registered.create()
widget.armSwitchKey = "SA"
widget.armSwitch = {active = function() return armed end}
widget.armDelay = 0
widget.batterySource = source("RxBatt", 12.3)
widget.cellCount = 3
widget.field4Source = source("Battery percentage", 88)
widget.telemetry4Source = source("VFR 2.4G", 96)

armed = true
registered.wakeup(widget)
now = 14
registered.wakeup(widget)
armed = false
now = 14.2
registered.wakeup(widget)
assert(widget.flightCount == 0, "short flight was counted")

now = 20
armed = true
registered.wakeup(widget)
now = 36
registered.wakeup(widget)
armed = false
now = 36.2
registered.wakeup(widget)
assert(widget.flightCount == 1, "valid flight was not counted")
assert(widget.dirty, "flight count was not queued for persistence")
assert(widget.stats and widget.stats.field4, "battery percentage was not captured")
assert(widget.stats and widget.stats.telemetry4, "telemetry 4 was not captured")
assert(widget.stats.telemetry4.label == "VFR 2.4G", "telemetry 4 label was not kept")

print("MultiDash flight count smoke test OK")
