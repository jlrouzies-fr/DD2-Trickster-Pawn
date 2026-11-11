#!/bin/bash
# Close the game the only way that never hangs on a dialog, and wait until the process is really gone.
powershell -NoProfile -Command "Stop-Process -Name DD2 -Force -ErrorAction SilentlyContinue"
for i in $(seq 1 15); do tasklist //FI "IMAGENAME eq DD2.exe" 2>/dev/null | grep -q DD2 || { echo "DD2 closed"; exit 0; }; sleep 2; done
echo "DD2 still running"; exit 1
