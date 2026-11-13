extends RefCounted
## Ekonominin tum sayilari ve Turkce metinleri. Denge ayari yalnizca buradan yapilir.
## Her ogenin "id"si degismez anahtardir (kayit ve ceviri icin), "name_tr" gorunen addir.

# --- Tasima ---
const FILL_SECONDS: float = 1.5

# Sirayla alinir. cost: dukkanda satin alma parasi (kilit aciksa), unlock_cost: Gelistirmeler'de kilit acma parasi,
# upgrade_cost: kapasite yukseltmesinin taban maliyeti.
const TOOLS: Array[Dictionary] = [
	{"id": "palm", "name_tr": "Avuç", "desc_tr": "Çıplak ellerin.", "capacity": 5.0, "cost": 0.0, "unlock_cost": 0.0, "upgrade_cost": 5.0},
	{"id": "cup", "name_tr": "Tas", "desc_tr": "Avuçtan çok daha fazla su alır.", "capacity": 12.0, "cost": 10.0, "unlock_cost": 6.0, "upgrade_cost": 8.0},
	{"id": "bucket", "name_tr": "Kova", "desc_tr": "Tek elde taşınan sağlam bir kova.", "capacity": 30.0, "cost": 60.0, "unlock_cost": 40.0, "upgrade_cost": 40.0},
	{"id": "double_bucket", "name_tr": "Çift kova", "desc_tr": "İki elde birer kova; denge de iyi.", "capacity": 120.0, "cost": 1200.0, "unlock_cost": 700.0, "upgrade_cost": 600.0},
	{"id": "yoke", "name_tr": "Sırık ve dört kova", "desc_tr": "Omuzda sırık, uçlarda sarkan kovalar.", "capacity": 300.0, "cost": 15000.0, "unlock_cost": 8000.0, "upgrade_cost": 8000.0},
]

# --- Alet kilidi ve kapasite yukseltmesi ---
# Kilitler sirayla acilir (Gelistirmeler ekrani); kilit acilmadan alet dukkanda alinamaz.
const TOOL_UPGRADE_MAX_LEVEL: int = 5
const TOOL_UPGRADE_CAPACITY_STEP: float = 0.2 ## Her seviye taban kapasitenin bu kadari kadar artirir
const TOOL_UPGRADE_COST_GROWTH: float = 1.8 ## maliyet = upgrade_cost * carpan^seviye

# --- Para ---
# Seviye i: drops_per_money damla = 1 para. cost: BU seviyeye gecmenin parasi (seviye 0 bedava).
const RATE_LEVELS: Array[Dictionary] = [
	{"drops_per_money": 5.0, "cost": 0.0},
	{"drops_per_money": 4.0, "cost": 100.0},
	{"drops_per_money": 3.0, "cost": 5000.0},
	{"drops_per_money": 2.0, "cost": 50000.0},
	{"drops_per_money": 1.0, "cost": 450000.0},
]
const RATE_NAME_TR: String = "Dönüşüm oranı"

# --- Pasif kaynaklar ---
# Her adet cekicle kurulan bir yapidir (build.gd); adet maliyeti floor(base_cost * 1,15^adet).
const SOURCE_COST_GROWTH: float = 1.3
const COST_ROUND_EPSILON: float = 1.0e-6

# Kaynak kilidi: ilk maliyetin bu orani (asagi yuvarlanir). Kilit acilmadan yapi kurulamaz.
const SOURCE_UNLOCK_FRACTION: float = 0.5

const SOURCES: Array[Dictionary] = [
	{"id": "crack", "name_tr": "Çatlak", "desc_tr": "Kayadaki ince bir sızıntı.", "rate": 0.5, "base_cost": 15.0},
	{"id": "dew", "name_tr": "Çiğ otu", "desc_tr": "Sabah otlardan süzülen damlalar.", "rate": 3.0, "base_cost": 100.0},
	{"id": "rain_cloud", "name_tr": "Bulut direği", "desc_tr": "Vadiye küçük bir yağmur getirir.", "rate": 20.0, "base_cost": 7000.0},
	{"id": "spring", "name_tr": "Çeşme", "desc_tr": "Toprağın altından fışkıran taze su.", "rate": 100.0, "base_cost": 110000.0},
	{"id": "stream_mouth", "name_tr": "Dere ağzı", "desc_tr": "Yamaçtan inen bir dere göle bağlanır.", "rate": 240.0, "base_cost": 700000.0},
]

# --- Kayip ---
# Pasif uretimin tabani yuzde 30'u sizar. Yukseltmeler ve yapilar (kamis, golge agaci: build_config.gd) puan (yuzde birimi) dusurur.
# Tum kalemlerle: 30 - 8 - 5 - 7 - 7 = 3.
const BASE_LOSS_PERCENT: float = 30.0
const MIN_LOSS_PERCENT: float = 0.0

const LOSS_UPGRADES: Array[Dictionary] = [
	{"id": "rock_bed", "name_tr": "Kaya yatağı", "desc_tr": "Çukurun tabanına taş döşenir.", "cost": 200.0, "points": 8.0},
	{"id": "clay_floor", "name_tr": "Kil taban", "desc_tr": "Kil toprak suyu tutar.", "cost": 40000.0, "points": 5.0},
]

# --- Kanal (parca, malzeme, pinar ve yukseltme fiyatlari canal_pieces.gd'de) ---
const CANAL_UNLOCK_COST: float = 300.0
const CANAL_VISIBLE_DROPS: float = 2000.0 ## Kanal bolumu toplam damla bu degere ulasinca gorunur
const CANAL_NAME_TR: String = "Kanal sistemi"
const CANAL_DESC_TR: String = "Pınarlardan göle su taşıyan kanallar döşenebilir."
const CANAL_SPRING_NAME_TR: String = "Pınar"
const CANAL_SPRING_DESC_TR: String = "Kanala su veren bir pınar açılır."
const CANAL_WIDTH_NAME_TR: String = "Geniş kanal"
const CANAL_WIDTH_DESC_TR: String = "Kanal daha çok su taşır."
const CANAL_LINING_NAME_TR: String = "Taş kaplama"
const CANAL_LINING_DESC_TR: String = "Kanaldan sızan su azalır."

# --- Gorunurluk ---
# Oyuncunun toplam kazandigi para maliyetin bu orani olunca oge gorunur.
const VISIBLE_COST_FRACTION: float = 0.5

# --- Asamalar ---
const STAGES: Array[Dictionary] = [
	{"id": "drop", "name_tr": "Damla", "threshold": 0.0, "text_tr": "Yerde tek bir damla var."},
	{"id": "pit", "name_tr": "Çukur", "threshold": 50.0, "text_tr": "Toprakta küçük bir çukur açıldı."},
	{"id": "pond", "name_tr": "Havuz", "threshold": 4000.0, "text_tr": "Artık bir havuz. Kenarında kamışlar bitti, balıklar geldi."},
	{"id": "lake", "name_tr": "Göl", "threshold": 200000.0, "text_tr": "Damlaya damlaya göl oldu. Kuşlar kondu."},
	{"id": "great_lake", "name_tr": "Büyük göl", "threshold": 3500000.0, "text_tr": "Karşı kıyı sisin içinde kayboldu."},
]
const GAME_END_DROPS: float = 9000000.0

# Canli sayilari, asama indeksine gore.
const FISH_BY_STAGE: Array[int] = [0, 0, 2, 5, 9]
const BIRDS_BY_STAGE: Array[int] = [0, 0, 0, 3, 6]
const REEDS_FROM_STAGE: int = 2

# --- Cevrimdisi ---
const OFFLINE_MIN_SECONDS: float = 30.0
const OFFLINE_CAP_SECONDS: float = 900.0

# --- Kayit ---
const SAVE_VERSION: int = 3
# Bundan buyuk sayilar bozuk sayilir.
const SAVE_MAX_NUMBER: float = 1.0e15
