# nameless-mmo — Godot project

The game, in GDScript on Godot 4.7.2 (local install: `D:\dev\tools\godot`). It began as a port of an Unreal
project (RPGTest). That project has since been deleted, so the Unreal names below are for history only.

Units are metres (Unreal cm / 100). Character origins are at the feet.

## Run
- Editor: open `godot/project.godot`. Main scene: `scenes/test_arena.tscn` (title screen on first load).
- Self test (casts every Mage and Rogue spell at bots, exercises the inventory, opens every screen; exits 0/1):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --selftest`
- Other user args: `--skip-title`, `--class Rogue`, `--screenshot out.png [--screen Inventory] [--cast 1]`.
- Network self test (headless dedicated server + dummy client as child processes, optional lag proxy; exits 0/1):
  `Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --selftest-net [--via-proxy 80]`
- Multiplayer flags: see **Networking** below.
- Character preview (models, materials, weapon grips): `... --path godot tools/preview_characters.tscn -- out.png [clip]`.

Controls: WASD move, mouse look, wheel zoom, Space jump, Shift sprint, `1`-`6` spells, `Esc`/`P` pause or back,
`I` inventory, `K` spellbook, `J` quest journal, `M`/`F2` world map, `F5` refill + reset cooldowns, `F6` god mode,
`F3` network stats overlay.

## Port map (historical: Unreal source is deleted)
| Unreal (removed) | Godot |
| --- | --- |
| `RPGTypes.h`, `RPGCombatLibrary`, `RPGDamageTypes.h` | `scripts/core/rpg.gd` (`RPG`) |
| `RPGPlayerController` input, `RPGGameInstance` (class, maps, tracked quest) | `scripts/core/game.gd` (autoload `Game`) |
| `import_kit.py` material instances (from `materials.json`) | `scripts/core/kit_materials.gd` |
| `RPGAttributeComponent` / `RPGStatusEffectComponent` / `RPGSpellbookComponent` | `scripts/components/` |
| `RPGItemDef`, `RPGItems`, `RPGInventoryComponent` | `scripts/inventory/` |
| `URPGQuestDatabase` / `DA_Quests` | `scripts/quests/quest_database.gd` + `assets/data/quests.json` |
| `RPGSpell`, `MageSpells`, `RogueSpells`, `RPGProjectile`, `RPGDelayedBlast` | `scripts/spells/` |
| `RPGTransientFX` | `scripts/fx/transient_fx.gd` |
| `RPGCharacterBase`, `MageCharacter`, `RogueCharacter`, `EnemyBotCharacter` + `RPGBotAIController` | `scripts/characters/` (`PlayerCharacter` holds the shared player half) |
| `RPGBotSpawner`, `L_TestArena` | `scripts/world/` |
| `RPGUITokens` / `RPGUIPrimitives` / `RPGButton` / common widgets | `scripts/ui/ui_tokens.gd` (`UITokens`) |
| `ARPGHUD` + `WBP_RootLayout`, `URPGScreen`, `URPGConfirmModal` | `scripts/ui/ui_root.gd`, `ui_screen.gd` |
| HUD widgets, nameplate | `scripts/ui/player_hud.gd`, `nameplate.gd` |
| Main menu, pause, class selection, spellbook, inventory, journal, world map | `scripts/ui/screens/` |

UI is built in code from the tokens (no `.tscn` per screen); texts come from the Unreal WBPs / C++.

## Assets
- `assets/characters/SKM_{Mage,Rogue}_Kit.glb` — the kit characters on the **CC0 Quaternius Universal Animation
  Library** rig, built by `Scripts/blender_kit/build_game_characters.py -- --rig ual` (re-rests the UAL rig
  arms-down to match the armor, fits the kit bodies/armor, exports GLB). The Unreal mannequin clips are Epic
  content and are not used here.
- `assets/animations/` — UAL clips (CC0, copy of `Art/ThirdParty/UniversalAnimationLibrary`); the bot uses the
  UAL mannequin itself, tinted.
- `assets/weapons/*.fbx` — copied from `Art/Export/Kit` (their `UCX_` collision hulls are stripped at load and
  weapons are fitted from their bounds; see `RPGCharacter._attach_weapon`).
- `assets/kit/materials.json` — copy of `Art/Export/Kit/materials.json` (linear colors).
- `assets/ui/textures` — originally exported from the Unreal project; this is now the only copy.
  `assets/ui/fonts` — Instrument Serif, Lora, Geist Mono (OFL, from google/fonts).
- `assets/data/quests.json` — quest data (originally from Unreal's `DA_Quests`); edit it directly.

## Combat framework
- `components/status_effects.gd`: one data-driven status system (`DEFS`): burn, poison, bleed, corruption, chill
  (5 stacks -> freeze), freeze, stun, root, fear, silence, slow, shock, vulnerable, frailty, death mark, regen,
  empower, thorns, haste, ambush. Stacks, max stacks, tick rate, refresh, potency, post-control immunity,
  per-character resistances, dispel. `RPG.deal_damage` applies attacker multipliers (buffs, class resource) and
  target multipliers (vulnerable, frailty, shock vs lightning) and emits `Game.damage_dealt` / `character_killed`.
- `components/class_resource.gd`: Heat, Frost, Arcane Charges, Static, Nature Essence, Soul Fragments, Combo
  Points (bar or pips on the HUD). `components/spellbook.gd`: resource costs/gains, channelling, cast-speed and
  cooldown rates, silence, and a left-mouse `basic_attack` for every class.
- `spells/ability.gd`: base for class abilities (cone/line/radius queries, telegraphed strikes, impact FX,
  camera shake). Abilities only talk to `RPGCharacter`, so enemies and bosses use them too (`EnemyCaster`, tuned
  with `configure({...})`). `Spell.modifiers` are data-driven specialisations, switchable in the Grimoire.
- FX (no Niagara in Godot): `fx/particle_fx.gd` (embers, sparks, shards, leaves, smoke, shadow, runes, mist,
  blood), `fx/telegraph.gd` (circle, ring, cone, line; red for enemies), `fx/lightning_arc.gd`,
  `fx/ground_zone.gd` (lingering areas). `characters/summon.gd`: allied summons on the bot AI.

## Networking
Server-authoritative PvP (FFA: every player is hostile to every other player; bots, cultists and
summons stay and are simulated by the server). Built-in ENet + SceneMultiplayer, no addons.

**Play:** title screen (or pause menu) -> **Multiplayer**. *Host* opens a listen server (port 7777 by
default, player cap, tick rate 30/60/128 Hz, optional UPnP) and reloads the arena as a networked
world. *Join* takes the host's IP (LAN, or public IP with the port forwarded / UPnP). Your class is
the one picked in Class Selection; picking another class in a session respawns you with it.
*Leave Session* returns to your own offline world.

**Command line** (after `--`):
| Flag | Meaning |
| --- | --- |
| `--server` | Dedicated server: no local player, no UI, no visuals. Run it with `--headless`. |
| `--port N`, `--max-players N` | Listen port (default 7777) and player cap (16). |
| `--tick-rate N`, `--snapshot-rate N` | Simulation rate (default 60 = `network/tick_rate`) and snapshots per second (default = tick rate). Clients adopt the server's values. |
| `--cheats` | Let clients use F5/F6 (always allowed offline and for the host). |
| `--upnp` | Dedicated server: open the port on the router. |
| `--connect IP[:PORT]`, `--name NAME`, `--class CLASS` | Join on start. |
| `--interp-ms N` | Client interpolation delay (default 60 = `network/interp_delay_ms`). |
| `--net-debug` | Start with the F3 overlay open. |
| `--net-log` | Print network stats every 2 s (server: per-peer rtt, loss, input queue and input health). |

Lag / loss simulation: `tools/net_proxy.tscn` is a UDP relay:
`Godot_v4.7.2-stable_win64_console.exe --headless --path godot tools/net_proxy.tscn -- --listen 7778 --target 127.0.0.1:7777 --latency 80 --jitter 15 --loss 2`,
then join `127.0.0.1:7778`. Latency is one-way (RTT is about twice it).

**How it works** (`scripts/net/`):
- `net.gd` (autoload `Net`): peer lifecycle, handshake (protocol version -> the client adopts the
  server's tick rate before anything is replicated), player registry, client clock, UPnP, stats.
  Offline play uses the `OfflineMultiplayerPeer` (a server with id 1), so single-player, the host and
  a dedicated server all run the same server code.
- `scenes/main.tscn` (`core/main.gd`): the level lives under `Levels` and is replicated by a
  `MultiplayerSpawner` (late joiners get it too); the UI is local and persistent.
- `net_world.gd` (`NetWorld`, one per level): characters are spawned through a `MultiplayerSpawner`
  (code-built, `spawn_function`); slow state (health, mana, shield, statuses, class resource,
  cooldowns, modifiers, inventory) rides on each character's `StateSync` synchronizer (on change,
  20 Hz max). Per tick it sends one unreliable **snapshot** per client (its own movement state + input
  ack, and every other entity) and one reliable batch of **events** (effects, damage/heal numbers,
  cast poses, animations, visual-only copies of projectiles/zones/walls/orbs). Stealthed enemies are
  left out of a client's snapshots.
- `input_frame.gd`: one tick of input (move, camera yaw/pitch, jump/sprint/attack, aim origin, the
  tick the client was viewing). Sent every tick with the last 4 frames for redundancy.
- Prediction (`characters/player_character.gd`): the client simulates its own movement with the same
  `_step_movement` the server runs, keeps unacknowledged frames, and on each snapshot rewinds to the
  server state and replays them; small errors are smoothed on the visual, big ones (> 1.5 m) snap.
  The server consumes one frame per tick per player (two when a backlog built up, waits when none
  arrived, fills sequence gaps) and a token bucket caps inputs at one per tick (speed hacks).
- Casts are reliable requests carrying the aim; the client plays the pose and starts the cooldown at
  once, the server validates, runs the spell and reports refusals. `lag_compensation.gd` rewinds
  other characters to what the shooter saw (max 200 ms) for instant hits; delayed effects
  (telegraphs, meteors) are not rewound. Remote players' projectiles are advanced by half their RTT.
- Remote entities (`net_interpolator.gd`) are drawn `interp_delay_ms` in the past, blended between
  snapshots. Physics interpolation is on, so rendering stays smooth above the tick rate.
- Effects: `TransientFX.spawn`, `ParticleFX.burst`, `Telegraph.spawn`, `LightningArc.spawn`,
  `GroundZone`, `Ability.impact` / `camera_shake` broadcast from the server and replay on clients
  (`*_local` variants draw on this peer only). Telegraph colour is judged per viewer (red = hostile to
  you). Gameplay nodes go into the level through `Game.add_to_world`.
- `net_debug_overlay.gd`: F3.

Testing scenarios, known issues and latency bugs to chase: `Docs/NETWORK_TESTING.md`.

## Classes
Every "Choose Your Path" card is a playable class (`characters/classes/`, kits in `abilities/*_kit.gd`): five
abilities plus an ultimate on key 6, a basic attack on left mouse and a class resource.
| Class | Resource | Kit (1-5, ULT) | Key interactions |
| --- | --- | --- | --- |
| Pyromancer | Heat (+30% fire dmg, Overheat at 100) | Firebolt, Flame Wave, Ember Dash, Combustion, Meteor, **Cataclysm** | Combustion eats Burn stacks; meteors on burning foes chain-combust |
| Cryomancer | Frost (from Chill) | Ice Shard, Frost Nova, Ice Wall, Crystal Armor, Shatter, **Absolute Zero** | 5 Chill = Freeze; Shatter frozen foes |
| Arcanist | Arcane Charges (4) | Arcane Missile, Arcane Barrage, Blink, Gravity Well, Singularity, **Reality Fracture** | Singularity +50% in a Gravity Well; charges scale spenders |
| Stormcaller | Static (Overcharge at 100) | Lightning Bolt, Chain Lightning, Thunder Step, Ball Lightning, Static Field, **Wrath of the Storm** | Shocked foes extend chains |
| Druid of the Veil | Nature Essence | Thorn Shot, Entangling Roots, Healing Bloom, Nature's Grasp, Ancient Guardian, **Awaken the Wild** | Thorn Shot bursts on rooted foes; Essence feeds the Guardian |
| Shadowweaver | Soul Fragments (5) | Shadow Bolt, Corruption, Curse of Frailty, Soul Drain, Soul Explosion, **Eclipse** | Corruption spreads on death; Soul Explosion eats afflictions |
| Nightblade | Combo Points (5) | Shadowstep, Fan of Blades, Smoke Bomb, Death Mark, Execution, **Nightfall** | Back attacks give double points; Ambush doubles a strike |
The original Mage and Rogue stay available (`--class Mage` / `--class Rogue`). Icons reuse the 13 existing spell
icons until dedicated art exists.

## Behaviour differences from Unreal
- Class selection spawns a distinct class per card (in Unreal every card spawned the Mage).
- The title screen title ("Nameless") is a placeholder; the WBP's title text couldn't be recovered.
- Locomotion/casting use UAL clips (`Idle`, `Walk`, `Jog_Fwd`, `Sprint`, `Jump`, `Spell_Simple_*`,
  `Sword_Attack`, `Punch_*`, `Roll`, `Hit_*`, `Death01`) instead of the mannequin ones.

## Not built yet
See `Docs/ROADMAP.md`. In short: every map except the test arena (the Unreal maps and generators are gone and must
be rebuilt), the environment kit import, minimap, interact prompt and settings.
