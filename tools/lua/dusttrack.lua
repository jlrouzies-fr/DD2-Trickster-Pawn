-- TEST (read only): every dust ball the pawn throws: distance and height of its target at launch, how close the ball
-- came to the target's body (0.7 m above its feet), how far the target moved meanwhile, how long the ball lived.
-- _G.__dt_reset = true clears.
if _G.__dt_reset or not _G.__dt then _G.__dt = { rows = {}, live = {}, hooked = _G.__dt and _G.__dt.hooked }; _G.__dt_reset = nil end
local T = _G.__dt
if not T.hooked then T.hooked = true
  sdk.hook(sdk.find_type_definition("app.ShellManager"):get_method("registShell"), function(args)
    pcall(function() local T = _G.__dt; local sh = sdk.to_managed_object(args[3]); if not sh then return end
      local c = PawnTrickster.state.ctx; local pg = c and c.chara:call("get_GameObject"); local ow = sh:get_field("<Owner>k__BackingField")
      if not (pg and ow and ow:get_address() == pg:get_address()) then return end
      if tostring(sh:get_field("<ShellParamId>k__BackingField")) ~= "2585554136" then return end
      local ti = sh:get_field("_TargetInfo"); local tg = ti and ti:get_field("TargetObject"); if not tg then return end
      sh:add_ref_permanent(); tg:add_ref_permanent()
      T.live[#T.live + 1] = { sh = sh, tg = tg, t0 = os.clock(), hits0 = PawnTrickster.state.dust_hits or 0 } end)
  end, function(r) return r end)
  re.on_frame(function() local T = _G.__dt
    for _, e in ipairs(T.live) do if not e.done then
      local ok, alive = pcall(function() local g = e.sh:call("get_GameObject"); if not g then return false end
        local p = g:call("get_Transform"):call("get_Position"); local q = e.tg:call("get_Transform"):call("get_Position"); local t = os.clock() - e.t0
        if not e.p0 then e.p0 = { x = p.x, y = p.y, z = p.z }; e.q0 = { x = q.x, y = q.y, z = q.z } end
        local d = math.sqrt((p.x - q.x) ^ 2 + (p.y - (q.y + 0.7)) ^ 2 + (p.z - q.z) ^ 2)
        if not e.min or d < e.min then e.min = d; e.tmin = t; e.dymin = p.y - q.y end
        e.q1 = { x = q.x, y = q.y, z = q.z }; e.p1 = { x = p.x, y = p.y, z = p.z }; e.t = t
        return t < 3.0 end)
      if not ok or not alive then e.done = true
        if e.p0 and e.q1 then
          local d0 = math.sqrt((e.q0.x - e.p0.x) ^ 2 + (e.q0.z - e.p0.z) ^ 2)
          local moved = math.sqrt((e.q1.x - e.q0.x) ^ 2 + (e.q1.z - e.q0.z) ^ 2); local flew = math.sqrt((e.p1.x - e.p0.x) ^ 2 + (e.p1.z - e.p0.z) ^ 2)
          e.row = { d0 = d0, dy0 = e.q0.y - (e.p0.y - 1.2), min = e.min or -1, tmin = e.tmin or 0, dymin = e.dymin or 0, moved = moved, flew = flew, life = e.t or 0 }
        end end end end
  end)
end
local n, h = 0, 0
for _, e in ipairs(T.live) do if e.done and e.row then n = n + 1
  if e.hit == nil then e.hit = (PawnTrickster.state.dust_hits or 0) > e.hits0 end -- (approximate: a hit counted since this ball left)
  local r = e.row
  out(string.format("ball: target %.1f m away, %+.1f m higher | closest %.1f m after %.2f s (ball %+.1f m above its feet) | target moved %.1f m | ball flew %.1f m, lived %.1f s", r.d0, r.dy0, r.min, r.tmin, r.dymin, r.moved, r.flew, r.life)) end end
out("dust balls tracked " .. n)
