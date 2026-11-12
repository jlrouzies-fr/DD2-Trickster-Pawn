-- PawnTrickster.lua - Trickster main pawn (beta 0.2.7): the main pawn takes the Trickster vocation (Job09) and fights with it.
--
-- With "auto_enable": true (the default) the pawn becomes a Trickster at every save load; set it to false in
-- reframework/data/PawnTrickster/config.json to run PawnTrickster.enable() / disable() by hand (REFramework menu >
-- Script Generated UI > Pawn Trickster). Every step is guarded; errors always go to reframework/data/PawnTrickster/log.txt; "log": true (or the panel's log switch) writes every step.
-- Back up the save folder before the first use: a pawn stored on Job09 is not something the online rift expects.
--
-- What enable() does (see trickster/README.md for the evidence behind each step):
--   1. qualifies and switches the main pawn to Job09 through the game's own HumanJobChanger;
--   2. equips a censer in the Main slot: the one she holds, else the one pawns.json remembers, else the best censer
--      she owns, else a starter censer (cfg.censer_item_id) - the save does not keep a pawn's censer equipped;
--   3. adds the missing app.Job09ActionSelector to HumanActionSelector.Selectors (pawns only get Job01..06);
--   4. makes sure Job09ActionController has a DecoyHandler (prefab shared with the Arisen's app.Player);
--   5. hooks PawnUtil.getJob*AttackAction* / PawnSkillActionController.getCommonAction* so Job09 returns
--      the censer swing / Effigial Incense action names instead of "";
--   6. skills: release mode keeps the pawn's own Job09 skills, levels, core skills and augments (pawns.json refills
--      them if the game ever loses them; a new Trickster pawn gets the vanilla rank-1 skills once); "debug": true
--      forces Aromatic Rally (97), Sweeping Shroud (95), Dragon's Delusion (99), Delusory Screen (92). Then one
--      decision pack of its own (summon, beckon, shroud, rally, delusion, screen, stance, trick: ActNo commands, flat
--      evaluators, per-frame gates; a skill slot fires only when that skill is equipped) goes to the AIDecisionMaker.
--      v47: the "trick" slot is Latching Effigy (96); Fickle Floor (93) and Espial Incense (94) are requested
--      from Lua; the keep-distance decision is force-ended when a cast has been waiting (it never ends alone); Scented
--      Alarum (98) runs on a timer out of battle; Dragon's Delusion is ended by a timer; optional vanilla voice lines;
--      a save loaded later in the same session (the main pawn is rebuilt) resets the script and enables it again.
--      v48g (0.2.5): Aromatic Rally every 12 s instead of 25, but only above 75 % of her stamina, and Dragon's
--      Delusion only above 50 % (settings rally_cooldown, rally_min_stamina, delusion_min_stamina). Latching Effigy
--      is cast while she faces an enemy 3-10.5 m away; the rule's own target has to be in that range, within 12
--      degrees of her facing and, when it is a Small enemy, higher than her (v48h; it used to wait for an enemy at
--      3-6 m in any direction: turned away it never latched, and the incense flew over level goblins). config.json: a setting that
--      still has its old default follows a changed default (config.defaults.json).
--      v48i (0.2.6): the "dust" slot, an idle attack: the censer swing from a distance, and the script throws the
--      game's own "thrown smoke" shell at the enemy she faces (app.ShellManager.requestCreateShell). The hit's damage
--      is written after the game's calculation (HitController.calcDamageValue), and the hate entry that shell adds
--      for its thrower is left out (HateSystem.addHateParam). Latching Effigy: when the game's incense leaves her
--      hand the script throws a second one at the target's legs (the game aims at a point that is over a goblin).
--      v48l (0.2.6): the dust attack is the game's own throw of smoke (Job09_ThrowSmoke): a real swing of the censer,
--      and the ball leaves when the game's own thrown smoke leaves the hand; PT.dust_test() for clips.
--      v48k (0.2.6): the smoke of a dust swing made minimal: the game's own smoke cloud of the censer swing (a shell
--      of its own) is taken out, the impact cloud and the censer's swing smoke fade out and are removed after 0.3 s.
--      only_slot (a test setting) holds every slot but one.
--      v48j (0.2.6): the ball's effects are scaled down where the game creates them, and an enemy it hits lets go of
--      the party's pawns for a few seconds and goes for the decoy (its stored hate of each pawn is written to 0 every
--      frame for that time).
--      v48f (0.2.4): a dispersed decoy is re-summoned only while the party is in battle (it came back every few
--      seconds out of combat too). New "regroup" rule: when Aromatic Rally is ready and no ally is within
--      rally_distance, she dashes to the Arisen (the game's own Move_Fix_Dash_Target pack) and casts it there.
--      v48e (0.2.3): her cast rules no longer carry two target checks of the Warrior attack they are copied from
--      ("target not immune to my weapon", "target point 0-2 m high": against phantoms every target failed and she
--      never cast) nor its check of her own AI state (false in the "Danger" state: she cast nothing for whole fights);
--      the party's battle state gates her slots instead ("rule_drop" in config.json). Aromatic Rally also when
--      another party pawn is within rally_distance, and not started under "rally_min_stamina" of her stamina.
--      v48d (0.2.2): enable() does nothing while she is enabled (two setups on top of each other left her idle).
--      v48c (0.2.2): "avoid_jobs" in config.json names vocations whose decisions she must not borrow (test aid).
--      v48b (0.2.2): the censer is equipped with the game's own ItemManager.setEquip: the equipment menu shows it as
--      equipped (not her old staff) and the save keeps it.
--      v48a (0.2.2): when a pawn is hired or dismissed (or a hired pawn changes vocation) she is set up again, so her
--      AI slots never sit on decisions of a vocation a party pawn has.
--      v47z: enemies made with the test helper PT.spawn_enemies are destroyed through the spawner once the scene is
--      unloaded (they outlive it otherwise and the game crashes at the title screen).
--      v47x: the console test helpers no longer run outside the InGame phase and are reset with the script state.
--      v47w: the combat rules are built once per load; a failure is logged and not retried every frame.
--      v47v: the talk-category cache is dropped at every reset (a stale category crashed the talk controller).
--      v47u: the Lua re-summon of a sleeping decoy waits while her own summon action is creating the decoy.
--      v47t: the Job09ActionSelector is no longer added to her selector list (not needed, see job09_selector).
--      v47s: when the game leaves the in-game phase (title, death, load) her packs are removed, the vanilla AI data
--      the script borrowed is put back and the Job09 selector it added to her is taken out before the scene is
--      unloaded; the game crashed at the title screen otherwise (5 of 7 returns).
--      v47m: created objects keep a permanent reference (PT.keep): short-lived ones crashed the game at random.
--      v47p: a new pawn no longer starts with the cut skills 118 / 119 (and an affected pawn loses them once);
--      core skills are read from the skill context's list and now reach pawns.json.
--      v47o: auto-enable waits until the same pawn object is seen twice (the game can shuffle her after a warp).
--      v47n: voice lines for Aromatic Rally, Dragon's Delusion and a latched effigy; the Delusory Screen line of
--      0.2.0 never played (its talk group does not start from a request) and is replaced.
--   PawnTrickster.disable() puts the previous job back and removes the added decision packs.

local PT = { enabled = false, state = {}, log_lines = {} }
_G.PawnTrickster = PT
-- v47m: every object this script creates keeps a PERMANENT reference. REFramework gives an add_ref() reference back
-- when the Lua value is garbage-collected, and an object that is created and then freed inside the same frame
-- corrupts the engine's table of frame-local objects: ten of them crashed the game within 8 s, the same objects
-- freed in a later frame or holding a permanent reference did not (measured 2026-11-10). The script had such
-- short-lived objects (the ActInterPackData wrapper of every ActNo slot at enable, the StartInformation of every
-- decoy re-summon); whether Lua collected them in their frame decided the crashes at DD2.exe+0x524507e and
-- +0x52590e4. add_ref() first: on a MemberwiseClone it also counts the references the clone copied.
function PT.keep(o)
    if o then o:add_ref(); o:add_ref_permanent() end
    return o
end

local DATA_DIR = "PawnTrickster"
local LOG_PATH = DATA_DIR .. "/log.txt"
local CFG_PATH = DATA_DIR .. "/config.json"

local cfg = {
    auto_enable = true,         -- true: make the main pawn a Trickster as soon as the save is loaded (re-applies after every load)
    revert_job = 3,             -- disable() sends the pawn back to this job when the save already had it on Job09 (3 = Mage)
    censer_item_id = 2104,      -- wp10_001_00: Trickster censers are wp10 (item _Job bit 512); wp09 is the duospear
    template_job = 5,           -- Job05 (Warrior) basic-attack decisions are reused for Job09
    debug = false,              -- false (release): the pawn keeps the skills, core skills, augments and censer the game and
                                -- pawns.json remember; a new Trickster pawn starts with the vanilla rank-1 skills only, and the
                                -- AI casts only the skills she has equipped. true: force `skills` at level 1 every load (testing)
    skills = { 97, 95, 99, 92 },-- debug only: Aromatic Rally, Sweeping Shroud, Dragon's Delusion, Delusory Screen
    starter_skills = { 95 },    -- release fallback: weapon / core skills a new Trickster pawn gets when the game's own skill
    starter_normal_skills = { 34 }, -- tables cannot be read (normally read live: level-1 entries with _UnlockRank <= 1;
                                    -- run 58 read 95 rank 1; 99 Dragon's Delusion is not a rank skill). Official ranks
                                    -- (Fextralife wiki, 2026-11-09): rank 1 Sweeping Shroud 95 (100 Dcp) + core Mending
                                    -- Vapor 34 (150 Dcp); 2 Delusory Screen 92; 3 Aromatic Rally 97; 4 Espial Incense 94;
                                    -- 5 Fickle Floor 93; 6 Latching Effigy 96; 7 Scented Alarum 98; 99 = Maister scroll.
                                    -- Censer swing, decoy, beckon, unsummon and possession are rank-0 core actions.
    remember = true,            -- keep pawns.json up to date (censer, weapon skills, skill levels, core skills, augments)
    summon_cooldown = 12.0,
    beckon_distance = 15.0,
    command_path = "mux",
    settle_seconds = 10.0, -- no Trickster decision before this many seconds after enable
    stance_band = { 7.0, 5.0 }, -- run 59: via.Range {start, width} written into the stance node's KeepDistance command: hold 7..12 m from the enemy target
                                -- (the only vanilla node with a small band, Common_KeepDistance_Dash, is {0, 3}: it dashed the pawn INTO 0-3 m; the
                                -- NPC large-target nodes are 25-50 m). The write goes to a MemberwiseClone of the vanilla node/command when the clone
                                -- works, else to the shared command (restored by disable()). nil = leave the vanilla band.
    stance = true, stance_min_band = 0.0, stance_value = 1.0, stance_weight = 24, stance_rank = 3, stance_cooldown = 6.0, stance_trigger = 8.0, -- stance allowed only while an enemy is within stance_trigger metres
    melee = false,          -- censer-swing slot (off: no damage, pulls the pawn into reach)
    retreat_seconds = 8.0,  -- stance only (summon slot held) for this long after the summon action ends: walk away from the decoy
    rally_distance = 12.0,  -- Rally only with the Arisen (v48e: or another party pawn) this close
    regroup = true, regroup_stop = 8.0, regroup_seconds = 8.0, regroup_cooldown = 20.0, regroup_max = 40.0, -- v48f: Rally ready and no ally in reach: dash to the Arisen (stop at regroup_stop m, give up after regroup_seconds; not when the Arisen is beyond regroup_max m)
    resummon_calm = false,  -- v48f: true re-summons a dispersed decoy out of battle as well (0.2.3 and earlier did)
    rally_cooldown = 12.0,   -- v48g: seconds between two Aromatic Rallies (25 until 0.2.4)
    delusion_min_stamina = 0.5, -- v48g: Dragon's Delusion is not started with less than this share of her stamina
    delusion_stop_stamina = 0.15, -- v48g: a running Dragon's Delusion is ended when her stamina falls under this share
    rally_min_stamina = 0.75, -- v48e (0.5), v48g (0.75 with the shorter cooldown): Rally is not started with less than this share of her stamina (0 = no check)
    rule_drop = { "ImmuneToDamage", "GeneralPointHeight", "BattleMode" }, -- v48e: checks of the copied Warrior attack her casts must not carry
    cast_in_ready = false,  -- v48e: her casts wait for the party's Battle state; true lets them start in the Ready state too
    big_enemy_hp = 5000,    -- Dragon's Delusion only with an enemy above this HP within 40 m
    protect = true,          -- protect the Arisen: a quick HP drop (protect_drop of max HP within ~2 s) or HP under
    protect_drop = 0.08,     -- protect_low opens a protect_seconds window: the summon slot (summon / Transfer / Shroud by
    protect_low = 0.5,       -- the mux) and Delusory Screen are released at once (cooldown timers to 0, repeated every
    protect_seconds = 6.0,   -- protect_repick seconds), the stance and Rally are held off
    protect_repick = 10.0,
    backoff_to_cooldown = true, -- a pick that lands on the module's 300-frame retry backoff waits the slot's own cooldown instead
    flee_first = false,      -- with an enemy within stance_trigger and the decoy up, hold every cast and let the stance move the pawn (run 33: the stance was not picked either; off)
    delusion_min_enemies = 3, crowd_distance = 25.0, -- Dragon's Delusion also against this many enemies within crowd_distance of the Arisen
    shroud = false,          -- cast Sweeping Shroud next to the decoy (its attention hate is player-only: off, the pawn moves instead)
    -- v47: the rank 4-7 skills
    effigy_near = 3.0, effigy_far = 10.5, effigy_height = 4.0, effigy_aim_deg = 12.0, effigy_band = true, effigy_hold = 12.0, -- v48g: cast while she faces an enemy (within effigy_aim_deg) that is effigy_near..effigy_far m away, and the rule only takes targets in that band (effigy_band); once latched she stops backing off for effigy_hold s
    screen_min_stamina = 0.45, -- v48g: Delusory Screen (26-39 % of her stamina a cast) is not started under this share
    effigy_face_target = true, effigy_small_rise = 0, -- v48h: the rule's own target has to be within effigy_aim_deg of her facing. effigy_small_rise above 0: a Small enemy only when it is this much higher than her as the game measures it, to the target's body point (0.2.5 shipped 1.7: the game's incense flew over level goblins; since v48i the script throws the incense at their legs, so the rule is off)
    effigy_min_stamina = 0.75, -- v48g: Latching Effigy (46 % of her stamina a cast) is not started with less than this share (0.6 still left her out of breath)
    dust = true,            -- v48i: the idle attack: a censer swing from a distance that throws a ball of incense smoke at the enemy she faces
    dust_near = 4.0, dust_far = 14.0, dust_cooldown = 4.0, -- where the rule's target has to be (m), seconds between two
    dust_aim_deg = 0,       -- above 0: the rule only takes a target within this many degrees of her facing (30 gave one swing a minute: idle, she rarely faces an enemy)
    dust_delay = 0.35, dust_window = 1.1, -- (only with dust_action "Job09_ShortSmokeAttack") the ball leaves the censer between these two moments of the swing (s), as soon as the pawn faces the target
    dust_action = "Job09_ThrowSmoke", -- v48l: the action of the dust attack. The game's own throw of smoke (the Arisen's Drifting Brume): the pawn swings the censer and the ball leaves when the game's own thrown smoke leaves the hand (0.7 s in). "Job09_ShortSmokeAttack" = the flick of the wrist of v48i-k
    dust_release_wait = 1.6, -- v48l: no ball if the game's throw has not come this long after the swing began (the swing was cut)
    dust_face_deg = 25.0, dust_turn_rate = 420.0, -- "faces" in degrees; how fast the script turns her to the target during the swing (degrees a second, 0 = not at all)
    dust_damage = 0,        -- damage of a hit; 0 = dust_damage_base + dust_damage_level x the pawn's level
    dust_damage_base = 20.0, dust_damage_level = 5.0,
    dust_no_aggro = true,   -- the game's "thrown smoke" hate for the thrower is not added (false: the enemy turns on the pawn)
    dust_aim_height = 0.7,  -- the ball is aimed this far above the target's feet (m)
    dust_safe = 3.5,        -- no swing while an enemy is closer to her than this (m)
    dust_height = 3.0,      -- v48j: the ball's target is at most this much higher or lower than her (m): a goblin down a cliff is no target
    dust_hit_scale = 0.4, dust_trail_scale = 1.0, -- size of the ball's impact burst and of its trail (1 = the game's own size). v48k: 0.12 / 0.25 with 60 % opacity left nothing to see of the throw (clip on a frozen goblin); the big smoke had been the swing's own shell, not these
    dust_swing_scale = 0.15, -- v48k: size of the censer's own smoke during the dust swing
    dust_fx_alpha = 1.0, dust_fx_speed = 1.0, -- v48k: those effects are also this opaque (1 = as the game draws them) and played this fast
    dust_hit_life = 0.5, dust_swing_life = 0.3, -- v48k: the impact cloud and the censer's swing smoke fade out and are removed after this many seconds (0 = left to play out). A smoke cloud grows with its age and the scale above does not change the size of its particles: this is what keeps it small
    dust_swing_shell = false, -- v48k: the censer swing throws the game's own smoke cloud as well (a shell of its own: three seconds of thick smoke and a burst where it lands). false = taken out during a dust swing
    dust_fool = true,       -- v48j: an enemy hit by the ball lets go of the party's pawns and goes for the decoy (only with a decoy out)
    dust_fool_seconds = 6.0, -- for how long
    dust_fool_big = false,  -- true: big enemies (more HP than big_enemy_hp) are fooled as well
    shell_reach_40 = 13.0,  -- how far a thrown smoke shell flies at 40 FPS (m); the reach used is this x (FPS / 40)^2
    effigy_rethrow = true, effigy_aim_height = 0.5, -- v48i: Latching Effigy: the incense is thrown by the script, aimed this far above the target's feet
    effigy_replace = true,  -- v48i: and the game's own incense is taken out (false: both fly; the game's one then lands next to the target and ends the latch)
    effigy_approach = true, effigy_approach_seconds = 8.0, effigy_approach_retry = 25.0, -- no enemy in reach: she stops backing off for a few seconds so one comes into reach
    preempt = true, preempt_wait = 1.5, preempt_interval = 6.0, -- the keep-distance decision never ends by itself: end it when a cast has waited preempt_wait s
    alarum_calm = 10.0, -- Scented Alarum only after this long out of battle
    effigy = true, effigy_cooldown = 35.0, effigy_min_enemies = 2, effigy_range = 25.0, -- Latching Effigy: decoy out, 2+ enemies, one within range of the decoy
    floor = true, floor_cooldown = 45.0, floor_need_ledge = true, floor_enemy_distance = 20.0, floor_drop = 4.0, -- Fickle Floor: a drop of floor_drop m between her and the nearest enemy
    espial = true, espial_cooldown = 60.0, espial_seconds = 3.5, espial_min_distance = 8.0, -- Espial Incense: trance, the decoy is sent next to the enemy nearest the Arisen
    alarum = true, alarum_interval = 300.0, alarum_seconds = 2.5, alarum_range = 50.0, -- Scented Alarum: out of battle, every alarum_interval s; a warning line when an enemy is within alarum_range
    delusion_seconds = 5.0,  -- Dragon's Delusion is held this long, then ended (held to exhaustion before v47)
    voice = true, voice_cooldown = 45.0, -- vanilla pawn lines on some casts (one line per voice_cooldown s at most)
    -- v47n: every category below was seen starting (PawnManager.onStartPawnTalkMonologue) and read as a subtitle on
    -- 2026-11-10. Categories of talk groups 27 and 82 (Skill_Guard, Rescue, CustomSkill, AttackVoice, HoldDown) are
    -- accepted by requestPawnTalk and never start: "screen" was one of them in 0.2.0 and never played.
    voice_lines = { taunt = "PawnTalk_ACT_Hate_01",          -- decoy / Sweeping Shroud: "I'll hold the enemy's focus!"
                    rally = "PawnTalk_ACT_TalkInBattle_01",  -- Aromatic Rally: "Falter not, and our foe shall soon be vanquished!"
                    delusion = "PawnTalk_ACT_ChanceTime_04", -- Dragon's Delusion: "Our foe has been thrown off balance!"
                    effigy = "PawnTalk_ACT_ChanceTime_01",   -- Latching Effigy, when it latches: "We've an opening! Focus your attacks!"
                    screen = "PawnTalk_ACT_Worried_01",      -- Delusory Screen cast for the Arisen: "Arisen! Are you all right!?"
                    alarum = "PawnTalk_CMN_Search_01" },     -- Scented Alarum: "Allow me to check whether there's aught nearby."
    share_player_decoy = true,
    resummon_seconds = 6.0,
    resummon_offset = 7.0,   -- the re-summoned decoy stands this far from the pawn, towards the nearest enemy  -- a dispersed (sleeping) decoy is re-summoned at the pawn at most this often -- the pawn summons through the Arisen's DecoyHandler (enemies only ever target the player's decoy; run 41)
    ui_icon_pattern = 8,     -- Trickster crest cell of the job icon sheet (the game draws cell 10, "?", for a Job09 pawn)
    ui_fix = true,           -- GUI: app.GUIBase.isDispEnableJob(Job09) answers true (status page icon, name and skill list of a Trickster pawn; run 21)
    test_guard = 0,          -- TEST ONLY: when > 0, app.Character.recoverAll() on the Arisen whenever HP falls under this fraction
    attack_range = 14.0, -- blackboard Action.AttackRangeXZ held at this many metres (0 = leave alone; "mage" = copy the party Mage's value, 30 m seen)
    goal_jobs = true,        -- goal planning (run 58): Job09 is appended to every all-vocation JobDecisions row (escape, dodge,
                             -- formation strafe, wrestle... had no Job09 entry at all) and a Job09-only row holding the Mage's
                             -- movement packs (goal_move_packs) is added next to each Mage row that carries one
    goal_move_packs = { "AppSystem/AI/Decision/Pack/Job03_KeepDistance_01.user", "AppSystem/AI/Decision/Pack/Job03_MoveAttackRange.user" },
    mage_keepdistance = true, -- also add the Mage's vanilla Job03_KeepDistance_01 decision pack (Approach / StrafeKeepDistance with Mage conditions) -- caster stance: vanilla KeepDistance node whose band starts >= stance_min_band
    require_battle = false, -- and only while the pawn's battle state is Battle -- "mux": vanilla generic packs + hook multiplexer (run 6); "actno": created ActNo packs (inert in run 5)
    job09_selector = false,  -- v47t: true adds an app.Job09ActionSelector to her selector list as 0.1.0-0.2.0 did. She
                             -- fights the same without it (her actions run by name under NoJobActionSelector), and a
                             -- pawn never has one in the vanilla game
    log = false,             -- true: write every step to reframework/data/PawnTrickster/log.txt (grows fast in fights)
}
do
    -- v48g: config.json holds every key, so a default changed by a later version never reached an install that had
    -- written the old one (seen in testing: a build with a 12 s Rally cooldown ran two fights on the saved 25 s).
    -- config.defaults.json keeps the defaults as they were when config.json was last written; a saved value that
    -- still equals its old default was never touched by the player and follows the new default.
    local DEF_PATH = DATA_DIR .. "/config.defaults.json"
    local function same(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) == "number" then return math.abs(a - b) < 1e-6 end
        if type(a) ~= "table" then return a == b end
        for k, v in pairs(a) do if not same(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    local defaults = {}
    for k, v in pairs(cfg) do defaults[k] = v end
    local ok, saved = pcall(json.load_file, CFG_PATH)
    local okd, olddef = pcall(json.load_file, DEF_PATH)
    PT.cfg_moved = {}
    if ok and type(saved) == "table" then
        local default_lines = cfg.voice_lines
        for k, v in pairs(saved) do
            if okd and type(olddef) == "table" and olddef[k] ~= nil and defaults[k] ~= nil and k ~= "voice_lines"
                and same(olddef[k], v) and not same(defaults[k], v) then
                PT.cfg_moved[#PT.cfg_moved + 1] = k
            else
                cfg[k] = v
            end
        end
        if type(cfg.voice_lines) ~= "table" then cfg.voice_lines = default_lines
        elseif cfg.voice_lines ~= default_lines then -- a 0.2.0 config: add the lines that came later, drop the one that never played
            for k, v in pairs(default_lines) do if cfg.voice_lines[k] == nil then cfg.voice_lines[k] = v end end
            if cfg.voice_lines.screen == "PawnTalk_ACT_Skill_Guard_07" then cfg.voice_lines.screen = default_lines.screen end
        end
    end
    pcall(json.dump_file, CFG_PATH, cfg)
    pcall(json.dump_file, DEF_PATH, defaults)
    PT.cfg_changed = {} -- (for the header of log.txt)
    for k, v in pairs(cfg) do -- (keys an older version wrote that this one has no default for count only when not false)
        if (defaults[k] ~= nil or v ~= false) and not same(defaults[k], v) then PT.cfg_changed[#PT.cfg_changed + 1] = k end
    end
    table.sort(PT.cfg_changed)
end

-- 0.2.7: log.txt holds everything a bug report needs, whatever "log" says. At each start the last log becomes
-- log.previous.txt (so a crash survives one relaunch) and log.txt begins with a header (build, REFramework, the
-- settings changed from their defaults). With "log": false it then only gets errors: lines that say "error",
-- "failed", "not found", "missing" or "could not", which includes every error thrown inside the script's hooks and
-- frame callbacks (see guard below), at most ERR_CAP of them per start. With "log": true it gets every step, as before.
PT.VERSION = "0.2.7"
local PREV_PATH = DATA_DIR .. "/log.previous.txt"
local ERR_CAP, err_written = 300, 0
local function write_line(line)
    local f = io.open(LOG_PATH, "a")
    if f then f:write(line, "\n"); f:close() end
end
do
    local old = io.open(LOG_PATH, "rb")
    if old then
        local size = old:seek("end") or 0
        old:seek("set", math.max(0, size - 4 * 1024 * 1024)) -- (logs of 0.2.6 and older were never emptied: keep the last 4 MB)
        local body = old:read("a") or ""
        old:close()
        local p = io.open(PREV_PATH, "wb")
        if p then p:write(body); p:close() end
    end
    local f = io.open(LOG_PATH, "w")
    if f then f:close() end
end
-- what counts as an error line with "log": false. Checked against an 8 MB log of 118,955 lines: 105 matches, all of
-- them real errors (action names such as HighFive_Failed have a capital F and do not match).
local function is_problem(line)
    for _, w in ipairs({ "error", "failed", "not found", "missing", "could not" }) do
        if line:find(w, 1, true) then return true end
    end
    return false
end
local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    local line = os.date("%H:%M:%S ") .. table.concat(parts, " ")
    PT.log_lines[#PT.log_lines + 1] = line
    if #PT.log_lines > 400 then table.remove(PT.log_lines, 1) end
    if cfg.log then
        write_line(line)
    elseif err_written < ERR_CAP and is_problem(line) then
        err_written = err_written + 1
        write_line(err_written < ERR_CAP and line or (line .. "  (no more errors are written until the next start)"))
    end
end
-- "log" switched on from the REFramework panel: the steps kept in memory (the last 400) go to the file first, so a
-- player who turns it on right after a bug still sends what led to it
function PT.set_log(on)
    on = on == true
    if on == (cfg.log == true) then return end
    if on then
        write_line(os.date("%H:%M:%S ") .. "log: switched on; the " .. #PT.log_lines .. " steps kept in memory follow")
        for _, l in ipairs(PT.log_lines) do write_line("  " .. l) end
    end
    cfg.log = on
    pcall(json.dump_file, CFG_PATH, cfg)
    log("log: " .. (on and "on (every step is written)" or "off (only errors are written)"))
end
do
    local function rf(name)
        local ok, v = pcall(function() return reframework[name](reframework) end)
        return ok and v ~= nil and tostring(v) or "?"
    end
    write_line(string.format("PawnTrickster %s started %s", PT.VERSION, os.date("%Y-%m-%d %H:%M:%S")))
    write_line(string.format("REFramework %s %s (commit %s, %s commits, built %s), %s", rf("get_tag"), rf("get_branch"),
        rf("get_commit_hash"):sub(1, 10), rf("get_commit_count"), rf("get_build_date"), _VERSION or "Lua"))
    local diff = {}
    for _, k in ipairs(PT.cfg_changed or {}) do
        local v = cfg[k]
        diff[#diff + 1] = k .. "=" .. (type(v) == "table" and "{...}" or tostring(v))
    end
    write_line("settings changed from the defaults: " .. (#diff > 0 and table.concat(diff, ", ") or "none"))
    if PT.cfg_moved and #PT.cfg_moved > 0 then write_line("settings that follow a new default: " .. table.concat(PT.cfg_moved, ", ")) end
    write_line("log: " .. (cfg.log and "every step" or "errors only (tick \"Enable debug logs\" in the REFramework panel for a bug report)"))
end

-- every hook and frame callback of the script runs through guard(): an error is written to log.txt with its stack
-- (the first 3 of each place, then every 100th with a count) instead of only to REFramework's log. A failed pre-hook
-- lets the game's method run; a failed post-hook returns the game's own result.
local guard_n = {}
local function guard_report(where, msg)
    local n = (guard_n[where] or 0) + 1
    guard_n[where] = n
    if n <= 3 then
        log("error in " .. where .. (n == 3 and " (3rd time; from now on every 100th):" or ":"), msg)
    elseif n % 100 == 0 then
        log("error in " .. where .. " (" .. n .. " times):", msg)
    end
end
local function guard_parts(kind, fn)
    local ok, info = pcall(function() return debug.getinfo(fn, "S") end)
    local where = kind .. " at line " .. tostring(ok and info and info.linedefined or "?")
    local function handler(e) -- runs before the stack unwinds: the stack is only written for the first 3 errors
        if (guard_n[where] or 0) < 3 and debug and debug.traceback then return debug.traceback(tostring(e), 2) end
        return tostring(e)
    end
    return where, handler
end
local function guard(kind, fn)
    local where, handler = guard_parts(kind, fn)
    local function done(ok, ...)
        if ok then return ... end
        guard_report(where, (...))
        return nil
    end
    return function(...) return done(xpcall(fn, handler, ...)) end
end
local function hook(m, pre, post)
    local gpre = pre and guard("pre-hook", pre)
    local gpost
    if post then
        local where, handler = guard_parts("post-hook", post)
        gpost = function(retval)
            local ok, r = xpcall(post, handler, retval)
            if ok then return r end
            guard_report(where, r)
            return retval
        end
    end
    return sdk.hook(m, gpre, gpost)
end
PT.guard = guard -- (for the test tools)

-- enum values read live on 2026-11-08 (see trickster/live/enums.txt)
local JOB09 = 9
local SKILL = { SmokeWall = 92, SmokeGround = 93, AttentionFregrance = 95, PossessionSmoke = 96, RageFregrance = 97,
                DetectFregrance = 98, SmokeDragon = 99, HealingSmoke = 118, SmokeGiants = 120 }
local SKILL_ACTION = { [92] = "Job09_CastSmokeWall", [93] = "Job09_CastSmokeGround", [94] = "Job09_CastTripFregrance",
                       [95] = "Job09_CastAttentionFregrance", [96] = "Job09_CastPossessionSmoke",
                       [97] = "Job09_CastRageFregrance", [98] = "Job09_CastDetectFregrance", [99] = "Job09_CastSmokeDragon",
                       [118] = "Job09_CastHealingSmoke", [120] = "Job09_PrepareSmokeGiants" }
local ACT = { normal = "Job09_ShortSmokeAttack", heavy = "Job09_SummonDecoy", transfer = "Job09_Transfer", unsummon = "Job09_Unsummon" }
ACT.dust = (type(cfg.dust_action) == "string" and cfg.dust_action ~= "") and cfg.dust_action or "Job09_ThrowSmoke" -- v48l
-- action hashes are murmur3-32 of the UTF-16LE name with seed 0xFFFFFFFF (checked against the four hashes read live:
-- Job09_ShortSmokeAttack 3838103887, Job09_SummonDecoy 2970940001, Job09_Transfer 607844537, Job09_Unsummon 2210594192)
local function action_hash(name)
    local function rotl(x, r) return ((x << r) | (x >> (32 - r))) & 0xffffffff end
    local data = {}
    for i = 1, #name do data[#data + 1] = name:byte(i); data[#data + 1] = 0 end
    local h = 0xffffffff
    local n = #data // 4
    for i = 0, n - 1 do
        local k = data[4 * i + 1] | (data[4 * i + 2] << 8) | (data[4 * i + 3] << 16) | (data[4 * i + 4] << 24)
        k = (k * 0xcc9e2d51) & 0xffffffff; k = rotl(k, 15); k = (k * 0x1b873593) & 0xffffffff
        h = h ~ k; h = rotl(h, 13); h = (h * 5 + 0xe6546b64) & 0xffffffff
    end
    local rem = #data - 4 * n; local k = 0
    if rem >= 3 then k = k ~ (data[4 * n + 3] << 16) end
    if rem >= 2 then k = k ~ (data[4 * n + 2] << 8) end
    if rem >= 1 then k = k ~ data[4 * n + 1]; k = (k * 0xcc9e2d51) & 0xffffffff; k = rotl(k, 15); k = (k * 0x1b873593) & 0xffffffff; h = h ~ k end
    h = h ~ #data
    h = h ~ (h >> 16); h = (h * 0x85ebca6b) & 0xffffffff; h = h ~ (h >> 13); h = (h * 0xc2b2ae35) & 0xffffffff; h = h ~ (h >> 16)
    return h
end
PT.action_hash = action_hash
PT.cfg = cfg -- (live table: console tweaks during tests; the file is only read at script load)
local ACT_HASH = setmetatable({}, { __index = function(t, k) local v = action_hash(k); rawset(t, k, v); return v end })
assert(ACT_HASH.Job09_SummonDecoy == 2970940001, "action_hash mismatch")
-- vanilla single-node ActInterPackData (shared, read only): Approach + job.HeavyAttack / job.NormalAttack. The heavy
-- command asks PawnUtil.getJobHeavyAttackAction(9) for its action name, which our hook answers per selected decision.
-- run 6c: the GenericJob_* ActInterPackData are NPC ("generic job") packs; decisions carrying them sat in the pawn's main
-- list, enabled, timers at 0, and were never chosen. The one decision ever chosen AND executed (run 5's attack,
-- Job05_NormalAttack_01's own pack) carried a vanilla PAWN pack. So all slots borrow the pack of a vanilla pawn decision:
-- Common_HeavyAttackFinish = move.Approach (AttackRange decorator) -> job.HeavyAttack. The heavy-attack hooks then
-- answer with the Job09 action the slot stands for (ShortSmokeAttack for the attack slot included).
local HEAVY_PACK_SRC = "AppSystem/AI/Decision/Pack/Common_HeavyAttackFinish.user" -- (v4, crashed at add time in run 7)
-- v5: vanilla pawn decision packs whose single node is ActNo(ActionID). They belong to jobs this pawn does not have
-- (no Warrior/Fighter/Mage/Thief pawn in the party), so retargeting their ActionID in memory affects only our slots.
-- The original ActionID strings are kept in PT.state.actno_restore and written back on disable.
local SHELL_POOL = { -- exact-case decision pack names per job (trickster/data/exact_case_paths.txt)
    [1] = { "Job01_ShieldSummons_EMTarget", "Job01_CymbalAttack", "Job01_RushAttack", "Job01_BlinkStrike", "Job01_BravesRaid" },
    [5] = { "Job05_WarCry_EMTarget", "Job05_ArcOfObliteration", "Job05_CrescentSlash", "Job05_CycloneSlash" },
    [3] = { "Job03_FireBoon", "Job03_ChargeAttack_01", "Job03_DivineShot", "Job03_Firestorm", "Job03_ChargeAttack_Simple" },
    [4] = { "Job04_SmokeScreen", "Job04_AdvancedTrigger", "Job04_Attract_01", "Job04_AbsoluteAvoidance", "Job04_AirCombo_01" },
    [6] = { "Job06_AddFlare", "Job06_Blizzard", "Job06_MeteorFall", "Job06_MineVolt", "Job06_FrozenStorm" },
}
local SHELL_JOB_ORDER = { 1, 5, 3, 4, 6 }
local party_job_set = {} -- filled by party_pawn_jobs() at enable (declared here: step_ai reads it)
local ACTNO_PACKS = { -- (v6 static choice, kept for reference; v9 picks shells from SHELL_POOL at enable)
    attack   = "AppSystem/AI/Decision/Pack/Job05_NormalAttack_01.user",
    summon   = "AppSystem/AI/Decision/Pack/Job01_ShieldSummons_EMTarget.user",
    -- run 11: the party had a Mage and a Thief pawn, so Job03/Job04 shells were live for them; Fighter/Warrior shells only
    rally    = "AppSystem/AI/Decision/Pack/Job01_CymbalAttack.user",
    screen   = "AppSystem/AI/Decision/Pack/Job01_RushAttack.user",
    delusion = "AppSystem/AI/Decision/Pack/Job05_WarCry_EMTarget.user",
}
-- find the first ActNo command in a vanilla decision pack's first decision; returns the pack data and the command
local function actno_pack(path)
    local src = sdk.create_userdata("app.DecisionPack", path)
    local decs = src and src:get_field("_Decisions")
    if not decs or decs:get_size() == 0 then return nil end
    local ap = decs:get_element(0):get_field("_ActInterPack")
    local nodes = ap and ap:get_field("_Pack") and ap:get_field("_Pack"):get_field("ActInterNodeList")
    if not nodes then return nil end
    for k = 0, nodes:get_size() - 1 do
        local cmd = nodes:get_element(k):get_field("_Command"); cmd = cmd and cmd:get_field("_Process")
        if cmd and cmd:get_type_definition():get_full_name() == "app.actinter.cmd.ActNo" then return ap, cmd, k end
    end
    return ap, nil
end
-- decision pack templates: a party buff (Mage Fire Boon), a taunt aimed at an enemy (Fighter Shield Summons),
-- a big-enemy opener (Warrior War Cry) and a melee normal attack (Warrior)
local TEMPLATE = {
    [97] = "AppSystem/AI/Decision/Pack/Job03_FireBoon.user",
    [95] = "AppSystem/AI/Decision/Pack/Job01_ShieldSummons_EMTarget.user",
    [99] = "AppSystem/AI/Decision/Pack/Job05_WarCry_EMTarget.user",
    [92] = "AppSystem/AI/Decision/Pack/Job04_SmokeScreen.user",
    summon = "AppSystem/AI/Decision/Pack/Job05_NormalAttack_01.user",
}
local TEMPLATE_SKILL = { [97] = 29, [95] = 6, [99] = 56, [92] = 45 } -- skill id each template was written for

-- ---------------------------------------------------------------------------------------------------------
-- object access
local function main_pawn()
    local pm = sdk.get_managed_singleton("app.PawnManager")
    return pm and pm:get_field("_MainPawn")
end
local function ctx()
    local pawn = main_pawn()
    if not pawn then return nil, "no main pawn" end
    local chara = pawn:get_field("<CachedCharacter>k__BackingField")
    local human = pawn:get_field("<CachedHuman>k__BackingField")
    if not chara or not human then return nil, "pawn has no cached character/human" end
    return { pawn = pawn, chara = chara, human = human,
             jobctx = human:get_field("<JobContext>k__BackingField"),
             skillctx = human:get_field("<SkillContext>k__BackingField"),
             abilityctx = human:get_field("<AbilityContext>k__BackingField"),
             selector = human:get_field("<HumanActionSelector>k__BackingField"),
             job09 = human:get_field("<Job09ActionCtrl>k__BackingField"),
             dm = pawn:get_field("CachedAIDecisionMaker"),
             goal = pawn:get_field("<CachedAIGoalPlanning>k__BackingField") }
end
-- current maximum HP of a character (app.Character: get_ReducedMaxHp is the loss-gauge maximum, get_OriginalMaxHp the
-- full one; there is no get_MaxHp, run 20)
local function max_hp(chara)
    local ok, v = pcall(function() return chara:call("get_ReducedMaxHp") end)
    if ok and v and v > 0 then return v end
    ok, v = pcall(function() return chara:call("get_OriginalMaxHp") end)
    return (ok and v) or 0
end
local function player_component()
    local cm = sdk.get_managed_singleton("app.CharacterManager")
    local pl = cm and cm:call("get_ManualPlayer")
    return pl and pl:call("get_Player"), pl
end
local function managed_string(s)
    local str = sdk.create_managed_string(s)
    PT.keep(str)
    return str
end
-- REFramework arrays: objects are assigned with arr[i] = obj; 4-byte enum elements live inline from +0x20
-- (checked live 2026-11-08: write_dword(0x20 + 4*i) reads back through get_element(i).value__).
local function enum_array(typename, values)
    local arr = sdk.create_managed_array(typename, #values)
    if not arr then return nil end
    PT.keep(arr)
    for i, v in ipairs(values) do arr:write_dword(0x20 + 4 * (i - 1), v) end
    return arr
end
local function obj_array(typename, objs)
    local arr = sdk.create_managed_array(typename, #objs)
    if not arr then return nil end
    PT.keep(arr)
    for i, o in ipairs(objs) do arr[i - 1] = o end
    return arr
end

-- ---------------------------------------------------------------------------------------------------------
-- 1. job
local function step_job(c)
    local before = c.jobctx:get_field("CurrentJob")
    PT.state.prev_job = PT.state.prev_job or before
    if before == JOB09 then log("job: already Job09"); return true end
    c.jobctx:call("setJobQualified", JOB09)
    local changer = c.human:get_field("<JobChanger>k__BackingField")
    if not changer then log("job: no HumanJobChanger"); return false end
    local ok, err = pcall(function() changer:call("requestChangeJob", JOB09) end)
    log("job: requestChangeJob(9)", ok, err or "", "qualified bits", c.jobctx:get_field("QualifiedJobBits"))
    return ok
end

-- 2. censer. Run 1 showed: ItemManager.getItem(id, 1, pawnChara) puts the item into the shared inventory under the
-- Arisen's CharacterID (2891076981), and equipping that StorageData on the pawn only took the bow off. So the item is
-- handed to the pawn first (passItem), then the pawn-owned StorageData is equipped.
local function find_storage(im, item_id, chara)
    local sd = im:call("getStorageData(System.Int32, app.Character)", item_id, chara)
    if sd and sd:get_field("_ItemId") == item_id then return sd end
    return nil
end
-- ---------------------------------------------------------------------------------------------------------
-- memory (v46). The save keeps the pawn's job, Job09 skill slots and unlocks (run 24) but NOT the censer: every load
-- reads the old Main weapon (the staff, 1500) back. reframework/data/PawnTrickster/pawns.json keeps, per pawn
-- CharacterID: the censer last held, the Job09 weapon-skill slots, skill levels, core skills and augments. At enable
-- the game's own data wins; pawns.json only fills what the game lost (censer always; skills/augments when empty).
local DB_PATH = DATA_DIR .. "/pawns.json"
local TRICKSTER_SKILLS = { 92, 93, 94, 95, 96, 97, 98, 99, 118, 119, 120 }
local TRICKSTER_NORMAL = { 34, 35, 36, 37, 38, 45, 56 } -- core skills in the game's Job09 table (38 Levitate, 45 / 56 rank 6)
local CENSER_FALLBACK = { 2103, 2104, 2105 } -- wp10_000..002 (item _Job 512), read live 2026-11-08
local db = {}
do local ok, t = pcall(json.load_file, DB_PATH); if ok and type(t) == "table" then db = t end end
local function db_save() local ok = pcall(json.dump_file, DB_PATH, db); if not ok then log("memory: could not write", DB_PATH) end end
local function pawn_key(c) local ok, id = pcall(function() return c.chara:call("get_CharaID") end); return (ok and id) and tostring(id) or nil end
local function db_rec(c) local k = pawn_key(c); if not k then return nil end; db[k] = db[k] or {}; return db[k] end
local function count_of(o)
    if not o then return 0 end
    local ok, n = pcall(function() return o:call("get_Count") end); if ok and type(n) == "number" then return n end
    ok, n = pcall(function() return o:get_size() end); return (ok and type(n) == "number") and n or 0
end
local function enum_val(v)
    if type(v) == "number" then return math.tointeger(v) or v end
    if v == nil then return nil end
    local ok, x = pcall(function() return v:get_field("value__") end); if ok and type(x) == "number" then return x end
    ok, x = pcall(function() return v.value__ end); return (ok and type(x) == "number") and x or nil
end
local function same_list(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
local function any_nonzero(t) for _, v in ipairs(t or {}) do if v and v ~= 0 then return true end end return false end
-- Job09 weapon-skill slots (SkillContext.EquipedSkills[9].Skills, as SkillCreator reads them)
local function read_skill_slots(c)
    local ok, out = pcall(function()
        local sk = c.skillctx:get_field("EquipedSkills")[JOB09]:get_field("Skills")
        local n = count_of(sk); if n == 0 then n = 6 end
        local t = {}
        for i = 0, n - 1 do t[#t + 1] = enum_val(sk[i]) or 0 end
        return t
    end)
    return ok and out or nil
end
-- Job09 augments (AbilityContext.EquipedAbilities[9].Abilities)
local function augment_holder(c) return c.abilityctx:get_field("EquipedAbilities")[JOB09] end
local function read_augments(c)
    local ok, out = pcall(function()
        local ab = augment_holder(c):get_field("Abilities")
        local t = {}
        for i = 0, count_of(ab) - 1 do t[#t + 1] = enum_val(ab[i]) or 0 end
        return t
    end)
    return ok and out or nil
end
local function read_levels(c)
    local t, any = {}, false
    for _, id in ipairs(TRICKSTER_SKILLS) do
        local ok, lv = pcall(function() return c.skillctx:call("getCustomSkillLevel", id) end)
        lv = ok and enum_val(lv) or 0
        if lv and lv > 0 then t[tostring(id)] = lv; any = true end
    end
    return t, any
end
-- v47p: read from HumanSkillContext.EnableNormalSkills { NormalSkillID, IsEnable }. isNormalSkillEnable(34) answered
-- false on a pawn whose entry 34 was enabled (2026-11-10), so core skills were never written to pawns.json before.
local function read_normal(c)
    local t, want = {}, {}
    for _, id in ipairs(TRICKSTER_NORMAL) do want[id] = true end
    local ok = pcall(function()
        local list = c.skillctx:get_field("EnableNormalSkills")
        for i = 0, list:call("get_Count") - 1 do
            local e = list:call("get_Item", i)
            local id = enum_val(e:get_field("NormalSkillID"))
            if want[id] and e:get_field("IsEnable") == true then t[#t + 1] = id end
        end
    end)
    if not ok then
        for _, id in ipairs(TRICKSTER_NORMAL) do
            local ok2, on = pcall(function() return c.skillctx:call("isNormalSkillEnable", id) end)
            if ok2 and on then t[#t + 1] = id end
        end
    end
    table.sort(t)
    return t
end
-- setCustomSkillEnable(id, 0) leaves a learned skill learned; the level lives in HumanSkillContext.EnabledCustomSkills
-- { CustomSkillID, Level, IsViewedNew } (one entry per skill id)
function PT.clear_skill_level(c, id)
    local done = false
    pcall(function()
        local list = c.skillctx:get_field("EnabledCustomSkills")
        for i = 0, list:call("get_Count") - 1 do
            local e = list:call("get_Item", i)
            if enum_val(e:get_field("CustomSkillID")) == id then e:set_field("Level", 0); done = true; break end
        end
    end)
    return done
end
local function set_level(c, id, lv)
    return pcall(function() c.skillctx:call("setCustomSkillEnable(app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)", id, lv) end)
end
local function set_normal(c, id)
    return pcall(function() c.skillctx:call("setNormalSkillEnable(app.HumanNormalSkillID)", id) end)
end
local function set_slot(c, id, slot) return pcall(function() c.skillctx:call("setSkill", JOB09, id, slot) end) end
local function set_augment(c, id, i) return pcall(function() augment_holder(c):call("setAbility", id, i) end) end
-- censers: weapons whose item _Job has the Job09 bit (512)
local function is_censer(im, id)
    if type(id) ~= "number" or id <= 0 then return false end
    for _, f in ipairs(CENSER_FALLBACK) do if f == id then return true end end
    local ok, r = pcall(function()
        local d = im:call("getItemData(System.Int32)", id)
        if not d or d:get_type_definition():get_full_name() ~= "app.ItemWeaponParam" then return false end
        local j = d:get_field("_Job"); j = j and (math.tointeger(j) or math.floor(j)) or 0
        return (j & 512) ~= 0
    end)
    return ok and r or false
end
local censer_list
local function censer_ids(im)
    if censer_list then return censer_list end
    local ids, seen = {}, {}
    pcall(function()
        local entries = im:get_field("_ItemDataDict"):get_field("_entries")
        for i = 0, entries:get_size() - 1 do
            local e = entries:get_element(i)
            local k = e and e:get_field("key")
            if type(k) == "number" and k > 0 and not seen[k] and is_censer(im, k) then seen[k] = true; ids[#ids + 1] = k end
        end
    end)
    for _, f in ipairs(CENSER_FALLBACK) do if not seen[f] then seen[f] = true; ids[#ids + 1] = f end end
    table.sort(ids)
    censer_list = ids
    log("memory: censer item ids", table.concat(ids, " "))
    return ids
end
local function main_item(im, c)
    local ok, id = pcall(function()
        return im:call("getEquipData(app.Character)", c.chara):get_field("Data"):get_field("Equips"):get_element(0):get_field("_ItemId")
    end)
    return ok and id or nil
end
local function pawn_owns(im, c, id)
    local sd = find_storage(im, id, c.chara)
    return sd ~= nil and sd:get_field("_CharaId") == c.chara:call("get_CharaID")
end
-- which censer to hold: the one equipped now (the game kept it) > the remembered one > the best one she owns > the
-- starter censer (created only when she owns none)
local function choose_censer(im, c)
    local cur = main_item(im, c)
    if cur and is_censer(im, cur) and pawn_owns(im, c, cur) then return cur, "equipped" end
    local rec = db_rec(c)
    if rec and rec.censer and pawn_owns(im, c, rec.censer) then return rec.censer, "remembered" end
    local best
    for _, id in ipairs(censer_ids(im)) do if pawn_owns(im, c, id) then best = id end end
    if best then return best, "owned" end
    return cfg.censer_item_id, "starter"
end
local function step_weapon(c, force_id)
    local im = sdk.get_managed_singleton("app.ItemManager")
    if not im then log("weapon: no ItemManager"); return false end
    local cid = c.chara:call("get_CharaID")
    local want, why = force_id, "chosen"
    if not want then want, why = choose_censer(im, c) end
    log("weapon: censer", want, "(" .. why .. ")")
    local sd = find_storage(im, want, c.chara)
    if not sd or sd:get_field("_CharaId") ~= cid then
        local got
        local ok, err = pcall(function()
            got = im:call("getItem(System.Int32, System.Int32, app.Character)", want, 1, c.chara)
        end)
        log("weapon: getItem", want, ok, err or "", "owner", got and got:get_field("_CharaId"), "equipped", got and got:get_field("_IsEquipped"))
        if got and got:get_field("_ItemId") == want and got:get_field("_CharaId") ~= cid then
            local okp, errp = pcall(function() im:call("passItem(app.ItemDefine.StorageData, System.Int32, app.Character, System.Boolean)", got, 1, c.chara, false) end)
            log("weapon: passItem to pawn", okp, errp or "")
        end
        sd = find_storage(im, want, c.chara)
    end
    if not sd then log("weapon: censer not found for pawn"); return false end
    log("weapon: pawn storage data owner", sd:get_field("_CharaId"), "pawn cid", cid, "storageId", sd:get_field("_StorageId"), "equipped", sd:get_field("_IsEquipped"))
    -- Run 2/3: the game's equip queue (addEquipChangeInfo + applyEquipChange) only takes the old weapon off for a pawn.
    -- Writing the Main slot of the pawn's EquipData and rebuilding the weapons does equip it (getWeaponJob() = 9).
    -- v48b: that write left the game's own bookkeeping behind: the equipment menu showed the "equipped" badge on the
    -- weapon she held before (the staff) and none on the censer, and the save did not keep the censer. The game's
    -- ItemManager.setEquip does both sides (seen 2026-11-10: the censer equipped through the equipment menu, or by
    -- this call, has the badge, the old weapon loses it, and the next load reads the censer back as equipped). It
    -- is tried first; the slot write stays as the fallback.
    local how = "setEquip"
    local ok, err = pcall(function()
        local ed = im:call("getEquipData(app.Character)", c.chara)
        local equips = ed:get_field("Data"):get_field("Equips")
        PT.state.prev_main_item = PT.state.prev_main_item or PT.prev_main_item or equips:get_element(0):get_field("_ItemId")
        if not is_censer(im, PT.state.prev_main_item) then PT.prev_main_item = PT.state.prev_main_item end
        local done = false
        if cfg.equip_by_game ~= false then
            local oke = pcall(function()
                im:call("setEquip(app.ItemDefine.StorageData, app.Character, app.EquipData.SlotEnum, System.Boolean, System.Boolean)", sd, c.chara, 0, false, false)
            end)
            done = oke and main_item(im, c) == want
        end
        if not done then
            how = "slot write"
            equips[0] = sd
            sd:set_field("_IsEquipped", true)
            sd:set_field("_EquipSlot", 0)
        end
        im:call("applyEquipDataForCharacter(app.Character)", c.chara)
    end)
    log("weapon: equip censer into Main slot (" .. how .. ")", ok, err or "", "previous item", PT.state.prev_main_item)
    return ok
end

-- 3. action selector
local function find_selector(c, typename)
    local list = c.selector:get_field("Selectors")
    if not list then return nil end
    for i = 0, list:call("get_Count") - 1 do
        local s = list:call("get_Item", i)
        if s and s:get_type_definition():get_full_name() == typename then return s end
    end
end
local function step_selector(c)
    if cfg.job09_selector ~= true then log("selector: no Job09ActionSelector added (job09_selector is off)"); return nil end
    local sel = find_selector(c, "app.Job09ActionSelector")
    if sel then log("selector: Job09ActionSelector already present"); return sel end
    -- the game's own path first
    pcall(function() c.selector:call("addJobSelector", c.chara) end)
    sel = find_selector(c, "app.Job09ActionSelector")
    if sel then PT.state.selector_added = true; log("selector: added by addJobSelector(chara)"); return sel end
    -- otherwise build one the way setupSelectors does
    local ok, err = pcall(function()
        sel = PT.keep(sdk.create_instance("app.Job09ActionSelector"))
        sel:call("setup", c.selector:get_field("Param"))
        c.selector:get_field("Selectors"):call("Insert", 0, sel) -- before NoJobActionSelector and the Job01..06 ones
    end)
    if ok then PT.state.selector_added = true end
    log("selector: created Job09ActionSelector", ok, err or "")
    pcall(function() c.selector:call("updateCurrentSelector") end)
    return ok and sel or nil
end

-- 4. decoy handler. Run 2: the pawn's handler exists but its Prefab is nil (the Arisen's comes from app.Player.DecoyPrefab);
-- building a fresh holder with setup(via.Prefab) crashed the game on the next summon (AV at DD2.exe+0x524a361), so the
-- player's own PrefabController object is shared instead.
local function player_decoy_prefab_controller()
    local _, pl = player_component()
    local human = pl and pl:call("get_Human")
    local hs = human and human:get_field("<HumanActionSelector>k__BackingField")
    local list = hs and hs:get_field("Selectors")
    if not list then return nil end
    for i = 0, list:call("get_Count") - 1 do
        local s = list:call("get_Item", i)
        if s and s:get_type_definition():get_full_name() == "app.Job09ActionSelector" then
            local dh = s:call("get_DecoyHandler")
            return dh and dh:get_field("<Prefab>k__BackingField")
        end
    end
end
local function player_decoy_handler()
    local _, pl = player_component()
    local human = pl and pl:call("get_Human")
    local hs = human and human:get_field("<HumanActionSelector>k__BackingField")
    local list = hs and hs:get_field("Selectors")
    if not list then return nil end
    for i = 0, list:call("get_Count") - 1 do
        local s = list:call("get_Item", i)
        if s and s:get_type_definition():get_full_name() == "app.Job09ActionSelector" then return s:call("get_DecoyHandler"), human end
    end
end
local function step_decoy(c)
    if not c.job09 then log("decoy: no Job09ActionController on pawn"); return false end
    -- v31: share the ARISEN's DecoyHandler itself (not only its prefab) unless the Arisen is a Trickster: the enemy hate
    -- code (HateSensor.updateDecoyHate / EnemySmokeDecoyUtil.getDecoyObject) only looks at the player's decoy, so a decoy
    -- summoned through the player's handler is the one enemies actually go for (run 41). Restored by disable().
    if cfg.share_player_decoy ~= false then
        local pdh, phuman = player_decoy_handler()
        local pjob = phuman and phuman:get_field("<JobContext>k__BackingField") and phuman:get_field("<JobContext>k__BackingField"):get_field("CurrentJob")
        local mine = c.job09:call("get_DecoyHandler")
        if pdh and pjob ~= JOB09 and (not mine or mine:get_address() ~= pdh:get_address()) then
            PT.state.own_decoy_handler = PT.state.own_decoy_handler or mine
            local ok, err = pcall(function() c.job09:call("set_DecoyHandler", pdh) end)
            log("decoy: pawn uses the Arisen's DecoyHandler (enemies only target the player's decoy)", ok, err or "")
        elseif pjob == JOB09 then log("decoy: the Arisen is a Trickster, keeping the pawn's own handler") end
    end
    local dh = c.job09:call("get_DecoyHandler")
    if dh then
        local prefab = dh:get_field("<Prefab>k__BackingField")
        if not prefab then
            local pctrl = player_decoy_prefab_controller()
            if pctrl then
                local ok, err = pcall(function() dh:call("set_Prefab", pctrl) end)
                log("decoy: shared the Arisen's PrefabController", ok, err or "")
            else log("decoy: no player PrefabController to share") end
        end
        if not dh:get_field("<Owner>k__BackingField") then pcall(function() dh:call("set_Owner", c.human) end) end
        log("decoy: handler present, prefab", tostring(dh:get_field("<Prefab>k__BackingField")), "has instance", dh:call("get_HasInstance"))
        return true
    end
    local okp, errp = pcall(function() c.job09:call("prepareDecoyAndAstralBody") end)
    dh = c.job09:call("get_DecoyHandler")
    log("decoy: prepareDecoyAndAstralBody", okp, errp or "", "handler now", tostring(dh))
    if dh then return true end
    local plcomp = player_component()
    local prefab = plcomp and plcomp:get_field("DecoyPrefab")
    if not prefab then log("decoy: player DecoyPrefab not found"); return false end
    local ok, err = pcall(function()
        dh = PT.keep(sdk.create_instance("app.DecoyHandler"))
        dh:call("setup(app.Human, via.Prefab)", c.human, prefab)
        c.job09:call("set_DecoyHandler", dh)
    end)
    log("decoy: built DecoyHandler from player's prefab", ok, err or "")
    return ok
end

-- 5. hooks: the pawn helpers return "" for Job09
local hooked = false
local job_arg = {}
-- `name_for_job9` is a string or a function returning the action name for this call (the heavy-attack name is
-- multiplexed: whatever Trickster action the currently selected decision stands for)
local mstrings = {}
local function mstring(name)
    if not mstrings[name] then mstrings[name] = managed_string(name) end
    return mstrings[name]
end
-- slot -> Job09 action, decided when the heavy-attack command asks for its action name:
--   summon: no decoy -> SummonDecoy; decoy far from the pawn -> Transfer (beckon); else Sweeping Shroud (taunt)
--   beckon: decoy -> Transfer; none -> SummonDecoy
--   shroud/rally/delusion/screen: their skill casts, except that with no decoy out they summon first
--   attack: the censer swing
local function heavy_name()
    local st = PT.state
    local slot = st.current_decision
    local has = st.has_decoy
    if slot == "attack" then return ACT.normal end
    if slot == "summon" then
        if not has then return ACT.heavy end
        if st.decoy_far then return ACT.transfer end
        return SKILL_ACTION[95]
    end
    if slot == "beckon" then return has and ACT.transfer or ACT.heavy end
    if slot == "shroud" or slot == "delusion" or slot == "screen" then return has and st.current_action or ACT.heavy end
    if slot == "rally" then return st.current_action end
    return ACT.heavy
end
local function hook_job_string(typename, method_name, name_for_job9, is_static)
    local td = sdk.find_type_definition(typename)
    local m = td and td:get_method(method_name)
    if not m then log("hook: method not found", typename, method_name); return end
    hook(m, function(args)
        -- static: args[2] is the first parameter; instance: args[3]
        local a = is_static and args[2] or args[3]
        job_arg[method_name] = a and (sdk.to_int64(a) & 0xff) or -1
    end, function(retval)
        if PT.enabled and job_arg[method_name] == JOB09 then
            local name = type(name_for_job9) == "function" and name_for_job9() or name_for_job9
            local str = mstring(name)
            if str then PT.state.hook_hits = (PT.state.hook_hits or 0) + 1; PT.state.last_hook = method_name .. "=" .. name; return sdk.to_ptr(str) end
        end
        return retval
    end)
    log("hook: installed", typename .. "." .. method_name)
end
local function hook_job_hash(typename, method_name, name_for_job9, is_static)
    local td = sdk.find_type_definition(typename)
    local m = td and td:get_method(method_name)
    if not m then log("hook: method not found", typename, method_name); return end
    hook(m, function(args)
        local a = is_static and args[2] or args[3]
        job_arg[method_name] = a and (sdk.to_int64(a) & 0xff) or -1
    end, function(retval)
        if PT.enabled and job_arg[method_name] == JOB09 then
            local name = type(name_for_job9) == "function" and name_for_job9() or name_for_job9
            PT.state.hook_hits = (PT.state.hook_hits or 0) + 1; PT.state.last_hook = method_name .. "=" .. name
            return sdk.to_ptr(ACT_HASH[name])
        end
        return retval
    end)
    log("hook: installed", typename .. "." .. method_name)
end
local function step_hooks()
    if hooked then return true end
    -- run 11: these hooks were never hit for job 9 in any run (job.NormalAttack/HeavyAttack do not resolve through
    -- PawnUtil), and the run-11 crash stack went through a hook trampoline inside the AI think update. Off by default.
    if not cfg.hooks then log("hooks: disabled (cfg.hooks)"); return true end
    hooked = true
    for _, n in pairs(ACT) do mstring(n); local _ = ACT_HASH[n] end
    for _, n in pairs(SKILL_ACTION) do mstring(n); local _ = ACT_HASH[n] end
    hook_job_string("app.PawnUtil", "getJobNormalAttackAction", ACT.normal, true)
    hook_job_string("app.PawnUtil", "getJobHeavyAttackAction", heavy_name, true)
    hook_job_hash("app.PawnUtil", "getJobNormalAttackActionHash", ACT.normal, true)
    hook_job_hash("app.PawnUtil", "getJobHeavyAttackActionHash", heavy_name, true)
    hook_job_string("app.PawnSkillActionController", "getCommonAction", ACT.normal, false)
    hook_job_hash("app.PawnSkillActionController", "getCommonActionHash", ACT.normal, false)
    return true
end

-- 6. skills and AI data
local rank1_skills -- defined below (needs dict helpers)
local function step_skills(c)
    local sc = c.skillctx
    if not sc then log("skills: no SkillContext"); return false end
    if cfg.debug then
        -- debug: force the test set at level 1 (free unlock) every load
        for i, id in ipairs(cfg.skills) do
            set_level(c, id, 1)
            local ok, err = pcall(function() sc:call("setSkill", JOB09, id, i - 1) end)
            log("skills (debug): equip", id, "slot", i - 1, ok, err or "")
        end
        return true
    end
    -- release: the game's data wins; pawns.json refills only what is empty; a brand-new Trickster pawn gets the
    -- vanilla rank-1 skills once
    local rec = db_rec(c) or {}
    if rec.starter_done and not rec.cut_fix then
        -- 0.1.0 / 0.2.0 gave a new pawn the cut skills 118 / 119: take them out of her slots and levels, once
        local sl = read_skill_slots(c); local removed = {}
        for i, id in ipairs(sl or {}) do
            if id == 118 or id == 119 or id == 120 then set_slot(c, 0, i - 1) end
        end
        local had = read_levels(c)
        for _, id in ipairs({ 118, 119, 120 }) do
            if had[tostring(id)] then PT.clear_skill_level(c, id); removed[#removed + 1] = id end
        end
        if type(rec.levels) == "table" then rec.levels["118"] = nil; rec.levels["119"] = nil; rec.levels["120"] = nil end
        if type(rec.slots) == "table" then for i, id in ipairs(rec.slots) do if id == 118 or id == 119 or id == 120 then rec.slots[i] = 0 end end end
        rec.cut_fix = true
        local k = pawn_key(c); if k then db[k] = rec; db_save() end
        if #removed > 0 then log("skills: cut skills removed from her slots (given by an older version):", table.concat(removed, " ")) end
    end
    local levels, any_level = read_levels(c)
    if not any_level and type(rec.levels) == "table" and next(rec.levels) then
        for k, lv in pairs(rec.levels) do local id = tonumber(k); if id and lv and lv > 0 then set_level(c, id, lv) end end
        log("memory: skill levels restored from pawns.json")
        levels, any_level = read_levels(c)
    end
    if #read_normal(c) == 0 and type(rec.normal) == "table" and #rec.normal > 0 then
        for _, id in ipairs(rec.normal) do set_normal(c, id) end
        log("memory: core skills restored", table.concat(rec.normal, " "))
    end
    local slots = read_skill_slots(c)
    if slots and not any_nonzero(slots) and any_nonzero(rec.slots) then
        for i, id in ipairs(rec.slots) do if id and id ~= 0 then set_slot(c, id, i - 1) end end
        log("memory: weapon-skill slots restored", table.concat(rec.slots, " "))
        slots = read_skill_slots(c)
    end
    local aug = read_augments(c)
    if aug and not any_nonzero(aug) and any_nonzero(rec.augments) then
        for i, id in ipairs(rec.augments) do if id and id ~= 0 then set_augment(c, id, i - 1) end end
        log("memory: augments restored", table.concat(rec.augments, " "))
    end
    if not any_level and not rec.starter_done then
        local g_custom, g_normal = rank1_skills()
        local starters = (g_custom and #g_custom > 0) and g_custom or (cfg.starter_skills or {})
        local starters_n = (g_normal and #g_normal > 0) and g_normal or (cfg.starter_normal_skills or {})
        log("skills: rank-1 table", g_custom and "game" or "config", table.concat(starters, " "), "core", g_normal and "game" or "config", table.concat(starters_n, " "))
        local free = 0
        for _, id in ipairs(starters) do
            set_level(c, id, 1)
            -- first empty weapon-skill slot (4 slots)
            while slots and free < 4 and (slots[free + 1] or 0) ~= 0 do free = free + 1 end
            if free < 4 then set_slot(c, id, free); if slots then slots[free + 1] = id end; free = free + 1 end
        end
        for _, id in ipairs(starters_n) do set_normal(c, id) end
        rec.starter_done = true; rec.cut_fix = true
        local k = pawn_key(c); if k then db[k] = rec; db_save() end
        log("skills: new Trickster pawn, rank-1 skills", table.concat(starters, " "), "core", table.concat(starters_n, " "))
    end
    log("skills: slots", table.concat(read_skill_slots(c) or { "?" }, " "))
    return true
end
-- the rank-1 Trickster skills from the game's own tables (GuiManager.CustomSkillJobDefineDictionary[Job09] ->
-- {skill id -> {level -> info._UnlockRank}}, NormalSkillDefineDictionary["Job09"] -> {id -> info._UnlockRank}; the same
-- fields SkillCreator edits). Returns nil, nil when a table cannot be read; the caller then uses cfg.starter_*.
local function dict_entries(d)
    local out = {}
    local e = d and d:get_field("_entries")
    if not e then return out end
    for i = 0, e:get_size() - 1 do
        local it = e:get_element(i)
        local k, v = it and it:get_field("key"), it and it:get_field("value")
        if k ~= nil and v ~= nil then out[#out + 1] = { key = enum_val(k) or k, value = v } end
    end
    return out
end
rank1_skills = function()
    local gm = sdk.get_managed_singleton("app.GuiManager")
    if not gm then return nil, nil end
    local custom, normal
    pcall(function()
        local jd = gm:get_field("CustomSkillJobDefineDictionary"):call("get_Item", JOB09)
        local t = {}
        for _, sk in ipairs(dict_entries(jd)) do
            if type(sk.key) == "number" and sk.key ~= 0 then
                for _, lv in ipairs(dict_entries(sk.value)) do
                    local r = lv.value:get_field("_UnlockRank")
                    -- v47p: 118 and 119 (cut skills, _UnlockRank 0, _OpenByGm true) passed the rank test and a
                    -- brand-new pawn started with Sweeping Shroud plus those two
                    if enum_val(lv.key) == 1 and type(r) == "number" and r <= 1 and lv.value:get_field("_OpenByGm") ~= true then t[#t + 1] = sk.key end
                end
            end
        end
        table.sort(t); custom = t
    end)
    pcall(function()
        local nd = gm:get_field("NormalSkillDefineDictionary"):call("get_Item", sdk.create_managed_string("Job09"))
        local t = {}
        for _, sk in ipairs(dict_entries(nd)) do
            local r = sk.value:get_field("_UnlockRank")
            if type(sk.key) == "number" and sk.key ~= 0 and type(r) == "number" and r <= 1 then t[#t + 1] = sk.key end
        end
        table.sort(t); normal = t
    end)
    return custom, normal
end
-- equipped Job09 weapon skills (PT.state.equipped[id] = true); nil when the slots could not be read (the AI then
-- falls back to the pre-v46 behaviour, all skill slots allowed)
local function refresh_equipped(c)
    local slots = read_skill_slots(c)
    if not slots then
        if not PT.state.equipped_warned then PT.state.equipped_warned = true; log("skills: could not read the Job09 slots; skill gates off") end
        PT.state.equipped = nil; return nil
    end
    local e = {}
    for _, id in ipairs(slots) do if id and id ~= 0 then e[id] = true end end
    PT.state.equipped = e
    return slots
end
local function has_skill(id)
    local e = PT.state.equipped
    if not e then return true end
    return e[id] == true
end
-- record the pawn's current Trickster setup in pawns.json (every 3 s once settled; empty reads never erase a record)
local function remember_tick()
    if not PT.enabled or PT.state.pending then return end
    local c = PT.state.ctx; if not c then return end
    if not PT.state.ready_t or os.clock() - PT.state.ready_t < 5.0 then return end
    if os.clock() < (PT.state.remember_next or 0) then return end
    PT.state.remember_next = os.clock() + 3.0
    local slots = refresh_equipped(c)
    if cfg.remember == false then return end
    if cfg.debug then return end -- debug forces a test set every load: never record it as the pawn's own setup
    if c.jobctx:get_field("CurrentJob") ~= JOB09 then return end
    local k = pawn_key(c); if not k then return end
    local rec = db[k] or {}
    local changed = {}
    local im = sdk.get_managed_singleton("app.ItemManager")
    local cur = im and main_item(im, c)
    if cur and is_censer(im, cur) and rec.censer ~= cur then rec.censer = cur; changed[#changed + 1] = "censer " .. tostring(cur) end
    if slots and any_nonzero(slots) and not same_list(slots, rec.slots) then rec.slots = slots; changed[#changed + 1] = "slots" end
    local aug = read_augments(c)
    if aug and any_nonzero(aug) and not same_list(aug, rec.augments) then rec.augments = aug; changed[#changed + 1] = "augments" end
    local levels, any_level = read_levels(c)
    if any_level then
        local diff = type(rec.levels) ~= "table"
        if not diff then
            for kk, v in pairs(levels) do if rec.levels[kk] ~= v then diff = true end end
            for kk, v in pairs(rec.levels) do if levels[kk] ~= v then diff = true end end
        end
        if diff then rec.levels = levels; changed[#changed + 1] = "levels" end
    end
    local normal = read_normal(c)
    if #normal > 0 and not same_list(normal, rec.normal) then rec.normal = normal; changed[#changed + 1] = "core" end
    if #changed > 0 then
        rec.updated = os.date("%Y-%m-%d %H:%M:%S")
        db[k] = rec; db_save()
        log("memory: recorded", table.concat(changed, ", "))
    end
end
PT.remembered = function() local c = PT.state.ctx or ctx(); return c and db[pawn_key(c) or ""] end

-- an ActInterPackData whose single node runs ActNo(action_name)
local function build_actno_pack(action_name, aim)
    local data = PT.keep(sdk.create_instance("app.ActInterPackData"))
    local pack = PT.keep(sdk.create_instance("app.ActInterPack"))
    local node = PT.keep(sdk.create_instance("app.ActInterNode"))
    local cmdsel = PT.keep(sdk.create_instance("app.ClassSelector`1<app.actinter.cmd.CommandBase>"))
    local actno = PT.keep(sdk.create_instance("app.actinter.cmd.ActNo"))
    actno:set_field("ActionID", managed_string(action_name))
    -- run 10: with CancelSequenceFlags 0 the picked ActNo never requested its action; with all cancel bits set (and the
    -- motion check off) the pawn played Job09_SummonDecoy / Cast* / ShortSmokeAttack on its own
    actno:set_field("CancelSequenceFlags", 0xffffffff)
    actno:set_field("IgnoreMotionCheck", true)
    actno:set_field("IsUpdateAimTarget", aim == true) -- v47: Latching Effigy only latches with the aim target updated
    cmdsel:set_field("_Process", actno)
    node:set_field("_Command", cmdsel)
    node:set_field("_PrimaryTarget", PT.keep(sdk.create_instance("app.actinter.ActionTarget")))
    node:set_field("_UseSubCommand", false)
    local subsel = PT.keep(sdk.create_instance("app.ClassSelector`1<app.actinter.cmd.CommandBase>"))
    subsel:set_field("_Process", PT.keep(sdk.create_instance("app.actinter.cmd.CarryEnd")))
    node:set_field("_SubCommand", subsel)
    node:set_field("_SecondaryTarget", PT.keep(sdk.create_instance("app.actinter.ActionTarget")))
    node:set_field("_Decorators", PT.keep(sdk.create_managed_array("app.ClassSelector`1<app.actinter.Decorator>", 0))) -- v47: add_ref (it was freed under the node before)
    pack:set_field("ActInterNodeList", obj_array("app.ActInterNode", { node }))
    data:set_field("_Pack", pack)
    return data
end

-- walk every ClassSelector condition of a Decision and retarget skill ids
local function retarget_conditions(dec, old_id, new_id)
    for _, fname in ipairs({ "_Preconditions", "_TargetPreconditions", "_TargetConditions" }) do
        local arr = dec:get_field(fname)
        if arr then
            for i = 0, arr:get_size() - 1 do
                local p = arr:get_element(i)
                p = p and p:get_field("_Process")
                if p then
                    local td = p:get_type_definition()
                    local f = td:get_field("_SkillID")
                    if f and p:get_field("_SkillID") == old_id then p:set_field("_SkillID", new_id) end
                end
            end
        end
    end
end

-- sdk.create_userdata returns the game's SHARED instance of a .user file (run 3 showed the vanilla Job05_NormalAttack_01
-- carrying our ActNo pack afterwards). Templates are therefore copied field by field into fresh objects before editing.
local function shallow_copy(obj)
    local td = obj:get_type_definition()
    local copy = PT.keep(sdk.create_instance(td:get_full_name()))
    local cur = td
    while cur and cur:get_full_name() ~= "System.Object" do
        for _, f in ipairs(cur:get_fields()) do
            if not f:is_static() then
                local n = f:get_name()
                local ok, v = pcall(function() return obj:get_field(n) end)
                if ok and v ~= nil then pcall(function() copy:set_field(n, v) end) end
            end
        end
        cur = cur:get_parent_type()
    end
    return copy
end
local function clone_pack(path)
    local src = sdk.create_userdata("app.DecisionPack", path)
    if not src then return nil end
    local pack = PT.keep(sdk.create_instance("app.DecisionPack"))
    pack:set_field("_Stage", src:get_field("_Stage"))
    local sdecs = src:get_field("_Decisions")
    local copies = {}
    for i = 0, sdecs:get_size() - 1 do copies[#copies + 1] = shallow_copy(sdecs:get_element(i)) end
    pack:set_field("_Decisions", obj_array("app.DecisionPack.Decision", copies))
    return pack
end

-- v2 decision set (after the run-4 fight): every Trickster decision is a copy of the first decision of
-- Job05_NormalAttack_01 (its State / BattleMode preconditions and target preconditions are the common "can act in
-- battle" set), with our own command pack, a flat FixedValue evaluator (the pawn's PawnCommonEvaluate curve reads a
-- per-job attack-range table that Job09 has no entry in, so Warrior-scored decisions never fired), no start/end
-- processes (they set Warrior attack ranges and speak Warrior lines), our cooldown, rank and skill ids. Lua gates
-- toggle _Enabled per frame (decoy out? decoy far? low HP?).
local BASE_TEMPLATE = "AppSystem/AI/Decision/Pack/Job05_NormalAttack_01.user"
local SEL_TYPES = { _Preconditions = "app.ClassSelector`1<app.decision.condition.ConditionBase>",
                    _TargetPreconditions = "app.ClassSelector`1<app.decision.tcondition.ConditionBase>",
                    _TargetConditions = "app.ClassSelector`1<app.decision.tcondition.ConditionBase>" }
local function fixed_eval(value, weight)
    local fv = PT.keep(sdk.create_instance("app.decision.evaluation.FixedValue")); fv:set_field("_Value", value)
    local sel = PT.keep(sdk.create_instance("app.ClassSelector`1<app.decision.evaluation.EvaluationCriteria>")); sel:set_field("_Process", fv)
    local ecd = PT.keep(sdk.create_instance("app.decision.evaluation.EvaluationCriteriaData")); ecd:set_field("_Weight", weight); ecd:set_field("_Criteria", sel)
    return obj_array("app.decision.evaluation.EvaluationCriteriaData", { ecd })
end
local V = {} -- v47 extras (functions hang on one table: the chunk is close to Lua's 200 local limit)
local guid_seed = 0x5a7c0000
local function make_decision(opts)
    local src = sdk.create_userdata("app.DecisionPack", BASE_TEMPLATE)
    if not src then log("make_decision: template missing"); return nil end
    local sdec = src:get_field("_Decisions"):get_element(0)
    local d = shallow_copy(sdec)
    for fname, elem in pairs(SEL_TYPES) do
        local arr = sdec:get_field(fname)
        if arr then
            local items = {}
            for k = 0, arr:get_size() - 1 do
                -- v48e: the Warrior attack's "target not immune to my weapon" and "target point 0-2 m high" checks
                -- mean nothing for a cast and made every phantom an invalid target (no pick in a whole fight); its
                -- BattleMode precondition is false while her AI state is "Danger" (all three fnames go through here)
                local proc0 = arr:get_element(k):get_field("_Process")
                local tn = proc0 and proc0:get_type_definition():get_name()
                if tn and V.rule_drop and V.rule_drop[tn] then
                    V.rule_dropped[tn] = (V.rule_dropped[tn] or 0) + 1
                else
                    local sel = shallow_copy(arr:get_element(k))
                    local proc = sel:get_field("_Process")
                    if proc then sel:set_field("_Process", shallow_copy(proc)) end
                    items[#items + 1] = sel
                end
            end
            if fname == "_TargetPreconditions" and opts.target_range then
                -- v48g: only targets in a distance band (via.Range = start, width): the rule's target is what the cast is
                -- aimed at, and Latching Effigy only latched on targets about 8-10 m away
                local dr = PT.keep(sdk.create_instance("app.decision.tcondition.DistanceRange"))
                local f = dr:get_type_definition():get_field("_Range"); local off = f and f:get_offset_from_base()
                if off then
                    dr:write_float(off, opts.target_range[1]); dr:write_float(off + 4, opts.target_range[2])
                    dr:set_field("_IsXZPlane", true); dr:set_field("_Not", false); dr:set_field("_IsEnable", true)
                    local sel = PT.keep(sdk.create_instance(elem)); sel:set_field("_Process", dr)
                    items[#items + 1] = sel
                    V.rule_added = (V.rule_added and (V.rule_added .. "; ") or "") .. string.format("DistanceRange %.1f..%.1f m on %s", opts.target_range[1], opts.target_range[1] + opts.target_range[2], tostring(opts.name))
                end
            end
            if fname == "_TargetPreconditions" and (opts.target_angle or opts.target_rise) then
                -- v48h: the game's own target conditions. AngleTargetDiff is what the vanilla "look at" rule uses (angle
                -- between her facing and the target; CompareType Le = 3): the rule's target is then an enemy she faces.
                -- Composite(Any) of ScaleType (Medium | Large | BigLarge = 14) and HeightDifference: a Small target only
                -- when it stands higher than her (the incense flew over level goblins: 2 latches in 13 aimed casts).
                local function tsel(proc) local sel = PT.keep(sdk.create_instance(elem)); sel:set_field("_Process", proc); return sel end
                if opts.target_angle then
                    local a = PT.keep(sdk.create_instance("app.decision.tcondition.AngleTargetDiff"))
                    a:set_field("_AngleDeg", opts.target_angle); a:set_field("_Compare", 3); a:set_field("_Not", false); a:set_field("_IsEnable", true)
                    items[#items + 1] = tsel(a)
                    V.rule_added = (V.rule_added and (V.rule_added .. ", ") or "") .. string.format("AngleTargetDiff <= %.0f", opts.target_angle)
                end
                if opts.target_rise then
                    local sc = PT.keep(sdk.create_instance("app.decision.tcondition.ScaleType"))
                    sc:set_field("_Type", 14); sc:set_field("_Not", false); sc:set_field("_IsEnable", true)
                    local hd = PT.keep(sdk.create_instance("app.decision.tcondition.HeightDifference"))
                    local f = hd:get_type_definition():get_field("_Range"); local off = f and f:get_offset_from_base()
                    if off then
                        hd:write_float(off, opts.target_rise); hd:write_float(off + 4, 8.0)
                        hd:set_field("_Not", false); hd:set_field("_IsEnable", true)
                        local comp = PT.keep(sdk.create_instance("app.decision.tcondition.Composite"))
                        comp:set_field("_Attain", 1); comp:set_field("_Conditions", obj_array(elem, { tsel(sc), tsel(hd) })); comp:set_field("_IsEnable", true)
                        items[#items + 1] = tsel(comp)
                        V.rule_added = (V.rule_added and (V.rule_added .. ", ") or "") .. string.format("not Small or %.1f m higher", opts.target_rise)
                    end
                end
            end
            d:set_field(fname, obj_array(elem, items))
        end
    end
    d:set_field("_ActInterPack", opts.pack or build_actno_pack(opts.action))
    d:set_field("_StartProcess", obj_array("app.ClassSelector`1<app.decision.process.ProcessBase>", {}))
    d:set_field("_EndProcess", obj_array("app.ClassSelector`1<app.decision.process.ProcessBase>", {}))
    d:set_field("_EvaluationCriterions", fixed_eval(opts.value or 1.0, opts.weight or 20.0))
    d:set_field("_HumanCustomSkillIDs", enum_array("app.HumanCustomSkillID", opts.skill and { opts.skill } or {}))
    d:set_field("_Cooldown", opts.cooldown or 6.0)
    d:set_field("_Policy", opts.policy or 1)
    d:set_field("_Target", opts.target or 4) -- Enemy (v48f: 2 = Player for the regroup rule)
    d:set_field("_Enabled", true) -- run 6c: app.AIDecision wrappers copy this at add time; a disabled decision is never wrapped
    local pr = sdec:get_field("_Priority")
    if pr then local pc = shallow_copy(pr); pc:set_field("_Rank", opts.rank or 2); d:set_field("_Priority", pc) end
    -- a fresh UniqueId so the decisions do not share the template's cooldown bookkeeping
    pcall(function()
        local g = d:get_field("_UniqueId"); guid_seed = guid_seed + 1
        g:set_field("mData1", guid_seed); g:set_field("mData2", 0x7a09); d:set_field("_UniqueId", g)
    end)
    return d
end

-- a single-node ActInterPackData whose command is a copy of Common_KeepDistance_Dash's move.KeepDistance with the
-- distance band (via.Range {s, r}: two floats) rewritten; the pawn then holds `min`..`max` metres from its enemy target
local STANCE_SRCS = { "AppSystem/AI/ActionInterface/ActInterPackData/Job02_Archer/Job02_KeepDistance_01.user",
                      "AppSystem/AI/ActionInterface/ActInterPackData/Job02_Archer/Job02_KeepDistance_02.user",
                      "AppSystem/AI/ActionInterface/ActInterPackData/Common/Common_KeepDistance_Dash.user" }
local function build_stance_pack()
    for _, path in ipairs(STANCE_SRCS) do
        local src = sdk.create_userdata("app.ActInterPackData", path)
        local nodes = src and src:get_field("_Pack") and src:get_field("_Pack"):get_field("ActInterNodeList")
        for k = 0, (nodes and nodes:get_size() or 0) - 1 do
            local node = nodes:get_element(k)
            local cmd = node:get_field("_Command"); cmd = cmd and cmd:get_field("_Process")
            if cmd and cmd:get_type_definition():get_full_name() == "app.actinter.cmd.move.KeepDistance" then
                local f = cmd:get_type_definition():get_field("_Distance"); local off = f and f:get_offset_from_base()
                local lo, hi = off and cmd:read_float(off) or -1, off and cmd:read_float(off + 4) or -1
                log("stance: candidate", path:match("([^/]+)%.user$"), "node", k, "band", lo, hi)
                if lo >= (cfg.stance_min_band or 4.0) then
                    local band = cfg.stance_band
                    if band and band[1] then
                        -- clone node -> ClassSelector -> command so the shared vanilla data keeps its band (run 59)
                        local ok, node2 = pcall(function()
                            local n2 = node:call("MemberwiseClone"); if not n2 then return nil end; n2 = PT.keep(n2)
                            local sel = node:get_field("_Command"); local sel2 = PT.keep(sel:call("MemberwiseClone"))
                            local cmd2 = PT.keep(cmd:call("MemberwiseClone"))
                            cmd2:write_float(off, band[1]); cmd2:write_float(off + 4, band[2] or 5.0)
                            sel2:set_field("_Process", cmd2); n2:set_field("_Command", sel2)
                            return n2
                        end)
                        if ok and node2 then
                            node = node2; log("stance: cloned node, band", band[1], band[2] or 5.0)
                        else
                            PT.state.band_restore = PT.state.band_restore or { cmd = cmd, off = off, lo = lo, hi = hi }
                            cmd:write_float(off, band[1]); cmd:write_float(off + 4, band[2] or 5.0)
                            log("stance: clone failed (" .. tostring(node2) .. "), shared command band written", band[1], band[2] or 5.0)
                        end
                    end
                    local pack = PT.keep(sdk.create_instance("app.ActInterPack"))
                    pack:set_field("ActInterNodeList", obj_array("app.ActInterNode", { node })) -- the vanilla node itself (or its clone)
                    local data = PT.keep(sdk.create_instance("app.ActInterPackData"))
                    data:set_field("_Pack", pack)
                    log("stance: using", path:match("([^/]+)%.user$"), "node", k)
                    return data
                end
            end
        end
    end
    log("stance: no vanilla KeepDistance node with a band >=", cfg.stance_min_band or 4.0)
    return nil
end

-- ---------------------------------------------------------------------------------------------------------
-- Goal planning (run 58, 2026-11-09): the pawn's AIGoalPlanning._AIGoalData._GoalTypeList[27]._ParamList[]._GoalParam
-- ._DecisionCategory._Process (app.goalplanning.AIGoalCategoryJob)._JobDecisions[] = { _Job: JobEnum[], _DecisionPacks }
-- decides which decision packs a vocation gets in each situation. 98 rows list the Mage, none lists Job09 (only two
-- carry/wrestle rows do), so a Job09 pawn ran on the generic locomotion only and stood at 2-3 m. Appending Job09 to every
-- Mage row made the pawn keep 8.9 m on average over a goblin fight (run 58a) but also gave it the Mage's casts (it stood in
-- JobMagicUser_StartMagicBarrier with a censer and never summoned): the patch below adds Job09 to the all-vocation rows
-- only and, next to each Mage-only row, a Job09 row with the movement packs of cfg.goal_move_packs. Live data writes:
-- `_Job` arrays are replaced by new managed arrays (4-byte enums written at +0x20), `_JobDecisions` by a longer array
-- holding the old rows plus the new one; everything is kept in PT.state.goal_restore and put back by disable().
local JD_T = "app.goalplanning.AIGoalCategoryJob.JobDecisions"
local function job_array(list)
    local a = PT.keep(sdk.create_managed_array("app.Character.JobEnum", #list))
    for i, v in ipairs(list) do a:write_dword(0x20 + 4 * (i - 1), v) end
    return a
end
local function goal_patch(c)
    if not c.goal or PT.state.goal_restore then return end
    local allow = {}
    for _, path in ipairs(cfg.goal_move_packs or {}) do
        local ok, o = pcall(function() return sdk.create_userdata("app.DecisionPack", path) end)
        if ok and o then allow[o:get_address()] = path:match("([^/]+)%.user$") end
    end
    local gtl = c.goal:get_field("_AIGoalData"):get_field("_GoalTypeList")
    local restore, generic, specific = {}, 0, 0
    for i = 0, gtl:get_size() - 1 do
        local pl = gtl:get_element(i):get_field("_ParamList")
        for j = 0, pl:get_size() - 1 do
            local e = pl:get_element(j); local gpar = e:get_field("_GoalParam") or e
            local cat; pcall(function() cat = gpar:get_field("_DecisionCategory"):get_field("_Process") end)
            if cat and cat:get_type_definition():get_full_name() == "app.goalplanning.AIGoalCategoryJob" then
                local jds = cat:get_field("_JobDecisions"); local extra = {}
                for k = 0, jds:get_size() - 1 do
                    local jd = jds:get_element(k); local jobs = jd:get_field("_Job"); local js, has3, has9 = {}, false, false
                    for q = 0, jobs:get_size() - 1 do local v = jobs:get_element(q):get_field("value__"); js[#js + 1] = v; if v == 3 then has3 = true end; if v == JOB09 then has9 = true end end
                    if has3 and not has9 then
                        if #js >= 4 then
                            js[#js + 1] = JOB09; jd:set_field("_Job", job_array(js)); restore[#restore + 1] = { jd = jd, old = jobs }; generic = generic + 1
                        else
                            local packs = jd:get_field("_DecisionPacks"); local keep = {}
                            for q = 0, packs:get_size() - 1 do local pk = packs:get_element(q); if pk and allow[pk:get_address()] then keep[#keep + 1] = pk end end
                            -- run 58c: the module rebuilds its decision lists from the goal rows and drops the pack added by
                            -- hand (0 of our 5 decisions were live), so the Trickster pack rides in every Job09 row too
                            if #keep > 0 and PT.state.trickster_pack then keep[#keep + 1] = PT.state.trickster_pack end
                            if #keep > 0 then
                                local nj = PT.keep(sdk.create_instance(JD_T)); nj:set_field("_Job", job_array({ JOB09 }))
                                local pa = PT.keep(sdk.create_managed_array("app.DecisionPack", #keep)); for q, pk in ipairs(keep) do pa[q - 1] = pk end
                                nj:set_field("_DecisionPacks", pa); extra[#extra + 1] = nj; specific = specific + 1
                            end
                        end
                    end
                end
                if #extra > 0 then
                    local n = jds:get_size(); local na = PT.keep(sdk.create_managed_array(JD_T, n + #extra))
                    for q = 0, n - 1 do na[q] = jds:get_element(q) end
                    for q, nj in ipairs(extra) do na[n + q - 1] = nj end
                    cat:set_field("_JobDecisions", na); restore[#restore + 1] = { cat = cat, old = jds }
                end
            end
        end
    end
    PT.state.goal_restore = restore
    log("goal: Job09 added to", generic, "all-vocation rows,", specific, "Job09 rows (movement packs + Trickster pack) created next to Mage rows")
end
local function goal_restore()
    local n = 0
    for _, r in ipairs(PT.state.goal_restore or {}) do
        pcall(function() if r.jd then r.jd:set_field("_Job", r.old) else r.cat:set_field("_JobDecisions", r.old) end; n = n + 1 end)
    end
    PT.state.goal_restore = nil
    if n > 0 then log("goal: vanilla job rows restored:", n) end
end

local function step_ai(c)
    if not c.dm then log("ai: no AIDecisionMaker"); return false end
    if PT.state.trickster_pack then log("ai: pack already added"); return true end
    pcall(refresh_equipped, c) -- v47k: the slot list below leaves out skills she has not equipped
    -- run 5: decisions carrying an ActInterPackData built with create_instance (a via.UserData) were selected (cooldowns
    -- ran) but never produced an action, while the decision reusing a vanilla pack did. So every decision now reuses a
    -- vanilla generic pack (shared, untouched) and the hooks on PawnUtil.getJobHeavyAttackAction(Hash) answer with the
    -- action the selected decision stands for (`PT.state.current_action`, tracked per frame). cfg.command_path = "actno"
    -- keeps the created ActNo packs for comparison.
    local use_mux = false -- v5: ActNo packs borrowed from vanilla pawn decisions, retargeted
    PT.state.actno_restore = PT.state.actno_restore or {}
    -- v9: shells from jobs nobody in the party has (nor the main pawn's previous job)
    local avoid = {}
    for j in pairs(party_job_set) do avoid[j] = true end
    if PT.state.prev_job then avoid[PT.state.prev_job] = true end
    avoid[JOB09] = true
    -- v48c: "avoid_jobs": [1, 5] in config.json leaves those vocations' decisions alone as well (the party's are left
    -- alone already). Used to test the slots she gets next to a hired Fighter / Warrior without one in the party.
    if type(cfg.avoid_jobs) == "table" then for _, j in ipairs(cfg.avoid_jobs) do if type(j) == "number" then avoid[j] = true end end end
    local shells = {}
    for _, j in ipairs(SHELL_JOB_ORDER) do
        if not avoid[j] then for _, n in ipairs(SHELL_POOL[j]) do shells[#shells + 1] = "AppSystem/AI/Decision/Pack/" .. n .. ".user" end end
    end
    local avoided = {}; for j in pairs(avoid) do avoided[#avoided + 1] = tostring(j) end
    log("ai: shells from jobs not in the party (avoid " .. table.concat(avoided, ",") .. "):", #shells, "candidates")
    -- v16: a vanilla pack whose decision is live on THIS pawn must never be touched or re-added (run 7 crash at add).
    -- The live set is the Guid list of the module's MainDecisions wrappers (they copy the decision's UniqueId).
    local live, live_n = {}, 0
    local function gk(g) return g and (tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))) or "?" end
    pcall(function()
        local mod = c.dm:get_field("<DecisionModule>k__BackingField")
        local list = mod and mod:get_field("<MainDecisions>k__BackingField")
        local items = list and list:get_field("_items"); local n = list and list:call("get_Count") or 0
        for i = 0, n - 1 do local w = items[i]; if w then live[gk(w:get_field("<UniqueID>k__BackingField"))] = true; live_n = live_n + 1 end end
    end)
    local function pack_is_live(path)
        local src = sdk.create_userdata("app.DecisionPack", path)
        local decs = src and src:get_field("_Decisions")
        if not decs then return false end
        for i = 0, decs:get_size() - 1 do if live[gk(decs:get_element(i):get_field("_UniqueId"))] then return true end end
        return false
    end
    log("ai: live main decisions on the pawn:", live_n)
    local shell_i = 0
    local defs = {
        cfg.melee and { name = "attack", action = ACT.normal, value = 0.8, weight = 14, rank = 2, cooldown = 3.0 } or nil,
        { name = "summon",   action = ACT.heavy,          value = 1.0, weight = 20, rank = 3, cooldown = cfg.summon_cooldown },
        { name = "beckon",   action = ACT.transfer,       value = 0.9, weight = 20, rank = 2, cooldown = 8.0 },
        { name = "shroud",   action = SKILL_ACTION[95],   value = 0.9, weight = 20, rank = 2, cooldown = 15.0, skill = 95, policy = 17 },
        { name = "rally",    action = SKILL_ACTION[97],   value = 0.8, weight = 12, rank = 2, cooldown = cfg.rally_cooldown or 12.0, skill = 97, policy = 25 },
        { name = "delusion", action = SKILL_ACTION[99],   value = 0.7, weight = 12, rank = 2, cooldown = 40.0, skill = 99, policy = 17 },
        { name = "screen",   action = SKILL_ACTION[92],   value = 0.5, weight = 10, rank = 2, cooldown = 30.0, skill = 92, policy = 17 },
        -- run 14: adding this slot (copied move.KeepDistance command in a created node) crashed the game within a second of
        -- addDecisionPack, out of battle. Off unless cfg.stance = true; a stance needs a vanilla node, not a copied command.
        cfg.stance and { name = "stance", kind = "keepdist", value = cfg.stance_value or 1.0, weight = cfg.stance_weight or 24, rank = cfg.stance_rank or 3, cooldown = cfg.stance_cooldown or 4.0 } or nil, -- v40: rank 3 like the summon slot (rank 2 was never picked while the pawn was hit)
        -- v47: the Latching Effigy slot, released by V.trick (after the stance entry: older slots keep their shells)
        { name = "trick", action = SKILL_ACTION[96], value = 1.0, weight = 20, rank = 3, cooldown = 12.0, skill = 96, policy = 17, aim = true,
          target_range = (cfg.effigy_band ~= false) and { cfg.effigy_near or 3.0, math.max(0.5, (cfg.effigy_far or 10.5) - (cfg.effigy_near or 3.0)) } or nil,
          target_angle = (cfg.effigy_face_target ~= false) and (cfg.effigy_aim_deg or 12.0) or nil,
          target_rise = ((cfg.effigy_small_rise or 0) > 0) and cfg.effigy_small_rise or nil },
        -- v48f: the game's own "dash to the target" pack, untouched, in a rule of ours whose target is the Arisen
        (cfg.regroup ~= false) and { name = "regroup", kind = "vanilla", need = 97, target = 2, value = 1.0, weight = 20, rank = 3, cooldown = cfg.regroup_cooldown or 20.0,
            path = "AppSystem/AI/ActionInterface/ActInterPackData/Common/Move_Fix_Dash_Target.user" } or nil,
        -- v48i: the idle attack. The censer swing where she stands; V.dust_fire throws the smoke ball when the swing starts
        (cfg.dust ~= false) and { name = "dust", action = ACT.dust, value = cfg.dust_value or 0.5, weight = cfg.dust_weight or 10, rank = cfg.dust_rank or 2, cooldown = cfg.dust_cooldown or 4.0, aim = true,
            target_range = { cfg.dust_near or 4.0, math.max(1.0, (cfg.dust_far or 14.0) - (cfg.dust_near or 4.0)) },
            target_angle = ((cfg.dust_aim_deg or 0) > 0) and cfg.dust_aim_deg or nil } or nil,
    }
    local compact = {}
    for i = 1, 12 do if defs[i] then compact[#compact + 1] = defs[i] end end
    defs = compact
    local decs, named, actions = {}, {}, {}
    V.rule_drop, V.rule_dropped = {}, {}
    if type(cfg.rule_drop) == "table" then for _, n in ipairs(cfg.rule_drop) do if type(n) == "string" then V.rule_drop[n] = true end end end
    for _, o in ipairs(defs) do
        if o.name == "beckon" or o.name == "shroud" then goto continue end -- covered by the summon slot's multiplex
        if o.kind == "vanilla" then -- v48f: no shell and no command of ours: the decision points at a vanilla pack as it is
            if o.need and not has_skill(o.need) then log("ai: slot", o.name, "left out: skill", o.need, "is not equipped"); goto continue end
            local vp = sdk.create_userdata("app.ActInterPackData", o.path)
            if not vp then log("ai: pack missing", o.path); goto continue end
            o.pack = vp
            local dv = make_decision(o)
            if dv then decs[#decs + 1] = dv; named[o.name] = dv; actions[o.name] = "Regroup"; log("ai: slot", o.name, "uses the vanilla pack", o.path:match("([^/]+)%.user$"), "with target", o.target) end
            goto continue
        end
        -- v47k: no slot for a skill she has not equipped. The gates are cooldown writes on the game's wrappers, and the
        -- game rebuilds those (timer 0) when the battle state changes: a gated slot could be picked in that frame
        -- (she cast Latching Effigy without owning it). Skills equipped later get their slot at the next load.
        if o.skill and not has_skill(o.skill) then log("ai: slot", o.name, "left out: skill", o.skill, "is not equipped"); goto continue end
        shell_i = shell_i + 1
        local path = shells[shell_i]
        while path and pack_is_live(path) do
            log("ai: shell", path:match("([^/]+)%.user$"), "is live on this pawn, skipped")
            shell_i = shell_i + 1; path = shells[shell_i]
        end
        if not path then log("ai: no free shell for slot", o.name); goto continue end
        local ap = actno_pack(path)
        if not ap then log("ai: pack missing", path); goto continue end
        local oldpack = ap:get_field("_Pack")
        PT.state.actno_restore[#PT.state.actno_restore + 1] = { ap = ap, old = oldpack }
        local mine
        if o.kind == "keepdist" then mine = build_stance_pack() else mine = build_actno_pack(o.action, o.aim) end -- (not and/or: a nil stance must not fall through to ActNo(nil))
        if not mine then goto continue end
        ap:set_field("_Pack", mine:get_field("_Pack"))
        PT.state.slot_cmds = PT.state.slot_cmds or {}
        PT.state.slot_cmds[o.name] = mine:get_field("_Pack"):get_field("ActInterNodeList"):get_element(0):get_field("_Command"):get_field("_Process")
        log("ai: slot", o.name, "shell", path:match("([^/]+)%.user$"), "nodes", oldpack and oldpack:get_field("ActInterNodeList"):get_size() or "?", "-> ActNo", o.action)
        o.pack = ap
        local d = make_decision(o)
        if d then decs[#decs + 1] = d; named[o.name] = d; actions[o.name] = o.action or "KeepDistance" end
        ::continue::
    end
    PT.state.actions = actions
    if named.dust or named.trick then local oks, es = pcall(function() V.shell_data(); V.shell_hooks() end); if not oks then log("shells: setup failed:", es) end end
    do local t = {}; for n, c in pairs(V.rule_dropped) do t[#t + 1] = n .. " x" .. c end; table.sort(t)
        log("ai: checks of the copied attack left out of her rules:", #t > 0 and table.concat(t, ", ") or "none")
        if V.rule_added then log("ai: target check added:", V.rule_added); V.rule_added = nil end end
    local pack = PT.keep(sdk.create_instance("app.DecisionPack"))
    pack:set_field("_Stage", 1) -- Main
    pack:set_field("_Decisions", obj_array("app.DecisionPack.Decision", decs))
    local ok, err = pcall(function() c.dm:call("addDecisionPack(app.DecisionPack)", pack) end)
    log("ai: trickster pack with", #decs, "decisions added", ok, err or "")
    if ok and cfg.mage_keepdistance and not PT.state.mage_pack then
        if pack_is_live("AppSystem/AI/Decision/Pack/Job03_KeepDistance_01.user") then
            log("ai: Job03_KeepDistance_01 is already live on this pawn (Mage main pawn), not re-added")
        else
            PT.state.mage_pack_due = os.clock() + 3.0 -- added later, on its own frame (run 32 crash right after a same-frame double add)
        end
    end
    -- the module only wraps new packs when it rebuilds its lists (situation change); ask it to rebuild now
    if ok and cfg.force_rebuild then -- run 9: forcing the rebuild mid-battle was followed by a crash within seconds; default off
        local mod = c.dm:get_field("<DecisionModule>k__BackingField")
        local ok2, err2 = pcall(function() mod:call("setNewDecisionLists") end)
        log("ai: setNewDecisionLists", ok2, err2 or "")
    end
    if ok then PT.state.trickster_pack = pack; PT.state.decs = named; PT.state.gates = {} end
    if ok and cfg.goal_jobs ~= false then local ok3, err3 = pcall(goal_patch, c); if not ok3 then log("goal: patch failed", err3) end end
    return ok
end

-- which of our decisions did the pawn select last? The module's MainDecisions list holds runtime wrappers around the
-- DecisionPack.Decision data; find the wrapper field that points back at the data (cached once) and match addresses.
-- (run 6a: the wrapper is app.AIDecision, which copies every Decision field and keeps no pointer to the data, so the
-- match goes through the UniqueID we gave each decision)
local function guid_key(g) return g and (tostring(g:get_field("mData1")) .. ":" .. tostring(g:get_field("mData2"))) or "?" end
-- live gate: keep a slot's wrapper CooldownTimer high while blocked (wrappers ignore _Enabled after the add; the timer
-- is read every tick). `wrappers[name]` is filled by track_selection.
local wrappers = {}
local gate_saved = {}
local wrapper_live = {} -- addresses of our wrappers seen in MainDecisions by the last track_selection (same frame)
local function live_wrapper(name)
    local w = wrappers[name]
    if not w or not wrapper_live[w:get_address()] then return nil end
    return w
end
local function gate_slot(name, blocked)
    local w = live_wrapper(name); if not w then return end
    if cfg.only_slot and cfg.only_slot ~= "" and name ~= cfg.only_slot then blocked = true end -- v48k, for tests and captures: every other slot held (e.g. only_slot = "dust": nothing but the dust swing)
    if blocked then
        local t = w:get_field("<CooldownTimer>k__BackingField") or 0
        if t < 300 then
            -- remember how much of the slot's own cooldown was left (it keeps running down while blocked)
            gate_saved[name] = { left = t, t = os.clock() }
            w:set_field("<CooldownTimer>k__BackingField", 600.0)
        end
    elseif PT.state.gate_blocked and PT.state.gate_blocked[name] then
        local sv = gate_saved[name]
        local left = sv and math.max(0, sv.left - (os.clock() - sv.t) * 60.0) or 0 -- the game's cooldown timers lose 60 units a second of real time at any frame rate (measured at 30 FPS: 2.0 a frame)
        w:set_field("<CooldownTimer>k__BackingField", left) -- released: resume the slot's own cooldown (0 = pick now)
        gate_saved[name] = nil
    end
    PT.state.gate_blocked = PT.state.gate_blocked or {}
    if PT.state.gate_blocked[name] ~= blocked then PT.state.gate_blocked[name] = blocked; log("gate:", name, blocked and "blocked" or "released") end
end
-- release a slot's cooldown at once (the protect rule): a decrease is never read as a pick by track_selection
local function poke_slot(name)
    local w = live_wrapper(name); if not w then return end
    local t = w:get_field("<CooldownTimer>k__BackingField") or 0
    if t > 0.5 and t < 300 then w:set_field("<CooldownTimer>k__BackingField", 0.0); log(string.format("poke: %s cooldown %.1f -> 0", name, t)) end
end
local last_timer = {}
local function track_selection(c)
    if not PT.state.decs or not c.dm then return end
    if not PT.state.guid_names then
        PT.state.guid_names = {}
        for name, d in pairs(PT.state.decs) do PT.state.guid_names[guid_key(d:get_field("_UniqueId"))] = name end
    end
    local mod = c.dm:get_field("<DecisionModule>k__BackingField")
    local list = mod and mod:get_field("<MainDecisions>k__BackingField")
    local items = list and list:get_field("_items"); local n = list and list:call("get_Count") or 0
    local seen = 0
    wrapper_live = {}
    for i = 0, n - 1 do
        local w = items[i]
        local name = w and PT.state.guid_names[guid_key(w:get_field("<UniqueID>k__BackingField"))]
        if name then
            seen = seen + 1
            wrappers[name] = w
            wrapper_live[w:get_address()] = true
            local t = w:get_field("<CooldownTimer>k__BackingField") or 0
            local full = w:get_field("<CooldownTime>k__BackingField") or 0
            local prev = last_timer[name]
            if prev ~= nil and t > prev + 1 and t <= full + 1 then -- (a jump above the slot's cooldown is our gate write)
                if t >= full - 1 and full > 0 then
                    PT.state.current_decision = name
                    PT.state.current_action = PT.state.actions[name]
                    PT.state.picks = (PT.state.picks or 0) + 1
                    log("pick:", name, "->", tostring(PT.state.current_action), "index", i, "timer", t)
                elseif t >= 290 and t <= 310 and cfg.backoff_to_cooldown ~= false then
                    -- the executor reports our ActNo as failed and the module applies its 300-frame retry backoff;
                    -- the action plays all the same, so make the slot wait its own cooldown (run 31)
                    PT.state.current_decision = name
                    PT.state.current_action = PT.state.actions[name]
                    PT.state.picks = (PT.state.picks or 0) + 1
                    PT.state.backoff_fixes = (PT.state.backoff_fixes or 0) + 1
                    if full > t then w:set_field("<CooldownTimer>k__BackingField", full); t = full end
                    log("pick:", name, "->", tostring(PT.state.current_action), "index", i, "(backoff 300 -> cooldown", full, ")")
                else
                    PT.state.retries = (PT.state.retries or 0) + 1
                end
            end
            last_timer[name] = t
        end
    end
    if seen ~= (PT.state.wrapped or 0) then PT.state.wrapped = seen; log("track:", seen, "of our decisions in MainDecisions (", n, "total )") end
end

-- per-frame gates
local function set_gate(name, on)
    local d = PT.state.decs and PT.state.decs[name]
    if not d then return end
    if PT.state.gates[name] ~= on then
        PT.state.gates[name] = on
        d:set_field("_Enabled", on)
        log("gate:", name, on and "enabled" or "disabled")
    end
end
local pos_of -- defined further down (position of a character)
local function update_summon_gate(c)
    if not c.job09 then return end -- (v4: runs before the pack exists; it is this function that adds the pack once ready)
    local dh = c.job09:call("get_DecoyHandler")
    local has = dh and dh:call("get_HasInstance") or false
    if has then
        local appeared, hidden, inproc = true, false, true
        pcall(function() appeared = dh:call("get_Appeared"); hidden = dh:call("get_Hidden"); inproc = dh:call("get_InProcess") end)
        -- v47u: not while she is playing Job09_SummonDecoy herself, nor for 4 s after that action started. The action
        -- creates the instance, which is "not appeared yet" for a moment; handler.start() on it in that moment is
        -- the crash of 2026-11-10 11:29:10 (DD2.exe+0x552832a, the second both log lines were written).
        local summoning = PT.state.act_now == ACT.heavy or (PT.state.summon_act_t and os.clock() - PT.state.summon_act_t < 4.0)
        -- v48f: only while the party is in battle (state of the previous frame). Out of battle the decoy came back
        -- every time it had dispersed, for as long as the session lasted (Nexus report on 0.2.2, 2026-11-11).
        local fighting = PT.state.battle == 2 or cfg.resummon_calm == true
        if fighting and (hidden or not appeared) and not inproc and not summoning and not PT.state.possessed and not (PT.state.effigy_t and os.clock() - PT.state.effigy_t < 8.0) then
            -- a dispersed decoy sleeps as a hidden instance; re-summon it the way the game does, at the pawn's feet
            if not PT.state.resummon_t or os.clock() - PT.state.resummon_t > (cfg.resummon_seconds or 6.0) then
                PT.state.resummon_t = os.clock()
                local ok, err = pcall(function()
                    local tf = c.chara:call("get_Transform"); local up = tf:call("get_UniversalPosition"); local q = tf:call("get_Rotation")
                    local fx, fz = 2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y) -- v48g: her facing is +Z (this pointed behind her until 0.2.4)
                    -- towards the nearest live enemy when there is one, else straight ahead
                    local pp = tf:call("get_Position"); local best
                    for _, e in ipairs(PT.enemies(true)) do
                        if e.hp > 0 then
                            local ep = pos_of(e.chara)
                            if ep then local d = math.sqrt((ep.x - pp.x) ^ 2 + (ep.z - pp.z) ^ 2); if d > 0.5 and (not best or d < best.d) then best = { d = d, x = (ep.x - pp.x) / d, z = (ep.z - pp.z) / d } end end
                        end
                    end
                    if best then fx, fz = best.x, best.z end
                    local off = cfg.resummon_offset or 6.0
                    if best and best.d < off + 1.0 then off = math.max(1.5, best.d * 0.6) end
                    up.x = up.x + fx * off; up.z = up.z + fz * off
                    local info = PT.keep(sdk.create_instance("app.SmokeDecoy.StartInformation"))
                    info:call("set_StateName", "Start")
                    info:set_field("<Position>k__BackingField", up); info:set_field("<Rotation>k__BackingField", q)
                    dh:call("start", info)
                end)
                PT.state.resummons = (PT.state.resummons or 0) + 1
                if ok then PT.state.retreat_until = os.clock() + (cfg.retreat_seconds or 8.0); PT.state.retreat_pending = false end
                log("decoy: sleeping instance re-summoned through handler.start(info) at the pawn", ok, err or "")
            end
        end
    end
    local far = false
    if has then
        local inst = dh:get_field("<Instance>k__BackingField")
        local go = inst and inst:call("get_GameObject"); local tf = go and go:call("get_Transform")
        local dp = tf and tf:call("get_Position"); local pp = c.chara:call("get_Transform"):call("get_Position")
        if dp and pp then
            local dist = math.sqrt((dp.x - pp.x) ^ 2 + (dp.y - pp.y) ^ 2 + (dp.z - pp.z) ^ 2)
            far = dist > (cfg.beckon_distance or 15.0)
        end
    end
    -- v47: a latched effigy stays on its enemy, and a decoy just sent by Espial stays where it was sent (no beckon)
    local eff_busy = (PT.state.effigy_t and os.clock() - PT.state.effigy_t < 4.5) or false -- the cast itself takes about 3.7 s
    if PT.state.possessed or eff_busy or (PT.state.sent_until and os.clock() < PT.state.sent_until) then far = false end
    local hp, maxhp = c.chara:call("get_Hp"), max_hp(c.chara)
    local low = (hp and maxhp and maxhp > 0) and (hp / maxhp < 0.6) or false
    local cur = c.selector:get_field("CurrentSelector")
    local sel_ok = cur ~= nil and cur:get_type_definition():get_full_name() == "app.Job09ActionSelector"
    local settled = PT.state.ready_t ~= nil and (os.clock() - PT.state.ready_t) > (cfg.settle_seconds or 5.0)
    local pm = sdk.get_managed_singleton("app.PawnManager")
    local bc = pm and pm:call("get_BattleController")
    local battle = bc and bc:get_field("_CurrentState") or 0
    -- run 6b: making the Job09ActionSelector the pawn's CURRENT selector (moved before the NoJob ones + updateCurrentSelector)
    -- crashed the game within a frame, so the selector is never required (runs 2-5 played every Job09 action under NoJob)
    local ready = settled and (battle == 2 or cfg.require_battle == false)
    if ready ~= PT.state.ready then PT.state.ready = ready; log("ready:", ready, "selector", cur and cur:get_type_definition():get_full_name() or "nil", "battle", battle) end
    PT.state.has_decoy = has; PT.state.decoy_far = far; PT.state.low_hp = low; PT.state.battle = battle
    local cmd = PT.state.slot_cmds and PT.state.slot_cmds.summon
    if cmd then
        local want = (not has) and ACT.heavy or ((far or not has_skill(95)) and ACT.transfer or SKILL_ACTION[95])
        if PT.state.summon_action ~= want then
            PT.state.summon_action = want
            cmd:set_field("ActionID", mstring(want))
            if PT.state.actions then PT.state.actions.summon = want end
            log("mux: summon slot ->", want, "(decoy", tostring(has), "far", tostring(far), ")")
        end
    end
    PT.state.prefab_ok = dh ~= nil and dh:get_field("<Prefab>k__BackingField") ~= nil
    if ready and not PT.state.trickster_pack and PT.state.prefab_ok and not PT.state.ai_failed then
        -- v47w: one attempt per load. An error in step_ai used to be retried every frame (each try borrowed the
        -- shells again and created a new set of objects): seen in a second load on 2026-11-10, crash 2 s later.
        local oka, ea = pcall(step_ai, c)
        if not oka then
            PT.state.ai_failed = true
            for _, r in ipairs(PT.state.actno_restore or {}) do pcall(function() r.ap:set_field("_Pack", r.old) end) end
            PT.state.actno_restore = {}
            log("ai: building her combat rules failed; not tried again in this load (she keeps the vanilla pawn behaviour):", ea)
        end
    end
    if PT.state.mage_pack_due and os.clock() > PT.state.mage_pack_due and battle ~= 2 then
        PT.state.mage_pack_due = nil
        local mp = sdk.create_userdata("app.DecisionPack", "AppSystem/AI/Decision/Pack/Job03_KeepDistance_01.user")
        if mp then
            local ok2, err2 = pcall(function() c.dm:call("addDecisionPack(app.DecisionPack)", mp) end)
            log("ai: vanilla Job03_KeepDistance_01 (Mage keep-distance) added", ok2, err2 or "")
            if ok2 then PT.state.mage_pack = mp end
        end
    end
    -- run 16: the pawn's blackboard Action.AttackRangeXZ (app.BBKeys.Action.Float = 1) is 0 for a Job09 pawn (no
    -- attack-range table entry), so every Approach / KeepDistance band collapses to melee. Hold it at cfg.attack_range.
    PT.state.frame_i = (PT.state.frame_i or 0) + 1
    if PT.state.decs and PT.state.decs.stance and PT.state.frame_i % 10 == 0 then
        -- one enemy scan per tick (quiet: run 19's log was 80% enemy lines)
        local elist = {}
        pcall(function() elist = PT.enemies(true) end)
        local mpos = pos_of(c.chara)
        local near, big, crowd_n = false, false, 0
        for _, e in ipairs(elist) do
            if e.hp > 0 then
                if mpos then
                    local p = pos_of(e.chara)
                    -- hysteresis: release under stance_trigger, block again only beyond stance_trigger + 3
                    local d = p and math.sqrt((p.x - mpos.x) ^ 2 + (p.y - mpos.y) ^ 2 + (p.z - mpos.z) ^ 2) or 999
                    local limit = (cfg.stance_trigger or 6.0) + ((PT.state.gate_blocked and PT.state.gate_blocked.stance == false) and 3.0 or 0.0)
                    if d < limit then near = true end
                end
                if e.hp > (cfg.big_enemy_hp or 5000) and e.dist >= 0 and e.dist < 40 then big = true end
                if e.dist >= 0 and e.dist < (cfg.crowd_distance or 25.0) then crowd_n = crowd_n + 1 end
            end
        end
        local crowd = crowd_n >= (cfg.delusion_min_enemies or 3)
        -- the Arisen: distance, HP, HP trend
        local _, pl = player_component()
        local ppos = pl and pos_of(pl)
        local pdist = (ppos and mpos) and math.sqrt((ppos.x - mpos.x) ^ 2 + (ppos.y - mpos.y) ^ 2 + (ppos.z - mpos.z) ^ 2) or 999
        local php, pmax = 1, 1
        pcall(function() php = pl:call("get_Hp"); pmax = max_hp(pl) end)
        php = php or 0; pmax = pmax or 0
        local player_low = (pmax > 0) and (php / pmax < (cfg.protect_low or 0.5)) or false
        -- v16: protect the Arisen. HP sampled once a second (last three samples); a drop of protect_drop of max HP
        -- against the oldest sample, or HP under protect_low, opens a protect window.
        local now = os.clock()
        PT.state.php_hist = PT.state.php_hist or {}
        local hist = PT.state.php_hist
        if #hist == 0 or now - hist[#hist].t >= 1.0 then hist[#hist + 1] = { t = now, hp = php }; if #hist > 3 then table.remove(hist, 1) end end
        local drop = (#hist >= 2 and pmax > 0) and ((hist[1].hp - php) / pmax) or 0
        local threat = (cfg.protect ~= false) and pmax > 0 and (drop >= (cfg.protect_drop or 0.08) or player_low)
        if threat then
            if not (PT.state.protect_until and now < PT.state.protect_until) then
                log(string.format("protect: Arisen hp %.0f/%.0f (drop %.0f%% in %.0fs, low %s): summon/Shroud + Screen released, stance and Rally held", php, pmax, drop * 100, now - hist[1].t, tostring(player_low)))
                PT.state.protects = (PT.state.protects or 0) + 1
            end
            PT.state.protect_until = now + (cfg.protect_seconds or 6.0)
            PT.state.retreat_until = nil
        end
        local protecting = PT.state.protect_until ~= nil and now < PT.state.protect_until
        PT.state.arisen_trouble = (player_low or protecting) and true or false -- v47n: the screen line addresses the Arisen
        local retreating = PT.state.retreat_until and now < PT.state.retreat_until
        local pressed = (cfg.flee_first == true) and near and PT.state.has_decoy and not protecting
        local stance_hold = (PT.state.stance_hold_until and now < PT.state.stance_hold_until)
            or (PT.state.approach_until and now < PT.state.approach_until) or eff_busy
            or (PT.state.possessed and now - (PT.state.possessed_t or now) < (cfg.effigy_hold or 12.0)) or false
        -- v48e: her rules no longer carry the copied attack's own-AI-state check (it is false in the "Danger" state, and
        -- she then cast nothing for whole fights): the party's battle state gates every slot instead
        local calm = not (battle == 2 or (cfg.cast_in_ready == true and battle == 1))
        if calm ~= PT.state.calm then PT.state.calm = calm; log("battle:", calm and "the party is not in battle, every slot held" or "the party is in battle, slots follow their own rules") end
        gate_slot("stance", calm or protecting or stance_hold or not (near or retreating))
        local shroud_hold = (cfg.shroud ~= true or not has_skill(95)) and has and not far -- Shroud does nothing for a pawn's decoy: no cast, move instead
        gate_slot("summon", (calm or (retreating and not protecting) or pressed or shroud_hold or PT.state.possessed or eff_busy) or false) -- walk away from the decoy first, then taunt
        if pressed ~= PT.state.pressed then PT.state.pressed = pressed; log("flee:", pressed and "enemy within reach, casts held, stance only" or "clear, casts released") end
        -- v46: a skill slot only fires when the pawn has that skill equipped (release mode)
        -- v48e: an ally in reach is the Arisen or another party pawn; and no Rally on low stamina (it is held for
        -- seconds and took her to -57 % in a goblin fight: winded, then the game's stamina break)
        local ally_near = pdist < (cfg.rally_distance or 12.0)
        local ally = ally_near and "arisen" or "none"
        if not ally_near and mpos then pcall(function() ally_near = V.pawn_near(c, mpos, cfg.rally_distance or 12.0) end); if ally_near then ally = "pawn" end end
        PT.state.rally_ally = ally
        -- v48g: her stamina as a share of the maximum; Rally and Delusion each have a floor under which they do not
        -- start (an 8 s Rally cooldown without one took her to -28 %: 15 s out of 120 in the out-of-stamina action)
        local sfrac = 1.0
        pcall(function()
            local sm = c.chara:get_field("<StaminaManager>k__BackingField")
            local mx = sm:get_field("<MaxValue>k__BackingField")
            if mx > 0 then sfrac = sm:get_field("<RemainingAmount>k__BackingField") / mx end
        end)
        local tired = (cfg.rally_min_stamina or 0) > 0 and sfrac < cfg.rally_min_stamina
        local dtired = (cfg.delusion_min_stamina or 0) > 0 and sfrac < cfg.delusion_min_stamina
        if tired ~= PT.state.rally_tired then PT.state.rally_tired = tired; if tired then PT.state.rally_tired_n = (PT.state.rally_tired_n or 0) + 1 end end
        gate_slot("rally", calm or eff_busy or pressed or protecting or not ally_near or tired or not has_skill(97))
        if PT.state.decs.regroup then
            -- v48f: Rally is ready, she has the stamina, nobody is in reach: go to the Arisen. The gate closes once an
            -- ally is in reach; the running dash is ended by V.regroup_tick at regroup_stop metres.
            local go = not calm and not eff_busy and not pressed and not protecting and not tired and not ally_near
                and has_skill(97) and pdist < (cfg.regroup_max or 40.0) and V.slot_ready("rally")
            gate_slot("regroup", not go)
            local okr, er = pcall(V.regroup_tick, c, now, pdist)
            if not okr and not PT.state.regroup_err then PT.state.regroup_err = true; log("regroup error:", er) end
        end
        gate_slot("delusion", calm or eff_busy or pressed or dtired or not (big or crowd) or not has_skill(99))
        gate_slot("screen", calm or eff_busy or pressed or ((cfg.screen_min_stamina or 0) > 0 and sfrac < cfg.screen_min_stamina) or not (PT.state.low_hp or player_low or protecting) or not has_skill(92))
        -- v48i: the dust ball is for the time nothing else is due. The game's order does that (its rank and score are the
        -- lowest of her rules); with "no enemy within the stance distance" in this gate it opened for a second at a time
        -- (v48i: not with an enemy within dust_safe metres of her: the swing roots her for two seconds)
        if PT.state.decs.dust then gate_slot("dust", (calm or eff_busy or pressed or protecting or cfg.dust == false or not V.dust_safe(c)) and true or false) end
        do -- v47: Latching Effigy / Fickle Floor / Espial Incense share the trick slot
            local okt, et = pcall(V.trick, c, { elist = elist, mpos = mpos, near = near, crowd_n = crowd_n, has = has, far = far, hold = pressed, protecting = protecting, now = now, dh = dh, battle = battle, sfrac = sfrac })
            if not okt and not PT.state.trick_err then PT.state.trick_err = true; log("trick error:", et) end
            local okp, ep = pcall(V.preempt, c, now)
            if not okp and not PT.state.preempt_err then PT.state.preempt_err = true; log("preempt error:", ep) end
        end
        if protecting and (not near or not PT.state.has_decoy) and (not PT.state.protect_poke_t or now - PT.state.protect_poke_t > (cfg.protect_repick or 10.0)) then
            PT.state.protect_poke_t = now
            poke_slot("summon"); poke_slot("screen")
        end
        -- test guard (never in a shipping build): keep a low-level Arisen alive through a test fight
        if (cfg.test_guard or 0) > 0 and pmax > 0 and php / pmax < cfg.test_guard then PT.heal_player() end
    end
    local want_range = cfg.attack_range
    if want_range == "mage" then want_range = PT.state.mage_range or 30.0 end
    if type(want_range) == "number" and want_range > 0 then
        pcall(function()
            local fb = c.dm:get_field("_AIBlackBoardController"):get_field("<BBAggregate>k__BackingField"):get_field("<Action>k__BackingField"):get_field("<BlackBoardFloat>k__BackingField")
            if fb and math.abs((fb:call("getValue", 1) or 0) - want_range) > 0.01 then
                fb:call("setValue", 1, want_range)
                PT.state.range_sets = (PT.state.range_sets or 0) + 1
            end
        end)
    end
end
-- trace of the pawn's current action (one log line per change) so a crash leaves the last actions in the log
local last_action = nil
local function action_trace(c)
    local am = c.chara:call("get_ActionManager")
    local list = am and am:get_field("CurrentActionList"); local items = list and list:get_field("_items")
    local act = items and items[0] and tostring(items[0]:get_field("Name")) or "?"
    if act ~= last_action then
        last_action = act
        log("action:", act, "sel", tostring(PT.state.current_decision), "hook", tostring(PT.state.last_hook))
        if V.on_action then local okv, ev = pcall(V.on_action, c, act); if not okv then log("on_action error:", ev) end end
        if act == "Job09_SummonDecoy" then
            PT.state.retreat_until = os.clock() + (cfg.retreat_seconds or 8.0) + 2.0 -- provisional (covers the cast)
            PT.state.retreat_pending = true
        elseif PT.state.retreat_pending then
            PT.state.retreat_pending = false
            PT.state.retreat_until = os.clock() + (cfg.retreat_seconds or 8.0)
            log("retreat: window", cfg.retreat_seconds or 8.0, "s (after the summon)")
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------
-- jobs of every pawn the PawnManager lists (generic: any List field whose items carry a CachedHuman)
local function party_pawn_jobs()
    local pm = sdk.get_managed_singleton("app.PawnManager"); if not pm then return {} end
    local jobs = {}
    party_job_set = {}
    local td = pm:get_type_definition()
    for _, f in ipairs(td:get_fields()) do
        if not f:is_static() and f:get_type():get_full_name():find("^System%.Collections%.Generic%.List") then
            pcall(function()
                local list = pm:get_field(f:get_name()); local n = list:call("get_Count")
                for i = 0, n - 1 do
                    local pw = list:call("get_Item", i)
                    local hm = pw and pw:get_field("<CachedHuman>k__BackingField")
                    local jc = hm and hm:get_field("<JobContext>k__BackingField")
                    if jc then
                        local j = jc:get_field("CurrentJob")
                        jobs[#jobs + 1] = f:get_name() .. "[" .. i .. "]=" .. tostring(j)
                        if type(j) == "number" then party_job_set[j] = true end
                        if j == 3 then -- the party Mage: its attack range is the template for ours
                            pcall(function()
                                local dm2 = pw:get_field("CachedAIDecisionMaker")
                                local fb = dm2:get_field("_AIBlackBoardController"):get_field("<BBAggregate>k__BackingField"):get_field("<Action>k__BackingField"):get_field("<BlackBoardFloat>k__BackingField")
                                local r = fb:call("getValue", 1)
                                if r and r > 0 then PT.state.mage_range = r; jobs[#jobs + 1] = "(mage range " .. tostring(r) .. ")" end
                            end)
                        end
                    end
                end
            end)
        end
    end
    return jobs
end
-- v48a: the vocations of the other party pawns (hired ones), sorted, "" when she is alone; nil while one of them
-- is still being set up. Her AI slots are built on decisions of vocations nobody in the party has (step_ai), chosen
-- at enable: a pawn hired later could be of the vocation she borrows from, and would then run her retargeted actions.
function PT.party_sig()
    local pm = sdk.get_managed_singleton("app.PawnManager"); if not pm then return nil end
    local list = pm:get_field("_PartyPawnList"); if not list then return nil end
    local main = pm:get_field("_MainPawn"); local main_addr = main and main:get_address()
    local jobs = {}
    for i = 0, list:call("get_Count") - 1 do
        local pw = list:call("get_Item", i)
        if pw and pw:get_address() ~= main_addr then
            local hm = pw:get_field("<CachedHuman>k__BackingField")
            local jc = hm and hm:get_field("<JobContext>k__BackingField")
            local j = jc and jc:get_field("CurrentJob")
            if type(j) ~= "number" then return nil end
            jobs[#jobs + 1] = j
        end
    end
    table.sort(jobs)
    return table.concat(jobs, ",")
end
-- true once the other pawns' vocations differ from those at enable on two checks in a row (2 s apart)
function PT.party_changed()
    local st = PT.state
    local now = os.clock()
    if now < (st.party_next or 0) then return false end
    st.party_next = now + 2.0
    local ok, sig = pcall(PT.party_sig)
    if not ok or sig == nil then st.party_cand = nil; return false end
    if st.party_sig == nil then st.party_sig = sig; return false end
    if sig == st.party_sig then st.party_cand = nil; return false end
    if st.party_cand ~= sig then st.party_cand = sig; return false end
    log("party: the other pawns' vocations changed from [" .. st.party_sig .. "] to [" .. sig .. "]")
    return true
end
function PT.enable()
    if PT.cfg_moved and #PT.cfg_moved > 0 then table.sort(PT.cfg_moved); log("config: settings that still had their old default now follow the new one:", table.concat(PT.cfg_moved, ", ")); PT.cfg_moved = nil end
    -- v48d: a second enable() on top of a running setup (the panel's button pressed while she is enabled, or a
    -- manual call seconds after auto-enable) stacked two setups: she then picked almost nothing in fights (0 and 1
    -- pick in 45 s, twice out of four stacked enables, 2026-11-10). enable() is a no-op while she is enabled.
    if PT.enabled then log("enable: already enabled (disable first to set her up again)"); return true end
    local c, err = ctx()
    if not c then log("enable failed:", err); return false end
    PT.weapon_fix = nil
    log("party pawn jobs:", table.concat(party_pawn_jobs(), " "), "(shells come from jobs absent here)")
    do local oks, sig = pcall(PT.party_sig); PT.state.party_sig = oks and sig or nil; PT.state.party_cand = nil end
    log("=== enable: pawn job", c.jobctx:get_field("CurrentJob"))
    PT.state.pending = { c = c, t = os.clock(), stage = 0 }
    PT.enabled = true
    step_hooks()
    step_job(c)
    return true
end
-- stages run over following frames so the job change can settle
local function pump()
    local p = PT.state.pending
    if not p then return end
    local c = p.c
    if p.stage == 0 and os.clock() - p.t > 1.0 then
        if c.jobctx:get_field("CurrentJob") ~= JOB09 then
            log("pump: job still", c.jobctx:get_field("CurrentJob"), "- forcing set_Job(9)")
            pcall(function() c.jobctx:call("set_Job", JOB09) end)
        end
        step_weapon(c); p.stage = 1; p.t = os.clock()
    elseif p.stage == 1 and os.clock() - p.t > 1.5 then
        p.stage = 2 -- whatever happens below, never run this stage twice
        -- refresh the human pointers (job change may have rebuilt controllers)
        local c2 = ctx(); if c2 then c = c2 end
        for _, step in ipairs({ { "selector", step_selector }, { "decoy", step_decoy }, { "skills", step_skills } }) do
            local ok, err = pcall(step[2], c)
            if not ok then log("pump: step", step[1], "failed:", err) end
        end
        local cur = c.selector:get_field("CurrentSelector")
        log("pump: current selector", cur and cur:get_type_definition():get_full_name() or "nil", "weapon job", tostring(c.chara:call("getWeaponJob")))
        PT.state.pending = nil
        PT.state.ctx = c
        PT.state.ready_t = os.clock()
        log("=== enable done")
    end
end

function PT.disable()
    PT.enabled = false
    PT.user_disabled = true -- auto-enable stays off until the next launch (or PT.enable() by hand)
    pcall(PT.restore_weapon)
    local c = ctx()
    if c then
        if PT.state.alarum_stop then pcall(V.request, c, "UpperBodyDefault", 1) end
        if PT.state.trickster_pack and c.dm then pcall(function() c.dm:call("removeDecisionPack(app.DecisionPack)", PT.state.trickster_pack) end) end
        if PT.state.mage_pack and c.dm then pcall(function() c.dm:call("removeDecisionPack(app.DecisionPack)", PT.state.mage_pack) end) end
        for _, r in ipairs(PT.state.actno_restore or {}) do pcall(function() r.ap:set_field("_Pack", r.old) end) end
        if PT.state.own_decoy_handler and c.job09 then pcall(function() c.job09:call("set_DecoyHandler", PT.state.own_decoy_handler) end); log("disable: pawn's own DecoyHandler restored") end
        log("vanilla pack node lists restored:", #(PT.state.actno_restore or {}))
        local okd, nd = pcall(V.drop_selector, c); log("disable: Job09 selectors removed", okd and nd or 0)
        pcall(goal_restore)
        if PT.state.band_restore then local b = PT.state.band_restore; pcall(function() b.cmd:write_float(b.off, b.lo); b.cmd:write_float(b.off + 4, b.hi) end); log("stance: vanilla band restored") end
        local back = (PT.state.prev_job and PT.state.prev_job ~= JOB09) and PT.state.prev_job or cfg.revert_job
        if back and back ~= JOB09 then
            local changer = c.human:get_field("<JobChanger>k__BackingField")
            local ok, err = pcall(function() changer:call("requestChangeJob", back) end)
            log("disable: pawn back to job", back, ok, err or "")
            -- v48b: the game's equip call refuses her old weapon while she is still a Trickster, so restore_weapon
            -- above fell back to the slot write (the menu would then show the censer as equipped). Once the job
            -- request has been applied the call is made again (V.weapon_fix_tick, from the frame hook).
            local lr = PT.last_restore
            if ok and lr and lr.how == "slot write" and cfg.equip_by_game ~= false then PT.weapon_fix = { id = lr.id, t = os.clock() + 1.0, tries = 0 } end
        end
    end
    log("=== disabled; previous job", PT.state.prev_job)
    PT.state = {}
end
function V.weapon_fix_tick()
    local w = PT.weapon_fix
    w.tries = w.tries + 1; w.t = os.clock() + 1.0
    local c = ctx(); local im = sdk.get_managed_singleton("app.ItemManager")
    if not (c and im) or w.tries > 10 then PT.weapon_fix = nil; return end
    if c.jobctx:get_field("CurrentJob") == JOB09 then return end -- the job request has not been applied yet
    PT.weapon_fix = nil
    local sd = im:call("getStorageData(System.Int32, app.Character)", w.id, c.chara)
    if not sd or sd:get_field("_ItemId") ~= w.id then return end
    local oke = pcall(function()
        im:call("setEquip(app.ItemDefine.StorageData, app.Character, app.EquipData.SlotEnum, System.Boolean, System.Boolean)", sd, c.chara, 0, false, false)
    end)
    log("disable: old weapon", w.id, "equipped again with the game's own call", oke, "main item", tostring(main_item(im, c)))
end

-- manual probes for the dev console
function PT.request(action_name, layer)
    local c = ctx(); if not c then return false end
    local ok, err = pcall(function() c.selector:call("requestAction(System.String, System.UInt32)", action_name, layer or 0) end)
    log("request", action_name, "layer", layer or 0, ok, err or "")
    return ok
end
function PT.status()
    local c = ctx(); if not c then return "no pawn" end
    local cur = c.selector:get_field("CurrentSelector")
    local dh = c.job09 and c.job09:call("get_DecoyHandler")
    local s = string.format("job=%s selector=%s job09sel=%s decoyHandler=%s decoy=%s enabled=%s",
        tostring(c.jobctx:get_field("CurrentJob")), cur and cur:get_type_definition():get_full_name() or "nil",
        tostring(find_selector(c, "app.Job09ActionSelector") ~= nil), tostring(dh ~= nil),
        tostring(dh and dh:call("get_HasInstance")), tostring(PT.enabled))
    log("status:", s)
    return s
end

-- ---------------------------------------------------------------------------------------------------------
-- fight test helpers (next window): list loaded enemies, warp the party next to one, log the pawn once a second
pos_of = function(chara) -- (declared near update_summon_gate, which uses it)
    local tf = chara and chara:call("get_Transform"); return tf and tf:call("get_Position")
end
function PT.enemies(quiet)
    local em = sdk.get_managed_singleton("app.EnemyManager")
    local list = em and em:get_field("_EnemyList")
    local n = list and list:call("get_Count") or 0
    local _, pl = player_component()
    local pp = pl and pos_of(pl)
    local out = {}
    for i = 0, n - 1 do
        local e = list:call("get_Item", i)
        local chara = e and (e:call("get_Chara") or e:get_field("<Chara>k__BackingField"))
        if chara then
            local p = pos_of(chara)
            local d = (p and pp) and math.sqrt((p.x - pp.x) ^ 2 + (p.y - pp.y) ^ 2 + (p.z - pp.z) ^ 2) or -1
            local ok, hp = pcall(function() return chara:call("get_Hp") end)
            out[#out + 1] = { idx = i, chara = chara, name = chara:get_type_definition():get_full_name(), dist = d, hp = ok and hp or -1 }
            if not quiet then log(string.format("enemy %d %s dist %.1f hp %s", i, tostring(chara:call("get_CharaID")), d, tostring(ok and hp or "?"))) end
        end
    end
    if not quiet then log("enemies loaded:", #out) end
    return out
end
-- TEST ONLY: full recovery of the Arisen (app.Character.recoverAll, listed on the type)
function PT.heal_player()
    local _, pl = player_component(); if not pl then return false end
    local ok, err = pcall(function() pl:call("recoverAll") end)
    PT.state.heals = (PT.state.heals or 0) + 1
    log("test guard: Arisen recoverAll", ok, err or "", "(heal", PT.state.heals, ")")
    return ok
end
-- warp the Arisen and the main pawn to `dist` metres from enemy `idx` (default: nearest alive)
function PT.arena(idx, dist)
    dist = dist or 12
    local list = PT.enemies()
    local pick
    for _, e in ipairs(list) do if (idx == nil and e.hp > 0 and (not pick or e.dist < pick.dist)) or e.idx == idx then pick = e end end
    if not pick then log("arena: no enemy"); return false end
    local c = ctx(); local _, pl = player_component()
    if not c or not pl then return false end
    local ep = pos_of(pick.chara); local pp = pos_of(pl)
    local dx, dz = pp.x - ep.x, pp.z - ep.z; local len = math.max(0.1, math.sqrt(dx * dx + dz * dz))
    local target = Vector3f.new(ep.x + dx / len * dist, ep.y + 0.5, ep.z + dz / len * dist)
    pcall(function() pl:call("get_Transform"):call("set_Position", target) end)
    pcall(function() c.chara:call("get_Transform"):call("set_Position", Vector3f.new(target.x + 2, target.y, target.z + 2)) end)
    log(string.format("arena: warped party %.0fm from enemy %d (%s)", dist, pick.idx, pick.name))
    return true
end
-- warp up to `n` live enemies within `maxdist` to `dist` metres around the Arisen (app.Character.warp; transforms ignore set_Position)
-- v16: `maxhp` skips stronger enemies (a low-level Arisen), `interval` seconds staggers the warps (first one now, the
-- rest from a queue served on frame), so the fight starts one enemy at a time instead of a ring at 9 m (run 19)
local bring_queue = {}
function PT.bring_enemies(n, dist, maxdist, maxhp, interval)
    n = n or 4; dist = dist or 9; maxdist = maxdist or 150
    local _, pl = player_component(); local pp = pl and pos_of(pl)
    if not pp then return 0 end
    local k = 0
    for _, e in ipairs(PT.enemies()) do
        if e.hp > 0 and e.dist < maxdist and (not maxhp or e.hp <= maxhp) and k < n then
            k = k + 1
            local ang = k * 1.3
            local target = Vector3f.new(pp.x + math.cos(ang) * dist, pp.y + 0.3, pp.z + math.sin(ang) * dist)
            if interval and interval > 0 and k > 1 then
                bring_queue[#bring_queue + 1] = { chara = e.chara, idx = e.idx, target = target, t = os.clock() + (k - 1) * interval }
                log(string.format("bring_enemies: %d (hp %s) queued, in %.0f s", e.idx, tostring(e.hp), (k - 1) * interval))
            else
                local ok, err = pcall(function() e.chara:call("warp(via.vec3, app.CharacterWarpOption)", target, 0) end)
                log("bring_enemies:", e.idx, "hp", e.hp, ok, err or "")
            end
        end
    end
    return k
end
local function bring_tick()
    if #bring_queue == 0 or os.clock() < bring_queue[1].t then return end
    local it = table.remove(bring_queue, 1)
    local ok, hp = pcall(function() return it.chara:call("get_Hp") end)
    if not ok or not hp or hp <= 0 then log("bring_enemies (queued):", it.idx, "gone, skipped"); return end
    local ok2, err = pcall(function() it.chara:call("warp(via.vec3, app.CharacterWarpOption)", it.target, 0) end)
    log("bring_enemies (queued):", it.idx, ok2, err or "")
end
-- TEST ONLY: spawn `names` (NickCore.enemySpawner names, e.g. "Goblin (weak)") `dist` m in front of the Arisen, one every
-- `interval` s, and warp each to its spot once its character exists. Needs Skill Maker's _NickCore (optional).
local spawn_queue, spawned = {}, {}
function PT.spawn_enemies(names, dist, interval)
    local sp = _G.NickCore and _G.NickCore.enemySpawner
    if not sp then log("spawn: NickCore.enemySpawner not loaded (Skill Maker core)"); return 0 end
    local _, pl = player_component(); if not pl then return 0 end
    local tf = pl:call("get_Transform"); local lp = tf:call("get_Position"); local q = tf:call("get_Rotation")
    local fx, fz = -(2 * (q.x * q.z + q.w * q.y)), -(1 - 2 * (q.x * q.x + q.y * q.y)) -- yaw 0 looks along -Z
    local len = math.max(0.01, math.sqrt(fx * fx + fz * fz)); fx, fz = fx / len, fz / len
    dist = dist or 12; interval = interval or 10
    for i, n in ipairs(names) do
        local d = dist + (i - 1) * 3
        spawn_queue[#spawn_queue + 1] = { name = n, t = os.clock() + (i - 1) * interval,
            target = Vector3f.new(lp.x + fx * d + (i - 1) * 2.5, lp.y + 0.3, lp.z + fz * d) }
    end
    log("spawn: queued", #names, "enemies", dist, "m ahead, every", interval, "s")
    return #names
end
function PT.destroy_spawns()
    local sp = _G.NickCore and _G.NickCore.enemySpawner
    if sp then pcall(function() sp.destroy_spawns() end); log("spawn: destroy_spawns") end
    spawn_queue, spawned = {}, {}
end
local function spawn_tick()
    if #spawn_queue > 0 and os.clock() >= spawn_queue[1].t then
        local sp = _G.NickCore and _G.NickCore.enemySpawner
        local it = table.remove(spawn_queue, 1)
        local ok, res = pcall(function() return sp.spawn_enemy(it.name, nil, false) end)
        log("spawn:", it.name, ok, ok and "" or tostring(res))
        if ok and res then res.target = it.target; spawned[#spawned + 1] = res; PT.spawned_any = true end
    end
    for _, s in ipairs(spawned) do
        if s.chara and not s.warped then
            s.warped = true
            local ok, err = pcall(function() s.chara:call("warp(via.vec3, app.CharacterWarpOption)", s.target, 0) end)
            log("spawn: warped", s.name, "to its spot", ok, err or "")
        end
    end
end
local fightlog_on, fightlog_t = false, 0
function PT.fightlog(on) fightlog_on = on ~= false; fightlog_t = 0; log("fightlog", fightlog_on) end
local function fightlog_tick()
    if not fightlog_on or os.clock() - fightlog_t < 1.0 then return end
    fightlog_t = os.clock()
    local c = PT.state.ctx or ctx(); if not c then return end
    local am = c.chara:call("get_ActionManager")
    local list = am and am:get_field("CurrentActionList"); local items = list and list:get_field("_items")
    local act = items and items[0] and tostring(items[0]:get_field("Name")) or "?"
    local pm = sdk.get_managed_singleton("app.PawnManager")
    local bc = pm and pm:call("get_BattleController")
    local dh = c.job09 and c.job09:call("get_DecoyHandler")
    local dm = c.dm and c.dm:get_field("<DecisionModule>k__BackingField")
    local last = dm and dm:get_field("_LastMainDecisionIndex")
    local edist = -1
    pcall(function()
        local pp = pos_of(c.chara)
        for _, e in ipairs(PT.enemies(true)) do
            if e.hp > 0 and pp then
                local p = pos_of(e.chara)
                local d = math.sqrt((p.x - pp.x) ^ 2 + (p.y - pp.y) ^ 2 + (p.z - pp.z) ^ 2)
                if edist < 0 or d < edist then edist = d end
            end
        end
    end)
    log(string.format("fight: battle=%s action=%s decoy=%s edist=%.1f sel=%s hp=%s", tostring(bc and bc:get_field("_CurrentState")), act,
        tostring(dh and dh:call("get_HasInstance")), edist, tostring(PT.state.current_decision), tostring(c.chara:call("get_Hp"))))
end
function PT.restore_weapon()
    local c = ctx(); local im = sdk.get_managed_singleton("app.ItemManager")
    local id = PT.state.prev_main_item or PT.prev_main_item
    if not (c and im and id) then log("restore_weapon: nothing recorded"); return false end
    local sd = im:call("getStorageData(System.Int32, app.Character)", id, c.chara)
    if not sd or sd:get_field("_ItemId") ~= id then log("restore_weapon: item", id, "not in pawn storage"); return false end
    local how = "setEquip"
    local ok, err = pcall(function()
        local done = false
        if cfg.equip_by_game ~= false then -- v48b: the game's own equip call first (see step_weapon)
            local oke = pcall(function()
                im:call("setEquip(app.ItemDefine.StorageData, app.Character, app.EquipData.SlotEnum, System.Boolean, System.Boolean)", sd, c.chara, 0, false, false)
            end)
            done = oke and main_item(im, c) == id
        end
        if not done then
            how = "slot write"
            local eq = im:call("getEquipData(app.Character)", c.chara):get_field("Data"):get_field("Equips")
            eq[0] = sd; sd:set_field("_IsEquipped", true); sd:set_field("_EquipSlot", 0)
        end
        im:call("applyEquipDataForCharacter(app.Character)", c.chara)
    end)
    log("restore_weapon", id, "(" .. how .. ")", ok, err or "")
    PT.last_restore = { id = id, how = how }
    return ok
end

-- ---------------------------------------------------------------------------------------------------------
-- GUI (run 21, 2026-11-08): the pawn pages of the menus ask the static app.GUIBase.isDispEnableJob(JobEnum) whether a
-- vocation may be shown for a pawn; it is true for Job01..06 and false for Job09, which is why the Status page drew the
-- "?" icon (UV pattern 10), no name and an empty skill list for a Trickster pawn. Answering true for Job09 makes the
-- same page draw the Trickster crest (pattern 8), the name and the 13 skill rows through the game's own code.
-- (A GUI hook runs on the main thread: not the AI-think-thread hooks that crashed in run 11.)
if cfg.ui_fix ~= false then
    local ok, err = pcall(function()
        local m = sdk.find_type_definition("app.GUIBase"):get_method("isDispEnableJob")
        hook(m, function(args) thread.get_hook_storage().job = sdk.to_int64(args[2]) & 0xff end, function(retval)
            if thread.get_hook_storage().job == JOB09 and (sdk.to_int64(retval) & 0xff) == 0 then
                PT.state.ui_fix_hits = (PT.state.ui_fix_hits or 0) + 1
                return sdk.to_ptr(1)
            end
            return retval
        end)
    end)
    log("ui: isDispEnableJob(Job09) -> true hook", ok, err or "")
    -- app.GUIBase.JobIconRef.setup(JobEnum) maps Job09 to UV pattern 10 (the "?" cell) wherever a pawn's job icon is
    -- drawn (Status page, character tab, party list, HUD); the Trickster crest is pattern 8 (3 Thief, 7 Magick Archer,
    -- 9 Warfarer, checked on screen in run 21).
    local ok2, err2 = pcall(function()
        hook(sdk.find_type_definition("app.GUIBase.JobIconRef"):get_method("setup(app.Character.JobEnum)"), function(args)
            local hs = thread.get_hook_storage(); hs.this = sdk.to_managed_object(args[2]); hs.job = sdk.to_int64(args[3]) & 0xff
        end, function(retval)
            local hs = thread.get_hook_storage()
            if hs.job == JOB09 and hs.this then
                local tex = hs.this:get_field("Tex")
                if tex and tex:call("get_UVPatternNo") == 10 then tex:call("set_UVPatternNo", cfg.ui_icon_pattern or 8); PT.state.ui_icon_hits = (PT.state.ui_icon_hits or 0) + 1 end
            end
            return retval
        end)
    end)
    log("ui: JobIconRef.setup(Job09) pattern 10 -> " .. tostring(cfg.ui_icon_pattern or 8) .. " hook", ok2, err2 or "")
    -- the job menus' shared data: JobInformationParam._EnablePawn is false for Job09 (pawn side of the guild / job lists).
    -- The loaded instance sits in the menus' JobInfoData field (create_userdata on the .user path returns an empty object).
    local function fix_jobinfo(gui, where)
        local jd = gui and (gui:get_field("JobInfoData") or gui:get_field("JobInformationData")); local params = jd and jd:get_field("_Params")
        for i = 0, (params and params:get_size() or 0) - 1 do
            local e = params:get_element(i)
            if e and e:get_field("_JobID") == JOB09 and not e:get_field("_EnablePawn") then
                e:set_field("_EnablePawn", true); PT.state.enable_pawn_sets = (PT.state.enable_pawn_sets or 0) + 1
                log("ui: JobInformationData Job09 _EnablePawn -> true (" .. where .. ")")
            end
        end
    end
    for _, spec in ipairs({ { "app.ui060601_01", "setupKeyGuide", "status" }, { "app.ui040101_00", "setupJobMenu", "guild" }, { "app.ui040101_00", "setupDisableJobs", "guild" }, { "app.ui040101_00", "setupContents", "guild" } }) do
        local ok3, err3 = pcall(function()
            local m = sdk.find_type_definition(spec[1]):get_method(spec[2])
            hook(m, function(args) pcall(fix_jobinfo, sdk.to_managed_object(args[2]), spec[3]) end, nil)
        end)
        log("ui: JobInfoData fix hook on " .. spec[1] .. "." .. spec[2], ok3, err3 or "")
    end
end

-- ---------------------------------------------------------------------------------------------------------
-- v47: rank 4-7 skills, timed ends, voice lines, soft reset
--   Latching Effigy (96)  Job09_CastPossessionSmoke through the trick slot with IsUpdateAimTarget (a bare requestAction
--                         plays the cast but nothing latches); while DecoyHandler.get_IsPossesion is true the summon slot
--                         is held (its Job09_Transfer beckon pulled the decoy back off the enemy after 2.7 s).
--   Fickle Floor (93)     Job09_CastSmokeGround, when the ground drops between her and the nearest enemy (ray casts).
--   Espial Incense (94)   Job09_CastTripFregrance holds a trance; a pawn's astral body never gets an instance, so the
--                         script moves the decoy itself (DecoyHandler.start at the enemy nearest the Arisen), then ends
--                         the trance with Job09_CastTripFregranceEnd.
--   Scented Alarum (98)   Job09_CastDetectFregrance is an upper-body action (layer 1 only) that holds and drains stamina
--                         until "UpperBodyDefault" is requested on layer 1.
V.cats = {}
V.auto = { next_try = 0, tries = 0 }
V.ray = {}
function V.request(c, name, layer)
    local ok, err = pcall(function() c.selector:call("requestAction(System.String, System.UInt32)", name, layer or 0) end)
    log("request", name, "layer", layer or 0, ok, err or "")
    return ok
end
-- a pawn talk category object by name (TalkManager's merged monologue catalog), cached
function V.category(name)
    local hit = V.cats[name]
    if hit ~= nil then return hit or nil end
    local found
    local ok, err = pcall(function()
        local tm = sdk.get_managed_singleton("app.TalkManager")
        local ents = tm:get_field("_PawnCommonTalkMonologueCatalog"):call("get_MergedCatalog"):get_field("_entries")
        for i = 0, ents:get_size() - 1 do
            local e = ents:get_element(i)
            local v = e and e:get_field("value"); local item = v and v:get_field("_Item")
            local cats = item and item:get_field("_CategoryList")
            if cats then
                local okn, n = pcall(function() return cats:get_size() end)
                if not okn or not n then n = cats:call("get_Count") end
                for k = 0, n - 1 do
                    local okc, cat = pcall(function() return cats:get_element(k) end)
                    if not okc or not cat then cat = cats:call("get_Item", k) end
                    if cat and cat:get_field("_Name") == name then found = cat; break end
                end
            end
            if found then break end
        end
    end)
    if not ok then log("voice: catalog walk failed:", err); return nil end
    V.cats[name] = found and found:add_ref() or false
    if not found then log("voice: category not found:", name) end
    return found
end
-- the pawn says a vanilla line (requestPawnTalk with the force flag: none of the game's cooldowns run, so ours does)
function V.say(c, key)
    if cfg.voice == false then return false end
    local now = os.clock()
    if PT.state.voice_t and now - PT.state.voice_t < (cfg.voice_cooldown or 45.0) then return false end
    local name = type(cfg.voice_lines) == "table" and cfg.voice_lines[key]
    if type(name) ~= "string" or name == "" then return false end
    local cat = V.category(name); if not cat then return false end
    local pm = sdk.get_managed_singleton("app.PawnManager"); local tc = pm and pm:get_field("TalkController")
    if not tc then return false end
    PT.state.voice_t = now
    local ok, r = pcall(function()
        return tc:call("requestPawnTalk(app.PawnTalkMonologueCategoryData, app.Character, app.AITarget, System.Boolean)", cat, c.chara, nil, true)
    end)
    log("voice:", key, name, ok, tostring(r))
    return ok
end
-- PawnTrickster.say("rally"): say one of the configured lines now, whatever the cooldown (panel / console test)
function PT.say(key)
    local c = PT.state.ctx; if not c then return false end
    PT.state.voice_t = nil
    return V.say(c, key)
end
function V.decoy_tf(dh)
    local inst = dh and dh:get_field("<Instance>k__BackingField")
    local go = inst and inst:call("get_GameObject")
    return go and go:call("get_Transform")
end
function V.decoy_out(dh)
    local ok, r = pcall(function() return dh:call("get_Appeared") == true and dh:call("get_Hidden") ~= true end)
    return ok and r
end
-- the keep-distance (stance) decision executes until something ends it, and an equal score never replaces it: when
-- one of our cast slots has been released and off cooldown for preempt_wait s, end the stance and hold it 3 s.
-- No pick after a preemption doubles the interval (up to 48 s) so she is not pulled out of her stance for nothing.
function V.end_stance(c)
    local ex = c.dm:get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
    local ed = ex and ex:get_field("<ExecutingDecision>k__BackingField")
    local dec = ed and ed:get_field("<Decision>k__BackingField")
    local uid = dec and dec:get_field("<UniqueID>k__BackingField")
    if not (uid and PT.state.guid_names and PT.state.guid_names[guid_key(uid)] == "stance") then return false end
    gate_slot("stance", true)
    ex:call("forceEndDecision")
    return true
end
function V.preempt(c, now)
    local st = PT.state
    if cfg.preempt == false or not c.dm then return end
    local want
    for _, name in ipairs({ "trick", "summon", "screen", "delusion", "rally", "regroup", "dust" }) do
        local w = wrappers[name]
        if w and wrapper_live[w:get_address()] and st.gate_blocked and st.gate_blocked[name] == false
            and (w:get_field("<CooldownTimer>k__BackingField") or 0) <= 1.0 then want = name; break end
    end
    if not want then st.want_since = nil; return end
    st.want_since = st.want_since or now
    if st.preempt_picks and (st.casts or 0) > st.preempt_picks then st.preempt_gap = nil; st.preempt_picks = nil end
    local gap = st.preempt_gap or (cfg.preempt_interval or 6.0)
    local wait = (want == "trick") and 0.3 or (cfg.preempt_wait or 1.5) -- the effigy's window is short
    if now - st.want_since < wait or (st.preempt_t and now - st.preempt_t < gap) then return end
    local ex = c.dm:get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
    local ed = ex and ex:get_field("<ExecutingDecision>k__BackingField")
    local dec = ed and ed:get_field("<Decision>k__BackingField")
    local uid = dec and dec:get_field("<UniqueID>k__BackingField")
    local running = uid and st.guid_names and st.guid_names[guid_key(uid)]
    local moving = last_action and (last_action == "NormalLocomotion" or last_action == "Strafe" or last_action:find("Idle", 1, true))
    if running ~= "stance" and not (want == "trick" and running == nil and moving) then return end
    if st.preempt_picks then st.preempt_gap = math.min(48.0, gap * 2) end -- the last one brought no pick
    st.preempt_t = now; st.preempt_picks = st.casts or 0; st.preempts = (st.preempts or 0) + 1
    st.stance_hold_until = now + 3.0
    gate_slot("stance", true)
    ex:call("forceEndDecision")
    log(string.format("preempt: %s ended for the %s slot (waited %.1f s, next in %.0f s at the earliest)", running or "a vanilla decision", want, now - st.want_since, st.preempt_gap or gap))
end
-- v48g: her stamina as a share of the maximum (1.0 when it cannot be read)
function V.stamina(c)
    local f = 1.0
    pcall(function()
        local sm = c.chara:get_field("<StaminaManager>k__BackingField"); local mx = sm:get_field("<MaxValue>k__BackingField")
        if mx > 0 then f = sm:get_field("<RemainingAmount>k__BackingField") / mx end
    end)
    return f
end
-- v48f: has the slot's own cooldown run out? (a blocked slot's timer is parked at 600; gate_saved keeps what was left)
function V.slot_ready(name)
    local w = live_wrapper(name); if not w then return false end
    local t = w:get_field("<CooldownTimer>k__BackingField") or 0
    if t >= 300 then local sv = gate_saved[name]; t = sv and math.max(0, sv.left - (os.clock() - sv.t) * 60.0) or 0 end
    return t <= 1.0
end
-- v48f: while the regroup rule runs, keep the stance off; end the dash at regroup_stop metres from the Arisen or
-- after regroup_seconds (the vanilla pack would run her to 1 m)
function V.regroup_tick(c, now, pdist)
    local st = PT.state
    local ex = c.dm:get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
    local ed = ex and ex:get_field("<ExecutingDecision>k__BackingField")
    local dec = ed and ed:get_field("<Decision>k__BackingField")
    local uid = dec and dec:get_field("<UniqueID>k__BackingField")
    if not (uid and st.guid_names and st.guid_names[guid_key(uid)] == "regroup") then st.regroup_t = nil; st.regroup_pd = nil; return end
    if not st.regroup_t then st.regroup_t = now; st.regroups = (st.regroups or 0) + 1; log(string.format("regroup: Rally is ready and no ally is in reach, going to the Arisen (%.0f m away)", pdist)) end
    st.stance_hold_until = math.max(st.stance_hold_until or 0, now + 3.0)
    -- this runs a few times a second and the dash covers several metres between two looks: stop one step early
    local step = st.regroup_pd and math.max(0.0, st.regroup_pd - pdist) or 0.0
    st.regroup_pd = pdist
    local arrived = pdist < (cfg.regroup_stop or 8.0) + step
    if arrived or now - st.regroup_t > (cfg.regroup_seconds or 8.0) then
        ex:call("forceEndDecision")
        log(string.format("regroup: ended %.1f s later, %.0f m from the Arisen (%s)", now - st.regroup_t, pdist, arrived and "arrived" or "time is up"))
        st.regroup_t = nil; st.regroup_pd = nil
    end
end
-- v48e: is another living party pawn within `dist` metres of position `mpos`?
function V.pawn_near(c, mpos, dist)
    local pm = sdk.get_managed_singleton("app.PawnManager"); local list = pm and pm:get_field("_PartyPawnList"); if not list then return false end
    local main = pm:get_field("_MainPawn"); local main_addr = main and main:get_address()
    for i = 0, list:call("get_Count") - 1 do
        local pw = list:call("get_Item", i)
        if pw and pw:get_address() ~= main_addr then
            local ch = pw:call("get_CachedCharacter")
            if ch and (ch:call("get_Hp") or 0) > 0 then
                local p = pos_of(ch)
                if p and math.sqrt((p.x - mpos.x) ^ 2 + (p.y - mpos.y) ^ 2 + (p.z - mpos.z) ^ 2) < dist then return true end
            end
        end
    end
    return false
end
function V.cool(key, secs, now) local t = PT.state[key]; return (not t) or (now - t > secs) end
-- one ray; returns the hit count and the first (nearest) hit position
function V.cast(ax, ay, az, bx, by, bz)
    local r = V.ray
    if not r.m then
        r.sys = sdk.get_native_singleton("via.physics.System")
        r.m = sdk.find_type_definition("via.physics.System"):get_method("castRay(via.Scene, via.physics.CastRayQuery, via.physics.CastRayResult)")
        r.res = PT.keep(sdk.create_instance("via.physics.CastRayResult"))
        r.q = PT.keep(sdk.create_instance("via.physics.CastRayQuery"))
        r.q:clearOptions(); r.q:enableAllHits(); r.q:enableNearSort()
        local fi = r.q:get_FilterInfo(); fi:set_Group(0); fi:set_Layer(2); fi:set_MaskBits(0)
        r.cpt = sdk.find_type_definition("via.physics.ContactPoint")
    end
    local scene = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")
    r.res:clear()
    r.q:call("setRay(via.vec3, via.vec3)", Vector3f.new(ax, ay, az), Vector3f.new(bx, by, bz))
    r.m:call(r.sys, scene, r.q, r.res)
    local n = r.res:get_NumContactPoints()
    if n == 0 then return 0, nil end
    local cp = r.res:call("getContactPoint(System.UInt32)", 0)
    return n, sdk.get_native_field(cp, r.cpt, "Position")
end
-- is there a drop between `p` (the pawn's feet) and `target`? Ground samples 2.5 / 4 / 5.5 m along the way: a drop is
-- ground lower than floor_drop under her feet (or none within 8 m) with nothing solid between her chest and the sample.
function V.ledge_at(p, target)
    local dx, dz = target.x - p.x, target.z - p.z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 3.0 then return false end
    dx, dz = dx / d, dz / d
    local n0, g0 = V.cast(p.x, p.y + 1.5, p.z, p.x, p.y - 8.0, p.z)
    if n0 == 0 or not g0 or math.abs(g0.y - p.y) > 1.0 then return false end -- she is not standing on ground we can see
    local drop = cfg.floor_drop or 4.0
    for _, r in ipairs({ 2.5, 4.0, 5.5 }) do
        if r < d then
            local x, z = p.x + dx * r, p.z + dz * r
            local n, g = V.cast(x, p.y + 1.5, z, x, p.y - 8.0, z)
            if n == 0 or (g and g.y < p.y - drop) then
                local nw = V.cast(p.x, p.y + 1.2, p.z, x, p.y + 1.2, z)
                if nw == 0 then return true, r end
            end
        end
    end
    return false
end
-- PawnTrickster.ledge_probe(): the ledge test in 8 directions, 6 m around the pawn (console check of the ray logic)
function PT.ledge_probe(dist)
    local c = PT.state.ctx; if not c then return "no pawn" end
    local p = c.chara:call("get_Transform"):call("get_Position"); local t = {}
    for k = 0, 7 do
        local a = k * math.pi / 4
        local ok, hit, at = pcall(V.ledge_at, p, { x = p.x + math.sin(a) * (dist or 6.0), y = p.y, z = p.z + math.cos(a) * (dist or 6.0) })
        t[#t + 1] = string.format("%d:%s", k * 45, ok and (hit and string.format("ledge@%.1f", at or 0) or "flat") or "error")
    end
    return table.concat(t, " ")
end
function V.ledge(c, now, target)
    local r = V.ray
    if r.bad or not target then return false end
    if r.t and now - r.t < 2.0 then return r.hit == true end
    r.t = now; r.hit = false
    local ok, hit, at = pcall(function() return V.ledge_at(c.chara:call("get_Transform"):call("get_Position"), target) end)
    if not ok then
        r.fails = (r.fails or 0) + 1; r.m = nil -- rebuild the query / result objects on the next call
        if r.fails >= 5 then r.bad = true end
        if r.fails == 1 or r.bad then log("floor: ray cast failed (" .. r.fails .. (r.bad and "), ledge rule off:" or "), will retry:"), hit) end
        return false
    end
    r.fails = 0
    r.hit = hit == true
    if r.hit ~= r.logged then r.logged = r.hit; log("floor: ledge", r.hit and string.format("found %.1f m ahead", at or 0) or "gone") end
    return r.hit
end
-- every 10 frames, from update_summon_gate: the trick slot (Latching Effigy, a fixed action name) is released while its
-- cast window is open; Fickle Floor and Espial Incense are requested from here
function V.trick(c, s)
    local cmd = PT.state.slot_cmds and PT.state.slot_cmds.trick
    if not cmd then return end
    local now = s.now
    local dtf = s.has and V.decoy_tf(s.dh) or nil
    local dpos = dtf and dtf:call("get_Position")
    local live, near_pawn, near_decoy, nearest, in_reach = 0, 999, 999, nil, false
    local close = 0 -- enemies within 15 m of her
    -- v48g: 35 casts sampled on 2026-11-11 (goblins). Cast while turned 15 degrees or more away from the rule's
    -- target: 0 latches in 15. So the window is "she faces an enemy in range" (it was "an enemy at 3-6 m", in any
    -- direction), and the rule only takes targets in that range (DistanceRange in make_decision). Distance did not
    -- decide the rest (a 7-10.5 m band: 1 latch in 8). Among the 20 casts that were aimed: 6 latches in 7 when the
    -- goblin stood 0.5 m or more higher than her, 2 in 13 when it was level or lower: the incense seems to fly over
    -- small enemies. v48h: both are in the rule itself now (AngleTargetDiff, and ScaleType / HeightDifference, see
    -- make_decision); with the angle condition 5 casts of 5 were aimed. Her facing is the transform's Z axis.
    local in_range, best_aim = false, 180.0
    local hx, hz = 0.0, 0.0
    pcall(function() local q = c.chara:call("get_Transform"):call("get_Rotation"); hx, hz = 2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y) end)
    local hlen = math.sqrt(hx * hx + hz * hz)
    for _, e in ipairs(s.elist) do
        if e.hp > 0 and e.dist >= 0 and e.dist < 60 then
            live = live + 1
            local p = pos_of(e.chara)
            if p and s.mpos then
                local d = math.sqrt((p.x - s.mpos.x) ^ 2 + (p.z - s.mpos.z) ^ 2)
                if d < near_pawn then near_pawn = d; nearest = p end
                if d <= 15.0 then close = close + 1 end
                if d >= (cfg.effigy_near or 3.0) and d <= (cfg.effigy_far or 10.5) and math.abs(p.y - s.mpos.y) <= (cfg.effigy_height or 4.0) then
                    in_range = true
                    if hlen > 0.01 then
                        local cosv = ((p.x - s.mpos.x) * hx + (p.z - s.mpos.z) * hz) / (d * hlen)
                        local aim = math.deg(math.acos(math.max(-1.0, math.min(1.0, cosv))))
                        if aim < best_aim then best_aim = aim end
                        if aim <= (cfg.effigy_aim_deg or 12.0) then in_reach = true end
                    end
                end
            end
            if p and dpos then
                local d = math.sqrt((p.x - dpos.x) ^ 2 + (p.z - dpos.z) ^ 2)
                if d < near_decoy then near_decoy = d end
            end
        end
    end
    local possessed = PT.state.possessed == true
    -- the window stays open 0.4 s after the last tick she faced an enemy (it flickered faster than preempt_wait)
    if in_reach then PT.state.reach_until = now + 0.4 elseif PT.state.reach_until and now < PT.state.reach_until then in_reach = true end
    local etired = (cfg.effigy_min_stamina or 0) > 0 and (s.sfrac or 1.0) < cfg.effigy_min_stamina
    local pick
    if live > 0 and not s.hold then
        local ready = cfg.effigy ~= false and has_skill(96) and s.has and not possessed and close >= (cfg.effigy_min_enemies or 2)
            and near_decoy < (cfg.effigy_range or 25.0) and V.cool("effigy_t", cfg.effigy_cooldown or 35.0, now) and V.decoy_out(s.dh) and not etired
        if ready and not in_range and near_pawn > (cfg.effigy_far or 10.5) and not s.protecting and cfg.effigy_approach ~= false and not (PT.state.approach_until and now < PT.state.approach_until)
            and V.cool("approach_t", cfg.effigy_approach_retry or 25.0, now) then
            -- the enemies crowd the decoy out of her reach: stop keeping her distance for a few seconds
            PT.state.approach_t = now; PT.state.approach_until = now + (cfg.effigy_approach_seconds or 8.0)
            local ended = V.end_stance(c)
            log(string.format("effigy: no enemy in range (nearest %.1f m from her, %.1f m from the decoy): stance held %.0f s (ended %s)", near_pawn, near_decoy, cfg.effigy_approach_seconds or 8.0, tostring(ended)))
        end
        if not ready then PT.state.approach_until = nil end
        if ready and in_reach then
            pick = 96
        elseif cfg.floor ~= false and has_skill(93) and not s.protecting and near_pawn < (cfg.floor_enemy_distance or 20.0)
            and near_pawn > 3.0 and V.cool("floor_t", cfg.floor_cooldown or 45.0, now) and V.cool("floor_try", 6.0, now) and last_action
            and (last_action == "NormalLocomotion" or last_action == "Strafe" or last_action:find("Idle", 1, true))
            and (cfg.floor_need_ledge == false or V.ledge(c, now, nearest)) then
            -- Fickle Floor is requested from Lua as well: the slot's action name is never rewritten (both crashes of
            -- 2026-11-09 came 2 s after the third rewrite of the trick command's ActionID in a session)
            PT.state.floor_try = now
            log(string.format("floor: cast requested (nearest enemy %.0f m from her)", near_pawn))
            V.request(c, SKILL_ACTION[93], 0)
        elseif cfg.espial ~= false and has_skill(94) and not s.protecting and s.has and not possessed and not s.near and near_pawn > 8.0
            and near_decoy > (cfg.espial_min_distance or 8.0) and near_decoy < 60.0 and V.cool("espial_t", cfg.espial_cooldown or 60.0, now)
            and V.cool("espial_try", 6.0, now) and last_action
            and (last_action == "NormalLocomotion" or last_action == "Strafe" or last_action:find("Idle", 1, true)) then
            -- Espial Incense is requested from Lua (the trance needs no aim target; the slot keeps its aim flag untouched)
            PT.state.espial_try = now
            log(string.format("espial: trance requested (nearest enemy %.0f m from her, %.0f m from the decoy)", near_pawn, near_decoy))
            V.request(c, SKILL_ACTION[94], 0)
        end
    end
    if pick and PT.state.trick_logged ~= pick then
        PT.state.trick_logged = pick
        log(string.format("trick: effigy window open (enemies %d, nearest to pawn %.1f m, to decoy %.1f m, facing one within %.0f degrees)", live, near_pawn, near_decoy, best_aim))
    elseif not pick then PT.state.trick_logged = nil end
    gate_slot("trick", pick == nil or not (s.battle == 2 or (cfg.cast_in_ready == true and s.battle == 1)))
end
-- Espial Incense: put the decoy next to the enemy nearest the Arisen, on its far side
function V.send_decoy(c)
    local dh = c.job09 and c.job09:call("get_DecoyHandler")
    if not dh or not dh:call("get_HasInstance") then return "no decoy" end
    local dtf = V.decoy_tf(dh); if not dtf then return "no decoy transform" end
    local best
    for _, e in ipairs(PT.enemies(true)) do
        if e.hp > 0 and e.dist >= 0 and e.dist < 40 and (not best or e.dist < best.dist) then best = e end
    end
    if not best then return "no enemy within 40 m" end
    local ep = pos_of(best.chara); if not ep then return "no enemy position" end
    local _, pl = player_component(); local pp = pl and pos_of(pl)
    local dx, dz = 0, 0
    if pp then
        local d = math.sqrt((ep.x - pp.x) ^ 2 + (ep.z - pp.z) ^ 2)
        if d > 0.5 then dx, dz = (ep.x - pp.x) / d, (ep.z - pp.z) / d end
    end
    local up = best.chara:call("get_Transform"):call("get_UniversalPosition")
    up.x = up.x + dx * 2.0; up.z = up.z + dz * 2.0
    local info = PT.keep(sdk.create_instance("app.SmokeDecoy.StartInformation"))
    info:call("set_StateName", "Start")
    info:set_field("<Position>k__BackingField", up); info:set_field("<Rotation>k__BackingField", dtf:call("get_Rotation"))
    dh:call("start", info)
    PT.state.sent_until = os.clock() + 20.0
    PT.state.espial_sends = (PT.state.espial_sends or 0) + 1
    return string.format("sent next to the enemy %.0f m from the Arisen", best.dist)
end
-- v48i: shells thrown by the script. The game's own shell data of the vocation is read (never written): the "thrown
-- smoke" shell (homing, hate type Job09_ThrowSmokeAttack = 25) is the dust ball, the shells with a
-- PossessionSmoke parameter are the Latching Effigy incense.
function V.shell_data()
    if V.sh_ud ~= nil then return V.sh_ud end
    V.sh_ud = false; V.sh_effigy = {}
    local ud = sdk.create_userdata("app.ShellParamData", "AppSystem/Shell/UserData/HumanShellParamData_Job09.user")
    local list = ud and ud:get_field("ShellParams"); local n = list and list:call("get_Count") or 0
    local en = 0
    for i = 0, n - 1 do
        local sp = list:call("get_Item", i)
        local adds = sp and sp:get_field("_ShellAdditionalParameter"); local acts = sp and sp:get_field("_ShellActionParameterList")
        local homing, kind = false, nil
        for k = 0, (acts and acts:call("get_Count") or 0) - 1 do
            local a = acts:call("get_Item", k); if a and a:get_type_definition():get_name() == "ShellActionParamHoming" then homing = true end
        end
        for k = 0, (adds and adds:call("get_Count") or 0) - 1 do
            local x = adds:call("get_Item", k); local tn = x and x:get_type_definition():get_name()
            if tn == "ShellAdditionalAddHateSmokeParameter" and x:get_field("_HateSnedType") == 25 then kind = "dust"
            elseif tn == "ShellAdditionalPossessionSmokeParameter" then kind = "effigy" end
        end
        local h = sp and sp:get_field("_ShellParamIdHash")
        if homing and kind == "dust" and not V.sh_dust then V.sh_dust = h end
        if homing and kind == "effigy" and h then V.sh_effigy[tostring(h)] = true; en = en + 1 end
    end
    if n > 0 then V.sh_ud = ud end
    log("shells: Job09 shell data", n, "entries; thrown smoke", tostring(V.sh_dust), "; effigy incense entries", en)
    return V.sh_ud
end
-- the living enemy closest to her facing, within `maxdeg` of it, between `near` and `far` metres (flat distance) and
-- at most `maxdy` metres higher or lower than her (default 8)
function V.front_enemy(c, near, far, maxdeg, maxdy)
    local tf = c.chara:call("get_Transform"); local pp = tf:call("get_Position"); local q = tf:call("get_Rotation")
    local fx, fz = 2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y) -- her facing is the transform's Z axis
    local fl = math.sqrt(fx * fx + fz * fz); if fl < 0.001 then return nil end
    local best, bang, bd
    for _, e in ipairs(PT.enemies(true)) do
        if e.hp > 0 then
            local p = pos_of(e.chara)
            if p then
                local dx, dz = p.x - pp.x, p.z - pp.z; local d = math.sqrt(dx * dx + dz * dz)
                if d >= near and d <= far and d > 0.01 and math.abs(p.y - pp.y) < (maxdy or 8.0) then
                    local ang = math.deg(math.acos(math.max(-1, math.min(1, (dx * fx + dz * fz) / (d * fl)))))
                    if ang <= maxdeg and (not bang or ang < bang) then best, bang, bd = e.chara, ang, d end
                end
            end
        end
    end
    return best, bang, bd
end
-- one shell of the Job09 data from her chest to a point `aim_h` above the target's feet, the target given to the shell
function V.throw(c, hash, target, aim_h)
    local ud = V.shell_data(); if not ud or not hash then return nil end
    local go = c.chara:call("get_GameObject"); local pp = pos_of(c.chara); local tp = pos_of(target)
    if not (go and pp and tp) then return nil end
    local sx, sy, sz = pp.x, pp.y + 1.2, pp.z
    local dx, dy, dz = tp.x - sx, (tp.y + aim_h) - sy, tp.z - sz
    local h = math.sqrt(dx * dx + dz * dz); if h < 0.5 then return nil end
    sx, sz = sx + dx / h * 0.6, sz + dz / h * 0.6
    local yaw, pitch = math.atan(dx, dz), -math.atan(dy, h) -- yaw about Y, then pitch about the local X axis (forward = +Z)
    local cy, sny, cp, snp = math.cos(yaw / 2), math.sin(yaw / 2), math.cos(pitch / 2), math.sin(pitch / 2)
    local rot = Quaternion.new(cy * cp, cy * snp, sny * cp, -sny * snp) -- w, x, y, z
    -- four request objects used in turn (kept: an object created and dropped in one frame crashes the game later)
    V.sh_infos = V.sh_infos or {}; V.sh_i = ((V.sh_i or 0) % 4) + 1
    local info = V.sh_infos[V.sh_i]
    if not info then info = PT.keep(sdk.create_instance("app.ShellRequest.ShellCreateInfo")); V.sh_infos[V.sh_i] = info end
    info:set_field("ShellParamIdHash", hash); info:set_field("TargetGameObject", target:call("get_GameObject"))
    V.sh_m = V.sh_m or sdk.find_type_definition("app.ShellManager"):get_method("requestCreateShell(via.GameObject, via.vec3, via.Quaternion, app.ShellRequest.ShellCreateInfo, app.ShellParamData, app.ShellRequest.EventCreateShellSuccess, app.ShellRequest.EventBeforeShellInstantiate)")
    local rid = V.sh_m:call(sdk.get_managed_singleton("app.ShellManager"), go, Vector3f.new(sx, sy, sz), rot, info, ud, nil, nil)
    PT.state.sh_clear = os.clock() + 1.5
    V.sh_own = { rid = rid, t = os.clock() } -- (registShell sees this one too: it is ours, not the game's)
    return rid
end
-- v48k: the effect objects of a dust swing that the effect hook noted (V.fx_cut), from the frame after their creation:
-- their effect players (the object and its children, three levels) get the opacity and play speed of the settings;
-- the ones with a life (the impact cloud, the censer's swing smoke) fade to nothing over it and are then removed
-- (via.effect.PlayerAction.Kill = 2). An entry that was not served in time is dropped untouched.
function V.fx_players(g, acc, depth)
    local ep = g:call("getComponent(System.Type)", V.ep_type); if ep then acc[#acc + 1] = ep end
    if depth < 3 then
        local ch = g:call("get_Transform"):call("get_Child")
        while ch do V.fx_players(ch:call("get_GameObject"), acc, depth + 1); ch = ch:call("get_Next") end
    end
end
function V.fx_tick(now)
    local al, sp = cfg.dust_fx_alpha or 1.0, cfg.dust_fx_speed or 1.0
    V.ep_type = V.ep_type or sdk.typeof("via.effect.EffectPlayer")
    for i = #V.fx_cut, 1, -1 do
        local it = V.fx_cut[i]; local age = now - it.t; it.n = it.n + 1
        local drop = age > 6.0 or (it.life > 0 and age > it.life + 0.5)
        if not drop and it.n >= 2 then
            local ok = pcall(function()
                if not it.eps then
                    it.eps = {}; it.base = {}; V.fx_players(it.g, it.eps, 0)
                    for k, ep in ipairs(it.eps) do
                        ep:add_ref(); it.base[k] = (ep:call("get_Color"):get_field("rgba") >> 24) & 255 -- 0xAABBGGRR
                        if sp ~= 1.0 then ep:call("set_PlaySpeed", sp) end
                    end
                end
                local f = al; if it.life > 0 then f = f * math.max(0.0, 1.0 - age / it.life) end
                if f < 1.0 then
                    for k, ep in ipairs(it.eps) do
                        local col = ep:call("get_Color"); local v = col:get_field("rgba")
                        col:set_field("rgba", (v & 0xFFFFFF) | (math.floor(it.base[k] * f) << 24)); ep:call("set_Color", col)
                    end
                end
                if it.life <= 0 then drop = true -- (the trail: set once)
                elseif age >= it.life then
                    for _, ep in ipairs(it.eps) do ep:call("set_Action", 2) end
                    drop = true; PT.state.dust_fx_cut = (PT.state.dust_fx_cut or 0) + 1
                end
            end)
            if not ok then drop = true end
        end
        if drop then table.remove(V.fx_cut, i) end
    end
end
-- hooks, set once per session at the first throw; each one returns at once outside the seconds after a throw
function V.shell_hooks()
    if V.sh_hooked then return end
    V.sh_hooked = true; V.dust_shells = {}; V.sh_type = sdk.typeof("app.Shell"); V.sh_dust_s = tostring(V.sh_dust)
    V.ch_type = sdk.typeof("app.Character"); V.fx_stack = {}
    local okh, eh = pcall(function()
        -- the game's own effigy incense leaving her hand
        hook(sdk.find_type_definition("app.ShellManager"):get_method("registShell"), function(args)
            if not PT.enabled or not PT.state.ctx then return end
            pcall(function()
                local now = os.clock()
                local eff = cfg.effigy_rethrow ~= false and PT.state.effigy_t and now - PT.state.effigy_t < 5.0 and V.sh_effigy
                local sw = V.swing_fx -- v48k: a dust swing is running
                if sw and now > sw.t then sw = nil end
                if not eff and not sw then return end
                local sh = sdk.to_managed_object(args[3]); if not sh then return end
                local rid = sh:get_field("<RequestId>k__BackingField")
                if V.sh_own and rid == V.sh_own.rid and now - V.sh_own.t < 1.0 then return end
                local ow = sh:get_field("<Owner>k__BackingField"); local pg = PT.state.ctx.chara:call("get_GameObject")
                if not (ow and pg and ow:get_address() == pg:get_address()) then return end
                local id = sh:get_field("<ShellParamId>k__BackingField"); local ids = tostring(id)
                if eff and V.sh_effigy[ids] then
                    if not PT.state.rethrow_t or now - PT.state.rethrow_t > 2.0 then
                        PT.state.rethrow_t = now; PT.state.rethrow_hash = id; PT.state.rethrow_rid = rid; PT.state.rethrow_due = now -- thrown from V.tick, not from inside the game's shell registration
                    end
                elseif sw and ids == V.sh_dust_s then
                    -- v48l: the game's own thrown smoke of the dust action leaving the hand: that is the moment of the
                    -- ball. The game's one (thrown straight ahead, no target) is taken out; V.tick throws the script's.
                    if PT.state.dust_due and not PT.state.dust_release then
                        PT.state.swing_kill = PT.state.swing_kill or {}; PT.state.swing_kill[#PT.state.swing_kill + 1] = rid
                        PT.state.dust_release = now; PT.state.dust_releases = (PT.state.dust_releases or 0) + 1
                    end
                elseif sw and cfg.dust_swing_shell ~= true and not (V.sh_effigy and V.sh_effigy[ids]) then
                    -- v48k: the swing's own smoke cloud (seen: parameter id 1754224672, one a swing). Taken out by
                    -- V.tick on the next frame, not from inside the game's shell registration.
                    PT.state.swing_kill = PT.state.swing_kill or {}; PT.state.swing_kill[#PT.state.swing_kill + 1] = rid
                end
            end)
        end, function(r) return r end)
        -- the dust ball's hit: the game computes 0 damage for a smoke shell; the hit's damage is written after that
        hook(sdk.find_type_definition("app.HitController"):get_method("calcDamageValue"), function(args)
            V.dust_info = nil
            if not V.dust_live or os.clock() > V.dust_live then return end
            pcall(function()
                local info = sdk.to_managed_object(args[3]); if not info then return end
                local ow = info:get_field("<AttackOwnerObject>k__BackingField"); if not ow or ow:get_address() ~= V.dust_owner then return end
                local ag = info:get_field("<AttackGameObject>k__BackingField") -- the shell's own GameObject
                local sh = ag and ag:call("getComponent(System.Type)", V.sh_type)
                if not sh or tostring(sh:get_field("<ShellParamId>k__BackingField")) ~= V.sh_dust_s then return end
                local a = sh:get_address(); local now = os.clock()
                if V.dust_shells[a] and now - V.dust_shells[a] < 10.0 then return end -- one hit per ball
                V.dust_shells[a] = now; V.dust_info = info
                -- v48j: the enemy that was hit, for V.fool_tick (the Character on the damaged object, else the one she threw at)
                local dg = info:get_field("<DamageGameObject>k__BackingField")
                local ch = dg and dg:call("getComponent(System.Type)", V.ch_type)
                if not ch then
                    local dh = info:get_field("<DamageOwnerHitController>k__BackingField"); local g2 = dh and dh:call("get_GameObject")
                    ch = g2 and g2:call("getComponent(System.Type)", V.ch_type)
                end
                PT.state.fool_src = ch and "hit" or "thrown"
                if not ch and V.dust_thrown and now - V.dust_thrown.t < 4.0 then ch = V.dust_thrown.ch end
                if ch then PT.state.fool_q = PT.state.fool_q or {}; PT.state.fool_q[#PT.state.fool_q + 1] = ch end
            end)
        end, function(r)
            local info = V.dust_info
            if info then
                V.dust_info = nil
                pcall(function() info:set_field("Damage", V.dust_dmg or 0); PT.state.dust_hits = (PT.state.dust_hits or 0) + 1 end)
            end
            return r
        end)
        -- the hate the thrown smoke adds for its thrower (HateSendTypeID 25): left out for the pawn
        local hm
        for _, x in ipairs(sdk.find_type_definition("app.HateSystem"):get_methods()) do
            if x:get_name() == "addHateParam" and x:get_num_params() == 3 and x:get_param_types()[2]:get_name() ~= "HateSendTypeID" then hm = x end
        end
        if hm then
            hook(hm, function(args)
                if cfg.dust_no_aggro == false or not V.dust_p25 or not V.dust_live or os.clock() > V.dust_live then return end
                local skip = false
                pcall(function()
                    if sdk.to_int64(args[4]) ~= V.dust_p25 then return end
                    local g = sdk.to_managed_object(args[3])
                    if g and g:get_address() == V.dust_owner then skip = true; PT.state.dust_hate_skips = (PT.state.dust_hate_skips or 0) + 1 end
                end)
                if skip then return sdk.PreHookResult.SKIP_ORIGINAL end
            end, function(r) return r end)
        end
        V.sh_hate_hook = hm ~= nil
        -- v48j: a fooled enemy forgets the party's pawns at the moment it sorts its ranking
        local ur = sdk.find_type_definition("app.HateSystem"):get_method("updateHateRanking")
        if ur then
            hook(ur, function(args)
                local fools = PT.state.fools; if not fools then return end
                pcall(function()
                    local hs = sdk.to_managed_object(args[2]); local a = hs and hs:get_address(); local set = PT.state.fool_gos
                    if not a or not set then return end
                    for _, f in pairs(fools) do if f.hsa == a then V.fool_wipe(hs, set); PT.state.fool_sorts = (PT.state.fool_sorts or 0) + 1; return end end
                end)
            end, function(r) return r end)
        end
        V.sh_rank_hook = ur ~= nil
        -- v48j: the size of the ball's effects. Neither the shell's ExpandRate nor its transform's scale changes the
        -- impact cloud; the effect objects themselves are scaled where the game creates them: while one of the
        -- shell's effect requests runs for a dust ball, what EffectManager.createEffectInternal returns gets its local
        -- scale multiplied (dust_hit_scale for the impact, dust_trail_scale for the rest).
        for _, m in ipairs(sdk.find_type_definition("app.Shell"):get_methods()) do
            local nm = m:get_name()
            if nm == "requestHitEffect" or nm == "requestTerrainHitEffect" or nm == "requestEffect" or nm == "requestOmenEffect" then
                local kind = (nm == "requestHitEffect" or nm == "requestTerrainHitEffect") and "hit" or "trail"
                hook(m, function(args)
                    local stk = V.fx_stack; local mine = false
                    if V.dust_live and os.clock() <= V.dust_live then
                        pcall(function()
                            local sh = sdk.to_managed_object(args[2]); local ow = sh and sh:get_field("<Owner>k__BackingField")
                            mine = (ow and ow:get_address() == V.dust_owner and tostring(sh:get_field("<ShellParamId>k__BackingField")) == V.sh_dust_s) and true or false
                        end)
                    end
                    stk[#stk + 1] = mine and (V.fx_kind or kind) or false -- (the outer request's kind is kept: the impact asks requestEffect for its parts)
                    if mine then V.fx_kind = stk[#stk] end
                end, function(r)
                    local stk = V.fx_stack; stk[#stk] = nil
                    local k = nil
                    for i = #stk, 1, -1 do if stk[i] then k = stk[i]; break end end
                    V.fx_kind = k
                    return r
                end)
            end
        end
        for _, m in ipairs(sdk.find_type_definition("via.effect.script.EffectManager"):get_methods()) do
            if m:get_name() == "createEffectInternal" then
                hook(m, function(args) end, function(ret)
                    local kind = V.fx_kind; local sw = V.swing_fx
                    if not kind and not sw then return ret end
                    pcall(function()
                        -- v48k: besides the ball's own effects (kind), the censer's smoke of the dust swing: the
                        -- effects named after the pawn that are made under the pawn or its weapon while the swing runs
                        local now = os.clock()
                        if sw and now > sw.t then V.swing_fx = nil; sw = nil end
                        if not kind and not sw then return end
                        local arr = sdk.to_managed_object(ret)
                        for i = 0, (arr and arr:get_size() or 0) - 1 do
                            local g = arr:get_element(i)
                            if g then
                                local f, life, what = nil, 0, nil
                                if kind == "hit" then f = cfg.dust_hit_scale or 0.4; life = cfg.dust_hit_life or 0.5; what = "dust_fx"
                                elseif kind then f = cfg.dust_trail_scale or 1.0; what = "dust_fx"
                                elseif tostring(g:call("get_Name")) == sw.name then
                                    local par = g:call("get_Transform"):call("get_Parent")
                                    local pn = par and tostring(par:call("get_GameObject"):call("get_Name")) or ""
                                    if "effect_" .. pn == sw.name or pn:find("^wp") then f = cfg.dust_swing_scale or 0.15; life = cfg.dust_swing_life or 0.3; what = "dust_fx_swing" end
                                end
                                if f then
                                    if f ~= 1.0 then
                                        local tf = g:call("get_Transform"); local sc = tf:call("get_LocalScale")
                                        tf:call("set_LocalScale", Vector3f.new(sc.x * f, sc.y * f, sc.z * f))
                                    end
                                    PT.state[what] = (PT.state[what] or 0) + 1
                                    -- (its effect player has no resource yet at this point: opacity, speed and the
                                    -- early end are V.fx_tick's, from the next frame on)
                                    V.fx_cut = V.fx_cut or {}
                                    if #V.fx_cut < 40 then g:add_ref(); V.fx_cut[#V.fx_cut + 1] = { g = g, t = now, life = life, n = 0 } end
                                end
                            end
                        end
                    end)
                    return ret
                end)
            end
        end
    end)
    log("shells: hooks", okh and "set" or ("failed: " .. tostring(eh)), "hate hook", tostring(V.sh_hate_hook))
end
-- the name of the script's rule the pawn is executing now (nil: a vanilla decision or none)
function V.running(c)
    local name
    pcall(function()
        local ex = c.dm:get_field("<DecisionModule>k__BackingField"):get_field("<DecisionExecutor>k__BackingField")
        local ed = ex and ex:get_field("<ExecutingDecision>k__BackingField")
        local dec = ed and ed:get_field("<Decision>k__BackingField")
        local uid = dec and dec:get_field("<UniqueID>k__BackingField")
        name = uid and PT.state.guid_names and PT.state.guid_names[guid_key(uid)]
    end)
    return name
end
function V.dust_damage(c)
    if (cfg.dust_damage or 0) > 0 then return cfg.dust_damage end
    local lv = 1
    pcall(function() lv = c.chara:call("get_Context"):get_field("HumanStatusContext"):get_field("_Level") or 1 end)
    return (cfg.dust_damage_base or 20.0) + (cfg.dust_damage_level or 5.0) * lv
end
-- how far a thrown smoke shell gets before it dies (m). Measured: 13 m and more at 40 FPS, 6.3-7.2 m at 30 FPS (the
-- game moves shells per frame): reach = shell_reach_40 x (fps / 40)^2, with a margin, never more than dust_far.
function V.reach()
    local f = PT.state.fps or 60.0
    return math.max(3.0, math.min(cfg.dust_far or 14.0, (cfg.shell_reach_40 or 13.0) * (f / 40.0) ^ 2 * 0.9))
end
-- no living enemy within dust_safe metres of her, and one within the ball's reach
function V.dust_safe(c)
    local ok, safe = pcall(function()
        local pp = pos_of(c.chara); local lim = cfg.dust_safe or 3.5; local reach = V.reach(); local inreach = false
        for _, e in ipairs(PT.enemies(true)) do
            if e.hp > 0 then local p = pos_of(e.chara)
                if p then local d2 = (p.x - pp.x) ^ 2 + (p.z - pp.z) ^ 2
                    if math.abs(p.y - pp.y) < 3.0 and d2 < lim * lim then return false end
                    if d2 <= reach * reach and math.abs(p.y - pp.y) < (cfg.dust_height or 3.0) then inreach = true end
                end
            end
        end
        return inreach
    end)
    return ok and safe
end
-- v48j: enemies hit by a dust ball are fooled for dust_fool_seconds: what they hold against each party pawn (the
-- temporary and the kept part of its app.HateCalculator in the enemy's ranking) is written to 0 every frame; the
-- distance part too. The game adds the kept part back all the time (the "pawn bias", 100), so the wipe runs every
-- frame and again right before the enemy sorts its ranking (pre-hook on HateSystem.updateHateRanking). Two weaker
-- versions were measured first: HateSystem.setCustomRate (the game puts the rate back to 1 every frame; the pawn
-- stayed on top in a third of the samples) and a once-a-frame wipe of the temporary and kept parts only (one goblin
-- 100 % on the decoy, the next one mostly on the pawn).
-- The Arisen is left alone: with a decoy out, the enemy's entry for the Arisen IS the decoy.
-- Only while a decoy is out: without one the enemy would turn to the Arisen.
-- every calculator of this enemy whose target is a party pawn: nothing held against it (temporary, kept, distance)
function V.fool_wipe(hs, set)
    local list = hs:get_field("_HateCalculators"); local n = list and list:call("get_Count") or 0
    for i = 0, n - 1 do
        local el = list:call("get_Item", i); local o = el and el:call("get_TargetObj")
        if o and set[o:get_address()] and not el:call("get_TargetSmokeDecoy") then
            el:set_field("_TargetHateValue_Temp", 0.0); el:set_field("_TargetHateValue_NotForget", 0.0); el:set_field("_TargetHateValue_Distance", 0.0)
        end
    end
end
function V.fool_tick(c, now)
    local st = PT.state
    local q = st.fool_q
    if q and #q > 0 then
        st.fool_q = nil
        for _, ch in ipairs(q) do
            if cfg.dust_fool ~= false and st.has_decoy then
                local big = false; pcall(function() big = (max_hp(ch) or 0) > (cfg.big_enemy_hp or 5000) end)
                local hs = ch:get_field("<HateSystem>k__BackingField")
                if hs and (not big or cfg.dust_fool_big == true) then
                    st.fools = st.fools or {}
                    local a = ch:get_address()
                    if not st.fools[a] then st.dust_fooled = (st.dust_fooled or 0) + 1 end
                    st.fools[a] = { ch = ch, hs = hs, hsa = hs:get_address(), t_end = now + (cfg.dust_fool_seconds or 6.0) }
                end
            end
        end
    end
    if not st.fools then return end
    if not st.fool_gos or now - (st.fool_gos_t or 0) > 1.0 then
        local gos = {} -- addresses of the party pawns' GameObjects
        pcall(function()
            local pm = sdk.get_managed_singleton("app.PawnManager"); local list = pm and pm:get_field("_PartyPawnList")
            for i = 0, (list and list:call("get_Count") or 0) - 1 do
                local pw = list:call("get_Item", i); local pch = pw and pw:call("get_CachedCharacter"); local g = pch and pch:call("get_GameObject")
                if g then gos[g:get_address()] = true end
            end
        end)
        st.fool_gos = gos; st.fool_gos_t = now
    end
    local left = 0; local set = st.fool_gos
    for a, f in pairs(st.fools) do
        local alive = false; pcall(function() alive = f.ch:call("get_Hp") > 0 end)
        if not alive or now > f.t_end or not st.has_decoy then st.fools[a] = nil
        else
            left = left + 1
            pcall(V.fool_wipe, f.hs, set)
        end
    end
    if left == 0 then st.fools = nil end
end
-- one frame of a dust swing: she is turned to the target, and the ball leaves once she faces it (true = done)
function V.dust_step(c, now)
    local st = PT.state
    local t = st.dust_target
    if t then local alive = false; pcall(function() alive = t:call("get_Hp") > 0 end); if not alive then t = nil end end
    if not t then t = V.front_enemy(c, (cfg.dust_near or 4.0) - 2.0, V.reach() + 0.5, 180.0, cfg.dust_height or 3.0); st.dust_target = t end
    if not t then if now >= st.dust_until then st.dust_blank = (st.dust_blank or 0) + 1; return true end return false end
    local tf = c.chara:call("get_Transform"); local pp = tf:call("get_Position"); local q = tf:call("get_Rotation"); local tp = pos_of(t)
    if not tp then return false end
    local yaw = math.atan(2 * (q.x * q.z + q.w * q.y), 1 - 2 * (q.x * q.x + q.y * q.y)) -- her facing is the transform's Z axis
    local dx, dz = tp.x - pp.x, tp.z - pp.z; local d = math.sqrt(dx * dx + dz * dz)
    local diff = (math.deg(math.atan(dx, dz) - yaw) + 540.0) % 360.0 - 180.0
    local dt = math.max(0.0, math.min(0.1, now - (st.dust_turn_t or now))); st.dust_turn_t = now
    local rate = cfg.dust_turn_rate or 420.0
    if rate > 0 and math.abs(diff) > 2.0 then
        local step = math.max(-rate * dt, math.min(rate * dt, diff)); local y = yaw + math.rad(step)
        tf:call("set_Rotation", Quaternion.new(math.cos(y / 2), 0, math.sin(y / 2), 0)); diff = diff - step
    end
    if now < st.dust_due then return false end
    local last = now >= st.dust_until
    if math.abs(diff) > (cfg.dust_face_deg or 25.0) and not last then return false end
    if math.abs(diff) > 70.0 then st.dust_blank = (st.dust_blank or 0) + 1; return true end
    V.dust_fire(c, t, math.abs(diff), d)
    return true
end
function V.dust_fire(c, target, ang, d)
    local st = PT.state
    if not V.shell_data() or not V.sh_dust then return end
    V.shell_hooks()
    local now = os.clock()
    V.dust_dmg = V.dust_damage(c); V.dust_live = now + 6.0
    V.dust_thrown = { ch = target, t = now }; V.fx_stack = {}; V.fx_kind = nil
    V.dust_owner = c.chara:call("get_GameObject"):get_address()
    pcall(function() local p25 = sdk.get_managed_singleton("app.HateManager"):call("getSendHateParam(app.HateSendTypeID)", 25); V.dust_p25 = p25 and p25:get_address() end)
    for a, t in pairs(V.dust_shells) do if now - t > 15.0 then V.dust_shells[a] = nil end end
    local rise = 0.0; pcall(function() rise = pos_of(target).y - pos_of(c.chara).y end)
    local rid = V.throw(c, V.sh_dust, target, (cfg.dust_aim_height or 0.7) + math.max(0.0, math.min(2.0, rise)) * 0.3) -- (a ball aimed low at a target up a slope hit the ground half way)
    if rid then
        st.dust_shots = (st.dust_shots or 0) + 1
        if cfg.dust_log ~= false and (st.dust_shots <= 5 or st.dust_shots % 20 == 0) then
            log(string.format("dust: ball %d thrown at an enemy %.1f m away, %.0f degrees off her facing, damage %.0f (hits so far %d, hate entries left out %d, enemies fooled %d)", st.dust_shots, d, ang, V.dust_dmg, st.dust_hits or 0, st.dust_hate_skips or 0, st.dust_fooled or 0))
        end
    end
end
-- Latching Effigy: the game's incense just left her hand (seen by the registShell hook). The same shell once more,
-- aimed at the legs of the enemy she faces: the game aims at a point that is above a goblin's head.
function V.effigy_rethrow(c)
    local st = PT.state
    if not V.shell_data() then return end
    local target, ang, d = V.front_enemy(c, 1.5, math.min((cfg.effigy_far or 10.5) + 4.0, V.reach() + 0.5), 60.0, cfg.effigy_height or 4.0)
    if not target then log(string.format("effigy: no enemy in front of her within %.1f m (the reach of a thrown shell at %.0f FPS): the game's incense is left as it is", V.reach(), st.fps or 60)); return end
    -- the game's incense goes: when it lands next to the target a moment after ours latched, it moves the decoy to
    -- where it landed and the latch is over (latches of 0.5-0.7 s in the first fights with two incenses)
    local gone = false
    if cfg.effigy_replace ~= false and st.rethrow_rid then
        gone = pcall(function() sdk.get_managed_singleton("app.ShellManager"):call("requestDestroyShell(System.Int32)", st.rethrow_rid) end)
    end
    local rid = V.throw(c, st.rethrow_hash, target, cfg.effigy_aim_height or 0.5)
    st.rethrows = (st.rethrows or 0) + 1
    log(string.format("effigy: incense thrown by the script at the enemy %.1f m away, %.0f degrees off her facing, aimed %.1f m above its feet (request %s; the game's incense taken out: %s)", d, ang, cfg.effigy_aim_height or 0.5, tostring(rid), tostring(gone)))
end
function V.on_action(c, act)
    local now = os.clock()
    if act ~= ACT.dust then V.swing_fx = nil end
    PT.state.act_now = act -- (update_summon_gate is defined above the script's last_action local)
    if act:find("Job09_", 1, true) == 1 and not act:find("End", 1, true) then PT.state.casts = (PT.state.casts or 0) + 1 end
    if act == SKILL_ACTION[96] or act == "Job09_CastPossessionSmokeEx" then PT.state.effigy_t = now
    elseif act == SKILL_ACTION[93] then PT.state.floor_t = now
    elseif act == SKILL_ACTION[94] then PT.state.espial_t = now; PT.state.espial_start = now; PT.state.espial_sent = false; PT.state.espial_end_t = nil
    elseif act == SKILL_ACTION[99] then PT.state.delusion_start = now; PT.state.delusion_end_t = nil; V.say(c, "delusion")
    elseif act == ACT.heavy or act == SKILL_ACTION[95] then
        if act == ACT.heavy then PT.state.summon_act_t = now end
        V.say(c, "taunt")
    elseif act == SKILL_ACTION[97] then V.say(c, "rally")
    elseif act == SKILL_ACTION[92] then if PT.state.arisen_trouble then V.say(c, "screen") end end
    -- (a pick is only seen when its decision ends, so the slot is read from the decision she is executing now)
    local forced = PT.state.dust_force and now < PT.state.dust_force -- (PT.dust_test: a swing asked for by a test)
    if act == ACT.dust and PT.state.decs and PT.state.decs.dust and (forced or V.running(c) == "dust") then
        PT.state.dust_force = nil; PT.state.dust_release = nil
        if ACT.dust == ACT.normal then
            PT.state.dust_due = now + (cfg.dust_delay or 0.35); PT.state.dust_until = now + (cfg.dust_window or 1.1)
        else
            -- v48l: the ball goes when the game's own thrown smoke of this action is registered (the registShell hook
            -- sets dust_release); until then the pawn is turned to its target
            PT.state.dust_due = now + 99.0; PT.state.dust_until = now + (cfg.dust_release_wait or 1.6)
        end
        PT.state.dust_target = nil; PT.state.dust_turn_t = now; PT.state.dust_swings = (PT.state.dust_swings or 0) + 1
        pcall(function()
            V.shell_data(); V.shell_hooks()
            local go = c.chara:call("get_GameObject")
            -- v48k: for 2.2 s the censer's smoke of this swing is made small and short, and the swing's own smoke shell is taken out
            V.swing_fx = { t = now + 2.2, name = "effect_" .. tostring(go:call("get_Name")) }
            -- v48l: the game's own ball of this swing counts as a dust ball from its first frame (its effects, no hate)
            V.dust_live = now + 6.0; V.dust_owner = go:get_address()
        end)
    end
end
-- For tests and captures (tools/lua/dust_now.lua): the dust swing now, whatever the gates say: the censer swing where
-- the pawn stands, the turn to an enemy in reach and the ball, exactly as when the game picks the dust rule.
function PT.dust_test()
    local c = PT.state.ctx; if not c then return false end
    PT.state.dust_force = os.clock() + 1.0
    V.request(c, ACT.dust, 0)
    return true
end
-- per-frame timers
function V.tick(c)
    local st = PT.state; local now = os.clock()
    st.vtick = (st.vtick or 0) + 1
    if st.vtick % 10 == 0 and c.job09 then
        local dh = c.job09:call("get_DecoyHandler")
        local poss = false
        if dh and dh:call("get_HasInstance") then poss = dh:call("get_IsPossesion") == true end
        if poss ~= (st.possessed == true) then
            if poss then st.possessed_t = now; log("effigy: the decoy latched onto an enemy; summon/beckon held"); V.say(c, "effigy")
            else log(string.format("effigy: released after %.1f s", now - (st.possessed_t or now))) end
            st.possessed = poss
        end
    end
    if st.espial_start then
        if last_action ~= SKILL_ACTION[94] then
            st.espial_start = nil
        else
            local dt = now - st.espial_start
            if not st.espial_sent and dt >= 1.2 then
                st.espial_sent = true
                local ok, r = pcall(V.send_decoy, c)
                log("espial: decoy", ok and r or ("error " .. tostring(r)))
            end
            if dt >= (cfg.espial_seconds or 3.5) and (not st.espial_end_t or now - st.espial_end_t > 0.7) then
                st.espial_end_t = now; V.request(c, "Job09_CastTripFregranceEnd", 0)
            end
        end
    end
    if st.delusion_start then
        if last_action ~= SKILL_ACTION[99] then
            st.delusion_start = nil
        elseif (now - st.delusion_start >= (cfg.delusion_seconds or 5.0) or V.stamina(c) < (cfg.delusion_stop_stamina or 0.15)) and (not st.delusion_end_t or now - st.delusion_end_t > 0.7) then
            -- v48g: also ended when her stamina runs low (one Delusion held 8 s took her from 100 % to -3 %)
            st.delusion_end_t = now; V.request(c, "Job09_CastSmokeDragonEnd", 0)
        end
    end
    if st.battle == 2 then st.calm_since = nil elseif not st.calm_since then st.calm_since = now end
    do local dt = now - (st.tick_t or now); st.tick_t = now
        if dt > 0.004 and dt < 0.5 then st.fps = (st.fps or 60.0) * 0.95 + (1.0 / dt) * 0.05 end end
    if st.dust_due then
        if last_action ~= ACT.dust then st.dust_due = nil -- the swing was cut
        else
            if st.dust_release then st.dust_release = nil; st.dust_due = now; st.dust_until = now end -- v48l: the game's throw just left the hand: the ball now
            local okd, done = pcall(V.dust_step, c, now)
            if not okd and not st.dust_err then st.dust_err = true; log("dust error:", done) end
            if not okd or done or now >= st.dust_until + 0.1 then st.dust_due = nil; st.dust_target = nil end
        end
    end
    if st.rethrow_due and now >= st.rethrow_due then
        st.rethrow_due = nil
        local okr, er = pcall(V.effigy_rethrow, c); if not okr and not st.rethrow_err then st.rethrow_err = true; log("effigy rethrow error:", er) end
    end
    if (st.fool_q and #st.fool_q > 0) or st.fools then
        local okf, ef = pcall(V.fool_tick, c, now); if not okf and not st.fool_err then st.fool_err = true; log("dust fool error:", ef) end
    end
    if st.swing_kill then -- v48k: the swing's own smoke shells, the frame after the game registered them
        local q = st.swing_kill; st.swing_kill = nil
        for _, rid in ipairs(q) do
            pcall(function() sdk.get_managed_singleton("app.ShellManager"):call("requestDestroyShell(System.Int32)", rid) end)
            st.dust_swing_shells = (st.dust_swing_shells or 0) + 1
        end
    end
    if V.fx_cut and #V.fx_cut > 0 then
        local okx, ex = pcall(V.fx_tick, now); if not okx and not st.fx_err then st.fx_err = true; log("dust effects error:", ex) end
    end
    if st.sh_clear and now >= st.sh_clear then -- the kept request objects do not hold on to an enemy
        st.sh_clear = nil
        for _, info in ipairs(V.sh_infos or {}) do pcall(function() info:set_field("TargetGameObject", nil) end) end
    end
    if st.alarum_stop then
        if now >= st.alarum_stop or st.battle == 2 then st.alarum_stop = nil; V.request(c, "UpperBodyDefault", 1); log("alarum: stopped") end
    elseif now >= (st.alarum_check or 0) then
        st.alarum_check = now + 1.0
        if cfg.alarum ~= false and st.ready_t and st.battle ~= 2 and has_skill(98) and last_action
            and st.calm_since and now - st.calm_since >= (cfg.alarum_calm or 10.0)
            and (last_action == "NormalLocomotion" or last_action:find("Idle", 1, true)) then
            st.alarum_next = st.alarum_next or (now + 40.0)
            if now >= st.alarum_next then
                st.alarum_next = now + (cfg.alarum_interval or 300.0)
                if V.request(c, SKILL_ACTION[98], 1) then
                    st.alarum_stop = now + (cfg.alarum_seconds or 2.5); st.alarums = (st.alarums or 0) + 1
                    local close = false
                    pcall(function()
                        for _, e in ipairs(PT.enemies(true)) do
                            if e.hp > 0 and e.dist >= 0 and e.dist < (cfg.alarum_range or 50.0) then close = true; break end
                        end
                    end)
                    log("alarum: cast, enemy within range:", close)
                    if close then V.say(c, "alarum") end
                end
            end
        end
    end
end
-- the main pawn object changed (a save was loaded again, or she was summoned back): drop every reference to the old
-- one, give the borrowed vanilla data back and let auto-enable run again. Nothing is called on the dead objects.
-- Leaving the game phase (title, death, load). Returning to the title crashed in the render stack about 10 s after
-- the title appeared in 5 of 7 returns with the pawn enabled, in 0 of 3 with the script off and in 0 of 3 after a
-- PawnTrickster.disable() (2026-11-10); giving back only the DecoyHandler (v47l) or only the weapon did not help. So
-- the moment the phase is left, everything disable() puts back except the job and the weapon is put back: the two
-- decision packs leave her module, the borrowed vanilla ActInterPackData shells get their own node lists, the goal
-- rows and the stance band are restored, she has her own DecoyHandler again. That alone still crashed (v47r, 1 of
-- 1); with the Job09ActionSelector the script added to her also taken out of her selector list the title was
-- reached and held (v47s). A pawn never has that selector in the vanilla game, and the scene unload does not
-- expect one. Then the script state is dropped; auto-enable sets her up again when a pawn is back (the same one
-- after a resume, a new one after a load).
-- take the Job09ActionSelector the script added out of the pawn's HumanActionSelector.Selectors
function V.drop_selector(c)
    local removed = 0
    if not (c and c.selector and PT.state.selector_added) then return removed end
    pcall(function()
        local list = c.selector:get_field("Selectors")
        for i = list:call("get_Count") - 1, 0, -1 do
            local s = list:call("get_Item", i)
            if s and s:get_type_definition():get_full_name() == "app.Job09ActionSelector" then list:call("RemoveAt", i); removed = removed + 1 end
        end
        c.selector:call("updateCurrentSelector")
    end)
    return removed
end
function V.teardown(c, why)
    local st = PT.state
    local packs, shells = 0, 0
    if c and c.dm then
        if st.trickster_pack and pcall(function() c.dm:call("removeDecisionPack(app.DecisionPack)", st.trickster_pack) end) then packs = packs + 1 end
        if st.mage_pack and pcall(function() c.dm:call("removeDecisionPack(app.DecisionPack)", st.mage_pack) end) then packs = packs + 1 end
    end
    for _, r in ipairs(st.actno_restore or {}) do if pcall(function() r.ap:set_field("_Pack", r.old) end) then shells = shells + 1 end end
    local own = st.own_decoy_handler
    if own and c and c.job09 then pcall(function() c.job09:call("set_DecoyHandler", own) end) end
    if st.band_restore then local b = st.band_restore; pcall(function() b.cmd:write_float(b.off, b.lo); b.cmd:write_float(b.off + 4, b.hi) end) end
    local sels = V.drop_selector(c)
    log("flow: " .. tostring(why) .. ":", packs, "packs removed,", shells, "vanilla node lists restored, own DecoyHandler", tostring(own ~= nil), "Job09 selectors removed", sels)
    V.soft_reset(why)
end
function V.soft_reset(why)
    log("=== soft reset:", why)
    -- the shared vanilla data goes back to what the game loaded (the borrowed ActInterPackData shells and the goal
    -- rows are .user data every pawn reads); nothing is called on the old pawn's own objects
    for _, r in ipairs(PT.state.actno_restore or {}) do pcall(function() r.ap:set_field("_Pack", r.old) end) end
    pcall(goal_restore)
    wrappers = {}; gate_saved = {}; wrapper_live = {}; last_timer = {}; last_action = nil
    -- test helpers: nothing of the old scene is kept. Enemies made with PT.spawn_enemies do not belong to the scene:
    -- they outlive its unload and the game then crashed at the title in 3 of 6 returns; Skill Maker's
    -- destroy_spawns() once the title is up prevented it in 9 of 9 (2026-11-10), the same call just before
    -- leaving did not. So it is queued here and run by the frame hook once the title has been up for 6 s.
    if PT.spawned_any then PT.spawned_any = nil; PT.spawn_cleanup_t = os.clock() end
    fightlog_on = false; bring_queue = {}; spawn_queue = {}; spawned = {}
    V.ray = {}
    V.cats = {} -- v47v: talk categories are looked up again after a load. A category object kept from an earlier load
                -- crashed PLPartyTalkController.evaluateRequest in the fourth load of a session (2026-11-10 11:29:10)
    PT.state = {}
    PT.enabled = false
    V.auto.tries = 0; V.auto.next_try = os.clock() + 3.0; V.auto.seen = nil; V.auto.waits = 0
end

re.on_frame(guard("frame callback", function()
    -- v47x: the test helpers (fight log, bring / spawn queues) only run in the plain InGame phase. The fight log used
    -- to call into the pawn every second while the scene was unloaded and at the title screen: with it on, the game
    -- crashed at the title in 2 of 6 returns on v47t-w; with it off, in 0 of 5 (2026-11-10).
    local mfm = sdk.get_managed_singleton("app.MainFlowManager")
    local phase = mfm and mfm:call("get_FlowPhase")
    if mfm and mfm:call("get_IsInGamePhase") and phase == 27 then
        pcall(fightlog_tick); pcall(bring_tick); pcall(spawn_tick)
    elseif PT.spawn_cleanup_t and phase ~= 8 then PT.spawn_title_t = nil -- 8 = TitleMenu
    elseif PT.spawn_cleanup_t and not PT.spawn_title_t then PT.spawn_title_t = os.clock()
    elseif PT.spawn_cleanup_t and os.clock() - PT.spawn_title_t > 6.0 then -- the title has been up for 6 s (4 s after leaving was too early: crash)
        PT.spawn_cleanup_t = nil; PT.spawn_title_t = nil
        local sp = _G.NickCore and _G.NickCore.enemySpawner
        if sp then local oks = pcall(function() sp.destroy_spawns() end); log("spawn: test spawns destroyed through the spawner after the unload", oks) end
    end
    if PT.weapon_fix and phase == 27 and os.clock() >= PT.weapon_fix.t then pcall(V.weapon_fix_tick) end
    if PT.weapon_fix and phase ~= 27 then PT.weapon_fix = nil end
    if not PT.enabled then return end
    local ok, err = pcall(function()
        local held = PT.state.ctx or (PT.state.pending and PT.state.pending.c)
        if held then
            -- title, death screen, loading: the scene is being torn down (the decoy's component threw on every frame
            -- of a reload before this check), so nothing is read or driven until the game phase is back
            local mf = sdk.get_managed_singleton("app.MainFlowManager")
            if not (mf and mf:call("get_IsInGamePhase") and mf:call("get_FlowPhase") == 27) then -- 27 = Phase.InGame
                local okt, et = pcall(V.teardown, held, "the game phase was left")
                if not okt then log("flow: teardown error:", et); pcall(V.soft_reset, "the game phase was left (after an error)") end
                return
            end
            local pawn = main_pawn()
            local ch = pawn and pawn:get_field("<CachedCharacter>k__BackingField")
            if not ch then return end -- loading screen or no main pawn: nothing to drive
            if ch:get_address() ~= held.chara:get_address() then V.soft_reset("the main pawn was rebuilt (save load or re-summon)"); return end
            -- v48a: a pawn was hired or dismissed, or a hired pawn changed vocation: same put-back as when the game
            -- phase is left, then auto-enable sets her up again with slots built on vocations the new party lacks
            if cfg.party_watch ~= false and PT.party_changed() then
                local okt, et = pcall(V.teardown, held, "the party changed")
                if not okt then log("flow: teardown error:", et); pcall(V.soft_reset, "the party changed (after an error)") end
                return
            end
        end
        pump()
        local c = PT.state.ctx
        if c then
            track_selection(c); update_summon_gate(c); action_trace(c); remember_tick()
            local okv, ev = pcall(V.tick, c)
            if not okv and not PT.state.tick_err then PT.state.tick_err = true; log("tick error:", ev) end
        end
    end)
    if not ok then log("frame error:", err) end
end))

if cfg.auto_enable then
    local A = V.auto -- (v47: reset by V.soft_reset so a later save load enables again)
    re.on_frame(guard("frame callback", function()
        if PT.enabled or PT.user_disabled or A.tries >= 30 or os.clock() < A.next_try then return end
        local mf = sdk.get_managed_singleton("app.MainFlowManager")
        if mf and mf:call("get_IsInGamePhase") and mf:call("get_FlowPhase") == 27 then
            A.next_try = os.clock() + 3.0
            local pawn = main_pawn()
            local ch = pawn and pawn:get_field("<CachedCharacter>k__BackingField")
            -- v47o: the same pawn object must be there on two checks in a row. After a long warp or a fall the game can
            -- create and remove the pawn every few seconds until she is placed next to the Arisen (seen 2026-11-10:
            -- enable, soft reset, enable... every 10 s). Only real enable attempts count against the 30 tries.
            local addr = ch and ch:get_address()
            if addr and A.seen == addr then
                A.tries = A.tries + 1
                PT.state.tried = true
                local ok = PT.enable()
                log("auto-enable: try", A.tries, ok)
            else
                A.waits = (A.waits or 0) + 1
                if A.waits == 1 or A.waits % 10 == 0 then log(addr and "auto-enable: main pawn found, one more check before enabling" or "auto-enable: waiting for the main pawn", "(check", A.waits, ")") end
            end
            A.seen = addr
        end
    end))
end

-- censer picker: hand one of the Arisen's censers (not the one the Arisen holds equipped) to the pawn, or switch
-- between the pawn's own censers. Uses the same passItem + Main-slot path as enable().
local item_name_m
local function item_name(id)
    local ok, n = pcall(function()
        item_name_m = item_name_m or sdk.find_type_definition("app.GUIBase"):get_method("getItemName(System.Int32)")
        return item_name_m:call(nil, id)
    end)
    if ok and n ~= nil and tostring(n) ~= "" then return tostring(n) end
    return "item " .. tostring(id)
end
function PT.censer_rows()
    local rows = {}
    local c = PT.state.ctx or ctx(); local im = sdk.get_managed_singleton("app.ItemManager")
    if not (c and im) then return rows end
    local _, pl = player_component()
    local pid = pl and pl:call("get_CharaID")
    local cur = main_item(im, c)
    for _, id in ipairs(censer_ids(im)) do
        local where, can
        if pawn_owns(im, c, id) then
            where = (cur == id) and "pawn, equipped" or "pawn"; can = cur ~= id
        elseif pl then
            local sd = find_storage(im, id, pl)
            if sd and sd:get_field("_CharaId") == pid then
                if sd:get_field("_IsEquipped") then where = "Arisen, equipped" else where = "Arisen"; can = true end
            end
        end
        if where then rows[#rows + 1] = { id = id, name = item_name(id), where = where, can = can } end
    end
    return rows
end
function PT.give_censer(id)
    if not PT.enabled then log("give_censer: enable the mod first"); return false end
    local c = PT.state.ctx or ctx(); local im = sdk.get_managed_singleton("app.ItemManager")
    if not (c and im) then log("give_censer: no pawn"); return false end
    if not is_censer(im, id) then log("give_censer:", id, "is not a censer"); return false end
    if not pawn_owns(im, c, id) then
        local _, pl = player_component()
        local sd = pl and find_storage(im, id, pl)
        if not sd or sd:get_field("_CharaId") ~= pl:call("get_CharaID") then log("give_censer: the Arisen does not hold", id); return false end
        if sd:get_field("_IsEquipped") then log("give_censer: the Arisen has", id, "equipped"); return false end
        local ok, err = pcall(function() im:call("passItem(app.ItemDefine.StorageData, System.Int32, app.Character, System.Boolean)", sd, 1, c.chara, false) end)
        log("give_censer: passItem", id, "to the pawn", ok, err or "")
        if not pawn_owns(im, c, id) then return false end
    end
    local ok = step_weapon(c, id)
    if ok and cfg.remember ~= false then
        local rec = db_rec(c); if rec then rec.censer = id; rec.updated = os.date("%Y-%m-%d %H:%M:%S"); db_save() end
    end
    return ok
end

re.on_draw_ui(guard("REFramework panel", function()
    if imgui.tree_node("Pawn Trickster") then
        imgui.text("enabled: " .. tostring(PT.enabled))
        if imgui.button("enable (pawn -> Trickster)") then PT.enable() end
        imgui.same_line()
        if imgui.button("disable (pawn back to job " .. tostring(cfg.revert_job) .. " / previous)") then PT.disable() end
        imgui.same_line()
        if imgui.button("status") then PT.status() end
        local lchg, lval = imgui.checkbox("Enable debug logs (every step, for a bug report)", cfg.log == true)
        if lchg then PT.set_log(lval) end
        imgui.text("   reframework/data/PawnTrickster/log.txt (errors are always written; the last start: log.previous.txt)")
        local dchg, dval = imgui.checkbox("debug (force the test skill set at every load)", cfg.debug == true)
        if dchg then cfg.debug = dval; pcall(json.dump_file, CFG_PATH, cfg); log("config: debug", tostring(dval), "(applies at the next enable)") end
        if PT.enabled and imgui.tree_node("Censer") then
            if not PT.ui_censers or os.clock() - (PT.ui_censers_t or 0) > 2.0 then
                local ok, rows = pcall(PT.censer_rows); PT.ui_censers = ok and rows or {}; PT.ui_censers_t = os.clock()
            end
            if #PT.ui_censers == 0 then imgui.text("no censer held by the pawn or the Arisen") end
            for _, r in ipairs(PT.ui_censers) do
                imgui.text(string.format("%s (%d): %s", r.name, r.id, r.where))
                if r.can then
                    imgui.same_line()
                    if imgui.button("equip on pawn##censer" .. tostring(r.id)) then pcall(PT.give_censer, r.id); PT.ui_censers = nil end
                end
            end
            imgui.tree_pop()
        end
        local rec = PT.remembered and PT.remembered()
        if rec then
            imgui.text(string.format("remembered: censer %s, skills %s, augments %s (%s)", tostring(rec.censer),
                type(rec.slots) == "table" and table.concat(rec.slots, " ") or "-", type(rec.augments) == "table" and table.concat(rec.augments, " ") or "-", tostring(rec.updated or "-")))
        end
        if cfg.debug then
            if imgui.button("summon decoy") then PT.request(ACT.heavy) end
            imgui.same_line()
            if imgui.button("beckon") then PT.request(ACT.transfer) end
            imgui.same_line()
            if imgui.button("unsummon") then PT.request(ACT.unsummon) end
            if imgui.button("Aromatic Rally") then PT.request(SKILL_ACTION[97]) end
            imgui.same_line()
            if imgui.button("Sweeping Shroud") then PT.request(SKILL_ACTION[95]) end
            imgui.same_line()
            if imgui.button("Dragon's Delusion") then PT.request(SKILL_ACTION[99]) end
            if imgui.button("Latching Effigy") then PT.request(SKILL_ACTION[96]) end
            imgui.same_line(); if imgui.button("Fickle Floor") then PT.request(SKILL_ACTION[93]) end
            imgui.same_line(); if imgui.button("Espial Incense") then PT.request(SKILL_ACTION[94]) end
            if imgui.button("Scented Alarum") then PT.request(SKILL_ACTION[98], 1) end
            imgui.same_line(); if imgui.button("stop Alarum") then PT.request("UpperBodyDefault", 1) end
        end
        for i = math.max(1, #PT.log_lines - 12), #PT.log_lines do imgui.text(PT.log_lines[i]) end
        imgui.tree_pop()
    end
end))

log("PawnTrickster loaded (auto_enable=" .. tostring(cfg.auto_enable) .. ")")
