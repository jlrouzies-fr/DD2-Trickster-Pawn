#!/bin/bash
# usage: warp.sh x y z    universal coordinates; the Arisen is put there, the main pawn 1.5 m aside.
# A warp of a few hundred metres rebuilds the pawn (the mod sets it up again, about 20 s).
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
{ echo "_G.__warp_target = { x = $1, y = $2, z = $3 }"; tail -n +2 "$TOOLS/lua/warp.lua"; } > "$WORK/warp_go.lua"
L "$WORK/warp_go.lua" | tail -2 | head -1
