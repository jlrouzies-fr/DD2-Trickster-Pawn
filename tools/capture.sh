#!/bin/bash
# Film a character's action for whoever asked for it: a camera on the main pawn (or the Arisen), a burst capture of the
# game window (no focus needed, the window may be covered) and an animated GIF plus a contact sheet as the result.
#
# usage: capture.sh <name> [options]            -> tools/work/captures/<name>.gif and <name>_sheet.jpg
#   --on-action TEXT   start when the subject begins an action whose name contains TEXT (e.g. Job09_ShortSmokeAttack);
#                      keeps --pre seconds before it (default 1) and --post after it (default 4); gives up after --wait (90)
#   --lua FILE         or: run this Lua file in the game once the capture runs (it starts the action); the film goes
#                      from a little before it to --seconds (6) after it
#   (neither: film --seconds from now)
#   --mode follow      the camera stands a little behind and above the subject and looks the way it faces (default);
#                      --dist 4.5 metres away, --height 2 above its feet, --yaw 20 degrees around it (0 behind, 180 in front)
#   --mode side        the camera stands beside the line from the subject to the enemy nearest to it: both in frame
#                      (--side 0|1|-1; 0 = the side the Arisen is not on)
#   --subject pawn|arisen   --fov N
#   --fps 10   --width 480
#   --nocam            leave the game's camera alone
#   --cam-early        with --on-action: put the camera on the subject while waiting, not only from the action's start
#                      (the default waits: with the camera on the pawn the awaited swing came far less often)
# The game's camera is only overwritten while the capture runs and comes back by itself (tools/lua/cam.lua).
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
name="$1"; shift
[ -n "$name" ] || { sed -n 2,16p "${BASH_SOURCE[0]}"; exit 1; }
seconds=6; fps=10; width=480; mode=follow; subject=pawn; dist=4.5; height=2; yaw=20; side=0; fov=nil
onact=""; lua=""; pre=1; post=4; wait=90; nocam=""; late=true
while [ $# -gt 0 ]; do case "$1" in
  --seconds) seconds="$2"; shift;; --fps) fps="$2"; shift;; --width) width="$2"; shift;; --mode) mode="$2"; shift;;
  --subject) subject="$2"; shift;; --dist) dist="$2"; shift;; --height) height="$2"; shift;; --yaw) yaw="$2"; shift;;
  --side) side="$2"; shift;; --fov) fov="$2"; shift;; --on-action) onact="$2"; shift;; --lua) lua="$2"; shift;;
  --pre) pre="$2"; shift;; --post) post="$2"; shift;; --wait) wait="$2"; shift;; --nocam) nocam=1;; --cam-early) late=false;;
  *) echo "unknown option $1"; exit 1;; esac; shift; done
game_running || { echo "DD2 is not running"; exit 1; }
OUT="$WORK/captures"; mkdir -p "$OUT"; gif="$OUT/$name.gif"; rm -f "$gif" "$OUT/${name}_sheet.jpg"
TRIG="$DEV/cap_trigger.txt"
camreq() { # $1 = seconds the camera may stay, $2 = action text or empty
  local a="nil"; [ -n "$2" ] && a="\"$2\""; local nc=false; [ -n "$nocam" ] && nc=true
  { echo "_G.__cam_req = { mode = \"$mode\", subject = \"$subject\", dist = $dist, height = $height, yaw = $yaw, side = $side, fov = $fov, seconds = $1, on_action = $a, nocam = $nc, late = $late }"
    cat "$TOOLS/lua/cam.lua"; } > "$WORK/cam_go.lua"
  # (another helper writing a console command at the same moment loses or mangles this one: try again)
  local r; for try in 1 2 3 4; do r=$(L "$WORK/cam_go.lua" | head -1 | cut -c1-200); case "$r" in cam*) break;; esac; sleep 1; done
  echo "$r"; case "$r" in cam*) return 0;; esac; return 1
}
PS=(powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$TOOLS/capture.ps1")" -Out "$(cygpath -w "$gif")" -Fps "$fps" -Width "$width")
if [ -n "$onact" ]; then
  "${PS[@]}" -TriggerFile "$(cygpath -w "$TRIG")" -PreRoll "$pre" -PostRoll "$post" -MaxWait "$wait" > "$WORK/capture.out" 2>&1 &
  pid=$!; sleep 4                               # (the capture is running before the trigger is armed)
  camreq $(awk "BEGIN { print int($wait + $post + 5.5) }") "$onact"
  wait $pid
elif [ -n "$lua" ]; then
  # the capture runs in a ring; the Lua file is run once it is up, and the film is kept from --pre seconds before the
  # file's answer came back (the console answers up to a second after the action started) to --seconds after it
  LT="$WORK/lua_trigger.txt"; rm -f "$LT"
  [ -z "$nocam" ] && camreq $(awk "BEGIN { print int($seconds + 14.5) }") ""
  "${PS[@]}" -TriggerFile "$(cygpath -w "$LT")" -PreRoll $(awk "BEGIN { print $pre + 1.5 }") -PostRoll "$seconds" -MaxWait 30 > "$WORK/capture.out" 2>&1 &
  pid=$!; sleep 4
  L "$lua" | head -1 | cut -c1-160; date > "$LT"
  wait $pid
else
  [ -z "$nocam" ] && camreq $(awk "BEGIN { print int($seconds + 8.5) }") ""
  "${PS[@]}" -Seconds "$seconds" > "$WORK/capture.out" 2>&1 &
  pid=$!; wait $pid
fi
echo "_G.__cam_req = { off = true }" > "$WORK/cam_go.lua"; cat "$TOOLS/lua/cam.lua" >> "$WORK/cam_go.lua"; L "$WORK/cam_go.lua" >/dev/null
tail -1 "$WORK/capture.out"
[ -f "$gif" ] && echo "$gif" || { echo "no GIF was written"; exit 1; }
