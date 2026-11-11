-- TEST (read only): twice a second in battle, the pawn's stamina (lowest, share of samples under 25 % and under 0),
-- the out-of-stamina action, and for each cast rule the pawn's AI executed: stamina when it started and the
-- lowest value until the next decision. _G.__stamwatch_reset = true clears.
if _G.__stamwatch_reset or not _G.__sw then _G.__sw = { t = 0, n = 0, lo = 9, low = 0, neg = 0, winded = 0, wn = 0, last = nil, cur = nil, casts = {} } end
_G.__stamwatch_reset = nil
if not _G.__sw_hook then _G.__sw_hook = true; re.on_frame(function() if _G.__sw_fn then _G.__sw_fn() end end) end
_G.__sw_fn = function()
  local W = _G.__sw; local now = os.clock(); if now - W.t < 0.5 then return end; W.t = now
  pcall(function()
    local st = PawnTrickster.state; if not (st and st.battle == 2) then return end
    local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter"); if ch:call("get_Hp") <= 0 then return end
    local sm = ch:get_field("<StaminaManager>k__BackingField"); local f = sm:get_field("<RemainingAmount>k__BackingField") / sm:get_field("<MaxValue>k__BackingField")
    W.n = W.n + 1; W.lo = math.min(W.lo, f); if f < 0.25 then W.low = W.low + 1 end; if f < 0 then W.neg = W.neg + 1 end
    local act = tostring(st.act_now)
    if act:find("OutOfStamina", 1, true) then W.winded = W.winded + 1; if not (W.last and W.last:find("OutOfStamina", 1, true)) then W.wn = W.wn + 1 end end
    W.last = act
    local ex = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
    local ed = ex:get_field("<ExecutingDecision>k__BackingField"); local dec = ed and ed:get_field("<Decision>k__BackingField"); local nm
    if dec then local g = dec:get_field("<UniqueID>k__BackingField"); nm = st.guid_names and st.guid_names[tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))] end
    if nm == "stance" or nm == "regroup" then nm = nil end
    if W.cur and W.cur.name ~= nm then W.casts[#W.casts + 1] = W.cur; W.cur = nil end
    if nm and not W.cur then W.cur = { name = nm, s0 = f, lo = f, n = 0 } end
    if W.cur then W.cur.lo = math.min(W.cur.lo, f); W.cur.n = W.cur.n + 1 end
  end)
end
local W = _G.__sw
local function sum(name) local n, s0, lo, cost, dur = 0, 0, 9, 0, 0
  for _, c in ipairs(W.casts) do if c.name == name then n = n + 1; s0 = s0 + c.s0; lo = math.min(lo, c.lo); cost = cost + (c.s0 - c.lo); dur = dur + c.n * 0.5 end end
  if n == 0 then return name .. ": none" end
  return string.format("%s x%d: started at %.0f %% on average, cost %.0f %% each, lowest %.0f %%, %.1f s each", name, n, 100 * s0 / n, 100 * cost / n, 100 * lo, dur / n) end
out(string.format("stamina: %d samples, lowest %.0f %%, under 25 %% in %d, under 0 in %d, out-of-stamina action %d samples in %d episodes | %s | %s | %s | %s | %s",
  W.n, W.lo * 100, W.low, W.neg, W.winded, W.wn, sum("rally"), sum("delusion"), sum("screen"), sum("summon"), sum("trick")))
