extends RefCounted
## Büyük kayaların görünür yüzeyi (kaya modelinin kendi üçgenleri): ışın kesişimi ve yukarıdan aşağı izdüşüm.
## Çarpışma küreleri görünür yüzeyin içinde kaldığı için çatlak yerleştirme bunu kullanır. Saf mantık (Node yok).

const Config = preload("res://scripts/core/config.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")

const PROJECT_HEIGHT: float = 6.0

static var _rocks: Array = []
static var _tri_meshes: Dictionary = {}   ## biçim -> TriangleMesh


static func _ensure() -> void:
	if not _rocks.is_empty():
		return
	for r: Dictionary in RocksBuilder.make_rocks():
		if float(r["size"]) < Config.ROCK_COLLIDE_MIN_SIZE:
			continue
		var xf: Transform3D = r["transform"]
		var box: AABB = RocksBuilder.mesh_box(int(r["variant"]))
		var c: Vector3 = box.get_center()
		var bound: float = box.size.length() * 0.5 * maxf(xf.basis.get_scale().x, maxf(xf.basis.get_scale().y, xf.basis.get_scale().z))
		_rocks.append({"xf": xf, "inv": xf.affine_inverse(), "variant": int(r["variant"]),
			"center": xf * c, "bound": bound})


static func rock_count() -> int:
	_ensure()
	return _rocks.size()


static func _tri_mesh(variant: int) -> TriangleMesh:
	if not _tri_meshes.has(variant):
		_tri_meshes[variant] = RocksBuilder.build_rock_mesh(variant).generate_triangle_mesh()
	return _tri_meshes[variant]


## Işın (dünya) en yakın kaya yüzeyini keser mi: {position, normal, t} ya da {}.
static func ray_hit(origin: Vector3, dir: Vector3, max_len: float) -> Dictionary:
	_ensure()
	var best_t: float = INF
	var best: Dictionary = {}
	var d_n: Vector3 = dir.normalized()
	for rock: Dictionary in _rocks:
		# Sınırlayıcı küre (dünya) ön elemesi
		var oc: Vector3 = origin - (rock["center"] as Vector3)
		var b: float = oc.dot(d_n)
		var rad: float = float(rock["bound"])
		var disc: float = b * b - (oc.dot(oc) - rad * rad)
		if disc < 0.0 or -b - sqrt(disc) > minf(best_t, max_len) or -b + sqrt(disc) < 0.0:
			continue
		var inv: Transform3D = rock["inv"]
		var o: Vector3 = inv * origin
		var d: Vector3 = inv.basis * d_n
		var hit: Dictionary = _tri_mesh(int(rock["variant"])).intersect_ray(o, d.normalized())
		if hit.is_empty():
			continue
		var xf: Transform3D = rock["xf"]
		var world_pos: Vector3 = xf * (hit["position"] as Vector3)
		var t: float = origin.distance_to(world_pos)
		if t > max_len or t >= best_t:
			continue
		best_t = t
		var n: Vector3 = (xf.basis.inverse().transposed() * (hit["normal"] as Vector3)).normalized()
		if n.dot(d_n) > 0.0:
			n = -n
		best = {"position": world_pos, "normal": n, "t": t}
	return best


## (x, z) noktasının üstünden aşağı bakınca görünen kaya yüzeyi; kaya yoksa {}.
static func project_down(x: float, z: float, from_y: float = PROJECT_HEIGHT) -> Dictionary:
	return ray_hit(Vector3(x, from_y, z), Vector3.DOWN, from_y + 4.0)
