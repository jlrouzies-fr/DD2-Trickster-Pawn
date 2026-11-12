#!/bin/bash
# two fights in a row (harpies, then goblins), one summary line each in $LOGS/soak2f.log
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
OUT="$LOGS/soak2f.log"; : > "$OUT"; mark=$(grep -c "" "$PTLOG")
for spec in "harpies:$T/fight_harpies.lua:$TOOLS/lua/bring_any.lua" "goblins:$TOOLS/lua/fight_goblins.lua:$TOOLS/lua/bring.lua"; do
  name=${spec%%:*}; rest=${spec#*:}; sp=${rest%%:*}; br=${rest#*:}
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { echo "STOP: game not running" >> "$OUT"; exit 1; }
  b=$(L "$T/dq.lua" | head -1 | cut -f2,4)
  SPAWN_LUA="$sp" BRING_LUA="$br" bash tools/sample_fight.sh ${1:-200} "$LOGS/s2f_$name.log"
  echo "$(date +%H:%M:%S) $name: $(grep "battle samples" "$LOGS/s2f_$name.log" | head -1 | cut -c1-60) | $(grep "a cast released" "$LOGS/s2f_$name.log" | sed 's/samples (0.5 s each): //; s/, err.*//') | $(grep "^stamina:" "$LOGS/s2f_$name.log" | cut -c9-330) | $(grep "error lines" "$LOGS/s2f_$name.log") | balls and hits $b -> $(L "$T/dq.lua" | head -1 | cut -f2,4) | model $(bash "$T/ap.sh" | tail -1 | sed 's/.*hip apart \([0-9.]*\) m.*/\1 m/')" >> "$OUT"
done
echo "problem lines: $(tail -n +$((mark+1)) "$PTLOG" | grep -c -i "error\|failed\|not found\|missing\|could not")" >> "$OUT"
echo "rally starts less than 6 s apart: $(tail -n +$((mark+1)) "$PTLOG" | grep "action: Job09_CastRageFregrance" | cut -c1-8 | awk -F: '{t=$1*3600+$2*60+$3; if (NR>1 && t-p<6) n++; p=t} END {print n+0, "of", NR}')" >> "$OUT"
echo "S2F END" >> "$OUT"
