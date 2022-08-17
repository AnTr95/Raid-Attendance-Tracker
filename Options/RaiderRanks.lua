local addon = ...;
local L = RAT_Locals;
local RAT = RAT;
local _G = _G;
local rrFrames = nil;

local rrOptions = CreateFrame("Frame", "RAT_RR_Options", InterfaceOptionsFramePanelContainer);
rrOptions.name = "Raider Ranks Settings";
rrOptions.parent = "Raid Attendance Tracker";
rrOptions:Hide();

local addonText = rrOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
addonText:SetText(L.ADDON_FULL);
addonText:SetPoint("TOP", 0, -16);

local version = rrOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
version:SetText(L.ADDON_VERSION);
version:SetPoint("TOPLEFT", 450, -32);

local author = rrOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
author:SetText(L.ADDON_AUTHOR);
author:SetPoint("TOPLEFT", 450, -16);

local title = rrOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetText(L.OPTIONS_RAIDER_RANKS_TITLE);
title:SetPoint("TOPLEFT", 16, -16);

local infoText = rrOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
infoText:SetText(L.SETUP_RR_INFO_TEXT);
infoText:SetPoint("TOPLEFT", 40, -85);
infoText:SetWordWrap(true);
infoText:SetJustifyV("TOP");
infoText:SetJustifyH("LEFT");
infoText:SetSize(520, 320);

local rankText = rrOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal");
rankText:SetText(L.OPTIONS_RANK_TEXT);
rankText:SetPoint("TOPLEFT", 60, -175);

local scanRRButton = CreateFrame("Button", nil, rrOptions, "UIMenuButtonStretchTemplate");
scanRRButton:SetSize(130, 50);
scanRRButton:SetPoint("TOPLEFT", 50, -350);
scanRRButton:SetText(L.OPTIONS_SCAN_RR_BUTTON);
scanRRButton:SetScript("OnClick", function(self)
	RAT_SavedOptions.RaiderRanks = {};
	local ranks = RAT:SuggestRaiderRanks();
	local frame = nil;
	for index, rank in pairs(ranks) do
		if (not RAT:Contains(RAT_SavedOptions.RaiderRanks, rank)) then
			table.insert(RAT_SavedOptions.RaiderRanks, rank);
			frame = "RAT_RRO_Checkbox_" .. rank;
			_G[frame]:SetChecked(true);
		end
	end
	self:Hide();
end);

local function initRRFrames()
	if (not rrFrames) then
		rrFrames = {};
		local ranks = RAT:GetAllGuildRanks();
		for i = 1, #ranks do
			local text = rrOptions:CreateFontString("RAT_RRO_Text_" .. ranks[i], "ARTWORK", "GameFontWhite");
			text:SetText(ranks[i]);
			text:SetPoint("TOPLEFT", 60+((i+1)%2*150), -195-(math.floor((i-1)/2))*25);
			text:Hide();
			table.insert(rrFrames, text);
		end
		for i = 1, #ranks do
			local checkButton = CreateFrame("CheckButton", "RAT_RRO_Checkbox_" .. ranks[i], rrOptions, "UICheckButtonTemplate");
			checkButton:SetSize(20, 20);
			checkButton:SetPoint("TOPLEFT", 150+((i+1)%2*150), -190-(math.floor((i-1)/2))*25);
			checkButton:SetScript("OnClick", function(self)
				local checked = self:GetChecked();
				local exists = RAT:Contains(RAT_SavedOptions.RaiderRanks, ranks[i]);
				if (checked and not exists) then
					table.insert(RAT_SavedOptions.RaiderRanks, ranks[i]);
				elseif (not checked and exists) then
					table.remove(RAT_SavedOptions.RaiderRanks, exists);
				end
			end);
			checkButton:Hide();
			table.insert(rrFrames, checkButton);
		end
	end
end

local function showRRFrames()
	if (not rrFrames) then
		initRRFrames();
	end
	for index, frame in pairs(rrFrames) do
		frame:Show();
		local frameName = frame:GetName();
		if (string.find(frameName, "RAT_RRO_Checkbox_")) then
			frameName = string.sub(frameName, 18);
			if (RAT:Contains(RAT_SavedOptions.RaiderRanks, frameName)) then
				frame:SetChecked(true);
			else
				frame:SetChecked(false);
			end
		end
	end
end

local function hideRRFrames()
	if (rrFrames) then
		for index, frame in pairs(rrFrames) do
			frame:Hide();
		end
	end
end

rrOptions:SetScript("OnShow", function()
	showRRFrames();
end);

rrOptions:SetScript("OnHide", function()
	RAT:Sync();
end);

InterfaceOptions_AddCategory(rrOptions);