extends RefCounted
## Cekic ve serbest yerlestirilen yapilarin (kamis, golge agaci, pasif kaynaklar) sayilari ve Turkce metinleri.
## Pasif kaynaklarin uretim ve maliyet sayilari economy_config.gd SOURCES'ta kalir; burada yalniz katalog birlestirilir.

# --- Cekic ---
const HAMMER_NAME_TR: String = "Çekiç"
const HAMMER_DESC_TR: String = "Dünyaya kanal, değirmen, ağaç ve su kaynağı kurar."
const HAMMER_UNLOCK_COST: float = 40.0 ## Gelistirmeler'de kilit acma parasi
const HAMMER_COST: float = 60.0 ## Dukkanda satin alma parasi

# --- Kayip azaltan yapilar ---
# Her biri kaybi loss_points puan dusurur; en fazla max_effective tanesi sayilir (fazlasi kurulabilir, etkisizdir).
# Maliyet: floor(base_cost * growth^adet). unlock_cost: Gelistirmeler'de kilit acma parasi.
const LOSS_STRUCTURES: Array[Dictionary] = [
	{"id": "reeds", "name_tr": "Kamış öbeği", "short_tr": "kamış", "desc_tr": "Göl kıyısına dikilir; kıyıdan sızmayı keser.",
		"base_cost": 60.0, "growth": 1.5, "unlock_cost": 300.0, "loss_points": 1.0, "max_effective": 7},
	{"id": "shade_tree", "name_tr": "Gölge ağacı", "short_tr": "gölge ağacı", "desc_tr": "Gölgede daha az buharlaşır.",
		"base_cost": 700.0, "growth": 1.5, "unlock_cost": 3000.0, "loss_points": 1.0, "max_effective": 7},
]

# --- Genel sinirlar ---
const MAX_STRUCTURES: int = 2000 ## Kayitta ve oyunda en fazla yapi
const REFUND_FACTOR: float = 0.5 ## Sokunce, sokulduktan sonraki adetle hesaplanan fiyatin bu kadari geri verilir
const MAX_COST: float = 1.0e15 ## Bundan buyuk maliyet "alinamaz" sayilir (tasmayi onler)

# Gecici (eski kayit gocu): eski tek seferlik kayip yukseltmelerinin id'leri ve yerlerini alan yapilar.
const LEGACY_LOSS_MIGRATION: Dictionary = {"reed_edge": "reeds", "shade_trees": "shade_tree"}
const LEGACY_LOSS_MIGRATION_COUNT: int = 7

# --- Metinler (oyuncuya gorunur) ---
const REASON_NO_HAMMER_TR: String = "Önce dükkândan bir çekiç al"
const REASON_LOCKED_TR: String = "Önce Geliştirmeler'den (Tab) kilidini aç"
const REASON_CANAL_LOCKED_TR: String = "Önce Geliştirmeler'den (Tab) kanal sistemini aç"
const REASON_NO_MONEY_TR: String = "Paran yetmiyor"
const REASON_MAX_COUNT_TR: String = "Daha fazla yapı kurulamaz"
const REASON_UNKNOWN_TR: String = "Bilinmeyen yapı"
const REASON_UNKNOWN_PIECE_TR: String = "Bilinmeyen kanal parçası"
const REASON_UNKNOWN_MATERIAL_TR: String = "Bilinmeyen malzeme"
const REASON_OUT_OF_BOUNDS_TR: String = "Burası kanal döşemeye uygun değil"
const REASON_OCCUPIED_TR: String = "Bu hücre dolu"
const NOTE_NO_EFFECT_TR: String = "Daha fazlası kaybı azaltmaz"
const NOTE_BUILD_HINT_TR: String = "Çekiçle kurulur (Q)"

# --- Serbest yapi yer kurali metinleri (dunya katmani) ---
const REASON_OUT_OF_VALLEY_TR: String = "Vadinin dışına kurulmaz"
const REASON_IN_CANAL_FIELD_TR: String = "Kanal alanına kurulmaz"
const REASON_NEAR_SHOP_TR: String = "Dükkânın yanına kurulmaz"
const REASON_NEAR_SPRING_ROCK_TR: String = "Kaynak kayasının yanına kurulmaz"
const REASON_IN_LAKE_TR: String = "Göl suyunun içine kurulmaz"
const REASON_REEDS_SHORE_TR: String = "Kamış, göl kıyısına yakın dikilir"
const REASON_TOO_CLOSE_TR: String = "Başka bir yapıya çok yakın"
const REASON_TREE_OUTSIDE_LAKE_TR: String = "Ağaç, gölün en geniş kıyısının dışına dikilir"
const REASON_TREE_CLOSE_TR: String = "Başka bir ağaca en az 3 m uzak olmalı"
const REASON_CRACK_ROCK_TR: String = "Çatlak bir kayaya açılır; bir kayaya bak"
const REASON_STREAM_EDGE_TR: String = "Dere ağzı vadi kenarına yakın olmalı"
