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

## Layout
| Path | Purpose |
| --- | --- |
| `Source/RPGTest/Core` | Game mode, game instance, player controller |
| `Source/RPGTest/Characters` | Player and NPC classes |
| `Source/RPGTest/Components` | Reusable actor components (stats, inventory, ...) |
| `Source/RPGTest/UI` | C++ widget base classes |
| `Content/RPGTest/*` | Project assets (Marketplace/Fab packs go at `Content/` root) |
| `Config/` | Project settings |
| `Plugins/` | Project plugins |

Binary assets (`.uasset`, `.umap`, textures, audio, meshes) are stored with Git LFS — see `.gitattributes`.
