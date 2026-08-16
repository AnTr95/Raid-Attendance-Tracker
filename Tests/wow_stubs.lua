-- Minimal globals so pure RAT modules load under standalone Lua 5.1.
RAT = RAT or {}
RAT_SavedData = RAT_SavedData or {}
RAT_SavedOptions = RAT_SavedOptions or { OfficerRanks = {}, RaiderRanks = {} }
RAT_Locals = RAT_Locals or {}
_G = _G or {}
local fakeTime = 1000000
function GetServerTime() return fakeTime end
function SetFakeServerTime(t) fakeTime = t end
-- Ambiguate is a WoW global; identity stub is enough to exercise CleanName's realm-collapse.
function Ambiguate(name, context) return name end
-- GetSize (Util) and SendDebugMessage (main) are called from Comms but defined in
-- files not loaded by this pure-Comms harness; stub them so restore-point code runs.
function RAT:GetSize(arr) local c = 0; for _ in pairs(arr or {}) do c = c + 1; end return c; end
function RAT:SendDebugMessage(msg) end
function RAT:RebuildRanks() end
function RAT:RosterReady() return true; end
