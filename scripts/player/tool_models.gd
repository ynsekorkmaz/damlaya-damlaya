extends RefCounted
## Alet modelleri: assets/models/tools/<id>.glb varsa o, yoksa kodla yer tutucu.
## Sonuc: {"root": Node3D, "waters": Array[Node3D]} ("Water" ile baslayan, alt ortada orijinli su nesneleri).

const Cfg = preload("res://scripts/player/arms_config.gd")
const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")


static func build(id: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "Tool_" + id
	var path: String = Cfg.TOOL_MODEL_DIR + id + ".glb"
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene != null:
			root.add_child(scene.instantiate())
	if root.get_child_count() == 0:
		_placeholder(root, id)
	var waters: Array[Node3D] = []
	for node: Node in root.find_children(Cfg.TOOL_WATER_PREFIX + "*", "Node3D", true, false):
		waters.append(node as Node3D)
	return {"root": root, "waters": waters}


## hands_grip.glb'den istenen el (Cfg.GRIP_NODE_R "Grip" sag, Cfg.GRIP_NODE_L "GripL" sol); yoksa null.
## Donen dugum yalnizca o mesh'i tasir; konum/donus/olcek Cfg.GRIPS ayarindan verilir. Malzeme cagirandadir.
static func build_grip(node_name: String, pos: Vector3, rot_deg: Vector3, scale: float) -> Node3D:
	if not ResourceLoader.exists(Cfg.GRIP_MODEL_PATH):
		return null
	var scene: PackedScene = load(Cfg.GRIP_MODEL_PATH)
	if scene == null:
		return null
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return null
	var found: bool = false
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if node.name == node_name:
			found = true
		elif node.name == node_name.replace("Grip", "Sleeve"):
			pass
		else:
			node.get_parent().remove_child(node)
			node.free()
	if not found:
		root.free()
		return null
	root.name = "Grip_" + node_name
	root.position = pos
	root.rotation = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	root.scale = Vector3.ONE * scale
	return root


## Ten malzemesi (vertex color); held_vessel ve held_hammer ayni yolu kullanir.
static func skin_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.85
	return mat


## Kaliteye gore ten kazanci: Orta/Yuksek'te tonemap teni solgunlastirir, carpan bunu dengeler.
static func apply_skin_gain(mat: StandardMaterial3D, gain: float) -> void:
	mat.albedo_color = Color(gain, gain * GraphicsConfig.SKIN_WARMTH.x, gain * GraphicsConfig.SKIN_WARMTH.y)


static func _placeholder(root: Node3D, id: String) -> void:
	match id:
		"cup":
			_add_cup(root)
		"bucket":
			_add_bucket(root, 0.0, 0.0, 1.0)
		"double_bucket":
			_add_bucket(root, -Cfg.PH_DOUBLE_HALF, 0.0, 1.0)
			_add_bucket(root, Cfg.PH_DOUBLE_HALF, 0.0, 1.0)
			_add_bar(root, Vector3(Cfg.PH_DOUBLE_HALF * 2.0, 0.025, 0.025), Vector3.ZERO, Cfg.PH_WOOD)
		"yoke":
			_add_bar(root, Vector3(Cfg.PH_YOKE_HALF * 2.0 + 0.1, 0.03, 0.03), Vector3.ZERO, Cfg.PH_WOOD)
			for sx: float in [-1.0, 1.0]:
				var x: float = sx * Cfg.PH_YOKE_HALF
				_add_bar(root, Vector3(0.012, Cfg.PH_YOKE_ROPE, 0.012), Vector3(x, -Cfg.PH_YOKE_ROPE * 0.5, 0.0), Cfg.PH_ROPE)
				_add_bucket(root, x, -Cfg.PH_YOKE_ROPE, 0.9)


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _add_bar(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.position = pos
	parent.add_child(mi)


## Su: orijin alt ortada, tam dolu yukseklikte; icindeki mesh yarim yukseklik yukari kayik.
static func _add_water(parent: Node3D, radius: float, height: float, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = Cfg.TOOL_WATER_PREFIX + "Holder"
	holder.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = height * 0.5
	holder.add_child(mi)
	parent.add_child(holder)


## Yarim kure tas (kodla donduruldu, ustu acik): cukur kasenin alt orta noktasi orijin.
static func _add_cup(root: Node3D) -> void:
	var r: float = Cfg.PH_CUP_RADIUS
	var steps: int = 6
	var segs: int = 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in steps:
		var a0: float = PI * 0.5 * float(i) / steps
		var a1: float = PI * 0.5 * float(i + 1) / steps
		for k: int in segs:
			var t0: float = TAU * float(k) / segs
			var t1: float = TAU * float(k + 1) / segs
			var p00: Vector3 = _bowl_point(r, a0, t0)
			var p01: Vector3 = _bowl_point(r, a0, t1)
			var p10: Vector3 = _bowl_point(r, a1, t0)
			var p11: Vector3 = _bowl_point(r, a1, t1)
			for v: Vector3 in [p00, p10, p01, p01, p10, p11]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material(Cfg.PH_WOOD)
	root.add_child(mi)
	_add_water(root, r * 0.8, r * 0.4, Vector3(0.0, r * 0.45, 0.0))


## Kasenin yuzeyi: a = 0 dip, a = PI/2 agiz kenari.
static func _bowl_point(r: float, a: float, t: float) -> Vector3:
	return Vector3(sin(a) * cos(t) * r, r - cos(a) * r, sin(a) * sin(t) * r)


## Kova: kulp tepesi (x, y) noktasinda orijin; govde asagi sarkar.
static func _add_bucket(parent: Node3D, x: float, y: float, s: float) -> void:
	var node := Node3D.new()
	node.position = Vector3(x, y, 0.0)
	node.scale = Vector3.ONE * s
	parent.add_child(node)
	var top_y: float = -Cfg.PH_BUCKET_DROP
	var body := CylinderMesh.new()
	body.top_radius = Cfg.PH_BUCKET_TOP_R
	body.bottom_radius = Cfg.PH_BUCKET_BOTTOM_R
	body.height = Cfg.PH_BUCKET_HEIGHT
	body.radial_segments = 20
	body.rings = 1
	body.cap_top = false
	var mi := MeshInstance3D.new()
	mi.mesh = body
	mi.material_override = _material(Cfg.PH_WOOD)
	mi.position.y = top_y - Cfg.PH_BUCKET_HEIGHT * 0.5
	node.add_child(mi)
	var ring := TorusMesh.new()
	ring.inner_radius = Cfg.PH_BUCKET_DROP - 0.008
	ring.outer_radius = Cfg.PH_BUCKET_DROP + 0.008
	ring.rings = 16
	ring.ring_segments = 6
	var handle := MeshInstance3D.new()
	handle.mesh = ring
	handle.material_override = _material(Cfg.PH_METAL)
	handle.rotation.x = PI * 0.5
	handle.position.y = top_y
	node.add_child(handle)
	var water_h: float = Cfg.PH_BUCKET_HEIGHT * 0.78
	_add_water(node, Cfg.PH_BUCKET_BOTTOM_R + 0.004, water_h, Vector3(0.0, top_y - Cfg.PH_BUCKET_HEIGHT + 0.03, 0.0))
