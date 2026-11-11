#!/bin/bash
# wait until PawnTrickster reports enabled and its rules are added; usage: waitpt.sh [tries of 6 s]
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
for i in $(seq 1 ${1:-16}); do r=$(bash "$TOOLS/lua.sh" "$TOOLS/lua/ptready.lua" | head -1); echo "$r" | grep -q "pack	true" && { echo "$(date +%H:%M:%S) $r"; exit 0; }
  game_running || { echo "DD2 GONE while waiting"; exit 1; }; sleep 6; done
echo "not ready: $r"; exit 2
