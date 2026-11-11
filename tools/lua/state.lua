-- read only: flow phase, the mod's state, the test guards
local mf = sdk.get_managed_singleton("app.MainFlowManager")
local PT = _G.PawnTrickster; local st = PT and PT.state or {}
local gm = sdk.get_managed_singleton("app.GuiManager"); local ts = gm and gm:get_field("TalkSelect")
out("phase", tostring(mf and mf:call("get_FlowPhase")), "enabled", tostring(PT and PT.enabled), "pack", tostring(st.trickster_pack ~= nil), "battle", tostring(st.battle),
    "picks", tostring(st.picks), "casts", tostring(st.casts), "err", tostring(st.tick_err or st.trick_err or st.preempt_err or st.regroup_err), "hireclosed", tostring(_G.__pt_hire_guard and _G.__pt_hire_guard.closed),
    "talksel", tostring(ts and ts:get_field("IsDisp") and ts:get_field("FlowNow") == 0))
