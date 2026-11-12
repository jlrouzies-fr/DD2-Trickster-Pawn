-- read only: is the main pawn's model where the pawn is? Prints the pawn's root and how far its hip joint is from it
-- (horizontally), read now (console time: before the late update) and once more inside re.on_frame (while the scene
-- is locked for rendering: there the joints are the copy the renderer draws). The second line goes to
-- reframework/data/pt_dev/modelcheck.txt a frame later. More than about 0.5 m apart at frame time, after the pawn
-- has moved, means the model is detached from the pawn (see AGENTS.md, section 5). At console time the two always
-- agree, so the first line alone proves nothing.
local function row()
  local ch = sdk.get_managed_singleton("app.PawnManager"):get_field("_MainPawn"):call("get_CachedCharacter")
  local p = ch:call("get_Transform"):call("get_Position"); local q = ch:call("get_HipJoint"):call("get_Position")
  return string.format("pawn (%.1f %.1f %.1f) hip %.2f m from the root", p.x, p.y, p.z, math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2))
end
_G.__mc = { want = true }; _G.__mc_row = row
if not _G.__mc_hooked then
  _G.__mc_hooked = true
  re.on_frame(function()
    local T = _G.__mc
    if T and T.want then
      T.want = false
      local ok, r = pcall(_G.__mc_row)
      local f = io.open("pt_dev/modelcheck.txt", "w")
      if f then f:write("frame time:   " .. tostring(r)); f:close() end
    end
  end)
end
out("console time: " .. row())
