#!/bin/bash
# wait until the flow phase is InGame (27); usage: waitgame.sh [tries of 6 s]
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
for i in $(seq 1 ${1:-14}); do r=$(bash "$TOOLS/lua.sh" "$TOOLS/lua/phase.lua" | head -1); echo "$r" | grep -q "phase	27" && { echo "$(date +%H:%M:%S) in game: $r" | cut -c1-90; exit 0; }
  game_running || { echo "DD2 GONE while waiting"; exit 1; }; sleep 6; done
echo "not in game: $r"; exit 2
