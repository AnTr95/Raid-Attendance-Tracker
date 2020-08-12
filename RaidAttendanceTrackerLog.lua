local RAT = RAT;
local _G = _G;

function RAT:PrintLog(date)
	for k, v in pairs(RAT_SavedData.Log) do
		if (k:find(date)) then
			--Print everything
		end
	end
end

function RAT:LogAll(playerName, attended, absent, strike, date)
	RAT:LogInit(playerName, date);
	RAT_SavedData.Log[date][playerName].Attended = RAT_SavedData.Log[date][playerName].Attended + attended;
	RAT_SavedData.Log[date][playerName].Absent = RAT_SavedData.Log[date][playerName].Absent + absent;
	RAT_SavedData.Log[date][playerName].Strikes = RAT_SavedData.Log[date][playerName].Strikes + strike;
end

function RAT:LogAttended(playerName, attended, date)
	RAT:LogInit(playerName, date);
	RAT_SavedData.Log[date][playerName].Attended = RAT_SavedData.Log[date][playerName].Attended + attended;
end

function RAT:LogAbsent(playerName, absent, date)
	RAT:LogInit(playerName, date);
	RAT_SavedData.Log[date][playerName].Absent = RAT_SavedData.Log[date][playerName].Absent + absent;
end

function RAT:LogStrike(playerName, strike, date)
	RAT:LogInit(playerName, date);
	RAT_SavedData.Log[date][playerName].Strikes = RAT_SavedData.Log[date][playerName].Strikes + strike;
end

function RAT:LogInit(playerName, date)
	if (not RAT:ContainsKey(RAT_SavedData.Log, date)) then
		RAT_SavedData.Log[date] = {};
		RAT_SavedData.Log[date][playerName] = {
			Attended = 0,
			Absent = 0,
			Strikes = 0,
		};
	else
		if (not RAT:ContainsKey(RAT_SavedData.Log[date], playerName)) then
			RAT_SavedData.Log[date][playerName] = {
				Attended = 0,
				Absent = 0,
				Strikes = 0,
			};
		end
	end
end