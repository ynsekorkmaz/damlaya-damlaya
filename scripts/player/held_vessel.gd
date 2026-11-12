extends Node3D
## Kameraya bagli birinci sahis kollar ve avuc; avucta tasinan/kapasite oranina gore yukselen su.
## Dis arayuz: script yolu, `game` alani (kurulumdan once atanir), kameranin cocugu olarak eklenir.

const Cfg = preload("res://scripts/player/arms_config.gd")
const Economy = preload("res://scripts/core/economy.gd")


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

	var skin_mat := StandardMaterial3D.new()
	skin_mat.vertex_color_use_as_albedo = true
	skin_mat.albedo_color = Color.WHITE
	skin_mat.roughness = 0.85
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Cfg.WATER
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 1.0
	water_mat.metallic_specular = 0.0
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.name == "Water":
			_water = mi
			_water_home = mi.position
			mi.material_override = water_mat
			mi.visible = false
		else:
			mi.material_override = skin_mat

	if game != null and game.has_signal("poured"):
		game.connect("poured", _on_poured)
	_last_pos = global_position
	_apply_pose(0.0)


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

	var target: float = 1.0 if (carried > Cfg.CUP_CARRIED_MIN or _pour_t >= 0.0) else 0.0
	_blend = lerpf(_blend, target, 1.0 - exp(-Cfg.BLEND_SPEED * delta))
	_shown_ratio = lerpf(_shown_ratio, ratio, 1.0 - exp(-Cfg.WATER_LERP_SPEED * delta))

	# Sallanma: yurumede belirgin, dururken sadece nefes.
	position = Vector3(
		sin(_walk_phase) * Cfg.SWAY_X * walk,
		absf(sin(_walk_phase)) * Cfg.SWAY_Y * walk + sin(_clock * TAU * Cfg.BREATH_HZ) * Cfg.BREATH_Y,
		0.0)

	_apply_pose(pour)
	_update_water()


## Model konum/donusunu bos ve avuc durusu arasinda karistirir; dokme egilmesi eklenir.
func _apply_pose(pour: float) -> void:
	var t: float = smoothstep(0.0, 1.0, _blend)
	var pos: Vector3 = Cfg.IDLE_POS.lerp(Cfg.CUP_POS, t)
	var rot: Vector3 = Cfg.IDLE_ROT_DEG.lerp(Cfg.CUP_ROT_DEG, t)
	rot.x += Cfg.POUR_PITCH_DEG * pour
	pos.z += Cfg.POUR_FORWARD * pour
	pos.y += Cfg.POUR_LIFT * pour
	_model.position = pos
	_model.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))


func _update_water() -> void:
	if _water == null:
		return
	var visible_now: bool = _shown_ratio > Cfg.WATER_VISIBLE_MIN
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
