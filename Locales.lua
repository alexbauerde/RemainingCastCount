-- RemainingCastCount - Übersetzungen (EN = Fallback, DE)

local _, ns = ...

local enUS = {
    CLICK_OPEN_SETTINGS   = "Click to open the settings",
    MINIMAP_CLICK         = "Click: open settings",
    MINIMAP_DRAG          = "Drag: move button",

    SUBTITLE              = "Shows on your action buttons how many times you can still cast a spell with your current mana.",
    ENABLED               = "Addon enabled",
    ENABLED_TIP           = "Show or hide the numbers on all action buttons.",
    SHOW_ZERO             = "Show 0",
    SHOW_ZERO_TIP         = "Show a red 0 when you don't have enough mana for the spell.",
    MINIMAP_BUTTON        = "Minimap button",
    MINIMAP_BUTTON_TIP    = "Show the button on the minimap.",
    SHOW_RANKS            = "Show all spell ranks",
    SHOW_RANKS_TIP        = "Lists every rank separately so you can toggle each one. Off: one toggle per spell that applies to all ranks.",
    FONT_SIZE             = "Font size:",
    SPELLS                = "Spells",
    ALL_ON                = "All on",
    ALL_OFF               = "All off",
    NO_SPELLS             = "No spells with a mana cost found.",
    MANA                  = "Mana",
    NO_MANA_COST          = "no mana cost",

    POSITION_TITLE        = "Position (drag the number)",
    DRAG_TITLE            = "Drag the number",
    DRAG_TIP              = "Drag the number to where it should appear on your buttons.",
    FONT_COLOR            = "Font color",
    FONT_COLOR_TIP        = "Click to choose the font color",
    WARN_COLORS           = "Warning colors",
    WARN_COLORS_TIP       = "Show 0 in red and 1–2 in yellow. Off: all numbers use the font color.",
    DEFAULTS              = "Defaults",
    DEFAULTS_TIP          = "Reset position and color",

    THRESHOLD_HEADER      = "Threshold",
    THRESHOLD_TIP         = "Only show the number when it is this value or lower. Empty: always show.",
}

local deDE = {
    CLICK_OPEN_SETTINGS   = "Klicken, um die Einstellungen zu öffnen",
    MINIMAP_CLICK         = "Klick: Einstellungen öffnen",
    MINIMAP_DRAG          = "Ziehen: Button verschieben",

    SUBTITLE              = "Zeigt an deinen Aktionsbuttons, wie oft du einen Zauber mit deinem aktuellen Mana noch wirken kannst.",
    ENABLED               = "Addon aktiv",
    ENABLED_TIP           = "Zahlen an allen Aktionsbuttons ein-/ausblenden.",
    SHOW_ZERO             = "0 anzeigen",
    SHOW_ZERO_TIP         = "Eine rote 0 anzeigen, wenn das Mana für den Zauber nicht mehr reicht.",
    MINIMAP_BUTTON        = "Minimap-Button",
    MINIMAP_BUTTON_TIP    = "Den Button an der Minimap anzeigen.",
    SHOW_RANKS            = "Alle Zauberränge zeigen",
    SHOW_RANKS_TIP        = "Listet jeden Rang einzeln, sodass du ihn separat an- und abwählen kannst. Aus: ein Schalter pro Zauber, der für alle Ränge gilt.",
    FONT_SIZE             = "Schriftgröße:",
    SPELLS                = "Zauber",
    ALL_ON                = "Alle an",
    ALL_OFF               = "Alle aus",
    NO_SPELLS             = "Keine Zauber mit Manakosten gefunden.",
    MANA                  = "Mana",
    NO_MANA_COST          = "keine Manakosten",

    POSITION_TITLE        = "Position (Zahl ziehen)",
    DRAG_TITLE            = "Zahl ziehen",
    DRAG_TIP              = "Ziehe die Zahl an die Stelle, an der sie auf deinen Buttons stehen soll.",
    FONT_COLOR            = "Schriftfarbe",
    FONT_COLOR_TIP        = "Klicken, um die Schriftfarbe zu wählen",
    WARN_COLORS           = "Warnfarben",
    WARN_COLORS_TIP       = "0 in Rot und 1–2 in Gelb anzeigen. Aus: alle Zahlen in der Schriftfarbe.",
    DEFAULTS              = "Standard",
    DEFAULTS_TIP          = "Position und Farbe zurücksetzen",

    THRESHOLD_HEADER      = "Schwelle",
    THRESHOLD_TIP         = "Die Zahl erst anzeigen, wenn sie diesen Wert erreicht oder unterschreitet. Leer: immer anzeigen.",
}

local locales = { deDE = deDE }

-- Fallback: Englisch, und notfalls der Schlüssel selbst
ns.L = setmetatable(locales[GetLocale()] or {}, {
    __index = function(_, key)
        return enUS[key] or key
    end,
})
