extends RefCounted
## Dükkân: shop.glb varsa o, yoksa basit ahşap tezgâh. Orijin zeminde, tezgâhın ön orta noktasında;
## ön yüz -Z, müşteri -Z tarafında durur. Tezgâh için kutu çarpışması.

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")

const WOOD := Color(0.52, 0.34, 0.18)
const WOOD_DARK := Color(0.36, 0.23, 0.12)
const CLOTH := Color(0.72, 0.28, 0.20)


## Dünya konumu (y araziden).
static func origin() -> Vector3:
	var p: Vector3 = Config.SHOP_POSITION
	p.y = TerrainShape.height(p.x, p.z)
	return p


## Yüzün (-Z) çukur merkezine dönmesi için y dönüşü (radyan).
static func facing_yaw() -> float:
	var p: Vector3 = Config.SHOP_POSITION
	return atan2(p.x, p.z)


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Shop"
	root.position = origin()
	root.rotation.y = facing_yaw()
	if ResourceLoader.exists(Config.SHOP_MODEL_PATH):
		var scene: PackedScene = load(Config.SHOP_MODEL_PATH)
		if scene != null:
			root.add_child(scene.instantiate())
	if root.get_child_count() == 0:
		_add_placeholder(root)
	var body := StaticBody3D.new()
	body.name = "ShopCollider"
	var shape := BoxShape3D.new()
	shape.size = Config.SHOP_COLLIDE_SIZE
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0.0, Config.SHOP_COLLIDE_SIZE.y * 0.5, Config.SHOP_COLLIDE_SIZE.z * 0.5)
	body.add_child(cs)
	root.add_child(body)
	return root


static func _add_placeholder(root: Node3D) -> void:
	var wood: StandardMaterial3D = _material(WOOD)
	var dark: StandardMaterial3D = _material(WOOD_DARK)
	var cloth: StandardMaterial3D = _material(CLOTH)
	var w: float = Config.SHOP_SIZE.x
	var h: float = Config.SHOP_SIZE.y
	var d: float = Config.SHOP_SIZE.z
	var counter_h: float = Config.SHOP_COLLIDE_SIZE.y
	# Tezgâh gövdesi ve üst tahtası
	_box(root, Vector3(w, counter_h - 0.08, 0.8), Vector3(0.0, (counter_h - 0.08) * 0.5, 0.45), wood)
	_box(root, Vector3(w + 0.2, 0.08, 1.0), Vector3(0.0, counter_h - 0.04, 0.4), dark)
	# Arka duvar ve raflar
	_box(root, Vector3(w, h - 0.2, 0.08), Vector3(0.0, (h - 0.2) * 0.5, d - 0.1), wood)
	_box(root, Vector3(w - 0.3, 0.06, 0.4), Vector3(0.0, 1.5, d - 0.3), dark)
	# Direkler
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(0.12, h, 0.12), Vector3(sx * (w * 0.5 - 0.06), h * 0.5, 0.1), dark)
	# Eğik kumaş tente
	var awning := _box(root, Vector3(w + 0.3, 0.06, d + 0.5), Vector3(0.0, h, d * 0.5 - 0.1), cloth)
	awning.rotation.x = deg_to_rad(8.0)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat
