extends SceneTree
## Kollari sahte oyunla tek basina gosterir ve ekran goruntusu alir.
## Kullanim: godot --path . -s res://tests/arms_view.gd -- --out=yol.png --carried=0.5 [--pour]

const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const VesselScript = preload("res://scripts/player/held_vessel.gd")

const FAKE_SOURCE: String = "extends Node\nsignal poured(drops: float, money: float)\nvar state\n"
const WAIT_FRAMES: int = 90

var _frame: int = 0
var _out: String = "kollar.png"
var _vessel: Node3D


func _initialize() -> void:
	var ratio: float = 0.0
	var pour: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--carried="):
			ratio = clampf(arg.substr(10).to_float(), 0.0, 1.0)
		elif arg == "--pour":
			pour = true

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.66, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	light.shadow_enabled = false
	root.add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.47, 0.62, 0.3)
	ground.material_override = ground_mat
	ground.position.y = -1.6
	root.add_child(ground)

	var camera := Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 400.0
	root.add_child(camera)
	camera.current = true

	var script := GDScript.new()
	script.source_code = FAKE_SOURCE
	script.reload()
	var fake_game := Node.new()
	fake_game.set_script(script)
	var state := GameState.new()
	state.tool_level = 0
	state.carried = ratio * Economy.tool_capacity(state)
	fake_game.set("state", state)
	root.add_child(fake_game)

	_vessel = Node3D.new()
	_vessel.set_script(VesselScript)
	_vessel.set("game", fake_game)
	camera.add_child(_vessel)
	if pour:
		fake_game.emit_signal("poured", 5.0, 1.0)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame >= WAIT_FRAMES:
		print("Ucgen sayisi (eller+su): ", _vessel.call("triangle_count"))
		var image: Image = root.get_texture().get_image()
		var err: Error = image.save_png(_out)
		print("Kaydedildi: %s (hata: %d, boyut: %s)" % [_out, err, str(image.get_size())])
		quit(0 if err == OK else 1)
	return false
