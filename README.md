# RPGTest

A PvP deathmatch RPG prototype made with [Godot 4.7](https://godotengine.org/download): sixteen classes with three
weapons each, a procedural forest and a test arena. Play offline against bots, or host a listen server that friends
join by IP. On-screen panels explain every ability, hold a 10-slot weapon inventory and let you tweak any balance
number while playing.

The game is the Godot project in [`godot/`](godot/). Open `godot/project.godot` in the Godot editor and press **F5**,
or run it from a terminal:

```bash
godot --path godot                                      # main menu
godot --path godot -- --map=2 --class=Mage --no-menu    # straight into the Test Arena
```

See [`godot/README.md`](godot/README.md) for the controls, classes, weapons, tool panels, multiplayer, project layout
and testing.
