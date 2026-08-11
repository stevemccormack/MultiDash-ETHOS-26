local SCHEMA_VERSION = 2
local sourceKeys = {
  battery = "batterySource", battery2 = "battery2Source", totalBattery = "totalBatterySource",
  link = "rssiSource",
  field1 = "field1Source", field2 = "field2Source", field3 = "field3Source",
  field4 = "field4Source", telemetry4 = "telemetry4Source", status = "statusSource",
  timer = "timerSource", inFlight1 = "inFlight1Source", inFlight2 = "inFlight2Source",
  inFlight3 = "inFlight3Source", inFlight4 = "inFlight4Source",
  current = "currentSource", rpm = "rpmSource",
}
local sourceOrder = {
  "battery", "battery2", "totalBattery", "link", "field1", "field2", "field3", "field4", "telemetry4",
  "status", "timer", "inFlight1", "inFlight2", "inFlight3", "inFlight4", "current", "rpm",
}
local thresholdKeys = {
  "batt", "fuel", "link", "current",
  "field1", "field2", "field3", "field4", "telemetry4",
}
local thresholdSuffixes = {"High", "Mid", "Low", "Mode"}
local objectProps = {"label", "toString", "name", "stringValue", "id"}

local function finiteNumber(v)
  v = tonumber(v)
  return v and v == v and v ~= math.huge and v ~= -math.huge and v or nil
end

local function clamp(v, lo, hi)
  v = finiteNumber(v) or 0
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function wholeNumber(v)
  return v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
end

local function modelName()
  local name = "default"
  if model and type(model.name) == "function" then
    local ok, value = pcall(model.name)
    if ok and value then name = value end
  end
  return tostring(name or "default")
end

local function legacyModelKey(name) return name:gsub("%W", "_") end

local function modelKey(name)
  local stem = name:gsub("%W", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if stem == "" then stem = "model" end
  local hash = 5381
  for i = 1, #name do hash = (hash * 33 + name:byte(i)) % 16777213 end
  return stem:sub(1, 36) .. "_" .. string.format("%06x", hash)
end

local function modelPath(key) return "SCRIPTS:/MultiDash/models/" .. key .. ".cfg" end

local function savedPaths(w)
  local name = w and w._modelName
  if not name then
    name = modelName()
    if w then w._modelName = name end
  end
  return modelPath(modelKey(name)), modelPath(legacyModelKey(name))
end

local function cleanKey(value)
  if value == nil then return nil end
  local text = tostring(value):gsub("[\r\n]", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" or text == "---" then return "" end
  return text
end

local function member(obj, name) return obj[name] end

local function prop(obj, name)
  local ok, value = pcall(member, obj, name)
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
  local category, id = prop(obj, "category"), prop(obj, "member")
  if category == nil or id == nil then return nil end
  return tostring(category) .. ":" .. tostring(id) .. ":" .. tostring(prop(obj, "options") or 0)
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
    return (switchOnly and switchKey(key)) or key, false
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
  for _ = 1, 128 do
    local ok, line = pcall(file.read, file, "*l")
    if not ok or not line then break end
    local name, value = line:match("^(%w+)=(.*)$")
    if name then map[name] = value:gsub("^%s+", ""):gsub("%s+$", "") end
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
  local fn, text = system[method], tostring(value)
  if method == "getSource" then
    local category, id, options = text:match("^([^:]+):([^:]+):([^:]+)$")
    if category and id then
      local source = callResolver(fn, {
        category = tonumber(category) or category,
        member = tonumber(id) or id,
        options = tonumber(options) or options,
      })
      if source then return source end
    end
  end
  local base, number = text:match("S[A-Z]") or text:match("s[a-z]"), tonumber(text)
  return callResolver(fn, value) or callResolver(fn, text:upper()) or callResolver(fn, text:lower())
    or (number and callResolver(fn, number))
    or (base and (callResolver(fn, base:upper()) or callResolver(fn, base:lower())))
end

local function assignSource(w, key, value)
  w[key] = value and value ~= "" and (resolve("getSource", value) or value) or nil
end

local function profileFlags(w)
  local profile = clamp(math.floor(finiteNumber(w.powerProfile) or 1), 1, 5)
  w.powerProfile = profile
  w.powerSourceType = profile == 4 and 2 or 1
  w.batteryMode = profile == 2 and 2 or 1
  w.rotorwingMode = profile == 3 and 2 or 1
end

local function deriveProfile(w)
  if w.powerSourceType == 2 then return 4 end
  if w.batteryMode == 2 then return 2 end
  if w.rotorwingMode == 2 then return 3 end
  return 1
end

local function orderPair(w, prefix, max, min)
  min = min or 0
  local high = clamp(w[prefix .. "High"] or 0, min, max)
  local mid = clamp(w[prefix .. "Mid"] or 0, min, max)
  if high < mid then high, mid = mid, high end
  w[prefix .. "High"], w[prefix .. "Mid"] = high, mid
end

local function normalize(w, schema)
  if schema < 2 and w.battHigh == 3.9 and w.battMid == 3.7 and w.battLow == 3.5 then
    w.battHigh, w.battMid, w.battLow = 4.15, 3.75, 3.45
  end
  if schema < 2 and (w.batteryType or 1) ~= 1
      and w.battHigh == 4.15 and w.battMid == 3.75 and w.battLow == 3.45 then
    local presets = {
      {4.15, 3.75, 3.45}, {4.25, 3.85, 3.50}, {4.10, 3.60, 3.20},
      {3.40, 3.25, 3.10}, {1.35, 1.15, 1.00},
    }
    local preset = presets[clamp(math.floor(finiteNumber(w.batteryType) or 1), 1, #presets)]
    w.battHigh, w.battMid, w.battLow = preset[1], preset[2], preset[3]
  end
  w.battHigh = clamp(w.battHigh or 4.15, 0, 4.35)
  w.battMid = clamp(w.battMid or 3.75, 0, 4.35)
  w.battLow = clamp(w.battLow or 3.45, 0, 4.35)
  if w.battHigh < w.battMid then w.battHigh, w.battMid = w.battMid, w.battHigh end
  if w.battMid < w.battLow then w.battMid, w.battLow = w.battLow, w.battMid end
  orderPair(w, "fuel", 100)
  orderPair(w, "link", 50000, -200)
  w.linkHigh, w.linkMid = wholeNumber(w.linkHigh), wholeNumber(w.linkMid)
  for _, prefix in ipairs({"current", "field1", "field2", "field3", "field4", "telemetry4"}) do
    orderPair(w, prefix, 50000)
  end
  for _, prefix in ipairs({"fuel", "link", "field1", "field2", "field3", "field4", "telemetry4"}) do
    if w[prefix .. "Mode"] ~= nil then w[prefix .. "Mode"] = w[prefix .. "Mode"] == 2 and 2 or 1 end
  end
  w.armDelay = clamp(w.armDelay or 5, 0, 60)
  w.inFlightScreen = w.inFlightScreen == 2 and 2 or 1
  w.cellCount = clamp(math.floor(finiteNumber(w.cellCount) or 0), 0, 12)
  w.batteryType = clamp(math.floor(finiteNumber(w.batteryType) or 1), 1, 5)
  w.themeMode = w.themeMode == 2 and 2 or 1
  w.fontSize = clamp(math.floor(finiteNumber(w.fontSize) or 2), 1, 3)
  w.batteryStyle = w.batteryStyle == 2 and 2 or 1
  w.rpmMax = clamp(math.floor(finiteNumber(w.rpmMax) or 8000), 1000, 50000)
  w.rpmWarn = clamp(math.floor(finiteNumber(w.rpmWarn) or math.floor(w.rpmMax * 0.8)), 0, w.rpmMax)
  w.flightMinSeconds = clamp(math.floor(finiteNumber(w.flightMinSeconds) or 15), 0, 300)
  w.packWarn = clamp(w.packWarn or 0.10, 0, 1)
  w.packBad = clamp(w.packBad or 0.20, 0, 1)
  if w.packBad < w.packWarn then w.packBad, w.packWarn = w.packWarn, w.packBad end
  w.statusMode = w.statusMode == 2 and 2 or 1
  w.fuelShowPercent = w.fuelShowPercent == 2 and 2 or 1
  w.flightCount = clamp(math.floor(finiteNumber(w.flightCount) or 0), 0, 9999)
  w.schemaVersion = SCHEMA_VERSION
  profileFlags(w)
end

local function writeFile(path, w, old, savedSources, armValue, validLanguage)
  local file = io.open(path, "w")
  if not file then return false end
  local function put(...)
    if not file:write(...) then error("write failed") end
  end
  local ok = pcall(function()
    put("schema=", tostring(SCHEMA_VERSION), "\n")
    for i = 1, #sourceOrder do
      local saved = sourceOrder[i]
      put(saved, "=", savedSources[saved] or old[saved] or "", "\n")
    end
    put("arm=", armValue or old.arm or "", "\n")
    put("armDelay=", tostring(w.armDelay or 5), "\n")
    put("flightMinSeconds=", tostring(w.flightMinSeconds or 15), "\n")
    put("inFlightScreen=", tostring(w.inFlightScreen or 1), "\n")
    put("image=", cleanKey(w.imageFile) or "", "\n")
    put("cells=", tostring(w.cellCount or 0), "\n")
    put("batteryType=", tostring(w.batteryType or 1), "\n")
    put("theme=", tostring(w.themeMode or 1), "\n")
    put("fontSize=", tostring(w.fontSize or 2), "\n")
    put("batteryStyle=", tostring(w.batteryStyle or 1), "\n")
    put("profile=", tostring(w.powerProfile or 1), "\n")
    put("powerSourceType=", tostring(w.powerSourceType or 1), "\n")
    put("batteryMode=", tostring(w.batteryMode or 1), "\n")
    put("rotorwingMode=", tostring(w.rotorwingMode or 1), "\n")
    put("rpmMax=", tostring(w.rpmMax or 8000), "\n")
    put("rpmWarn=", tostring(w.rpmWarn or 6400), "\n")
    put("packWarn=", tostring(w.packWarn or 0.10), "\n")
    put("packBad=", tostring(w.packBad or 0.20), "\n")
    put("fuelShowPercent=", tostring(w.fuelShowPercent or 1), "\n")
    put("statusMode=", tostring(w.statusMode or 1), "\n")
    put("flightCount=", tostring(clamp(math.floor(finiteNumber(w.flightCount) or 0), 0, 9999)), "\n")
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

local function promote(tmp, path)
  if not os or type(os.rename) ~= "function" then return false end
  local backup = path .. ".bak"
  if type(os.remove) == "function" then pcall(os.remove, backup) end
  local old = io.open(path, "r")
  local hadOld = old ~= nil
  if old then pcall(old.close, old) end
  if hadOld then
    local ok, moved = pcall(os.rename, path, backup)
    if not ok or moved == false or moved == nil then return false end
  end
  local ok, moved = pcall(os.rename, tmp, path)
  if ok and moved ~= false and moved ~= nil then return true end
  if hadOld then pcall(os.rename, backup, path) end
  return false
end

local function write(w, validLanguage)
  if not w then return true end
  local legacyProfile = deriveProfile(w)
  if w.powerProfile ~= 5 and legacyProfile ~= (w.powerProfile or 1) then w.powerProfile = legacyProfile end
  normalize(w, SCHEMA_VERSION)
  local path, legacyPath = savedPaths(w)
  local old = readMap(path)
  if next(old) == nil then old = readMap(legacyPath) end
  local savedSources, pending = {}, false
  for i = 1, #sourceOrder do
    local saved, value, wait = sourceOrder[i]
    local keyName = sourceKeys[saved]
    if w._sourceClears and w._sourceClears[keyName] then value, wait = "", false
    else value, wait = objectKey(w[keyName], false) end
    savedSources[saved] = value
    pending = pending or wait
  end
  local armValue, armWait
  local armSpec = sourceSpec(w.armSwitch)
  if w._armCleared then armValue, armWait = "", false
  elseif armSpec then armValue, armWait = armSpec, false
  elseif w.armSwitchKey then armValue, armWait = w.armSwitchKey, false
  else armValue, armWait = objectKey(w.armSwitch, true) end
  if pending or armWait then return false end

  local tmp = path .. ".tmp"
  if not writeFile(tmp, w, old, savedSources, armValue, validLanguage) then return false end
  if promote(tmp, path) then return true end
  local ok = writeFile(path, w, old, savedSources, armValue, validLanguage)
  if ok and os and type(os.remove) == "function" then pcall(os.remove, tmp) end
  return ok
end

local numericFields = {
  armDelay = "armDelay", flightMinSeconds = "flightMinSeconds", inFlightScreen = "inFlightScreen",
  cells = "cellCount", batteryType = "batteryType", theme = "themeMode", fontSize = "fontSize",
  batteryStyle = "batteryStyle", profile = "powerProfile", powerSourceType = "powerSourceType",
  batteryMode = "batteryMode", rotorwingMode = "rotorwingMode", rpmMax = "rpmMax",
  rpmWarn = "rpmWarn", packWarn = "packWarn", packBad = "packBad",
  fuelShowPercent = "fuelShowPercent", statusMode = "statusMode", flightCount = "flightCount",
}

local function read(w, validLanguage)
  if not w then return true end
  local path, legacyPath = savedPaths(w)
  local map = readMap(path)
  if next(map) == nil then map = readMap(path .. ".bak") end
  if next(map) == nil then map = readMap(legacyPath) end
  local schema = finiteNumber(map.schema) or 1
  for name, value in pairs(map) do
    local numeric = finiteNumber(value)
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
    elseif numericFields[name] and numeric then
      w[numericFields[name]] = numeric
    elseif numeric and w[name] ~= nil then
      w[name] = numeric
    end
  end
  if not map.profile then w.powerProfile = deriveProfile(w) end
  normalize(w, schema)
  w.selectedBmp, w.selectedFile, w._filtered, w._batteryLevels = nil, nil, nil, nil
  w.linkMin, w.linkMinSource, w.linkSeenAt = nil, nil, nil
  return true
end

return {read = read, write = write}
