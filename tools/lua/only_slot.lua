-- Hold every slot of the pawn but one, to test or film that action alone (no other skill's effects in the picture).
-- _G.__only = "dust" (or "rally", "summon", "stance", "delusion", "screen", "trick", "regroup"); "" or nil = all back.
local v = _G.__only; _G.__only = nil
PawnTrickster.cfg.only_slot = (v and v ~= "") and v or nil
out("only_slot", tostring(PawnTrickster.cfg.only_slot))
