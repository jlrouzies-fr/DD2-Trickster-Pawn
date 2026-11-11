#!/bin/bash
# Start the crash-dialog watchdog (run it in the background for the whole session). It writes tools/work/dd2_state.txt
# every 5 s and kills a DD2.exe that sits on a crash dialog. It stops when tools/work/watchdog.run is deleted.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$TOOLS/watchdog.ps1")" -Dir "$(cygpath -w "$WORK")"
