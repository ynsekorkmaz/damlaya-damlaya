extends Node3D
## Kanal alanının çevresi: zeminde soluk ızgara (çekiç eldeyken ve oyuncu yakınken), batı kenarında A/B/C pınar çeşmeleri
## (kapalıyken kuru ve soluk, açıkken su akar; etiket ve akış değeri), doğu kenarından göle giden dere şeritleri.
## Dış bağlantı: bind(game, lake, equipment, player).

const Config = preload("res://scripts/core/config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const BuildRules = preload("res://scripts/core/build_rules.gd")
const StreamPath = preload("res://scripts/core/stream_path.gd")
const NumberFormat = preload("res://scripts/core/number_format.gd")
const WaterFx = preload("res://scripts/world/water_fx.gd")
const StructuresView = preload("res://scripts/world/structures_view.gd")

const CHECK_INTERVAL: float = 0.5
const SHORE_DELTA: float = 0.1
const LABEL_HEIGHT: float = 2.1
const LABEL_PIXEL: float = 0.007
const LABEL_FONT: int = 64
const LABEL_OPEN := Color(0.97, 0.97, 0.94)
const LABEL_CLOSED := Color(0.78, 0.80, 0.80, 0.8)
const PALE := Color(0.88, 0.90, 0.92, 0.45)
const JET_HEIGHT: float = 0.8
const SPRING_DROPS: int = 18
const SPRING_FLOW_WIDTH: float = 0.6

var game: Node
var lake: Node
var equipment: Node
var player: Node3D

var _grid: MeshInstance3D
var _grid_on: bool = false
var _springs: Dictionary = {}    ## pınar id -> {root, label, jet, spray, flow, pale_nodes}
var _streams: Dictionary = {}    ## satır -> MeshInstance3D
var _stream_rows: Array[int] = []
var _timer: float = 0.0
var _built_shore: float = -1.0
var _grid_timer: float = 0.0


func _ready() -> void:
	name = "CanalFieldView"
	_grid = _build_grid()
	_grid.visible = false
	add_child(_grid)


func bind(game_node: Node, lake_node: Node, equipment_node: Node, player_node: Node3D) -> void:
	game = game_node
	lake = lake_node
	equipment = equipment_node
	player = player_node
	_build_springs()
	game.connect("structures_changed", refresh)
	game.connect("purchased", _on_purchased)
	refresh()


func _on_purchased(_kind: String, _id: String) -> void:
	refresh()


# ---------- Izgara ----------

func _build_grid() -> MeshInstance3D:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var w: float = Config.CANAL_GRID_LINE_WIDTH * 0.5
	var y: float = Config.CANAL_FIELD_HEIGHT + Config.CANAL_GRID_LIFT
	var cell: float = Config.CANAL_CELL_SIZE
	for i in range(Config.CANAL_FIELD_COLS + 1):
		var x: float = CanalField.west() + float(i) * cell
		_quad(verts, idx, Vector3(x - w, y, CanalField.north() - w), Vector3(x + w, y, CanalField.south() + w))
	for j in range(Config.CANAL_FIELD_ROWS + 1):
		var z: float = CanalField.north() + float(j) * cell
		_quad(verts, idx, Vector3(CanalField.west() - w, y, z - w), Vector3(CanalField.east() + w, y, z + w))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Config.CANAL_GRID_COLOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Grid"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _quad(verts: PackedVector3Array, idx: PackedInt32Array, a: Vector3, b: Vector3) -> void:
	var k: int = verts.size()
	verts.append(Vector3(a.x, a.y, a.z))
	verts.append(Vector3(b.x, a.y, a.z))
	verts.append(Vector3(b.x, a.y, b.z))
	verts.append(Vector3(a.x, a.y, b.z))
	idx.append_array([k, k + 1, k + 2, k, k + 2, k + 3])


# ---------- Pınarlar ----------

func _build_springs() -> void:
	var net: Object = game.get("canal")
	var ids: Array = net.call("spring_ids")
	ids.sort()
	for id: Variant in ids:
		var sid: String = String(id)
		var def: Dictionary = (net.get("spring_defs") as Dictionary)[sid]
		var p: Vector2 = CanalField.spring_point(int(def["row"]))
		var root := Node3D.new()
		root.name = "Spring_" + sid
		root.position = Vector3(p.x, TerrainShape.height(p.x, p.y), p.y)
		root.rotation.y = PI * 0.5   # çeşme, alana (doğuya) bakar
		add_child(root)
		var model: Node3D = StructuresView.make_model("spring")
		root.add_child(model)
		var jet_mesh := CylinderMesh.new()
		jet_mesh.top_radius = 0.025
		jet_mesh.bottom_radius = 0.07
		jet_mesh.height = JET_HEIGHT
		jet_mesh.radial_segments = 8
		jet_mesh.rings = 1
		var jet := WaterFx.make_instance(jet_mesh, WaterFx.water_material(-1))
		jet.position = Vector3(0.0, 0.6 + JET_HEIGHT * 0.5, 0.0)
		root.add_child(jet)
		var spray := WaterFx.make_instance(WaterFx.drops_mesh(SPRING_DROPS, 0.06, 300 + int(def["row"])), WaterFx.drop_material(1, JET_HEIGHT, 0.7))
		spray.position = Vector3(0.0, 0.6, 0.0)
		root.add_child(spray)
		# Çeşmeden alanın batı kenarına akan su (açıkken)
		var flow_pts := PackedVector3Array()
		var steps: int = 4
		var x0: float = p.x
		var x1: float = CanalField.west() + 0.2
		for i in range(steps + 1):
			var x: float = lerpf(x0, x1, float(i) / float(steps))
			flow_pts.append(Vector3(x, Config.CANAL_FIELD_HEIGHT + 0.12, p.y))
		var flow := WaterFx.make_instance(WaterFx.ribbon_mesh(flow_pts, SPRING_FLOW_WIDTH), WaterFx.water_material(1, true))
		flow.top_level = true
		root.add_child(flow)
		flow.global_transform = Transform3D.IDENTITY
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = LABEL_PIXEL
		label.font_size = LABEL_FONT
		label.outline_size = 14
		label.outline_modulate = Color(0.05, 0.08, 0.12, 0.9)
		label.double_sided = true
		label.no_depth_test = false
		label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
		root.add_child(label)
		_springs[sid] = {"root": root, "label": label, "jet": jet, "spray": spray, "flow": flow, "model": model,
			"open": null, "def": def}


# ---------- Güncelleme ----------

func refresh() -> void:
	if game == null:
		return
	var net: Object = game.get("canal")
	for sid: String in _springs:
		var e: Dictionary = _springs[sid]
		var open: bool = bool(net.call("is_spring_open", sid))
		if e["open"] == open:
			continue
		e["open"] = open
		(e["jet"] as Node3D).visible = open
		(e["spray"] as Node3D).visible = open
		(e["flow"] as Node3D).visible = open
		var label: Label3D = e["label"]
		var flow_text: String = NumberFormat.format_int(float((e["def"] as Dictionary)["flow"])) + "/sn"
		if open:
			label.text = "%s   %s" % [sid, flow_text]
			label.modulate = LABEL_OPEN
		else:
			label.text = "%s   kapalı (%s)" % [sid, flow_text]
			label.modulate = LABEL_CLOSED
		_set_pale(e["model"] as Node3D, not open)
	_refresh_streams()


static func _set_pale(root: Node3D, pale: bool) -> void:
	var overlay: Material = null
	if pale:
		overlay = StandardMaterial3D.new()
		(overlay as StandardMaterial3D).albedo_color = PALE
		(overlay as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(overlay as StandardMaterial3D).roughness = 1.0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = overlay


func _shore() -> float:
	var total: float = (game.get("state") as Object).get("total_drops")
	var lake_r: float = 0.0
	if lake != null:
		lake_r = float(lake.call("shore_radius"))
	return BuildRules.effective_shore(lake_r, BasinShape.radius(total))


## Göle çıkışı olan akan satırlar için dere şeridi; yalnızca akış ya da kıyı değişince yeniden kurulur.
func _refresh_streams() -> void:
	var result: Dictionary = game.call("canal_result")
	var net: Object = game.get("canal")
	var cols: int = net.get("cols")
	var rows: int = net.get("rows")
	var flowing: Dictionary = {}
	for cell: Variant in result["flowing"]:
		flowing[cell] = true
	var total: float = (game.get("state") as Object).get("total_drops")
	var basin_r: float = BasinShape.radius(total)
	var basin_d: float = BasinShape.depth(total)
	_built_shore = _shore()
	for row in range(rows):
		var active: bool = false
		if flowing.has(Vector2i(cols - 1, row)):
			var piece: Dictionary = net.call("get_piece", cols - 1, row)
			if not piece.is_empty():
				for group: Variant in Pieces.rotated_nodes(String(piece["piece"]), int(piece["rotation"])):
					if (group as Array).has(Pieces.E):
						active = true
		var existing: MeshInstance3D = _streams.get(row, null)
		if existing != null:
			existing.queue_free()
			_streams.erase(row)
		if not active:
			continue
		var pts: PackedVector3Array = StreamPath.points(CanalField.exit_point(row), _built_shore, basin_r, basin_d, Config.CANAL_STREAM_STEP)
		if pts.size() < 2:
			continue
		var mi := WaterFx.make_instance(WaterFx.ribbon_mesh(pts, Config.CANAL_STREAM_WIDTH), WaterFx.water_material(1, true))
		mi.name = "Stream_%d" % row
		add_child(mi)
		_streams[row] = mi


func _process(delta: float) -> void:
	if game == null:
		return
	_grid_timer += delta
	if _grid_timer >= 0.1:
		_grid_timer = 0.0
		var want: bool = false
		if equipment != null and player != null and bool(equipment.call("hammer_active")) \
				and bool((game.get("state") as Object).get("canal_unlocked")):
			want = CanalField.distance_to(player.global_position.x, player.global_position.z) < Config.CANAL_FIELD_NEAR
		if want != _grid_on:
			_grid_on = want
			_grid.visible = want
	_timer += delta
	if _timer >= CHECK_INTERVAL:
		_timer = 0.0
		if absf(_shore() - _built_shore) > SHORE_DELTA:
			_refresh_streams()
