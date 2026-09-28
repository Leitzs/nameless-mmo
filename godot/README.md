# RPGTest (Godot)

A PvP deathmatch RPG prototype: sixteen classes, a procedural forest and a test arena. Play offline against bots, or
host a listen server that friends join by IP. This is the Godot 4 version of the Unreal project in the repository
root. It lives next to it until it reaches parity (the ten classes after the Archer exist only here).

## Requirements
- [Godot 4.7](https://godotengine.org/download) standard build. The .NET build is not needed, and there are no addons.
- Git + Git LFS (the repository's binary assets use LFS; the Godot project itself is text only).

## Run
Open `godot/project.godot` in the Godot editor and press **F5**. The main menu has fields for your name and class and
buttons for the map and for playing offline, hosting or joining.

From a terminal (`godot` is the Godot binary; on Windows use the `_console.exe` variant to see the output), any
option goes after `--`:

```bash
godot --path godot                                            # main menu
godot --path godot -- --map=2 --class=Rogue --no-menu         # straight into the Test Arena as a rogue
godot --path godot -- --host --map=1                          # host Whisperwood on port 7777
godot --path godot -- --connect=127.0.0.1 --name=Bob          # join a host
```

| Option | Effect |
| --- | --- |
| `--map=N` | Map to open (1 = Whisperwood Forest, 2 = Test Arena) |
| `--class=Name`, `--name=Name` | Class and player name for this run (the saved profile is left alone) |
| `--no-menu` | Skip the main menu when playing offline |
| `--host`, `--connect=IP[:port]` | Host a game / join one |
| `--auto-self-test=Class\|All`, `--quit-after-self-test` | Run the ability self test after spawning (see Testing) |
| `--log-verbose` | Log every ability release and hit |

## Maps
| Map | Scene | Purpose |
| --- | --- | --- |
| Whisperwood Forest | `maps/whisperwood/whisperwood.tscn` | Procedural forest (`WorldGenerator`) with a village, roads, ruins and a training bot |
| Test Arena | `maps/test_arena/test_arena.tscn` | Flat grid arena: a duel bot with range rings, a group of three, cover, high ground and a range lane |

## Multiplayer (PvP deathmatch)
Built-in high-level multiplayer (ENet over UDP, port 7777) with a listen server: one player hosts and plays, and the
others join by IP. In the menu the host picks a map and presses **HOST GAME**, which shows the host's LAN IP. The
other players type that IP and press **JOIN**. Over the internet, use the host's public IP and forward UDP port 7777
to the host PC. Windows Firewall asks to allow Godot the first time you host.

In game: **F3** changes class (you respawn), **Tab** shows the scoreboard and **F10** leaves. **F2** changes the map
(host only; everyone follows). Every other player is an enemy, and bots attack everyone.

The model is **"owner moves, server rules"**. Each machine simulates its own character's movement. The server
validates and executes abilities, damage, statuses, deaths and score. Offline play uses Godot's
`OfflineMultiplayerPeer`, so offline and online run the same code.

## Classes and combat
**Left mouse** is the basic attack (hold it to keep attacking) and **1-5** are the abilities. **WASD** moves,
**Space** jumps, **Shift** sprints, the mouse aims (soft lock on the enemy under the crosshair), **`** opens the
console and **F1** toggles the controls panel.

| Class | Resource | Basic attack / abilities 1-5 |
| --- | --- | --- |
| Mage | Mana | Arcane Bolt / Fireball, Frost Nova, Lightning Strike, Blink, Arcane Shield |
| Warlock | Mana | Fel Bolt / Shadow Bolt, Corruption (DoT), Drain Life (channel), Fear, Demonic Circle (place / return) |
| Paladin | Mana | Sword Swing (shield blocks 15% frontal damage) / Crusader Strike, Hammer of Justice (stun), Flash of Light, Cleanse (usable while stunned), Divine Shield |
| Rogue | Energy | Dagger Slash / Stealth, Backstab (x2 from behind), Throwing Knife (poison + slow), Kidney Shot, Shadowstep |
| Warrior | Rage | Sword Slash / Charge, Mortal Strike (halves healing), Hamstring, Whirlwind, Berserker Rush |
| Archer | Energy | Quick Shot / Aimed Shot, Multi-Shot, Concussive Shot (slow), Disengage (leap back), Rain of Arrows |
| Cleric | Mana | Smite / Holy Fire (burn), Renew (heal over time), Silence, Psychic Scream (area fear), Sanctuary (holy ground that heals you) |
| Druid | Mana | Wrath / Moonfire (damage over time), Entangling Roots, Rejuvenation (heal over time), Typhoon (cone knockback), Barkskin (usable while stunned) |
| Necromancer | Mana | Bone Shard / Bone Spear, Decrepify (slow + weaken), Raise Wraith (follower that shoots), Bone Armor (absorb), Grasp of the Dead (area root) |
| Shaman | Mana | Lightning Bolt / Chain Lightning, Frost Shock, Capacitor Totem (delayed area stun), Healing Stream Totem, Ghost Wolf (speed) |
| Monk | Energy | Jab / Rising Sun Kick, Flying Kick (dash through), Paralysis, Leg Sweep (area stun), Vivify (heal) |
| Barbarian | Rage | Cleave (hits every enemy in front) / Leap, Rend (bleed), Hurl Axe, War Cry (weakens enemies), Earthquake (aura) |
| Bard | Mana | Dissonant Note / Vicious Mockery (weaken), Lullaby (sleep), Thunderwave (knockback), Song of Rest, Inspire (speed + damage) |
| Death Knight | Runic power | Rune Strike / Death Grip (pull), Death Strike (heals for the damage), Chains of Ice, Death and Decay, Icebound Fortitude |
| Demon Hunter | Fury | Demon's Bite / Fel Rush, Chaos Strike, Eye Beam (channel), Chaos Nova (area stun), Metamorphosis (leap + demon form) |
| Summoner | Mana | Spirit Bolt / Fire Elemental, Frost Wisp (followers that shoot), Stone Guardian, Spirit Ward (absorb), Meteor |

Rage, fury and runic power start empty, are built by fighting and drain out of combat.

PvP rules:
- Stuns, freezes, fears, roots, sleeps, paralysis and silences have diminishing returns: full duration, then half, then a quarter, then immunity until 15 s pass without one.
- Fear breaks after the target takes 15% of its max health in damage; sleep and paralysis break on any damage.
- Silence blocks every ability but the basic attack and interrupts the spell being cast. Crowd-control breakers (Cleanse, Barkskin, Icebound Fortitude) still work.
- Stealth breaks when you attack or take damage, and enemies within 3.5 m see through it.
- Damage over time prevents entering stealth.
- Using a summon again replaces the previous one; summons vanish when their caster dies.

## Project layout
| Path | Purpose |
| --- | --- |
| `autoload/` | `Game` (content registry, profile, local player), `Session` (host / join / clock sync), `FX` (effects for everyone) |
| `core/` | `RPG` (shared enums and constants), `RPGLog`, `Materials` (shared materials and primitive meshes) |
| `game/` | `main.tscn` (root scene and game flow), `Match` (deathmatch rules, respawn, kill feed), `PlayerInfo`, `GameMap`, `GameData`, dev console commands and the self test |
| `characters/` | `CombatCharacter` plus its components (`Health`, `ResourcePool`, `StatusEffects`), player (`PlayerInput`, `PlayerCamera`), bots (`BotBrain`, `BotSpawner`) and the swappable visual (`CharacterVisual`, blockout body, cosmetics) |
| `abilities/` | `Ability` base, `AbilityCaster` (cast flow and networking), `Combat` (damage / heal / status rules, queries), archetypes, special abilities and spell actors (projectile, delayed blast, demonic circle, summon) |
| `statuses/` | `StatusEffect` (a status as data) and `StatusSpec` (status + duration + magnitude) |
| `data/` | All content as resources: `game_data.tres` (the registry), classes, abilities per class, statuses, maps |
| `maps/` | Level scenes |
| `world/` | `WorldGenerator` (terrain, roads, vegetation, navmesh), `MedievalProp`, clearings and paths |
| `fx/` | Shaders, shared materials, transient effects and floating combat text |
| `ui/` | `GameUI` (menus, HUD, console), `rpg_theme.tres` |
| `tools/` | `check_project.gd`: loads and compiles everything headless |

## How it is built
- **Scenes and composition.** A character is a `CharacterBody3D` (`CombatCharacter`) with component child nodes. What
  controls it is also a child: `PlayerInput` + `PlayerCamera` for players, `BotBrain` + `NavigationAgent3D` for bots.
  Components talk through signals.
- **Data-driven content.** Classes, abilities, statuses and maps are `Resource`s in `data/`, listed in
  `data/game_data.tres`. Most abilities are data-only instances of nine archetypes:
  - `ProjectileAbility`, `MeleeStrikeAbility` (also frontal cones), `SelfBuffAbility`, `TargetedDebuffAbility`,
    `NovaAbility`
  - `DashStrikeAbility`: dashes and leaps that strike along the path or on landing
  - `SummonAbility`: a `Summon` that stays or follows the caster, pulses around itself and/or shoots (totems,
    consecrated ground, elementals)
  - `ChannelBeamAbility`: channeled beams, optionally draining life
  - `GroundBlastAbility`: telegraphed strikes on the ground

  Bespoke ones are small scripts in `abilities/special/`. Statuses cover crowd control (stun, sleep, fear, root,
  silence), speed, damage and healing over time, damage dealt and taken multipliers, shields and invulnerability.
- **Networking.** `Main/LevelSpawner` replicates the map, `Main/PlayerSpawner` the players' info, and each map's
  `ActorSpawner` replicates characters and spell actors from spawn data. A `MultiplayerSynchronizer` per character
  syncs movement (authority: the owning peer) and the server-owned state of the components.
  - Abilities: the owner predicts the start (animation, facing, cooldown) and sends its aim; the server validates it and
    runs `Ability.execute`.
  - Timed steps in abilities are coroutines (`await ctx.wait(t)`).
- **Visuals.** No imported art: primitive meshes, a grid shader, an additive glow shader for all effects and a
  keyframed blockout body with an `AnimationTree`. `CharacterVisual` is the only thing gameplay talks to, so a rigged
  model can replace the blockout body later.

## Adding content
- **An ability.** In the FileSystem dock, create a new resource of an archetype type (e.g. `ProjectileAbility`) in
  `data/abilities/<class>/`. Give it a unique `id` (`class.name`) and fill in the numbers in the inspector. Then add it
  to the class's `abilities` array (index 0 = left mouse, 1-5 = keys). For new behavior, extend `Ability` or an
  archetype in `abilities/special/` and override `execute` (server only). If there is a movement part, also override
  `on_release` (runs on the caster's machine). Anything visible must be a spawned actor (`Game.current_map.spawn_actor`),
  synced state or `FX.spawn_for_all`.
- **A status.** Create a `StatusEffect` resource in `data/statuses/`. Pick its `effect`, rules (`blocked_by`, diminishing
  returns, break on damage) and overlay, then add it to `statuses` in `data/game_data.tres`. The HUD, nameplates and
  body overlays pick it up. Abilities apply it with a `StatusSpec` (status, duration, magnitude).
- **A class.** Create a `CharacterClass` resource in `data/classes/` (stats, resource, abilities, colors, `cosmetics`)
  and add it to `classes` in `data/game_data.tres`. It shows up in the menu and the class picker.
- **A map.** Make a scene whose root has `game/game_map.gd`, with an `Actors` node, an `ActorSpawner`
  (`MultiplayerSpawner` whose spawn path is `Actors`) and at least one `Marker3D` in the `player_start` group. Use
  `maps/test_arena/test_arena.tscn` as the template. Add `BotSpawner` markers for bots and a `NavigationRegion3D` if
  bots should path-find. Then create a `MapInfo` resource in `data/maps/` and add it to `maps` in
  `data/game_data.tres`.

## Testing
There is no unit test framework yet. Gameplay is checked with the self test, which casts every ability of a class
at a bot and logs what each one did:

```bash
# Everything compiles, loads and instantiates
godot --headless --path godot -s res://tools/check_project.gd
# Offline: every ability of every class on the Test Arena's duel bot (exit code 0 = all passed)
godot --headless --path godot -- --map=2 --no-menu --auto-self-test=All --quit-after-self-test
# Networked: a host, plus a client that runs the self test through the server
godot --headless --path godot -- --host --map=2
godot --headless --path godot -- --connect=127.0.0.1 --auto-self-test=All --quit-after-self-test
```

In game, the console (**`**) has `selftest [Class|All]`, `cast <slot>`, `refill`, `god`, `gotobot`, `status` and
`map <n>`. The Unreal names (`RpgSelfTest`...) work too. In the editor, *Debug > Customize Run Instances* runs a host
and a client side by side.

## Differences from the Unreal version
- Epic's Manny/Quinn and the LevelPrototyping pack can't be used outside Unreal. They are replaced by the code-built
  blockout body with keyframed animations and by a grid shader.
- The Gameplay Ability System is replaced by plain Godot pieces:
  - character components: `Health`, `ResourcePool`, `StatusEffects`, `AbilityCaster`
  - resources: `Ability`, `StatusEffect`
  - enums instead of gameplay tags
- The Slate menus are Control scenes styled by one `Theme`, and the Python-built arena is a regular scene you edit in
  the editor.
- Networking uses Godot's scene replication and RPCs instead of actor replication. The rules and the self test are the
  same; with the ten extra classes, 96/96 abilities pass offline and from a remote client.
