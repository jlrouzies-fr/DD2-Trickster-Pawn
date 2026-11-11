#!/bin/bash
# usage: hover.sh x y z seconds    hold the Arisen in the air at a point so a far area streams in, then let it drop.
# Only on the first load of a game session: after a second load a hover left the game on a black screen (phase 31).
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
{ echo "_G.__hover_req = { $1, $2, $3, $4 }"; cat "$TOOLS/lua/hover.lua"; } > "$WORK/hover_go.lua"
L "$WORK/hover_go.lua" | head -1
