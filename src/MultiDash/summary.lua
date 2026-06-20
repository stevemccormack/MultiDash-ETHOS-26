local function draw(w, c, scale, scrW, scrH, api)
  local px, textW = api.px, api.getTextW
  local T = function(key) return api.tr(w, key) end
  lcd.color(c.bg)
  lcd.drawFilledRectangle(0, 0, scrW, scrH)

  local light = tonumber(w.themeMode) == 2
  local panel = light and lcd.RGB(224, 229, 236) or lcd.RGB(29, 34, 40)
  local header = light and lcd.RGB(210, 218, 228) or lcd.RGB(39, 47, 56)
  local alternate = light and lcd.RGB(232, 236, 241) or lcd.RGB(24, 29, 35)
  local grid = light and lcd.RGB(150, 160, 172) or lcd.RGB(72, 84, 96)
  local margin = px(9, scale, 4, math.floor(scrW * 0.03))
  local pad = px(10, scale, 5, 14)
  local radius = px(8, scale, 4, 10)
  local headerY = px(6, scale, 2, 10)
  local headerH = px(58, scale, 40, 68)
  local width = scrW - margin * 2
  local bold = px(1, scale, 1, 2)

  local function boldText(text, x, y, color)
    lcd.color(color)
    lcd.drawText(x, y, text)
    lcd.drawText(x + bold, y, text)
  end

  local function boldRight(text, right, y, color)
    boldText(text, right - (textW(text) or 0), y, color)
  end

  api.roundPanel(margin, headerY, width, headerH, radius, header, grid)
  api.setFontSize("large", scale)
  local title = "Flights: " .. tostring(math.floor(tonumber(w.flightCount) or 0))
  local titleY = headerY + px(7, scale, 3, 10)
  boldText(title, margin + pad, titleY, c.text)
  api.setFontSize("huge", scale)
  boldRight(api.formatTime(w.flightTime or 0), scrW - margin - pad, headerY + px(3, scale, 1, 8), c.text)

  if not w.statOrder or #w.statOrder == 0 then
    api.setFontSize("large", scale)
    boldText(T("No flight stats captured"), margin + pad, headerY + headerH + px(28, scale, 16, 38), c.muted)
    return
  end

  local tableY = headerY + headerH + px(7, scale, 4, 10)
  local bottom = scrH - px(5, scale, 2, 8)
  local headerRowH = px(32, scale, 22, 38)
  local rows = #w.statOrder
  local usable = bottom - tableY - headerRowH
  if usable < rows then return end
  local rowH = math.max(20, math.floor(usable / rows))
  local tableH = headerRowH + rowH * rows
  local statusW = px(138, scale, 108, math.floor(width * 0.26))
  local valueW = px(124, scale, 78, math.floor(width * 0.22))
  local xName = margin + pad + px(8, scale, 4, 10)
  local xStatus = margin + width - statusW
  local xMax = xStatus - valueW
  local xMin = xMax - valueW
  local nameW = xMin - xName - pad

  api.roundPanel(margin, tableY, width, tableH, radius, panel, grid)
  lcd.color(header)
  lcd.drawFilledRectangle(margin + 1, tableY + radius, width - 2, headerRowH - radius)
  lcd.drawFilledRectangle(margin + radius, tableY + 1, width - radius * 2, headerRowH)
  api.setFontSize("small", scale)
  local labelY = tableY + px(8, scale, 3, 10)
  boldText(T("Sensor"), xName, labelY, c.text)
  boldRight(T("Min"), xMin + valueW - pad, labelY, c.text)
  boldRight(T("Max"), xMax + valueW - pad, labelY, c.text)
  boldText(T("Status"), xStatus + pad, labelY, c.text)

  local y = tableY + headerRowH
  local rowIndex = 0
  local function row(key)
    local stat = w.stats[key]
    if not stat then return end
    rowIndex = rowIndex + 1
    if rowIndex % 2 == 0 then
      lcd.color(alternate)
      lcd.drawFilledRectangle(margin + 1, y, width - 2, rowH)
    end
    local color, status = api.statStatus(w, key, stat, c)
    local inset = px(4, scale, 2, 6)
    local stripW = px(7, scale, 4, 10)
    local textY = y + math.max(1, math.floor((rowH - px(22, scale, 14, 28)) / 2))
    lcd.color(color)
    lcd.drawFilledRectangle(margin + 1, y + 1, stripW, rowH - 1)
    api.setFontSize(rowH >= px(31, scale, 22, 36) and "large" or "small", scale)
    boldText(api.fitText(stat.label, nameW), xName, textY, c.text)
    local minText, maxText = api.formatValue(stat.min), api.formatValue(stat.max)
    if key == "fuel" or key == "field4" then minText, maxText = minText .. "%", maxText .. "%" end
    if textW(maxText) > valueW - pad or textW(minText) > valueW - pad then api.setFontSize("small", scale) end
    boldRight(minText, xMin + valueW - pad, textY, c.text)
    boldRight(maxText, xMax + valueW - pad, textY, c.text)
    api.setFontSize(rowH >= px(31, scale, 22, 36) and "large" or "small", scale)
    local badgeX, badgeY = xStatus + inset, y + inset
    local badgeW, badgeH = statusW - inset * 2, rowH - inset * 2
    api.roundPanel(badgeX, badgeY, badgeW, badgeH, math.min(radius, math.floor(badgeH / 2)), c.bg, color)
    status = api.fitText(T(status), badgeW - pad * 2)
    lcd.color(color)
    lcd.drawText(badgeX + math.floor((badgeW - (textW(status) or 0)) / 2), textY - px(7, scale, 4, 9), status)
    lcd.color(grid)
    lcd.drawFilledRectangle(margin + 1, y + rowH - 1, width - 2, 1)
    y = y + rowH
  end

  for i = 1, #w.statOrder do
    if w.statOrder[i] ~= "rpm" then row(w.statOrder[i]) end
  end
  if w.stats.rpm then row("rpm") end
end

return {draw = draw}
