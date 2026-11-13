extends RefCounted
## Saf ekonomi mantigi. Zaman disaridan gelir; Node, dosya ya da rastgelelik yok.

const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Build = preload("res://scripts/core/build.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")


# ---------- Arama yardimcilari ----------

static func source_def(id: String) -> Dictionary:
	for def: Dictionary in Cfg.SOURCES:
		if def["id"] == id:
			return def
	return {}


static func loss_def(id: String) -> Dictionary:
	for def: Dictionary in Cfg.LOSS_UPGRADES:
		if def["id"] == id:
			return def
	return {}


## Kurulu (ve goc ile gelen yerlestirilmemis) kaynak adedi; structures'tan turetilir.
static func source_count(state: GameState, id: String) -> int:
	return Build.count(state, id)


# ---------- Tasima ----------

## Alet indeksi icin yukseltmeli kapasite.
static func tool_capacity_at(state: GameState, index: int) -> float:
	return tool_capacity_for(index, tool_upgrade_level(state, index))


## Alet indeksi ve yükseltme seviyesi için kapasite: taban * (1 + 0,2 * seviye).
static func tool_capacity_for(index: int, level: int) -> float:
	return float(Cfg.TOOLS[index]["capacity"]) * (1.0 + Cfg.TOOL_UPGRADE_CAPACITY_STEP * level)


static func tool_capacity(state: GameState) -> float:
	return tool_capacity_at(state, state.tool_level)


static func tool_name(state: GameState) -> String:
	return Cfg.TOOLS[state.tool_level]["name_tr"]


static func tool_index(id: String) -> int:
	for i: int in Cfg.TOOLS.size():
		if Cfg.TOOLS[i]["id"] == id:
			return i
	return -1


static func has_next_tool(state: GameState) -> bool:
	return state.tool_level + 1 < Cfg.TOOLS.size()


## Siradaki aletin dukkan maliyeti; alet kalmadiysa -1. Kilit acik mi bakmaz (bkz. next_tool_unlocked).
static func cost_tool(state: GameState) -> float:
	if not has_next_tool(state):
		return -1.0
	return Cfg.TOOLS[state.tool_level + 1]["cost"]


## Siradaki aletin kilidi Gelistirmeler'den acilmis mi.
static func next_tool_unlocked(state: GameState) -> bool:
	return has_next_tool(state) and state.tool_level + 1 <= state.tool_unlocked


## Dukkanda satin alma: yalnizca kilidi acik siradaki alet.
static func buy_tool(state: GameState) -> bool:
	var cost: float = cost_tool(state)
	if cost < 0.0 or not next_tool_unlocked(state) or state.money < cost:
		return false
	state.money -= cost
	state.tool_level += 1
	return true


static func is_tool_unlocked(state: GameState, index: int) -> bool:
	return index >= 0 and index <= state.tool_unlocked


static func is_tool_owned(state: GameState, index: int) -> bool:
	return index >= 0 and index <= state.tool_level


## Siradaki kilitli aletin kilit maliyeti; kalmadiysa -1.
static func cost_tool_unlock(state: GameState) -> float:
	if state.tool_unlocked + 1 >= Cfg.TOOLS.size():
		return -1.0
	return Cfg.TOOLS[state.tool_unlocked + 1]["unlock_cost"]


static func unlock_tool(state: GameState) -> bool:
	var cost: float = cost_tool_unlock(state)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.tool_unlocked += 1
	return true


static func tool_upgrade_level(state: GameState, index: int) -> int:
	return int(state.tool_upgrades.get(Cfg.TOOLS[index]["id"], 0))


## Kapasite yukseltmesinin maliyeti; sahip olunmayan alet, ust seviye ya da gecersiz indeks icin -1.
static func cost_tool_upgrade(state: GameState, index: int) -> float:
	if index < 0 or index >= Cfg.TOOLS.size() or not is_tool_owned(state, index):
		return -1.0
	var level: int = tool_upgrade_level(state, index)
	if level >= Cfg.TOOL_UPGRADE_MAX_LEVEL:
		return -1.0
	return floorf(float(Cfg.TOOLS[index]["upgrade_cost"]) * pow(Cfg.TOOL_UPGRADE_COST_GROWTH, level) + Cfg.COST_ROUND_EPSILON)


static func upgrade_tool(state: GameState, index: int) -> bool:
	var cost: float = cost_tool_upgrade(state, index)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.tool_upgrades[Cfg.TOOLS[index]["id"]] = tool_upgrade_level(state, index) + 1
	return true


## Genel odeme: yeterse duser ve true doner (kanal gibi dis maliyetler icin).
static func spend(state: GameState, cost: float) -> bool:
	if cost < 0.0 or is_nan(cost) or state.money < cost:
		return false
	state.money -= cost
	return true


## Kaynakta doldururken cagrilir. Eklenen miktari dondurur.
static func fill(state: GameState, delta: float) -> float:
	if not (delta > 0.0):
		return 0.0
	var capacity: float = tool_capacity(state)
	var room: float = maxf(capacity - state.carried, 0.0)
	var added: float = minf(capacity / Cfg.FILL_SECONDS * delta, room)
	state.carried += added
	return added


## Eldeki suyun hepsini gole doker. Kazanilan parayi dondurur.
static func pour(state: GameState) -> float:
	if state.carried <= 0.0:
		return 0.0
	var drops: float = state.carried
	state.carried = 0.0
	return add_drops(state, drops)


# ---------- Para ----------

static func drops_per_money(state: GameState) -> float:
	return Cfg.RATE_LEVELS[state.rate_level]["drops_per_money"]


## Gole ulasan damlayi toplama ekler ve o anki oranla paraya cevirir. Kazanilan parayi dondurur.
static func add_drops(state: GameState, drops: float) -> float:
	if not (drops > 0.0) or is_inf(drops):
		return 0.0
	var earned: float = drops / drops_per_money(state)
	state.total_drops += drops
	state.money += earned
	state.total_money_earned += earned
	return earned


static func has_next_rate(state: GameState) -> bool:
	return state.rate_level + 1 < Cfg.RATE_LEVELS.size()


static func cost_rate(state: GameState) -> float:
	if not has_next_rate(state):
		return -1.0
	return Cfg.RATE_LEVELS[state.rate_level + 1]["cost"]


static func buy_rate(state: GameState) -> bool:
	var cost: float = cost_rate(state)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.rate_level += 1
	return true


# ---------- Pasif kaynaklar ----------

## Siradaki adedin fiyati: floor(ilkMaliyet * 1.15^adet). Bilinmeyen id icin -1.
static func cost_source(state: GameState, id: String) -> float:
	if source_def(id).is_empty():
		return -1.0
	return Build.next_cost(state, id)


static func source_unlocked(state: GameState, id: String) -> bool:
	return state.unlocked_sources.has(id)


## floor(ilkMaliyet * 0.5); acilmissa ya da bilinmiyorsa -1.
static func cost_source_unlock(state: GameState, id: String) -> float:
	if source_def(id).is_empty():
		return -1.0
	return Build.unlock_cost(state, id)


static func unlock_source(state: GameState, id: String) -> bool:
	if source_def(id).is_empty():
		return false
	return Build.unlock(state, id)


## Kayiptan once, damla/sn.
static func passive_rate_gross(state: GameState) -> float:
	var total: float = 0.0
	for def: Dictionary in Cfg.SOURCES:
		total += float(def["rate"]) * source_count(state, def["id"])
	return total


## Kayiptan sonra, damla/sn.
static func passive_rate_net(state: GameState) -> float:
	return passive_rate_gross(state) * (1.0 - loss_fraction(state))


# ---------- Kanal ----------

## Acilmamissa kilit maliyeti, acilmissa -1.
static func cost_canal_unlock(state: GameState) -> float:
	if state.canal_unlocked:
		return -1.0
	return Cfg.CANAL_UNLOCK_COST


static func unlock_canal(state: GameState) -> bool:
	var cost: float = cost_canal_unlock(state)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.canal_unlocked = true
	return true


## Kanal bolumu: kilit acikken ya da toplam damla esige ulasinca gorunur.
static func canal_section_visible(state: GameState) -> bool:
	return state.canal_unlocked or state.total_drops >= Cfg.CANAL_VISIBLE_DROPS


## Kanal parcasi kilidi: acilmissa ya da bilinmiyorsa -1.
static func cost_piece_unlock(state: GameState, id: String) -> float:
	if not Pieces.has_piece(id) or state.unlocked_pieces.has(id):
		return -1.0
	return float(Pieces.PIECES[id]["unlock_cost"])


static func piece_unlocked(state: GameState, id: String) -> bool:
	return state.unlocked_pieces.has(id)


static func unlock_piece(state: GameState, id: String) -> bool:
	var cost: float = cost_piece_unlock(state, id)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.unlocked_pieces.append(id)
	return true


static func cost_material_unlock(state: GameState, id: String) -> float:
	if not Pieces.has_material(id) or state.unlocked_materials.has(id):
		return -1.0
	return float(Pieces.MATERIALS[id]["unlock_cost"])


static func material_unlocked(state: GameState, id: String) -> bool:
	return state.unlocked_materials.has(id)


static func unlock_material(state: GameState, id: String) -> bool:
	var cost: float = cost_material_unlock(state, id)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.unlocked_materials.append(id)
	return true


## Gelistirmeler'de parca/malzeme satiri: acik ya da kilit maliyeti gorunur (acma maliyeti 0 olanlar listelenmez).
static func piece_row_visible(state: GameState, id: String) -> bool:
	if not Pieces.has_piece(id) or int(Pieces.PIECES[id]["unlock_cost"]) <= 0:
		return false
	return piece_unlocked(state, id) or is_visible(state, cost_piece_unlock(state, id))


static func material_row_visible(state: GameState, id: String) -> bool:
	if not Pieces.has_material(id) or int(Pieces.MATERIALS[id]["unlock_cost"]) <= 0:
		return false
	return material_unlocked(state, id) or is_visible(state, cost_material_unlock(state, id))


# ---------- Cekic ----------

## Acilmamissa kilit maliyeti, acilmissa -1.
static func cost_hammer_unlock(state: GameState) -> float:
	if state.hammer_unlocked:
		return -1.0
	return BuildCfg.HAMMER_UNLOCK_COST


static func unlock_hammer(state: GameState) -> bool:
	var cost: float = cost_hammer_unlock(state)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.hammer_unlocked = true
	return true


## Dukkan fiyati; zaten alinmissa -1. Kilit acik mi bakmaz.
static func cost_hammer(state: GameState) -> float:
	if state.hammer_owned:
		return -1.0
	return BuildCfg.HAMMER_COST


## Dukkanda satin alma: yalnizca kilidi acik cekic.
static func buy_hammer(state: GameState) -> bool:
	var cost: float = cost_hammer(state)
	if cost < 0.0 or not state.hammer_unlocked or state.money < cost:
		return false
	state.money -= cost
	state.hammer_owned = true
	return true


## Gelistirmeler'de cekic satiri: kilidi acik ya da kilit maliyeti gorunur.
static func hammer_row_visible(state: GameState) -> bool:
	return state.hammer_unlocked or is_visible(state, cost_hammer_unlock(state))


## Dukkanda cekic satiri: alinmis ya da dukkan fiyati gorunur.
static func hammer_shop_visible(state: GameState) -> bool:
	return state.hammer_owned or is_visible(state, cost_hammer(state))


# ---------- Kayip ----------

## 0..1 arasi; yalnizca pasif uretime uygulanir. Tek seferlik yukseltmeler + kamis/golge agaci yapilari (7'şer tavanli).
static func loss_fraction(state: GameState) -> float:
	var percent: float = Cfg.BASE_LOSS_PERCENT
	for id: String in state.loss_upgrades:
		var def: Dictionary = loss_def(id)
		if not def.is_empty():
			percent -= float(def["points"])
	percent -= Build.loss_points(state)
	return maxf(percent, Cfg.MIN_LOSS_PERCENT) / 100.0


static func has_loss_upgrade(state: GameState, id: String) -> bool:
	return state.loss_upgrades.has(id)


## Alinmissa ya da bilinmiyorsa -1.
static func cost_loss(state: GameState, id: String) -> float:
	var def: Dictionary = loss_def(id)
	if def.is_empty() or has_loss_upgrade(state, id):
		return -1.0
	return def["cost"]


static func buy_loss(state: GameState, id: String) -> bool:
	var cost: float = cost_loss(state, id)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.loss_upgrades.append(id)
	return true


# ---------- Ilerleme ----------

## Pasif uretim (kayip sonrasi) + kanal teslimati kadar damlayi gole ekler. Eklenen damlayi dondurur.
## Hizlar sabit kabul edilir, bu yuzden buyuk delta da dogru calisir.
static func tick(state: GameState, delta: float, canal_delivered_per_sec: float) -> float:
	if not (delta > 0.0) or is_inf(delta):
		return 0.0
	var canal: float = 0.0
	if canal_delivered_per_sec > 0.0 and not is_inf(canal_delivered_per_sec):
		canal = canal_delivered_per_sec
	var drops: float = (passive_rate_net(state) + canal) * delta
	add_drops(state, drops)
	return drops


# ---------- Asamalar ----------

static func stage_index(state: GameState) -> int:
	var index: int = 0
	for i: int in Cfg.STAGES.size():
		if state.total_drops >= float(Cfg.STAGES[i]["threshold"]):
			index = i
	return index


static func stage_def(state: GameState) -> Dictionary:
	return Cfg.STAGES[stage_index(state)]


## Asama icindeki ilerleme, 0..1; log(1+toplam) uzerinden. Son asama GAME_END_DROPS'a dogru ilerler.
static func stage_progress(state: GameState) -> float:
	var index: int = stage_index(state)
	var low: float = Cfg.STAGES[index]["threshold"]
	var high: float = Cfg.GAME_END_DROPS
	if index + 1 < Cfg.STAGES.size():
		high = Cfg.STAGES[index + 1]["threshold"]
	var span: float = log(1.0 + high) - log(1.0 + low)
	if span <= 0.0:
		return 1.0
	return clampf((log(1.0 + state.total_drops) - log(1.0 + low)) / span, 0.0, 1.0)


## Tum oyun boyunca golun doluluğu, 0..1; surekli, tekduze. Son asama esiginde 1 olur ve orada kalir.
static func lake_fill(state: GameState) -> float:
	var top: float = Cfg.STAGES[Cfg.STAGES.size() - 1]["threshold"]
	return clampf(log(1.0 + state.total_drops) / log(1.0 + top), 0.0, 1.0)


static func is_finished(state: GameState) -> bool:
	return state.total_drops >= Cfg.GAME_END_DROPS


# ---------- Canlilar ----------

static func fish_count(state: GameState) -> int:
	return Cfg.FISH_BY_STAGE[stage_index(state)]


static func bird_count(state: GameState) -> int:
	return Cfg.BIRDS_BY_STAGE[stage_index(state)]


static func reeds_visible(state: GameState) -> bool:
	return stage_index(state) >= Cfg.REEDS_FROM_STAGE


# ---------- Gorunurluk ----------

## Toplam kazanilan para maliyetin yarisina ulasinca gorunur. Maliyet < 0 (alinamaz) ise gorunmez.
static func is_visible(state: GameState, cost: float) -> bool:
	return cost >= 0.0 and state.total_money_earned >= cost * Cfg.VISIBLE_COST_FRACTION


## Dukkanda gosterilecek siradaki alet.
static func tool_visible(state: GameState) -> bool:
	return is_visible(state, cost_tool(state))


## Gelistirmeler'de alet satiri: sahip olunan (Avuc icin ilk seviye maliyeti gorunurse), kilidi acik ya da
## kilidi gorunur olan siradaki kilitli alet.
static func tool_row_visible(state: GameState, index: int) -> bool:
	if index < 0 or index >= Cfg.TOOLS.size():
		return false
	if is_tool_owned(state, index):
		if index == 0 and tool_upgrade_level(state, 0) == 0:
			return is_visible(state, cost_tool_upgrade(state, 0))
		return true
	if is_tool_unlocked(state, index):
		return true
	return index == state.tool_unlocked + 1 and is_visible(state, cost_tool_unlock(state))


static func rate_row_visible(state: GameState) -> bool:
	return state.rate_level > 0 or rate_visible(state)


## Kaynak satiri: kilidi acik ya da kilit maliyeti gorunur.
static func source_row_visible(state: GameState, id: String) -> bool:
	if source_def(id).is_empty():
		return false
	return source_unlocked(state, id) or is_visible(state, cost_source_unlock(state, id))


## Kamis / golge agaci satiri: kilidi acik ya da kilit maliyeti gorunur.
static func structure_row_visible(state: GameState, kind: String) -> bool:
	if not Build.is_kind(kind):
		return false
	return Build.is_unlocked(state, kind) or is_visible(state, Build.unlock_cost(state, kind))


static func rate_visible(state: GameState) -> bool:
	return is_visible(state, cost_rate(state))


static func source_visible(state: GameState, id: String) -> bool:
	return is_visible(state, cost_source(state, id))


static func loss_visible(state: GameState, id: String) -> bool:
	return is_visible(state, cost_loss(state, id))


# ---------- Cevrimdisi ----------

## Gecen sure < OFFLINE_MIN_SECONDS ise 0 (last_seen degismez). Aksi halde en fazla OFFLINE_CAP_SECONDS
## kadar uretim eklenir ve last_seen_unix = now olur. Saat geri alinmissa 0 ve last_seen = now.
## last_seen_unix 0 ise (hic kaydedilmemis) yalnizca last_seen ayarlanir.
static func apply_offline(state: GameState, now_unix: int, canal_delivered_per_sec: float = 0.0) -> float:
	if state.last_seen_unix <= 0:
		state.last_seen_unix = now_unix
		return 0.0
	var elapsed: float = float(now_unix - state.last_seen_unix)
	if elapsed < 0.0:
		state.last_seen_unix = now_unix
		return 0.0
	if elapsed < Cfg.OFFLINE_MIN_SECONDS:
		return 0.0
	state.last_seen_unix = now_unix
	return tick(state, minf(elapsed, Cfg.OFFLINE_CAP_SECONDS), canal_delivered_per_sec)
