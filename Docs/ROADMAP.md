# RPGTest roadmap

State after v0.1 (first playable) and what is left from the original plan.

## What v0.1 contains

| Area | Where | Notes |
| --- | --- | --- |
| Free third-person camera, WASD, sprint, jump, zoom | `Characters/MageCharacter`, `Core/RPGPlayerController` | Enhanced Input actions/mapping are built in code (no input assets). |
| Mage class with 5 spells on keys 1-5 | `Spells/MageSpells`, `Components/RPGSpellbookComponent` | Fireball, Frost Nova, Lightning Strike, Blink, Arcane Shield. |
| Health / mana / shield, status effects | `Components/RPGAttributeComponent`, `Components/RPGStatusEffectComponent` | Slow, freeze, stun, burn. |
| Enemy bot | `Characters/EnemyBotCharacter`, `AI/RPGBotAIController`, `AI/RPGBotSpawner` | Melee combo + telegraphed charge, patrol, chase, leash, respawn. |
| HUD | `UI/RPGHUD` | Canvas-drawn: bars, spell bar with cooldowns, crosshair, enemy bars, damage numbers, zone banner, F1 help. |
| Forest map | `World/RPGWorldGenerator`, `Content/RPGTest/Maps/L_Whisperwood` | Procedural terrain + instanced vegetation, roads, clearings, pond. |
| Test arena map | `Content/RPGTest/Maps/L_TestArena`, `Scripts/create_test_arena.py` | Flat grid map of placed actors: duel bot with its patrol/aggro/leash rings drawn on the floor (`ARPGBotSpawner::bShowRangeRings`), 3-bot group behind a line-of-sight wall, 2 m platform, range lane marked every 5 m. |
| Map selector | `Core/RPGGameInstance`, `Core/RPGPlayerController`, `UI/RPGHUD` | Canvas menu shown on the first level of each play session (pauses the game); F2 reopens it. The map list lives in `URPGGameInstance`. |
| Medieval props | `World/RPGMedievalProp` | Only 4 types for now: Cottage, Campfire, Watchtower, Fence. |
| Materials | `Content/RPGTest/Materials/M_RPG_Surface`, `M_RPG_FX` | Everything is primitive shapes colored via per-instance / primitive custom data. |
| Characters | `Content/Characters/Mannequins` | Manny/Quinn + animations copied from the engine's third person template. |

Debug console commands (open the console with `` ` `` during play): `RpgGod`, `RpgRefill`, `RpgGoToBot`, `RpgCast <1-5>`, `RpgStatus`, `RpgSelfTest`, `RpgMap <n>` (plays map n of the selector list).

## Not done yet (cut to ship v0.1 fast)

### Verification
- [x] Run `RpgSelfTest` and read `LogRPG` output (casts every spell at the nearest bot and checks damage/freeze/shield/blink). Result: 4/5 on both maps; Blink fails because of the aim bug below.
- [ ] Fix aim soft-lock picking an enemy behind the aim direction: with a bot in melee contact behind the mage, the camera boom's probe pulls the camera next to the mage, and `AMageCharacter::ComputeAim`'s aim-assist sphere (90 cm, starting at the mage) already overlaps the bot at distance 0, so it locks on. Blink then goes towards the bot and stops on its capsule. Likely fix: skip pawn hits that are not in front of the ray start.
- [ ] Play-test and tune numbers (damage, cooldowns, mana, bot HP 500, bot melee 16 / charge 24).
- [ ] Check mouse-look pitch direction (uses the UE template convention; flip `bInvertLookY` on the Mage if it feels inverted).

### Visual tuning
- [ ] Tune cosmetic attachments (mage hat and staff, bot helmet and sword). They are aligned to the idle pose 0.25 s after spawn in `AlignCosmetics()`; offsets may need adjusting after seeing them in game.
- [ ] Check the mannequin `Paint Tint` result (mage purple, bot red) and FX intensities / light brightness (candelas) under the level's exposure.
- [ ] Verify terrain faces render correctly (winding copied from `CreateGridMeshWelded`) and the vertex-color ground looks right.
- [ ] Post process: exposure range, color grading, vignette; volumetric fog density for forest mood.

### Map content
- [ ] Place the village (Oakhaven): cottages, campfire, fences, well. The layout (clearings/roads) already exists in the generator defaults.
- [ ] Old Watchtower Ruins on the hill (NE), Bandit Camp (SE) with a 2-bot spawner, Mirror Pond (NW), Circle of Elders (SW), Woodcutter's Glade (N).
- [ ] More prop types that were drafted then cut: TwoStoryHouse (tavern), Well, Tent, Cart, MarketStall, Barrels, Crates, HayBales, LanternPost, RuinWall, RuinTower, TrainingDummy, Signpost, StandingStone, Banner, WoodPile.
- [ ] Consider replacing the procedural terrain with a real Landscape (sculpt/paint tools) and primitives with real art (Fab packs go in `Content/` root; swap paths in `Core/RPGAssets.h`).

### Gameplay
- [ ] Hit-react animations, spell sounds, Niagara VFX instead of glowing primitives.
- [ ] UMG HUD (current HUD is Canvas-based, no widget assets).
- [ ] Input assets (IA_/IMC_) so keys can be rebound in the editor / settings menu.
- [ ] Evaluate moving spells/attributes to the Gameplay Ability System if multiplayer or many classes are planned.
- [ ] Mana potions / loot / XP, more enemy types, a second class.
