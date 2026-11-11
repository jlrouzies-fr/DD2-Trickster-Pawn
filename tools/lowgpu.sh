#!/bin/bash
# Test runs with a low GPU load: lowgpu.sh on | off | status
# on  (game closed, before a launch): keeps a copy of the player's config.ini and ReShade.ini, then sets DLSS to Ultra
#     Performance and the frame rate option to 30 in config.ini, and takes the files named in LOWGPU_OFF_FILES (add-ons
#     in the game folder, e.g. a neural-rendering add-on) out of loading by renaming them to <name>.testoff.
# off (game closed, after the last run): puts the two ini files and the renamed files back.
# Option values must be members of the game's own enums (a wrong string crashes the game at boot): UltraPerformance and
# Max30 were read from the running game (SystemOptionUtil.getUpscalingQualitySelection, the FrameRate option's list).
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
B="$WORK/lowgpu"; mode="$1"
case "$mode" in
on)
  game_running && { echo "close the game first"; exit 1; }
  mkdir -p "$B"
  [ -f "$B/config.ini" ] || cp -p "$DD2_DIR/config.ini" "$B/config.ini"
  [ -f "$DD2_DIR/ReShade.ini" ] && { [ -f "$B/ReShade.ini" ] || cp -p "$DD2_DIR/ReShade.ini" "$B/ReShade.ini"; }
  python - "$DD2_DIR/config.ini" <<'PY'
import io, sys, re
p = sys.argv[1]; s = io.open(p, encoding="utf-8", newline="").read()
want = {"DLSS": "UltraPerformance", "UpscalingQuality": "UltraPerformance", "FrameRate": "Max30"}
a = s.index("[AppOption]"); m = re.search(r"\r?\n\[", s[a + 1:]); b = a + 1 + m.start() if m else len(s)
sec = s[a:b]
for k, v in want.items():
    sec, n = re.subn(r"(?m)^(%s=)[^\r\n]*" % re.escape(k), lambda mo: mo.group(1) + v, sec)
    print(k, "->", v, "(%d line)" % n)
io.open(p, "w", encoding="utf-8", newline="").write(s[:a] + sec + s[b:])
PY
  for f in $LOWGPU_OFF_FILES; do [ -f "$DD2_DIR/$f" ] && mv "$DD2_DIR/$f" "$DD2_DIR/$f.testoff" && echo "$f -> $f.testoff"; done
  # a frame-rate mod that holds its own cap overrides the option and any engine call: LOWGPU_FPS_JSON names its json
  # settings file (relative to the game folder); its "fps" value is set to 30 for the test runs
  if [ -n "$LOWGPU_FPS_JSON" ] && [ -f "$DD2_DIR/$LOWGPU_FPS_JSON" ]; then
    [ -f "$B/fps.json" ] || cp -p "$DD2_DIR/$LOWGPU_FPS_JSON" "$B/fps.json"
    python - "$DD2_DIR/$LOWGPU_FPS_JSON" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p, encoding="utf-8")); old = d.get("fps"); d["fps"] = 30
json.dump(d, open(p, "w", encoding="utf-8"), indent=4); print("fps", old, "-> 30 in", p[-34:])
PY
  fi
  echo "low GPU settings on";;
off)
  game_running && { echo "close the game first"; exit 1; }
  [ -f "$B/config.ini" ] && cp -p "$B/config.ini" "$DD2_DIR/config.ini" && rm -f "$B/config.ini" && echo "config.ini restored"
  [ -f "$B/ReShade.ini" ] && cp -p "$B/ReShade.ini" "$DD2_DIR/ReShade.ini" && rm -f "$B/ReShade.ini" && echo "ReShade.ini restored"
  [ -n "$LOWGPU_FPS_JSON" ] && [ -f "$B/fps.json" ] && cp -p "$B/fps.json" "$DD2_DIR/$LOWGPU_FPS_JSON" && rm -f "$B/fps.json" && echo "$LOWGPU_FPS_JSON restored"
  for f in "$DD2_DIR"/*.testoff; do [ -f "$f" ] && mv "$f" "${f%.testoff}" && echo "$(basename "${f%.testoff}") back"; done
  echo "low GPU settings off";;
*)
  [ -f "$B/config.ini" ] && echo "on (the player's config.ini is kept in $B)" || echo "off"
  grep -E "^(DLSS|UpscalingQuality|FrameRate)=" "$DD2_DIR/config.ini"; ls "$DD2_DIR"/*.testoff 2>/dev/null;;
esac
