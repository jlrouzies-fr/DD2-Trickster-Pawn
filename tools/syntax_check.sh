#!/bin/bash
# Compile the repository's PawnTrickster.lua inside the running game (it is not executed). Needs the game running.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cp -f "$REPO/reframework/autorun/PawnTrickster.lua" "$DEV/pt_syntax_check.lua"
L "$TOOLS/lua/syntax.lua" | head -1
rm -f "$DEV/pt_syntax_check.lua"
