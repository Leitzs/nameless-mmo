# CLAUDE.md

Guidance for Claude Code when working in `godot/`, the Godot 4.7 project of RPGTest: a PvP deathmatch RPG prototype
with sixteen classes (three weapons each), a listen server and join by IP. `README.md` has the player-facing details
(controls, tool panels, weapons), the layout and the "adding an ability / weapon / status / class / map" recipes; read
it before changing gameplay.

## Commands
`godot` is the Godot 4.7 binary (on Windows the `_console.exe` variant prints to the terminal; on macOS it is
`/Applications/Godot.app/Contents/MacOS/Godot`). Run from the repository root.

```bash
godot --headless --path godot --import                                    # (re)import after adding files; creates .uid files and registers new class_names
godot --headless --path godot -s res://tools/check_project.gd             # compile/load/instantiate everything
godot --headless --path godot -- --map=2 --no-menu --auto-self-test=All --quit-after-self-test   # gameplay test, exit 0 = pass
godot --headless --path godot -- --host --map=2                           # networked test: host...
godot --headless --path godot -- --connect=127.0.0.1 --auto-self-test=All --quit-after-self-test # ...and client
```

The self test must end with `SelfTest: all done, 128/128 abilities activated.` both offline and from a client (about
8 minutes; `--auto-self-test=<class id>` tests one class). Per class it checks slots 1-5 and the basic attack with the
first weapon, then the basic attack with each other weapon. Add `--log-verbose` to log every release and hit. There is
no unit test framework yet.

A new `class_name` isn't known to other scripts until `--import` runs. A script run with `-s` that names project
classes (or autoloads) in type hints fails to parse; load such code at runtime with `load("...").new()` instead.

Every run ends with "2 ObjectDB instances were leaked" / "1 resources still in use" for `status_effect.gd`. That's an
engine quirk with a script whose typed array uses its own type (`blocked_by: Array[StatusEffect]`) and is harmless.
Any other leak report is a real bug; find it with `--verbose`.

## Conventions
- Typed GDScript, strict: untyped declarations and unsafe void returns are **errors** (`project.godot`). Type every
  variable, parameter and return. Loops over untyped arrays need `for x: T in ...`. Use `:=` only when the type is
  obvious.
- Tabs for indentation. `snake_case` files and functions, `PascalCase` `class_name`. Private members start with `_`.
  Doc comments use `##`.
- Units are meters and seconds. Characters face -Z and their origin is at the feet.
- Colors given to materials, UI and FX are sRGB. The procedural world (`WorldGenerator`, `MedievalProp`) works in
  linear colors, feeding `surface_instanced.gdshader` and vertex colors.
- Content is data. New classes, abilities, weapons, statuses and maps are `.tres` resources registered in
  `data/game_data.tres` (weapons in their class's `weapons`), not code. Keep new abilities on the archetypes in
  `abilities/archetypes/`, and put bespoke behavior in small scripts under `abilities/special/`. Give new abilities a
  `describe()` so the spellbook and Balance panel can explain them.
- Share materials and meshes through `Materials` (`core/materials.gd`), and effects through `FX` / `AbilityFX`.

## Architecture rules that are easy to break
- **Server authority.** `Ability.execute`, `Combat.apply_damage/apply_heal/apply_status`, bot AI, the match rules,
  inventory changes (`Inventory`) and balance changes (`Tuning`) run on the server only. Anything visible from them
  must be one of:
  - a spawned actor (`Game.current_map.spawn_actor(data)`, whose scene implements `configure_spawn(data)`)
  - state synced by the character's `ServerSync` (health, statuses, cooldowns, `weapon_id`...) or a `PlayerInfo`
    (score, inventory)
  - `FX.spawn_for_all`
- **Movement belongs to the owner.** `MovementSync` authority is the owning peer. Server-side knockback, launches and
  teleports go through the character's RPCs to the owner. Movement inside an ability happens in `on_release`, which
  runs on the caster's machine, and is sent to the server in `ctx.payload`.
- **RPCs.** `any_peer` RPCs check `multiplayer.get_remote_sender_id()`; server→owner RPCs are `authority`. Offline
  runs on `OfflineMultiplayerPeer` (peer 1 = server), so there's no separate offline code path.
- **Synced containers** (`StatusEffects.active`, `AbilityCaster.cooldowns`, `PlayerInfo.items`) must be reassigned
  with a new Dictionary/array to replicate. Mutating them in place doesn't sync.
- **Weapon and balance multipliers.** Direct damage from abilities goes through `SpellContext.damage_multiplier`
  (use `get_damage_multiplier(ctx)` or `ctx.damage_multiplier`, including for what summons and delayed blasts deal);
  `Combat` applies the global damage/healing multipliers, the weapon's healing and its damage-over-time multiplier.
  Costs, cooldowns and attack speed come from `AbilityCaster.get_cost/get_ability_cooldown` and the character's
  `get_*_multiplier` functions, never from `Ability.resource_cost` / `cooldown` directly.
- **Live balance.** `Tuning` writes into the shared resources in memory, so read numbers from the resources when you
  use them, don't cache them. Stats copied onto a character (max health, max resource, regen, frontal block) are
  refreshed by `CombatCharacter.refresh_stats()` on `Tuning.changed`.
- **Timed steps.**
  - Abilities use coroutines: `await ctx.wait(t)`, then `if not ctx.is_active(): return`.
  - Node scripts use `get_tree().create_timer(t).timeout.connect(...)`, never `await`, so a freed node can't resume.
- **Avoid RefCounted cycles.** `CastInstance.context` is cleared when a cast ends. Keep back-references one-way or
  clear them, or they leak.
- **Tool panels and input.** The panels under `UI/Panels` stay visible while playing; `GameUI` disables their mouse
  and focus whenever gameplay has the input (the captured mouse sits at the screen center). Opening a panel frees the
  mouse; new panels should go through `GameUI.toggle_panel`.
- **Physics layers** are in `RPG.LAYER_*`: 1 world, 2 characters, 4 bounds. Use them, not literals.
- **Log** through `RPGLog.info/verbose/warn`, which prefixes the network role.

## Where things are
`game/main.gd` has the game flow and the command-line options. `game/match.gd` holds the deathmatch rules and
`game/inventory.gd` the inventory rules. `characters/combat_character.gd` is the character hub (weapon, stats).
`abilities/ability_caster.gd` runs the cast flow and its networking. `abilities/combat.gd` has the damage rules and
queries, `abilities/ability_text.gd` the ability explanations. `autoload/tuning.gd` applies and replicates balance
changes. `characters/components/status_effects.gd` handles immunities, diminishing returns and DoTs. `ui/panels/` has
the tool bar, spellbook, inventory and balance panels. `game/dev/` has the console commands and the self test.
