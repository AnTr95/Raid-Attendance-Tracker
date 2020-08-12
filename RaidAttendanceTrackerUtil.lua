local RAT = RAT;
local _G = _G;
local L = RAT_Locals;

local escapeCodes = {};
escapeCodes.SUCCESS = "|cFF00FF00";
escapeCodes.FAIL = "|cFFFF0000";
local PAU = {}; --Players Awaiting Update
local calendarRaidIndex = nil;

local GetGuildRosterInfo = GetGuildRosterInfo;

local function compareAlphabetically(str1, str2)
	local strLetter1 = str1:sub(1,2);
	local strLetter2 = str2:sub(1,2);
	if (strLetter1 == strLetter2) then
		compareAlphabetically(str1:sub(2), str2:sub(2));
	end
	return strLetter1 < strLetter2;
end

function RAT:Broadcast(amount)
	local awardedPlayers = {};
	local playersToText;
	if (IsInRaid()) then
		local bench = RAT:GetBench();
		for i = 1, GetNumGroupMembers() do
			local pl = UnitName("raid" .. i);
			local index = RAT:GetGuildMemberIndex(pl);
			if (RAT:GetMain(pl)) then
				local main = RAT:GetMain(pl);
				if (main) then
					pl = main;
					index = RAT:GetGuildMemberIndex(main);
				end
			end
			if (index ~= -1) then
				if (RAT:Eligible(index) and not RAT:Contains(awardedPlayers, pl)) then
					awardedPlayers[i] = pl;
				end
			end
		end
		for i = 1, RAT:GetSize(bench) do
			local pl = bench[i];
			local index = RAT:GetGuildMemberIndex(pl);
			if (index ~= -1) then
				if (RAT:Eligible(index) and not RAT:Contains(awardedPlayers, pl)) then
					awardedPlayers[#awardedPlayers+1] = pl;
				end
			end
		end
	end
	local strings = RAT:ToString(awardedPlayers);
	SendChatMessage(L.ADDON .. L.BROADCAST_AWARDED_ALL1 .. amount .. L.BROADCAST_AWARDED_ALL2 .. strings[1], "GUILD", "COMMON", nil);
	for i = 2, #strings do
		C_Timer.After(i*0.1, function() 
			SendChatMessage(strings[i], "GUILD", "COMMON", nil);
		end);
	end
end

function RAT:BroadcastAbsent(players)
	local strings = RAT:ToString(players);
	C_Timer.After(0.4, function() 
		SendChatMessage(L.ADDON .. L.BROADCAST_ABSENT_ALL .. strings[1], "GUILD", "COMMON", nil);
	end);
	for i = 2, #strings do
		C_Timer.After(0.4+(i*0.1), function() 
			SendChatMessage(strings[i], "GUILD", "COMMON", nil);
		end);
	end
end
--[[
function RAT:BroadcastStrike(player)
	SendChatMessage("RAT: following players recieved a strike: " .. player, "GUILD", "COMMON", nil);
end
]]
function RAT:BroadcastNextAward(time)
	C_Timer.After(0.8, function() 
		SendChatMessage(L.ADDON .. L.BROADCAST_AWARD_NEXT .. time, "GUILD", "COMMON", nil);
	end);
end

function RAT:BroadcastSummary()
	if (RAT_SavedData.Summary) then
		for player, data in pairs(RAT_SavedData.Summary) do
			if (RAT_SavedData.Attendance[player]) then
				local gainedAttendance = RAT_SavedData.Attendance[player].Attended - data.Attended;
				local gainedAbsence = RAT_SavedData.Attendance[player].Absent - data.Absent;
				local gainedRank = math.abs(RAT_SavedData.Attendance[player].Rank - data.Rank);
				local preRank = tonumber(RAT_SavedData.Attendance[player].Rank) <= tonumber(data.Rank) and "gained " or "lost ";
				if (UnitIsConnected(player)) then
					SendChatMessage(L.SUMMARY1 .. gainedAttendance .. L.SUMMARY2 .. gainedAbsence .. L.SUMMARY3 .. preRank .. gainedRank .. L.SUMMARY4, "WHISPER", "COMMON", player);
				end
			end
		end
	end
end

--[[
	Checking if a table contains a given value and if it does, what index is the value located at
	param(arr) table
	param(value) T - value to check exists
	return boolean or integer / returns false if the table does not contain the value otherwise it returns the index of where the value is located
]]
function RAT:Contains(arr, value)
	if (value == nil or arr == nil) then
		return false;
	end
	for k, v in pairs(arr) do
		if (v == value) then
			return k;
		end
	end
	return false;
end

function RAT:AntiCheat()
	for pl, data in pairs(RAT_SavedData.Attendance) do
		local index = RAT:GetGuildMemberIndex(pl);
		local pNote = select(7, GetGuildRosterInfo(index));
		local oNote = "";
		if (RAT:GetMain(pl)) then
			local main = RAT:GetMain(pl);
			local mainIndex = RAT:GetGuildMemberIndex(main);
			oNote = select(8, GetGuildRosterInfo(mainIndex));
		else
			oNote = select(8, GetGuildRosterInfo(index));
		end
		if (oNote ~= pNote) then
			if (not RAT:Contains(PAU, pl)) then
				table.insert(PAU, pl);
				GuildRosterSetPublicNote(index, oNote);
				DEFAULT_CHAT_FRAME:AddMessage(escapeCodes.FAIL .. L.ADDON .. L.ERROR_CHEAT_DETECTED1 .. pl .. L.ERROR_CHEAT_DETECTED2 .. oNote .. L.ERROR_CHEAT_DETECTED3 .. pNote .. L.DOT);
			end
		else
			if (RAT:Contains(PAU, pl)) then
				PAU[RAT:Contains(PAU, pl)] = nil;
			end
		end
	end
	--UpdateAllAlts()?
end

function RAT:Eligible(playerIndex)
	if (IsInGuild() and playerIndex ~= -1) then
		local name, rank = GetGuildRosterInfo(playerIndex);
		if (RAT:Contains(RAT_SavedOptions.RaiderRanks, rank)) then
			return true;
		end
	end
	return false;
end

function RAT:FromSecondsToBestUnit(seconds)
	local days = 0;
	local hr = 0;
	local min = 0;
	local unit = "";
	while (seconds >= 60) do
		min = min + 1;
		seconds = seconds - 60;
	end
	while (min >= 60) do
		hr = hr + 1;
		min = min - 60;
	end
	while (hr >= 24) do
		days = days + 1;
		hr = hr - 24;
	end
	if (days > 0) then
		unit = days .. " day(s)";
	end
	if (hr > 0) then
		unit = unit .. " " .. hr .. " hour(s)";
	end
	if (min > 0) then
		unit = unit .. " " .. min .. " minute(s)";
	end
	if (seconds > 0) then
		unit = unit .. " " .. seconds .. " second(s)";
	end
	return unit;
	--[[if seconds > 86400 then
		return seconds/86400 .. " day(s)"
	elseif seconds > 3600 then
		return seconds/3600 .. " hour(s)"
	elseif seconds > 60 then
		return seconds/60 .. " minute(s)"
	else
		return seconds .. " second(s)" 
	end]]
end

function RAT:ToSecondsFromDays(days)
	return 86400*days;
end

function RAT:BuildAddonMessage(internalPrefix, data)
	local msg = {};
	msg[1] = internalPrefix;
	if (data) then
		if (type(data) == table) then
			for k,v in pairs(data) do
				msg[#msg+1] = v;
			end
		else
			msg[2] = data;
		end
	end
	return msg;
end

function RAT:Round(x)
	return x+0.5-(x+0.5)%1;
end

--[[
	Checking if a table contains a given value and if it does, what index is the value located at
	param(arr) table
	param(value) T - value to check exists
	return boolean or integer / returns false if<< the table does not contain the value otherwise it returns the index of where the value is locatedd
]]
function RAT:ContainsKey(arr, value)
	if (value == nil or arr == nil) then
		return false;
	end
	for k, v in pairs(arr) do
		if (k == value) then
			return true;
		end
	end
	return false;
end

function RAT:GetIndexFromKey(arr, value)
	if (value == nil or arr == nil) then
		return false;
	end
	for k, v in pairs(arr) do
		if (v == value) then
			return k;
		end
	end
	return false;
end

--[[
	Returns the guild members index based of a name, if no name is found return -1
]]
function RAT:GetGuildMemberIndex(name)
	for i = 1, GetNumGuildMembers() do
		local fullName = GetGuildRosterInfo(i);
		if (fullName) then
			fullName = fullName:sub(0, fullName:find("-")-1);
			if (name == fullName) then
				return i;
			end
		end
	end
	return -1;
end

function RAT:UpdateNote(name, index)
	if (not RAT:Contains(PAU, name)) then
		table.insert(PAU, name);
	end
	if (index ~= -1) then
		local attendance = RAT_SavedData.Attendance[name].Attended;
		local absent = RAT_SavedData.Attendance[name].Absent;
		local percent = RAT_SavedData.Attendance[name].Percent;
		local strikes = RAT_SavedData.Attendance[name].Strikes;
		local rank = RAT_SavedData.Attendance[name].Rank;
		--R:99 AP:9999 100% M:999 S9/9
		GuildRosterSetOfficerNote(index, "R:" .. rank .. " AP:" .. attendance .. " " .. percent .. "%" .. " M:" .. absent .. " S:" .. strikes .. "/3");
		GuildRosterSetPublicNote(index, "R:" .. rank .. " AP:" .. attendance .. " " .. percent .. "%" .. " M:" .. absent .. " S:" .. strikes .. "/3");
		if (string.len(select(8,GetGuildRosterInfo(index))) > 31) then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000" .. L.ADDON .. L.ERROR_OFFICER_NOTE_TOO_LONG1 .. name .. L.ERROR_OFFICER_NOTE_TOO_LONG2);
		end
	end
end

--[[
	Returns the argument entered by the player
	param(cmd) string / message sent by the player
	return string / Returns the second argument
]]
function RAT:GetArg(cmd)
	if (cmd == nil) then
		return "";
	end
	local command, rest = cmd:match("^(%S*)%s*(.-)$");
	return rest;
end

--[[
	Returns the command entered by the player
	param(cmd) string / message sent by the player
	return string / Returns the first argument
]]
function RAT:GetCmd(cmd)
	if (cmd == nil) then
		return "";
	end
	local command, rest = cmd:match("^(%S*)%s*(.-)$");
	return command;
end

--[[
	Prints the containings of a table
	param(arr) table / Values to print
	param(str) string / Information about the values held by arr
]]
function RAT:ToString(arr)
	local sb = "";
	local count = 75;
	local strings = {};
	for k, v in pairs(arr) do
		if ((string.len(sb .. " " .. v)+count) < 255) then
			sb = sb .. " " .. v;
		else
			strings[#strings+1] = sb;
			count = 0;
			sb = v;
		end
	end
	strings[#strings+1] = sb;
	return strings;
end
--[[
	Splits the given keyword on each whitespace and stores it in a table
]]
function RAT:Split(keyword)
	local words = {};
	local count = 1;
	for word in keyword:gmatch("%S+") do
		words[count] = word;
		count = count + 1;
	end
	return words;
end

--[[
	Returns the size of a table
	param(arr) table
	returns integer / The size of the table
]]
function RAT:GetSize(arr)
	local count = 0;
	for k, v in pairs(arr) do
		count = count + 1;
	end
	return count;
end


--[[
function RAT:RecoverNextAward(time)
	local tempNextAward = RAT_SavedData.NextAward;
	local correctHour = RAT_SavedData.RaidHours;
	local correctRaid = RAT_SavedData.Raids;
	local freq = RAT_SavedOptions.Frequency * 60;
	while(time > tempNextAward + freq) do
		correctHour = correctHour + 1;
		if (correctHour == 4) then
			correctHour = 0;
			tempNextAward = tempNextAward + RAT:ToSecondsFromDays(RAT:Round(2.5-(8/6*math.cos(2*math.pi/3*correctRaid))-1/6*math.cos(2*math.pi*correctRaid)+2/math.sqrt(3)*math.sin(2*math.pi/3*correctRaid))) - 3*3600;
			correctRaid = correctRaid + 1;
		else
			tempNextAward = tempNextAward + 3600;
		end
	end
	RAT_SavedData.Raids = correctRaid;
	RAT_SavedData.RaidHours = correctHour;
	RAT_SavedData.NextAward = tempNextAward;
	RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward-time));
end
]]
function RAT:GetHighestRankedPlayer(players)
	local winner = players[0];
	for k, v in pairs(players) do
		local rank = RAT:GetRank(v);
		if (RAT:GetRank(winner) > rank) then
			winner = v;
		end
	end
	return winner;
end

function RAT:Sync()
	--Read all notes and override RAT_SavedData.Attendance and RAT_SavedData.Ranks
	RAT_SavedData.Attendance = {};
	RAT_SavedData.Ranks = {};
	for i = 1, GetNumGuildMembers() do
		local name = Ambiguate(select(1, GetGuildRosterInfo(i)), "short");
		if (RAT:Eligible(i) and not RAT:GetMain(name)) then
			local note = select(8, GetGuildRosterInfo(i));
			local index = RAT:GetGuildMemberIndex(name);
			if (not note:find("R:") or not note:find("AP:") or not note:find("M:") or not note:find("S:") or not note:find("%%")) then
				GuildRosterSetOfficerNote(index, "");
				note = "";
				DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000" .. L.ADDON .. name .. L.ERROR_NOTE_SYNTAX);
			end
			RAT:InitPlayer(name);
			local vars = RAT:Split(note);
			for k, v in pairs(vars) do
				local indexOf = v:find(":");
				if (v:find("R:")) then
					RAT_SavedData.Attendance[name].Rank = v:sub(indexOf+1);
				elseif (v:find("AP:")) then
					RAT_SavedData.Attendance[name].Attended = v:sub(indexOf+1);
				elseif (v:find("M:")) then
					RAT_SavedData.Attendance[name].Absent = v:sub(indexOf+1);
				elseif (v:find("S:")) then
					local indexOfTwo = v:find("%/");
					RAT_SavedData.Attendance[name].Strikes = v:sub(indexOf+1, indexOfTwo-1);
				elseif (v:find("%%")) then
					local indexOfTwo = v:find("%%");
					RAT_SavedData.Attendance[name].Percent = v:sub(1, indexOfTwo-1);
				end
				RAT_SavedData.Attendance[name].Score = RAT:CalculateScore(name);
			end
			if (note == "") then
				RAT:UpdateNote(name, index);
			end
		end
	end
	RAT:InsertionSort();
	--RAT:UpdateAllAlts();
end

--[[
function RAT:CleanAltDb()
	for player, data in pairs(RAT_SavedData.AltDb) do
		if (not data.IsAlt) then
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, player)) then
				for index, alt in pairs(data.Alts) do
					if (RAT_SavedData.AltDb[alt]) then
						RAT_SavedData.AltDb[alt] = nil;
					end
				end
				RAT_SavedData.AltDb[player] = nil;
			end
		else
			if (not RAT:IsUnitInGuild(player)) then
				RAT_SavedData.AltDb[player] = nil;
			end
		end
	end
end
]]

function RAT:GetHighestRankingUser()
	local userRank = select(3,GetGuildInfo("player"));
	local highestRank = userRank;
	local highestUser = UnitName("player");
	for user, rank in pairs(RAT.Users) do
		if (rank < highestRank) then
			highestRank = rank;
			highestUser = user;
		elseif (rank == highestRank) then
			if (compareAlphabetically(user, highestUser)) then
				highestRank = rank;
				highestUser = user;
			end
		end
	end
	return highestUser;
end

--[[
	Insertionsort O(n^2)
]]
function RAT:InsertionSort()
	for j = 2, RAT:GetSize(RAT_SavedData.Ranks) do
		local current = RAT_SavedData.Ranks[j];
		local i = j - 1;
		while (i > 0 and RAT_SavedData.Attendance[RAT_SavedData.Ranks[i]].Score < RAT_SavedData.Attendance[current].Score) do
			RAT_SavedData.Ranks[i+1] = RAT_SavedData.Ranks[i];
			i = i -1;
		end
		RAT_SavedData.Ranks[i+1] = current;
	end
end
--[[
function RAT:GetMain(alt)
	for main, data in pairs(RAT_SavedData.AltDb) do
		local alts = data.Alts;
		if (RAT:Contains(alts, alt)) then
			return main;
		end
	end
	return false;
end]]
function RAT:GetMain(alt)
	local index = RAT:GetGuildMemberIndex(alt);
	local note = select(8, GetGuildRosterInfo(index));
	local mainIndex = RAT:GetGuildMemberIndex(note);
	if (mainIndex ~= -1 and RAT:Eligible(mainIndex)) then
		return note;
	end
	return false;
end
--[[
function RAT:MergeAltDb(db)
	RAT:CleanAltDb();
	for player, data in pairs(db) do
		if (not RAT:ContainsKey(RAT_SavedData.AltDb, player)) then
			if (not data.IsAlt) then
				RAT:InitAlt(player);
				RAT_SavedData.AltDb[player].Alts = data.Alts;
			else
				RAT:InitAlt(player);
				RAT_SavedData.AltDb[player].IsAlt = true;
			end
		end
	end
end
]]
--[[
function RAT:UpdateAllAlts()
	for player, altData in pairs(RAT_SavedData.AltDb) do
		local playerIndex = RAT:GetGuildMemberIndex(player);
		if (not altData.IsAlt and RAT:Eligible(playerIndex)) then
			for index, alt in pairs(altData.Alts) do
				if(not RAT:ContainsKey(RAT_SavedData.Attendance, alt)) then
					RAT:InitPlayer(alt);
				end
				if(not RAT:ContainsKey(RAT_SavedData.AltDb, alt)) then
					RAT:InitAlt(alt);
				end
				local data = RAT_SavedData.Attendance[player];
				RAT_SavedData.Attendance[alt].Attended = data.Attended;
				RAT_SavedData.Attendance[alt].Absent = data.Absent;
				RAT_SavedData.Attendance[alt].Percent = data.Percent;
				RAT_SavedData.Attendance[alt].Strikes = data.Strikes;
				RAT_SavedData.Attendance[alt].Rank = data.Rank;
				RAT_SavedData.Attendance[alt].Score = data.Score;
				RAT_SavedData.AltDb[alt].IsAlt = true;
				local index = RAT:GetGuildMemberIndex(alt);
				RAT:UpdateNote(alt, index);
			end
		end
	end
end]]

function RAT:UpdateAllAlts()
	for index = 1, GetNumGuildMembers() do
		local name = Ambiguate(select(1, GetGuildRosterInfo(index)), "short");
		local main = RAT:GetMain(name);
		if (main) then
			local mainIndex = RAT:GetGuildMemberIndex(main);
			local mainNote = select(8, GetGuildRosterInfo(mainIndex));
			GuildRosterSetPublicNote(index, mainNote);
		end
	end
end


function RAT:UpdatePlayerAlts(main)
	for index = 1, GetNumGuildMembers() do
		local name = Ambiguate(select(1, GetGuildRosterInfo(index)), "short");
		local itMain = RAT:GetMain(name);
		if (itMain == main) then
			local mainIndex = RAT:GetGuildMemberIndex(main);
			local mainNote = select(8, GetGuildRosterInfo(mainIndex));
			GuildRosterSetPublicNote(index, mainNote);
		end
	end
end

--[[
function RAT:UpdatePlayerAlts(main)
	local altData = RAT_SavedData.AltDb[main];
	if (altData and not altData.IsAlt) then
		for index, alt in pairs(altData.Alts) do
			if(not RAT:ContainsKey(RAT_SavedData.Attendance, alt)) then
				RAT:InitPlayer(alt);
			end
			if(not RAT:ContainsKey(RAT_SavedData.AltDb, alt)) then
				RAT:InitAlt(alt);
			end
			local data = RAT_SavedData.Attendance[main];
			RAT_SavedData.Attendance[alt].Attended = data.Attended;
			RAT_SavedData.Attendance[alt].Absent = data.Absent;
			RAT_SavedData.Attendance[alt].Percent = data.Percent;
			RAT_SavedData.Attendance[alt].Strikes = data.Strikes;
			RAT_SavedData.Attendance[alt].Rank = data.Rank;
			RAT_SavedData.Attendance[alt].Score = data.Score;
			RAT_SavedData.AltDb[alt].IsAlt = true;
			local index = RAT:GetGuildMemberIndex(alt);
			RAT:UpdateNote(alt, index);
		end
	else
		--Is not alt
	end
end
]]


local f = CreateFrame("Frame");

f:SetScript("OnEvent", function(self, event, ...)
	if (event == "CALENDAR_OPEN_EVENT") then
		if (C_Calendar.GetEventInfo().time.monthDay == C_Calendar.GetDate().monthDay) then
			f:UnregisterEvent("CALENDAR_OPEN_EVENT");
			local players = {};
			local attending = RAT:GetLastAttending();
			local absent = RAT:GetLastAbsent();
			for j = 1, C_Calendar.GetNumInvites() do
				local inviteData = C_Calendar.EventGetInvite(j);
				local inviteStatus = inviteData.inviteStatus;
				local name = inviteData.name;
				if (RAT:Contains(attending, name)) then
					if (inviteStatus == 1 or inviteStatus == 9) then
						RAT:PlayerAbsent(name, 1);
						RAT:PlayerAttended(name, -1);
						attending[RAT:Contains(attending, name)] = nil;
						absent[#absent+1] = name;
						players[#players+1] = name;
					end
				end
			end
			RAT:SetLastAbsent(absent);
			RAT:SetLastAttending(attending);
			if (#players > 0) then
				local strings = RAT:ToString(players);
				C_Timer.After(0.7, function() 
					SendChatMessage(L.ADDON .. L.BROADCAST_CALENDAR_PUNISHED .. strings[1], "GUILD", "COMMON");
				end);
				for i = 2, #strings do
					C_Timer.After(0.7+(i*0.1), function() 
						SendChatMessage(strings[i], "GUILD", "COMMON");
					end);
				end
			end
		else
			C_Calendar.OpenEvent(0, C_Calendar.GetDate().monthDay, calendarRaidIndex);
		end
	end
end)

function RAT:PunishCalendar()
	local date = C_Calendar.GetDate();
	local realmMonth = date.month;
	local realmDay = date.monthDay;
	local realmYear = date.year;
	for i = 1, C_Calendar.GetNumDayEvents(0, realmDay) do
		local calendarEvent = C_Calendar.GetDayEvent(0, realmDay, i);
		local calendarType = calendarEvent.calendarType;
		local eventType = calendarEvent.eventType;
		if (calendarType == "PLAYER" and eventType == 0) then
			calendarRaidIndex = i;
			C_Calendar.CloseEvent();
			f:RegisterEvent("CALENDAR_OPEN_EVENT");
			C_Calendar.OpenEvent(0, realmDay, i); -- Selects the calendar event for modification
		end
	end
end

function RAT:IsUnitInGuild(unit)
	if (RAT:GetGuildMemberIndex(unit) ~= -1) then
		return true;
	end
	return false;
end

local function summaryFilter(self, event, msg)
	if (msg:find("RAT Summary:")) then
		return true;
	end
	return false;
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", summaryFilter)