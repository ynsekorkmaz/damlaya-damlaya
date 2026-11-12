extends Node3D
## Sahneyi kodla kurar. `--screenshot=<yol>` verilirse ölçüm yapıp çıkar.

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const InputSetup = preload("res://scripts/core/input_setup.gd")
const SkyBuilder = preload("res://scripts/world/sky_builder.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")


func _ready() -> void:
	InputSetup.register()
	add_child(SkyBuilder.build())
	add_child(TerrainBuilder.build())
	add_child(RocksBuilder.build())

	var spawn: Vector3 = Config.PLAYER_SPAWN
	spawn.y = TerrainShape.height(spawn.x, spawn.z) + Config.SPAWN_LIFT
	var player := CharacterBody3D.new()
	player.set_script(preload("res://scripts/player/player.gd"))
	player.position = spawn
	player.rotation.y = atan2(spawn.x, spawn.z)  # çukura (merkeze) bak
	add_child(player)

	var hud := CanvasLayer.new()
	hud.set_script(preload("res://scripts/ui/debug_hud.gd"))
	add_child(hud)

	var cam_at := Vector2.INF
	var look_at := Vector2.INF
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-at="):
			cam_at = _parse_xz(arg.substr("--camera-at=".length()))
		elif arg.begins_with("--look-at="):
			look_at = _parse_xz(arg.substr("--look-at=".length()))
	if cam_at != Vector2.INF:
		player.position = Vector3(cam_at.x, TerrainShape.height(cam_at.x, cam_at.y) + Config.SPAWN_LIFT, cam_at.y)
		if look_at != Vector2.INF:
			player.rotation.y = atan2(cam_at.x - look_at.x, cam_at.y - look_at.y)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_capture_and_quit(arg.substr("--screenshot=".length()))


func _parse_xz(text: String) -> Vector2:
	var parts: PackedStringArray = text.split(",")
	if parts.size() != 2:
		return Vector2.INF
	return Vector2(parts[0].to_float(), parts[1].to_float())


func _capture_and_quit(path: String) -> void:
	for i in range(Config.SCREENSHOT_WAIT_FRAMES):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("FPS: ", Performance.get_monitor(Performance.TIME_FPS))
	print("Ucgen: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("Cizim cagrisi: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(path)
	print("Goruntu kaydedildi: ", path, " (hata kodu ", err, ")")
	get_tree().quit()
