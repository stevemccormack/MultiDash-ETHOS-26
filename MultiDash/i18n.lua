local codes = {
  "en", "de", "es", "fr", "it", "pl", "pt", "zh_cn", "zh_tw",
}
local defaultCode = "en"
local currentCode
local current
local fallback

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

local function loadLabels(code)
  local chunk = loadfile("lang/" .. code .. ".lua")
  if chunk then
    local ok, labels = pcall(chunk)
    if ok and type(labels) == "table" then return labels end
  end
  return {}
end

local function load(code)
  code = valid(code)
  if currentCode == code and current then return current end
  local labels = loadLabels(code)
  currentCode = code
  current = labels
  return labels
end

local function text(widget, key)
  local labels = load(widget and widget.language or defaultCode)
  local value = labels[key]
  if type(value) == "string" and value ~= "" then return value end
  if currentCode ~= "en" then
    fallback = fallback or loadLabels("en")
    value = fallback[key]
    if type(value) == "string" and value ~= "" then return value end
  end
  return key
end

return {
  codes = codes,
  default = function() return valid(defaultCode) end,
  valid = valid,
  text = text,
}
