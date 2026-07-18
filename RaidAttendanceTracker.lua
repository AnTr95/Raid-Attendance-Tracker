RAT = {};
local _G = _G;
--[[
local mt = {__index = RAT};
setmetatable(RAT, mt);]]
local L = RAT_Locals;
RAT.Users = {};
--------------
--	LOCALS  --
--------------

local f = CreateFrame("Frame");
local ticks = 0;
local playersToRank = {};
local playersRegister = false;
local currentIndex = 0;
local addon = ...;
local syncDelay = 10;
local synced = false;
local benched = {};
local awaitingSync = false;
local lastAttending = {};
local lastAbsent = {};
local lastAmount = 0;
local summerTime = true; --check if time > winter time then make winter time
local EndlessAlgo, PercentAlgo, AttendancePointsAlgo, CustomAlgo = "Score", "Percent", "Attended", "";
local weekdays = {[1] = "Sunday", [2] = "Monday", [3] = "Tuesday", [4] = "Wednesday", [5] = "Thursday", [6] = "Friday", [7] = "Saturday"};
local escapeCodes = {};
escapeCodes.SUCCESS = "|cFF00FF00";
escapeCodes.FAIL = "|cFFFF0000";
escapeCodes.DEBUG = "|cFF43ABC9";
escapeCodes.WARNING = "|cFFFFFF00";


---------------------
-- Caching globals --
---------------------

local RAT = RAT;

local Ambiguate = Ambiguate;
local string = string
local pairs = pairs;
local GetServerTime = GetServerTime;

SLASH_RAIDATTENDANCETRACKER1 = "/rat"; -- slashcommand

----------------------
--	LEADERRBOARD    --
----------------------

local leaderBoard = CreateFrame("Frame", "RAT_Leaderboard", UIParent, BackdropTemplateMixin and "BackdropTemplate");
leaderBoard:SetSize(420, 520);
leaderBoard:SetPoint("CENTER");
leaderBoard:SetMovable(true);
leaderBoard:EnableMouse(true);
leaderBoard:RegisterForDrag("LeftButton");
leaderBoard:SetFrameStrata("DIALOG");
leaderBoard:SetToplevel(true);
leaderBoard:SetScript("OnDragStart", leaderBoard.StartMoving);
leaderBoard:SetScript("OnDragStop", leaderBoard.StopMovingOrSizing);
leaderBoard:SetBackdrop({
	bgFile = "Interface/DialogFrame/UI-DialogBox-Background-Dark",
	edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 }
});
leaderBoard:Hide();
tinsert(UISpecialFrames, "RAT_Leaderboard"); -- Escape closes the window

local lbTitle = leaderBoard:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge");
lbTitle:SetPoint("TOP", 0, -18);
lbTitle:SetText(L.ADDON_FULL);

-- Column headers (x positions match the data columns below).
local function makeHeader(label, x)
	local h = leaderBoard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	h:SetPoint("TOPLEFT", x, -48);
	h:SetText(label);
	return h;
end
makeHeader("#  Name", 26);
makeHeader("AP", 220);
makeHeader("M", 268);
makeHeader("%", 312);

local lbDivider = leaderBoard:CreateTexture(nil, "ARTWORK");
lbDivider:SetColorTexture(1, 1, 1, 0.18);
lbDivider:SetPoint("TOPLEFT", 20, -62);
lbDivider:SetPoint("TOPRIGHT", -36, -62);
lbDivider:SetHeight(1);

local lbScroll = CreateFrame("ScrollFrame", "RAT_LeaderboardScroll", leaderBoard, "UIPanelScrollFrameTemplate");
lbScroll:SetPoint("TOPLEFT", 20, -68);
lbScroll:SetPoint("BOTTOMRIGHT", -36, 48);
local lbContent = CreateFrame("Frame", nil, lbScroll);
lbContent:SetSize(340, 1);
lbScroll:SetScrollChild(lbContent);

-- Four vertically-aligned columns (same rows => rows line up across columns).
local function makeColumn(font, x, w)
	local fs = lbContent:CreateFontString(nil, "ARTWORK", font);
	fs:SetPoint("TOPLEFT", x, 0);
	fs:SetWidth(w);
	fs:SetJustifyH("LEFT");
	fs:SetJustifyV("TOP");
	fs:SetSpacing(5);
	return fs;
end
local lbName = makeColumn("GameFontNormal", 6, 185);   -- rank + class-coloured name
local lbAP   = makeColumn("GameFontHighlight", 200, 44);
local lbM    = makeColumn("GameFontHighlight", 248, 40);
local lbPct  = makeColumn("GameFontHighlight", 292, 48);

local closeButton = CreateFrame("Button", "RAT_closeButton", leaderBoard, "UIPanelButtonTemplate");
closeButton:SetSize(120, 24);
closeButton:SetPoint("BOTTOM", 0, 16);
closeButton:SetText(CLOSE or "Close");
closeButton:HookScript("OnClick", function()
	leaderBoard:Hide();
end);

local function updateLeaderboard()
	local names, aps, ms, pcts = "", "", "", "";
	for k, v in pairs(RAT_SavedData.Ranks) do
		if (not RAT:GetMain(v)) then
			local d = RAT_SavedData.Attendance[v];
			local shown = v;
			local idx = RAT:GetGuildMemberIndex(v);
			if (idx ~= -1) then
				local classFile = select(11, GetGuildRosterInfo(idx));
				local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile];
				if (c) then
					shown = "|c" .. c.colorStr .. v .. "|r";
				end
			end
			names = names .. d.Rank .. ".  " .. shown .. "\n";
			aps = aps .. d.Attended .. "\n";
			ms = ms .. d.Absent .. "\n";
			pcts = pcts .. d.Percent .. "%\n";
		end
	end
	lbName:SetText(names);
	lbAP:SetText(aps);
	lbM:SetText(ms);
	lbPct:SetText(pcts);
	lbContent:SetHeight(math.max(lbName:GetStringHeight(), 1) + 8);
end

function RAT:InitRaidTimes()
	RAT_SavedOptions.RaidTimes = {};
	RAT_SavedOptions.RaidTimes.Monday = {};
	RAT_SavedOptions.RaidTimes.Tuesday = {};
	RAT_SavedOptions.RaidTimes.Wednesday = {};
	RAT_SavedOptions.RaidTimes.Thursday = {};
	RAT_SavedOptions.RaidTimes.Friday = {};
	RAT_SavedOptions.RaidTimes.Saturday = {};
	RAT_SavedOptions.RaidTimes.Sunday = {};
end

function RAT:SendDebugMessage(msg)
	if (RAT_SavedOptions.Debug) then
		RAT_SavedData.DebugLog[#RAT_SavedData.DebugLog+1] = tostring(date("%y/%m/%d %H:%M:%S")) .." : " .. msg;
		DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.DEBUG .. L.ADDON .. msg);
	end
end

--[[
	Handles all chat commands 
	param(msg) string
]]
local function handler(msg, editbox)
	local arg = RAT:GetArg(msg);
	local cmd = RAT:GetCmd(string.lower(msg));
	if (cmd ~= "") then
		if (cmd == "ranks") then
			-- Read-only: any synced guild member (officer or not) may view the rankings.
			if (synced) then
				RAT:RequestFreshest();
				C_Timer.After(1.5, function()
					RAT:UpdateRank();
					updateLeaderboard();
					if (not leaderBoard:IsShown()) then
						leaderBoard:Show();
					end
				end);
			else
				DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.SYSTEM_STILL_SYNCING1 .. math.floor(syncDelay+0.5) .. L.SYSTEM_STILL_SYNCING3);
			end
		elseif (synced and C_GuildInfo.CanEditOfficerNote()) then
			if (cmd == "award") then
				local args = RAT:Split(arg);
				if (RAT:GetSize(args) == 1) then
					RAT:AllAttended(tonumber(arg), true);
					RAT:BroadcastCommand("AWARDALL", { tonumber(arg) });
				elseif (RAT:GetSize(args) == 2 and tonumber(args[2])) then
					args[1] = args[1]:gsub("^%l", string.upper);
					if (RAT:GetMain(args[1])) then
						args[1] = RAT:GetMain(args[1]);
					end
					local index = RAT:GetGuildMemberIndex(args[1]);
					if (index ~= -1 and RAT:Eligible(index)) then
						RAT:PlayerAttended(args[1], tonumber(args[2]));
						RAT:RebuildRanks();
						RAT:SendGuild(L.ADDON .. args[1] .. L.BROADCAST_AWARDED_PLAYER1 .. args[2] .. L.BROADCAST_AWARDED_PLAYER2);
						RAT:BroadcastCommand("AWARD", { args[1], tonumber(args[2]) });
					else
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_PLAYER_INELIGIBLE);
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_AWARD);
				end
			elseif (cmd == "absent") then
				local args = RAT:Split(arg);
				if (RAT:GetSize(args) == 2 and tonumber(args[2])) then
					args[1] = args[1]:gsub("^%l", string.upper);
					if (RAT:GetMain(args[1])) then
						args[1] = RAT:GetMain(args[1]);
					end
					local index = RAT:GetGuildMemberIndex(args[1]);
					if (index ~= -1 and RAT:Eligible(index)) then
						RAT:PlayerAbsent(args[1], tonumber(args[2]));
						RAT:RebuildRanks();
						RAT:SendGuild(L.ADDON .. args[1] .. L.BROADCAST_ABSENT_PLAYER1 .. args[2] .. L.BROADCAST_ABSENT_PLAYER2);
						RAT:BroadcastCommand("ABSENT", { args[1], tonumber(args[2]) });
					else
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_PLAYER_INELIGIBLE);
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_ABSENT);
				end
			elseif (cmd == "strike") then
				local args = RAT:Split(arg);
				local amount = tonumber(args[2]) or 1;
				args[1] = args[1]:gsub("^%l", string.upper);
				if (RAT:GetMain(args[1])) then
					args[1] = RAT:GetMain(args[1]);
				end
				local index = RAT:GetGuildMemberIndex(args[1]);
				if (index ~= -1 and RAT:Eligible(index)) then
					RAT:StrikePlayer(args[1], amount);
					RAT:RebuildRanks();
					RAT:SendGuild(L.ADDON .. args[1] .. L.BROADCAST_STRIKE_PLAYER1 .. amount .. L.BROADCAST_STRIKE_PLAYER2);
					RAT:BroadcastCommand("STRIKE", { args[1], amount });
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_PLAYER_INELIGIBLE);
				end
			elseif (cmd == "import") then
				local args = RAT:Split(arg);
				args[1] = args[1]:gsub("^%l", string.upper);
				if (RAT:GetMain(args[1])) then
					args[1] = RAT:GetMain(args[1]);
				end
				local index = RAT:GetGuildMemberIndex(args[1]);
				if (index ~= -1 and RAT:Eligible(index) and tonumber(args[2]) and tonumber(args[3])) then
					RAT:Import(args[1], tonumber(args[2]), tonumber(args[3]));
					RAT:RebuildRanks();
					RAT:SendGuild(L.ADDON .. L.BROADCAST_IMPORT_PLAYER1 .. args[1] .. L.BROADCAST_IMPORT_PLAYER2 .. args[2] .. L.BROADCAST_IMPORT_PLAYER3 .. args[3] .. L.BROADCAST_IMPORT_PLAYER4);
					RAT:BroadcastCommand("IMPORT", { args[1], tonumber(args[2]), tonumber(args[3]) });
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_IMPORT);
				end
			elseif (cmd == "update") then
				RAT:UpdateRank();
				DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS ..  L.ADDON .. L.SYSTEM_UPDATE_COMPLETED);
			elseif (cmd == "delete") then
				arg = arg:gsub("^%l", string.upper);
				if (RAT:GetMain(arg)) then
					arg = RAT:GetMain(arg);
				end
				local index = RAT:GetGuildMemberIndex(arg);
				if (index ~= -1 and RAT:Eligible(index)) then
					RAT:DeletePlayer(arg);
					RAT:RebuildRanks();
					RAT:SendGuild(L.ADDON .. L.BROADCAST_DELETED_PLAYER .. arg .. L.DOT);
					RAT:BroadcastCommand("DELETEPLAYER", { arg });
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_PLAYER_INELIGIBLE);
				end
			elseif (cmd == "swap") then
				arg = arg:gsub("^%l", string.upper);
				if (RAT:GetMain(arg)) then
					arg = RAT:GetMain(arg);
				end
				local index = RAT:GetGuildMemberIndex(arg);
				if (index ~= -1 and RAT:Eligible(index)) then
					RAT:PlayerAbsent(arg, 1);
					RAT:PlayerAttended(arg, -1);
					RAT:RebuildRanks();
					RAT:SendGuild(L.ADDON .. arg .. L.BROADCAST_SWAPED_PLAYER);
					RAT:BroadcastCommand("SWAP", { arg });
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_PLAYER_INELIGIBLE);
				end
			elseif (cmd == "skip") then
				RAT:SkipToNextRaidDay();
				RAT:BroadcastSummary();
				RAT_SavedData.Bench = {};
				RAT_SavedData.Summary = {};
			elseif (cmd == "bench") then
				local args = RAT:Split(arg);
				if (RAT:GetSize(args) == 1) then
					arg = arg:gsub("^%l", string.upper);
					if (RAT:GetMain(arg)) then
						arg = RAT:GetMain(arg);
						arg = RAT:CleanName(arg);
					end
					local index = RAT:GetGuildMemberIndex(arg);
					if (index ~= -1 and RAT:Eligible(index)) then
						if (not RAT:IsBenched(arg)) then
							RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = arg;
							RAT:Touch();
							RAT:SendGuild(L.ADDON .. arg .. L.BROADCAST_BENCHED_PLAYER);
							RAT:BroadcastCommand("BENCH", { arg });
						else
							DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_BENCHED_ALREADY);
						end
					else
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_PLAYER_INELIGIBLE);
					end
				end
			elseif (cmd == "alt") then
				local args = RAT:Split(arg);
				if (RAT:GetSize(args) == 2) then
					args[1] = args[1]:gsub("^%l", string.upper);
					args[2] = args[2]:gsub("^%l", string.upper);
					local mainIndex = RAT:GetGuildMemberIndex(args[1]);
					local altIndex = RAT:GetGuildMemberIndex(args[2]);
					if (args[1] ~= args[2] and mainIndex ~= -1 and RAT:Eligible(mainIndex) and altIndex ~= -1) then
						RAT_SavedData.Alts[args[2]] = args[1];
						if (RAT_SavedData.Attendance[args[2]]) then
							RAT_SavedData.Attendance[args[2]] = nil;
						end
						RAT:RebuildRanks();
						RAT:Touch();
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS .. L.ADDON .. args[2] .. L.SYSTEM_ALT_ADDED .. args[1] .. L.DOT);
						RAT:BroadcastCommand("ALT", { args[2], args[1] });
					else
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_ALT);
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_ALT);
				end
			elseif (cmd == "undo") then
				if ((next(lastAttending) or next(lastAbsent)) and lastAmount) then
					RAT:Undo(lastAttending, lastAbsent, lastAmount);
					RAT:BroadcastCommand("UNDO", {});
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.ERROR_UNDO);
				end
			elseif (cmd == "sync") then
				RAT:RequestFreshest();
				DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS .. L.ADDON .. L.SYSTEM_STARTED_SYNC);
			elseif (cmd == "debug") then
				if (RAT_SavedOptions.Debug == false) then
					RAT_SavedOptions.Debug = true;
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS .. L.ADDON .. L.SYSTEM_DEBUG_ENABLED);
				else
					RAT_SavedOptions.Debug = false;
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS .. L.ADDON .. L.SYSTEM_DEBUG_DISABLED);
				end
			end
		elseif (not C_GuildInfo.CanEditOfficerNote()) then
			DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ERROR_NOT_OFFICER);
		else
			DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.SYSTEM_STILL_SYNCING1 .. math.floor(syncDelay+0.5) .. L.SYSTEM_STILL_SYNCING3);
		end
	else
		Settings.OpenToCategory(RAT.OptionsCategories.Options:GetID());
	end
end

SlashCmdList["RAIDATTENDANCETRACKER"] = handler;
f:RegisterEvent("ADDON_LOADED");
f:RegisterEvent("PLAYER_LOGIN");
f:RegisterEvent("CHAT_MSG_RAID");
f:RegisterEvent("CHAT_MSG_RAID_LEADER");
f:RegisterEvent("CHAT_MSG_WHISPER");
f:RegisterEvent("CHAT_MSG_ADDON");
f:RegisterEvent("GUILD_ROSTER_UPDATE");
C_ChatInfo.RegisterAddonMessagePrefix("RATSYSTEM");

f:SetScript("OnUpdate", function(self, elapsed)
	if (playersRegister and C_GuildInfo.CanEditOfficerNote()) then
		ticks = ticks - elapsed;
	end
	if (not synced) then
		syncDelay = syncDelay - elapsed;
	end
	if (syncDelay <= 0 and not synced) then
		RAT:SendDebugMessage("Sync delay has passed. Requesting Guild Roster..., Starting Sync");
		synced = true;
		C_GuildInfo.GuildRoster();
		RAT:ReconcileRoster();
		RAT:BroadcastVersion();
	end
	local time = GetServerTime();
	if (time > RAT_SavedData.NextAward and RAT_SavedData.NextAward ~= 0) then
		local freq = RAT_SavedOptions.Frequency * 60;
		if (time > RAT_SavedData.NextAward + 60) then --Player is considered late
			RAT:SendDebugMessage("The time for NextAward: " .. RAT_SavedData.NextAward .. " has passed as time is: " .. time .. " but the player is considered late causing no rewards to be given out and calculating when the next reward should be...");
			RAT:RecoverNextAward(time);
			RAT_SavedData.Summary = {};
			if (C_GuildInfo.CanEditOfficerNote()) then
				RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward-time));
				C_ChatInfo.SendAddonMessage("RATSYSTEM", "GETBENCH", "GUILD");
			end
		else
			if (RAT:IsItRaidStart()) then
				RAT_SavedData.Bench = {};
				RAT_SavedData.Summary = {};
				if (not RAT_SavedOptions.AwardStart) then
					RAT:SendDebugMessage("NextAward passed but rewards on raid start is turned off.");
					RAT:SetNextAward(time);
					return;
				end
			end
			RAT:SendDebugMessage("NextAward passed; rewards will be given out.");
			RAT:SetNextAward(time);
			if (IsInRaid()) then
				RAT.Users = {};   -- reset so only officers who respond this round are considered for posting
				C_ChatInfo.SendAddonMessage("RATSYSTEM", "GETRANK", "RAID");
				C_Timer.After(10, function()
					local amPoster = (RAT:GetHighestRankingUser() == GetUnitName("player", true)) and C_GuildInfo.CanEditOfficerNote() and true or false;
					RAT:AllAttended(1, amPoster);
					if (RAT_SavedOptions.PunishCalendar and RAT:IsItRaidStart() and amPoster) then
						RAT:PunishCalendar();
					end
					if (amPoster) then
						RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward-time));
					end
					if (RAT:IsItRaidFinish()) then
						RAT:SendDebugMessage("Raid ended. Sending summary and reseting variables...");
						C_Timer.NewTicker(1, function(s)
							if (not RAT:IsAwardHandOutRunning()) then
								if (amPoster) then
									RAT:BroadcastSummary();
								end
								RAT_SavedData.Bench = {};
								RAT_SavedData.Summary = {};
								RAT:SendDebugMessage("Variables have been reset");
								s:Cancel();
								s = nil;
							end
						end);
					end
				end);
			end
		end
	end
	if (ticks <= 0 and playersRegister and C_GuildInfo.CanEditOfficerNote()) then
		playersRegister = false;
		ticks = 0;
		currentIndex = 0;
		C_ChatInfo.SendChatMessage("RAT: Highest ranked player: " .. RAT:GetHighestRankedPlayer(playersToRank), "RAID",  nil, nil);
		playersToRank = {};
	end
end);

f:SetScript("OnEvent", function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addonLoaded = ...;
		if (addon == addonLoaded) then
			if (RAT_SavedData == nil) then RAT_SavedData = {}; end
			if (RAT_SavedOptions == nil) then RAT_SavedOptions = {}; end

			if (RAT_SavedData.Attendance == nil) then RAT_SavedData.Attendance = {}; end
			--if (RAT_SavedData.AltDb == nil) then RAT_SavedData.AltDb = {}; end
			if (RAT_SavedData.Ranks == nil) then RAT_SavedData.Ranks = {}; end
			if (RAT_SavedData.Log == nil) then RAT_SavedData.Log = {}; end
			if (RAT_SavedData.NextAward == nil) then RAT_SavedData.NextAward = 0; end
			if (RAT_SavedData.Bench == nil) then RAT_SavedData.Bench = {}; end
			if (RAT_SavedData.Summary == nil) then RAT_SavedData.Summary = {}; end
			if (RAT_SavedData.SetupCompleted == nil) then RAT_SavedData.SetupCompleted = false; end
			if (RAT_SavedData.DebugLog == nil) then RAT_SavedData.DebugLog = {}; end
			if (RAT_SavedData.Alts == nil) then RAT_SavedData.Alts = {}; end
			if (RAT_SavedData.LastModified == nil) then RAT_SavedData.LastModified = 0; end

			if (RAT_SavedOptions.RaidTimes == nil) then RAT:InitRaidTimes(); end
			if (RAT_SavedOptions.AwardStart == nil) then RAT_SavedOptions.AwardStart = true; end
			if (RAT_SavedOptions.Frequency == nil) then RAT_SavedOptions.Frequency = 60; end
			if (RAT_SavedOptions.RankingAlgo == nil) then RAT_SavedOptions.RankingAlgo = "RAT-Algorithm"; end
			if (RAT_SavedOptions.PunishCalendar == nil) then RAT_SavedOptions.PunishCalendar = false; end
			if (RAT_SavedOptions.RaiderRanks == nil) then RAT_SavedOptions.RaiderRanks = {}; end
			if (RAT_SavedOptions.OfficerRanks == nil) then RAT_SavedOptions.OfficerRanks = {}; end
			if (RAT_SavedOptions.Debug == nil) then RAT_SavedOptions.Debug = false; end
		end
	elseif (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") then
		local message, sender = ...;
		message = string.lower(message);
		if (message == "!rat" and synced) then
			sender = RAT:CleanName(sender);
			ticks = 6;
			playersRegister = true;
			playersToRank[currentIndex] = sender;
			currentIndex = currentIndex + 1;
		end
	elseif (event == "CHAT_MSG_WHISPER") then
		local message, sender = ...;
		local fullNameSender = sender;
		local replyTo = RAT:WhisperTarget(fullNameSender); -- full Name-Realm for whisper replies
		message = strtrim(string.lower(message)); -- tolerate case / stray whitespace
		sender = RAT:CleanName(sender);
		local arg = RAT:GetArg(message);
		local cmd = RAT:GetCmd(message);
			if (cmd == "!rat") then
				local args = RAT:Split(arg);
				local index = RAT:GetGuildMemberIndex(sender);
				if (arg == "bench") then
					if (C_GuildInfo.CanEditOfficerNote()) then
						if (RAT:GetMain(sender)) then
							local main = RAT:GetMain(sender);
							sender = main;
							index = RAT:GetGuildMemberIndex(main);
						end
						if (RAT:Eligible(index) and not RAT:IsBenched(sender)) then
							RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = sender;
							RAT:Touch();
							RAT:SendGuild(L.ADDON .. sender .. L.BROADCAST_BENCHED_PLAYER);
							RAT:BroadcastCommand("BENCH", { sender });
						elseif (RAT:IsBenched(sender)) then
							C_ChatInfo.SendChatMessage(L.ADDON .. sender .. L.ERROR_BENCHED_ALREADY, "WHISPER", nil, replyTo);
						end
					end
				elseif (RAT:GetSize(args) == 2 and args[1] == "alt") then
					if (C_GuildInfo.CanEditOfficerNote()) then
						local main = args[2]:gsub("^%l", string.upper);
						local mainIndex = RAT:GetGuildMemberIndex(main);
						local altIndex = RAT:GetGuildMemberIndex(sender);
						if (sender ~= main and mainIndex ~= -1 and RAT:Eligible(mainIndex) and altIndex ~= -1) then
							RAT_SavedData.Alts[sender] = main;
							if (RAT_SavedData.Attendance[sender]) then
								RAT_SavedData.Attendance[sender] = nil;
							end
							RAT:RebuildRanks();
							RAT:Touch();
							C_ChatInfo.SendChatMessage(L.ADDON .. sender .. L.SYSTEM_ALT_ADDED .. main .. L.DOT, "WHISPER", nil, replyTo);
							RAT:BroadcastCommand("ALT", { sender, main });
						else
							C_ChatInfo.SendChatMessage(L.ADDON .. args[2] .. L.ERROR_PLAYER_INELIGIBLE, "WHISPER", nil, replyTo);
						end
					end
				elseif (arg == "help") then
					C_ChatInfo.SendChatMessage(L.ADDON .. L.HELP1, "WHISPER", nil, replyTo);
					C_ChatInfo.SendChatMessage(L.HELP2, "WHISPER", nil, replyTo);
				elseif (arg == "myrank") then
					local target = sender;
					if (RAT:GetMain(sender)) then target = RAT:GetMain(sender); end
					local d = RAT_SavedData.Attendance[target];
					if (d) then
						C_ChatInfo.SendChatMessage(L.ADDON .. L.MYRANK1 .. d.Rank .. L.MYRANK2 .. d.Attended .. L.MYRANK3 .. d.Absent .. L.MYRANK4 .. d.Percent .. "%", "WHISPER", nil, replyTo);
					else
						C_ChatInfo.SendChatMessage(L.ADDON .. L.MYRANK_NONE, "WHISPER", nil, replyTo);
					end
				end
			end
	elseif (event == "CHAT_MSG_ADDON") then
		local prefix, msg, channel, sender = ...;
		if (prefix == "RATSYSTEM") then
			RAT:HandleInbound(msg, sender);
		end
	elseif (event == "GUILD_ROSTER_UPDATE" and C_GuildInfo.CanEditOfficerNote()) then
		if (awaitingSync) then
			awaitingSync = false;
			RAT:RebuildRanks();
		end
	elseif (event == "PLAYER_LOGIN") then
		RAT:InitComms();
		-- 4.0: every client (officer or not) runs OnUpdate so all in-raid clients compute awards locally.
		C_Timer.After(5, function()
			if (C_GuildInfo.CanEditOfficerNote()) then
				RAT:CheckForDSTTransition();
			end
		end);
		--[[
			if (RAT_SavedOptions.MinimapMode == "Always") then
				RAT_MinimapButton:Show();
			else
				RAT_MinimapButton:Hide();
			end
		]]
		if (not RAT_SavedData.SetupCompleted and IsInGuild()) then
			RAT:StartSetup();
		end
	end
end);

function RAT:IsBenched(pl)
	for i = 1, RAT:GetSize(RAT_SavedData.Bench) do
		if (pl == RAT_SavedData.Bench[i]) then
			return true;
		end
	end
	return false;
end

function RAT:GetBench() 
	return RAT_SavedData.Bench;
end
function RAT:GetLastAttending()
	return lastAttending;
end
function RAT:SetLastAttending(players)
	lastAttending = players;
end
function RAT:GetLastAbsent()
	return lastAbsent;
end
function RAT:SetLastAbsent(players)
	lastAbsent = players;
end
function RAT:GetLastAmount()
	return lastAmount;
end
function RAT:SetLastAmount(amount)
	lastAmount = amount;
end
--[[
function RAT:InitAlt(pl)
	RAT_SavedData.AltDb[pl] = {};
	RAT_SavedData.AltDb[pl].Alts = {};
	RAT_SavedData.AltDb[pl].IsAlt = false;
end]]

function RAT:UpdateGuild()
	awaitingSync = true;
	C_GuildInfo.GuildRoster();
end
-- local function _CalendarFrame_InviteToRaid(maxInviteCount)
-- 	local inviteCount = 0;
-- 	local i = 1;
-- 	while ( inviteCount < maxInviteCount and i <= CalendarEventGetNumInvites() ) do
-- 		local name, level, className, classFilename, inviteStatus = CalendarEventGetInvite(i);
-- 		if ( not UnitInParty(name) and not UnitInRaid(name) and
-- 			 (inviteStatus == CALENDAR_INVITESTATUS_ACCEPTED or
-- 			 inviteStatus == CALENDAR_INVITESTATUS_CONFIRMED or
-- 			 inviteStatus == CALENDAR_INVITESTATUS_SIGNEDUP) ) then
-- 			InviteUnit(name);
-- 			inviteCount = inviteCount + 1;
-- 		end
-- 		i = i + 1;
-- 	end
-- 	return inviteCount;
-- end
--CalendarFrame.selectedDayButton;
--CalendarGetDayEvent(monthoffset, day, index)

local function benchFilterRecieve(self, event, msg)
	if (msg == "!rat bench") then
		return true;
	end
	return false;
end

local function helpFilterRecieve(self, event, msg)
	if (msg == "!rat help") then
		return true;
	end
	return false;
end

local function helpFilterSend(self, event, msg)
	if (msg == L.HELP2 or msg == (L.ADDON .. L.HELP1)) then
		return true;
	end
	return false;
end

local function altFilterSend(self, event, msg)
	if (msg:find(L.ADDON) and (msg:find(L.SYSTEM_ALT_ADDED .. L.DOT) or (msg:find(L.ERROR_PLAYER_INELIGIBLE_OR) and msg:find(L.ERROR_PLAYER_INELIGIBLE)) or msg:find(L.ERROR_ALT_ALREADY))) then
		return true;
	end
	return false;
end

local function altFilterRecieve(self, event, msg)
	if (msg:find("!rat alt") and msg ~= L.HELP2) then
		return true;
	end
	return false;
end

local function benchFilterSend(self, event, msg)
	if (msg:find(L.ADDON) and msg:find(L.ERROR_BENCHED_ALREADY)) then
		return true;
	end
	return false;
end

local function myrankFilterRecieve(self, event, msg)
	return strtrim(string.lower(msg or "")) == "!rat myrank";
end

local function myrankFilterSend(self, event, msg)
	if (msg:find(L.ADDON) and (msg:find(L.MYRANK2, 1, true) or msg:find(L.MYRANK_NONE, 1, true))) then
		return true;
	end
	return false;
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", benchFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", helpFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", altFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", helpFilterSend);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", altFilterSend);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", benchFilterSend);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", myrankFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", myrankFilterSend);

local options = CreateFrame("Frame");
options:Hide();

RAT.OptionsCategories = {};
RAT.OptionsCategories.Options = Settings.RegisterCanvasLayoutCategory(options, "Raid Attendance Tracker");
Settings.RegisterAddOnCategory(RAT.OptionsCategories.Options);

function RAT_OnAddonCompartmentClick(addonName, buttonName)
	Settings.OpenToCategory(RAT.OptionsCategories.Options:GetID());
end

--------------------------
------Blizzard Taint------
--------------------------
if ((UIDROPDOWNMENU_OPEN_PATCH_VERSION or 0) < 1) then
	UIDROPDOWNMENU_OPEN_PATCH_VERSION = 1;
	hooksecurefunc("UIDropDownMenu_InitializeHelper", function(frame)
		if (UIDROPDOWNMENU_OPEN_PATCH_VERSION ~= 1) then
			return;
		end
		if (UIDROPDOWNMENU_OPEN_MENU and UIDROPDOWNMENU_OPEN_MENU ~= frame and not issecurevariable(UIDROPDOWNMENU_OPEN_MENU, "displayMode")) then
			UIDROPDOWNMENU_OPEN_MENU = nil;
			local t, f, prefix, i = _G, issecurevariable, " \0", 1;
			repeat
				i, t[prefix .. i] = i + 1;
			until f("UIDROPDOWNMENU_OPEN_MENU")
		end
	end)
end
if ((UIDROPDOWNMENU_VALUE_PATCH_VERSION or 0) < 2) then
	UIDROPDOWNMENU_VALUE_PATCH_VERSION = 2;
	hooksecurefunc("UIDropDownMenu_InitializeHelper", function()
		if (UIDROPDOWNMENU_VALUE_PATCH_VERSION ~= 2) then
			return;
		end
		for i=1, UIDROPDOWNMENU_MAXLEVELS do
			for j=1, UIDROPDOWNMENU_MAXBUTTONS do
				local b = _G["DropDownList" .. i .. "Button" .. j];
				if (not (issecurevariable(b, "value") or b:IsShown())) then
					b.value = nil;
					repeat
						j, b["fx" .. j] = j+1;
					until issecurevariable(b, "value")
				end
			end
		end
	end)
end