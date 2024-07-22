local RAT = RAT;
local _G = _G;
local L = RAT_Locals;
local page = 1;
local rtFrames = nil;
local rrFrames = nil;
local weekdaysNames = {[1] = "Sunday", [2] = "Monday", [3] = "Tuesday", [4] = "Wednesday", [5] = "Thursday", [6] = "Friday", [7] = "Saturday"};

local function findTwoLetterMatches(arr, value)
	local subValue = value:sub(1,2);
	for i, string in pairs(arr) do
		if (string:match(subValue)) then
			arr[i] = nil;
		end
	end
	return arr;
end

local function shortToFullRaidDay(day)
	if (day == "Mo" or day == "Mon" or day == "Mondays" or day == "Monday") then
		return "Monday";
	elseif (day == "Tu" or day == "Tue" or day == "Tuesdays" or day == "Tuesday") then
		return "Tuesday";
	elseif (day == "Wed" or day == "Wednesdays" or day == "Wednesday") then
		return "Wednesday";
	elseif (day == "Thu" or day == "Thur" or day == "Thursdays" or day == "Thursday") then
		return "Thursday";
	elseif (day == "Fr" or day == "Fri" or day == "Fridays" or day == "Friday") then
		return "Friday";
	elseif (day == "Sat" or day == "Saturdays" or day == "Saturday") then
		return "Saturday";
	elseif (day == "Su" or day == "Sun" or day == "Sundays" or day == "Sunday") then
		return "Sunday";
	end
	return;
end
--[[
local f = CreateFrame("Frame");

f:SetScript("OnEvent", function(self, event, ...)
	if (event == "CALENDAR_OPEN_EVENT") then
		f:UnregisterEvent("CALENDAR_OPEN_EVENT");
		local timeInfo = C_Calendar.GetEventInfo().time;
		local weekday = timeInfo.weekday;
		local hour = timeInfo.hour;
		local min = timeInfo.minute;
		weekday = weekdaysNames[weekday];
		if (not RAT:ContainsKey(raidDays, weekday)) then
			raidDays[weekday] = {};
			raidDays[weekday].StartHour = hour;
			raidDays[weekday].StartMinute = min;
			raidDays[weekday].FinishHour = 23;
			raidDays[weekday].FinishMinute = 00;
		end
		print("added" .. weekday)
	end
end)
]]
function RAT:SuggestRaidDays()
	local monthLength = {
		[1] = 31,
		[2] = 28,
		[3] = 31,
		[4] = 30,
		[5] = 31,
		[6] = 30,
		[7] = 31,
		[8] = 31,
		[9] = 30,
		[10] = 31,
		[11] = 30,
		[12] = 31,
	}
	local dayKeywords = {
		"Mondays",
		"Tuesdays",
		"Wednesdays",
		"Thursdays",
		"Fridays",
		"Saturdays",
		"Sundays",
		"Monday",
		"Tuesday",
		"Wednesday",
		"Thursday",
		"Friday",
		"Saturday",
		"Sunday",
		"Mon",
		"Mo",
		"Tu",
		"Tue",
		"Wed",
		"Thu",
		"Thur",
		"Fri",
		"Fr",
		"Sat",
		"Su",
		"Sun",
	};
	local raidDays = {};
	local tempRaidDays = {};
	local raidTimesFound = false;
	local gInfo = GetGuildInfoText();
	local gInfoWords = RAT:Split(gInfo);
	for i, word in pairs(gInfoWords) do
		local word = word:match("%a*");
		if (word) then
			for j, day in pairs(dayKeywords) do
				if (word:match("^"..day.."$")) then
					word = word:match("^"..day.."$");
					local possibleTime = gInfoWords[i+1];
					local startHour = nil;
					local startMinute = nil;
					local finishHour = nil;
					local finishMinute = nil;
					table.insert(tempRaidDays, shortToFullRaidDay(word));
					dayKeywords = findTwoLetterMatches(dayKeywords, day);
					--First try and see if the following word is raid times, if not scan again later for general raid times.
					if (possibleTime) then
						if (possibleTime:match("[%d%.%-:]+")) then --Only match numbers, ., - and :
							local times = {};
							for time in possibleTime:gmatch("%d+") do
								table.insert(times,time);
							end
							if (#times == 4) then
								for k, time in pairs(times) do
									if (time:len() ~= 2) then
										break;
									end
								end
								startHour = times[1];
								startMinute = times[2];
								finishHour = times[3];
								finishMinute = times[4];
								raidTimesFound = true;
							elseif (#times == 2) then
								if (times[1]:len() == 4 and times[2]:len() == 4) then
									startHour = times[1]:sub(1,2);
									startMinute = times[1]:sub(3,4);
									finishHour = times[2]:sub(1,2);
									finishMinute = times[2]:sub(3,4);
									raidTimesFound = true;
								elseif (times[1]:len() == 2 and times[2]:len() == 2) then
									startHour = times[1];
									startMinute = times[2];
									possibleTime = gInfoWords[i+2];
									if (possibleTime) then
										if (possibleTime == "-" or possibleTime == "to") then
											possibleTime = gInfoWords[i+3];
										end
										if (possibleTime:match("[%d%.%-:]+")) then
											times = {};
											for time in possibleTime:gmatch("%d+") do
												table.insert(times,time);
											end
											if (#times == 2) then
												for k, time in pairs(times) do
													if (time:len() ~= 2) then
														break;
													end
												end
												finishHour = times[1];
												finishMinute = times[2];
												raidTimesFound = true;
											end
										end
									end
								end
							elseif (#times == 1 and times[1]:len() == 4) then
								startHour = times[1]:sub(1,2);
								startMinute = times[1]:sub(3,4);
								possibleTime = gInfoWords[i+2];
								if (possibleTime) then
									if (possibleTime == "-" or possibleTime == "to") then
										possibleTime = gInfoWords[i+3];
									end
									if (possibleTime:match("[%d%.%-:]+")) then
										times = {};
										for time in possibleTime:gmatch("%d+") do
											table.insert(times,time);
										end
										if (#times == 1 and times[1]:len() == 4) then
											finishHour = times[1]:sub(1,2);
											finishMinute = times[2]:sub(3,4);
											raidTimesFound = true;
										end
									end
								end
							end
						end
						if (startHour and startMinute and finishHour and finishMinute) then
							--Suggest Raid Day and Time
							local raidDay = shortToFullRaidDay(word);
							raidDays[raidDay] = {};
							raidDays[raidDay].StartHour = startHour;
							raidDays[raidDay].StartMinute = startMinute;
							raidDays[raidDay].FinishHour = finishHour;
							raidDays[raidDay].FinishMinute = finishMinute;
						end
					end
				end
			end
		end
	end
	--Scan guild info for general raid times
	if (not raidTimesFound) then
		for i, word in pairs(gInfoWords) do
			if (word:match("[%d%.%-:]+")) then --Only match numbers, ., - and :
				local times = {};
				for time in word:gmatch("%d+") do
					table.insert(times,time);
				end
				if (#times == 4) then
					for j, time in pairs(times) do
						if (time:len() ~= 2) then
							break;
						end
					end
					startHour = times[1];
					startMinute = times[2];
					finishHour = times[3];
					finishMinute = times[4];
					raidTimesFound = true;
				elseif (#times == 2) then
					if (times[1]:len() == 4 and times[2]:len() == 4) then
						startHour = times[1]:sub(1,2);
						startMinute = times[1]:sub(3,4);
						finishHour = times[2]:sub(1,2);
						finishMinute = times[2]:sub(3,4);
						raidTimesFound = true;
						break;
					elseif (times[1]:len() == 2 and times[2]:len() == 2) then
						startHour = times[1];
						startMinute = times[2];
						local possibleTime = gInfoWords[i+1];
						if (possibleTime) then
							if (possibleTime == "-" or possibleTime == "to") then
								possibleTime = gInfoWords[i+2];
							end
							if (possibleTime:match("[%d%.%-:]+")) then
								times = {};
								for time in possibleTime:gmatch("%d+") do
									table.insert(times,time);
								end
								if (#times == 2) then
									for j, time in pairs(times) do
										if (time:len() ~= 2) then
											break;
										end
									end
									finishHour = times[1];
									finishMinute = times[2];
									raidTimesFound = true;
									break;
								end
							end
						end
					end
				elseif (#times == 1 and times[1]:len() == 4) then
					startHour = times[1]:sub(1,2);
					startMinute = times[1]:sub(3,4);
					local possibleTime = gInfoWords[i+1];
					if (possibleTime) then
						if (possibleTime == "-" or possibleTime == "to") then
							possibleTime = gInfoWords[i+2];
						end
						if (possibleTime:match("[%d%.%-:]+")) then
							times = {};
							for time in possibleTime:gmatch("%d+") do
								table.insert(times,time);
							end
							if (#times == 1 and times[1]:len() == 4) then
								finishHour = times[1]:sub(1,2);
								finishMinute = times[2]:sub(3,4);
								raidTimesFound = true;
								break;
							end
						end
					end
				end
			end
		end
		if (#tempRaidDays > 0 and startHour and startMinute and finishHour and finishMinute) then
			for j, raidDay in pairs(tempRaidDays) do
				--Suggest Raid Day and Time
				raidDays[raidDay] = {};
				raidDays[raidDay].StartHour = startHour;
				raidDays[raidDay].StartMinute = startMinute;
				raidDays[raidDay].FinishHour = finishHour;
				raidDays[raidDay].FinishMinute = finishMinute;
			end
		end
	end
	--[[
	local date = C_DateAndTime.GetCurrentCalendarTime();
	local realmMonth = date.month;
	local realmDay = date.monthDay;
	local realmYear = date.year;
	local monthOffset = 0;
	for i = 1, 7 do
		if (realmDay > monthLength[realmMonth]) then
			realmDay = 1;
			monthOffset = 1;
		end
		for j = 1, C_Calendar.GetNumDayEvents(monthOffset, realmDay) do
			local calendarEvent = C_Calendar.GetDayEvent(0, realmDay, j);
			local calendarType = calendarEvent.calendarType;
			local eventType = calendarEvent.eventType;
			if (calendarType == "PLAYER" and eventType == 0) then
				C_Calendar.CloseEvent();
				f:RegisterEvent("CALENDAR_OPEN_EVENT");
				C_Calendar.OpenEvent(0, realmDay, j); -- Selects the calendar event for modification
			end
		end
		realmDay = realmDay + 1;
	end]]
	return raidDays;
end

function RAT:SuggestRaiderRanks()
	local suggestedRanks = {
		"Guild Master",
		"Officer",
		"Raider",
		"Trial",
	};
	local ranks = RAT:GetAllGuildRanks();
	local suggest = {};
	for index, rank in pairs(ranks) do
		if (RAT:Contains(suggestedRanks, rank)) then
			suggest[#suggest+1] = rank;
		end
	end
	return suggest;
end

function RAT:GetAllGuildRanks()
	local ranks = {};
	for i = 1, GetNumGuildMembers() do
		local rank = select(2, GetGuildRosterInfo(i));
		if (not RAT:Contains(ranks, rank)) then
			ranks[#ranks+1] = rank;
		end
	end
	return ranks;
end

---------------------------------
-------------Assets--------------
---------------------------------

local setupFrame = CreateFrame("Frame", "RAT_SetupFrame");
setupFrame:SetPoint("CENTER");
setupFrame:SetWidth(485);
setupFrame:SetHeight(615);
setupFrame:SetFrameStrata("FULLSCREEN_DIALOG");
setupFrame:EnableDrawLayer("BACKGROUND");
setupFrame:SetMovable(true);
setupFrame:EnableMouse(true);
setupFrame:RegisterForDrag("LeftButton");
setupFrame:SetScript("OnDragStart", setupFrame.StartMoving);
setupFrame:SetScript("OnDragStop", setupFrame.StopMovingOrSizing);

setupFrame:Hide();

local normalTexture = setupFrame:CreateTexture("RAT_SetupFrameTexture", "BACKGROUND");
normalTexture:SetDrawLayer("BACKGROUND", 1);
normalTexture:SetTexture("Interface\\LFGFRAME\\UI-FRAME-THREEBUTTON-BLANK");
normalTexture:SetPoint("TOPLEFT");

local profileTexture = setupFrame:CreateTexture(nil, "BACKGROUND");
profileTexture:SetDrawLayer("BACKGROUND", 0);
profileTexture:SetTexture("Interface\\addons\\RaidAttendanceTracker\\Res\\setup.tga");
profileTexture:SetPoint("TOPLEFT",12, -5);

local addonText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
addonText:SetText(L.ADDON_FULL);
addonText:SetPoint("TOP",-42, -18);
addonText:SetFont("Fonts\\FRIZQT__.TTF", 12);

local version = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
version:SetText(L.ADDON_VERSION);
version:SetPoint("TOPRIGHT", -70, -20);
version:Hide();

local author = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
author:SetText(L.ADDON_AUTHOR);
author:SetPoint("TOPLEFT", version, "TOPLEFT", 0, -20);
author:Hide();

local title = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
title:SetText(L.OPTIONS_SETUP_TITLE);
title:SetPoint("TOP", -42,-45);
title:SetFont("Fonts\\FRIZQT__.TTF", 25);

local setupText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
setupText:SetText(L.SETUP_INFO_TEXT);
setupText:SetWordWrap(true);
setupText:SetJustifyV("TOP");
setupText:SetJustifyH("LEFT");
setupText:SetSize(250, 300);
setupText:SetPoint("TOP", -50, -120);
setupText:Hide();

local leftButton = CreateFrame("Button", "RAT_LeftButton", setupFrame, "UIPanelButtonTemplate");
leftButton:SetText(L.OPTIONS_LEFT_BUTTON);
leftButton:SetSize(109, 25);
leftButton:SetPoint("TOPLEFT", 26, -405);
leftButton:SetScript("OnClick", function(self)
	page = page - 1;
	RAT:OpenSetupPage(page);
end);
leftButton:Disable();

local pageText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
pageText:SetText(L.OPTIONS_PAGE_TEXT1 .. page .. L.OPTIONS_PAGE_TEXT2);
pageText:SetPoint("TOP", -50, -410);
pageText:SetFont("Fonts\\FRIZQT__.TTF", 14);

local rightButton = CreateFrame("Button", "RAT_RightButton", setupFrame, "UIPanelButtonTemplate");
rightButton:SetText(L.OPTIONS_RIGHT_BUTTON);
rightButton:SetSize(109, 25);
rightButton:SetPoint("TOPLEFT", 242, -405);
rightButton:SetScript("OnClick", function(self)
	page = page + 1;
	RAT:OpenSetupPage(page);
end);

local crossButton = CreateFrame("Button", "RAT_CrossButton", setupFrame, "UIPanelCloseButton");
crossButton:SetSize(33, 33);
crossButton:SetPoint("TOPRIGHT", -126, -7);

local timeZones = {"UTC+0", "UTC+1", "UTC+2", "UTC+3", "UTC+4", "UTC+5", "UTC+6", "UTC+7", "UTC+8", "UTC+9", "UTC+10", "UTC+11", "UTC+12", "UTC-1", "UTC-2", "UTC-3", "UTC-4", "UTC-5", "UTC-6", "UTC-7", "UTC-8", "UTC-9", "UTC-10", "UTC-11", "UTC-12"};
local function TimeZoneMenuGenerator(owner, rootDescription)
	for _, timeZone in ipairs(timeZones) do
		rootDescription:CreateButton(timeZone, function(data)
			local prev = RAT_SavedData.TimeZone;
			RAT_SavedData.TimeZone = string.match(timeZone, "[%-]?[%d]+");
			if (prev and prev ~= RAT_SavedData.TimeZone and RAT:GetNextRaidDay("Monday")) then
				RAT:SetNextAward(GetServerTime());
				RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward - GetServerTime()));
			end
			if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
				rightButton:Disable();
			else
				rightButton:Enable();
			end
		end);
	end
end

local timeZoneMenu = CreateFrame("DropdownButton", "RAT_TimeZoneDropDown", setupFrame, "WowStyle1DropdownTemplate");
timeZoneMenu:SetPoint("TOPLEFT", 220, -370);
timeZoneMenu:SetDefaultText("Select Timezone");
timeZoneMenu:SetWidth(90);
timeZoneMenu:Hide();

timeZoneMenu:SetupMenu(TimeZoneMenuGenerator);

timeZoneMenu:SetSelectionText(function(selections)
	if (RAT_SavedData.TimeZone) then
		if (string.find(RAT_SavedData.TimeZone, "-")) then
			return "UTC"..RAT_SavedData.TimeZone;
		else
			return "UTC+"..RAT_SavedData.TimeZone;
		end
	end
end);

local scanRTButton = CreateFrame("Button", "RAT_ScanRTButton", setupFrame, "UIMenuButtonStretchTemplate");
scanRTButton:SetSize(130,50);
scanRTButton:SetPoint("TOPLEFT", 50, -350);
scanRTButton:SetText(L.OPTIONS_SCAN_RT_BUTTON);
scanRTButton:SetScript("OnClick", function(self)
	local SRD = RAT:SuggestRaidDays();
	RAT_SavedData.TimeZone = RAT:GetRealmTimeZone();
	for day, data in pairs(SRD) do 
		RAT:AddRaidDay(day, tonumber(data.StartHour), tonumber(data.StartMinute), tonumber(data.FinishHour), tonumber(data.FinishMinute));
		local frameStart = "RAT_RT_Start_" .. day;
		local frameFinish = "RAT_RT_Finish_" .. day;
		_G[frameStart]:SetText(data.StartHour .. ":" .. data.StartMinute);
		_G[frameFinish]:SetText(data.FinishHour .. ":" .. data.FinishMinute);
	end
	if (string.find(RAT_SavedData.TimeZone, "-")) then
		timeZoneMenu:SetDefaultText("UTC"..RAT_SavedData.TimeZone);
	else
		timeZoneMenu:SetDefaultText("UTC+"..RAT_SavedData.TimeZone);
	end
	if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
		rightButton:Disable();
	else
		rightButton:Enable();
	end
	self:Hide();
end);
scanRTButton:Hide();

local infoText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
infoText:SetText("");
infoText:SetPoint("TOPLEFT", 40, -85);
infoText:SetWordWrap(true);
infoText:SetJustifyV("TOP");
infoText:SetJustifyH("LEFT");
infoText:SetSize(290, 320);
infoText:Hide();

local dayText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
dayText:SetText(L.OPTIONS_DAY_TEXT);
dayText:SetPoint("TOPLEFT", 80, -150);
dayText:Hide();

local startText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
startText:SetText(L.OPTIONS_START_TEXT);
startText:SetPoint("TOPLEFT", 220, -150);
startText:Hide();

local finishText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
finishText:SetText(L.OPTIONS_FINISH_TEXT);
finishText:SetPoint("TOPLEFT", 280, -150);
finishText:Hide();

local timeZoneText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
timeZoneText:SetText(L.OPTIONS_SERVER_TIMEZONE_TEXT);
timeZoneText:SetPoint("TOPLEFT", 220, -350);
timeZoneText:Hide();

local rankText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
rankText:SetText(L.OPTIONS_RANK_TEXT);
rankText:SetPoint("TOPLEFT", 60, -175);
rankText:Hide();

local scanRRButton = CreateFrame("Button", "RAT_ScanRRButton", setupFrame, "UIMenuButtonStretchTemplate");
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
			frame = "RAT_RR_Checkbox_" .. rank;
			_G[frame]:SetChecked(true);
		end
	end
	if (next(RAT_SavedOptions.RaiderRanks)) then
		rightButton:Enable();
	else
		rightButton:Disable();
	end
	self:Hide();
end);
scanRRButton:Hide();

local sortRankText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
sortRankText:SetText(L.OPTIONS_SORT_RANK_TEXT);
sortRankText:SetPoint("TOPLEFT", 60, -175);
sortRankText:Hide();

local sortRankHelp = CreateFrame("Button", "RAT_SortRankHelp", setupFrame, "UIPanelInfoButton");
sortRankHelp:SetPoint("TOPLEFT", 40, -172);
sortRankHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_SORT_RANKS_TOOLTIP);
	GameTooltip:Show();
end);
sortRankHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end);
sortRankHelp:Hide();

local rankAlgos = {"RAT-Algorithm", "Highest Percent", "Most Points"};
local function AlgoMenuGenerator(owner, rootDescription)
	for _, algo in ipairs(rankAlgos) do
		rootDescription:CreateButton(algo, function(data)
			RAT_SavedOptions.RankingAlgo = algo;
		end);
	end
end

local sortRankMenu = CreateFrame("DropdownButton", "RAT_SortRankDropDown", setupFrame, "WowStyle1DropdownTemplate");
sortRankMenu:SetPoint("TOPLEFT", 215, -165);
sortRankMenu:SetWidth(110);
sortRankMenu:Hide();

sortRankMenu:SetupMenu(AlgoMenuGenerator);

sortRankMenu:SetSelectionText(function(selections)
	return RAT_SavedOptions.RankingAlgo;
end);

local frequencyText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
frequencyText:SetPoint("TOPLEFT", 60, -205);
frequencyText:SetText(L.OPTIONS_FREQUENCY_TEXT);
frequencyText:Hide();

local frequencyHelp = CreateFrame("Button", "RAT_FrequencyHelp", setupFrame, "UIPanelInfoButton");
frequencyHelp:SetPoint("TOPLEFT", 40, -202);
frequencyHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_FREQUENCY_TOOLTIP);
	GameTooltip:Show();
end);
frequencyHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end)
frequencyHelp:Hide();
local frequencyEditBoxLastValue = 60;
local frequencyEditBox = CreateFrame("EditBox", "RAT_FrequencyEditBox", setupFrame, "InputBoxTemplate");
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
frequencyEditBox:Hide();

local awardStartText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
awardStartText:SetText(L.OPTIONS_AWARD_START_TEXT);
awardStartText:SetPoint("TOPLEFT", 60, -235);
awardStartText:Hide();

local awardStartHelp = CreateFrame("Button", "RAT_AwardStartHelp", setupFrame, "UIPanelInfoButton");
awardStartHelp:SetPoint("TOPLEFT", 40, -232);
awardStartHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_AWARD_RAID_START_TOOLTIP);
	GameTooltip:Show();
end);
awardStartHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end);
awardStartHelp:Hide();

local awardStartCheckButton = CreateFrame("CheckButton", "RAT_AwardStartCheckButton", setupFrame, "UICheckButtonTemplate");
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
awardStartCheckButton:Hide();


local punishCalendarText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
punishCalendarText:SetText(L.OPTIONS_PUNISH_CALENDAR_TEXT);
punishCalendarText:SetPoint("TOPLEFT", 60, -265);
punishCalendarText:Hide();

local punishCalendarHelp = CreateFrame("Button", "RAT_PunishCalendarHelp", setupFrame, "UIPanelInfoButton");
punishCalendarHelp:SetPoint("TOPLEFT", 40, -262);
punishCalendarHelp:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self);
	GameTooltip:SetText(L.SETUP_PUNISH_CALENDAR_TOOLTIP);
	GameTooltip:Show();
end);
punishCalendarHelp:SetScript("OnLeave", function(self)
	GameTooltip:Hide();
end);
punishCalendarHelp:Hide();

local punishCalendarCheckButton = CreateFrame("CheckButton", "RAT_PunishCalendarCheckButton", setupFrame, "UICheckButtonTemplate");
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
punishCalendarCheckButton:Hide();
--[[
	local minimapModeText = setupFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
	minimapModeText:SetText(L.OPTIONS_MINIMAP_MODE_TEXT);
	minimapModeText:SetPoint("TOPLEFT", 60, -295);
	minimapModeText:Hide();

	local minimapStateMenu = CreateFrame("Button", "RAT_MinimapStateDropDown", setupFrame, "UIDropDownMenuTemplate");
	minimapStateMenu:SetPoint("TOPLEFT", 200, -285);
	minimapStateMenu:Hide();

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
]]
local function initRTFrames()
	local weekdays = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
	if (not rtFrames) then
		rtFrames = {};
		for i = 1, 7 do
			local text = setupFrame:CreateFontString("RAT_RT_Text_" .. weekdays[i], "ARTWORK", "GameFontWhite");
			text:SetText(weekdays[i]);
			text:SetPoint("TOPLEFT", 80, -170-((i-1)*25));
			text:Hide();
			table.insert(rtFrames, text);
		end
		for i = 1, 7 do
			local editBox = CreateFrame("EditBox", "RAT_RT_Start_" .. weekdays[i], setupFrame, "InputBoxTemplate");
			editBox:SetPoint("TOPLEFT", 220, -165-((i-1)*25));
			editBox:SetSize(40,20);
			editBox:SetAutoFocus(false);
			editBox:SetScript("OnEnterPressed", function(self)
				local frame = "RAT_RT_Finish_" .. weekdays[i];
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
				if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
					rightButton:Disable();
				else
					rightButton:Enable();
				end
				if (i == 7) then
					frame = "RAT_RT_Start_" .. weekdays[1];
				else
					frame = "RAT_RT_Start_" .. weekdays[i+1];
				end
				_G[frame]:SetFocus();
			end);
			editBox:SetScript("OnTabPressed", function(self)
				local frame = "RAT_RT_Finish_" .. weekdays[i];
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
				if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
					rightButton:Disable();
				else
					rightButton:Enable();
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
					frameName = string.sub(frameName, 14);
					if (RAT:IsRaidDay(frameName)) then
						RAT:RemoveRaidDay(frameName);
					end
					if (RAT:GetNextRaidDay("Monday") == nil) then
						rightButton:Disable();
					end
				end
			end);
			editBox:Hide();
			table.insert(rtFrames, editBox);
		end
		for i = 1, 7 do
			local editBox = CreateFrame("EditBox", "RAT_RT_Finish_" .. weekdays[i], setupFrame, "InputBoxTemplate");
			editBox:SetPoint("TOPLEFT", 280, -165-((i-1)*25));
			editBox:SetSize(40,20);
			editBox:SetAutoFocus(false);
			editBox:SetScript("OnEnterPressed", function(self)
				local frame = "RAT_RT_Start_" .. weekdays[i];
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
					frame = "RAT_RT_Finish_" .. weekdays[1];
				else
					frame = "RAT_RT_Finish_" .. weekdays[i+1];
				end
				if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
					rightButton:Disable();
				else
					rightButton:Enable();
				end
				_G[frame]:SetFocus();
			end);
			editBox:SetScript("OnTabPressed", function(self)
				local frame = "RAT_RT_Start_" .. weekdays[i];
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
				if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
					rightButton:Disable();
				else
					rightButton:Enable();
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
					if (RAT:GetNextRaidDay("Monday") == nil) then
						rightButton:Disable();
					end
				end
			end);
			editBox:Hide();
			table.insert(rtFrames, editBox);
		end
	end
end

local function initRRFrames()
	if (not rrFrames) then
		rrFrames = {};
		local ranks = RAT:GetAllGuildRanks();
		for i = 1, #ranks do
			local text = setupFrame:CreateFontString("RAT_RR_Text_" .. ranks[i], "ARTWORK", "GameFontWhite");
			text:SetText(ranks[i]);
			text:SetPoint("TOPLEFT", 60+((i+1)%2*150), -195-(math.floor((i-1)/2))*25);
			text:Hide();
			table.insert(rrFrames, text);
		end
		for i = 1, #ranks do
			local checkButton = CreateFrame("CheckButton", "RAT_RR_Checkbox_" .. ranks[i], setupFrame, "UICheckButtonTemplate");
			checkButton:SetSize(20, 20);
			checkButton:SetPoint("TOPLEFT", 150+((i+1)%2*150), -195-(math.floor((i-1)/2))*25);
			checkButton:SetScript("OnClick", function(self)
				local checked = self:GetChecked();
				local exists = RAT:Contains(RAT_SavedOptions.RaiderRanks, ranks[i]);
				if (checked and not exists) then
					table.insert(RAT_SavedOptions.RaiderRanks, ranks[i]);
					rightButton:Enable();
				elseif (not checked and exists) then
					table.remove(RAT_SavedOptions.RaiderRanks, exists);
					if (next(RAT_SavedOptions.RaiderRanks) == nil) then
						rightButton:Disable();
					end
				end
			end);
			checkButton:Hide();
			table.insert(rrFrames, checkButton);
		end
	end
end


local function showRTFrames()
	if (not rtFrames) then
		initRTFrames();
	end
	for index, frame in pairs(rtFrames) do
		frame:Show();
	end
end

local function hideRTFrames()
	if (rtFrames) then
		for index, frame in pairs(rtFrames) do
			frame:Hide();
		end
	end
end

local function showRRFrames()
	if (not rrFrames) then
		initRRFrames();
	end
	for index, frame in pairs(rrFrames) do
		frame:Show();
	end
end

local function hideRRFrames()
	if (rrFrames) then
		for index, frame in pairs(rrFrames) do
			frame:Hide();
		end
	end
end

local function hideAll()
	setupText:Hide();
	startText:Hide();
	finishText:Hide();
	dayText:Hide();
	scanRTButton:Hide();
	hideRTFrames();
	hideRRFrames();
	infoText:Hide();
	scanRRButton:Hide();
	rankText:Hide();
	awardStartText:Hide();
	awardStartHelp:Hide();
	awardStartCheckButton:Hide();
	frequencyEditBox:Hide();
	frequencyHelp:Hide();
	frequencyText:Hide();
	punishCalendarText:Hide();
	punishCalendarHelp:Hide();
	punishCalendarCheckButton:Hide();
	sortRankMenu:Hide();
	sortRankText:Hide();
	sortRankHelp:Hide();
	timeZoneText:Hide();
	timeZoneMenu:Hide();
	--minimapModeText:Hide();
	--minimapStateMenu:Hide();
end

function RAT:OpenSetupPage(page)
	hideAll();
	if (page == 1) then
		setupText:Show();
		leftButton:Disable();
		title:SetText(L.OPTIONS_SETUP_TITLE);
		rightButton:Enable();
		rightButton:SetText(L.OPTIONS_RIGHT_BUTTON);
	elseif (page == 2) then
		title:SetText(L.OPTIONS_RAID_TIMES_TITLE);
		leftButton:Enable();
		infoText:SetText(L.SETUP_RT_INFO_TEXT);
		infoText:Show();
		startText:Show();
		finishText:Show();
		scanRTButton:Show();
		dayText:Show();
		showRTFrames();
		timeZoneText:Show();
		timeZoneMenu:SetDefaultText("Select Timezone");
		if (RAT_SavedData.TimeZone) then
			if (string.find(RAT_SavedData.TimeZone, "-")) then
				timeZoneMenu:SetDefaultText("UTC"..RAT_SavedData.TimeZone);
			else
				timeZoneMenu:SetDefaultText("UTC+"..RAT_SavedData.TimeZone);
			end
		end
		timeZoneMenu:Show();
		rightButton:Enable();
		if (RAT_SavedData.TimeZone == nil or RAT:GetNextRaidDay("Monday") == nil) then
			rightButton:Disable();
		end
	elseif (page == 3) then
		initRRFrames();
		title:SetText(L.OPTIONS_RAIDER_RANKS_TITLE);
		infoText:SetText(L.SETUP_RR_INFO_TEXT);
		infoText:Show();
		rankText:Show();
		scanRRButton:Show();
		showRRFrames();
		rightButton:Enable();
		if (next(RAT_SavedOptions.RaiderRanks) == nil) then
			rightButton:Disable();
		end
	elseif (page == 4) then
		title:SetText(L.OPTIONS_SETTINGS_TITLE);
		infoText:SetText(L.SETUP_SETTINGS_INFO_TEXT);
		infoText:Show();
		awardStartText:Show();
		awardStartHelp:Show();
		awardStartCheckButton:Show();
		frequencyEditBox:Show();
		frequencyHelp:Show();
		frequencyText:Show();
		punishCalendarText:Show();
		punishCalendarHelp:Show();
		punishCalendarCheckButton:Show();
		sortRankHelp:Show();
		sortRankMenu:Show();
		sortRankText:Show();
		frequencyEditBox:SetText(tonumber(RAT_SavedOptions.Frequency));
		sortRankMenu:SetDefaultText(RAT_SavedOptions.RankingAlgo);
		awardStartCheckButton:SetChecked(RAT_SavedOptions.AwardStart);
		punishCalendarCheckButton:SetChecked(RAT_SavedOptions.PunishCalendar);
		--minimapModeText:Show();
		--minimapStateMenu:Show();
		--Initialize_MinimapState();
		--UIDropDownMenu_SetSelectedName(minimapStateMenu, RAT_SavedOptions.MinimapMode);
	elseif (page == 5) then
		rightButton:SetText(L.OPTIONS_RIGHT_BUTTON);
		title:SetText(L.OPTIONS_SETUP_COMPLETED_TITLE);
		infoText:Show();
		infoText:SetText(L.SETUP_COMPLETED_INFO_TEXT1);
		RAT_SavedData.SetupCompleted = true;
	elseif (page == 6) then
		rightButton:SetText(L.OPTIONS_RIGHT_BUTTON_DONE);
		title:SetText(L.OPTIONS_SETUP_COMPLETED_TITLE);
		infoText:Show();
		infoText:SetText(L.SETUP_COMPLETED_INFO_TEXT2);
	elseif (page == 7) then
		setupFrame:Hide();
		RAT:Sync();
	end
	pageText:SetText(L.OPTIONS_PAGE_TEXT1 .. page .. L.OPTIONS_PAGE_TEXT2);
end

function RAT:StartSetup()
	if (rtFrames) then
		for index, frame in pairs(rtFrames) do
			if (frame:GetName():find("Start") or frame:GetName():find("Finish")) then
				frame:SetText("");
			end
		end
	end
	if (rrFrames) then
		for index, frame in pairs(rrFrames) do
			if (frame:GetName():find("Checkbox")) then
				frame:SetChecked(false);
			end
		end
	end
	RAT:InitRaidTimes();
	RAT:UpdateGuild();
	setupFrame:Show();
	initRTFrames();
	page = 1;
	RAT:OpenSetupPage(page);
end