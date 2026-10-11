-- luacheck config: the WoW API names this addon reads, plus the globals it defines.
-- When the addon starts using a new WoW API name, add it to read_globals.
std = "lua51"
max_line_length = 160
max_string_line_length = false
codes = true
exclude_files = { "**/Libs/**", "**/libs/**", ".release/**" }
ignore = {
    "212", -- unused arguments: event handlers and callbacks take fixed signatures
}
read_globals = {
    "ActionButton_GetPagedID",
    "AddonCompartmentFrame",
    "BackdropTemplateMixin",
    "BOOKTYPE_SPELL",
    "CreateFrame",
    "C_Spell",
    "C_SpellBook",
    "C_Timer",
    "C_TooltipInfo",
    "Enum",
    "EnumerateFrames",
    "GameTooltip",
    "GameTooltip_Hide",
    "GetActionInfo",
    "GetCursorPosition",
    "GetLocale",
    "GetMacroSpell",
    "GetNumSpellTabs",
    "GetSpellBookItemInfo",
    "GetSpellInfo",
    "GetSpellPowerCost",
    "GetSpellSubtext",
    "GetSpellTabInfo",
    "HasAction",
    "HideUIPanel",
    "InterfaceOptionsFrame_OpenToCategory",
    "InterfaceOptions_AddCategory",
    "IsPassiveSpell",
    "issecretvalue",
    "LibStub",
    "Minimap",
    "SecureButton_GetModifiedAttribute",
    "Settings",
    "SettingsPanel",
    "STANDARD_TEXT_FONT",
    "UIParent",
    "UnitPower",
    "UnitPowerMax",
    "wipe",
}
globals = {
    "RemainingCastCountDB",
    "RemainingCastCount_OnAddonCompartmentClick",
    "RemainingCastCount_OnAddonCompartmentEnter",
    "RemainingCastCount_OnAddonCompartmentLeave",
    "SLASH_REMAININGCASTCOUNT1",
    "SlashCmdList",
    "ColorPickerFrame", -- the old-style color picker is set up through its fields
}
