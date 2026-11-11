# AGENTS.md

Instructions for an AI agent (or a person working like one) that debugs or improves this mod on its own: launch the
game, reproduce a problem, find its cause in the running game, fix the script, prove the fix, and leave the machine
as it was. Everything here was learned the hard way over about seventy in-game runs; the history is in
`docs/DEVELOPMENT.md` and `docs/NOTES.md`.

The mod is one file: `reframework/autorun/PawnTrickster.lua` (REFramework Lua, Dragon's Dogma 2). It makes the
player's main pawn a Trickster (vocation `Job09`, Arisen-only in the vanilla game) and gives it combat rules.

## 1. Rules that are not negotiable

1. **The save is not yours.** Copy the player's save folder before the first launch and put that copy back when you
   finish (`DD2_SAVE_DIR`, `DD2_SAVE_BACKUP`, see section 3). The mod changes the pawn's vocation, skills and weapon in
   the save; tests kill characters and hire or dismiss pawns.
2. **Never leave the game stuck, and never be blind for more than 30 seconds.** A live `DD2.exe` can be sitting on a
   crash dialog, a rift pawn's hire window, a tutorial window or the death screen. Run the watchdog for the whole
   session, install the guard, and read `tools/state.sh` at least every 30 seconds while the game runs. A background
   loop must check the state itself and stop when the game is gone.
3. **Prove it in the game.** A fix is done when the same situation that failed now works, measured the same way, and
   the regression list of section 8 has been run on the final build. "It should work" is not a result. If you could
   not test a path, say so in the notes and in the release text.
4. **Name the cause before you change code.** Section 6 gives the method that names the exact condition that refuses
   a rule. Two release notes of this mod blamed the wrong thing because a correlation was written down as a cause.
5. **Probes read; they do not poke.** List type, field and method names first. Call a method only when its name and
   signature tell you what it does, one deliberate call at a time, never in a loop over "everything that looks
   interesting". Section 5 lists calls that crashed or froze the game.
6. **Leave no trace.** At the end: game closed, save restored, the player's `config.json` and `pawns.json` restored,
   dev console and guard removed (`tools/uninstall_dev.sh`), an idle console command left behind.
7. **Report what happened.** Failed runs, a pawn that died and spoiled a sample, a number you misread: write them
   down. Counts beat adjectives ("0 casts in 56 s", not "barely casts").
8. **Take the keyboard focus once per launch, for a second or two.** Everything runs through the console without
   focus except the Space presses that load a save: `start.sh` fronts the game only when the title menu is up, taps
   Space until the save starts loading and hands the focus back (measured: 1.5 s, 4 taps). The player of this
   machine was interrupted for 40 to 65 s per launch by an earlier version that tapped through the whole boot, and
   said so three times. Do not add a second focus session to a run (the death screen and `loadsave.sh` need one:
   set the Arisen's no-die flag before a fight, and leave the title leg out of a regression unless the player
   agreed). Never minimize the game window (a swapchain resize crashed a graphics mod).
9. **The machine is not yours either.** A modded game can draw the whole GPU (414 W on the author's machine) while the
   player does something else. Ask how test runs should be configured, or use `LOWGPU=1` (section 3), and say in your
   notes at which frame rate you measured: several things in this game depend on it (section 5).

## 2. What you need

- Dragon's Dogma 2 with REFramework. Windows, Git Bash, PowerShell 5, Python 3 for the release script.
- For the fight helpers: the mod "Skill Maker" (its `_NickCore/EnemySpawner.lua` is what
  `PawnTrickster.spawn_enemies` drives). Without it you can still fight world enemies (`bring.lua` brings loaded ones
  next to the party).
- A save standing somewhere quiet with enemies not far away. The default test spot of the tools is outside the
  Borderwatch Outpost camp, universal position `364.2 205.5 -2616.0` (`ARENA` overrides it).

## 3. Setup

```bash
export DD2_DIR="E:/SteamLibrary/steamapps/common/Dragons Dogma 2"      # the folder with DD2.exe
export DD2_SAVE_DIR="C:/Program Files (x86)/Steam/userdata/<id>/2054970/remote/win64_save"
export DD2_SAVE_BACKUP="C:/somewhere/dd2_save_backup"                    # your copy of that folder
bash tools/install_dev.sh        # game closed: copies the script, the dev console and the guard into the game
bash tools/watchdog.sh &         # background, whole session: tools/work/dd2_state.txt every 5 s
bash tools/start.sh              # restore the save, launch without focus, load the save, wait for the mod
bash tools/state.sh              # one line: flow phase, mod state, guard counters
```

- `tools/lua.sh file.lua` runs a Lua file inside the game through the dev console
  (`tools/autorun/zz_pt_dev_console.lua`: it executes `reframework/data/pt_dev/cmd.lua` when its `-- seq N` line
  changes and writes `out.txt`). `out(...)` prints a line. The last line is `[seq N] ok ...` or `[seq N] ERR ...`.
- The console **runs the last command again at every game start**. A probe that crashes the game crashes every
  launch after it. `tools/start.sh` writes an idle command first; do the same by hand (`tools/lua.sh --idle`) before
  any launch you do yourself.
- Two writers at the same moment lose a command (`TIMEOUT`). A background loop and your own commands share the
  console: retry once (the `L` helper in `tools/env.sh` does).
- `export LOWGPU=1` makes `start.sh` run `tools/lowgpu.sh on` first: DLSS Ultra Performance and the 30 FPS option in
  `config.ini` (the player's file is kept and put back by `lowgpu.sh off`, which `uninstall_dev.sh` runs).
  `LOWGPU_OFF_FILES="some.addon64"` takes add-ons in the game folder out of loading for the runs (renamed to
  `.testoff`); `LOWGPU_FPS_JSON="reframework/data/<mod>/config.json"` sets `"fps": 30` in the settings of a frame-rate
  mod that holds its own cap (such a mod undoes `via.Application.set_MaxFps` within a second; without one,
  `lua/fps30.lua` holds the cap). Option strings must be members of the game's enums: read them from the game
  (`SystemOptionUtil.getUpscalingQualitySelection`), never guess.
- Scripts are read at game start. After editing `PawnTrickster.lua`: `tools/syntax_check.sh` (compiles it inside the
  running game, catches syntax errors and Lua's 200-locals limit, which this file is close to), then close the game,
  `install_dev.sh`, `start.sh`. Do not use REFramework's "reset scripts".
- **`config.json` remembers everything.** The script writes every setting to
  `reframework/data/PawnTrickster/config.json` at each start and reads it back over its defaults at the next one. A
  default you change in the script does not take effect on a machine that already wrote the old value, unless
  `config.defaults.json` (written next to it since 0.2.5) shows the old value was itself a default. Two fights were
  once reported as a test of a new setting that the game was not using. After changing a default, read the live
  value before measuring: `out(PawnTrickster.cfg.rally_cooldown)`. To compare settings without relaunching, use
  `lua/variant.lua` (it sets values in the running game and rebuilds the pawn's rules).
- The mod's own log is `reframework/data/PawnTrickster/log.txt` (`"log": true` in its `config.json`). It is appended
  across sessions: remember the line count before a test and read from there.

## 4. Driving the game without a person

| Need | Tool |
|---|---|
| Real state | `tools/state.sh`: phase 8 title, 24 setup, 27 in game, 31 a broken resume (black screen), 40 death screen, 44-46 unloading |
| Go somewhere | `tools/warp.sh x y z` (universal coordinates). A warp of a few hundred metres rebuilds the pawn; the mod sets it up again in about 20 s |
| Far area | `tools/hover.sh x y z 12`, then warp. Only on the first load of a session: after a second load it left phase 31 |
| A fight | `tools/sample_fight.sh 150 log.txt` (goblin waves, samplers, keep-alive, revive). `SPAWN_LUA=tools/lua/fight_rogues.lua BRING_LUA=tools/lua/bring_any.lua` for human-sized enemies (2500 HP: a fight lasts minutes) |
| Enemies | `lua/fight_goblins.lua`, `lua/bring.lua`, `lua/enemies.lua`, `lua/cleanup.lua`, `lua/phantoms.lua` |
| Keep the Arisen alive | `lua/safe.lua` (no-die flag, gone at the next load) and `lua/heal.lua`; `lua/revive.lua` revives the pawn only when it is down |
| Kill the Arisen | `lua/nodie_off.lua`, then `lua/hp1.lua` every few seconds next to an enemy: the next real hit kills. `setHp(0)` does nothing |
| Death screen | real Space presses (`load_space.ps1 -Seconds 3`) pick "Load from Autosave": a second focus session. Do not get there: `lua/safe.lua` before any fight in which the pawn's skills are held or the party is weak |
| One action alone | `{ echo '_G.__only = "dust"'; cat tools/lua/only_slot.lua; } > x.lua; tools/lua.sh x.lua` holds every slot of the pawn but that one (`""` gives them back): the only way to film or measure one action's effects without the other skills' smoke in the picture |
| A still target | spawn one enemy, then `{ echo '_G.__dummy = { dist = 5.5, arisen_back = 3 }'; cat tools/lua/dummy.lua; } > x.lua; tools/lua.sh x.lua`: the enemy nearest to the Arisen becomes a statue (its GameObject stops updating), the pawn is put 5.5 m from it and the Arisen behind the pawn. A statue is not hit: let it go around the impact (`{ off = true }`), and before `cleanup.lua` |
| A cast on demand | `PawnTrickster.dust_test()` plays the dust swing now, whatever the gates say; `PawnTrickster.request("<action name>")` plays any action |
| Frame by frame | `powershell -File tools/gifsheet.ps1 -In clip.gif -Out sheet.jpg -From 16 -To 35 -Crop "x,y,w,h" -Zoom 1.4`: every frame of a stretch of a capture's GIF on one sheet |
| What an effect is | `lua/efxtime.lua`: every effect the game creates in the 5 s after the pawn starts an action (time, object, parent, distance from the pawn) |
| Title and back | `tools/totitle.sh 30`, `tools/loadsave.sh` |
| Hire a pawn | a rift pawn's dialog opens from the Space presses of a load when one stands at the start point; `lua/hire_pause.lua` (or the file `pt_dev/hire_pause.flag` before launch) stops the guard, `lua/hire_accept.lua` picks "Hire", `lua/dismiss.lua` dismisses. Otherwise ask the player to hire one and save |
| Party | `lua/pawns.lua` |
| Try a setting | `{ echo "_G.__variant = { rally_cooldown = 8 }"; cat tools/lua/variant.lua; } > x.lua; tools/lua.sh x.lua`, then `tools/waitpt.sh` |
| Test skills | the same with `debug = true, skills = { 96, 97, 99, 92 }` (the save is changed: restore it afterwards) |
| Show a result | `tools/capture.sh name --on-action Job09_ShortSmokeAttack` films the pawn from behind when it starts that action and writes `tools/work/captures/name.gif` (for the person who asked) and `name_sheet.jpg` (twelve frames with their times, for you). See "Showing what you built" below |
| Stop | `tools/stop_game.sh` (never quit through menus) |

**Showing what you built.** Counters say that a thing happened, not what it looks like. When the work is something
a player sees (a new attack, a projectile, an effect), film it and hand the GIF to whoever asked:

```bash
bash tools/capture.sh dust --on-action Job09_ShortSmokeAttack --pre 1.5 --post 3 --width 640   # waits for the action
bash tools/capture.sh rally --lua tools/work/start_rally.lua --seconds 6                        # or starts it itself
bash tools/capture.sh view --seconds 4                                                          # or just films
```

- The camera (`tools/lua/cam.lua`) stands a little behind and above the main pawn and looks the way the pawn faces
  (`--subject arisen` for the Arisen, `--dist`, `--height`, `--yaw`; `--mode side` puts it beside the pawn and the
  enemy nearest to it instead). Keep it that simple: a camera that tries to be clever (following a projectile,
  choosing sides) spent most of its first hour looking at rock and grass. The game's own camera is untouched: its
  transform is overwritten just before rendering and comes back when the capture ends or after its time limit.
- The frames come from `PrintWindow`, so the game window may be covered and never takes the focus. The GIF is built
  without any external program (`tools/capture.ps1`): 10 frames a second, 480 pixels wide by default.
- **Film a cast on something that stands still.** A clip of a real fight shows a camera chasing a pawn that chases
  goblins; the player could not tell from it whether the pawn threw anything. A statue (`lua/dummy.lua`), the cast
  on demand, the side camera and a short clip (`--pre 0 --seconds 2.2`) gave a picture that needs no explaining, and
  showed two things twenty fight clips had not: the swing's animation is a flick of the wrist, and the "minimal"
  settings had made the ball invisible.
- **Hold the other skills while you film one** (`lua/only_slot.lua`). Two rounds of "smaller" were judged on clips
  in which the decoy, Rally and the effigy smoked as well, and the player still saw "WAY too big". With only the
  dust slot released, one side view named the real source in a minute. The Arisen then has nobody drawing the
  enemies off: `lua/safe.lua` first.
- `--on-action TEXT` starts from the moment the filmed character begins an action whose name contains TEXT, keeping
  `--pre` seconds from before. The action names are the ones the mod's log prints ("action: ...").
- `tools/gifsheet.ps1` puts every frame of a stretch of the GIF on one sheet (the twelve frames of the capture's own
  sheet are 0.3 s apart or more: a swing fits between two of them).
- Look at the contact sheet yourself before you send the GIF. Five of the first seven captures showed nothing
  useful and reported success all the same.

Test traps that cost hours:

- **A launch can hang.** REFramework suspends the game's threads while it hooks the window, and that hook can
  deadlock, by itself (seen with no key pressed and no window touched) or when the window is fronted in that moment.
  The process then looks alive (window, memory) and never answers: REFramework's log ends on "Suspending <thread>"
  lines, 0 % GPU, the console times out. `tools/start.sh` waits for the hook to finish ("Resuming" after
  "WindowsMessageHook" in `re2_framework_log.txt`, about 10 s after the process starts); when the hook has not
  finished after 20 s it closes the game and launches again.
- **The launch presses Space only at the title menu.** The dev console writes the game's flow phase to
  `pt_dev/phase.txt` whenever it changes (and the timeline to `pt_dev/phase_log.txt`); `load_space.ps1 -PhaseFile`
  waits without the focus through the intros (phase 3 StartUp, about 22 s, they end by themselves), fronts the game
  when the phase is 8 (TitleMenu), taps until it is 9 or more (the save is loading) and hands the focus back.
  Launch to in game: about 65 s, the same as with Space tapped through the whole boot.
- **A syntax error in an autorun script stops the boot** on a REFramework error box. The dev console is such a
  script: read your edit of it once more before a launch (a line break inside a string cost one launch here).
- **A hook keeps the function it was given.** A console file that sets a hook once per session and is then edited
  and run again goes on running its first version (the capture camera looked straight down for that reason: a
  default had changed and the old code multiplied by it). Make the hook call a function it looks up each time
  (`_G.__cam.frame`), and keep its state under a key the old code does not read.
- Two helpers writing console commands at the same moment can also mangle one (a syntax error at a line that has
  none), not only lose it. Check the answer of a command that matters and send it again.
- A background `bash script.sh` that you stop from outside may go on running (only the outer shell dies) and trip
  over a script file you edited meanwhile. Start long helpers with `exec bash script.sh`, and never edit a script
  that is running.

- Steam can start the game minutes after the launch request. `tools/start.sh` gives up after a while ("DD2 is not
  running"); look for a late process before you start again, or two requests pile up. A game that came up late
  sits at the title: `tools/loadsave.sh` carries on from there.
- Spawned goblins stand idle until they are brought next to the party (`bring.lua`). A helper that respawns instead
  produces a "fight" with no battle. Sometimes two of a wave stay passive even after `bring.lua` (battle state 0
  for a minute): force a fresh wave (`cleanup.lua`, spawn, bring) when the party has been out of battle for 10 s.
- Spawned enemies outlive a scene unload and crash the game at the title about half the time unless
  `PawnTrickster.destroy_spawns()` ran (`lua/cleanup.lua`; the mod also does it at the title).
- A level 1 pawn dies from falls on slopes and cliffs, from harpies that carry it off, and from phantoms. A pawn
  left dead for a few minutes is gone (`PawnManager._MainPawn` is nil) and every later sample is void. Revive it when
  its HP is 0, and check "down" in the sampler output before believing a number.
- A keep-alive that calls `recoverAll` on the pawn every few seconds refills its stamina and hides every stamina
  effect. `revive.lua` does not do that.
- The party battle state flips to Win (4) and back between waves; samplers that only count state 2 see less time
  than the wall clock.
- With the Arisen standing still, the pawn drifts 12-20 m away. A player moves. Say which one you measured.

## 5. Engine rules (each one was a crash or a freeze)

- **Object lifetime.** An object created from Lua, given `add_ref()` and garbage-collected inside its creation frame
  corrupts the engine's frame-local object table: random crashes seconds later. Every created object goes through
  `PT.keep` (a permanent reference). Follow it for anything you create.
- **`sdk.create_userdata` returns the game's shared instance** of a `.user` file. Editing it edits the vanilla data
  for everyone. Copy first (`shallow_copy`, `MemberwiseClone`), and restore anything you had to change in place
  (`PT.state.actno_restore`, `goal_restore`).
- Never rewrite an `ActNo` command's `ActionID` at run time more than the mod already does (the third rewrite
  crashed in the garbage collector twice).
- Never add two decision packs in the same frame. Never call `setNewDecisionLists` in battle.
- Never make the `Job09ActionSelector` the pawn's current selector, and never add a second Job09 selector.
- A vanilla decision pack that is live on this pawn must not be touched or added again.
- Never call `DecoyHandler.start()` while the pawn's own summon action is creating the instance.
- Never call a GUI page's own setup methods (`setupChara`, `setupItemSlot`, ...). Open the page with
  `GuiManager.requestGuiType`, read its lists, act with real keys.
- Never call `TalkEntity.play` directly (froze the game). `TalkController.requestPawnTalk(cat, chara, nil, true)` is
  the way; talk groups 27 and 82 are accepted and never start.
- Never start an interaction while `IsPlayerTalking`.
- Option strings written to the game's settings must stay valid enum members.
- Hooks: a handful of targeted managed hooks is fine. A net of thousands of pre+post hooks crashed the game. Native
  `via.*` hooks fail. `message.get` cannot be hooked.
- Do not scan the game's pak files while the game runs.
- `ItemManager.setEquip(StorageData, Character, SlotEnum 0, false, false)` is the game's equip call; it refuses a
  weapon the current vocation cannot hold, silently.
- **Shells (projectiles).** `app.ShellManager.requestCreateShell(owner GameObject, position, rotation,
  ShellCreateInfo, ShellParamData, nil, nil)` throws one; the request object is kept (`PT.keep`) and reused, its
  `TargetGameObject` cleared afterwards. Never request a shell from inside the `registShell` hook (do it on the next
  frame). A shell's `<RequestId>` is a slot number that is reused within seconds: it identifies nothing later on.
  A shell is recognised by its owner and `<ShellParamId>`. `requestDestroyShell(request id)` takes one out safely.
- **Shells move per frame.** The thrown smoke flew 13 m at 40 FPS and 7 m at 30 FPS before dying. Anything measured
  with projectiles depends on the frame rate of the run.
- **Cooldown timers are real time.** A decision wrapper's `CooldownTimer` loses 60 units a second at any frame rate
  (2.0 a frame at 30 FPS, measured with `lua/timerrate.lua`); `_Cooldown` is in seconds. The opposite was written
  down here once from an assumption: measure before you write a mechanism down.

## 6. How pawn AI works, and how to find out why a rule is not picked

```
pawn.CachedAIDecisionMaker.<DecisionModule>            app.DecisionEvaluationModule
  <PreDecisions> / <MainDecisions> / <PostDecisions>   lists of app.AIDecision (runtime copies of DecisionPack.Decision)
  <DecisionExecutor>.<ExecutingDecision>               what runs now: Score, Target, ActionPackData, Decision
```

- **Order**: `Priority._Layer` (Common 0, Quest 1, Reaction 2) first, then `_Rank` (Lowest 0 .. Highest 4), then
  the score. A running Common decision is not interrupted by another Common decision: it has to end
  (`DecisionExecutor.forceEndDecision()` is safe and is how the mod ends its own stance and its regroup dash).
- **The lists are rebuilt at every battle-state change** from the goal-planning rows; runtime copies get cooldown
  timer 0 then. Out of battle the mod's rules are not in the list at all.
- **A rule is eligible** when its preconditions hold (`AIDecision.arePreconditionsValid(blackboard)`) and at least
  one target of its kind passes `checkTargetPreconditions(bb, target)` and `checkTargetConditions(bb, target)`.
- **A decision copied from a vanilla one keeps that one's conditions.** This mod's rules are copies of the Warrior's
  `Job05_NormalAttack_01`. Two inherited conditions silenced the pawn for whole fights until 0.2.3:
  `tcondition.ImmuneToDamage` (phantoms) and `condition.BattleMode` (false while the pawn's own AI state,
  `Character.CharaAIStateCtrl`, is Danger = 128). `cfg.rule_drop` names what is left out.
- Enums worth knowing: `PawnBattleController._CurrentState` Normal 0, Ready 1, Battle 2, Escape 3, Win 4.
  `AIDecisionDefine.OwnerState` flags Ground 1, Air 2, Climb 4, CanBattle 8, ... `AIStateEnum` Normal 1, Caution 8,
  Combat 64, Danger 128. `AITargetFlag` My 1, Player 2, Enemy 4, Party 64, Position 2048. Stamina AI state
  (`Pawn.<AIStaminaManager>`) FullPower 1, SavedPower 2, Breaktime 4. `Pawn.<SkillActionController>` counts vanilla
  skill uses for the "skill break time" walk; the mod's casts are not counted.

**The method** (all read-only, safe to sample twice a second for minutes):

1. `lua/diag.lua`: for the first of the mod's rules that is released and off cooldown, the game's own precondition
   answer, each shared precondition's cached result with its type, and the two target checks for every target.
   Output is aggregated: one line per outcome, with the failing condition named.
2. `lua/execsample.lua`: what the main pawn's AI executes and which action it plays, in percent of battle samples.
   Works for any vocation (use it on the pawn as a vanilla Mage for a baseline: `lua/disable.lua`).
3. `lua/p2sample.lua`: the same for the other party pawns, with a count of Job09 actions they played (must be 0).
4. `lua/prio.lua` and `lua/wconds.lua`: priority, policy, tags, conditions and scoring of every live decision.
5. `lua/ais.lua`, `lua/stprobe.lua`, `lua/rallywhy.lua`, `lua/decoyst.lua`: AI state, gates, why Rally is closed,
   the decoy handler.
6. `lua/stamwatch.lua`: the pawn's stamina (lowest value, time out of stamina) and what each cast rule costs.
   Stamina, not cooldowns, is what limits a Trickster pawn: a Rally costs about half of it.
7. `lua/effwatch.lua`: for every Latching Effigy cast, where the rule's target was (distance, height, angle from
   the pawn's facing) and whether the decoy latched. The pattern for a new question is the same: record the
   situation at the moment of the cast and the outcome a few seconds later, then tabulate.

8. `lua/dustwatch.lua` (swings, balls, hits, hate entries left out, enemies fooled, incense thrown by the script) and
   `lua/dusttrack.lua`: for every dust ball, where its target was, how close the ball came, how far it flew. Two of
   the four misses it recorded were out of reach at 30 FPS and one hit a slope: the tracker named in a minute what
   the hit counter could not.

`tools/sample_fight.sh` resets and prints samplers 1-3 and 6; the others are run by hand.

Reference numbers (level 1 pawn, goblin waves, Arisen standing still): a vanilla Mage executes attack or cast
decisions 68 % of the battle time and strafes 61 % of it. The Trickster of 0.2.5 alone with the Arisen: Rally
31-42 %, all casts 40-55 %, its own stance 25-36 %, never more than a few seconds out of stamina. One fight is a
noisy sample (Rally share moved by 10 points between two identical fights): run two before comparing settings.

## 7. How the mod is built

- `enable()` (automatic at every load): vocation change through `HumanJobChanger`, censer through
  `ItemManager.setEquip`, a `DecoyHandler` shared with the Arisen's prefab, hooks so Job09 has action names, skills
  (the pawn's own in release mode; `"debug": true` forces `cfg.skills`), then one decision pack of its own.
- **Slots**: `summon` (summon / beckon / taunt, multiplexed), `rally`, `delusion`, `screen`, `trick` (Latching
  Effigy), `stance` (keep distance), `regroup` (dash to the Arisen for Rally), `dust` (the idle attack). Each cast slot borrows the
  ActInterPackData of a vanilla decision of a vocation nobody in the party has (a "shell") and puts an `ActNo` command
  in it. `regroup` points at the vanilla pack `Common/Move_Fix_Dash_Target` untouched, with target Player.
- **Stamina floors**: Rally, Delusion, Screen and Latching Effigy do not start under a share of the pawn's stamina
  (`*_min_stamina`), and a running Delusion is ended when it runs low. Without them the pawn casts itself out of
  breath.
- **Latching Effigy** is released while the pawn faces an enemy 3-10.5 m away, and the rule carries created
  target conditions so that its own target (what the cast is aimed at) qualifies: `tcondition.DistanceRange`,
  `AngleTargetDiff` (angle between the pawn's facing and the target, the condition the vanilla "look at" rule
  uses) and a `Composite(Any)` of `ScaleType` (not Small) and `HeightDifference` (higher than the pawn).
- **The dust ball** (0.2.6): the `dust` slot plays the game's own throw of smoke (`Job09_ThrowSmoke`, setting
  `dust_action`); the script turns the pawn to an enemy in reach during the wind-up, and when the game's own thrown
  smoke leaves the hand (seen in the `registShell` hook, 0.73 s in) it takes that shell out and throws the same
  shell (entry of `HumanShellParamData_Job09` with hate type 25) at the target. An animation that already throws
  the projectile you want gives you the release moment for free: `lua/actwatch.lua` shows the actions and shells
  that follow a requested action. The shell computes 0 damage; the damage is written into the
  hit's `DamageInfo` after `HitController.calcDamageValue`. The hate entry the shell adds for its thrower is left out
  by skipping `HateSystem.addHateParam` for that parameter and the pawn. It has the lowest score of the pawn's rules
  and ends the stance like the casts do, when no enemy is within `dust_safe` metres.
- **The dust swing's smoke** (0.2.6, third attempt). The censer swing registers a shell of its own (parameter id
  1754224672: three seconds of thick smoke and a burst with sparks where it lands): that was the big smoke, not the
  ball. It is taken out the frame after `registShell` sees it during a dust swing (`dust_swing_shell`). The ball's
  impact and the censer's own swing effects are noted where the game creates them
  (`EffectManager.createEffectInternal`, while one of the shell's effect requests runs or under the pawn / its weapon
  during the swing) and, from the next frame, faded and removed after 0.3 s (`V.fx_tick`: `EffectPlayer.set_Color`
  alpha, then `set_Action(2)` = `via.effect.PlayerAction.Kill`). Scaling the effect's transform (the first two
  attempts) moves the emitters closer together and leaves every particle its size: a smoke cloud stays as big, and
  it grows with its age, so ending it early is what makes it small. The effect player has no resource yet when
  `createEffectInternal` returns: set colour and speed on a later frame. The wisp that follows the censer all the
  time is the weapon's own effect (a new `effect_<pawn>` every few seconds) and is left alone.
- **Fooled enemies** (0.2.6): for six seconds after a dust hit, the enemy's stored hate of every party pawn is
  written to 0 each frame and again right before the enemy sorts its ranking (pre-hook on
  `HateSystem.updateHateRanking`), so the decoy is on top of it. An enemy's ranking holds one `HateCalculator` per
  target (temporary + kept + distance hate); for the Arisen the game retargets the Arisen's own calculator to the
  decoy, the pawns have theirs. `HateSystem.setCustomRate` is reset by the game every frame and was too weak even
  when written every frame. `lua/foolwatch.lua` counts who is on top of each enemy's ranking.
- **Latching Effigy's incense** is thrown by the script (0.2.6): when the game's incense leaves the pawn's hand
  (seen in the `registShell` hook), the same shell is thrown at the legs of the enemy the pawn faces and the game's
  one is destroyed. The game aims at a point above a goblin's head; and a second incense landing next to the target
  moves the decoy there, which ends the latch.
- **The game's own conditions are the best tools.** The offline list of every condition type in the vanilla packs
  answered in a minute what hours of sampling had circled: there is a condition for "target in front of me", for
  target size, for height. Look there first, read the fields and enums in the game, and let
  `tools/lua/tcheck_table.lua` show whether a created condition answers as intended.
- The pawn's facing is its transform's +Z axis (`get_AxisZ`).
- **Gates**: Lua decides every 10 frames which slots may fire and parks the others by writing the runtime copy's
  cooldown timer to 600 (`gate_slot`). A pick is detected by the timer jumping to the slot's cooldown
  (`track_selection`). All slots are held while the party is not in battle.
- **Preemption**: the stance never ends by itself; when a cast has waited `preempt_wait` seconds it is ended.
- **Teardown**: when the game phase is left, on a party change, and in `disable()`: packs removed, borrowed vanilla
  data restored. Auto-enable sets the pawn up again.
- **Memory**: `pawns.json` keeps censer, skills, core skills and augments per pawn.
- Config defaults are the `cfg` table at the top of the script; `config.json` in the data folder overrides them and
  is rewritten with new keys at every start.

## 8. Before you call something done

Run on the final build, each with its sampler output and the mod's log read from the start of that launch:

1. The situation that failed, measured the way it was measured when it failed.
2. Goblin waves, 150 s (`sample_fight.sh`): casts, longest wait of a released cast (a few seconds at most), no
   error line, "down" count.
3. Out of battle for a minute after a fight: no cast, no decoy summoned.
4. Return to the title (`totitle.sh 30`), load again, a short fight.
5. `lua/disable.lua` (the pawn goes back to its old vocation and weapon), `lua/enable.lua`, a short fight.
6. If rules, targets or the party code changed: a big enemy (the cyclops), flying enemies (harpies), a hired pawn in
   the party (`p2sample.lua`: no Job09 action on it), a death and "Load from Autosave".
7. If a skill rule changed: that skill equipped through `"debug": true` and `"skills"`.
8. A soak of 10 minutes or more on the final build.

Then: section "what changed and what was measured" in `docs/DEVELOPMENT.md`, raw facts and traps in
`docs/NOTES.md`, the changelog, the shipped readme (`reframework/data/PawnTrickster/README.txt`), and a version bump
in the script's first line. In texts meant for players the pawn is "it".

## 9. Open problems (good first targets)

- **The dust attack's swing, and whether the pawn's model is drawn right (stopped mid-work, 2026-11-11).** The player
  wants the pawn to swing its censer and the ball to leave from it at the end of the swing. HEAD plays the throw by
  hand (`Job09_ThrowSmoke`), which is not that. `docs/v48m_wip.patch` switches to `Job09_MoveSmokeAttack` (the censer
  swung round on its chain; `Job09_DashSmokeAttack` is a low sweep) and lets the ball go when the swing's own smoke
  shell is registered. In most clips of that work the pawn's model stood frozen in one pose or was not drawn while
  the ball left from where the pawn really was, and the player saw a stuck model in the game too. Three causes were
  named and none is proven (a request for `NormalLocomotion`, destroying the swing's shell, the capture camera): read
  the v48m section of `docs/DEVELOPMENT.md` first. Start by filming through the game's own camera.
- **The capture camera may lie about characters.** `tools/lua/cam.lua` overwrites the camera transform at `LockScene`,
  after the game has decided what its own camera sees. A character the game's camera does not look at was seen
  frozen, left behind or missing in clips. Until that is settled, judge a character's animation only on clips made
  with `--nocam` with the Arisen's camera on the scene, or move the camera earlier in the frame and prove it.
- **The dust ball's hit rate and cadence.** About two balls in three hit (moving goblins dodge a homing shell;
  leading the target was not tried), and the pawn threw one every 15 s in a solo test fight at 30 FPS. The rule's
  cooldown is 4 s; what else holds it back was not measured after the last change.
- **The mod's own tick counts frames.** The gates are worked out every 10 frames (0.17 s at 60 FPS, 0.33 s at 30).
  A tick on real time would make low frame rates react as fast; it was left alone because every test so far ran
  with this one.
- **The Danger AI state**: what sets it and whether vanilla pawns act differently in it was not looked into.
- **The decoy in battle** is re-summoned every `resummon_seconds` (6 s) when enemies destroy it; whether that is too
  eager for players was never asked.
- **Latching Effigy** latches in about half of the casts on goblins level with or below the pawn (2 in 21 with the
  game's own throw). Known misses: the script throws at the enemy closest to the pawn's facing, which is not always
  the rule's target; targets beyond the shell's reach at low frame rates; a cast started turned away gets no script
  incense. The rule's own target (`DecisionExecutor.<ExecutingDecision>.<Target>`) would be the better aim. A latch
  on a goblin lasts 4-5 s (it dies), on a rogue until it dies (minutes). Rogues count as Small for `ScaleType`.
  `HeightDifference` measures to the target's body point, about a metre above its feet.
- **Online**: what other players see when they hire a Trickster pawn is untested.
- **Arisen and pawn both casting Trickster skills** in the same fight is untested.
- The pawn dies easily on slopes while holding its stance (it strafes off ledges).
