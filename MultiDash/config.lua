local function configure(w, api)
  if not form or type(form.addLine) ~= "function" then return end
  local clamp = api.clamp
  local T = function(key) return api.tr(w, key) end
  local batteryTypes = {"LiPo", "LiHV", "Li-ion", "LiFe", "NiCd"}
  local languageNames = {
    "English", "Deutsch", "Espanol", "Francais", "Italiano", "Polski",
    "Portugues", "Zhongwen Jianti", "Zhongwen Fanti",
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

  local function addToggle(label, get, set)
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
    if form.addHeader and pcall(form.addHeader, label) then return end
    if form.addTitle and pcall(form.addTitle, label) then return end
    form.addLine(string.upper(label))
  end

  local function addSource(label, key, resetCells)
    local line = form.addLine(T(label))
    if form.addSourceField then
      local get = function() return w[key] end
      local set = changed(function(value)
        w[key] = value
        w._sourceClears = w._sourceClears or {}
        w._sourceClears[key] = value == nil or nil
        if resetCells then w.detectedCells = nil end
      end)
      if pcall(form.addSourceField, line, nil, get, set) then return end
      pcall(form.addSourceField, line, get, set)
    end
  end

  local function addArmSource()
    local line = form.addLine("Arm switch")
    local get = function() return w.armSwitch end
    local set = changed(function(value)
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
    local function field(suffix)
      local key = prefix .. suffix:sub(1, 1):upper() .. suffix:sub(2)
      addNumber(T(label) .. " " .. T(suffix), 0, max,
        function() return w[key] end,
        function(value) w[key] = clamp(tonumber(value) or 0, 0, max) end,
        decimals)
    end
    field("high")
    field("mid")
    if prefix == "batt" then field("low") end
    if w[prefix .. "Mode"] ~= nil then
      addChoice(T(label) .. " " .. T("Scoring"), scoringChoices,
        function() return w[prefix .. "Mode"] or 1 end,
        function(value) w[prefix .. "Mode"] = clamp(math.floor(tonumber(value) or 1), 1, 2) end)
    end
  end

  addSection("Display")
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
  addToggle(T("Light"),
    function() return w.themeMode == 2 end,
    function(value) w.themeMode = value and 2 or 1 end)
  addToggle("Round gauge",
    function() return w.batteryStyle == 2 end,
    function(value) w.batteryStyle = value and 2 or 1 end)
  addSection("MODEL SETTINGS")
  addArmSource()
  addNumber("Delay", 0, 60,
    function() return w.armDelay or 5 end,
    function(value) w.armDelay = clamp(tonumber(value) or 0, 0, 60) end, 0)
  addSource(T("Timer"), "timerSource")
  addNumber(T("Flights"), 0, 9999,
    function() return w.flightCount or 0 end,
    function(value) w.flightCount = clamp(math.floor(tonumber(value) or 0), 0, 9999) end, 0)
  addSource("Status source", "statusSource")
  addToggle("Status pos/neg",
    function() return w.statusMode == 2 end,
    function(value) w.statusMode = value and 2 or 1 end)

  addSection("Power")
  addToggle(T("Fuel"),
    function() return w.powerSourceType == 2 end,
    function(value) w.powerSourceType = value and 2 or 1 end)
  addSource("Power source", "batterySource", true)
  addSource("RPM", "rpmSource")
  addSource("Batt/Fuel %", "field4Source")
  if (w.powerSourceType or 1) == 2 then
    addToggle("Fuel %",
      function() return (w.fuelShowPercent or 1) ~= 2 end,
      function(value) w.fuelShowPercent = value and 1 or 2 end)
    addThreshold("fuel", "Fuel", 0, 100)
  else
    addNumber(T("Cells"), 0, 12,
      function() return w.cellCount or 0 end,
      function(value) w.cellCount = clamp(tonumber(value) or 0, 0, 12); w.detectedCells = nil end, 0)
    addChoice(T("Battery type"), batteryTypes,
      function() return w.batteryType or 1 end,
      function(value) w.batteryType = clamp(math.floor(tonumber(value) or 1), 1, #batteryTypes); w.detectedCells = nil end)
    addThreshold("batt", "Cell V", 2, 4.35)
    addThreshold("field4", "Batt/Fuel %", 0, 100)
  end
  addSource("Current", "currentSource")
  addNumber("Current high", 0, 10000,
    function() return w.currentHigh end,
    function(value) w.currentHigh = clamp(tonumber(value) or 0, 0, 10000) end, 1)
  addNumber("Current mid", 0, 10000,
    function() return w.currentMid end,
    function(value) w.currentMid = clamp(tonumber(value) or 0, 0, 10000) end, 1)

  addSection(T("Link"))
  addSource("LQ", "rssiSource")
  addThreshold("link", "LQ", 0)

  addSection("TELEMETRY")
  addSource("Tlm 1", "field1Source")
  addThreshold("field1", "Tlm 1", 0)
  addSource("Tlm 2", "field2Source")
  addThreshold("field2", "Tlm 2", 0)
  addSource("Tlm 3", "field3Source")
  addThreshold("field3", "Tlm 3", 0)
  addSource("Tlm 4", "telemetry4Source")
  addThreshold("telemetry4", "Tlm 4", 0)

  addSection("In flight")
  addToggle("In flight screen",
    function() return (w.inFlightScreen or 1) ~= 2 end,
    function(value) w.inFlightScreen = value and 1 or 2 end)
  addSource("In flight stat 1", "inFlight1Source")
  addSource("In flight stat 2", "inFlight2Source")
  addSource("In flight stat 3", "inFlight3Source")
  addSource("In flight stat 4", "inFlight4Source")

  addChoice(T("Language"), languageNames,
    function() return languageIndex(w.language) end,
    function(value) w.language = api.languageCodes[clamp(math.floor(tonumber(value) or 1), 1, #api.languageCodes)] end)
end

return {configure = configure}
