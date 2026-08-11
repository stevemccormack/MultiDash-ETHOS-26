local function boldText(text, x, y, color, bold)
  lcd.color(color)
  lcd.drawText(x, y, text)
  if bold and bold > 0 then lcd.drawText(x + 1, y, text) end
end

local function boldRight(api, text, right, y, color, bold)
  boldText(text, right - (api.getTextW(text) or 0) - (bold or 0), y, color, bold)
end

local function draw(w, c, scale, scrW, scrH, api)
  local px, textW, textH = api.px, api.getTextW, api.getTextH
  lcd.color(c.bg)
  lcd.drawFilledRectangle(0, 0, scrW, scrH)

  local light = tonumber(w.themeMode) == 2
  local panel = light and lcd.RGB(224, 229, 236) or lcd.RGB(29, 34, 40)
  local header = light and lcd.RGB(210, 218, 228) or lcd.RGB(39, 47, 56)
  local grid = light and lcd.RGB(150, 160, 172) or lcd.RGB(72, 84, 96)
  local compact = scrH < 250
  local margin = px(9, scale, 4, math.floor(scrW * 0.03))
  local pad = px(10, scale, 5, 14)
  local headerY = px(6, scale, 2, 10)
  local headerH = compact and px(36, scale, 30, 42) or px(58, scale, 40, 68)
  local width = scrW - margin * 2
  local bold = tonumber(w.fontSize) == 3 and 1 or 0

  api.roundPanel(margin, headerY, width, headerH, header, grid)
  local title = api.flightCountText(w)
  local summaryTitle = api.tr(w, "Flight summary"):upper()
  local timer = api.timerText(w)
  api.setFittingFont("huge", title .. summaryTitle .. timer,
    width - pad * 4 - bold * 3, headerH - 4)
  local titleW, summaryW, timerW = textW(title) or 0, textW(summaryTitle) or 0, textW(timer) or 0
  local titleX = margin + pad
  local timerX = margin + width - pad - timerW - bold
  local summaryX = titleX + titleW + bold
    + math.floor((timerX - titleX - titleW - summaryW - bold * 2) / 2)
  local textY = headerY + math.max(1, math.floor((headerH - textH(title)) / 2))
  boldText(title, titleX, textY, c.text, bold)
  boldText(summaryTitle, summaryX, textY, c.text, bold)
  boldText(timer, timerX, textY, c.text, bold)

  if not w.statOrder or #w.statOrder == 0 then
    local message = api.tr(w, "No flight stats captured")
    api.setFittingFont("large", message, width - pad * 2, scrH - headerY - headerH - pad)
    boldText(api.fitText(message, width - pad * 2), margin + pad,
      headerY + headerH + px(18, scale, 10, 24), c.muted, bold)
    return
  end

  local tableY = headerY + headerH + px(7, scale, 4, 10)
  local bottom = scrH - px(5, scale, 2, 8)
  local headerRowH = compact and px(24, scale, 18, 26) or px(32, scale, 22, 38)
  local rows = #w.statOrder
  local usable = bottom - tableY - headerRowH
  if usable < rows then return end
  local rowH = math.floor(usable / rows)
  if rowH < 8 then return end
  local tableH = headerRowH + rowH * rows
  local statusW = px(138, scale, 108, math.floor(width * 0.26))
  local valueW = px(124, scale, 78, math.floor(width * 0.22))
  local xName = margin + pad + px(8, scale, 4, 10)
  local xStatus = margin + width - statusW
  local xMax = xStatus - valueW
  local xMin = xMax - valueW
  local nameW = xMin - xName - pad

  api.roundPanel(margin, tableY, width, tableH, panel, grid)
  lcd.color(header)
  lcd.drawFilledRectangle(margin + 1, tableY + 1, width - 2, headerRowH - 1)
  api.setFittingFont("small", "Sensor Min Max Status", width, headerRowH - 2)
  local labelY = tableY + math.max(1, math.floor((headerRowH - textH("Sensor")) / 2))
  boldText(api.tr(w, "Sensor"), xName, labelY, c.text, bold)
  boldRight(api, api.tr(w, "Min"), xMin + valueW - pad, labelY, c.text, bold)
  boldRight(api, api.tr(w, "Max"), xMax + valueW - pad, labelY, c.text, bold)
  boldText(api.tr(w, "Status"), xStatus + pad, labelY, c.text, bold)

  local y = tableY + headerRowH
  local function row(key)
    local stat = w.stats[key]
    if not stat then return end
    local color, status = api.statStatus(w, key, stat, c)
    local stripW = px(7, scale, 4, 10)
    lcd.color(color)
    lcd.drawFilledRectangle(margin + 1, y + 1, stripW, rowH - 1)
    api.setFittingFont(rowH >= px(31, scale, 22, 36) and "large" or "small",
      stat.label, nameW, rowH - 2)
    local textY = y + math.max(0, math.floor((rowH - textH(stat.label)) / 2))
    boldText(api.fitText(stat.label, nameW), xName, textY, c.text, 0)
    local minText, maxText = api.formatValue(stat.min), api.formatValue(stat.max)
    if key == "fuel" or key == "field4" then minText, maxText = minText .. "%", maxText .. "%" end
    api.setFittingFont("small", minText .. maxText, valueW - pad, rowH - 2)
    boldRight(api, minText, xMin + valueW - pad, textY, c.text, 0)
    boldRight(api, maxText, xMax + valueW - pad, textY, c.text, 0)
    status = api.fitText(api.tr(w, status), statusW - pad * 2)
    api.setFittingFont("small", status, statusW - pad * 2, rowH - 2)
    lcd.color(color)
    lcd.drawText(xStatus + math.floor((statusW - (textW(status) or 0)) / 2),
      y + math.max(0, math.floor((rowH - textH(status)) / 2)), status)
    y = y + rowH
  end

  for i = 1, #w.statOrder do
    if w.statOrder[i] ~= "rpm" then row(w.statOrder[i]) end
  end
  if w.stats.rpm then row("rpm") end
end

return {draw = draw}
