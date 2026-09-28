# RPGTest

Unreal Engine 5.8 C++ + Blueprint RPG project.

## Requirements
- Unreal Engine 5.8 (Epic Games Launcher)
- Visual Studio 2022 with the **Game development with C++** workload (or JetBrains Rider)
- Git + [Git LFS](https://git-lfs.com/)

## Setup
```bash
git clone <repo-url>
cd rpg-test
git lfs install
git lfs pull
```
Then right-click `RPGTest.uproject` → **Generate Visual Studio project files**, open `RPGTest.sln`,
build **RPGTestEditor / Development Editor / Win64**, and run.

## Maps
Pressing Play first shows the main menu (name, class, map, play offline / host / join); F2 in game opens the map selector:

| Map | Purpose |
| --- | --- |
| `Content/RPGTest/Maps/L_Whisperwood` | Whisperwood Forest: the procedural forest with the village, roads and a training bot. |
| `Content/RPGTest/Maps/L_TestArena` | Test Arena: a flat grid map for testing the mage, spells and bot rules. Built by `Scripts/create_test_arena.py`; see the script header for its layout and how to rebuild it. |

## Multiplayer (PvP deathmatch)
Networking uses Unreal's built-in replication over UDP (`IpNetDriver`), with a listen server: one player hosts and plays,
the others join by IP. Settings (port 7777, 60 Hz server tick, timeouts, push-model replication) are in `Config/DefaultEngine.ini`.

1. Both players open the game (packaged build, or *Standalone Game* from the editor). The main menu shows up.
2. Each one types a name and picks a class (Mage, Warlock, Paladin, Rogue, Warrior, Archer).
3. The host picks a map and presses **HOST GAME**. The menu shows the host's LAN IP.
4. The other player types that IP (e.g. `192.168.1.20` or `192.168.1.20:7777`) and presses **JOIN**.
   - Same network: use the LAN IP. Internet: the host's public IP, with UDP port 7777 forwarded to the host PC.
   - Windows Firewall asks to allow the game the first time you host: allow it.

In game: **F3** changes class (respawns), **Tab** shows the scoreboard, **F10** leaves (back to the menu),
**F2** changes map (host only; everyone follows). Every other player is an enemy; bots attack everyone.
For quick tests in the editor: *Play > Net Mode: Play As Listen Server*, *Number of Players: 2* (skips the menu).

How it is split (see the class comments for details):

| Path | Purpose |
| --- | --- |
| `Source/RPGTest/Net/RPGSessionSubsystem` | Host / join by IP / leave, connection errors |
| `Source/RPGTest/Core/RPGLocalPlayer` | Sends the player's name and class to the server on every login |
| `Source/RPGTest/Core/RPGTestGameMode`, `RPGGameState`, `RPGPlayerState` | Deathmatch rules, class per player, score, respawn, kill feed |
| `Source/RPGTest/Characters/RPGCharacterMovementComponent` | Client-predicted sprint / casting slow-down |
| `Source/RPGTest/Abilities/RPGGameplayAbility` | Client-predicted ability activation (GAS), aim sent to the server as target data |
| `Source/RPGTest/UI/SRPGMenuWidgets` | Main menu and class picker (Slate) |

## Classes and combat (Gameplay Ability System)
Controls: **left mouse** is the class's basic attack (hold to keep attacking), **1-5** its abilities.

| Class | Resource | Basic attack / abilities 1-5 |
| --- | --- | --- |
| Mage | Mana | Arcane Bolt / Fireball, Frost Nova, Lightning Strike, Blink, Arcane Shield |
| Warlock | Mana | Fel Bolt / Shadow Bolt, Corruption (DoT), Drain Life (channel), Fear, Demonic Circle (place / return) |
| Paladin | Mana | Sword Swing (shield blocks 15% frontal damage) / Crusader Strike, Hammer of Justice (stun), Flash of Light, Cleanse (usable while stunned), Divine Shield |
| Rogue | Energy | Dagger Slash / Stealth, Backstab (x2 from behind), Throwing Knife (poison + slow), Kidney Shot, Shadowstep |
| Warrior | Rage | Sword Slash / Charge, Mortal Strike (halves healing), Hamstring, Whirlwind, Berserker Rush |
| Archer | Energy | Quick Shot / Aimed Shot, Multi-Shot, Concussive Shot (slow), Disengage (leap back), Rain of Arrows |

PvP rules shared by everyone: stuns, freezes, fears and roots have diminishing returns (full, half, quarter, then
immune for 15 s); fear breaks after 15% max health in damage; stealth breaks on attacking or taking damage and enemies
within 3.5 m see through it; damage over time prevents entering stealth.

How it is built (`Source/RPGTest/Abilities` and `Source/RPGTest/Spells`):

| Piece | Role |
| --- | --- |
| `URPGAbilitySystemComponent` | One per character: vitals and class resource (regen, rage), damage/heal pipeline, statuses (immunities, diminishing returns, break on damage), hotbar slots |
| `URPGAttributeSet` | Health, resource, shield + IncomingDamage/IncomingHealing meta attributes |
| `URPGGameplayAbility` | Base of every ability: cost, cooldown, cast time, predicted activation, server-validated aim |
| `RPGAbilityArchetypes` | Data-only ability shapes: Projectile, MeleeStrike, SelfBuff, TargetedDebuff, Nova |
| `RPGStatusEffects` | One table row per status (stun, slow, burn, stealth...): display, overlay, immunities, diminishing returns |
| `RPGGameplayEffects` | Generic effects (damage, heal, cost, timed/infinite status, damage over time) configured with set-by-caller data |
| `URPGCombatLibrary` | `ApplyDamage` / `ApplyHeal` / `ApplyStatus`, hostility, melee arcs, "is behind" |

Adding an ability: subclass an archetype (or `URPGGameplayAbility` for something bespoke), fill in the numbers in the
constructor and give it its own cooldown tag (`Cooldown.<Class>.<Ability>`). `ExecuteSpell` runs on the server only:
anything visible must be a replicated actor, replicated state or `ARPGTransientFX::SpawnForAll`.
Adding a status: a native tag in `RPGGameplayTags` and a row in `RPGStatusEffects.cpp`; the HUD, overlays and
immunities pick it up. Adding a class: derive from `ARPGPlayerCharacter`, set `SetClassStats`, `AbilityClasses`
(slot 0 = left mouse), optional `PassiveTags` and the look (`AddCosmeticPart` / `AddBladeParts`) in the constructor,
and add a row to `CharacterClasses` in `URPGGameInstance`'s constructor.

Testing: `RpgSelfTest All` (console, host or client) uses every ability of every class on the arena's duel bot and
logs what each did; `-RPGAutoSelfTest=All` on the command line runs it after joining (e.g. a client started with
`127.0.0.1 -game -RPGAutoSelfTest=All`, to exercise the networked path). `-LogCmds="LogRPG Verbose"` logs every
release and hit on the server.

## Layout
| Path | Purpose |
| --- | --- |
| `Source/RPGTest/Core` | Game mode, game instance, player controller |
| `Source/RPGTest/Characters` | Player classes and NPCs |
| `Source/RPGTest/Abilities` | Gameplay Ability System layer: ability system component, attributes, effects, tags, statuses |
| `Source/RPGTest/Spells` | Ability archetypes, class kits, projectiles and other spell actors |
| `Source/RPGTest/Components` | Reusable actor components |
| `Source/RPGTest/UI` | C++ widget base classes |
| `Content/RPGTest/*` | Project assets (Marketplace/Fab packs go at `Content/` root) |
| `Content/LevelPrototyping` | Grid materials and blockout meshes from the engine's Level Prototyping template pack |
| `Scripts/` | Editor Python scripts (run with `UnrealEditor-Cmd -run=pythonscript` or Tools > Execute Python Script) |
| `Config/` | Project settings |
| `Plugins/` | Project plugins |

Binary assets (`.uasset`, `.umap`, textures, audio, meshes) are stored with Git LFS — see `.gitattributes`.
