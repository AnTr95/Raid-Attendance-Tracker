local addon = ...;
local L = RAT_Locals;
local RAT = RAT;
local _G = _G;
local plTexts = {};
local selectedPlayers = {};
local selectedAction = "Award";
local amount = 0;

local escapeCodes = {};
escapeCodes.SUCCESS = "|cFF00FF00";
escapeCodes.FAIL = "|cFFFF0000";

local ccOptions = CreateFrame("Frame");
ccOptions:Hide();

RAT.OptionsCategories.CommandCenter = Settings.RegisterCanvasLayoutSubcategory(RAT.OptionsCategories.Options, ccOptions, "Command Center");

local addonText = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
addonText:SetText(L.ADDON_FULL);
addonText:SetPoint("TOP", 0, -16);

local version = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
version:SetText(L.ADDON_VERSION);
version:SetPoint("TOPLEFT", 450, -32);

local author = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
author:SetText(L.ADDON_AUTHOR);
author:SetPoint("TOPLEFT", 450, -16);

local title = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
title:SetText(L.OPTIONS_COMMAND_CENTER_TITLE);
title:SetPoint("TOPLEFT", 16, -16);

local infoText = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
infoText:SetText();
infoText:SetPoint("TOPLEFT", 40, -85);
infoText:SetWordWrap(true);
infoText:SetJustifyV("TOP");
infoText:SetJustifyH("LEFT");
infoText:SetSize(520, 320);

local awardAllButton = CreateFrame("Button", "RAT_AwardAllButton", ccOptions, "UIMenuButtonStretchTemplate");
awardAllButton:SetSize(120,50);
awardAllButton:SetPoint("TOPLEFT", 20, -80);
awardAllButton:SetText(L.OPTIONS_AWARD_ALL_BUTTON);
awardAllButton:SetScript("OnClick", function(self)
	StaticPopup_Show ("RAT_AWARD_ALL_BUTTON");
end);

local undoButton = CreateFrame("Button", "RAT_UndoButton", ccOptions, "UIMenuButtonStretchTemplate");
undoButton:SetSize(120,50);
undoButton:SetPoint("TOPLEFT", 20, -150);
undoButton:SetText(L.OPTIONS_UNDO_BUTTON);
undoButton:SetScript("OnClick", function(self)
	local lastAttending = RAT:GetLastAttending();
	local lastAbsent = RAT:GetLastAbsent();
	local lastAmount = RAT:GetLastAmount();
	if ((next(lastAttending) or next(lastAbsent)) and lastAmount) then
		RAT:Undo(lastAttending, lastAbsent, lastAmount);
	else
		DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.ERROR_UNDO);
	end
end);
--130 size or 100?
local skipButton = CreateFrame("Button", "RAT_UndoButton", ccOptions, "UIMenuButtonStretchTemplate");
skipButton:SetSize(120,50);
skipButton:SetPoint("TOPLEFT", 20, -220);
skipButton:SetText(L.OPTIONS_SKIP_BUTTON);
skipButton:SetScript("OnClick", function(self)
	StaticPopup_Show ("RAT_SKIP_BUTTON");
end);

local setupButton = CreateFrame("Button", "RAT_SetupButton", ccOptions, "UIMenuButtonStretchTemplate");
setupButton:SetSize(120,50);
setupButton:SetPoint("TOPLEFT", 20, -290);
setupButton:SetText(L.OPTIONS_SETUP_BUTTON);
setupButton:SetScript("OnClick", function(self)
	StaticPopup_Show ("RAT_SETUP_BUTTON");
end);

local deleteButton = CreateFrame("Button", "RAT_DeleteButton", ccOptions, "UIMenuButtonStretchTemplate");
deleteButton:SetSize(120,50);
deleteButton:SetPoint("TOPLEFT", 20, -360);
deleteButton:SetText(L.OPTIONS_DELETE_BUTTON);
deleteButton:SetScript("OnClick", function(self)
	StaticPopup_Show ("RAT_DELETE_BUTTON");
end);

local line = ccOptions:CreateTexture(nil, "BACKGROUND");
line:SetColorTexture(0.7 ,0.7, 0.7, 0.5);
line:SetSize(1, 560);
line:SetPoint("TOPLEFT", 185,0);

local markButton = CreateFrame("Button", "RAT_MarkButton", ccOptions, "UIPanelButtonTemplate");
markButton:SetSize(100,25);
markButton:SetPoint("TOPLEFT", 400, -60);
markButton:SetText(L.OPTIONS_MARK_BUTTON);
markButton:SetScript("OnClick", function(self)
	for pl, data in pairs(RAT_SavedData.Attendance) do
		table.insert(selectedPlayers, pl);
		local frame = "RAT_CC_Checkbox_" .. pl;
		_G[frame]:SetChecked(true);
	end
end);

local unmarkButton = CreateFrame("Button", "RAT_UnmarkButton", ccOptions, "UIPanelButtonTemplate");
unmarkButton:SetSize(100,25);
unmarkButton:SetPoint("TOPLEFT", 505, -60);
unmarkButton:SetText(L.OPTIONS_UNMARK_BUTTON);
unmarkButton:SetScript("OnClick", function(self)
	for key, pl in pairs(selectedPlayers) do
		local frame = "RAT_CC_Checkbox_" .. pl;
		_G[frame]:SetChecked(false);
	end
	selectedPlayers = {};
end);


local actionButton = CreateFrame("Button", "RAT_ActionButton", ccOptions, "UIPanelButtonTemplate");
actionButton:SetSize(80,25);
actionButton:SetPoint("BOTTOMLEFT", 470, 18);
actionButton:SetText(L.OPTIONS_ACTION_BUTTON);
actionButton:SetScript("OnClick", function(self)
	if(next(selectedPlayers)) then
		if (selectedAction == "Bench") then
			for k, pl in pairs(selectedPlayers) do
				RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = pl;
				local msg = "BENCH " .. pl;
				C_ChatInfo.SendAddonMessage("RATSYSTEM", msg, "GUILD");
				SendChatMessage(L.ADDON .. pl .. L.BROADCAST_BENCHED_PLAYER, "GUILD");
			end
		elseif (selectedAction == "Award") then
			if (amount ~= 0) then
				for k, pl in pairs(selectedPlayers) do
					RAT:PlayerAttended(pl, amount);
					C_Timer.After(2, function() RAT:UpdatePlayerAlts(pl); end);
				end
				if (#selectedPlayers > 1) then
					local strings = RAT:ToString(selectedPlayers);
					SendChatMessage(L.ADDON .. L.BROADCAST_AWARDED_ALL1 .. amount .. L.BROADCAST_AWARDED_ALL2 .. strings[1], "GUILD", "COMMON", nil);
					for i = 2, #strings do
						SendChatMessage(strings[i], "GUILD", "COMMON", nil);
					end
				else
					SendChatMessage(L.ADDON .. selectedPlayers[1] .. L.BROADCAST_AWARDED_PLAYER1 .. amount .. L.BROADCAST_AWARDED_PLAYER2, "GUILD");
				end
				C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				RAT:SetLastAttending(selectedPlayers);
				RAT:SetLastAbsent({});
				RAT:SetLastAmount(amount);
			end
		elseif (selectedAction == "Absent") then
			if (amount ~= 0) then
				for k, pl in pairs(selectedPlayers) do
					RAT:PlayerAbsent(pl, amount);
					C_Timer.After(2, function() RAT:UpdatePlayerAlts(pl); end);
				end
				if (#selectedPlayers > 1) then
					local strings = RAT:ToString(selectedPlayers);
					SendChatMessage(L.ADDON .. L.BROADCAST_CC_ABSENT_PLAYER1 .. amount .. L.BROADCAST_CC_ABSENT_PLAYER2 .. strings[1], "GUILD", "COMMON", nil);
					for i = 2, #strings do
						SendChatMessage(strings[i], "GUILD", "COMMON", nil);
					end
				else
					SendChatMessage(L.ADDON .. selectedPlayers[1] .. L.BROADCAST_ABSENT_PLAYER1 .. amount .. L.BROADCAST_ABSENT_PLAYER2, "GUILD");
				end
				C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				RAT:SetLastAttending({});
				RAT:SetLastAbsent(selectedPlayers);
				RAT:SetLastAmount(amount);
			end
		elseif (selectedAction == "Strike") then
			if (amount ~= 0) then
				for k, pl in pairs(selectedPlayers) do
					RAT:StrikePlayer(pl, amount);
					C_Timer.After(2, function() RAT:UpdatePlayerAlts(pl); end);
					SendChatMessage(L.ADDON .. pl .. L.BROADCAST_STRIKE_PLAYER1 .. amount .. L.BROADCAST_STRIKE_PLAYER2, "GUILD");
				end
				C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
			end
		end
	end
end);

local actions = {"Award", "Absent", "Bench", "Strike"};
local function TimeZoneMenuGenerator(owner, rootDescription)
	for _, action in ipairs(actions) do
		rootDescription:CreateButton(action, function(data)
			selectedAction = action;
			if (selectedAction == "Bench") then
				actionButton:Enable();
			else
				if (amount ~= 0) then
					actionButton:Enable();
				else
					actionButton:Disable();
				end
			end
		end);
	end
end

local actionMenu = CreateFrame("DropdownButton", nil, ccOptions, "WowStyle1DropdownTemplate");
actionMenu:SetPoint("BOTTOMLEFT", 220, 15);
actionMenu:SetWidth(110);

actionMenu:SetupMenu(TimeZoneMenuGenerator);

actionMenu:SetSelectionText(function(selections)
	return selectedAction;
end);

local actionText = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
actionText:SetText(L.OPTIONS_ACTION_TEXT);
actionText:SetPoint("BOTTOMLEFT", 220, 50);

local amountEditBox = CreateFrame("EditBox", nil, ccOptions, "InputBoxTemplate");
amountEditBox:SetAutoFocus(false);
amountEditBox:SetSize(50, 20);
amountEditBox:SetPoint("BOTTOMLEFT", 385, 20);
amountEditBox:SetScript("OnEscapePressed", function(self)
	self:ClearFocus();
end);
amountEditBox:SetScript("OnEnterPressed", function(self)
	self:ClearFocus();
end);
amountEditBox:SetScript("OnTextChanged", function(self)
	if (tonumber(self:GetText())) then
		actionButton:Enable();
		amount = tonumber(self:GetText());
	else
		if (selectedAction ~= "Bench") then
			actionButton:Disable();
		end
		amount = 0;
	end
end);

local amountText = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
amountText:SetText(L.OPTIONS_AMOUNT_TEXT);
amountText:SetPoint("BOTTOMLEFT", amountEditBox, "TOPLEFT", -3, 10);

ccOptions:SetScript("OnShow", function()
	for key, pl in pairs(selectedPlayers) do
		local frame = "RAT_CC_Checkbox_" .. pl;
		_G[frame]:SetChecked(false);
	end
	selectedPlayers = {};
	selectedAction = "Award";
	amount = 0;
	amountEditBox:SetText("");
	local sortedArray = {};
	for pl, data in pairs(RAT_SavedData.Attendance) do
		table.insert(sortedArray, pl);
	end
	table.sort(sortedArray);
	for i = 1, #sortedArray do
		local pl = sortedArray[i];
		if (not RAT:Contains(plTexts, pl)) then
			local plText = ccOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal");
			plText:SetText(pl);
			plTexts[#plTexts+1] = pl;
			plText:SetPoint("TOPLEFT", 230+((#plTexts+2)%3*145), -100-(math.floor((#plTexts-1)/3))*25);

			local checkButton = CreateFrame("CheckButton", "RAT_CC_Checkbox_" .. pl, ccOptions, "UICheckButtonTemplate");
			checkButton:SetSize(20, 20);
			checkButton:SetPoint("TOPLEFT", 205+((#plTexts+2)%3*145), -95-(math.floor((#plTexts-1)/3))*25);
			checkButton:SetScript("OnClick", function(self)
				local checked = self:GetChecked();
				local exists = RAT:Contains(selectedPlayers, pl);
				if (checked and not exists) then
					table.insert(selectedPlayers, pl);
				elseif (not checked and exists) then
					table.remove(selectedPlayers, exists);
				end
			end);
		end
	end
	actionMenu:SetDefaultText(selectedAction);
	actionButton:Disable();
end);

StaticPopupDialogs["RAT_SKIP_BUTTON"] = {
	text = "Are you sure you want to skip the current or coming raid?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		RAT:SkipToNextRaidDay();
		RAT:BroadcastSummary();
		RAT_SavedData.Bench = {};
		RAT_SavedData.Summary = {};
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
};

StaticPopupDialogs["RAT_SETUP_BUTTON"] = {
	text = "Are you sure you want to start the setup? It will reset all settings except alts and the attendance database.",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		RAT_SavedOptions.AwardStart = true;
		RAT_SavedOptions.Frequency = 60;
		RAT_SavedOptions.RankingAlgo = "RAT-Algorithm";
		RAT_SavedOptions.PunishCalendar = false;
		RAT_SavedOptions.RaiderRanks = {};
		RAT_SavedData.SetupCompleted = false;
		RAT_SavedData.NextAward = 0;
		RAT:StartSetup();
		SettingsPanel:Hide();
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
};

StaticPopupDialogs["RAT_AWARD_ALL_BUTTON"] = {
	text = "How many points do you wish to award the raid?",
	button1 = "Award",
	button2 = "Cancel",
	hasEditBox = true,
	OnShow = function(self, data)
		self.editBox:SetText("1");
	end,
	OnAccept = function(self, data, data2)
		local input = self.editBox:GetText();
		if (tonumber(input)) then
			RAT:AllAttended(tonumber(input));
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
};

StaticPopupDialogs["RAT_DELETE_BUTTON"] = {
	text = "Are you sure you want to delete all data? If so type DELETE below. WARNING: This can not be undone.",
	button1 = "Confirm",
	button2 = "Cancel",
	hasEditBox = true,
	showAlert = true,
	OnShow = function(self, data)
		self.button1:Disable();
	end,
	OnAccept = function(self, data, data2)
		for i = 1, GetNumGuildMembers() do
			local isEligible = RAT:Eligible(i);
			local name = Ambiguate(GetGuildRosterInfo(i), "none");
			local hasMain = RAT:GetMain(name);
			RAT_SavedData.Attendance = {};
			if (isEligible or hasMain) then
				if (isEligible and not hasMain) then
					RAT:InitPlayer(name);
					RAT:UpdateNote(name, i);
				elseif (hasMain) then
					GuildRosterSetPublicNote(i, "R:99 AP:0 0% M:0 S:0/3");
				end
			else
				local note = select(8, GetGuildRosterInfo(i));
				if (note:find("R:") and note:find("AP:") and note:find("M:") and note:find("S:") and note:find("%%")) then
					GuildRosterSetOfficerNote(i, "");
					GuildRosterSetPublicNote(i, "");
				end
			end
		end
		RAT:Sync();
		SendChatMessage(L.ADDON .. Ambiguate(UnitName("player"), "none") .. L.SYSTEM_DELETED_DATA, "GUILD");
	end,
	EditBoxOnTextChanged = function(self, data)
		local input = self:GetText();
		if (input == "DELETE") then
			self:GetParent().button1:Enable();
		else
			self:GetParent().button1:Disable();
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
};

Settings.RegisterAddOnCategory(RAT.OptionsCategories.CommandCenter);