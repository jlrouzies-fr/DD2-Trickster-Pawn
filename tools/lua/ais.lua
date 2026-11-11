local pm = sdk.get_managed_singleton("app.PawnManager"); local pawn = pm:get_field("_MainPawn"); local ch = pawn:call("get_CachedCharacter"); local ai = ch:get_field("CharaAIStateCtrl")
local pl = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer"); local st = PawnTrickster.state
local names = { [1] = "Normal", [8] = "Caution", [64] = "Combat", [128] = "Danger" }
local function nm(v) return names[v] or tostring(v) end
out("AI state", nm(ai:call("get_AIState")), "base", nm(ai:get_field("_AIState")), "temp", nm(ai:get_field("_TempAIState")), "| arisen hp", string.format("%.0f", pl:call("get_Hp")), "pawn hp", string.format("%.0f", ch:call("get_Hp")), "party", tostring(pm:call("get_BattleController"):get_field("_CurrentState")), "picks", tostring(st.picks), "casts", tostring(st.casts))
