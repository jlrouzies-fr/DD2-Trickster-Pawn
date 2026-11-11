#!/bin/bash
# usage: sample_fight.sh <seconds> <log> [nowarp]
# A fight against waves of three spawned goblins (or what SPAWN_LUA spawns) (needs Skill Maker's NickCore spawner, see AGENTS.md) at the spot in
# ARENA="x y z" (default: outside Borderwatch), with the samplers reset at the start and their result at the end.
# The Arisen cannot die during it, the pawn is revived when it goes down (never left dead: a dead pawn disappears).
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
LOG="$2"; : > "$LOG"; A=(${ARENA:-364.22 205.95 -2615.97})
mark=$(grep -c "" "$PTLOG" 2>/dev/null || echo 0)
SPAWN="${SPAWN_LUA:-$TOOLS/lua/fight_goblins.lua}"   # SPAWN_LUA=tools/lua/fight_rogues.lua for human-sized enemies
BRING="${BRING_LUA:-$TOOLS/lua/bring.lua}"       # bring.lua only moves enemies under 1000 HP; BRING_LUA=tools/lua/bring_any.lua for the others
for f in diag execsample p2sample stamwatch rallywhy; do L "$TOOLS/lua/$f.lua" >/dev/null; done
L "$TOOLS/lua/safe.lua" >/dev/null
if [ -z "$3" ]; then L "$TOOLS/lua/cleanup.lua" >/dev/null; bash "$TOOLS/warp.sh" ${A[0]} ${A[1]} ${A[2]} >> "$LOG"; sleep 6; fi
L "$SPAWN" >/dev/null; sleep 9; L "$BRING" >/dev/null; sleep 3
for f in diag execsample p2sample stamwatch rallywhy; do { echo "_G.__${f}_reset = true"; cat "$TOOLS/lua/$f.lua"; } > "$WORK/${f}_reset.lua"; L "$WORK/${f}_reset.lua" >/dev/null; done
t0=$(date +%s); k=0; idle=0
while [ $(( $(date +%s) - t0 )) -lt $1 ]; do
  sleep 5; L "$TOOLS/lua/safe.lua" >/dev/null; L "$TOOLS/lua/heal.lua" >/dev/null; L "$TOOLS/lua/revive.lua" >/dev/null
  s=$(bash "$TOOLS/state.sh"); rc=$?; echo "$s" | cut -c1-110 >> "$LOG"
  [ $rc -ne 0 ] && { sleep 6; grep -q " RUNNING " "$WORK/dd2_state.txt" || { echo "STOP: $(cut -c1-60 "$WORK/dd2_state.txt")" >> "$LOG"; exit 1; }; }
  k=$((k+1)); echo "$s" | grep -q "battle	2" && idle=0 || idle=$((idle+1))
  if [ $((k % 3)) -eq 0 ] || [ $idle -ge 2 ]; then n=$(L "$TOOLS/lua/enemies_n.lua" | head -1 | cut -f2)
    if [ "${n:-0}" -lt 2 ] 2>/dev/null; then idle=0; L "$TOOLS/lua/cleanup.lua" >/dev/null; L "$SPAWN" >/dev/null; sleep 8; L "$BRING" >/dev/null; echo "wave (alive was $n)" >> "$LOG"
    else L "$BRING" >/dev/null; fi; fi
done
echo "== RESULT $(date +%H:%M:%S)" >> "$LOG"
L "$TOOLS/lua/execsample.lua" | grep -v "^\[seq" | cut -c1-1500 >> "$LOG"
L "$TOOLS/lua/p2sample.lua" | grep -v "^\[seq" | cut -c1-900 >> "$LOG"
L "$TOOLS/lua/diag.lua" | grep -v "^ROWS\|^TFAIL\|^\[seq" | cut -c1-600 >> "$LOG"
L "$TOOLS/lua/stamwatch.lua" | head -1 | cut -c1-900 >> "$LOG"
L "$TOOLS/lua/rallywhy.lua" | grep -v "^\[seq" | head -6 | cut -c1-200 >> "$LOG"
L "$TOOLS/lua/revive.lua" | head -1 >> "$LOG"
echo "error lines in the mod's log during this fight: $(tail -n +$((mark + 1)) "$PTLOG" | grep -ci "error")" >> "$LOG"
echo "FIGHT END" >> "$LOG"
