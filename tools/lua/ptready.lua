local st = PawnTrickster and PawnTrickster.state or {}
out("enabled", tostring(PawnTrickster and PawnTrickster.enabled), "pack", tostring(st.trickster_pack ~= nil), "ready", tostring(st.ready_t ~= nil))
