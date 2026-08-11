local widget = assert(loadfile("widget.lua"))()

local function init()
  system.registerWidget({
    key = "mdash",
    name = "MultiDash",
    title = false,
    create = widget.create,
    paint = widget.paint,
    wakeup = widget.wakeup,
    configure = widget.configure,
    read = widget.read,
    write = widget.write,
    close = widget.close,
  })
end

return {init = init}
