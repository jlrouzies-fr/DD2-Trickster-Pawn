-- TEST: revive the main pawn only when she is down (no stamina refill otherwise)
local mp = sdk.get_managed_singleton("app.PawnManager"):call("get_MainPawn"); local ch = mp and mp:get_field("<CachedCharacter>k__BackingField")
local hp = ch and ch:call("get_Hp"); if ch and hp <= 0 then pcall(function() ch:call("recoverAll") end); _G.__revives = (_G.__revives or 0) + 1 end
out("pawn hp", tostring(hp), "revives", tostring(_G.__revives or 0))
