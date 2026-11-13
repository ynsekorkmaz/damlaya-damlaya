extends RefCounted
## Göle giden dere şeridinin yolu: başlangıçtan gölün o anki kıyısına doğru, zemini izleyen noktalar. Saf mantık.

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")


## start (x, z) noktasından göl merkezine doğru kıyıya (shore_radius) kadar noktalar. Çok kısaysa boş.
static func points(start: Vector2, shore_radius: float, basin_radius: float, basin_depth: float, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var dist: float = start.length()
	var length: float = dist - shore_radius
	if dist <= 0.0001 or length < Config.CANAL_STREAM_MIN_LENGTH:
		return out
	var dir: Vector2 = -start / dist
	var end: Vector2 = start + dir * (length + Config.CANAL_STREAM_OVERLAP)
	var total: float = start.distance_to(end)
	var n: int = maxi(2, ceili(total / maxf(step, 0.1)) + 1)
	for i in range(n):
		var p: Vector2 = start.lerp(end, float(i) / float(n - 1))
		out.append(Vector3(p.x, TerrainShape.height(p.x, p.y, basin_radius, basin_depth) + Config.CANAL_STREAM_LIFT, p.y))
	return out
