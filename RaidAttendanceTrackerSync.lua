local RAT = RAT;
local _G = _G;
local L = RAT_Locals;

local GetServerTime = GetServerTime;

function RAT:SendSyncAddonMessage(prefix, msg, channel, target)
	if InCombatLockdown() then
		self.SyncQueue = self.SyncQueue or {};
		self.SyncQueue[#self.SyncQueue + 1] = { prefix, msg, channel, target };
		self:SendDebugMessage("Queued sync addon message while in combat: " .. tostring(msg));
		return false;
	end

	C_ChatInfo.SendAddonMessage(prefix, msg, channel, target);
	return true;
end

function RAT:FlushSyncQueue()
	if InCombatLockdown() then
		return;
	end

	if not self.SyncQueue or #self.SyncQueue == 0 then
		return;
	end

	for _, payload in ipairs(self.SyncQueue) do
		C_ChatInfo.SendAddonMessage(payload[1], payload[2], payload[3], payload[4]);
	end

	self.SyncQueue = {};
end

-----------------------
-- Master Detection  --
-----------------------

function RAT:GetMasterOfficer()
	-- Returns highest rank guild member who can edit officer notes, or nil
	if (not IsInGuild()) then return nil; end

	local masterRank = 9999;
	local masterName = nil;
	local masterServer = nil;

	for i = 1, GetNumGuildMembers() do
		local name, rank, rankIndex = GetGuildRosterInfo(i);
		if name and rankIndex < masterRank then
			-- Ambiguate to check if they're online
			local testName = Ambiguate(name, "none");
			-- Check if this rank can edit officer notes
			if C_GuildInfo.CanEditOfficerNote() then
				-- If we can edit, assume this rank can too (simplification)
				-- More accurate: track by rank, but we don't have that API
				masterRank = rankIndex;
				masterName = testName;
				masterServer = name:match("%-(.+)$") or GetRealmName();
			end
		end
	end

	if masterName then
		return masterName .. "-" .. masterServer;
	end
	return nil;
end

function RAT:IsMaster()
	local master = RAT:GetMasterOfficer();
	if not master then return false; end
	local myName, myServer = UnitFullName("player");
	return (myName .. "-" .. myServer) == master;
end

------------------------
-- Data Compression   --
------------------------

function RAT:SerializeAttendanceData()
	-- Serialize all attendance data into a single string
	-- Format: Player1:Attended:Absent:Percent:Strikes:Rank:Score:Timestamp|Player2:...
	local data = {};

	for playerName, playerData in pairs(RAT_SavedData.Attendance) do
		local entry = playerName .. ":" ..
			playerData.Attended .. ":" ..
			playerData.Absent .. ":" ..
			playerData.Percent .. ":" ..
			playerData.Strikes .. ":" ..
			playerData.Rank .. ":" ..
			RAT:Round(playerData.Score) .. ":" ..
			(playerData.LastModified or GetServerTime());
		table.insert(data, entry);
	end

	return table.concat(data, "|");
end

function RAT:DeserializeAttendanceData(dataString)
	-- Parse serialized data back into table
	-- Returns table of {playerName, data}
	local result = {};

	if not dataString or dataString == "" then
		return result;
	end

	for entry in string.gmatch(dataString, "[^|]+") do
		local parts = RAT:Split(entry .. ":");
		if #parts >= 8 then
			local playerName = parts[1];
			result[playerName] = {
				Attended = tonumber(parts[2]) or 0,
				Absent = tonumber(parts[3]) or 0,
				Percent = tonumber(parts[4]) or 0,
				Strikes = tonumber(parts[5]) or 0,
				Rank = tonumber(parts[6]) or 99,
				Score = tonumber(parts[7]) or 0,
				LastModified = tonumber(parts[8]) or GetServerTime(),
			};
		end
	end

	return result;
end

function RAT:ChunkData(dataString, chunkSize)
	-- Split data into chunks for addon message limits
	-- Returns array of chunks
	local chunks = {};
	local currentChunk = "";

	for entry in string.gmatch(dataString, "[^|]+") do
		if string.len(currentChunk) + string.len(entry) + 1 > chunkSize then
			if currentChunk ~= "" then
				table.insert(chunks, currentChunk);
				currentChunk = entry;
			else
				-- Single entry is too large, include anyway
				table.insert(chunks, entry);
				currentChunk = "";
			end
		else
			if currentChunk == "" then
				currentChunk = entry;
			else
				currentChunk = currentChunk .. "|" .. entry;
			end
		end
	end

	if currentChunk ~= "" then
		table.insert(chunks, currentChunk);
	end

	return chunks;
end

------------------------
-- Validation        --
------------------------

function RAT:ValidateUpdate(playerName, newData, senderCanEditOfficial, senderTimestamp)
	-- Validate incoming update from another player
	-- Returns: isValid, errorMessage

	-- Only accept if sender can edit officer notes
	if not senderCanEditOfficial then
		return false, "Sender cannot edit officer notes";
	end

	-- Check if timestamp is newer than local copy
	local localData = RAT_SavedData.Attendance[playerName];
	if localData and localData.LastModified and senderTimestamp <= localData.LastModified then
		return false, "Update is not newer than local data";
	end

	-- Validate numeric ranges
	if newData.Attended and newData.Attended < 0 then
		return false, "Invalid attendance (negative)";
	end
	if newData.Absent and newData.Absent < 0 then
		return false, "Invalid absent (negative)";
	end
	if newData.Percent and (newData.Percent < 0 or newData.Percent > 100) then
		return false, "Invalid percent (out of range)";
	end
	if newData.Strikes and (newData.Strikes < 0 or newData.Strikes > 3) then
		return false, "Invalid strikes (out of range)";
	end
	if newData.Rank and (newData.Rank < 0 or newData.Rank > 9999) then
		return false, "Invalid rank (out of range)";
	end

	-- Validate score can be recalculated
	if newData.Attended and newData.Absent and newData.Percent then
		local calculatedPercent = RAT:CalculatePercent(playerName);
		if calculatedPercent ~= newData.Percent then
			-- This is a warning, not a hard fail (percent might be rounded)
			RAT:SendDebugMessage("WARNING: Percent mismatch for " .. playerName .. " (expected " .. calculatedPercent .. ", got " .. newData.Percent .. ")");
		end
	end

	-- Recalculate score
	if newData.Attended and newData.Percent then
		local tempData = {
			Attended = newData.Attended,
			Percent = newData.Percent,
		};
		RAT_SavedData.Attendance[playerName] = tempData;
		local calculatedScore = RAT:CalculateScore(playerName);

		if newData.Score and math.abs(calculatedScore - newData.Score) > 0.1 then
			return false, "Score does not match calculation (tampering detected)";
		end
	end

	return true, "Valid";
end

------------------------
-- Broadcast         --
------------------------

function RAT:BroadcastFullSync()
	-- Master broadcasts full attendance data to guild
	if not RAT:IsMaster() then return; end
	if not IsInGuild() then return; end
	if not RAT_SavedData.Attendance or RAT:GetSize(RAT_SavedData.Attendance) == 0 then
		RAT:SendDebugMessage("Skipping full sync broadcast because attendance data is empty");
		return;
	end

	local dataString = RAT:SerializeAttendanceData();
	local chunks = RAT:ChunkData(dataString, 240); -- Leave room for prefix
	local totalChunks = #chunks;
	local timestamp = GetServerTime();

	for chunkNum, chunkData in ipairs(chunks) do
		local batchLabel = chunkNum .. "of" .. totalChunks;
		local msg = "FULLSYNC|" .. batchLabel .. "|" .. chunkData;
		RAT:SendSyncAddonMessage("RATSYSTEM", msg, "GUILD");

		-- Rate limit messages
		if chunkNum < totalChunks then
			C_Timer.After(0.1, function() end);
		end
	end
end

function RAT:BroadcastUpdate(playerName, changes)
	-- Master broadcasts a single player update
	-- changes = {Attended = 100, Absent = 5, Percent = 95, Strikes = 0, Rank = 1, Score = 42.5}
	if not RAT:IsMaster() then return; end
	if not IsInGuild() then return; end
	if not C_GuildInfo.CanEditOfficerNote() then return; end

	local timestamp = GetServerTime();
	playerName = RAT:NormalizePlayerName(playerName);
	local playerData = RAT_SavedData.Attendance[playerName];

	if not playerData then return; end

	local msg = "UPDATE|" .. timestamp .. "|" .. playerName .. ":" ..
		(changes.Attended or playerData.Attended) .. ":" ..
		(changes.Absent or playerData.Absent) .. ":" ..
		(changes.Percent or playerData.Percent) .. ":" ..
		(changes.Strikes or playerData.Strikes) .. ":" ..
		(changes.Rank or playerData.Rank) .. ":" ..
		RAT:Round(changes.Score or playerData.Score);

	RAT:SendSyncAddonMessage("RATSYSTEM", msg, "GUILD");
end

------------------------
-- Receiving         --
------------------------

function RAT:ReceiveFullSync(batchLabel, dataChunk, senderName)
	-- Parse batch label "1of6"
	local batchNum, totalBatches = string.match(batchLabel, "(%d+)of(%d+)");
	batchNum = tonumber(batchNum);
	totalBatches = tonumber(totalBatches);

	if not batchNum or not totalBatches then
		RAT:SendDebugMessage("Invalid batch label: " .. batchLabel);
		return;
	end

	if not RAT_SavedData.FullSyncBuffer then
		RAT_SavedData.FullSyncBuffer = {};
	end

	RAT_SavedData.FullSyncBuffer[batchNum] = dataChunk;

	-- Check if we have all chunks
	if RAT:GetSize(RAT_SavedData.FullSyncBuffer) == totalBatches then
		local fullData = "";
		for i = 1, totalBatches do
			if RAT_SavedData.FullSyncBuffer[i] then
				if fullData ~= "" then
					fullData = fullData .. "|";
				end
				fullData = fullData .. RAT_SavedData.FullSyncBuffer[i];
			end
		end

		-- Deserialize and apply
		local newData = RAT:DeserializeAttendanceData(fullData);
		if not newData or RAT:GetSize(newData) == 0 then
			RAT:SendDebugMessage("Ignoring empty full sync from " .. senderName);
			return;
		end

		for playerName, playerData in pairs(newData) do
			playerName = RAT:NormalizePlayerName(playerName);
			local existingData = RAT_SavedData.Attendance[playerName];
			local incomingModified = tonumber(playerData.LastModified or 0);
			local existingModified = tonumber(existingData and existingData.LastModified or 0);
			if existingData and existingModified and incomingModified and incomingModified < existingModified then
				RAT:SendDebugMessage("Keeping existing attendance for " .. playerName .. " because incoming sync is older");
			else
				RAT_SavedData.Attendance[playerName] = playerData;
			end
		end

		-- Clear buffer
		RAT_SavedData.FullSyncBuffer = {};

		RAT:SendDebugMessage("Full sync applied from " .. senderName);
	end
end

function RAT:ReceiveUpdate(timestamp, updateData, senderName, senderCanEditOfficer)
	-- Parse: PlayerName:Attended:Absent:Percent:Strikes:Rank:Score
	local parts = RAT:Split(updateData .. ":");

	if #parts < 7 then return; end

	local playerName = RAT:NormalizePlayerName(parts[1]);
	local newData = {
		Attended = tonumber(parts[2]) or 0,
		Absent = tonumber(parts[3]) or 0,
		Percent = tonumber(parts[4]) or 0,
		Strikes = tonumber(parts[5]) or 0,
		Rank = tonumber(parts[6]) or 99,
		Score = tonumber(parts[7]) or 0,
	};

	-- Validate
	local isValid, errMsg = RAT:ValidateUpdate(playerName, newData, senderCanEditOfficer, timestamp);
	if not isValid then
		RAT:SendDebugMessage("UPDATE REJECTED for " .. playerName .. ": " .. errMsg);
		return;
	end

	-- Apply update
	if not RAT_SavedData.Attendance[playerName] then
		RAT:InitPlayer(playerName);
	end

	newData.LastModified = timestamp;
	for key, value in pairs(newData) do
		RAT_SavedData.Attendance[playerName][key] = value;
	end

	RAT:SendDebugMessage("UPDATE applied for " .. playerName .. " from " .. senderName);
end
