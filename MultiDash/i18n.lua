local codes = {
  "en", "de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw",
}
local defaultCode = "en"
local english = {Scoring = "scoring", ["Dash Fuel"] = "Fuel"}
local currentCode
local current

local function valid(code)
  local legacyIndex = tonumber(code)
  if legacyIndex then
    return codes[math.max(1, math.min(#codes, math.floor(legacyIndex)))]
  end
  for i = 1, #codes do
    if codes[i] == code then return code end
  end
  return defaultCode
end

local function systemDefault()
  local locale
  if system and type(system.getLocale) == "function" then
    local ok, value = pcall(system.getLocale)
    if ok then locale = value end
  end
  locale = tostring(locale or ""):lower():gsub("%-", "_")
  if locale:match("^zh") and (locale:find("tw", 1, true) or locale:find("hk", 1, true)
      or locale:find("hant", 1, true)) then return "zh_tw" end
  if locale:match("^zh") then return "zh_cn" end
  local short = locale:match("^([a-z][a-z])")
  return valid(short or defaultCode)
end

local function loadLabels(code)
  local chunk = loadfile("lang/" .. code .. ".lua")
  if chunk then
    local ok, labels = pcall(chunk)
    if ok and type(labels) == "table" then return labels end
  end
  return {}
end

local function load(code)
  if currentCode == code and current then return current end
  code = valid(code)
  if currentCode == code and current then return current end
  local labels = code == defaultCode and english or loadLabels(code)
  currentCode = code
  current = labels
  return labels
end

local function text(widget, key)
  local labels = load(widget and widget.language or defaultCode)
  local value = labels[key]
  if type(value) == "string" and value ~= "" then return value end
  return key
end

return {
  codes = codes,
  default = function() return valid(defaultCode) end,
  systemDefault = systemDefault,
  valid = valid,
  text = text,
}
