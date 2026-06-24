FONT_S, FONT_L, FONT_XL, FONT_XXL = 1, 2, 3, 4

local function noop() end
lcd = setmetatable({
  RGB = function(r, g, b) return r * 65536 + g * 256 + b end,
  getWindowSize = function() return 784, 316 end,
  getTextSize = function(text) return #tostring(text) * 8, 18 end,
}, {__index = function() return noop end})

local files = {}
local openedPath
io.open = function(path, mode)
  openedPath = path
  if mode == "w" then
    local parts = {}
    return {
      write = function(_, ...) for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end end,
      close = function() files[path] = table.concat(parts) end,
    }
  end
  local text = files[path]
  if not text then return nil end
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
  local index = 0
  return {
    read = function()
      index = index + 1
      return lines[index]
    end,
    close = noop,
  }
end

local function source(name)
  return {name = function() return name end, value = function() return 0 end}
end

local registered
system = {
  registerWidget = function(widget) registered = widget end,
  getSource = function(name) return source(name) end,
  getSwitch = function(name) return source(name) end,
}
model = {name = function() return "Storage/Test" end}
form = {}

local entry = assert(loadfile("main.lua"))()
entry.init()
local original = registered.create()
original.batterySource = source("RxBatt")
original.currentSource = source("ESC current")
original.telemetry4Source = source("VFR")
original.armSwitchKey = "SA"
original.armDelay = 7
original.cellCount = 12
original.batteryType = 2
original.battHigh = 4.35
original.flightCount = 27
original.language = "fr"
assert(registered.write(original))
assert(openedPath == "SCRIPTS:/MultiDash/models/Storage_Test.cfg")
assert(files[openedPath]:find("battery=RxBatt", 1, true))
assert(files[openedPath]:find("current=ESC current", 1, true))
assert(files[openedPath]:find("telemetry4=VFR", 1, true))
assert(files[openedPath]:find("flightCount=27", 1, true))

local restored = registered.create()
assert(registered.read(restored))
assert(restored.batterySource:name() == "RxBatt")
assert(restored.currentSource:name() == "ESC current")
assert(restored.telemetry4Source:name() == "VFR")
assert(restored.armSwitchKey == "SA")
assert(restored.armDelay == 7)
assert(restored.cellCount == 12)
assert(restored.batteryType == 2)
assert(restored.battHigh == 4.35)
assert(restored.flightCount == 27)
assert(restored.language == "fr")

print("MultiDash storage smoke test OK")
