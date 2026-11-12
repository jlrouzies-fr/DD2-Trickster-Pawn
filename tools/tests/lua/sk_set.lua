local PT = PawnTrickster; PT.fightlog(false); local c = PT.state.ctx
local ok1, e1 = pcall(function() c.skillctx:call("setCustomSkillEnable(app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)", _G.__sk_id, 1) end)
local ok2, e2 = pcall(function() c.skillctx:call("setSkill", 9, _G.__sk_id, _G.__sk_slot) end)
local sk = c.skillctx:get_field("EquipedSkills")[9]:get_field("Skills"); local t = {}
for i = 0, 3 do t[#t + 1] = tostring(sk[i] and (type(sk[i]) == "number" and sk[i] or sk[i]:get_field("value__")) or "?") end
out("learn", tostring(ok1), tostring(e1), "| setSkill", _G.__sk_id, "slot", _G.__sk_slot, tostring(ok2), tostring(e2), "| slots now", table.concat(t, " "))
