FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4

local prompt = "Use Single Large Widget"
local draws = {}
local function noop() end
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  getWindowSize = function() return 320, 160 end,
  getTextSize = function(text) return #tostring(text) * 8, 18 end,
  drawText = function(_, _, text) draws[tostring(text)] = true end,
  invalidate = noop,
}, {__index = function() return noop end})

local registered
system = {
  registerWidget = function(widget) registered = widget end,
  getSource = function() return nil end,
  getSwitch = function() return nil end,
}
model = {name = function() return "Size Test" end}

local entry = assert(loadfile("main.lua"))()
entry.init()
local widget = registered.create()
registered.paint(widget)
assert(draws[prompt], "tiny widget did not show size prompt")

draws = {}
registered.paint(widget, {w = 320, h = 160})
assert(draws[prompt], "zone table size did not show size prompt")

draws = {}
registered.paint(widget, 0, 0, 320, 160)
assert(draws[prompt], "x/y/w/h size did not show size prompt")

for _, size in ipairs({{472, 191}, {472, 210}, {630, 236}, {630, 258}, {784, 294}, {784, 316}}) do
  draws = {}
  lcd.getWindowSize = function() return size[1], size[2] end
  registered.paint(widget)
  assert(not draws[prompt], "single-large widget size was blocked")
end

for _, size in ipairs({{420, 220}, {700, 180}, {360, 260}, {480, 272}, {480, 320}, {640, 360}, {800, 480}}) do
  draws = {}
  lcd.getWindowSize = function() return size[1], size[2] end
  registered.paint(widget)
  assert(draws[prompt], "non-single-large widget did not show size prompt")
end

draws = {}
lcd.getWindowSize = function() return 784, 316 end
registered.paint(widget)
assert(not draws[prompt], "single-large widget was blocked")

draws = {}
lcd.getWindowSize = function() return 0, 56, 472, 210 end
registered.paint(widget)
assert(not draws[prompt], "four-return ETHOS window geometry was misread")

draws = {}
registered.paint(widget, 0, 56, 472, 210)
assert(not draws[prompt], "paint x/y/w/h geometry was misread")

print("MultiDash widget size smoke test OK")
