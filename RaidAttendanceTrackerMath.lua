--2.5- 8/6 cos(2pi/3 x)+ -1/6 cos(2pi x) + 2/sqrt(3) sin(2pi/3 x) Raid days
--2.5-(8/6*math.cos(2*math.pi/3*x))-1/6*math.cos(2*math.pi*x)+2/math.sqrt(3)*math.sin(2*math.pi/3*x)
local RAT = RAT;
local _G = _G;
local L = RAT_Locals;

local function phi(x)
  -- Ensure 0 <= phi(x) <= 1 :
	if (x <= -8) then
		return 0;
 	elseif (x >= 8) then
   		return 1;
  	else
  		local s, b, q = x, x, x^2;
  		for i = 3, math.huge, 2 do
  			b = b*q/i;
  			local t = s;
  			s = t + b;
  			if (s == t) then break; end
  		end
  		return 0.5 + s*exp(-0.5*q - 0.91893853320467274178);
  	end
  --[[
  if x < -1.8 then return 0.005 end
  if -1.8 < x and x < 1.8 then return -0.00101618*x^11+0.00889025*x^9-0.0322789*x^7+0.0792529*x^5-0.197821*x^3+0.564972*x+0.5 end
  if 1.8 < x then return 0.995 end]]
end

function RAT:InitRaid()
	if (IsInRaid()) then
		for i = 1, GetNumGroupMembers() do
			local pl = GetUnitName("raid".. i);
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, pl)) then
				RAT:InitPlayer(pl);
			end
		end
	end
end

function RAT:InitPlayer(playerName)
	local index = RAT:GetGuildMemberIndex(playerName);
	if (index ~= -1) then
		if (RAT:Eligible(index) or RAT:GetMain(playerName)) then
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, playerName)) then
				RAT_SavedData.Attendance[playerName] = {
					Attended = 0,
					Absent = 0,
					Percent = 0,
					Strikes = 0,
					Rank = 99,
					Score = 0,
				};
				RAT_SavedData.Ranks[RAT:GetSize(RAT_SavedData.Ranks)+1] = playerName;
			end
		end
	end
end

function RAT:InitSummary(playerName)
	local index = RAT:GetGuildMemberIndex(playerName);
	if (index ~= -1) then
		if (RAT:Eligible(index)) then
			if (not RAT:ContainsKey(RAT_SavedData.Summary, playerName)) then
				RAT_SavedData.Summary[playerName] = {
					Attended = RAT_SavedData.Attendance[playerName].Attended,
					Absent = RAT_SavedData.Attendance[playerName].Absent,
					Rank = RAT_SavedData.Attendance[playerName].Rank,
				};
			end
		end
	end
end

function RAT:DeletePlayer(player)
	RAT_SavedData.Attendance[player] = {
		Attended = 0,
		Absent = 0,
		Percent = 0,
		Strikes = 0,
		Rank = 99,
		Score = 0,
	};
	RAT:UpdateRank();
	--[[local rank = RAT_SavedData.Attendance[player].Rank
	RAT_SavedData.Attendance[player] = nil
	for i = rank, RAT:GetSize(RAT_SavedData.Attendance)+1 do
		if i == RAT:GetSize(RAT_SavedData.Attendance)+1 then
			RAT_SavedData.Ranks[i] = nil
			break
		end
		RAT_SavedData.Ranks[i] = RAT_SavedData.Ranks[i+1]
	end]]
end
--[[
	DEPRECATED replaced with SetNextAward in Time
function RAT:SetNextAward()
	if (RAT_SavedData.RaidHours == 4) then
		RAT_SavedData.NextAward = RAT_SavedData.NextAward + RAT:ToSecondsFromDays(RAT:Round(2.5-(8/6*math.cos(2*math.pi/3*RAT_SavedData.Raids))-1/6*math.cos(2*math.pi*RAT_SavedData.Raids)+2/math.sqrt(3)*math.sin(2*math.pi/3*RAT_SavedData.Raids))) - 3*3600;
		RAT_SavedData.RaidHours = 0;
		RAT_SavedData.Raids = RAT_SavedData.Raids + 1;
	else
		RAT_SavedData.NextAward = RAT_SavedData.NextAward + 3600; --1h
	end
end
]]
function RAT:StrikePlayer(playerName, strikes)
	local index = RAT:GetGuildMemberIndex(playerName);
	if (index ~= -1) then
		if (RAT:GetMain(playerName)) then
			local main = RAT:GetMain(playerName);
			playerName = main;
			index = RAT:GetGuildMemberIndex(main);
		end
		if (RAT:Eligible(index)) then
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, playerName)) then
				RAT:InitPlayer(playerName);
			end
			RAT_SavedData.Attendance[playerName].Strikes = RAT_SavedData.Attendance[playerName].Strikes + strikes;
			RAT:AddToNoteQueue(playerName, index);
			--RAT:BroadcastStrike(playerName);
			RAT:LogStrike(playerName, strikes, tostring(date()));
		end
	end
end

function RAT:Import(playerName, attended, absent)
	local index = RAT:GetGuildMemberIndex(playerName);
	if (index ~= -1) then
		if (RAT:GetMain(playerName)) then
			local main = RAT:GetMain(playerName);
			playerName = main;
			index = RAT:GetGuildMemberIndex(main);
		end
		if (RAT:Eligible(index)) then
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, playerName)) then
				RAT:InitPlayer(playerName);
			end
			RAT_SavedData.Attendance[playerName].Attended = attended;
			RAT_SavedData.Attendance[playerName].Absent = absent;
			RAT_SavedData.Attendance[playerName].Percent = RAT:CalculatePercent(playerName);
			RAT_SavedData.Attendance[playerName].Score = RAT:CalculateScore(playerName);
			RAT:UpdateRank();
		end	
	end
end

function RAT:GetAbsentPlayers(absent)
	local attending = false;
	local absentPlayers = {};
	--local bench = RAT:GetBench()
	--Main isnt in the raid, alt is will think he is absent
	if (IsInRaid()) then
		for k, v in pairs(RAT_SavedData.Attendance) do
			attending = false;
			for i = 1, GetNumGroupMembers() do
				local pl = GetUnitName("raid" .. i);
				if (RAT:GetMain(pl)) then
					local main = RAT:GetMain(pl);
					if (main) then
						pl = main;
						index = RAT:GetGuildMemberIndex(main);
						isBench = RAT:IsBenched(main);
					end
				end
				if (pl == k) then
					attending = true;
					break;
				end
			end
			for i = 1, RAT:GetSize(RAT_SavedData.Bench) do
				local pl = RAT_SavedData.Bench[i];
				if (pl == k) then
					attending = true;
					break;
				end
			end
			if (attending == false) then
				if (not RAT:GetMain(k)) then
					RAT:PlayerAbsent(k, absent);
					absentPlayers[#absentPlayers+1] = k;
				end
			end
		end
		if (absentPlayers ~= nil) then
			RAT:BroadcastAbsent(absentPlayers);
		end
		RAT:SetLastAbsent(absentPlayers);
	end
end
function RAT:AllAttended(attended)
	if (IsInRaid()) then
		local attendingPlayers = {};
		--What if main is in the raid
		--local bench = RAT:GetBench()
		for i = 1, GetNumGroupMembers() do
			local pl = GetUnitName("raid" .. i);
			local index = RAT:GetGuildMemberIndex(pl);
			local isBench = RAT:IsBenched(pl);
			if (RAT:GetMain(pl)) then
				local main = RAT:GetMain(pl);
				if (main) then
					pl = main;
					index = RAT:GetGuildMemberIndex(main);
					isBench = RAT:IsBenched(main);
				end
			end
			if (index ~= -1 and RAT:Eligible(index)) then
				if (not RAT:ContainsKey(RAT_SavedData.Attendance, pl)) then
					RAT:InitPlayer(pl);
				end
				if (not isBench and not RAT:Contains(attendingPlayers, pl)) then
					RAT:PlayerAttended(pl, attended);
					attendingPlayers[#attendingPlayers+1] = pl;
				end
			end
		end
		for i = 1, RAT:GetSize(RAT_SavedData.Bench) do
			local pl = RAT_SavedData.Bench[i];
			local index = RAT:GetGuildMemberIndex(pl);
			if (index ~= -1 and RAT:Eligible(index) and not RAT:Contains(attendingPlayers, pl)) then
				if (not RAT:ContainsKey(RAT_SavedData.Attendance, pl)) then
					RAT:InitPlayer(pl);
				end
				RAT:PlayerAttended(pl, attended);
				attendingPlayers[#attendingPlayers+1] = pl;
			end
		end
		RAT:Broadcast(attended);
		RAT:GetAbsentPlayers(attended);
		RAT:UpdateRank();
		RAT:SetLastAttending(attendingPlayers);
		RAT:SetLastAmount(attended);
		C_Timer.After(2, function() RAT:UpdateAllAlts(); end);
	end
end
function RAT:PlayerAttended(playerName, attended)
	local index = RAT:GetGuildMemberIndex(playerName);
	if (index ~= -1) then
		if (RAT:Eligible(index)) then
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, playerName)) then
				RAT:InitPlayer(playerName);
			end
			if (not RAT:ContainsKey(RAT_SavedData.Summary, playerName)) then
				RAT:InitSummary(playerName);
			end
			RAT_SavedData.Attendance[playerName].Attended = (RAT:GetAttendance(playerName) + attended);
			RAT_SavedData.Attendance[playerName].Percent = RAT:CalculatePercent(playerName);
			RAT_SavedData.Attendance[playerName].Score = RAT:CalculateScore(playerName);
			RAT:AddToNoteQueue(playerName, index);
			RAT:LogAttended(playerName, attended, tostring(date()));
		end
	end
end
--[[function RAT_ForceNextAward(time)
	RAT_SavedData.NextAward = time
end]]
function RAT:PlayerAbsent(playerName, absent)
	local index = RAT:GetGuildMemberIndex(playerName);
	if (index ~= -1) then
		if (RAT:Eligible(index)) then
			if (not RAT:ContainsKey(RAT_SavedData.Attendance, playerName)) then
				RAT:InitPlayer(playerName);
			end
			if (not RAT:ContainsKey(RAT_SavedData.Summary, playerName)) then
				RAT:InitSummary(playerName);
			end
			RAT_SavedData.Attendance[playerName].Absent = RAT_SavedData.Attendance[playerName].Absent + absent;
			RAT_SavedData.Attendance[playerName].Percent = RAT:CalculatePercent(playerName);
			RAT_SavedData.Attendance[playerName].Score = RAT:CalculateScore(playerName);
			RAT:AddToNoteQueue(playerName, index);
			RAT:LogAbsent(playerName, absent, tostring(date()));
		end
	end
end
function RAT:Undo(lastAttending, lastAbsent, lastAmount)
	for k, v in pairs(lastAttending) do
		RAT:PlayerAttended(v, -lastAmount);
	end
	for k, v in pairs(lastAbsent) do
		RAT:PlayerAbsent(v, -lastAmount);
	end
	RAT:UpdateRank();
	SendChatMessage(L.ADDON .. L.BROADCAST_UNDONE_AWARD, "GUILD");
	RAT:SetLastAmount(-lastAmount);
	C_Timer.After(2, function() RAT:UpdateAllAlts(); end);
end


function RAT:GetAttendance(playerName)
	return RAT_SavedData.Attendance[playerName].Attended;
end
function RAT:GetRank(playerName)
	return RAT_SavedData.Attendance[playerName].Rank;
end
function RAT:UpdateRank()
	--local attended = RAT_SavedData.Attendance[playerName].Attended
	RAT:InsertionSort();
	for k, v in pairs(RAT_SavedData.Ranks) do
		local index = RAT:GetGuildMemberIndex(v);
		if (RAT_SavedData.Ranks[k-1]) then
			local previousPerson = RAT_SavedData.Attendance[RAT_SavedData.Ranks[k-1]];
			if (RAT_SavedData.Attendance[v].Score == previousPerson.Score) then
				RAT_SavedData.Attendance[v].Rank = previousPerson.Rank;
				RAT:AddToNoteQueue(v, index);
			else
				RAT_SavedData.Attendance[v].Rank = k;
				RAT:AddToNoteQueue(v, index);
			end
		else
			RAT_SavedData.Attendance[v].Rank = k;
			RAT:AddToNoteQueue(v, index);
		end
	end
	--RAT:AntiCheat();
end
function RAT:CalculateScore(playerName)
	local attended = RAT_SavedData.Attendance[playerName].Attended;
	local percent = RAT_SavedData.Attendance[playerName].Percent/100;
	if (RAT_SavedOptions.RankingAlgo == "RAT-Algorithm") then
		if (percent > 0.95) then
			percent = 0.95;
		end
		local percentCalc = phi((7.09*percent)-5.32);
		local attendedCalc = ((attended*attended)+(percent*100))/(attended+55);
		local score = math.pow(attendedCalc, percentCalc);
		return score;
	elseif (RAT_SavedOptions.RankingAlgo == "Highest Percent") then
		local score = percent;
		return score;
	elseif (RAT_SavedOptions.RankingAlgo == "Most Points") then
		local score = attended;
		return score;
	end
end
function RAT:CalculatePercent(playerName)
	local attended = RAT_SavedData.Attendance[playerName].Attended;
	local absent = tonumber(RAT_SavedData.Attendance[playerName].Absent);
	local total = attended + absent;
	local percent = 0;
	if (absent == 0) then
		if (attended == 0) then
			return 0;
		else
			return 100;
		end
	else
		local percent = (attended/total)*100;
		percent = percent+0.5-(percent+0.5)%1;
		if (percent == 100) then
			return 99;
		end
		return percent;
	end
	return percent;
end