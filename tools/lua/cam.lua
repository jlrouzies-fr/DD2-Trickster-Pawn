-- TEST: a camera on a character (the main pawn by default) for captures, and an action trigger for capture.sh.
-- The game's camera is not changed: its transform is overwritten each frame just before rendering, and comes back
-- the moment this stops (after `seconds`, or with _G.__cam_req = { off = true }).
--
-- _G.__cam_req = {
--   mode = "follow" | "side",   -- follow (default): a little behind and above the subject, looking the way it faces
--                               -- side: beside the line from the subject to the enemy nearest to it, both in frame
--   subject = "pawn" | "arisen",-- whose action is filmed (default pawn)
--   dist = 4.5, height = 2.0,   -- how far from the subject and how high above its feet the camera stands (m)
--   yaw = 20,                   -- follow: degrees around the subject (0 = straight behind, 180 = in front)
--   ahead = 2.0, look_h = 1.1,  -- follow: the camera looks at a point this far in front of the subject, this high
--   side = 0 | 1 | -1,          -- side: which side of the line (0 = the one the Arisen / pawn is not standing on)
--   fov = nil,
--   seconds = 20,               -- the camera is given back after this long, whatever happens
--   on_action = "ShortSmoke",   -- write pt_dev/cap_trigger.txt when the subject starts an action whose name has this text
--   nocam = true,               -- only watch for the action, leave the camera alone
--   late = true,                -- with on_action: leave the camera alone until the action starts (while the camera
--                               -- sat on the pawn waiting, the pawn's dust swing came far less often: 0 in 170 s)
-- }
local req = _G.__cam_req; _G.__cam_req = nil
_G.__cam = _G.__cam or { n = 0 }
local C = _G.__cam
local function subject(which)
  if which == "arisen" then return sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer") end
  local pawn = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn")
  return pawn and pawn:call("get_CachedCharacter")
end
local function pos_of(ch) local tf = ch and ch:call("get_Transform"); return tf and tf:call("get_Position") end
local function action_of(ch)
  local am = ch:call("get_ActionManager"); local list = am and am:get_field("CurrentActionList"); local items = list and list:get_field("_items")
  return items and items[0] and tostring(items[0]:get_field("Name")) or "?"
end
-- the living enemy nearest to p within 25 m (what a side view keeps in frame with the subject)
local function interest(p)
  local best, bd
  local em = sdk.get_managed_singleton("app.EnemyManager"); local l = em and em:get_field("_EnemyList"); local n = l and l:call("get_Count") or 0
  for i = 0, n - 1 do pcall(function()
    local ch = l:call("get_Item", i):call("get_Chara"); if ch:call("get_Hp") <= 0 then return end
    local q = pos_of(ch); local d = math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
    if d < 25 and math.abs(q.y - p.y) < 2.5 and (not bd or d < bd) then best, bd = q, d end end) end -- (on the subject's level: one down a cliff makes the camera look at rock)
  return best, bd
end
-- the first solid thing on the way from a to b (nil: the way is free)
local function ray(ax, ay, az, bx, by, bz)
  local r = C.ray
  if not r then r = {}; C.ray = r
    r.sys = sdk.get_native_singleton("via.physics.System")
    r.m = sdk.find_type_definition("via.physics.System"):get_method("castRay(via.Scene, via.physics.CastRayQuery, via.physics.CastRayResult)")
    r.res = sdk.create_instance("via.physics.CastRayResult"); r.res:add_ref_permanent()
    r.q = sdk.create_instance("via.physics.CastRayQuery"); r.q:add_ref_permanent()
    r.q:clearOptions(); r.q:enableAllHits(); r.q:enableNearSort()
    local fi = r.q:get_FilterInfo(); fi:set_Group(0); fi:set_Layer(2); fi:set_MaskBits(0)
    r.cpt = sdk.find_type_definition("via.physics.ContactPoint")
  end
  local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
  r.res:clear()
  r.q:call("setRay(via.vec3, via.vec3)", Vector3f.new(ax, ay, az), Vector3f.new(bx, by, bz))
  r.m:call(r.sys, scene, r.q, r.res)
  if r.res:get_NumContactPoints() == 0 then return nil end
  return sdk.get_native_field(r.res:call("getContactPoint(System.UInt32)", 0), r.cpt, "Position")
end
local function look_rot(fx, fy, fz, flip)
  if flip then fx, fy, fz = -fx, -fy, -fz end
  local h = math.sqrt(fx * fx + fz * fz); local yaw = math.atan(fx, fz); local pitch = -math.atan(fy, h)
  local cy, sy, cp, sp = math.cos(yaw / 2), math.sin(yaw / 2), math.cos(pitch / 2), math.sin(pitch / 2)
  return Quaternion.new(cy * cp, cy * sp, sy * cp, -sy * sp)
end
local function frame()
  local S = C.shot; if not S then return end
  local now = os.clock()
  if now > S.t_end then C.shot = nil; C.ended = "time"; return end
  local ch = subject(S.subject); local p = ch and pos_of(ch); if not p then return end
  -- action trigger
  if S.on_action then local a = action_of(ch)
    if a ~= S.last_act then S.last_act = a
      if a:find(S.on_action, 1, true) and not S.fired then S.fired = true; C.n = C.n + 1
        local f = io.open("pt_dev/cap_trigger.txt", "w"); if f then f:write(tostring(C.n) .. " " .. a); f:close() end end end end
  if S.nocam or (S.late and not S.fired) then return end -- (late: the camera only moves once the action has started)
  local cx, cy, cz, lx, ly, lz
  if S.mode == "follow" then
    -- behind the subject, a little to the side and above, looking past it the way it faces. The camera turns with
    -- the subject, slowly, so that a pawn that turns to its target is still seen from behind.
    local q = ch:call("get_Transform"):call("get_Rotation"); local face = math.atan(2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y))
    if not S.base then S.base = face else local d = (face - S.base + math.pi) % (2 * math.pi) - math.pi; S.base = S.base + d * 0.06 end
    local a = S.base + math.rad(180 + S.yaw) -- yaw 0 = straight behind, 180 = in front
    lx, ly, lz = p.x + math.sin(S.base) * S.ahead, p.y + S.look_h, p.z + math.cos(S.base) * S.ahead
    -- a place with nothing solid between it and the subject: as asked, then higher, then closer and higher. Never
    -- closer than that (a camera pulled up to the subject shows nothing of it). Looked for again once a second.
    if not S.fplan or (not S.fired and now - (S.fplan_t or 0) > 1.0) then -- (kept once the awaited action has started: a camera that re-places itself mid-shot ruins it)
      S.fplan = { 1.0, 0.0 }; S.fplan_t = now; S.blocked = true
      for _, c in ipairs({ { 1.0, 0.0 }, { 1.0, 1.5 }, { 0.65, 1.2 }, { 0.65, 2.2 } }) do
        local x, y, z = p.x + math.sin(a) * S.dist * c[1], p.y + S.height + c[2], p.z + math.cos(a) * S.dist * c[1]
        if not ray(p.x, p.y + S.look_h, p.z, x, y, z) then S.fplan = c; S.blocked = false; break end
      end
    end
    cx, cy, cz = p.x + math.sin(a) * S.dist * S.fplan[1], p.y + S.height + S.fplan[2], p.z + math.cos(a) * S.dist * S.fplan[1]
  else
    local q, d = S.q, S.d
    if not q or (not S.fired and now - (S.q_t or 0) > 0.5) then local nq, nd = interest(p); if nq then q, d = { x = nq.x, y = nq.y, z = nq.z }, nd; S.q, S.d, S.q_t = q, d, now end end
    if not q then q = { x = p.x + 4, y = p.y, z = p.z }; d = 4 end
    local mx, my, mz = (p.x + q.x) / 2, (p.y + q.y) / 2, (p.z + q.z) / 2
    local dx, dz = q.x - p.x, q.z - p.z; local l = math.max(0.1, math.sqrt(dx * dx + dz * dz))
    local back = math.max(S.dist, 0.75 * l + 3.0)
    -- beside the line, at a place from which both are seen: first the side where the other one of the pair (Arisen /
    -- pawn) is not standing (side 0) or the side asked for, at full distance; then the other side, closer, higher.
    -- A place is taken when no solid thing lies between it and the subject's chest or the middle of the line.
    -- Chosen again every half second until the action starts, then kept (a camera that changes sides ruins the shot).
    if not S.plan or (not S.fired and now - (S.plan_t or 0) > 0.5) then
      local sides = { S.side, -S.side }
      if S.side == 0 then
        local o = subject(S.subject == "pawn" and "arisen" or "pawn"); local op = o and pos_of(o)
        local cross = op and ((op.x - p.x) * dz - (op.z - p.z) * dx) or 1
        local s0 = (cross > 0) and 1 or -1; sides = { s0, -s0 }
      end
      local best
      for _, f in ipairs({ 1.0, 0.7, 0.5 }) do
        for _, hh in ipairs({ S.height, S.height + 1.5 }) do
          for _, sd in ipairs(sides) do
            local x, y, z = mx + (-dz / l * sd) * back * f, math.max(p.y, q.y) + hh, mz + (dx / l * sd) * back * f
            if not ray(mx, my + S.look_h, mz, x, y, z) and not ray(p.x, p.y + 1.2, p.z, x, y, z) then best = { sd, f, hh }; break end
          end
          if best then break end
        end
        if best then break end
      end
      S.plan = best or { sides[1], 0.5, S.height + 1.5 }; S.plan_t = now; S.blocked = best == nil
    end
    local px, pz = -dz / l * S.plan[1], dx / l * S.plan[1]
    back = back * S.plan[2]
    cx, cy, cz = mx + px * back, math.max(p.y, q.y) + S.plan[3], mz + pz * back
    lx, ly, lz = mx, my + S.look_h, mz
  end
  -- smoothed, so that a target that changes does not jump the view
  if S.c then local k = 0.15; cx, cy, cz = S.c[1] + (cx - S.c[1]) * k, S.c[2] + (cy - S.c[2]) * k, S.c[3] + (cz - S.c[3]) * k
    lx, ly, lz = S.l[1] + (lx - S.l[1]) * k, S.l[2] + (ly - S.l[2]) * k, S.l[3] + (lz - S.l[3]) * k end
  S.c, S.l = { cx, cy, cz }, { lx, ly, lz }
  local cam = sdk.get_primary_camera(); if not cam then return end
  local tf = cam:call("get_GameObject"):call("get_Transform")
  tf:call("set_Position", Vector3f.new(cx, cy, cz))
  tf:call("set_Rotation", look_rot(lx - cx, ly - cy, lz - cz, S.flip))
  if S.fov then pcall(function() cam:call("set_FOV", S.fov) end) end
  S.frames = (S.frames or 0) + 1
end
-- The hook is set once per game session and calls whatever this file defined last (a hook that keeps the first
-- `frame` it was given goes on running old code after the file is edited and run again).
C.frame = frame
if not C.hooked2 then C.hooked2 = true
  local ok = pcall(re.on_pre_application_entry, "LockScene", function()
    local f = _G.__cam and _G.__cam.frame; if not f then return end
    local okf, e = pcall(f); if not okf then _G.__cam.err = tostring(e) end end)
  C.entry = ok and "LockScene" or "none"
end
if req then
  if req.off then C.shot = nil; C.ended = "off"
  else
    C.shot = { mode = req.mode or "follow", subject = req.subject or "pawn", dist = req.dist or 4.5, height = req.height or 2.0, yaw = req.yaw or 20.0, ahead = req.ahead or 2.0,
      side = req.side or 0, look_h = req.look_h or 1.1, fov = req.fov, flip = req.flip ~= false, on_action = req.on_action, nocam = req.nocam == true, late = (req.late == true and req.on_action ~= nil),
      t_end = os.clock() + (req.seconds or 20.0) }
    C.err = nil; C.ended = nil
  end
end
local S = C.shot
out("cam", S and (S.mode .. " on " .. S.subject .. string.format(", %.0f s left, frames %d", S.t_end - os.clock(), S.frames or 0)) or ("off (" .. tostring(C.ended) .. ")"),
  "hook", tostring(C.entry), "view blocked", tostring(S and S.blocked), "trigger", S and tostring(S.on_action) .. " fired " .. tostring(S.fired) or "-", "err", tostring(C.err))
