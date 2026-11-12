> Working notes of the development, kept as they were written. They say "she" for the test pawn, name scratch
> files (`r/...`, `tools/...` of a temporary folder) and paths of the author's own mod workspace
> (`mods-src/...`) that are not part of this repository; the cleaned-up helpers are in `tools/`.

# A Trickster main pawn: reverse-engineering study

Date: 2026-11-08. Follow-up to the hybrid-vocation study in `../README.md`, this time for one vocation only,
Trickster (`Job09`), with the question "how could it be modded, no limits". Everything below was read from the
game itself: the pak files (decoded offline), the live type database and live objects (REFramework web API and
the Lua dev console) while the game was in the field with the main pawn as an Archer. No pawn was switched to
Trickster yet; that is the test the prototype at the end is for.

## Verdict: working prototype — in run 10 (2026-11-08 15:52) the main pawn fought as a Trickster on its own: its decision maker chose and played Job09_SummonDecoy, Aromatic Rally, Dragon's Delusion, Delusory Screen and censer swings with no manual request (see "Runs 7–10" below)

The earlier study graded Trickster "weak" because only two of its skills have ready-made AI commands. That was
the wrong measure. What matters is what a pawn's action layer can **execute** and what the AI can **request**:

- Every Trickster action is requestable by name through the layer pawns already use
  (`HumanActionSelector.requestAction(name)`); the names are the `app.Job09ActionID` enum.
- The AI command `app.actinter.cmd.ActNo { ActionID }` runs any such name from a normal decision pack, so no new
  command classes are needed.
- The decoy (Simulacrum) is owned by an `app.Human`, not by the player object. `DecoyHandler.setup(app.Human,
  via.Prefab)` and `SmokeDecoy.setOwner(app.Human)` are the real owner paths; the only player-held piece is the
  prefab reference (`app.Player.DecoyPrefab`), which can be shared.
- Enemies already target decoys owned by non-player humans: the duel NPC Trickster (`ch300962`) uses the same
  `Job09ActionController`, so the hate/targeting side is not player-specific.

What actually blocks a Trickster pawn is small and all of it is reachable from Lua:

| Gate | Evidence | Fix |
|---|---|---|
| The pawn has no `Job09ActionSelector` (only Job01..Job06 + common selectors; the Arisen has Job07/08/09 too) | live `HumanActionSelector.Selectors` of the main pawn vs the player | `addJobSelector(chara)` or `sdk.create_instance("app.Job09ActionSelector")` + `setup(Param)` + insert |
| `PawnUtil.getJobNormalAttackAction(9)` / `getJobHeavyAttackAction(9)` return `""` (Job01..03 return names), `PawnSkillActionController.getCommonAction(9)` returns `""` | called live | post-hooks returning `Job09_ShortSmokeAttack` / `Job09_SummonDecoy` (+ their hashes) |
| No `DecoyHandler` on a pawn's `Job09ActionController` (the player's is created with `Player.DecoyPrefab`) | live: player's handler has Owner = Human, Prefab = PrefabController | `prepareDecoyAndAstralBody()` or `DecoyHandler.setup(human, player.DecoyPrefab)` |
| No Job09 rows in pawn AI data: `AIGoalCategoryJob.JobDecisions` (111 goal params, jobs 1..6 only; Job07-09 appear only in a carry/wrestle goal), `CustomSkillDecisions` (82 sets, none for 92..120) | live walk of `AIGoalPlanning._AIGoalData` | append Job09 to the Warrior entries' `_Job` arrays; add `CustomSkillDecisionSet`s whose packs are cloned templates with `ActNo` commands |
| Guild UI hides hybrids for pawns | `GuiManager.requestJobGuildMenu2(disabledJobs...)` | not needed: `JobContext.setJobQualified(9)` + `HumanJobChanger.requestChangeJob(9)` |
| No censer in the pawn's equipment | item ids 2000..2010 = `wp09_000_00`..`wp09_012_00`, `_Job` bit 128 = Job09 | `ItemManager.getItem(2000, 1, chara, 0)` → `addEquipChangeInfo(storage, chara, Main=0, true)` → `applyEquipChange()` |

Expected quality once the gates are lifted: the pawn fights with censer swings (normal attack = `Job09_ShortSmokeAttack`,
draws aggro to itself), summons the simulacrum (heavy attack = `Job09_SummonDecoy`, then enemies hit a 1500 HP
decoy with a 30 m territory), and casts Aromatic Rally / Sweeping Shroud / Dragon's Delusion / Delusory Screen
through cloned decision logic. Latching Effigy (96) and Espial Incense (119) are context actions (no action name
from `getCustomSkillAction`) and stay out of scope. This is "a Trickster that plays like a support pawn", not a
human player's Trickster; see "What will be rough".

## How Trickster works inside the game

### Actions (`app.Job09ActionID`, 59 names)
Core: `Job09_Normal`, `Job09_ShortSmokeAttack` / `MoveSmokeAttack` / `DashSmokeAttack` (censer swings = Beveiling
Fumes), `Job09_PrepareThrowSmoke` / `ThrowSmoke` (Drifting Brume), `Job09_SummonDecoy` / `SummonDecoyDash` /
`SummonDecoyFinish` (Effigial Incense), `Job09_Transfer` (Invoking Essence, beckon), `Job09_Unsummon` (Effigial
Snuff), `Job09_Wear` (Enthralling Aroma, possess with the decoy), cling/hold-down variants, small levitate.
Skills: `Job09_CastSmokeWall` (Delusory Screen), `CastSmokeGround` (Fickle Floor), `CastAttentionFregrance`
(Sweeping Shroud), `CastPossessionSmoke`/`Ex` (Latching Effigy), `CastRageFregrance` (Aromatic Rally),
`CastSmokeDragon` (Dragon's Delusion), `CastDetectFregrance` (Scented Alarum), `CastFocusAimSmoke` (Espial
Incense), plus the cut `CastHealingSmoke`, `CastTripFregrance`, `PrepareSmokeGiants`/`CastSmokeGiants` (the
"#Rejected#" skills in `job09act.msg`; Smoke Giants is still used by the duel NPC).

`Job09ActionSelector.getCustomSkillAction(id, speed)` (read live on the Arisen): 92→`Job09_CastSmokeWall`,
93→`CastSmokeGround`, 94→`CastTripFregrance`, 95→`CastAttentionFregrance`, 96→"" , 97→`CastRageFregrance`,
98→`CastDetectFregrance`, 99→`CastSmokeDragon`, 118→`CastHealingSmoke`, 119→"", 120→`PrepareSmokeGiants`.
`getNormalAttackAction` = `Job09_ShortSmokeAttack`, `getSubNormalAttackAction` = `Job09_SummonDecoy`.

Skill ids (`app.HumanCustomSkillID`): SmokeWall 92, SmokeGround 93, TripFregrance 94, AttentionFregrance 95,
PossessionSmoke 96, RageFregrance 97, DetectFregrance 98, SmokeDragon 99, HealingSmoke 118, FocusAimSmoke 119,
SmokeGiants 120. Normal skills: DecoyRegeneration 34, DecoyRangeUp 35, ThrowSmoke 36, DecoyFastSummon 37, Levitate 38.

### Controllers
- `app.Human` has `Job01..Job10ActionCtrl` on every human, pawns included. `Job09ActionController` holds the
  `DecoyHandler`, smoke-terrain registration, the Detect fragrance shell, Smoke Giants list and the Rally buff
  effect; `prepareDecoyAndAstralBody()` exists on it.
- `app.DecoyHandler { Owner: app.Human, Prefab: PrefabController, Instance: SmokeDecoy }` with
  `setup(app.Human)`, `setup(app.Human, via.Prefab)`, `create()`, `start(StartInformation)`, `vanish()`,
  `startPossessionSmoke()`, `startTransferSmoke()`, `startWear()`.
- `app.SmokeDecoy` (a `CloneCharacter`): `setOwner(app.Human)`, `clearHate()`, `setTarget(...)`,
  `updateTerritory()`, `IsTargetResistered`, `IsPossesion`. `OwnerPlayer` is a cached field that will be null
  for a pawn; nothing in the method list takes an `app.Player`.
- `app.Job09CastRageFregrance` has a `PawntList: List<app.Pawn>`: Aromatic Rally buffs pawns (the Arisen's
  party). Cast by a pawn, it should still find the other pawns; whether the Arisen is included is untested.
- `app.SmokeDecoyPossessController` lives on the possessed enemy; `app.PossessionManager` is dragonsplague,
  not Trickster.

### Parameters (`AppSystem/ch/Common/Human/UserData/Parameter/Job09Parameter.user`, full dump in `live/job09parameter_dump.txt`)
Decoy: BaseHp 1500, LowHpThreshold 800 (LowHpRate 0.3), FullRecoverTime 6 s, TerritoryRadius 30 m (41 m with
DecoyRangeUp), OutOfTerritoryDamage 0, SummonTime 1.0 s (0 with DecoyFastSummon), PossessionAttensionInterval
15 s, catch damage 500/1000, 82 per-enemy damage rates (0.4–6.0). Aromatic Rally: Lv1 5 s attack ×2.0, Lv2 10 s
×2.2, defence ×0.33, MaxHpDamageFactor 40, slip damage every 2–2.5 s. Each skill has shell request ids
(`Job_ID_09` / `AttentionFregrance`, `AttentionFregranceLv2`, ...) that the action resolves through
`humanshellparamdata_job09.user`.

### The duel NPC Trickster (`ch300962`, think table `ch300962_NRD_Job09CombatThink.user`)
15 tables, 61 rows (summary in `live/thinktable_ch300962.txt`): one Latching Effigy at the start of the fight
(`取り憑く似姿`), keep-distance and side-step loops, then an attack table with censer swing, dash swing and Smoke
Giants ×1 / ×3 on timers, plus a warp back into the arena. It never manages a decoy on its own. It is a scripted
duel enemy and not a model for a pawn; the pawn route uses the Utility module (goal planning) like every pawn.

## How pawn AI selects actions (confirmed live)
Main pawn out of combat: `AIDecisionMaker.CurrentModuleType = Utility`, module `app.DecisionEvaluationModule`
with 2 pre / 14 main / 7 post decisions (Warp, ClingCliff, DrawWeapon, Approach, Interact, TurnLantern, ...).
Goal planning (`app.goalplanning.AIGoalPlanning`) reads `_AIGoalData` (`PawnAIGoalData.user`): 27 goal types,
263 goal params, 111 of them `AIGoalCategoryJob` with `JobDecisions[] { _Job: JobEnum[], _DecisionPacks }`.
Job occurrences in those lists: Job03 98, Job04 83, Job06 83, Job01 78, Job05 75, Job02 66, Job07/08/09 2
(a wrestle/carry goal for non-Fighter/Warrior jobs). `_CSDecisions._CustomSkillDecisions` has 82 sets
(set 0 = Spell Stock, 18 packs). A decision pack (e.g. `Job03_FireBoon`) is: Priority, Policy (Magic|Help|Skill),
Target flags, cooldown 1 s / 10 s on success, preconditions (`State`, `PawnBattleState`, `IsPrepareSpell(skill)`,
`Personality`), target preconditions (`IsCaught`, `IsDead`, `StatusCondition`, `JobType`, ...), evaluation
criteria (curves), and an `ActInterPackData` whose nodes run `DrawWeapon` then `job03.FireBoon` with a
`move.KeepDistance` sub-command. The Warrior normal attack pack is `move.Approach` → `job.NormalAttack`: the
`job.NormalAttack` / `job.HeavyAttack` commands are generic and resolve through the current job selector, so a
Job09 selector turns them into censer swing / summon decoy with no new data.

## Approaches, ranked for Trickster

1. **Runtime Lua (recommended, prototype written):** `trickster/PawnTrickster.lua`. Lifts every gate above at
   runtime, clones four template decision packs (`Job03_FireBoon` → Aromatic Rally, `Job01_ShieldSummons_EMTarget`
   → Sweeping Shroud, `Job05_WarCry_EMTarget` → Dragon's Delusion, `Job04_SmokeScreen` → Delusory Screen) with
   `ActNo` commands, extends the Warrior `JobDecisions` lists with Job09, and gates a "summon decoy" decision on
   `DecoyHandler.HasInstance`. Effort to a first fight: the test session below plus a few iterations. Effort to a
   good pawn: 1–2 weeks of tuning (positions, when to beckon, voice lines).
2. **Loose-file data:** write Job09 rows into `PawnAIGoalData.user`, `CustomSkillDecisionRefData.user` and new
   decision packs. Same AI result, but needs an RSZ writer (the decoder in `tools/rszdump.py` reads only, and
   the Decision layout still has unknown trailing fields), and the selector/hook/decoy gates still need Lua.
3. **Native patching:** nothing here needs it.

## What will be rough
- Positioning: the pawn summons the decoy where it stands. A good Trickster places it between enemies and the
  party; the prototype relies on the decoy's 30 m territory and on Sweeping Shroud. A later version should
  beckon (`Job09_Transfer`) when the decoy is far and summon only near enemies (template conditions handle
  "enemy in range" already).
- `Job09CastRageFregrance.PawntList` buffs pawns; whether a pawn's cast also buffs the Arisen is unknown.
- Pawn voice lines for Job09 skills do not exist; `PawnTalk` processes in cloned packs will say Fire Boon lines.
- Hired pawns and the online rift: a stored Job09 main pawn loads `StrayPawnJobCombatResource_Job01..06` on
  other players' games (nothing for Job09). Keep it offline, or restore the job before saving/uploading.
- `HumanCombatResourceManager` has `getPawnJobIdx(JobEnum)` and `PawnJobCombatResource_Job01..06` only; the main
  pawn's own prefab (`CharaCombatResource_ch100000_00`) carries the Arisen FSM, effects ch01..ch09 and
  `ch100ColliderBank`, so colliders/effects are probably present, but the censer hit colliders are untested.

## In-game runs (2026-11-08, three launches with `load_space.ps1 -Launch -Seconds 35`)

Result: **the main pawn performed Trickster actions in game.** Run 3, main pawn (an Archer) in the field near Vernworth:

| Step | What happened |
|---|---|
| `JobContext.setJobQualified(9)` + `HumanJobChanger.requestChangeJob(9)` | job 2 → 9 immediately (qualified bits 48 → 304) |
| `HumanActionSelector.addJobSelector(chara)` | the game itself added `app.Job09ActionSelector` to the pawn's list |
| censer | `ItemManager.getItem(2104, 1, pawnChara)` puts the item in the shared inventory under the Arisen's id (2891076981); `passItem(sd, 1, pawnChara, false)` hands it to the pawn. `addEquipChangeInfo` + `applyEquipChange` queue and run but never replace the Main slot (the bow only comes off). Writing the pawn's `EquipData.Data.Equips[0] = sd`, `sd._IsEquipped = true`, then `applyEquipDataForCharacter(chara)` equips it: `getWeaponJob() = 9`, `IsEquipRightWeapon = true`. Item 2000 is a duospear (wp09 = Job07, `_Job` 128); censers are wp10 (`_Job` 512), items 2103–2105. |
| decoy handler | present on the pawn's `Job09ActionController` but with `Prefab = nil`. `setup(via.Prefab)` with the Arisen's prefab crashed the game on the next summon (AV reading 0x3F800010 at DD2.exe+0x524a361, crash kit `2026-11-08_140946`). Sharing the Arisen's `PrefabController` object (`set_Prefab(playerHandler.Prefab)`) works. |
| `requestAction("Job09_SummonDecoy")` | action list shows `Job09_SummonDecoy`; a `SmokeDecoy` instance appears 1 m from the pawn (`HasInstance`, `Appeared` true), no crash |
| `requestAction("Job09_CastRageFregrance")` | action list shows `Job09_CastRageFregrance` (Aromatic Rally) |
| `requestAction("Job09_Transfer")` | action list shows `Job09_Transfer` (beckon) |
| AI data | 73 `JobDecisions` entries extended with Job09, 4 skill sets added, summon pack added; the pawn's live `MainDecisions` then listed two `ActNo(Job09_SummonDecoy)` decisions (the module picked the injected pack up). No fight happened during the runs, so autonomous casting is still unobserved. |

Also learned: REFramework managed arrays have no `set_element` (assign `arr[i] = obj`; 4-byte enums live at `+0x20 + 4*i`,
written with `write_dword`); the equip queue is a `StoreEquipChangeInfo` list on `ItemManager`; `requestAction` works
even while `CurrentSelector` is still `NoJobActionSelector`; `PawnTrickster.lua`'s `config.json` overrides the defaults
(the first runs equipped item 2000 because of a stale config).

Still open: autonomous use in a real fight (positions, how often it summons/beckons), Aromatic Rally's effect on the
Arisen, hit colliders of the censer swing, and the equip path through the game's own queue (why `applyEquipChange`
refuses the swap for a pawn).

## Run 4: the fight test (2026-11-08 14:30)

Setup as before (job 9, censer 2104 in the Main slot, `addJobSelector`, shared decoy prefab, 73 job lists extended,
4 skill sets, summon pack) — all in one `enable()` after the array-type fix. Four bandits (`ch230000`, 1600/2500 HP)
were 65–77 m away and did not notice the party; `via.Transform.set_Position` does not move characters, but
`app.Character.warp(vec3, CharacterWarpOption 0)` does, so the bandits were warped 7–12 m from the party and the pawn's
battle state went to Battle with one contact.

| Phase | Observation (per-second log, `runs/run4_log.txt`) |
|---|---|
| first 60 s | the pawn only moved (`NormalLocomotion`, `Strafe`, dodges) while being hit (HP 1554 → 1135); its main list had 27 decisions including the Warrior attack packs and the two summon decisions, but they were never chosen |
| manual `Job09_SummonDecoy` | decoy appeared; from that moment the pawn's HP stopped falling and regenerated (1414 → 1485): the bandits turned on the simulacrum |
| summon pack re-scored (`FixedValue` ×20, rank High, 4 s cooldown) | 10 s later the pawn **chose attacks by itself**: `Job05_Tackle` ×9 (the Warrior packs' job-specific command still plays its Warrior action) and `Job09_SummonDecoy` ×2 more through the generic `job.HeavyAttack` decisions |
| end | all four bandits dead, decoy still up, pawn at 1478 HP; victory idle (`LivGoodJob`) |

What this settles: a pawn-owned simulacrum does pull enemy aggro, and the pawn's own goal planning will issue
Trickster actions through the generic heavy-attack path. What it also shows: (1) the pawn attack decisions scored
by `PawnCommonEvaluate` (which reads the per-job attack-range table set by `SetAttackRange`) never fire for Job09, so
Trickster decisions need their own evaluators (`FixedValue`/`DistanceFromTarget`) or an attack-range entry;
(2) job-specific Warrior commands (`job05.Tackle`) must be filtered out of the reused lists; (3) no `Job09_Cast*` skill
was chosen in this fight (the cloned skill packs keep `IsPrepareSpell`/`PawnBattleState` conditions written for
spells; they need the same evaluator treatment); (4) **the game autosaves at battle end** — the save was overwritten
with the Trickster pawn and restored from the pre-run backup afterwards.

## Run 5: the v2 decision set (2026-11-08 14:48, `runs/run5_fight_log.txt`)

v2 replaced the cloned Warrior/Mage/Fighter packs by one pack of seven decisions of our own (attack, summon, beckon,
shroud, rally, delusion, screen), each a field copy of `Job05_NormalAttack_01`'s first decision with a flat
`FixedValue` evaluator, no start/end processes, our cooldown/rank/skill id, and an `ActInterPackData` built with
`sdk.create_instance` whose single node runs `ActNo(<Job09 action>)`. Four bandits were warped to 9 m.

| Observation | Meaning |
|---|---|
| all seven decisions appeared in the pawn's MainDecisions (indices 8–11 for ours) and their cooldown timers ran (summon 720 f, rally 1500 f, delusion 2400 f) | the decision maker **selects** them: conditions, evaluator and ranks are fine |
| the fight log never left `NormalLocomotion`/`Strafe` for the ActNo decisions; patching `IgnoreMotionCheck=true`, `IsUpdateAimTarget=false` on the live `ActNo` objects and resetting the timers changed nothing | a decision whose `ActInterPackData` was made with `create_instance` is **inert**: `app.ActInterPackData` derives from `via.UserData`, and the ActionInterface evidently needs the native resource behind it |
| the one decision that reused a vanilla pack (`Job05_NormalAttack_01`'s own `ActInterPackData`) did act: `Job05_Tackle` ×5 | vanilla `.user` pack data works, and that pack carries a `job05.Tackle` node of its own, hence the Warrior move on a Trickster |
| right after `enable()` the current selector was still `NoJobActionSelector` (weapon job 9) | the selector switches on the next weapon draw; manual `requestAction` still played Job09 actions in runs 2–4 |

Consequence (v3, run 6): every decision reuses a **vanilla generic pack** (`GenericJob_HeavyAttack_01.user` =
`move.Approach` + `job.HeavyAttack`; `GenericJob_NomarlAttack_01.user` for the censer swing), and the existing hooks on
`PawnUtil.getJobHeavyAttackAction` / `...Hash` answer with the Trickster action that the **selected decision** stands
for (`_LastMainDecisionIndex` → MainDecisions wrapper → our `Decision` by address). The action hash is
murmur3-32 of the UTF-16LE name with seed 0xFFFFFFFF (verified against the four hashes read live), so any
`Job09_*` name can be answered without a lookup table. `config.json` `command_path = "actno"` keeps the created packs
for comparison.

## Runs 6a–6c: v3 in game (2026-11-08 15:08–15:24, `runs/run6b_log.txt`, `runs/run6c_log.txt`)

| Run | What happened | What it settles |
|---|---|---|
| 6a (15:08) | v3 `enable()` → **crash one second later** at `DD2.exe+0x5247c10` (called from `+0x5247b30`; the run-2 decoy crash was at `+0x524a361`, same region). The summon decision was enabled at once: out of battle, no target, pack just added. Crash kit `2026-11-08_150804`. | never let a Trickster decision fire outside a battle; add the pack only once the pawn is settled and in Battle |
| 6b (15:13) | gates (settled + Battle + Job09 selector current) never opened: `addJobSelector` appends the Job09 selector **behind two `NoJobActionSelector` entries**, so `updateCurrentSelector` never reaches it. Moving it ahead and updating made it current → **crash within a frame** at `DD2.exe+0x4b07c4` (stack through `+0x52c1a8b`). Crash kit `2026-11-08_151600`. | the Job09 selector must never be the pawn's current selector; every Job09 action in runs 2–6 played under `NoJobActionSelector` by name |
| 6c (15:17) | gates = settled 10 s + Battle. Decisions created with `_Enabled=false` **never appeared** in the module's `MainDecisions`; a fresh pack with all seven enabled had to be added from the console and showed up ~13 s later. `_LastMainDecisionIndex` is the **evaluation cursor** (8 → 13 → 18 every frame), not the choice. Against the warped 104 k-HP enemy the seven wrappers had their `CooldownTimer` reset to 300 f every 5 s in round robin (the module's retry backoff), then sat at 0 — never chosen, the heavy-attack hooks never called. The bandits died to the Arisen before the pack was in the list. | `app.AIDecision` wrappers copy the `Decision` fields at add time (no back pointer; our per-decision Guid survives in `UniqueID`); gating must happen at add time or through the hook, not by toggling `_Enabled`; a real pick shows as the wrapper's timer jumping to its `CooldownTime` |

The only decision ever **chosen and executed** so far is run 5's attack slot, which carried a vanilla pawn pack
(`Job05_NormalAttack_01`'s own `ActInterPackData`, whose node is `ActNo` → `Job05_Tackle`). The `GenericJob_*` packs
used in 6c are NPC ("generic job") packs and were never chosen. Hence v4: every slot borrows the pack of the vanilla
pawn decision `Common_HeavyAttackFinish` (`move.Approach` with `AttackRange` decorator → `job.HeavyAttack`), the
template's `SetAttackRange` start/end processes are kept, the pack is added only when the pawn is settled and in
Battle, and the heavy-attack hooks answer per slot and decoy state (attack → censer swing; summon → summon / beckon /
Sweeping Shroud; skill slots summon first when no decoy is out).

## Runs 7–10: the pawn fights as a Trickster on its own (2026-11-08 15:30–15:53)

| Run | What happened | What it settles |
|---|---|---|
| 7 (15:30, v4) | all slots on `Common_HeavyAttackFinish`'s pack (live for every pawn), template start/end processes kept, pack added once settled + in Battle → **crash in the same second** at `DD2.exe+0x523a668` (stack `+0x525a3f4` ← `+0x5244903` [call rax+0x30] ← `+0x527218c` ← `+0x5644359`), before any pick. Crash kit `2026-11-08_153235`. | never share an `ActInterPackData` with a decision that is live for the same pawn; never add the pack mid-battle |
| 8 (15:35, v5→v6) | the atlas's "`ActNo`" packs were our own run-3 mutations: the real `Job05_NormalAttack_01` is Approach → `job.NormalAttack` → `job05.Tackle` → `NormalAttack` → `job.ComboAttack`. The `PawnUtil.getJob*AttackAction(Hash)` hooks were never hit in any run: `job.NormalAttack/HeavyAttack` do not resolve through `PawnUtil`, so they are no vehicle under `NoJobActionSelector`. v6 hot-reloaded: the vanilla **shell** (`ActInterPackData`) of an inactive-job pawn pack keeps its native resource, and its `_Pack` is swapped for our single-node `ActNo` list (restored on disable). Added fine, but every pack added after the hot reload was dropped by `DecisionPackHandler.addCheckedDecision` (even one with the vanilla node list). | the shells work; a hot-reloaded script cannot add packs (two `PawnTrickster` instances) |
| 9 (15:44, v6 fresh) | pack added in Battle + `setNewDecisionLists()` → wrapped instantly (`5 of ours in MainDecisions`), then **crash within seconds** at `DD2.exe+0x5645f7c` (evaluation core, same `+0x564xxxx` family as run 7's frame 4). | forcing the rebuild / wrapping mid-battle is what crashes; the module must wrap on its own |
| **10 (15:47, v6, pack added 10 s after enable, out of battle)** | wrapped on the module's own rebuild (`5 of ours, 17 total`), bandits warped in. **Real picks** (wrapper timer = full cooldown): summon 15:49:01, rally 15:49:13, summon 15:49:18, screen 15:49:31 … but the `ActNo` ended without an action (`CarryEnd`, `StrafeActionTurn`). After setting `IgnoreMotionCheck=true` and **`CancelSequenceFlags=0xFFFFFFFF`** on the five commands, the next picks played: **`Job09_SummonDecoy` 15:51:59 (decoy=true), `Job09_CastRageFregrance` 15:52:06, `Job09_SummonDecoy` 15:52:11, `Job09_CastSmokeDragon` 15:52:18, `Job09_SummonDecoy` 15:52:27, `Job09_ShortSmokeAttack` 15:52:35, `Job09_CastRageFregrance` 15:52:39, `Job09_SummonDecoy` 15:52:42, `Job09_ShortSmokeAttack` 15:52:48, `Job09_CastSmokeWall` 15:52:52**, all chosen by the pawn's own decision maker, no `request()` call, pawn HP steady at 1465–1471 while the 104 k-HP enemy was 14 m away. `runs/run10_log.txt`. | **the main pawn fights as a Trickster autonomously**: summons, re-summons, Aromatic Rally, Dragon's Delusion, Delusory Screen, censer swings |

How the executor runs a pack (read live in run 10): `ActionInterface.<Executor>` keeps a `LinkedList<ActInterNode>` and a
`CommandExecutor` whose `_PrimaryCommand` is a **clone** of the node's command (the pack's own command objects keep
`Owner = nil`), so command fields must be right *before* the pick; `ActNo` runs `RoutineType` TargetDir → Ready →
Action → Wait, and with `CancelSequenceFlags = 0` it never reached the request.

### The working recipe (v6, `PawnTrickster.lua`)

1. `requestChangeJob(9)` + censer into `Equips[0]` + `addJobSelector` + shared `DecoyHandler.Prefab` + 4 skills (as before).
2. Each slot = field copy of `Job05_NormalAttack_01`'s first decision (State/BattleMode preconditions, benign target
   conditions), `FixedValue` evaluator, no start/end processes, own cooldown/rank/skill id, fresh Guid,
   `_Enabled = true`; its `_ActInterPack` is the **vanilla shell** of an inactive-job pawn pack
   (`Job05_NormalAttack_01`, `Job01_ShieldSummons_EMTarget`, `Job03_FireBoon`, `Job05_WarCry_EMTarget`,
   `Job04_SmokeScreen`) whose `_Pack` is replaced by one `ActInterNode` running
   `ActNo { ActionID = Job09_…, CancelSequenceFlags = 0xFFFFFFFF, IgnoreMotionCheck = true }`.
3. The pack is added **once, out of battle, ~10 s after enable** (`require_battle = false`, `force_rebuild = false`);
   the module wraps it on its next rebuild. Never force `setNewDecisionLists`, never add in battle, never make the
   Job09 selector current.
4. `disable()` restores the five vanilla `_Pack` node lists and the pawn's job and weapon.

Done since (v7–v9, runs 11–12 below): beckon and Sweeping Shroud through the summon slot's per-frame `ActionID`
multiplex (which is also the summon gate: no decoy → summon, decoy far → beckon, decoy near → Shroud), the hooks
removed, the shells chosen at enable from jobs no pawn in the party has (`SHELL_POOL`, five packs per job for
Job01/03/04/05/06, the main pawn's previous job avoided too). Still to do: tuning of values and cooldowns (the pawn
casts almost continuously), Rally's effect on the Arisen, Latching Effigy / Fickle Floor / Espial Incense slots,
auto-enable and save safety for everyday use (the game autosaves the Trickster pawn at battle end).

## Runs 11–12: beckon/shroud multiplexing, no hooks (2026-11-08 17:53–18:00)

- **Run 11 (v7).** The summon slot's `ActNo.ActionID` is re-pointed every frame from the decoy state (no decoy →
  `Job09_SummonDecoy`; decoy farther than 15 m → `Job09_Transfer`; decoy near → `Job09_CastAttentionFregrance`), which
  works because the executor clones the node command at pick time. A party check logged the hired pawns' jobs:
  **Mage (3) and Thief (4)**, so the `Job03_FireBoon` / `Job04_SmokeScreen` shells were live for them. Crash 4 s after
  the bandits were warped in, before the battle started, at `DD2.exe+0x524507e` with a REFramework hook trampoline
  (`dinput8.dll+0xb5555`) in the think-update stack (crash kit `2026-11-08_1755`). The `PawnUtil` /
  `PawnSkillActionController` hooks never fired for job 9 in any run, so v8 turns them off (`cfg.hooks`) and borrows
  Fighter shells (`Job01_CymbalAttack`, `Job01_RushAttack`) for rally and screen.
- **Run 12 (v8).** No crash. Three seconds after the bandits arrived: `Job09_SummonDecoy`, mux → beckon (decoy far) →
  Sweeping Shroud (decoy near), then `Job09_CastSmokeDragon`, `Job09_CastSmokeWall`, `Job09_CastRageFregrance`,
  `Job09_ShortSmokeAttack`, repeated Sweeping Shroud: within the first minute 1 summon, 4 Shroud, 2 Rally,
  2 Delusion, 3 Screen, 4 censer swings, all from the pawn's own decisions. Against the 104 k-HP enemy afterwards
  (two minutes): 9 Shroud, 4 Rally, 2 Delusion, 2 Screen, 8 swings; pawn HP dipped to 600 and recovered to 1473, the
  decoy stayed up the whole time. `runs/run12_log.txt`.
- **Run 13 (v9).** Shells chosen at enable from jobs no pawn in the party has: party jobs 2, 3, 4 → all five shells from
  Fighter packs (`Job01_ShieldSummons_EMTarget`, `Job01_CymbalAttack`, `Job01_RushAttack`, `Job01_BlinkStrike`,
  `Job01_BravesRaid`); summon 2 s after the bandits arrived, mux → beckon → Shroud as in run 12. (A first launch failed
  on a Lua scoping slip: the party job set was declared after `step_ai`; fixed.) `runs/run13_log.txt`.
- **Run 14 (v10, caster stance).** A sixth slot whose node ran a `shallow_copy` of `Common_KeepDistance_Dash`'s
  `move.KeepDistance` command with the `_Distance` band rewritten to 6–10 m **crashed the game within a second of
  `addDecisionPack`**, out of battle (`DD2.exe+0x52590e4` ← `+0x548e8c1` ← `+0x16824e`, crash kit
  `2026-11-08_1846`). The copied command carries runtime references (`JumpRequester`, navigation controller) that a
  cloned move command evidently must not inherit. The slot is off unless `cfg.stance = true`; a stance should reuse a
  vanilla `move.KeepDistance` node whose range already fits (the Archer `Job02_KeepDistance_*` packs are candidates once
  the main pawn is no longer an ex-Archer), or set the band on a fresh `create_instance` command rather than a copy.
- **Run 15 (v11).** The stance slot references a **vanilla `ActInterNode` object** instead (no copied or created move
  command): `Common_KeepDistance_Dash`'s node, swapped into the shell live. Picked at 18:57:11 and executed with no
  crash, the pawn kept casting at full HP. The Archer dumps settle the semantics: `move.KeepDistance._Distance` is a
  band **on top of the character's attack range** (`Job02_KeepDistance_01/02` use `StrafeKeepDistance` 0–0.5 m behind
  `ContinuousAimedShot`/`Aim`; the Common node uses 0–3 m), so a caster stance for a Job09 pawn needs the attack range
  set first (the template's `SetAttackRange` start process, pointed at a long-range action, is the lever to try). The
  v11 code picks the first vanilla KeepDistance node whose band starts at `stance_min_band` or more, so with the
  default 4 m it finds none and logs it; `stance_min_band = 0` takes the Common node. A slip in v11 (`a and f() or g()`
  with `f()` returning nil) built an `ActNo(nil)` for the stance slot; it was re-pointed live and is fixed.
- **Run 16 (v12): the caster stance, found.** The fight log now carries the pawn-to-nearest-enemy distance. The pawn's
  AI blackboard (`AIDecisionMaker._AIBlackBoardController.<BBAggregate>`, collections Common / Action / Formation /
  Npc / Situation keyed by the `app.BBKeys.*` enums) holds `Action.Float.AttackRangeXZ` (key 1) and `AttackRangeY`
  (key 2), readable and writable through `AIBlackBoardFloat.getValue(int)` / `setValue(int, float)`. For the Job09 pawn
  **`AttackRangeXZ` was 0.0** (no Job09 entry in the attack-range table), which is why every `Approach` and
  `KeepDistance` band collapsed to melee. Set to **9.0 m** live (never overwritten afterwards), the pawn fought the
  104 k-HP enemy from **24–35 m** for the whole observed minute (9 Shroud, 8 swings, 3 Rally, 2 Delusion, 2 Screen),
  HP 1375 → 1368 instead of the 600 dips seen before. v12 holds `cfg.attack_range` (default 9.0) on the blackboard every
  frame; the vanilla locomotion decisions then keep the pawn at range on their own, so the extra stance slot is optional.
  `runs/run16_log.txt`.
- **Run 17 (tuning attempt, failed).** Censer swing at value 1.0, skill weights 12/10, summon slot 18 s, stance slot
  at weight 16: against the bandits the pawn stayed at 1–3 m swinging (8 swings), the stance slot never won a pick,
  and the pawn **died** after 80 s (HP 1554 → 0 under three large hits). `runs/run17_log.txt`.
- **Run 18 (v13 + Mage templates): the fix.** (1) The stance slot is gated live through its wrapper's
  `CooldownTimer` (held at 600 f while no enemy is within 6 m, reset to 0 when one closes in): wrappers ignore
  `_Enabled` after the add, but the timer is read every tick. (2) Stance weight 18 / value 1.0, censer swing back to
  0.8 × 14. (3) Templates from the party Mage (the user's idea): its blackboard `AttackRangeXZ` read live is **30 m**
  (Thief 0 out of combat), and the Mage's vanilla `Job03_KeepDistance_01` decision pack (`Approach` +
  `StrafeKeepDistance`, Mage conditions, `DistanceFromTarget` / `ScaleType` / `NumberOfEnemiesAroundTarget`
  evaluators) was added to our pawn as-is (list 18 → 20, no crash). Same bandits, same timing as run 17: the pawn
  **ended the fight at 1548 / 1554 HP**, real stance picks between casts, 4 Shroud, 2 Rally, 1 Delusion, 1 Screen,
  3 swings, decoy up. `runs/run18_log.txt`. v14 reads the Mage's range at enable (`attack_range = "mage"`), adds the
  Mage pack by default (`mage_keepdistance`), and the gate has hysteresis (release under 6 m, block beyond 9 m).
  Default range stays 9 m: the Mage's 30 m keeps a Trickster too far from the decoy it should be luring enemies onto.
- **Run 19 (v15, last run of the day).** No melee slot, a 5 s retreat window after each summon, skill gates through
  the wrapper timers (Rally only with the Arisen within 12 m, Delusion only with an enemy above 5 000 HP within 40 m,
  Screen only when the pawn is under 60 % or the Arisen under 50 %), range 10 m, the Mage keep-distance pack added at
  enable. Everything engaged as designed (summon at +3 s, retreat window, Rally gate following the Arisen's distance),
  but the **Arisen died within ~25 s** of the four bandits being warped to 9 m, which froze the test (the pawn then stood
  at 1 257 HP for three minutes with nothing to do). The Mage's blackboard range read **4 m out of combat** (30 m in
  combat), so the `"mage"` option must sample it during a fight. `runs/run19_log.txt`.

## Runs 20–22: a new low-level save, and the menus (2026-11-08 21:28–22:05)

The user switched to a fresh character (Lv 1 Arisen at Borderwatch Outpost, Mage main pawn, no hired pawns), which
changed the test setup and exposed what the menus do with a Trickster pawn.

- **Run 20 (v16).** Party = the main pawn only (job 3 → 9), so the shells come from Fighter packs. After the job change
  the pawn's own Job03 packs were not live any more (the new liveness check on `MainDecisions` Guids passed, and the
  Mage's `Job03_KeepDistance_01` was added without conflict). No enemy was loaded inside the outpost, so the test
  spawned two "Goblin (weak)" (650 HP) through Skill Maker's `NickCore.enemySpawner`; a `Vector3f` handed over as the
  universal position is read as `via.Position` doubles (garbage x, the goblins fell out of the world), so the helper
  spawns at the Arisen's position and warps each goblin to its spot (`PT.spawn_enemies`). Fight: summon at +5 s, the
  decoy up throughout, Rally ×3, Screen ×1, stance ×1, pawn 400 → 309 HP at 10–14 m; the idle Lv 1 Arisen was still
  hit to 81/366 and 151/480 and a console guard healed it (`recoverAll`). Two facts for the code: `app.Character` has
  no `get_MaxHp` (the current maximum is `get_ReducedMaxHp`, the loss-gauge value; `get_OriginalMaxHp` the full one),
  so the v16 protect rule never fired from the script; and `PT.enemies()` logging flooded the log (quiet scans now).
  The outpost guards killed both goblins. Crash afterwards from a probe calling `get_StaminaManager()` (never again).
- **Run 21 (v17, the menus).** The pause-menu Status page is `app.ui060601_01` (`IsPawn`, `JobIcon`/`StatusJobIcon`
  of type `app.GUIBase.JobIconRef` {Job, Tex}, `TxtJobName`, `SkillCtrl.ItemList`). It can be driven without focus:
  `GuiManager:requestGuiType(12)`, `ui060101:selectMenuSub(4)`, then `PartyList:setSelect(1)` +
  `partyListCtrlSelectionChangedIsPC()` for the pawn page. For the Job09 pawn the game drew icon cell 10 (the "?"),
  no name and four empty skill rows (what the user saw). `JobInformationParam._EnablePawn` (false for Job09) changed
  nothing when set; flipping `IsPawn` changed nothing. **The gate is the static `app.GUIBase.isDispEnableJob(JobEnum)`:
  true for Job01–06, false for Job09, asked four times per page build.** With a post-hook answering true for Job09
  the same page built, through the game's own code, the name "Trickster" and 13 skill rows (the four custom skills
  97/95/99/92 and the five Trickster core skills). The icon cell still came out as 10: `JobIconRef.setup(JobEnum)`
  maps Job09 to the "?" cell for pawns, so a second post-hook swaps cell 10 for cell 8 (Trickster crest; cells checked
  on screen: 3 Thief, 7 Magick Archer, 8 Trickster, 9 Warfarer). Both hooks are `cfg.ui_fix` (v18/v19). A test call
  of `GuiManager:requestJobGuildMenu2` crashed the game (as in the Paladin notes; the guild list must be checked at a
  real guild).
- **Run 22 (v18 + console icon hook).** Fresh launch; the Status page of the pawn showed the Trickster crest, the
  name and 13 skill rows with the mod's hooks only (`runs/run22_log.txt`). A `%d` on float HP in the protect log
  raised a Lua error every tick and disabled the whole gate block for this run (fixed in v19), so the fight ran with
  the summon mux and the range keeper only.

### Where this leaves the design (2026-11-08, end of the evening window)

- **Fighting.** The pawn fights as a Trickster on its own: summon, beckon/Shroud through the summon multiplexer, Rally,
  Delusion, Screen, a live-gated keep-distance stance, the Mage's keep-distance pack and a 10 m blackboard range. Run 23
  (v19, two weak goblins, Lv 1 party): summon 3 s in, Rally, stance and Screen picks, and the protect rule fired when
  the Arisen lost 39 % in 3 s (summon slot released at once). The pawn still takes hits at 6–8 m (`DmgShrink*` while
  casting Shroud next to the decoy); the next tuning pass should keep the pawn farther from the decoy it beckons to
  (cast Shroud, then back off) and watch stamina (two `RunningOutOfStamina` stretches in run 20).
- **Menus.** `cfg.ui_fix`: `app.GUIBase.isDispEnableJob(Job09)` answers true and `JobIconRef.setup(Job09)` draws
  cell 8, so the Status page shows the Trickster crest, name and skills for the pawn. Unverified: the Vocation Guild list
  for the pawn (the same gate is the likely switch; `requestJobGuildMenu2` from Lua crashes, so this needs a real guild)
  and the HUD/party-list icons (the icon hook covers every `JobIconRef`, so they should follow).
- **Persistence.** Run 24 reloads the autosave written at the end of run 23 with the pawn stored as Job09 + censer, with
  `auto_enable` on, to see what the game does with a saved Trickster pawn (see NOTES for the result).
- **Test setup for a low-level Arisen.** `PT.spawn_enemies({"Goblin (weak)"}, 12, 10)` (NickCore spawner), `test_guard`
  0.6 (recoverAll), one or two goblins. Four warped bandits at 9 m (run 19) or two goblins on an idle Lv 1 Arisen without
  the guard (run 22) end in a game over.

## Runs 35–47: why the decoy did nothing for a pawn, and the fix (2026-11-09 morning)

A hate recorder (each goblin's `app.HateSystem._Ranking`, an `app.HateCalculator[]` with `_TargetObj`,
`_TargetSmokeDecoy` and the temp / not-forget / distance hate values) showed the root cause of every melee death:
**the pawn's decoy was never a hate target**. Enemy code only handles the player's decoy: `HateSensor.updateDecoyHate`
is called every frame with the player's GameObject, `EnemySmokeDecoyUtil.getDecoyObject(Human)` is asked only about
the player's Human (3 629 calls, all for the Arisen), and the owner's hate entry is then retargeted to the decoy.
Everything tried on the pawn's own decoy failed or crashed: forcing `HateSensor._IsDetectDecoy`, mirroring the instance
into the Arisen's handler, `IsTargetResistered` / `AttensionTimer`, `addHateParam` (crash on a nil Nullable),
`registerSendHate`, `AddHateToSpecificEnemies` (threw), writing `OwnerPlayer` (crash), `setOwner(Arisen)` (crash),
`updateDecoyHate(pawn, decoy)` by hand, `_TargetSmokeDecoy` on the pawn's entry (the entry vanished).

**The fix (v31):** the pawn's `Job09ActionController` is given the **Arisen's own `DecoyHandler` object**
(`set_DecoyHandler`; the Arisen is not a Trickster, so its handler is idle). The decoy the pawn summons is then
natively "the player's decoy": in run 41 both goblins ranked it first within two seconds. Follow-ups:

- A dispersed decoy does not vanish, it **sleeps** (`SmokeDecoy.onDamageHit` → `CloneCharacter.finish` → `sleep`;
  `HasInstance` stays true, `Hidden` true). Letting the AI play `Job09_SummonDecoy` over that sleeping instance crashed
  twice (runs 42/43); `handler.vanish()` on it crashed; `handler.finish()` is a no-op. The game's own re-summon is
  `CloneCharacterHandler.start(StartInformation{StateName "Start", Position, Rotation})` → `applyStartInfo`, and that
  call works from Lua on the shared handler: **v35 re-summons a sleeping decoy that way**, at most every 6 s, and the
  multiplexer never arms the summon action while an instance exists.
- v36 places the re-summoned decoy 6 m from the pawn towards the nearest enemy; v37 opens the retreat window after it.
- Runs 46–49 (v35–v39): decoy ranked first / alternating with the pawn, two to five automatic re-summons per fight, no
  crash across seven 2–3 minute fights plus idle time, pawn 400 → 265–353 HP against two goblins (it died or dropped to
  ~150–200 before). v39 stops the Sweeping Shroud casts next to the decoy (their attention never lands for a pawn), so
  the pawn is rooted less; `cfg.shroud = true` restores them.
- Not achievable yet: Sweeping Shroud's attention (not-forget hate on the decoy) stays 0 for the pawn; the decoy competes
  with the pawn on distance hate alone, hence the placement rules. If the Arisen becomes a Trickster, the pawn keeps its
  own (inert) handler (`cfg.share_player_decoy`).
- Crashes to never repeat (all in NOTES): `addHateParam` with a nil Nullable, owner rewrites on the decoy,
  `vanish()` on a sleeping instance, the AI summon over a sleeping instance.

## Run 58: the inn's Vocation Guild, and goal planning (2026-11-09 afternoon)

The user made a new save in front of the Borderwatch innkeeper. The inn talk could be started from Lua after all
(NOTES, run 58): the innkeeper's talk is an `app.InteractiveObject`; from that spot its two coordinate checks failed
(`Work.isTerrainFound`, the counter blocks the ray, and `Work.isInCamera`, the hip-height point was out of frame), so
test-only hooks answered "clear" and "visible", a post-hook on `InteractManager.processHighestPriorityObjectForPlayer`
pinned a created `InteractPoint` on the innkeeper, and `addActiveInteract(player, point)` + `executeInteract(player)`
started the real talk. The talk select (`GuiManager.TalkSelect`, ui021601) is driven by `SelectedIndex` + `reqEnd()`
and its entries are readable in `ScrCtrl.InfoList[i].Msg`.

**Verified on the real guild screen (`app.ui040101_00`), pawn tab:**

- Vocations: Fighter, Archer, Mage (Rank 1), Thief, **Trickster** — Trickster with the crest (icon cell 8), "Rank 1",
  "Censers", the vanilla description, selected as the current vocation (`IsUnlocked` and `isEquip` from the mod's
  qualified bit). `JobInformationData` on the screen reads Job09 `_EnablePawn = true` (v43 hook) and `_DisableJobList`
  is empty.
- Weapon Skills: Unequip + the four unlocked Trickster skills; the game lists unlocked skills plus the next rank's
  (the Arisen's Thief at rank 1 showed Enkindled Blades / Shadow Cloak as "Acquire 200"), and the Trickster skill table
  (`GuiManager.CustomSkillJobDefineDictionary[Job09]`: 95 rank 1, 92 rank 2, 97 rank 3, 94 rank 4, 93 rank 5, 96 rank
  6, 98 rank 7, 118/119 Maister, 99/120 unobtainable) means more rows appear as the pawn ranks up with Dcp.
- Core Skills: Mending Vapor (150 Dcp, JobA 9); Augments: "Remove Augments" only at rank 1 (the pawn had 0 Dcp).
- Switching the character tab from Lua: write the tab's `_ListCtrl.InputKeyNext` bit into the GUI `SystemInput`
  flags and call `_CharaTab.updateInput()` in the same frame. Calling `_ListCtrl.next()` / `charaChange()` directly
  throws, corrupts the row item array (rows draw the default "Fighter" template) and the later close crashed the game.

**Posture (goal planning, v44).** The pawn's `AIGoalPlanning._AIGoalData._GoalTypeList[]._ParamList[]._GoalParam
._DecisionCategory` (`AIGoalCategoryJob`) maps vocations to decision packs per situation: 98 rows list the Mage,
none listed Job09, so a Trickster pawn ran on the generic locomotion only. v44 (`cfg.goal_jobs`) appends Job09 to the
24 all-vocation rows (escape, dodge, formation strafe, wrestle...) and adds a Job09-only row next to each Mage row
that carries `Job03_KeepDistance_01` / `Job03_MoveAttackRange` (`cfg.goal_move_packs`); `disable()` restores the
vanilla arrays. Giving Job09 all 98 Mage rows kept the pawn at 8.9 m on average over a goblin fight (400 → 400 HP)
but also gave it the Mage casts (it froze in `JobMagicUser_StartMagicBarrier` with a censer and never summoned), hence
the movement-only version.

**Run 59: the stance node (v45).** The posture bug itself: the stance slot borrowed the only vanilla KeepDistance node
with a small band, `Common_KeepDistance_Dash`, whose `_Distance` is via.Range {start 0, width 3}: a dash *into* 0–3 m.
With {7, 5} (7–12 m) written into a cloned copy of that node (`cfg.stance_band`), the arena fight gave an average
pawn–enemy distance of 8.9 m with the decoy up on every tick, Rally cast 25 times and the pawn at 383/400 HP at the end.
Her 23 Dcp from the kill landed in the Job09 cumulative-exp slot (the game's own award; read it with the JobEnum
overload of `getJobExp`, the integer overload is an index).

**Progression through the real menus (runs 59–61).** The guild header shows the pawn's Dcp as earned (23 after one
goblin), `JobContext.addJobExp(JobEnum 9, n)` raises her Job09 exp (23 → 623, rank 2) and the Vocations tab then
draws "Rank 2" with two pips plus "new" markers on Core Skills and Augments; exp and rank survive a save and reload.
`setJobExpWithJobRank` is a no-op on the pawn. Buying a skill through the real menu works (run 64): at rank 4 the list
offers Espial Incense for 700 Dcp and the two level-2 upgrades for 1000, the game's own confirm dialog deducts the Dcp
(3600 → 2900) and unlocks the row, then offers to equip it. Operational rule learned the hard way: never start a new
`InteractManager` interaction while `IsPlayerTalking` is true (guild or talk select open) — it kills every REFramework
Lua script and hangs the game logic behind the open screen (twice today).

## Using it (state at the end of 2026-11-09)

- Install: `PawnTrickster.lua` (v45) in `reframework/autorun/`, `config.example.json` as `reframework/data/PawnTrickster/config.json`
  (the installed copy is in place; `auto_enable` true makes the main pawn a Trickster at every load, re-equipping a
  censer from its storage, and the game then saves the pawn on Job09). REFramework UI → "Pawn Trickster (prototype)"
  has enable / disable buttons; disable sends the pawn back to the previous job (`revert_job`, Mage, when the save
  already had it on Job09) and removes the decision packs.
- What works: the pawn fights as a Trickster on its own (decoy that enemies actually target since v31, beckon, Rally,
  Delusion, Delusory Screen), the Status page shows the Trickster crest, name and skill list, a save keeps the pawn on
  Job09 with its skills, the pawn comes back after a reload with auto-enable, and **vocation progression is native**:
  after one fight the pawn had 46 Job09 experience, rank 1 of 9, 46 discipline (run 50).
- Known gaps: posture is fixed by the goal rows plus the 7–12 m stance band (v45 as installed, run 62: 12.2 m average, decoy up 99 % of the fight, 20 HP lost); the Vocation Guild list for the pawn is verified at the Borderwatch inn (Trickster
  listed, selectable, skills and core skills follow the vanilla rank rules). A pawn stored on Job09 is outside what the
  online rift expects (keep a save backup; `mods-src/crash-kit` and the `savebackup` recipe in NOTES). `test_guard` is a
  test-only Arisen heal and should be 0 for real play. Never drive the guild screen's own list controls from Lua
  (`_ListCtrl.next()`, `charaChange()`): see run 58.

### v46: memory and release mode (written offline, not run yet)

- `debug: false` (default): the pawn keeps her own Trickster setup. The save already keeps skill slots and unlocks;
  `reframework/data/PawnTrickster/pawns.json` (per pawn CharacterID) also keeps the censer, which the save drops at
  every load, and refills skill slots, levels, core skills and augments if the game ever loads them empty. A new
  Trickster pawn gets the rank-1 skills once (read from the game's skill table, fallback 95 + core 34). The AI only
  casts skills she has equipped.
- `debug: true`: the old behaviour, Aromatic Rally / Sweeping Shroud / Dragon's Delusion / Delusory Screen forced at
  level 1 every load, manual skill buttons in the panel.
- Censer list in the panel: equip one of her censers, or hand her one of the Arisen's (not the Arisen's equipped one).
- Open in v46 (v47 adds a soft reset, see below): a second save load in the same session is not re-applied (auto-enable runs once per launch).

### v47 (0.2.0): rank 4-7 skills, voice lines, stance preemption (run of 2026-11-09, 21:12-00:12, unattended)

Checked in game with v46/v47 in release mode (`debug: false`): censer 2104 and slots 97 95 99 92 come back from
`pawns.json` after a relaunch; `PawnTrickster.disable()` returns her to Mage with staff 1500, restores the 6 shell
packs and 27 goal rows; `enable()` in the same session brings the Trickster setup back; with her own four skills she
cast Aromatic Rally, summoned the decoy (taunt line), cast Dragon's Delusion (ended after 5 s) and Rally again.

- **The stance never ends by itself.** The keep-distance decision executes until something ends it, and a released
  slot of equal score never replaces it. `V.preempt` calls `forceEndDecision()` on the executor (safe, many calls) when
  one of our cast slots has been released and off cooldown for `preempt_wait` s, then gates the stance for 3 s. For the
  trick slot it also ends a vanilla movement decision (her action is NormalLocomotion / Strafe / Idle) after 0.3 s.
- **Never rewrite the trick command's `ActionID` at run time.** The third rewrite crashed the game twice, about 2 s
  later, in the local-frame GC (`DD2.exe+0x5244a30..0x5245081`; crash folders `2026-11-09_212102`, `_221158`,
  `_225359` under `mods-src/crash-kit/crashes/`). The trick slot is Latching Effigy only; Fickle Floor and Espial
  Incense are requested from Lua (`selector:requestAction(name, 0)`), Scented Alarum on layer 1 and stopped with
  `UpperBodyDefault`.
- **Latching Effigy** (`Job09_CastPossessionSmoke`, policy 17, `IsUpdateAimTarget` true): the smoke flies to the
  decision's aim target, not to the nearest enemy. It latched 5 times, each time with that enemy 4-6 m from her and
  on her level; it missed at 6.8-9.4 m, with the enemy 7-9 m below her, when a beckon (`Job09_Transfer`) cut the
  3.2-3.7 s cast, and when the aim target was a goblin 33 m away. Rules now: decoy out, 2+ enemies within 15 m of
  her, nearest 3-6 m away and within 2.5 m of her height; no beckon / summon / rally / delusion / screen for 4.5 s
  after the cast starts; when no enemy is in reach the stance is held for 8 s so the enemies close in. One possession
  lasted 6 s (the goblin died); `effigy_hold` (no backing off for 12 s while latched) is not measured.
- **Fickle Floor**: cast from Lua works; the ledge rule (ray casts between her and the nearest enemy, drop of
  `floor_drop` m) never fired in a real fight, only with `floor_need_ledge: false`.
- **Espial Incense**: trance, the decoy is moved next to the enemy nearest the Arisen, `...End` after `espial_seconds`.
  Seen twice.
- **Scented Alarum**: out of battle after `alarum_calm` s, every `alarum_interval` s, 2.5 s long. Seen.
- **Dragon's Delusion** is ended by a timer (`delusion_seconds`, 5 s; cast 23:15:38, End 23:15:43).
- **Voice** (the screen line named here never played; lines replaced in v47n, see the next section): `TalkEntity` is never played directly; the talk controller's
  `requestPawnTalk(category, pawn, nil, true)` plays any catalogued line. Lines used: taunt `PawnTalk_ACT_Hate_01`
  ("I'll hold the enemy's focus!", proven by a subtitle screenshot), screen `PawnTalk_ACT_Skill_Guard_07`, alarum
  `PawnTalk_CMN_Search_01` (both seen as accepted requests in the log only).
- **Soft reset**: when the main pawn's character object changes, the script drops its state and auto-enable runs
  again. NOT verified: the only in-session reload of this run (death screen, 23:25, v47i) crashed in the graphics stack (dxgi / D3D12Core / nvwgf2umx / dd2clouds / VollmondSky / NvCamera64, managed frame `app.FilterSettingBase<FilterParamHazeFilter>.update`, folder `2026-11-09_232500`); the cause is not proven. v47j stopped the script's own exceptions during the load and removed the write-backs from the soft reset, and was not put through a reload.
- **No slot for a skill she has not equipped (v47k).** The gates are cooldown writes (600) on the game's decision
  wrappers, and the game rebuilds its decision lists when the battle state changes (log: `track: 0 of our
  decisions` then `track: N of our decisions`): the new wrappers start at timer 0, so every slot can be picked
  until the next gate tick. In release mode (slots 97 95 99 92) she cast `Job09_CastPossessionSmoke` at 23:31:28
  without owning skill 96. `step_ai` now reads the equipped skills first and leaves out the trick / rally /
  delusion / screen slot of a skill that is not equipped (`ai: slot trick left out: skill 96 is not equipped`,
  pack with 5 decisions). Checked at 23:41-23:45: 16 Job09 actions over two list rebuilds, all from her four
  skills. Cost: a skill equipped during play gets its slot at the next load or after disable / enable. The same
  one-frame window still exists for an equipped skill whose tactical gate is closed (harmless: she owns it).
- **Crash right after `addDecisionPack`, intermittent** (cause found and fixed in v47m, see the next section): `DD2.exe+0x52590e4` at 23:36:16, the second the pack
  was added (folder `2026-11-09_233616`); the same offset as run 14 and as crashes on 2026-11-09 at 09:21, 09:59
  and 21:21. The next launch with the same script and save went through. Cause not found.
- While the game is not in the game phase (title, death screen, loading) the frame hook does nothing: during a reload
  the decoy's component threw `InvalidOperationException` in `get_GameObject` twice a frame before this check.
- A dead main pawn (`DieLoop`) is left alone: no casts, no errors (seen for 2.5 minutes).
- Test hazards: Skill Maker's spawner can return true and spawn nothing (check for "spawn: warped" lines, relaunch);
  the "Pawn Commands" tutorial window opens after every load; Space taps at load can open a pawn's hire dialog inside
  the Borderwatch inn (closed through `TalkSelect`, "Cancel").
- Fresh install (23:46-23:52, `config.json` and `pawns.json` deleted before the launch): both files were written
  (79 keys, `log` and `debug` false, `auto_enable` true; her censer 2104 and slots 97 95 99 92 kept), she was
  enabled without a log line, and a fight gave 5 picks, 2 preemptions and no error flag.
- Not tested at the end of that run (most of it was tested on 2026-11-10, see the next section): large monsters, flying enemies, world events, a Trickster Arisen next to her, hired pawns, a 30-minute
  soak, a brand-new pawn's first start, censer changes through the menus. `spawn_enemies` returned true for
  "Cyclops (weak)" twice and no cyclops reached the enemy list; the two spawned harpies stood idle on the ground
  (battle state 0), so that minute and a half of casting next to them says nothing about flying enemies.

### v47l-v47z (0.2.1): the random crashes fixed, a new pawn's start fixed, voice lines that really play (run of 2026-11-10, 08:57-13:57)

Raw facts, measurements and tool notes are in NOTES.md, "Run of 2026-11-10".

- **30-minute soak on the final build** (v47z, third load of a session): 1,736 battle ticks, decoy out 100 %,
  9.6 m from the nearest enemy on average, Rally 71, Screen 22, 26 voice lines, no error line.
- **Cause of the random crashes (v47m).** An object the script creates (`sdk.create_instance`, `MemberwiseClone`,
  managed strings and arrays), gives `add_ref()` and then lets the Lua garbage collector free *in the frame it was
  created in* corrupts the engine's table of frame-local objects. Measured from the console: 10 such objects crash the
  game within 8 s, 400 within 1 s; the same objects freed in a later frame, or holding `add_ref_permanent()`, do
  nothing. The script dropped one `ActInterPackData` wrapper per ActNo slot at every enable (the crash "the second the
  pack is added", `DD2.exe+0x52590e4`) and one `SmokeDecoy.StartInformation` per decoy re-summon (the crash 1-2 s
  into a fight, `+0x524507e` / `+0x5244b01`, 7 occurrences since 2026-11-08). `PT.keep` now gives every created
  object a permanent reference (34 sites). Since then: no crash of either kind in about 50 minutes of fights over 12
  launches, and none in the stress test that killed v47l.
- **A brand-new pawn's start (v47p, v47q).** 0.1.0 and 0.2.0 gave a pawn that never was a Trickster the cut skills
  118 and 119 next to Sweeping Shroud (the game's table lists them at unlock rank 0, opened by the game master).
  The starter rule now skips them, a pawn that has them loses them once, and core skills are read from the skill
  context's own list, so `pawns.json` records them. First start checked on the 2026-11-08 save (Mage pawn, no
  memory file): job 3 -> 9, starter censer 2104, Sweeping Shroud, Mending Vapor, a clean rank-1 fight.
- **Voice lines (v47n).** `requestPawnTalk` returns true for every category, but categories of talk groups 27 and 82
  never start: the 0.2.0 Delusory Screen line (`Skill_Guard_07`) never played. Lines now, each seen starting
  (`PawnManager.onStartPawnTalkMonologue`) and read as a subtitle: taunt `ACT_Hate_01`, Aromatic Rally
  `ACT_TalkInBattle_01`, Dragon's Delusion `ACT_ChanceTime_04`, a latched effigy `ACT_ChanceTime_01`, Delusory Screen
  cast for the Arisen `ACT_Worried_01`, Scented Alarum `CMN_Search_01`. A 0.2.0 config gets the new keys at load.
- **Real large and flying enemies** (release mode, four skills): 3 minutes against a cyclops (decoy out 83 % of the
  fight, 9.4 m from the nearest enemy on average, Delusion / Screen / Rally cast, downed 3 times and back each time)
  and 2 minutes against three harpies with three goblins (decoy out 100 %, put to sleep once), no error line.
- **Rank 4-7:** Fickle Floor's ledge rule fired on a real cliff edge (ledge found 2.5 m ahead, enemy 8 m away beyond
  it); Latching Effigy approach / cast / latch sequence seen again; `effigy_hold` still not measurable on enemies
  that die in 3 s.
- (The cause of the crash in the next point was found in the following run: see "v48a-v48d (0.2.2)" below.)
- **Returning to the title and loading again in one session: the script's part is fixed; this install still crashes there after open-world fights, with or without the script.** Fixed in the script: the state
  it left in the scene (v47r-v47t: the moment the game phase is left her packs are removed and the vanilla AI data
  the script borrowed is put back; no Job09 selector is added to her any more) and data kept across loads (v47v:
  the talk-category cache; v47w: a failed rule build is not retried every frame). Found in the test setup: enemies
  made with the test helper `PawnTrickster.spawn_enemies` outlive the scene unload (v47z cleans them through Skill
  Maker's `destroy_spawns()` once the title is up). On v47t-v47z: idle returns held 4 of 4; returns after arena
  fights against spawned goblins held 12 of 12 with that cleanup and crashed 3 of 6 without it; up to five loads
  in one session with a fight and a voice line in each. Returns after a fight against world harpies crashed 3 of
  3, **including the control with the script renamed away** (same address, same render stack: dd2clouds /
  VollmondSky / renodx-dlss / the NVIDIA driver): that crash belongs to this install, not to the script. NOTES.md
  has the trail. Not tested: a death-screen reload.
- **v47t: no Job09ActionSelector is added to her any more.** She fights the same without it (decoy, Rally,
  Delusion, Fickle Floor, Latching Effigy, Espial Incense, Scented Alarum all seen): her actions run by name under
  `NoJobActionSelector`. `job09_selector: true` brings the old behaviour back.
- v47u: the Lua re-summon of a sleeping decoy waits while her own summon action is creating the decoy.
- v47o: auto-enable waits until the same pawn object is seen on two checks (after a long warp the game can create and
  remove the pawn every few seconds, and the script enabled and reset in a loop).
- **A Trickster Arisen next to her:** she keeps her own DecoyHandler (with the Arisen's PrefabController) and
  fights with her own decoy (out 89 % of a one-minute fight, Rally and Screen cast, no error). The Arisen had no
  censer and did not cast herself.
- Not tested: hired pawns in the party, world events, a censer picked in her own equipment menu, a death-screen
  reload (the Arisen could not be killed from the console), an Arisen and a pawn both casting Trickster skills.

### v48a-v48d (0.2.2): hired pawns, the censer the game's way, and where the title crash really came from (run of 2026-11-10, 13:56-17:56)

Raw facts, the trial table and tool notes are in NOTES.md, "Run of 2026-11-10, 13:56-17:56".

- **The crash at the title screen (and on a load from the death screen) was not this script.** Two faults, found
  with one repeatable trial (30 s among the world harpies, return to the title):
  1. The Volumetric Clouds add-on kept the sky's depth view across frames and made a shader view from it after the
     game had destroyed that depth buffer (7-8 s after a scene is left): crash in the NVIDIA driver, or "device
     removed". Fixed in `mods-src/VolumetricClouds/addon/dd2_clouds.cpp`; its log now says "view dropped" at that
     moment.
  2. `DD2.exe+0x971cbf2` is the old `0x9717cd2` crash (a render record destroyed with a null view): the 4.2 patch
     moved the function and the DD2CrashTrace guard had not been installed since. The guard is now an exception
     handler that writes nothing into the game. It fired twice, each a few seconds into a title return (15:49:16,
     16:53:13), and the game went on.
  With both in place: 13 returns to the title out of 13 held, plus a death reload; before, the same trial went wrong
  6 times out of 6.
  The seven title crashes of the morning (arena and inn returns) carry the same driver address, so they were fault 1
  as well. Why they came more often with the pawn enabled, and with test-spawned enemies left alive, was not looked
  into. The teardown at the phase change (v47r-v47z) stays: it is right on its own.
- **A death and "Load from Autosave"** (real key presses on the death screen): unload, load, in game 18 s later; she
  is set up again by auto-enable, censer back, rules built, the low-health protect rule active at once.
- **Hired pawns (v48a).** A hired Mage, a hired Thief and a hired Archer fought normally next to her (Firestorm,
  Anodyne, barrier; Job04 attacks and dodges; aimed and threefold arrows) and she kept casting; a 12-minute soak with
  the Archer in the party ran without an error line (Rally 18, Delusion 3, decoy out 99 % of the battle ticks). The script used to read the party's vocations only at enable; now
  it watches them (`PT.party_sig`, every 2 s, same answer twice) and on a change puts her back to vanilla and lets
  auto-enable set her up again on vocations the new party lacks: 18 s after a hire, 19 s after a dismissal.
  `"party_watch": false` switches it off. Nine setups in one session (party changes, disable / enable, the borrowed
  vocation changing each time) each ended in a normal fight.
- **Next to a Fighter or a Warrior (v48c).** None was on offer at the inn, so `"avoid_jobs": [1]`, `[1, 5]`, `[1, 5,
  3]`, `[1, 5, 3, 4]` were used to build her slots on Warrior, Mage, Thief and Sorcerer decisions in turn: she summons
  and casts on each (4-5 picks in a 50 s fight). The hired Fighter itself was not seen.
- **(Explained and fixed in v48e, see the next section: not disable / enable.)** As written on the day: `disable()` / `enable()` twice in one session can leave her passive (she walks and strafes, picks
  nothing): clearly in 2 sessions out of 5, one pick in 45 s in a third, normal in two. The first cycle always
  works, party changes never showed it, the setup log is identical; loading the save again brings her back. Not the stacked enable that v48d now refuses (`enable()` does
  nothing while she is enabled), and not the borrowed vocation. Details in NOTES.
- **The censer the game's way (v48b).** The game's Equipment page showed her old staff as equipped and the censer as
  not, and the save never kept the censer: the script wrote her Main slot behind the game's back. It now calls the
  game's `ItemManager.setEquip` (slot write kept as the fallback, `"equip_by_game": false` forces it). The page shows
  the censer with the badge, the next load reads it back as equipped. A censer given to her and equipped in the
  game's own menu works too and is recorded in `pawns.json` within 3 s. `disable()` equips the old weapon again with
  the same call once her old vocation is back.
- Not tested: the Arisen and her both casting Trickster skills (left out on request), a hired Fighter or Warrior
  itself (only her side of it).

### v48e (0.2.3): why she went passive, found and fixed (run of 2026-11-10, 20:36-22:35)

Raw facts and the probes are in NOTES.md, "Run of 2026-11-10, 20:36-22:35".

- **The passive fights (she follows, circles, casts nothing) had two causes, both in the rules her casts are built
  from, and neither is disable / enable.** Every cast rule is a copy of the first decision of
  `Job05_NormalAttack_01` and kept that Warrior attack's conditions. Read live on her rule wrappers twice a second
  (`AIDecision.arePreconditionsValid`, each shared precondition's cached result, `checkTargetPreconditions` /
  `checkTargetConditions` for every enemy target):
  1. `tcondition.ImmuneToDamage` (target not immune to my weapon): against two phantoms every target failed it;
     Rally was released for 32.7 s and nothing was picked (v48d). With the check left out: 3 picks and 4 casts in the
     first seconds of the same fight.
  2. `condition.BattleMode{Ready|Battle}`: false while her own AI state (`Character.CharaAIStateCtrl`) is "Danger"
     (temp state 128 over base Normal), although the party's battle controller says Battle. Seen with five or six
     test goblins around the level 1 party: a 56 s fight and a 44 s fight with a cast released the whole time and
     no pick. Healing her or the Arisen did not end the state. With the check left out, same six goblins, AI state
     Danger for the whole minute: 8 picks, 8 casts, no released cast waited more than 3 s.
  `GeneralPointHeight{0, 2}` never failed in these fights (goblins, harpies up to 15 m above her); it is left out as
  well because a cast does not need to reach its target.
- **v48e:** `"rule_drop": ["ImmuneToDamage", "GeneralPointHeight", "BattleMode"]` (default) names the condition
  types `make_decision` does not copy; the log says what was left out. Since her own AI state no longer gates the
  casts, every slot is held while the party's battle state is not Battle (`"cast_in_ready": true` adds Ready). Out
  of battle her rules are not in the module's list anyway (0 of 5 tracked), and 50 s after a fight showed no cast.
- **Disable / enable is cleared.** Three cycles in a row in one session, a 50 s fight after each: 5, 4 and 3 picks,
  no cast waited more than 2 s. The 0.2.2 "open defect" was the Danger state (and, in the cycle test of this run's
  first attempt, a pawn that had died from a fall): the fights it was seen in were the ones with waves of test
  goblins piling up.
- **What was looked at and is not a cause:** stamina (the game's FullPower / SavedPower / Breaktime state), the
  vanilla "skill break time" (`PawnSkillActionController`: her skill count stays 0, so the High-rank walk rule that
  needs it never runs), the rank of her rules (a released cast was picked within 2.5 s in every healthy fight; the
  one 7.6 s wait was the vanilla Reaction-layer "dash back to the Arisen").
- **Her activity next to a vanilla Mage** (same pawn, same arena fight against waves of three goblins, sampled
  twice a second; the Mage is her after `disable()`):

  | | executing an attack / cast decision | executing a movement decision | lower-body action Strafe |
  |---|---|---|---|
  | vanilla Mage, 120 s | 68 % (Firestorm 34, barrier 11, bolts 20, Anodyne 3) | 17 % | 61 % |
  | Trickster v48d, 150 s | 26 % (Rally 17, Delusion 7, Screen 1, summon 1) | 72 % (her own stance 57) | not sampled |
  | Trickster v48e, 60 s (six goblins) | 41 % (summon / beckon 18, Rally 15, Delusion 7, Screen 1) | 51 % (stance 29) | not sampled |

  So a vanilla Mage strafes as much as she does, but with a spell in hand. The Trickster's only filler would be the
  censer swing, which is off because it does no damage and pulled her into melee (run 17). Not changed.
- **Aromatic Rally (v48e):** released when the Arisen **or another living party pawn** is within `rally_distance`
  (hired Archer in the party, Arisen out of range: the rule saw "pawn" for 17 of 24 battle seconds), and not
  started under `"rally_min_stamina": 0.5` of her stamina (v48d took her to -57 % in a goblin fight: winded, then the
  game's stamina break; with the check her lowest was 42 %).
- **Regression on v48e:** hired Archer in the party (hired by the load's key presses, she was set up again 20 s later), 6-minute arena soak against waves of three goblins: 134 s in the Battle state, 9 picks, 11 casts (Rally 10, Delusion 1, summon 1 in the log), no error line, no released cast waited more than 2.5 s; executing Rally 25 %, her stance 17 %, Delusion 6 %, summon 5 % of the battle samples; then the title, held for 60 s. Harpies, 100 s: no error (a harpy carried her off and she died from the fall, as a
  level 1 pawn does there). Return to the title after that (30 s watched) and a second load: she was set up again.
  The real cyclops, 127 s in battle with her AI state Danger throughout: 11 picks, 12 casts (Rally 7, Delusion 4,
  summon 1), no error line, no released cast waited more than 1.6 s. Then the Arisen at 1 HP without protection:
  the protect rule kept releasing summon and Screen for 70 s (6 more picks), she died to the cyclops, "Load from
  Autosave" by key presses: in game 33 s later, auto-enable, rules built 22 s after that.
  Latching Effigy (debug skill set 96 97 99 92, 150 s against goblin waves): the window opened twice and she cast
  it twice, the approach rule ran once ("no enemy in reach ... stance held 8 s"), 20 casts in all, no error.
  Final solo soak, 12 minutes against goblin waves: 700 s in the Battle state, 27 picks, 22 casts (Screen 10,
  Rally 9, Delusion 1, summon 1, beckon 1), no error line, no released cast waited more than 2 s, one death
  (revived by the test loop).
- **(Addressed in v48f by the regroup rule, next section.)** A design limit, not a fault: in a solo fight Rally is rarely allowed. In that soak she stood more than
  12 m from the Arisen for 83 % of the battle samples (15-20 m: 30 %, over 20 m: 48 %), so the Rally gate was
  closed 84 % of the time with "no ally in reach" and her own stance ran for 71 % of the fight (casts 14 %). The
  arena's Arisen stands still, a player moves, so play will differ, but nothing brings her back towards her
  allies: holding the stance for 25 s from the console left her at 15 m and more. A rule that walks her to the
  Arisen when Rally is ready would be a new slot (not written). With a hired Archer near her the same gate was
  open for 93 of 136 battle seconds.
- Not tested on v48e: a hired Fighter or Warrior itself, the Arisen and her both casting Trickster skills (left
  out on request).

### v48f (0.2.4): the decoy out of battle, a regroup rule for Rally, a hired Fighter (run of 2026-11-11, 08:24-09:36)

- **Nexus report on 0.2.2 (2026-11-11): "the pawn keeps spawning the trickster clone all the time. Even outside
  combat."** Two paths did that. The AI summon slot could fire whenever her own AI state was Caution or Combat
  (0.2.3 already holds every slot unless the party is in battle). And `update_summon_gate` re-summoned a dispersed
  decoy from Lua (`handler.start`) with no battle check: three such lines out of battle in the log of 2026-11-10
  (22:05:57, 22:09:41 twice). v48f: that call only while `PT.state.battle == 2` (`"resummon_calm": true` restores
  the old behaviour). After the fix: no summon and no re-summon in three calm stretches (105 s after a fight; 40 s
  after a dismissal by hand; 45 s after a far warp with goblins near and the party state Ready). A decoy that is out
  when a fight ends stays out (handler `Appeared` true two and a half minutes later, also 110 m away), as it does
  for the Arisen. In battle it is still re-summoned every `resummon_seconds` (6 s) when enemies destroy it: four
  times in 18 s next to the cyclops. The hidden-instance case out of battle itself could not be staged again (the
  decoy would not disperse on request); the fix rests on the condition in the code and on those calm stretches.
- **Regroup rule.** A seventh decision, `regroup`: target Player (`AITargetFlag` 2), its pack is the vanilla
  `Common/Move_Fix_Dash_Target` ActInterPackData untouched (one `move.Approach` node, `_FixedMove` 3, stop at 1 m,
  primary target = the decision's target; the same pack the Reaction layer uses to bring a pawn back). No shell, no
  command of ours. Released when Rally's own cooldown has run out (`V.slot_ready`), she is not tired, the party is in
  battle and no ally is within `rally_distance`; `V.regroup_tick` holds the stance while it runs and ends the dash
  with `forceEndDecision` at `regroup_stop` metres (8 by default; the gate block runs about twice a second and the
  dash covers several metres between two looks, so it stops one step early: she ends 5-6 m from the Arisen) or
  after `regroup_seconds`. The stance preemption list has the new slot.
- **Measured, solo, Arisen standing still, goblin waves** (same samplers as v48e):

  | | Rally executing | her stance | within 12 m of the Arisen | Rally gate open | casts | down |
  |---|---|---|---|---|---|---|
  | v48e, 12 min | 5 % | 71 % | 17 % | 16 % | 22 | 1 |
  | v48f, stop at 5 m (ended at 3-4 m), 8 min | 22 % | 42 % | 85 % | 71 % | 25 | 2-3 |
  | v48f, stop at 8 m (ended at 3 m: the overshoot), 200 s | 24 % | 54 % | 94 % | 89 % | 11 | 0 |

  Close to the Arisen she is close to the melee: with the 5 m stop she went down two or three times in 8 minutes,
  which is why the default is 8 m and the dash stops a step early. `"regroup": false` turns the rule off.
- **A hired Fighter, at last** (hired by the user, save `DD2_save_backup_20261111_hired_fighter`). At the hire she
  was set up again in 12 s with `avoid 1,9`: her slots on Warrior decisions. v48e, 150 s: the Fighter executed
  `Job01_Guard_1s`, `Job01_GuardKeepDistance_01`, `Job01_ContinuousNormalAttacks`, `Job01_BlinkStrike_Standard`,
  the generic dash attacks; 0 Job09 actions in 138 samples; she cast 8 times. v48f final build, 120 s: Rally 30 %,
  four regroups ending 5-6 m from the Arisen, 0 Job09 actions on the Fighter in 120 samples, no error line.
- **Regression on the final build** (driven with the tools of the public repository, which are the helpers of these
  runs made portable): title return, 30 s watched, second load, 60 s fight; `disable()` (job 3) and `enable()`, 60 s
  fight; no error line in the whole session. On the build before the stop-distance change: the cyclops with the
  Fighter, 100 s (she carried and revived the downed Fighter with the vanilla decisions). A death could not be
  produced: at 1 HP without protection the Arisen survived two and a half minutes of goblins behind the decoy, the
  Screen and the Fighter. "Load from Autosave" was last run on v48e.
- **Tool trap found:** the portable start script pressed Space while REFramework was still hooking the window
  (slow boot, another program was compiling shaders): the game process hung (32 s of CPU in 10 minutes, "not
  responding") and I looked ten minutes too late. The script now waits for the dev console to answer before any
  key press.
- Published texts say "it" for the pawn from 0.2.4 on (the user's wish); these notes keep "she".

### v48g (0.2.5): Rally cadence against stamina, where Latching Effigy latches, config defaults (run of 2026-11-11, 09:45-12:30)

- **Gaps of v48f closed first.** Death and "Load from Autosave" at the cyclops (Arisen at 1 HP, no protection): dead
  at 09:50:11, phase 27 again 31 s later, rules rebuilt 14 s after that, the regroup slot included. Solo fight with
  the final 8 m stop: Rally 28 %, stance 41 %, 15 casts, lowest stamina 42 %, no death.
- **Rally cadence.** `"rally_cooldown"` is a setting now (it was fixed at 25 s). Solo, Arisen standing still, goblin
  waves, about 200 s each (`tools/lua/stamwatch.lua` of the public repository gives the stamina columns):

  | Rally cooldown / stamina floor | Rally executing | her stance | lowest stamina | out of stamina |
  |---|---|---|---|---|
  | 25 s / 50 % (three fights) | 28, 22, 28 % | 41, 32, 40 % | 42, 13, 20 % | never |
  | 12 s / 70 % (one fight, 120 s of battle) | 42 % | 19 % | 23 % | never |
  | 8 s / 80 % (one fight) | 19 % | 40 % | -28 % | 3 episodes, 15 s of 120 |
  | **12 s / 75 %, Delusion floor 50 %, Screen 45 %** (two fights) | 31, 42 % | 36, 25 % | -3 %, 23 % | one 4 s episode, never |

  Stamina is the limit, not the cooldown: a Rally costs 44-55 % of her stamina (4 s), a Delusory Screen 26-39 %, a
  Dragon's Delusion 27-46 % when ended at 5 s and 103 % the one time it ran 8 s (the -3 % above). Hence
  `rally_min_stamina` 0.75, `delusion_min_stamina` 0.5, `screen_min_stamina` 0.45, `effigy_min_stamina` 0.4 as floors
  under which a cast does not start, and `delusion_stop_stamina` 0.15 that ends a running Delusion.
  **Correction of something I told the user during the run:** two "confirmation" fights of the 12 s cadence had in
  fact run on 25 s / 50 %, because config.json still held the values an earlier build of the same morning had
  written. The table above only has fights whose live values were read back from the console.
- **config.json and changed defaults.** The file holds every key, so a default changed by a later version never
  reached an install that had written the old one. v48g writes `config.defaults.json` next to it (the defaults at
  the time of writing); at load, a saved value that still equals its old default follows the new default, anything
  else is the player's and stays. Tested in game with a staged pair of files: four stale defaults moved (logged as
  "config: settings that still had their old default now follow the new one: ..."), a value changed by hand stayed.
  An install coming from 0.2.2-0.2.4 has no defaults file yet: its saved values all stay, as before.
- **Latching Effigy: what decides a latch.** `tools/lua/effwatch.lua` records, for every cast, the executing rule's
  target (distance, height, angle from her facing) and whether `DecoyHandler.get_IsPossesion` turned true within 5 s.
  35 casts against goblins, five runs (old window; "faces an enemy 2-10 m"; the same over 10 minutes; "7-10.5 m"
  band; the final "3-10.5 m"):

  | at the start of the cast | casts | latched |
  |---|---|---|
  | turned 15 degrees or more away from the rule's target | 15 | 0 |
  | facing it (within 6 degrees) | 20 | 8 |
  | ... and the goblin 0.5 m or more higher than her | 7 | 6 |
  | ... and the goblin level with her or lower | 13 | 2 |

  Distance did not decide it: latches at 4.8 to 9.8 m, and a rule restricted to 7-10.5 m latched once in 8. The
  old window ("an enemy at 3-6 m from her", any direction) is replaced by "she faces an enemy 3-10.5 m away within
  `effigy_aim_deg` 12 degrees", and the trick rule gets a target precondition `tcondition.DistanceRange` so that its
  own target, which is what the cast is aimed at, is in that range (a created condition object in the copied rule
  works; `_IsEnable` has to be set). The height finding (the incense seems to fly over a goblin that is not uphill)
  is not built in: nothing taller than a goblin was sampled. **The overall latch rate did not improve:** 5 of 25
  with the new windows against 3 of 10 with the old one in these runs (10 of 47 in the older logs). Fewer casts are
  wasted on a turned back, but the rule's target is often not the enemy she faces (the window looks at any enemy in
  range, the game picks the target), so 10 of those 25 casts still started unaimed. A Latching Effigy costs 46 % of
  her stamina, hence `effigy_min_stamina` 0.6.
- **Her facing is the transform's +Z axis.** The script's old "forward" vector pointed behind her (checked against
  `get_AxisZ`: dot product -1). It was only used for the re-summon position when no enemy is found, fixed, and
  for where `spawn_enemies` puts test goblins ("ahead" was behind the Arisen; left as it is, the arena was chosen
  with it).
- **Regression on the final build:** started from the user's 0.2.2-era config.json (no defaults file: the new settings came in at their defaults, read back live as Rally 12 s / 0.75, Delusion 0.5, Screen 0.45, effigy 3-10.5 m) and the save with the hired Fighter. Fight with the Fighter, 150 s: Rally 39 % of the battle samples, 11 casts, lowest stamina 30 %, 0 Job09 actions on the Fighter in 113 samples. 40 s out of battle: no cast. Title return, 30 s watched, second load, 60 s fight; `disable()` (job 3) and `enable()`, 60 s fight; Latching Effigy with the test skill set, 240 s (4 casts, none latched: one aimed at a goblin 1.3 m lower, three unaimed; she ran out of stamina three times, 8 s in all, with the effigy floor still at 0.4: a cast costs 46 %, the floor is 0.6 now). No error line in the session. After the floor change: a fresh launch and a solo fight, 130 s of battle: Rally 36 %, stance 31 %, 15 casts, lowest stamina 23 %, no death, no error line. Not re-run after the last two edits (a default number and a comment): the fights with the Fighter, title return, disable / enable.

### v48h (0.2.5 as built for release; not uploaded): the effigy rule built from the game's own target conditions (2026-11-11, 11:34-12:30)

- **Where the answer was.** v48g's Lua window ("she faces an enemy in range") could not stop unaimed casts, because
  the game picks the rule's target. The offline list of condition types in the vanilla packs
  (`atlas/decision_packs.md`) has what was needed: `tcondition.AngleTargetDiff(_AngleDeg, _Compare)` (the vanilla
  `dp_Common_Pawn_CommandCome_LookAt` turns the pawn with `HumanTurnOnSpot` when it is 20 or more),
  `tcondition.ScaleType(_Type)`, `tcondition.HeightDifference(_Range)`, `tcondition.Composite(_Attain, _Conditions)`.
  Read in game: `app.CompareType` Eq 0, Neq 1, Ge 2, Le 3, Gt 4, Lt 5; `ScaleType.Type` Small 1, Medium 2, Large 4,
  BigLarge 8.
- **The trick rule's target preconditions are now:** the copied `IsCaught` and `IsDead`, `DistanceRange` 3-10.5 m,
  `AngleTargetDiff` Le `effigy_aim_deg` (12), and `Composite(Any)` of `ScaleType` 14 (not Small) and
  `HeightDifference` from `effigy_small_rise` (0.4 m) up. All created objects, `_IsEnable` set, kept with `PT.keep`.
  `"effigy_face_target": false` and `"effigy_small_rise": 0` take the last two out.
- **Checked against the game's own answer** (`tools/lua/tcheck_table.lua`: `checkTargetPreconditions` for every
  target three times a second, counted by range / angle / height computed by the probe). Goblins, all three
  conditions: in range, within 12 degrees and higher: true 62, false 2; angle 13-25 or over 25: true 4 of 2,104;
  in range and within 12 degrees but lower than her: true 34, false 150 (so goblins are Small, and
  `HeightDifference` measures from another point than the feet: a level goblin passes 18 % of the time). The
  cyclops (BigLarge, every target lower than her by the probe's measure): true 637 of 1,263 within 12 degrees, so
  the size branch lets it through (its many target regions make the probe's own angle a rough guide there).
- **Latches.** With the angle condition, 5 casts of 5 were aimed (0-2 degrees); 15 of the 35 earlier casts were not.
  The one that latched was the goblin 1.4 m higher; the four misses were 0.3 to 2.0 m lower. All samples of the
  day, aimed casts only: **a goblin 0.5 m or more higher than her 7 of 8, the cyclops 1 of 1, a goblin level or
  lower 2 of 17**; unaimed casts 0 of 15. With the height condition on, 4 minutes against goblins gave one cast,
  which latched: against small enemies on flat ground she now rarely casts it, instead of spending 46 % of her
  stamina on a miss. Not sampled: Medium enemies; whether a higher threshold would do better.
- **The height threshold was wrong at first.** `effigy_small_rise` 0.4: in the regression round all four effigy
  casts were aimed and all four went at goblins 0.2-0.9 m LOWER than her (0 latched): `HeightDifference` measures
  to the target's body point, about a metre above its feet. With 1.7 the game's answer for aimed goblins in
  range was: feet lower than hers 0 of 91, 0-0.5 m higher 0 of 28, 0.5-1 m 2 of 3, 1 m or more 11 of 11, and the
  one cast latched (goblin 1.7 m higher). 1.7 is the default; `effigy_min_stamina` went to 0.75 in the same
  edit (0.6 still gave three short out-of-stamina episodes with the test skill set). Totals of the day, aimed
  casts: higher goblin 8 of 9, cyclops 1 of 1, level or lower goblin 2 of 21. **Regression round on v48h** (0.4
  threshold, otherwise the final code): fight with the hired Fighter (0 Job09 actions on it), 40 s calm without
  a cast, title 30 s, second load, disable / enable, fights after each: no error line. The two default numbers
  changed after that round were run live for five and a half minutes through `variant.lua`, no error line.
- **Final sanity on this build:** fresh launch from the user's 0.2.2-era config, solo fight with her own skills (no Latching Effigy equipped, so the trick rule is not built): 133 s of battle, Rally 35 %, Screen 21 % (her HP was under 60 %), stance 9 %, 21 casts, lowest stamina 21 %, no death, no error line. With the test skill set on the same build: the goblin and cyclops samples above, no error line since 11:34. Not re-run on v48h: the fight with the hired Fighter, title return, disable / enable (last run on v48g an hour earlier; v48h only adds target conditions to the trick rule).

### v48i (0.2.6): the dust ball (idle attack), and Latching Effigy's incense thrown by the script (2026-11-11, 12:50-14:45)

Asked by the user: an idle attack ("an alternative to swing, that swings from a distance and throws a magic dust ball",
some damage, no aggro, looking like the censer's smoke), Latching Effigy sampled on human-sized enemies, and the effigy
aimed lower so that it works on level small enemies. All tests of this section ran at 30 FPS with DLSS Ultra
Performance (the user's request for test runs, see NOTES), pawn level 1, Arisen standing still.

- **How the game throws things** (learned from reading Skill Maker's `_NickCore/ShellSpawner.lua`, none of its code is
  used): `app.ShellManager.requestCreateShell(owner GameObject, via.vec3, via.Quaternion, app.ShellRequest.ShellCreateInfo,
  app.ShellParamData, nil, nil)` with `ShellCreateInfo.ShellParamIdHash` = the `_ShellParamIdHash` of an entry of a shell
  data file and `TargetGameObject` = the target. The vocation's file is `AppSystem/Shell/UserData/HumanShellParamData_Job09.user`
  (38 entries, read only). Entry 8 (hash 2585554136) is the game's own "thrown smoke": a homing shell with a pale violet
  smoke trail, additional parameter `ShellAdditionalAddHateSmokeParameter` with hate type 25 (`Job09_ThrowSmokeAttack`).
  Entries 15, 16 and 24 are the Latching Effigy incense (homing, `ShellAdditionalPossessionSmokeParameter`).
- **Damage.** A smoke shell's hit goes through `app.HitController.calcDamageValue(DamageInfo)` with 0 damage
  (`DamageType` -1). `FixedDamage` written before the calculation is ignored. `Damage` written in the post-hook is
  applied by the game: a rogue went 2490 -> 2450, a goblin 610 -> 0 and the party's battle state went to Win. The hit is
  recognised in the hook by `DamageInfo.<AttackOwnerObject>` (the pawn's GameObject) and the `app.Shell` component of
  `<AttackGameObject>` (`<ShellParamId>` = the dust hash). A first version noted the shell's GameObject address at
  `registShell` and never matched (3 balls, 0 hits counted).
- **No aggro.** The hit raised the enemy's hate of the pawn from 192 to 408-416, with or without damage: it is the
  shell's own hate entry, added through `app.HateSystem.addHateParam(GameObject, HateSendSettingData.SendHateParam,
  Nullable)`. Skipping that call when the parameter is `HateManager.getSendHateParam(25)` and the GameObject is the
  pawn: 193 -> 193 and 193 -> 198 over two hits of 40 damage. The written damage adds no hate by itself
  (`HateSystem.onCalcDamageEnd` skipped or not made no difference).
- **The rule** (`dust` slot, last in the list so older slots keep their shells): the censer swing
  (`Job09_ShortSmokeAttack`) through an ActNo command like the casts, target Enemy with a created `DistanceRange`
  4-14 m, rank 2, value 0.5 x weight 10 (the lowest score of her rules). Lessons, one build each:
  1. A pick is only seen when its decision ends (the cooldown timer starts then), so "the swing of the dust slot" is
     read from the decision she is executing when the action starts (`V.running`).
  2. With `AngleTargetDiff` <= 30 on the rule: 5 swings in a 4 minute fight; the game's answer was "no valid target"
     in most samples (idle, she rarely faces an enemy). Without it she swung facing away. So the rule takes any
     target in range and the script turns her (`Transform.set_Rotation`, `dust_turn_rate` 420 degrees a second) during
     the first part of the swing; the ball leaves once she is within `dust_face_deg` (25) of the target, between
     `dust_delay` (0.35 s) and `dust_window` (1.1 s). Balls then left 0-2 degrees off her facing.
  3. With a valid target she still waited behind her own keep-distance stance, which never ends by itself: 21 s of a
     106 s battle. `dust` is now last in `V.preempt`'s list; the gate holds it while an enemy is within `dust_safe`
     (3.5 m) of her. Result, 226 s of battle: 15 swings, `OURS:dust` 17 % of the battle samples, the stance 18 % (it
     was 33 % one build earlier), casts and swings together 58 %, not down once.
  4. **A thrown shell's reach depends on the frame rate.** At 40 FPS the ball hit targets 9.7-13.0 m away; at 30 FPS
     it died after 6.3-7.2 m (lifetime about 2 s; the game moves shells per frame). `V.reach()` = `shell_reach_40` (13)
     x (FPS / 40)^2 x 0.9, at most `dust_far`; the gate needs an enemy within it. A ball aimed 0.7 m above the feet of
     a target standing 1 m higher hit the slope after 3.1 m: the aim point rises with the target (0.3 m a metre).
  Hit rate before change 4: 18 of 29 balls over four fights (10 of 15 in the best one). Damage: `dust_damage`, or
  `dust_damage_base` 20 + `dust_damage_level` 5 x the pawn's level (25 at level 1).
- **Latching Effigy on human-sized enemies** (three rogue fighters, 2500 HP, v48h rules, 40 FPS): the game answers the
  `ScaleType` branch as for goblins, a rogue is Small (aimed targets in range, feet lower than hers: 0 of 64 passed the
  1.7 m height rule; 0.5-1 m higher 17 of 17, 1 m or more 3 of 3). With the height rule off: 3 casts, latched on a rogue
  1.0 m higher at 9.8 m and on a level one at 3.6 m, missed a level one at 3.5 m. Few casts: a latch on a rogue lasts
  until it dies (11 minutes in one case), goblins die within seconds.
- **Why the incense flew over goblins, and the fix.** The effigy incense fired from the pawn with the target given and
  aimed 1.0 m above a goblin's feet flew past it (15 m); aimed 0.5 m above the feet it latched 4 times in 4 on goblins
  level with or below her (5.6-12.4 m, 40 FPS). So the game's aim point is too high for a small enemy. The script
  now throws the incense itself: the `registShell` hook sees the game's incense leave her hand (a shell of hers with
  an effigy hash within 5 s of the cast's start) and `V.effigy_rethrow` throws the same shell at the legs
  (`effigy_aim_height` 0.5) of the enemy she faces. With both incenses flying the latch often ended after 0.5-0.7 s:
  the game's incense lands next to the target a moment later and moves the decoy there (`_IsCreateDecoy`). The game's
  one is therefore taken out with `ShellManager.requestDestroyShell(request id)` (`effigy_replace`); latches then
  lasted 4.1 and 5.3 s. Counts on goblins at 30 FPS with the height rule off: both incenses 7 of 13 (level or lower
  6 of 12); replaced 2 of 4 aimed casts (the two misses: 8.5 m away, beyond the 30 FPS reach, and a second enemy at
  26 degrees). 0.2.5's rule on level or lower goblins: 2 of 21. `effigy_small_rise` is 0 by default again.
- **Cooldowns are real time** (measured after this build, 14:48): the wrappers' `CooldownTimer` loses 2.0 units a frame
  at 30 FPS, 60 a second. Cadences do not depend on the frame rate through the cooldowns; a thrown shell's reach
  does. The lower cadences of the 30 FPS fights of this section have another cause, not looked for.
- **Regression on this build** (hired Fighter save, the player's own config.json): launch to in-game in 63 s; fight with the hired Fighter (200 s, 71 s of it in battle: the Fighter clears the waves): no Job09 action on the Fighter in 140 samples, she was not down, 2 swings, 2 balls, 2 hits of 30 (pawn level 2), 2 hate entries left out, `OURS:dust` 8 % of the battle samples, Rally 32 %, stamina never under 30 %; 60 s out of battle: picks 15 -> 15, casts 15 -> 15, no ball; title for 30 s, second load, fight (55 s of battle, no swing came up); disable, enable (set up again in 15 s), fight (1 swing, a miss; the Fighter was down for 7 s of it). No error line in the whole run. Then the game was closed, the Fighter save, the player's config.json, pawns.json, config.ini, ReShade.ini, the frame-rate mod's json and the add-on file were put back (9 of 9 save files identical to the backup).

### v48j (still 0.2.6): the ball smaller, and a hit fools the enemy (2026-11-11, 15:40-16:25)

Asked by the user after seeing the first GIF: "it could be smaller, especially the impact dust flying around", and a
lore-friendly effect on the enemy. Blindness does not exist in the game (no type name with "Blind" among 200,000;
the status actions with code of their own are Sleep, Stone, Wet and the damage-over-time ones). Chosen with the
user: an enemy hit by the ball is fooled, it lets go of the party's pawns and goes for the decoy ("this way it
could detract enemies away from that pawn or other pawn also, not just away from Arisen").

- **How decoy aggro works here** (9 November's probes and today's): every enemy has a ranking of
  `app.HateCalculator`s, one per target; a calculator's total is temporary + kept + distance hate. For the Arisen
  the game retargets the Arisen's own calculator to the decoy while one is out (`_TargetSmokeDecoy`), with all the
  hate the Arisen had. The main pawn's calculator is its own: about 190 on an idle goblin (kept 100, the "pawn
  bias" the game adds back all the time, plus 70-90 of distance hate) against about 180 for the decoy entry. So
  the decoy and the pawn are neck and neck, and in a fight without the ball the decoy was on top in 48 % of the
  samples, the main pawn in 14 %, nobody in 34 %.
- **Fooled.** For `dust_fool_seconds` (6) after a hit, the three parts of the hate that enemy holds against each
  party pawn (every `HateCalculator` of its `_HateCalculators` whose target is a party pawn) are written to 0, once
  a frame and again right before the enemy sorts its ranking (pre-hook on `HateSystem.updateHateRanking`). Three
  versions, each measured with `tools/lua/foolwatch.lua` (top of the ranking of fooled enemies, four samples a
  second): `HateSystem.setCustomRate(GameObject, 0.1)` written every frame (the game puts the rate back to 1 on the
  next frame): decoy on top in 65 % of 68 samples; the temporary and kept parts written to 0 once a frame: 61 % of
  46 (one goblin 100 %, the next mostly on the pawn); the final version: 113 of 113 samples over five goblins.
  Only while a decoy is out (without one the enemy would turn to the Arisen); not on enemies with more HP than
  `big_enemy_hp` unless `dust_fool_big`. The hit enemy is the `app.Character` on `DamageInfo.<DamageGameObject>`
  (counter "found by hit").
- **The ball's target has to be on her level** (`dust_height` 3 m, in the target choice and in the gate's "an enemy in
  reach"): one ball of the regression fight went at a goblin 4.7 m away and 7.9 m below her, down the cliff of the
  test spot, and hit the ground after half a metre.
- **Smaller.** The shell's `<ExpandRate>` (1.0) written to 0.4 changes nothing; its transform's local scale at 0.35
  thins the trail a little and leaves the impact cloud as it is. The effect objects are scaled where the game creates
  them: `app.Shell.requestHitEffect` / `requestTerrainHitEffect` / `requestEffect` / `requestOmenEffect` are hooked
  (a stack, the outer request's kind wins: the impact asks `requestEffect` for its parts), and while one runs for a
  dust ball the GameObjects returned by `via.effect.script.EffectManager.createEffectInternal` get their local scale
  multiplied: `dust_hit_scale` 0.4, `dust_trail_scale` 0.7. One ball: 4 requests, 3 objects (1 trail, 2 impact).
  `Shell.requestHitEffect`'s return value and `EffectManager2__StandardCreatedEvent` gave nothing to work with.
- **Regression on this build** (hired Fighter save, the player's own config.json): on the build before the last two edits (the height limit and the stronger wipe): launch to the mod being ready in 84 s; fight with the hired Fighter (240 s, 104 s of it in battle): no Job09 action on the Fighter in 204 samples, she was not down, 1 swing, whose ball went at a goblin 4.7 m away and 7.9 m below her and hit the ground (hence `dust_height`); without a ball the goblins' rankings had the decoy on top in 22 % of 945 samples, the main pawn in 22 %, the Fighter in 36 %; 60 s out of battle: picks 23 -> 23, casts 17 -> 17; title for 30 s, second load, fight (2 swings, 1 hit); disable, enable (ready in 14 s), fight (3 swings, 2 balls). No error line. On the final build, solo: six swings, six balls, five hits, five enemies fooled, the decoy on top of their rankings in 113 of 113 samples (other goblins of the same fights: decoy 31 %, main pawn 33 %, nobody 36 % of 3,810 samples; 326 wipes at ranking sorts); then 40 s out of battle (picks 35 -> 35, casts 39 -> 39), title for 30 s, second load, fight (3 swings, 3 hits, 3 enemies fooled), disable, enable, fight (2 swings, 2 hits, 2 fooled): no error line, she was not down. Then the game was closed and the Fighter save, the player's config.json, pawns.json, config.ini, ReShade.ini, the frame-rate mod's json and the add-on file were put back (9 of 9 save files identical to the backup).

### v48k (still 0.2.6): the smoke of the dust swing made minimal (2026-11-11, 16:45-17:55)

The user, after v48j: "the smoke basic attack and the smoke effect that remains on the enemy is still WAY too big, it
really has to be minimal", and, seeing me judge clips of whole fights: "you really need to disable all the pawn skills
for that test".

- **What the smoke was.** With every other slot held (`cfg.only_slot = "dust"`, new, a test setting read by
  `gate_slot`; `tools/lua/only_slot.lua`) a side view showed a three metre swirl at the pawn and puffs for three
  seconds after it, with the ball's own effects already cut. `registShell` during the swing: besides the dust ball
  (2585554136) the censer swing registers **a shell of its own, parameter id 1754224672**, one a swing: the game's
  smoke cloud of the basic attack (thick smoke for three seconds, a burst with sparks where it lands). v48j and the
  first two steps of v48k had shrunk the ball's effects and never touched it.
- **Scaling an effect does not shrink smoke.** The transform scale of an effect object (v48j: 0.4 / 0.7, then 0.12 /
  0.25) moves its emitters closer together; every particle keeps its size, and a smoke particle grows with its age.
  The impact cloud at scale 0.12 was still three metres wide a second after the hit. Colour alpha and play speed
  set inside the `createEffectInternal` hook did little: the effect player has no resource yet at that point
  (`get_Resource` is empty there).
- **The fix.**
  1. During a dust swing (2.2 s from its start) a shell of the pawn that is neither the dust ball nor an effigy
     incense is noted in the `registShell` hook and destroyed by `V.tick` on the next frame
     (`ShellManager.requestDestroyShell`; `dust_swing_shell = true` keeps it). Counter "swing smoke shells taken
     out": one per swing.
  2. The effect objects of the ball's impact, and the effects named after the pawn that are created under the pawn or
     its weapon during the swing, are kept (`add_ref`) in `V.fx_cut` by the effect hook. `V.fx_tick`, from the next
     frame: play speed and opacity of the settings on their effect players (the object and its children, three
     levels), the alpha going to 0 over `dust_hit_life` / `dust_swing_life` (0.3 s), then
     `EffectPlayer.set_Action(2)` (`via.effect.PlayerAction.Kill`). An entry not served within its life + 0.5 s is
     dropped untouched. The ball's trail keeps its scale (0.25) and gets the opacity once.
  3. Removed: the "effects named after the enemy" of step 1 (they were its footstep dust, `Common/Move/13_Cm_Move`,
     and hit sparks), `dust_enemy_scale`, `V.fx_faint`. `dust_fx_speed` back to 1.0 (a faster effect grows faster).
- **What is left**: a wisp at the censer on the swing, a faint line where the ball flies, a puff at the impact that is
  gone in a third of a second. The thin smoke that follows the censer at all times is the weapon's own effect (a new
  `effect_<pawn>` under the pawn every few seconds, with or without a swing) and was left alone.
- **Measured** (solo save, level 1 pawn, 30 FPS, low-GPU settings): clips `k3a`, `k3b` with only the dust slot
  released (tools/work/captures). Then with every slot back: a minute out of battle, no cast; a goblin fight, 57 s in
  battle: a cast executing in 38 of the 64 samples with one released, Rally 5 times, dust 15 % of the samples,
  lowest stamina 42 %, the pawn not down, no error line; session totals 4 swings, 4 balls, 3 hits, 2 enemies
  fooled, 16 effects cut short, 4 swing shells taken out. After `lua/disable.lua` and `lua/enable.lua`: a second fight, 60 s in battle: Rally 4 times, one dust swing (its ball missed; its swing shell taken out, 3 effects cut short), lowest stamina 42 %, the pawn not down, no error line.
- **Not tested on this build**: the return to the title and a second load (it needs Space presses, and the user's
  rule since today is one focus session per launch); a hired pawn in the party; rogues; a frame rate other than 30.
- **A still target, and what the throw looks like** (18:00-18:10). The user could not judge the clip: "the character
  doesnt move and it doesnt seem to throw it further? dont the game have Dummyes that dont move". No dummy was
  looked for in the game; a spawned goblin whose GameObject stops updating (`set_UpdateSelf(false)`,
  `tools/lua/dummy.lua`) is a statue, and `PT.dust_test()` (new) plays the dust swing on demand whatever the gates
  say. A GameObject that does not update is not hit (the ball flew through it): the statue is let go for a second
  around the impact (`tools/work/dust_demo.lua`). Side view, pawn 4.5-5.5 m from the statue, frame by frame
  (`tools/gifsheet.ps1`):
  - with 0.12 / 0.25 and 60 % opacity nothing of the throw could be seen at all;
  - with the trail at the game's size and full opacity: a puff at the censer, a pink streak that crosses 5 m in two
    frames (0.2 s), a burst of sparks half a metre wide on the goblin for 0.3 s, everything gone 0.6 s after the
    throw; 25 damage (650 -> 625). These are the defaults now: `dust_trail_scale` 1.0, `dust_hit_scale` 0.4,
    `dust_fx_alpha` 1.0, `dust_hit_life` 0.5.
  - **the pawn's own movement is a flick of the wrist**: `Job09_ShortSmokeAttack` moves the censer hand a few
    centimetres and nothing else. That is the game's animation for the short censer swing; a throw that reads as a
    throw needs another action (not looked for yet).
  - at 30 FPS the ball dies after about 7 m (it went on past the statue to the edge of the picture when the statue was
    not hit); at 40 FPS about 13 m.
- **Test tools**: `tools/lua/only_slot.lua`, `tools/lua/efxtime.lua` (every effect created in the 5 s after an
  action starts: time, object, parent, distance), `tools/work/efxcut.lua` and `shcut.lua` (the two fixes as live
  probes, tried before the script was changed), `tools/work/dustlab.sh` (dust slot alone, Arisen cannot die, waves).

### v48l (still 0.2.6): the dust attack is a real swing, the ball leaves at its end (2026-11-11, 18:12-18:35)

The user, on the clip of v48k on a frozen goblin: "the ball looks good now. for the attack: she should swing the
cenders, and the ball flies when the animation is done, i guess like other skills anim?"

- The game has the move: `Job09_ThrowSmoke` (the Arisen's Drifting Brume; `Job09_PrepareThrowSmoke` is its charge).
  Played on the pawn with `PT.request` and watched with `tools/lua/actwatch.lua` (actions and shells of the pawn for
  6 s after a request): the action runs 3.3 s, and at +0.73 s the game registers **its own thrown-smoke shell,
  2585554136**, the very shell the dust ball is. On film: a wind-up with the censer arm going back and round for
  0.6 s, the smoke leaving the hand, a recovery of two seconds.
- `dust_action = "Job09_ThrowSmoke"` (new setting; `ACT.dust`): the dust slot's rule plays that action. The script
  turns the pawn to its target from the start of the swing, as before, and waits: when the `registShell` hook sees
  the game's own thrown smoke of this swing, that shell is taken out (it flies straight ahead with no target) and
  the script's ball goes on the same tick (`dust_release`; no ball when the game's throw has not come after
  `dust_release_wait` = 1.6 s, i.e. the swing was cut). The same pattern as the effigy incense. With
  `"Job09_ShortSmokeAttack"` the old timing (`dust_delay`, `dust_window`) is used.
- From the first frame of the swing the pawn's thrown-smoke shells count as dust balls (`V.dust_live` and
  `V.dust_owner` are set in `V.on_action`, not only in `V.dust_fire`), so the game's own shell of that one frame gets
  the effect handling and adds no hate.
- **Measured.** On the frozen goblin, side view (`tools/work/captures/throw2.gif`, `throw2_all.jpg`): wind-up frames
  12-18, release 19, the streak 20, the burst on the goblin 21-23, smoke gone by 26; 1 swing, 1 release, 1 ball,
  1 hit, 25 damage, the game's shell taken out. Goblin fight with every slot, 110 s (solo save, level 1 pawn, 30 FPS): 4 dust swings picked by the rule, 4 releases, 4 balls, 4 hits (25 each), 3 enemies fooled, the game's shell taken out each time; a cast executing in 124 of the 159 samples with one released, longest wait 1.6 s; Rally 7 times, Delusion 3; the pawn not down, no error line. One out-of-stamina episode of 2 s after the seventh Rally (lowest -4 %); the throw itself costs no stamina (700 of 700 before and after, measured twice with `tools/work/stam_dust.lua`).
- Not tested on this build: the title and a second load, a hired pawn, rogues, a frame rate other than 30.

### v48m (NOT a version: work stopped by the user at 18:52, kept as `runs/v48m_wip.patch`) (2026-11-11, 18:25-18:52)

The user, on v48l: "wait but now she just throws it with her hand, she is not at all swinging the cenders and it
throws from it / at the end of the swinging animation". Then, watching the game during my tests: "her character is
just stuck, at least the 3d model, but she moves invisible". Then: "ok we have to stop here".

- **What the censer swings are** (`tools/lua/actwatch.lua`, pawn standing, played with `PT.request`):
  `Job09_MoveSmokeAttack` 5.3 s, the censer swung round over the head on its chain, the swing's own shell
  (1754224672) registered at +0.73 s; `Job09_DashSmokeAttack` 3.5 s, a low sweep, shell at +0.56 s;
  `Job09_ShortSmokeAttack` 3.1 s, shell at +0.66 s. All three register that shell 0.50 m ahead of the pawn and
  1.25 m above its feet. `Job09_ThrowSmoke` (v48l) is a throw by hand. A second request (`NormalLocomotion` at
  +1.5 s) does replace the action.
- **The patch**: `dust_action = "Job09_MoveSmokeAttack"`; the ball goes when the swing's own shell is registered;
  the swing's shell is no longer destroyed, its effects are ended instead (kind "cloud"); `PT.dust_action(name)`.
- **Solved on 2026-11-12 (see "v48n (0.2.8)" below): none of the three causes named here.** The script turned the
  pawn to its target with `Transform.set_Rotation` from `re.on_frame`, i.e. while the scene is locked for rendering,
  and one such write is enough to leave the model where it stood. It was in the build since v48i.
- **The unsolved problem (as written on 2026-11-11): the pawn's model.** In most clips of this work the pawn's model either stood still in one
  pose where it had been, or was not drawn, while the ball left from where the pawn really was. Three causes were
  named and none is established:
  1. the request for `NormalLocomotion` that ended the swing early (first build of the patch): removed, the clips
     did not change;
  2. `requestDestroyShell` on the swing's own shell (v48k): removed, the clips did not change;
  3. the capture camera: it overwrites the camera transform at `LockScene`, after the game has decided what its own
     camera sees; a character outside the game's own view may not be animated or placed. This fits every clip (the
     pawn was drawn and moving whenever the Arisen's camera happened to look at it) and was not tested: the one take
     through the game's own camera (`--nocam`, `tools/work/inview.lua`) did not have the pawn in the picture.
  The author saw the stuck model in the game window themselves, during a run of the first build of the patch (cause 1
  was in that build, and the capture camera was armed). **So: no clip of today proves how a dust swing looks to a
  player, and "the short swing is a flick of the wrist" (v48k) may be the same artefact.** Before anything else:
  film through the game's own camera, the Arisen turned to the pawn.
- **State of the versions.** On Nexus: 0.2.2 only (the author's upload, "Version 1"). 0.2.3, 0.2.4 and 0.2.5 were
  built into `mods-src/release/` and never uploaded (I wrote "0.2.5 is the released one" here and told the author so;
  the author corrected it). 0.2.5 (`PawnTrickster_0.2.5/PawnTrickster.zip` = the script of commit 6c2f7f8) is the last
  build that is finished and tested and has none of today's dust work. v48j (8346a88) is the last 0.2.6 build that went through
  the full regression with a hired pawn. v48k and v48l (HEAD, installed) passed fights by the numbers; nobody
  watched them in the game. v48k destroys a shell that belongs to a running action, v48l does not (hand throw).

### 0.2.6 packed for Nexus, and a tool that pushes it (2026-11-11, 19:00-19:10)

Asked by the author once it was clear that 0.2.6 has the throw by hand: pack 0.2.6, update the page text, upload.

- **Release folder** `mods-src/release/PawnTrickster_0.2.6/` (built by `mods-src/PawnHybridAI/tools/
  release_trickster_026.py`): `PawnTrickster.zip` (script and readme of HEAD), `description.bbcode.txt` and
  `CHANGELOG.txt` reworded for the throw by hand, and `PawnTrickster_CHANGELOG.txt`: the Nexus changelog in the
  Ink & Iron format (a title line, then one short "- Added: / Fixed: / Changed:" line per change), covering
  everything since 0.2.2, the version on the page. The shipped readme no longer offers the censer swings as
  `dust_action`.
- **`mods-src/PawnHybridAI/tools/nexus_upload_dd2.py trickster`**: new version of the file that is already on the
  page (`POST /v3/mod-files/{id}/versions`, `archive_existing_file`), then the changelog entry. It imports the
  Witcher project's `nexus_upload_inkiron.py` and runs with that project's venv Python. `--dry-run` (no network),
  `--check` (read only), nothing is sent without `--go`. The key is read from `NEXUS_API_KEY` (machine environment)
  and never shown. `--nexus-version` gives the label on Nexus when it is not the release's number.
- **The page** (read with `--check`): dragonsdogma2/mods/2545 "Trickster Pawn (Experimental)", version "1", one
  active file, id 8357808, "PawnTrickster", one version, uploaded 2026-11-10 20:09. Not uploaded by me: the version
  label is the author's decision (the page says "1", the release is 0.2.6), and so is the go. The page description is
  not reachable through this API: `description.bbcode.txt` is pasted by hand.
- **Version numbers on Nexus are not ours** (asked by the author). The page counts 1, 2, 3; 0.x.y are local build numbers. Build 0.2.2 is
  version 1; this build goes up as version 2. The upload tool takes the page's version + 1 (or `nexus_versions` in
  the script, or `--nexus-version`) and refuses a label that looks like 0.x.y; the description speaks of "version 2";
  the shipped readme says which Nexus version it is; `CHANGELOG.txt` (local, one line per build) is not posted.
- **Uploaded on the author's go, 2026-11-11 19:05:** `nexus_upload_dd2.py trickster --go`: build 0.2.6
  added as version 2 of file 8357808 ("PawnTrickster"), the old version archived by Nexus, changelog entry "2" posted
  (10 lines). Checked right after through the same API: page version 2, the file has 2 versions, 1 archived. Nexus'
  public search still answered "version 1" a minute later (its index lags). The page description was not changed:
  `description.bbcode.txt` is for the author to paste. This build is the throw by hand, not watched in the game.

### v48n (0.2.8): the stuck model found and fixed, skills without a reload (2026-11-12, 08:55-10:30)

The author gave a four-hour slot. First the 0.2.7 panel was looked at on screen (the checkbox is there; with logs off
the log keeps "not found" lines and guarded errors with their stack). Then the open problem of v48m.

- **What it was.** `V.dust_step` turned the pawn to its target during a smoke throw with
  `Transform.set_Rotation`, from the frame callback. `re.on_frame` runs between the engine stages `LockScene` and
  `EndRendering`; a transform written inside that window keeps the copy the renderer reads, and that copy is not
  refreshed any more. The pawn's model then stays drawn where the write happened, still animated, and the pawn
  itself (position, collisions, shells, AI) goes on without a visible body; the next such write moves the model to
  the pawn's place of that moment. One write is enough. It was in every build since v48i (0.2.6, on Nexus as
  version 2), whenever the pawn had to turn more than 2 degrees for a throw.
- **How it was found.** The author, watching the test scene, said the test itself seemed to freeze the characters' models. A record of the pawn's hands during a throw put them 10.8 m from the pawn's
  root. From there: (1) the same read is right from the console and wrong inside `re.on_frame`; (2) one sample per
  engine stage: `Transform.get_WorldMatrix` equals `get_Position` up to pre-`LockScene`, is stale from
  pre-`WaitRendering` to `EndRendering`, and right again after; (3) a camera pointed at the stale place shows the
  model, a camera behind the real place shows nobody; (4) on a clean pawn, every step of my tests replayed one at a
  time with that read after each (warps of every kind, the capture camera in its three modes, the frozen dummy,
  recorders, a bad action name): all clean; a quick "place, then throw" loop: stale at the first cycle; (5) a fresh
  launch, one rotation write from `re.on_frame`, a move: 11.69 m apart.
- **The fix.** `V.dust_step` stores the yaw it wants (`st.dust_yaw`); `V.turn_apply`, called from
  `re.on_pre_application_entry("LateUpdateBehavior")`, writes it. Measured on the fixed build: the pawn turned
  110 degrees away from a frozen goblin and asked to throw: ball thrown 1 degree off its facing, then the pawn
  moved: 0.02-0.05 m between root and hip inside the lock, 4 of 4; 12 reads during a 120 s goblin fight and 7 during
  a 150 s one: 0.01-0.17 m.
- **Wrong turns of this run**, for the record: the game's own hiding of characters outside its camera
  (`InCameraChecker`, `CharacterMeshVisibleToggler`, motion every fourth frame) looked like the cause for twenty
  minutes; so did the pawn's occlusion volume, whose box sat at the stale place (it follows the same render copy);
  so did my short warp. A goblin as a clean test subject proved nothing: the write that breaks the pawn was never
  made on it.
- **Skills without a reload** (`V.skills_changed`, `skill_watch`): the rules are built for the Job09 skills equipped
  at that moment (`st.built_sig`). When the equipped set differs from it for 4 s, out of battle, with no menu and no
  talk open, the pawn is set up again the way a party change does it. From the console (the calls of the mod's debug
  path): Latching Effigy in place of Delusory Screen gave the effigy rule and dropped the screen rule 26 s later;
  with the pause menu open nothing happened for 16 s, and the setup ran 5 s after it closed. The guild's own menu was
  not driven.
- **Tried and left out:** a lead for the smoke ball (9 of 10 hits with it, 7 of 7 without, lead 0.1 m on average),
  and a frame-rate independent reach (the shell's speed numbers are per frame in shared data: InitialSpeed 0.54,
  Acceleration -0.008, RangeDist 20).
- **Regression on the final build** (solo test save, 30 FPS): 150 s of goblin waves: 22 casts, longest wait of a
  released cast 1.6 s, pawn down 0, error lines 0; a minute out of battle: no cast; disable and enable; a soak of
  10 minutes (numbers in NOTES.md). Not run: title and second load, death and reload, a hired pawn, a big enemy.

- **Second part, the same day** (asked by the author): rogues,
  harpies, a cyclops, a hobgoblin group, the rank 4-7 skills, a hired Fighter (who died in a fight: the party-change
  setup ran in the middle of the battle), five rapid skill changes, four disable / enable cycles, a 120 m warp in
  the middle of a throw five times, the title in the middle of a fight, two soaks of four fights. No error line in
  any of it and the model on the pawn in every check. One real finding: **the pawn ran out of stamina when a cast
  with a stamina floor followed a costly cast within a few seconds** (an effigy 4 s after a Rally; a Screen 3 s
  after a Rally: 7.5 s out of stamina against harpies). The floor is read when the rule is released, and the cast
  before it takes its stamina over its three to five seconds. `V.cast_busy` / `cast_spacing` (6 s): Dragon's
  Delusion, Delusory Screen and Latching Effigy stay held for that long after a Rally, a Screen or an effigy began.
  The soak after it: 0 out-of-stamina samples in about 10.7 minutes of battle, the share of battle time spent
  casting about the same (65-72 %). Numbers: NOTES.md.

- **Third part: title and second load, death and "Load from Autosave"** (on the author's word, one short focus
  session each): both clean on 0.2.8, each followed by a fight with no error line. Before that, **one crash**, 19 s
  after a second load, inside the game's hand IK (`UpperBodyTransformer.HandParentInfoHolder.initDataToApplyHandIK`,
  DD2.exe+0x326bc2), in the second the rules were added and the pawn began its first summon. The save loaded there
  was an autosave made by the test with the Arisen at 0 HP (the no-die flag), so the Arisen was dying in that second.
  Not reproduced on a healthy save nor in a staged attempt; whether the mod has a part in it is open. Evidence:
  `mods-src/crash-kit/crashes/2026-11-12_120657`.

- **Fourth part: everything that was still untested** (asked by the author). Passed: a skill change during a setup (three timings); the real click
  on "Enable debug logs" (off, then on); **the guild's own menu** (unequip and equip with real keys on the pawn's
  tab: the mod waits while the guild is open and sets the pawn up a second after the talk ends); the Arisen as a
  Trickster casting next to the pawn; 40 FPS (a four-fight soak, no error line, no out-of-stamina sample); a
  Trickster pawn with the mod passive (the game runs, the pawn only walks). Found and changed at 40 FPS: **the
  smoke ball missed flying harpies** (3 hits in 8; the reach is 11.7 m there instead of 6.6 m at 30 FPS): it is no
  longer thrown at an enemy in the air; and **Rally chained four times in a row** when the battle state kept
  changing (cooldowns start at 0 after every change), down to -27 % stamina: `cast_spacing` holds Rally as well.
  **Two crashes stay open**, each seen once and not reproduced: 19 s after a second load (hand IK; the Arisen was
  dying, most likely from a fall at the load point), and 3 s after the guild's skill screen switched to the pawn's
  tab in a session that had already been through six console setups and ImGui clicks (the same later: fine, three
  times). Online stays untested: it cannot be seen from one machine.

## Run 6 protocol (v3)

1. Back up the save folder; copy `PawnTrickster.lua` to `reframework/autorun/` (config.json: censer 2104, `command_path` mux).
2. `load_space.ps1 -Launch -Seconds 35`, wait for `IsInGamePhase`.
3. Dev console: `PawnTrickster.enable()`; after ~3 s `PawnTrickster.status()` must read `job=9`, `job09sel=true`,
   `decoyHandler=true`; the log must show `weapon: equip censer into Main slot true`, `decoy: shared the Arisen's
   PrefabController true`, `ai: trickster pack with 7 decisions added true` and a `track: wrapper ... decision field ...` line.
4. `PawnTrickster.bring_enemies(4, 9, 200)` warps the nearest live enemies around the Arisen; `PawnTrickster.fightlog(true)`
   logs battle state, current action, decoy presence, selected decision, last hook answer and HP once a second.
5. Watch for `select: summon Job09_SummonDecoy` followed by `action=Job09_SummonDecoy` and `decoy=true` with no
   `request()` call, then `select: shroud|rally|delusion` with the matching `Job09_Cast*` action.
6. `PawnTrickster.restore_weapon()`, `PawnTrickster.disable()`, idle `cmd.lua`, `Stop-Process DD2`, remove the autorun
   copy, restore the save backup (battle end autosaves).

## Test protocol (first manual probes; done in runs 1–3)
1. Back up `Steam/userdata/<id>/2054970/remote` (the first study's backup script does this).
2. Copy `PawnTrickster.lua` to `reframework/autorun/`, reset scripts (or launch).
3. In the REFramework UI (or dev console `PawnTrickster.enable()`): enable, then `status()`; expect
   `job=9`, `job09sel=true`, `decoyHandler=true`, `selector=app.Job09ActionSelector` once the censer is in hand.
4. Buttons: "summon decoy" → a simulacrum appears next to the pawn; "beckon"; "Aromatic Rally" → party buff
   effect. Capture with PrintWindow.
5. Pick a fight: watch the log for `gate: decoy out` flips and the pawn choosing the ActNo packs.
6. `disable()`, quit without saving, restore the backup if anything was saved.

## Files
- `AI_ATLAS.md` – the pawn combat-AI atlas (pipeline, goals, decision anatomy, command/condition catalogs, where the
  per-job logic is hard-coded) and the Trickster design derived from it. `atlas/decision_packs.md` (618 packs dumped
  live, one section each), `atlas/goals.md` (261 goal params decoded offline with exact pack lists per job),
  `atlas/catalog.md` (308 condition / 45 evaluation / 225 command / 51 process classes with examples),
  `atlas/live_dumps.zip` (the raw 880 dumps), `atlas/*.json` (machine-readable).
- `PawnTrickster.lua` – the prototype; run three times in game (see "In-game runs"), last fixes (shared-instance cloning,
  equip slot write) are syntax-checked but not yet run.
- `runs/run*_log.txt` – the prototype logs of the three runs.
- `NOTES.md` – running notes with the raw facts and tool usage.
- `live/job09parameter_dump.txt` – full Job09Parameter dump; `live/enums.txt` – enum values (skill ids, action
  hashes, AI flags); `live/thinktable_ch300962.txt` – NPC Trickster think table; `live/attacktable_nrd_job09.txt`;
  `live/job03_fireboon.txt`, `live/job05_normalattack_01.txt`, `live/job01_shieldsummons_emtarget.txt` – template
  decision packs; `live/goaldata_3317500834.txt` – a `JobDecisions` goal; `live/*.json` – the pawn's live
  decision module / goal planning fields.
- `data/exact_case_paths.txt` – exact-case asset paths (needed by `sdk.create_userdata`).
- `../tools/dumplib.lua` – live object dumper used through the dev console; `../tools/rszdump.py`,
  `apischema.py`, `extra_types.json` – offline RSZ decoder (reads most decision/actinter files; curves decoded).

**The two one-off crashes of 2026-11-12, looked into (16:00-16:40, no change to the mod).** Crash 1 (after a second
load): `app.UpperBodyTransformer.HandParentInfoHolder.initDataToApplyHandIK`, on a motion job thread: a human
character's upper-body transformer held an UpperArm joint whose skeleton was gone, the game reported it and read
through a null anyway. Every human has that object, NPCs included; a load, the mod's weapon swap and the decoy were
measured and do not touch a skeleton. Crash 2 (guild, pawn tab): `app.TriggerManager.onLateUpdate`, the array it
rebuilds every frame was allocated over its own temporary object (overlapping memory from the thread's local heap):
damage done earlier, by what is unknown. REFramework's dump holds no heap, so neither can be taken further. For the
next one, `DD2CrashTrace.dll` now writes a report with the exact method of each frame, the typed objects with field
and GameObject names, and a dump with the memory around them (`reframework/data/DD2CrashTrace/crash_*.txt`). Details:
NOTES.md, "fifth part".

**A hunt for the state behind crash 1 (2026-11-12, 16:57-17:33, no change to the mod).** A read-only recorder checked
every character near the party five times a frame for a hand-IK or Hip joint without a skeleton, through far warps,
the pawn left behind, rogue and goblin fights, the Arisen's death: 0 sightings in about 61,000 frames while 482
characters were destroyed (369 NPCs, the pawn 14 times). The game clears a character's transformer in the same step
that destroys it, so the crash needs the motion job to run inside that step: a narrow race of the game's own, for
any human being removed. Nothing the mod does widens it. Details: NOTES.md, "sixth part"; tools in
`mods-src/crash-kit/hunt/`.
