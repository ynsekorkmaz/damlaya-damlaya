extends RefCounted
## Kanal parca kataloğu ve tum sayilar (yonlu parcalar modeli). Saf veri ve yardimci fonksiyonlar.

# Yonler: saat yonunde. Satir asagi dogru arttigi icin S = (0, 1).
const N: int = 0
const E: int = 1
const S: int = 2
const W: int = 3
const DIR_VEC: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_NAMES_TR: Array[String] = ["Kuzey", "Doğu", "Güney", "Batı"]

## Varsayilan oyun duzeni: gol dogu kenarinda, pinarlar bati kenarinda.
const DEFAULT_COLS: int = 14
const DEFAULT_ROWS: int = 10
const DEFAULT_SPRINGS: Dictionary = {
	"A": {"row": 4, "flow": 80.0, "cost": 200},
	"B": {"row": 1, "flow": 240.0, "cost": 70000},
	"C": {"row": 8, "flow": 800.0, "cost": 250000},
}
## Eski belgenin 8x5 duzeni (testler icin).
const LEGACY_COLS: int = 8
const LEGACY_ROWS: int = 5
const LEGACY_SPRINGS: Dictionary = {
	"A": {"row": 2, "flow": 60.0, "cost": 4000},
	"B": {"row": 0, "flow": 180.0, "cost": 30000},
	"C": {"row": 4, "flow": 480.0, "cost": 200000},
}

## Parcalar. nodes: parca icindeki bagli agiz gruplari (0 derecede). links: parca ici dugum baglantilari.
## hub: varsa bu dugume bir koldan girilip baska bir kola cikilamaz (Y kanal).
## leak_factor: sizintiya ek carpan.
const PIECE_IDS: Array[String] = ["straight", "elbow", "tee", "wye", "cross", "gate", "mill", "aqueduct", "reservoir"]
const PIECES: Dictionary = {
	"straight": {
		"id": "straight", "name_tr": "Düz kanal", "desc_tr": "İki ucu açık düz kanal.",
		"base_cost": 30, "unlock_cost": 0, "leak_factor": 1.0,
		"nodes": [[E, W]], "links": [],
	},
	"elbow": {
		"id": "elbow", "name_tr": "Dirsek", "desc_tr": "Suyu dik açıyla çevirir.",
		"base_cost": 32, "unlock_cost": 50, "leak_factor": 1.0,
		"nodes": [[W, S]], "links": [],
	},
	"tee": {
		"id": "tee", "name_tr": "T kanal", "desc_tr": "Üç ağzı da birbirine bağlıdır.",
		"base_cost": 45, "unlock_cost": 150, "leak_factor": 1.0,
		"nodes": [[W, E, S]], "links": [],
	},
	"wye": {
		"id": "wye", "name_tr": "Y kanal", "desc_tr": "Gövdeden gelen suyu iki kola ayırır; kollar birbirine geçmez. Yarı sızıntı.",
		"base_cost": 60, "unlock_cost": 400, "leak_factor": 0.5,
		"nodes": [[W], [N], [S]], "links": [[0, 1], [0, 2]], "hub": 0,
	},
	"cross": {
		"id": "cross", "name_tr": "Artı kanal", "desc_tr": "Dört ağzı da birbirine bağlıdır.",
		"base_cost": 60, "unlock_cost": 600, "leak_factor": 1.0,
		"nodes": [[N, E, S, W]], "links": [],
	},
	"gate": {
		"id": "gate", "name_tr": "Savak", "desc_tr": "Düz kanal gibidir; kapatınca su geçmez.",
		"base_cost": 90, "unlock_cost": 900, "leak_factor": 1.0,
		"nodes": [[E, W]], "links": [],
	},
	"mill": {
		"id": "mill", "name_tr": "Değirmen", "desc_tr": "Düz kanal gibidir; bulunduğu kanal ağına verim bonusu verir.",
		"base_cost": 600, "unlock_cost": 2500, "leak_factor": 1.0,
		"nodes": [[E, W]], "links": [],
	},
	"aqueduct": {
		"id": "aqueduct", "name_tr": "Su kemeri", "desc_tr": "İki bağımsız hat: doğu-batı ve kuzey-güney. Birbirine karışmazlar.",
		"base_cost": 150, "unlock_cost": 3000, "leak_factor": 1.0,
		"nodes": [[E, W], [N, S]], "links": [],
	},
	"reservoir": {
		"id": "reservoir", "name_tr": "Biriktirme havuzu", "desc_tr": "Dört ağzı bağlıdır; bulunduğu ağın kapasitesini artırır.",
		"base_cost": 400, "unlock_cost": 6000, "leak_factor": 1.0,
		"nodes": [[N, E, S, W]], "links": [],
	},
}

## Malzemeler: hucre basina sizinti, fiyat carpani, kilit maliyeti.
const MATERIAL_IDS: Array[String] = ["earth", "wood", "stone"]
const MATERIALS: Dictionary = {
	"earth": {"id": "earth", "name_tr": "Toprak", "desc_tr": "Ucuz ama çok sızdırır.", "leak": 0.05, "cost_mult": 1.0, "unlock_cost": 0},
	"wood": {"id": "wood", "name_tr": "Ahşap", "desc_tr": "Daha az sızdırır.", "leak": 0.03, "cost_mult": 2.5, "unlock_cost": 4000},
	"stone": {"id": "stone", "name_tr": "Taş", "desc_tr": "En az sızdırır.", "leak": 0.012, "cost_mult": 6.0, "unlock_cost": 50000},
}

## Fiyat formulleri
const PIECE_COST_GROWTH: float = 1.04
const MILL_COST_GROWTH: float = 1.5
const REFUND_FACTOR: float = 0.5

## Yukseltmeler
const WIDTH_MAX_LEVEL: int = 4
const WIDTH_BASE_COST: float = 12000.0
const WIDTH_COST_GROWTH: float = 4.0
const LINING_MAX_LEVEL: int = 3
const LINING_BASE_COST: float = 15000.0
const LINING_COST_GROWTH: float = 4.0
## Tas kaplama seviyesine gore sizinti carpani.
const LINING_LEAK_MULT: Array[float] = [1.0, 0.7, 0.4, 0.16]

## Akis parametreleri
const CAP_PER_EXIT_BASE: float = 80.0
const CAP_WIDTH_GROWTH: float = 2.0
const MILL_BONUS_PER_MILL: float = 0.08
const MILL_BONUS_MAX_COUNT: int = 3
const RESERVOIR_CAP_BASE: float = 40.0
const RESERVOIR_MAX_COUNT: int = 2


# --- Yon yardimcilari ---

static func opposite(dir: int) -> int:
	return (dir + 2) % 4


static func has_piece(piece_id: String) -> bool:
	return PIECES.has(piece_id)


static func has_material(material: String) -> bool:
	return MATERIALS.has(material)


static func get_piece_def(piece_id: String) -> Dictionary:
	return PIECES.get(piece_id, {})


## Donusle dondurulmus dugum agiz gruplari. Donus 90 derece adimlarla saat yonunde.
static func rotated_nodes(piece_id: String, rotation: int) -> Array:
	var def: Dictionary = PIECES.get(piece_id, {})
	var out: Array = []
	if def.is_empty():
		return out
	for group in def["nodes"]:
		var ports: Array = []
		for dir in group:
			ports.append((int(dir) + rotation) % 4)
		out.append(ports)
	return out


## Su 'heading' yonunde akarken (ornegin E) saga ya da sola donen dirsegin donusu.
static func elbow_rotation(heading: int, turn_right: bool) -> int:
	if turn_right:
		return (heading + 3) % 4
	return heading % 4


# --- Sizinti, kapasite ---

static func leak(piece_id: String, material: String, lining_level: int) -> float:
	var def: Dictionary = PIECES.get(piece_id, {})
	var mat: Dictionary = MATERIALS.get(material, {})
	if def.is_empty() or mat.is_empty():
		return 0.0
	var lvl: int = clampi(lining_level, 0, LINING_MAX_LEVEL)
	return float(mat["leak"]) * LINING_LEAK_MULT[lvl] * float(def["leak_factor"])


static func cap_per_exit(width_level: int) -> float:
	return CAP_PER_EXIT_BASE * pow(CAP_WIDTH_GROWTH, width_level)


## Tek bir havuzun kapasite eki.
static func reservoir_extra(width_level: int) -> float:
	return RESERVOIR_CAP_BASE * pow(CAP_WIDTH_GROWTH, width_level)


# --- Fiyatlar ---

## Bilinmeyen parca ya da malzeme icin -1.
static func piece_cost(piece_id: String, material: String, piece_total: int, mill_total: int) -> int:
	if not PIECES.has(piece_id) or not MATERIALS.has(material):
		return -1
	var base: float = float(PIECES[piece_id]["base_cost"])
	var mult: float = float(MATERIALS[material]["cost_mult"])
	if piece_id == "mill":
		return floori(floorf(base * pow(MILL_COST_GROWTH, mill_total)) * mult)
	return floori(base * mult * pow(PIECE_COST_GROWTH, piece_total))


static func refund_of(cost_after_removal: int) -> int:
	return floori(cost_after_removal * REFUND_FACTOR)


## En yuksek seviyede -1.
static func width_upgrade_cost(level: int) -> int:
	if level >= WIDTH_MAX_LEVEL:
		return -1
	return floori(WIDTH_BASE_COST * pow(WIDTH_COST_GROWTH, level))


static func lining_upgrade_cost(level: int) -> int:
	if level >= LINING_MAX_LEVEL:
		return -1
	return floori(LINING_BASE_COST * pow(LINING_COST_GROWTH, level))
