#!/bin/bash
# close the guild screen, cancel the talk select until no talk is on, hooks off, hire guard back on
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"; D="$T/guild"   # helper Lua files; logs and generated files go to tools/work/tests
L "$D/t_guild_close.lua" | head -1 | cut -c1-80; sleep 4
for i in 1 2 3 4; do r=$(L "$D/gq.lua" | head -1); echo "$r" | cut -c1-200; case "$r" in *"IsPlayerTalking	false"*) break;; esac
  printf '_G.__pick_text = "Cancel"\n' > "$LOGS/pc.lua"; cat "$D/t_pick_text.lua" >> "$LOGS/pc.lua"; L "$LOGS/pc.lua" | grep pick | cut -c1-80; sleep 4; done
echo '_G.__force_hp = false; _G.__inn_terrain_skip = false; _G.__inn_cam_skip = false; out("inn hooks off")' > "$LOGS/off.lua"; L "$LOGS/off.lua" | head -1
sleep 5; L tools/lua/hire_unpause.lua | head -1
