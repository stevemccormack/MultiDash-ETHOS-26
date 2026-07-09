local sourceKeys = {
  battery = "batterySource",
  link = "rssiSource",
  field1 = "field1Source",
  field2 = "field2Source",
  field3 = "field3Source",
  field4 = "field4Source",
  telemetry4 = "telemetry4Source",
  status = "statusSource",
  timer = "timerSource",
  inFlight1 = "inFlight1Source",
  inFlight2 = "inFlight2Source",
  inFlight3 = "inFlight3Source",
  inFlight4 = "inFlight4Source",
  current = "currentSource",
  rpm = "rpmSource",
}
local sourceOrder = {
  "battery", "link", "field1", "field2", "field3", "field4", "telemetry4", "status", "timer",
  "inFlight1", "inFlight2", "inFlight3", "inFlight4", "current", "rpm",
}
local thresholdKeys = {"batt", "fuel", "link", "current", "field1", "field2", "field3", "field4", "telemetry4"}
local thresholdSuffixes = {"High", "Mid", "Low", "Mode"}
local objectProps = {"label", "toString", "name", "stringValue", "id"}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function modelKey()
  local name = "default"
  if model and type(model.name) == "function" then
    local ok, value = pcall(model.name)
    if ok and value then name = value end
  end
  return (name or "default"):gsub("%W", "_")
end

local function modelPath(key)
  return "SCRIPTS:/MultiDash/models/" .. key .. ".cfg"
end

local function cleanKey(value)
  if value == nil then return nil end
  local text = tostring(value):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" or text == "---" then return "" end
  return text
end

local function prop(obj, name)
  local ok, value = pcall(function() return obj[name] end)
  if not ok then return nil end
  if type(value) == "function" then
    local fn = value
    ok, value = pcall(fn, obj)
    if not ok then ok, value = pcall(fn) end
  end
  return ok and value or nil
end

local function sourceSpec(obj)
  local kind = type(obj)
  if kind ~= "table" and kind ~= "userdata" then return nil end
  local category, member = prop(obj, "category"), prop(obj, "member")
  if category == nil or member == nil then return nil end
  return tostring(category) .. ":" .. tostring(member) .. ":" .. tostring(prop(obj, "options") or 0)
end

local function switchKey(text)
  text = cleanKey(text)
  local key = text and text:match("^([Ss][A-Za-z])%f[%W]")
  return key and key:upper() or nil
end

local function objectKey(obj, switchOnly)
  local kind = type(obj)
  if kind == "string" or kind == "number" then
    local key = cleanKey(obj) or ""
    return (switchOnly and switchKey(key)) or key
  end
  if not obj then return nil, false end
  local best, id, spec = nil, nil, sourceSpec(obj)
  if spec then return spec, false end
  for i = 1, #objectProps do
    local value = prop(obj, objectProps[i])
    local text = cleanKey(value)
    if text == "" then return "", false end
    if text and not tonumber(text) and (not best or #text > #best) then
      best = text
    elseif type(value) == "string" or type(value) == "number" then
      id = id or tostring(value)
    end
  end
  local text = tostring(obj)
  local fallback = text:match("S[A-Z]") or text:match("s[a-z]")
  local wait = not best and not id and not fallback
  best = best or fallback or id or ""
  return (switchOnly and switchKey(best)) or best, wait
end

local function readMap(path)
  local map, file = {}, io.open(path, "r")
  if not file then return map end
  while true do
    local ok, line = pcall(file.read, file, "*l")
    if not ok or not line then break end
    local name, value = line:match("^(%w+)=(.*)$")
    if name then map[name] = value end
  end
  pcall(file.close, file)
  return map
end

local function callResolver(fn, value)
  local ok, result = pcall(fn, value)
  return ok and result or nil
end

local function resolve(method, value)
  if not value or value == "" or not system or type(system[method]) ~= "function" then return nil end
  local fn = system[method]
  local text = tostring(value)
  if method == "getSource" then
    local category, member, options = text:match("^([^:]+):([^:]+):([^:]+)$")
    if category and member then
      local source = callResolver(fn, {
        category = tonumber(category) or category,
        member = tonumber(member) or member,
        options = tonumber(options) or options,
      })
      if source then return source end
    end
  end
  local base = text:match("S[A-Z]") or text:match("s[a-z]")
  local number = tonumber(text)
  return callResolver(fn, value) or callResolver(fn, text:upper()) or callResolver(fn, text:lower())
    or (number and callResolver(fn, number))
    or (base and (callResolver(fn, base:upper()) or callResolver(fn, base:lower())))
end

local function assignSource(w, key, value)
  w[key] = value and (resolve("getSource", value) or value) or nil
end

local function write(w, validLanguage)
  if not w then return true end
  local key = modelKey()
  local path = modelPath(key)
  local old = readMap(path)
  local savedSources, pending = {}, false
  for i = 1, #sourceOrder do
    local saved = sourceOrder[i]
    local keyName = sourceKeys[saved]
    local value, wait
    if w._sourceClears and w._sourceClears[keyName] then
      value, wait = "", false
    else
      value, wait = objectKey(w[keyName], false)
    end
    savedSources[saved] = value
    pending = pending or wait
  end
  local armValue, armWait
  local armSpec = sourceSpec(w.armSwitch)
  if w._armCleared then
    armValue, armWait = "", false
  elseif armSpec then
    armValue, armWait = armSpec, false
  elseif w.armSwitchKey then
    armValue, armWait = w.armSwitchKey, false
  else
    armValue, armWait = objectKey(w.armSwitch, true)
  end
  pending = pending or armWait
  if pending then return false end
  local file = io.open(path, "w")
  if not file then return false end
  local function put(...)
    if not file:write(...) then error("write failed") end
  end
  local ok = pcall(function()
    for i = 1, #sourceOrder do
      local saved = sourceOrder[i]
      put(saved, "=", savedSources[saved] or old[saved] or "", "\n")
    end
    put("arm=", armValue or old.arm or "", "\n")
    put("armDelay=", tostring(w.armDelay or 5), "\n")
    put("inFlightScreen=", tostring(w.inFlightScreen or 1), "\n")
    put("image=", w.imageFile or "", "\n")
    put("cells=", tostring(w.cellCount or 0), "\n")
    put("batteryType=", tostring(w.batteryType or 1), "\n")
    put("theme=", tostring(w.themeMode or 1), "\n")
    put("batteryStyle=", tostring(w.batteryStyle or 1), "\n")
    put("powerSourceType=", tostring(w.powerSourceType or 1), "\n")
    put("fuelShowPercent=", tostring(w.fuelShowPercent or 1), "\n")
    put("statusMode=", tostring(w.statusMode == 2 and 2 or 1), "\n")
    put("flightCount=", tostring(w.flightCount or 0), "\n")
    put("language=", validLanguage(w.language), "\n")
    for i = 1, #thresholdKeys do
      local key = thresholdKeys[i]
      for j = 1, #thresholdSuffixes do
        local suffix = thresholdSuffixes[j]
        local value = w[key .. suffix]
        if value ~= nil then put(key, suffix, "=", tostring(value), "\n") end
      end
    end
  end)
  pcall(file.close, file)
  return ok
end

local function normalize(w)
  if w.battHigh == 3.9 and w.battMid == 3.7 and w.battLow == 3.5 then
    w.battHigh, w.battMid, w.battLow = 4.15, 3.75, 3.45
  end
  w.battHigh = clamp(w.battHigh or 4.15, 0, 4.35)
  w.battMid = clamp(w.battMid or 3.75, 0, 4.35)
  w.battLow = clamp(w.battLow or 3.45, 0, 4.35)
  w.fuelHigh = clamp(w.fuelHigh or 40, 0, 100)
  w.fuelMid = clamp(w.fuelMid or 20, 0, 100)
  if (w.field4High or 0) == 0 and (w.field4Mid or 0) == 0 then
    w.field4High, w.field4Mid = 80, 30
  end
  w.telemetry4High = clamp(w.telemetry4High or w.field4High or 80, 0, 10000)
  w.telemetry4Mid = clamp(w.telemetry4Mid or w.field4Mid or 30, 0, 10000)
  w.telemetry4Mode = w.telemetry4Mode == 2 and 2 or 1
  w.statusMode = w.statusMode == 2 and 2 or 1
end

local function read(w, validLanguage)
  if not w then return true end
  local key = modelKey()
  local file = io.open(modelPath(key), "r")
  if file then
    while true do
      local ok, line = pcall(file.read, file, "*l")
      if not ok or not line then break end
      local name, value = line:match("^(%w+)=(.*)$")
      if name then
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
        if value == "" then value = nil end
        if sourceKeys[name] then
          assignSource(w, sourceKeys[name], value)
        elseif name == "arm" then
          w.armSwitchKey = value
          w.armSwitch = resolve("getSource", value) or resolve("getSwitch", value)
        elseif name == "image" then
          w.imageFile = value
        elseif name == "language" then
          w.language = validLanguage(value)
        else
          local n = tonumber(value)
          if n then
            if name == "armDelay" then w.armDelay = clamp(n, 0, 60)
            elseif name == "inFlightScreen" then w.inFlightScreen = n == 2 and 2 or 1
            elseif name == "cells" then w.cellCount = clamp(math.floor(n), 0, 12)
            elseif name == "batteryType" then w.batteryType = clamp(math.floor(n), 1, 5)
            elseif name == "theme" then w.themeMode = n == 2 and 2 or 1
            elseif name == "batteryStyle" then w.batteryStyle = n == 2 and 2 or 1
            elseif name == "powerSourceType" then w.powerSourceType = n == 2 and 2 or 1
            elseif name == "fuelShowPercent" then w.fuelShowPercent = n == 2 and 2 or 1
            elseif name == "statusMode" then w.statusMode = n == 2 and 2 or 1
            elseif name == "flightCount" then w.flightCount = clamp(math.floor(n), 0, 9999)
            elseif w[name] ~= nil then w[name] = n end
          end
        end
      end
    end
    pcall(file.close, file)
  end
  normalize(w)
  w.selectedBmp, w.selectedFile, w.iconBmp, w.iconLoaded = nil, nil, nil, false
  return true
end

return {read = read, write = write}
