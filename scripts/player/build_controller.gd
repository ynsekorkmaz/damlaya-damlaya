extends Node
## Çekiçle yerleştirme: bakılan zemin noktası (kamera ışını, en çok 8 m), kanal hücresi vurgusu ve yarı saydam önizleme,
## sol tık kur (basılı tutup sürükleyince döşer), sağ tık sök, R döndür, savakta E aç/kapat.
## Dış bağlantı: add_child'dan önce game, player, equipment, lake, hud (isteğe bağlı), hammer_view (isteğe bağlı) atanır.

const Config = preload("res://scripts/core/config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const Build = preload("res://scripts/core/build.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const BuildRules = preload("res://scripts/core/build_rules.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const CanalView = preload("res://scripts/world/canal_view.gd")
const StructuresView = preload("res://scripts/world/structures_view.gd")
const RockSurface = preload("res://scripts/world/rock_surface.gd")

const GHOST_OK := Color(0.45, 1.0, 0.55, 0.45)
const GHOST_BAD := Color(1.0, 0.40, 0.35, 0.45)
const HL_OK := Color(0.45, 1.0, 0.55, 0.26)
const HL_BAD := Color(1.0, 0.40, 0.35, 0.26)
const HL_NEUTRAL := Color(1.0, 0.93, 0.55, 0.22)
const HIGHLIGHT_LIFT: float = 0.045
const MARKER_RADIUS: float = 0.55
const MOVE_EPS: float = 0.04
const PROMPT_NO_SELECTION: String = "Q: yapı seç"
const PROMPT_OFF_FIELD: String = "Kanalı batıdaki kanal alanına kur (gölün solu)"
const PROMPT_GATE_OPEN: String = "E: savağı kapat"
const PROMPT_GATE_CLOSED: String = "E: savağı aç"
const PROMPT_OCCUPIED: String = "%s: R döndür, sağ tık söker"
const PROMPT_REMOVE: String = "Sağ tık: sök"

var game: Node
var player: CharacterBody3D
var equipment: Node
var lake: Node
var hud: Node
var hammer_view: Node
var audio: Node ## audio_manager (isteğe bağlı): yerleştirilemez sesi

var looked_cell: Vector2i = CanalField.NONE
var looked_gate: bool = false
var debug_force: bool = false ## ekran goruntusu: fare yakalanmis gibi calis

var _prompt: String = ""
var _was_captured: bool = false
var _version: int = 0
var _last_drag_cell: Vector2i = CanalField.NONE

# Işın sonucu (fizik karesinde)
var _has_hit: bool = false
var _hit_pos: Vector3 = Vector3.ZERO
var _hit_normal: Vector3 = Vector3.UP
var _hit_on_rock: bool = false
var _crack_ok: bool = false
var _crack_pos: Vector3 = Vector3.ZERO
var _crack_normal: Vector3 = Vector3.UP

# Önizleme
var _root: Node3D
var _previews: Dictionary = {}
var _preview_key: String = ""
var _preview_ok: int = -1
var _ghost_ok: StandardMaterial3D
var _ghost_bad: StandardMaterial3D
var _hl_cell: MeshInstance3D
var _hl_disc: MeshInstance3D
var _hl_mats: Dictionary = {}

# Denetim önbelleği
var _ck_cell: Vector2i = CanalField.NONE
var _ck_rot: int = -1
var _ck_sel: String = ""
var _ck_mat: String = ""
var _ck_money: int = -1
var _ck_version: int = -1
var _ck_ok: bool = false
var _ck_prompt: String = ""
var _ck_occupied: bool = false

var _fk_pos: Vector3 = Vector3(1.0e9, 0.0, 0.0)
var _fk_sel: String = ""
var _fk_money: int = -1
var _fk_version: int = -1
var _fk_shore: float = -1.0
var _fk_ok: bool = false
var _fk_prompt: String = ""


func _ready() -> void:
	name = "BuildController"
	_root = Node3D.new()
	_root.name = "Previews"
	add_child(_root)
	_ghost_ok = _ghost(GHOST_OK)
	_ghost_bad = _ghost(GHOST_BAD)
	_hl_mats = {1: _flat_material(HL_OK), 0: _flat_material(HL_BAD), 2: _flat_material(HL_NEUTRAL)}
	var plane := PlaneMesh.new()
	plane.size = Vector2(Config.CANAL_CELL_SIZE, Config.CANAL_CELL_SIZE)
	_hl_cell = MeshInstance3D.new()
	_hl_cell.mesh = plane
	_hl_cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hl_cell.visible = false
	_hl_cell.material_override = _hl_mats[2]
	_root.add_child(_hl_cell)
	var disc := CylinderMesh.new()
	disc.top_radius = MARKER_RADIUS
	disc.bottom_radius = MARKER_RADIUS
	disc.height = 0.012
	disc.radial_segments = 20
	disc.rings = 1
	_hl_disc = MeshInstance3D.new()
	_hl_disc.mesh = disc
	_hl_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hl_disc.visible = false
	_hl_disc.material_override = _hl_mats[2]
	_root.add_child(_hl_disc)
	if game != null:
		game.connect("structures_changed", _on_changed)


func _on_changed() -> void:
	_version += 1


func _is_captured() -> bool:
	return debug_force or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and bool(player.get("input_enabled")))


func has_prompt() -> bool:
	return not _prompt.is_empty()


static func _ghost(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b) * 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# ---------- Işın ----------

func _physics_process(_delta: float) -> void:
	_has_hit = false
	_crack_ok = false
	if game == null or player == null or equipment == null:
		return
	if not _is_captured():
		return
	var hammer: bool = bool(equipment.call("hammer_active"))
	var px: float = player.global_position.x
	var pz: float = player.global_position.z
	if not hammer and CanalField.distance_to(px, pz) > Config.GATE_REACH + 1.0:
		return
	var cam: Camera3D = player.call("get_camera")
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var reach: float = Config.BUILD_REACH if hammer else Config.GATE_REACH
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	var t_phys: float = INF
	if not hit.is_empty():
		t_phys = origin.distance_to(hit["position"])
		_hit_pos = hit["position"]
		_hit_normal = hit["normal"]
		_has_hit = true
		var collider: Object = hit["collider"]
		_hit_on_rock = collider is Node and (collider as Node).is_in_group("rock")
	if hammer:
		var rh: Dictionary = RockSurface.ray_hit(origin, dir, reach)
		if not rh.is_empty() and float(rh["t"]) <= t_phys:
			_hit_pos = rh["position"]
			_hit_normal = rh["normal"]
			_hit_on_rock = true
			_has_hit = true
	if hammer and _has_hit and _hit_on_rock and equipment.call("selected_id") == "crack":
		_project_crack(space)


## Çatlak hedefi: bakılan kaya noktasının üstünden aşağı bakınca görünen yüzey (büyük kaya: görünür yüzey, kaynak kayası: fizik).
func _project_crack(space: PhysicsDirectSpaceState3D) -> void:
	var big: Dictionary = RockSurface.project_down(_hit_pos.x, _hit_pos.z)
	if not big.is_empty():
		_crack_pos = big["position"]
		_crack_normal = big["normal"]
		_crack_ok = true
		return
	var q := PhysicsRayQueryParameters3D.create(_hit_pos + Vector3(0.0, 2.5, 0.0), _hit_pos + Vector3(0.0, -0.4, 0.0))
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty() and (hit["collider"] as Node).is_in_group("rock"):
		_crack_pos = hit["position"]
		_crack_normal = hit["normal"]
		_crack_ok = true
	else:
		_crack_pos = _hit_pos
		_crack_normal = _hit_normal
		_crack_ok = true


# ---------- Girdi ----------

func _unhandled_input(event: InputEvent) -> void:
	if game == null or equipment == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not bool(player.get("input_enabled")):
		return
	if event.is_action_pressed("shop") and not event.is_echo() and looked_gate:
		if game.call("toggle_gate", looked_cell.x, looked_cell.y):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("rotate") and not event.is_echo() and bool(equipment.call("hammer_active")):
		_rotate()
		get_viewport().set_input_as_handled()


func _rotate() -> void:
	var piece: Dictionary = _piece_at(looked_cell)
	if not piece.is_empty():
		if game.call("rotate_canal", looked_cell.x, looked_cell.y) and hammer_view != null:
			hammer_view.call("swing")
		return
	if bool(equipment.call("is_canal")):
		equipment.set("canal_rotation", (int(equipment.get("canal_rotation")) + 1) % 4)
	elif bool(equipment.call("is_free")):
		equipment.set("free_rotation", fposmod(float(equipment.get("free_rotation")) + deg_to_rad(Config.PLACE_ROT_STEP_DEG), TAU))
	_ck_version = -1
	_fk_version = -1


func _piece_at(cell: Vector2i) -> Dictionary:
	if cell == CanalField.NONE:
		return {}
	return (game.get("canal") as Object).call("get_piece", cell.x, cell.y)


# ---------- Kare ----------

func _process(_delta: float) -> void:
	if game == null or player == null or equipment == null:
		return
	var captured: bool = _is_captured()
	var active: bool = captured and _was_captured
	_was_captured = captured
	_update_look(captured)
	if not captured:
		_hide_preview()
		_set_prompt("")
		return
	if not bool(equipment.call("hammer_active")):
		_hide_preview()
		_last_drag_cell = CanalField.NONE
		_set_prompt(_gate_prompt() if looked_gate else "")
		return
	var released: bool = not Input.is_action_pressed("interact")
	if released:
		_last_drag_cell = CanalField.NONE
	if active and Input.is_action_just_pressed("pour"):
		_try_remove()
	var sel: String = equipment.get("selected")
	if sel.is_empty():
		_hide_preview()
		_set_prompt(PROMPT_NO_SELECTION)
		return
	if bool(equipment.call("is_canal")):
		_process_canal(active)
	else:
		_process_free(active)


func _update_look(captured: bool) -> void:
	var cell: Vector2i = CanalField.NONE
	if captured and _has_hit:
		cell = CanalField.world_to_cell(_hit_pos.x, _hit_pos.z)
	looked_cell = cell
	looked_gate = false
	if cell != CanalField.NONE:
		var piece: Dictionary = _piece_at(cell)
		looked_gate = not piece.is_empty() and piece["piece"] == "gate"


func _gate_prompt() -> String:
	var piece: Dictionary = _piece_at(looked_cell)
	return PROMPT_GATE_OPEN if bool(piece.get("open", true)) else PROMPT_GATE_CLOSED


func _set_prompt(text: String) -> void:
	if text == _prompt:
		return
	_prompt = text
	game.call("set_prompt", text)


# ---------- Kanal parçası ----------

func _process_canal(active: bool) -> void:
	var piece_id: String = equipment.call("selected_id")
	var mat: String = equipment.get("material")
	var rot: int = equipment.get("canal_rotation")
	var cell: Vector2i = looked_cell
	if cell == CanalField.NONE:
		_hide_preview()
		_set_prompt(PROMPT_OFF_FIELD)
		return
	var piece: Dictionary = _piece_at(cell)
	var occupied: bool = not piece.is_empty()
	var money: int = int((game.get("state") as Object).get("money"))
	if cell != _ck_cell or rot != _ck_rot or piece_id != _ck_sel or mat != _ck_mat or money != _ck_money or _version != _ck_version:
		_ck_cell = cell
		_ck_rot = rot
		_ck_sel = piece_id
		_ck_mat = mat
		_ck_money = money
		_ck_version = _version
		_ck_occupied = occupied
		var def: Dictionary = Pieces.get_piece_def(piece_id)
		if occupied:
			_ck_ok = false
			var pdef: Dictionary = Pieces.get_piece_def(String(piece["piece"]))
			_ck_prompt = PROMPT_OCCUPIED % String(pdef.get("name_tr", ""))
		else:
			var check: Dictionary = game.call("can_place_canal", cell.x, cell.y, piece_id, rot, mat)
			_ck_ok = bool(check["ok"])
			if _ck_ok:
				_ck_prompt = "%s (%s): %s para   R: döndür" % [String(def.get("name_tr", piece_id)), _material_name(mat), NumberFormat.format_int(float(check["cost"]))]
			else:
				_ck_prompt = String(check["reason_tr"])
	_set_prompt(_ck_prompt)
	var center: Vector2 = CanalField.cell_center(cell.x, cell.y)
	var y: float = TerrainShape.height(center.x, center.y)
	if occupied:
		_show_highlight_cell(Vector3(center.x, y, center.y), 2)
		_activate_preview("")
		return
	_show_highlight_cell(Vector3(center.x, y, center.y), 1 if _ck_ok else 0)
	var key: String = "canal|%s|%s" % [piece_id, mat]
	var node: Node3D = _preview_node(key, func() -> Node3D: return CanalView.make_piece(piece_id, mat))
	node.position = Vector3(center.x, y, center.y)
	node.rotation.y = CanalField.yaw_of_rotation(rot)
	_activate_preview(key)
	_apply_ok(node, _ck_ok)
	if not active:
		return
	var pressed: bool = Input.is_action_just_pressed("interact")
	var held: bool = Input.is_action_pressed("interact")
	if pressed or (held and cell != _last_drag_cell):
		_last_drag_cell = cell
		if _ck_ok and game.call("place_canal", cell.x, cell.y, piece_id, rot, mat):
			_ck_version = -1
			if hammer_view != null:
				hammer_view.call("swing")
		elif not _ck_ok and pressed:
			_play_denied()


static func _material_name(material: String) -> String:
	return String(Pieces.MATERIALS.get(material, {}).get("name_tr", material))


# ---------- Serbest yapı ----------

func _process_free(active: bool) -> void:
	var kind: String = equipment.call("selected_id")
	if not _has_hit:
		_hide_preview()
		_set_prompt("")
		return
	var pos: Vector3 = _hit_pos
	var normal: Vector3 = _hit_normal
	if kind == "crack":
		if not _crack_ok:
			_hide_preview()
			_set_prompt(BuildCfg.REASON_CRACK_ROCK_TR)
			return
		pos = _crack_pos
		normal = _crack_normal
	var money: int = int((game.get("state") as Object).get("money"))
	var shore: float = _shore()
	if pos.distance_to(_fk_pos) > MOVE_EPS or kind != _fk_sel or money != _fk_money or _version != _fk_version or absf(shore - _fk_shore) > 0.05:
		_fk_pos = pos
		_fk_sel = kind
		_fk_money = money
		_fk_version = _version
		_fk_shore = shore
		var ctx: Dictionary = {
			"shore": shore, "max_radius": BasinShape.max_radius(),
			"structures": game.call("structures"), "on_rock": _hit_on_rock,
		}
		var rule: Dictionary = BuildRules.check_free(kind, pos.x, pos.z, ctx)
		var base: Dictionary = game.call("can_place_structure", kind)
		_fk_ok = bool(rule["ok"]) and bool(base["ok"])
		var def: Dictionary = Build.kind_def(kind)
		if not bool(base["ok"]):
			_fk_prompt = String(base["reason_tr"])
		elif not bool(rule["ok"]):
			_fk_prompt = String(rule["reason_tr"])
		else:
			_fk_prompt = "%s: %s para   R: döndür" % [String(def.get("name_tr", kind)), NumberFormat.format_int(float(base["cost"]))]
			if not String(base["note_tr"]).is_empty():
				_fk_prompt += "   (" + String(base["note_tr"]) + ")"
	_set_prompt(_fk_prompt)
	var rot: float = equipment.get("free_rotation")
	var key: String = "free|" + kind
	var node: Node3D = _preview_node(key, func() -> Node3D: return StructuresView.make_model(kind))
	if kind == "crack":
		node.transform = Transform3D(StructuresView._crack_basis(normal, rot), pos + normal * 0.02)
	else:
		node.position = pos
		node.rotation = Vector3(0.0, rot, 0.0)
	_activate_preview(key)
	_apply_ok(node, _fk_ok)
	_show_highlight_disc(pos, 1 if _fk_ok else 0, kind == "crack")
	if active and Input.is_action_just_pressed("interact"):
		if not _fk_ok:
			_play_denied()
		elif game.call("place_structure", kind, pos.x, pos.z, rot):
			_fk_version = -1
			if hammer_view != null:
				hammer_view.call("swing")


func _play_denied() -> void:
	if audio != null:
		audio.call("play_event", "build_denied")


func _shore() -> float:
	var total: float = (game.get("state") as Object).get("total_drops")
	var lake_r: float = 0.0
	if lake != null:
		lake_r = float(lake.call("shore_radius"))
	return BuildRules.effective_shore(lake_r, BasinShape.radius(total))


# ---------- Sökme ----------

func _try_remove() -> void:
	var piece: Dictionary = _piece_at(looked_cell)
	if not piece.is_empty():
		var refund: int = int(game.call("remove_canal", looked_cell.x, looked_cell.y))
		_after_remove(refund)
		return
	if not _has_hit:
		return
	var items: Array = game.call("structures")
	var best: int = -1
	var best_d: float = Config.PLACE_REMOVE_RADIUS
	for i in range(items.size()):
		var s: Dictionary = items[i]
		if not bool(s["placed"]):
			continue
		var d: float = Vector2(float(s["x"]) - _hit_pos.x, float(s["z"]) - _hit_pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		_after_remove(int(game.call("remove_structure", best)))


func _after_remove(refund: int) -> void:
	if hammer_view != null:
		hammer_view.call("swing")
	if refund > 0 and hud != null:
		hud.call("show_gain", "+%s para" % NumberFormat.format_money(float(refund)))
	_ck_version = -1
	_fk_version = -1


# ---------- Önizleme düğümleri ----------

func _preview_node(key: String, factory: Callable) -> Node3D:
	if _previews.has(key):
		return _previews[key]
	var node: Node3D = factory.call()
	CanalView.apply_ghost(node, _ghost_ok)
	node.set_meta("ok", 1)
	node.visible = false
	_root.add_child(node)
	_previews[key] = node
	return node


func _activate_preview(key: String) -> void:
	if key == _preview_key:
		return
	_preview_key = key
	for k: String in _previews:
		(_previews[k] as Node3D).visible = (k == key)


func _apply_ok(node: Node3D, ok: bool) -> void:
	var state: int = 1 if ok else 0
	if int(node.get_meta("ok", -1)) == state:
		return
	node.set_meta("ok", state)
	CanalView.apply_ghost(node, _ghost_ok if ok else _ghost_bad)


func _show_highlight_cell(pos: Vector3, state: int) -> void:
	_hl_cell.visible = true
	_hl_disc.visible = false
	_hl_cell.position = pos + Vector3(0.0, HIGHLIGHT_LIFT, 0.0)
	if _hl_cell.material_override != _hl_mats[state]:
		_hl_cell.material_override = _hl_mats[state]


func _show_highlight_disc(pos: Vector3, state: int, hide_it: bool) -> void:
	_hl_cell.visible = false
	_hl_disc.visible = not hide_it
	_hl_disc.position = pos + Vector3(0.0, 0.02, 0.0)
	if _hl_disc.material_override != _hl_mats[state]:
		_hl_disc.material_override = _hl_mats[state]


func _hide_preview() -> void:
	if _preview_key.is_empty() and not _hl_cell.visible and not _hl_disc.visible:
		return
	_activate_preview("")
	_hl_cell.visible = false
	_hl_disc.visible = false
