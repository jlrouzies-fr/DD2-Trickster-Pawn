#!/bin/bash
# From the title screen: Space presses while the title menu is up (the window takes the focus once, for a few seconds), then wait for the in-game phase.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$TOOLS/load_space.ps1")" -GameDir "$(cygpath -w "$DD2_DIR")" -Seconds 20 -PhaseFile "$(cygpath -w "$DEV/phase.txt")" | tail -1
for i in $(seq 1 10); do sleep 5; s=$(bash "$TOOLS/state.sh"); echo "$s" | grep -q "phase	27" && { echo "$s" | cut -c1-60; exit 0; }
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { sleep 6; grep -q " RUNNING " "$WORK/dd2_state.txt" || { echo "GAME GONE during load: $(cut -c1-60 "$WORK/dd2_state.txt")"; exit 1; }; }; done
echo "not in game: $s"; exit 2
