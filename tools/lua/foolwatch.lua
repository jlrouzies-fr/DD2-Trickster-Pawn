-- TEST (read only): who is on top of each living enemy's hate ranking, four times a second, counted apart for
-- enemies the dust ball has fooled at that moment and for the others. Also whether the main pawn is in the ranking.
-- _G.__fw_reset = true clears.
if _G.__fw_reset or not _G.__fw then
  _G.__fw = { hooked = _G.__fw and _G.__fw.hooked, t = 0, a = { n = 0, decoy = 0, pawn = 0, arisen = 0, other = 0, none = 0, haspawn = 0 }, b = { n = 0, decoy = 0, pawn = 0, arisen = 0, other = 0, none = 0, haspawn = 0 } }
  _G.__fw_reset = nil
end
local W = _G.__fw
if not W.hooked then W.hooked = true
  re.on_frame(function() local W = _G.__fw; local now = os.clock(); if now - W.t < 0.25 then return end; W.t = now
    pcall(function()
      local st = PawnTrickster.state; local c = st.ctx; if not c or st.battle ~= 2 then return end
      local pg = c.chara:call("get_GameObject"):get_address()
      local ag = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer"):call("get_GameObject"):get_address()
      local em = sdk.get_managed_singleton("app.EnemyManager"); local l = em:get_field("_EnemyList")
      for i = 0, l:call("get_Count") - 1 do pcall(function()
        local ch = l:call("get_Item", i):call("get_Chara"); if ch:call("get_Hp") <= 0 then return end
        local hs = ch:get_field("<HateSystem>k__BackingField"); if not hs then return end
        local B = (st.fools and st.fools[ch:get_address()]) and W.a or W.b
        local rk = hs:get_field("_Ranking"); local k = rk:get_size(); local top, haspawn = nil, false
        for j = 0, k - 1 do local el = rk:get_element(j)
          if el and el:call("get_Enable") then local o = el:call("get_TargetObj"); local a = o and o:get_address()
            local kind = el:call("get_TargetSmokeDecoy") and "decoy" or (a == pg and "pawn") or (a == ag and "arisen") or "other"
            if kind == "pawn" then haspawn = true end; top = top or kind end end
        B.n = B.n + 1; B[top or "none"] = B[top or "none"] + 1; if haspawn then B.haspawn = B.haspawn + 1 end end) end
    end)
  end)
end
local function line(name, B) if B.n == 0 then return name .. ": no sample" end
  return string.format("%s: %d samples | top of the ranking: decoy %.0f%%, main pawn %.0f%%, Arisen %.0f%%, other %.0f%%, nobody %.0f%% | main pawn in the ranking at all %.0f%%", name, B.n,
    100 * B.decoy / B.n, 100 * B.pawn / B.n, 100 * B.arisen / B.n, 100 * B.other / B.n, 100 * B.none / B.n, 100 * B.haspawn / B.n) end
out(line("enemies fooled by the ball", W.a)); out(line("other enemies", W.b))
