-- TEST: play one action on the main pawn and log what follows for 6 s: every action it goes through (name, seconds
-- since the request) and every shell it registers (seconds, shell parameter id, and where the shell is relative to
-- the pawn at registration and one frame later: metres ahead of the pawn / to its right / above its feet).
-- _G.__aw_req = "Job09_ThrowSmoke" asks for that action now; run again with nothing set to read the timeline.
-- _G.__aw_req2 = { name = "NormalLocomotion", t = 1.6 } asks for a second action that long after the first (does it cut the first one short?).
-- For finding out what an action does, when its projectile leaves and from where.
_G.__aw = _G.__aw or { rows = {}, t0 = -99, last = "", pend = {} }
local A = _G.__aw; A.pend = A.pend or {}
function A.rel(p) -- a world position in the pawn's frame: ahead, right, up
  local tf = PawnTrickster.state.ctx.chara:call("get_Transform"); local pp = tf:call("get_Position"); local q = tf:call("get_Rotation")
  local yaw = math.atan(2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y))
  local dx, dz = p.x - pp.x, p.z - pp.z
  return string.format("%.2f ahead, %.2f right, %.2f up", dx * math.sin(yaw) + dz * math.cos(yaw), dx * math.cos(yaw) - dz * math.sin(yaw), p.y - pp.y)
end
function A.reg(args)
  local now = os.clock(); if now - A.t0 > 6.0 then return end
  local c = PawnTrickster.state.ctx; if not c then return end
  local sh = sdk.to_managed_object(args[3]); if not sh then return end
  local ow = sh:get_field("<Owner>k__BackingField"); local pg = c.chara:call("get_GameObject")
  if not (ow and pg and ow:get_address() == pg:get_address()) then return end
  local where = "?"; pcall(function() where = A.rel(sh:call("get_GameObject"):call("get_Transform"):call("get_Position")) end)
  A.rows[#A.rows + 1] = string.format("+%.2f s  shell %s  at %s", now - A.t0, tostring(sh:get_field("<ShellParamId>k__BackingField")), where)
  sh:add_ref(); A.pend[#A.pend + 1] = { sh = sh, n = 0, row = #A.rows }
end
function A.frame()
  local now = os.clock()
  for i = #A.pend, 1, -1 do local p = A.pend[i]; p.n = p.n + 1
    if p.n >= 2 then table.remove(A.pend, i)
      pcall(function() A.rows[p.row] = A.rows[p.row] .. "  | a frame later " .. A.rel(p.sh:call("get_GameObject"):call("get_Transform"):call("get_Position")) end) end end
  if now - A.t0 > 6.0 then return end
  if A.req2 and now - A.t0 >= A.req2.t then local r = A.req2; A.req2 = nil; A.rows[#A.rows + 1] = string.format("+%.2f s  request %s: %s", now - A.t0, r.name, tostring(PawnTrickster.request(r.name, r.layer or 0))) end
  local a = PawnTrickster.state.act_now or ""
  if a ~= A.last then A.last = a; A.rows[#A.rows + 1] = string.format("+%.2f s  action %s", now - A.t0, a) end
end
if not A.hooked then A.hooked = true
  sdk.hook(sdk.find_type_definition("app.ShellManager"):get_method("registShell"), function(args) pcall(_G.__aw.reg, args) end, function(r) return r end)
  re.on_frame(function() pcall(_G.__aw.frame) end)
end
local req = _G.__aw_req; _G.__aw_req = nil
if req then A.rows = {}; A.t0 = os.clock(); A.req2 = _G.__aw_req2; _G.__aw_req2 = nil; A.last = PawnTrickster.state.act_now or ""; out("request " .. req, tostring(PawnTrickster.request(req))) return end
out("timeline: " .. #A.rows .. " rows")
for _, s in ipairs(A.rows) do out(s) end
