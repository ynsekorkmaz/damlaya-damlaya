extends RefCounted
## Saf ekonomi mantigi. Zaman disaridan gelir; Node, dosya ya da rastgelelik yok.

const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")


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


static func source_count(state: GameState, id: String) -> int:
	return int(state.sources.get(id, 0))


# ---------- Tasima ----------

static func tool_capacity(state: GameState) -> float:
	return Cfg.TOOLS[state.tool_level]["capacity"]


static func tool_name(state: GameState) -> String:
	return Cfg.TOOLS[state.tool_level]["name_tr"]


static func has_next_tool(state: GameState) -> bool:
	return state.tool_level + 1 < Cfg.TOOLS.size()


## Siradaki aletin maliyeti; alet kalmadiysa -1.
static func cost_tool(state: GameState) -> float:
	if not has_next_tool(state):
		return -1.0
	return Cfg.TOOLS[state.tool_level + 1]["cost"]


static func buy_tool(state: GameState) -> bool:
	var cost: float = cost_tool(state)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.tool_level += 1
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

## floor(ilkMaliyet * 1.15^adet). Bilinmeyen id ya da ust sinir icin -1.
static func cost_source(state: GameState, id: String) -> float:
	var def: Dictionary = source_def(id)
	if def.is_empty():
		return -1.0
	var count: int = source_count(state, id)
	if count >= Cfg.MAX_SOURCE_COUNT:
		return -1.0
	# Kayan nokta hatasi (100 * 1,15 = 114,999...) yuzunden eksik yuvarlanmasin diye kucuk pay eklenir.
	return floorf(float(def["base_cost"]) * pow(Cfg.SOURCE_COST_GROWTH, count) + Cfg.COST_ROUND_EPSILON)


static func buy_source(state: GameState, id: String) -> bool:
	var cost: float = cost_source(state, id)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	state.sources[id] = source_count(state, id) + 1
	return true


## Kayiptan once, damla/sn.
static func passive_rate_gross(state: GameState) -> float:
	var total: float = 0.0
	for def: Dictionary in Cfg.SOURCES:
		total += float(def["rate"]) * source_count(state, def["id"])
	return total


## Kayiptan sonra, damla/sn.
static func passive_rate_net(state: GameState) -> float:
	return passive_rate_gross(state) * (1.0 - loss_fraction(state))


# ---------- Kayip ----------

## 0..1 arasi; yalnizca pasif uretime uygulanir.
static func loss_fraction(state: GameState) -> float:
	var percent: float = Cfg.BASE_LOSS_PERCENT
	for id: String in state.loss_upgrades:
		var def: Dictionary = loss_def(id)
		if not def.is_empty():
			percent -= float(def["points"])
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


static func tool_visible(state: GameState) -> bool:
	return is_visible(state, cost_tool(state))


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
