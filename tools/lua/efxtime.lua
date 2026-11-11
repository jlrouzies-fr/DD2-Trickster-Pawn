-- TEST (read only): the timeline of every effect the game creates in the 5 s after the main pawn starts an action
-- whose name contains _G.__et_action (default "Job09_ShortSmokeAttack"): seconds since the action began, the effect
-- object, its parent, its distance from the pawn, its local scale, and for its effect players (three levels) the
-- resource, play speed, looped flag and colour. Run once to set the hook, again to read the last action's timeline.
-- _G.__et_reset = true clears. Names the effect behind a cloud seen in a capture.
_G.__et = _G.__et or { rows = {}, t0 = -99, last_act = "", n = 0 }
local E = _G.__et
E.want = _G.__et_action or E.want or "Job09_ShortSmokeAttack"
if _G.__et_reset then E.rows = {}; E.n = 0; _G.__et_reset = nil end
local ept = sdk.typeof("via.effect.EffectPlayer")
function E.players(g, acc, depth)
  pcall(function() local ep = g:call("getComponent(System.Type)", ept); if ep then acc[#acc + 1] = ep end end)
  if depth < 3 then pcall(function() local ch = g:call("get_Transform"):call("get_Child")
    while ch do E.players(ch:call("get_GameObject"), acc, depth + 1); ch = ch:call("get_Next") end end) end
  return acc
end
function E.created(ret)
  local now = os.clock(); if now - E.t0 > 5.0 then return end
  local c = PawnTrickster.state.ctx; if not c then return end
  local pp = c.chara:call("get_Transform"):call("get_Position")
  local arr = sdk.to_managed_object(ret)
  for i = 0, (arr and arr:get_size() or 0) - 1 do local g = arr:get_element(i)
    if g and #E.rows < 200 then
      local tf = g:call("get_Transform"); local par = tf:call("get_Parent"); local q = tf:call("get_Position")
      local pname = par and tostring(par:call("get_GameObject"):call("get_Name")) or "none"
      local eps = E.players(g, {}, 0); local info = {}
      for k, ep in ipairs(eps) do if k <= 2 then
        local res, col = "?", "?"
        pcall(function() local h = ep:call("get_Resource"); res = tostring(h and (h:call("get_ResourcePath") or h:call("ToString")) or "none") end)
        pcall(function() col = string.format("%08x", ep:call("get_Color"):get_field("rgba")) end)
        info[#info + 1] = string.format("[%s speed %.1f looped %s colour %s]", res, ep:call("get_PlaySpeed"), tostring(ep:call("get_Looped")), col)
      end end
      E.rows[#E.rows + 1] = string.format("#%d +%.2f s  %s  parent %s  %.1f m from the pawn  scale %.2f  players %d %s", E.n, now - E.t0,
        tostring(g:call("get_Name")), pname, math.sqrt((q.x - pp.x) ^ 2 + (q.y - pp.y) ^ 2 + (q.z - pp.z) ^ 2), tf:call("get_LocalScale").x, #eps, table.concat(info, " ")):gsub("VFX/Effects/", "")
    end
  end
end
if not E.hooked then E.hooked = true
  for _, m in ipairs(sdk.find_type_definition("via.effect.script.EffectManager"):get_methods()) do
    if m:get_name() == "createEffectInternal" then
      sdk.hook(m, function(args) end, function(ret) pcall(_G.__et.created, ret); return ret end)
    end
  end
  re.on_frame(function() local E = _G.__et
    pcall(function() local a = PawnTrickster.state.act_now or ""
      if a ~= E.last_act then E.last_act = a
        if a:find(E.want, 1, true) then E.t0 = os.clock(); E.n = E.n + 1 end end end)
  end)
end
out("actions seen " .. E.n .. " (" .. E.want .. "), effects in the last one " .. #E.rows)
for _, s in ipairs(E.rows) do out(s) end
