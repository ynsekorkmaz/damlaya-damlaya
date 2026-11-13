extends Node3D
## Serbest yapıların çizimi: kamış, gölge ağacı ve çiğ otu tür başına MultiMesh; çatlak, bulut direği, çeşme ve dere ağzı ayrı düğüm.
## game.structures() ve structures_changed'e göre; çanak/kıyı belirgin değişince (en sık 0,5 sn'de bir) yükseklikler ve dere şeritleri yenilenir.
## Konumsuz (placed=false) yapılara açılışta yer verir. Pasif kaynaklar görünür: çatlak sızıntısı, bulut + yağmur, çeşme fışkırması, dere ağzı şeridi.
## Dış bağlantı: bind(game, lake).

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const BuildRules = preload("res://scripts/core/build_rules.gd")
const StreamPath = preload("res://scripts/core/stream_path.gd")
const Placeholders = preload("res://scripts/world/placeholder_models.gd")
const WaterFx = preload("res://scripts/world/water_fx.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")
const RockSurface = preload("res://scripts/world/rock_surface.gd")

const MULTI_KINDS: Array[String] = ["reeds", "shade_tree", "dew"]
const MODEL_FILES: Dictionary = {
	"reeds": "reeds.glb", "shade_tree": "tree_shade.glb", "dew": "grass_dew.glb", "spring": "fountain.glb",
	"crack": "crack.glb", "rain_cloud": "cloud_pole.glb", "stream_mouth": "stream_mouth.glb",
}
const CHECK_INTERVAL: float = 0.5
const BASIN_DELTA: float = 0.05
const SHORE_DELTA: float = 0.12
const SCALE_MIN: float = 0.85
const SCALE_MAX: float = 1.2
const REED_SINK: float = 0.04
const CRACK_LIFT: float = 0.012
const CRACK_SEEP_LENGTH: float = 0.45
const CRACK_SEEP_WIDTH: float = 0.07
const RAY_UP: float = 4.0
const RAY_DOWN: float = 3.0
const CLOUD_HEIGHT: float = 3.05      ## bulutun yerden yüksekliği (direk tepesi ~2,5 m)
const RAIN_DROPS: int = 12
const RAIN_RADIUS: float = 0.55
const FOUNTAIN_SPLASH_HEIGHT: float = 0.22   ## havuza düşen suyun sıçrama yüksekliği
const FOUNTAIN_DROPS: int = 14
const FOUNTAIN_DEFAULT_SPOUT := Vector3(0.0, 0.72, 0.21)   ## glb'de "Spout" yoksa
const FOUNTAIN_DEFAULT_BASIN := Vector3(0.0, 0.27, 0.27)   ## glb'de "Basin" yoksa
const FOUNTAIN_BASIN_HALF_Z: float = 0.28
const FOUNTAIN_BASIN_WIDTH: float = 0.72
const CLOUD_SWAY: float = 0.12
const CLOUD_SWAY_SPEED: float = 0.6

static var _scenes: Dictionary = {}

var game: Node
var lake: Node

var _multi: Dictionary = {}       ## tür -> Array[{node: MultiMeshInstance3D, xf: Transform3D}]
var _node_root: Node3D
var _clouds: Array[Dictionary] = []
var _timer: float = 0.0
var _built_basin: float = -1.0
var _built_shore: float = -1.0
var _busy: bool = false
var _clock: float = 0.0


func _ready() -> void:
	name = "StructuresView"
	_node_root = Node3D.new()
	_node_root.name = "Nodes"
	add_child(_node_root)


func bind(game_node: Node, lake_node: Node) -> void:
	game = game_node
	lake = lake_node
	game.connect("structures_changed", _on_changed)
	refresh()
	# Çatlaklar kaya çarpışmasına yaslanır: fizik hazır olunca bir kez daha kurulur.
	await get_tree().physics_frame
	await get_tree().physics_frame
	refresh()


func _on_changed() -> void:
	if not _busy:
		refresh()


# ---------- Model ----------

## Tür için yeni model düğümü (glb varsa o, yoksa yer tutucu).
static func make_model(kind: String) -> Node3D:
	if MODEL_FILES.has(kind):
		var path: String = Config.BUILD_MODEL_DIR + String(MODEL_FILES[kind])
		if not _scenes.has(path):
			_scenes[path] = load(path) if ResourceLoader.exists(path) else null
		var scene: PackedScene = _scenes[path]
		if scene != null:
			var inst: Node3D = scene.instantiate() as Node3D
			if inst != null:
				if kind == "rain_cloud" and inst.get_node_or_null("Cloud") == null:
					inst.add_child(Placeholders.cloud())   # bulut kodda kalır; direk modelin parçası
				return inst
	match kind:
		"reeds":
			return Placeholders.reeds()
		"shade_tree":
			return Placeholders.tree()
		"dew":
			return Placeholders.dew()
		"spring":
			return Placeholders.fountain()
		"crack":
			return Placeholders.crack()
		"rain_cloud":
			return Placeholders.cloud_pole()
		"stream_mouth":
			return Placeholders.stream_mouth()
	return Node3D.new()


## Her MeshInstance3D için kökten göreli dönüşüm (MultiMesh parçaları).
static func _mesh_parts(root: Node3D) -> Array:
	var out: Array = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		out.append({"mesh": mi.mesh, "xf": xf})
	return out


func _ensure_multi(kind: String) -> Array:
	if _multi.has(kind):
		return _multi[kind]
	var template: Node3D = make_model(kind)
	var list: Array = []
	for part: Dictionary in _mesh_parts(template):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part["mesh"]
		mm.instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d" % [kind, list.size()]
		mmi.multimesh = mm
		add_child(mmi)
		list.append({"node": mmi, "xf": part["xf"]})
	template.free()
	_multi[kind] = list
	return list


static func variation(index: int) -> float:
	var f: float = fposmod(sin(float(index) * 12.9898 + 4.1) * 43758.5453, 1.0)
	return lerpf(SCALE_MIN, SCALE_MAX, f)


# ---------- Güncelleme ----------

func refresh() -> void:
	if game == null:
		return
	_auto_place_pending()
	var total: float = (game.get("state") as Object).get("total_drops")
	var basin_r: float = BasinShape.radius(total)
	var basin_d: float = BasinShape.depth(total)
	_built_basin = basin_r
	_built_shore = _shore()
	var items: Array = game.call("structures")
	for kind: String in MULTI_KINDS:
		_update_multi(kind, items, basin_r, basin_d)
	for child: Node in _node_root.get_children():
		child.queue_free()
	_clouds.clear()
	for i in range(items.size()):
		var s: Dictionary = items[i]
		if not bool(s["placed"]):
			continue
		var kind: String = s["kind"]
		if MULTI_KINDS.has(kind):
			continue
		_add_node_kind(kind, i, s, basin_r, basin_d)


func _shore() -> float:
	var total: float = (game.get("state") as Object).get("total_drops")
	var lake_r: float = 0.0
	if lake != null:
		lake_r = float(lake.call("shore_radius"))
	return BuildRules.effective_shore(lake_r, BasinShape.radius(total))


func _update_multi(kind: String, items: Array, basin_r: float, basin_d: float) -> void:
	var list: Array = _ensure_multi(kind)
	var placed: Array[Dictionary] = []
	for s: Dictionary in items:
		if s["kind"] == kind and bool(s["placed"]):
			placed.append(s)
	for part: Dictionary in list:
		var mm: MultiMesh = (part["node"] as MultiMeshInstance3D).multimesh
		mm.instance_count = placed.size()
		for i in range(placed.size()):
			var s: Dictionary = placed[i]
			var x: float = s["x"]
			var z: float = s["z"]
			var y: float = TerrainShape.height(x, z, basin_r, basin_d)
			if kind == "reeds":
				y -= REED_SINK
			var sc: float = variation(i)
			var basis := Basis(Vector3.UP, float(s["rot"])).scaled(Vector3(sc, sc, sc))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)) * (part["xf"] as Transform3D))


func _add_node_kind(kind: String, index: int, s: Dictionary, basin_r: float, basin_d: float) -> void:
	var x: float = s["x"]
	var z: float = s["z"]
	var model: Node3D = make_model(kind)
	_node_root.add_child(model)
	var ground: float = TerrainShape.height(x, z, basin_r, basin_d)
	match kind:
		"crack":
			var hit: Dictionary = _surface_at(x, z, ground)
			var n: Vector3 = hit["normal"]
			var pos: Vector3 = hit["position"] + n * CRACK_LIFT
			model.transform = Transform3D(_crack_basis(n, float(s["rot"])), pos)
			_add_seep(pos, n, float(s["rot"]))
		"rain_cloud":
			model.position = Vector3(x, ground, z)
			model.rotation.y = float(s["rot"])
			var cloud: Node3D = model.get_node_or_null("Cloud") as Node3D
			if cloud != null:
				cloud.position.y = CLOUD_HEIGHT
				_clouds.append({"node": cloud, "base": cloud.position, "phase": float(index) * 1.9})
			var rain := WaterFx.make_instance(WaterFx.drops_mesh(RAIN_DROPS, RAIN_RADIUS, 100 + index),
				WaterFx.drop_material(0, CLOUD_HEIGHT - 0.1, 0.0))
			rain.position = Vector3(0.0, CLOUD_HEIGHT - 0.1, 0.0)
			model.add_child(rain)
		"spring":
			model.position = Vector3(x, ground, z)
			model.rotation.y = float(s["rot"])
			add_fountain_water(model, 200 + index)
		"stream_mouth":
			model.position = Vector3(x, ground, z)
			model.rotation.y = float(s["rot"])
			var pts: PackedVector3Array = StreamPath.points(Vector2(x, z), _built_shore, basin_r, basin_d, Config.CANAL_STREAM_STEP)
			if pts.size() >= 2:
				var ribbon := WaterFx.make_instance(WaterFx.ribbon_mesh(pts, Config.CANAL_STREAM_WIDTH), WaterFx.water_material(1, true))
				ribbon.top_level = true
				model.add_child(ribbon)
				ribbon.global_transform = Transform3D.IDENTITY
		_:
			model.position = Vector3(x, ground, z)
			model.rotation.y = float(s["rot"])


## Çeşme suyu: modeldeki "Spout"tan "Basin" yüzeyine düşen ince su, havuz yüzeyi ve sıçrama damlaları.
## Döner: {jet: Node3D (düşen su + havuz yüzeyi), spray: MeshInstance3D}; ikisi de modele eklenir (kaynak kapanınca gizlenir).
static func add_fountain_water(model: Node3D, seed_value: int) -> Dictionary:
	var spout_node: Node3D = model.find_child("Spout", true, false) as Node3D
	var basin_node: Node3D = model.find_child("Basin", true, false) as Node3D
	var sp: Vector3 = spout_node.position if spout_node != null else FOUNTAIN_DEFAULT_SPOUT
	var bp: Vector3 = basin_node.position if basin_node != null else FOUNTAIN_DEFAULT_BASIN
	var jet := Node3D.new()
	jet.name = "Jet"
	var fall_mesh := CylinderMesh.new()
	fall_mesh.top_radius = 0.028
	fall_mesh.bottom_radius = 0.04
	fall_mesh.height = maxf(sp.y - bp.y, 0.05)
	fall_mesh.radial_segments = 8
	fall_mesh.rings = 1
	var fall := WaterFx.make_instance(fall_mesh, WaterFx.water_material(-1))
	fall.position = Vector3(sp.x, (sp.y + bp.y) * 0.5, sp.z)
	jet.add_child(fall)
	var pool_pts := PackedVector3Array([
		Vector3(bp.x, bp.y, bp.z - FOUNTAIN_BASIN_HALF_Z), Vector3(bp.x, bp.y, bp.z), Vector3(bp.x, bp.y, bp.z + FOUNTAIN_BASIN_HALF_Z)])
	jet.add_child(WaterFx.make_instance(WaterFx.ribbon_mesh(pool_pts, FOUNTAIN_BASIN_WIDTH), WaterFx.water_material(1, true)))
	model.add_child(jet)
	var spray := WaterFx.make_instance(WaterFx.drops_mesh(FOUNTAIN_DROPS, 0.05, seed_value),
		WaterFx.drop_material(1, FOUNTAIN_SPLASH_HEIGHT, 0.22))
	spray.position = Vector3(sp.x, bp.y, sp.z)
	model.add_child(spray)
	return {"jet": jet, "spray": spray}


## Çatlak yüzeyi: büyük kayalarda görünür yüzey (RockSurface), kaynak kayasında fizik ışını; yoksa zemin.
func _surface_at(x: float, z: float, ground: float) -> Dictionary:
	var fallback: Dictionary = {"position": Vector3(x, ground, z), "normal": Vector3.UP}
	var big: Dictionary = RockSurface.project_down(x, z)
	if not big.is_empty():
		return big
	if not is_inside_tree():
		return fallback
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, ground + RAY_UP, z), Vector3(x, ground - RAY_DOWN, z))
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return fallback
	var collider: Object = hit["collider"]
	if collider is Node and (collider as Node).is_in_group("rock"):
		return {"position": hit["position"], "normal": hit["normal"]}
	return fallback


static func _crack_basis(normal: Vector3, rot: float) -> Basis:
	var up: Vector3 = normal.normalized()
	var tangent: Vector3 = up.cross(Vector3.UP)
	if tangent.length() < 0.05:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized().rotated(up, rot)
	var z: Vector3 = tangent.cross(up)
	return Basis(tangent, up, z)


## Çatlaktan aşağı ince su sızıntısı.
func _add_seep(pos: Vector3, normal: Vector3, rot: float) -> void:
	var down: Vector3 = Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
	if down.length() < 0.15:
		down = Vector3(cos(rot), 0.0, sin(rot)) * 0.3 + Vector3(0.0, -0.05, 0.0)
	down = down.normalized()
	var pts := PackedVector3Array([pos, pos + down * CRACK_SEEP_LENGTH * 0.5 + normal * 0.01, pos + down * CRACK_SEEP_LENGTH + normal * 0.01])
	var seep := WaterFx.make_instance(WaterFx.ribbon_mesh(pts, CRACK_SEEP_WIDTH), WaterFx.water_material(1, true))
	seep.top_level = true
	_node_root.add_child(seep)
	seep.global_transform = Transform3D.IDENTITY


# ---------- Konumsuz yapılara yer ver ----------

func _auto_place_pending() -> void:
	var items: Array = game.call("structures")
	var any: bool = false
	for s: Dictionary in items:
		if not bool(s["placed"]):
			any = true
			break
	if not any:
		return
	_busy = true
	var ctx: Dictionary = {
		"shore": _shore(), "max_radius": BasinShape.max_radius(), "structures": items, "rock_spots": _rock_spots(),
	}
	for i in range(items.size()):
		var s: Dictionary = items[i]
		if bool(s["placed"]):
			continue
		var kind: String = s["kind"]
		var index: int = 0
		for other: Dictionary in items:
			if other["kind"] == kind and bool(other["placed"]):
				index += 1
		var res: Dictionary = BuildRules.auto_place(kind, index, ctx)
		if bool(res["found"]):
			game.call("set_structure_position", i, float(res["x"]), float(res["z"]), float(res["rot"]))
			items = game.call("structures")
			ctx["structures"] = items
	_busy = false


## Çatlak adayları: büyük kayaların merkezi ve kaynak kayası.
static func _rock_spots() -> Array:
	var spots: Array = []
	spots.append(Vector2(Config.SPRING_POSITION.x, Config.SPRING_POSITION.z))
	for r: Dictionary in RocksBuilder.make_rocks():
		if float(r["size"]) >= Config.ROCK_COLLIDE_MIN_SIZE:
			var o: Vector3 = (r["transform"] as Transform3D).origin
			spots.append(Vector2(o.x, o.z))
	return spots


# ---------- Karede ----------

func _process(delta: float) -> void:
	if game == null:
		return
	_clock += delta
	for c: Dictionary in _clouds:
		var node: Node3D = c["node"]
		if not is_instance_valid(node):
			continue
		var base: Vector3 = c["base"]
		var t: float = _clock * CLOUD_SWAY_SPEED + float(c["phase"])
		node.position = base + Vector3(sin(t) * CLOUD_SWAY, sin(t * 1.7) * 0.03, cos(t * 0.8) * CLOUD_SWAY * 0.6)
	_timer += delta
	if _timer < CHECK_INTERVAL:
		return
	_timer = 0.0
	var total: float = (game.get("state") as Object).get("total_drops")
	var basin_r: float = BasinShape.radius(total)
	if absf(basin_r - _built_basin) > BASIN_DELTA or absf(_shore() - _built_shore) > SHORE_DELTA:
		refresh()
