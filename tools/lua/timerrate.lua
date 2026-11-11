-- TEST (read only): how the game counts a decision's cooldown. For 3 s, every frame, the CooldownTimer of every
-- decision wrapper of the main pawn that is counting down; then: how much a timer drops per frame and per second.
-- Run it, wait 4 s, run it again to read. _G.__tr_reset = true starts a new measurement.
if _G.__tr_reset or not _G.__tr then _G.__tr = { w = {}, n = 0, t0 = nil, hooked = _G.__tr and _G.__tr.hooked, run = true }; _G.__tr_reset = nil end
local T = _G.__tr
if not T.hooked then T.hooked = true
  re.on_frame(function() local T = _G.__tr; if not T or not T.run then return end
    pcall(function()
      local now = os.clock(); T.t0 = T.t0 or now; T.n = T.n + 1
      if now - T.t0 > 3.0 then T.run = false; T.t1 = now; return end
      local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn")
      local mod = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField")
      local list = mod:get_field("<MainDecisions>k__BackingField"); local items = list:get_field("_items"); local n = list:call("get_Count")
      for i = 0, n - 1 do local w = items[i]
        if w then local t = w:get_field("<CooldownTimer>k__BackingField") or 0; local a = w:get_address(); local e = T.w[a]
          if not e then e = { first = t, t0 = now, f0 = T.n, full = w:get_field("<CooldownTime>k__BackingField") or 0, ok = true }; T.w[a] = e end
          if e.ok and e.last and t > e.last + 0.001 then e.ok = false end -- the timer was set again: not a clean countdown
          if e.ok and t > 0 then e.last = t; e.t1 = now; e.f1 = T.n end end end
    end)
  end)
end
if T.run then out("measuring for 3 s; run again to read") return end
local rows, sumf, sums, k = {}, 0, 0, 0
for _, e in pairs(T.w) do if e.ok and e.last and e.f1 and e.f1 - e.f0 >= 30 and e.first - e.last > 0.5 then
  local pf = (e.first - e.last) / (e.f1 - e.f0); local ps = (e.first - e.last) / (e.t1 - e.t0); k = k + 1; sumf = sumf + pf; sums = sums + ps
  if #rows < 4 then rows[#rows + 1] = string.format("full %.0f: %.1f -> %.1f in %d frames / %.2f s = %.3f a frame, %.1f a second", e.full, e.first, e.last, e.f1 - e.f0, e.t1 - e.t0, pf, ps) end end end
out(string.format("timers counting down: %d | average drop %.3f a frame, %.1f a second | frames in the window %d over %.2f s = %.1f FPS", k, k > 0 and sumf / k or 0, k > 0 and sums / k or 0, T.n, (T.t1 or 0) - (T.t0 or 0), T.n / math.max(0.01, (T.t1 or 0) - (T.t0 or 0))))
for _, r in ipairs(rows) do out(r) end
