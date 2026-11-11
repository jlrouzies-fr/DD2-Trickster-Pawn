#!/bin/bash
# Remove the development helpers again (the mod itself stays). Do this before you play normally: the guard closes
# every rift pawn's hire dialog.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
rm -f "$DD2_DIR/reframework/autorun/zz_pt_dev_console.lua" "$DD2_DIR/reframework/autorun/zz_pt_hire_guard.lua" "$DEV/hire_pause.flag"
rm -f "$WORK/watchdog.run"
echo "dev console and hire guard removed; watchdog told to stop"
bash "$TOOLS/lowgpu.sh" off | tail -1   # the player's graphics options and add-ons, if a low-GPU run changed them
