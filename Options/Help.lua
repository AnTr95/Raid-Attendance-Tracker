local addon = ...;
local L = RAT_Locals;
local RAT = RAT;
local _G = _G;

local helpOptions = CreateFrame("Frame", "RAT_Help_Options", InterfaceOptionsFramePanelContainer);
helpOptions.name = "Help/Commands";
helpOptions.parent = "Raid Attendance Tracker";
helpOptions:Hide();

local addonText = helpOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
addonText:SetText(L.ADDON_FULL);
addonText:SetPoint("TOP", 0, -16);

local version = helpOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
version:SetText(L.ADDON_VERSION);
version:SetPoint("TOPLEFT", 450, -32);

local author = helpOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
author:SetText(L.ADDON_AUTHOR);
author:SetPoint("TOPLEFT", 450, -16);

local title = helpOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetText(L.OPTIONS_HELP_TITLE);
title:SetPoint("TOPLEFT", 16, -16);

local infoText = helpOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
infoText:SetText(L.SETUP_COMPLETED_INFO_TEXT1 .. "\n\n" .. L.SETUP_COMPLETED_INFO_TEXT2);
infoText:SetPoint("TOPLEFT", 40, -85);
infoText:SetWordWrap(true);
infoText:SetJustifyV("TOP");
infoText:SetJustifyH("LEFT");
infoText:SetSize(520, 420);

InterfaceOptions_AddCategory(helpOptions);