extends RefCounted
## Serbest yerlestirilen yapilarin kurallari: kamis, golge agaci ve pasif kaynaklar. Saf mantik.
## Tek dogruluk kaynagi state.structures; state.counts ondan turetilir (add/remove/rebuild_counts guncel tutar).
## Konum dogrulamasi (kiyi yakinligi vb.) dunya katmaninda; burada yalnizca sayi, kilit ve para vardir.

const Cfg = preload("res://scripts/core/economy_config.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")


# ---------- Katalog ----------

## Tum yapi turlerinin id'leri: once kayip yapilari, sonra pasif kaynaklar.
static func kind_ids() -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in BuildCfg.LOSS_STRUCTURES:
		out.append(String(def["id"]))
	for def: Dictionary in Cfg.SOURCES:
		out.append(String(def["id"]))
	return out


static func is_kind(kind: String) -> bool:
	return not kind_def(kind).is_empty()


static func is_source(kind: String) -> bool:
	for def: Dictionary in Cfg.SOURCES:
		if def["id"] == kind:
			return true
	return false


## Birlesik tanim: id, name_tr, desc_tr, base_cost, growth, unlock_cost, is_source, loss_points, max_effective, rate.
## Bilinmeyen tur icin {}. Her cagrida yeni sozluk uretir; yalnizca arayuz ve yerlestirme icin.
static func kind_def(kind: String) -> Dictionary:
	for def: Dictionary in BuildCfg.LOSS_STRUCTURES:
		if def["id"] == kind:
			var out: Dictionary = def.duplicate()
			out["is_source"] = false
			out["rate"] = 0.0
			return out
	for def: Dictionary in Cfg.SOURCES:
		if def["id"] == kind:
			return {
				"id": def["id"], "name_tr": def["name_tr"], "short_tr": String(def["name_tr"]).to_lower(), "desc_tr": def["desc_tr"],
				"base_cost": def["base_cost"], "growth": Cfg.SOURCE_COST_GROWTH,
				"unlock_cost": floorf(float(def["base_cost"]) * Cfg.SOURCE_UNLOCK_FRACTION + Cfg.COST_ROUND_EPSILON),
				"is_source": true, "loss_points": 0.0, "max_effective": 0, "rate": def["rate"],
			}
	return {}


# ---------- Sayim ----------

static func count(state: GameState, kind: String) -> int:
	return int(state.counts.get(kind, 0))


## Kamis ve golge agaci icin etkisi sayilan adet (tavanli); kaynaklar icin 0.
static func effective_count(state: GameState, kind: String) -> int:
	for def: Dictionary in BuildCfg.LOSS_STRUCTURES:
		if def["id"] == kind:
			return mini(count(state, kind), int(def["max_effective"]))
	return 0


## Kamis ve agaclarin toplam kayip dusurmesi (puan).
static func loss_points(state: GameState) -> float:
	var total: float = 0.0
	for def: Dictionary in BuildCfg.LOSS_STRUCTURES:
		total += float(def["loss_points"]) * mini(count(state, String(def["id"])), int(def["max_effective"]))
	return total


## state.counts'u structures'tan yeniden kurar.
static func rebuild_counts(state: GameState) -> void:
	state.counts.clear()
	for item: Dictionary in state.structures:
		var kind: String = item["kind"]
		state.counts[kind] = int(state.counts.get(kind, 0)) + 1


# ---------- Fiyat ----------

## Siradaki adedin fiyati: floor(taban * carpan^adet). Bilinmeyen tur icin -1; MAX_COST ustu MAX_COST.
static func next_cost(state: GameState, kind: String) -> float:
	return cost_at(kind, count(state, kind))


static func cost_at(kind: String, existing_count: int) -> float:
	var def: Dictionary = kind_def(kind)
	if def.is_empty():
		return -1.0
	var raw: float = float(def["base_cost"]) * pow(float(def["growth"]), existing_count)
	if is_inf(raw) or raw > BuildCfg.MAX_COST:
		return BuildCfg.MAX_COST
	# Kayan nokta hatasi (100 * 1,15 = 114,999...) yuzunden eksik yuvarlanmasin diye kucuk pay eklenir.
	return floorf(raw + Cfg.COST_ROUND_EPSILON)


# ---------- Kilit ----------

static func is_unlocked(state: GameState, kind: String) -> bool:
	if is_source(kind):
		return state.unlocked_sources.has(kind)
	return state.unlocked_structures.has(kind)


## Acilmamissa kilit maliyeti; acilmissa ya da bilinmiyorsa -1.
static func unlock_cost(state: GameState, kind: String) -> float:
	var def: Dictionary = kind_def(kind)
	if def.is_empty() or is_unlocked(state, kind):
		return -1.0
	return float(def["unlock_cost"])


static func unlock(state: GameState, kind: String) -> bool:
	var cost: float = unlock_cost(state, kind)
	if cost < 0.0 or state.money < cost:
		return false
	state.money -= cost
	if is_source(kind):
		state.unlocked_sources.append(kind)
	else:
		state.unlocked_structures.append(kind)
	return true


# ---------- Kurma ve sokme ----------

## {ok, reason_tr, cost (int), note_tr}. Kamis/agacta 7'den sonra ok kalir, yalniz note_tr dolar.
static func can_place(state: GameState, kind: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason_tr": "", "cost": -1, "note_tr": ""}
	var def: Dictionary = kind_def(kind)
	if def.is_empty():
		result["reason_tr"] = BuildCfg.REASON_UNKNOWN_TR
		return result
	var cost: float = next_cost(state, kind)
	result["cost"] = int(cost)
	if not bool(def["is_source"]) and count(state, kind) >= int(def["max_effective"]):
		result["note_tr"] = BuildCfg.NOTE_NO_EFFECT_TR
	if not state.hammer_owned:
		result["reason_tr"] = BuildCfg.REASON_NO_HAMMER_TR
	elif not is_unlocked(state, kind):
		result["reason_tr"] = BuildCfg.REASON_LOCKED_TR
	elif state.structures.size() >= BuildCfg.MAX_STRUCTURES:
		result["reason_tr"] = BuildCfg.REASON_MAX_COUNT_TR
	elif state.money < cost:
		result["reason_tr"] = BuildCfg.REASON_NO_MONEY_TR
	else:
		result["ok"] = true
	return result


## Odeme yapmadan ekler (yukleme, goc ve testler icin). Eklenen ogenin indeksini dondurur; bilinmeyen turde -1.
static func add(state: GameState, kind: String, x: float, z: float, rot: float, placed: bool = true) -> int:
	if not is_kind(kind):
		return -1
	state.structures.append({"kind": kind, "x": x if placed else 0.0, "z": z if placed else 0.0, "rot": rot if placed else 0.0, "placed": placed})
	state.counts[kind] = count(state, kind) + 1
	return state.structures.size() - 1


## Kurallar saglaniyorsa parayi dusurup yapiyi ekler. Koordinat sayisal ve sonlu olmali.
static func place(state: GameState, kind: String, x: float, z: float, rot: float) -> bool:
	if not _finite(x) or not _finite(z) or not _finite(rot):
		return false
	var check: Dictionary = can_place(state, kind)
	if not check["ok"]:
		return false
	state.money -= float(check["cost"])
	add(state, kind, x, z, rot, true)
	return true


## Yapiyi yerlestirilmis yapar (goc ile gelen yerlestirilmemis yapilara dunya katmani konum verir).
static func set_position(state: GameState, index: int, x: float, z: float, rot: float) -> bool:
	if index < 0 or index >= state.structures.size() or not _finite(x) or not _finite(z) or not _finite(rot):
		return false
	var item: Dictionary = state.structures[index]
	item["x"] = x
	item["z"] = z
	item["rot"] = rot
	item["placed"] = true
	return true


## Sokulursa verilecek iade: sokulduktan sonraki adetle hesaplanan fiyatin yarisi. Gecersiz indeks 0.
static func removal_refund(state: GameState, index: int) -> int:
	if index < 0 or index >= state.structures.size():
		return 0
	var kind: String = state.structures[index]["kind"]
	return floori(cost_at(kind, count(state, kind) - 1) * BuildCfg.REFUND_FACTOR)


## Yapiyi sokar, iadeyi paraya ekler ve dondurur. Cekic yoksa ya da indeks gecersizse 0 (hicbir sey sokulmez).
static func remove(state: GameState, index: int) -> int:
	if not state.hammer_owned or index < 0 or index >= state.structures.size():
		return 0
	var refund: int = removal_refund(state, index)
	var kind: String = state.structures[index]["kind"]
	state.structures.remove_at(index)
	var left: int = count(state, kind) - 1
	if left > 0:
		state.counts[kind] = left
	else:
		state.counts.erase(kind)
	state.money += float(refund)
	return refund


static func _finite(v: float) -> bool:
	return not is_nan(v) and not is_inf(v)
