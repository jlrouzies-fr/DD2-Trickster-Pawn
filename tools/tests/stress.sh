#!/bin/bash
# stress of 0.2.8 outside fights: skill changes in quick succession, a change while the setup is running, every slot
# emptied, disable / enable cycles. One line per step in $LOGS/stress.log; stops when the game is not running normally.
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
OUT="$LOGS/stress.log"; : > "$OUT"
say() { echo "$(date +%H:%M:%S) $*" >> "$OUT"; }
alive() { grep -q " RUNNING " "$WORK/dd2_state.txt" || { say "STOP: game not running"; exit 1; }; }
sk() { { echo "_G.__sk_id = $1; _G.__sk_slot = $2"; cat "$T/sk_set.lua"; } > "$LOGS/sk_tmp.lua"; say "set skill $1 in slot $2: $(L "$LOGS/sk_tmp.lua" | head -1 | cut -f9-)"; }
st() { say "   $(L "$T/sk.lua" | head -1 | cut -c1-200)"; }
waitready() { for i in $(seq 1 14); do alive; r=$(L "$T/sk.lua" | head -1); case "$r" in *"ready true"*"cand nil"*) case "$r" in "built for [nil]"*) ;; *) say "   ready: $(echo "$r" | cut -c1-150)"; return 0;; esac;; esac; sleep 4; done; say "   NOT READY after 56 s: $(echo "$r" | cut -c1-150)"; return 1; }
mark=$(grep -c "" "$PTLOG")
say "=== A: five skill changes 1.5 s apart"; st
sk 96 3; sleep 1.5; sk 92 3; sleep 1.5; sk 96 3; sleep 1.5; sk 93 2; sleep 1.5; sk 94 1; st
sleep 9; waitready
say "=== B: a change while the setup is running"; sk 92 3; sleep 6; st; sk 99 2; sleep 2; st; sleep 9; waitready
say "=== C: every slot emptied (no setup expected), then one skill back"; sk 0 0; sk 0 1; sk 0 2; sk 0 3; sleep 9; st; sk 97 0; sleep 9; waitready
say "=== D: the start set back"; sk 95 1; sk 99 2; sk 92 3; sleep 9; waitready
say "=== E: disable / enable four times, 7 s apart"
for i in 1 2 3 4; do alive; L "$TOOLS/lua/disable.lua" >/dev/null; sleep 3; L "$TOOLS/lua/enable.lua" >/dev/null; sleep 4; done; sleep 10; waitready
say "setups in the mod's log: $(tail -n +$((mark+1)) "$PTLOG" | grep -c "=== enable done"), skill-change teardowns: $(tail -n +$((mark+1)) "$PTLOG" | grep -c "skills: the equipped skills changed"), problem lines: $(tail -n +$((mark+1)) "$PTLOG" | grep -c -i "error\|failed\|not found\|missing\|could not")"
tail -n +$((mark+1)) "$PTLOG" | grep -i "error\|failed\|not found\|missing\|could not\|skills: the equipped" | cut -c1-170 >> "$OUT"
say "STRESS END"
