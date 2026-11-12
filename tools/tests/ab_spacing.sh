#!/bin/bash
# cast_spacing 0 against 6, alternating fights of the same kind; one line each in $LOGS/ab_spacing.log
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
OUT="$LOGS/ab_spacing.log"; : > "$OUT"
for v in 0 6 0 6; do
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { echo "STOP: game not running" >> "$OUT"; exit 1; }
  echo "PawnTrickster.cfg.cast_spacing = $v; out('cast_spacing', PawnTrickster.cfg.cast_spacing)" > "$LOGS/ab_set.lua"; L "$LOGS/ab_set.lua" >/dev/null
  mark=$(grep -c "" "$PTLOG")
  SPAWN_LUA="${AB_SPAWN:-$TOOLS/lua/fight_goblins.lua}" BRING_LUA="${AB_BRING:-$TOOLS/lua/bring.lua}" bash tools/sample_fight.sh ${1:-170} "$LOGS/abs_$v.log"
  echo "$(date +%H:%M:%S) spacing $v: $(grep "battle samples" "$LOGS/abs_$v.log" | head -1 | cut -c1-19) | $(grep "a cast released" "$LOGS/abs_$v.log" | sed 's/samples (0.5 s each): //; s/, none.*//') | $(grep "^stamina:" "$LOGS/abs_$v.log" | sed 's/stamina: [0-9]* samples, //; s/ | delusion.*//' | cut -c1-200) | casts $(tail -n +$((mark+1)) "$PTLOG" | grep "action: Job09" | grep -v End | sed 's/.*action: Job09_\([A-Za-z]*\).*/\1/' | sort | uniq -c | tr -s ' ' | tr '\n' ',')" >> "$OUT"
done
echo "PawnTrickster.cfg.cast_spacing = 6; out('cast_spacing', PawnTrickster.cfg.cast_spacing)" > "$LOGS/ab_set.lua"; L "$LOGS/ab_set.lua" >/dev/null
echo "ABS END" >> "$OUT"
