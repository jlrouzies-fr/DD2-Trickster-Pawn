# Test scripts of the 0.2.8 test day (2026-11-12)

The scripts that drove the tests listed in `docs/NOTES.md` ("0.2.8", second to fourth part). They are here as they
ran that day, with one change: the paths. Helper Lua files are in `lua/`, logs and generated files go to
`tools/work/tests/` (not versioned). **They were not run again after that move**: shell and Lua syntax are checked,
nothing more. Read a script before you run it, and follow `AGENTS.md` (watchdog running, save backed up, never more
than 30 s without looking at the game's state).

All of them expect the game running with the dev console (`tools/install_dev.sh`, `tools/start.sh`) and source
`tools/work/myenv.sh` when it exists (your `export DD2_DIR=...` lines), then `tools/env.sh`.

| Script | What it does | Needs |
|---|---|---|
| `soak.sh` | four fights in a row (goblins, rogues, a mixed group, harpies) with `tools/sample_fight.sh`; one summary line each in `soak.log`, then the problem lines of the mod's log and the casts by kind. `SOAK_SECS` = seconds per fight (190) | the arena of `sample_fight.sh` |
| `soak2f.sh [seconds]` | two fights (harpies, then goblins); also counts Rallies less than 6 s apart | same |
| `ab_spacing.sh [seconds]` | `cast_spacing` 0 against 6 in alternating fights of the same kind (`AB_SPAWN`, `AB_BRING` choose the enemies); sets it back to 6 | same |
| `both.sh [seconds]` | the Arisen and the pawn both cast Trickster skills in one fight: the Arisen is asked for one action every 7 s | run `lua/arisen_job9.lua` first (it makes the Arisen a Trickster: use a test save) |
| `stress.sh` | outside fights: five skill changes 1.5 s apart, a change while the setup runs, every slot emptied, the start set back, four disable / enable cycles; waits for the rules after each | a pawn that has skills 92-99 learned (`lua/sk_set.lua` enables each skill it sets) |
| `setupchange.sh` | a second skill change 5, 9 and 14 s into the setup the first one started | same |
| `start40.sh` | `tools/start.sh` with the low-GPU settings but the frame-rate cap at 40 instead of 30 | `LOWGPU_OFF_FILES`, `LOWGPU_FPS_JSON` as for `tools/lowgpu.sh` |
| `guild_open.sh [sub-menu text]` | from the inn start of the test save (Borderwatch): starts the innkeeper's talk from Lua and picks "Vocation Guild", then the sub-menu ("Acquire/Equip Skills" by default) by its text. The skill screen itself takes real keys (`tools/keys.ps1`: C = the pawn's tab, arrows, F = confirm, Esc = back) | the hire guard installed (the script pauses it); the Arisen at the inn |
| `guild_close.sh` | closes the guild screen, cancels the talk select until no talk is on, switches the inn hooks off and the hire guard back on | after `guild_open.sh` |
| `click.ps1 -X .. -Y .. [-N ..]` | ONE focus session: fronts the game, left-clicks at a client pixel, gives the focus back. For ImGui (REFramework's menu ignores posted mouse messages) | know the pixel: take a screenshot first |
| `insert.ps1` | opens / closes REFramework's menu without the focus (a posted Insert key) | |
| `lua/panel_window.lua` | draws the mod's panel (`PawnTrickster.draw_panel()`) in a window of its own for 150 s, to click its checkbox without walking REFramework's menu tree. The window position in it is for a 3840x2160 screen | REFramework's menu open (`insert.ps1`) |

## What these runs taught (the short list; details in `docs/NOTES.md`)

- **Guild.** Before any key, wait until the talk select shows the inn's own texts (`lua/guild/gq.lua` prints them).
  A rift pawn that walks up takes the talk instead, and the keys then land in its hire / status pages. Never start
  an interaction while `InteractManager.IsPlayerTalking` is true (it hangs the game's logic and every script).
  `lua/guild/t_inn_hook.lua` and `t_inn_cam.lua` hook two checks of the interact system so that the innkeeper can
  be talked to from the start spot; `guild_close.sh` switches them off again.
- **Samplers and cast spacing.** "A cast executing in N of M released samples" cannot compare a build with the
  spacing against one without it (the spacing holds the rules while a cast runs). Count casts.
- **Frame rate.** The reach the mod allows the smoke ball is 6.6 m at 30 FPS and 11.7 m at 40 FPS: numbers about the ball belong to the
  frame rate of the run.
- **A hook keeps the first function it was given.** A test script that registers `re.on_frame` twice under the same
  flag keeps running its first version: give a changed recorder new global names, as `lua/panel_window.lua` does
  (`__ptp2`).
- **Globals.** The dev console runs each command in its own environment: write `_G.name = ...` for anything a later
  command must see.
