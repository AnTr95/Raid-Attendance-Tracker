--https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_Calendar/Blizzard_Calendar.lua#L2827

local RAT = RAT;
local L = RAT_Locals;
local _G = _G;

local GetServerTime = GetServerTime;
local date = date;
--dump date("%A %d/%m/%Y %H:%M:%S",GetServerTime());

local weekdays = {[1] = "Sunday", [2] = "Monday", [3] = "Tuesday", [4] = "Wednesday", [5] = "Thursday", [6] = "Friday", [7] = "Saturday"};
local STANDARD_SERVER_TIME_ZONE = 2;

local function timeUnitsToSeconds(days, hours, minutes)
	return (86400*days)+(hours*3600)+(minutes*60);
end


--Gets the actual servers time its follwing CET/CEST an amount in seconds since a specific epoch
--[[
local function getCurrentServerTime()
	local timeInfo = date("!*t", GetServerTime());
	local timeZone;
	local weekday, day, month, year, hour, min, sec, isdst = weekdays[timeInfo.wday], timeInfo.day, timeInfo.month, timeInfo.year, timeInfo.hour, timeInfo.min, timeInfo.sec, timeInfo.isdst;
	if (timeInfo.isdst) then
		timeZone = 2;
	else
		timeZone = 1;
	end
	return weekday, day, month, year, hour, min, sec, isdst, timeZone;
end
]]
--[[
function gto()
	local utcdate   = date("!*t", GetServerTime())
	local localdate = date("*t", GetServerTime())
	localdate.isdst = false -- if true it will remove 1 hr from the difference
	return difftime(time(localdate), time(utcdate))
end]]

--Calculates the time difference between UTC+0 to the realms timezone
function RAT:GetRealmTimeZone()
	local timeInfo = date("!*t", GetServerTime());
	local realmInfo = {};
	timeInfo.isdst = date("*t").isdst;
	local weekday, day, month, year, hour, min, sec = weekdays[timeInfo.wday], timeInfo.day, timeInfo.month, timeInfo.year, timeInfo.hour, timeInfo.min, timeInfo.sec;
	local realmTimeHour, realmTimeMinute = GetGameTime();
	local realmDate = C_Calendar.GetDate();
	realmInfo.hour = realmTimeHour;
	realmInfo.min = realmTimeMinute;
	realmInfo.day = realmDate.monthDay;
	realmInfo.month = realmDate.month;
	realmInfo.year = realmDate.year;
	return RAT:Round(difftime(time(realmInfo), time(timeInfo))/3600);
	--[[
	if (not IsInInstance()) then
		local realmTimeHour, realmTimeMinute = GetGameTime();
		if (realmTimeHour == hour) then
			return timeZone;
		else
			--local _, realmMonth, realmDay, realmYear = CalendarGetDate();
			local date = C_Calendar.GetDate();
			local realmMonth = date.month;
			local realmDay = date.monthDay;
			local realmYear = date.year;
			if (realmDay == day) then
				return realmTimeHour-hour+timeZone;
			else
				if (realmMonth == month) then
					if (realmDay > day) then
						return realmTimeHour-hour+timeZone+24;
					else
						return realmTimeHour-hour+timeZone-24;
					end
				else
					if (realmYear == year) then
						if(realmMonth > month) then
							return realmTimeHour-hour+timeZone+24;
						else
							return realmTimeHour-hour+timeZone-24;
						end
					elseif (realmYear > year) then
						return realmTimeHour-hour+timeZone+24;
					else
						return realmTimeHour-hour+timeZone-24;
					end
				end
			end
		end
	else
		return nil;
	end
	]]
end

local function getRealmTime(realmTimeZone)
	local timeInfo = date("!*t", GetServerTime()+(realmTimeZone*3600));
	local weekday, day, month, year, hour, min, sec = weekdays[timeInfo.wday], timeInfo.day, timeInfo.month, timeInfo.year, timeInfo.hour, timeInfo.min, timeInfo.sec;
	return weekday, day, month, year, hour, min, sec;
end

local function syncNextAward()
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local weekday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	local nextRaid = RAT:GetNextRaidDay(weekday);
	local totalSeconds = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min);
	local prev = RAT_SavedData.NextAward;
	RAT:RecoverNextAward(GetServerTime());
	if(prev and prev ~= RAT_SavedData.NextAward) then
		RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward - GetServerTime()));
	end
end


--[[
function RAT:SetNextAwardOld(time)
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local weekday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	local freq = RAT_SavedOptions.Frequency * 60;
	local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, weekday, hour, min, RAT_SavedOptions.RaidTimes[weekday].FinishHour, RAT_SavedOptions.RaidTimes[weekday].FinishMinute);
	print(timeDiff)
	print(time+freq)
	if (timeDiff + time >= time + freq) then -- Raid is over
		print("here")
		local nextRaid = RAT:GetNextRaidDay(weekday)
		timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min);
		RAT_SavedData.NextAward = time + timeDiff - sec;
	elseif (RAT_SavedData.NextAward + freq > time + timeDiff) then --Sets it to raid finish
		print("here3")
		RAT_SavedData.NextAward = time + timeDiff - sec;
	else
		RAT_SavedData.NextAward = RAT_SavedData.NextAward + freq - sec; --Sets it to frequency min later
	end
end
]]
function RAT:AddRaidDay(day, startHour, startMinute, finishHour, finishMinute)
	RAT_SavedOptions.RaidTimes[day] = {};
	RAT_SavedOptions.RaidTimes[day].StartHour = startHour;
	RAT_SavedOptions.RaidTimes[day].StartMinute = startMinute;
	RAT_SavedOptions.RaidTimes[day].FinishHour = finishHour;
	RAT_SavedOptions.RaidTimes[day].FinishMinute = finishMinute;
	syncNextAward();
	--Change next reward
end

function RAT:RemoveRaidDay(day)
	RAT_SavedOptions.RaidTimes[day] = {};
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	for k, v in pairs(RAT_SavedOptions.RaidTimes) do
		if (RAT:IsRaidDay(k)) then
			if (RAT:GetNextRaidDay(day) == select(1, getRealmTime(timeZone))) then
				RAT_SavedData.NextAward = 0;
			end
			syncNextAward();
			break;
		end
		RAT_SavedData.NextAward = 0;
	end
end

function RAT:IsRaidDay(day)
	if (next(RAT_SavedOptions.RaidTimes[day])) then
		return true;
	end
	return false;
end

function RAT:GetNextRaidDay(lastRaid)
	local weekday = RAT:GetIndexFromKey(weekdays, lastRaid);
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local wday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	if (RAT:IsRaidDay(lastRaid) and (hour < RAT_SavedOptions.RaidTimes[lastRaid].FinishHour or (hour == RAT_SavedOptions.RaidTimes[lastRaid].FinishHour and min < RAT_SavedOptions.RaidTimes[lastRaid].FinishMinute))) then
		return lastRaid;
	end
	for i = weekday+1, weekday + 7 do
		if (i > 7) then
			i = i-7;
		end
		if RAT:IsRaidDay(weekdays[i]) then
			return weekdays[i];
		end
	end
end

function RAT:SkipToNextRaidDay()
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local timeInfo = date("!*t", RAT_SavedData.NextAward+(timeZone*3600));
	local weekday, day, month, year, hour, min, sec = weekdays[timeInfo.wday], timeInfo.day, timeInfo.month, timeInfo.year, timeInfo.hour, timeInfo.min, timeInfo.sec;
	local nextWeekdayIndex = RAT:GetIndexFromKey(weekdays, weekday) + 1;
	if (nextWeekdayIndex == 8) then
		nextWeekdayIndex = 1;
	end
	local nextWeekday = weekdays[nextWeekdayIndex];
	local nextRaid = RAT:GetNextRaidDay(nextWeekday);
	local totalSeconds = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min);
	RAT_SavedData.NextAward = RAT_SavedData.NextAward + totalSeconds-sec;
	RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward - GetServerTime()));
end

--/run RAT_SavedData.NextAward = RAT_SavedData.NextAward 
--/run RAT:RemoveRaidDay("Sunday");

function RAT:SetNextAward(time)
	local freq = RAT_SavedOptions.Frequency * 60;
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local weekday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	local nextRaid = RAT:GetNextRaidDay(weekday);
	if (weekday == nextRaid) then --raid today
		if (hour > RAT_SavedOptions.RaidTimes[nextRaid].StartHour or (hour == RAT_SavedOptions.RaidTimes[nextRaid].StartHour and min >= RAT_SavedOptions.RaidTimes[nextRaid].StartMinute)) then -- raid has started
			local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min, RAT_SavedOptions.RaidTimes[nextRaid].FinishHour, RAT_SavedOptions.RaidTimes[nextRaid].FinishMinute);
			if (time + freq > time + timeDiff) then -- Set to raid end
				RAT_SavedData.NextAward = time + timeDiff - sec;
			else
				--local timeDiff2 = RAT:GetTimeDifferenceBetweenDays(nextRaid, nextRaid, RAT_SavedOptions.RaidTimes[nextRaid].StartHour, RAT_SavedOptions.RaidTimes[nextRaid].StartMinute, RAT_SavedOptions.RaidTimes[nextRaid].FinishHour, RAT_SavedOptions.RaidTimes[nextRaid].FinishMinute);
				--local raidEnd = timeDiff2%freq;
				local count = 0;
				while (freq < timeDiff and count < 100) do
					local count = count + 1;
					timeDiff = timeDiff - freq;
				end
				if (timeDiff < freq) then
					timeDiff = freq;
				end
				RAT_SavedData.NextAward = time + timeDiff - sec;
			end
		else
			local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min, RAT_SavedOptions.RaidTimes[nextRaid].StarthHour, RAT_SavedOptions.RaidTimes[nextRaid].StartMinute);
			RAT_SavedData.NextAward = time + timeDiff - sec;
		end
	else
		local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min, RAT_SavedOptions.RaidTimes[nextRaid].StarthHour, RAT_SavedOptions.RaidTimes[nextRaid].StartMinute);
		RAT_SavedData.NextAward = time + timeDiff - sec;
	end
end

function RAT:RecoverNextAward(time)
	--Reset Summary + Bench?
	local freq = RAT_SavedOptions.Frequency * 60;
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local weekday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	local nextRaid = RAT:GetNextRaidDay(weekday);
	if (weekday == nextRaid) then --raid today
		if (hour > RAT_SavedOptions.RaidTimes[nextRaid].StartHour or (hour == RAT_SavedOptions.RaidTimes[nextRaid].StartHour and min >= RAT_SavedOptions.RaidTimes[nextRaid].StartMinute)) then -- raid has started
			local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min, RAT_SavedOptions.RaidTimes[nextRaid].FinishHour, RAT_SavedOptions.RaidTimes[nextRaid].FinishMinute);
			if (time + freq > time + timeDiff) then -- Set to raid end
				RAT_SavedData.NextAward = time + timeDiff - sec;
			else
				local minDiff = (RAT_SavedOptions.RaidTimes[nextRaid].StartMinute-min)*60;
				RAT_SavedData.NextAward = time + freq + minDiff - sec;
			end
		else
			local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min, RAT_SavedOptions.RaidTimes[nextRaid].StarthHour, RAT_SavedOptions.RaidTimes[nextRaid].StartMinute);
			RAT_SavedData.NextAward = time + timeDiff - sec;
			RAT_SavedData.Summary = {};
			RAT_SavedData.Bench = {};
		end
	else
		local timeDiff = RAT:GetTimeDifferenceBetweenDays(weekday, nextRaid, hour, min, RAT_SavedOptions.RaidTimes[nextRaid].StarthHour, RAT_SavedOptions.RaidTimes[nextRaid].StartMinute);
		RAT_SavedData.NextAward = time + timeDiff - sec;
		RAT_SavedData.Summary = {};
		RAT_SavedData.Bench = {};
	end
end

function RAT:IsItRaidStart()
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local weekday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	if (select(2,RAT:GetTimeDifferenceBetweenDays(weekday, weekday, RAT_SavedOptions.RaidTimes[weekday].StartHour, RAT_SavedOptions.RaidTimes[weekday].StartMinute, hour, min)) == 7) then
		return true;
	end
	return false;
end

function RAT:IsItRaidFinish()
	local timeZone = RAT_SavedData.TimeZone or RAT:GetRealmTimeZone();
	local weekday, day, month, year, hour, min, sec = getRealmTime(timeZone);
	if (select(2,RAT:GetTimeDifferenceBetweenDays(weekday, weekday, RAT_SavedOptions.RaidTimes[weekday].FinishHour, RAT_SavedOptions.RaidTimes[weekday].FinishMinute, hour, min)) == 7) then
		return true;
	end
	return false;
end

function RAT:CheckForDSTTransition()
	if (RAT_SavedData.TimeZone ~= RAT:GetRealmTimeZone()) then
		RAT_SavedData.TimeZone = RAT:GetRealmTimeZone();
		if (RAT:GetNextRaidDay("Monday")) then
			RAT:SetNextAward(GetServerTime());
			RAT:BroadcastNextAward(RAT:FromSecondsToBestUnit(RAT_SavedData.NextAward - GetServerTime()));
		end
		SendChatMessage(L.ADDON .. L.BROADCAST_DST_CHANGE, "GUILD", "COMMON", nil);
	end
end

function RAT:GetTimeDifferenceBetweenDays(prevRaid, nextRaid, prevFinishHour, prevFinishMinute, nextStartHour, nextStartMinute)
	local prevWeekday = RAT:GetIndexFromKey(weekdays, prevRaid);
	local nextWeekday = RAT:GetIndexFromKey(weekdays, nextRaid);
	prevFinishHour = tonumber(prevFinishHour) or tonumber(RAT_SavedOptions.RaidTimes[prevRaid].FinishHour);
	prevFinishMinute = tonumber(prevFinishMinute) or tonumber(RAT_SavedOptions.RaidTimes[prevRaid].FinishMinute);
	nextStartHour = tonumber(nextStartHour) or tonumber(RAT_SavedOptions.RaidTimes[nextRaid].StartHour);
	nextStartMinute = tonumber(nextStartMinute) or tonumber(RAT_SavedOptions.RaidTimes[nextRaid].StartMinute);
	local dayDiff;
	if (prevWeekday > nextWeekday) then
		dayDiff = 7 + (nextWeekday - prevWeekday);--(7-prevWeekday)+nextWeekday
	elseif (prevWeekday < nextWeekday) then
		dayDiff = nextWeekday - prevWeekday;
	else
		dayDiff = 7;
	end

	local hourDiff;
	if (prevFinishHour > nextStartHour) then
		hourDiff = 24 + (nextStartHour - prevFinishHour);
		dayDiff = dayDiff - 1;
	elseif (prevFinishHour < nextStartHour) then
		hourDiff = nextStartHour - prevFinishHour;
		if (dayDiff == 7) then
			dayDiff = 0;
		end
	else
		if (prevFinishMinute < nextStartMinute) then
			dayDiff = 0;
		end
		hourDiff = 0;
	end

	local minuteDiff;
	if (prevFinishMinute > nextStartMinute ) then
		minuteDiff = 60 + (nextStartMinute - prevFinishMinute);
		hourDiff = hourDiff - 1;
	elseif (prevFinishMinute < nextStartMinute) then
		minuteDiff = nextStartMinute - prevFinishMinute;
	else
		minuteDiff = 0	
	end

	return timeUnitsToSeconds(dayDiff,hourDiff,minuteDiff), dayDiff, hourDiff, minuteDiff;
end