local ok, e = pcall(function() return PawnTrickster.destroy_spawns() end)
out("destroy", ok, tostring(e))
