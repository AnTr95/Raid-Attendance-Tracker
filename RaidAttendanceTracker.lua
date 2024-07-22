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
local lastAntiCheat = 0;
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

local leaderBoard = CreateFrame("Frame", nil, nil, BackdropTemplateMixin and "BackdropTemplate");
leaderBoard:SetWidth(180);
leaderBoard:SetHeight(450);
leaderBoard:SetPoint("CENTER");
leaderBoard:SetMovable(true);
leaderBoard:EnableMouse(true);
leaderBoard:RegisterForDrag("LeftButton");
leaderBoard:SetFrameLevel(3);
leaderBoard:SetScript("OnDragStart", leaderBoard.StartMoving);
leaderBoard:SetScript("OnDragStop", leaderBoard.StopMovingOrSizing);
leaderBoard:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", --Set the background and border textures
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
});
leaderBoard:SetBackdropColor(0.3,0.3,0.3,0.6);
leaderBoard:Hide();

local texture = leaderBoard:CreateTexture();
texture:SetTexture(0.5, 0.5, 0.5, 0.5);
texture:SetAllPoints();

local leaderboardText = leaderBoard:CreateFontString(nil, "ARTWORK", "GameFontNormal");
leaderboardText:ClearAllPoints();
leaderboardText:SetPoint("TOP", 0, -10);
leaderboardText:SetText("");


local closeButton = CreateFrame("Button", "RAT_closeButton", leaderBoard, "UIPanelButtonTemplate");
closeButton:SetSize(160, 25);
closeButton:SetPoint("BOTTOM", 0, 10);
closeButton:SetText("OK");
closeButton:HookScript("OnClick", function(frame)
	leaderBoard:Hide();
end);

local function updateLeaderboard()
	local text = "";
	for k, v in pairs(RAT_SavedData.Ranks) do
		if (not RAT:GetMain(v)) then
			local plRank = RAT_SavedData.Attendance[v].Rank;
			text = text .. plRank .. ". " .. v .. "\n";
		end
	end
	leaderboardText:SetText(text);
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
	msg = string.lower(msg);
	local arg = RAT:GetArg(msg);
	local cmd = RAT:GetCmd(msg);
	if (cmd ~= "") then
		if (synced and C_GuildInfo.CanEditOfficerNote()) then
			if (cmd == "award") then
				local args = RAT:Split(arg);
				if (RAT:GetSize(args) == 1) then
					RAT:AllAttended(arg);
					C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				elseif (RAT:GetSize(args) == 2 and tonumber(args[2])) then
					args[1] = args[1]:gsub("^%l", string.upper);
					if (RAT:GetMain(args[1])) then
						args[1] = RAT:GetMain(args[1]);
					end
					local index = RAT:GetGuildMemberIndex(args[1]);
					if (index ~= -1 and RAT:Eligible(index)) then
						RAT:PlayerAttended(args[1], args[2]);
						C_Timer.After(2, function() RAT:UpdatePlayerAlts(args[1]); end);
						SendChatMessage(L.ADDON .. args[1] .. L.BROADCAST_AWARDED_PLAYER1 .. args[2] .. L.BROADCAST_AWARDED_PLAYER2, "GUILD");
						C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
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
						RAT:PlayerAbsent(args[1], args[2]);
						C_Timer.After(2, function() RAT:UpdatePlayerAlts(args[1]); end);
						SendChatMessage(L.ADDON .. args[1] .. L.BROADCAST_ABSENT_PLAYER1 .. args[2] .. L.BROADCAST_ABSENT_PLAYER2, "GUILD");
						C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
					else
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_PLAYER_INELIGIBLE);
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_ABSENT);
				end
			elseif (cmd == "strike") then
				local args = RAT:Split(arg);
				local amount = args[2] or 1;
				args[1] = args[1]:gsub("^%l", string.upper);
				if (RAT:GetMain(args[1])) then
					args[1] = RAT:GetMain(args[1]);
				end
				local index = RAT:GetGuildMemberIndex(args[1]);
				if (index ~= -1 and RAT:Eligible(index)) then
					RAT:StrikePlayer(args[1], amount);
					C_Timer.After(2, function() RAT:UpdatePlayerAlts(args[1]); end);
					SendChatMessage(L.ADDON .. args[1] .. L.BROADCAST_STRIKE_PLAYER1 .. amount .. L.BROADCAST_STRIKE_PLAYER2, "GUILD");
					C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
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
				if (index ~= -1 and RAT:Eligible(index)) then
					RAT:Import(args[1], args[2], args[3]);
					C_Timer.After(2, function() RAT:UpdatePlayerAlts(args[1]); end);
					SendChatMessage(L.ADDON .. L.BROADCAST_IMPORT_PLAYER1 .. args[1] .. L.BROADCAST_IMPORT_PLAYER2 .. args[2] .. L.BROADCAST_IMPORT_PLAYER3 .. args[3] .. L.BROADCAST_IMPORT_PLAYER4, "GUILD");
					C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_PLAYER_INELIGIBLE);
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
					SendChatMessage(L.ADDON .. L.BROADCAST_DELETED_PLAYER .. arg .. L.DOT, "GUILD");
					C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_PLAYER_INELIGIBLE);
				end
			--elseif (cmd == "winter") then
			--	RAT_SavedData.NextAward = RAT_SavedData.NextAward + 3600;
			--elseif (cmd == "summer") then
			--	RAT_SavedData.NextAward = RAT_SavedData.NextAward - 3600;
			elseif (cmd == "swap") then
				arg = arg:gsub("^%l", string.upper);
				if (RAT:GetMain(arg)) then
					arg = RAT:GetMain(arg);
				end
				local index = RAT:GetGuildMemberIndex(arg);
				if (index ~= -1 and RAT:Eligible(index)) then
					RAT:PlayerAbsent(arg, 1);
					RAT:PlayerAttended(arg, -1);
					C_Timer.After(2, function() RAT:UpdatePlayerAlts(arg); end);
					SendChatMessage(L.ADDON .. arg .. L.BROADCAST_SWAPED_PLAYER, "GUILD");
					C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_PLAYER_INELIGIBLE);
				end
			elseif (cmd == "skip") then
				RAT:SkipToNextRaidDay();
				RAT:BroadcastSummary();
				RAT_SavedData.Bench = {};
				RAT_SavedData.Summary = {};
			elseif (cmd == "ranks") then
				RAT:UpdateRank();
				if (leaderBoard:IsShown()) then
					leaderBoard:Hide();
				else
					updateLeaderboard();
					leaderBoard:Show();
				end
			elseif (cmd == "bench") then
				local args = RAT:Split(arg);
				if (RAT:GetSize(args) == 1) then
					arg = arg:gsub("^%l", string.upper);
					if (RAT:GetMain(arg)) then
						arg = RAT:GetMain(arg);
					end
					local index = RAT:GetGuildMemberIndex(arg);
					if (index ~= -1 and RAT:Eligible(index)) then
						if (not RAT:IsBenched(arg)) then
							RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = arg;
							local msg = "BENCH " .. arg;
							C_ChatInfo.SendAddonMessage("RATSYSTEM", msg, "GUILD");
							SendChatMessage(L.ADDON .. arg .. L.BROADCAST_BENCHED_PLAYER, "GUILD");
						else
							DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_BENCHED_ALREADY);
						end
					else
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. arg .. L.ERROR_PLAYER_INELIGIBLE);
					end
				end
			elseif (cmd == "alt") then
				local args = RAT:Split(arg);
				args[1] = args[1]:gsub("^%l", string.upper);
				args[2] = args[2]:gsub("^%l", string.upper);
				if (RAT:GetSize(args) == 2) then
					local mainIndex = RAT:GetGuildMemberIndex(args[1]);
					local altIndex = RAT:GetGuildMemberIndex(args[2]);
					local altNote = select(8, GetGuildRosterInfo(altIndex));
					local mainNote = select(8, GetGuildRosterInfo(mainIndex));
					if (args[1] ~= args[2]) then
						--if (not RAT:ContainsKey(RAT_SavedData.AltDb, args[1]) and mainIndex ~= -1 and RAT:Eligible(mainIndex) and altIndex ~= -1) then
						--	RAT:InitAlt(args[1]);
						--end	
						--if (not RAT:Contains(RAT_SavedData.AltDb[args[1]].Alts, args[2]) and mainIndex ~= -1 and RAT:Eligible(mainIndex) and altIndex ~= -1) then	
						--	table.insert(RAT_SavedData.AltDb[args[1]].Alts, args[2]);
						--	RAT:UpdatePlayerAlts(args[1]);
						--	DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS .. L.ADDON .. args[2] .. L.SYSTEM_ALT_ADDED .. args[1] .. L.DOT);
						--	C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
						if (altNote ~= args[1] and mainIndex ~= -1 and RAT:Eligible(mainIndex) and altIndex ~= -1) then
							GuildRosterSetOfficerNote(altIndex, args[1]);
							GuildRosterSetPublicNote(altIndex, mainNote)
							DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.SUCCESS .. L.ADDON .. args[2] .. L.SYSTEM_ALT_ADDED .. args[1] .. L.DOT);
						elseif (altNote == args[1]) then
							DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_ALT_ALREADY .. args[2] .. L.DOT);
						else
							DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. args[1] .. L.ERROR_PLAYER_INELIGIBLE_OR .. args[2] .. L.ERROR_PLAYER_INELIGIBLE);
						end
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.SYNTAX_ALT);
				end
			elseif (cmd == "undo") then
				if ((next(lastAttending) or next(lastAbsent)) and lastAmount) then
					RAT:Undo(lastAttending, lastAbsent, lastAmount);
					C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
				else
					DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.ERROR_UNDO);
				end
			elseif (cmd == "sync") then
				RAT:Sync();
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
		InterfaceOptionsFrame_OpenToCategory(RAT_RT_Options);
		InterfaceOptionsFrame_OpenToCategory(RAT_RT_Options);
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
	if (not synced and C_GuildInfo.CanEditOfficerNote()) then
		syncDelay = syncDelay - elapsed;
	end
	if (syncDelay <= 0 and not synced and C_GuildInfo.CanEditOfficerNote()) then
		RAT:SendDebugMessage("Sync delay has passed. Requesting Guild Roster..., Starting Sync");
		synced = true;
		C_GuildInfo.GuildRoster();
		RAT:Sync();
		--RAT:CleanAltDb();
	end
	lastAntiCheat = lastAntiCheat + elapsed;
	local time = GetServerTime();
	if (time > RAT_SavedData.NextAward and RAT_SavedData.NextAward ~= 0 and C_GuildInfo.CanEditOfficerNote()) then
		local freq = RAT_SavedOptions.Frequency * 60;
		if (time > RAT_SavedData.NextAward + 60) then --Player is considered late
			RAT:SendDebugMessage("The time for NextAward: " .. RAT_SavedData.NextAward .. " has passed as time is: " .. time .. " but the player is considered late causing no rewards to be given out and calculating when the next reward should be... Also requesting the bench from other addon users.");
			RAT:RecoverNextAward(time);
			RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward-time));
			RAT_SavedData.Summary = {};
			C_ChatInfo.SendAddonMessage("RATSYSTEM", "GETBENCH", "GUILD");
		else
			if (RAT:IsItRaidStart()) then 
				RAT_SavedData.Bench = {};
				RAT_SavedData.Summary = {};
				if (not RAT_SavedOptions.AwardStart) then
					RAT:SendDebugMessage("The time for NextAward: " .. RAT_SavedData.NextAward .. " has passed as time is: " .. time .. " but rewards on raid start is turned off.");
					RAT:SetNextAward(time);
					--Dont award raid start
					return;
				end
			end
			RAT:SendDebugMessage("The time for NextAward: " .. RAT_SavedData.NextAward .. " has passed as time is: " .. time .. " and rewards will be given out.");
			RAT:SetNextAward(time);
			--RAT:CleanAltDb();
			--C_ChatInfo.SendAddonMessage("RATSYSTEM", "GETALTS", "GUILD");
			if (IsInRaid()) then
				C_ChatInfo.SendAddonMessage("RATSYSTEM", "GETRANK", "RAID");
				C_Timer.After(10, function()
					if (RAT:GetHighestRankingUser() == UnitName("player") and synced) then
						RAT:AllAttended(1);
						if (RAT_SavedOptions.PunishCalendar and RAT:IsItRaidStart()) then
							RAT:PunishCalendar();
						end
						RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward-time));
						C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
						if (RAT:IsItRaidFinish()) then
							RAT:SendDebugMessage("Raid ended. Sending summary and reseting variables...");
							C_Timer.NewTicker(1, function(s)
								if (not RAT:IsAwardHandOutRunning()) then
									RAT:BroadcastSummary();
									RAT_SavedData.Bench = {};
									RAT_SavedData.Summary = {};
									RAT:SendDebugMessage("Variables have been reset");
									s:Cancel();
									s = nil;
								end
							end);
						end
					elseif (not synced) then
						DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.SYSTEM_STILL_SYNCING1 .. L.SYSTEM_STILL_SYNCING2 .. math.floor(syncDelay+0.5) .. L.SYSTEM_STILL_SYNCING3);
					end
				end);
			end
		end
	end
	if (ticks <= 0 and playersRegister and C_GuildInfo.CanEditOfficerNote()) then
		playersRegister = false;
		ticks = 0;
		currentIndex = 0;
		SendChatMessage("RAT: Highest ranked player: " .. RAT:GetHighestRankedPlayer(playersToRank), "RAID",  nil, nil);
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

			if (RAT_SavedOptions.RaidTimes == nil) then RAT:InitRaidTimes(); end
			if (RAT_SavedOptions.AwardStart == nil) then RAT_SavedOptions.AwardStart = true; end
			if (RAT_SavedOptions.Frequency == nil) then RAT_SavedOptions.Frequency = 60; end
			if (RAT_SavedOptions.RankingAlgo == nil) then RAT_SavedOptions.RankingAlgo = "RAT-Algorithm"; end
			if (RAT_SavedOptions.PunishCalendar == nil) then RAT_SavedOptions.PunishCalendar = false; end
			if (RAT_SavedOptions.RaiderRanks == nil) then RAT_SavedOptions.RaiderRanks = {}; end
			if (RAT_SavedOptions.Debug == nil) then RAT_SavedOptions.Debug = false; end
		end
	elseif (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") then
		local message, sender = ...;
		message = string.lower(message);
		if (message == "!rat" and synced) then
			sender = Ambiguate(sender, "short");
			ticks = 6;
			playersRegister = true;
			playersToRank[currentIndex] = sender;
			currentIndex = currentIndex + 1;
		end
	elseif (event == "CHAT_MSG_WHISPER") then
		local message, sender = ...;
		message = string.lower(message);
		sender = Ambiguate(sender, "short");
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
						SendChatMessage(L.ADDON .. sender .. L.BROADCAST_BENCHED_PLAYER, "GUILD");
						C_ChatInfo.SendAddonMessage("RATSYSTEM", "BENCH " .. sender, "GUILD");
					elseif (RAT:IsBenched(sender)) then
						SendChatMessage(L.ADDON .. sender .. L.ERROR_BENCHED_ALREADY, "WHISPER", nil, sender);
					end
				else
					--Cant Promote
				end
			elseif (RAT:GetSize(args) == 2 and args[1] == "alt") then
				if (C_GuildInfo.CanEditOfficerNote()) then
					local main = args[2];
					main = main:gsub("^%l", string.upper);
					local mainIndex = RAT:GetGuildMemberIndex(main);
					local altIndex = RAT:GetGuildMemberIndex(sender);
					local altNote = select(8, GetGuildRosterInfo(altIndex));
					local mainNote = select(8, GetGuildRosterInfo(mainIndex));
					if (sender ~= main) then
						if (altNote ~= main and mainIndex ~= -1 and RAT:Eligible(mainIndex) and altIndex ~= -1) then
							GuildRosterSetOfficerNote(altIndex, main);
							GuildRosterSetPublicNote(altIndex, mainNote)
							SendChatMessage(L.ADDON .. sender .. L.SYSTEM_ALT_ADDED .. main .. L.DOT, "WHISPER", nil, sender);
						--	RAT:InitAlt(main);
						--if (not RAT:Contains(RAT_SavedData.AltDb[main].Alts, sender) and mainIndex ~= -1 and RAT:Eligible(mainIndex) and RAT:GetGuildMemberIndex(sender) ~= -1) then
						--	table.insert(RAT_SavedData.AltDb[main].Alts, sender);
						--RAT:UpdatePlayerAlts(main);
						--	C_ChatInfo.SendAddonMessage("RATSYSTEM", "SYNCATTENDANCE", "GUILD");
						elseif (altNote == main) then
							SendChatMessage(L.ADDON .. sender .. L.ERROR_ALT_ALREADY .. main .. L.DOT, "WHISPER", nil, sender);
						else
							SendChatMessage(L.ADDON .. args[2] .. L.ERROR_PLAYER_INELIGIBLE, "WHISPER", nil, sender);
						end
					end
				else
					--Cant promote
				end
			elseif (arg == "help") then
				SendChatMessage(L.ADDON .. L.HELP1, "WHISPER", nil, sender);
				SendChatMessage(L.HELP2, "WHISPER", nil, sender);
			end
		end
	elseif (event == "CHAT_MSG_ADDON") then
		local prefix, msg, channel, sender = ...;
		sender = Ambiguate(sender, "short");
		if (prefix == "RATSYSTEM" and Ambiguate(UnitName("player"), "short") ~= sender) then
			msg = RAT:Split(msg);
			local internalPrefix = msg[1];
			if (internalPrefix and internalPrefix == "BENCH") then
				if (C_GuildInfo.CanEditOfficerNote()) then
					local raider = msg[2];
					if (raider and not RAT:IsBenched(raider)) then
						RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = raider;
					end
				end
			elseif (internalPrefix and internalPrefix == "GETRANK" and synced) then
				if (C_GuildInfo.CanEditOfficerNote()) then
					local sendMsg = "RETURNRANK " .. UnitName("player") .. " " .. select(3, GetGuildInfo("player"));
					C_ChatInfo.SendAddonMessage("RATSYSTEM", sendMsg, "WHISPER", sender);
				end
			elseif (internalPrefix and internalPrefix == "RETURNRANK") then
				if (C_GuildInfo.CanEditOfficerNote()) then
					local user = msg[2];
					local rank = tonumber(msg[3]);
					if (user and rank) then
						if (not RAT:ContainsKey(RAT.Users, user)) then
							RAT.Users[user] = rank;
						end
					end
				end
			elseif (internalPrefix and internalPrefix == "SYNCATTENDANCE") then
				awaitingSync = true;
				C_GuildInfo.GuildRoster();
			elseif (internalPrefix and internalPrefix == "GETBENCH") then
				if (C_GuildInfo.CanEditOfficerNote()) then
					for i, pl in pairs(RAT_SavedData.Bench) do
						local sendMsg = "RETURNBENCH " .. pl;
						C_ChatInfo.SendAddonMessage("RATSYSTEM", sendMsg, "WHISPER", sender);
					end
				end
			elseif (internalPrefix and internalPrefix == "RETURNBENCH") then
				if (C_GuildInfo.CanEditOfficerNote()) then
					local pl = msg[2];
					if (not RAT:Contains(RAT_SavedData.Bench, pl)) then
						RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = pl;
					end
				end
			--[[
			elseif (internalPrefix and internalPrefix == "GETALTS") then
				for player, data in pairs(RAT_SavedData.AltDb) do
					local sendMsg = "RETURNALTS " .. player .. " " .. tostring(data.IsAlt);
					for index, alt in pairs(data.Alts) do
						sendMsg = sendMsg .. " " .. alt;
					end
					C_ChatInfo.SendAddonMessage("RATSYSTEM", sendMsg, "WHISPER", sender);
				end
			elseif (internalPrefix and internalPrefix == "RETURNALTS") then
				local player = msg[2];
				local isAlt = msg[3];
				if (isAlt == "true") then
					isAlt = true;
				elseif (isAlt == "false") then
					isAlt = false;
				end
				if (not RAT:ContainsKey(RAT_SavedData.AltDb, player)) then
					RAT:InitAlt(player);
					RAT_SavedData.AltDb[player].IsAlt = isAlt;
				end
				local alts = RAT_SavedData.AltDb[player].Alts;
				for i = 4, RAT:GetSize(msg) do
					if (not RAT:Contains(alts, msg[i])) then
						if (not RAT:ContainsKey(RAT_SavedData.AltDb, msg[i]) and not isAlt) then
							RAT:InitAlt(msg[i]);]]
							--RAT_SavedData.AltDb[msg[i]].IsAlt = true;
						--[[end
						RAT_SavedData.AltDb[player].Alts[#alts+1] = msg[i];
					end
				end
			]]
			end
		end
	elseif (event == "GUILD_ROSTER_UPDATE" and C_GuildInfo.CanEditOfficerNote()) then
		if (awaitingSync) then
			awaitingSync = false;
			RAT:Sync();
		end
		if (lastAntiCheat >= 0.5) then
			lastAntiCheat = 0;
			RAT:AntiCheat();
		end
		--RAT:CleanAltDb();
	elseif (event == "PLAYER_LOGIN") then
		if (not C_GuildInfo.CanEditOfficerNote()) then
			f:SetScript("OnUpdate", nil);
		end
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

ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", benchFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", helpFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", altFilterRecieve);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", helpFilterSend);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", altFilterSend);
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", benchFilterSend);

local options = CreateFrame("Frame");
options:Hide();

RAT.OptionsCategories = {};
RAT.OptionsCategories.Options = Settings.RegisterCanvasLayoutCategory(options, "Raid Attendance Tracker");
RAT.OptionsCategories.Options.ID = "RATOptions";
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