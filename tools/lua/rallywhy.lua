-- TEST (read only): once every 0.5 s in battle, why the Rally gate is where it is (distance to the Arisen, ally seen, tired)
if _G.__rallywhy_reset then _G.__rw_reset = true; _G.__rallywhy_reset = nil end
if _G.__rw_reset or not _G.__rw then _G.__rw = { t = 0, n = 0, c = {}, dist = {} } end; _G.__rw_reset = nil
if not _G.__rw_hook then _G.__rw_hook = true
  re.on_frame(function() local R = _G.__rw; local now = os.clock(); if now - R.t < 0.5 then return end; R.t = now
    pcall(function() local st = PawnTrickster.state; if not (st and st.battle == 2) then return end
      local pm = sdk.get_managed_singleton("app.PawnManager"); local ch = pm:get_field("_MainPawn"):call("get_CachedCharacter")
      local pl = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer")
      local a, b = ch:call("get_Transform"):call("get_Position"), pl:call("get_Transform"):call("get_Position")
      local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
      local bucket = d < 9 and "<9 m" or (d < 12 and "9-12 m" or (d < 15 and "12-15 m" or (d < 20 and "15-20 m" or ">20 m")))
      R.n = R.n + 1; R.dist[bucket] = (R.dist[bucket] or 0) + 1
      local blk = st.gate_blocked and st.gate_blocked.rally
      local k = string.format("rally %s | ally %s tired %s protect %s", blk and "blocked" or "released", tostring(st.rally_ally), tostring(st.rally_tired), tostring(st.protect_until ~= nil and now < st.protect_until))
      R.c[k] = (R.c[k] or 0) + 1 end) end)
end
local R = _G.__rw; local t = {}; for k, v in pairs(R.c) do t[#t + 1] = string.format("%d  %s", v, k) end; table.sort(t, function(x, y) return tonumber(x:match("^(%d+)")) > tonumber(y:match("^(%d+)")) end)
local d = {}; for k, v in pairs(R.dist) do d[#d + 1] = k .. " " .. v end; table.sort(d)
out("samples " .. R.n .. " | distance to the Arisen: " .. table.concat(d, ", ")); for _, s in ipairs(t) do out(s) end
