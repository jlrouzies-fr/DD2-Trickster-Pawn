-- TEST (read only): for every Latching Effigy cast, who the executing rule's target was (distance, height, bearing
-- from the pawn's facing), how far the nearest enemy was, and whether the decoy latched within 5 s.
-- _G.__effwatch_reset = true clears.
if _G.__effwatch_reset or not _G.__ew then _G.__ew = { rows = {}, cur = nil, last = nil } end
_G.__effwatch_reset = nil
if not _G.__ew_hook then _G.__ew_hook = true; re.on_frame(function() if _G.__ew_fn then pcall(_G.__ew_fn) end end) end
_G.__ew_fn = function()
  local E = _G.__ew; local st = PawnTrickster.state; if not st then return end
  local act = tostring(st.act_now); local now = os.clock()
  if E.cur then
    if st.possessed then E.cur.latched = true end
    if now - E.cur.t > 5.0 then E.rows[#E.rows + 1] = E.cur; E.cur = nil end
  end
  if act == "Job09_CastPossessionSmoke" and E.last ~= act and not E.cur then
    local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter")
    local tf = ch:call("get_Transform"); local pp = tf:call("get_Position"); local q = tf:call("get_Rotation")
    local fx, fz = 2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y) -- the pawn's facing is the transform's Z axis
    local row = { t = now, latched = false, tgt = "?", td = -1, tdy = 0, tang = -1, nd = 999, nang = -1, n6 = 0, dec = "?" }
    local function bearing(p) local dx, dz = p.x - pp.x, p.z - pp.z; local d = math.sqrt(dx * dx + dz * dz); if d < 0.01 then return 0, d end
      local c = (dx * fx + dz * fz) / (d * math.sqrt(fx * fx + fz * fz)); return math.deg(math.acos(math.max(-1, math.min(1, c)))), d end
    local ex = pawn:get_field("CachedAIDecisionMaker"):get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
    local ed = ex:get_field("<ExecutingDecision>k__BackingField"); local dec = ed and ed:get_field("<Decision>k__BackingField")
    if dec then local g = dec:get_field("<UniqueID>k__BackingField"); row.dec = st.guid_names and st.guid_names[tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))] or "vanilla" end
    local tg = ed and ed:get_field("<Target>k__BackingField")
    if tg then pcall(function() local ttf = tg:get_field("<Transform>k__BackingField"); local p = ttf:call("get_Position"); local a, d = bearing(p)
      row.td = d; row.tdy = p.y - pp.y; row.tang = a; row.tgt = tostring(tg:get_field("<GameObject>k__BackingField"):call("get_Name")) end) end
    for _, e in ipairs(PawnTrickster.enemies(true)) do if e.hp > 0 then pcall(function() local p = e.chara:call("get_Transform"):call("get_Position"); local a, d = bearing(p)
      if d < row.nd then row.nd = d; row.nang = a end; if d <= 6.5 then row.n6 = row.n6 + 1 end end) end end
    E.cur = row
  end
  E.last = act
end
local E = _G.__ew; local n, l = 0, 0; local t = {}
for _, r in ipairs(E.rows) do n = n + 1; if r.latched then l = l + 1 end
  t[#t + 1] = string.format("%s rule=%s target %.1f m dy %.1f %.0f degrees off its facing | nearest %.1f m, %.0f degrees off | enemies within 6.5 m: %d", r.latched and "LATCHED" or "missed ", r.dec, r.td, r.tdy, r.tang, r.nd, r.nang, r.n6) end
out("effigy casts " .. n .. ", latched " .. l); for _, s in ipairs(t) do out(s) end
