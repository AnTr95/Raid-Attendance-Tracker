-- Minimal globals so pure RAT modules load under standalone Lua 5.1.
RAT = RAT or {}
RAT_SavedData = RAT_SavedData or {}
RAT_SavedOptions = RAT_SavedOptions or { OfficerRanks = {}, RaiderRanks = {} }
_G = _G or {}
local fakeTime = 1000000
function GetServerTime() return fakeTime end
function SetFakeServerTime(t) fakeTime = t end
-- Ambiguate is a WoW global; identity stub is enough to exercise CleanName's realm-collapse.
function Ambiguate(name, context) return name end
