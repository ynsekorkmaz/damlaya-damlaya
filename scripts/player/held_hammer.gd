extends Node3D
## Elde çekiç: ekranın sağ altında (hammer.glb ya da yer tutucu), yürürken hafif sallanır, yapı kurunca kısa vuruş yapar,
## alet değişiminde aşağıdan yumuşakça girer/çıkar. Su aleti (held_vessel) çekiç girerken aşağı iner.
## Dış bağlantı: kamera çocuğu olarak eklenir; `equipment` (ve isteğe bağlı `vessel`) atanır.

const Config = preload("res://scripts/core/config.gd")
const Placeholders = preload("res://scripts/world/placeholder_models.gd")

const REST_POS := Vector3(0.27, -0.30, -0.50)
const REST_ROT_DEG := Vector3(-32.0, 24.0, -10.0)
const MODEL_SCALE: float = 1.25
const HIDE_DROP: float = 0.55           # çekiç gizliyken aşağı kayma (m)
const BLEND_SPEED: float = 5.0          # giriş/çıkış hızı (1/sn)
const STRIKE_TIME: float = 0.28
const STRIKE_PITCH_DEG: float = -62.0
const STRIKE_FORWARD: float = -0.08
const STRIKE_DOWN: float = -0.05
const SWAY_X: float = 0.010
const SWAY_Y: float = 0.008
const SWAY_FREQ: float = 7.0
const WALK_SPEED_REF: float = 5.0
const SPEED_SMOOTH: float = 8.0
const BREATH_Y: float = 0.0014
const BREATH_HZ: float = 0.7
const SKIN := Color(0.70, 0.50, 0.38)

var equipment: Node
var vessel: Node3D

var _rig: Node3D
var _t: float = 0.0
var _strike: float = -1.0
var _clock: float = 0.0
var _walk_phase: float = 0.0
var _speed: float = 0.0
var _last_pos: Vector3


func _ready() -> void:
	name = "HeldHammer"
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var model: Node3D = null
	if ResourceLoader.exists(Config.HAMMER_MODEL_PATH):
		var scene: PackedScene = load(Config.HAMMER_MODEL_PATH)
		if scene != null:
			model = scene.instantiate() as Node3D
	if model == null:
		model = Placeholders.hammer()
	model.name = "HammerModel"
	model.scale = Vector3.ONE * MODEL_SCALE
	_rig.add_child(model)
	_rig.add_child(_build_hand())
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_last_pos = global_position
	visible = false


## Sapı saran yumruk ve geriye uzanan ön kol (basit, ten rengi).
func _build_hand() -> Node3D:
	var hand := Node3D.new()
	hand.name = "Hand"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SKIN
	mat.roughness = 0.85
	var fist := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.042
	fm.height = 0.084
	fm.radial_segments = 12
	fm.rings = 6
	fist.mesh = fm
	fist.scale = Vector3(1.15, 0.9, 1.0) * MODEL_SCALE
	fist.position = Vector3(0.0, 0.02, 0.0)
	fist.material_override = mat
	hand.add_child(fist)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.030
	am.bottom_radius = 0.040
	am.height = 0.34
	am.radial_segments = 10
	am.rings = 1
	arm.mesh = am
	arm.material_override = mat
	# Ön kol: yumruktan kameraya doğru ve aşağı
	var dir := Vector3(0.30, -0.80, 0.50).normalized()
	arm.position = dir * 0.18 + Vector3(0.0, 0.02, 0.0)
	arm.basis = Basis(Quaternion(Vector3.UP, dir))
	hand.add_child(arm)
	return hand


## Yapı kurulunca vuruş hareketi.
func swing() -> void:
	_strike = 0.0


func _process(delta: float) -> void:
	_clock += delta
	var want: float = 1.0 if (equipment != null and bool(equipment.call("hammer_active"))) else 0.0
	_t = move_toward(_t, want, BLEND_SPEED * delta)
	if vessel != null:
		vessel.set("lowered", _t)
		vessel.visible = _t < 0.995
	visible = _t > 0.005

	var pos: Vector3 = global_position
	var flat: float = Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() / maxf(delta, 0.0001)
	_last_pos = pos
	_speed = lerpf(_speed, minf(flat, WALK_SPEED_REF * 2.0), 1.0 - exp(-SPEED_SMOOTH * delta))
	var walk: float = clampf(_speed / WALK_SPEED_REF, 0.0, 1.0)
	_walk_phase += delta * SWAY_FREQ * (0.4 + 0.6 * walk)

	var strike: float = 0.0
	if _strike >= 0.0:
		_strike += delta
		if _strike >= STRIKE_TIME:
			_strike = -1.0
		else:
			strike = sin(PI * _strike / STRIKE_TIME)

	var shown: float = smoothstep(0.0, 1.0, _t)
	var p: Vector3 = REST_POS
	p.x += sin(_walk_phase) * SWAY_X * walk
	p.y += absf(sin(_walk_phase)) * SWAY_Y * walk + sin(_clock * TAU * BREATH_HZ) * BREATH_Y
	p.y -= HIDE_DROP * (1.0 - shown)
	p.z += STRIKE_FORWARD * strike
	p.y += STRIKE_DOWN * strike
	var rot: Vector3 = REST_ROT_DEG
	rot.x += STRIKE_PITCH_DEG * strike
	_rig.position = p
	_rig.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
