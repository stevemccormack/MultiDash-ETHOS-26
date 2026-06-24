local module
local failed

local function call(method, ...)
  if not module and not failed then
    local chunk = loadfile("widget.lua")
    if chunk then
      local ok, result = pcall(chunk)
      if ok and type(result) == "table" then
        module = result
      else
        failed = true
      end
    else
      failed = true
    end
  end
  local fn = module and module[method]
  if fn then return fn(...) end
end

local function proxy(method)
  return function(...) return call(method, ...) end
end

local widget = {
  key = "mdash",
  name = "MultiDash",
  title = false,
  create = function(...)
    local w = call("create", ...)
    return w ~= nil and w or {}
  end,
  paint = proxy("paint"),
  wakeup = proxy("wakeup"),
  configure = proxy("configure"),
  read = proxy("read"),
  write = proxy("write"),
  close = proxy("close"),
}

local function init()
  if system and type(system.registerWidget) == "function" then
    pcall(system.registerWidget, widget)
  end
end

return {init = init}
