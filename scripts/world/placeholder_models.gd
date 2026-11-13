extends RefCounted
## Model dosyası yoksa kullanılan, koddan üretilmiş sade yer tutucular (metre, +Y yukarı; ızgara Doğu = +X, Güney = +Z).
## Kanal parçaları glb ile aynı sözleşmeyi izler: "Channel", "Water" (V: Doğu/Kuzey uçta 0, Batı/Güney yönünde artar),
## değirmende "Wheel", savakta "Gate". Tek tek MeshInstance3D döner; renkler vertex rengidir.

const Config = preload("res://scripts/core/config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")

const HALF: float = 1.0                  # hücre yarı boyu
const WALL_OUT: float = 0.45             # oluk dış yarı genişliği
const WALL_IN: float = 0.30              # su yarı genişliği
const WALL_H: float = 0.28
const WATER_Y: float = 0.2
const COL_CHANNEL := Color(0.62, 0.46, 0.30)
const COL_WOOD := Color(0.55, 0.36, 0.20)
const COL_STONE := Color(0.62, 0.60, 0.56)
const COL_LEAF := Color(0.30, 0.50, 0.22)
const COL_LEAF_DARK := Color(0.22, 0.40, 0.18)
const COL_BARK := Color(0.40, 0.28, 0.18)
const COL_REED := Color(0.52, 0.62, 0.30)
const COL_REED_TIP := Color(0.45, 0.30, 0.18)
const COL_CRACK := Color(0.10, 0.08, 0.07)
const COL_CLOUD := Color(0.96, 0.97, 1.0)
const COL_METAL := Color(0.62, 0.64, 0.66)


static func _vertex_mat(roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Parçalardan (mesh + dönüşüm + renk) tek mesh.
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part: Dictionary in parts:
		_add_part(st, part["mesh"], part["xf"], part["color"])
	st.set_material(_vertex_mat())
	return st.commit()


static func _add_part(st: SurfaceTool, mesh: Mesh, xf: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var basis_n: Basis = xf.basis.inverse().transposed()
	var count: int = index.size() if not index.is_empty() else verts.size()
	for i in range(count):
		var k: int = index[i] if not index.is_empty() else i
		st.set_color(color)
		st.set_normal((basis_n * normals[k]).normalized())
		st.add_vertex(xf * verts[k])


static func _box(size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> Dictionary:
	var m := BoxMesh.new()
	m.size = size
	return {"mesh": m, "xf": Transform3D(Basis.from_euler(rot), pos), "color": color}


static func _sphere(radius: float, pos: Vector3, color: Color, squash: float = 1.0) -> Dictionary:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 10
	m.rings = 6
	return {"mesh": m, "xf": Transform3D(Basis().scaled(Vector3(1.0, squash, 1.0)), pos), "color": color}


static func _cylinder(top: float, bottom: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, seg: int = 8) -> Dictionary:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = seg
	m.rings = 1
	return {"mesh": m, "xf": Transform3D(Basis.from_euler(rot), pos), "color": color}


static func _mesh_node(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	return mi


# ---------- Kanal parçaları ----------

## Parça id'sine göre yer tutucu: Channel + Water (+ Water_001, Wheel, Gate).
static func canal_piece(piece_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = piece_id
	var def: Dictionary = Pieces.get_piece_def(piece_id)
	var groups: Array = def.get("nodes", [[Pieces.E, Pieces.W]])
	var parts: Array = []
	for g: Variant in groups:
		var ports: Array = g
		for dir: Variant in ports:
			parts.append_array(_arm(int(dir)))
	if piece_id == "aqueduct":
		parts.append(_box(Vector3(2.0, 0.4, 0.6), Vector3(0.0, 0.1, 0.0), COL_STONE))
	var channel: MeshInstance3D = _mesh_node("Channel", merge(parts))
	root.add_child(channel)
	for gi in range(groups.size()):
		var ports: Array = groups[gi]
		var water_name: String = "Water" if gi == 0 else "Water_%03d" % gi
		root.add_child(_mesh_node(water_name, _water_mesh(ports)))
	if piece_id == "gate":
		var gate: MeshInstance3D = _mesh_node("Gate", merge([_box(Vector3(0.08, 0.45, 0.62), Vector3(0.0, 0.22, 0.0), COL_WOOD)]))
		gate.position = Vector3(0.0, 0.05, 0.0)
		root.add_child(gate)
		root.add_child(_mesh_node("GateFrame", merge([
			_box(Vector3(0.12, 0.9, 0.08), Vector3(0.0, 0.5, -0.45), COL_WOOD),
			_box(Vector3(0.12, 0.9, 0.08), Vector3(0.0, 0.5, 0.45), COL_WOOD),
			_box(Vector3(0.12, 0.08, 1.0), Vector3(0.0, 0.96, 0.0), COL_WOOD)])))
	elif piece_id == "mill":
		root.add_child(_mesh_node("MillBody", merge([_box(Vector3(2.2, 2.4, 0.9), Vector3(0.0, 1.2, -1.0), COL_WOOD)])))
		var wheel: MeshInstance3D = _mesh_node("Wheel", merge([
			_cylinder(0.5, 0.5, 0.15, Vector3.ZERO, COL_WOOD, Vector3(PI * 0.5, 0.0, 0.0), 12),
			_box(Vector3(1.0, 0.08, 0.1), Vector3.ZERO, COL_STONE),
			_box(Vector3(0.08, 1.0, 0.1), Vector3.ZERO, COL_STONE)]))
		wheel.position = Vector3(0.0, 0.64, 0.0)
		root.add_child(wheel)
	elif piece_id == "reservoir":
		root.get_node("Channel").queue_free()
		root.add_child(_mesh_node("Channel", merge([
			_box(Vector3(2.0, 0.2, 0.15), Vector3(0.0, 0.1, -0.925), COL_STONE),
			_box(Vector3(2.0, 0.2, 0.15), Vector3(0.0, 0.1, 0.925), COL_STONE),
			_box(Vector3(0.15, 0.2, 1.7), Vector3(-0.925, 0.1, 0.0), COL_STONE),
			_box(Vector3(0.15, 0.2, 1.7), Vector3(0.925, 0.1, 0.0), COL_STONE),
			_box(Vector3(1.9, 0.08, 1.9), Vector3(0.0, 0.0, 0.0), COL_CHANNEL)])))
	for node: Node in root.get_children():
		if node is MeshInstance3D:
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not String(node.name).begins_with("Water") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Bir ağıza giden kol: taban ve iki yan duvar, merkezden hücre kenarına.
static func _arm(dir: int) -> Array:
	var along: Vector3 = CanalField.port_vector(dir)
	var side := Vector3(-along.z, 0.0, along.x)
	var floor_len: float = HALF + WALL_OUT
	var floor_mid: Vector3 = along * ((HALF - WALL_OUT) * 0.5)
	var out: Array = []
	var fx: float = absf(along.x) * floor_len + absf(side.x) * (WALL_OUT * 2.0)
	var fz: float = absf(along.z) * floor_len + absf(side.z) * (WALL_OUT * 2.0)
	out.append(_box(Vector3(fx, 0.1, fz), floor_mid + Vector3(0.0, 0.02, 0.0), COL_CHANNEL))
	var wall_len: float = HALF - WALL_OUT
	var wall_mid: Vector3 = along * ((HALF + WALL_OUT) * 0.5)
	for sgn in [-1.0, 1.0]:
		var wall_pos: Vector3 = wall_mid + side * sgn * (WALL_OUT - 0.07)
		var wx: float = absf(along.x) * wall_len + absf(side.x) * 0.14
		var wz: float = absf(along.z) * wall_len + absf(side.z) * 0.14
		out.append(_box(Vector3(wx, WALL_H, wz), wall_pos + Vector3(0.0, WALL_H * 0.5 - 0.03, 0.0), COL_CHANNEL))
	return out


## Su şeridi: ağızlardan merkeze; V Doğu/Kuzey ucunda 0, Batı/Güney yönünde artar.
static func _water_mesh(ports: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for dir: Variant in ports:
		var along: Vector3 = CanalField.port_vector(int(dir))
		var side := Vector3(-along.z, 0.0, along.x)
		var b: int = verts.size()
		for end in [0.0, 1.0]:
			var p: Vector3 = along * (HALF * end)
			for sgn in [-1.0, 1.0]:
				var q: Vector3 = p + side * sgn * WALL_IN + Vector3(0.0, WATER_Y, 0.0)
				verts.append(q)
				normals.append(Vector3.UP)
				uvs.append(Vector2((sgn + 1.0) * 0.5, _v_of(q)))
		idx.append_array([b, b + 2, b + 3, b, b + 3, b + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## V = Doğu ucundan (x = +1) Batı'ya ya da Kuzey ucundan (z = -1) Güney'e uzaklık: glb sözleşmesi.
static func _v_of(p: Vector3) -> float:
	if absf(p.x) >= absf(p.z):
		return HALF - p.x
	return HALF + p.z


# ---------- Serbest yapılar ----------

## Gölge ağacı: gövde ve yaprak topları (tek mesh, vertex rengi). 4-5 m.
static func tree() -> Node3D:
	var parts: Array = [
		_cylinder(0.14, 0.24, 2.8, Vector3(0.0, 1.4, 0.0), COL_BARK, Vector3.ZERO, 7),
		_sphere(1.7, Vector3(0.0, 3.5, 0.0), COL_LEAF, 0.85),
		_sphere(1.2, Vector3(1.1, 3.0, 0.4), COL_LEAF_DARK, 0.85),
		_sphere(1.2, Vector3(-1.0, 3.1, -0.5), COL_LEAF_DARK, 0.85),
		_sphere(1.0, Vector3(0.1, 4.2, 0.7), COL_LEAF, 0.85),
	]
	var root := Node3D.new()
	root.name = "tree_shade"
	root.add_child(_mesh_node("Tree", merge(parts)))
	return root


## Kamış öbeği: 9 ince, hafif eğik sap ve kahverengi başak. 1,2-1,6 m.
static func reeds() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var parts: Array = []
	for i in range(9):
		var ang: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.0, 0.38)
		var h: float = rng.randf_range(1.2, 1.6)
		var lean := Vector3(rng.randf_range(-0.14, 0.14), 0.0, rng.randf_range(-0.14, 0.14))
		var pos := Vector3(cos(ang) * rr, h * 0.5, sin(ang) * rr)
		parts.append(_cylinder(0.006, 0.014, h, pos, COL_REED, lean, 4))
		parts.append(_cylinder(0.022, 0.022, 0.14, pos + Vector3(0.0, h * 0.5 - 0.06, 0.0) + Vector3(lean.z, 0.0, -lean.x) * h * 0.5, COL_REED_TIP, lean, 5))
	var root := Node3D.new()
	root.name = "reeds"
	root.add_child(_mesh_node("Reeds", merge(parts)))
	return root


## Çiğ otu: kısa otlar ve damla boncukları.
static func dew() -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var parts: Array = []
	for i in range(14):
		var ang: float = rng.randf() * TAU
		var rr: float = rng.randf_range(0.0, 0.32)
		var h: float = rng.randf_range(0.28, 0.5)
		var lean := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
		parts.append(_cylinder(0.003, 0.012, h, Vector3(cos(ang) * rr, h * 0.5, sin(ang) * rr), COL_REED, lean, 4))
		if i % 3 == 0:
			parts.append(_sphere(0.022, Vector3(cos(ang) * rr, h * 0.8, sin(ang) * rr), Color(0.80, 0.93, 1.0), 1.0))
	var root := Node3D.new()
	root.name = "grass_dew"
	root.add_child(_mesh_node("Dew", merge(parts)))
	return root


## Çeşme: taş halka ve ortada küçük sütun (su fışkırması görünümde eklenir).
static func fountain() -> Node3D:
	var parts: Array = []
	for i in range(7):
		var a: float = TAU * float(i) / 7.0
		parts.append(_sphere(0.42, Vector3(cos(a) * 0.65, 0.22, sin(a) * 0.65), COL_STONE, 0.7))
	parts.append(_cylinder(0.18, 0.28, 0.7, Vector3(0.0, 0.35, 0.0), COL_STONE, Vector3.ZERO, 8))
	var root := Node3D.new()
	root.name = "fountain"
	root.add_child(_mesh_node("Fountain", merge(parts)))
	return root


## Bulut: direğin üstünde sallanan yumuşak kümeler (glb direğe de kodla eklenir). Orijin bulutun merkezi.
static func cloud() -> MeshInstance3D:
	var c: MeshInstance3D = _mesh_node("Cloud", merge([
		_sphere(0.34, Vector3(0.0, 0.0, 0.0), COL_CLOUD, 0.75),
		_sphere(0.26, Vector3(0.32, -0.04, 0.05), COL_CLOUD, 0.75),
		_sphere(0.26, Vector3(-0.30, -0.04, -0.04), COL_CLOUD, 0.75),
		_sphere(0.22, Vector3(0.08, 0.14, 0.0), COL_CLOUD, 0.8)]))
	c.position = Vector3(0.0, 3.35, 0.0)
	return c


## Bulut direği gövdesi: ince direk ve bulut (Cloud) ayrı düğüm; bulut sallanır.
static func cloud_pole() -> Node3D:
	var root := Node3D.new()
	root.name = "rain_cloud"
	root.add_child(_mesh_node("Pole", merge([
		_cylinder(0.05, 0.08, 3.0, Vector3(0.0, 1.5, 0.0), COL_WOOD, Vector3.ZERO, 6),
		_box(Vector3(0.5, 0.08, 0.08), Vector3(0.0, 2.9, 0.0), COL_WOOD)])))
	root.add_child(cloud())
	return root


## Kayadaki çatlak: koyu, ince, iki ucu sivri şerit; +Y yüzey normali, uzun eksen X.
static func crack() -> Node3D:
	var verts := PackedVector3Array([
		Vector3(-0.28, 0.0, 0.0), Vector3(-0.08, 0.0, -0.03), Vector3(0.12, 0.0, -0.02), Vector3(0.30, 0.0, 0.0),
		Vector3(0.10, 0.0, 0.03), Vector3(-0.10, 0.0, 0.025)])
	var normals := PackedVector3Array()
	for i in range(verts.size()):
		normals.append(Vector3.UP)
	var colors := PackedColorArray()
	for i in range(verts.size()):
		colors.append(COL_CRACK)
	var idx := PackedInt32Array([0, 1, 5, 1, 2, 4, 1, 4, 5, 2, 3, 4])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _vertex_mat())
	var root := Node3D.new()
	root.name = "crack"
	root.add_child(_mesh_node("Crack", mesh))
	return root


## Dere ağzı: iki taş ve ince oluk (başlangıç noktası göstergesi).
static func stream_mouth() -> Node3D:
	var root := Node3D.new()
	root.name = "stream_mouth"
	root.add_child(_mesh_node("Mouth", merge([
		_sphere(0.55, Vector3(-0.7, 0.2, 0.0), COL_STONE, 0.7),
		_sphere(0.5, Vector3(0.7, 0.18, 0.1), COL_STONE, 0.7),
		_sphere(0.4, Vector3(0.0, 0.14, -0.55), COL_STONE, 0.7)])))
	return root


## Çekiç: orijin tutma noktası, sap +Y, vuruş yüzü -Z.
static func hammer() -> Node3D:
	var root := Node3D.new()
	root.name = "hammer"
	root.add_child(_mesh_node("Hammer", merge([
		_cylinder(0.014, 0.018, 0.30, Vector3(0.0, 0.07, 0.0), COL_WOOD, Vector3.ZERO, 8),
		_box(Vector3(0.05, 0.06, 0.14), Vector3(0.0, 0.23, 0.0), COL_METAL)])))
	return root
