-- Run: luajit Tests/run.lua   (from repo root; LuaJIT = Lua 5.1, as WoW uses)
dofile("Tests/wow_stubs.lua")
dofile("RaidAttendanceTrackerComms.lua")

local failures = 0
function assertEq(actual, expected, msg)
  if actual ~= expected then
    failures = failures + 1
    print("FAIL: " .. (msg or "") .. " expected [" .. tostring(expected) .. "] got [" .. tostring(actual) .. "]")
  else
    print("ok: " .. (msg or ""))
  end
end

dofile("Tests/comms_test.lua")

if failures > 0 then
  print(failures .. " failure(s)")
  os.exit(1)
else
  print("all passed")
  os.exit(0)
end
