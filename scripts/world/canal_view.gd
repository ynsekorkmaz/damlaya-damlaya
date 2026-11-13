extends Node3D
## Kanal parçalarının çizimi: hücre başına model örneği (glb ya da yer tutucu), akan hücrede kayan su, dönen değirmen
## çarkı, açık/kapalı savak. Yalnızca game.structures_changed / purchased'ta güncellenir; karede yalnızca çark ve kapak hareketi.
## Dış bağlantı: bind(game).

const Config = preload("res://scripts/core/config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const Placeholders = preload("res://scripts/world/placeholder_models.gd")
const WaterFx = preload("res://scripts/world/water_fx.gd")

const MATERIAL_COLORS: Dictionary = {
	"earth": Color(0.50, 0.37, 0.24), "wood": Color(0.58, 0.40, 0.24), "stone": Color(0.64, 0.62, 0.58),
}

static var _scenes: Dictionary = {}        ## parça id -> PackedScene ya da null (glb yok)
static var _channel_mats: Dictionary = {}  ## "parça|malzeme" -> Material
static var _textures: Dictionary = {}

var game: Node

var _entries: Dictionary = {}   ## hücre indeksi -> {node, key, parts, flowing, sign0, sign1, gate_open}
var _animated: Array[Dictionary] = []
var _flowing_nodes: Dictionary = {}   ## hücre -> akan ağız yönleri (dünya yönü)


func _ready() -> void:
	name = "CanalView"


func bind(game_node: Node) -> void:
	game = game_node
	game.connect("structures_changed", refresh)
	game.connect("purchased", _on_purchased)
	refresh()


func _on_purchased(_kind: String, _id: String) -> void:
	refresh()


# ---------- Model üretimi (önizleme de kullanır) ----------

## Parça + malzeme için yeni örnek. meta "parts": {waters, wheel, gate, gate_y}. Su malzemesi yönü refresh'te atanır.
static func make_piece(piece_id: String, material: String) -> Node3D:
	var root: Node3D = null
	var from_file: bool = false
	var scene: PackedScene = _scene_for(piece_id)
	if scene != null:
		root = scene.instantiate() as Node3D
		from_file = root != null
	if root == null:
		root = Placeholders.canal_piece(piece_id)
	var parts: Dictionary = {"waters": [], "wheel": null, "gate": null, "gate_y": 0.0}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var nm: String = String(mi.name)
		if nm.begins_with("Water"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.material_override = WaterFx.water_material(1)
			(parts["waters"] as Array).append(mi)
		elif nm == "Channel":
			var mat: Material = _channel_material(piece_id, material, mi, from_file)
			if mat != null:
				mi.material_override = mat
		elif nm == "Wheel":
			parts["wheel"] = mi
		elif nm == "Gate":
			parts["gate"] = mi
			parts["gate_y"] = mi.position.y
	root.set_meta("parts", parts)
	return root


static func _scene_for(piece_id: String) -> PackedScene:
	if _scenes.has(piece_id):
		return _scenes[piece_id]
	var path: String = Config.CANAL_MODEL_DIR + piece_id + ".glb"
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	_scenes[piece_id] = scene
	return scene


## Channel malzemesi: ahşap glb'nin kendi dokusudur (null = olduğu gibi); toprak/taş dokusu ya da yer tutucu rengi.
static func _channel_material(piece_id: String, material: String, mi: MeshInstance3D, from_file: bool) -> Material:
	var key: String = "%s|%s|%s" % [piece_id, material, "f" if from_file else "p"]
	if _channel_mats.has(key):
		return _channel_mats[key]
	var mat: Material = null
	if from_file:
		if material != "wood" or not _has_embedded_wood(mi):
			var src: Material = mi.mesh.surface_get_material(0)
			var std: StandardMaterial3D = null
			if src is StandardMaterial3D:
				std = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				std = StandardMaterial3D.new()
			var tex: Texture2D = _texture(material)
			if tex != null:
				std.albedo_texture = tex
				std.albedo_color = Color.WHITE
			else:
				std.albedo_color = MATERIAL_COLORS.get(material, Color.WHITE)
			mat = std
	else:
		var std2 := StandardMaterial3D.new()
		std2.albedo_color = MATERIAL_COLORS.get(material, Color.WHITE)
		std2.roughness = 0.95
		std2.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat = std2
	_channel_mats[key] = mat
	return mat


static func _has_embedded_wood(mi: MeshInstance3D) -> bool:
	var src: Material = mi.mesh.surface_get_material(0)
	return src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture != null


static func _texture(material: String) -> Texture2D:
	if _textures.has(material):
		return _textures[material]
	var path: String = Config.CANAL_TEX_DIR + material + ".jpg"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_textures[material] = tex
	return tex


## Yarı saydam önizleme: tüm yüzeyler tek malzeme, su gizli.
static func apply_ghost(root: Node3D, ghost: Material) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = ghost
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if String(mi.name).begins_with("Water"):
			mi.visible = false


## Akış yönü (Vector2i, ızgara) -> yön indeksi N, E, S, W; bilinmezse -1.
static func dir_index(v: Vector2i) -> int:
	for i in range(Pieces.DIR_VEC.size()):
		if Pieces.DIR_VEC[i] == v:
			return i
	return -1


## V (UV'nin V ekseni) yüksek olan yerel ağızlar: glb sözleşmesi. Su, çıkış ağzı V'si yüksek ise +V yönünde akar.
static func high_ports(piece_id: String, water_index: int) -> Array:
	if piece_id == "aqueduct" and water_index == 1:
		return [Pieces.S]
	if piece_id == "cross" or piece_id == "reservoir":
		return [Pieces.W, Pieces.S]
	return [Pieces.W]


## Desen yönü: +1 (+V) ya da -1 (-V). exit_local: akışın çıkış ağzı (parça yerelinde, N=0..W=3); -1 bilinmiyor.
static func water_sign(piece_id: String, water_index: int, exit_local: int) -> int:
	if exit_local < 0:
		return 1 if (piece_id == "aqueduct" and water_index == 1) else -1
	return 1 if high_ports(piece_id, water_index).has(exit_local) else -1


# ---------- Güncelleme ----------

func refresh() -> void:
	if game == null:
		return
	var net: Object = game.get("canal")
	var result: Dictionary = game.call("canal_result")
	var flow_dir: Dictionary = result["flow_dir"]
	_flowing_nodes = result.get("flowing_nodes", {})
	var flowing: Dictionary = {}
	for cell: Variant in result["flowing"]:
		flowing[cell] = true
	var cols: int = net.get("cols")
	var rows: int = net.get("rows")
	for row in range(rows):
		for col in range(cols):
			_update_cell(net, col, row, col + row * cols, flowing, flow_dir)
	_animated.clear()
	for idx: Variant in _entries:
		var e: Dictionary = _entries[idx]
		var parts: Dictionary = e["parts"]
		if parts["wheel"] != null or parts["gate"] != null:
			_animated.append(e)


func _update_cell(net: Object, col: int, row: int, idx: int, flowing: Dictionary, flow_dir: Dictionary) -> void:
	var piece: Dictionary = net.call("get_piece", col, row)
	if piece.is_empty():
		if _entries.has(idx):
			(_entries[idx]["node"] as Node).queue_free()
			_entries.erase(idx)
		return
	var key: String = "%s|%d|%s" % [piece["piece"], int(piece["rotation"]), piece["material"]]
	var e: Dictionary = _entries.get(idx, {})
	if e.is_empty() or e["key"] != key:
		if not e.is_empty():
			(e["node"] as Node).queue_free()
		var node: Node3D = make_piece(String(piece["piece"]), String(piece["material"]))
		var c: Vector2 = CanalField.cell_center(col, row)
		node.position = Vector3(c.x, TerrainShape.height(c.x, c.y), c.y)
		node.rotation.y = CanalField.yaw_of_rotation(int(piece["rotation"]))
		add_child(node)
		e = {"node": node, "key": key, "parts": node.get_meta("parts"), "sign0": 99, "sign1": 99, "spin": false,
			"gate_open": bool(piece.get("open", true)), "gate_now": -1.0}
		_entries[idx] = e
	var cell := Vector2i(col, row)
	var is_flowing: bool = flowing.has(cell)
	var local_dir: int = -1
	if is_flowing and flow_dir.has(cell):
		var wd: int = dir_index(flow_dir[cell])
		if wd >= 0:
			local_dir = posmod(wd - int(piece["rotation"]), 4)
	var piece_id: String = String(piece["piece"])
	var waters: Array = (e["parts"] as Dictionary)["waters"]
	var mouths: Array = _flowing_nodes.get(cell, [])
	for i in range(waters.size()):
		var mi: MeshInstance3D = waters[i]
		var line_flowing: bool = is_flowing
		if piece_id == "aqueduct" and waters.size() == 2:
			# Su kemerinde her hat ayrı: hat 0 yerelde doğu-batı, hat 1 kuzey-güney; yalnızca akan hattın suyu görünür.
			var axis_a: int = Pieces.E if i == 0 else Pieces.N
			var wa: int = (axis_a + int(piece["rotation"])) % 4
			line_flowing = mouths.has(wa) or mouths.has((wa + 2) % 4)
		mi.visible = line_flowing
		if not line_flowing:
			continue
		var exit_local: int = local_dir
		if piece_id == "aqueduct":
			# Her hat kendi ekseninde akar: akış başka eksendeyse varsayılan yön.
			var along_ew: bool = local_dir == Pieces.E or local_dir == Pieces.W
			if (i == 0) != along_ew:
				exit_local = -1
		var s: int = water_sign(piece_id, i, exit_local)
		var key_sign: String = "sign%d" % mini(i, 1)
		if e[key_sign] != s:
			e[key_sign] = s
			mi.material_override = WaterFx.water_material(s)
	e["spin"] = is_flowing
	e["gate_open"] = bool(piece.get("open", true))


func _process(delta: float) -> void:
	for e: Dictionary in _animated:
		var parts: Dictionary = e["parts"]
		var wheel: Node3D = parts["wheel"]
		if wheel != null and bool(e["spin"]):
			wheel.rotation.z += Config.CANAL_WHEEL_SPEED * delta
		var gate: Node3D = parts["gate"]
		if gate != null:
			var target: float = float(parts["gate_y"]) + (Config.CANAL_GATE_LIFT if bool(e["gate_open"]) else 0.0)
			if float(e["gate_now"]) < 0.0:
				e["gate_now"] = target
			e["gate_now"] = move_toward(float(e["gate_now"]), target, Config.CANAL_GATE_SPEED * delta)
			gate.position.y = float(e["gate_now"])
