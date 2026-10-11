-- RemainingCastCount - Core
-- Zeigt unten rechts an jedem Aktionsbutton, wie oft der Zauber mit dem aktuellen Mana noch gewirkt werden kann.

local ADDON_NAME, ns = ...
local L = ns.L

local MANA  = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
local floor = math.floor

ns.ICON = "Interface\\AddOns\\RemainingCastCount\\Art\\Logo-Icon"

ns.defaults = {
    enabled      = true,
    disabled     = {},
    disabledRanks = {}, -- [spellID] = true -> einzelner Rang aus (nur mit showRanks)
    thresholds   = {}, -- [Zaubername] = n -> Zahl erst ab n und darunter zeigen (alle Ränge)
    rankThresholds = {}, -- [spellID] = n -> eigener Wert für einen Rang (nur mit showRanks)
    showRanks    = false, -- Ränge in der Liste einzeln schaltbar   -- [Zaubername] = true  -> wird nicht angezeigt (gilt für alle Ränge)
    fontSize     = 14,
    showZero     = true, -- "0" in Rot anzeigen, wenn das Mana nicht mehr reicht
    minimap      = true,
    minimapAngle = 220,
    maxCount     = 50,
    color        = { r = 1, g = 1, b = 1 }, -- Schriftfarbe
    warnColors   = true, -- 0 rot, 1-2 gelb
    point        = "BOTTOMRIGHT", -- Ankerpunkt am Button
    ox           = -0.05, -- Versatz in Anteilen der Buttonbreite
    oy           = 0.05,  -- Versatz in Anteilen der Buttonhöhe   -- höchste Zahl, die angezeigt wird (darüber "50+")
}

---------------------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------------------
local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end
ns.IsSecret = IsSecret

function ns.Print(msg)
    print("|cff33ccffRemainingCastCount|r: " .. tostring(msg))
end

function ns.GetSpellName(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return (GetSpellInfo(spellID))
end

function ns.GetSpellIcon(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return select(3, GetSpellInfo(spellID))
end

-- Letzte lesbare Kosten pro Zauber (Fallback, falls das Spiel Werte im Kampf verschleiert)
local costCache = {}

local function ReadManaCost(spellID)
    local costs
    if C_Spell and C_Spell.GetSpellPowerCost then
        costs = C_Spell.GetSpellPowerCost(spellID)
    elseif GetSpellPowerCost then
        costs = GetSpellPowerCost(spellID)
    end
    if not costs then return 0 end
    for _, c in ipairs(costs) do
        if c.type == MANA or c.name == "MANA" then
            local v = c.cost
            if (not v or v == 0) and c.minCost and c.minCost > 0 then
                v = c.minCost
            end
            if (not v or v == 0) and c.costPercent and c.costPercent > 0 then
                v = floor(UnitPowerMax("player", MANA) * c.costPercent / 100)
            end
            return v or 0
        end
    end
    return 0
end

-- Fallback: Kosten aus dem Tooltip lesen ("35 Mana")
local function ReadManaCostFromTooltip(spellID)
    if not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) then return nil end
    local data = C_TooltipInfo.GetSpellByID(spellID)
    if not data or not data.lines then return nil end
    for _, line in ipairs(data.lines) do
        for _, text in ipairs({ line.leftText, line.rightText }) do
            if type(text) == "string" and not IsSecret(text) then
                local num = text:match("^%s*([%d%.,]+)%s+Mana")
                if num then
                    num = tonumber((num:gsub("[%.,]", "")))
                    if num and num > 0 then return num end
                end
            end
        end
    end
    return nil
end

ns.lastCostError = {}

function ns.GetManaCost(spellID)
    if not spellID then return nil end
    local ok, cost = pcall(ReadManaCost, spellID)
    if ok and cost ~= nil and not IsSecret(cost) and cost > 0 then
        costCache[spellID] = cost
        return cost
    end
    ns.lastCostError[spellID] = not ok and tostring(cost) or (IsSecret(cost) and "secret") or nil

    local ok2, tipCost = pcall(ReadManaCostFromTooltip, spellID)
    if ok2 and tipCost then
        costCache[spellID] = tipCost
        return tipCost
    end

    if ok and cost ~= nil and not IsSecret(cost) then
        return costCache[spellID] or cost
    end
    return costCache[spellID]
end

local function GetPlayerMana()
    local ok, power = pcall(UnitPower, "player", MANA)
    if ok and power ~= nil and not IsSecret(power) then return power end
    return nil
end

function ns.IsSpellShown(spellID)
    if not ns.db or not ns.db.enabled then return false end
    local name = ns.GetSpellName(spellID)
    if not name then return false end
    if ns.db.disabled[name] then return false end
    if ns.db.showRanks and ns.db.disabledRanks[spellID] then return false end
    return true
end

-- Höchste Zahl, die noch angezeigt wird (nil = immer anzeigen)
function ns.GetThreshold(spellID)
    if not ns.db then return nil end
    if ns.db.showRanks and ns.db.rankThresholds[spellID] then
        return ns.db.rankThresholds[spellID]
    end
    local name = ns.GetSpellName(spellID)
    return name and ns.db.thresholds[name] or nil
end

---------------------------------------------------------------------------
-- Aktionsbuttons
---------------------------------------------------------------------------
local BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}

local buttons = {}
ns.buttonSources = {}

local LAB_NAMES = {
    "LibActionButton-1.0",
    "LibActionButton-1.0-ElvUI",
    "LibActionButton-1.0-EllesmereUI",
}

-- Prüft, ob ein beliebiger Frame wie ein Aktionsbutton aussieht
local function LooksLikeActionButton(f)
    if f._state_type or f._state_action then return true end
    if type(f.action) == "number" then return true end
    if f.GetAttribute then
        local ok, t = pcall(f.GetAttribute, f, "type")
        if ok and t == "action" then return true end
        local ok2, a = pcall(f.GetAttribute, f, "action")
        if ok2 and type(a) == "number" then return true end
    end
    return false
end

local function CollectButtons()
    wipe(buttons)
    wipe(ns.buttonSources)
    local seen = {}
    local function add(b, source)
        if b and not seen[b] then
            seen[b] = true
            buttons[#buttons + 1] = b
            ns.buttonSources[source] = (ns.buttonSources[source] or 0) + 1
        end
    end

    -- 1) Blizzard-Leisten
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do add(_G[prefix .. i], "Blizzard") end
    end

    -- 2) LibActionButton (ElvUI, Bartender & viele UI-Pakete)
    if LibStub then
        for _, libName in ipairs(LAB_NAMES) do
            local lab = LibStub(libName, true)
            if lab then
                local list = (lab.GetAllButtons and lab:GetAllButtons()) or lab.buttonRegistry or {}
                for k, v in pairs(list) do
                    add(type(k) == "table" and k or v, libName)
                end
            end
        end
    end

    -- 3) Alles andere, was wie ein Aktionsbutton aussieht (eigene UI-Pakete)
    if EnumerateFrames then
        local f = EnumerateFrames()
        while f do
            if not seen[f] and not (f.IsForbidden and f:IsForbidden())
                and f.IsObjectType and (f:IsObjectType("CheckButton") or f:IsObjectType("Button")) then
                local ok, yes = pcall(LooksLikeActionButton, f)
                if ok and yes then add(f, "Other") end
            end
            f = EnumerateFrames(f)
        end
    end
end
ns.CollectButtons = CollectButtons

local function GetActionSlot(button)
    -- LibActionButton
    if button._state_type == "action" and type(button._state_action) == "number" then
        return button._state_action
    end
    local action = button.action
    if type(action) ~= "number" or action == 0 then
        if button.CalculateAction then
            local ok, a = pcall(button.CalculateAction, button)
            if ok and type(a) == "number" then action = a end
        end
    end
    if (type(action) ~= "number" or action == 0) and SecureButton_GetModifiedAttribute then
        local ok, a = pcall(SecureButton_GetModifiedAttribute, button, "action")
        if ok and type(a) == "number" then action = a end
    end
    if (type(action) ~= "number" or action == 0) and button.GetAttribute then
        local ok, a = pcall(button.GetAttribute, button, "action")
        if ok and type(a) == "number" then action = a end
    end
    if (type(action) ~= "number" or action == 0) and ActionButton_GetPagedID then
        local ok, a = pcall(ActionButton_GetPagedID, button)
        if ok and type(a) == "number" then action = a end
    end
    return (type(action) == "number") and action or nil
end

local function GetSpellFromSlot(slot)
    if not slot or slot == 0 or not HasAction(slot) then return nil end
    local actionType, id, subType = GetActionInfo(slot)
    if actionType == "spell" then
        return id
    elseif actionType == "macro" then
        if subType == "spell" and id then return id end
        if GetMacroSpell and id then return GetMacroSpell(id) end
    end
    return nil
end

local function GetButtonSpell(button)
    -- LibActionButton-Buttons mit direktem Zauber/Makro statt Aktionsplatz
    local st = button._state_type
    if st == "spell" and type(button._state_action) == "number" then
        return button._state_action
    elseif st == "macro" and button._state_action and GetMacroSpell then
        return GetMacroSpell(button._state_action)
    end
    return GetSpellFromSlot(GetActionSlot(button))
end

---------------------------------------------------------------------------
-- Anzeige
--
-- WoW Forever liefert das Spieler-Mana als "Secret Value": Addons dürfen
-- damit nicht rechnen. StatusBars akzeptieren Secret Values aber.
-- Deshalb gibt es pro Button unsichtbare Schwellen-Leisten (Kosten*1,
-- Kosten*2, ...). Jede Zahl k steckt in einem Clip-Rahmen, der nur dann
-- breit ist, wenn Schwelle k erreicht und Schwelle k+1 noch nicht erreicht
-- ist. So zeichnet das Spiel genau die passende Zahl, ohne dass das Addon
-- den Wert je kennt. Ist das Mana lesbar, wird ganz normal gerechnet.
---------------------------------------------------------------------------
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local BAR_TEX = "Interface\\Buttons\\WHITE8X8"

local function SetupFont(fs, scale)
    local size = floor(ns.db.fontSize * (scale or 1) + 0.5)
    if fs.rccSize ~= size then
        if not fs:SetFont(STANDARD_TEXT_FONT or DEFAULT_FONT, size, "OUTLINE") then
            fs:SetFont(DEFAULT_FONT, size, "OUTLINE")
        end
        fs.rccSize = size
    end
end
ns.SetupFont = SetupFont

local function ApplyColor(fs, k)
    if ns.db.warnColors and k == 0 then
        fs:SetTextColor(1, 0.2, 0.2)
    elseif ns.db.warnColors and k <= 2 then
        fs:SetTextColor(1, 0.82, 0)
    else
        local c = ns.db.color
        fs:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
    end
end
ns.ApplyColor = ApplyColor

local function ColorKey()
    local c = ns.db.color
    return (ns.db.warnColors and "w" or "n") .. (c.r or 1) .. ":" .. (c.g or 1) .. ":" .. (c.b or 1)
end

---------------------------------------------------------------------------
-- Position
-- Der Halter liegt über der ganzen Buttonbreite (plus Rand, damit die Zahl
-- auch etwas überstehen darf). Vertikal hängt er oben, mittig oder unten am
-- Button, horizontal wird der Text links, mittig oder rechts darin verankert.
---------------------------------------------------------------------------
local function SplitPoint(point)
    point = point or "BOTTOMRIGHT"
    local v = point:find("TOP") and "TOP" or (point:find("BOTTOM") and "BOTTOM") or ""
    local hz = point:find("LEFT") and "LEFT" or (point:find("RIGHT") and "RIGHT") or ""
    return v, hz
end
ns.SplitPoint = SplitPoint

local function AnchorText(fs, h)
    local hz = h.lHz or "RIGHT"
    local pt = (hz ~= "") and hz or "CENTER"
    local x
    if hz == "RIGHT" then
        x = -(h.lMargin or 0) + (h.lOx or 0)
    elseif hz == "LEFT" then
        x = (h.lMargin or 0) + (h.lOx or 0)
    else
        x = h.lOx or 0
    end
    fs:ClearAllPoints()
    fs:SetPoint(pt, h, pt, x, 0)
    fs:SetJustifyH(pt == "CENTER" and "CENTER" or pt)
end
ns.AnchorText = AnchorText

function ns.LayoutHolder(button, h, scale, extraY)
    scale = scale or 1
    extraY = extraY or 0
    local w, bh = button:GetWidth(), button:GetHeight()
    if not w or w <= 0 then w, bh = 36, 36 end
    local key = table.concat({ w, bh, ns.db.point, ns.db.ox, ns.db.oy, ns.db.fontSize, scale, extraY }, ":")
    if h.lKey == key then return end
    h.lKey = key

    local v, hz = SplitPoint(ns.db.point)
    local margin = w * 0.6
    local y = (ns.db.oy or 0) * bh
    if v == "BOTTOM" then y = y + extraY end

    h.lHz, h.lMargin, h.lOx = hz, margin, (ns.db.ox or 0) * w
    h:ClearAllPoints()
    h:SetHeight(ns.db.fontSize * scale + 4)
    local lp = (v ~= "") and (v .. "LEFT") or "LEFT"
    local rp = (v ~= "") and (v .. "RIGHT") or "RIGHT"
    h:SetPoint(lp, button, lp, -margin, y)
    h:SetPoint(rp, button, rp, margin, y)

    if h.text then AnchorText(h.text, h) end
    if h.clips then
        for k = 0, #h.clips do
            local c = h.clips[k]
            if c then AnchorText(c.text, h) end
        end
    end
end

local function GetHolder(button)
    local h = button.RCCHolder
    if not h then
        h = CreateFrame("Frame", nil, button)
        h:SetFrameLevel(button:GetFrameLevel() + 5)
        h.bars, h.clips = {}, {}
        h.text = h:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.RCCHolder = h
    end

    -- Liegt bereits eine Reagenzien-Zahl unten am Button, rutschen wir darüber
    local extraY = 0
    local count = button.Count
    if count and count:IsShown() then
        local ok, txt = pcall(count.GetText, count)
        if ok and type(txt) == "string" and not IsSecret(txt) and txt ~= "" then
            extraY = ns.db.fontSize
        end
    end
    ns.LayoutHolder(button, h, 1, extraY)
    return h
end

local function GetBar(h, k)
    local bar = h.bars[k]
    if not bar then
        bar = CreateFrame("StatusBar", nil, h)
        bar:SetAllPoints(h)
        bar:SetOrientation("HORIZONTAL")
        bar:SetStatusBarTexture(BAR_TEX)
        bar:SetStatusBarColor(0, 0, 0, 0)
        h.bars[k] = bar
    end
    return bar
end

local function GetClip(h, k)
    local clip = h.clips[k]
    if not clip then
        clip = CreateFrame("Frame", nil, h)
        clip:SetClipsChildren(true)
        local fs = clip:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        AnchorText(fs, h)
        clip.text = fs
        h.clips[k] = clip
    end
    return clip
end

-- Max. Anzahl, die gezeichnet wird (bestimmt die Zahl der Schwellen-Leisten)
local function GetCap(cost)
    local limit = ns.db.maxCount or 50
    local ok, maxMana = pcall(UnitPowerMax, "player", MANA)
    if ok and type(maxMana) == "number" and not IsSecret(maxMana) and maxMana > 0 then
        local c = floor(maxMana / cost)
        if c < 1 then c = 1 end
        if c <= limit then return c, false end
    end
    return limit, true
end

local function ConfigureBands(h, cost, threshold)
    local cap, plus = GetCap(cost)
    -- Mit Schwelle reicht eine Stufe darüber: sie sammelt alles Höhere und bleibt verborgen
    if threshold and threshold < cap then cap, plus = threshold + 1, true end
    if h.cfgCost == cost and h.cfgCap == cap and h.cfgPlus == plus and h.cfgThreshold == threshold
        and h.cfgSize == ns.db.fontSize and h.cfgZero == ns.db.showZero
        and h.cfgColor == ColorKey() then
        return
    end

    for k = 1, cap do
        local bar = GetBar(h, k)
        bar:SetMinMaxValues(cost * k - 1, cost * k)
        bar:Show()
    end
    for k = cap + 1, #h.bars do h.bars[k]:Hide() end

    for k = 0, cap do
        local clip = GetClip(h, k)
        clip:ClearAllPoints()
        clip:SetPoint("TOP", h, "TOP")
        clip:SetPoint("BOTTOM", h, "BOTTOM")
        -- rechte Kante: Schwelle k erreicht?
        if k == 0 then
            clip:SetPoint("RIGHT", h, "RIGHT")
        else
            clip:SetPoint("RIGHT", h.bars[k]:GetStatusBarTexture(), "RIGHT")
        end
        -- linke Kante: Schwelle k+1 erreicht?
        if k == cap then
            clip:SetPoint("LEFT", h, "LEFT")
        else
            clip:SetPoint("LEFT", h.bars[k + 1]:GetStatusBarTexture(), "RIGHT")
        end
        SetupFont(clip.text)
        clip.text:SetText((k == cap and plus) and (k .. "+") or tostring(k))
        ApplyColor(clip.text, k)
        clip:SetShown((k > 0 or ns.db.showZero) and (not threshold or k <= threshold))
    end
    for k = cap + 1, #h.clips do h.clips[k]:Hide() end
    -- Index 0 liegt nicht im Array-Teil, deshalb separat behandeln
    if h.clips[0] then h.clips[0]:SetShown(ns.db.showZero) end

    h.cfgCost, h.cfgCap, h.cfgPlus, h.cfgThreshold = cost, cap, plus, threshold
    h.cfgSize, h.cfgZero, h.cfgColor = ns.db.fontSize, ns.db.showZero, ColorKey()
end

local function HideBands(h)
    for k = 0, #h.clips do
        if h.clips[k] then h.clips[k]:Hide() end
    end
    for k = 1, #h.bars do h.bars[k]:Hide() end
    h.cfgCost = nil
end

local function UpdateButton(button, mana, rawMana)
    local cost, threshold
    if rawMana ~= nil then
        local spellID = GetButtonSpell(button)
        if spellID and ns.IsSpellShown(spellID) then
            local c = ns.GetManaCost(spellID)
            if c and c > 0 then cost, threshold = c, ns.GetThreshold(spellID) end
        end
    end

    if not cost then
        if button.RCCHolder then button.RCCHolder:Hide() end
        return
    end

    local h = GetHolder(button)

    if mana then
        -- Mana ist lesbar: einfach rechnen
        HideBands(h)
        local count = floor(mana / cost)
        if (count > 0 or ns.db.showZero) and (not threshold or count <= threshold) then
            SetupFont(h.text)
            h.text:SetText(count)
            ApplyColor(h.text, count)
            h.text:Show()
        else
            h.text:Hide()
        end
    else
        -- Mana ist ein Secret Value: Schwellen-Leisten
        h.text:Hide()
        ConfigureBands(h, cost, threshold)
        for k = 1, h.cfgCap do
            h.bars[k]:SetValue(rawMana)
        end
    end
    h:Show()
end

function ns.UpdateAll()
    if not ns.db then return end
    local mana, rawMana
    if ns.db.enabled then
        local ok, v = pcall(UnitPower, "player", MANA)
        if ok and v ~= nil then
            rawMana = v
            if not IsSecret(v) then mana = v end
        end
    end
    ns.manaIsSecret = rawMana ~= nil and mana == nil
    for i = 1, #buttons do
        local ok, err = pcall(UpdateButton, buttons[i], mana, rawMana)
        if not ok then ns.lastUpdateError = err end
    end
end

local pending = false
function ns.RequestUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        ns.UpdateAll()
    end)
end

---------------------------------------------------------------------------
-- Datenbank
---------------------------------------------------------------------------
local function InitDB()
    RemainingCastCountDB = RemainingCastCountDB or {}
    for k, v in pairs(ns.defaults) do
        if RemainingCastCountDB[k] == nil then
            if type(v) == "table" then
                local t = {}
                for kk, vv in pairs(v) do t[kk] = vv end
                RemainingCastCountDB[k] = t
            else
                RemainingCastCountDB[k] = v
            end
        end
    end
    ns.db = RemainingCastCountDB
end

---------------------------------------------------------------------------
-- Slash-Befehl & Addon-Icon
---------------------------------------------------------------------------
local function Debug()
    local p = ns.Print
    CollectButtons()
    local okMana, rawMana = pcall(UnitPower, "player", MANA)
    p(("Buttons found: %d | Mana: %s (%s) | enabled: %s"):format(
        #buttons,
        okMana and (IsSecret(rawMana) and "SECRET" or tostring(rawMana)) or ("error: " .. tostring(rawMana)),
        tostring(GetPlayerMana()),
        tostring(ns.db.enabled)))

    local src = {}
    for k, v in pairs(ns.buttonSources) do src[#src + 1] = k .. "=" .. v end
    p("Sources: " .. (#src > 0 and table.concat(src, ", ") or "none"))

    local shown = 0
    for _, b in ipairs(buttons) do
        -- nur sichtbare Buttons mit Zauber, damit man sieht, was auf dem Bildschirm ist
        local spellID = b:IsVisible() and GetButtonSpell(b)
        if spellID then
            local slot = GetActionSlot(b)
            local cost = ns.GetManaCost(spellID)
            local err = ns.lastCostError[spellID]
            local name = b:GetName() or (b:GetParent() and b:GetParent():GetName() and (b:GetParent():GetName() .. ".<unnamed>")) or tostring(b)
            p(("%s | slot=%s lab=%s | spell=%s (%s) | cost=%s%s | on=%s | threshold=%s | display=%s"):format(
                name, tostring(slot), tostring(b._state_type),
                tostring(spellID), tostring(ns.GetSpellName(spellID)),
                tostring(cost), err and (" [API: " .. err .. "]") or "",
                tostring(ns.IsSpellShown(spellID)), tostring(ns.GetThreshold(spellID)),
                b.RCCHolder and (b.RCCHolder:IsVisible() and ("visible, steps=" .. tostring(b.RCCHolder.cfgCap)) or "hidden") or "none"))
            shown = shown + 1
            if shown >= 10 then break end
        end
    end
    if shown == 0 then p("No visible action buttons with spells found.") end
    ns.lastUpdateError = nil
    ns.UpdateAll()
    local okMax, maxMana = pcall(UnitPowerMax, "player", MANA)
    p(("Mode: %s | Max mana: %s"):format(ns.manaIsSecret and "secret (threshold bars)" or "direct",
        okMax and (IsSecret(maxMana) and "SECRET" or tostring(maxMana)) or "error"))
    if ns.lastUpdateError then p("Update error: " .. tostring(ns.lastUpdateError)) end
end

SLASH_REMAININGCASTCOUNT1 = "/rcc"
SlashCmdList.REMAININGCASTCOUNT = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "debug" then
        Debug()
        ns.UpdateAll()
        return
    end
    ns.OpenOptions()
end

function RemainingCastCount_OnAddonCompartmentClick()
    ns.OpenOptions()
end

function RemainingCastCount_OnAddonCompartmentEnter(_, button)
    local owner = (type(button) == "table" and button) or AddonCompartmentFrame or UIParent
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("RemainingCastCount")
    GameTooltip:AddLine(L.CLICK_OPEN_SETTINGS, 1, 1, 1)
    GameTooltip:Show()
end

function RemainingCastCount_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")

local function SafeRegister(event)
    pcall(f.RegisterEvent, f, event)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        CollectButtons()
        ns.InitOptions()
        ns.InitMinimapButton()

        pcall(self.RegisterUnitEvent, self, "UNIT_POWER_FREQUENT", "player")
        pcall(self.RegisterUnitEvent, self, "UNIT_MAXPOWER", "player")
        pcall(self.RegisterUnitEvent, self, "UNIT_DISPLAYPOWER", "player")
        pcall(self.RegisterUnitEvent, self, "UNIT_AURA", "player")
        SafeRegister("PLAYER_ENTERING_WORLD")
        SafeRegister("ACTIONBAR_SLOT_CHANGED")
        SafeRegister("ACTIONBAR_PAGE_CHANGED")
        SafeRegister("UPDATE_BONUS_ACTIONBAR")
        SafeRegister("UPDATE_SHAPESHIFT_FORM")
        SafeRegister("SPELLS_CHANGED")
        SafeRegister("PLAYER_LEVEL_UP")
        SafeRegister("PLAYER_REGEN_ENABLED")
        SafeRegister("BAG_UPDATE_DELAYED")
        SafeRegister("UPDATE_MACROS")

        ns.RequestUpdate()
        return
    end

    if event == "UNIT_POWER_FREQUENT" and arg2 ~= "MANA" then
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- UI-Pakete erzeugen ihre Leisten oft erst nach dem Login
        CollectButtons()
        for _, delay in ipairs({ 1, 3, 8 }) do
            C_Timer.After(delay, function()
                CollectButtons()
                ns.UpdateAll()
            end)
        end
    end

    if event == "SPELLS_CHANGED" and ns.RefreshOptionsList then
        ns.RefreshOptionsList()
    end

    ns.RequestUpdate()
end)
