local function configure(w, api)
  if not form or type(form.addLine) ~= "function" then return end
  local clamp = api.clamp
  local sourcePresent = api.sourcePresent
  local T = function(key) return api.tr(w, key) end
  local batteryTypes = {"LiPo", "LiHV", "Li-ion", "LiFe", "NiCd"}
  local profiles = {T("Electric"), T("Electric Dual Battery"), T("Rotorwing"), T("Fuel"), T("General")}
  local fontSizes = {T("Small"), T("Medium"), T("Large")}
  local languageNames = {
    "English", "Deutsch", "Español", "Français", "Italiano", "Polski",
    "Português", "简体中文", "繁體中文",
  }
  local scoringChoices = {T("High is good"), T("Low is good")}

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

  local function addNumber(label, min, max, get, set, decimals)
    if not form.addNumberField then return end
    label = T(label)
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
    label = T(label)
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

  local function addToggle(label, get, set)
    label = T(label)
    local setter = changed(set)
    if form.addBooleanField then
      local line = form.addLine(label)
      if pcall(form.addBooleanField, line, nil, get, setter) then return end
      if pcall(form.addBooleanField, line, get, setter) then return end
    end
    addChoice(label, {T("Off"), T("On")}, function() return get() and 2 or 1 end,
      function(value) set(tonumber(value) == 2) end)
  end

  local function addSection(label)
    label = T(label)
    if form.addHeader and pcall(form.addHeader, label) then return end
    if form.addTitle and pcall(form.addTitle, label) then return end
    form.addLine(string.upper(label))
  end

  local function addSource(label, key)
    local line = form.addLine(T(label))
    if not form.addSourceField then return end
    local get = function() return w[key] end
    local set = changed(function(value)
      if not sourcePresent(value) then value = nil end
      if w[key] ~= value then
        w._filtered, w._batteryLevels = nil, nil
        if key == "rssiSource" then
          w.linkMin, w.linkMinSource, w.linkSeenAt = nil, nil, nil
        end
      end
      w[key] = value
      w._sourceClears = w._sourceClears or {}
      w._sourceClears[key] = value == nil or nil
    end)
    if pcall(form.addSourceField, line, nil, get, set) then return end
    pcall(form.addSourceField, line, get, set)
  end

  local function addArmSource()
    local line = form.addLine(T("Arm"))
    local get = function() return w.armSwitch end
    local set = changed(function(value)
      if not sourcePresent(value) then value = nil end
      w.armSwitch, w.armSwitchKey = value, nil
      w._armCleared = value == nil or nil
    end)
    if form.addSwitchField then
      if pcall(form.addSwitchField, line, nil, get, set) then return end
      if pcall(form.addSwitchField, line, get, set) then return end
    end
    if form.addSourceField then
      if pcall(form.addSourceField, line, nil, get, set) then return end
      pcall(form.addSourceField, line, get, set)
    end
  end

  local function addThreshold(prefix, label, decimals, maxValue)
    local max = maxValue or 10000
    local min = prefix == "link" and -200 or 0
    for _, suffix in ipairs({"High", "Mid"}) do
      local key = prefix .. suffix
      addNumber(T(label) .. " " .. T(suffix:lower()), min, max,
        function() return w[key] end,
        function(value) w[key] = clamp(tonumber(value) or 0, min, max) end, decimals)
    end
    if w[prefix .. "Mode"] ~= nil then
      addChoice(T(label) .. " " .. T("Scoring"), scoringChoices,
        function() return w[prefix .. "Mode"] or 1 end,
        function(value) w[prefix .. "Mode"] = clamp(math.floor(tonumber(value) or 1), 1, 2) end)
    end
  end

  addSection("Display")
  local imageLine = form.addLine(T("Image"))
  if form.addFileField then
    local get = function() return w.imageFile and w.imageFile:match("[^/]+$") or "" end
    local set = changed(function(value)
      w.imageFile = value and value ~= "" and ("BITMAPS:/models/" .. value) or nil
      w.selectedBmp, w.selectedFile = nil, nil
    end)
    if not pcall(form.addFileField, imageLine, nil, "BITMAPS:/models", "image+ext", get, set) then
      pcall(form.addFileField, imageLine, "BITMAPS:/models", "image+ext", get, set)
    end
  end
  addToggle("Light", function() return w.themeMode == 2 end,
    function(value) w.themeMode = value and 2 or 1 end)
  addChoice("Font size", fontSizes, function() return w.fontSize or 2 end,
    function(value) w.fontSize = clamp(math.floor(tonumber(value) or 2), 1, 3) end)
  addToggle("Dial gauge", function() return w.batteryStyle == 2 end,
    function(value) w.batteryStyle = value and 2 or 1 end)

  addSection("MODEL SETTINGS")
  addChoice("Operating profile", profiles, function() return w.powerProfile or 1 end,
    function(value) api.applyProfile(w, value) end)
  addArmSource()
  addNumber("Delay", 0, 60, function() return w.armDelay or 5 end,
    function(value) w.armDelay = clamp(tonumber(value) or 0, 0, 60) end, 0)
  addNumber("Minimum flight seconds", 0, 300, function() return w.flightMinSeconds or 15 end,
    function(value) w.flightMinSeconds = clamp(math.floor(tonumber(value) or 15), 0, 300) end, 0)
  addSource("Timer", "timerSource")
  addNumber("Flights", 0, 9999, function() return w.flightCount or 0 end,
    function(value) w.flightCount = clamp(math.floor(tonumber(value) or 0), 0, 9999) end, 0)
  addSource("Status source", "statusSource")
  addToggle("Status pos/neg", function() return w.statusMode == 2 end,
    function(value) w.statusMode = value and 2 or 1 end)
  local profile = w.powerProfile or 1
  local dualMode, fuelMode = profile == 2, profile == 4
  addSection("Power")
  if dualMode then
    addSource("Battery 1 Power Source", "batterySource")
    addSource("Battery 2 Power Source", "battery2Source")
    addSource("Total Pack Voltage Source", "totalBatterySource")
  else
    addSource("Power source", "batterySource")
  end
  if fuelMode then
    addSource("Batt/Fuel %", "field4Source")
    addToggle("Fuel %", function() return (w.fuelShowPercent or 1) ~= 2 end,
      function(value) w.fuelShowPercent = value and 1 or 2 end)
    addThreshold("fuel", "Fuel", 0, 100)
  else
    if not dualMode then addSource("Batt/Fuel %", "field4Source") end
    addNumber(dualMode and "Cells per battery" or "Cells", 0, 12,
      function() return w.cellCount or 0 end,
      function(value)
        w.cellCount = clamp(math.floor(tonumber(value) or 0), 0, 12)
      end, 0)
    addChoice("Battery type", batteryTypes, function() return w.batteryType or 1 end,
      function(value) api.applyBatteryType(w, value) end)
    addNumber("Cell V green", 0, 4.35, function() return w.battHigh end,
      function(value) w.battHigh = clamp(tonumber(value) or 0, 0, 4.35) end, 2)
    addNumber("Cell V warning", 0, 4.35, function() return w.battMid end,
      function(value) w.battMid = clamp(tonumber(value) or 0, 0, 4.35) end, 2)
    addNumber("Cell V empty", 0, 4.35, function() return w.battLow end,
      function(value) w.battLow = clamp(tonumber(value) or 0, 0, 4.35) end, 2)
    if not dualMode then addThreshold("field4", "Batt/Fuel %", 0, 100) end
    if dualMode then
      addNumber("Pack mismatch warning", 0, 1, function() return w.packWarn or 0.10 end,
        function(value) w.packWarn = clamp(tonumber(value) or 0, 0, 1) end, 2)
      addNumber("Pack mismatch alert", 0, 1, function() return w.packBad or 0.20 end,
        function(value) w.packBad = clamp(tonumber(value) or 0, 0, 1) end, 2)
    end
  end
  addSource("RPM", "rpmSource")
  addNumber("RPM warning", 0, 50000, function() return w.rpmWarn or 6400 end,
    function(value) w.rpmWarn = clamp(math.floor(tonumber(value) or 6400), 0, 50000) end, 0)
  addNumber("RPM max", 1000, 50000, function() return w.rpmMax or 8000 end,
    function(value) w.rpmMax = clamp(math.floor(tonumber(value) or 8000), 1000, 50000) end, 0)
  if profile ~= 4 then
    addSource("Current", "currentSource")
    addNumber("Current high", 0, 10000, function() return w.currentHigh end,
      function(value) w.currentHigh = clamp(tonumber(value) or 0, 0, 10000) end, 1)
    addNumber("Current mid", 0, 10000, function() return w.currentMid end,
      function(value) w.currentMid = clamp(tonumber(value) or 0, 0, 10000) end, 1)
  end

  addSection("Link")
  addSource("LQ", "rssiSource")
  addThreshold("link", "LQ", 0)

  addSection("TELEMETRY")
  for i, prefix in ipairs({"field1", "field2", "field3", "telemetry4"}) do
    local label = "Tlm " .. i
    addSource(label, prefix .. "Source")
    addThreshold(prefix, label, 1)
  end

  addSection("In flight")
  addToggle("In flight screen", function() return (w.inFlightScreen or 1) ~= 2 end,
    function(value) w.inFlightScreen = value and 1 or 2 end)
  for i = 1, 4 do addSource("In flight stat " .. i, "inFlight" .. i .. "Source") end

  addChoice("Language", languageNames, function() return languageIndex(w.language) end,
    function(value) w.language = api.languageCodes[clamp(math.floor(tonumber(value) or 1), 1, #api.languageCodes)] end)
end

return {configure = configure}
