extends Node3D
## Sahneyi kodla kurar. `--screenshot=<yol>` verilirse ölçüm yapıp çıkar.
## Ek argümanlar: --quality=low|medium|high (ayar dosyasına yazmadan), --no-save, --open-menu, --open-shop, --open-upgrades[=aletler|su|kaynaklar|kayip|kanal],
## --debug-drops/money/tool/carried/canal/hammer, --debug-build=kanal|bitki|kemer, --equip-hammer, --open-book[=kanal|bitki|kaynak],
## --select-build=<yapi_id>, --camera-y=<m> (kamera yuksekligi). --equip-hammer / --select-build ekran goruntusunde fare yakalanmis gibi calisir.

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
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const Build = preload("res://scripts/core/build.gd")


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

	var life_view := Node3D.new()
	life_view.set_script(preload("res://scripts/world/life_view.gd"))
	add_child(life_view)
	life_view.call("bind", game, lake, settings)

	var vessel := Node3D.new()
	vessel.set_script(preload("res://scripts/player/held_vessel.gd"))
	vessel.set("game", game)
	(player.call("get_camera") as Camera3D).add_child(vessel)

	var hud: CanvasLayer = null
	if ResourceLoader.exists("res://scripts/ui/hud.gd"):
		hud = CanvasLayer.new()
		hud.set_script(load("res://scripts/ui/hud.gd"))
		hud.set("game", game)
		add_child(hud)

	var equipment := Node.new()
	equipment.set_script(preload("res://scripts/player/equipment.gd"))
	equipment.set("game", game)
	equipment.set("player", player)
	add_child(equipment)

	var hammer_view := Node3D.new()
	hammer_view.set_script(preload("res://scripts/player/held_hammer.gd"))
	hammer_view.set("equipment", equipment)
	hammer_view.set("vessel", vessel)
	(player.call("get_camera") as Camera3D).add_child(hammer_view)

	var interaction := Node.new()
	interaction.set_script(preload("res://scripts/player/interaction.gd"))
	interaction.set("game", game)
	interaction.set("player", player)
	interaction.set("equipment", equipment)
	add_child(interaction)

	var build_controller := Node.new()
	build_controller.set_script(preload("res://scripts/player/build_controller.gd"))
	build_controller.set("game", game)
	build_controller.set("player", player)
	build_controller.set("equipment", equipment)
	build_controller.set("lake", lake)
	build_controller.set("hud", hud)
	build_controller.set("hammer_view", hammer_view)
	add_child(build_controller)
	interaction.set("build", build_controller)

	var canal_view := Node3D.new()
	canal_view.set_script(preload("res://scripts/world/canal_view.gd"))
	add_child(canal_view)
	var structures_view := Node3D.new()
	structures_view.set_script(preload("res://scripts/world/structures_view.gd"))
	add_child(structures_view)
	var field_view := Node3D.new()
	field_view.set_script(preload("res://scripts/world/canal_field_view.gd"))
	add_child(field_view)

	var build_hud := CanvasLayer.new()
	build_hud.set_script(preload("res://scripts/ui/build_hud.gd"))
	build_hud.set("game", game)
	build_hud.set("equipment", equipment)
	build_hud.set("player", player)
	add_child(build_hud)

	var shop_panel := CanvasLayer.new()
	shop_panel.set_script(preload("res://scripts/ui/shop_panel.gd"))
	shop_panel.set("game", game)
	shop_panel.set("player", player)
	add_child(shop_panel)

	var upgrades_panel := CanvasLayer.new()
	upgrades_panel.set_script(preload("res://scripts/ui/upgrades_panel.gd"))
	upgrades_panel.set("game", game)
	upgrades_panel.set("player", player)
	add_child(upgrades_panel)

	var debug_hud := CanvasLayer.new()
	debug_hud.set_script(preload("res://scripts/ui/debug_hud.gd"))
	debug_hud.set("settings", settings)
	debug_hud.set("equipment", equipment)
	debug_hud.set("player", player)
	add_child(debug_hud)

	var pause_menu := CanvasLayer.new()
	pause_menu.set_script(preload("res://scripts/ui/pause_menu.gd"))
	pause_menu.set("game", game)
	pause_menu.set("player", player)
	pause_menu.set("settings", settings)
	add_child(pause_menu)

	var book := CanvasLayer.new()
	book.set_script(preload("res://scripts/ui/build_book.gd"))
	book.set("game", game)
	book.set("player", player)
	book.set("equipment", equipment)
	add_child(book)

	var manager := Node.new()
	manager.set_script(preload("res://scripts/ui/panel_manager.gd"))
	manager.set("game", game)
	manager.set("shop", shop_panel)
	manager.set("upgrades", upgrades_panel)
	manager.set("pause", pause_menu)
	manager.set("book", book)
	manager.set("equipment", equipment)
	add_child(manager)

	var audio := Node.new()
	audio.set_script(preload("res://scripts/audio/audio_manager.gd"))
	add_child(audio)
	audio.call("bind", game, player, equipment, lake, settings, [[shop_panel, "panel"], [upgrades_panel, "panel"], [pause_menu, "panel"], [book, "book"]])
	build_controller.set("audio", audio)

	var st: GameState = game.get("state")
	var cam_at := Vector2.INF
	var look_at := Vector2.INF
	var pitch_deg: float = 0.0
	var debug_carried: float = -1.0
	var open_shop: bool = false
	var open_menu: bool = false
	var open_upgrades: bool = false
	var upgrades_section: String = ""
	var debug_build: String = ""
	var equip_hammer: bool = false
	var open_book: bool = false
	var book_section: String = ""
	var select_build: String = ""
	var camera_y: float = -1.0
	var screenshot_mode: bool = false
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
			st.tool_unlocked = maxi(st.tool_unlocked, st.tool_level)
		elif arg == "--open-upgrades" or arg.begins_with("--open-upgrades="):
			open_upgrades = true
			upgrades_section = arg.substr("--open-upgrades=".length()) if arg.contains("=") else ""
		elif arg == "--debug-canal":
			st.canal_unlocked = true
		elif arg == "--debug-hammer":
			st.hammer_unlocked = true
			st.hammer_owned = true
		elif arg.begins_with("--debug-build="):
			debug_build = arg.substr("--debug-build=".length())
		elif arg == "--equip-hammer":
			equip_hammer = true
		elif arg == "--open-book" or arg.begins_with("--open-book="):
			open_book = true
			book_section = arg.substr("--open-book=".length()) if arg.contains("=") else ""
		elif arg.begins_with("--select-build="):
			select_build = arg.substr("--select-build=".length())
		elif arg.begins_with("--camera-y="):
			camera_y = arg.substr("--camera-y=".length()).to_float()
		elif arg.begins_with("--screenshot="):
			screenshot_mode = true
		elif arg == "--open-shop":
			open_shop = true
		elif arg == "--open-menu":
			open_menu = true
	if not debug_build.is_empty():
		_apply_debug_build(game, st, debug_build)
	if debug_carried >= 0.0:
		st.carried = minf(debug_carried, Economy.tool_capacity(st))
	canal_view.call("bind", game)
	structures_view.call("bind", game, lake)
	field_view.call("bind", game, lake, equipment, player)
	var basin_r: float = BasinShape.radius(st.total_drops)
	var basin_d: float = BasinShape.depth(st.total_drops)
	(terrain.get_node("Patch") as Node).call("bind", game)
	if cam_at != Vector2.INF:
		player.position = Vector3(cam_at.x, TerrainShape.height(cam_at.x, cam_at.y, basin_r, basin_d) + Config.SPAWN_LIFT, cam_at.y)
		if look_at != Vector2.INF:
			player.rotation.y = atan2(cam_at.x - look_at.x, cam_at.y - look_at.y)
	if pitch_deg != 0.0:
		(player.call("get_camera") as Camera3D).rotation.x = deg_to_rad(pitch_deg)
	if camera_y >= 0.0:
		(player.call("get_camera") as Camera3D).position.y = camera_y
	if equip_hammer or not select_build.is_empty():
		equipment.call("set_slot", 1)
	if not select_build.is_empty():
		equipment.call("select", ("canal:" if Pieces.has_piece(select_build) else "free:") + select_build)
	if screenshot_mode and (equip_hammer or not select_build.is_empty()):
		build_controller.set("debug_force", true)

	if open_shop:
		shop_panel.call("open")
	if open_upgrades:
		upgrades_panel.call("open_section", upgrades_section)
	if open_menu:
		pause_menu.call("open")
	if open_book:
		book.call("open_section", book_section)

	if OS.get_cmdline_user_args().has("--demo"):
		var demo := Node.new()
		demo.set_script(preload("res://scripts/tools/demo_player.gd"))
		demo.set("game", game)
		demo.set("player", player)
		demo.set("equipment", equipment)
		demo.set("audio", audio)
		demo.set("lake", lake)
		add_child(demo)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_capture_and_quit(arg.substr("--screenshot=".length()))


## Ekran goruntusu senaryolari: "kanal" (ornek ag) ve "bitki" (kamis, agac, her kaynaktan bir tane).
func _apply_debug_build(game: Node, st: GameState, scenario: String) -> void:
	st.hammer_unlocked = true
	st.hammer_owned = true
	st.canal_unlocked = true
	st.money = maxf(st.money, 1.0e7)
	st.total_money_earned = maxf(st.total_money_earned, st.money)
	for id: String in Pieces.PIECE_IDS:
		if not st.unlocked_pieces.has(id):
			st.unlocked_pieces.append(id)
	for id: String in Pieces.MATERIAL_IDS:
		if not st.unlocked_materials.has(id):
			st.unlocked_materials.append(id)
	if scenario == "kanal":
		var net: Object = game.get("canal")
		net.call("open_spring", "A")
		net.call("open_spring", "B")
		_build_sample_network(net)
	elif scenario == "kemer":
		# Yalniz A pinari acik: su kemerinin dogu-bati hatti akar, kuzey-guney hatti kurudur.
		(game.get("canal") as Object).call("open_spring", "A")
		_build_aqueduct_sample(game.get("canal"))
	elif scenario == "bitki":
		for kind: String in ["reeds", "shade_tree"]:
			if not st.unlocked_structures.has(kind):
				st.unlocked_structures.append(kind)
		for def: Dictionary in Cfg.SOURCES:
			if not st.unlocked_sources.has(String(def["id"])):
				st.unlocked_sources.append(String(def["id"]))
		for i in range(5):
			Build.add(st, "reeds", 0.0, 0.0, 0.0, false)
		for i in range(4):
			Build.add(st, "shade_tree", 0.0, 0.0, 0.0, false)
		for def: Dictionary in Cfg.SOURCES:
			Build.add(st, String(def["id"]), 0.0, 0.0, 0.0, false)


## A pinarindan goele duz hat; B pinarindan degirmen, savak, dirsek, T, su kemeri, arti, havuz ve Y iceren ikinci hat.
func _build_sample_network(net: Object) -> void:
	for col in range(14):
		var mat: String = "earth" if col < 4 else ("wood" if col < 10 else "stone")
		var piece: String = "cross" if col == 4 else "straight"
		net.call("place", col, 4, piece, 0, "stone" if col == 4 else mat)
	var list: Array = [
		[0, 1, "straight", 0, "wood"], [1, 1, "straight", 0, "wood"], [2, 1, "mill", 0, "wood"], [3, 1, "gate", 0, "wood"],
		[4, 1, "elbow", 0, "wood"], [4, 2, "tee", 3, "wood"], [4, 3, "aqueduct", 0, "stone"],
		[5, 2, "straight", 0, "wood"], [6, 2, "reservoir", 0, "stone"], [7, 2, "wye", 0, "wood"],
		[7, 1, "elbow", 3, "wood"], [7, 3, "elbow", 2, "wood"],
		[8, 2, "straight", 0, "wood"], [9, 2, "straight", 0, "earth"], # kuru, bagli olmayan iki parca
	]
	for col in range(8, 14):
		list.append([col, 1, "straight", 0, "wood"])
		list.append([col, 3, "straight", 0, "stone"])
	for e: Array in list:
		net.call("place", e[0], e[1], e[2], e[3], e[4])


## A pinarindan (satir 4) goele duz hat, 3. sutunda su kemeri; kemeri dik kesen hat pinara bagli degil.
func _build_aqueduct_sample(net: Object) -> void:
	for col in range(14):
		net.call("place", col, 4, "aqueduct" if col == 3 else "straight", 0, "wood")
	for row in [2, 3, 5, 6]:
		net.call("place", 3, row, "straight", 1, "wood")


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
	await _free_scene_and_quit()


## Cikista kaynaklarin serbest kalmasi icin once sahne agaci bosaltilir, birkac kare beklenir.
func _free_scene_and_quit() -> void:
	var tree: SceneTree = get_tree()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for i in range(Config.EXIT_FLUSH_FRAMES):
		await tree.process_frame
	tree.quit()
