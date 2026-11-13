extends Node3D
## Kameraya bagli birinci sahis kollar ve avuc; avucta tasinan/kapasite oranina gore yukselen su.
## Dis arayuz: script yolu, `game` alani (kurulumdan once atanir), kameranin cocugu olarak eklenir.

const Cfg = preload("res://scripts/player/arms_config.gd")
const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")
const Economy = preload("res://scripts/core/economy.gd")
const EconomyCfg = preload("res://scripts/core/economy_config.gd")
const ToolModels = preload("res://scripts/player/tool_models.gd")


var game: Node

var _rig: Node3D
var _model: Node3D
var _water: MeshInstance3D
var _water_home: Vector3
var _blend: float = 0.0          # 0 bos durus, 1 avuc durusu
var _shown_ratio: float = 0.0
var _speed: float = 0.0
var _walk_phase: float = 0.0
var _clock: float = 0.0
var _pour_t: float = -1.0
var _last_pos: Vector3
var _water_mat: StandardMaterial3D
var _skin_mat: StandardMaterial3D
var _tools: Array[Dictionary] = []   # seviye -> {"root": Node3D, "waters": Array[Node3D]}; seviye 0 (avuc) bos
var _shown_level: int = -1           # gorunen alet seviyesi
var _drop: float = 0.0               # alet degisim animasyonu, 0..1
var lowered: float = 0.0             # cekic girerken disaridan verilen indirme, 0..1


func _ready() -> void:
	name = "HeldVessel"
	_rig = Node3D.new()
	_rig.name = "Arms"
	_rig.scale = Vector3.ONE
	add_child(_rig)

	var scene: PackedScene = load(Cfg.MODEL_PATH)
	_model = scene.instantiate() as Node3D
	_model.name = "HandsModel"
	_model.scale = Vector3.ONE * Cfg.ARM_SCALE
	_rig.add_child(_model)

	_skin_mat = StandardMaterial3D.new()
	_skin_mat.vertex_color_use_as_albedo = true
	_skin_mat.albedo_color = Color.WHITE
	_skin_mat.roughness = 0.85
	_water_mat = StandardMaterial3D.new()
	_water_mat.albedo_color = Cfg.WATER
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 1.0
	_water_mat.metallic_specular = 0.0
	_water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name == "Water":
			_water = mi
			_water_home = mi.position
			mi.material_override = _water_mat
			mi.visible = false
		else:
			mi.material_override = _skin_mat
	_build_tools()
	_bind_quality()
	# Eller ve aletler gölge alır ama atmaz (kameraya bu kadar yakın nesnenin yere gölgesi tuhaf durur)
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if game != null and game.has_signal("poured"):
		game.connect("poured", _on_poured)
	_last_pos = global_position
	_apply_pose(0.0)


## Kalite ayarına bağlanır: Orta/Yüksek'te tonemap teni solgunlaştırır, çarpan bunu dengeler.
func _bind_quality() -> void:
	var settings: Node = get_tree().get_first_node_in_group("graphics_settings")
	if settings == null:
		return
	settings.connect("quality_changed", _on_quality_changed.bind(settings))
	_on_quality_changed(0, settings)


func _on_quality_changed(_level: int, settings: Node) -> void:
	var gain: float = float(settings.get("skin_gain"))
	_skin_mat.albedo_color = Color(gain, gain * GraphicsConfig.SKIN_WARMTH.x, gain * GraphicsConfig.SKIN_WARMTH.y)


## Seviye basina alet modeli (glb ya da yer tutucu) kurulur; hepsi gizli baslar.
func _build_tools() -> void:
	_tools.clear()
	for level: int in EconomyCfg.TOOLS.size():
		var id: String = EconomyCfg.TOOLS[level]["id"]
		if level == 0:
			_tools.append({})
			continue
		var entry: Dictionary = ToolModels.build(id)
		var root: Node3D = entry["root"]
		root.visible = false
		for water: Node3D in entry["waters"]:
			_style_water(water)
		if level == 1:
			root.position = Cfg.CUP_TOOL_POS
			root.scale = Vector3.ONE * Cfg.CUP_TOOL_SCALE
			_model.add_child(root)
		else:
			root.scale = Vector3.ONE * float(_pose(id)["scale"])
			_rig.add_child(root)
			if id == "bucket":
				var grip: Node3D = ToolModels.build_grip()
				if grip != null:
					grip.name = "Grip"
					for node: Node in grip.find_children("*", "MeshInstance3D", true, false):
						(node as MeshInstance3D).material_override = _skin_mat
					root.add_child(grip)
		_tools.append(entry)


func _style_water(water: Node3D) -> void:
	if water is MeshInstance3D:
		(water as MeshInstance3D).material_override = _water_mat
	for node: Node in water.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _water_mat
	water.visible = false


func _pose(id: String) -> Dictionary:
	return Cfg.TOOL_POSES.get(id, Cfg.TOOL_POSES["bucket"])


func _show_level(level: int) -> void:
	_shown_level = level
	_model.visible = level <= 1
	for i: int in _tools.size():
		if i == 0:
			continue
		(_tools[i]["root"] as Node3D).visible = (i == level)


func _on_poured(_drops: float, _money: float) -> void:
	_pour_t = 0.0


func _process(delta: float) -> void:
	_clock += delta
	var ratio: float = 0.0
	var carried: float = 0.0
	if game != null:
		var state: Object = game.get("state")
		if state != null:
			var capacity: float = Economy.tool_capacity(state)
			carried = state.carried
			ratio = clampf(carried / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0

	# Yatay hiz (konum farki), yumusatilmis.
	var pos: Vector3 = global_position
	var flat_speed: float = Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() / maxf(delta, 0.0001)
	_last_pos = pos
	_speed = lerpf(_speed, minf(flat_speed, Cfg.WALK_SPEED_REF * 2.0), 1.0 - exp(-Cfg.SPEED_SMOOTH * delta))
	var walk: float = clampf(_speed / Cfg.WALK_SPEED_REF, 0.0, 1.0)
	_walk_phase += delta * Cfg.SWAY_FREQ * (0.4 + 0.6 * walk)

	var pour: float = 0.0
	if _pour_t >= 0.0:
		_pour_t += delta
		if _pour_t >= Cfg.POUR_TIME:
			_pour_t = -1.0
		else:
			pour = sin(PI * _pour_t / Cfg.POUR_TIME)

	var level: int = 0
	if game != null and game.get("state") != null:
		level = clampi(int((game.get("state") as Object).get("tool_level")), 0, EconomyCfg.TOOLS.size() - 1)
	if _shown_level < 0:
		_show_level(level)
	if level != _shown_level:
		_drop = move_toward(_drop, 1.0, Cfg.TOOL_CHANGE_SPEED * delta)
		if _drop >= 1.0:
			_show_level(level)
	else:
		_drop = move_toward(_drop, 0.0, Cfg.TOOL_CHANGE_SPEED * delta)

	var target: float = 1.0 if (carried > Cfg.CUP_CARRIED_MIN or _pour_t >= 0.0 or _shown_level == 1) else 0.0
	_blend = lerpf(_blend, target, 1.0 - exp(-Cfg.BLEND_SPEED * delta))
	_shown_ratio = lerpf(_shown_ratio, ratio, 1.0 - exp(-Cfg.WATER_LERP_SPEED * delta))

	# Sallanma: yurumede belirgin, dururken sadece nefes.
	position = Vector3(
		sin(_walk_phase) * Cfg.SWAY_X * walk,
		absf(sin(_walk_phase)) * Cfg.SWAY_Y * walk + sin(_clock * TAU * Cfg.BREATH_HZ) * Cfg.BREATH_Y,
		0.0)

	var walk_swing: float = sin(_walk_phase - Cfg.SWING_LAG) * walk
	_apply_pose(pour)
	_apply_tool_pose(pour, walk_swing)
	_update_water()


## Model konum/donusunu bos ve avuc durusu arasinda karistirir; dokme egilmesi eklenir.
func _apply_pose(pour: float) -> void:
	var t: float = smoothstep(0.0, 1.0, _blend)
	var pos: Vector3 = Cfg.IDLE_POS.lerp(Cfg.CUP_POS, t)
	var rot: Vector3 = Cfg.IDLE_ROT_DEG.lerp(Cfg.CUP_ROT_DEG, t)
	rot.x += Cfg.POUR_PITCH_DEG * pour
	pos.z += Cfg.POUR_FORWARD * pour
	pos.y += Cfg.POUR_LIFT * pour
	pos.y -= Cfg.TOOL_CHANGE_DROP * smoothstep(0.0, 1.0, maxf(_drop, lowered))
	_model.position = pos
	_model.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))


## Asili aletler (kova, cift kova, sirik): sarkac gibi sallanir, dokmede one egilir.
func _apply_tool_pose(pour: float, walk_swing: float) -> void:
	if _shown_level < 2:
		return
	var id: String = EconomyCfg.TOOLS[_shown_level]["id"]
	var pose: Dictionary = _pose(id)
	var root: Node3D = _tools[_shown_level]["root"]
	var swing: float = float(pose["swing"])
	var idle: float = sin(_clock * TAU * Cfg.IDLE_SWING_HZ) * Cfg.IDLE_SWING_DEG
	var rot: Vector3 = pose["rot"]
	rot.z += walk_swing * swing + idle
	rot.x += absf(walk_swing) * swing * 0.3 + float(pose["pour_pitch"]) * pour
	var pos: Vector3 = pose["pos"]
	pos += (pose["pour_pos"] as Vector3) * pour
	pos.y -= Cfg.TOOL_CHANGE_DROP * smoothstep(0.0, 1.0, maxf(_drop, lowered))
	root.position = pos
	root.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))


func _update_water() -> void:
	var visible_now: bool = _shown_ratio > Cfg.WATER_VISIBLE_MIN
	if _shown_level > 0:
		var waters: Array = _tools[_shown_level]["waters"]
		for water: Node3D in waters:
			water.visible = visible_now
			if visible_now:
				water.scale.y = _shown_ratio
	if _water == null:
		return
	if _shown_level > 0:
		_water.visible = false
		return
	_water.visible = visible_now
	if not visible_now:
		return
	var wobble: float = 1.0 + Cfg.WATER_WOBBLE * sin(_clock * TAU * Cfg.WATER_WOBBLE_HZ)
	var top: float = lerpf(Cfg.WATER_TOP_MIN, Cfg.WATER_TOP_MAX, _shown_ratio)
	var spread: float = lerpf(Cfg.WATER_SPREAD_MIN, 1.0, _shown_ratio) * wobble
	_water.scale = Vector3(spread, top / Cfg.WATER_MESH_HEIGHT, spread)
	_water.position = _water_home


## Hata ayiklama: modelin toplam ucgen sayisi (eller + su).
func triangle_count() -> int:
	var total: int = 0
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for si in range(mesh.get_surface_count()):
			total += mesh.surface_get_array_index_len(si) / 3
	return total
