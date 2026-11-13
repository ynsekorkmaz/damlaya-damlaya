extends Node
## Tanıtım senaryosu (`--demo`): oyunu kendi kendine oynar; film kaydı (--write-movie) için sesleri sırayla duyurur.
## Oyuncu gerçek girdi olaylarıyla sürülür (hareket eylemleri, tuşlar, fare düğmeleri); bakış, oyuncunun gövde ve kamera
## açısını yumuşakça hedefe çevirerek verilir (fare yakalama film kaydında güvenilir olmadığı için). Ekranın altında
## o an dinlenen sesi söyleyen bir altyazı gösterilir. Dış bağlantı: add_child'dan önce atanır: game, player, equipment, audio, lake.
## Zaman damgaları (video saniyesi) çıktıya "[DEMO] t=..." olarak yazılır.

const Config = preload("res://scripts/core/config.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const SpringBuilder = preload("res://scripts/world/spring_builder.gd")
const ShopBuilder = preload("res://scripts/world/shop_builder.gd")
const Economy = preload("res://scripts/core/economy.gd")

const LOOK_RATE: float = 6.0
const SUBTITLE_SIZE: int = 38
const WALK_PITCH_DEG: float = -7.0
const QUIT_SILENCE_SEC: float = 2.0

var game: Node
var player: CharacterBody3D
var equipment: Node
var audio: Node
var lake: Node

var _cam: Camera3D
var _want_yaw: float = 0.0
var _want_pitch: float = 0.0
var _look_on: bool = false
var _clock: float = 0.0
var _label: Label
var _spring_xz: Vector2
var _spring_center: Vector3
var _shop_xz: Vector2
var _state: Object


func _ready() -> void:
	name = "DemoPlayer"
	_state = game.get("state")
	_cam = player.call("get_camera")
	_spring_center = SpringBuilder.origin() + Vector3(0.0, Config.FILL_TARGET_HEIGHT, 0.0)
	_spring_xz = Vector2(_spring_center.x, _spring_center.z)
	_shop_xz = Vector2(Config.SHOP_POSITION.x, Config.SHOP_POSITION.z)
	_want_yaw = player.rotation.y
	_want_pitch = _cam.rotation.x
	_build_overlay()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_run()


func _process(delta: float) -> void:
	_clock += delta
	if not _look_on or not bool(player.get("input_enabled")):
		return
	var k: float = 1.0 - exp(-LOOK_RATE * delta)
	player.rotation.y = lerp_angle(player.rotation.y, _want_yaw, k)
	var pitch: float = lerpf(_cam.rotation.x, _want_pitch, k)
	_cam.rotation.x = pitch
	player.set("_pitch", pitch)


# ---------- Altyazı ----------

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60.0
	panel.offset_right = -60.0
	panel.offset_top = -118.0
	panel.offset_bottom = -22.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.72)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)


func _say(text: String) -> void:
	_label.text = text
	print("[DEMO] t=%.1f %s" % [_clock, text])


# ---------- Girdi yardımcıları ----------

func _frame() -> void:
	await get_tree().process_frame


func _wait(sec: float) -> void:
	var until: float = _clock + sec
	while _clock < until:
		await _frame()


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(code: Key, hold: float = 0.12) -> void:
	_key(code, true)
	await _wait(hold)
	_key(code, false)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)


func _click(button: MouseButton, hold: float = 0.18) -> void:
	_mouse(button, true)
	await _wait(hold)
	_mouse(button, false)


func _flat() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z)


func _set_look_dir(dir: Vector2, pitch_deg: float) -> void:
	_look_on = true
	_want_yaw = atan2(-dir.x, -dir.y)
	_want_pitch = deg_to_rad(pitch_deg)


## Kameranın bir noktaya bakmasını bekler.
func _face_point(point: Vector3, max_sec: float = 2.5) -> void:
	var d: Vector3 = point - _cam.global_position
	_look_on = true
	_want_yaw = atan2(-d.x, -d.z)
	_want_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await _settle(max_sec)


func _face_dir(yaw: float, pitch_deg: float, max_sec: float = 2.5) -> void:
	_look_on = true
	_want_yaw = yaw
	_want_pitch = deg_to_rad(pitch_deg)
	await _settle(max_sec)


func _settle(max_sec: float) -> void:
	var until: float = _clock + max_sec
	while _clock < until:
		if absf(angle_difference(player.rotation.y, _want_yaw)) < 0.02 and absf(_cam.rotation.x - _want_pitch) < 0.02:
			break
		await _frame()


## Hedef noktaya yürür (ya da koşar). Takılırsa zıplar, hâlâ takılırsa hedefe ışınlar.
func _walk(target: Vector2, sprint: bool, tol: float = 0.9, timeout: float = 30.0, pitch_deg: float = WALK_PITCH_DEG) -> void:
	var t0: float = _clock
	var mark: Vector2 = _flat()
	var mark_t: float = _clock
	var stuck: int = 0
	if sprint:
		Input.action_press("sprint")
	while _clock - t0 < timeout:
		var d: Vector2 = target - _flat()
		if d.length() <= tol:
			break
		_set_look_dir(d, pitch_deg)
		if absf(angle_difference(player.rotation.y, _want_yaw)) < 0.5:
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
		if _clock - mark_t > 1.4:
			if (_flat() - mark).length() < 0.5:
				stuck += 1
				if stuck >= 2:
					player.global_position = Vector3(target.x, player.global_position.y + 0.6, target.y)
					player.velocity = Vector3.ZERO
					print("[DEMO] takildi, hedefe isinlandi: ", target)
					break
				Input.action_press("jump")
				await _wait(0.15)
				Input.action_release("jump")
			mark = _flat()
			mark_t = _clock
		await _frame()
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _wait(0.5)


## Bakış yönünü bozmadan yana kayar (metre); sağ = pozitif.
func _strafe(meters: float) -> void:
	var right: Vector3 = player.global_transform.basis.x
	var start: float = player.global_position.dot(right)
	var action: String = "move_right" if meters > 0.0 else "move_left"
	Input.action_press(action)
	var t0: float = _clock
	while absf(player.global_position.dot(right) - start) < absf(meters) and _clock - t0 < 3.0:
		await _frame()
	Input.action_release(action)
	await _wait(0.45)


func _pour_zone_point(frac_of_radius: float, extra: float, dir: Vector2) -> Vector2:
	var r: float = BasinShape.radius(float(_state.get("total_drops")))
	return dir.normalized() * (r * frac_of_radius + extra)


func _fill_until_full(max_sec: float) -> void:
	_mouse(MOUSE_BUTTON_LEFT, true)
	var t0: float = _clock
	while _clock - t0 < max_sec:
		if float(_state.get("carried")) >= Economy.tool_capacity(_state) - 0.001:
			break
		await _frame()
	await _wait(0.35)
	_mouse(MOUSE_BUTTON_LEFT, false)


func _pour() -> void:
	await _click(MOUSE_BUTTON_RIGHT, 0.2)


# ---------- Senaryo ----------

func _run() -> void:
	var water_dir: Vector2 = _spring_xz.normalized()
	await _wait(0.5)
	_say("Açılış: rüzgâr ve vadi ortamı")
	await _wait(3.0)

	# Kaynağa yürüme
	var spring_stand: Vector2 = _spring_xz + (Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z) - _spring_xz).normalized() * 3.6
	_say("Ayak sesi: çimen (yürüme)")
	var mid: Vector2 = _flat().lerp(spring_stand, 0.5)
	await _walk(mid, false, 1.0)
	_say("Ayak sesi: çimen (koşma, sıklaşan adım)")
	await _walk(spring_stand, true, 0.9)
	_say("Kaynak kayası: şırıltı")
	await _face_point(_spring_center)
	await _wait(3.2)

	# Avuçla doldur ve dök
	_say("Su doldurma: dolum döngüsü, sonra \"dolu\" sesi")
	await _fill_until_full(4.0)
	await _wait(1.6)
	_say("Çukura yürüyoruz")
	await _walk(_pour_zone_point(1.0, 1.2, water_dir), false, 0.9)
	await _face_dir(atan2(water_dir.x, water_dir.y), -22.0)
	_say("Dökme: avuç (küçük dökülme), damla, para")
	await _pour()
	await _wait(2.8)

	# Geliştirmeler (Tab)
	_say("Tab: Geliştirmeler paneli açılır")
	await _tap(KEY_TAB)
	await _wait(1.3)
	_say("Arayüzde gezinme (üzerine gelme sesi)")
	for i in range(3):
		await _tap(KEY_DOWN)
		await _wait(0.5)
	for i in range(3):
		await _tap(KEY_UP)
		await _wait(0.5)
	await _tap(KEY_RIGHT)
	await _wait(0.6)
	await _tap(KEY_DOWN)
	await _wait(0.6)
	_say("Satın alma: kilit açma (olumlu ses)")
	var before: int = int(_state.get("tool_unlocked"))
	await _tap(KEY_ENTER)
	await _wait(0.6)
	if int(_state.get("tool_unlocked")) == before:
		game.call("unlock_tool")
	await _wait(1.4)
	_say("Para yetmezse: olumsuz ses")
	var saved_money: float = float(_state.get("money"))
	_state.set("money", 0.0)
	game.call("buy_rate")
	await _wait(1.8)
	_state.set("money", saved_money)
	await _tap(KEY_TAB)
	await _wait(1.2)

	# Dükkân
	_say("Dükkâna yürüyoruz")
	await _walk(_shop_xz + Vector2(0.0, 3.0), true, 0.9)
	await _face_point(Vector3(_shop_xz.x, Config.SHOP_LOOK_HEIGHT + 0.8, _shop_xz.y))
	_say("E: dükkân paneli açılır")
	await _tap(KEY_E)
	await _wait(1.6)
	_say("Dükkândan alım")
	var level_before: int = int(_state.get("tool_level"))
	await _tap(KEY_ENTER)
	await _wait(0.6)
	if int(_state.get("tool_level")) == level_before and bool(Economy.next_tool_unlocked(_state)):
		game.call("buy_tool")
	await _wait(1.6)
	await _tap(KEY_E)
	await _wait(1.3)

	# Kova ile doldur ve dök
	_state.set("tool_level", maxi(int(_state.get("tool_level")), 2))
	_state.set("tool_unlocked", maxi(int(_state.get("tool_unlocked")), 2))
	_say("Kaynağa dönüyoruz (kova ile doldurulacak)")
	await _walk(spring_stand, true, 0.9)
	await _face_point(_spring_center)
	_say("Kova ile su doldurma")
	await _fill_until_full(5.0)
	await _wait(1.4)
	_say("Çukura yürüyoruz")
	await _walk(_pour_zone_point(1.0, 1.2, water_dir), true, 0.9)
	await _face_dir(atan2(water_dir.x, water_dir.y), -22.0)
	_say("Dökme: kova dolusu (orta dökülme)")
	await _pour()
	await _wait(3.0)

	# Suyun içinde yürüme
	_say("Ayak sesi: suyun içinde (şap şap)")
	var inner: Vector2 = _pour_zone_point(0.35, 0.0, water_dir)
	await _walk(inner, false, 1.0, 12.0)
	var side: Vector2 = Vector2(-water_dir.y, water_dir.x)
	await _walk(_pour_zone_point(0.4, 0.0, side), false, 1.0, 12.0)
	await _walk(_pour_zone_point(0.4, 0.0, -side), true, 1.0, 14.0)
	await _wait(0.4)

	# Çekiç ve kanal alanı
	_say("Kanal alanına koşuyoruz")
	await _walk(Vector2(-35.0, 10.5), true, 0.9, 30.0)
	await _face_dir(0.0, -20.0)
	_say("2: çekice geçiş")
	await _tap(KEY_2)
	await _wait(1.6)
	_say("Q: yapı kitapçığı (sayfa sesi)")
	await _tap(KEY_Q)
	await _wait(1.6)
	await _tap(KEY_DOWN)
	await _wait(0.6)
	await _tap(KEY_DOWN)
	await _wait(0.8)
	_say("Enter: parça seçilir, kitapçık kapanır")
	await _tap(KEY_ENTER)
	await _wait(1.6)
	await _face_dir(0.0, -20.0)
	_say("Kanal parçası kurma (tak)")
	await _click(MOUSE_BUTTON_LEFT, 0.25)
	await _wait(1.6)
	_say("R: parçayı döndürme (tık)")
	await _tap(KEY_R)
	await _wait(1.0)
	await _tap(KEY_R)
	await _wait(1.2)
	_say("Sağ tık: parçayı sökme")
	await _click(MOUSE_BUTTON_RIGHT, 0.25)
	await _wait(1.8)
	_say("Para yetmezse: yerleştirilemez sesi")
	var build_money: float = float(_state.get("money"))
	_state.set("money", 0.0)
	await _wait(0.4)
	await _click(MOUSE_BUTTON_LEFT, 0.25)
	await _wait(1.6)
	_state.set("money", build_money)
	await _wait(0.4)
	_say("Birkaç parça daha kurma (tak, tak, tak)")
	await _click(MOUSE_BUTTON_LEFT, 0.25)
	await _wait(0.9)
	await _strafe(-2.0)
	await _click(MOUSE_BUTTON_LEFT, 0.25)
	await _wait(0.9)
	await _strafe(-2.0)
	await _click(MOUSE_BUTTON_LEFT, 0.25)
	await _wait(1.2)
	_say("Basılı tutup sürükleme: art arda kurma")
	_mouse(MOUSE_BUTTON_LEFT, true)
	await _strafe(7.0)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _wait(1.5)

	# Akan kanal, değirmen, pınar
	_say("Değirmene yürüyoruz")
	await _walk(Vector2(-43.0, -3.6), true, 0.9, 25.0)
	await _face_point(Vector3(-43.0, 1.0, -7.0))
	_say("Değirmen: çark sesi ve akan kanal suyu")
	await _wait(4.2)
	_say("Akan kanal hattı: kanal suyu")
	await _walk(Vector2(-31.0, 2.2), false, 0.9, 20.0)
	await _face_point(Vector3(-31.0, 0.3, -1.0))
	await _wait(4.2)
	_say("Pınar çeşmesi")
	var spring_pt: Vector2 = CanalField.spring_point(4)
	await _walk(spring_pt + Vector2(3.4, 0.0), false, 0.9, 25.0)
	await _face_point(Vector3(spring_pt.x, 1.0, spring_pt.y))
	await _wait(4.2)

	# Göle dönüş, aşama atlama, göl kıyısı
	_say("Göle koşuyoruz")
	await _tap(KEY_1)
	await _walk(_pour_zone_point(1.0, 1.0, Vector2(-1.0, 0.1)), true, 0.9, 30.0)
	await _face_dir(-PI * 0.5, -18.0)
	var next_stage: Dictionary = Cfg.STAGES[mini(3, Cfg.STAGES.size() - 1)]
	_say("Aşama atlama: yeni aşama akoru")
	_state.set("carried", 200.0)
	_state.set("total_drops", maxf(float(next_stage["threshold"]) - 5.0, float(_state.get("total_drops"))))
	await _wait(0.5)
	# Çukur büyüdüğü için dökme bölgesinde olduğumuzdan emin ol.
	await _pour()
	await _wait(3.2)
	_say("Göl kıyısı: göl sesi ve kuş sesleri")
	await _face_dir(-PI * 0.5, -6.0)
	for i in range(3):
		audio.set("_bird_timer", 0.3)
		await _wait(1.9)
	await _wait(0.6)
	_say("Bitiş")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	await _wait(QUIT_SILENCE_SEC)
	print("[DEMO] bitti t=%.1f" % _clock)
	get_tree().quit()
