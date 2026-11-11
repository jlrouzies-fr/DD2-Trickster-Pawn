local pm = sdk.get_managed_singleton("app.PawnManager"); local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer")
local pp = pl:call("get_Transform"):call("get_UniversalPosition")
local function desc(ch)
  local ok, s = pcall(function()
    local p = ch:call("get_Transform"):call("get_UniversalPosition"); local d = math.sqrt((p.x - pp.x) ^ 2 + (p.z - pp.z) ^ 2)
    local job = "?"; pcall(function() job = tostring(ch:call("get_Human"):call("get_JobContext"):get_field("CurrentJob")) end)
    return string.format("%s job=%s d=%.0f inParty=%s dead=%s", tostring(ch:call("get_CharaIDString")), job, d, tostring(pm:call("isInParty(app.Character)", ch)), tostring(ch:call("get_IsDead")))
  end)
  return ok and s or ("err " .. tostring(s))
end
local t = {}
local l = pm:call("get_PawnCharacterList"); local n = l and l:call("get_Count") or 0
for i = 0, n - 1 do t[#t + 1] = desc(l:call("get_Item", i)) end
local hits = _G.__pt_hire_guard
out("partyNum", tostring(pm:call("getPartyPawnNum")), "pawnChars", n, table.concat(t, " | "), "guard paused", tostring(hits and hits.pause), "closed", tostring(hits and hits.closed))
