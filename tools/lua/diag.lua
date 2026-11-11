-- TEST (read only): twice a second in battle, for the first of our cast rules that is released and off cooldown:
-- the game's own precondition check, each shared precondition wrapper's cached result, and for every enemy target the
-- game's target precondition / target condition checks. Aggregated by outcome. _G.__d2_reset = true clears.
if _G.__diag_reset then _G.__d2_reset = true; _G.__diag_reset = nil end
if _G.__d2_reset or not _G.__d2 then _G.__d2 = { t = 0, n = 0, idle = 0, cnt = {}, rows = {}, tfail = {}, err = nil, picks0 = nil, pk = {} } end
_G.__d2_reset = nil
local function gk(g) return tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2")) end
local function short(ap) local s = "?"; pcall(function() s = tostring(ap:call("ToString")) end); return (s:match("ActInterPackData/(.-)%.user") or s) end
local function cdesc(c)
  local tn = c:get_type_definition():get_name(); local t = { tn }
  for _, fn in ipairs({ "_Operation", "_State", "_BattleState", "_Not" }) do local ok, v = pcall(function() return c:get_field(fn) end); if ok and v ~= nil then t[#t + 1] = fn:sub(2, 4) .. "=" .. tostring(v) end end
  return table.concat(t, ",")
end
local SIG3 = "(app.AIDecisionDefine.AITargetFlag, app.ActionTargetUniqueTypeFlag, app.AIDecisionDefine.AIPositionFlag)"
if not _G.__d2_hook then _G.__d2_hook = true; re.on_frame(function() if _G.__d2_fn then _G.__d2_fn() end end) end
do
  _G.__d2_fn = (function()
    local D = _G.__d2; local now = os.clock(); if now - D.t < 0.5 then return end; D.t = now
    local ok, e = pcall(function()
      local st = PawnTrickster.state; if not (PawnTrickster.enabled and st and st.trickster_pack and st.battle == 2) then return end
      local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter")
      local mod = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField")
      local ex = mod:get_field("<DecisionExecutor>k__BackingField"); local bb = ex:get_field("<Blackboard>k__BackingField")
      local list = mod:get_field("<MainDecisions>k__BackingField"); local items = list:get_field("_items"); local w, wname
      for i = 0, list:call("get_Count") - 1 do local x = items[i]; if x then
        local nm = st.guid_names and st.guid_names[gk(x:get_field("<UniqueID>k__BackingField"))]
        if nm and nm ~= "stance" and not w and st.gate_blocked and st.gate_blocked[nm] == false and (x:get_field("<CooldownTimer>k__BackingField") or 0) <= 1.0 then w = x; wname = nm end end end
      local dp = (D.picks0 and (st.picks or 0) > D.picks0) and ((st.picks or 0) - D.picks0) or 0; D.picks0 = st.picks or 0
      local sst, sfr = "?", -1
      pcall(function() sst = ({ [1] = "Full", [2] = "Saved", [4] = "Break" })[pawn:get_field("<AIStaminaManager>k__BackingField"):call("get_State")] or "?"
        local sm = ch:get_field("<StaminaManager>k__BackingField"); sfr = sm:get_field("<RemainingAmount>k__BackingField") / sm:get_field("<MaxValue>k__BackingField") end)
      local skc, skm, brk = -1, -1, false
      pcall(function() local sc = pawn:get_field("<SkillActionController>k__BackingField"); skc = sc:get_field("_SkillCount"); skm = sc:get_field("_MaxSkillCount"); brk = sc:call("get_IsSkillBreakTime") end)
      if brk then D.brk_t = D.brk_t or now; D.brk_max = math.max(D.brk_max or 0, now - D.brk_t) else D.brk_t = nil end
      D.sklog = D.sklog or {}
      if D.skc ~= skc or D.brk ~= brk then D.sklog[#D.sklog + 1] = string.format("%.0f:%d/%d%s", now, skc, skm, brk and "B" or ""); if #D.sklog > 60 then table.remove(D.sklog, 1) end end
      D.skc = skc; D.skm = skm; D.brk = brk
      sst = sst .. (brk and "+SKILLBREAK" or "")
      D.stam = D.stam or {}; local SB = D.stam[sst] or { n = 0, picks = 0, rel = 0, lo = 9, hi = -9, ex = {} }; D.stam[sst] = SB
      SB.n = SB.n + 1; SB.picks = SB.picks + dp; SB.lo = math.min(SB.lo, sfr); SB.hi = math.max(SB.hi, sfr); D.sst = sst; D.sfr = sfr
      do local ed0 = ex:get_field("<ExecutingDecision>k__BackingField"); local dec0 = ed0 and ed0:get_field("<Decision>k__BackingField"); local nm0 = "none"
        if dec0 then local n0 = st.guid_names and st.guid_names[gk(dec0:get_field("<UniqueID>k__BackingField"))]; nm0 = n0 and ("OURS:" .. n0) or short(ed0:get_field("<ActionPackData>k__BackingField")) end
        SB.ex[nm0] = (SB.ex[nm0] or 0) + 1 end
      if w then SB.rel = SB.rel + 1 end
      if not w then D.idle = D.idle + 1; D.wait_t = nil; return end
      D.n = D.n + 1
      local pre = w:call("arePreconditionsValid(app.AIBlackBoardController)", bb)
      local fail = {}
      local pw = w:get_field("<PreconditionWrappers>k__BackingField")
      if pw then for i = 0, pw:call("get_Count") - 1 do local cw = pw:call("get_Item", i)
        local r = cw:get_field("_Result"); local has, val; pcall(function() has = r:get_field("_HasValue"); val = r:get_field("_Value") end)
        if has == nil then pcall(function() has = r:call("get_HasValue"); val = has and r:call("get_Value") end) end
        if has == nil then D.nullable = D.nullable or (function() local t = {}; pcall(function() for _, f in ipairs(r:get_type_definition():get_fields()) do t[#t + 1] = f:get_name() end end); return type(r) .. ":" .. table.concat(t, ",") end)() end
        if has and val == false then fail[#fail + 1] = cdesc(cw:get_field("_Condition")) elseif not has then fail[#fail + 1] = "unset:" .. cw:get_field("_Condition"):get_type_definition():get_name() end end end
      if not pre and ch:call("get_Hp") <= 0 then fail[#fail + 1] = "PAWN DOWN" end
      local tl = bb:call("getTargetsOfType" .. SIG3, w:get_field("<Target>k__BackingField"), w:get_field("<UniqueTarget>k__BackingField"), w:get_field("<PositionTarget>k__BackingField"))
      local nt, npre, ncond, nboth = 0, 0, 0, 0
      local pp = ch:call("get_Transform"):call("get_Position")
      if tl then for i = 0, tl:call("get_Count") - 1 do local t = tl:call("get_Item", i); if t then nt = nt + 1
        local a = w:call("checkTargetPreconditions(app.AIBlackBoardController, app.AITarget)", bb, t)
        local b = w:call("checkTargetConditions(app.AIBlackBoardController, app.AITarget)", bb, t)
        if a then npre = npre + 1 end; if b then ncond = ncond + 1 end; if a and b then nboth = nboth + 1 end
        if not (a and b) then
          local d = "?"; pcall(function()
            local tf = t:get_field("<Transform>k__BackingField"); local p = tf:call("get_Position"); local tc = t:get_field("<Character>k__BackingField")
            d = string.format("%s tpre=%s tcond=%s dy=%.1f dist=%.0f hp=%s gp=%s", tostring(t:get_field("<GameObject>k__BackingField"):call("get_Name")), tostring(a), tostring(b), p.y - pp.y,
              math.sqrt((p.x - pp.x) ^ 2 + (p.z - pp.z) ^ 2), tc and string.format("%.0f", tc:call("get_Hp")) or "-", tostring(t:get_field("<GeneralPoint>k__BackingField") ~= nil)) end)
          D.tfail[#D.tfail + 1] = d; if #D.tfail > 40 then table.remove(D.tfail, 1) end
        end end end end
      local ed = ex:get_field("<ExecutingDecision>k__BackingField"); local dec = ed and ed:get_field("<Decision>k__BackingField"); local exn, score = "none", -1
      if dec then local nm = st.guid_names and st.guid_names[gk(dec:get_field("<UniqueID>k__BackingField"))]
        exn = nm and ("OURS:" .. nm) or short(ed:get_field("<ActionPackData>k__BackingField")); score = ed:get_field("<Score>k__BackingField") or -1 end
      if exn:find("^OURS:") and exn ~= "OURS:stance" then D.casting = (D.casting or 0) + 1; D.wait_t = nil; return end
      D.wait_t = D.wait_t or now; local wsec = now - D.wait_t; D.maxwait = math.max(D.maxwait or 0, wsec)
      if dp > 0 then D.wait_t = nil end
      local bm = "?"; pcall(function() local hm = ch:call("get_Human"); bm = string.format("drawn=%s humanBattle=%s", tostring(ch:call("get_IsDrawedWeapon")), tostring(hm:call("get_IsBattleMode"))) end)
      sst = sst .. " " .. bm
      local key = string.format("[%s] %s pre=%s fail=[%s] targets %d: tpre %d, both %s | exec %s", sst, wname, tostring(pre), table.concat(fail, "+"), nt, npre, nboth > 0 and "yes" or "NO", exn)
      D.cnt[key] = (D.cnt[key] or 0) + 1; if dp > 0 then D.pk[key] = (D.pk[key] or 0) + dp end
      D.rows[#D.rows + 1] = string.format("%.1f %s pre=%s both=%d/%d exec=%s %.2f act=%s", now, wname, tostring(pre), nboth, nt, exn, score, tostring(st.act_now)); if #D.rows > 30 then table.remove(D.rows, 1) end
    end)
    if not ok then D.err = tostring(e) end
  end)
end
local D = _G.__d2; local a = {}; for k, n in pairs(D.cnt) do a[#a + 1] = string.format("%4d  %s  (picks %d)", n, k, D.pk[k] or 0) end; table.sort(a, function(x, y) return x > y end)
out("samples (0.5 s each): a cast released " .. D.n .. " (of these, one of our casts executing " .. tostring(D.casting or 0) .. "), none released " .. D.idle .. ", longest wait " .. string.format("%.1f", D.maxwait or 0) .. " s, err " .. tostring(D.err) .. " nullable " .. tostring(D.nullable))
for k, SB in pairs(D.stam or {}) do local e = {}; for n, c in pairs(SB.ex) do e[#e + 1] = string.format("%s %d", n, c) end; table.sort(e, function(x, y) return tonumber(x:match("(%d+)$")) > tonumber(y:match("(%d+)$")) end)
  out(string.format("STAMINA %s: %d samples, stamina %.0f-%.0f %%, picks %d, a cast released in %d | executing: %s", k, SB.n, SB.lo * 100, SB.hi * 100, SB.picks, SB.rel, table.concat(e, ", "))) end
out("now: stamina state " .. tostring(D.sst) .. string.format(" %.0f %%", (D.sfr or 0) * 100) .. ", skill count " .. tostring(D.skc) .. "/" .. tostring(D.skm) .. ", break " .. tostring(D.brk) .. ", longest break " .. string.format("%.1f s", D.brk_max or 0))
out("SKILLCOUNT " .. table.concat(D.sklog or {}, " "))
for _, s in ipairs(a) do out(s) end
if _G.__d2_rows then out("ROWS " .. table.concat(D.rows, " ; ")); out("TFAIL " .. table.concat(D.tfail, " ; ")) end
