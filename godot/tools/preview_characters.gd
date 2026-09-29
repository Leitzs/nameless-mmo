## Renders the three characters side by side (front view) to check models, materials and weapon grips:
## Godot --path godot tools/preview_characters.tscn -- <out.png> [clip] [seconds]
extends Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://preview.png"
	var clip := StringName(args[1]) if args.size() > 1 else &"Idle"
	var seconds := float(args[2]) if args.size() > 2 else 0.6
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.24, 0.27)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 4.2)
	cam.fov = 50
	add_child(cam)
	cam.make_current()
	var chars: Array[RPGCharacter] = []
	var i := 0
	for path in ["res://scripts/characters/mage.gd", "res://scripts/characters/rogue.gd", "res://scripts/characters/enemy_bot.gd"]:
		var c: RPGCharacter = load(path).new()
		c.position = Vector3((i - 1) * 1.5, 0, 0)
		c.rotation.y = PI  # face the camera (+Z)
		add_child(c)
		c.set_physics_process(false)
		c.set_process(false)
		chars.append(c)
		i += 1
	cam.make_current()
	for c in chars:
		if c._anim:
			c._anim.play(clip)
	await get_tree().create_timer(seconds).timeout
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
