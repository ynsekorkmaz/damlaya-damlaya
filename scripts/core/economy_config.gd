extends RefCounted
## Ekonominin tum sayilari ve Turkce metinleri. Denge ayari yalnizca buradan yapilir.
## Her ogenin "id"si degismez anahtardir (kayit ve ceviri icin), "name_tr" gorunen addir.

# --- Tasima ---
const FILL_SECONDS: float = 1.5

# Sirayla alinir. cost: bu aleti almanin parasi.
const TOOLS: Array[Dictionary] = [
	{"id": "palm", "name_tr": "Avuç", "capacity": 5.0, "cost": 0.0},
	{"id": "cup", "name_tr": "Tas", "capacity": 15.0, "cost": 12.0},
	{"id": "bucket", "name_tr": "Kova", "capacity": 50.0, "cost": 90.0},
	{"id": "double_bucket", "name_tr": "Çift kova", "capacity": 140.0, "cost": 700.0},
	{"id": "yoke", "name_tr": "Sırık ve dört kova", "capacity": 400.0, "cost": 6000.0},
]

# --- Para ---
# Seviye i: drops_per_money damla = 1 para. cost: BU seviyeye gecmenin parasi (seviye 0 bedava).
const RATE_LEVELS: Array[Dictionary] = [
	{"drops_per_money": 5.0, "cost": 0.0},
	{"drops_per_money": 4.0, "cost": 60.0},
	{"drops_per_money": 3.0, "cost": 600.0},
	{"drops_per_money": 2.0, "cost": 8000.0},
	{"drops_per_money": 1.0, "cost": 120000.0},
]
const RATE_NAME_TR: String = "Dönüşüm oranı"

# --- Pasif kaynaklar ---
const SOURCE_COST_GROWTH: float = 1.15
const MAX_SOURCE_COUNT: int = 100000
const COST_ROUND_EPSILON: float = 1.0e-6

const SOURCES: Array[Dictionary] = [
	{"id": "crack", "name_tr": "Çatlak", "rate": 0.5, "base_cost": 15.0},
	{"id": "dew", "name_tr": "Çiğ", "rate": 3.0, "base_cost": 100.0},
	{"id": "rain_cloud", "name_tr": "Yağmur bulutu", "rate": 20.0, "base_cost": 1100.0},
	{"id": "spring", "name_tr": "Kaynak", "rate": 120.0, "base_cost": 12000.0},
	{"id": "stream_mouth", "name_tr": "Dere ağzı", "rate": 700.0, "base_cost": 150000.0},
]

# --- Kayip ---
# Pasif uretimin tabani yuzde 30'u sizar. Yukseltmeler puan (yuzde birimi) dusurur.
const BASE_LOSS_PERCENT: float = 30.0
const MIN_LOSS_PERCENT: float = 0.0

const LOSS_UPGRADES: Array[Dictionary] = [
	{"id": "rock_bed", "name_tr": "Kaya yatağı", "cost": 200.0, "points": 8.0},
	{"id": "reed_edge", "name_tr": "Kamış kenarı", "cost": 2500.0, "points": 7.0},
	{"id": "shade_trees", "name_tr": "Gölge ağaçları", "cost": 30000.0, "points": 7.0},
	{"id": "clay_floor", "name_tr": "Kil taban", "cost": 400000.0, "points": 5.0},
]

# --- Gorunurluk ---
# Oyuncunun toplam kazandigi para maliyetin bu orani olunca oge gorunur.
const VISIBLE_COST_FRACTION: float = 0.5

# --- Asamalar ---
const STAGES: Array[Dictionary] = [
	{"id": "drop", "name_tr": "Damla", "threshold": 0.0, "text_tr": "Yerde tek bir damla var."},
	{"id": "pit", "name_tr": "Çukur", "threshold": 50.0, "text_tr": "Toprakta küçük bir çukur açıldı."},
	{"id": "pond", "name_tr": "Havuz", "threshold": 1000.0, "text_tr": "Artık bir havuz. Kenarında kamışlar bitti, balıklar geldi."},
	{"id": "lake", "name_tr": "Göl", "threshold": 25000.0, "text_tr": "Damlaya damlaya göl oldu. Kuşlar kondu."},
	{"id": "great_lake", "name_tr": "Büyük göl", "threshold": 400000.0, "text_tr": "Karşı kıyı sisin içinde kayboldu."},
]
const GAME_END_DROPS: float = 2000000.0

# Canli sayilari, asama indeksine gore.
const FISH_BY_STAGE: Array[int] = [0, 0, 2, 5, 9]
const BIRDS_BY_STAGE: Array[int] = [0, 0, 0, 3, 6]
const REEDS_FROM_STAGE: int = 2

# --- Cevrimdisi ---
const OFFLINE_MIN_SECONDS: float = 30.0
const OFFLINE_CAP_SECONDS: float = 900.0

# --- Kayit ---
const SAVE_VERSION: int = 1
# Bundan buyuk sayilar bozuk sayilir.
const SAVE_MAX_NUMBER: float = 1.0e15
