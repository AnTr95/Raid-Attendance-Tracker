local RAT = RAT;

--------------------------------------------------------------------------------
-- Name normalisation
-- Ambiguate("none") gives "Character" (same realm) or "Character-Realm" (cross
-- realm). Blizzard's 12.0 cross-realm bug can duplicate the realm segment
-- (e.g. "Ant-Kazzak-Kazzak-Kazzak"); we keep only the first realm so keys stay
-- consistent AND cross-realm whisper targets remain valid.
--------------------------------------------------------------------------------

-- Every stored key is the CHARACTER NAME ONLY. Ambiguate("none") strips the realm relative
-- to the LOCAL player, so a bare "Ant" transmitted to another realm's client would be
-- mis-resolved to that reader's own realm. Keeping only the character name makes keys
-- identical on every client. The realm is recovered from the guild roster only when we
-- actually need to whisper someone -- see RAT:WhisperTarget. (Also collapses Blizzard's
-- duplicated-realm bug, e.g. Ant-Kazzak-Kazzak.)
function RAT:CleanName(name)
	if (not name) then return name; end
	return name:match("^([^%-]+)") or name;
end

-- Resolve a character-name key (or a raw sender that may carry a realm / the duplicated-realm
-- bug) to a full "Character-Realm" that is valid to whisper cross-realm. Bare names are looked
-- up in the guild roster to recover their realm.
function RAT:WhisperTarget(name)
	if (not name) then return name; end
	if (not string.find(name, "-", 1, true)) then
		local index = RAT:GetGuildMemberIndex(name);
		if (index ~= -1) then
			name = GetGuildRosterInfo(index) or name;
		end
	end
	local character, realm = name:match("^([^%-]+)%-([^%-]+)");
	if (character and realm) then
		return character .. "-" .. realm;
	end
	return name;
end

--------------------------------------------------------------------------------
-- Message codec (Task 1)
-- Envelope: "TYPE|field|field|...". Delimiter "|" never appears in player names
-- or numbers, so it is safe. gmatch skips empty tokens; our commands never send
-- empty fields.
--------------------------------------------------------------------------------

function RAT:EncodeMessage(msgType, fields)
	local parts = { msgType };
	if (fields) then
		for i = 1, #fields do
			parts[#parts+1] = tostring(fields[i]);
		end
	end
	return table.concat(parts, "|");
end

function RAT:DecodeMessage(str)
	local fields = {};
	for token in string.gmatch(str, "([^|]+)") do
		fields[#fields+1] = token;
	end
	local msgType = table.remove(fields, 1);
	return msgType, fields;
end

--------------------------------------------------------------------------------
-- Snapshot serialize / deserialize (Task 2)
-- Only Attended/Absent/Strikes travel per player; Percent/Score/Rank are
-- recomputed on receipt. Record delimiter ";", field delimiter ",", tag is the
-- first char: T time, A attendance, L alt link, B bench.
--------------------------------------------------------------------------------

function RAT:SerializeSnapshot(data)
	local out = { "T" .. (data.LastModified or 0) };
	for name, a in pairs(data.Attendance or {}) do
		out[#out+1] = "A" .. name .. "," .. (a.Attended or 0) .. "," .. (a.Absent or 0) .. "," .. (a.Strikes or 0);
	end
	for alt, main in pairs(data.Alts or {}) do
		out[#out+1] = "L" .. alt .. "," .. main;
	end
	for i = 1, #(data.Bench or {}) do
		out[#out+1] = "B" .. data.Bench[i];
	end
	return table.concat(out, ";");
end

function RAT:DeserializeSnapshot(str)
	local data = { LastModified = 0, Attendance = {}, Alts = {}, Bench = {} };
	for record in string.gmatch(str, "([^;]+)") do
		local tag = string.sub(record, 1, 1);
		local body = string.sub(record, 2);
		if (tag == "T") then
			data.LastModified = tonumber(body) or 0;
		elseif (tag == "A") then
			local name, att, abs, str2 = string.match(body, "^(.-),(%-?%d+),(%-?%d+),(%-?%d+)$");
			if (name) then
				data.Attendance[name] = { Attended = tonumber(att), Absent = tonumber(abs), Strikes = tonumber(str2) };
			end
		elseif (tag == "L") then
			local alt, main = string.match(body, "^(.-),(.+)$");
			if (alt) then data.Alts[alt] = main; end
		elseif (tag == "B") then
			data.Bench[#data.Bench+1] = body;
		end
	end
	return data;
end

--------------------------------------------------------------------------------
-- Chunking + reassembly (Task 3)
--------------------------------------------------------------------------------

function RAT:ChunkPayload(payload, maxLen)
	local chunks = {};
	local i = 1;
	local n = string.len(payload);
	while (i <= n) do
		chunks[#chunks+1] = string.sub(payload, i, i + maxLen - 1);
		i = i + maxLen;
	end
	if (#chunks == 0) then chunks[1] = ""; end
	return chunks;
end

function RAT:NewReassembler()
	return { parts = {}, total = nil, count = 0 };
end

function RAT:ReassemblerAdd(r, seq, total, body)
	r.total = total;
	if (not r.parts[seq]) then r.count = r.count + 1; end
	r.parts[seq] = body;
	if (r.count == total) then
		local ordered = {};
		for i = 1, total do ordered[i] = r.parts[i]; end
		return table.concat(ordered);
	end
	return nil;
end

--------------------------------------------------------------------------------
-- Conflict resolution + officer predicate (Task 4)
--------------------------------------------------------------------------------

function RAT:ShouldAdopt(localTS, peerTS, peerIsOfficer)
	return (peerIsOfficer == true) and ((peerTS or 0) > (localTS or 0));
end

function RAT:RankNameIsOfficer(rankName)
	local ranks = RAT_SavedOptions and RAT_SavedOptions.OfficerRanks;
	if (not ranks or rankName == nil) then return false; end
	for i = 1, #ranks do
		if (ranks[i] == rankName) then return true; end
	end
	return false;
end

--------------------------------------------------------------------------------
-- Store version stamp (Task 5)
--------------------------------------------------------------------------------

function RAT:Touch()
	RAT_SavedData.LastModified = GetServerTime();
end

--------------------------------------------------------------------------------
-- Transport: lockdown/throttle-safe outbound queue (Task 7)
--------------------------------------------------------------------------------

local PREFIX = "RATSYSTEM";
local outQueue = {};
local commsFrame;

function RAT:IsLockedDown()
	return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown();
end

local function rawSendAddon(item)
	local result = C_ChatInfo.SendAddonMessage(PREFIX, item.msg, item.channel, item.target);
	return result == Enum.SendAddonMessageResult.Success or result == nil;
end

function RAT:FlushQueue()
	if (RAT:IsLockedDown()) then return; end
	local pending = outQueue;
	outQueue = {};
	for i = 1, #pending do
		local item = pending[i];
		local ok;
		if (item.kind == "guild") then
			C_ChatInfo.SendChatMessage(item.msg, "GUILD");
			ok = true;
		else
			ok = rawSendAddon(item);
		end
		if (not ok) then
			for j = i, #pending do outQueue[#outQueue+1] = pending[j]; end
			C_Timer.After(1, function() RAT:FlushQueue(); end);
			return;
		end
	end
end

function RAT:SendAddon(msg, channel, target)
	if (channel == "WHISPER") then target = RAT:WhisperTarget(target); end
	outQueue[#outQueue+1] = { kind = "addon", msg = msg, channel = channel or "GUILD", target = target };
	RAT:FlushQueue();
end

function RAT:SendGuild(msg)
	outQueue[#outQueue+1] = { kind = "guild", msg = msg };
	RAT:FlushQueue();
end

function RAT:InitComms()
	if (commsFrame) then return; end
	commsFrame = CreateFrame("Frame");
	commsFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED");
	commsFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
	commsFrame:SetScript("OnEvent", function() RAT:FlushQueue(); end);
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX);
end

--------------------------------------------------------------------------------
-- Inbound routing + officer verification + chunk reassembly (Task 8)
--------------------------------------------------------------------------------

RAT.MessageHandlers = RAT.MessageHandlers or {};
local snapBuffers = {};

function RAT:GetSenderRank(sender)
	local index = RAT:GetGuildMemberIndex(sender);
	if (index == -1) then return nil; end
	return select(2, GetGuildRosterInfo(index));
end

-- Types that do not carry authoritative data (requests / rank election / bench recovery).
local UNVERIFIED = { VERQUERY = true, VER = true, SNAPREQ = true, GETRANK = true, RETURNRANK = true, GETBENCH = true, RETURNBENCH = true };

function RAT:HandleInbound(msg, sender)
	-- Keep the full sender (with realm) so handlers can whisper cross-realm; compare by character name.
	if (RAT:CleanName(GetUnitName("player")) == RAT:CleanName(sender)) then return; end
	local msgType, fields = RAT:DecodeMessage(msg);

	if (msgType == "SNAP") then
		local seq = tonumber(fields[1]);
		local total = tonumber(fields[2]);
		local body = string.sub(msg, string.len("SNAP|" .. fields[1] .. "|" .. fields[2] .. "|") + 1);
		snapBuffers[sender] = snapBuffers[sender] or RAT:NewReassembler();
		local full = RAT:ReassemblerAdd(snapBuffers[sender], seq, total, body);
		if (full) then
			snapBuffers[sender] = nil;
			RAT:HandleInbound("SNAPDATA|" .. full, sender);
		end
		return;
	end

	if (not UNVERIFIED[msgType]) then
		if (not RAT:RankNameIsOfficer(RAT:GetSenderRank(sender))) then
			RAT:SendDebugMessage("Dropped " .. tostring(msgType) .. " from non-officer " .. tostring(sender));
			return;
		end
	end

	local handler = RAT.MessageHandlers[msgType];
	if (handler) then handler(fields, sender, msg); end
end

--------------------------------------------------------------------------------
-- Version handshake, snapshot transfer, reconciliation (Task 9)
--------------------------------------------------------------------------------

local function selfIsOfficer()
	return C_GuildInfo.CanEditOfficerNote() and true or false;
end

function RAT:CurrentSnapshotData()
	return { LastModified = RAT_SavedData.LastModified or 0, Attendance = RAT_SavedData.Attendance, Alts = RAT_SavedData.Alts, Bench = RAT_SavedData.Bench };
end

function RAT:SendSnapshotTo(target)
	local payload = RAT:SerializeSnapshot(RAT:CurrentSnapshotData());
	local bodyMax = 255 - string.len("SNAP|99|99|");
	local chunks = RAT:ChunkPayload(payload, bodyMax);
	for i = 1, #chunks do
		RAT:SendAddon("SNAP|" .. i .. "|" .. #chunks .. "|" .. chunks[i], "WHISPER", target);
	end
end

function RAT:BroadcastVersion()
	RAT:SendAddon(RAT:EncodeMessage("VERQUERY", { RAT_SavedData.LastModified or 0, selfIsOfficer() and 1 or 0 }), "GUILD");
end

function RAT:AdoptSnapshot(data, sender)
	local peerIsOfficer = RAT:RankNameIsOfficer(RAT:GetSenderRank(sender));
	if (not RAT:ShouldAdopt(RAT_SavedData.LastModified or 0, data.LastModified or 0, peerIsOfficer)) then
		return;
	end
	local attendance = {};
	for name, a in pairs(data.Attendance) do
		attendance[name] = { Attended = a.Attended, Absent = a.Absent, Strikes = a.Strikes, Percent = 0, Rank = 99, Score = 0 };
	end
	RAT_SavedData.Attendance = attendance;
	RAT_SavedData.Alts = data.Alts or {};
	RAT_SavedData.Bench = data.Bench or {};
	RAT_SavedData.LastModified = data.LastModified;
	RAT:RebuildRanks();
	RAT:SendDebugMessage("Adopted snapshot from officer " .. tostring(sender));
end

RAT.MessageHandlers["VERQUERY"] = function(fields, sender)
	local peerTS = tonumber(fields[1]) or 0;
	RAT:SendAddon(RAT:EncodeMessage("VER", { RAT_SavedData.LastModified or 0, selfIsOfficer() and 1 or 0 }), "WHISPER", sender);
	if (RAT:ShouldAdopt(RAT_SavedData.LastModified or 0, peerTS, RAT:RankNameIsOfficer(RAT:GetSenderRank(sender)))) then
		RAT:SendAddon("SNAPREQ", "WHISPER", sender);
	end
end

RAT.MessageHandlers["VER"] = function(fields, sender)
	local peerTS = tonumber(fields[1]) or 0;
	if (RAT:ShouldAdopt(RAT_SavedData.LastModified or 0, peerTS, RAT:RankNameIsOfficer(RAT:GetSenderRank(sender)))) then
		RAT:SendAddon("SNAPREQ", "WHISPER", sender);
	end
end

RAT.MessageHandlers["SNAPREQ"] = function(fields, sender)
	RAT:SendSnapshotTo(sender);
end

RAT.MessageHandlers["SNAPDATA"] = function(fields, sender, rawMsg)
	local payload = string.sub(rawMsg, string.len("SNAPDATA|") + 1);
	RAT:AdoptSnapshot(RAT:DeserializeSnapshot(payload), sender);
end

--------------------------------------------------------------------------------
-- Ported from the old CHAT_MSG_ADDON block: rank election + bench recovery.
-- (RAT.Users is defined in RaidAttendanceTracker.lua.)
--------------------------------------------------------------------------------

RAT.MessageHandlers["GETRANK"] = function(fields, sender)
	if (C_GuildInfo.CanEditOfficerNote()) then
		local name, server = UnitFullName("player");
		RAT:SendAddon(RAT:EncodeMessage("RETURNRANK", { name .. "-" .. server, select(3, GetGuildInfo("player")) }), "WHISPER", sender);
	end
end

RAT.MessageHandlers["RETURNRANK"] = function(fields, sender)
	if (C_GuildInfo.CanEditOfficerNote()) then
		local user = fields[1];
		local rank = tonumber(fields[2]);
		if (user and rank and not RAT:ContainsKey(RAT.Users, user)) then
			RAT.Users[user] = rank;
		end
	end
end

RAT.MessageHandlers["GETBENCH"] = function(fields, sender)
	if (C_GuildInfo.CanEditOfficerNote()) then
		for i, pl in pairs(RAT_SavedData.Bench) do
			RAT:SendAddon(RAT:EncodeMessage("RETURNBENCH", { pl }), "WHISPER", sender);
		end
	end
end

RAT.MessageHandlers["RETURNBENCH"] = function(fields, sender)
	if (C_GuildInfo.CanEditOfficerNote()) then
		local pl = fields[1];
		if (pl and not RAT:Contains(RAT_SavedData.Bench, pl)) then
			RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = pl;
		end
	end
end

--------------------------------------------------------------------------------
-- Manual command layer (Tasks 10-12)
-- The initiating officer applies locally, posts to guild, and broadcasts the
-- command; every verified-officer receiver re-runs the same math. Receivers do
-- NOT post to guild (only the initiator does).
--------------------------------------------------------------------------------

function RAT:BroadcastCommand(msgType, fields)
	RAT:SendAddon(RAT:EncodeMessage(msgType, fields), "GUILD");
end

RAT.MessageHandlers["AWARD"] = function(fields)
	RAT:PlayerAttended(fields[1], tonumber(fields[2])); RAT:RebuildRanks();
end
RAT.MessageHandlers["ABSENT"] = function(fields)
	RAT:PlayerAbsent(fields[1], tonumber(fields[2])); RAT:RebuildRanks();
end
RAT.MessageHandlers["STRIKE"] = function(fields)
	RAT:StrikePlayer(fields[1], tonumber(fields[2])); RAT:RebuildRanks();
end
RAT.MessageHandlers["IMPORT"] = function(fields)
	RAT:Import(fields[1], tonumber(fields[2]), tonumber(fields[3])); RAT:RebuildRanks();
end
RAT.MessageHandlers["DELETEPLAYER"] = function(fields)
	RAT:DeletePlayer(fields[1]); RAT:RebuildRanks();
end
RAT.MessageHandlers["SWAP"] = function(fields)
	RAT:PlayerAbsent(fields[1], 1); RAT:PlayerAttended(fields[1], -1); RAT:RebuildRanks();
end
-- Silent revert on receivers (initiator's own /rat undo posts once).
RAT.MessageHandlers["UNDO"] = function(fields)
	local la, lb, lam = RAT:GetLastAttending(), RAT:GetLastAbsent(), RAT:GetLastAmount();
	for k, v in pairs(la) do RAT:PlayerAttended(v, -lam); end
	for k, v in pairs(lb) do RAT:PlayerAbsent(v, -lam); end
	RAT:UpdateRank();
	RAT:SetLastAmount(-lam);
end
RAT.MessageHandlers["BENCH"] = function(fields)
	local pl = RAT:CleanName(fields[1]);
	if (not RAT:IsBenched(pl)) then RAT_SavedData.Bench[RAT:GetSize(RAT_SavedData.Bench)+1] = pl; end
end
RAT.MessageHandlers["DELETEALL"] = function(fields)
	RAT_SavedData.Attendance = {}; RAT_SavedData.Ranks = {}; RAT_SavedData.Bench = {}; RAT_SavedData.Summary = {};
	RAT:ReconcileRoster();
end
RAT.MessageHandlers["AWARDALL"] = function(fields)
	local amount = tonumber(fields[1]) or 1;
	if (IsInRaid()) then RAT:AllAttended(amount, false); end
end
RAT.MessageHandlers["ALT"] = function(fields)
	local alt = RAT:CleanName(fields[1]);
	local main = RAT:CleanName(fields[2]);
	if (alt and main and alt ~= main) then
		RAT_SavedData.Alts[alt] = main;
		if (RAT_SavedData.Attendance[alt]) then RAT_SavedData.Attendance[alt] = nil; end
		RAT:RebuildRanks();
	end
end
