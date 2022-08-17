local addon = ...;
local L = RAT_Locals;
local RAT = RAT;
local _G = _G;
local rtFrames = nil;

local rtOptions = CreateFrame("Frame", "RAT_RT_Options", InterfaceOptionsFramePanelContainer);
rtOptions.name = "Raid Times Settings";
rtOptions.parent = "Raid Attendance Tracker";
rtOptions:Hide();

local addonText = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
addonText:SetText(L.ADDON_FULL);
addonText:SetPoint("TOP", 0, -16);

local version = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
version:SetText(L.ADDON_VERSION);
version:SetPoint("TOPLEFT", 450, -32);

local author = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
author:SetText(L.ADDON_AUTHOR);
author:SetPoint("TOPLEFT", 450, -16);

local title = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetText(L.OPTIONS_RAID_TIMES_TITLE);
title:SetPoint("TOPLEFT", 16, -16);

local infoText = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
infoText:SetText(L.SETUP_RT_INFO_TEXT);
infoText:SetPoint("TOPLEFT", 40, -85);
infoText:SetWordWrap(true);
infoText:SetJustifyV("TOP");
infoText:SetJustifyH("LEFT");
infoText:SetSize(520, 320);

local timeZoneMenu = CreateFrame("Button", nil, rtOptions, "UIDropDownMenuTemplate");
timeZoneMenu:SetPoint("TOPLEFT", 200, -370);

local timeZones = {"UTC+0", "UTC+1", "UTC+2", "UTC+3", "UTC+4", "UTC+5", "UTC+6", "UTC+7", "UTC+8", "UTC+9", "UTC+10", "UTC+11", "UTC+12", "UTC-1", "UTC-2", "UTC-3", "UTC-4", "UTC-5", "UTC-6", "UTC-7", "UTC-8", "UTC-9", "UTC-10", "UTC-11", "UTC-12"};

local function timeZoneMenu_OnClick(self)
	UIDropDownMenu_SetSelectedID(timeZoneMenu, self:GetID());
	local prev = RAT_SavedData.TimeZone;
	RAT_SavedData.TimeZone = string.match(self:GetText(), "[%-]?[%d]+");
	if (prev and prev ~= RAT_SavedData.TimeZone) then
		RAT:SetNextAward(GetServerTime());
		RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward - GetServerTime()));
	end
end

local function Initialize_TimeZoneMenu(self, level)
	local info = UIDropDownMenu_CreateInfo();
	for k,v in pairs(timeZones) do
		info = UIDropDownMenu_CreateInfo();
		info.text = v;
		info.value = v;
		info.func = timeZoneMenu_OnClick
		UIDropDownMenu_AddButton(info, level);
	end
end

UIDropDownMenu_SetWidth(timeZoneMenu, 90);
UIDropDownMenu_SetButtonWidth(timeZoneMenu, 90);
UIDropDownMenu_JustifyText(timeZoneMenu, "CENTER");
UIDropDownMenu_Initialize(timeZoneMenu, Initialize_TimeZoneMenu);

local scanRTButton = CreateFrame("Button", nil, rtOptions, "UIMenuButtonStretchTemplate");
scanRTButton:SetSize(130,50);
scanRTButton:SetPoint("TOPLEFT", 50, -350);
scanRTButton:SetText(L.OPTIONS_SCAN_RT_BUTTON);
scanRTButton:SetScript("OnClick", function(self)
	local raidDays = RAT:SuggestRaidDays();
	RAT_SavedData.TimeZone = RAT:GetRealmTimeZone();
	for day, data in pairs(raidDays) do 
		RAT:AddRaidDay(day, tonumber(data.StartHour), tonumber(data.StartMinute), tonumber(data.FinishHour), tonumber(data.FinishMinute));
		local frameStart = "RAT_RTO_Start_" .. day;
		local frameFinish = "RAT_RTO_Finish_" .. day;
		_G[frameStart]:SetText(data.StartHour .. ":" .. data.StartMinute);
		_G[frameFinish]:SetText(data.FinishHour .. ":" .. data.FinishMinute);
	end
	if (string.find(RAT_SavedData.TimeZone, "-")) then
		UIDropDownMenu_SetSelectedName(timeZoneMenu, "UTC"..RAT_SavedData.TimeZone);
	else
		UIDropDownMenu_SetSelectedName(timeZoneMenu, "UTC+"..RAT_SavedData.TimeZone);
	end
	self:Hide();
end);

local dayText = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal");
dayText:SetText(L.OPTIONS_DAY_TEXT);
dayText:SetPoint("TOPLEFT", 80, -150);

local startText = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal");
startText:SetText(L.OPTIONS_START_TEXT);
startText:SetPoint("TOPLEFT", 220, -150);

local finishText = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal");
finishText:SetText(L.OPTIONS_FINISH_TEXT);
finishText:SetPoint("TOPLEFT", 280, -150);

local timeZoneText = rtOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal");
timeZoneText:SetText(L.OPTIONS_SERVER_TIMEZONE_TEXT);
timeZoneText:SetPoint("TOPLEFT", 220, -350);

local function initRTFrames()
	local weekdays = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
	if (not rtFrames) then
		rtFrames = {};
		for i = 1, 7 do
			local text = rtOptions:CreateFontString("RAT_RTO_Text_" .. weekdays[i], "ARTWORK", "GameFontWhite");
			text:SetText(weekdays[i]);
			text:SetPoint("TOPLEFT", 80, -170-((i-1)*25));
			text:Hide();
			table.insert(rtFrames, text);
		end
		for i = 1, 7 do
			local editBox = CreateFrame("EditBox", "RAT_RTO_Start_" .. weekdays[i], rtOptions, "InputBoxTemplate");
			editBox:SetPoint("TOPLEFT", 220, -165-((i-1)*25));
			editBox:SetSize(40,20);
			editBox:SetAutoFocus(false);
			editBox:SetScript("OnEnterPressed", function(self)
				local frame = "RAT_RTO_Finish_" .. weekdays[i];
				local otherText = _G[frame]:GetText();
				local text = self:GetText();
				if (text ~= "" and otherText ~= "") then
					if ((string.match(otherText, "[%d][%d][%.%-:][%d][%d]") and string.len(otherText) == 5) or (string.match(otherText, "[%d]+") and string.len(otherText) == 4)) then
						if ((string.match(text, "[%d][%d][%.%-:][%d][%d]") and string.len(text) == 5) or (string.match(text, "[%d]+") and string.len(text) == 4)) then
							local startHour = tonumber(string.match(text, "^[%d][%d]"));
							local startMinute = tonumber(string.match(text, "[%d][%d]$"));
							local finishHour = tonumber(string.match(otherText, "^[%d][%d]"));
							local finishMinute = tonumber(string.match(otherText, "[%d][%d]$"));
							if (startHour and startMinute and finishHour and finishMinute) then
								RAT:AddRaidDay(weekdays[i], startHour, startMinute, finishHour, finishMinute);
							end
						end
					end
				end
				if (i == 7) then
					frame = "RAT_RTO_Start_" .. weekdays[1];
				else
					frame = "RAT_RTO_Start_" .. weekdays[i+1];
				end
				_G[frame]:SetFocus();
			end);
			editBox:SetScript("OnTabPressed", function(self)
				local frame = "RAT_RTO_Finish_" .. weekdays[i];
				local otherText = _G[frame]:GetText();
				local text = self:GetText();
				if (text ~= "" and otherText ~= "") then
					if ((string.match(otherText, "[%d][%d][%.%-:][%d][%d]") and string.len(otherText) == 5) or (string.match(otherText, "[%d]+") and string.len(otherText) == 4)) then
						if ((string.match(text, "[%d][%d][%.%-:][%d][%d]") and string.len(text) == 5) or (string.match(text, "[%d]+") and string.len(text) == 4)) then
							local startHour = tonumber(string.match(text, "^[%d][%d]"));
							local startMinute = tonumber(string.match(text, "[%d][%d]$"));
							local finishHour = tonumber(string.match(otherText, "^[%d][%d]"));
							local finishMinute = tonumber(string.match(otherText, "[%d][%d]$"));
							if (startHour and startMinute and finishHour and finishMinute) then
								RAT:AddRaidDay(weekdays[i], startHour, startMinute, finishHour, finishMinute);
							end
						end
					end
				end
				_G[frame]:SetFocus();
			end);
			editBox:SetScript("OnEscapePressed", function(self)
				self:ClearFocus();
			end);
			editBox:SetScript("OnTextChanged", function(self)
				local text = self:GetText();
				if (not string.match(text, "[%d%.%-:]$")) then
					editBox:SetText(string.sub(text, 1, string.len(text)-1));
				end
				if (text == "") then
					local frameName = self:GetName();
					frameName = string.sub(frameName, 15);
					if (RAT:IsRaidDay(frameName)) then
						RAT:RemoveRaidDay(frameName);
					end
				end
			end);
			editBox:Hide();
			table.insert(rtFrames, editBox);
		end
		for i = 1, 7 do
			local editBox = CreateFrame("EditBox", "RAT_RTO_Finish_" .. weekdays[i], rtOptions, "InputBoxTemplate");
			editBox:SetPoint("TOPLEFT", 280, -165-((i-1)*25));
			editBox:SetSize(40,20);
			editBox:SetAutoFocus(false);
			editBox:SetScript("OnEnterPressed", function(self)
				local frame = "RAT_RTO_Start_" .. weekdays[i];
				local otherText = _G[frame]:GetText();
				local text = self:GetText();
				if (text ~= "" and otherText ~= "") then
					if ((string.match(otherText, "[%d][%d][%.%-:][%d][%d]") and string.len(otherText) == 5) or (string.match(otherText, "[%d]+") and string.len(otherText) == 4)) then
						if ((string.match(text, "[%d][%d][%.%-:][%d][%d]") and string.len(text) == 5) or (string.match(text, "[%d]+") and string.len(text) == 4)) then
							local finishHour = tonumber(string.match(text, "^[%d][%d]"));
							local finishMinute = tonumber(string.match(text, "[%d][%d]$"));
							local startHour = tonumber(string.match(otherText, "^[%d][%d]"));
							local startMinute = tonumber(string.match(otherText, "[%d][%d]$"));
							if (startHour and startMinute and finishHour and finishMinute) then
								RAT:AddRaidDay(weekdays[i], startHour, startMinute, finishHour, finishMinute);
							end
						end
					end
				end
				if (i == 7) then
					frame = "RAT_RTO_Finish_" .. weekdays[1];
				else
					frame = "RAT_RTO_Finish_" .. weekdays[i+1];
				end
				_G[frame]:SetFocus();
			end);
			editBox:SetScript("OnTabPressed", function(self)
				local frame = "RAT_RTO_Start_" .. weekdays[i];
				local otherText = _G[frame]:GetText();
				local text = self:GetText();
				if (text ~= "" and otherText ~= "") then
					if ((string.match(otherText, "[%d][%d][%.%-:][%d][%d]") and string.len(otherText) == 5) or (string.match(otherText, "[%d]+") and string.len(otherText) == 4)) then
						if ((string.match(text, "[%d][%d][%.%-:][%d][%d]") and string.len(text) == 5) or (string.match(text, "[%d]+") and string.len(text) == 4)) then
							local finishHour = tonumber(string.match(text, "^[%d][%d]"));
							local finishMinute = tonumber(string.match(text, "[%d][%d]$"));
							local startHour = tonumber(string.match(otherText, "^[%d][%d]"));
							local startMinute = tonumber(string.match(otherText, "[%d][%d]$"));
							if (startHour and startMinute and finishHour and finishMinute) then
								RAT:AddRaidDay(weekdays[i], startHour, startMinute, finishHour, finishMinute);
							end
						end
					end
				end
				_G[frame]:SetFocus();
			end);
			editBox:SetScript("OnEscapePressed", function(self)
				self:ClearFocus();
			end);
			editBox:SetScript("OnTextChanged", function(self)
				local text = self:GetText();
				if (not string.match(text, "[%d%.%-:]$")) then
					editBox:SetText(string.sub(text, 1, string.len(text)-1));
				end
				if (text == "") then
					local frameName = self:GetName();
					frameName = string.sub(frameName, 16);
					if (RAT:IsRaidDay(frameName)) then
						RAT:RemoveRaidDay(frameName);
					end
				end
			end);
			editBox:Hide();
			table.insert(rtFrames, editBox);
		end
	end
end

local function showRTFrames()
	if (not rtFrames) then
		initRTFrames();
	end
	for index, frame in pairs(rtFrames) do
		frame:Show();
		local frameName = frame:GetName();
		if (string.find(frameName, "RAT_RTO_Start_")) then
			frameName = string.sub(frameName, 15);
			if (RAT:IsRaidDay(frameName)) then
				local hour = RAT_SavedOptions.RaidTimes[frameName].StartHour;
				local min = RAT_SavedOptions.RaidTimes[frameName].StartMinute;
				if (string.len(hour) == 1) then
					hour = "0" .. hour;
				end
				if (string.len(min) == 1) then
					min = "00";
				end
				frame:SetText(hour .. ":" .. min);
			else
				frame:SetText("")
			end
		elseif (string.find(frameName, "RAT_RTO_Finish_")) then
			frameName = string.sub(frameName, 16);
			if (RAT:IsRaidDay(frameName)) then
				local hour = RAT_SavedOptions.RaidTimes[frameName].FinishHour;
				local min = RAT_SavedOptions.RaidTimes[frameName].FinishMinute;
				if (string.len(hour) == 1) then
					hour = "0" .. hour;
				end
				if (string.len(min) == 1) then
					min = "00";
				end
				frame:SetText(hour .. ":" .. min);
			else
				frame:SetText("");
			end
		end
	end
end

local function hideRTFrames()
	if (rtFrames) then
		for index, frame in pairs(rtFrames) do
			frame:Hide();
		end
	end
end

rtOptions:SetScript("OnShow", function()
	showRTFrames();
	Initialize_TimeZoneMenu();
	if (RAT_SavedData.TimeZone) then 
		if (string.find(RAT_SavedData.TimeZone, "-")) then
			UIDropDownMenu_SetSelectedName(timeZoneMenu, "UTC"..RAT_SavedData.TimeZone);
		else
			UIDropDownMenu_SetSelectedName(timeZoneMenu, "UTC+"..RAT_SavedData.TimeZone);
		end
	end
end);

InterfaceOptions_AddCategory(rtOptions);