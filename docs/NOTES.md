> Working notes of the development, kept as they were written. They say "she" for the test pawn, name scratch
> files (`r/...`, `tools/...` of a temporary folder) and paths of the author's own mod workspace
> (`mods-src/...`) that are not part of this repository; the cleaned-up helpers are in `tools/`.

# Trickster-pawn RE: running notes (2026-11-08)

## Tools (scratchpad)
- tools/api.py (web API client), tools/rszdump.py (RSZ decoder via typecache+whitelist+extra_types.json), tools/apischema.py (fetch missing type schemas from API), tools/runall.py, tools/lua.sh (dmo_dev console; seq file `seq`), dumplib.lua (live object dumper, copied to reframework/data/dmo_dev/dumplib.lua; loads with io.open+load into _G; `dumpuser(type, path, depth)` / `dumpobj(obj, depth)`).
- Console idle line to restore: `-- seq 9300\n-- (idle)` in reframework/data/dmo_dev/cmd.lua.
- Game was running (Monk session testing, player on Job07). Do NOT launch/close it. Pak extraction: single pak open only while running.
- live/job09parameter_dump.txt = full Job09Parameter (1350 lines). live/*.json = pawn DecisionEvaluationModule / AIGoalPlanning / AIDecisionMaker field dumps. types/*.txt = API type dumps.

## Facts
- Enum values: HumanCustomSkillID Job09: SmokeWall=92 SmokeGround=93 TripFregrance=94 AttentionFregrance=95 PossessionSmoke=96 RageFregrance=97 DetectFregrance=98 SmokeDragon=99 HealingSmoke=118 FocusAimSmoke=119 SmokeGiants=120. Job07: 70-79,114,115. Job08: 80-91,116,117. Normal skills Job09: DecoyRegeneration=34 DecoyRangeUp=35 ThrowSmoke=36 DecoyFastSummon=37 Levitate=38.
- English names: 92 Delusory Screen, 93 Fickle Floor, 95 Sweeping Shroud, 96 Latching Effigy, 97 Aromatic Rally, 98 Scented Alarum, 99 Dragon's Delusion, 119 Espial Incense; 94/118/120 are cut ("Rejected" in msg) but 120 SmokeGiants is used by the NPC Trickster.
- Job09ActionSelector.getCustomSkillAction(id,speed) (player, live): 92 Job09_CastSmokeWall, 93 Job09_CastSmokeGround, 94 Job09_CastTripFregrance, 95 Job09_CastAttentionFregrance, 96 "" (context action), 97 Job09_CastRageFregrance, 98 Job09_CastDetectFregrance, 99 Job09_CastSmokeDragon, 118 Job09_CastHealingSmoke, 119 "", 120 Job09_PrepareSmokeGiants. Normal attack idle = Job09_ShortSmokeAttack; SUB normal attack (AttackL) = Job09_SummonDecoy. app.Job09ActionID enum lists all 60 action names (Job09_Transfer = beckon, Job09_Unsummon, Job09_Wear...).
- Pawn (live, main pawn Job02): HumanActionSelector.Selectors has Job01..Job06 selectors only (player has Job07/08/09 too). AIDecisionMaker module = Utility (DecisionEvaluationModule), 2 pre / 14 main / 7 post decisions out of combat. PawnUtil.getJobNormalAttackAction(9) = "" (Job01..03 return names), getJobHeavyAttackAction(9) = "". PawnSkillActionController.getCommonAction(2|9) = "". HumanSkillAvailability: IsPlayerOrPawn true, isRestrictedJobSkill false.
- DecoyHandler: reached via Job09ActionSelector.get_DecoyHandler(); fields Owner=app.Human, Prefab=app.PrefabController (via.Prefab), Instance (SmokeDecoy). app.Player holds DecoyPrefab/AstralBodyPrefab via.Prefab fields. SmokeDecoy has <OwnerPlayer> (may be null for pawn) and setOwner(app.Human).
- AI command app.actinter.cmd.ActNo { ActionID string, CancelSequenceFlags u32, IgnoreMotionCheck, IsUpdateAimTarget } requests any action by name (used by Job07 NPC packs). job.NormalAttack/job.HeavyAttack generic commands map to the selector's normal/sub-normal attack (for Job09: censer swing / summon decoy).
- Job09Parameter (live dump): decoy BaseHp 1500, LowHpThreshold 800, FullRecoverTime 6 s, TerritoryRadius 30 m (41 with DecoyRangeUp), SummonTime 1.0 s, PossessionAttensionInterval 15 s, LifeTime null (6000). Aromatic Rally: Lv1 5 s x2.0 attack, Lv2 10 s x2.2; defence x0.33; MaxHpDamageFactor 40.
- Pawn data files: no Job07+ rows anywhere (decision packs, CustomSkillDecisionRefData, AIGoalCategoryJob.JobDecisions, PawnJobCombatResource prefabs).
- RSZ decoder: curve layout = i32 n + n*16B keys + 24B (LoopStart, LoopEnd, MinValue, MaxValue f32, LoopCount, LoopWrapNo i32). MoveBase whitelist is stale (extra tail fields). Decision packs partly decode.

## Runs (2026-11-08 afternoon, user's go; game started with load_space.ps1 -Launch -Seconds 35)
- Run 1: enable() worked up to the AI step: job 2→9 via requestChangeJob ✓, `addJobSelector(chara)` added Job09ActionSelector ✓, skills equipped ✓, DecoyHandler already existed on the pawn's Job09ActionController (Prefab nil). Bugs: REFramework arrays have no set_element (use arr[i]=obj / write_dword(0x20+4i) for enums); pump stage re-ran every frame. Item 2000 is a DUOSPEAR (wp09 = Job07 weapons, _Job 128). Trickster censers are wp10 (_Job 512): items 2103..2105 (wp10_003_00, wp10_001_00, wp10_004_00).
- Run 2: fixed arrays; 73 JobDecisions entries extended, 4 CS sets, summon pack added ✓. `requestAction("Job09_SummonDecoy")` → the pawn PLAYED Job09_SummonDecoy (action list) even with NoJob selector, but no decoy: handler Prefab nil. `dh:setup(via.Prefab)` with the Arisen's via.Prefab then summon → CRASH (AV reading 0x3F800010 at DD2.exe+0x524a361, inside requestAction; crash kit 2026-11-08_140946). Equip: getItem(2104,1,pawn) lands in the Arisen's storage (owner 2891076981); passItem(sd,1,pawn,false) moves it to the pawn ✓; addEquipChangeInfo(sd,pawn,Main,true)+applyEquipChange() returns true but EquipData.Equips[0] keeps the bow (1700) and weaponJob stays 0/2; callEquipChangeFunc(sd,chara,0,true,true,true) also no-op. applyEquipDataForCharacter(chara) rebuilds the current slot (bow back).
- Run 3 (in progress): share the Arisen's DecoyHandler PrefabController via set_Prefab; diagnose equip (canChangeEquip, pending lists).
- Run 4 (fight, 14:30): decoy pulls aggro; autonomous Job09_SummonDecoy through generic job.HeavyAttack decisions; Warrior-scored decisions never fire for Job09 (PawnCommonEvaluate reads the per-job attack-range table); battle end autosaves (restore backup after every run).
- Run 5 (fight, 14:48, v2 decision set): the 7 own decisions were added and SELECTED (cooldown timers ran: summon 720f, rally 1500f, delusion 2400f) but the ActNo ones never produced an action (fight log: NormalLocomotion only); the one decision reusing a vanilla ActInterPackData (Job05_NormalAttack_01's) did act (Job05_Tackle x5, the pack's own job05 node). Patching IgnoreMotionCheck/IsUpdateAimTarget on the live ActNo objects changed nothing. Conclusion: an `app.ActInterPackData` made with `sdk.create_instance` (the type derives from `via.UserData`) is inert for the ActionInterface; vanilla `.user` packs work. Current selector was still NoJobActionSelector right after enable (weapon job 9).
- Run 6a (15:08): v3 enable, then CRASH 1 s after "enable done" at DD2.exe+0x5247c10 (first frame, called from +0x5247b30; no .pdata entry; same code region as the run-2 decoy crash at +0x524a361). The summon decision was enabled at once (out of battle, no target, selector NoJob). Crash kit 2026-11-08_150804.
- Run 6b (15:13): v3.1 (gates: settled + battle + Job09 selector current). The Job09ActionSelector added by addJobSelector sits at the END of HumanActionSelector.Selectors, behind TWO NoJobActionSelector entries (list: Down, Stun, ClimbLadder, ClimbRope, RunningOutOfStamina, ObjectCarry, BridalCarry, Carry, CarrySmallAnimal, Job01..Job06, NoJob, NoJob, Job09), so updateCurrentSelector never picks it. Moving it before the first NoJob + updateCurrentSelector made it current -> CRASH within a frame at DD2.exe+0x4b07c4 (stack through +0x52c1a8b/+0x52c1c52). Crash kit 2026-11-08_151600. => never make the Job09 selector current on a pawn; Job09 actions run by name under NoJob.
- Run 6c (15:17): gates = settled 10 s + battle only. Findings: (1) decisions added with _Enabled=false are NOT wrapped into the module's MainDecisions at all (and toggling the data's _Enabled later does nothing: app.AIDecision wrappers copy the Decision fields and keep no back pointer); a fresh DecisionPack with all 7 enabled had to be added from the console; (2) _LastMainDecisionIndex is the module's evaluation CURSOR (cycles 8 -> 13 -> 18 every frame), not the chosen decision; the chosen decision is the wrapper whose CooldownTimer jumps to CooldownTime; (3) wrapper UniqueID does match our per-decision Guid (mData1 seed), so identification by Guid works.
- Run 7 (15:30, v4: all slots on Common_HeavyAttackFinish's ActInterPackData, start/end processes kept, pack added once settled+battle): CRASH in the same second as the add (DD2.exe+0x523a668 <- +0x525a3f4 <- +0x5244903 [call rax+0x30] <- +0x527218c <- +0x5644359), before any pick or hook call. Crash kit 2026-11-08_153235. That pack is live for every pawn (Common_*), so two wrappers shared one ActInterPackData; the SetAttackRange start process was also shared with a live vanilla decision.
- Run 8 (15:35): the "ActNo" nodes the atlas shows for Job05_NormalAttack_01 / Job01_ShieldSummons_EMTarget / Job03_FireBoon / Job04_SmokeScreen / Job05_WarCry_EMTarget are OUR run-3 mutations (the atlas was dumped after run 3); the real packs are multi-node job packs (Job05_NormalAttack_01 = Approach, job.NormalAttack, job05.Tackle, NormalAttack, job.ComboAttack). The PawnUtil.getJob*AttackAction(Hash) hooks were NEVER hit in any run (hook_hits nil): job.NormalAttack/HeavyAttack do not resolve their action through PawnUtil, so the generic job.* commands are not a vehicle under NoJobActionSelector (and the Job09 selector must not be current). v6 (hot-reloaded in run 8): keep the vanilla ActInterPackData SHELL of an inactive-job pawn pack and swap its _Pack for our single ActNo node (restored on disable); 5 slots added in battle without a crash.
- Run 9 (15:44, v6 fresh launch): pack added in battle + forced setNewDecisionLists -> wrapped at once, then crash within seconds (DD2.exe+0x5645f7c, evaluation core). Run 10 (15:47): pack added out of battle 10 s after enable, wrapped by the module itself -> real picks; ActNo only played once CancelSequenceFlags=0xFFFFFFFF + IgnoreMotionCheck=true were set on the commands (the CommandExecutor runs CLONES of the node commands, so set the fields before the pick). Autonomous Job09_SummonDecoy, CastRageFregrance, CastSmokeDragon, CastSmokeWall, ShortSmokeAttack confirmed (runs/run10_log.txt). DecisionPackHandler: ActiveDecisionPacks, DecisionPacksToAdd queue, processDecisionPackChanges/addCheckedDecision; after a hot reload every added pack was dropped (two script instances) -> never hot-reload for pack tests.
- Run 11 (17:53, v7: summon-slot mux by re-pointing the node ActNo's ActionID per frame, party check, attack value 0.8): party = main pawn Job02 + hired Job03 + Job04 -> the Job03_FireBoon / Job04_SmokeScreen shells were live for the hired pawns. CRASH 4 s after warping the bandits, before battle (DD2.exe+0x524507e <- +0x52447e7 <- +0x528ad8c <- dinput8.dll+0xb5555 (REFramework hook trampoline) <- +0x52bbe45 think update). Crash kit 2026-11-08_1755. The PawnUtil/PawnSkillActionController hooks never fired for job 9 in any run -> v8 disables them (cfg.hooks) and uses Job01_CymbalAttack / Job01_RushAttack shells for rally/screen.
- Run 12 (17:56, v8): no crash; 3 s after the bandits arrived: Job09_SummonDecoy, mux -> Transfer (decoy far) -> CastAttentionFregrance (decoy near), CastSmokeDragon, CastSmokeWall, CastRageFregrance, ShortSmokeAttack, repeated Sweeping Shroud: a full Trickster rotation from the pawn's own decisions, without hooks.
- Run 13 (18:07, v9): party jobs 2,3,4 avoided -> 15 Fighter/Warrior candidates, 5 Job01 shells used; summon 2 s into the bandit fight, mux Transfer -> AttentionFregrance. First launch hit "bad argument to for iterator" (party_job_set declared after step_ai -> global nil); fixed by declaring it next to SHELL_POOL.
- Run 14 (18:45, v10): stance slot = created node with a shallow_copy of Common_KeepDistance_Dash's move.KeepDistance (band written at _Distance offset 272) -> CRASH ~1 s after addDecisionPack, out of battle (DD2.exe+0x52590e4 <- +0x548e8c1 <- +0x16824e). Crash kit 2026-11-08_1846. Copied move commands are not safe (runtime refs: JumpRequester, _CharacterNaviController); stance off by default (cfg.stance). Candidates: vanilla Job02_KeepDistance_* nodes, or a fresh create_instance KeepDistance with only data fields set.
- Run 15 (18:55, v11): stance slot = vanilla ActInterNode object referenced from our shell (Common_KeepDistance_Dash node 0, band 0..3) -> picked and executed, no crash. KeepDistance/StrafeKeepDistance _Distance is RELATIVE to the attack range (Archer packs use 0..0.5 behind ContinuousAimedShot/Aim). Archer KeepDistance packs have the move only as SubCommand. Lua pitfall: `cond and f() or g()` runs g() when f() returns nil -> ActNo(nil) slot (repointed live).
- Run 16 (19:02, v12: fight log edist = pawn-to-nearest-enemy distance; skill weights 20->14): blackboard found. AIDecisionMaker._AIBlackBoardController.<BBAggregate> has Common/Action/Formation/Npc/Situation collections (AIBlackBoardCollection`11 keyed by app.BBKeys.<Coll>.<Type> enums); Action.<BlackBoardFloat> (app.AIBlackBoardFloat: getValue(int)/setValue(int,float), values = BlackBoardItem<float>[8]); app.BBKeys.Action.Float: AttackRangeXZ=1, AttackRangeY=2; Situation.Float: DistanceTarget01..03. The Trickster pawn had AttackRangeXZ = 0 (no Job09 range table) -> Approach/KeepDistance bands collapse to melee. Set to 9.0 live (keeper re-applies, never overwritten); result vs the 104k-HP enemy: pawn held 24-35 m for 70 s, HP 1375->1368 (before: dips to 600), still casting the full kit. v12 holds cfg.attack_range per frame. Cast spam remains (Shroud every ~8 s from the summon slot) -> tuning next.
- Run 17 (19:10): attack value 1.0 + stance weight 16 -> pawn melee'd at 1-3 m and DIED at 80 s; stance never picked (utility too low). Run 18 (19:14, v13): stance gate via wrapper CooldownTimer (600 while blocked, 0 on release; wrappers read it every tick), stance 1.0x18, attack 0.8x14; party Mage AttackRangeXZ = 30 (Thief 0); vanilla Job03_KeepDistance_01 DecisionPack added as-is via addDecisionPack (18->20 wrappers, no crash). Result: same bandits, HP 1554->1548, real stance picks (timer 360). v14: attack_range "mage" option, mage_keepdistance, gate hysteresis (+3 m), pick filter t <= cooldown+1.
- v15 / run 19 (19:23, last run of 2026-11-08): no melee slot (cfg.melee), retreat window 5 s after a summon (stance released), skill gates through wrapper timers (rally: Arisen within 12 m; delusion: enemy with HP > 5000 within 40 m; screen: pawn HP < 60% or Arisen < 50%), attack_range 10, summon slot 15 s, Mage keep-distance pack added at enable. The Mage's blackboard range reads 4.0 OUT of combat (30 in combat) -> the "mage" option must sample during battle. Result: summon +3 s, retreat window, rally gate followed the Arisen; the Arisen died in ~25 s (4 bandits at 9 m) and the test froze (pawn idle at 1257 HP for 3 min). Next: protect-the-Arisen rule (summon + Shroud + Screen when the Arisen is targeted/losing HP), gentler warp (15 m staggered).
- v9 (written during run 12): shells chosen at enable from SHELL_POOL (5 exact-case packs per job for Job01/03/04/05/06) skipping every job present in the party (PawnManager._PartyPawnList) and the main pawn's previous job; beckon/shroud slot defs skipped (summon mux covers them).
- v3 (for run 6): every decision reuses a vanilla generic pack (`GenericJob_HeavyAttack_01.user` = Approach + job.HeavyAttack, `GenericJob_NomarlAttack_01.user` for the attack), and the `PawnUtil.getJobHeavyAttackAction(Hash)` hooks return the action of the decision selected last (`_LastMainDecisionIndex` -> MainDecisions wrapper -> our Decision by address). Action hash = murmur3-32(UTF-16LE name, seed 0xFFFFFFFF), verified against the 4 live hashes, so any `Job09_*` name can be answered.

## Runs 20-21 (2026-11-08 21:28-21:56, new low-level save: Lv 1 Arisen at Borderwatch, Mage main pawn, no hired pawns)
- Run 20 (v16): party = main pawn only (job 3 -> 9); shells from Job01 (avoid 3, 9); after the job change the pawn's own Job03 packs were NOT live any more (the new liveness check passed, `Job03_KeepDistance_01` added cleanly). No enemies loaded at Borderwatch Training Grounds (universal 404,207,-2567); NickCore.enemySpawner (Skill Maker core) spawned "Goblin (weak)" (650 HP): a Vector3f passed as the universal position is read as via.Position doubles -> garbage x, the goblins fell out of the world and died; spawning at the Arisen's own position and warping with `app.Character.warp` to a local target works. Fight: summon at +5 s, decoy up the whole fight, Rally x3, Screen x1, stance x1, pawn 400 -> 309 HP, 10-14 m from the goblins, ran out of stamina twice (LocomotionOnRunningOutOfStamina). The Arisen (idle, Lv 1) was hit to 81/366 and 151/480: the console guard healed twice (recoverAll), protect windows x5 released the summon slot (pokes). `app.Character` has no `get_MaxHp`: the current maximum is `get_ReducedMaxHp` (loss gauge), full `get_OriginalMaxHp` -> v17. The outpost guards killed both goblins.
- Crash 21:38:15 (kit 2026-11-08_213815): a probe calling `chara:get_StaminaManager()` on the pawn and listing the manager's methods -> AV through a REFramework invoke (dinput8.dll on the stack). Never call get_StaminaManager from Lua.
- Run 21 (v17, GUI): pause menu Status page is `app.ui060601_01` (IsPawn, JobIcon/StatusJobIcon `app.GUIBase.JobIconRef` {Job, Tex}, CharaTab.JobIcon, TxtJobName, SkillCtrl ItemList = SkillItem[], JobInfoData `app.JobInformationData._Params[10]` of `app.JobInformationParam` {_JobID,_EnablePawn,...}). Switch the page to the pawn without focus: `PartyList:setSelect(1)` + `partyListCtrlSelectionChangedIsPC()` (CharaTab setSelectedIndex + setupChara rebuilds the Arisen). Icon UV patterns: 3 Thief, 7 Magick Archer, 8 Trickster, 9 Warfarer, 10 "?". For the Job09 pawn the game set pattern 10, no name, 4 empty skill rows; `_EnablePawn=true` on the Job09 param changed nothing; flipping IsPawn changed nothing. **Gate: static `app.GUIBase.isDispEnableJob(JobEnum)`: true for 1..6, false for 9 (4 calls per page build).** Returning true for Job09 makes the page draw pattern 8, "Trickster" and 13 rows (4 custom skills 97/95/99/92 + 5 core skills) through the game's own code -> v18 hook (cfg.ui_fix).
- Crash 21:56:04 (kit 2026-11-08_215604): `GuiManager:requestJobGuildMenu2(JobEnum[0], 0, false)` 13 min after loading (as in the Paladin notes: 3 crashes out of 4 calls). Never open the guild from Lua; test the guild list at a real guild.
- Options for the test window: `UpscalingAlgorithm` members None,DLSS,FSR1,FSR2,FSR3,PSSR2; `FrameRate` Variable,Max30,Fix60,Max60,Max120; set through `_ApplyValueModel/_FixedValueModel:set_StringValue` + `applyValues()` + `saveConfigFile()`, plus `via.Application.set_MaxFps(30)` and `via.render.UpscalingInterface.set_EnableUpscaling(false)` for the live effect. (User's values: Fix60 / DLSS, restored at the end of the window.)
- Run 22 (21:58, v18 + console icon hook): fresh launch, the pawn Status page showed crest / "Trickster" / 13 skill rows with the mod's hooks only. The `%d` on float HP in the protect log threw every tick -> the whole 10-frame gate block (stance/skill gates, protect, test guard, range keeper after it) was dead this run; the idle Lv 1 Arisen died against two goblins (game over flow 40, ui080101/ui080102). Fixed in v19 (`%.0f`).
- Run 23 (22:06, v19, test_guard 0.6): one goblin died too fast (guards); two goblins: summon +3 s, retreat window, mux Transfer -> Shroud, Rally/stance/Screen picks, protect fired (Arisen 178/376, drop 39 % in 3 s) and poked the summon slot three times, guard healed once; pawn 400 -> 221, goblins dead at 22:10 (autosave).
- Run 24 (22:11, reload of that autosave, auto_enable on): the save keeps the pawn on Job09 with skills 97/95/99/92 and HP 221; Equips[0] read the staff (1500) until enable re-equipped the censer. auto_enable fired once at IsInGamePhase before `_MainPawn` was cached ("no main pawn") and never again -> v20 retries every 3 s. Manual enable then worked (19 main decisions, 5 ours). Fight: the pawn averaged 2.5 m from the goblins over 53 s and fell 221 -> 67 HP: after the summon it cast Shroud at once beside the decoy and the stance (config 0.7 x 18) never beat the summon slot (1.0 x 20). v21: summon slot gate-blocked during the retreat window, stance weight 24 (cfg.stance_weight), attack_range 12.
- Run 25 (22:17, v21, auto_enable retry worked at load: pawn Job09 + censer re-equipped, pack added before any console command): summon slot held 5 s after the summon (gate log), but the window was spent on the cast and a DmgShrinkM stagger; first stance pick 15 s after the summon; average pawn-enemy distance 3.3 m over 60 s, pawn 400 -> 202; protect + guard fired once each (Arisen 273/492). v22: the retreat window starts at the END of the summon action (next action change) and lasts 8 s; stance_trigger 8 m.
- Run 26 (22:21, v22): retreat window now logged after the summon ends; average distance 4.2 m over 70 s, pawn 400 -> 164. Cause in the log: the Arisen kept losing HP, the protect window stayed open and the 5 s pokes re-released the summon slot, so the pawn cast Shroud in place every 5 s (22:22:23 ... :43) with the goblins on it and the stance only got two picks. v23: pokes every 10 s and only while no enemy is within stance_trigger of the pawn (unless the decoy is down). HUD party bars are hidden by the installed HUD mods, so the HUD job icon cannot be checked from a screenshot; the icon hook covers every JobIconRef anyway.
- Run 27 (22:25, v23): first pair of goblins never gave the pawn a target (they fought the outpost guards; 67 s of battle=2 with Strafe only, no pick, HP 400 untouched). Second pair: no pokes any more, retreat window logged after the summon, but still 3.5 m average and 280 -> 173: every gate RELEASE wrote CooldownTimer 0, so Rally (gated on the Arisen's distance) fired every 10-15 s instead of 25 s and Screen likewise; the pawn stood in casts. v24: blocking remembers the remaining cooldown (frames) and the release writes it back.
- Run 28 (22:31, v24): no pokes, cooldowns preserved across gate toggles (picks hardly logged any more: the detection keys on a timer jump to the full value, which the restored partial timers no longer produce), yet 3.6 m average and the pawn DIED at 22:34:21 (DieCollapse) against two 650-HP goblins: casts root it at close range and goblins outrun the keep-distance moves. Archer `Job02_KeepDistance_*` packs carry `job02.ContinuousAimedShot` (bow) commands, so they are not reusable as-is; `Common_Pawn_Escape` is a Common pack (live already). Posture is the open problem; see README "Using it". The save was restored to the pre-session backup (Mage pawn) before run 29.
- Run 29 (22:37, v25, save restored to the Mage pawn): auto-enable converted the pawn at load (try 2, 3 s after the first look: job 9, censer from storage, 5 decisions wrapped, 19 main decisions); the Status page showed crest / "Trickster" / 13 rows with the mod's hooks only (screenshot `shot_run29_status_crop.jpg` in the scratchpad: pawn "Glynn", Lv 1). `PT.disable()` removed the packs (19 -> 12 main decisions) and asked for job 3, but the auto-enable loop re-enabled within a frame (job 9, censer back, packs re-added at 22:41:06 without a crash). v26: `PT.user_disabled` stops the loop for the session; disable() restores the weapon itself; `PT.prev_main_item` survives the state wipe.
- Run 30 (22:42, v26, Mage save): auto-enable at try 2; `PT.disable()` -> staff back (restore_weapon 1500), job 3, packs removed, and it STAYED off (user_disabled); `PT.enable()` by hand afterwards re-added the packs (13 -> 20 main decisions). The disable/enable cycle is safe out of battle. Installed config: auto_enable true, test_guard 0 (0.6 only for test runs).
- Run 31 (22:46, v27 flee_first): casts held for 37 s while goblins were within reach, yet 2.3 m average and 400 -> 148: no stance pick during the hold. A wrapper recorder (timer jumps with the pawn's action) showed the real mechanism: **a pick of one of our ActNo slots lands the wrapper's CooldownTimer on ~300, the module's retry backoff for a decision whose command reported failure, although the Job09 action plays** (`screen 0 -> 300 during Job09_CastSmokeWall`). So Shroud / Screen / Rally came back every 5 s instead of 12-30 s and the pawn stood casting. Stance picks land on 360 (its real cooldown) and often during a DmgShrink stagger. `app.AIDecision` also has `DisableFlag` / `set_DisableFlag` (a cleaner live gate than the timer) and `IsPenalizeConsecutiveChoice`. v28: a jump into 290..310 is treated as the pick it is and the slot's full cooldown is written (`cfg.backoff_to_cooldown`).
- Run 32 (22:52, v28): crash at 22:54:00 (kit 2026-11-08_225400, DD2.exe+0x5244b01 <- +0x525a3f4, no plugin on the stack) in the frame where our pack AND the Mage `Job03_KeepDistance_01` pack were added together, out of battle, 10 s after the auto-enable; 1 crash in ~16 such adds. v29 adds the Mage pack 3 s later on its own frame. (Console note: writing `-- seq N` by hand into cmd.lua moves the console's last-seen seq; the runner's `scratchpad/seq` must be set above it or every command times out.)
- Run 33 (23:00, v29): Mage pack added 3 s after ours (no crash). First pair of goblins died to the guards without engaging. Second pair at 8 m: v28 confirmed (`pick: summon -> ... (backoff 300 -> cooldown 720)`), only 3 Job09 casts in 90 s instead of one every 5 s, but with flee_first the pawn neither cast nor moved while the goblins were on it (no stance pick for 50 s, 2.3 m average, 400 -> 198). flee_first is off by default from v30; the posture question stays open (the stance decision is rarely selected while the pawn is being hit, the vanilla Strafe/locomotion decisions win).
- Run 34 (23:06, v30 = shipped defaults, last run of the window): summon 12 s in, picks with the backoff fix (summon 720, screen 1800, rally 1500 frames), one stance pick, but two 650-HP goblins at 8 m on a 400-HP Lv 1 pawn with an idle Arisen: 4.2 m average and the pawn died at 23:08:48 (41 s). The setup is harsher than real play (the Arisen fights and draws aggro there); still, survivability against fast melee is the open design problem. Close-out: save restored to the pre-session backup (Mage pawn), config.ini FrameRate=Fix60 / UpscalingAlgorithm=DLSS restored, installed config auto_enable true / test_guard 0, autorun = v30.

## 2026-11-09 window (5 h granted): why the pawn gets hit despite the decoy
- Run 35 (23:20-23:36 by the wall clock; the game's os.date reads 09:0x): a hate recorder read each goblin's `app.HateSystem._Ranking` (`app.HateCalculator[]`: `_TargetObj`, `_TargetSmokeDecoy`, `_TargetHateValue_Temp/NotForget/Distance`) every 2 s through three fights. **The pawn's decoy never appears in any enemy's hate ranking**: only PAWN (ch100000_00), ARISEN (ch000000_00) and the outpost guard (ch300095). The decoy (`app.SmokeDecoy`, parent `app.CloneCharacter`, GameObject `Job09_SmokeDecoy`) has `IsTargetResistered=false`, no HateSystem of its own, and its `CloneCharacter.<OwnerPlayer>` is nil (owner = the pawn). Every goblin's `HateSensor._IsDetectDecoy` is false. Forcing `_IsDetectDecoy=true` each second (284 writes) changed nothing; mirroring the pawn's decoy into the Arisen's idle `DecoyHandler.Instance` changed nothing. So the whole Trickster mechanic (decoy draws aggro, Shroud redirects) is inert for a pawn-owned decoy: the pawn and the Arisen keep all the hate, which is why the pawn fights at 2-4 m and dies. Leads: `app.EnemySmokeDecoyUtil.getDecoyObject(Human)/getNearestDecoyObject(GameObject)` (static lookups enemies use), `HateSensor.updateDecoyHate(GameObject, GameObject)`, `HateManager.registerSendHate(GameObject, GameObject, HateSendTypeID, SendHateParam)`, `SmokeDecoy.set_IsTargetResistered`.
- Run 36 (09:08): `app.EnemySmokeDecoyUtil.getDecoyObject(Human)` hooked (safe, main thread): 3629 calls in 30 s, every one for the ARISEN's Human (ch000000_00): enemies only ever look for the player's decoy. Returning the pawn's decoy GameObject from that hook (2032 overrides) did NOT put the decoy into any hate ranking; neither did setting the decoy's `IsTargetResistered` and `AttensionTimer` (8 s) by hand. Hate API found: `HateSendTypeID` has `Job09_AttentionSmokeAttack=28` (Shroud), `Job09_SmokeAttack=24`, `Job09_PossessionStart/Loop=26/27`; `HateSystem.addHateParam(GameObject, HateSendTypeID, Nullable<float>)`, `addHateParam(GameObject, SendHateParam, Nullable<float>)`, `AddHateToSpecificEnemies(Character, CharacterID, HateSendTypeID)`, `HateManager.registerSendHate(GameObject sender, GameObject, HateSendTypeID, SendHateParam)`, `getSendHateParam(HateSendTypeID)`. Calling `addHateParam(decoyGO, 28, nil)` on the goblins' HateSystems from Lua crashed the game at once (the nil for the Nullable<float>, most likely).
- Run 37 (09:14): `HateSystem.AddHateToSpecificEnemies(decoy, enemyID, 28)` threw ("Invoke threw an exception", no crash); `HateManager.registerSendHate(decoyGO, enemyGO, 28, getSendHateParam(28))` ran 32 times without error and still no decoy entry appeared in any ranking. The decoy has no `HateSystem` (nil) and enemies seem to build one `HateCalculator` per registered HateSystem, so a target without one can never rank. Next: set the decoy's `CloneCharacter.OwnerPlayer` to the Arisen's `app.Player` before its `start()` (poll every frame while `CompletedClone` is false) to see whether the vanilla registration is gated on the owner being the player.
- Run 38 (09:19): `app.Character.get_Player()` returns nil for the Arisen's character; the `app.Player` component comes from `go:getComponent(System.Type)` with `sdk.typeof("app.Player")`. Writing that Player into the pawn decoy's `CloneCharacter.<OwnerPlayer>` crashed the game within seconds (kit 2026-11-09_0921xx): the decoy then runs player-only code against a non-Trickster player. Not a usable lever.
- Run 39 (09:24, reference): the Arisen (still a Thief; `requestChangeJob(9)` did not take) played `Job09_SummonDecoy` through `HumanActionSelector.requestAction` and its decoy appeared in every goblin's ranking at once as `_TargetSmokeDecoy` — **in place of the ARISEN entry** (the owner's HateCalculator is retargeted to the decoy) — with `IsTargetResistered=false`, no HateSystem and `OwnerPlayer=nil` too, so none of those flags is the gate. The gate is which owners the sensor asks about: `getDecoyObject(Human)` only for the player. Calling `HateSensor.updateDecoyHate(pawnGO, pawnDecoyGO)` on each goblin ran (52 calls, no error) but the pawn had died before the entries could be read; retest with a pawn heal guard.
- Run 40 (09:29): with a pawn heal guard. `HateSensor.updateDecoyHate(pawnGO, pawnDecoyGO)` every second (64 calls) and every frame (718 calls): the PAWN entry never switched. Writing the decoy into the PAWN `HateCalculator._TargetSmokeDecoy` made the goblins DROP the pawn from their rankings altogether (entries gone, only the Arisen left). Native reference (hook on `updateDecoyHate`): the game calls it every frame per enemy with (ownerGO = ch000000_00, decoyGO = Job09_SmokeDecoy) while the Arisen's decoy exists, and the ARISEN entry's `_TargetObj` becomes the decoy GameObject; `getDecoyObject(Human)` is still asked only for the Arisen even while our pawn calls run. Re-owning the pawn's decoy to the Arisen's Human with `CloneCharacter.setOwner(app.Human)` crashed the game (third owner-related crash). Conclusion: the enemy side only ever handles the PLAYER's decoy. Next: give the pawn's Job09ActionController the ARISEN's DecoyHandler object (`set_DecoyHandler`) so the decoy the pawn summons is the player's decoy natively.
- **Run 41 (09:37): the fix.** `pawn.Job09ActionController.set_DecoyHandler(<the Arisen's DecoyHandler object>)` (the Arisen is not a Trickster, so its handler is idle): the pawn's next `Job09_SummonDecoy` created the decoy through the player's handler and BOTH goblins ranked `Job09_SmokeDecoy` first within 2 s (len 0.6 / 3.2 m), the pawn second, the Arisen's entry replaced by the decoy. No crash. Afterwards the goblins dispersed the decoy: it stays as a HIDDEN instance (`HasInstance` true, `Appeared` false, `Hidden` true, `Status` 2) and the mux never summoned again; a forced `Job09_SummonDecoy` re-created it and the goblins retargeted it at once. v31 shares the handler at enable (restored on disable, skipped when the Arisen is Job09); v32 counts a hidden decoy as down. Shared-handler caveats to watch: the handler's `Owner` is the Arisen (the decoy spawns where the caster stands, fine so far); if the Arisen becomes a Trickster the pawn keeps its own (inert) handler.
- Run 42 (09:43, v32 native): the handler share happened at enable (`decoy: pawn uses the Arisen's DecoyHandler ... true`), summon 30 s into the fight, mux -> Shroud, the decoy dispersed at 09:44:33 and the mux re-armed the summon (decoy=true again by 09:44:43). Crash at 09:44:45 (kit 2026-11-09_094445) at DD2.exe+0x5244b01 <- +0x525a3f4, the same pair as the run 32 crash (decision module), with REFramework on the stack: a second sporadic crash in the decision module during our frame work (gate / poke timer writes at 09:44:36, or the hidden-decoy resummon). Not reproduced on purpose yet.
- Run 43 (09:48, v32): same sequence as run 42: summon, Shroud/Rally, the decoy dispersed, `mux: summon slot -> Job09_SummonDecoy (decoy false)` over the hidden instance at 09:49:59, crash at 09:50:00 (kit 2026-11-09_095000, DD2.exe+0x524507e <- +0x52448cb <- +0x49f961b: the think/decision region, the run-11 address). Two for two: re-arming the summon while a hidden instance of the shared handler exists is the trigger. v34 finishes the hidden instance through `CloneCharacterHandler.finish()` and arms the summon only once `HasInstance` is false; v33 only writes gate/poke timers to wrappers seen in MainDecisions this frame.
- Run 44 (09:54, v34): no crash during the fight, but `CloneCharacterHandler.finish()` on the hidden instance is a no-op (HasInstance stays true, Hidden true, Status 2) so the pawn never summoned again and the goblins ended with empty hate rankings (no target at all); `vanish()` on that hidden instance crashed the game at once (kit 2026-11-09_1001xx). Pattern: the shared handler's FIRST decoy works (enemies target it); once dispersed the hidden instance cannot be torn down from our side (finish no-op, vanish crash, AI resummon crashed ~10 s later in runs 42/43; one forced resummon in run 41 survived). Next: hook the handler/SmokeDecoy lifecycle (create/start/finish/vanish/onInstantiated/setStay) on both handlers, written to a json file, during an Arisen-owned reference decoy and a pawn fight, to learn the game's own teardown sequence.
- Run 45 (10:02, lifecycle hooks -> `runs/run45_lifecycle.json`): native summon = `Handler.create` -> `onInstantiated` -> `setOwner` -> `Handler.finish` -> `Handler.start(StartInformation)` -> `SmokeDecoy.start` -> `applyStartInfo`. Dispersal = `SmokeDecoy.onDamageHit` -> `CloneCharacter.finish` x2 -> `CloneCharacter.sleep` (2 s later): the decoy SLEEPS (Status 2, Hidden). Native resummon over a sleeping or a visible instance (Arisen, `requestAction`) = `Handler.start(info)` (+ `finish` of the old one) -> `applyStartInfo`, no crash. `app.SmokeDecoy.StartInformation` = {StateName "Start", Position via.Position (universal), Rotation}; built from Lua (`set_StateName`, the pawn's `get_UniversalPosition` moved 1.5 m forward) and passed to `dh:call("start", info)` on the shared handler it re-appeared the decoy at the pawn with no crash (17 s watched). This is the pawn's resummon path (v35). The 3 s `finish()` loop of v34 was a no-op (Handler.finish -> SmokeDecoy.finish, instance kept).
- Run 46 (10:12, v35 native): the full loop works: shared handler at enable, first summon by the AI action, the goblins rank the decoy first (alternating with the pawn, both at d~99 since the decoy stands 1.5 m from the pawn), two automatic re-summons through `handler.start(info)` (10:15:14, 10:15:55) after dispersals, no crash over 2.5 min. Pawn still at 2.6 m average and 400 -> 203 HP (the re-summon at its own feet keeps the fight on top of it). The decoy's not-forget hate stays 0 (Sweeping Shroud's attention does not land on this decoy: `AttensionTimer` 0, and a manual `set_AttensionTimer(10)` did not count down). v36 places the re-summoned decoy 6 m from the pawn towards the nearest enemy.
- Also run 46: `HateManager.registerSendHate(decoyGO, enemyGO, 28, param)` with the decoy now a real target still left its not-forget hate at 0; the Shroud attention path stays player-only. The decoy competes with the pawn on distance hate alone, which is why it must stand away from the pawn (v36) and the pawn must back off after a re-summon (v37 retreat window).
- Run 47 (10:19, v37): three fights without a crash (2 goblins, 3 goblins, 2 goblins; ~6.5 min of battle). Decoy first / alternating with the pawn, 1-4 automatic re-summons per fight, Dragon's Delusion twice against three goblins (crowd gate), pawn 400 -> 353 in the first fight, two guard heals over the next two (still 3-4 m from the goblins, 4-6 hits per fight). v38: attack_range 14, resummon_offset 7.
- Run 48 (10:30, v38): stable again (2 goblins, 3 re-summons, 7 hits, one guard heal, 400 -> 296); 4 min idle afterwards with the decoy standing (Status 4) and no frame error. Average distance still 2.1 m: range 14 / offset 7 did not move the pawn away. Shroud casts (8 per fight) root the pawn for nothing since their attention never lands -> v39 holds the summon slot while the decoy is up and near (Transfer when far stays; `cfg.shroud = true` restores the casts).
- Run 49 (10:40, v39, last run of the window): no Shroud casts, 5 automatic re-summons, 8 hits, 0 stance picks, 2.5 m average, 400 -> 265 with one guard heal; stable. Posture is unchanged by removing the casts: the vanilla locomotion decisions keep the pawn close and our KeepDistance slot is not selected while it is being hit. Close-out: save restored to the pre-session backup (Mage pawn), installed config auto_enable true / test_guard 0 / share_player_decoy true / shroud false, autorun = v39, options in config.ini untouched today (Fix60 / DLSS; the 30 fps cap and upscaler-off were applied live per launch only).
- Run 50 (10:49, v40 stance rank 3): 1 stance pick (0 before), 2 re-summons, 6 hits, 2.4 m, 400 -> 315 with one guard heal: marginal. **Real progression works natively**: after one fight the pawn's `JobContext.getJobExp(Job09)` = 46, `calcJobRank(9)` = 1 (max 9), ConsumableExp (DCP) 46, QualifiedJobBits 256, ChangedJobBits 260 (job 3 exp 0). `requestJobGuildMenu2(JobEnum[1..10], MenuKind.Job, false)` crashed the game too (4th crash of that call, with an empty and with a full array): the guild menu cannot be opened from Lua; the pawn's guild list has to be checked at a real guild (Vernworth).
- Runs 51-52 (10:55-11:15, guild from Lua): `GuiManager.requestJobGuildMenu2` crashes however it is called. Warping the party onto the Vernworth guild icon (1.55 km) landed in a quest trigger (dialog); abandoned, save restored. Working path: `app.NPCManager.get_NPCHolder_FullList()` holds every unique NPC (1706); the holder 1.5 m from the "Vernworth Vocation Guild" icon (CharaID 3335726897) is the guild master; `NPCHolder.warp(Position, Quaternion)` (universal position) moves his simulation point and the entity generates there within seconds (`get_entity_complete` true, GameObject ch310062 then ch300400 after a second warp). His talk is an `app.InteractiveObject` (InteractManager.InteractiveObjects, `<Owner>` = his GameObject, 1 point: Distance 2.0 m, AngleRangeFromCharacter 90°, `isInteractEnable(pl)` true, `canPlayerInteract` false at 2.5 m); `executeInteractForSystem(UInt32, Character)` is the call to start it. A third warp to 1.5 m from the Arisen crashed the game (kit 2026-11-09_11xxxx) - keep ~1.9 m and place him on the side the Arisen faces.
- Run 53 (11:08): the guild master warped to 1.9 m on the Arisen's facing side (the `-fwd` side of my quaternion estimate is the front): `canPlayerInteract(0)` true and he became the InteractManager's highest-priority object. `InteractiveObject.executeInteractForSystem(0, arisenCharacter)` returned true and the game crashed within 5 s (kit 2026-11-09_1108xx). Next: the player path `InteractManager.executeInteract(Character)`.
- Runs 54-55 (11:15-11:40, the guild talk from Lua): `NPCHolder.warp` is flaky (one crash on the first warp of a session, one at 1.5 m; two sessions fine at 3 m). With the guild master 1.6 m away and the Arisen turned to face him (`Transform.set_Rotation`; forward is +Z in the quaternion, my -Z guess had him behind), `canPlayerInteract(0)` is true and he is the InteractManager's highest-priority object, but neither `InteractManager.executeInteract(arisen)` nor setting `IsPlayerInteractTriggered` starts a talk (IsPlayerTalking stays false, no GUI), and `InteractiveObject.executeInteractForSystem` crashed (run 53). The guild master's talk data is most likely area-bound (Vernworth). Guild conclusion: not reachable from Lua in this window; the mod carries the two data-level switches that gate pawn vocations in the GUI (`isDispEnableJob` hook, `JobInformationData` Job09 `_EnablePawn`, v41) and the Status page proves the pattern; the Vocation Guild list itself has to be checked by walking to Vernworth.
- Runs 56-57 (11:18-11:30, v41-v43): `sdk.create_userdata("app.JobInformationData", "AppSystem/Gui/JobMenu/JobInformationData.user")` returns an EMPTY object (0 params) although that is the exact path the Status page's instance reports, so the flag has to be set on the menus' loaded instance: Status page field `JobInfoData`, Vocation Guild screen (`app.ui040101_00`) field `JobInformationData` (the guild screen also has `_DisableJobList`, `setupDisableJobs(1)`, `setupJobMenu(1)`, `getJobInfoParam(1)`). v43 hooks `ui060601_01.setupKeyGuide` and `ui040101_00.setupJobMenu / setupDisableJobs / setupContents` and sets Job09 `_EnablePawn` there (log `... -> true (status)` confirmed). Whether the guild then lists Trickster for the pawn still needs a real guild visit.
- Run 58 (2026-11-09 afternoon, user's new save in front of the Borderwatch innkeeper, v43): **the inn's Vocation Guild is reachable from Lua.** The innkeeper's talk is an `app.InteractiveObject` (owner ch300059, one point, Distance 2.0, 90°). From the user's spot `canPlayerInteract` was false for two coordinate reasons only (`canCharacterInteractWithoutCoordCondition` true): `Work.isTerrainFound` (the counter blocks the ray) and `Work.isInCamera` (the hip-height point was out of frame). Test-only hooks returning "no terrain" / "in camera" made the work's `_canPlayerInteract` true, but the highest-priority object was a gimmick talk point (gm51_191), so a post-hook on `InteractManager.processHighestPriorityObjectForPlayer` pins an `InteractPoint {Object, PointNo}` built with `sdk.create_instance("app.InteractManager.InteractPoint")`. `executeInteract(player)` alone does nothing; `addActiveInteract(player, point)` then `executeInteract(player)` starts the real inn talk (TalkEvent 1939). The talk select (`GuiManager.TalkSelect` = ui021601) is driven by `SelectedIndex` + `reqEnd()`; its texts are in `ScrCtrl.InfoList[i].Msg` (Rest / Organize Storage / Vocation Guild / Talk / Cancel, then Change Vocation / Acquire-Equip Skills / Adventurers' Branch / Cancel). Faking pad Interact (CharacterInput bit 6) and `IsPlayerInteractTriggered` did not start it. The earlier "hire menu" came from the generic executeInteract grabbing a rift pawn near the inn; `app.ui041701.reqHide()` closes the stuck pawn-details panel.
- Run 58, guild screen (`app.ui040101_00`, FlowId JobMenu=2 / CustomSkillMenu=10 / NormalSkillMenu=8 / AbilityMenu=13, `openMenu(MenuKind)`, `_CharaTab` = `GUIBase.CharaChangeJobGuildRef`): **the pawn's Vocations list shows Fighter, Archer, Mage, Thief, Trickster** (Trickster: crest 8, "Rank 1", censers, the vanilla description, IsUnlocked + isEquip from the mod's qualified bit 256), Weapon Skills lists Unequip + the four unlocked skills (the game lists unlocked skills plus the next rank's, as for the Arisen's Thief), Core Skills lists Mending Vapor (150 Dcp, JobA 9), Augments only "Remove Augments" at rank 1 (pawn Dcp 0). Switching the character tab: set the tab's `_ListCtrl.InputKeyNext` bit into `Input.Input.ButtonTriggerFlags/ButtonOnFlags` (GuiInputSystem.Input = app.SystemInput) and call `_CharaTab.updateInput()` in the same frame; calling `_ListCtrl.next()`/`charaChange()` directly throws and corrupted ItemList[3] (rows 3-4 drew the default "Fighter" template) and the later `setFlowId(End)` crashed the game. A fresh instance (close with `setFlowId(24)`, reopen from the talk select) renders every row correctly.
- Run 58a (15:34, goal planning, console patch): the pawn's `AIGoalPlanning._AIGoalData._GoalTypeList[27]._ParamList[]._GoalParam._DecisionCategory._Process` (`AIGoalCategoryJob`) holds `_JobDecisions[] { _Job: JobEnum[], _DecisionPacks[] }`; 111 job-category goal params, 98 rows list the Mage, 2 list Job09 (carry/wrestle). Appending Job09 to all 98 Mage rows (new JobEnum[] arrays, 4-byte values at +0x20) and fighting two weak goblins in the Borderwatch yard: **average pawn-enemy distance 8.9 m (2.1-2.5 m in runs 46-50), pawn 400 -> 400 HP**, actions Strafe 20 / NormalLocomotion 18 / JobMagicUser_StartMagicBarrier 12 - but no decision of ours was ever selected (sel=nil throughout), no decoy, and the pawn stayed frozen in the Mage's StartMagicBarrier stance after the fight (a censer cannot finish it). The Mage rows carry the casts (Boons, ThunderRain, Frigor, HolyShine, CureSpot... 63 of 98 rows are casts only).
- Run 58b (15:38, v44 logic as a console patch first): restore, then Job09 appended only to the all-vocation rows (24: Common_Pawn_Escape, Common_Ring_Dodge, Common_Pawn_FormationStrafe, Common_Wrestle, Common_Pawn_Avoid...; a Job09 pawn had none of these) and a Job09-only row created next to each Mage row that carries `Job03_KeepDistance_01` / `Job03_MoveAttackRange` / a Common_* pack (9 rows). Test spot: the outpost yard reached by `app.Character.warp(via.vec3, CharacterWarpOption 1)` on the player (throws "Invoke threw an exception" but moves the character; `Transform.set_Position` does not); the first spot tried (the goblin field 25 m below the outpost) is a dark cave where the pawn fell through the ground and died; `recoverAll` + a warp onto the player revived her. Spawns 12 m ahead died at once when the Arisen faced a rock. First-time tutorial popups (`app.ui080101`, "Pawn Forfeiture", "Pawn Commands") pause the game: `setFlowId(4 Out)` closes them, `GuiManager.addTutorialHistory(id)` for every key of `TutorialDataTable` (138) stops them for the session.
- Run 58c (15:45): the user walked the party to an open spot just outside Borderwatch camp and asked to keep it as the fight-test arena: universal (364.22, 205.45, -2615.97), rotation (0, -0.958, 0, 0.287). Goblins spawned inside the camp are killed by the guards within seconds (two spawns, two bring_enemies pulls all died at once), so every later posture test starts from this spot.
- Run 58d (15:45-15:50, arena, v44 logic as console patches): first arena fight with the movement-only rows: **0 of the mod's 5 decisions were live** (`DecisionEvaluationModule.MainDecisions` held 24 wrappers, none with our UniqueIDs), no decoy, pawn 400 -> 0 (DieCollapse), 5.5 m average: the module rebuilds its lists from the goal rows once Job09 has rows, and the pack added with `addDecisionPack` is dropped. Fix: the Trickster pack rides in every created Job09 goal row (console `t_goal_patch3`, 9 rows; source v44b). Within seconds the module held 29 wrappers including our 5 (stance, summon, rally, delusion, screen), `decoy=true`, `sel=rally`. Active battle goals seen in `_CurrentGoalList` during the fight: gt3.p0, p2, p3, p5, p10 (job category) + gt3.p6/p23/p34/p39 (common).
- Run 58d result (15:49-15:53, decisions live): 220 battle ticks with the decoy up on every tick, picks rally 57 / stance 158 / screen 4 / summon 1, actions NormalLocomotion 134 / Strafe 39 / CastRageFregrance 34 / CastSmokeWall 2, pawn 302 -> 211 HP, **average pawn-enemy distance 3.3 m** (2.1-2.5 m in runs 46-50 without goal rows; 8.9 m with the Mage's full rows but no casting). The remaining 650-HP goblin outlived the 180 s window (the user was exploring). v44 = this configuration (goal rows with movement packs + Trickster pack).
- Run 59 (16:16-16:21, arena, v44 + band write): **the stance node was the posture bug.** `build_stance_pack` only ever found one vanilla KeepDistance node, `Common_KeepDistance_Dash` node 0, whose `_Distance` is via.Range {0, 3} = start 0 m, width 3 m: the "stance" dashed the pawn INTO 0-3 m (the Archer KeepDistance packs hold Aim/ContinuousAimedShot nodes, the only other KeepDistance nodes are NPC large-target ones: {25,10}, {35,5}, {50,10}, {25,3}). Writing {7, 5} (7-12 m) into that command for the run: 206 battle ticks, decoy up on every tick, **average pawn-enemy distance 8.9 m** (min 1.3), pawn 400 -> 383 HP, picks rally 187 / summon 11 / stance 6, one goblin killed by the party; pawn Dcp 0 -> 23 during the fight (getJobExp(9) still 0 mid-battle). v45: `cfg.stance_band = {7, 5}` written into a MemberwiseClone of the node/command (shared data untouched), fallback: write into the shared command and restore in disable().
- Run 59b (16:25): back at the innkeeper (inn chain), the guild header shows **23 Dcp** for the pawn, the Dcp earned in the arena fight; `getJobExp(app.Character.JobEnum)` = 23 for Job09 (the Int32 overload is an array index: 8). Rank-up display test follows (setJobExpWithJobRank(9, 3)).
- Crash 16:28 (run 59b): after `ui040101_00.setFlowId(24)` closed the Vocations screen and the talk select picked "Acquire/Equip Skills" 5 s later, the game crashed within seconds (the same sequence worked at 15:3x). `JobContext.setJobExpWithJobRank(JobEnum 9, 3)` on the pawn changed nothing (exp 23 -> 23, rank 1).
- Run 60 (16:28, relaunch after the crash, v45 installed): at load `stance: cloned node, band 7.0 5.0` (MemberwiseClone path works, shared data untouched), `goal: Job09 added to 24 all-vocation rows, 3 Job09 rows`, `track: 5 of our decisions in MainDecisions (17 total)`; the save on disk had advanced to the arena autosave.
- 16:29 (run 60): `JobContext.addJobExp(JobEnum 9, 600)` works on the pawn (exp 23 -> 623, calcJobRank 2, ConsumableExp 623). A mistimed talk-select pick chose "Rest"; the next inn talk attached to a rift pawn (Kazu hire dialog) and every Lua script stopped (mod log and dmo_dev console silent, game unpaused, isDispTalkSelect true via the web API): REFramework Lua died. Relaunched.
- Run 61 (16:38, relaunch): the pawn's Job09 exp 623 / rank 2 survived the save (the inn Rest autosaved) and reload. At the inn (text-based talk-select picks, one talk per screen) the Vocations tab shows **Trickster Rank 2** with two pips and 623 Dcp in the header, "new" markers on Core Skills / Augments: rank display and Dcp are the game's own. Skills tab check follows.
- 16:40 (run 61): **Lua death pattern found**: calling `InteractManager.addActiveInteract` + `executeInteract(player)` while `IsPlayerTalking` is still true (guild screen or talk select open) stops every REFramework Lua script (mod log and console silent) and the game logic hangs behind the open screen while the window still responds; the REFramework.NET web API (localhost:8899, `/api/explorer/chain` with `_GUIList -> _items -> array`, `/api/explorer/method`) still reads and calls, but the GUI no longer updates. Both Lua deaths today (16:29, 16:40) were this. Rule: end the talk first (close the guild with setFlowId(24), cancel the talk select until `IsPlayerTalking` is false, wait 5 s) before any new interaction. The vocation screen on the relaunched game showed Trickster Rank 2 / 623 Dcp for the pawn (exp set with `addJobExp`), read from the game's own data after a save/reload.
- Run 62 (16:49-16:53, arena, v45 as installed, restored save): **12.2 m average pawn-enemy distance** over 191 battle ticks, decoy up on 189, picks rally 151 / stance 27 / screen 6 / summon 3, pawn 400 -> 380 HP, one goblin killed (pawn Job09 exp 0 -> 23). Rift pawns that join the fight open a hire dialog afterwards (Pickle, Kazu, Leek today) and pause the game: cancel it through `ui021601` (`SelectedIndex` = last, `reqEnd()`). Close-out: save restored to the 14:36 backup, v45 installed, auto_enable / goal_jobs / stance_band on, test_guard 0.
- Run 63 (18:20-18:27, user back; save backed up to the Desktop `DD2_save_backup_20261109_182033`): the game had crashed/closed at 16:55 right after the last verification. `addJobExp(9, 1500)` -> exp 1500, rank 3, Dcp 1500. Opening Acquire/Equip Skills and switching to the pawn tab **crashed the game** (crash kit 2026-11-09_182650: DD2.exe+0x55df596, last loose file TEX_ui040102_08_IAM.tex, the guild skill-icon sheet; the 10:48 `requestJobGuildMenu2` crash had the same last file). Second skills-screen crash with the pawn above rank 1 (16:28 at rank 2 / 623 Dcp); at rank 1 the screen opened three times without trouble. Hypothesis: the pawn's purchasable/"new" Trickster skill rows (rank-4 skill 94 "Acquire 700", or Mending Vapor affordable) hit a Job09 pawn code path that crashes; to be isolated (Dcp only vs rank).
- Run 64 (18:28-18:45, save backed up to the Desktop first): **skill purchase through the real menu works for the pawn.** Crash isolation first: 600 Dcp at rank 1 -> skills screen fine; rank 2 (600 exp) fine; rank 3 (1500 exp) fine, so the two earlier skills-screen crashes were not rank-related (the 16:28 one followed a re-pick right after `setFlowId(24)`, the 18:26 one a tab switch right after a hire-dialog cancel). The game lists Trickster skills whose `_UnlockRank` <= current rank (not "next rank" as I wrote earlier): at rank 3 everything was already unlocked by the mod, at rank 4 (`addJobExp` 1500 more, 3600 Dcp) the list gained Espial Incense (700 Dcp) and the level-2 upgrades Mists of Slumber / Illusive Divider (1000 Dcp each). Selecting the Espial Incense row (`_Main_ContentsListCtrl.setSelectedIndex(6, true)`) and `setFlowId(11)` (CustomSkillUnlockConfirm) opened the game's dialog "Spend 700 discipline to acquire Espial Incense?" (`GuiManager.Dialog` = ui010101: `Ret` = 1 SelYes + `setFlowId(4 FadeOut, false)` answers it); result: row `IsUnlocked` true, **Dcp 3600 -> 2900**, then the game asked "Equip Espial Incense?" and moved to the slot picker (flow 22). Jumping that flow to 18 directly did not equip and left the screen in a mixed state (closed with End). A method tracer (28 hooks on ui040101_00 / MainContentsItem writing to `reframework/data/PawnTrickster/trace.txt`) is in `scratchpad/t_tracer.lua`. Big-monster test: the spawner's "Cyclops (weak)" fell through the world and died; "Cyclops (unarmed)" stood over the party but never registered in `EnemyManager._EnemyList`, so nothing engaged (needs a real hit to provoke) - not done. Hire dialogs open by themselves when unhired pawns loiter near the player (one opened right after load with no script running).
- v46 (2026-11-09 evening, written with the game closed, NOT run yet): **memory and release mode.** The save keeps the pawn's Job09 skill slots and unlocks (run 24) but reads the old staff (1500) back into the Main slot at every load, so v46 keeps `reframework/data/PawnTrickster/pawns.json` per pawn CharacterID: censer last held, Job09 weapon-skill slots (`SkillContext.EquipedSkills[9].Skills`), skill levels (`getCustomSkillLevel` for 92-99/118-120), core skills (`isNormalSkillEnable` 34-37) and augments (`AbilityContext.EquipedAbilities[9].Abilities`, `setAbility(id, i)`), the same fields SkillCreator's VocationState.lua saves for the Arisen. Recorded every 3 s once settled; empty reads never erase a record. At enable the game's data wins and pawns.json refills only empty categories; the censer order is equipped > remembered > best owned > starter (created only when she owns none; censers = `ItemWeaponParam._Job & 512`, fallback 2103-2105). `debug` (default false) keeps the old forced set (97/95/99/92 at level 1); release mode gives a new Trickster pawn the rank-1 skills once, read from `GuiManager.CustomSkillJobDefineDictionary[Job09]` level-1 `_UnlockRank <= 1` (fallback 95 + core 34), and the AI gates rally/delusion/screen/shroud on the skill being equipped. The menu panel (now "Pawn Trickster") has a debug checkbox, a censer list (pawn's and Arisen's censers, "equip on pawn" through passItem + the Main-slot write) and the remembered record. Caveat found while reading: SkillCreator's "vanilla" Trickster table (95 r1, 92 r2, 97 r3, 94 r4, ..., 118/119/99/120 unobtainable) disagrees with run 64 (Espial Incense = 119 bought at rank 4), so the unlock ranks on this install may be SkillCreator's, not vanilla. Not handled: a second save load in the same session (death reload, title load) - auto-enable runs once per launch.
- Pawn voice (2026-11-09, game closed): pawn speech is in `natives/stm/streaming/sound/wwise/pawntalk_resident_<f1..f4|m1..m4>[_verylow|_low|_high|_veryhigh].spck.1.x64.<lang>` (AKPK, 2422 streamed WEMs per voice in English, 84-92 MB) plus quest/end banks; the only Job09 sound bank is `job09_skill_es` (effects). `mods-src/EnchantNoHaze/pakread.py` extracts them from re_chunk_000.pak with `DD2_STM_Release.list`. No decoder (vgmstream) is installed.
- Official Trickster ranks (Fextralife wiki, read 2026-11-09), matching the game's `CustomSkillJobDefineDictionary[Job09]` read in run 58 level for level: weapon skills (level 1 / level 2): 95 Sweeping Shroud r1 100 Dcp / Suffocating Shroud r4 1000; 92 Delusory Screen r2 300 / Illusive Divider r4 1000; 97 Aromatic Rally r3 450 / Aromatic Resurgence r5 1300; **94 Espial Incense** r4 700 / Visitant Aura r6 1600; 93 Fickle Floor r5 1100 / Tricky Terrace r7 2500; 96 Latching Effigy r6 1800 / Binding Effigy r8 2500; 98 Scented Alarum r7 2500 / Fragrant Alarum r9 3000; 99 Dragon's Delusion = Maister scroll Theurgist's Rite (Luz); Curing Cloud (Dark Arisen update, rank not listed). Core skills: rank 0 free (Beveiling Fumes, Effigial Incense, Effigial Snuff, Invoking Essence, Enthralling Aroma); Mending Vapor r1 150 (34), Drifting Brume r2 250 (36), Effigial Quickburn r3 400 (37), Trailing Aroma r4 600 (35), Buoyant Brume (Dark Arisen update). Augments: Detection r2, Enlightenment r4, Fugacity r6, Obfuscation r8, Allure r9. Starting censer: Bewitching Balm. Correction: Espial Incense is 94, not 119 (line 11 above); the "Mists of Slumber" / "Drowsing Fumes" names seen in the guild on this install are not vanilla names (probably SkillCreator renames).
- Pawn talk playback (2026-11-09 evening, live probes at the Borderwatch inn, seq 14313-14319):
  - Catalog: `TalkManager._PawnCommonTalkMonologueCatalog:get_MergedCatalog()` is a Dictionary of RefCounter; data in `value._Item._CategoryList` (an array) -> `_Segments` -> `_Candidates` (`_MsgId` Guid, `_Personality1-4`). `via.gui.message.getName(guid)` gives names like `PawnTalk_ACT_Hate_01_000_000`. Category hash = murmur3 (seed 0xFFFFFFFF) of the UTF-16LE category name. Dump: `reframework/data/dmo_dev/pawn_talk_catalog.tsv` (10,158 lines).
  - Flow: `PawnManager.TalkController` (`app.PLPartyTalkController`) evaluates requests, keeps `_TalkHistory` (per category hash, with `CooldownInterval`) and `_LastPlayedCategoryHash`, then `_Entity` (`TalkEntity`) `play(Character speaker, PawnTalkMonologueSegmentData seg, byte monoIndex, uint categoryHash, bool)` adds the subtitle (`GuiManager.addTalkSubtitleMessage`) and plays the voice via `_VoiceController` (`app.WwiseVoiceController`) from the speaker's voice-preset bank.
  - Request path that the controller accepts: `sdk.create_instance("app.PLPartyTalkController.PawnTalkRequestInfo")`, `set_Request(1)` (Category), `set_Timing(t)`, `set_Hash(h)`, `set_Speaker(mainPawnChara)`, then `info:call("request(app.PLPartyTalkController)", tc)`. For `PawnTalk_RUB_Reuse_01` (timing 2) it set `_LastPlayedCategoryHash` and added a history entry; a repeat a few seconds later was ignored (cooldown). The line starts about 2 s after the request (the first screenshot at 1.5 s was too early). This path only serves OnReaction categories: a Category or Selector request for an OnAI category such as `PawnTalk_ACT_Hate_01` (timing 1) never reaches `isRequestDisabled` and leaves no trace, in or out of combat. `TalkManager.getPawnCategory(timing, hash)` returns nil for every hash tried.
  - **Never call `TalkEntity.play` directly**: it threw inside `addTalkSubtitleMessage`, and 5 s later the game stopped presenting frames (REFramework looped on "Last chance encountered for hooking"; process alive, image frozen) and had to be killed. Save unaffected.
  - **Verified by subtitle (2026-11-09 21:00, seq 14320-14336, sound was off so the Subtitles option was turned on for the test):** the request path above played `PawnTalk_RUB_Reuse_01` ("Over here, if you please.", pawn portrait + subtitle), and the direct overload played the combat line `PawnTalk_ACT_Hate_01` ("I'll hold the enemy's focus!") at the arena with no enemy engaged.
  - **Force path for any category, OnAI included:** `tc:call("requestPawnTalk(app.PawnTalkMonologueCategoryData, app.Character, app.AITarget, System.Boolean)", catObj, mainPawnChara, nil, true)`. `catObj` is the category object from the merged catalog (walk `_CategoryList`, match `_Name`; keep it with `add_ref`). With the last bool `true` it returned true and the line started 0.27 s later; with `false` it returned false. None of `canRequestPlay`, `isTalkingTooMuch`, `isRequestDisabled`, `evaluateRequest` runs inside it, so the mod must keep its own cooldown. Other overloads: `(TalkTiming)`, `(PawnTalkRequestInfo)`, `(List<CategoryData>, Character, AITarget, bool)`, `(List<CategoryData>, Character, AITarget, TalkTiming, bool)`.
  - TalkTiming: 0 Invalid, 1 OnAI, 2 OnReaction, 3 OnChangeWorldArea, 4 OnChangeArea, 5 OnChangeLocalArea, 6 OnChangeUIArea. Category fields: `_Name`, `_Timing`, `_PriorityType` (Hate_01: 1200), `_IsEnabled`, `_Segments`.
  - Hooks (from the Nexus mod Pawn Chatter Control, read as a sample): `app.PawnManager.onStartPawnTalkMonologue` (`args[3]` = category object) fires when a line really starts, the reliable "it played" signal; a post-hook on `PLPartyTalkController.isRequestDisabled(category)` returning `sdk.to_ptr(0)` / `sdk.to_ptr(1)` allows / blocks a line; `_IsEnabled = false` mutes a category.
  - Options: `OptionManager._OptionItems[85]` is SubtitleDisplay, 74 DisplayPawnTalking, 49 PawnVoiceVolume; set with `item._ApplyValueModel` / `_FixedValueModel` `set_StringValue("ON"|"OFF")` (valid enum members only). Subtitles appeared without `applyValues`; set back to OFF after the test.
  - New lines that the game does not have: the Nexus mod Warrior Sound Redesign ships `reframework/plugins/shared_audio.dll` (miniaudio, loaded with `package.loadlib`; `sa.load` a file under `reframework/data`, `sa.play`, `sa.set_gain`), which plays files on the default device outside Wwise (2D, not affected by the game's volume sliders). That, plus our own subtitle, is the route for generated lines; the other is replacing WEMs in the voice banks.
  - Fitting existing lines: `PawnTalk_ACT_Hate_01` ("I'll hold the enemy's focus!", "I shall draw the enemy's attention!", one per personality) suits Sweeping Shroud and the decoy.

## Run of 2026-11-09, 21:12-00:12 (v47 to v47k, 0.2.0)

- The keep-distance (stance) decision executes until something ends it; `DecisionExecutor.forceEndDecision()` is safe (dozens of calls) and the next evaluation picks a released slot.
- Never rewrite an ActNo command's `ActionID` at run time: the third rewrite crashed about 2 s later in the local-frame GC (DD2.exe+0x5244a30..0x5245081, twice). One slot = one action for the whole session; other actions go through `selector:requestAction(name, layer)`.
- Latching Effigy (`Job09_CastPossessionSmoke`, `IsUpdateAimTarget` true) flies to the decision's aim target. Latched 5 times, each with that enemy 4-6 m from her on her level; missed at 6.8-9.4 m, 7-9 m below, when `Job09_Transfer` cut the 3.2-3.7 s cast, and with an aim target 33 m away.
- Espial Incense: `Job09_CastTripFregrance`, later `...End`; Scented Alarum: `Job09_CastDetectFregrance` on layer 1, stopped with `UpperBodyDefault` on layer 1; Dragon's Delusion: `Job09_CastSmokeDragonEnd` after 5 s.
- The game rebuilds a pawn's decision lists when the battle state changes; our wrappers come back with cooldown timer 0. A gate that is only a cooldown write leaves a window: she cast Latching Effigy without owning it (23:31:28). v47k builds no slot for an unequipped skill (pack with 5 decisions for slots 97 95 99 92; 16 Job09 actions over two rebuilds, none unequipped).
- Crash `DD2.exe+0x52590e4` the second the pack was added (23:36:16), same offset as run 14 and three other crashes on 2026-11-09; the next launch with identical files passed. Intermittent, cause not found.
- In-session reload (death screen, v47i) crashed in the graphics stack (dxgi / D3D12Core / nvwgf2umx / dd2clouds / VollmondSky / NvCamera64); just before it the script read the destroyed decoy twice a frame (`via.Component.get_GameObject` InvalidOperationException). v47j: nothing runs outside the game phase, the soft reset writes nothing back into the old pawn's objects. The reload was not tried again.
- A dead main pawn (`DieLoop`) is left alone, no errors. An autosave can be written while she is dying: the next load then starts with a dead pawn.
- Release mode checked: memory across a relaunch (censer 2104, slots 97 95 99 92), `PawnTrickster.disable()` (job 3, staff 1500, 6 packs, 27 goal rows restored), `enable()` again in the same session.
- Test hazards: the spawner can return true and spawn nothing; a tutorial window opens after every load; Space taps at load can open a pawn's hire dialog in the Borderwatch inn (cancel through `GuiManager.TalkSelect`); goblins spawned inside the inn are killed by NPCs.

### Last checks of the run (23:46-23:54)

- Fresh install: with `reframework/data/PawnTrickster/config.json` and `pawns.json` deleted, the script wrote both at
  the first load (79 config keys with the release defaults, the pawn's own censer and four skills), enabled her and
  wrote nothing to the log. A goblin fight on that install: 5 picks, 2 preemptions, no error flag, decoy out.
- `PT.cfg.log = true` from the console turns the log on for the session without touching the file.
- Spawner: "Cyclops (weak)" returned true twice and never appeared in `EnemyManager._EnemyList`. "Harpy" spawns,
  but both stood idle on the ground and the battle state went to 0: not a flying-enemy test. Large and flying
  enemies need a real encounter in the world.
- Soak on the fresh install, 23:57-00:02 (six weak goblins in two waves, the Arisen healed from the console): 20
  casts (Aromatic Rally 7, Delusory Screen 8, Dragon's Delusion 3 with 2 timed ends), 43 picks and 20 preemptions
  since the load, no error line, no error flag. No Sweeping Shroud in that stretch (the decoy stayed out).
- A second reload could not be triggered: `HitController.setHpValue(1.0, false)` (from `Character.get_Hit`) set the
  Arisen to 1 HP but the goblins did not land a hit in a minute, and `Character.requestFallDead()` did nothing
  on flat ground. The in-session reload stays unverified.
- End of run: Subtitles read OFF / OFF, game closed, save restored from the 21:19 backup, the original
  `config.json` (50 keys, `log` true) and `pawns.json` put back.
- Last launch, 00:05-00:08, with the user's own `config.json` put back (50 keys, `log` true) and v47k: the pack
  with 5 decisions was added at 00:06:31, status `job=9 ... enabled=true`, no error line. A stray pawn opened its
  hire dialog (cursor on "Hire") while the Arisen stood idle in the inn; nothing was pressed, the game was closed
  with the dialog open. The save files were byte-identical to the backup before and after the copy, the config
  was put back once more (the game had rewritten it at 00:05).

## Run of 2026-11-10, 08:57-13:57 (5 h, v47k -> v47z = 0.2.1)

### The random crashes: found and fixed (v47m)

- Both crash families are the same mechanism. `DD2.exe+0x52590a0` is the managed-object release (`lock dec [obj+8]`,
  skipped when the count is negative); `+0x52590e4` faults reading the header of an object that is already freed.
  `+0x5244a30` (called at the end of every module entry) walks the table of frame-local objects and faults at
  `+0x524507e` / `+0x5245081` on an entry whose memory is gone. Two `+0x52590e4` stacks mapped with a C# probe
  (nearest method below each address): 23:36:16 = `PawnAIBlackBoardController.update` ->
  `AIBlackBoardController.updateImpl` -> `AIGoalPlanning.checkSituation` -> `updateSortTarget` -> list clear -> release;
  21:21:02 = `NavigationManager.onUpdate` -> Dictionary remove -> release. Main thread, the game's own update.
- REFramework reference counts, measured in game with `obj:read_dword(8)`: a fresh `sdk.create_instance` /
  `create_managed_string` / `MemberwiseClone` object is frame-local (negative count, an index into the frame table);
  `add_ref()` makes it 1, is idempotent, and that reference is given back when the Lua value is garbage-collected;
  `add_ref_permanent()` adds one that stays; `set_field` on an object field counts the new value and releases the old
  one; an array store `arr[i] = o` adds 2; `add_ref()` on a MemberwiseClone also counts each reference it copied. A
  field-by-field copy of a vanilla Decision takes +1 on every child and gives exactly that back when it is freed.
- **The rule that crashes:** an object created with `sdk.create_instance`, given `add_ref()` and then freed by the Lua
  garbage collector **in the frame it was created in** corrupts the engine's frame-local table. Console experiments:
  400 such objects crashed within 1 s (`+0x5272817`, inside the routine that turns a local object global), 10 crashed
  within 8 s, 1 survived; the same 400 objects freed in a later frame, or holding a permanent reference, or with no
  reference at all, did nothing.
- The script had such objects: `build_actno_pack` returns an `ActInterPackData` of which only `_Pack` is used (one
  wrapper dropped per slot at every enable: the crash "the second the pack is added"), and every decoy re-summon and
  Espial send built a `SmokeDecoy.StartInformation` dropped right after the call (the crashes 1-2 s into a fight,
  7 occurrences at `+0x524507e` / `+0x5244b01` since 2026-11-08). Whether Lua collected them inside their frame was
  the dice roll; a second load made it likely (the soft reset leaves a lot of garbage to collect).
- v47m: `PT.keep(o)` = `add_ref()` then `add_ref_permanent()` on every object the script creates (34 sites). The
  objects are never freed; the leak is a few hundred small objects per load and one per decoy re-summon. Checked in
  game: 60 fresh objects + 20 clones through `PT.keep`, dropped and collected in one frame, no crash.
- **Rule for any REFramework Lua mod here:** never let a created managed object die in its creation frame; give
  objects handed to the engine a permanent reference.

### Second save load in one session, and the crash at the title screen (state at 11:15; resolved further down)

- The mod's side works: return to title through the pause menu (below), load again: `=== soft reset`, 27 goal rows
  restored, auto-enable, censer equipped again, pack with 5 decisions added (09:27:35-09:27:50 on v47l, again at
  10:59:11-10:59:30 on v47r). The same reset runs when the game rebuilds the pawn inside a session (a long warp, a
  fall into the void that puts the party back): five such resets on v47n-o, each followed by a normal enable, two of
  them followed by the cyclops and harpy fights below.
- **Returning to the title crashes on this install while the pawn is enabled.** 11 returns with her enabled: 8
  crashes, all in the render stack (nvwgf2umx / D3D12Core / dxgi / dd2clouds.addon64 / VollmondSky / NvCamera64 /
  renodx-dlss) 2 to 12 s after the title appears, once as the box "Fatal D3D error (24, DXGI_ERROR_DEVICE_REMOVED)
  DeviceRemovedReason 0x887a0001". 3 returns with the script renamed away: 0 crashes. 3 returns after
  `PawnTrickster.disable()` (8 s before leaving): 0 crashes. 2 returns with only the Job09ActionSelector removed by
  hand some seconds before leaving and no fight in that load: 0 crashes.
- What did not prevent it: giving back only the DecoyHandler at the moment the phase is left (v47l: 1 survived, 3
  crashed); putting only the previous weapon back 5 s before (crashed); the full data teardown at the moment the
  phase is left (v47r: packs removed, 5 shell node lists, 27 goal rows, own handler: crashed); the same plus the
  selector taken out at that moment (v47s: crashed, mid-fight); the selector removed by hand a minute before, then a
  fight, then the return (crashed). Cause not found. What the survivors share: the pawn was no longer driven for
  several seconds before leaving (`disable()`), or had not fought in that load.
- v47s keeps the teardown (`V.teardown`: the shared vanilla data is back to what the game loaded before the scene is
  unloaded, and auto-enable sets her up again when a pawn is back); it is cleanup, not a fix for this crash.
- Workaround for users: press "disable" in the mod's panel before quitting to the title.
- The Job09ActionSelector the script adds to her selector list (step 3) is not needed for combat: with it removed she
  summoned the decoy and cast Rally and Delusion as usual (11:05-11:06). It is still added (every other test ran with
  it); dropping it is a candidate for the next version.
- The `via.Component.get_GameObject` InvalidOperationException burst during the unload is another mod (it is there
  with the script off).
- How to drive it without focus: `GuiManager:requestGuiType(12)` opens the pause menu, `ui060101:returnTitle()` sets
  `IsReturnTitle`, `ui060101:requestEndMenu()` then goes to the title in about 10 s; Space taps load from there. The
  menu can refuse to open while a hire dialog is closing: check `FlowNow == 6` and retry.
  Dead ends: `MainFlowManager.requestLoadGameData(slot)` hangs in phase StartLoad (21) on a black screen;
  `requestStartType(4 = BackLatest)` throws, fades out and removes the player (StartType: NewGame 0, Latest 2, Base 3,
  BackLatest 4, BackBase 5, BackStart 6, Restart 11). The Arisen could not be killed for a death-screen test: a 45 m
  and a 60 m fall at 1 HP did no damage.

### Voice lines (v47n)

- "It really started" = a hook on `app.PawnManager.onStartPawnTalkMonologue` (args[3] = category). Categories of talk
  groups 27 and 82 (`Skill_Guard_07`, `Rescue_02`, `CustomSkill_01`, `AttackVoice_01`, `HoldDown_01`) are accepted by
  `requestPawnTalk(cat, pawn, nil, true)` (returns true) and never start, in or out of battle; `isRequestDisabled`
  is false and the group is not in cooldown. So the 0.2.0 Delusory Screen line never played.
- Started and read as subtitles on Ethera: `ACT_Hate_01`, `CMN_Search_01` ("Allow me to check whether there's aught
  nearby."), `ACT_TalkInBattle_01` ("Let us dispense a crushing defeat!"), `ACT_ChanceTime_01` ("All together now! We
  attack as one!"), `ACT_ChanceTime_04` ("Our foe has been thrown off balance!"), `ACT_Worried_01` ("Arisen! Are you
  all right!?"), `ACT_OnSightEscapingEnemy_01` ("We've got them on the run!"), `ACT_CoopAttack_01` ("You hold the
  enemy's focus, and I shall strike them down!").
- v47n lines: taunt Hate_01, rally TalkInBattle_01, delusion ChanceTime_04, effigy (when it latches) ChanceTime_01,
  screen Worried_01 (only when the screen is cast for the Arisen), alarum Search_01. A 0.2.0 `config.json` gets the
  new keys and loses the dead screen line at load. `PawnTrickster.say("rally")` says a line now (test).

### Running unattended without leaving the game stuck

- A live DD2.exe proves nothing: the fatal D3D box keeps the process alive. `tools/watchdog.ps1` (scratchpad; every
  5 s, kills DD2 when one of its windows is a `#32770` dialog or is titled Crash / Fatal / Error) ran for the session.
- `reframework/autorun/zz_pt_hire_guard.lua` (temporary, deleted at the end): cancels a pawn hire dialog
  (`GuiManager.TalkSelect` = `app.ui021601`, `FlowNow` 0 = open, 1 = ended; `IsDisp` stays true after it closed),
  sends an open tutorial window (`app.ui080101`, flow Exec 3) to `setFlowId(app.ui080101.FlowId)` 4, and sets the
  option DisplayTutorial (OptionID 80) to OFF in memory. The click flags on the tutorial panel only page it.

### First start of a brand-new pawn (v47p, v47q)

- Tested with the save of 2026-11-08 21:23 (the pawn is a Mage that never was a Trickster) and no `pawns.json`.
- Bug in 0.1.0 / 0.2.0: she got Sweeping Shroud **and the cut skills 118 and 119** in her slots. The game's table
  (`GuiManager.CustomSkillJobDefineDictionary[9]`) lists them with `_UnlockRank` 0 and `_OpenByGm` true, and the
  starter rule took every level-1 entry with rank <= 1. v47p skips `_OpenByGm` entries.
- A pawn that already has them loses them once (`rec.cut_fix`): slots cleared with `setSkill(job, 0, slot)`, levels
  cleared in `HumanSkillContext.EnabledCustomSkills[id].Level` (`setCustomSkillEnable(id, 0)` does not unlearn).
  Checked with 118 / 119 put on her by hand before the enable: `skills: cut skills removed ... 118 119`, levels
  restored from the file, `skills: slots 95 0 0 0 0 0`.
- Core skills: `isNormalSkillEnable(34)` answers false on a pawn whose `EnableNormalSkills[34].IsEnable` is true, so
  the memory file never recorded core skills. v47p reads the list itself; `pawns.json` now has `"normal": [34]`.
- First start on v47q: `job: requestChangeJob(9) true`, `weapon: censer 2104 (starter)`, `skills: rank-1 table game
  95 core game 34`, `skills: new Trickster pawn, rank-1 skills 95 core 34`, pack with 2 decisions (summon, stance);
  a one-minute fight as a rank-1 Trickster: decoy out 98 % of the fight, 8.6 m mean distance, taunt line, no error.

### Real large and flying enemies (v47n, release mode, her four skills)

- Monster groups with world positions: `reframework/data/IGO/data/groups.json` (the user's IGO mod: 631 groups,
  name, x / y / z, count). Cyclops at (85.7, 259.6, -2805.5), harpies at (28.5, 187.6, -2408.8), ogre at
  (-186.6, 106.7, -2057.8), golem near (-105, 87.8, -1996.7).
- Cyclops (HP 39,992), 3 minutes: decoy out 83 % of the battle ticks, pawn 9.4 m from the nearest enemy on average
  (57 % of the time at 6-13 m, 10 % under 4 m), Dragon's Delusion 4 (3 timed ends), Delusory Screen 3, Aromatic
  Rally 3, 5 stance preemptions, she was downed 3 times and carried on after each revive (a console heal), delusion
  and screen lines, no error line. The Arisen was held unkillable for the test (`HitController.set_IsNoDie(true)`).
- Three harpies and three goblins, 2 minutes: decoy out 100 %, 6.7 m on average (32 % under 4 m: harpies swoop),
  Rally 3, Delusion 2, Screen 1, one beckon, she was put to sleep once and carried on, no error line.
- Long warps: `Character.warp` to a place that is not streamed in drops the party through the ground and the game
  puts it back; hold the Arisen above the spot for 6 s (re-warp twice a second), let her land, go back for the pawn
  and warp both. After a long warp the game can create and remove the pawn every few seconds until she stands next to
  the Arisen: v47o waits for the same pawn object on two checks before enabling.

### Rank 4-7 skills again (v47o-q, debug set 96 93 94 98)

- Fickle Floor's ledge rule fired in a real situation: on a cliff edge above a lake, goblins 8 m away beyond the
  edge: `floor: ledge found 2.5 m ahead`, `floor: cast requested (nearest enemy 8 m from her)`,
  `Job09_CastSmokeGround`. `PawnTrickster.ledge_probe()` at that spot: ledge at 2.5-5.5 m toward the lake in four
  directions, flat in the other four; all flat at the arena.
- Latching Effigy: `no enemy in reach (nearest 7.4 m): stance held 8 s`, window open at 5.0 m, cast, latched 2 s
  later, released after 2.8 s (weak goblins die fast under their own kind), the stance stayed blocked from the
  approach to the release. `effigy_hold` (12 s) cannot be measured on enemies that die in 3 s.
- With only the two idle spawned goblins left 15 m and 24 m away she did not retry: the rule wants two enemies within
  15 m of her.

### v47t-v47w: after the commit of v47s (11:15-11:45; the title crash is resolved in the next section)

- **v47t: the Job09ActionSelector is no longer added** (`job09_selector`, default false). Without it she summoned the
  decoy, cast Rally and Delusion (release set), and with the debug set cast Fickle Floor twice, Latching Effigy,
  Espial Incense (trance, decoy sent, End) and Scented Alarum (layer 1 request, stopped). Every Job09 action runs by
  name under `NoJobActionSelector`.
- **Title returns on v47t-w** (teardown at the phase change, no added selector): decoy summoned on request at the inn,
  no enemies: held. Fights before the return: crashed, held, held (v47t), held (v47v), crashed (v47w with
  `stance: false`, so the cloned stance command is not the cause either). 2 crashes in 6. All returns of the day with
  the pawn enabled: 11 crashes in 18; after `disable()`: 0 in 3; script off: 0 in 3.
- Two more failures in later loads of a session, both after surviving title returns:
  - 11:29:10, fourth load, `DD2.exe+0x552832a` = `PLPartyTalkController.updateRequestList` -> `evaluateRequest`, the
    second the taunt line was requested. The script cached talk category objects (`V.cats`) for the whole session;
    v47v drops the cache at every reset.
  - 11:39:45, second load: building the third slot threw (`get_element` not callable on the node list of the pack the
    script had just built), `step_ai` was retried every frame (each try borrowed the shells again), crash 2 s later
    (dump only, no stack). v47w: one attempt per load, the shells are given back, she keeps the vanilla pawn behaviour
    for that load.
  Read together with the title crashes: something is left inconsistent when the scene is unloaded while she is
  enabled, and it shows either at the title or in a later load. Lead not followed for lack of time: the script's
  permanent objects (decision copies, the stance clone) hold counted references to objects that live inside vanilla
  `.user` resources (conditions, targets, the KeepDistance command's JumpRequester and Timer); what the engine does
  with those resources at unload is unknown. `disable()` a few seconds before leaving is the only thing that held
  every time.
- v47u: the Lua re-summon of a sleeping decoy is skipped while her own `Job09_SummonDecoy` action is running and for
  4 s after it started (the action creates the instance, which reads as "not appeared" for a moment).
- `update_summon_gate` is defined above the script's `local last_action`: a `last_action` written there is a global
  and always nil. `PT.state.act_now` (set in `V.on_action`) is what that function can read.
- Autosaves: the game saved during arena fights; the next launch then started at the arena with the three spawned
  goblins around the party. Restore the save backup before any test that needs the inn start.

### The title-screen crash: two causes fixed, one test-setup cause found (11:47-12:28, v47w-v47z; NOT closed, see the correction below)

Two things in the script and one in the test setup, separated by 28 title returns on the teardown builds:

1. **State the script left in the scene** (fixed by v47r-v47t): with the pawn enabled and no fight in that load, the
   return crashed twice (v47k, v47q) and then held every time once the vanilla AI data was put back at the phase
   change and the Job09ActionSelector was out of her selector list (2 returns with the selector removed by hand on
   v47r, 1 with the decoy out on v47t, 1 on v47x).
2. **The test spawner** (`PawnTrickster.spawn_enemies`, which calls Skill Maker's `_NickCore/EnemySpawner`): its
   enemies are generated outside the scene's own tables and outlive the scene unload. On the teardown builds, fights
   against spawned goblins followed by a return crashed in 3 of 6 when nothing cleaned them, and held in 11 of 11
   when the spawner's `destroy_spawns()` ran once the title was up (3 by hand on v47x, 6 by a stray test loop on
   v47w / v47x, 2 by the script on v47z). The same call just before leaving, or 4 s after leaving, crashed in 2 of 3.
   v47z queues the cleanup at every reset and runs it when the title has been up for 6 s; it does nothing unless the
   test helper was used.
3. Not the cause: the fight logger (v47x keeps the test helpers inside the InGame phase anyway; a clean return with
   it on still crashed until the spawner cleanup was added), the cloned stance command (`stance: false` crashed too),
   the decoy instance (held with only the decoy out).

- A stray test loop: `TaskStop` on the background soak script did not stop its bash loop, which went on sending
  heals, spawns and `fightlog(true)` every 8 s from 11:47 to 12:03, also at the title screen. `tools/soak.sh` now
  exits on a stop file. Check `Get-CimInstance Win32_Process` for leftover `bash ... soak.sh` after stopping a task.
- Several loads in one session on v47w-v47z: five loads with a fight and a voice line in each (11:49-11:58), then
  3 + 2 + 3 more on v47x-v47z; no talk-controller crash and no failed rule pack after v47v / v47w.

### Correction (12:58-13:10): the title return is NOT closed

(Closed in the afternoon run: two faults outside the script, see "The crash at the title screen and on a death reload" below.)

- 30-minute soak on v47z, third load of a session (12:28-12:58, three weak goblins kept on her, the Arisen healed
  from the console): 1,736 battle ticks, decoy out 100 %, 9.6 m from the nearest enemy on average (89 % of the time
  at 6-13 m), Aromatic Rally 71, Delusory Screen 22, 52 stance preemptions, 26 voice lines, no error line. The return
  to the title after it held (spawner cleanup at 12:58:43).
- Then two trials in fresh launches with **no test spawner at all**, a 30 s fight against the world harpies at
  (30.3, 183, -2394.5) reached with the long test warps:
  - 13:03: 7 picks (Rally 2, Delusion, Screen with its line, a beckon), plain return: **crash** about 10 s after the
    title appeared.
  - 13:08: 4 picks, `PawnTrickster.disable()`, 8 s, return: **crash** as well. `disable()` only held in the three
    idle trials of the morning.
- So what is established on v47t-v47z: idle returns hold (4 of 4); returns after arena fights against spawned goblins
  hold when the spawner's `destroy_spawns()` runs with the title up (12 of 12) and crash in half the cases when it
  does not (3 of 6, plus 2 of 3 when it ran too early); returns after a fight against world enemies crashed in 2 of
  2. Those two trials differ from the arena ones in three ways that were not separated: real enemies (harpies in
  the air, 12-18 enemies loaded), the long hover / warp sequence with the game recreating the pawn before the fight,
  and no spawner. The section title above ("resolved") was written before these two trials and is wrong; the commit
  message of 3d16d93 says "resolved" too.
- What a player should do until this is understood: quit the game instead of returning to the title, and after a
  death load from the death screen only if they accept the risk (not tested at all).
- Next steps that would separate the causes: a return after a fight against world enemies reached on foot or from a
  save made next to them (no warps); the same with the script renamed away (does the vanilla game with this mod list
  crash at the title after a harpy fight?); the same with `PawnTrickster.disable()` right after the load (pawn never
  enabled in that load).
- **Control, 13:13-13:15: the same harpy trial with `PawnTrickster.lua` renamed away** (script not loaded at all, same
  hover / warp, 30 s in the fight, plain return): **crash** 4 s after the title appeared, same address
  (`7ff94305d8e0`) and same stack as every title crash of the day (nvwgf2umx / D3D12Core / dxgi / dd2clouds.addon64 /
  VollmondSky / NvCamera64 / renodx-dlss). So the crash after the open-world harpy fights is not the pawn script: it
  is this install's render stack at the title after that scene (3 of 3 there, with and without the script). What
  the script contributed (idle returns at the inn: 2 crashes before v47r, 0 of 4 after) is fixed; whether the arena
  crashes without the spawner cleanup are the spawner or the same render-stack problem is not decided (12 of 12
  held with the cleanup, 3 of 6 crashed without).
- End of run (13:15): game closed, save byte-identical to `DD2_save_backup_20261110_run5h`, the user's own
  `config.json` and `pawns.json` put back, `zz_pt_hire_guard.lua` and the scratch dumps deleted, console idle,
  watchdog stopped. Subtitles read OFF / OFF at the last launch; the tutorial option was only changed in memory.
- **A Trickster Arisen next to her (13:17-13:20, v47z):** the Arisen was switched from Thief to Job09 with
  `setJobQualified(9)` + `JobChanger:requestChangeJob(9)` before the script enabled. Log: `decoy: the Arisen is a
  Trickster, keeping the pawn's own handler`, `decoy: shared the Arisen's PrefabController true`, pack with 5
  decisions. A one-minute goblin fight: her own decoy out 89 % of the battle ticks, Rally 1, Screen 2, 4 picks, no
  error line. (The Arisen had no censer and did nothing herself; both casting at once was not tried.) Game closed
  and state restored again at 13:20 (the session had autosaved the Arisen as a Trickster: 2 save files put back).

## Run of 2026-11-10, 13:56-17:56 (4 h, v47z -> v48b = 0.2.2)

Asked for: the crash fix, and everything not tested yet except the Arisen and the pawn both casting Trickster skills.
Tools of this run are in the session scratchpad (`tools/trial.sh`, `harpy.sh`, `keys.ps1`, `watchdog.ps1`); the temporary
hire / tutorial guard `reframework/autorun/zz_pt_hire_guard.lua` was deleted at the end.

### Nothing keeps the Arisen alive

- No script in `reframework/autorun` sets a no-die flag outside the test helper `r/safe.lua` of these runs. At load
  her hit controller reads `IsNoDie` false, `IsAttackNoDie` false, `<IsInvincible>` false; `test_guard` is 0.
- She could not be killed from the console because the calls do nothing: `setHp(0, true, 0)`, `setHpValue(0, true)`,
  `setHpValue(0, false)` leave her HP as it was, and a fall after a warp does no damage. `setHpValue(1.0, false)` sets
  1 HP and the next real hit kills her (the cyclops at 14:01:39; three saurians brought next to her at 15:04:19).

### The crash at the title screen and on a death reload: two faults, neither in the pawn script

One script was used for every trial: fresh launch, save load, 30 s among the world harpies at (30.3, 183.5,
-2394.5) with the Arisen unkillable, return to the title through the pause menu, watch.

| trial | clouds add-on | DD2CrashTrace | result |
|---|---|---|---|
| 13:03, 13:14 (script off), 14:02 (death reload at the cyclops) | old | old (not installed on 4.2) | crash in `nvwgf2umx.dll+0x50d8e0` |
| 13:09 | old | old | crash `DD2.exe+0x971cbf2` |
| A1 14:09 | removed | old | crash `DD2.exe+0x971cbf2`, 15 s after the title |
| D1 14:38 | old | old | "GPU device removed" 5 ms after two "depth SRV for the before-fog pass" lines, Fatal D3D box |
| B1 14:25, B2 14:29 (second load), B3 14:46 | fixed | code patch at `0x971cbe0` | held 45-60 s |
| C1 14:33 | old | code patch at `0x971cbe0` | held 60 s |
| X1 14:42 | fixed | old | held 60 s, "view dropped" logged |
| V1 14:52 | fixed | exception guard, no code patch | held 90 s, "view dropped" logged |
| V2 15:58, V3 16:03 | fixed | exception guard | held 90 s and 120 s (V3: the kept view still named a live buffer) |

**Fault 1: the clouds add-on used a depth view of the scene that was gone** (`mods-src/VolumetricClouds/addon/
dd2_clouds.cpp`, fixed there; the full account is in that mod's README, last section).
- The crash stack was read with a map file from a rebuild of the same source (6 bytes differ from the installed
  binary): `on_draw` > `draw_clouds+0xb02` > `own_dsv_srv+0x1b1` > ReShade `create_resource_view` > D3D12 > driver.
  The driver faults on `movzx eax, word ptr [rsi+0x2c]` with rsi = 0: a shader view created on a resource whose
  driver object no longer exists.
- `g_sky_dsv` kept the sky draws' depth view across command lists. ReShade keeps a view's entry after its resource
  is destroyed (the erase in `device_impl::unregister_resource` is `#if 0`), so the lookup returned a dead pointer.
  The game destroys the scene's depth buffer 7-8 s after leaving the scene; the title scene's fog composite binds no
  depth view and used the kept one. That is the "4-10 s after the title appeared" of the morning's notes.
- With the fix the add-on logs the event instead of crashing: "the depth buffer ... of the kept sky depth view was
  destroyed: view dropped" at 14:42:26 (X1), 14:52:21 (V1), 15:14:47, 15:42:17; on the death reload of 15:04 a
  kept view was used 0.3 s before its buffer was destroyed, without harm (the lookup holds the lock the destroy
  notification takes).

**Fault 2: `DD2.exe+0x971cbf2` is the crash `DD2.exe+0x9717cd2` of 2026-11-01..03, unguarded since the 4.2 patch.**
- The function moved from `0x9717cc0` to `0x971cbe0` (same bytes; release function `0x523a8e0` -> `0x5247c40`).
  `DD2CrashTrace.dll` logged "does not match the expected code (other game build): not installed" at every launch
  since. The record it destroys has a set and b null, as before (rcx = 0 at `mov rax, [rcx]`).
- First try: the plugin's 14-byte jump patch retargeted to the new address. Four title returns in a row held (B1, B2,
  C1, B3), C1 with the OLD clouds add-on, and the guard logged no hit. In B3 the add-on's log shows a live depth
  buffer bound at the title and no destruction of the old one. Without the patch the old buffer was destroyed 7-8 s
  into the title in 5 of 7 logged returns (D1, X1, V1, 15:14, 15:42; not in V3 over 120 s, and not at 15:24 from
  inside the inn). 0 of 4 against 5 of 7 is too little to say the patch changes what the game does at unload (V5,
  without the patch, later showed B3's picture); it was taken out anyway, because the handler below does the job
  without writing to the game's code (the 4.2 build checks its own code, see the plugin's tamper-trap notes).
- The guard is now a vectored exception handler: an access violation at `0x971cbe0 + 0x12` with rcx = 0 resumes at
  `+0x1b` (after the call through b) and logs the record. No byte of the game is written. `mods-src/CrashTrace/
  crash_trace.cpp` (git-ignored folder), installed as `reframework/plugins/DD2CrashTrace.dll`.
- **It fired (twice by the end of the run; first: 15:49:16.848, 4 s into a title return).** Record a = `via.render.RegularBuffer`, b = null, c =
  `via.render.UnorderedAccessView`; call chain `0x971cbf2 < 0x94c2c2f < 0x94c3475 < 0x94c2ac7 < 0x94226d0 <
  0x60c7b1 < 0x550a0cc`, the same as the crash of A1; `via.render.MeshRenderer` and `via.render.RayTracingManager`
  on the stack. The game went on: the title held, the save was loaded again at 15:49:50 and played until it was
  closed at 15:51. What leaves that record with a null view is still not known.

**Counts with both in place (fixed add-on, exception guard; 14:49 on):** 10 returns to the title, 10 held (V1 90 s,
15:14 50 s, 15:24 45 s, 15:42 40 s, 15:45 30 s, 15:49 35 s then loaded, 15:55 40 s, V2 90 s, V3 120 s, 16:21 60 s
after the 12-minute soak), plus the death reload of 15:04 and two second loads (15:43, 15:50). "View dropped" was logged in 3 of them (V1, 15:14, 15:42)
and in X1; the guard hit in 1. Before, the same harpy trial went wrong 6 times out of 6 (13:03, 13:09, 13:14, A1, D1,
and 14:02 at the cyclops). The one crash after 14:49 was 15:33:39, caused by console calls into the Equipment page
(see the test-setup facts).

### A death and "Load from Autosave" (15:04, v47z)

- At the cyclops (108, 260, -2798), 1 HP kept from the console, three saurians brought to her: dead at 15:04:19,
  flow phase 40 (ConfirmContinue). The script logged `flow: the game phase was left: 2 packs removed, 5 vanilla node
  lists restored` and the soft reset in the same second.
- The death screen (`app.ui023401`, `FlowNow` 4, entries "Load from Autosave / Load from Last Interim Save / Load
  from Last Inn Rest / Return to Title") was answered with real Space presses (3 s). Phases 46 (UnloadWait), 24
  (Setup), 27 (InGame) 18 s later. No crash.
- She was set up again without help: `auto-enable` at 15:05:00, censer 2104 "(remembered)", rules built at 15:05:12,
  and with the Arisen at 1/516 HP the first log lines are the protect rule releasing summon and Screen.
- The morning's attempt (14:02) forced the dialog from Lua and crashed 4 s later: that crash was fault 1, not the
  forcing.

### Hired pawns (v48a)

- A rift pawn stands next to the save's start point in the Borderwatch inn; the Space presses that load the save
  talk to it and its dialog opens ("Hire / (details) / Add to Favorites / Cancel"). `TalkSelect.SelectedIndex` = the
  "Hire" row + `reqEnd()` hires it (the same two calls the test guard uses for Cancel). Hired: a Mage (15:17, v47z)
  and, in the next launch, a Thief (15:27, v48a). No wandering pawn showed up at the cyclops, the harpies or on the
  road in 5 minutes of waiting with the guard paused.
- **Mage hired after she was enabled, v47z:** one-minute fight at the arena against three world goblins. The Mage cast
  Firestorm (prepare / ready / cast / end), rapid shots, Anodyne and a barrier; she cast Rally and Delusion; no
  error line. Her slots sat on Fighter decisions (Job01), which a Mage does not use.
- **The gap in v47z:** the party's vocations were read once, at enable. A pawn hired later is not seen until the next
  load; had it been a Fighter, it would have run the decisions she had retargeted to Job09 actions.
- **v48a:** `PT.party_sig()` is the sorted list of the other party pawns' vocations (nil while one is still being set
  up). When it differs from the one at enable on two checks 2 s apart, the script does what it does when the game
  phase is left (`V.teardown`: packs out, borrowed node lists, goal rows, stance band and DecoyHandler back) and
  auto-enable sets her up again. `"party_watch": false` switches it off.
  - Thief hired at about 15:27:14: `party: the other pawns' vocations changed from [] to [4]` at 15:27:19, enable at
    15:27:25 with `_PartyPawnList[0]=9 _PartyPawnList[1]=4`, `shells from jobs not in the party (avoid 4,9): 19
    candidates`, rules back at 15:27:37 (18 s). Fight: the Thief used Job04 heavy and light attacks, dodges, a
    high-five after the kill; she summoned the decoy, cast Rally and Delusion; no error line.
  - Thief dismissed (`PawnManager.dismissPawn(app.Character)`) at about 15:30:22: `changed from [4] to []` at 15:30:28,
    rules back at 15:30:47 (19 s), `avoid 9: 24 candidates`.
- **Archer, and a 12-minute soak (16:09-16:21, v48b).** In the last launch the load's Space presses confirmed the
  dialog themselves (its first entry is "Hire"): an Archer joined, `changed from [] to [2]` at 16:07:59, rules back
  at 16:08:18 (`avoid 2,9: 24 candidates`). Twelve minutes at the arena with waves of three goblins, the Arisen
  healed from the console: 92 state checks, none with an error; fight log 275 battle ticks, decoy out 99 % of them,
  7.3 m from the nearest enemy on average, Aromatic Rally 18, Dragon's Delusion 3, 14 stance preemptions, 10 voice
  lines, no error line. The Archer aimed, shot normal and threefold arrows and high-fived. The return to the title
  after it held 60 s.
- A hired Fighter or Warrior (the two vocations whose decisions she borrows first) was never on offer. Her side of
  that case was tested with `avoid_jobs`, see "After the first commit" below.

### A censer through the game's Equipment menu (v48b)

- The page is `app.ui060401_00` (pause menu > Equipment). It was driven the way a player does, with key presses
  (`tools/keys.ps1`: Z / C switch the character, arrows move, F confirms, Esc leaves); the menu itself was opened
  without focus (`requestGuiType(12)`, `selectMenuSub(3)`).
- **What the page showed on v47z:** on her tab, the Wooden Staff with the "equipped" badge and her censer without it,
  although the censer was in her Main slot (her storage entries read staff 1500 `_IsEquipped` true, censer 2104
  false). The script's equip step wrote the Main slot of her EquipData and left the game's own bookkeeping behind.
- **The game's own Equip works for her.** Command popup on her censer: "Equip / Add to Favorites / Give / Give
  Multiple / Cancel". After Equip: censer badge on, Main slot 2104 `_IsEquipped` true.
- **A new censer:** a second one (2105, Dragonswail Litany) was put in the Arisen's inventory with
  `ItemManager.getItem`. On the Arisen's tab its Equip is greyed (not his vocation); Give > her, then on her tab
  Equip: Main slot 2105 at 15:38:23, `memory: recorded censer 2105` at 15:38:26, `pawns.json` "censer": 2105. Fight
  with it: decoy summoned, Rally cast, no error. After a return to the title and a load: `weapon: censer 2105
  (equipped)`: the save had kept it, which it never did for a censer equipped by the script.
- **v48b:** the equip step calls the game's `ItemManager.setEquip(StorageData, Character, SlotEnum, Boolean, Boolean)`
  with (her censer's storage entry, her character, 0, false, false) and only falls back to the slot write when the
  Main slot does not hold the censer afterwards. From a fresh load of the backup save (staff in the Main slot):
  `weapon: equip censer into Main slot (setEquip) true`, staff flag false, censer flag true, weapon job 9, the
  Equipment page shows the censer with the badge and the staff as not usable, a fight works, and after an autosave,
  a title return and a load the log reads `weapon: censer 2104 (equipped)`.
- `disable()`: the game's call refuses the staff while she is still a Trickster (the job change is a request, applied
  a frame later), so `restore_weapon` falls back to the slot write as before and `V.weapon_fix_tick` makes the call
  again once her old vocation is back: `disable: old weapon 1500 equipped again with the game's own call true`
  (15:52:57), staff flag true, censer flag false. `enable()` after that: censer back through `setEquip`, a fight
  with Summon and Screen, no error.
- `"equip_by_game": false` keeps the old slot write.

### Test-setup facts worth keeping

- Flow phases (`app.MainFlowManager.Phase`): TitleMenu 8, Setup 24, InGame 27, ResumeForFusibleWait 31,
  ConfirmContinue 40, RequestUnLoad 44, Unloading 45, UnloadWait 46.
- A hover warp (the Arisen held in the air so the area streams in) on a second load of a session put the game in
  phase 31 with a black screen for good (14:56). On a first load it works. To the cyclops a plain warp is enough.
- Never call a GUI page's own setup methods from the console (`ui060401_00.setupChara`, `setupCharaInfo`,
  `setupItemSlot` threw and reset the page; the game crashed at `DD2.exe+0x52590e4` 10 s later, 15:33:39). Reading
  the page's lists is fine; act with real keys.
- `GuiManager.reqSave()` sets `IsReqSave` but nothing is saved while a battle is on
  (`MainFlowManager.IsCheckRequestSaveValid` is true for type 1 only); no autosave came in 95 s of fighting either.
- World goblins near the arena are not loaded in the first seconds after a warp: `bring_enemies` returns 0, try again
  after 8 s. Goblins from the test spawner stand idle until they are brought next to the party.

### State at the first commit (16:25)

- Game closed; save byte-identical to Desktop\DD2_save_backup_20261110_run5h (9 files); the user's config.json and
  pawns.json put back; the temporary guard and its flag file deleted; dev console idle; watchdog stopped.
- Left installed: `reframework/autorun/PawnTrickster.lua` v48b (identical to the source and to the 0.2.2 zip),
  `DD2Clouds.addon64` (the fixed build), `reframework/plugins/DD2CrashTrace.dll` (the exception guard).
- Release folder (local, git-ignored): `mods-src/release/PawnTrickster_0.2.2/` (zip, CHANGELOG.txt,
  description.bbcode.txt, media copied from 0.2.1). Nothing uploaded. The clouds release zip (0.1.5) is not rebuilt.

### After the first commit (16:25-17:32): the vocation of the borrowed rules, repeated re-setups, more title returns (v48c, v48d)

- **v48c: `"avoid_jobs"`** in config.json (a list of vocation numbers) leaves those vocations' decisions alone as well,
  as if such pawns were in the party. A test aid: no hired Fighter or Warrior was on offer (the rift pawn at the inn
  was a Mage, a Thief, then an Archer). Her slots are built on decisions of the first free vocation in the order
  Fighter, Warrior, Mage, Thief, Sorcerer.
- **The vocation of the borrowed decisions does not matter.** One 50 s fight against three goblins each (rows 2-4: a
  fresh launch with the list in config.json; row 1: set from the console, then `disable()` / `enable()`):

  | avoided | borrowed from | picks / casts | cast |
  |---|---|---|---|
  | 1 (as next to a Fighter) | Warrior (+ Thief for the stance) | 3 / 2 | Summon, Rally |
  | 1, 5 (Fighter and Warrior) | Mage | 5 / 5 | Summon, Rally, Delusion, beckon |
  | 1, 5, 3 | Thief | 4 / 4 | Summon, Rally, Delusion |
  | 1, 5, 3, 4 | Sorcerer | 4 / 4 | Summon, Delusion, Screen |

  So next to a hired Fighter, or a Fighter and a Warrior, she has working slots. What a hired Fighter itself does next
  to her is still not seen in game; by construction none of its decisions is touched.
- **Several re-setups in one session.** One session, nine setups: the first by auto-enable, two through the party path
  (`PawnTrickster.state.party_sig` set to a wrong value from the console, which runs the same code as a hire), two
  `disable()` / `enable()` cycles, then three party-path ones with the borrowed vocation changing each time (Warrior,
  Mage, Thief). A 45 s fight after each: 2 to 4 picks and 3 to 6 casts every time, no error line. (That session's
  second `disable()` / `enable()` cycle is the one that did not go silent, see the next point.)
- **`disable()` / `enable()` twice in one session can leave her passive (found here, not fixed, intermittent). [Explained in the run of 20:36-22:35 below: the Danger AI state, not disable / enable.]**
  After the second cycle she walked and strafed through whole fights (battle state 2, enemies 1-4 m from her) without
  a single pick in 2 sessions of 5: 16:31 (0 picks in 50 s) and 17:15-17:19 (0 picks in three fights); in a third
  (17:09) she made 1 pick in 45 s; in two she fought normally (16:47, 4 picks after the second cycle; 17:27-17:30,
  four cycles, 1-2 picks in each 25 s fight). The first cycle always worked (15:53, 16:27, 16:45, 17:07, 17:12,
  17:26). The setup log of a
  silent cycle is the same, line for line, as that of a working one (5 decisions added, 5 tracked in MainDecisions).
  - Not the cause: the vocation of the borrowed decisions (table above); two enables on top of each other (the
    16:31 and 17:09 runs had an auto-enable and a manual enable 5 s apart, so v48d makes `enable()` a no-op while she
    is enabled: the 17:15 run had the guard and was silent all the same); the decoy being out at enable.
  - Once silent, a re-setup through the party path does not bring her back (17:19, 0 picks). **Loading the save
    again does** (title, load, 17:21: 5 picks, 5 casts).
  - Her decision module in a working fight, for comparison when it shows again (`r/modprobe.lua` of the run's
    scratchpad, read only): `app.DecisionEvaluationModule`, 29 main decisions, hers at five positions between 16 and
    25, `DisableFlag` 0, cooldown timers running. No dump of the silent state was caught.
  - Re-setups through the party path alone (hire, dismissal, the faked signature) never showed it: 7 of 7 fought
    normally (the Thief and Archer hires, five with the faked signature). They do not change her vocation; `disable()` / `enable()` changes it to Mage and back each time.
- **More title returns with both fixes** (the counts above end at 16:21): 16:53 after the nine-setup session, 60 s:
  "view dropped" at 16:53:12.193 and **a second hit of the exception guard at 16:53:13.368** (RegularBuffer, null
  view), 1.2 s apart in the same return, and the title held. V4 (16:56) and V5 (17:01), harpy trial, 90 s each: held.
  V5's add-on log shows a live depth buffer bound at the title ("bound view"), the picture B3 gave with the code
  patch in: so that picture is not an effect of the patch.
- **Totals with both fixes (14:49-17:03): 13 returns to the title, 13 held**, a death reload and two second loads;
  "view dropped" logged in 4 of them (V1, 15:14, 15:42, 16:53), the exception guard hit in 2 (15:49, 16:53). One more
  return at 17:20 (12 s at the title, then a load that worked) is not counted: too short a watch.

### End state (17:35)

- Game closed; save byte-identical to Desktop\DD2_save_backup_20261110_run5h (9 files); the user's config.json and
  pawns.json put back (no `avoid_jobs` in it); the temporary guard deleted; dev console idle; watchdog stopped.
- Left installed: `reframework/autorun/PawnTrickster.lua` v48d (identical to the source and to the 0.2.2 zip),
  `DD2Clouds.addon64` (the fixed build), `reframework/plugins/DD2CrashTrace.dll` (the exception guard).

## Run of 2026-11-10, 20:36-22:35 (v48d -> v48e = 0.2.3): the passive fights

Probes (scratchpad `r/`, read only unless said): `diag.lua` (the sampler described in the README), `execsample.lua`
(what the main pawn's AI executes, any vocation), `prio.lua` (priority / policy / tags of every live decision),
`wconds.lua` (conditions and evaluation criteria of live decisions), `skc.lua`, `stam.lua`, `ais.lua`.

- **What the inherited conditions are.** Preconditions: `State{All, Ground|CanBattle}` (`app.AIDecisionDefine.OwnerState`:
  Ground 1, Air 2, Climb 4, CanBattle 8, IsInteractingWithObject 16, Caught 32, Catch 64, ObjectCarry 128,
  PushAndPull 256, GimmickConstraint 512), `State{Any, 1014, _Not}` (none of the busy states),
  `BattleMode{6}` (`BattleMode.BattleState`: Normal 1, Ready 2, Battle 4). Target preconditions: `IsCaught`, `IsDead`,
  `ImmuneToDamage{_Element 1, _UseEnchantment}`, `GeneralPointHeight{0, 2}`.
- **How the module orders decisions** (`EvaluationMethodType.Priority`): by `Priority._Layer` (Common 0, Quest 1,
  Reaction 2), then `_Rank` (Lowest 0 .. Highest 4). Reaction layer on her: `Common_ClingCliff`, `DrawWeapon`,
  `Move_Fix_Dash_Target` (target Player: the run back to the Arisen), `Pawn_Ring_Dodge`, `Move_FixedDash_Position`.
  Common layer rank 4: `HumanCatch`, `EnemyCarry_01`, `ch1_MoveApproach`; rank 3: her stance and summon, two
  `MoveToPosition_Walk_Target` (precondition `IsSkillBreakTime`, start process `ResetSkillCount`); rank 2: her
  Screen / Delusion / Rally, `DrawWeaponIdle`, `Job03_KeepDistance_01`; rank 1: a third `MoveToPosition_Walk_Target`
  without the break-time condition (the one seen executing between her casts, score 0.95-1.0).
- **Skill break time.** `app.Pawn.<SkillActionController>` (`PawnSkillActionController`): `_SkillCount` /
  `_MaxSkillCount` (6-11, redrawn), `get_IsSkillBreakTime`. Vanilla attacks stock a skill; at the maximum the
  High-rank walk becomes valid and resets the count: the vanilla "a few attacks, then reposition" rhythm. Her count
  stayed 0 through 46 picks (0/10): her casts are not counted, so she never takes that break.
- **Stamina.** `app.Pawn.<AIStaminaManager>.get_State` (FullPower 1, SavedPower 2, Breaktime 4); her stamina in
  `Character.<StaminaManager>` (`<RemainingAmount>`, `<MaxValue>` 709.9). Rally held for ~9 s took her from 100 % to
  below 0 (-57 % seen, `LocomotionOnRunningOutOfStamina`). A test helper that called `recoverAll` on her every 7 s
  hid this in the earlier soaks.
- **Phantoms** (`spawn_enemies({"Phantom","Phantom"})`, v48d): 65 samples, Rally released in all, `targets 1: tpre 0`,
  0 picks; she executed `MoveToPosition_Walk_Target` (57 %) and `Job03_KeepDistance_01`. v48e: `targets 1: tpre 1`,
  summon, beckon and two Screens in 30 s; the phantoms then drained her stamina and killed her (level 1, 400 HP)
  and the pawn object was gone 13 s later (`_MainPawn` nil), so phantoms are not a soak enemy for this save.
- **The Danger state.** `ais.lua`: `CharaAIStateCtrl.get_AIState` 128 (Danger; `_AIState` 1 Normal, `_TempAIState`
  128), party `PawnBattleController._CurrentState` 2 (its enum: Normal 0, Ready 1, Battle 2, Escape 3, Win 4; the
  script's `battle == 2` is Battle). The sampler in those fights: `pre=false fail=[BattleMode,Bat=6]`, every
  target valid. `Human.get_IsBattleMode` was false as well (`TimerBattleMode` <= 0) and one call of
  `Human.setTimerBattleMode()` made it true for 5 s without changing the condition's answer, so the condition
  reads the AI state, not that timer. What sets Danger was not looked into; `recoverAll` on her and on the Arisen
  left it on.
- **Test traps of this run.** (1) The keep-alive loop and my own console commands share `cmd.lua`: two writers at
  once lose a command (TIMEOUT); retry once. (2) Spawned goblins stand idle until brought next to the party; a
  wave helper that respawned instead of bringing them produced a 170 s "fight" with no battle. (3) The harpy cliff
  and the arena's slope kill a strafing level 1 pawn (SlideDown, SlideDownToFall, DieFromFall); a pawn left dead
  for a few minutes is gone (`_MainPawn` nil) and every later sample is void: revive her when her HP is 0.
  (4) A rift pawn's hire dialog only opens from the Space presses that load the save; with the guard paused by
  `dmo_dev/hire_pause.flag` those presses also confirmed the hire (an Archer this time).
- **Soak with the hired Archer, v48e:** hired Archer in the party (hired by the load's key presses, she was set up again 20 s later), 6-minute arena soak against waves of three goblins: 134 s in the Battle state, 9 picks, 11 casts (Rally 10, Delusion 1, summon 1 in the log), no error line, no released cast waited more than 2.5 s; executing Rally 25 %, her stance 17 %, Delusion 6 %, summon 5 % of the battle samples; then the title, held for 60 s.

- **Rally and distance (final solo soak, `r/rallywhy.lua`, 568 samples):** distance from her to the Arisen under
  9 m 14 %, 9-12 m 3 %, 12-15 m 5 %, 15-20 m 30 %, over 20 m 48 %; Rally gate "blocked, ally none" 471 samples,
  "released, ally arisen" 91, "blocked, tired" 6. `PawnTrickster.state.stance_hold_until = os.clock() + 25` from
  the console: 15-20 m and over 20 m for the whole 25 s (the Mage keep-distance pack and the rank-1 walk keep her
  out). Decisions in that soak: her stance 71 %, Screen 6 %, Rally 5 %, `MoveToPosition_Walk_Target` 5 %,
  `Job03_KeepDistance_01` 4 %, summon 2 %, Delusion 1 %.
- **The other checks of the evening, in order:** arena fight v48d (150 s, baseline), the same pawn as a Mage
  (120 s), phantoms v48d / v48e, six goblins v48e (Danger), 50 s out of battle (no cast), harpies 100 s, title 30 s
  and second load, hired Archer soak 6 min and title 60 s, fresh launch and the cyclops 127 s, death and Load from
  Autosave, solo soak 12 min, fresh launch with the debug set and Latching Effigy 150 s. Eight launches, no crash,
  no error line in `log.txt` after the v48e install.

### End state (22:35)

- Game closed; save byte-identical to Desktop\DD2_save_backup_20261110_run5h; the user's config.json and pawns.json
  put back; the temporary guard deleted; dev console idle; watchdog stopped.
- Left installed: `reframework/autorun/PawnTrickster.lua` v48e (identical to the source and to the 0.2.3 zip).

## Run of 2026-11-11, 08:24-09:36 (v48e -> v48f = 0.2.4)

- Vanilla movement packs (`r/movepacks.lua`, nodes of `AppSystem/AI/ActionInterface/ActInterPackData/...`):
  `ch1/ch1_MoveApproach` move.Approach `_FixedMove` 2, stop 0.5 m; `ch1/ch1_Move_Run_Target` `_HowToMove` 1,
  `_FixedMove` 1, stop 0.2 m; `Common/Move_Fix_Dash_Target` `_UseOwnMoveSetting` true, `_FixedMove` 3, stop 1.0 m;
  `Common/MoveToPosition_Dash` `_FixedMove` 3, primary target `_Target` 2048 (Position). The first three have primary
  target `_Target` 0: they move to the target of the decision that carries them.
- `Job09_Unsummon` requested out of battle plays, and the handler still reports `HasInstance` true, `Appeared` true,
  `Hidden` false afterwards. After a far warp (pawn rebuilt) the handler has no instance (`Hidden` true).
- With the Arisen at 1 HP and a hired Fighter, picks went on at the usual rate for 150 s (protect rule) and the
  Arisen was never hit.
- The party battle state with a Fighter that kills goblins flips between 2 and 4 (Win) or 0 every 10-30 s; the
  "battle:" lines of the log show it.
- `_G.__revives` of the test loop is per game session, not per fight: read the difference.

### End state (09:36)

- Game closed; save restored to the user's save of 08:30 (hired Fighter in the party), copy on the Desktop as
  `DD2_save_backup_20261111_hired_fighter`; config.json and pawns.json put back; dev console and guard removed.
- Left installed: `reframework/autorun/PawnTrickster.lua` v48f (identical to the source and to the 0.2.4 zip).
- Public repository prepared locally in `mods-src/release/_github/DD2-Trickster-Pawn` (git-ignored here), not
  committed and not pushed: the user allows pushes to it only outside 09:00-18:00.

## Run of 2026-11-11, 09:45-12:30 (v48f -> v48g = 0.2.5)

- Tools of this run are the public repository's (`mods-src/release/_github/DD2-Trickster-Pawn/tools`): `variant.lua`
  (change config values live and rebuild her rules through disable / enable), `stamwatch.lua`, `effwatch.lua`,
  `sample_fight.sh`.
- **config.json trap (cost one wrong report):** every start writes all keys, and the next start reads them back
  over the new defaults. After changing a default, read the live value from the console (`PawnTrickster.cfg.x`)
  before believing a measurement. The public `start.sh` does not reset the file; `tools/work/regress.sh` of this
  run copied the user's 0.2.2-era config in first.
- (WRONG, corrected 2026-11-11 14:48: the timers run on real time, see the end of this file.) The cooldown timers of the runtime rules count frames (the gate code assumes 60 per second): 12-13 Rallies in
  190 s on a "25 s" cooldown.
- Effigy samples, raw (target distance m / height m / degrees off her facing): run 1 (old window) latched 9.1/0.5/2,
  9.5/3.9/2, 4.8/-0.2/5, missed 5.5/0.3/22, 4.8/-0.3/2, 2.1/-0.2/52, 3.9/-1.0/51, 5.4/0.2/49, 6.5/-0.2/150,
  3.4/-0.2/3. Run 2: missed 2.1/0.0/5, 6.0/-1.2/0, 6.6/-1.0/148. Run 3: latched 9.3/0.6/0, 8.2/0.8/0, 9.5/-1.0/0,
  6.2/0.7/1, missed 6.4/-0.6/3, 5.5/-0.3/67, 7.3/-2.3/50, 11.7/-1.2/152, 3.7/-0.2/3, 9.3/0.7/69. Run 4 (7-10.5 m
  band): latched 9.8/2.8/0, missed 9.0/-0.2/1, 9.1/-1.6/54, 7.1/-0.4/0, 7.3/-0.3/6, 9.2/-0.5/174, 9.0/-2.1/1,
  7.1/0.9/1. Run 5 (3-10.5 m, final): missed 9.8/-1.9/167, 9.5/-1.3/1, 8.8/-9.1/33, 12.0/-1.3/15.
- With the test skill set (96 97 99 92) and a 6-10 s effigy cooldown she ran out of stamina in every long fight
  (lowest -19 to -29 %, 3-5 episodes) before the floors: Screen was the cast without a floor (her own HP under
  60 % releases it every 30 s).
- `tcondition.DistanceRange` (`_Range` via.Range start / width, `_IsXZPlane`, `_Not`), `tcondition.Distance`
  (`_Distance`, `_Compare`, `_IsXZPlane`), `tcondition.AroundSelf` (`_AroundTarget`, `_Distance`, `_IsDead`,
  `_Not`) exist; no simple "height of a character" getter on `app.Character` (`Human.BodyHeight` for humans only).

### End state (12:30)

- Game closed; save restored to the user's save of 08:30 (hired Fighter), config.json and pawns.json put back,
  `config.defaults.json` of the test runs deleted, dev console and guard removed.
- Left installed: `reframework/autorun/PawnTrickster.lua` v48g (identical to the source and to the 0.2.5 zip).

### Addendum, 11:34-12:30: v48h

- Raw effigy samples of v48h. Angle condition only (8 min): missed 9.3/-0.9/2, 9.0/-1.3/1, 8.0/-0.3/1, 9.8/-2.0/1,
  latched 9.2/+1.4/0. Angle and height (4 min, goblins): latched 13.8/-0.4/2 (the target had moved on by the time
  the cast started; the game's height measure had passed it). Cyclops (1 min): latched 9.6/-3.0/2.
- The cyclops is 18 targets for a rule with target Enemy (one per region); a goblin is 2. A probe that uses
  `AITarget.<Transform>` gets the root for all of them.
- `sed -i` with Windows paths in the pattern silently matched nothing twice today; use Python for edits.
- The 0.2.5 commit a6695c5 is v48g; the effigy conditions came in the commit after it.
- 12:28: Steam started the game five minutes after the launch request; `start.sh` had given up ("DD2 is not
  running") and the fight loop that followed ran against a game still booting, which then sat at the title. Look
  for a late process before starting again; `loadsave.sh` from the title was enough. The final file from that
  fresh process: live settings as intended (Rally 12 s / 0.75, effigy rise 1.7, effigy floor 0.75), 79 s of
  battle, 8 casts, lowest stamina 42 %, no error line.
- End state 12:40: as at 12:30 above; commits a6695c5, 146769c, 6c2f7f8 and this one on main, local.

## Run of 2026-11-11, 12:50-14:45: dust ball, effigy incense, test-run settings

- Probe files of this run are in the public repo clone under `tools/work/` (not published): `fire.lua` (one shell from
  the pawn or the Arisen at the nearest enemy, flight logged), `dmghook.lua`, `dmgpost.lua`, `hate.lua`,
  `hatehook2.lua`, `hateskip.lua`, `hitid.lua`, `shtrack.lua`. Published samplers: `tools/lua/dustwatch.lua`,
  `tools/lua/dusttrack.lua`.
- Shell data fields: `app.ShellParamData.ShellParams` (list) of entries with `_ShellId`, `_ShellParamIdHash`,
  `_ShellParameterBase` (`ShellBaseParam`, `effectParam`, `colliderParam`), `_ShellActionParameterList`
  (`ShellActionParamHoming`, `ShellActionParamSpeed`: InitialSpeed 0.54, MaxSpeed 0.15, Acceleration -0.008,
  RangeDist 20 for entry 8), `_ShellAdditionalParameter`. A live `app.Shell` has `<Owner>`, `<ShellParamId>` (the
  hash), `<RequestId>` (a slot number, reused), `_TargetInfo` (`app.Shell.ShellTargetInfo`: Type 3, TargetObject,
  WorkIndex, LockOnTarget and GeneralPoint filled in the first frame).
- Other Job09 shells seen: entry 13 is a large lingering smoke cloud (0.5 s shell), entry 26 a slow projectile with a
  healing smoke parameter that passes through its target, entry 0-2 the short smoke of the swing (hate type 24).
- `app.HateSendTypeID`: Job09_SmokeAttack 24, Job09_ThrowSmokeAttack 25, Job09_PossessionStart 26,
  Job09_PossessionLoop 27, Job09_AttentionSmokeAttack 28 / Lv2 29. `HateManager.getSendHateParam(id)` returns the
  parameter object the hate calls carry. `HateSystem.getTotalHate(GameObject)`, `getRawTotalTempHate`,
  `getRawTotalNotForgetHate` read an enemy's hate of someone; an enemy's `HateSystem` is `Character.<HateSystem>`.
- `app.HitController.DamageInfo` has `Damage`, `FixedDamage`, `MagicDamage`, `<AttackOwnerObject>`,
  `<AttackGameObject>`, `<AttackHitController>`, `<DamageGameObject>` among 120 fields.
- Writing the pawn's `Transform.set_Rotation` each frame turns it; an action with its own aim (the effigy cast) turns
  it back at about 12 degrees a frame.
- `sdk.get_tdb` does not exist in this REFramework's Lua; the MCP's type search answers "which types mention X".
- **Test-run settings asked by the user** (GPU load): DLSS Ultra Performance, 30 FPS, and the RenoDX DLSS add-on
  ("DLSS 5", `renodx-dlss.addon64`) off. `tools/lowgpu.sh on|off` does it and restores it: `config.ini` values
  `UltraPerformance` (read from `SystemOptionUtil.getUpscalingQualitySelection(1, args)`: MaxQuality, Balanced,
  MaxPerformance, UltraPerformance), the add-on file renamed to `.testoff`, and `"fps": 30` in the json of the
  frame-rate mod that holds its own cap (it set 40 again a second after every `set_MaxFps(30)`). Measured: 88 % GPU
  and 414 W before, 83 % for the game alone with only the engine cap, about 30 % and 155 W with all three.
- **Launch.** Space is tapped again from the moment REFramework's window hook is done (log: "Resuming" after
  "WindowsMessageHook"), for 15 s: launch to in-game in under a minute. Waiting for the dev console (this morning's
  change) left the game on its intros and title for one to two minutes. One boot deadlocked inside that hook with no
  key pressed and no window touched (13:40: log ends on "Suspending" lines, process not responding, 0 % GPU):
  `start.sh` now detects it after 20 s, closes the game and launches again. The hung boot of this morning was
  probably the same and not the Space presses.
- `TaskStop` on a background `bash script.sh` killed the outer shell only; the script went on and later hit a syntax
  error because the file had been edited meanwhile. Start long scripts with `exec bash script.sh`.
- The spawned goblins of a wave sometimes stand passive next to the party (battle state 0 for a minute with two
  alive); `bring.lua` does not wake them. A helper that forces a fresh wave after 10 s out of battle
  (`tools/work/keeper2.sh`) avoids the dead time.
- **Cooldown timers run on real time.** Measured at 30 FPS with `tools/lua/timerrate.lua` (every frame for 3 s, the
  `CooldownTimer` of the pawn's decision wrappers that are counting down): 2.000 units a frame, 60.0 a second, on
  five timers (CooldownTime 360, 720 = Rally's 12 s, 1200 three times). So `_Cooldown` seconds are seconds at any
  frame rate and the gate code's `* 60` is right. Earlier notes and a report to the user said the timers count
  frames (an assumption from 60 FPS runs, never measured): wrong. The user had said "Yes, fix timers" to an offer
  to make them real seconds; the answer was this measurement, no code change. `os.clock()` is wall time here
  (91 frames in 3.01 s under a 30 FPS cap).

## Run of 2026-11-11, 14:55-15:20: a capture tool (GIF of the pawn's action)

- Asked by the user after "how did the swing magic ball look": a reusable tool that films the pawn's action and
  produces a GIF for whoever asked. Then, while I was building a camera that framed pawn and target from the side:
  "why dont you just put the camera on her, a bit on the back to have a good view, and capture that and thats it?
  dont try anything crazy like following the ball". The default is now exactly that.
- `tools/capture.sh`, `tools/capture.ps1`, `tools/lua/cam.lua` in the public repo clone. Camera: the primary
  camera's GameObject transform written in `re.on_pre_application_entry("LockScene")` (position, and a rotation
  whose +Z points AWAY from the look direction: the camera looks down its -Z). Capture: `PrintWindow(hwnd, dc, 3)` at
  10 frames a second into 480 or 640 pixel bitmaps (a 4K window, about 45 ms a frame). GIF: WPF's
  `GifBitmapEncoder` with a 256-colour palette per frame (`BitmapPalette(frame, 256)`), then the file is walked
  block by block to add the NETSCAPE loop block and a delay on every frame (the encoder writes neither). 46 frames
  at 640x360 are about 7 MB. No ffmpeg, ImageMagick or Pillow on this machine.
- What the dust ball looks like (capture `dust7`): the pawn swings, a streak of pale violet smoke runs to the goblin
  in about half a second and bursts there in a pink-white cloud with sparks about two metres wide, gone after two
  seconds. A smoke streak and a burst, not a ball.
- Mistakes of this hour: the hook kept the first version of the camera code after the file was edited (camera
  straight above the action for three captures); "the enemy nearest to the pawn" was one that had fallen down the
  cliff; a ray check that pulled the camera up to the pawn made the pawn disappear from the frame; a console command
  mangled by the fight helper writing at the same moment; `$(( ))` with a fractional number of seconds. The user saw
  the game window standing still on a patch of ground for a minute and a half and asked whether the pawn was frozen.
- At 30 FPS the dust gate was open only for a narrow band of distances (no enemy within 3.5 m, one within the 6.6 m
  reach): two captures timed out after 90 s without a swing. For the demo `dust_safe` was set to 2.0 in the running
  game only.

## Run of 2026-11-11, 15:40-16:25: ball smaller, fooled enemies, start script

- `app.HateSystem` custom rates: `setCustomRate(GameObject, Single)`, `getCustomRate(GameObject)`. Set once, the rate
  reads 1.0 again on the next frame. `HateCalculator` fields written from Lua without trouble:
  `_TargetHateValue_Temp`, `_TargetHateValue_NotForget` (the kept part; the pawn bias 100 comes back within frames),
  `_TargetHateValue_Distance`. An enemy's `_Ranking` is a managed array (`get_size`, `get_element`), entries have
  `get_Enable`, `get_TargetObj`, `get_TargetSmokeDecoy`, `get_TargetHateValue`, `get_CustomRate`.
- Effects of a shell: `createEffectInternal` returns a `via.GameObject[]`; the objects are named `effect_<owner>`
  (`effect_ShellBase` for the trail and the impact of the ball, `effect_ch220000_00` for effects attached to a
  goblin). Scaling their transform scales what is drawn.
- Probe files: `tools/work/fool.lua`, `fool2.lua`, `fool3.lua` (rates and direct writes), `efxprobe*.lua`,
  `tools/lua/foolwatch.lua` (published: who is on top of each enemy's ranking, fooled enemies apart).
- Start script, third version of the day. With `launch_bg.ps1 -UntilHook` the Space taps began 12 s after the launch
  and a fixed 15 s ended before the title was up: the game sat at the title until the fallback. Now: runs of 6 s of
  Space, the phase read between two runs, until the save is loaded (five runs, 84 s from launch to the mod being
  ready in the regression launch). Editing `start.sh` while an instance of it was running broke that instance
  again (second time today).
- `capture.sh --lua` now keeps the film from a little before the Lua file's answer to `--seconds` after it (the
  first version started the clock too early and cut the impact). `--mode side` gave usable shots once the hook
  bug was out; it drifts when the target runs.

## Run of 2026-11-11, 16:45-17:55: the smoke minimal (v48k), the launch takes the focus for 1.5 s

- Effects. `via.effect.EffectPlayer` (98 methods, names listed with `tools/work/epnames.lua`): `set_Action(via.effect.
  PlayerAction)` with Idle 0, Start 1, Kill 2, Finish 3, Pause 4, Resume 5, Step 6, PauseStart 7; `set_PlaySpeed`,
  `get/set_Color` (`via.Color`, field `rgba` = 0xAABBGGRR), `set_EmitMaskBit`, `set_TotalLoopFrame`; no size or
  scale. `set_Action(2)` on the players of an effect object removes it at once (about 60 objects in this run, no
  trouble). `get_Resource` is empty inside the `createEffectInternal` post-hook.
- One dust swing creates five effect objects: +0.4 s `effect_ShellBase` under `ShellBase` (the ball's trail), +0.45 s
  two `effect_<pawn>` (under the weapon `wp10_001_00` and under the pawn: the censer's swing smoke), at the hit two
  `effect_ShellBase` under `NoParentEffects` (the impact). And one more shell than the ball: parameter id 1754224672.
- The pawn drawn by the capture camera is sometimes missing (the camera stands where the game's own camera does not
  see it: culled, I think; not looked into). The clip then shows smoke around nobody. A side view (`--mode side`)
  showed the pawn in the same fight.
- With only the dust slot released the Arisen died twice in two minutes (nobody draws the goblins off, and my
  keep-alive loop had ended): death screen, which needs key presses, so two relaunches. `lua/safe.lua` first.
- The dust swing came once in 20 to 60 s in that test fight (the gate wants an enemy in reach and none within
  `dust_safe`); `PawnTrickster.request("Job09_ShortSmokeAttack")` plays the swing on demand (without the ball),
  `tools/work/fire_go.lua` throws the ball without the swing.
- **Launch.** The user, twice in this run: "why are you focusing many times the game and doing space??? you are
  supposed to do it only one time when the game launch and pass the main menu", then "you are still pushing space 4x
  TOO LONG, FIX THAT, TOP PRIORITY". History of the day: 25 s of taps, 15 s, runs of 6 s (up to eight, each fronting
  the game again), one session until the save was loaded (40 to 65 s). Now: the dev console writes
  `MainFlowManager.get_FlowPhase` to `pt_dev/phase.txt` when it changes; `load_space.ps1 -PhaseFile` takes no focus
  until the phase is 8 (TitleMenu), taps until it is 9 or more, hands the focus back. Measured: 4 taps, focus held
  1.5 s. Timeline of that boot: 17:42:10 process, 17:42:29 phase 3 (StartUp, scripts running), 17:42:51 phase 4,
  17:42:52 phase 8, 17:42:53 phase 21, 17:42:55 phase 24, 17:43:16 in game. The intros end by themselves in the
  same time the taps took before. Phase names: 1 WaitReady, 2 CheckContinue, 3 StartUp, 4 CheckNetwork, 8 TitleMenu,
  11-13 InitLoad, 20 RequestLoad, 21 StartLoad, 22 LoadingWait, 23 Loading, 24 Setup, 26 SetupWait, 27 InGame,
  40 ConfirmContinue (the death screen), 44-46 unloading.
- My edit of the dev console put a line break inside a Lua string (a `\n` written through a Python heredoc): the
  script did not load, no phase file, the launcher waited, the game was closed 30 s into the boot (no crash entry in
  the Windows log; by the user or by a REFramework error box, not established). `load_space.ps1` now ends when the
  game process has ended.
- `via.GameObject.set_UpdateSelf(false)` on an enemy: it stands as a statue in the pose it had, stays in the enemy
  list with its HP, is not hit by a shell (the ball passed through), and comes back to life with `true`. No trouble
  in four freezes; release it before `cleanup.lua`. `app.Character.warp(via.vec3, 0)` moves the Arisen and the pawn
  a few metres without rebuilding the pawn.
- `capture.sh --lua` keeps `--pre` + 1.5 s before the Lua file's answer: `--pre 0 --seconds 2.2` gives a 3.7 s clip
  and a sheet with a frame every 0.3 s; `tools/gifsheet.ps1` makes a sheet of every frame of a stretch of the GIF
  (System.Drawing, `SelectActiveFrame`), cropped and enlarged.
- The side camera is steady once there is one enemy and it does not move. With the Arisen next to the statue the
  pawn was put behind the Arisen (in the line of the throw); `dummy.lua` now moves the Arisen behind the pawn. The
  far side of the statue was a rock (the pawn climbed).
- `Job09_ThrowSmoke` requested on the pawn: 3.3 s, its shell (2585554136) registered at +0.73 s, twice the same
  timing. `tools/lua/actwatch.lua` (`_G.__aw_req = "<action>"`) is the tool for "what does this action do and when
  does its projectile leave". Other names of `app.Job09ActionID` not tried: `Job09_PrepareThrowSmoke`,
  `MoveSmokeAttack`, `DashSmokeAttack`, `Job09_SmokeAttack`, `Job09_AttentionSmokeAttack`.
- The goblin of the last clip carried a torch and dropped it when the ball hit: a hit staggers a weak goblin.

## Run of 2026-11-11, 18:12-18:52: the swing (v48l, v48m patch), launch focus, stopped by the user

- `app.Job09ActionID`: 60 names (`tools/work/j9names.lua`): Normal, Skill, Start/Keep/EndSmallLevitate,
  ShortSmokeAttack, MoveSmokeAttack, SummonDecoy(+Finish, Dash), ClingSmokeAttack, JumpSummonDecoyLanding,
  PrepareThrowSmoke, ThrowSmoke, DashSmokeAttack, PrepareMoveThrowSmoke, HoldDownSmokeAttack, Cling/HoldDown
  variants of Transfer, WearSmokeDecoy, KeepDraw, Sheathe, SummonToWear, WearToTransfer, Transfer, Wear, Unsummon,
  CS01-CS11, the Cast* skills, None.
- Launch: the booting game can take the focus again after `launch_bg.ps1 -UntilHook` has returned; `load_space.ps1`
  then kept it for the whole boot (45 s, once). Now it tracks the user's window (the last foreground window that is
  not the game's) and gives the focus back whenever a window of the game has it, while waiting for the title and
  for 15 s after its taps. Measured twice after that: 1.1 s and 1.5 s of focus, "given back 1 time".
- `Process.MainWindowHandle` of DD2 is whichever of its windows is on top: after Alt+Esc it was REFramework's
  minimized console and the capture failed ("no client area"). `capture.ps1` finds the window by class and title
  (`via`, "Dragon's Dogma 2"); `FindWindow("via", null)` returns another, empty window.
- `"$C\$n.gif"` in bash does not expand `$n`: build Windows paths with `cygpath -w "$PWD/.../$n.gif"`.
- I named a cause for the stuck model three times in an hour, each time as a fact, each time wrong or unproven.
  The user was told so. See the v48m section of README.md.
