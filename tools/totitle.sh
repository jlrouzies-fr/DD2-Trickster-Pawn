#!/bin/bash
# Return to the title screen through the pause menu, without focus, then watch the game for <seconds> (default 25).
# exit 0 = at the title and alive, 1 = game gone or crash dialog, 3 = the title was not reached
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
[ -n "$NOCLEAN" ] || L "$TOOLS/lua/cleanup.lua" >/dev/null
for try in 1 2; do
  L "$TOOLS/lua/menu_open.lua" >/dev/null; sleep 3; L "$TOOLS/lua/menu_title.lua" >/dev/null; sleep 1; L "$TOOLS/lua/menu_end.lua" >/dev/null
  sleep 7; s=$(bash "$TOOLS/state.sh"); echo "$s" | cut -c1-40
  echo "$s" | grep -q "phase	27" || break
  [ $try -eq 2 ] && { echo "TITLE NOT REACHED"; exit 3; }
done
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt ${1:-25} ]; do
  sleep 4
  grep -q " RUNNING " "$WORK/dd2_state.txt" || { sleep 6; grep -q " RUNNING " "$WORK/dd2_state.txt" || { echo "GAME GONE OR CRASH DIALOG after $(( $(date +%s) - t0 )) s: $(cut -c1-70 "$WORK/dd2_state.txt")"; exit 1; }; }
done
echo "$(date +%H:%M:%S) at the title, alive after ${1:-25} s"
