# nameless-mmo

Action-RPG built in **Godot 4.7.2** with GDScript. It started as an Unreal Engine 5.8 C++ project (RPGTest), which was ported to Godot and then removed.

## Requirements
- [Godot 4.7.2](https://godotengine.org/) (standard build, not .NET)
- Git + [Git LFS](https://git-lfs.com/)
- Blender, only to rebuild the asset kit (`Scripts/blender_kit/`)

## Setup
```bash
git clone <repo-url>
cd nameless-mmo
git lfs install
git lfs pull
```
Open `godot/project.godot` in the Godot editor and press Play, or run
`Godot_v4.7.2-stable_win64.exe --path godot`.
The main scene is `scenes/test_arena.tscn`, and the title screen shows on first load.

Self test (headless; exits 0 on success, 1 on failure):
`Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --selftest`

## Layout
| Path | Purpose |
| --- | --- |
| `godot/` | The game: scripts, scenes, assets. Details in `godot/README.md`. |
| `Art/` | Blender kit (`Art/Blender`), exported FBX/materials (`Art/Export`), third-party CC0 sources (`Art/ThirdParty`) |
| `Scripts/blender_kit/` | Blender Python that builds the kit and the game characters |
| `Docs/ROADMAP.md` | Current state and open TODOs |

Binary assets (meshes, textures, audio) are stored with Git LFS. See `.gitattributes`.
