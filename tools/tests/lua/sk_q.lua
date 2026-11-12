local PT = PawnTrickster; local st = PT.state
local e = {}; for id in pairs(st.equipped or {}) do e[#e + 1] = id end; table.sort(e)
local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local sc = pawn:get_field("<CachedHuman>k__BackingField"):get_field("<SkillContext>k__BackingField")
local sk = sc:get_field("EquipedSkills")[9]:get_field("Skills"); local t = {}
for i = 0, 3 do local v = sk[i] and (type(sk[i]) == "number" and sk[i] or sk[i]:get_field("value__")) or 0; if v ~= 0 then t[#t + 1] = v end end; table.sort(t)
local d = {}; for k in pairs(st.decs or {}) do d[#d + 1] = k end; table.sort(d)
out("game slots [" .. table.concat(t, ",") .. "] built for [" .. tostring(st.built_sig) .. "] enabled " .. tostring(PT.enabled) .. " pending " .. tostring(st.pending ~= nil) .. " ready " .. tostring(st.ready_t ~= nil) .. " pack " .. tostring(st.trickster_pack ~= nil) .. " rules: " .. table.concat(d, " "))
