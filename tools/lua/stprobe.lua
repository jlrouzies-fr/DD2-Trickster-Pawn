local st = PawnTrickster.state or {}; local t = {}
local function kv(tbl) local r = {}; for k, v in pairs(tbl or {}) do r[#r + 1] = tostring(k) .. "=" .. tostring(v) end; table.sort(r); return table.concat(r, ",") end
out("clock", string.format("%.1f", os.clock()), "gate_blocked{" .. kv(st.gate_blocked) .. "}", "want_since", tostring(st.want_since), "preempt_t", tostring(st.preempt_t), "gap", tostring(st.preempt_gap), "preempt_picks", tostring(st.preempt_picks),
  "picks", tostring(st.picks), "casts", tostring(st.casts), "preempts", tostring(st.preempts), "hold_until", tostring(st.stance_hold_until), "cur", tostring(st.current_decision), "act_now", tostring(st.act_now), "battle", tostring(st.battle), "ready_t", tostring(st.ready_t))
