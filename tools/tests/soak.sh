#!/bin/bash
# long soak: four fights in a row against different enemies, hired pawn in the party; one summary line each in $LOGS/soak.log
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
OUT="$LOGS/soak.log"; : > "$OUT"; mark=$(grep -c "" "$PTLOG")
i=0
for spec in "goblins:$TOOLS/lua/fight_goblins.lua:$TOOLS/lua/bring.lua" "rogues:$TOOLS/lua/fight_rogues.lua:$TOOLS/lua/bring_any.lua" "mixed:$T/fight_mixed.lua:$TOOLS/lua/bring_any.lua" "harpies:$T/fight_harpies.lua:$TOOLS/lua/bring_any.lua"; do
  i=$((i+1)); name=${spec%%:*}; rest=${spec#*:}; sp=${rest%%:*}; br=${rest#*:}
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { echo "STOP: game not running" >> "$OUT"; exit 1; }
  SPAWN_LUA="$sp" BRING_LUA="$br" bash tools/sample_fight.sh ${SOAK_SECS:-190} "$LOGS/soak_$name.log"
  echo "$(date +%H:%M:%S) $name: $(grep "battle samples" "$LOGS/soak_$name.log" | head -1 | cut -c1-60) | $(grep "a cast released" "$LOGS/soak_$name.log" | sed 's/.*executing \([0-9]*\)).*longest wait \([0-9.]*\) s.*/casting \1 samples, longest wait \2 s/') | $(grep "^hired pawn" "$LOGS/soak_$name.log" | cut -c1-90) | $(grep "error lines" "$LOGS/soak_$name.log") | $(grep "^pawn hp" "$LOGS/soak_$name.log" | cut -f3,4) | model $(bash "$T/ap.sh" | tail -1 | sed 's/.*hip apart \([0-9.]*\) m.*/\1 m/')" >> "$OUT"
done
echo "problem lines in the mod's log over the soak: $(tail -n +$((mark+1)) "$PTLOG" | grep -c -i "error\|failed\|not found\|missing\|could not")" >> "$OUT"
tail -n +$((mark+1)) "$PTLOG" | grep -i "error\|failed\|not found\|missing\|could not" | cut -c1-200 | head -8 >> "$OUT"
echo "casts by kind: $(tail -n +$((mark+1)) "$PTLOG" | grep "action: Job09" | sed 's/.*action: \([A-Za-z0-9_]*\).*/\1/' | sort | uniq -c | tr '\n' ' ')" >> "$OUT"
echo "SOAK END" >> "$OUT"
