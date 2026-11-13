extends RefCounted
## Büyük kayaların görünür yüzeyi (RocksBuilder._surface ile aynı biçim): ışın kesişimi ve yukarıdan aşağı izdüşüm.
## Çarpışma küreleri görünür yüzeyin içinde kaldığı için çatlak yerleştirme bunu kullanır. Saf mantık (Node yok).

const Config = preload("res://scripts/core/config.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")

const BOUND_RADIUS: float = 0.8       # yerel birim uzayda sınırlayıcı küre
const MARCH_STEPS: int = 56
const BISECT_STEPS: int = 6
const PROJECT_HEIGHT: float = 6.0

static var _rocks: Array = []


static func _ensure() -> void:
	if not _rocks.is_empty():
		return
	for r: Dictionary in RocksBuilder.make_rocks():
		if float(r["size"]) < Config.ROCK_COLLIDE_MIN_SIZE:
			continue
		var xf: Transform3D = r["transform"]
		_rocks.append({"xf": xf, "inv": xf.affine_inverse(), "variant": int(r["variant"])})


static func rock_count() -> int:
	_ensure()
	return _rocks.size()


## Yerel noktanın (birim uzay) kayanın içinde olup olmadığı.
static func _inside(p: Vector3, variant: int) -> bool:
	var len2: float = p.length_squared()
	if len2 < 0.000001:
		return true
	var dir: Vector3 = p / sqrt(len2)
	return len2 <= RocksBuilder._surface(dir, variant).length_squared()


## Işın (dünya) en yakın kaya yüzeyini keser mi: {position, normal, t} ya da {}.
static func ray_hit(origin: Vector3, dir: Vector3, max_len: float) -> Dictionary:
	_ensure()
	var best_t: float = INF
	var best: Dictionary = {}
	for rock: Dictionary in _rocks:
		var inv: Transform3D = rock["inv"]
		var o: Vector3 = inv * origin
		var d: Vector3 = inv.basis * dir
		var a: float = d.dot(d)
		var b: float = o.dot(d)
		var c: float = o.dot(o) - BOUND_RADIUS * BOUND_RADIUS
		var disc: float = b * b - a * c
		if disc < 0.0 or a < 0.000001:
			continue
		var root: float = sqrt(disc)
		var t0: float = maxf((-b - root) / a, 0.0)
		var t1: float = minf((-b + root) / a, max_len)
		if t1 <= t0 or t0 >= best_t:
			continue
		var hit_t: float = _march(o, d, t0, t1, int(rock["variant"]))
		if hit_t >= 0.0 and hit_t < best_t:
			best_t = hit_t
			var local_hit: Vector3 = o + d * hit_t
			var xf: Transform3D = rock["xf"]
			var n: Vector3 = (xf.basis.inverse().transposed() * local_hit.normalized()).normalized()
			best = {"position": origin + dir * hit_t, "normal": n, "t": hit_t}
	return best


static func _march(o: Vector3, d: Vector3, t0: float, t1: float, variant: int) -> float:
	var dt: float = (t1 - t0) / float(MARCH_STEPS)
	var prev_t: float = t0
	if _inside(o + d * t0, variant):
		return t0
	for k in range(1, MARCH_STEPS + 1):
		var t: float = t0 + dt * float(k)
		if _inside(o + d * t, variant):
			var lo: float = prev_t
			var hi: float = t
			for i in range(BISECT_STEPS):
				var mid: float = (lo + hi) * 0.5
				if _inside(o + d * mid, variant):
					hi = mid
				else:
					lo = mid
			return hi
		prev_t = t
	return -1.0


## (x, z) noktasının üstünden aşağı bakınca görünen kaya yüzeyi; kaya yoksa {}.
static func project_down(x: float, z: float, from_y: float = PROJECT_HEIGHT) -> Dictionary:
	return ray_hit(Vector3(x, from_y, z), Vector3.DOWN, from_y + 4.0)
