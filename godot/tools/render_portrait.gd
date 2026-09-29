## Renders a class card portrait (1200x900, like the Classes/ art) from a character model:
## Godot --path godot tools/render_portrait.tscn -- <character script> <out.png> [clip]
extends Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	get_window().size = Vector2i(1200, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.045, 0.06)
	env.environment.ambient_light_color = Color(0.35, 0.3, 0.45)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	env.environment.fog_enabled = false
	env.environment.fog_light_color = Color(0.2, 0.12, 0.3)
	env.environment.fog_density = 0.05
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-25), deg_to_rad(40), 0)
	key.light_energy = 1.2
	key.light_color = Color(1.0, 0.85, 0.7)
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.0, -1.5)
	rim.light_color = Color(0.55, 0.3, 1.0)
	rim.light_energy = 3.0
	rim.omni_range = 5.0
	add_child(rim)
	var c: RPGCharacter = load(args[0]).new()
	c.rotation.y = PI - 0.3
	add_child(c)
	c.set_physics_process(false)
	c.set_process(false)
	var cam := Camera3D.new()
	cam.position = Vector3(0.05, 1.5, 1.35)
	cam.rotation.x = deg_to_rad(-3)
	cam.fov = 45
	add_child(cam)
	cam.make_current()
	if c._anim:
		c._anim.play(StringName(args[2]) if args.size() > 2 else &"Sword_Idle")
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()
