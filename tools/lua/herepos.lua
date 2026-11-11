-- bring the pawn next to the Arisen (same warp call as warp.sh, at her current position)
local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer")
local lp = pl:call("get_Transform"):call("get_Position"); local up = pl:call("get_Transform"):call("get_UniversalPosition")
local mp = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"); local ch = mp and mp:call("get_CachedCharacter")
if ch then pcall(function() ch:call("warp(via.vec3, app.CharacterWarpOption)", Vector3f.new(lp.x + 1.5, lp.y + 0.3, lp.z + 1.5), 1) end) end
out(string.format("arisen %.1f %.1f %.1f", up.x, up.y, up.z), "pawn", tostring(ch ~= nil))
