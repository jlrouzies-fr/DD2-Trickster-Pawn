#!/bin/bash
# Copy the repository's script and readme into the game, and add the two development helpers to reframework/autorun:
# the dev console and the guard that closes rift-pawn hire dialogs and tutorial windows during unattended runs.
# The game must be closed (scripts are read at start).
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
game_running && { echo "close the game first"; exit 1; }
mkdir -p "$DD2_DIR/reframework/autorun" "$DD2_DIR/reframework/data/PawnTrickster"
cp -f "$REPO/reframework/autorun/PawnTrickster.lua" "$DD2_DIR/reframework/autorun/PawnTrickster.lua"
cp -f "$REPO/reframework/data/PawnTrickster/README.txt" "$DD2_DIR/reframework/data/PawnTrickster/README.txt"
cp -f "$TOOLS/autorun/zz_pt_dev_console.lua" "$TOOLS/autorun/zz_pt_hire_guard.lua" "$DD2_DIR/reframework/autorun/"
bash "$TOOLS/lua.sh" --idle
echo "installed: PawnTrickster.lua, README.txt, dev console, hire guard"
