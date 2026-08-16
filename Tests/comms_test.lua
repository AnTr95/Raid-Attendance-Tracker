-- Task 1: codec
local encoded = RAT:EncodeMessage("AWARD", { "Xerxos", 5 })
assertEq(encoded, "AWARD|Xerxos|5", "encode command")

local t, fields = RAT:DecodeMessage("AWARD|Xerxos|5")
assertEq(t, "AWARD", "decode type")
assertEq(fields[1], "Xerxos", "decode field 1")
assertEq(fields[2], "5", "decode field 2 (string)")

local t2, f2 = RAT:DecodeMessage("SYNCVER")
assertEq(t2, "SYNCVER", "decode type-only")
assertEq(#f2, 0, "decode type-only has no fields")

-- Task 2: snapshot round-trip
local snap = {
  LastModified = 1234567,
  Attendance = {
    Xerxos = { Attended = 95, Absent = 5, Strikes = 1 },
    Naturage = { Attended = 40, Absent = 0, Strikes = 0 },
  },
  Alts = { Xerxalt = "Xerxos" },
  Bench = { "Naturage" },
}
local s = RAT:SerializeSnapshot(snap)
local d = RAT:DeserializeSnapshot(s)
assertEq(d.LastModified, 1234567, "snapshot time round-trips")
assertEq(d.Attendance.Xerxos.Attended, 95, "attended round-trips as number")
assertEq(d.Attendance.Xerxos.Absent, 5, "absent round-trips")
assertEq(d.Attendance.Xerxos.Strikes, 1, "strikes round-trips")
assertEq(d.Attendance.Naturage.Attended, 40, "second player round-trips")
assertEq(d.Alts.Xerxalt, "Xerxos", "alt link round-trips")
assertEq(d.Bench[1], "Naturage", "bench round-trips")

-- Task 3: chunking + reassembly
local chunks = RAT:ChunkPayload("abcdefg", 3)
assertEq(#chunks, 3, "chunk count")
assertEq(chunks[1], "abc", "chunk 1")
assertEq(chunks[3], "g", "chunk 3")

local r = RAT:NewReassembler()
assertEq(RAT:ReassemblerAdd(r, 2, 3, "def"), nil, "incomplete after out-of-order chunk")
assertEq(RAT:ReassemblerAdd(r, 1, 3, "abc"), nil, "still incomplete")
assertEq(RAT:ReassemblerAdd(r, 3, 3, "g"), "abcdefg", "reassembled after final chunk")

-- Task 4: conflict resolution + officer predicate
assertEq(RAT:ShouldAdopt(100, 200, true), true, "officer newer -> adopt")
assertEq(RAT:ShouldAdopt(100, 200, false), false, "raider newer -> ignore")
assertEq(RAT:ShouldAdopt(200, 100, true), false, "officer older -> ignore")
assertEq(RAT:ShouldAdopt(100, 100, true), false, "officer equal -> ignore")

RAT_SavedOptions.OfficerRanks = { "Guild Master", "Officer" }
assertEq(RAT:RankNameIsOfficer("Officer"), true, "officer rank accepted")
assertEq(RAT:RankNameIsOfficer("Raider"), false, "raider rank rejected")
assertEq(RAT:RankNameIsOfficer(nil), false, "nil rank rejected")

-- CleanName: character name only (globally consistent keys)
assertEq(RAT:CleanName("Ant-Kazzak-Kazzak-Kazzak"), "Ant", "strips realm + duplicated-realm bug")
assertEq(RAT:CleanName("Ant-Kazzak"), "Ant", "strips realm -> character name only")
assertEq(RAT:CleanName("Ant"), "Ant", "bare name unchanged")
assertEq(RAT:CleanName(nil), nil, "nil is safe")

-- WhisperTarget: recover a valid single-realm target (roster path needs WoW APIs, so test only names that already carry a realm)
assertEq(RAT:WhisperTarget("Ant-Kazzak-Kazzak"), "Ant-Kazzak", "whisper target collapses duplicated realm")
assertEq(RAT:WhisperTarget("Ant-Kazzak"), "Ant-Kazzak", "whisper target keeps single realm")

-- Task 1 (safe-removal plan): restore points
RAT_SavedData = { LastModified = 5, Attendance = { Ant = { Attended = 3, Absent = 1, Strikes = 0 } }, Alts = {}, Bench = {}, Snapshots = {}, NextSnapshotId = 1 }
local rpId = RAT:SaveRestorePoint("test-a")
assertEq(type(rpId), "number", "SaveRestorePoint returns a numeric id")
assertEq(#RAT_SavedData.Snapshots, 1, "one restore point stored")
assertEq(RAT_SavedData.Snapshots[1].size, 1, "restore point records player count")
local rpEntry = RAT:GetRestorePoint(rpId)
local rpSnap = RAT:DeserializeSnapshot(rpEntry.payload)
assertEq(rpSnap.Attendance.Ant.Attended, 3, "restore point payload round-trips attendance")
assertEq(#RAT:ListRestorePoints(), 1, "ListRestorePoints returns one entry")
-- cap eviction: 1 + 12 = 13 saves, capped at 10, oldest (rpId) evicted
for i = 1, 12 do RAT:SaveRestorePoint("bulk") end
assert(#RAT_SavedData.Snapshots <= 10, "restore points capped at 10")
assertEq(RAT:GetRestorePoint(rpId), nil, "oldest restore point evicted")

-- Task 2 (safe-removal plan): RestoreFrom recovers a snapshot and Touches LastModified
RAT_SavedData = { LastModified = 1, Attendance = { Bob = { Attended = 10, Absent = 2, Strikes = 0 } }, Alts = {}, Bench = {}, Snapshots = {}, NextSnapshotId = 1 }
local backupId = RAT:SaveRestorePoint("test-restore")
RAT_SavedData.Attendance = {}   -- simulate a wipe
SetFakeServerTime(2000000)
assertEq(RAT:RestoreFrom(backupId), true, "RestoreFrom returns true for a valid id")
assertEq(RAT_SavedData.Attendance.Bob.Attended, 10, "RestoreFrom recovers attendance")
assertEq(RAT_SavedData.LastModified, 2000000, "RestoreFrom Touches LastModified so it wins the sync")
assertEq(RAT:RestoreFrom(99999), false, "RestoreFrom returns false for unknown id")
