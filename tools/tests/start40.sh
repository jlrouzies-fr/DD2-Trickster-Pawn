#!/bin/bash
# launch like tools/start.sh but capped at 40 FPS (the user's own cap) instead of 30: DLSS Ultra Performance and the
# add-on off as usual, the frame-rate mod's json left at 40. Needs LOWGPU_OFF_FILES / LOWGPU_FPS_JSON from myenv.sh.
T="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; [ -f "$T/../work/myenv.sh" ] && . "$T/../work/myenv.sh"; . "$T/../env.sh"; cd "$REPO"
LOGS="$WORK/tests"; mkdir -p "$LOGS"; T="$T/lua"   # helper Lua files; logs and generated files go to tools/work/tests
bash tools/lowgpu.sh on | tail -1
python - "$DD2_DIR/$LOWGPU_FPS_JSON" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8")); d["fps"] = int(40); json.dump(d, open(p, "w", encoding="utf-8"), indent=4); print("fps json ->", d["fps"])
PY
LOWGPU= bash tools/start.sh
