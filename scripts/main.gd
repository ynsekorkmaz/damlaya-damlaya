extends Node3D
## Sahneyi kodla kurar. `--screenshot=<yol>` verilirse ölçüm yapıp çıkar.
## Ek argümanlar: --quality=low|medium|high (ayar dosyasına yazmadan), --no-save, --open-menu, --open-shop.

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const InputSetup = preload("res://scripts/core/input_setup.gd")
const SkyBuilder = preload("res://scripts/world/sky_builder.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")
const SpringBuilder = preload("res://scripts/world/spring_builder.gd")
const ShopBuilder = preload("res://scripts/world/shop_builder.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const GameState = preload("res://scripts/core/game_state.gd")


func _ready() -> void:
	InputSetup.register()
	var settings := Node.new()
	settings.set_script(preload("res://scripts/game/graphics_settings.gd"))
	add_child(settings)
	var sky: Node3D = SkyBuilder.build()
	add_child(sky)
	settings.call("bind", (sky.get_node("WorldEnvironment") as WorldEnvironment).environment, sky.get_node("Sun") as DirectionalLight3D)
	var terrain: Node3D = TerrainBuilder.build()
	add_child(terrain)
	add_child(RocksBuilder.build())
	add_child(SpringBuilder.build())
	add_child(ShopBuilder.build())

	var lake := Node3D.new()
	lake.set_script(preload("res://scripts/world/lake_view.gd"))
	add_child(lake)

	var game := Node.new()
	game.name = "Game"
	game.set_script(preload("res://scripts/game/game.gd"))
	add_child(game)

	var spawn: Vector3 = Config.PLAYER_SPAWN
	spawn.y = TerrainShape.height(spawn.x, spawn.z) + Config.SPAWN_LIFT
	var player := CharacterBody3D.new()
	player.set_script(preload("res://scripts/player/player.gd"))
	player.position = spawn
	player.rotation.y = atan2(spawn.x - Config.SPAWN_LOOK_AT.x, spawn.z - Config.SPAWN_LOOK_AT.y)
	add_child(player)

	lake.call("bind", game, player)
	lake.call("connect_quality", settings)

	var vessel := Node3D.new()
	vessel.set_script(preload("res://scripts/player/held_vessel.gd"))
	vessel.set("game", game)
	(player.call("get_camera") as Camera3D).add_child(vessel)

	var interaction := Node.new()
	interaction.set_script(preload("res://scripts/player/interaction.gd"))
	interaction.set("game", game)
	interaction.set("player", player)
	add_child(interaction)

	if ResourceLoader.exists("res://scripts/ui/hud.gd"):
		var hud := CanvasLayer.new()
		hud.set_script(load("res://scripts/ui/hud.gd"))
		hud.set("game", game)
		add_child(hud)

	var shop_panel := CanvasLayer.new()
	shop_panel.set_script(preload("res://scripts/ui/shop_panel.gd"))
	shop_panel.set("game", game)
	shop_panel.set("player", player)
	add_child(shop_panel)

	var debug_hud := CanvasLayer.new()
	debug_hud.set_script(preload("res://scripts/ui/debug_hud.gd"))
	debug_hud.set("settings", settings)
	add_child(debug_hud)

	var pause_menu := CanvasLayer.new()
	pause_menu.set_script(preload("res://scripts/ui/pause_menu.gd"))
	pause_menu.set("game", game)
	pause_menu.set("player", player)
	pause_menu.set("settings", settings)
	add_child(pause_menu)

	var st: GameState = game.get("state")
	var cam_at := Vector2.INF
	var look_at := Vector2.INF
	var pitch_deg: float = 0.0
	var debug_carried: float = -1.0
	var open_shop: bool = false
	var open_menu: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-at="):
			cam_at = _parse_xz(arg.substr("--camera-at=".length()))
		elif arg.begins_with("--look-at="):
			look_at = _parse_xz(arg.substr("--look-at=".length()))
		elif arg.begins_with("--pitch="):
			pitch_deg = arg.substr("--pitch=".length()).to_float()
		elif arg.begins_with("--debug-drops="):
			st.total_drops = arg.substr("--debug-drops=".length()).to_float()
		elif arg.begins_with("--debug-carried="):
			debug_carried = arg.substr("--debug-carried=".length()).to_float()
		elif arg.begins_with("--debug-money="):
			st.money = arg.substr("--debug-money=".length()).to_float()
			st.total_money_earned = maxf(st.total_money_earned, st.money)
		elif arg.begins_with("--debug-tool="):
			st.tool_level = clampi(arg.substr("--debug-tool=".length()).to_int(), 0, Cfg.TOOLS.size() - 1)
		elif arg == "--open-shop":
			open_shop = true
		elif arg == "--open-menu":
			open_menu = true
	if debug_carried >= 0.0:
		st.carried = minf(debug_carried, Economy.tool_capacity(st))
	var basin_r: float = BasinShape.radius(st.total_drops)
	var basin_d: float = BasinShape.depth(st.total_drops)
	(terrain.get_node("Patch") as Node).call("bind", game)
	if cam_at != Vector2.INF:
		player.position = Vector3(cam_at.x, TerrainShape.height(cam_at.x, cam_at.y, basin_r, basin_d) + Config.SPAWN_LIFT, cam_at.y)
		if look_at != Vector2.INF:
			player.rotation.y = atan2(cam_at.x - look_at.x, cam_at.y - look_at.y)
	if pitch_deg != 0.0:
		(player.call("get_camera") as Camera3D).rotation.x = deg_to_rad(pitch_deg)

	if open_shop:
		shop_panel.call("open")
	if open_menu:
		pause_menu.call("open")

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_capture_and_quit(arg.substr("--screenshot=".length()))


func _parse_xz(text: String) -> Vector2:
	var parts: PackedStringArray = text.split(",")
	if parts.size() != 2:
		return Vector2.INF
	return Vector2(parts[0].to_float(), parts[1].to_float())


func _capture_and_quit(path: String) -> void:
	var pour_frame: int = Config.SCREENSHOT_WAIT_FRAMES - Config.SCREENSHOT_POUR_FRAMES_BEFORE
	var measure_start: int = 0
	for i in range(Config.SCREENSHOT_WAIT_FRAMES):
		await get_tree().process_frame
		if i == Config.SCREENSHOT_MEASURE_FROM:
			measure_start = Time.get_ticks_usec()
		if i == pour_frame and OS.get_cmdline_user_args().has("--debug-pour"):
			get_node("Game").call("try_pour")
	await RenderingServer.frame_post_draw
	var measured_frames: int = Config.SCREENSHOT_WAIT_FRAMES - Config.SCREENSHOT_MEASURE_FROM
	var elapsed: float = float(Time.get_ticks_usec() - measure_start) / 1000000.0
	print("FPS ort: ", snappedf(float(measured_frames) / maxf(elapsed, 0.000001), 0.1))
	print("Cizici: ", RenderingServer.get_current_rendering_method(), ", kalite: ", get_node("GraphicsSettings").get("level"))
	print("FPS: ", Performance.get_monitor(Performance.TIME_FPS))
	print("Ucgen: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("Cizim cagrisi: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(path)
	print("Goruntu kaydedildi: ", path, " (hata kodu ", err, ")")
	get_tree().quit()
