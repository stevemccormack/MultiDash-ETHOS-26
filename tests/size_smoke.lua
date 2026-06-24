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

for _, size in ipairs({{480, 272}, {800, 480}, {1280, 720}}) do
  draws = {}
  lcd.getWindowSize = function() return size[1], size[2] end
  registered.paint(widget)
  assert(draws[prompt], "non single-large size did not show prompt")
end

draws = {}
lcd.getWindowSize = function() return 784, 316 end
registered.paint(widget)
assert(not draws[prompt], "single-large widget was blocked")

print("MultiDash widget size smoke test OK")
