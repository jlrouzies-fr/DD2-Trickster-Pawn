#!/bin/bash
# the Arisen (made a Trickster) and the pawn both cast Trickster skills in one fight: the Arisen is asked for an action
# every 7 s for $1 seconds (default 150) while goblin waves run; samplers of sample_fight.sh for the pawn
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
OUT="$LOGS/both.log"; : > "$OUT"; mark=$(grep -c "" "$PTLOG")
say() { echo "$(date +%H:%M:%S) $*" >> "$OUT"; }
bash tools/sample_fight.sh ${1:-150} "$LOGS/both_fight.log" &
fp=$!; sleep 30
i=0; acts=(Job09_SummonDecoy Job09_CastRageFregrance Job09_Transfer Job09_CastAttentionFregrance Job09_CastSmokeWall Job09_ThrowSmoke Job09_CastSmokeDragon)
while kill -0 $fp 2>/dev/null; do
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { say "STOP: game not running"; break; }
  a=${acts[$((i % ${#acts[@]}))]}; i=$((i+1))
  { echo "_G.__ac = \"$a\""; cat "$T/arisen_cast.lua"; } > "$LOGS/ac_tmp.lua"; r=$(L "$LOGS/ac_tmp.lua" | head -1 | cut -c1-70); sleep 2.5
  say "$r | $(L "$T/arisen_q.lua" | head -1 | cut -c1-150)"; sleep 4
done
wait $fp
say "the pawn's casts: $(tail -n +$((mark+1)) "$PTLOG" | grep "action: Job09" | sed 's/.*action: \([A-Za-z0-9_]*\).*/\1/' | sort | uniq -c | tr '\n' ' ')"
say "problem lines: $(tail -n +$((mark+1)) "$PTLOG" | grep -c -i "error\|failed\|not found\|missing\|could not") | $(grep "battle samples" "$LOGS/both_fight.log" | head -1 | cut -c1-60) | $(grep "a cast released" "$LOGS/both_fight.log" | cut -c1-120) | $(grep "^stamina:" "$LOGS/both_fight.log" | sed 's/ | rally.*//' | cut -c1-130) | model $(bash "$T/ap.sh" | tail -1 | sed 's/.*hip apart \([0-9.]*\) m.*/\1 m/')"
tail -n +$((mark+1)) "$PTLOG" | grep -i "error\|failed\|not found\|missing\|could not\|decoy:" | cut -c1-180 | head -10 >> "$OUT"
say "BOTH END"
