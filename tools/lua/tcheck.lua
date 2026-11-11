-- read only: for one of the mod's rules (_G.__tcheck_rule, default "trick"), every target of its kind with the game's
-- own answers (target preconditions, target conditions) next to distance, height and angle from the pawn's facing
local name = _G.__tcheck_rule or "trick"
local st = PawnTrickster.state; local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter")
local mod = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField")
local bb = mod:get_field("<DecisionExecutor>k__BackingField"):get_field("<Blackboard>k__BackingField")
local list = mod:get_field("<MainDecisions>k__BackingField"); local items = list:get_field("_items"); local w
for i = 0, list:call("get_Count") - 1 do local x = items[i]; if x then local g = x:get_field("<UniqueID>k__BackingField")
  if st.guid_names and st.guid_names[tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))] == name then w = x end end end
if not w then out("rule " .. name .. " is not in the list (battle " .. tostring(st.battle) .. ")") return end
local tf = ch:call("get_Transform"); local pp = tf:call("get_Position"); local az = tf:call("get_AxisZ")
local tl = bb:call("getTargetsOfType(app.AIDecisionDefine.AITargetFlag, app.ActionTargetUniqueTypeFlag, app.AIDecisionDefine.AIPositionFlag)", w:get_field("<Target>k__BackingField"), w:get_field("<UniqueTarget>k__BackingField"), w:get_field("<PositionTarget>k__BackingField"))
local rows = {}
if tl then for i = 0, tl:call("get_Count") - 1 do local t = tl:call("get_Item", i); if t then
  local a = w:call("checkTargetPreconditions(app.AIBlackBoardController, app.AITarget)", bb, t)
  local b = w:call("checkTargetConditions(app.AIBlackBoardController, app.AITarget)", bb, t)
  local p = t:get_field("<Transform>k__BackingField"):call("get_Position"); local dx, dz = p.x - pp.x, p.z - pp.z; local d = math.sqrt(dx * dx + dz * dz)
  local ang = d > 0.01 and math.deg(math.acos(math.max(-1, math.min(1, (dx * az.x + dz * az.z) / (d * math.sqrt(az.x * az.x + az.z * az.z)))))) or 0
  rows[#rows + 1] = string.format("%s d=%.1f dy=%.1f angle=%.0f -> pre %s cond %s", tostring(t:get_field("<GameObject>k__BackingField"):call("get_Name")), d, p.y - pp.y, ang, tostring(a), tostring(b)) end end end
out(name .. ": " .. #rows .. " targets | " .. table.concat(rows, " | "))
