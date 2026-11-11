PawnTrickster.user_disabled = false
local ok, e = pcall(function() return PawnTrickster.enable() end)
out("enable", tostring(ok), tostring(e))
