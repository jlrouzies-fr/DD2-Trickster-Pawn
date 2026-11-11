#!/bin/bash
# Launch the game without taking the focus, load the last save, wait until the pawn mod has set the pawn up.
# With DD2_SAVE_DIR and DD2_SAVE_BACKUP set, the backup is copied over the save first (same start for every run).
# env: LOWGPU=1 runs with a low GPU load (lowgpu.sh), NOSAVE=1 skips the save restore, NOPT=1 does not wait for the mod, LOAD_SECONDS (limit of the wait for the title menu, default 150).
# Loading the save needs real Space presses, so the game window takes the focus ONCE, for the seconds the title menu is up.
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
game_running && { echo "DD2 already running"; exit 1; }
if [ -z "$NOSAVE" ] && [ -n "$DD2_SAVE_DIR" ] && [ -n "$DD2_SAVE_BACKUP" ]; then
  cp -f "$DD2_SAVE_BACKUP"/* "$DD2_SAVE_DIR"/ && echo "save restored from $(basename "$DD2_SAVE_BACKUP")"
fi
[ -n "$LOWGPU" ] && bash "$TOOLS/lowgpu.sh" on | tail -1   # LOWGPU=1: DLSS Ultra Performance, 30 FPS (see lowgpu.sh)
bash "$TOOLS/lua.sh" --idle >/dev/null
GD="$(cygpath -w "$DD2_DIR")"
# Space is tapped from the moment REFramework has finished hooking the game window (that also skips the intros, and
# the save is loaded seconds after the title appears). Not earlier: REFramework suspends every game thread while it
# hooks the window. The hook is done when REFramework's log, written by this launch, has a "Resuming" line after
# "WindowsMessageHook": about 10 s after the process starts.
# That hook can deadlock by itself (seen 2026-11-11 13:40 with no key pressed and no window touched: the log ends on
# "Suspending <thread>" lines, the process stays alive, "not responding", 0 % GPU). Then: close the game, launch again.
RLOG="$DD2_DIR/re2_framework_log.txt"; up=0
for attempt in 1 2 3; do
  : > "$WORK/launch.mark"; sleep 1
  powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$TOOLS/launch_bg.ps1")" -GameDir "$GD" -UntilHook | tail -1
  hookt=0
  for i in $(seq 1 360); do
    if [ -f "$RLOG" ] && [ "$RLOG" -nt "$WORK/launch.mark" ]; then
      n=$(grep -a -n "WindowsMessageHook" "$RLOG" | tail -1 | cut -d: -f1)
      if [ -n "$n" ]; then
        if tail -n +"$n" "$RLOG" | grep -a -q "Resuming"; then up=1; break; fi
        [ $hookt -eq 0 ] && hookt=$(date +%s)
        [ $(( $(date +%s) - hookt )) -gt 20 ] && { echo "boot hung in REFramework's window hook (attempt $attempt): closing the game and launching again"; break; }
      fi
    fi
    sleep 0.5
    [ $i -gt 240 ] && ! game_running && { echo "DD2 is not running (launch failed)"; exit 1; }
  done
  [ $up -eq 1 ] && break
  bash "$TOOLS/stop_game.sh" >/dev/null; sleep 3
done
[ $up -eq 1 ] || { echo "REFramework never finished its window hook in three launches"; exit 1; }
sleep 2
# ONE short focus session (the user's rule: the game is fronted once per launch, and for as short as possible): the
# dev console writes the game's flow phase to pt_dev/phase.txt; load_space.ps1 fronts the window only when the title
# menu is up (phase 8), taps Space until the save starts loading (phase 9 or more) and hands the focus back: a few
# seconds. The intros play by themselves. LOAD_SECONDS (default 150) is the limit for the whole wait.
PHF="$DEV/phase.txt"; rm -f "$PHF"
powershell -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$TOOLS/load_space.ps1")" -GameDir "$GD" -Seconds ${LOAD_SECONDS:-150} -PhaseFile "$(cygpath -w "$PHF")" | tail -1
game_running || { echo "DD2 is gone"; exit 1; }
bash "$TOOLS/waitgame.sh" 16 || { echo "the save did not load in the one focus session; the focus is not taken a second time (tools/loadsave.sh would, for 8 s: only on the user's word)"; exit 1; }
[ -n "$LOWGPU" ] && [ -z "$LOWGPU_FPS_JSON" ] && bash "$TOOLS/lua.sh" "$TOOLS/lua/fps30.lua" | head -1
[ -n "$NOPT" ] || bash "$TOOLS/waitpt.sh" 10
