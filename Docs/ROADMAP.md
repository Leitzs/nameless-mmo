# Roadmap

The project is Godot-only (`godot/`). The Unreal version (v0.1, "RPGTest") was ported and then deleted, and the port is now the game. Details and file map are in `godot/README.md`.

## What exists

| Area | Where (`godot/scripts/`) | Notes |
| --- | --- | --- |
| Third-person camera, WASD, sprint, jump, zoom | `characters/`, `core/game.gd` | Input is built in code. |
| 7 playable classes + original Mage/Rogue | `characters/classes/`, `abilities/*_kit.gd`, `spells/` | 5 abilities + ultimate on `6`, left-mouse basic attack, a class resource each. |
| Combat framework | `components/status_effects.gd`, `components/class_resource.gd`, `components/spellbook.gd`, `spells/ability.gd` | Data-driven statuses, resistances, telegraphs, modifiers, summons, enemy casters. |
| Enemies | `characters/`, `world/` (bot spawner) | Melee bot with patrol/chase/leash/respawn; `EnemyCaster` uses class abilities. |
| FX | `fx/` | Code-driven particles, telegraphs, lightning arcs, ground zones. |
| Inventory | `inventory/`, `ui/screens/` | Stacking slot grid, drag-and-drop, item use. |
| UI | `ui/` | Token-driven UI built in code: HUD, nameplates, title, pause, class selection, spellbook, inventory, quest journal, world map. |
| Quests (data only) | `quests/quest_database.gd`, `assets/data/quests.json` | Read by the journal, the HUD tracker and the world map. |
| Map | `scenes/test_arena.tscn` | Test arena only. |
| Characters | `assets/characters/`, `assets/animations/` | Kit characters on the CC0 Quaternius UAL rig, built from `Scripts/blender_kit/build_game_characters.py -- --rig ual`. |

Verify with `-- --selftest`.

## Not done yet

### Maps
The Unreal maps and their generator scripts were deleted with the project, so these must be rebuilt in Godot.
- [ ] Procedural forest (Whisperwood): terrain, vegetation scatter, roads, clearings, pond. Replaces `RPGWorldGenerator`.
- [ ] Medieval props (Cottage, Campfire, Watchtower, Fence, CastleWall/Tower, Gatehouse, Keep) and the castle map.
- [ ] Kingdom main map from the Blender kit (spawn → farms → village → forest/sanctum/ruins/barrow → Highcrest → castle). Needs a Godot import of `Art/Export/Kit`.
- [ ] Map travel from the world map markers (only the test arena exists now).

### Gameplay
- [ ] Play-test and tune numbers (damage, cooldowns, resources, bot HP).
- [ ] Minimap and interact prompt on the HUD.
- [ ] Loot / XP, more enemy types, bosses.
- [ ] Spell ranks/upgrades, an equipment system for the paper doll, gold/weight.
- [ ] Quest runtime (the journal only reads static data).
- [ ] Settings and save/load screens.
- [ ] Sounds.

### Art
- [ ] Dedicated icons for the new class abilities (they reuse the 13 original spell icons).
- [ ] Final title text on the title screen ("Nameless" is a placeholder).
- [ ] Performance target: GTX 1060 6GB; profile before adding heavy effects.
