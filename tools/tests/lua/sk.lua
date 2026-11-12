local PT = PawnTrickster; local st = PT.state; local c = st.ctx
local e = {}; for id in pairs(st.equipped or {}) do e[#e + 1] = id end; table.sort(e)
local slots = {}
pcall(function() for i = 0, 3 do slots[#slots + 1] = tostring(c.skillctx:call("getSkill", 9, i)) end end)
local d = {}; for k in pairs(st.decs or {}) do d[#d + 1] = k end; table.sort(d)
out("built for [" .. tostring(st.built_sig) .. "] equipped now [" .. table.concat(e, ",") .. "] battle " .. tostring(st.battle) .. " slots built: " .. table.concat(d, " ") .. " | enabled " .. tostring(PT.enabled) .. " ready " .. tostring(st.ready_t ~= nil) .. " cand " .. tostring(st.skill_cand))
