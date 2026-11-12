extends RefCounted
## Göl yüzeyi hesabı: doluluktan su seviyesi, seviyeden kıyı yarıçapı. Saf mantık.

const Config = preload("res://scripts/core/config.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")

static var _table: PackedFloat32Array = PackedFloat32Array()


## Çukurun en alçak noktası (merkez).
static func bottom_level() -> float:
	return TerrainShape.height(0.0, 0.0)


## fill 0..1 (Economy.lake_fill) -> su yüzeyi yüksekliği. fill 0 iken dibin hemen üstü.
static func level_for_fill(fill: float) -> float:
	var low: float = bottom_level() + Config.LAKE_PUDDLE_THICKNESS
	var high: float = maxf(Config.LAKE_TOP_LEVEL, low)
	return lerpf(low, high, clampf(fill, 0.0, 1.0))


## Verilen seviyede suyun çanaktaki en uzak kıyı yarıçapı (m). Tablodan doğrusal ara değer.
static func shore_radius(level: float) -> float:
	if _table.is_empty():
		_build_table()
	var low: float = bottom_level()
	var high: float = Config.LAKE_TOP_LEVEL
	var t: float = clampf((level - low) / (high - low), 0.0, 1.0)
	var x: float = t * float(Config.LAKE_TABLE_STEPS)
	var i: int = mini(int(floor(x)), Config.LAKE_TABLE_STEPS - 1)
	return lerpf(_table[i], _table[i + 1], x - float(i))


static func _build_table() -> void:
	_table.resize(Config.LAKE_TABLE_STEPS + 1)
	var low: float = bottom_level()
	for i in range(Config.LAKE_TABLE_STEPS + 1):
		var level: float = lerpf(low, Config.LAKE_TOP_LEVEL, float(i) / float(Config.LAKE_TABLE_STEPS))
		_table[i] = _ray_radius(level)


## Merkezden ışınlar atıp arazinin seviyeye ilk eriştiği uzaklığın en büyüğü.
static func _ray_radius(level: float) -> float:
	var best: float = 0.0
	for k in range(Config.LAKE_RAYS):
		var ang: float = TAU * float(k) / float(Config.LAKE_RAYS)
		var dir := Vector2(cos(ang), sin(ang))
		var prev_r: float = 0.0
		var prev_h: float = TerrainShape.height(0.0, 0.0)
		var r: float = Config.LAKE_RAY_STEP
		var found: float = 0.0
		while r <= Config.LAKE_RAY_MAX:
			var h: float = TerrainShape.height(dir.x * r, dir.y * r)
			if h >= level:
				var span: float = h - prev_h
				var f: float = 0.0 if span <= 0.0 else clampf((level - prev_h) / span, 0.0, 1.0)
				found = lerpf(prev_r, r, f)
				break
			prev_r = r
			prev_h = h
			r += Config.LAKE_RAY_STEP
		best = maxf(best, found)
	return best
