local lazy = assert(loadfile("lazy.lua"))()

local widget = lazy.wrap({
  key = "mdash",
  name = "MultiDash",
  title = false,
}, "widget.lua", {
  "create", "paint", "wakeup", "configure", "read", "write", "close",
}, {
  create = function() return {} end,
})

local function init()
  system.registerWidget(widget)
end

return {init = init}
