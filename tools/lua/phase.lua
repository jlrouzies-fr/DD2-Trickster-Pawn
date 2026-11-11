local mf = sdk.get_managed_singleton("app.MainFlowManager")
out("phase", tostring(mf and mf:call("get_FlowPhase")), "ingame", tostring(mf and mf:call("get_IsInGamePhase")), "PT", tostring(_G.PawnTrickster ~= nil), "guard", _G.__pt_hire_guard and _G.__pt_hire_guard.closed)
