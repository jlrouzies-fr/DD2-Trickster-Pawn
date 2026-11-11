-- A still target for filming or measuring a cast: the living enemy nearest to the Arisen is frozen where it stands
-- (its GameObject stops updating: a statue that can still be hit), and the main pawn is put _G.__dummy.dist metres
-- (default 5.5) from it, on the line to the Arisen, facing it. _G.__dummy = { off = true } lets the statue go again
-- (do that before cleanup.lua). far = true puts the pawn on the side of the enemy the Arisen is not on; arisen_back = 3 moves the Arisen 3 m behind the pawn (out of the line of the throw). Run again with nothing set to read where everything is.
-- usage: spawn one enemy and bring it (fight_goblins.lua / bring.lua), wait two seconds, then this file.
_G.__dm = _G.__dm or {}
local M = _G.__dm; local R = _G.__dummy; _G.__dummy = nil
local PT = PawnTrickster; local c = PT.state.ctx; if not c then out("no pawn") return end
local function pos(ch) return ch:call("get_Transform"):call("get_Position") end
if R and R.off then
  if M.go then M.go:call("set_UpdateSelf", true); out("dummy released") else out("no dummy") end
  M.go = nil; M.chara = nil; return
end
if R then
  local best
  for _, e in ipairs(PT.enemies(true)) do if e.hp > 0 and e.dist >= 0 and e.dist < 30 and (not best or e.dist < best.dist) then best = e end end
  if not best then out("no living enemy within 30 m of the Arisen") return end
  local go = best.chara:call("get_GameObject")
  if not go:get_type_definition():get_method("set_UpdateSelf") then out("no set_UpdateSelf on " .. go:get_type_definition():get_full_name()) return end
  local ep = pos(best.chara)
  local pl = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer"); local ap = pos(pl)
  local dx, dz = ap.x - ep.x, ap.z - ep.z; local h = math.sqrt(dx * dx + dz * dz); if h < 0.1 then out("the enemy stands on the Arisen") return end
  local d = R.dist or 5.5; local f = d / h
  if R.far then f = -f end -- the pawn on the other side of the enemy: the Arisen is then behind the target, not in the line of the throw
  -- the pawn: on the line from the enemy to the Arisen, d metres from the enemy, at a height between the two
  local target = Vector3f.new(ep.x + dx * f, ep.y + (ap.y - ep.y) * math.min(1.0, f) + 0.3, ep.z + dz * f)
  go:call("set_UpdateSelf", false); go:add_ref_permanent(); M.go = go; M.chara = best.chara
  c.chara:call("warp(via.vec3, app.CharacterWarpOption)", target, 0)
  if R.arisen_back and not R.far then -- the Arisen out of the line of the throw: that many metres behind the pawn
    local g = (d + R.arisen_back) / h
    pl:call("warp(via.vec3, app.CharacterWarpOption)", Vector3f.new(ep.x + dx * g, target.y + 0.2, ep.z + dz * g), 0)
  end
  local yaw = R.far and math.atan(dx, dz) or math.atan(-dx, -dz) -- the pawn faces the enemy (its facing is the transform's +Z axis)
  c.chara:call("get_Transform"):call("set_Rotation", Quaternion.new(math.cos(yaw / 2), 0, math.sin(yaw / 2), 0))
end
if not M.chara then out("no dummy set") return end
local ep, pp = pos(M.chara), pos(c.chara)
out(string.format("dummy %s hp %.0f, frozen %s | pawn %.1f m from it, %.1f m higher", tostring(M.go:call("get_Name")), M.chara:call("get_Hp"),
  tostring(M.go:call("get_UpdateSelf") == false), math.sqrt((ep.x - pp.x) ^ 2 + (ep.z - pp.z) ^ 2), pp.y - ep.y))
