local function configure(w, api)
  if not form or type(form.addLine) ~= "function" then return end
  local clamp = api.clamp
  local T = function(key) return api.tr(w, key) end
  local armChoices = {"Off", "SA", "SB", "SC", "SD", "SE", "SF", "SG", "SH"}
  local batteryTypes = {"LiPo", "LiHV", "Li-ion", "LiFe", "NiCd"}
  local languageNames = {
    "English", "Deutsch", "Espanol", "Francais", "Italiano", "Polski",
    "Portugues", "Zhongwen Jianti", "Zhongwen Fanti",
  }

  local function languageIndex(code)
    for i = 1, #api.languageCodes do
      if api.languageCodes[i] == code then return i end
    end
    return 1
  end

  local function changed(setter)
    return function(value)
      setter(value)
      w.dirty, w.dirtyAt = true, os.clock()
    end
  end

  local function armSwitchIndex()
    local key = w.armSwitchKey
    if not key and w.armSwitch then
      if type(w.armSwitch.name) == "function" then
        local ok, name = pcall(w.armSwitch.name, w.armSwitch)
        if ok then key = name end
      end
      key = key or tostring(w.armSwitch)
    end
    key = key and (tostring(key):match("S[A-H]") or tostring(key):match("s[a-h]"))
    key = key and key:upper() or ""
    for i = 1, #armChoices do
      if armChoices[i] == key then return i end
    end
    return 1
  end

  local function setArmSwitchIndex(value)
    local key = armChoices[clamp(math.floor(tonumber(value) or 1), 1, #armChoices)]
    if key == "Off" then
      w.armSwitchKey, w.armSwitch = nil, nil
    else
      w.armSwitchKey, w.armSwitch = key, api.resolveSwitch(key)
    end
  end

  local function addNumber(label, min, max, get, set, decimals)
    if not form.addNumberField then return end
    local places = decimals or 0
    local factor = 10 ^ places
    local fieldMin, fieldMax = min, max
    local fieldGet, fieldSet = get, changed(set)
    if places > 0 then
      fieldMin, fieldMax = math.floor(min * factor + 0.5), math.floor(max * factor + 0.5)
      fieldGet = function() return math.floor((tonumber(get()) or 0) * factor + 0.5) end
      fieldSet = changed(function(value) set((tonumber(value) or 0) / factor) end)
    end
    local line = form.addLine(label)
    local ok, field = pcall(form.addNumberField, line, nil, fieldMin, fieldMax, fieldGet, fieldSet)
    if not ok then ok, field = pcall(form.addNumberField, line, fieldMin, fieldMax, fieldGet, fieldSet) end
    if ok and field and type(field.decimals) == "function" then pcall(field.decimals, field, places) end
  end

  local function addChoice(label, choices, get, set)
    local values = {}
    for i = 1, #choices do values[i] = {choices[i], i} end
    local setter = changed(set)
    local line
    if form.addChoiceField then
      line = form.addLine(label)
      if pcall(form.addChoiceField, line, nil, values, get, setter) then return end
      if pcall(form.addChoiceField, line, nil, choices, get, setter) then return end
      if pcall(form.addChoiceField, line, values, get, setter) then return end
      if pcall(form.addChoiceField, line, choices, get, setter) then return end
    end
    if form.addSelectField then
      if not line then line = form.addLine(label) end
      if pcall(form.addSelectField, line, nil, values, get, setter) then return end
      if pcall(form.addSelectField, line, nil, choices, get, setter) then return end
      if pcall(form.addSelectField, line, values, get, setter) then return end
      if pcall(form.addSelectField, line, choices, get, setter) then return end
    end
    addNumber(label, 1, #choices, get, set, 0)
  end

  local function addSource(label, key, resetCells)
    local line = form.addLine(T(label))
    if form.addSourceField then
      local get = function() return w[key] end
      local set = changed(function(value)
        w[key] = value
        if resetCells then w.detectedCells = nil end
      end)
      if pcall(form.addSourceField, line, nil, get, set) then return end
      pcall(form.addSourceField, line, get, set)
    end
  end

  local function addThreshold(prefix, label, decimals, maxValue)
    local max = maxValue or 10000
    local function field(suffix)
      addNumber(T(label) .. " " .. T(suffix), 0, max,
        function() return w[prefix .. suffix:sub(1, 1):upper() .. suffix:sub(2)] end,
        function(value) w[prefix .. suffix:sub(1, 1):upper() .. suffix:sub(2)] = clamp(tonumber(value) or 0, 0, max) end,
        decimals)
    end
    field("high")
    field("mid")
    if prefix == "batt" then field("low") end
    if w[prefix .. "Mode"] ~= nil then
      addChoice(T(label) .. " " .. T("scoring"), {T("High is good"), T("Low is good")},
        function() return w[prefix .. "Mode"] end,
        function(value) w[prefix .. "Mode"] = tonumber(value) == 2 and 2 or 1 end)
    end
  end

  local line = form.addLine(T("Image"))
  if form.addFileField then
    local get = function() return w.imageFile and w.imageFile:match("[^/]+$") or "" end
    local set = changed(function(value)
      w.imageFile = value and value ~= "" and ("BITMAPS:/models/" .. value) or nil
      w.selectedBmp, w.selectedFile = nil, nil
    end)
    if not pcall(form.addFileField, line, nil, "BITMAPS:/models", "image+ext", get, set) then
      pcall(form.addFileField, line, "BITMAPS:/models", "image+ext", get, set)
    end
  end

  form.addLine(T("Display / Arm"))
  addChoice(T("Theme"), {T("Dark"), T("Light")},
    function() return w.themeMode or 1 end,
    function(value) w.themeMode = tonumber(value) == 2 and 2 or 1 end)
  addChoice(T("Arm switch"), armChoices, armSwitchIndex, setArmSwitchIndex)
  addChoice(T("Arm switch direction"), {T("Normal"), T("Reversed")},
    function() return w.armSwitchReverse or 1 end,
    function(value) w.armSwitchReverse = tonumber(value) == 2 and 2 or 1 end)
  addNumber(T("Arming delay"), 0, 60,
    function() return w.armDelay or 5 end,
    function(value) w.armDelay = clamp(tonumber(value) or 0, 0, 60) end, 0)
  addNumber(T("Flights"), 0, 9999,
    function() return w.flightCount or 0 end,
    function(value) w.flightCount = clamp(math.floor(tonumber(value) or 0), 0, 9999) end, 0)

  form.addLine(T("Power / Battery / Fuel"))
  addChoice(T("Power Source Type"), {T("Battery"), T("Fuel")},
    function() return w.powerSourceType or 1 end,
    function(value) w.powerSourceType = tonumber(value) == 2 and 2 or 1 end)
  addSource("Power source", "batterySource", true)
  addSource("Battery/Fuel percentage", "field4Source")
  if (w.powerSourceType or 1) == 2 then
    addChoice(T("Fuel percentage"), {T("On"), T("Off")},
      function() return w.fuelShowPercent or 1 end,
      function(value) w.fuelShowPercent = tonumber(value) == 2 and 2 or 1 end)
    addThreshold("fuel", "Fuel", 0, 100)
  else
    addNumber(T("Cells"), 0, 12,
      function() return w.cellCount or 0 end,
      function(value) w.cellCount = clamp(tonumber(value) or 0, 0, 12); w.detectedCells = nil end, 0)
    addChoice(T("Battery type"), batteryTypes,
      function() return w.batteryType or 1 end,
      function(value) w.batteryType = clamp(math.floor(tonumber(value) or 1), 1, #batteryTypes); w.detectedCells = nil end)
    addChoice(T("Battery style"), {T("Tower"), T("Gauge")},
      function() return w.batteryStyle or 1 end,
      function(value) w.batteryStyle = tonumber(value) == 2 and 2 or 1 end)
    addThreshold("batt", "Battery/cell", 2, 4.35)
    addThreshold("field4", "Battery/Fuel percentage", 0, 100)
  end
  addSource("Current", "currentSource")
  addNumber(T("Current high"), 0, 10000,
    function() return w.currentHigh end,
    function(value) w.currentHigh = clamp(tonumber(value) or 0, 0, 10000) end, 1)
  addNumber(T("Current mid"), 0, 10000,
    function() return w.currentMid end,
    function(value) w.currentMid = clamp(tonumber(value) or 0, 0, 10000) end, 1)

  form.addLine(T("Link"))
  addSource("Link quality", "rssiSource")
  addThreshold("link", "Link quality", 0)

  form.addLine(T("Telemetry / Engine"))
  addSource("RPM", "rpmSource")
  addSource("Telemetry 1", "field1Source")
  addThreshold("field1", "Telemetry 1", 0)
  addSource("Telemetry 2", "field2Source")
  addThreshold("field2", "Telemetry 2", 0)
  addSource("Telemetry 3", "field3Source")
  addThreshold("field3", "Telemetry 3", 0)
  addSource("Telemetry 4", "telemetry4Source")
  addThreshold("field4", "Telemetry 4", 0)

  form.addLine(T("In-flight screen"))
  addChoice(T("In-flight screen"), {T("On"), T("Off")},
    function() return w.inFlightScreen or 1 end,
    function(value) w.inFlightScreen = tonumber(value) == 2 and 2 or 1 end)
  addSource("In-flight stat 1", "inFlight1Source")
  addSource("In-flight stat 2", "inFlight2Source")
  addSource("In-flight stat 3", "inFlight3Source")
  addSource("In-flight stat 4", "inFlight4Source")

  form.addLine(T("Language"))
  addChoice(T("Language"), languageNames,
    function() return languageIndex(w.language) end,
    function(value) w.language = api.languageCodes[clamp(math.floor(tonumber(value) or 1), 1, #api.languageCodes)] end)
end

return {configure = configure}
