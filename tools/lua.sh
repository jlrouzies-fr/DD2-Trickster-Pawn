#!/bin/bash
# usage: lua.sh <file.lua>      run a Lua file inside the running game through the dev console, print its out() lines
#        lua.sh --idle          leave an idle command behind (the console replays the last command at every game start)
# The last output line is "[seq N] ok <result>" or "[seq N] ERR <message>"; "TIMEOUT seq N" means no answer in 12 s.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
n=$(( $(cat "$WORK/seq" 2>/dev/null || echo 1000) + 1 )); echo $n > "$WORK/seq"
if [ "$1" = "--idle" ]; then printf -- "-- seq %s\n-- (idle)\n" $n > "$DEV/cmd.lua"; echo "idle command written"; exit 0; fi
{ echo "-- seq $n"; cat "$1"; } > "$DEV/cmd.tmp"; mv -f "$DEV/cmd.tmp" "$DEV/cmd.lua"
for i in $(seq 1 24); do grep -q "^\[seq $n\]" "$DEV/out.txt" 2>/dev/null && { cat "$DEV/out.txt"; exit 0; }; sleep 0.5; done
echo "TIMEOUT seq $n"; exit 2
