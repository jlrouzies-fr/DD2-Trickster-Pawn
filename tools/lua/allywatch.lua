-- TEST (read only): once a second in battle, which ally her Rally rule sees (arisen / pawn / none)
_G.__ally = _G.__ally or { t = 0, n = {} }
if not _G.__ally_hook then _G.__ally_hook = true
  re.on_frame(function() local A = _G.__ally; local now = os.clock(); if now - A.t < 1.0 then return end; A.t = now
    pcall(function() local st = PawnTrickster.state; if st and st.battle == 2 and st.rally_ally then A.n[st.rally_ally] = (A.n[st.rally_ally] or 0) + 1 end
      if st and st.rally_tired then A.n.tired = (A.n.tired or 0) + 1 end end) end)
end
local t = {}; for k, v in pairs(_G.__ally.n) do t[#t + 1] = k .. "=" .. v end; table.sort(t)
out("rally ally seconds", table.concat(t, " "), "now", tostring(PawnTrickster.state and PawnTrickster.state.rally_ally))
