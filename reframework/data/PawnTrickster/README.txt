Trickster Main Pawn 0.2.6 (beta) - REFramework script

What it does
- At every save load your main pawn becomes a Trickster and holds a censer.
- The first time, the pawn starts like a new Trickster at rank 1: Sweeping Shroud, the core skill
  Mending Vapor and a censer. Dragon's Delusion stays a Maister skill.
  After that it keeps what you give it: buy and equip skills, core skills and augments at the
  Vocation Guild as usual. The game saves those; this mod also keeps a copy and the censer it held.
- It fights as a Trickster on its own, with the skills it has equipped: it summons a decoy that
  enemies attack, beckons it, and casts its equipped skills when they fit. It holds about 7-12 m
  from its target instead of running into melee.
- The decoy is summoned and re-summoned only while the party is in battle (0.2.4).
- Aromatic Rally: when you or another party pawn is within 12 m of the pawn, every 12 s at the
  most, and only with three quarters of its stamina or more (a Rally costs about half of it).
  When Rally is ready and nobody is that close, the pawn dashes back to you (to about 5-8 m) and
  casts it there.
- Between casts it keeps its distance and circles, and (0.2.6) it throws smoke: turned to an
  enemy 4-14 m away it swings the censer (the Trickster's own throwing move), and at the end of
  the swing a puff of incense smoke flies to that enemy. A hit does a little damage (20 + 5 for each level of the pawn) and does not draw
  the enemy's attention to the pawn. While the decoy is out, the enemy is fooled for 6 s: it
  lets go of your pawns and goes for the decoy. It is a filler for the time no skill is due: in a
  test fight the pawn threw one about every 15 s, and two in three hit.
- Rank 4 to 7 skills, each only when equipped:
  Latching Effigy: decoy out, two or more enemies around the pawn, and the pawn facing one that
  is 3-10 m away. 0.2.6: the mod throws the incense itself, at the target's legs. The game's own
  throw flies over small enemies such as goblins unless they stand higher than the pawn.
  Fickle Floor: a drop of 4 m or more between the pawn and the nearest enemy (never on flat ground).
  Espial Incense: enemies far from the pawn and from the decoy; the decoy is sent next to the enemy
  nearest you.
  Scented Alarum: out of battle, every 5 minutes.
- Dragon's Delusion is ended after 5 s, or sooner when the pawn's stamina runs low. It, Delusory
  Screen and Latching Effigy are not started on low stamina (0.2.5), so the pawn no longer casts
  itself out of breath.
- The pawn speaks vanilla pawn lines on some casts (the game has no Trickster lines for pawns), one
  line per 45 s at most: when the decoy goes out, on Aromatic Rally, on Dragon's Delusion, when a
  Latching Effigy latches, when it casts Delusory Screen for you, and on a Scented Alarum that
  finds enemies.
- Trickster shows up in the pawn's Vocation Guild list, Status page and skill pages. Discipline and
  rank are earned and spent through the game's own menus.

Censer
- The mod equips the censer through the game's own equip call: the game's Equipment menu shows it
  as equipped and the save keeps it. If a load still comes back without it, the mod puts the
  remembered one back.
- To give the pawn another censer, use the game's Equipment menu like for any weapon: Give it from
  your page, then Equip it on the pawn's page. The mod records it within a few seconds.
  Or: REFramework menu > Script Generated UI > Pawn Trickster > Censer lists the pawn's censers and
  yours (except the one you have equipped); "equip on pawn" hands it over.

Hired pawns
- You can hire other pawns as usual. When a pawn joins or leaves, the mod sets your pawn up again;
  for about 20 s it fights like a plain pawn, then its Trickster rules are back.
- Hired pawns keep their own behaviour. Tested with a hired Mage, Thief, Archer and Fighter.

Settings (reframework/data/PawnTrickster/config.json, written on the first start)
- "auto_enable": false stops the automatic switch; use the buttons in the REFramework menu instead.
- "voice": false silences the cast lines. "voice_cooldown" is the pause between two lines (s).
- "effigy", "floor", "espial", "alarum": false switches that skill's rule off. Each has a
  "..._cooldown" (s); "alarum_interval" is the time between two Scented Alarums (s).
- "floor_need_ledge": false allows Fickle Floor on flat ground too.
- "delusion_seconds": how long Dragon's Delusion is held.
- "regroup": false stops the dash back to you for Aromatic Rally. "regroup_stop" is how close the
  pawn comes (m), "regroup_cooldown" the pause between two dashes (s).
- "rally_distance" (m), "rally_cooldown" (s) and "rally_min_stamina" (0 to 1) set when Aromatic
  Rally may start. "delusion_min_stamina", "screen_min_stamina", "effigy_min_stamina": the same
  floor for those skills.
- "effigy_near", "effigy_far" (m), "effigy_aim_deg": where an enemy has to be for Latching Effigy.
  "effigy_rethrow": false gives the throw back to the game; "effigy_small_rise": 1.7 then makes
  the pawn cast it at small enemies only when they stand higher (what 0.2.5 did).
- "dust": false switches the smoke ball off. "dust_action": the move it is thrown with
  ("Job09_ThrowSmoke", the full swing; "Job09_ShortSmokeAttack" is a flick of the wrist). "dust_damage": its damage (0 = "dust_damage_base"
  + "dust_damage_level" for each level of the pawn). "dust_cooldown" (s): the pause between two.
  "dust_near", "dust_far" (m): how far the enemy may be. "dust_safe" (m): no swing while an enemy
  is closer to the pawn than this. "dust_no_aggro": false lets a hit draw the enemy's attention,
  like the game's own thrown smoke does. "dust_fool": false stops the hit from turning the enemy
  to the decoy; "dust_fool_seconds" is how long that lasts; "dust_fool_big": true includes big
  enemies. The smoke of this attack is kept small: the big cloud the censer swing throws by
  itself is taken out ("dust_swing_shell": true gives it back), and the puff at the impact and
  the swing's smoke fade out after "dust_hit_life" / "dust_swing_life" seconds (0.5 / 0.3; 0 = the
  game's full cloud). "dust_fx_alpha": how opaque what is left is (1 = as the game draws it).
  The thin wisp that follows the censer at all times is the weapon's own and is not changed.
- "resummon_seconds": the pause before a destroyed decoy is summoned again in battle (s).
  "resummon_calm": true brings it back out of battle as well (0.2.3 and earlier did).
- "debug": true forces a fixed test skill set at every load (for testing only).
- "log": true writes a step-by-step log to log.txt in this folder (for bug reports).
- "party_watch", "equip_by_game", "rule_drop", "cast_in_ready": switches back to older behaviour.
  You should not need them.
- pawns.json in this folder is the mod's memory of your pawn's censer, skills and augments.
- config.defaults.json (0.2.5) remembers the default values of the version that wrote
  config.json. A setting you never changed then follows a default that a later version changes;
  a setting you changed stays yours. Do not edit it.

Uninstall
- Press "disable" in the REFramework menu (the pawn returns to its previous vocation, or Mage),
  save, quit, then delete reframework/autorun/PawnTrickster.lua and this folder.
- If you delete the files without disabling, the pawn stays a Trickster in the save, without a
  censer.

Known limits (beta)
- In battle the decoy is summoned again about 6 s after enemies destroy it ("resummon_seconds").
- Close to you the pawn is also close to what you are fighting; a low-level pawn can go down there.
  "regroup_stop" moves the point it dashes to, "regroup": false keeps it at range.
- Skills you equip or remove on the pawn count for its combat rules from the next load, or after
  disable / enable in the mod's panel.
- Latching Effigy: with the incense thrown by the mod it latched on goblins level with or below
  the pawn in about half of the casts in testing (2 in 21 with the game's own throw), on rogues
  in 2 casts of 3, and never when cast turned away. A latch on a goblin lasts a few seconds.
- Thrown smoke (the ball and the effigy incense) does not fly as far at a low frame rate: about
  7 m at 30 FPS, 13 m at 40. The mod only throws at enemies within that reach.
- The smoke ball misses a moving enemy about one time in three.
- Fickle Floor needs a real drop between the pawn and the enemy (seen on a cliff edge);
  "floor_need_ledge": false allows it anywhere.
- Returning to the title screen and loading again, and dying and choosing Load from Autosave,
  were tested: the pawn is set up again by itself. If your game crashes at the title with the
  mod and not without it, report it with "log": true.
- Tested against goblins, rogues, phantoms, a cyclops and harpies, next to a Trickster Arisen
  (the pawn then uses a decoy of its own), with a hired Mage, Thief, Archer or Fighter in the
  party, with a censer given and equipped in the game's Equipment menu, and through a death and
  reload.
  Not tested: you and the pawn both casting Trickster skills at the same time; what other players
  see when they hire your pawn online.

Fixed
- 0.2.6: Latching Effigy flew over small enemies standing level with the pawn or lower.
- 0.2.5: Latching Effigy was cast in any direction and at small enemies it flies over; Dragon's
  Delusion could drain all stamina.
- 0.2.4: the decoy came back out of battle every time it had dispersed.
- 0.2.3: fights in which the pawn followed and circled but cast nothing (enemies its weapon cannot
  hurt, such as phantoms; fights the game rates as dangerous for it).
- 0.2.1: the random crashes of 0.1.0 / 0.2.0; two unusable cut skills given to a new Trickster pawn.

Other mods
- Skill Maker and other mods that change the Arisen's skills are left alone: this script only
  touches the main pawn.

Source and bug reports: https://github.com/jlrouzies-fr/DD2-Trickster-Pawn

Back up your save before the first use. A pawn saved as a Trickster is not something the online pawn
system was built for; other players who hire your pawn are untested.
