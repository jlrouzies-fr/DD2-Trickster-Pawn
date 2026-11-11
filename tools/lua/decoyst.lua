-- read only: the pawn's decoy handler state (the getters the mod itself reads)
local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter")
local c = PawnTrickster.state.ctx; local j9 = c and c.job09
local dh = j9 and j9:call("get_DecoyHandler")
out("handler", tostring(dh ~= nil), "has instance", tostring(dh and dh:call("get_HasInstance")), "appeared", tostring(dh and dh:call("get_Appeared")), "hidden", tostring(dh and dh:call("get_Hidden")), "in process", tostring(dh and dh:call("get_InProcess")), "battle", tostring(PawnTrickster.state.battle), "resummons", tostring(PawnTrickster.state.resummons))
