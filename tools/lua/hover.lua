-- TEST ONLY: hold the Arisen at a universal point for some seconds (re-warp twice a second) so the area streams in,
-- then let her drop. _G.__hover_req = { x, y, z, seconds }
if not _G.__hover then
  _G.__hover = { n = 0 }
  re.on_frame(function()
    local h = _G.__hover; if not h.t or os.clock() > h.t then h.t = nil; return end
    h.n = h.n + 1; if h.n % 20 ~= 0 then return end
    pcall(function()
      local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer"); if not pl then return end
      local tf = pl:call("get_Transform"); local pp = tf:call("get_UniversalPosition"); local lp = tf:call("get_Position")
      local tl = Vector3f.new(h.x - (pp.x - lp.x), h.y - (pp.y - lp.y), h.z - (pp.z - lp.z))
      pcall(function() pl:call("warp(via.vec3, app.CharacterWarpOption)", tl, 1) end)
    end)
  end)
end
local r = _G.__hover_req; local h = _G.__hover
h.x, h.y, h.z = r[1], r[2], r[3]; h.t = os.clock() + r[4]
out("hovering at", h.x, h.y, h.z, "for", r[4], "s")
