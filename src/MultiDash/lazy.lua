local function caller(path)
  local module
  local failed = false

  local function load()
    if module then return module end
    if failed then return nil end
    local chunk = loadfile(path)
    if not chunk then
      failed = true
      return nil
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
      failed = true
      return nil
    end
    module = result
    return module
  end

  return function(method, ...)
    local mod = load()
    local fn = mod and mod[method]
    if fn then return fn(...) end
  end
end

local function wrap(registration, path, callbacks, fallback)
  local call = caller(path)
  local function proxy(method)
    return function(...)
      local result = call(method, ...)
      if result ~= nil then return result end
      local value = fallback and fallback[method]
      if type(value) == "function" then return value(...) end
      return value
    end
  end
  for i = 1, #callbacks do
    local method = callbacks[i]
    registration[method] = proxy(method)
  end
  return registration
end

return {wrap = wrap}
