extends RefCounted
## Oyunun degisen durumu. Yalnizca veri tutar; kurallar economy.gd'de.

var carried: float = 0.0 ## Elde tasinan damla
var total_drops: float = 0.0 ## Gole ulasan toplam damla, hic azalmaz
var money: float = 0.0
var total_money_earned: float = 0.0 ## Hic azalmaz; gorunurluk icin
var tool_level: int = 0
var tool_unlocked: int = 0 ## Kilidi acik en yuksek alet indeksi (>= tool_level)
var tool_upgrades: Dictionary = {} ## alet id -> kapasite yukseltme seviyesi (int)
var rate_level: int = 0
var sources: Dictionary = {} ## kaynak id -> sahip olunan adet (int)
var unlocked_sources: Array[String] = [] ## kilidi acilmis pasif kaynak id'leri
var canal_unlocked: bool = false
var loss_upgrades: Array[String] = [] ## alinan kayip yukseltmesi id'leri
var last_seen_unix: int = 0 ## 0 = hic kaydedilmemis
