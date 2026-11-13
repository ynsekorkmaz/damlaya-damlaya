extends RefCounted
## Oyunun degisen durumu. Yalnizca veri tutar; kurallar economy.gd ve build.gd'de.

const Pieces = preload("res://scripts/core/canal_pieces.gd")

var carried: float = 0.0 ## Elde tasinan damla
var total_drops: float = 0.0 ## Gole ulasan toplam damla, hic azalmaz
var money: float = 0.0
var total_money_earned: float = 0.0 ## Hic azalmaz; gorunurluk icin
var tool_level: int = 0
var tool_unlocked: int = 0 ## Kilidi acik en yuksek alet indeksi (>= tool_level)
var tool_upgrades: Dictionary = {} ## alet id -> kapasite yukseltme seviyesi (int)
var rate_level: int = 0
var unlocked_sources: Array[String] = [] ## kilidi acilmis pasif kaynak id'leri
var canal_unlocked: bool = false
var loss_upgrades: Array[String] = [] ## alinan tek seferlik kayip yukseltmesi id'leri
var last_seen_unix: int = 0 ## 0 = hic kaydedilmemis

# Cekic: dukkandaki alet siralamasindan bagimsiz.
var hammer_unlocked: bool = false
var hammer_owned: bool = false

# Kanal parca turu ve malzeme kilitleri (acma maliyeti 0 olanlar bastan acik).
var unlocked_pieces: Array[String] = []
var unlocked_materials: Array[String] = []

# Serbest yerlestirilen yapilar. Oge: {kind: String, x: float, z: float, rot: float, placed: bool}.
# placed=false: konumu henuz verilmemis (eski kayit gocunden); dunya katmani bunlari bir yere dizer.
var structures: Array[Dictionary] = []
var unlocked_structures: Array[String] = [] ## kilidi acilmis kamis/golge agaci turleri
## TURETILMIS: tur -> adet (kaynaklar dahil). structures'tan Build.rebuild_counts ile kurulur, elle degistirilmez.
var counts: Dictionary = {}


func _init() -> void:
	for id: String in Pieces.PIECE_IDS:
		if int(Pieces.PIECES[id]["unlock_cost"]) <= 0:
			unlocked_pieces.append(id)
	for id: String in Pieces.MATERIAL_IDS:
		if int(Pieces.MATERIALS[id]["unlock_cost"]) <= 0:
			unlocked_materials.append(id)
