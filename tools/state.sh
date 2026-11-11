#!/bin/bash
# One line with the REAL state of the game: the watchdog's verdict first (a live DD2.exe can be sitting on a crash
# dialog), then the console's answer: flow phase (8 title, 27 in game, 40 death screen), the mod's state, the guards.
# exit 0 = answered, 1 = the watchdog says the game is not running normally, 2 = the console did not answer
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
w=$(cut -c1-60 "$WORK/dd2_state.txt" 2>/dev/null | tr -d '\r\n')
case "$w" in *RUNNING*) ;; *) echo "WATCHDOG: $w"; tail -1 "$WORK/watchdog.log" 2>/dev/null; exit 1;; esac
r=$(bash "$TOOLS/lua.sh" "$TOOLS/lua/state.lua" | head -1)
echo "$(date +%H:%M:%S) $r"
case "$r" in TIMEOUT*) exit 2;; esac
