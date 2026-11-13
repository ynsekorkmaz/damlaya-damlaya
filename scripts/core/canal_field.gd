extends RefCounted
## Kanal alanı geometrisi: ızgara hücresi <-> dünya koordinatı, arazi düzleştirme maskesi, dönüş. Saf mantık.
## Dünya: Doğu = +X, Güney = +Z, Kuzey = -Z. Satır 0 kuzeyde, sütun 0 batıda.

const Config = preload("res://scripts/core/config.gd")

const NONE := Vector2i(-1, -1)


static func west() -> float:
	return Config.CANAL_FIELD_EAST - float(Config.CANAL_FIELD_COLS) * Config.CANAL_CELL_SIZE


static func east() -> float:
	return Config.CANAL_FIELD_EAST


static func north() -> float:
	return Config.CANAL_FIELD_NORTH


static func south() -> float:
	return Config.CANAL_FIELD_NORTH + float(Config.CANAL_FIELD_ROWS) * Config.CANAL_CELL_SIZE


## Hücre merkezi (x, z).
static func cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		west() + (float(col) + 0.5) * Config.CANAL_CELL_SIZE,
		north() + (float(row) + 0.5) * Config.CANAL_CELL_SIZE)


## Dünya noktasının hücresi; alan dışında NONE.
static func world_to_cell(x: float, z: float) -> Vector2i:
	if not contains(x, z, 0.0):
		return NONE
	var col: int = clampi(floori((x - west()) / Config.CANAL_CELL_SIZE), 0, Config.CANAL_FIELD_COLS - 1)
	var row: int = clampi(floori((z - north()) / Config.CANAL_CELL_SIZE), 0, Config.CANAL_FIELD_ROWS - 1)
	return Vector2i(col, row)


## Alan dikdörtgeninin içinde mi (margin kadar genişletilmiş).
static func contains(x: float, z: float, margin: float = 0.0) -> bool:
	return x >= west() - margin and x <= east() + margin and z >= north() - margin and z <= south() + margin


## Alan dikdörtgenine uzaklık (içeride 0).
static func distance_to(x: float, z: float) -> float:
	var ex: float = maxf(maxf(west() - x, x - east()), 0.0)
	var ez: float = maxf(maxf(north() - z, z - south()), 0.0)
	return sqrt(ex * ex + ez * ez)


## Arazi düzleştirme: 1 = tam düz (alan ve payı), 0 = etkisiz; kenarda TRANSITION boyunca yumuşak.
static func flat_mask(x: float, z: float) -> float:
	var m: float = Config.CANAL_FIELD_FLAT_MARGIN
	var ex: float = maxf(maxf(west() - m - x, x - (east() + m)), 0.0)
	var ez: float = maxf(maxf(north() - m - z, z - (south() + m)), 0.0)
	var d: float = sqrt(ex * ex + ez * ez)
	if d <= 0.0:
		return 1.0
	return 1.0 - smoothstep(0.0, Config.CANAL_FIELD_TRANSITION, d)


## Parça dönüşü (0..3, saat yönünde) için Y ekseni dönüşü (radyan): Doğu -> Güney.
static func yaw_of_rotation(rotation: int) -> float:
	return -float(rotation) * PI * 0.5


## Yön (N=0, E=1, S=2, W=3) birim vektörü, dünya uzayında.
static func port_vector(dir: int) -> Vector3:
	match posmod(dir, 4):
		0:
			return Vector3(0.0, 0.0, -1.0)
		1:
			return Vector3(1.0, 0.0, 0.0)
		2:
			return Vector3(0.0, 0.0, 1.0)
	return Vector3(-1.0, 0.0, 0.0)


## Pınar çeşmesinin yeri (x, z): alanın batı kenarının dışında, satır ortasında.
static func spring_point(row: int) -> Vector2:
	var c: Vector2 = cell_center(0, row)
	return Vector2(west() - Config.CANAL_SPRING_OUTSET, c.y)


## Göl çıkışı: son sütun hücresinin doğu ağzı (x, z), alanın doğu kenarında.
static func exit_point(row: int) -> Vector2:
	var c: Vector2 = cell_center(Config.CANAL_FIELD_COLS - 1, row)
	return Vector2(east(), c.y)
