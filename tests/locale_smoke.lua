FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4

local codes = {"en", "de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw"}
local expectedCodes = table.concat(codes, ",")
local critical = {
  "NO TELEMETRY", "ARMED", "Batt", "Curr", "Link", "Dash Fuel",
  "Stat 1", "Stat 2", "Stat 3", "Stat 4",
}

local english = assert(loadfile("lang/en.lua"))()
local keyCount = 0
for _ in pairs(english) do keyCount = keyCount + 1 end
assert(keyCount == 69, "unexpected English key count")

for _, code in ipairs(codes) do
  local labels = assert(loadfile("lang/" .. code .. ".lua"))()
  local count = 0
  for key in pairs(english) do
    count = count + 1
    assert(type(labels[key]) == "string" and labels[key] ~= "",
      code .. " is missing " .. key)
  end
  assert(count == keyCount, code .. " key count differs")
  for _, key in ipairs(critical) do
    assert(not labels[key]:find("[^\x20-\x7E]"),
      code .. " dashboard label is not radio-safe: " .. key)
  end
end

local i18n = assert(loadfile("i18n.lua"))()
assert(table.concat(i18n.codes, ",") == expectedCodes, "language list differs")

local draws = {}
local function noop() end
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  getWindowSize = function() return 784, 316 end,
  getTextSize = function(text) return #tostring(text) * 8, 18 end,
  loadBitmap = function() return {} end,
  drawText = function(_, _, text) draws[tostring(text)] = true end,
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
model = {name = function() return "Locale Test" end}
form = {}
os.clock = function() return 1 end

local entry = assert(loadfile("main.lua"))()
entry.init()

for _, code in ipairs(codes) do
  draws = {}
  local labels = assert(loadfile("lang/" .. code .. ".lua"))()
  local widget = registered.create()
  widget.language = code
  widget.batterySource = {value = function() return 0 end}
  widget.armSwitchKey = "SA"
  widget.armSwitch = {active = function() return true end}
  widget.armSeenAt = 1
  widget.armDelay = 999
  registered.paint(widget)
  assert(draws[labels["NO TELEMETRY"]], code .. " telemetry alert did not render")
  assert(draws[labels["ARMED"]], code .. " armed alert did not render")
  registered.close(widget)
end

print("MultiDash locale smoke test OK")
