#!/bin/bash
# from the inn start spot: start the innkeeper's talk from Lua and walk the talk select to the guild's skill screen.
# $1 = sub-menu text (default "Acquire/Equip Skills"). The hire guard must be paused (it cancels every talk select).
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"; D="$T/guild"   # helper Lua files; logs and generated files go to tools/work/tests
sub="${1:-Acquire/Equip Skills}"
L tools/lua/hire_pause.lua | head -1
L "$D/t_inn_face.lua" | grep "faced\|ch300059" | head -3 | cut -c1-110
L "$D/t_inn_hook.lua" | head -1; L "$D/t_inn_cam.lua" | head -1; sleep 2
L "$D/t_force_hp.lua" | grep "force\|current" | head -2 | cut -c1-120; sleep 2
L "$D/t_inn_chk.lua" | head -3 | cut -c1-120
L "$D/t_inn_active_exec.lua" | head -3 | cut -c1-90; sleep 5
L "$D/gq.lua" | head -1 | cut -c1-230
printf '_G.__pick_text = "Vocation Guild"\n' > "$LOGS/p1.lua"; cat "$D/t_pick_text.lua" >> "$LOGS/p1.lua"; L "$LOGS/p1.lua" | grep pick | cut -c1-80; sleep 6
L "$D/gq.lua" | head -1 | cut -c1-230
printf '_G.__pick_text = "%s"\n' "$sub" > "$LOGS/p2.lua"; cat "$D/t_pick_text.lua" >> "$LOGS/p2.lua"; L "$LOGS/p2.lua" | grep pick | cut -c1-80; sleep 8
L "$D/gq.lua" | head -1 | cut -c1-230
