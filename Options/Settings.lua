local addon = ...;
local L = RAT_Locals;
local RAT = RAT;
local _G = _G;

local settingsOptions = CreateFrame("Frame", "RAT_Settings_Options", InterfaceOptionsFramePanelContainer);
settingsOptions.name = "Settings";
settingsOptions.parent = "Raid Attendance Tracker";
settingsOptions:Hide();

local addonText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
addonText:SetText(L.ADDON_FULL);
addonText:SetPoint("TOP", 0, -16);

local version = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
version:SetText(L.ADDON_VERSION);
version:SetPoint("TOPLEFT", 450, -32);

local author = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
author:SetText(L.ADDON_AUTHOR);
author:SetPoint("TOPLEFT", 450, -16);

local title = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetText(L.OPTIONS_SETTINGS_TITLE);
title:SetPoint("TOPLEFT", 16, -16);

local infoText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
infoText:SetText(L.SETUP_SETTINGS_INFO_TEXT);
infoText:SetPoint("TOPLEFT", 40, -85);
infoText:SetWordWrap(true);
infoText:SetJustifyV("TOP");
infoText:SetJustifyH("LEFT");
infoText:SetSize(520, 320);

local sortRankText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontWhite");
sortRankText:SetText(L.OPTIONS_SORT_RANK_TEXT);
sortRankText:SetPoint("TOPLEFT", 60, -175);

local sortRankHelp = CreateFrame("Button", nil, settingsOptions, "UIPanelInfoButton");
sortRankHelp:SetPoint("TOPLEFT", 40, -172);
sortRankHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_SORT_RANKS_TOOLTIP);
	GameTooltip:Show();
end);
sortRankHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end);

local sortRankMenu = CreateFrame("Button", nil, settingsOptions, "UIDropDownMenuTemplate");
sortRankMenu:SetPoint("TOPLEFT", 200, -165);

local rankAlgos = {"RAT-Algorithm", "Highest Percent", "Most Points"};

local function sortRankState_OnClick(self)
	UIDropDownMenu_SetSelectedID(sortRankMenu, self:GetID());
	RAT_SavedOptions.RankingAlgo = self:GetText();
end

local function Initialize_SortRankState(self, level)
	local info = UIDropDownMenu_CreateInfo();
	for k,v in pairs(rankAlgos) do
		info = UIDropDownMenu_CreateInfo();
		info.text = v;
		info.value = v;
		info.func = sortRankState_OnClick
		UIDropDownMenu_AddButton(info, level);
	end
end

UIDropDownMenu_SetWidth(sortRankMenu, 110);
UIDropDownMenu_SetButtonWidth(sortRankMenu, 110);
UIDropDownMenu_JustifyText(sortRankMenu, "CENTER");
UIDropDownMenu_Initialize(sortRankMenu, Initialize_SortRankState);

local frequencyText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontWhite");
frequencyText:SetPoint("TOPLEFT", 60, -205);
frequencyText:SetText(L.OPTIONS_FREQUENCY_TEXT);

local frequencyHelp = CreateFrame("Button", nil, settingsOptions, "UIPanelInfoButton");
frequencyHelp:SetPoint("TOPLEFT", 40, -202);
frequencyHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_FREQUENCY_TOOLTIP);
	GameTooltip:Show();
end);
frequencyHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end)
local frequencyEditBoxLastValue = 60;
local frequencyEditBox = CreateFrame("EditBox", nil, settingsOptions, "InputBoxTemplate");
frequencyEditBox:SetAutoFocus(false);
frequencyEditBox:SetSize(30, 20);
frequencyEditBox:SetPoint("TOPLEFT", 290, -202);
frequencyEditBox:SetScript("OnEscapePressed", function(self)
	self:SetText(frequencyEditBoxLastValue);
	self:ClearFocus();
end);
frequencyEditBox:SetScript("OnTextChanged", function(self)
	local value = self:GetNumber();
	if (value <= 0) then
		self:SetText(string.sub(self:GetText(), 1, string.len(self:GetText())-1));
	end
end);
frequencyEditBox:SetScript("OnEnterPressed", function(self)
	RAT_SavedOptions.Frequency = self:GetNumber();
	frequencyEditBoxLastValue = self:GetNumber();
	self:ClearFocus();
end);

local awardStartText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontWhite");
awardStartText:SetText(L.OPTIONS_AWARD_START_TEXT);
awardStartText:SetPoint("TOPLEFT", 60, -235);

local awardStartHelp = CreateFrame("Button", nil, settingsOptions, "UIPanelInfoButton");
awardStartHelp:SetPoint("TOPLEFT", 40, -232);
awardStartHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_AWARD_RAID_START_TOOLTIP);
	GameTooltip:Show();
end);
awardStartHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end);
local awardStartCheckButton = CreateFrame("CheckButton", nil, settingsOptions, "UICheckButtonTemplate");
awardStartCheckButton:SetSize(20,20);
awardStartCheckButton:SetPoint("TOPLEFT", 300, -232);
awardStartCheckButton:SetScript("OnClick", function(self)
	local checked = self:GetChecked();
	if (checked) then
		RAT_SavedOptions.AwardStart = true;
	else
		RAT_SavedOptions.AwardStart = false;
	end
end);


local punishCalendarText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontWhite");
punishCalendarText:SetText(L.OPTIONS_PUNISH_CALENDAR_TEXT);
punishCalendarText:SetPoint("TOPLEFT", 60, -265);

local punishCalendarHelp = CreateFrame("Button", nil, settingsOptions, "UIPanelInfoButton");
punishCalendarHelp:SetPoint("TOPLEFT", 40, -262);
punishCalendarHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_PUNISH_CALENDAR_TOOLTIP);
	GameTooltip:Show();
end);
punishCalendarHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end);

local punishCalendarCheckButton = CreateFrame("CheckButton", nil, settingsOptions, "UICheckButtonTemplate");
punishCalendarCheckButton:SetSize(20,20);
punishCalendarCheckButton:SetPoint("TOPLEFT", 300, -262);
punishCalendarCheckButton:SetScript("OnClick", function(self)
	local checked = self:GetChecked();
	if (checked) then
		RAT_SavedOptions.PunishCalendar = true;
	else
		RAT_SavedOptions.PunishCalendar = false;
	end
end);
punishCalendarCheckButton:Disable();

local minimapModeText = settingsOptions:CreateFontString(nil, "ARTWORK", "GameFontWhite");
minimapModeText:SetText(L.OPTIONS_MINIMAP_MODE_TEXT);
minimapModeText:SetPoint("TOPLEFT", 60, -295);

local minimapStateMenu = CreateFrame("Button", nil, settingsOptions, "UIDropDownMenuTemplate");
minimapStateMenu:SetPoint("TOPLEFT", 200, -285);

local minimapStates = {"Always", "On Hover", "Never"};

local function minimapState_OnClick(self)
	UIDropDownMenu_SetSelectedID(minimapStateMenu, self:GetID());
	local state = self:GetText();
	RAT_SavedOptions.MinimapMode = state;
	if (state == "Always") then
		RAT_MinimapButton:Show();
	else
		RAT_MinimapButton:Hide();
	end
end

local function Initialize_MinimapState(self, level)
	local info = UIDropDownMenu_CreateInfo()
	for k,v in pairs(minimapStates) do
	  info = UIDropDownMenu_CreateInfo()
	  info.text = v
	  info.value = v
	  info.func = minimapState_OnClick
	  UIDropDownMenu_AddButton(info, level)
	end
end

UIDropDownMenu_SetWidth(minimapStateMenu, 110)
UIDropDownMenu_SetButtonWidth(minimapStateMenu, 110)
UIDropDownMenu_JustifyText(minimapStateMenu, "CENTER")
UIDropDownMenu_Initialize(minimapStateMenu, Initialize_MinimapState)

settingsOptions:SetScript("OnShow", function()
	Initialize_SortRankState();
	UIDropDownMenu_SetSelectedName(sortRankMenu, RAT_SavedOptions.RankingAlgo);
	punishCalendarCheckButton:SetChecked(RAT_SavedOptions.PunishCalendar);
	awardStartCheckButton:SetChecked(RAT_SavedOptions.AwardStart);
	frequencyEditBox:SetText(RAT_SavedOptions.Frequency);
	Initialize_MinimapState();
	UIDropDownMenu_SetSelectedName(minimapStateMenu, RAT_SavedOptions.MinimapMode);
end);

InterfaceOptions_AddCategory(settingsOptions);