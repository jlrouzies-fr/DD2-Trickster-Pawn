-- TEST ONLY: the Arisen cannot die (flag on her hit controller, gone at the next load); the pawn is healed
local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer"); local hit = pl:call("get_Hit")
hit:call("set_IsNoDie", true)
local mp = sdk.get_managed_singleton("app.PawnManager"):call("get_MainPawn"); local ch = mp and mp:get_field("<CachedCharacter>k__BackingField")
local php = ch and ch:call("get_Hp"); if ch and _G.__heal_pawn then pcall(function() ch:call("recoverAll") end) end
local p = pl:call("get_Transform"):call("get_UniversalPosition")
out("nodie", tostring(hit:call("get_IsNoDie")), "arisen hp", tostring(pl:call("get_Hp")), "pawn hp", tostring(php), "pawn dead", tostring(ch and ch:call("get_IsDead")), string.format("pos %.1f %.1f %.1f", p.x, p.y, p.z))
