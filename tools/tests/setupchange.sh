#!/bin/bash
# a skill change made while the mod is setting the pawn up (three timings), then the final state
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
OUT="$LOGS/setupchange.log"; : > "$OUT"; mark=$(grep -c "" "$PTLOG")
say() { echo "$(date +%H:%M:%S) $*" >> "$OUT"; }
skc() { { echo "_G.__sk_id = $1; _G.__sk_slot = $2"; cat "$T/sk_ctx.lua"; } > "$LOGS/sk_tmp.lua"; say "set $1 in slot $2: $(L "$LOGS/sk_tmp.lua" | head -1 | cut -f6-)"; }
q() { say "   $(L "$T/sk_q.lua" | head -1 | cut -c1-200)"; }
waitready() { for i in $(seq 1 16); do r=$(L "$T/sk_q.lua" | head -1); case "$r" in *"enabled true pending false ready true pack true"*) g=$(echo "$r" | sed 's/game slots \[\([0-9,]*\)\].*/\1/'); b=$(echo "$r" | sed 's/.*built for \[\([0-9,]*\)\].*/\1/'); [ "$g" = "$b" ] && { say "   settled: $(echo "$r" | cut -c1-190)"; return 0; };; esac; sleep 4; done; say "   NOT SETTLED after 64 s: $(echo "$r" | cut -c1-190)"; return 1; }
q
for d in 5 9 14; do
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { say "STOP: game not running"; exit 1; }
  say "=== first change, the second one $d s later (the setup is running then)"
  skc 96 3; sleep $d; q; skc 94 2; sleep 3; q; waitready
  skc 92 3; skc 99 2; sleep 10; waitready
done
say "setups: $(tail -n +$((mark+1)) "$PTLOG" | grep -c "=== enable done"), skill-change teardowns: $(tail -n +$((mark+1)) "$PTLOG" | grep -c "skills: the equipped skills changed"), problem lines: $(tail -n +$((mark+1)) "$PTLOG" | grep -c -i "error\|failed\|not found\|missing\|could not")"
tail -n +$((mark+1)) "$PTLOG" | grep -i "error\|failed\|not found\|missing\|could not" | cut -c1-200 | head -6 >> "$OUT"
say "SETUPCHANGE END"
