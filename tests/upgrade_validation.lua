local files = {}
io.open = function(path, mode)
  if mode == "w" then files[path] = "" end
  if mode == "r" and files[path] == nil then return nil end
  local position = 1
  return {
    write = function(_, ...)
      for i = 1, select("#", ...) do files[path] = files[path] .. tostring(select(i, ...)) end
      return true
    end,
    read = function()
      local text = files[path]
      if position > #text then return nil end
      local ending = text:find("\n", position, true)
      local line = text:sub(position, ending and ending - 1 or #text)
      position = ending and ending + 1 or #text + 1
      return line
    end,
    close = function() return true end,
  }
end

system = {
  getSource = function(value) return {key = value, label = tostring(value)} end,
  getSwitch = function(value) return {key = value, label = tostring(value)} end,
}
model = {name = function() return "91 NG" end}

local old = {
  batterySource = 25.2, rssiSource = 99, field1Source = 101, field2Source = 102,
  field3Source = 103, field4Source = 80, telemetry4Source = 104, statusSource = 1,
  timerSource = 120, inFlight1Source = 201, inFlight2Source = 202,
  inFlight3Source = 203, inFlight4Source = 204, currentSource = 45, rpmSource = 7200,
  armSwitch = "SA", armDelay = 7, inFlightScreen = 2,
  imageFile = "BITMAPS:/models/91ng.png", cellCount = 6, batteryType = 2,
  themeMode = 2, batteryStyle = 2, powerSourceType = 1, fuelShowPercent = 2,
  statusMode = 2, flightCount = 42, language = "de",
  battHigh = 4.2, battMid = 3.8, battLow = 3.5,
  linkHigh = 97, linkMid = 75, currentHigh = 70, currentMid = 40,
  fuelHigh = 50, fuelMid = 25,
  field1High = 100, field1Mid = 50, field1Mode = 1,
  field2High = 200, field2Mid = 100, field2Mode = 2,
  field3High = 300, field3Mid = 150, field3Mode = 2,
  field4High = 85, field4Mid = 35,
  telemetry4High = 400, telemetry4Mid = 200, telemetry4Mode = 1,
}
local fixture = {}
local function line(name, value) fixture[#fixture + 1] = name .. "=" .. tostring(value or "") .. "\n" end
for _, item in ipairs({
  {"battery", "batterySource"}, {"link", "rssiSource"}, {"field1", "field1Source"},
  {"field2", "field2Source"}, {"field3", "field3Source"}, {"field4", "field4Source"},
  {"telemetry4", "telemetry4Source"}, {"status", "statusSource"}, {"timer", "timerSource"},
  {"inFlight1", "inFlight1Source"}, {"inFlight2", "inFlight2Source"},
  {"inFlight3", "inFlight3Source"}, {"inFlight4", "inFlight4Source"},
  {"current", "currentSource"}, {"rpm", "rpmSource"},
}) do line(item[1], old[item[2]]) end
line("arm", old.armSwitch); line("armDelay", old.armDelay); line("inFlightScreen", old.inFlightScreen)
line("image", old.imageFile); line("cells", old.cellCount); line("batteryType", old.batteryType)
line("theme", old.themeMode); line("batteryStyle", old.batteryStyle)
line("powerSourceType", old.powerSourceType); line("fuelShowPercent", old.fuelShowPercent)
line("statusMode", old.statusMode); line("audioEnabled", 2)
line("flightCount", old.flightCount); line("language", old.language)
for _, prefix in ipairs({"batt", "fuel", "link", "current", "field1", "field2", "field3", "field4", "telemetry4"}) do
  for _, suffix in ipairs({"High", "Mid", "Low", "Mode"}) do
    local value = old[prefix .. suffix]
    if value ~= nil then line(prefix .. suffix, value) end
  end
end
files["SCRIPTS:/MultiDash/models/91_NG.cfg"] = table.concat(fixture)
assert(files["SCRIPTS:/MultiDash/models/91_NG.cfg"])

local v2 = assert(loadfile("storage.lua"))()
local upgraded = {
  fontSize = 2, batteryMode = 1, rotorwingMode = 1, rpmMax = 8000,
  battHigh = 4.15, battMid = 3.75, battLow = 3.45,
  linkHigh = 98, linkMid = 80, currentHigh = 60, currentMid = 35,
  fuelHigh = 40, fuelMid = 20,
  field1High = 0, field1Mid = 0, field1Mode = 1,
  field2High = 0, field2Mid = 0, field2Mode = 2,
  field3High = 0, field3Mid = 0, field3Mode = 2,
  field4High = 80, field4Mid = 30,
  telemetry4High = 80, telemetry4Mid = 30, telemetry4Mode = 1,
}
assert(v2.read(upgraded, function(code) return code end))
for _, key in ipairs({
  "batterySource", "rssiSource", "field1Source", "field2Source", "field3Source",
  "field4Source", "telemetry4Source", "statusSource", "timerSource",
  "inFlight1Source", "inFlight2Source", "inFlight3Source", "inFlight4Source",
  "currentSource", "rpmSource",
}) do
  assert(upgraded[key] and tostring(upgraded[key].key) == tostring(old[key]), key)
end
for _, key in ipairs({
  "armDelay", "inFlightScreen", "imageFile", "cellCount", "batteryType", "themeMode",
  "batteryStyle", "powerSourceType", "fuelShowPercent", "statusMode", "flightCount",
  "language", "battHigh", "battMid", "battLow", "linkHigh", "linkMid",
  "currentHigh", "currentMid", "fuelHigh", "fuelMid", "field1High", "field1Mid",
  "field1Mode", "field2High", "field2Mid", "field2Mode", "field3High", "field3Mid",
  "field3Mode", "field4High", "field4Mid", "telemetry4High", "telemetry4Mid",
  "telemetry4Mode",
}) do
  assert(upgraded[key] == old[key], key)
end
assert(upgraded.armSwitch and upgraded.armSwitch.key == "SA")
assert(upgraded.battery2Source == nil)
assert(upgraded.fontSize == 2 and upgraded.batteryMode == 1)
assert(upgraded.rotorwingMode == 1 and upgraded.rpmMax == 8000)
assert(upgraded.powerProfile == 1 and upgraded.schemaVersion == 2)
assert(upgraded.flightMinSeconds == 15 and upgraded.rpmWarn == 6400)
assert(upgraded.packWarn == 0.10 and upgraded.packBad == 0.20 and upgraded.audioEnabled == nil)
assert(v2.write(upgraded, function(code) return code end))
local migrated
for path in pairs(files) do
  if path ~= "SCRIPTS:/MultiDash/models/91_NG.cfg" then migrated = path end
end
assert(migrated and migrated:match("^SCRIPTS:/MultiDash/models/91_NG_[0-9a-f]+%.cfg$"))
assert(not files[migrated]:find("audioEnabled=", 1, true), "obsolete audio setting was retained")

for _, case in ipairs({
  {"Legacy Fuel", "powerSourceType=2\n", 4},
  {"RC1 Dual", "batteryMode=2\n", 2},
  {"RC1 Rotor", "rotorwingMode=2\n", 3},
}) do
  model.name = function() return case[1] end
  local legacyKey = case[1]:gsub("%W", "_")
  files["SCRIPTS:/MultiDash/models/" .. legacyKey .. ".cfg"] = case[2]
  local candidate = {
    battHigh = 4.15, battMid = 3.75, battLow = 3.45,
    fuelHigh = 40, fuelMid = 20, linkHigh = 98, linkMid = 80,
    currentHigh = 60, currentMid = 35, field1High = 0, field1Mid = 0,
    field2High = 0, field2Mid = 0, field3High = 0, field3Mid = 0,
    field4High = 80, field4Mid = 30, telemetry4High = 80, telemetry4Mid = 30,
  }
  assert(v2.read(candidate, function(code) return code end))
  assert(candidate.powerProfile == case[3], case[1] .. " profile migration")
end

print("V1.3.3 and RC1 migration passed: settings retained, legacy power modes mapped, and new features use safe defaults")
