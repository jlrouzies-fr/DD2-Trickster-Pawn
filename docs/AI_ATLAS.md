> The dumps this atlas was built from (`atlas/...`, `data/...`) are extracts of game data and are not in this
> repository.

# Dragon's Dogma 2 pawn combat AI: an atlas, and how a Trickster pawn fits in

Built on 2026-11-08 from 618 decision packs dumped live from the running game (`atlas/live_dumps.zip`,
`atlas/decision_packs.md`), all 261 goal-data files decoded offline (`atlas/goals.md`), the skill→pack table
(`../data/customskill_decision_map.txt`), the live type database, and the three Trickster test runs described in
`README.md`. Counts below are over the 613 untouched packs (five were mutated in memory by the prototype during the
runs and are excluded from the statistics).

## 1. The pipeline, bottom-up

```
Utility module (app.DecisionEvaluationModule, every pawn)              <- AIDecisionMaker.CurrentModuleType = Utility
  Pre / Main / Post decision lists (app.AIDecision, built from DecisionPack.Decision)
  scored every think tick: Priority(Layer, Rank) first, then EvaluationCriteria x weight, cooldowns, control tags
Goal planning (app.goalplanning.AIGoalPlanning)                        <- owns _AIGoalData = PawnAIGoalData.user
  27 goal types x 263 goal params (AIGoalData_*.user); each param has
    _SituationConditionList: AISituationEvaluationData (category Discovery/Battle/RDL_DNG/ALL..., priority, target)
    _ExclusionConditionList, _CoolTime, _Priority (PriorityRank), a _DecisionCategory:
      AIGoalCategoryCommon  -> one pack list for every job
      AIGoalCategoryJob     -> JobDecisions[]: { _Job: JobEnum[], _DecisionPacks[] }   (111 params use it)
  + CustomSkillDecisions (CustomSkillDecisionRefData.user): HumanCustomSkillID -> DecisionPack[] (82 skills)
    the pawn's goal planning only picks the sets whose skill the pawn has equipped
DecisionPack (.user, 794 files) -> Decision[] -> ActInterPackData -> ActInterPack -> ActInterNode[] -> app.actinter.cmd.*
  commands run on the pawn through HumanActionSelector (requestAction / requestCustomSkill / requestNormalAttack ...)
```

Live check: an Archer main pawn out of combat held 2 pre, 14 main and 7 post decisions (Warp, ClingCliff,
DrawWeapon, Approach, Interact, TurnLantern, LivPawnAction...). After the prototype added a pack with
`AIDecisionMaker.addDecisionPack`, that pack's decisions appeared in the main list on the next think.

## 2. Goals (261 goal params)

- Categories: `AIGoalCategoryJob` 111, `AIGoalCategoryCommon` ~150. Every `JobDecisions` entry in the game lists
  only Job01..Job06, except a carry/wrestle goal that lists `{2,3,4,6,7,8,9}` (the non-heavy jobs). There is no
  Job07/08/09 combat row anywhere.
- Typical attack goal (AIGoalData_3317500834, priority 2, situations ALL): Job01 → `Job01_NormalAttack_01/_02`,
  `Common_HeavyAttackFinish`, `Job01_GuardCloseDistance_01`, `Job01_TuskToss`; Job02 → move/static normal attacks,
  `Job02_FullBend`, `Job02_MoveAttackRange`; Job03 → normal attacks, `Job03_ChargeAttack_01`, `Job03_KeepDistance_01`;
  Job04 → combo attacks, `Job04_LoopAttack`, `Job04_Snatch`; Job05 → `Job05_NormalComboAttack_01`,
  `Job05_NormalAttack_01`; Job06 reuses the Job03 packs plus `Job06_ChargeAttack`; `{1,4,5}` → `Common_AttackOnFrigor`.
- Families of per-skill packs, visible in the names: `_Spot` (cast from a fixed spot), `_gimmick` (hit a gimmick),
  `_Break` (break a climbed/pinned target), `_TiredReaction` (enemy exhausted), `_Multiple` (several enemies),
  `_Help` (ally in trouble), `_Stock*` (Spell Stock), `_EMTarget` / `_MemberTarget` (taunts aimed at enemies vs
  party), `_BattleEnd` / `_Release` (toggle skills off), `_CNT0014` (DLC content variants).
- The Situation categories (`app.GoalAISituationCategory`): None 0, ALL, Discovery 1, Battle 2, Simple_Battle 4,
  Contents0014 8, RDL_DNG 16, Ch258/Ch259/Ch270 (specific bosses), DiscoveryNRD, BattleNRD.

## 3. Anatomy of a decision (what every pack repeats)

| Piece | Convention seen in the packs |
|---|---|
| `_Priority` | Layer Common(0) / Quest(1) / Reaction(2); Rank Lowest..Highest; attack packs use Common/Medium (0,2) |
| `_Policy` flags | None 0, Attack 1, Magic 2, Healing 4, Help 8, Skill 16; e.g. Thunder Rain = 19 (Attack+Magic+Skill), Fire Boon = 26 (Magic+Help+Skill), normal attack = 1 |
| `_Target` flags | My 1, Player 2, Enemy 4, Gimmick 16, Party 64, Position 2048...; attacks = 4 (652 of 1,100 decisions), buffs = 67 (My+Player+Party) |
| `_Cooldown` / `_CooldownOnSuccess` | 1–12 s / 5–20 s; `CooldownID` names shared timers (Enchant_20s, HealingSpot_5s, ArcOfObliteration_30s...) |
| `_Preconditions` (self) | nearly always `State(op=0, State=9)` + `State(op=1, State=1014, Not)` (= "idle/able to act" and "not in a busy state"), then `BattleMode(6)` or `PawnBattleState(4/6)`, skill checks (`IsPrepareSpell(skill)`, `PawnCustomSkill(skill)`, `IsStockSpell`), `Personality`, `OrderedFromPalyer`, `IsSafetyPosition` |
| `_TargetPreconditions` | `IsCaught(Not)`, `IsDead(Not)`, `ImmuneToDamage(attribute/element...)`, `GeneralPointHeight`, `StatusCondition(Not)`, `JobType` (for party targets), `IsFlying`, `ScaleType`, `IsBoss`, `IsAroundEnemySpecies` |
| `_TargetConditions` (re-checked while running) | `IsCaught(Not)`, `IsDead(Not)`, `IsDown` |
| `_EvaluationCriterions` | `PawnCommonEvaluate x16` (the shared curve files `PawnBattleEvaluationCriterions_ShortRange/LongRange/Job02/Air.user`), `AIStaminaStatus x1`, `DistanceFromTarget`, `NumberOfEnemiesAroundTarget`, `TargetHpPct`, `FixedValue` |
| `_StartProcess` / `_EndProcess` | `SetAttackRange(ActionID, Job, Category, SkillActionID)` on start, `SetAttackRange(IsReset)` on end (822 uses): tells the AI the reach of the attack it is about to do; `BBActionBool`, `PawnTalk` (voice), `SetMaxWeightOnPress`, `AddDecisionPack` (chains follow-up packs) |
| `_HumanCustomSkillIDs` | the skill(s) the decision needs equipped; empty for basic attacks |
| ActInterPack | `DrawWeapon` → `move.Approach` → the attack command, often with a `move.KeepDistance` / `StrafeKeepDistance` sub-command that runs while the main command waits |

Catalog sizes (see `atlas/catalog.md` for every class with examples): 308 condition classes (State 1,787 uses, IsDead
1,209, IsCaught 1,107, ImmuneToDamage 411, PawnBattleState 402, Composite 530, RayCheck 248, Distance 231...),
45 evaluation classes, 225 command classes used by pawns, 51 process classes.

Decoy-aware pieces that already exist: target conditions `IsTargetDecoy` (used twice, in Common_Pawn packs),
`IsDecoy(_IsPlayerDecoy)`, `IsPossessedDecoy`, `IsPossess(_Type)`; evaluation `TargetIsParty`; the enemy side
reacts to decoys through hate (`SmokeDecoy.IsTargetResistered`, `HateSystem`).

## 4. Commands: generic vs job-specific

- Generic job commands (`app.actinter.cmd.job.*`): `NormalAttack` 180 uses, `ComboAttack` 116, `HeavyAttack` 43,
  `ChargeAttack`, `DashAttack`, `JumpAttack`, `SkillCombo`, `CustomSkillStandardBase`. They resolve through the
  pawn's *current* `HumanActionSelector` selector, which follows the equipped weapon. On a Job09 selector:
  `NormalAttack` = `Job09_ShortSmokeAttack` (censer swing), `HeavyAttack` = `Job09_SummonDecoy`.
- Per-skill commands (`job01.BlinkStrike`, `job03.Levin`, `job06.MeteorFall`, ...) call `requestCustomSkill(id)`
  with extra logic (aim, wait for charge, release). Job09 has only `CastSmokeGiants` and `CastPossessionSmoke`.
- `ActNo { ActionID }` requests any action node by name; 7 pawn packs and the NPC Job07 packs use it. Together with
  the `app.Job09ActionID` names it covers every Trickster action without new classes.

## 5. Where the per-job logic is hard-coded (the real gates for a Trickster pawn)

| Place | What it does | Lifted how (verified in game) |
|---|---|---|
| `HumanActionSelector.addNormalJobSelectors()` (pawn setup) | only Job01..Job06 selectors | `addJobSelector(chara)` after the job change adds `Job09ActionSelector` |
| `PawnUtil.getJobNormalAttackAction/HeavyAttackAction(+Hash)` and `PawnSkillActionController.getCommonAction(+Hash)` | return "" for Job07–10 | post-hooks returning `Job09_ShortSmokeAttack` / `Job09_SummonDecoy` |
| `Job09ActionController.DecoyHandler.Prefab` | filled from `app.Player.DecoyPrefab` only | share the Arisen's `PrefabController` (`set_Prefab`); a fresh holder from `setup(via.Prefab)` crashed |
| `ItemManager` equip queue (`addEquipChangeInfo` + `applyEquipChange`) | for a pawn it only removed the old weapon | write `EquipData.Data.Equips[Main] = storageData`, flag it equipped, `applyEquipDataForCharacter(chara)` |
| guild UI (`requestJobGuildMenu2` disabled-job list) | hides hybrids | `JobContext.setJobQualified(9)` + `HumanJobChanger.requestChangeJob(9)` bypass it |
| `HumanCombatResourceManager` (`PawnJobCombatResource_Job01..06`) | per-job pawn resources | not needed so far: the main pawn's own CharaID prefab (Arisen FSM, effects ch01..09, `ch100ColliderBank`) carried the summon, Rally and beckon animations |
| AI data (goals, skill sets) | Job01..06 only | append Job09 to Warrior `_Job` arrays; add `CustomSkillDecisionSet`s with cloned packs |

Everything in the table is managed code reachable from REFramework Lua; no native patch is required.

## 6. Trickster port: the design that follows from the data

Role: a support pawn. It never deals real damage, so the pack set is: one decoy manager, three or four buffs/controls,
basic censer swings for aggro, and movement that keeps it near the party.

| Decision | Template family | Commands | Conditions to add |
|---|---|---|---|
| Summon simulacrum | `Job05_NormalAttack_01` shape (Battle, enemy target, Medium) | `DrawWeapon` → `move.Approach` → `ActNo(Job09_SummonDecoy)` | gate on no decoy (prototype toggles `_Enabled` from `DecoyHandler.HasInstance`); prefer `Distance` to enemy 5–15 m |
| Beckon / reposition decoy | `Common_Pawn_FormationFollowPL` shape | `ActNo(Job09_Transfer)` | decoy farther than ~20 m from the party, or `IsTargetDecoy` target not engaged |
| Sweeping Shroud (95) | taunt family `Job01_ShieldSummons_EMTarget` / `Job05_WarCry_EMTarget` | `ActNo(Job09_CastAttentionFregrance)` | `NumberOfEnemiesAroundTarget` ≥ 2, decoy present |
| Aromatic Rally (97) | party buff family `Job03_FireBoon` (Target My+Player+Party, Policy Magic+Help+Skill) | `ActNo(Job09_CastRageFregrance)` | `PawnBattleState(Battle)`, boss or ≥3 enemies; keep the `IsPrepareSpell(Not)` precondition retargeted to 97 |
| Dragon's Delusion (99) | `Job05_WarCry_EMTarget` | `ActNo(Job09_CastSmokeDragon)` | `IsBoss` or `ScaleType` large, long cooldown |
| Delusory Screen (92) | `Job04_SmokeScreen` | `ActNo(Job09_CastSmokeWall)` | ally low HP (`SelfRecoverableHP` / `IsLowestHpInParty`), enemy approaching |
| censer swings | Warrior `JobDecisions` lists extended with Job09 (generic `job.NormalAttack`) | — | none; `SetAttackRange(ActionID=Job09_ShortSmokeAttack)` on start |
| leave out | Latching Effigy (96), Espial Incense (119): context actions without a plain action name; Fickle Floor (93): positional |

Quality expectations: the summon/rally/beckon actions are confirmed to run on a pawn; the pawn's own goal planning
picked up the injected pack. Positioning is the weak spot (summon where the pawn stands), so the decoy mostly
works through its 30 m territory and Sweeping Shroud, and the next iteration should summon only within ~10 m of
an enemy and beckon when the decoy drifts.

## 7. Engineering notes learned the hard way

- `sdk.create_userdata(type, path)` returns the game's shared instance: editing it edits the vanilla pack for every
  pawn. Copy first (the prototype's `clone_pack` / `shallow_copy`). Paths must be exact-case
  (`data/exact_case_paths.txt`); a wrong case yields an empty object.
- REFramework managed arrays: `arr[i] = obj` for objects; 4-byte enum elements are inline at `+0x20 + 4*i`
  (`write_dword`); there is no `set_element`.
- `requestAction(name, 0)` works even while `CurrentSelector` is `NoJobActionSelector`; `requestCustomSkill`
  needs the job selector.
- Save safety: `Job09` is a legal `JobEnum` in save data, but the rift expects pawn jobs 1–6. Quit without
  saving after tests, or restore the previous job before any save/upload; the main pawn's bow was taken off by
  the equip queue and has to be put back.
- The offline RSZ decoder reads all goal data and most packs; `via.AnimationCurve` is `i32 n + n×16-byte keys +
  24 bytes`, stale whitelists hide extra fields in a few classes (`MoveBase`, `AIStaminaStatus`, ...). The live
  dumper (`tools/dumplib.lua`) is the reliable reader while the game runs.
