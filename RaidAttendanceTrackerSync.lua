local RAT = RAT;
local _G = _G;
local L = RAT_Locals;

local GetServerTime = GetServerTime;

function RAT:SendSyncAddonMessage(prefix, msg, channel, target)
	-- Proactively queue if in combat; WoW 12.0 silently drops addon messages in combat
	-- rather than raising an error, so a pcall-only guard is insufficient.
	if InCombatLockdown() then
		self.SyncQueue = self.SyncQueue or {};
		self.SyncQueue[#self.SyncQueue + 1] = { prefix, msg, channel, target };
		self:SendDebugMessage("Queued sync addon message (in combat lockdown)");
		return false;
	end

	local ok, err = pcall(C_ChatInfo.SendAddonMessage, prefix, msg, channel, target);
	if ok then
		return true;
	end

	self.SyncQueue = self.SyncQueue or {};
	self.SyncQueue[#self.SyncQueue + 1] = { prefix, msg, channel, target };
	self:SendDebugMessage("Queued sync addon message after send failure: " .. tostring(err));
	return false;
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
			testName = RAT:NormalizePlayerName(testName);
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
	myName = RAT:NormalizePlayerName(myName .. "-" .. myServer);
	return myName == master;
end

------------------------
-- Data Compression   --
------------------------

function RAT:SerializeAttendanceData()
	-- Serialize all attendance data into a single string.
	-- Format: Player1:Attended:Absent:Percent:Strikes:Rank:Score:Timestamp|Player2:...
	-- AltDb is broadcast separately via individual ALT messages in BroadcastFullSync.
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
	-- Parse serialized data back into table.
	-- Returns table of {playerName = data}.
	local result = {};

	if not dataString or dataString == "" then
		return result;
	end

	for entry in string.gmatch(dataString, "[^|]+") do
		local parts = RAT:Split(entry .. ":", ":");
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

local function rankCanEditOfficerNote(rankIndex)
	if (type(rankIndex) ~= "number") then
		return false;
	end

	local function checkFlags(rankOrder)
		local ok, result = pcall(C_GuildInfo.GuildControlGetRankFlags, rankOrder);
		if (not ok) then
			return nil;
		end

		if (type(result) == "table") then
			local canEditOfficerNote = rawget(result, "canEditOfficerNote");
			if (type(canEditOfficerNote) == "boolean") then
				return canEditOfficerNote;
			end
			local canEditOfficerNoteText = rawget(result, "canEditOfficerNoteText");
			if (type(canEditOfficerNoteText) == "boolean") then
				return canEditOfficerNoteText;
			end
			if (type(result[8]) == "boolean") then
				return result[8];
			end
		else
			local flags = { C_GuildInfo.GuildControlGetRankFlags(rankOrder) };
			if (type(flags[8]) == "boolean") then
				return flags[8];
			end
		end

		return nil;
	end

	local canEdit = checkFlags(rankIndex);
	if (canEdit == nil) then
		canEdit = checkFlags(rankIndex + 1);
	end
	if (type(canEdit) == "boolean") then
		return canEdit;
	end

	return false;
end

function RAT:CanSenderEditOfficerNote(senderName)
	if (type(senderName) ~= "string" or senderName == "") then
		return false;
	end

	senderName = RAT:NormalizePlayerName(Ambiguate(senderName, "none"));
	if (not IsInGuild()) then
		return false;
	end

	for i = 1, GetNumGuildMembers() do
		local rosterName, _, rankIndex = GetGuildRosterInfo(i);
		if (type(rosterName) == "string") then
			local normalizedRosterName = RAT:NormalizePlayerName(Ambiguate(rosterName, "none"));
			if (normalizedRosterName == senderName) then
				return rankCanEditOfficerNote(rankIndex);
			end
		end
	end

	return false;
end

function RAT:ValidateUpdate(playerName, newData, senderName, senderTimestamp)
	-- Validate incoming update from another player
	-- Returns: isValid, errorMessage

	if (not RAT:CanSenderEditOfficerNote(senderName)) then
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
		local existing = RAT_SavedData.Attendance[playerName];
		local hadExisting = (existing ~= nil);
		if (not hadExisting) then
			existing = {
				Attended = 0,
				Absent = 0,
				Percent = 0,
				Strikes = 0,
				Rank = 99,
				Score = 0,
				LastModified = 0,
			};
			RAT_SavedData.Attendance[playerName] = existing;
		end

		local oldAttended = existing.Attended;
		local oldPercent = existing.Percent;
		existing.Attended = newData.Attended;
		existing.Percent = newData.Percent;
		local calculatedScore = RAT:CalculateScore(playerName);
		existing.Attended = oldAttended;
		existing.Percent = oldPercent;

		if (not hadExisting) then
			RAT_SavedData.Attendance[playerName] = nil;
		end

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
	-- Officer broadcasts full attendance data to the guild.
	-- WoW addon message limit is 255 bytes per message.
	-- Overhead per chunk: "FULLSYNC|" (9) + batchLabel (~50) + "|" (1) = ~60 bytes.
	-- Safe data per chunk = 255 - 60 = 195; use 170 for safety margin.
	local CHUNK_SIZE = 170;

	if not C_GuildInfo.CanEditOfficerNote() then return; end
	if not IsInGuild() then return; end
	if not RAT_SavedData.Attendance or RAT:GetSize(RAT_SavedData.Attendance) == 0 then
		RAT:SendDebugMessage("BroadcastFullSync: skipped – attendance data is empty");
		return;
	end

	local dataString = RAT:SerializeAttendanceData();
	local chunks = RAT:ChunkData(dataString, CHUNK_SIZE);
	local totalChunks = #chunks;
	local timestamp = GetServerTime();
	local sender = RAT:NormalizePlayerName(Ambiguate(GetUnitName("player", true), "none")) or "unknown";
	local syncId = tostring(timestamp) .. ":" .. sender;

	RAT:SendDebugMessage("BroadcastFullSync: " .. RAT:GetSize(RAT_SavedData.Attendance) ..
		" players, " .. string.len(dataString) .. " bytes → " .. totalChunks .. " chunks (chunkSize=" .. CHUNK_SIZE .. ")");

	for chunkNum, chunkData in ipairs(chunks) do
		local batchLabel = syncId .. "#" .. chunkNum .. "of" .. totalChunks;
		local msg = "FULLSYNC|" .. batchLabel .. "|" .. chunkData;
		RAT:SendDebugMessage("BroadcastFullSync: chunk " .. chunkNum .. "/" .. totalChunks ..
			" msgLen=" .. string.len(msg));
		RAT:SendSyncAddonMessage("RATSYSTEM", msg, "GUILD");
	end

	-- Broadcast each alt entry individually so receivers merge into their AltDb.
	if (RAT_SavedData.AltDb) then
		local altDelay = (totalChunks * 0.05) + 0.5;
		for altName, entry in pairs(RAT_SavedData.AltDb) do
			if (type(entry) == "table" and entry.Main) then
				local altMsg = "ALT|" .. altName .. "|" .. entry.Main .. "|" .. (entry.Timestamp or timestamp);
				C_Timer.After(altDelay, function()
					RAT:SendSyncAddonMessage("RATSYSTEM", altMsg, "GUILD");
				end);
				altDelay = altDelay + 0.05;
			end
		end
	end
end

function RAT:BroadcastUpdate(playerName, changes)
	-- Master broadcasts a single player update
	-- changes = {Attended = 100, Absent = 5, Percent = 95, Strikes = 0, Rank = 1, Score = 42.5}
	if not C_GuildInfo.CanEditOfficerNote() then return; end
	if not IsInGuild() then return; end

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
	-- Parse batch label "syncId#1of6" (legacy "1of6" also supported)
	local syncId, batchNum, totalBatches = string.match(batchLabel, "^(.-)#(%d+)of(%d+)$");
	if (not syncId) then
		syncId = "legacy";
		batchNum, totalBatches = string.match(batchLabel, "(%d+)of(%d+)");
	end
	batchNum = tonumber(batchNum);
	totalBatches = tonumber(totalBatches);

	if not batchNum or not totalBatches then
		RAT:SendDebugMessage("Invalid batch label: " .. batchLabel);
		return;
	end

	if not RAT_SavedData.FullSyncBuffer then
		RAT_SavedData.FullSyncBuffer = {};
	end

	local sessionKey = senderName .. "|" .. tostring(syncId);
	if (type(RAT_SavedData.FullSyncBuffer[sessionKey]) ~= "table") then
		RAT_SavedData.FullSyncBuffer[sessionKey] = {
			TotalBatches = totalBatches,
			Chunks = {},
		};
	end

	local session = RAT_SavedData.FullSyncBuffer[sessionKey];
	session.TotalBatches = totalBatches;
	session.Chunks[batchNum] = dataChunk;

	local receivedSoFar = RAT:GetSize(session.Chunks);
	RAT:SendDebugMessage("ReceiveFullSync: chunk " .. batchNum .. "/" .. totalBatches ..
		" from " .. senderName .. " (have " .. receivedSoFar .. "/" .. totalBatches .. ")");

	-- Check if we have all chunks
	if receivedSoFar == totalBatches then
		local fullData = "";
		for i = 1, totalBatches do
			if session.Chunks[i] then
				if fullData ~= "" then
					fullData = fullData .. "|";
				end
				fullData = fullData .. session.Chunks[i];
			end
		end

		-- Deserialize and apply
		RAT:SendDebugMessage("ReceiveFullSync: all " .. totalBatches .. " chunks received from " ..
			senderName .. ", assembling " .. string.len(fullData) .. " bytes");
		local newData = RAT:DeserializeAttendanceData(fullData);
		if not newData or RAT:GetSize(newData) == 0 then
			RAT:SendDebugMessage("ReceiveFullSync: IGNORED empty payload from " .. senderName);
			return;
		end
		RAT:SendDebugMessage("ReceiveFullSync: deserialised " .. RAT:GetSize(newData) .. " players");

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

		-- Ensure every player in Attendance is present in the Ranks array,
		-- then re-sort so /rat ranks reflects the just-synced data.
		RAT_SavedData.Ranks = RAT_SavedData.Ranks or {};
		for playerName, _ in pairs(RAT_SavedData.Attendance) do
			local alreadyInRanks = false;
			for _, existingName in ipairs(RAT_SavedData.Ranks) do
				if (existingName == playerName) then
					alreadyInRanks = true;
					break;
				end
			end
			if (not alreadyInRanks) then
				RAT_SavedData.Ranks[#RAT_SavedData.Ranks + 1] = playerName;
			end
		end
		RAT:UpdateRank();

		-- Clear buffer
		RAT_SavedData.FullSyncBuffer[sessionKey] = nil;

		RAT:SendDebugMessage("ReceiveFullSync: applied from " .. senderName ..
			" – Attendance=" .. RAT:GetSize(RAT_SavedData.Attendance) ..
			" Ranks=" .. RAT:GetSize(RAT_SavedData.Ranks));
	end
end

function RAT:ReceiveUpdate(timestamp, updateData, senderName)
	-- Parse: PlayerName:Attended:Absent:Percent:Strikes:Rank:Score
	local parts = RAT:Split(updateData .. ":", ":");

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
	local isValid, errMsg = RAT:ValidateUpdate(playerName, newData, senderName, timestamp);
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

------------------------
-- Alt Sync           --
------------------------

function RAT:BroadcastAlt(altName, mainName)
	if (not C_GuildInfo.CanEditOfficerNote()) then return; end
	if (not IsInGuild()) then return; end
	altName = RAT:NormalizePlayerName(altName);
	mainName = RAT:NormalizePlayerName(mainName);
	local timestamp = GetServerTime();
	local msg = "ALT|" .. altName .. "|" .. mainName .. "|" .. timestamp;
	RAT:SendSyncAddonMessage("RATSYSTEM", msg, "GUILD");
end

function RAT:ReceiveAlt(altName, mainName, timestamp, senderName)
	if (not RAT:CanSenderEditOfficerNote(senderName)) then
		RAT:SendDebugMessage("ALT rejected from unauthorized sender: " .. tostring(senderName));
		return;
	end
	if (not altName or altName == "" or not mainName or mainName == "") then return; end
	timestamp = tonumber(timestamp) or 0;
	altName = RAT:NormalizePlayerName(altName);
	mainName = RAT:NormalizePlayerName(mainName);

	RAT_SavedData.AltDb = RAT_SavedData.AltDb or {};
	local existing = RAT_SavedData.AltDb[altName];
	if (existing and tonumber(existing.Timestamp or 0) >= timestamp) then
		RAT:SendDebugMessage("ALT for " .. altName .. " not applied: existing entry is same age or newer");
		return;
	end

	RAT_SavedData.AltDb[altName] = { Main = mainName, Timestamp = timestamp };
	RAT:SendDebugMessage("ALT applied: " .. altName .. " -> " .. mainName .. " from " .. senderName);
end

----------------------------
-- Data Version Exchange  --
----------------------------

function RAT:GetMaxDataVersion()
	local maxTs = 0;
	if (RAT_SavedData.Attendance) then
		for _, data in pairs(RAT_SavedData.Attendance) do
			local ts = tonumber(data.LastModified or 0);
			if (ts > maxTs) then maxTs = ts; end
		end
	end
	return maxTs;
end

function RAT:BroadcastDataVersion()
	if (not IsInGuild()) then return; end
	local version = RAT:GetMaxDataVersion();
	local count = RAT:GetSize(RAT_SavedData.Attendance or {});
	RAT:SendDebugMessage("BroadcastDataVersion: version=" .. version .. " players=" .. count);
	local msg = "DATAVERSION|" .. version;
	RAT:SendSyncAddonMessage("RATSYSTEM", msg, "GUILD");
end

---------------------------------
-- Highest Ranking Raid Officer --
---------------------------------

function RAT:IsHighestRankingRaidOfficer()
	if (not C_GuildInfo.CanEditOfficerNote()) then return false; end
	if (not IsInRaid()) then return false; end

	local myRankIndex = select(3, GetGuildInfo("player"));
	if (type(myRankIndex) ~= "number") then return false; end

	for i = 1, GetNumGroupMembers() do
		local unitName = GetUnitName("raid" .. i, true);
		if (unitName) then
			local memberName = Ambiguate(unitName, "none");
			memberName = RAT:NormalizePlayerName(memberName);
			local myName = RAT:NormalizePlayerName(Ambiguate(GetUnitName("player", true), "none"));
			if (memberName ~= myName) then
				for j = 1, GetNumGuildMembers() do
					local rosterName, _, rosterRankIndex = GetGuildRosterInfo(j);
					if (type(rosterName) == "string") then
						local normalizedRoster = RAT:NormalizePlayerName(Ambiguate(rosterName, "none"));
						if (normalizedRoster == memberName and rosterRankIndex < myRankIndex) then
							-- Another raid member has a higher guild rank (lower index)
							-- Check if that rank can also edit officer notes
							local ok, flags = pcall(C_GuildInfo.GuildControlGetRankFlags, rosterRankIndex);
							local theyCanEdit = false;
							if (ok and type(flags) == "table") then
								theyCanEdit = flags.canEditOfficerNote or flags.canEditOfficerNoteText or flags[8] or false;
							end
							if (theyCanEdit) then
								return false;
							end
						end
					end
				end
			end
		end
	end
	return true;
end

------------------------
-- Operation Sync     --
------------------------

function RAT:IsApplyingRemoteSyncOp()
	return self._ApplyingRemoteSyncOp == true;
end

function RAT:RunAsRemoteSyncOp(callback)
	self._ApplyingRemoteSyncOp = true;
	local ok, err = pcall(callback);
	self._ApplyingRemoteSyncOp = false;
	if (not ok) then
		RAT:SendDebugMessage("Remote sync operation failed: " .. tostring(err));
	end
	return ok;
end

local function trackAppliedOperation(opId)
	RAT.AppliedSyncOperations = RAT.AppliedSyncOperations or {};
	RAT.AppliedSyncOperations[opId] = GetServerTime();

	local retained = 0;
	for _ in pairs(RAT.AppliedSyncOperations) do
		retained = retained + 1;
	end
	if (retained <= 300) then
		return;
	end

	local now = GetServerTime();
	for id, timestamp in pairs(RAT.AppliedSyncOperations) do
		if (now - (timestamp or 0)) > 600 then
			RAT.AppliedSyncOperations[id] = nil;
		end
	end
end

function RAT:BroadcastOperation(opCode, payload)
	if (not C_GuildInfo.CanEditOfficerNote()) then return; end
	if (not IsInGuild()) then return; end

	local sender = RAT:NormalizePlayerName(Ambiguate(GetUnitName("player", true), "none")) or "unknown";
	local opId = tostring(GetServerTime()) .. ":" .. sender .. ":" .. tostring(math.random(1000, 9999));
	local msg = "OP|" .. opId .. "|" .. tostring(opCode) .. "|" .. tostring(payload or "");
	RAT:SendSyncAddonMessage("RATSYSTEM", msg, "GUILD");
	trackAppliedOperation(opId);
end

function RAT:ReceiveOperation(opId, opCode, payload, senderName)
	if (type(opId) ~= "string" or opId == "") then return; end
	if (type(opCode) ~= "string" or opCode == "") then return; end
	if (not RAT:CanSenderEditOfficerNote(senderName)) then
		RAT:SendDebugMessage("Rejected operation from unauthorized sender: " .. tostring(senderName));
		return;
	end

	RAT.AppliedSyncOperations = RAT.AppliedSyncOperations or {};
	if (RAT.AppliedSyncOperations[opId]) then
		return;
	end

	local parts;
	if (payload and payload ~= "") then
		parts = RAT:Split(payload, ":");
	else
		parts = {};
	end

	RAT:RunAsRemoteSyncOp(function()
		if (opCode == "AWARDALL") then
			local amount = tonumber(parts[1] or payload);
			if (amount) then RAT:AllAttended(amount); end
		elseif (opCode == "AWARD") then
			local playerName = RAT:NormalizePlayerName(parts[1]);
			local amount = tonumber(parts[2]);
			if (playerName and amount) then RAT:PlayerAttended(playerName, amount); end
		elseif (opCode == "ABSENT") then
			local playerName = RAT:NormalizePlayerName(parts[1]);
			local amount = tonumber(parts[2]);
			if (playerName and amount) then RAT:PlayerAbsent(playerName, amount); end
		elseif (opCode == "STRIKE") then
			local playerName = RAT:NormalizePlayerName(parts[1]);
			local amount = tonumber(parts[2] or 1);
			if (playerName and amount) then RAT:StrikePlayer(playerName, amount); end
		elseif (opCode == "IMPORT") then
			local playerName = RAT:NormalizePlayerName(parts[1]);
			local attended = tonumber(parts[2]);
			local absent = tonumber(parts[3]);
			if (playerName and attended and absent) then RAT:Import(playerName, attended, absent); end
		elseif (opCode == "DELETE") then
			local playerName = RAT:NormalizePlayerName(parts[1] or payload);
			if (playerName and playerName ~= "") then RAT:DeletePlayer(playerName); end
		elseif (opCode == "SWAP") then
			local playerName = RAT:NormalizePlayerName(parts[1] or payload);
			if (playerName and playerName ~= "") then
				RAT:PlayerAbsent(playerName, 1);
				RAT:PlayerAttended(playerName, -1);
			end
		elseif (opCode == "UNDO") then
			local amount = tonumber(parts[1]);
			if (not amount) then return; end

			local attendingPlayers = {};
			local absentPlayers = {};
			if (parts[2] and parts[2] ~= "") then
				for _, playerName in ipairs(RAT:Split(parts[2], ",")) do
					playerName = RAT:NormalizePlayerName(playerName);
					if (playerName and playerName ~= "") then
						attendingPlayers[#attendingPlayers + 1] = playerName;
					end
				end
			end
			if (parts[3] and parts[3] ~= "") then
				for _, playerName in ipairs(RAT:Split(parts[3], ",")) do
					playerName = RAT:NormalizePlayerName(playerName);
					if (playerName and playerName ~= "") then
						absentPlayers[#absentPlayers + 1] = playerName;
					end
				end
			end

			RAT:Undo(attendingPlayers, absentPlayers, amount);
		end
	end);

	trackAppliedOperation(opId);
end
