"""
Builds /Game/RPGTest/Maps/L_TestArena: a flat, hand-laid test map for the mage, the spells and the enemy bot.

Run it with the editor closed, from the project root, then bake the navmesh the bots patrol and chase on:
    "<UE>/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" "%CD%/RPGTest.uproject" -run=pythonscript -script="%CD%/Scripts/create_test_arena.py"
    "<UE>/Engine/Binaries/Win64/UnrealEditor-Cmd.exe" "%CD%/RPGTest.uproject" -run=ResavePackages -BuildNavigationData -Package=/Game/RPGTest/Maps/L_TestArena "-ini:Engine:[/Script/NavigationSystem.NavigationSystemV1]:bWaitForAsyncLoadingBeforeBuildingNavigationAutomatically=False"
(the -ini override lifts an editor lock that only a ticking editor would release). It also runs inside the editor (Tools > Execute Python Script), where the navmesh builds on its own; save the map afterwards.
Running it again rebuilds the map in place.

The result is ordinary placed actors (nothing is generated at runtime), so the level can be edited by hand afterwards.

Layout (1 unit = 1 cm, X is forward from the spawn, Y is to the right, the floor top is at Z = 0):
  Spawn        (-6500, 0)       Player start on a blue pad, facing the duel bot. Outside every bot's reach.
  Duel         (0, 0)           1 bot. Its patrol / aggro / leash ranges are drawn on the floor by the spawner.
                                Nothing stands within 27 m of it, so RpgSelfTest (which teleports the player around
                                the nearest bot and blinks away from it) always has open ground.
  High ground  (-2500, -3000)   2 m platform with a ramp, inside the duel bot's leash ring.
  Group        (5200, -4200)    3 bots for area spells, too far away to be pulled by the duel fight.
  Cover wall   16 m before the group, across the path from the spawn: behind it the bots cannot see you
                                (they need line of sight to aggro), step out and they come.
  Range lane   X = -6500        Runs from the spawn towards -Y with a mark every 5 m up to 45 m (Fireball range).
  PvP starts   +Y side          4 more player starts for deathmatch, away from every bot's aggro ring.
"""

import math

import unreal

MAP_PATH = "/Game/RPGTest/Maps/L_TestArena"

ARENA_HALF_X = 8000.0
ARENA_HALF_Y = 6000.0
WALL_HEIGHT = 400.0

SPAWN = (-6500.0, 0.0)
DUEL = (0.0, 0.0)
GROUP = (5200.0, -4200.0)
COVER_DISTANCE = 1600.0   # from the group, towards the spawn
COVER_LENGTH = 2600.0
PLATFORM = (-2500.0, -3000.0)
PLATFORM_SIZE = 1200.0
PLATFORM_HEIGHT = 200.0
RANGE_LANE_X = -6500.0
RANGE_LANE_START_Y = -500.0
RANGE_LANE_WIDTH = 1400.0
RANGE_MARK_SPACING = 500.0
RANGE_MARK_COUNT = 9
PVP_STARTS = [(-6500.0, 4500.0), (-2500.0, 4800.0), (2500.0, 4800.0), (7000.0, 3000.0)]

FLOOR_MATERIAL = "/Game/LevelPrototyping/Materials/MI_PrototypeGrid_Gray"
BLOCK_MATERIAL = "/Game/LevelPrototyping/Materials/MI_PrototypeGrid_TopDark"
SURFACE_MATERIAL = "/Game/RPGTest/Materials/M_RPG_Surface"
CUBE_MESH = "/Engine/BasicShapes/Cube"
CYLINDER_MESH = "/Engine/BasicShapes/Cylinder"

GEOMETRY = "Arena/Geometry"
MARKINGS = "Arena/Markings"
SIGNS = "Arena/Signs"
LIGHTING = "Lighting"
GAMEPLAY = "Gameplay"

# Rotations are (pitch, yaw, roll) like FRotator. Text faces its local +X.
FACE_SPAWN = (0.0, 180.0, 0.0)          # upright, readable from the spawn looking +X
FACE_POSITIVE_Y = (0.0, 90.0, 0.0)      # upright, readable when looking towards -Y
FLOOR_TOWARDS_NEGATIVE_Y = (90.0, 90.0, 0.0)  # lying on the floor, readable when looking towards -Y

WHITE = (235, 235, 230)
GOLD = (255, 205, 90)
GREEN = (60, 200, 70)
AMBER = (255, 160, 20)
RED = (235, 50, 40)

actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)


def load(path):
    asset = unreal.load_asset(path)
    if asset is None:
        raise RuntimeError("Missing asset " + path)
    return asset


def rotator(rotation):
    return unreal.Rotator(roll=rotation[2], pitch=rotation[0], yaw=rotation[1])


def spawn(actor_class, label, folder, location=(0.0, 0.0, 0.0), rotation=(0.0, 0.0, 0.0)):
    actor = actors.spawn_actor_from_class(actor_class, unreal.Vector(*location), rotator(rotation))
    if actor is None:
        raise RuntimeError("Could not spawn " + label)
    actor.set_actor_label(label)
    actor.set_folder_path(folder)
    return actor


def shape(mesh, label, folder, center, size, material, color=None, emissive=0.0, rotation=(0.0, 0.0, 0.0), solid=True):
    """A basic shape (100 unit mesh, pivot at its center) scaled to size."""
    actor = spawn(unreal.StaticMeshActor, label, folder, center, rotation)
    actor.set_actor_scale3d(unreal.Vector(size[0] / 100.0, size[1] / 100.0, size[2] / 100.0))
    component = actor.static_mesh_component
    component.set_static_mesh(mesh)
    component.set_material(0, material)
    if color is not None:
        # M_RPG_Surface reads its look from custom primitive data: RGB at 0-3, roughness at 4, emissive at 5.
        component.set_default_custom_primitive_data_vector4(0, unreal.Vector4(color[0], color[1], color[2], 1.0))
        component.set_default_custom_primitive_data_float(4, 0.8)
        component.set_default_custom_primitive_data_float(5, emissive)
    if not solid:
        component.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        component.set_editor_property("can_ever_affect_navigation", False)
        component.set_cast_shadow(False)
    return actor


def floor_mark(mesh, label, center, size, material, color, emissive=0.4):
    """Flat, non-colliding paint on the floor (2 cm tall so it does not z-fight)."""
    return shape(mesh, label, MARKINGS, (center[0], center[1], 1.0), (size[0], size[1], 2.0), material, color, emissive, solid=False)


def text(label, location, rotation, string, size, color, folder=SIGNS):
    actor = spawn(unreal.TextRenderActor, label, folder, location, rotation)
    component = actor.text_render
    component.set_editor_property("text", unreal.Text(string))
    component.set_editor_property("world_size", size)
    component.set_editor_property("horizontal_alignment", unreal.HorizTextAligment.EHTA_CENTER)
    component.set_editor_property("vertical_alignment", unreal.VerticalTextAligment.EVRTA_TEXT_CENTER)
    component.set_editor_property("text_render_color", unreal.Color(r=color[0], g=color[1], b=color[2], a=255))
    return actor


def build_lighting():
    sun = spawn(unreal.DirectionalLight, "Sun", LIGHTING, (0.0, 0.0, 1500.0), (-50.0, -40.0, 0.0))
    sun_light = sun.get_component_by_class(unreal.DirectionalLightComponent)
    sun_light.set_mobility(unreal.ComponentMobility.MOVABLE)
    sun_light.set_editor_property("atmosphere_sun_light", True)

    spawn(unreal.SkyAtmosphere, "SkyAtmosphere", LIGHTING)

    sky = spawn(unreal.SkyLight, "SkyLight", LIGHTING, (0.0, 0.0, 1500.0))
    sky_light = sky.get_component_by_class(unreal.SkyLightComponent)
    sky_light.set_mobility(unreal.ComponentMobility.MOVABLE)
    sky_light.set_editor_property("real_time_capture", True)

    # Just enough haze to blend the horizon; the arena itself stays crisp.
    fog = spawn(unreal.ExponentialHeightFog, "HeightFog", LIGHTING, (0.0, 0.0, -500.0))
    fog.get_component_by_class(unreal.ExponentialHeightFogComponent).set_editor_property("fog_density", 0.004)


def group_approach():
    """Unit vector from the spawn to the group, and the yaw that faces back towards the spawn."""
    dx, dy = GROUP[0] - SPAWN[0], GROUP[1] - SPAWN[1]
    length = math.hypot(dx, dy)
    direction = (dx / length, dy / length)
    return direction, math.degrees(math.atan2(-direction[1], -direction[0]))


def cover_center():
    direction, _ = group_approach()
    return (GROUP[0] - direction[0] * COVER_DISTANCE, GROUP[1] - direction[1] * COVER_DISTANCE)


def build_geometry(cube, floor, block):
    shape(cube, "Floor", GEOMETRY, (0.0, 0.0, -50.0), (ARENA_HALF_X * 2.0, ARENA_HALF_Y * 2.0, 100.0), floor)

    wall_z = WALL_HEIGHT * 0.5
    long_x = ARENA_HALF_X * 2.0 + 200.0
    long_y = ARENA_HALF_Y * 2.0 + 200.0
    shape(cube, "Wall_PosX", GEOMETRY, (ARENA_HALF_X + 50.0, 0.0, wall_z), (100.0, long_y, WALL_HEIGHT), block)
    shape(cube, "Wall_NegX", GEOMETRY, (-ARENA_HALF_X - 50.0, 0.0, wall_z), (100.0, long_y, WALL_HEIGHT), block)
    shape(cube, "Wall_PosY", GEOMETRY, (0.0, ARENA_HALF_Y + 50.0, wall_z), (long_x, 100.0, WALL_HEIGHT), block)
    shape(cube, "Wall_NegY", GEOMETRY, (0.0, -ARENA_HALF_Y - 50.0, wall_z), (long_x, 100.0, WALL_HEIGHT), block)

    # Line-of-sight wall across the path to the group, inside the bots' aggro range but beyond their patrols.
    _, face_spawn_yaw = group_approach()
    cover = cover_center()
    shape(cube, "CoverWall", GEOMETRY, (cover[0], cover[1], 200.0), (100.0, COVER_LENGTH, 400.0), block, rotation=(0.0, face_spawn_yaw, 0.0))

    # High ground: a 2 m platform with a 14 degree ramp on its -X side.
    shape(cube, "Platform", GEOMETRY, (PLATFORM[0], PLATFORM[1], PLATFORM_HEIGHT * 0.5), (PLATFORM_SIZE, PLATFORM_SIZE, PLATFORM_HEIGHT), block)
    shape(cube, "PlatformRamp", GEOMETRY, (PLATFORM[0] - PLATFORM_SIZE * 0.5 - 400.0, PLATFORM[1], 85.0), (840.0, 600.0, 30.0), block, rotation=(14.04, 0.0, 0.0))


def build_markings(cube, cylinder, surface):
    floor_mark(cylinder, "SpawnPad", SPAWN, (400.0, 400.0), surface, (0.05, 0.2, 0.75), 0.8)
    floor_mark(cylinder, "GroupPad", GROUP, (800.0, 800.0), surface, (0.35, 0.05, 0.04), 0.3)

    # Range lane: firing line at the spawn end, side lines, a mark every 5 m (gold every 10 m) with its distance.
    lane_end_y = RANGE_LANE_START_Y - RANGE_MARK_SPACING * RANGE_MARK_COUNT
    lane_length = RANGE_LANE_START_Y - lane_end_y
    half_width = RANGE_LANE_WIDTH * 0.5
    floor_mark(cube, "Range_FiringLine", (RANGE_LANE_X, RANGE_LANE_START_Y), (RANGE_LANE_WIDTH, 40.0), surface, (0.1, 0.3, 0.9), 0.8)
    for side, x in (("Left", RANGE_LANE_X - half_width), ("Right", RANGE_LANE_X + half_width)):
        floor_mark(cube, "Range_Side%s" % side, (x, RANGE_LANE_START_Y - lane_length * 0.5), (12.0, lane_length), surface, (0.6, 0.6, 0.6), 0.2)

    for index in range(1, RANGE_MARK_COUNT + 1):
        meters = index * RANGE_MARK_SPACING / 100.0
        y = RANGE_LANE_START_Y - index * RANGE_MARK_SPACING
        major = index % 2 == 0
        color = (0.9, 0.6, 0.1) if major else (0.75, 0.75, 0.75)
        floor_mark(cube, "Range_Mark_%dm" % meters, (RANGE_LANE_X, y), (RANGE_LANE_WIDTH, 28.0 if major else 12.0), surface, color, 0.6 if major else 0.3)
        text("Range_Label_%dm" % meters, (RANGE_LANE_X - half_width + 160.0, y + 90.0, 2.0), FLOOR_TOWARDS_NEGATIVE_Y, "%d m" % meters,
             110.0, GOLD if major else WHITE, MARKINGS)


def build_signs(cube, surface):
    direction, face_spawn_yaw = group_approach()
    cover = cover_center()
    text("Sign_Duel", (DUEL[0], DUEL[1], 480.0), FACE_SPAWN, "DUEL - 1 BOT", 220.0, GOLD)
    text("Sign_Group", (GROUP[0], GROUP[1], 480.0), (0.0, face_spawn_yaw, 0.0), "GROUP - 3 BOTS", 220.0, GOLD)
    text("Sign_Cover", (cover[0] - direction[0] * 70.0, cover[1] - direction[1] * 70.0, 330.0), (0.0, face_spawn_yaw, 0.0),
         "HIDE HERE: NO LINE OF SIGHT", 90.0, WHITE)
    text("Sign_HighGround", (PLATFORM[0], PLATFORM[1], 480.0), FACE_SPAWN, "HIGH GROUND - 2 M", 130.0, WHITE)
    text("Sign_RangeLane", (RANGE_LANE_X, RANGE_LANE_START_Y - RANGE_MARK_SPACING * RANGE_MARK_COUNT - 400.0, 260.0), FACE_POSITIVE_Y,
         "RANGE LANE", 200.0, GOLD)

    # Legend for the duel bot's rings, on a board to the right of the spawn.
    board = (SPAWN[0] + 1100.0, SPAWN[1] + 1500.0)
    shape(cube, "Legend_Board", SIGNS, (board[0] + 30.0, board[1], 300.0), (20.0, 900.0, 420.0), surface, (0.03, 0.03, 0.04))
    text("Legend_Title", (board[0], board[1], 450.0), FACE_SPAWN, "BOT RANGE RINGS", 90.0, WHITE)
    text("Legend_Patrol", (board[0], board[1], 360.0), FACE_SPAWN, "PATROL", 90.0, GREEN)
    text("Legend_Aggro", (board[0], board[1], 270.0), FACE_SPAWN, "AGGRO", 90.0, AMBER)
    text("Legend_Leash", (board[0], board[1], 180.0), FACE_SPAWN, "LEASH", 90.0, RED)


def build_gameplay():
    spawn(unreal.PlayerStart, "PlayerStart", GAMEPLAY, (SPAWN[0], SPAWN[1], 100.0))

    # Extra starts for deathmatch: the game mode respawns players at the start farthest from the other players.
    # All of them are outside the bots' aggro rings.
    for index, (x, y) in enumerate(PVP_STARTS):
        yaw = math.degrees(math.atan2(-y, -x))  # face the arena center
        spawn(unreal.PlayerStart, "PlayerStart_PvP%d" % (index + 1), GAMEPLAY, (x, y, 100.0), (0.0, yaw, 0.0))

    duel = spawn(unreal.RPGBotSpawner, "DuelBotSpawner", GAMEPLAY, (DUEL[0], DUEL[1], 0.0), FACE_SPAWN)
    duel.set_editor_property("bot_count", 1)
    duel.set_editor_property("spawn_radius", 0.0)
    # The change notification reruns the construction script, which builds the rings.
    duel.set_editor_property("show_range_rings", True, unreal.PropertyAccessChangeNotifyMode.ALWAYS)
    ring_dashes = duel.get_component_by_class(unreal.InstancedStaticMeshComponent).get_instance_count()
    unreal.log("TestArena: duel spawner range rings have %d dashes" % ring_dashes)
    if ring_dashes == 0:
        raise RuntimeError("The duel spawner did not build its range rings")

    _, face_spawn_yaw = group_approach()
    group = spawn(unreal.RPGBotSpawner, "GroupBotSpawner", GAMEPLAY, (GROUP[0], GROUP[1], 0.0), (0.0, face_spawn_yaw, 0.0))
    group.set_editor_property("bot_count", 3)
    group.set_editor_property("spawn_radius", 400.0)

    # Navigation for patrols and chases. The default volume brush is a 200 unit cube.
    bounds = spawn(unreal.NavMeshBoundsVolume, "NavMeshBounds", GAMEPLAY, (0.0, 0.0, 300.0))
    bounds.set_actor_scale3d(unreal.Vector((ARENA_HALF_X * 2.0 + 200.0) / 200.0, (ARENA_HALF_Y * 2.0 + 200.0) / 200.0, 1000.0 / 200.0))
    origin, extent = bounds.get_actor_bounds(False)
    unreal.log("TestArena: nav bounds extent %s" % extent)
    if extent.x < 1000.0:
        raise RuntimeError("NavMeshBoundsVolume has no brush; add one in the editor")

    # The navmesh itself is built by the second command in the module docstring (or by the editor when the map is opened).


def open_empty_map():
    if not unreal.EditorAssetLibrary.does_asset_exist(MAP_PATH):
        if not levels.new_level(MAP_PATH, False):
            raise RuntimeError("Could not create " + MAP_PATH)
        return

    # Rebuild an existing map in place.
    if not levels.load_level(MAP_PATH):
        raise RuntimeError("Could not open " + MAP_PATH)
    for actor in actors.get_all_level_actors():
        if not isinstance(actor, (unreal.WorldSettings, unreal.Brush)) or isinstance(actor, unreal.Volume):
            actors.destroy_actor(actor)


def main():
    open_empty_map()

    cube = load(CUBE_MESH)
    cylinder = load(CYLINDER_MESH)
    floor = load(FLOOR_MATERIAL)
    block = load(BLOCK_MATERIAL)
    surface = load(SURFACE_MATERIAL)

    build_lighting()
    build_geometry(cube, floor, block)
    build_markings(cube, cylinder, surface)
    build_signs(cube, surface)
    build_gameplay()

    if not levels.save_current_level():
        raise RuntimeError("Could not save " + MAP_PATH)
    unreal.log("TestArena: saved %s with %d actors" % (MAP_PATH, len(actors.get_all_level_actors())))


main()
