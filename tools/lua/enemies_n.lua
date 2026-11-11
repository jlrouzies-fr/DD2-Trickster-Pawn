local n = 0
for _, e in ipairs(PawnTrickster.enemies(true)) do if e.hp > 0 and e.dist >= 0 and e.dist < 60 then n = n + 1 end end
out("alive", n)
