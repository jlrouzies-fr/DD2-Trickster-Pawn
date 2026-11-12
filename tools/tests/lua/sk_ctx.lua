-- equip a Job09 skill on the main pawn without the mod's context (works while the mod is setting the pawn up)
local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local human = pawn:get_field("<CachedHuman>k__BackingField")
local sc = human:get_field("<SkillContext>k__BackingField")
local ok1 = pcall(function() sc:call("setCustomSkillEnable(app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)", _G.__sk_id, 1) end)
local ok2, e2 = pcall(function() sc:call("setSkill", 9, _G.__sk_id, _G.__sk_slot) end)
local sk = sc:get_field("EquipedSkills")[9]:get_field("Skills"); local t = {}
for i = 0, 3 do t[#t + 1] = tostring(sk[i] and (type(sk[i]) == "number" and sk[i] or sk[i]:get_field("value__")) or "?") end
local PT = PawnTrickster; local st = PT.state
out("setSkill", _G.__sk_id, "slot", _G.__sk_slot, tostring(ok2), tostring(e2), "| slots now", table.concat(t, " "), "| mod: enabled", tostring(PT.enabled), "pending", tostring(st.pending ~= nil), "ready", tostring(st.ready_t ~= nil), "built", tostring(st.built_sig))
