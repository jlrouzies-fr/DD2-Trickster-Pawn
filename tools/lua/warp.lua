_G.__warp_target = { x = 364.22, y = 205.95, z = -2615.97 }
local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer")
local tf = pl:call("get_Transform"); local pp = tf:call("get_UniversalPosition"); local lp = tf:call("get_Position")
local off = { x = pp.x - lp.x, y = pp.y - lp.y, z = pp.z - lp.z }
local T = _G.__warp_target or { x = 333.6, y = 205.7, z = -2503.1 }
local tl = Vector3f.new(T.x - off.x, T.y - off.y, T.z - off.z)
pcall(function() pl:call("warp(via.vec3, app.CharacterWarpOption)", tl, 1) end)
local mp = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = mp:call("get_CachedCharacter")
pcall(function() ch:call("warp(via.vec3, app.CharacterWarpOption)", Vector3f.new(tl.x + 1.5, tl.y, tl.z + 1.5), 1) end)
out("warped to", T.x, T.y, T.z)
