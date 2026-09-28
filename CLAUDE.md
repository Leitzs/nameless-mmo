# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

RPGTest is an Unreal Engine 5.8 C++ project: a PvP deathmatch RPG prototype (listen server, join by IP) with six
classes built on the Gameplay Ability System. `README.md` has the player-facing details (controls, class kits, PvP
rules, maps) and the "how to add an ability / status / class" recipe; read it before changing gameplay.

The game is being migrated to Godot 4.7 in `godot/`, which has its own `CLAUDE.md` and `README.md`. Work there follows
Godot conventions, not the Unreal patterns described below.

## Build and run

Single runtime module `RPGTest` (`Source/RPGTest`, dependencies in `RPGTest.Build.cs`). `<UE>` below is the engine
install dir (e.g. `C:\Program Files\Epic Games\UE_5.8`).

```bash
# Build the editor target (same as VS: RPGTestEditor / Development Editor / Win64)
"<UE>/Engine/Build/BatchFiles/Build.bat" RPGTestEditor Win64 Development -Project="%CD%/RPGTest.uproject" -WaitMutex

# Regenerate project files after adding/removing source files
"<UE>/Engine/Build/BatchFiles/Build.bat" -projectfiles -project="%CD%/RPGTest.uproject" -game

# Run a standalone game client that joins a local host and runs the automated self-test
"<UE>/Engine/Binaries/Win64/UnrealEditor.exe" "%CD%/RPGTest.uproject" 127.0.0.1 -game -RPGAutoSelfTest=All -log
```

If the editor is open, a command-line build of the editor target fails (DLLs locked); use Live Coding instead
(the `unreal-mcp` skill can trigger it when the MCP server is connected). Header/UPROPERTY layout changes need a
full rebuild with the editor closed.

Editor Python scripts live in `Scripts/` and run with
`UnrealEditor-Cmd.exe RPGTest.uproject -run=pythonscript -script=<path>` (editor closed) or Tools > Execute Python
Script. `Scripts/create_test_arena.py` rebuilds `L_TestArena`; its docstring has the full command, including the
navmesh bake step.

## Testing

There are no automation-framework unit tests. Gameplay is verified with `Exec` console commands on
`ARPGPlayerController` (development builds, host or client):

- `RpgSelfTest [Class|All]` — casts every ability of a class on the nearest bot and logs the outcome; run on
  `L_TestArena` (its duel bot has clear ground around it). A single class is the "single test" equivalent.
- `RpgCast <slot>`, `RpgRefill`, `RpgGod`, `RpgGoToBot`, `RpgStatus`, `RpgMap <n>` — manual debugging helpers.
- `-LogCmds="LogRPG Verbose"` logs every ability release and hit on the server. The module's log category is `LogRPG`
  (`RPGTest.h`).
- Networked path: PIE with *Net Mode: Play As Listen Server, 2 players*, or a host plus a `-game` client with
  `-RPGAutoSelfTest=All` as above.

## Architecture

**Networking model.** Listen server, server-authoritative. `ARPGTestGameMode` (deathmatch rules, respawn, class per
player) + `ARPGGameState` / `ARPGPlayerState` (score, kill feed). `URPGLocalPlayer` (set via `LocalPlayerClassName`)
sends the chosen name/class in the login URL; `URPGSessionSubsystem` handles host/join/leave. Push-model replication
is enabled, so replicated properties need `MARK_PROPERTY_DIRTY` when changed. Sprint/cast slow-down is predicted in
`URPGCharacterMovementComponent`.

**GAS layout.** The `URPGAbilitySystemComponent` lives on the character (`ARPGCharacterBase`), not the PlayerState, and
is the hub: vitals, class resource (mana/energy/rage), the damage/heal pipeline, statuses with immunities and
diminishing returns, and the hotbar. Damage and healing go through `IncomingDamage`/`IncomingHealing` meta attributes
on `URPGAttributeSet`; gameplay code should call `URPGCombatLibrary::ApplyDamage/ApplyHeal/ApplyStatus` rather than
applying effects directly. Effects in `RPGGameplayEffects` are generic and parameterized by set-by-caller magnitudes.
Gameplay tags are native (`RPGGameplayTags`), not ini/DataTable-defined.

**Abilities.** `URPGGameplayAbility` handles cost, cooldown, cast time, local prediction and server-validated aim
(sent as target data). Class kits (`Spells/<Class>Spells`) are mostly subclasses of the data-only archetypes in
`RPGAbilityArchetypes` (Projectile, MeleeStrike, SelfBuff, TargetedDebuff, Nova) with numbers set in constructors.
`ExecuteSpell` runs only on the server, so any visual must be a replicated actor/state or
`ARPGTransientFX::SpawnForAll`. Statuses are rows in `RPGStatusEffects.cpp`; HUD and overlays read from there.
Keep new abilities on these shared archetypes; the old spellbook/status components were removed in the GAS migration
and should not come back.

**Classes.** `ARPGCharacterBase` → `ARPGPlayerCharacter` (abstract) → `Mage/Warlock/Paladin/Rogue/Warrior/ArcherCharacter`;
`AEnemyBotCharacter` + `ARPGBotAIController`/`ARPGBotSpawner` for bots (which attack everyone). A class is configured
entirely in its constructor (`SetClassStats`, `AbilityClasses` with slot 0 = LMB, `PassiveTags`, cosmetic parts) and
registered in `URPGGameInstance::CharacterClasses`.

**Code-built content.** There are no gameplay Blueprints: characters, UI and visuals are defined in C++. Menus are
plain Slate (`UI/SRPGMenuWidgets`), the HUD is `ARPGHUD`. Visuals are engine primitives plus two master materials,
with all asset paths centralized in `Core/RPGAssets.h` (color passed through custom primitive data). Whisperwood's
forest/village is generated by `ARPGWorldGenerator`; `L_TestArena` is placed actors built by the Python script.

## Conventions

- Tabs, 4-wide, for C++/C#/ini (`.editorconfig`); `RPG` prefix on all project types.
- Binary assets are in Git LFS (`.gitattributes`); Marketplace/Fab packs go at `Content/` root, project assets under
  `Content/RPGTest/`.
- `.mcp.json` points at the in-editor `unreal-mcp` server (plugins `ModelContextProtocol`, `AllToolsets`); it only
  works while the editor is running.
