# DD2 Trickster Pawn

A REFramework script for Dragon's Dogma 2 that makes your **main pawn a Trickster**.

In the vanilla game the Trickster is an Arisen-only vocation: pawns have no Trickster combat logic, no Trickster
entry in their Vocation Guild list and no censer handling. This mod adds all three through the game's own systems.
Current version: **0.2.6 (beta)**. Releases are on Nexus Mods; this repository holds the source, the development
notes and the tools used to test it.

## What the pawn does

- At every save load the main pawn becomes a Trickster and holds a censer. The first time it starts like a new
  Trickster at rank 1; after that it keeps the skills, core skills, augments and censer you give it.
- It fights on its own with the skills it has equipped: it summons a decoy that enemies really attack, beckons it,
  casts Aromatic Rally next to you or another pawn as often as its stamina allows (and dashes back to you for it), Dragon's Delusion against big
  enemies or groups, Delusory Screen when you take a burst of damage, and the rank 4-7 skills (Latching Effigy,
  Fickle Floor, Espial Incense, Scented Alarum) when they are equipped and fit.
- It holds about 7-12 m from its target instead of walking into melee.
- Between skills it throws a ball of incense smoke at an enemy in range (0.2.6): a little damage, and the enemy does
  not turn on the pawn for it.
- Trickster shows up in the pawn's Vocation Guild list, Status page and skill pages; discipline, rank and skills go
  through the game's own menus.
- Hired pawns keep their own behaviour (tested with a Mage, Thief, Archer and Fighter).

The full player-facing text, with settings and known limits, is
[`reframework/data/PawnTrickster/README.txt`](reframework/data/PawnTrickster/README.txt). Version history:
[`CHANGELOG.md`](CHANGELOG.md).

## Install

1. Back up your save folder (`Steam\userdata\<your id>\2054970\remote\win64_save`).
2. Install [REFramework](https://github.com/praydog/REFramework).
3. Copy the `reframework` folder of this repository (or of a release zip) into the game folder.
4. Load your save. A few seconds later the main pawn is a Trickster. Settings are written to
   `reframework/data/PawnTrickster/config.json` on the first start; [`config.example.json`](config.example.json)
   is an older example of that file (the script adds the keys it does not find).

To uninstall: REFramework menu > Script Generated UI > Pawn Trickster > disable, save, quit, then delete
`reframework/autorun/PawnTrickster.lua` and `reframework/data/PawnTrickster`.

## Reporting a bug

Everything is in `reframework/data/PawnTrickster/`. `log.txt` is the log of the current game start: it always holds
the mod's build, the REFramework version, the settings changed from their defaults and every error of the mod (errors
in its hooks and frame callbacks are caught and written there with their stack). `log.previous.txt` is the start
before, so after a crash and a relaunch the crash's log is still there.

1. REFramework menu > Script Generated UI > Pawn Trickster > tick **Enable debug logs** (or `"log": true` in
   `config.json`). It can be ticked right after the bug: the last 400 steps kept in memory are written at once.
2. Note the time on your clock when the problem happens (every log line starts with it).
3. Open an [issue](../../issues/new?template=bug_report.yml) (or post in the Nexus Bugs tab) and attach:
   - `log.txt`; after a crash, `log.previous.txt` if you started the game again, and `reframework_crash.dmp` from
     the game folder if there is one
   - `pawns.json` for a censer, skill or augment problem
   - what the pawn did and what you expected, the time, the enemies, the party and your other mods that touch pawns,
     skills or AI. A short video of the moment helps a lot.
4. Untick it afterwards: the log grows quickly in fights.

If `log.txt` does not start with today's date, the mod did not load: send `re2_framework_log.txt` from the game
folder instead.

## Contributing

Everything is in one file, [`reframework/autorun/PawnTrickster.lua`](reframework/autorun/PawnTrickster.lua).
Changes are accepted when they were tried in the game: say what you tested and what you measured.

- [`AGENTS.md`](AGENTS.md) is the working method: how to drive the game unattended, how to find out why the pawn
  does not do something, the engine rules that crash the game when broken, and the checks to run before a change is
  called done. It is written for AI coding agents and works just as well for people.
- [`tools/`](tools) holds the helpers that method uses: a dev console for REFramework, launch and load scripts that
  do not steal the focus, a watchdog for crash dialogs, fight helpers and the samplers that say what the pawn's AI is
  doing and which condition refuses a rule.
- [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) is the development log with the evidence behind every design
  decision, [`docs/NOTES.md`](docs/NOTES.md) the raw facts run by run, [`docs/AI_ATLAS.md`](docs/AI_ATLAS.md) a map
  of the game's pawn AI data. They were written as working notes (they say "she" for the test pawn and mention
  scratch files that are not here); the tools in this repository are the cleaned-up versions of those scratch files.
- `python tools/build_release.py <version>` builds the release zip into `dist/`.

Open problems worth picking up are listed at the end of `AGENTS.md`.

## How it works, in short

The script switches the pawn to `Job09` through the game's job changer, equips a censer with the game's equip call,
gives it a decoy handler, and adds one decision pack of its own to the pawn's AI. Each cast rule is a copy of a
vanilla decision whose command is replaced by the Trickster action; Lua opens and closes the rules every few frames
(is the decoy out, is an ally near, is the Arisen in trouble, is the party in battle). When the game leaves the
world, or the party changes, everything borrowed from the vanilla data is put back and the pawn is set up again.

## Credits

- praydog for REFramework.
- Everything the pawn does is the game's own Trickster actions, skills and AI nodes; no assets from other mods.
