extends Node3D
## Kameraya bağlı basit kap (avuç/tas) ve içinde taşınan/kapasite oranına göre yükselen su.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const Economy = preload("res://scripts/core/economy.gd")

## Kap kesiti (yarıçap, yükseklik): dış yüz alttan ağza, ağız kenarı, iç yüz aşağı.
const PROFILE: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.065, 0.025), Vector2(0.082, 0.07),
	Vector2(0.09, 0.12), Vector2(0.083, 0.122), Vector2(0.074, 0.075), Vector2(0.058, 0.035),
	Vector2(0.0, 0.022),
]
const INNER_FIRST: int = 5  ## iç yüzün ilk profil noktası

var game: Node

var _water: MeshInstance3D
var _water_material: StandardMaterial3D
var _shown_ratio: float = 0.0


func _ready() -> void:
	name = "HeldVessel"
	position = Config.HELD_OFFSET
	rotation_degrees = Config.HELD_TILT_DEG
	scale = Vector3.ONE * Config.HELD_SCALE

	var cup := MeshInstance3D.new()
	cup.name = "Cup"
	cup.mesh = build_cup_mesh()
	add_child(cup)

	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(Palette.WATER, 0.9)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.roughness = 0.1
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = 0.002
	disk.radial_segments = Config.HELD_SEGMENTS
	disk.rings = 1
	_water = MeshInstance3D.new()
	_water.name = "HeldWater"
	_water.mesh = disk
	_water.material_override = _water_material
	_water.visible = false
	add_child(_water)


func _process(delta: float) -> void:
	if game == null:
		return
	var state: Object = game.get("state")
	var capacity: float = Economy.tool_capacity(state)
	var ratio: float = clampf(state.carried / capacity, 0.0, 1.0) if capacity > 0.0 else 0.0
	_shown_ratio = lerpf(_shown_ratio, ratio, 1.0 - exp(-Config.HELD_LERP_SPEED * delta))
	_water.visible = _shown_ratio > 0.005
	if not _water.visible:
		return
	var y: float = lerpf(Config.HELD_WATER_MIN, Config.HELD_WATER_MAX, _shown_ratio)
	_water.position = Vector3(0.0, y, 0.0)
	var r: float = inner_radius_at(y) * 0.97
	_water.scale = Vector3(r, 1.0, r)


## İç yüzdeki yarıçap (verilen yükseklikte), doğrusal ara değer.
static func inner_radius_at(y: float) -> float:
	for i in range(INNER_FIRST, PROFILE.size() - 1):
		var a: Vector2 = PROFILE[i]
		var b: Vector2 = PROFILE[i + 1]
		if y <= a.y and y >= b.y:
			var t: float = (y - b.y) / maxf(a.y - b.y, 0.0001)
			return lerpf(b.x, a.x, t)
	return PROFILE[INNER_FIRST].x


## Profili döndürerek kap: dış yüz ve iç yüz ayrı sarım, yumuşak gölgeli.
static func build_cup_mesh() -> ArrayMesh:
	var segs: int = Config.HELD_SEGMENTS
	var n: int = PROFILE.size()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for i in range(n):
		for j in range(segs):
			var ang: float = TAU * float(j) / float(segs)
			var p: Vector2 = PROFILE[i]
			verts.append(Vector3(cos(ang) * p.x, p.y, sin(ang) * p.x))
			var inner: bool = i >= INNER_FIRST
			colors.append(Palette.CLAY_DARK if inner else Palette.CLAY)
	var idx := PackedInt32Array()
	for i in range(n - 1):
		for j in range(segs):
			var j2: int = (j + 1) % segs
			var a: int = i * segs + j
			var b: int = i * segs + j2
			var c: int = (i + 1) * segs + j
			var d: int = (i + 1) * segs + j2
			idx.append_array([a, b, d, a, d, c])
	# Dış duvardaki bir üçgenin normali dışa bakmalı (Godot ön yüzü saat yönü); değilse tüm sarımı çevir.
	var probe: int = (segs * 2) * 6
	var probe_n: Vector3 = (verts[idx[probe + 2]] - verts[idx[probe]]).cross(verts[idx[probe + 1]] - verts[idx[probe]])
	var outward: Vector3 = verts[idx[probe]] * Vector3(1.0, 0.0, 1.0)
	if probe_n.dot(outward) < 0.0:
		for k in range(0, idx.size(), 3):
			var tmp: int = idx[k + 1]
			idx[k + 1] = idx[k + 2]
			idx[k + 2] = tmp
	var mesh_normals := PackedVector3Array()
	mesh_normals.resize(verts.size())
	for k in range(0, idx.size(), 3):
		var fn2: Vector3 = (verts[idx[k + 2]] - verts[idx[k]]).cross(verts[idx[k + 1]] - verts[idx[k]])
		for q in range(3):
			mesh_normals[idx[k + q]] += fn2
	for k in range(mesh_normals.size()):
		mesh_normals[k] = mesh_normals[k].normalized() if mesh_normals[k].length() > 0.0 else Vector3.UP

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = mesh_normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh
