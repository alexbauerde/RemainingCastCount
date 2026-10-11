-- RemainingCastCount - Einstellungsseite (/rcc) und Minimap-Button

local _, ns = ...
local L = ns.L

local ROW_HEIGHT = 26
local THRESHOLD_X = -110 -- rechte Kante des Schwellen-Felds, von der rechten Zeilenkante aus

local panel = CreateFrame("Frame", "RemainingCastCountOptionsPanel")
panel.name = "RemainingCastCount"
panel:Hide()

---------------------------------------------------------------------------
-- Zauber aus dem Zauberbuch sammeln
---------------------------------------------------------------------------
local function GetRankText(spellID, subName)
    if type(subName) == "string" and subName ~= "" then return subName end
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, t = pcall(C_Spell.GetSpellSubtext, spellID)
        if ok and type(t) == "string" and t ~= "" then return t end
    elseif GetSpellSubtext then
        local t = GetSpellSubtext(spellID)
        if t and t ~= "" then return t end
    end
    return nil
end

-- withRanks = true: jeder Rang als eigener Eintrag, sonst ein Eintrag pro Zaubername
function ns.CollectSpells(withRanks)
    local list, byName = {}, {}

    local function add(spellID, isPassive, subName)
        if not spellID or isPassive then return end
        local name = ns.GetSpellName(spellID)
        if not name then return end
        local entry = byName[name]
        if not entry then
            entry = { name = name, ranks = {}, allIDs = {} }
            byName[name] = entry
            list[#list + 1] = entry
        end
        for _, id in ipairs(entry.allIDs) do
            if id == spellID then return end
        end
        -- Ränge sind aufsteigend sortiert: der höchste bestimmt Icon & Kosten
        entry.spellID = spellID
        entry.icon = ns.GetSpellIcon(spellID) or entry.icon
        entry.allIDs[#entry.allIDs + 1] = spellID
        entry.ranks[#entry.ranks + 1] = {
            spellID = spellID,
            rank = GetRankText(spellID, subName),
            icon = ns.GetSpellIcon(spellID),
        }
    end

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if info and not info.shouldHide and (not info.offSpecID or info.offSpecID == 0) then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if item and item.itemType == Enum.SpellBookItemType.Spell and not item.isOffSpec then
                        add(item.spellID, item.isPassive, item.subName)
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        -- Fallback für ältere Clients
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            for slot = offset + 1, offset + numSpells do
                local kind, spellID = GetSpellBookItemInfo(slot, BOOKTYPE_SPELL or "spell")
                if kind == "SPELL" then
                    add(spellID, IsPassiveSpell(slot, BOOKTYPE_SPELL or "spell"))
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)

    local result = {}
    for _, e in ipairs(list) do
        e.cost = ns.GetManaCost(e.spellID) or 0
        if e.cost > 0 then
            if withRanks then
                for i, r in ipairs(e.ranks) do
                    local cost = ns.GetManaCost(r.spellID) or 0
                    if cost > 0 then
                        result[#result + 1] = {
                            name = e.name, spellID = r.spellID, icon = r.icon or e.icon,
                            cost = cost, isRank = true, allIDs = e.allIDs,
                            rank = r.rank or ((#e.ranks > 1) and ("#" .. i) or nil),
                        }
                    end
                end
            else
                result[#result + 1] = e
            end
        end
    end
    return result
end

---------------------------------------------------------------------------
-- UI-Bausteine
---------------------------------------------------------------------------
local function CreateCheck(parent, label, tooltip, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    text:SetText(label)
    cb.label = text
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        ns.RequestUpdate()
    end)
    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    cb.Refresh = function(self) self:SetChecked(getter()) end
    return cb
end

local function CreateButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

---------------------------------------------------------------------------
-- Panel-Aufbau
---------------------------------------------------------------------------
local checks = {}
local scrollFrame, scrollChild, emptyText, fontLabel
local rows = {}

---------------------------------------------------------------------------
-- Vorschau: Zahl per Drag & Drop positionieren, Farbe wählen
---------------------------------------------------------------------------
local PREVIEW_SCALE = 2
local previewBtn, previewHolder, dragger, swatch

local function RefreshPreview()
    if not previewBtn then return end
    local tex
    for _, e in ipairs(ns.CollectSpells()) do
        if e.cost and e.cost > 0 and e.icon then tex = e.icon break end
    end
    previewBtn.icon:SetTexture(tex or "Interface\\Icons\\Spell_Holy_HolyBolt")

    local fs = previewHolder.text
    ns.SetupFont(fs, PREVIEW_SCALE)
    fs:SetText("5")
    ns.ApplyColor(fs, 5)
    previewHolder.lKey = nil
    ns.LayoutHolder(previewBtn, previewHolder, PREVIEW_SCALE, 0)

    dragger:ClearAllPoints()
    dragger:SetPoint("TOPLEFT", fs, "TOPLEFT", -6, 4)
    dragger:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 6, -4)

    local c = ns.db.color
    swatch.tex:SetColorTexture(c.r, c.g, c.b)
end
ns.RefreshPreview = RefreshPreview

local function SetPositionFromDrag()
    local cx, cy = dragger:GetCenter()
    local left, bottom, w, h = previewBtn:GetRect()
    if not cx or not left then return end
    local right, top = left + w, bottom + h
    local bx, by = left + w / 2, bottom + h / 2
    local tw = previewHolder.text:GetStringWidth()
    local H = ns.db.fontSize * PREVIEW_SCALE + 4

    local dx, dy = (cx - bx) / w, (cy - by) / h
    local hz = (dx < -1 / 6) and "LEFT" or ((dx > 1 / 6) and "RIGHT" or "")
    local v  = (dy > 1 / 6) and "TOP" or ((dy < -1 / 6) and "BOTTOM" or "")

    local ox, oy
    if hz == "RIGHT" then
        ox = (cx + tw / 2 - right) / w
    elseif hz == "LEFT" then
        ox = (cx - tw / 2 - left) / w
    else
        ox = dx
    end
    if v == "TOP" then
        oy = (cy + H / 2 - top) / h
    elseif v == "BOTTOM" then
        oy = (cy - H / 2 - bottom) / h
    else
        oy = dy
    end

    local function clamp(x) return math.max(-0.6, math.min(0.6, x)) end
    local point = v .. hz
    ns.db.point = (point ~= "") and point or "CENTER"
    ns.db.ox = math.floor(clamp(ox) * 1000 + 0.5) / 1000
    ns.db.oy = math.floor(clamp(oy) * 1000 + 0.5) / 1000
end

local function OpenColorPicker()
    local c = ns.db.color
    local prev = { r = c.r, g = c.g, b = c.b }
    local function apply(r, g, b)
        c.r, c.g, c.b = r, g, b
        RefreshPreview()
        ns.UpdateAll()
    end
    local function onChange()
        apply(ColorPickerFrame:GetColorRGB())
    end
    local function onCancel()
        apply(prev.r, prev.g, prev.b)
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r, g = c.g, b = c.b,
            hasOpacity = false,
            swatchFunc = onChange,
            cancelFunc = onCancel,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = onChange
        ColorPickerFrame.cancelFunc = onCancel
        ColorPickerFrame.previousValues = prev
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

local function BuildPreview()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -30, -62)
    title:SetText(L.POSITION_TITLE)

    previewBtn = CreateFrame("Frame", nil, panel)
    previewBtn:SetSize(36 * PREVIEW_SCALE, 36 * PREVIEW_SCALE)
    previewBtn:SetPoint("TOP", title, "BOTTOM", 0, -10)

    local border = previewBtn:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(0, 0, 0, 1)

    previewBtn.icon = previewBtn:CreateTexture(nil, "ARTWORK")
    previewBtn.icon:SetAllPoints()
    previewBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    previewHolder = CreateFrame("Frame", nil, previewBtn)
    previewHolder:SetFrameLevel(previewBtn:GetFrameLevel() + 5)
    previewHolder.text = previewHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormal")

    dragger = CreateFrame("Frame", nil, panel)
    dragger:SetFrameLevel(previewHolder:GetFrameLevel() + 5)
    dragger:SetMovable(true)
    dragger:EnableMouse(true)
    dragger:RegisterForDrag("LeftButton")
    dragger.hl = dragger:CreateTexture(nil, "HIGHLIGHT")
    dragger.hl:SetAllPoints()
    dragger.hl:SetColorTexture(1, 1, 1, 0.15)

    dragger:SetScript("OnDragStart", function(self)
        -- Griff erst fest positionieren (er hängt sonst am Text),
        -- dann den Text an den Griff hängen, damit er der Maus folgt
        local l, b, w, h = self:GetRect()
        self:ClearAllPoints()
        self:SetSize(w, h)
        self:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", l - panel:GetLeft(), b - panel:GetBottom())
        previewHolder.text:ClearAllPoints()
        previewHolder.text:SetPoint("CENTER", self, "CENTER")
        self:StartMoving()
    end)
    dragger:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SetPositionFromDrag()
        RefreshPreview()
        ns.UpdateAll()
    end)
    dragger:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.DRAG_TITLE, 1, 1, 1)
        GameTooltip:AddLine(L.DRAG_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    dragger:SetScript("OnLeave", GameTooltip_Hide)

    -- Farbe
    swatch = CreateFrame("Button", nil, panel)
    swatch:SetSize(20, 20)
    swatch:SetPoint("TOPLEFT", previewBtn, "BOTTOMLEFT", -30, -18)
    local sb = swatch:CreateTexture(nil, "BACKGROUND")
    sb:SetPoint("TOPLEFT", -1, 1)
    sb:SetPoint("BOTTOMRIGHT", 1, -1)
    sb:SetColorTexture(0.6, 0.6, 0.6, 1)
    swatch.tex = swatch:CreateTexture(nil, "ARTWORK")
    swatch.tex:SetAllPoints()
    swatch:SetScript("OnClick", OpenColorPicker)
    local sl = swatch:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sl:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    sl:SetText(L.FONT_COLOR)
    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.FONT_COLOR_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    swatch:SetScript("OnLeave", GameTooltip_Hide)

    local warn = CreateCheck(panel, L.WARN_COLORS, L.WARN_COLORS_TIP,
        function() return ns.db.warnColors end,
        function(v) ns.db.warnColors = v; RefreshPreview() end)
    warn:SetPoint("TOPLEFT", swatch, "BOTTOMLEFT", -3, -6)
    checks[#checks + 1] = warn

    local reset = CreateButton(panel, L.DEFAULTS, 100, function()
        ns.db.point = ns.defaults.point
        ns.db.ox, ns.db.oy = ns.defaults.ox, ns.defaults.oy
        local d = ns.defaults.color
        ns.db.color.r, ns.db.color.g, ns.db.color.b = d.r, d.g, d.b
        ns.db.warnColors = ns.defaults.warnColors
        warn:Refresh()
        RefreshPreview()
        ns.UpdateAll()
    end)
    reset:SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 3, -6)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.DEFAULTS_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", GameTooltip_Hide)
end

local function BuildPanel()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("RemainingCastCount")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    sub:SetJustifyH("LEFT")
    sub:SetText(L.SUBTITLE)

    -- Allgemeine Optionen
    local c1 = CreateCheck(panel, L.ENABLED, L.ENABLED_TIP,
        function() return ns.db.enabled end, function(v) ns.db.enabled = v end)
    c1:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -2, -10)

    local c2 = CreateCheck(panel, L.SHOW_ZERO, L.SHOW_ZERO_TIP,
        function() return ns.db.showZero end, function(v) ns.db.showZero = v end)
    c2:SetPoint("LEFT", c1, "RIGHT", 140, 0)

    local c3 = CreateCheck(panel, L.MINIMAP_BUTTON, L.MINIMAP_BUTTON_TIP,
        function() return ns.db.minimap end, function(v) ns.db.minimap = v; ns.UpdateMinimapButton() end)
    c3:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, -2)

    local c4 = CreateCheck(panel, L.SHOW_RANKS,
        L.SHOW_RANKS_TIP,
        function() return ns.db.showRanks end, function(v) ns.db.showRanks = v; ns.RefreshOptionsList() end)
    c4:SetPoint("LEFT", c3, "RIGHT", 140, 0)

    checks = { c1, c2, c3, c4 }
    BuildPreview()

    -- Schriftgröße
    local fontTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontTitle:SetPoint("TOPLEFT", c3, "BOTTOMLEFT", 4, -10)
    fontTitle:SetText(L.FONT_SIZE)

    local minus = CreateButton(panel, "-", 24, function()
        ns.db.fontSize = math.max(8, ns.db.fontSize - 1)
        fontLabel:SetText(ns.db.fontSize)
        RefreshPreview()
        ns.UpdateAll()
    end)
    minus:SetPoint("LEFT", fontTitle, "RIGHT", 10, 0)

    fontLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fontLabel:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    fontLabel:SetWidth(24)

    local plus = CreateButton(panel, "+", 24, function()
        ns.db.fontSize = math.min(32, ns.db.fontSize + 1)
        fontLabel:SetText(ns.db.fontSize)
        RefreshPreview()
        ns.UpdateAll()
    end)
    plus:SetPoint("LEFT", fontLabel, "RIGHT", 8, 0)

    -- Zauberliste
    local listTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -270)
    listTitle:SetText(L.SPELLS)

    local allOn = CreateButton(panel, L.ALL_ON, 90, function()
        wipe(ns.db.disabled)
        wipe(ns.db.disabledRanks)
        ns.RefreshOptionsList()
        ns.RequestUpdate()
    end)
    allOn:SetPoint("LEFT", listTitle, "RIGHT", 16, 0)

    local allOff = CreateButton(panel, L.ALL_OFF, 90, function()
        for _, e in ipairs(ns.CollectSpells()) do ns.db.disabled[e.name] = true end
        ns.RefreshOptionsList()
        ns.RequestUpdate()
    end)
    allOff:SetPoint("LEFT", allOn, "RIGHT", 6, 0)

    local border = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    border:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", -4, -8)
    border:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
    if border.SetBackdrop then
        border:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        border:SetBackdropColor(0, 0, 0, 0.4)
        border:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
    end

    scrollFrame = CreateFrame("ScrollFrame", "RemainingCastCountOptionsScroll", border, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 6)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:SetScript("OnSizeChanged", function(self, w) scrollChild:SetWidth(w) end)

    -- Spaltenkopf über den Schwellen-Feldern (Zeilen enden 34 px vor dem Rahmen: Scrollleiste)
    local thresholdTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    thresholdTitle:SetPoint("BOTTOM", border, "TOPRIGHT", THRESHOLD_X - 34 - 18, 2)
    thresholdTitle:SetText(L.THRESHOLD_HEADER)

    emptyText = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", 8, -8)
    emptyText:SetText(L.NO_SPELLS)
end

-- Eigener Wert der Zeile; Ränge ohne eigenen Wert erben (grau) den des Zaubers
local function FillThreshold(row)
    local own = row.isRank and ns.db.rankThresholds[row.spellID] or ns.db.thresholds[row.spellName]
    local shown = own or (row.isRank and ns.db.thresholds[row.spellName]) or nil
    row.threshold:SetText(shown and tostring(shown) or "")
    if own then
        row.threshold:SetTextColor(1, 1, 1)
    else
        row.threshold:SetTextColor(0.6, 0.6, 0.6)
    end
end

local function SaveThreshold(box)
    local row = box:GetParent()
    if not row.spellName then return end
    local v = tonumber(box:GetText())
    if row.isRank then
        ns.db.rankThresholds[row.spellID] = v
    else
        ns.db.thresholds[row.spellName] = v
    end
    FillThreshold(row)
    ns.RequestUpdate()
end

local function GetRow(i)
    local row = rows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24)
    row.check:SetPoint("LEFT", 4, 0)
    row.check:SetScript("OnClick", function(self)
        local name = row.spellName
        if not name then return end
        local on = self:GetChecked()
        if row.isRank then
            if on then
                -- War der ganze Zauber aus, bleiben die anderen Ränge aus
                if ns.db.disabled[name] then
                    ns.db.disabled[name] = nil
                    for _, id in ipairs(row.allIDs or {}) do ns.db.disabledRanks[id] = true end
                end
                ns.db.disabledRanks[row.spellID] = nil
            else
                ns.db.disabledRanks[row.spellID] = true
            end
        else
            ns.db.disabled[name] = (not on) and true or nil
        end
        ns.RequestUpdate()
    end)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", THRESHOLD_X - 36 - 12, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.cost = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.cost:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.cost:SetJustifyH("RIGHT")

    row.threshold = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.threshold:SetSize(36, 20)
    row.threshold:SetPoint("RIGHT", row, "RIGHT", THRESHOLD_X, 0)
    row.threshold:SetAutoFocus(false)
    row.threshold:SetNumeric(true)
    row.threshold:SetMaxLetters(3)
    row.threshold:SetJustifyH("CENTER")
    row.threshold:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    row.threshold:SetScript("OnEscapePressed", function(self)
        FillThreshold(self:GetParent())
        self:ClearFocus()
    end)
    row.threshold:SetScript("OnEditFocusGained", function(self) self:SetTextColor(1, 1, 1) end)
    row.threshold:SetScript("OnEditFocusLost", SaveThreshold)
    row.threshold:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.THRESHOLD_HEADER, 1, 1, 1)
        GameTooltip:AddLine(L.THRESHOLD_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row.threshold:SetScript("OnLeave", GameTooltip_Hide)

    -- Tooltip über Icon/Name
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    rows[i] = row
    return row
end

function ns.RefreshOptionsList()
    if not scrollChild or not panel:IsShown() then return end

    for _, cb in ipairs(checks) do cb:Refresh() end
    fontLabel:SetText(ns.db.fontSize)

    local spells = ns.CollectSpells(ns.db.showRanks)
    for i, e in ipairs(spells) do
        local row = GetRow(i)
        -- Offene Eingabe noch für den alten Zauber dieser Zeile speichern
        if row.threshold:HasFocus() then row.threshold:ClearFocus() end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
        row.spellName = e.name
        row.spellID = e.spellID
        row.isRank = e.isRank
        row.allIDs = e.allIDs
        row.icon:SetTexture(e.icon or 134400)
        row.name:SetText(e.rank and (e.name .. "  |cff9d9d9d" .. e.rank .. "|r") or e.name)
        row.cost:SetText(e.cost > 0 and (e.cost .. " " .. L.MANA) or ("|cff808080" .. L.NO_MANA_COST .. "|r"))
        row.check:SetChecked(not ns.db.disabled[e.name]
            and not (e.isRank and ns.db.disabledRanks[e.spellID]))
        FillThreshold(row)
        row:Show()
    end
    for i = #spells + 1, #rows do rows[i]:Hide() end

    emptyText:SetShown(#spells == 0)
    RefreshPreview()
    scrollChild:SetHeight(math.max(1, #spells * ROW_HEIGHT))
end

panel:SetScript("OnShow", function()
    -- Breite erst setzen, wenn das Panel sichtbar ist
    C_Timer.After(0, function()
        if scrollFrame then scrollChild:SetWidth(scrollFrame:GetWidth()) end
        ns.RefreshOptionsList()
    end)
end)

---------------------------------------------------------------------------
-- Registrierung & Öffnen
---------------------------------------------------------------------------
function ns.InitOptions()
    BuildPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        ns.category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(ns.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function ns.OpenOptions()
    if ns.category and Settings and Settings.OpenToCategory then
        if SettingsPanel and SettingsPanel:IsShown() and panel:IsVisible() then
            HideUIPanel(SettingsPanel)
            return
        end
        Settings.OpenToCategory(ns.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

---------------------------------------------------------------------------
-- Minimap-Button
---------------------------------------------------------------------------
local mmButton

local function UpdateMinimapPosition()
    local angle = math.rad(ns.db.minimapAngle or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.InitMinimapButton()
    if mmButton or not Minimap then return end

    mmButton = CreateFrame("Button", "RemainingCastCountMinimapButton", Minimap)
    mmButton:SetSize(31, 31)
    mmButton:SetFrameStrata("MEDIUM")
    mmButton:SetFrameLevel(8)
    mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mmButton:RegisterForDrag("LeftButton")
    mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = mmButton:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = mmButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(ns.ICON)
    icon:SetPoint("TOPLEFT", 7, -6)

    local overlay = mmButton:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    mmButton:SetScript("OnClick", function() ns.OpenOptions() end)

    mmButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdateMinimapPosition()
        end)
    end)
    mmButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    mmButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RemainingCastCount")
        GameTooltip:AddLine(L.MINIMAP_CLICK, 1, 1, 1)
        GameTooltip:AddLine(L.MINIMAP_DRAG, 1, 1, 1)
        GameTooltip:Show()
    end)
    mmButton:SetScript("OnLeave", GameTooltip_Hide)

    ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
    if not mmButton then return end
    UpdateMinimapPosition()
    mmButton:SetShown(ns.db.minimap)
end
