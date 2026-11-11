-- TEST (read only): twice a second in battle, what every OTHER party pawn executes (decision pack) and plays (action)
if _G.__p2sample_reset then _G.__p2_reset = true; _G.__p2sample_reset = nil end
if _G.__p2_reset or not _G.__p2 then _G.__p2 = { t = 0, n = 0, ex = {}, act = {}, job = "?", j9 = 0 } end; _G.__p2_reset = nil
if not _G.__p2_hook then _G.__p2_hook = true; re.on_frame(function() if _G.__p2_fn then _G.__p2_fn() end end) end
_G.__p2_fn = function()
  local E = _G.__p2; local now = os.clock(); if now - E.t < 0.5 then return end; E.t = now
  local ok, e = pcall(function()
    local pm = sdk.get_managed_singleton("app.PawnManager"); local bc = pm:call("get_BattleController"); if not bc or bc:get_field("_CurrentState") ~= 2 then return end
    local main = pm:get_field("_MainPawn"); local list = pm:get_field("_PartyPawnList")
    for i = 0, list:call("get_Count") - 1 do local pw = list:call("get_Item", i)
      if pw and (not main or pw:get_address() ~= main:get_address()) then
        local ch = pw:call("get_CachedCharacter"); if ch and ch:call("get_Hp") > 0 then
          local ex = pw:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
          local ed = ex:get_field("<ExecutingDecision>k__BackingField"); local nm = "none"
          if ed and ed:get_field("<Decision>k__BackingField") then local s = "?"; pcall(function() s = tostring(ed:get_field("<ActionPackData>k__BackingField"):call("ToString")) end); nm = s:match("ActInterPackData/(.-)%.user") or s end
          E.n = E.n + 1; E.ex[nm] = (E.ex[nm] or 0) + 1
          pcall(function() E.job = tostring(ch:call("get_Human"):call("get_JobContext"):get_field("CurrentJob")) end)
          pcall(function() local it = ch:call("get_ActionManager"):get_field("CurrentActionList"):get_field("_items")
            for k = 0, 1 do local a = it[k] and tostring(it[k]:get_field("Name")) or nil; if a then local key = (k == 0 and "" or "upper:") .. a; E.act[key] = (E.act[key] or 0) + 1; if a:find("Job09") then E.j9 = E.j9 + 1 end end end end)
        else E.dead = (E.dead or 0) + 1 end end end
  end)
  if not ok then E.err = tostring(e) end
end
local E = _G.__p2
local function top(t) local r = {}; for k, n in pairs(t) do r[#r + 1] = { k, n } end; table.sort(r, function(a, b) return a[2] > b[2] end); local s = {}; for i = 1, math.min(#r, 18) do s[#s + 1] = string.format("%s %d (%.0f%%)", r[i][1], r[i][2], 100 * r[i][2] / math.max(1, E.n)) end; return table.concat(s, ", ") end
out("hired pawn: battle samples " .. E.n .. ", vocation " .. E.job .. ", down " .. tostring(E.dead or 0) .. ", Job09 actions seen " .. E.j9 .. ", err " .. tostring(E.err))
out("DECISIONS " .. top(E.ex)); out("ACTIONS " .. top(E.act))
