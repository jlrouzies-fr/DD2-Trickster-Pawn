-- TEST: change config values in the running game and build the pawn's rules again (disable, then enable).
-- _G.__variant = { rally_cooldown = 12, rally_min_stamina = 0.7 }
for k, v in pairs(_G.__variant or {}) do PawnTrickster.cfg[k] = v end
local ok1 = pcall(PawnTrickster.disable); PawnTrickster.user_disabled = false
_G.__variant_enable_at = os.clock() + 4
if not _G.__variant_hook then _G.__variant_hook = true
  re.on_frame(function() if _G.__variant_enable_at and os.clock() > _G.__variant_enable_at then _G.__variant_enable_at = nil; pcall(PawnTrickster.enable) end end) end
local t = {}; for k, v in pairs(_G.__variant or {}) do t[#t + 1] = k .. "=" .. tostring(v) end; table.sort(t)
out("variant", table.concat(t, " "), "disable", tostring(ok1), "enable in 4 s")
