extends Node
## Ses sistemi: veri yolları (Master, SFX, Ambience, UI), ses havuzu, olaylar, ayak sesi, konumlu döngüler, ambiyans.
## Sesler sound_bank.gd'den açılışta bir kez üretilir; oyun sırasında tampon üretilmez.
## Dış bağlantı: add_child'dan sonra bind(game, player, equipment, lake, settings, panels) çağrılır
## (panels: [[düğüm, tür]], tür "book" ya da "panel"; düğümde is_open() olmalı). Hepsi isteğe bağlıdır; boş bırakılan ilgili sesi sessiz yapar.
## Olay tablosu ve sayılar audio_config.gd'de. Konumlu kaynaklar en çok AudioConfig.POSITIONAL_SOURCES tanedir.

const AC = preload("res://scripts/core/audio_config.gd")
const SoundBank = preload("res://scripts/audio/sound_bank.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const SpringBuilder = preload("res://scripts/world/spring_builder.gd")

const SRC_SPRING: int = 0
const SRC_LAKE: int = 1
const SRC_WATER_A: int = 2
const SRC_WATER_B: int = 3
const SRC_MILL: int = 4
const SILENT_DB: float = -60.0
const FAR: float = 1.0e12

var game: Node
var player: Node
var equipment: Node
var lake: Node
var settings: Node

var _bank: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _sfx_voices: Array[AudioStreamPlayer] = []
var _ui_voices: Array[AudioStreamPlayer] = []
var _fill_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _bird_player: AudioStreamPlayer3D
var _pos_players: Array[AudioStreamPlayer3D] = []
var _pos_target: Array[Vector3] = []
var _pos_active: Array[bool] = []
var _last_variant: Dictionary = {}

var _fill_hold: float = 0.0
var _fill_db: float = SILENT_DB
var _was_full: bool = false

var _sched_time: PackedFloat32Array = PackedFloat32Array()
var _sched_name: Array[String] = []

var _panel_nodes: Array[Node] = []
var _panel_kinds: Array[String] = []
var _panel_open: Array[bool] = []
var _ui_gap: float = 0.0
var _ui_quiet: float = 0.0

var _step_dist: float = 0.0
var _air_time: float = 0.0
var _was_on_floor: bool = true

var _pos_timer: float = 0.0
var _bird_timer: float = 0.0
var _spring_pos: Vector3 = Vector3.ZERO
var _piece_count: int = 0
var _struct_count: int = 0
var _bound: bool = false


func _ready() -> void:
	name = "AudioManager"
	add_to_group("audio_manager")
	_rng.randomize()
	_setup_buses()
	_bank = SoundBank.new().build_all()
	_build_players()
	_bird_timer = _next_bird_gap()


## Katalog (ad -> Array[AudioStreamWAV]); testler için.
func bank() -> Dictionary:
	return _bank


# ---------- Kurulum ----------

func _ensure_bus(bus_name: String, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, AC.BUS_MASTER)
	AudioServer.set_bus_volume_db(idx, db)


func _setup_buses() -> void:
	_ensure_bus(AC.BUS_SFX, AC.BUS_DB_SFX)
	_ensure_bus(AC.BUS_AMBIENCE, AC.BUS_DB_AMBIENCE)
	_ensure_bus(AC.BUS_UI, AC.BUS_DB_UI)


func _stream_of(sound: String) -> AudioStream:
	var list: Array = _bank.get(sound, [])
	return list[0] if not list.is_empty() else null


func _make_player(bus: String, pool: Array) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	pool.append(p)
	return p


func _make_3d(sound: String, db: float, bus: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = bus
	p.stream = _stream_of(sound)
	p.volume_db = db
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = AC.POS_UNIT_SIZE
	p.max_distance = AC.POS_MAX_DISTANCE
	add_child(p)
	return p


func _build_players() -> void:
	for i in range(AC.SFX_VOICES):
		_make_player(AC.BUS_SFX, _sfx_voices)
	for i in range(AC.UI_VOICES):
		_make_player(AC.BUS_UI, _ui_voices)
	var scratch: Array = []
	_fill_player = _make_player(AC.BUS_SFX, scratch)
	_fill_player.stream = _stream_of("fill_loop")
	_fill_player.volume_db = SILENT_DB
	_wind_player = _make_player(AC.BUS_AMBIENCE, scratch)
	_wind_player.stream = _stream_of("wind_loop")
	_wind_player.volume_db = AC.WIND_DB
	var defs: Array = [["spring_loop", AC.SPRING_DB], ["lake_loop", AC.LAKE_DB], ["canal_loop", AC.CANAL_DB], ["canal_loop", AC.CANAL_DB], ["mill_loop", AC.MILL_DB]]
	for d: Array in defs:
		_pos_players.append(_make_3d(String(d[0]), float(d[1]), AC.BUS_SFX))
		_pos_target.append(Vector3.ZERO)
		_pos_active.append(false)
	_pos_players[SRC_WATER_B].pitch_scale = 1.07
	_bird_player = _make_3d("bird", AC.BIRD_DB, AC.BUS_AMBIENCE)
	_sched_time.resize(AC.SCHEDULE_SLOTS)
	for i in range(AC.SCHEDULE_SLOTS):
		_sched_name.append("")


## Oyun nesnelerini bağlar; sinyalleri dinler, arayüz düğmelerine tık sesi takar.
func bind(game_node: Node, player_node: Node, equipment_node: Node, lake_node: Node, settings_node: Node, panels: Array = []) -> void:
	game = game_node
	player = player_node
	equipment = equipment_node
	lake = lake_node
	settings = settings_node
	_spring_pos = SpringBuilder.origin() + Vector3(0.0, AC.SPRING_HEIGHT, 0.0)
	if game != null:
		game.connect("filled", _on_filled)
		game.connect("poured", _on_poured)
		game.connect("stage_changed", _on_stage)
		game.connect("purchased", _on_purchased)
		game.connect("purchase_denied", _on_purchase_denied)
		game.connect("structures_changed", _on_structures_changed)
		_piece_count = int((game.get("canal") as Object).call("piece_count"))
		_struct_count = (game.get("state") as Object).get("structures").size()
	if equipment != null:
		equipment.connect("hammer_denied", _on_hammer_denied)
	if settings != null:
		settings.connect("sound_changed", _on_sound_changed)
		_apply_volume(bool(settings.get("sound_on")), float(settings.get("volume")))
	else:
		_apply_volume(AC.DEFAULT_SOUND_ON, AC.DEFAULT_VOLUME)
	for entry: Array in panels:
		_panel_nodes.append(entry[0] as Node)
		_panel_kinds.append(String(entry[1]))
		_panel_open.append(bool((entry[0] as Node).call("is_open")))
	_hook_tree(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	_wind_player.play()
	_bound = true


func _apply_volume(on: bool, volume: float) -> void:
	var idx: int = AudioServer.get_bus_index(AC.BUS_MASTER)
	AudioServer.set_bus_volume_db(idx, AC.master_db(volume, on))
	AudioServer.set_bus_mute(idx, not on)


func _on_sound_changed(on: bool, volume: float) -> void:
	_apply_volume(on, volume)


# ---------- Olay çalma ----------

## Olay adına bağlı sesi çalar (havuzdan serbest ses, yoksa en eskisi). Bilinmeyen olayda false.
func play_event(event: String, db_offset: float = 0.0, pitch_mul: float = 1.0) -> bool:
	var def: Dictionary = AC.EVENTS.get(event, {})
	if def.is_empty():
		return false
	var sound: String = def["sound"]
	var list: Array = _bank.get(sound, [])
	if list.is_empty():
		return false
	if String(def["bus"]) == "ambience":
		return _play_bird(list, def, db_offset)
	var idx: int = 0
	if list.size() > 1:
		idx = _rng.randi_range(0, list.size() - 1)
		if idx == int(_last_variant.get(sound, -1)):
			idx = (idx + 1) % list.size()
		_last_variant[sound] = idx
	var pool: Array[AudioStreamPlayer] = _ui_voices if String(def["bus"]) == "ui" else _sfx_voices
	var p: AudioStreamPlayer = _acquire(pool)
	p.stream = list[idx]
	p.volume_db = float(def["db"]) + db_offset
	var spread: float = float(def["pitch"])
	p.pitch_scale = pitch_mul * (1.0 + _rng.randf_range(-spread, spread))
	p.play()
	return true


func _acquire(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = pool[0]
	var oldest_pos: float = -1.0
	for p: AudioStreamPlayer in pool:
		if not p.playing:
			return p
		var pos: float = p.get_playback_position()
		if pos > oldest_pos:
			oldest_pos = pos
			oldest = p
	return oldest


## Aynı anda çalan (havuz + döngü) ses sayısı; testler için.
func playing_count() -> int:
	var n: int = 0
	for p: AudioStreamPlayer in _sfx_voices:
		if p.playing:
			n += 1
	for p: AudioStreamPlayer in _ui_voices:
		if p.playing:
			n += 1
	return n


func voice_capacity() -> int:
	return _sfx_voices.size() + _ui_voices.size()


func positional_count() -> int:
	return _pos_players.size()


func _schedule(event: String, delay: float) -> void:
	for i in range(_sched_name.size()):
		if _sched_name[i].is_empty():
			_sched_name[i] = event
			_sched_time[i] = delay
			return


func _run_schedule(delta: float) -> void:
	for i in range(_sched_name.size()):
		if _sched_name[i].is_empty():
			continue
		_sched_time[i] -= delta
		if _sched_time[i] <= 0.0:
			var ev: String = _sched_name[i]
			_sched_name[i] = ""
			play_event(ev)


# ---------- Oyun olayları ----------

func _on_filled(_amount: float) -> void:
	_fill_hold = AC.FILL_HOLD_SEC
	if _was_full or game == null:
		return
	var state: Object = game.get("state")
	if float(state.get("carried")) >= Economy.tool_capacity(state as GameState) - AC.FILL_FULL_EPS:
		_was_full = true
		play_event("fill_full")


func _on_poured(drops: float, money: float) -> void:
	if drops < AC.POUR_SMALL_DROPS:
		play_event("pour_small")
	elif drops < AC.POUR_MID_DROPS:
		play_event("pour_mid")
	else:
		play_event("pour_large")
	for i in range(AC.PLINK_COUNT):
		_schedule("plink", _rng.randf_range(AC.PLINK_DELAY_MIN, AC.PLINK_DELAY_MAX))
	if money > 0.0:
		_schedule("coins", AC.COIN_DELAY_SEC)


func _on_stage(_index: int) -> void:
	play_event("stage")


func _on_purchased(kind: String, _id: String) -> void:
	play_event("unlock" if kind.contains("unlock") else "purchase")


func _on_purchase_denied(_kind: String, _id: String) -> void:
	play_event("purchase_denied")


func _on_hammer_denied(_unlocked: bool) -> void:
	play_event("purchase_denied")


## Kur / sök / döndür: kanal parçası ya da yapı sayısındaki değişimden anlaşılır (eşitse döndürme ya da savak).
func _on_structures_changed() -> void:
	if game == null:
		return
	var pieces: int = int((game.get("canal") as Object).call("piece_count"))
	var structs: int = (game.get("state") as Object).get("structures").size()
	var total_now: int = pieces + structs
	var total_before: int = _piece_count + _struct_count
	_piece_count = pieces
	_struct_count = structs
	if total_now > total_before:
		play_event("build_place")
	elif total_now < total_before:
		play_event("build_remove")
	else:
		play_event("build_rotate")


# ---------- Arayüz ----------

func _hook_tree(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)
	for child: Node in node.get_children():
		_hook_tree(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)


func _hook_button(button: BaseButton) -> void:
	var hover := Callable(self, "_on_ui_hover").bind(button)
	if button.mouse_entered.is_connected(hover):
		return
	button.mouse_entered.connect(hover)
	button.focus_entered.connect(hover)
	button.pressed.connect(Callable(self, "_on_ui_click").bind(button))


func _on_ui_hover(button: BaseButton) -> void:
	if button.disabled or _ui_gap > 0.0 or _ui_quiet > 0.0:
		return
	_ui_gap = AC.UI_HOVER_MIN_GAP
	play_event("ui_hover")


func _on_ui_click(button: BaseButton) -> void:
	if button.disabled:
		return
	play_event("ui_click")


func _poll_panels() -> void:
	for i in range(_panel_nodes.size()):
		var open: bool = bool(_panel_nodes[i].call("is_open"))
		if open == _panel_open[i]:
			continue
		_panel_open[i] = open
		_ui_quiet = 0.25
		if _panel_kinds[i] == "book":
			play_event("book_open" if open else "book_close")
		else:
			play_event("panel_open" if open else "panel_close")


# ---------- Kare ----------

func _process(delta: float) -> void:
	_ui_gap = maxf(_ui_gap - delta, 0.0)
	_ui_quiet = maxf(_ui_quiet - delta, 0.0)
	_run_schedule(delta)
	_update_fill(delta)
	if not _bound:
		return
	_poll_panels()
	_update_steps(delta)
	_update_positional(delta)
	_update_birds(delta)


func _update_fill(delta: float) -> void:
	_fill_hold = maxf(_fill_hold - delta, 0.0)
	var target: float = AC.FILL_DB if _fill_hold > 0.0 else SILENT_DB
	var speed: float = AC.FILL_FADE_IN if target > _fill_db else AC.FILL_FADE_OUT
	_fill_db = move_toward(_fill_db, target, speed * delta)
	if _fill_db <= SILENT_DB + 0.5:
		if _fill_player.playing:
			_fill_player.stop()
	else:
		if not _fill_player.playing:
			_fill_player.play()
		_fill_player.volume_db = _fill_db
	if _was_full and game != null:
		var state: Object = game.get("state")
		if float(state.get("carried")) < Economy.tool_capacity(state as GameState) - AC.FILL_FULL_EPS:
			_was_full = false


func _in_water() -> bool:
	if lake == null or player == null:
		return false
	var r: float = float(lake.call("shore_radius"))
	if r <= AC.LAKE_MIN_RADIUS:
		return false
	var pos: Vector3 = (player as Node3D).global_position
	return Vector2(pos.x, pos.z).length() < r - AC.STEP_WATER_MARGIN


func _update_steps(delta: float) -> void:
	if player == null:
		return
	var on_floor: bool = bool(player.call("is_on_floor"))
	var vel: Vector3 = player.get("velocity")
	var speed: float = Vector2(vel.x, vel.z).length()
	if on_floor:
		if not _was_on_floor and _air_time > 0.2:
			play_event("step_water" if _in_water() else "land")
		_air_time = 0.0
	else:
		_air_time += delta
	_was_on_floor = on_floor
	var stride: float = AC.STRIDE_SPRINT if speed >= AC.SPRINT_SPEED_MIN else AC.STRIDE_WALK
	if on_floor and speed >= AC.STEP_MIN_SPEED and bool(player.get("input_enabled")):
		_step_dist += speed * delta
		if _step_dist >= stride:
			_step_dist -= stride
			play_event("step_water" if _in_water() else "step_grass")
	elif speed < AC.STEP_MIN_SPEED:
		_step_dist = stride * 0.6


# ---------- Konumlu döngüler ----------

func _set_source(index: int, active: bool, pos: Vector3) -> void:
	_pos_active[index] = active
	_pos_target[index] = pos


func _refresh_positional() -> void:
	var pp: Vector3 = (player as Node3D).global_position
	_set_source(SRC_SPRING, true, _spring_pos)
	# Göl kıyısı: oyuncuya en yakın kıyı noktası (içindeyse oyuncunun altı)
	var shore: float = float(lake.call("shore_radius")) if lake != null else 0.0
	if shore > AC.LAKE_MIN_RADIUS:
		var flat := Vector2(pp.x, pp.z)
		var d: float = flat.length()
		var level: float = float(lake.call("water_level"))
		if d <= shore or d < 0.001:
			_set_source(SRC_LAKE, true, Vector3(pp.x, level, pp.z))
		else:
			var edge: Vector2 = flat / d * shore
			_set_source(SRC_LAKE, true, Vector3(edge.x, level, edge.y))
	else:
		_set_source(SRC_LAKE, false, Vector3.ZERO)
	if game == null:
		_set_source(SRC_WATER_A, false, Vector3.ZERO)
		_set_source(SRC_WATER_B, false, Vector3.ZERO)
		_set_source(SRC_MILL, false, Vector3.ZERO)
		return
	# Su kaynakları: akan kanal hücreleri ve çeşmelerden oyuncuya en yakın ikisi; en yakın akan değirmen
	var d0: float = FAR
	var d1: float = FAR
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var dm: float = FAR
	var pm := Vector2.ZERO
	var net: Object = game.get("canal")
	var flowing: Array = (game.call("canal_result") as Dictionary).get("flowing", [])
	for cell: Vector2i in flowing:
		var c: Vector2 = CanalField.cell_center(cell.x, cell.y)
		var dist: float = (c.x - pp.x) * (c.x - pp.x) + (c.y - pp.z) * (c.y - pp.z)
		if dist < d0:
			d1 = d0
			p1 = p0
			d0 = dist
			p0 = c
		elif dist < d1:
			d1 = dist
			p1 = c
		if dist < dm:
			var piece: Dictionary = net.call("get_piece", cell.x, cell.y)
			if not piece.is_empty() and String(piece["piece"]) == "mill":
				dm = dist
				pm = c
	var structures: Array = (game.get("state") as Object).get("structures")
	for s: Dictionary in structures:
		if not bool(s.get("placed", false)) or not AC.WATER_STRUCTURE_KINDS.has(String(s["kind"])):
			continue
		var c := Vector2(float(s["x"]), float(s["z"]))
		var dist: float = (c.x - pp.x) * (c.x - pp.x) + (c.y - pp.z) * (c.y - pp.z)
		if dist < d0:
			d1 = d0
			p1 = p0
			d0 = dist
			p0 = c
		elif dist < d1:
			d1 = dist
			p1 = c
	var limit: float = AC.POS_MAX_DISTANCE * AC.POS_MAX_DISTANCE
	_set_source(SRC_WATER_A, d0 < limit, Vector3(p0.x, pp.y, p0.y))
	_set_source(SRC_WATER_B, d1 < limit, Vector3(p1.x, pp.y, p1.y))
	_set_source(SRC_MILL, dm < limit, Vector3(pm.x, pp.y + 0.6, pm.y))


func _update_positional(delta: float) -> void:
	if player == null:
		return
	_pos_timer -= delta
	if _pos_timer <= 0.0:
		_pos_timer = AC.POS_UPDATE_SEC
		_refresh_positional()
	for i in range(_pos_players.size()):
		var p: AudioStreamPlayer3D = _pos_players[i]
		if _pos_active[i]:
			if not p.playing:
				p.global_position = _pos_target[i]
				p.play(_rng.randf() * 0.5)
			else:
				p.global_position = p.global_position.move_toward(_pos_target[i], AC.POS_MOVE_SPEED * delta)
		elif p.playing:
			p.stop()


# ---------- Ambiyans ----------

func _next_bird_gap() -> float:
	var gap: float = _rng.randf_range(AC.BIRD_GAP_MIN, AC.BIRD_GAP_MAX)
	if game != null and Economy.bird_count((game.get("state") as GameState)) > 0:
		gap *= AC.BIRD_GAP_FACTOR_WITH_BIRDS
	return gap


func _update_birds(delta: float) -> void:
	_bird_timer -= delta
	if _bird_timer > 0.0 or player == null:
		return
	_bird_timer = _next_bird_gap()
	play_event("bird")


func _play_bird(list: Array, def: Dictionary, db_offset: float) -> bool:
	var pp := Vector3.ZERO
	if player != null:
		pp = (player as Node3D).global_position
	var ang: float = _rng.randf() * TAU
	var dist: float = _rng.randf_range(AC.BIRD_DISTANCE_MIN, AC.BIRD_DISTANCE_MAX)
	_bird_player.global_position = pp + Vector3(cos(ang) * dist, _rng.randf_range(AC.BIRD_HEIGHT_MIN, AC.BIRD_HEIGHT_MAX), sin(ang) * dist)
	_bird_player.stream = list[_rng.randi_range(0, list.size() - 1)]
	_bird_player.volume_db = float(def["db"]) + db_offset
	var spread: float = float(def["pitch"])
	_bird_player.pitch_scale = 1.0 + _rng.randf_range(-spread, spread)
	_bird_player.play()
	return true
