-- TEST (read only), independent of the pawn mod: twice a second while the party is in battle, what the main pawn's AI
-- executes (decision pack) and which action she plays. _G.__es_reset = true clears.
if _G.__execsample_reset then _G.__es_reset = true; _G.__execsample_reset = nil end
if _G.__es_reset or not _G.__es then _G.__es = { t = 0, n = 0, ex = {}, act = {}, job = "?" } end
_G.__es_reset = nil
if not _G.__es_hook then _G.__es_hook = true; re.on_frame(function() if _G.__es_fn then _G.__es_fn() end end) end
_G.__es_fn = function()
  local E = _G.__es; local now = os.clock(); if now - E.t < 0.5 then return end; E.t = now
  local ok, e = pcall(function()
    local pm = sdk.get_managed_singleton("app.PawnManager"); local bc = pm:call("get_BattleController"); if not bc or bc:get_field("_CurrentState") ~= 2 then return end
    local pawn = pm:get_field("_MainPawn"); if not pawn then return end; local ch = pawn:call("get_CachedCharacter"); if not ch or ch:call("get_Hp") <= 0 then E.dead = (E.dead or 0) + 1; return end
    local ex = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
    local ed = ex:get_field("<ExecutingDecision>k__BackingField"); local nm = "none"
    if ed and ed:get_field("<Decision>k__BackingField") then local s = "?"; pcall(function() s = tostring(ed:get_field("<ActionPackData>k__BackingField"):call("ToString")) end); nm = s:match("ActInterPackData/(.-)%.user") or s
      local g = ed:get_field("<Decision>k__BackingField"):get_field("<UniqueID>k__BackingField")
      local st = _G.PawnTrickster and PawnTrickster.state; local mine = st and st.guid_names and st.guid_names[tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))]; if mine then nm = "OURS:" .. mine end end
    E.n = E.n + 1; E.ex[nm] = (E.ex[nm] or 0) + 1; pcall(function() E.job = tostring(ch:call("get_Human"):call("get_JobContext"):get_field("CurrentJob")) end)
    pcall(function() local am = ch:call("get_ActionManager"); local it = am:get_field("CurrentActionList"):get_field("_items")
      local a0 = it[0] and tostring(it[0]:get_field("Name")) or "?"; E.act[a0] = (E.act[a0] or 0) + 1 end)
  end)
  if not ok then E.err = tostring(e) end
end
local E = _G.__es
local function top(t) local r = {}; for k, n in pairs(t) do r[#r + 1] = { k, n } end; table.sort(r, function(a, b) return a[2] > b[2] end); local s = {}; for i = 1, math.min(#r, 16) do s[#s + 1] = string.format("%s %d (%.0f%%)", r[i][1], r[i][2], 100 * r[i][2] / math.max(1, E.n)) end; return table.concat(s, ", ") end
out("battle samples " .. E.n .. " (0.5 s each), vocation " .. E.job .. ", down " .. tostring(E.dead or 0) .. ", err " .. tostring(E.err))
out("DECISIONS " .. top(E.ex)); out("ACTIONS " .. top(E.act))
