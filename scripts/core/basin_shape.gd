extends RefCounted
## Çanak boyutu: toplam damlaya göre yarıçap ve derinlik, çanak profili. Saf mantık.

const Config = preload("res://scripts/core/config.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")


## Anahtar toplamlar: aşama eşikleri + oyun sonu.
static func keys() -> Array[float]:
	var out: Array[float] = []
	for st: Dictionary in Cfg.STAGES:
		out.append(float(st["threshold"]))
	out.append(Cfg.GAME_END_DROPS)
	return out


static func radius(total_drops: float) -> float:
	return _interp(total_drops, Config.BASIN_RADII)


static func depth(total_drops: float) -> float:
	return _interp(total_drops, Config.BASIN_DEPTHS)


static func max_radius() -> float:
	return Config.BASIN_RADII[Config.BASIN_RADII.size() - 1]


## Anahtarlar arasında log(1+toplam) üzerinden, doğrusal ile smoothstep karışımı (tekdüze artan).
static func _interp(total_drops: float, values: Array[float]) -> float:
	var k: Array[float] = keys()
	var t: float = maxf(total_drops, 0.0)
	var last: int = k.size() - 1
	if t >= k[last]:
		return values[last]
	var i: int = 0
	while i + 1 < last and t >= k[i + 1]:
		i += 1
	var a: float = log(1.0 + k[i])
	var b: float = log(1.0 + k[i + 1])
	var f: float = clampf((log(1.0 + t) - a) / (b - a), 0.0, 1.0)
	f = lerpf(f, smoothstep(0.0, 1.0, f), Config.BASIN_SMOOTH)
	return lerpf(values[i], values[i + 1], f)


## Çanağın yüksekliğe katkısı (negatif); r >= basin_radius iken tam 0.
static func pit(r: float, basin_radius: float, basin_depth: float) -> float:
	if basin_radius <= 0.0 or r >= basin_radius:
		return 0.0
	return -basin_depth * (1.0 - smoothstep(0.0, 1.0, r / basin_radius))


## pit'in r'ye göre türevi (dışa doğru artış, >= 0).
static func pit_slope(r: float, basin_radius: float, basin_depth: float) -> float:
	if basin_radius <= 0.0 or r >= basin_radius:
		return 0.0
	var u: float = r / basin_radius
	return basin_depth * 6.0 * u * (1.0 - u) / basin_radius


## Çanak içinde zemin dalgalarının payı: içeride BASIN_FLAT_KEEP, dışarıda 1.
static func wave_keep(r: float, basin_radius: float) -> float:
	if basin_radius <= 0.0:
		return 1.0
	var s: float = smoothstep(Config.BASIN_FLAT_START, Config.BASIN_FLAT_END, r / basin_radius)
	return Config.BASIN_FLAT_KEEP + (1.0 - Config.BASIN_FLAT_KEEP) * s


## wave_keep'in r'ye göre türevi.
static func wave_keep_slope(r: float, basin_radius: float) -> float:
	if basin_radius <= 0.0:
		return 0.0
	var span: float = Config.BASIN_FLAT_END - Config.BASIN_FLAT_START
	var t: float = (r / basin_radius - Config.BASIN_FLAT_START) / span
	if t <= 0.0 or t >= 1.0:
		return 0.0
	return (1.0 - Config.BASIN_FLAT_KEEP) * 6.0 * t * (1.0 - t) / (span * basin_radius)
