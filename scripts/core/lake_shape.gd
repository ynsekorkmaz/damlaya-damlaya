extends RefCounted
## Göl yüzeyi: toplam damladan su seviyesi, seviyeden kıyı yarıçapı. Saf mantık.

const Config = preload("res://scripts/core/config.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")


## Çanağın en alçak noktası (merkez).
static func bottom_level(total_drops: float) -> float:
	return rim_level() - BasinShape.depth(total_drops)


## Çanak ağzının (merkez zemin) yüksekliği.
static func rim_level() -> float:
	return TerrainShape.height(0.0, 0.0, 1.0, 0.0)


## Su yüzeyi yüksekliği: toplam 0 iken dipte (görünmez), ilk damlalarda dipte ince birikinti,
## sonra ağzın FREEBOARD altına yükselir ve orada kalır; çanak büyüdükçe kıyı genişler.
static func level(total_drops: float) -> float:
	var bottom: float = bottom_level(total_drops)
	var top: float = maxf(rim_level() - Config.LAKE_FREEBOARD, bottom + Config.LAKE_PUDDLE_THICKNESS)
	var ramp: float = clampf(log(1.0 + maxf(total_drops, 0.0)) / log(1.0 + Config.LAKE_RAMP_DROPS), 0.0, 1.0)
	if total_drops <= 0.0:
		return bottom
	return bottom + Config.LAKE_PUDDLE_THICKNESS + (top - bottom - Config.LAKE_PUDDLE_THICKNESS) * ramp


## Verilen seviyede, çanakta merkezden ışınlarla arazinin seviyeye ilk eriştiği uzaklığın en büyüğü (m).
static func shore_radius(water_level: float, basin_radius: float, basin_depth: float) -> float:
	var limit: float = basin_radius * 1.15 + 1.0
	var step: float = limit / float(Config.LAKE_RAY_STEPS)
	var best: float = 0.0
	for k in range(Config.LAKE_RAYS):
		var ang: float = TAU * float(k) / float(Config.LAKE_RAYS)
		var dx: float = cos(ang)
		var dz: float = sin(ang)
		var prev_r: float = 0.0
		var prev_h: float = TerrainShape.height(0.0, 0.0, basin_radius, basin_depth)
		var crossed: bool = false
		for s in range(1, Config.LAKE_RAY_STEPS + 1):
			var r: float = step * float(s)
			var h: float = TerrainShape.height(dx * r, dz * r, basin_radius, basin_depth)
			if h >= water_level:
				var span: float = h - prev_h
				var f: float = 0.0 if span <= 0.0 else clampf((water_level - prev_h) / span, 0.0, 1.0)
				best = maxf(best, lerpf(prev_r, r, f))
				crossed = true
				break
			prev_r = r
			prev_h = h
		if not crossed:
			best = maxf(best, limit)
	return best
