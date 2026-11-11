-- compile (not run) reframework/data/pt_dev/pt_syntax_check.lua with the game's own Lua: catches syntax errors and
-- the 200-locals limit before a relaunch
local f = io.open("pt_dev/pt_syntax_check.lua", "r"); if not f then out("no file") return end
local src = f:read("a"); f:close(); local ch, e = load(src, "PawnTrickster"); out("bytes", #src, "syntax ok", tostring(ch ~= nil), tostring(e))
