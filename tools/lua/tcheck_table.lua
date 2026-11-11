-- TEST (read only): three times a second in battle, for every target of the trick rule: the game's own answer to the
-- rule's target preconditions, counted by what the script computes itself (in range, angle from the pawn's facing,
-- height of the target's feet above the pawn's). Shows whether a created target condition does what it is meant to. _G.__tcheck_table_reset = true clears.
if _G.__tcheck_table_reset or not _G.__tt then _G.__tt = { t = 0, c = {} } end
_G.__tcheck_table_reset = nil
if not _G.__tt_hook then _G.__tt_hook = true; re.on_frame(function() if _G.__tt_fn then pcall(_G.__tt_fn) end end) end
_G.__tt_fn = function()
  local T = _G.__tt; local now = os.clock(); if now - T.t < 0.33 then return end; T.t = now
  local st = PawnTrickster.state; if not (st and st.battle == 2) then return end
  local cfg = PawnTrickster.cfg
  local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter")
  local mod = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField")
  local bb = mod:get_field("<DecisionExecutor>k__BackingField"):get_field("<Blackboard>k__BackingField")
  local list = mod:get_field("<MainDecisions>k__BackingField"); local items = list:get_field("_items"); local w
  for i = 0, list:call("get_Count") - 1 do local x = items[i]; if x then local g = x:get_field("<UniqueID>k__BackingField")
    if st.guid_names and st.guid_names[tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))] == "trick" then w = x end end end
  if not w then return end
  local tf = ch:call("get_Transform"); local pp = tf:call("get_Position"); local az = tf:call("get_AxisZ")
  local tl = bb:call("getTargetsOfType(app.AIDecisionDefine.AITargetFlag, app.ActionTargetUniqueTypeFlag, app.AIDecisionDefine.AIPositionFlag)", w:get_field("<Target>k__BackingField"), w:get_field("<UniqueTarget>k__BackingField"), w:get_field("<PositionTarget>k__BackingField"))
  if not tl then return end
  for i = 0, tl:call("get_Count") - 1 do local t = tl:call("get_Item", i); if t then
    local a = w:call("checkTargetPreconditions(app.AIBlackBoardController, app.AITarget)", bb, t)
    local p = t:get_field("<Transform>k__BackingField"):call("get_Position"); local dx, dz = p.x - pp.x, p.z - pp.z; local d = math.sqrt(dx * dx + dz * dz)
    local ang = d > 0.01 and math.deg(math.acos(math.max(-1, math.min(1, (dx * az.x + dz * az.z) / (d * math.sqrt(az.x * az.x + az.z * az.z)))))) or 0
    local dy = p.y - pp.y
    local key = string.format("range %s | angle %s | height %s", (d >= (cfg.effigy_near or 3) and d <= (cfg.effigy_far or 10.5)) and "in " or "out",
      ang <= (cfg.effigy_aim_deg or 12) and "<=12" or (ang <= 25 and "13-25" or ">25 "), dy >= 1.0 and ">=1.0   " or (dy >= 0.5 and "0.5-1.0" or (dy >= 0 and "0-0.5  " or (dy >= -0.5 and "-0.5-0 " or "<-0.5  "))))
    local e = T.c[key] or { y = 0, n = 0 }; T.c[key] = e; if a then e.y = e.y + 1 else e.n = e.n + 1 end
  end end
end
local t = {}; for k, e in pairs(_G.__tt.c) do t[#t + 1] = string.format("%s  ->  preconditions true %d, false %d", k, e.y, e.n) end; table.sort(t)
out(#t .. " situations"); for _, s in ipairs(t) do out(s) end
