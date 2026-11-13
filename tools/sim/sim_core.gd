extends RefCounted
## Denge simulatoru cekirdegi: oyunun GERCEK mantigini (game.gd, Economy, Build, CanalNetwork/Flow) cagirir,
## formul kopyalamaz. Zaman adimlidir (STEP sn); oyuncu su tasir, Tab'dan, dukkandan ve cekicle alisveris yapar.
## Kullanim: SimCore.new().run({"kind": "greedy", "horizon": 60.0, "seed": 1}) -> sonuc sozlugu. Bkz. DENGE.md.

const Cfg = preload("res://scripts/core/economy_config.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const Config = preload("res://scripts/core/config.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const CanalNetwork = preload("res://scripts/core/canal_network.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const GameScript = preload("res://scripts/game/game.gd")

# --- Oyuncu modeli ---
const STEP: float = 0.5 ## zaman adimi (sn)
const TAB_SECONDS: float = 2.0 ## Tab ekraninda islem basina
const SHOP_SECONDS: float = 2.0 ## dukkanda islem basina (yurume ayrica)
const PIECE_SECONDS: float = 1.5 ## kanal parcasi basina kurma suresi
const STRUCT_SECONDS: float = 1.5 ## serbest yapi basina
const STRUCT_TRIP: float = 3.0 ## serbest yapi icin cukur kiyisindan yer secip donme
const CYCLE_OVERHEAD: float = 0.6 ## her tasima turunda nisan alma, donme, dokme
const FIELD_INNER_WALK: float = 20.0 ## kanal alaninda parcalar arasi dolasma (m, gidis)
const MAX_SECONDS: float = 36000.0 ## 10 saatte bitmeyen oyun "bitmedi" sayilir
const REPLAN_SECONDS: float = 120.0
const SLICE_SECONDS: float = 600.0
const BIG_MONEY: float = 1.0e12
const MEANINGFUL_PAYBACK: float = 7200.0 ## anlamli aday: geri odeme suresi bundan kisa
const MEANINGFUL_GAIN: float = 0.005 ## ve gelir artisi mevcut gelirin en az bu orani (kuru donem olcusu)

const TAB_OPS: Array[String] = ["tool_unlock", "tool_upg", "rate", "loss", "hammer_unlock", "src_unlock", "st_unlock",
	"canal_unlock", "piece_unlock", "mat_unlock", "spring", "width", "lining"]

var g: Node ## gercek oyun
var tmp: Node ## aday degerlendirme icin gecici oyun
var strat: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var t: float = 0.0
var phase: String = "fill"
var cur: Dictionary = {}
var busy: float = 0.0
var pending: Dictionary = {}
var committed: Dictionary = {}
var batch_i: int = 0
var next_replan: float = 0.0
var force_replan: bool = true
var last_allow: bool = true
var build_counter: int = 0
var cand_cache: Dictionary = {}

# --- Olcumler ---
var milestones: Dictionary = {}
var stage_times: Dictionary = {}
var purchase_times: Array[float] = []
var purchase_names: Array[String] = []
var slices: Array = []
var slice_acc: Dictionary = {}
var max_gap: float = 0.0
var max_gap_at: float = 0.0
var last_purchase_t: float = 0.0
var hand_money_total: float = 0.0
var passive_money_total: float = 0.0
var canal_money_total: float = 0.0
var new_items_at_30: Array = []
var recorded_30: bool = false
var replans: int = 0
var earned_hist: Array[float] = [] ## her adimin sonunda toplam kazanilan para
var first_line_step: int = -1
var max_dry_mid: float = 0.0 ## 20-60. dk arasi en uzun kuru donem
var min_meaningful_cost: float = 0.0 ## son planlamada alinabilir anlamli en ucuz ilk parti maliyeti
var min_meaningful_label: String = ""
var dry_run: float = 0.0
var max_dry: float = 0.0
var max_dry_at: float = 0.0
var max_dry_label: String = ""
var events: Array = [] ## tamamlanan adaylar: zaman, ad, maliyet, gelir artisi, geri odeme suresi


# =====================================================================
#  Yardimcilar
# =====================================================================

static func clone_state(s: GameState) -> GameState:
	var c: GameState = GameState.new()
	c.carried = s.carried
	c.total_drops = s.total_drops
	c.money = s.money
	c.total_money_earned = s.total_money_earned
	c.tool_level = s.tool_level
	c.tool_unlocked = s.tool_unlocked
	c.tool_upgrades = s.tool_upgrades.duplicate()
	c.rate_level = s.rate_level
	c.unlocked_sources = s.unlocked_sources.duplicate()
	c.canal_unlocked = s.canal_unlocked
	c.loss_upgrades = s.loss_upgrades.duplicate()
	c.hammer_unlocked = s.hammer_unlocked
	c.hammer_owned = s.hammer_owned
	c.unlocked_pieces = s.unlocked_pieces.duplicate()
	c.unlocked_materials = s.unlocked_materials.duplicate()
	c.unlocked_structures = s.unlocked_structures.duplicate()
	c.counts = s.counts.duplicate()
	return c


static func clone_net(n: CanalNetwork) -> CanalNetwork:
	var c: CanalNetwork = CanalNetwork.new(n.cols, n.rows, n.spring_defs)
	c.from_dict(n.to_dict())
	return c


static func spring_distance() -> float:
	return Vector2(Config.SPRING_POSITION.x, Config.SPRING_POSITION.z).length()


## Kaynaktan cukur kiyisindaki doktume noktasina bir yon yurume suresi (sn). Oyuncu kayaya FILL_REACH icinde durur.
static func haul_walk(total_drops: float) -> float:
	var r: float = BasinShape.radius(total_drops)
	var d: float = spring_distance() - r - Config.POUR_MARGIN - (Config.SPRING_RADIUS + Config.FILL_REACH)
	return maxf(d, 0.0) / Config.SPRINT_SPEED


static func shop_walk(total_drops: float) -> float:
	var r: float = BasinShape.radius(total_drops)
	var d: float = Vector2(Config.SHOP_POSITION.x, Config.SHOP_POSITION.z).length() - r - Config.POUR_MARGIN - Config.SHOP_INTERACT_RADIUS
	return maxf(d, 0.0) / Config.SPRINT_SPEED


static func field_trip(total_drops: float) -> float:
	var r: float = BasinShape.radius(total_drops)
	var to_field: float = maxf(absf(Config.CANAL_FIELD_EAST) - r - Config.POUR_MARGIN, 0.0)
	return 2.0 * (to_field + FIELD_INNER_WALK) / Config.SPRINT_SPEED


## El ile tasimanin damla/sn karsiligi (tum tur: doldur, yuru, dok, don).
static func hand_drops_per_sec(s: GameState) -> float:
	var cycle: float = Cfg.FILL_SECONDS + 2.0 * haul_walk(s.total_drops) + CYCLE_OVERHEAD
	return Economy.tool_capacity(s) / cycle


## Para/sn: el + pasif + kanal.
func income(gg: Node) -> float:
	var s: GameState = gg.state
	var drops: float = hand_drops_per_sec(s) + Economy.passive_rate_net(s) + float(gg.canal_result().get("delivered", 0.0))
	return drops / Economy.drops_per_money(s)


func income_parts(gg: Node) -> Dictionary:
	var s: GameState = gg.state
	var ratio: float = Economy.drops_per_money(s)
	return {"hand": hand_drops_per_sec(s) / ratio, "passive": Economy.passive_rate_net(s) / ratio,
		"canal": float(gg.canal_result().get("delivered", 0.0)) / ratio}


# =====================================================================
#  Islemler (op): gercek game.gd sarmalayicilarini cagirir
# =====================================================================

static func op_mode(op: Dictionary) -> String:
	var k: String = op["t"]
	if TAB_OPS.has(k):
		return "tab"
	if k == "tool_buy" or k == "hammer_buy":
		return "shop"
	if k == "build":
		return "build"
	return "cbuild"


func apply_op(gg: Node, op: Dictionary) -> bool:
	match String(op["t"]):
		"tool_unlock": return gg.unlock_tool()
		"tool_buy": return gg.buy_tool()
		"tool_upg": return gg.upgrade_tool(String(Cfg.TOOLS[int(op["i"])]["id"]))
		"rate": return gg.buy_rate()
		"loss": return gg.buy_loss(String(op["id"]))
		"hammer_unlock": return gg.unlock_hammer()
		"hammer_buy": return gg.buy_hammer()
		"src_unlock": return gg.unlock_source(String(op["id"]))
		"st_unlock": return gg.unlock_structure(String(op["id"]))
		"build":
			build_counter += 1
			return gg.place_structure(String(op["id"]), float(build_counter % 40), floorf(build_counter / 40.0), 0.0)
		"canal_unlock": return gg.unlock_canal()
		"piece_unlock": return gg.unlock_piece(String(op["id"]))
		"mat_unlock": return gg.unlock_material(String(op["id"]))
		"spring": return gg.open_spring(String(op["id"]))
		"width": return gg.upgrade_canal_width()
		"lining": return gg.upgrade_canal_lining()
		"cplace": return gg.place_canal(int(op["c"]), int(op["r"]), String(op["p"]), int(op["rot"]), String(op["m"]))
		"cremove":
			var had: bool = not gg.canal.get_piece(int(op["c"]), int(op["r"])).is_empty()
			gg.remove_canal(int(op["c"]), int(op["r"]))
			return had
	return false


func batch_duration(batch: Dictionary) -> float:
	var n: int = (batch["ops"] as Array).size()
	var drops: float = g.state.total_drops
	match String(batch["mode"]):
		"tab": return TAB_SECONDS * n
		"shop": return 2.0 * shop_walk(drops) + SHOP_SECONDS * n
		"build": return STRUCT_TRIP + STRUCT_SECONDS * n
		_: return field_trip(drops) + PIECE_SECONDS * n + TAB_SECONDS


func make_batches(ops: Array) -> Array:
	var out: Array = []
	for op: Dictionary in ops:
		var mode: String = op_mode(op)
		if (mode == "build" or mode == "cbuild") and not out.is_empty() and out.back()["mode"] == mode:
			(out.back()["ops"] as Array).append(op)
		else:
			out.append({"mode": mode, "ops": [op], "cost": 0.0})
	return out


# =====================================================================
#  Aday uretimi
# =====================================================================

func _hammer_ops() -> Array:
	var ops: Array = []
	var s: GameState = g.state
	if not s.hammer_owned:
		if not s.hammer_unlocked:
			ops.append({"t": "hammer_unlock"})
		ops.append({"t": "hammer_buy"})
	return ops


func _canal_prereq(pieces: Array, mats: Array) -> Array:
	var s: GameState = g.state
	var ops: Array = []
	ops.append_array(_hammer_ops())
	if not s.canal_unlocked:
		ops.append({"t": "canal_unlock"})
	for id: String in pieces:
		if not s.unlocked_pieces.has(id):
			ops.append({"t": "piece_unlock", "id": id})
	for id: String in mats:
		if not s.unlocked_materials.has(id):
			ops.append({"t": "mat_unlock", "id": id})
	return ops


func _row_full(net: CanalNetwork, row: int) -> bool:
	for c: int in net.cols:
		if net.get_piece(c, row).is_empty():
			return false
	return true


func _row_material(net: CanalNetwork, row: int) -> String:
	return String(net.get_piece(0, row).get("material", "earth"))


func _leak_of(mat: String) -> float:
	return float(Pieces.MATERIALS[mat]["leak"])


## Hat adaylari: bir pinar icin duz hat kurmak (gerekli kilit/pinar acma dahil).
func _line_ops(sid: String, mat: String) -> Array:
	var net: CanalNetwork = g.canal
	var row: int = int(net.spring_defs[sid]["row"])
	if _row_full(net, row):
		return []
	var ops: Array = _canal_prereq(["straight"], [mat] if mat != "earth" else [])
	if not net.is_spring_open(sid):
		ops.append({"t": "spring", "id": sid})
	for c: int in net.cols:
		if net.get_piece(c, row).is_empty():
			ops.append({"t": "cplace", "c": c, "r": row, "p": "straight", "rot": 0, "m": mat})
	return ops


func _reline_ops(sid: String, mat: String) -> Array:
	var net: CanalNetwork = g.canal
	if not net.is_spring_open(sid):
		return []
	var row: int = int(net.spring_defs[sid]["row"])
	if not _row_full(net, row) or _leak_of(mat) >= _leak_of(_row_material(net, row)) - 1.0e-9:
		return []
	var ops: Array = _canal_prereq([], [mat])
	for c: int in net.cols:
		var p: Dictionary = net.get_piece(c, row)
		if String(p["material"]) != mat:
			ops.append({"t": "cremove", "c": c, "r": row})
			ops.append({"t": "cplace", "c": c, "r": row, "p": p["piece"], "rot": p["rotation"], "m": mat})
	return ops


## Dikey cikis yiginin yonu: var olan yigin varsa o, yoksa daha cok bos satiri olan yon; yer yoksa 0.
func _stack_dir(net: CanalNetwork, row: int) -> int:
	var last: int = net.cols - 1
	for d: int in [1, -1]:
		var rr: int = row + d
		if net.in_bounds(last, rr) and String(net.get_piece(last, rr).get("piece", "")) == "straight" 				and not net.get_piece(last - 1, rr).is_empty():
			return d
	var best_d: int = 0
	var best_free: int = 0
	for d: int in [1, -1]:
		var free: int = 0
		var rr2: int = row + d
		while net.in_bounds(last, rr2) and net.get_piece(last, rr2).is_empty() and net.get_piece(last - 1, rr2).is_empty():
			free += 1
			rr2 += d
		if free > best_free:
			best_free = free
			best_d = d
	return best_d


## Ek cikisin ham islemleri (kilit/parasiz): hattin sonunda dikey yigin. Gecerli degilse bos.
func _exit_raw(net: CanalNetwork, row: int) -> Array:
	if not _row_full(net, row):
		return []
	var d: int = _stack_dir(net, row)
	if d == 0:
		return []
	var cx: int = net.cols - 2
	var ex: int = net.cols - 1
	var k: int = 0
	while net.in_bounds(ex, row + d * (k + 1)) and String(net.get_piece(ex, row + d * (k + 1)).get("piece", "")) == "straight" 			and not net.get_piece(cx, row + d * (k + 1)).is_empty():
		k += 1
	var j: int = k + 1
	var rj: int = row + d * j
	if not net.in_bounds(cx, rj) or not net.get_piece(cx, rj).is_empty() or not net.get_piece(ex, rj).is_empty():
		return []
	var ops: Array = []
	var line_mat: String = _row_material(net, row)
	if k == 0:
		ops.append({"t": "cremove", "c": cx, "r": row})
		ops.append({"t": "cplace", "c": cx, "r": row, "p": "tee", "rot": 0 if d > 0 else 2, "m": line_mat})
	else:
		ops.append({"t": "cremove", "c": cx, "r": row + d * k})
		ops.append({"t": "cplace", "c": cx, "r": row + d * k, "p": "tee", "rot": 3, "m": "earth"})
	ops.append({"t": "cplace", "c": cx, "r": rj, "p": "elbow", "rot": 2 if d > 0 else 3, "m": "earth"})
	ops.append({"t": "cplace", "c": ex, "r": rj, "p": "straight", "rot": 0, "m": "earth"})
	return ops


func _apply_raw(net: CanalNetwork, ops: Array) -> void:
	for op: Dictionary in ops:
		if String(op["t"]) == "cplace":
			net.place(int(op["c"]), int(op["r"]), String(op["p"]), int(op["rot"]), String(op["m"]))
		else:
			net.remove(int(op["c"]), int(op["r"]))


## Mevcut hatta bir ek cikis (kilitler dahil).
func _exit_ops(sid: String) -> Array:
	var net: CanalNetwork = g.canal
	if not net.is_spring_open(sid):
		return []
	var raw: Array = _exit_raw(net, int(net.spring_defs[sid]["row"]))
	if raw.is_empty():
		return []
	var ops: Array = _canal_prereq(["tee", "elbow", "straight"], [])
	ops.append_array(raw)
	return ops


## Yeni hat + k ek cikis paketi (cikislar hattin kurulmus halinde hesaplanir).
func _line_exit_ops(sid: String, mat: String, k: int) -> Array:
	var base: Array = _line_ops(sid, mat)
	if base.is_empty():
		return []
	var net: CanalNetwork = g.canal
	var work: CanalNetwork = clone_net(net)
	var row: int = int(net.spring_defs[sid]["row"])
	var raw_all: Array = []
	for op: Dictionary in base:
		if String(op["t"]) == "cplace":
			work.place(int(op["c"]), int(op["r"]), String(op["p"]), int(op["rot"]), String(op["m"]))
	for i: int in k:
		var raw: Array = _exit_raw(work, row)
		if raw.is_empty():
			return []
		_apply_raw(work, raw)
		raw_all.append_array(raw)
	var ops: Array = _canal_prereq(["tee", "elbow", "straight"], [mat] if mat != "earth" else [])
	if not net.is_spring_open(sid):
		ops.append({"t": "spring", "id": sid})
	for op: Dictionary in base:
		if String(op["t"]) == "cplace":
			ops.append(op)
	ops.append_array(raw_all)
	return ops


func _mill_ops() -> Array:
	var net: CanalNetwork = g.canal
	if net.mill_count() >= Pieces.MILL_BONUS_MAX_COUNT or net.open_springs.is_empty():
		return []
	var per: Dictionary = g.canal_result().get("per_spring", {})
	var best_id: String = ""
	var best: float = -1.0
	for id: String in per.keys():
		var a: float = float(per[id]["arrived"])
		if a > best:
			best = a
			best_id = id
	if best_id == "":
		return []
	var row: int = int(net.spring_defs[best_id]["row"])
	for c: int in [6, 5, 7, 4, 8, 3, 9]:
		var p: Dictionary = net.get_piece(c, row)
		if not p.is_empty() and String(p["piece"]) == "straight":
			var ops: Array = _canal_prereq(["mill"], [])
			ops.append({"t": "cremove", "c": c, "r": row})
			ops.append({"t": "cplace", "c": c, "r": row, "p": "mill", "rot": 0, "m": p["material"]})
			return ops
	return []


func _canal_signature() -> String:
	var s: GameState = g.state
	return "%d|%d|%d|%d|%d|%d|%d|%d" % [int(Economy.canal_section_visible(g.state)), g.canal.version, s.rate_level, int(s.canal_unlocked), int(s.hammer_owned) + 2 * int(s.hammer_unlocked),
		s.unlocked_pieces.size(), s.unlocked_materials.size(), s.tool_level]


func _gen_candidates() -> Array:
	var out: Array = []
	var s: GameState = g.state
	var allow_build: bool = bool(strat.get("build", true))
	var allow_canal: bool = bool(strat.get("canal", true))
	# El aletleri
	if Economy.has_next_tool(s):
		var ops: Array = []
		if not Economy.next_tool_unlocked(s):
			ops.append({"t": "tool_unlock"})
		ops.append({"t": "tool_buy"})
		out.append(_cand("tool:" + String(Cfg.TOOLS[s.tool_level + 1]["id"]), "hand", ops))
	if Economy.cost_tool_upgrade(s, s.tool_level) >= 0.0:
		out.append(_cand("upg:" + String(Cfg.TOOLS[s.tool_level]["id"]), "hand", [{"t": "tool_upg", "i": s.tool_level}]))
	if Economy.has_next_rate(s) and not bool(strat.get("no_rate", false)):
		out.append(_cand("rate", "rate", [{"t": "rate"}]))
	if allow_build:
		for def: Dictionary in Cfg.LOSS_UPGRADES:
			if Economy.cost_loss(s, String(def["id"])) >= 0.0:
				out.append(_cand("loss:" + String(def["id"]), "loss", [{"t": "loss", "id": def["id"]}]))
		for def: Dictionary in Cfg.SOURCES:
			var sid: String = String(def["id"])
			var ops2: Array = _hammer_ops()
			if not s.unlocked_sources.has(sid):
				ops2.append({"t": "src_unlock", "id": sid})
			ops2.append({"t": "build", "id": sid})
			out.append(_cand("src:" + sid, "passive", ops2))
		for def: Dictionary in BuildCfg.LOSS_STRUCTURES:
			var kid: String = String(def["id"])
			if Build_count(s, kid) >= int(def["max_effective"]):
				continue
			var ops3: Array = _hammer_ops()
			if not s.unlocked_structures.has(kid):
				ops3.append({"t": "st_unlock", "id": kid})
			ops3.append({"t": "build", "id": kid})
			out.append(_cand("loss_struct:" + kid, "loss", ops3))
	if allow_canal and allow_build:
		out.append_array(_canal_candidates())
	return out


static func Build_count(s: GameState, kind: String) -> int:
	return int(s.counts.get(kind, 0))


func _canal_candidates() -> Array:
	if not Economy.canal_section_visible(g.state):
		return [] # Tab'da kanal bolumu henuz gorunmuyor (CANAL_VISIBLE_DROPS)
	var sig: String = _canal_signature()
	if cand_cache.get("sig", "") == sig:
		return cand_cache["list"]
	var s: GameState = g.state
	var net: CanalNetwork = g.canal
	var out: Array = []
	for sid: String in net.spring_ids():
		for mat: String in Pieces.MATERIAL_IDS:
			var ops: Array = _line_ops(sid, mat)
			if not ops.is_empty():
				out.append(_cand("line:%s:%s" % [sid, mat], "canal", ops, true))
				for k: int in [1, 2, 3, 4, 6]:
					var xops: Array = _line_exit_ops(sid, mat, k)
					if xops.is_empty():
						break
					out.append(_cand("line:%s:%s+%d" % [sid, mat, k], "canal", xops, true))
		for mat2: String in ["wood", "stone"]:
			var rops: Array = _reline_ops(sid, mat2)
			if not rops.is_empty():
				out.append(_cand("reline:%s:%s" % [sid, mat2], "canal", rops, true))
		var eops: Array = _exit_ops(sid)
		if not eops.is_empty():
			out.append(_cand("exit:" + sid, "canal", eops, true))
	var mops: Array = _mill_ops()
	if not mops.is_empty():
		out.append(_cand("mill", "canal", mops, true))
	if not net.open_springs.is_empty():
		if net.width_cost() >= 0:
			var wops: Array = _canal_prereq([], [])
			wops.append({"t": "width"})
			out.append(_cand("width", "canal", wops, true))
		if net.lining_cost() >= 0:
			var lops: Array = _canal_prereq([], [])
			lops.append({"t": "lining"})
			out.append(_cand("lining", "canal", lops, true))
	cand_cache = {"sig": sig, "list": out}
	return out


## Adayi degerlendirir: parti maliyetleri ve gelir artisi (gecici oyunda, sonsuz parayla). Gecersizse {}.
func _cand(label: String, tag: String, ops: Array, clone_canal: bool = false) -> Dictionary:
	var c: Dictionary = {"label": label, "tag": tag, "batches": make_batches(ops), "valid": false, "cost": 0.0, "delta": 0.0, "score": 0.0}
	tmp.state = clone_state(g.state)
	tmp.state.money = BIG_MONEY
	tmp.canal = clone_net(g.canal) if clone_canal else g.canal
	var before: float = income(g)
	var total: float = 0.0
	for b: Dictionary in c["batches"]:
		var m0: float = tmp.state.money
		for op: Dictionary in b["ops"]:
			if not apply_op(tmp, op):
				return c
		b["cost"] = roundf(m0 - tmp.state.money) ## tum bedeller tam sayi; buyuk para farki kayan nokta hatasi birakir
		total += float(b["cost"])
	c["cost"] = total
	c["delta"] = income(tmp) - before
	c["score"] = float(c["delta"]) / maxf(total, 1.0)
	c["valid"] = float(c["delta"]) > 1.0e-9
	return c


# =====================================================================
#  Strateji
# =====================================================================

func _choose(cands: Array) -> Dictionary:
	var pool: Array = []
	var kind: String = String(strat.get("kind", "greedy"))
	for c: Dictionary in cands:
		if bool(c["valid"]):
			pool.append(c)
	if pool.is_empty():
		return {}
	if kind == "hand":
		pool = pool.filter(func(c: Dictionary) -> bool: return c["tag"] == "hand" or c["tag"] == "rate")
		if pool.is_empty():
			return {}
	var s: GameState = g.state
	var inc: float = maxf(income(g), 1.0e-6)
	var bias: float = float(strat.get("canal_bias", 1.0))
	if kind == "canal_rush" and not _canal_started():
		if s.tool_level >= int(strat.get("rush_tool", 2)):
			var lines: Array = pool.filter(func(c: Dictionary) -> bool: return String(c["label"]).begins_with("line:"))
			if not lines.is_empty():
				lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["cost"]) < float(b["cost"]))
				return lines[0]
		pool = pool.filter(func(c: Dictionary) -> bool: return c["tag"] == "hand" or c["tag"] == "rate")
		if pool.is_empty():
			return {}
	if kind == "canal_rush":
		bias = maxf(bias, 3.0)
		if g.canal.open_springs.size() < g.canal.spring_ids().size():
			# Hepsini birakip kanala kos: pinarlar tamamlanana kadar pasif/kayip alinmaz
			var focused: Array = pool.filter(func(c: Dictionary) -> bool: return c["tag"] != "passive" and c["tag"] != "loss" and (not String(c["label"]).begins_with("upg:") or g.state.tool_level < 2))
			if not focused.is_empty():
				pool = focused
	# Olcut: bekleme suresi * agirlik + geri odeme suresi (cookie-clicker sezgisi). Kucuk olan iyi.
	var wait_w: float = float(strat.get("wait_w", 1.0))
	var limit: float = float(strat.get("horizon", 1.0e12)) ## bundan uzun beklenecek aday elenir (yoksa en kisa bekleyen)
	var eligible: Array = []
	for c: Dictionary in pool:
		var wait: float = maxf(0.0, float(c["batches"][0]["cost"]) - s.money) / inc
		c["wait"] = wait
		var payback: float = float(c["cost"]) / maxf(float(c["delta"]), 1.0e-9)
		c["metric"] = wait_w * wait + payback / (bias if c["tag"] == "canal" else 1.0)
		if wait <= limit:
			eligible.append(c)
	if eligible.is_empty():
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["wait"]) < float(b["wait"]))
		return pool[0]
	if kind == "random":
		var best: float = 1.0e30
		for c: Dictionary in eligible:
			best = minf(best, float(c["metric"]))
		var good: Array = eligible.filter(func(c: Dictionary) -> bool: return float(c["metric"]) <= 2.0 * best)
		return good[rng.randi() % good.size()]
	var pick: Dictionary = {}
	var pick_metric: float = 1.0e30
	for c: Dictionary in eligible:
		if float(c["metric"]) < pick_metric:
			pick_metric = float(c["metric"])
			pick = c
	return pick


func _canal_started() -> bool:
	return not g.canal.open_springs.is_empty() and float(g.canal_result().get("delivered", 0.0)) > 0.0


func _replan() -> void:
	replans += 1
	var cands: Array = _gen_candidates()
	min_meaningful_cost = 1.0e30
	var inc_now: float = income(g)
	for c: Dictionary in cands:
		if bool(c["valid"]) and float(c["cost"]) / maxf(float(c["delta"]), 1.0e-9) <= MEANINGFUL_PAYBACK 				and float(c["delta"]) >= MEANINGFUL_GAIN * inc_now:
			if float(c["batches"][0]["cost"]) < min_meaningful_cost:
				min_meaningful_cost = float(c["batches"][0]["cost"])
				min_meaningful_label = String(c["label"])
	committed = _choose(cands)
	batch_i = 0
	next_replan = t + REPLAN_SECONDS
	force_replan = false


func _decide(allow_non_tab: bool) -> void:
	last_allow = allow_non_tab
	if not pending.is_empty():
		return
	if force_replan or t >= next_replan:
		_replan()
	if committed.is_empty():
		return
	var batch: Dictionary = committed["batches"][batch_i]
	if String(batch["mode"]) != "tab" and not allow_non_tab:
		return
	if g.state.money < float(batch["cost"]):
		return
	# Kanal ilk kez acilacaksa oyuncu once hat icin gereken parayi biriktirir (kilit + pinar + hat tek seferde).
	if String(batch["ops"][0]["t"]) == "canal_unlock" and g.state.money < _remaining_cost():
		return
	pending = {"kind": "batch", "batch": batch, "dur": batch_duration(batch)}


# =====================================================================
#  Ana dongu
# =====================================================================

func _haul_action(ph: String) -> Dictionary:
	var walk: float = haul_walk(g.state.total_drops) + CYCLE_OVERHEAD * 0.5
	match ph:
		"fill": return {"kind": "fill", "dur": Cfg.FILL_SECONDS}
		"walk_in": return {"kind": "walk_in", "dur": walk}
		_: return {"kind": "walk_out", "dur": walk}


func _next() -> Dictionary:
	if not pending.is_empty():
		var p: Dictionary = pending
		pending = {}
		return p
	return _haul_action(phase)


func _complete(a: Dictionary) -> void:
	match String(a["kind"]):
		"fill":
			Economy.fill(g.state, Cfg.FILL_SECONDS)
			phase = "walk_in"
		"walk_in":
			var earned: float = g.try_pour()
			hand_money_total += earned
			slice_acc["hand"] += earned
			phase = "walk_out"
			_decide(true)
		"walk_out":
			phase = "fill"
			_decide(false)
		"batch":
			_finish_batch(a["batch"])
			_decide(last_allow)


func _finish_batch(batch: Dictionary) -> void:
	for op: Dictionary in batch["ops"]:
		if not apply_op(g, op):
			if OS.get_cmdline_user_args().has("--debug"):
				print("OP BASARISIZ t=%.1f op=%s para=%.2f aday=%s" % [t, op, g.state.money, committed.get("label", "?")])
			committed = {}
			force_replan = true
			return
		_record_purchase(op)
	_record_gap()
	batch_i += 1
	if batch_i >= (committed["batches"] as Array).size():
		events.append({"t": t, "label": committed["label"], "cost": committed["cost"], "delta": committed["delta"],
			"income": income(g), "payback": float(committed["cost"]) / maxf(float(committed["delta"]), 1.0e-9)})
		committed = {}
		force_replan = true


func _op_name(op: Dictionary) -> String:
	var k: String = String(op["t"])
	match k:
		"tool_unlock": return "unlock:" + String(Cfg.TOOLS[g.state.tool_unlocked]["id"])
		"tool_buy": return "tool:" + String(Cfg.TOOLS[g.state.tool_level]["id"])
		"tool_upg": return "upg:%s:%d" % [Cfg.TOOLS[int(op["i"])]["id"], Economy.tool_upgrade_level(g.state, int(op["i"]))]
		"rate": return "rate:%d" % g.state.rate_level
		"loss", "src_unlock", "st_unlock", "piece_unlock", "mat_unlock", "spring", "build": return "%s:%s" % [k, op["id"]]
		"cplace": return "cplace:%s" % op["p"]
	return k


func _record_purchase(op: Dictionary) -> void:
	var name: String = _op_name(op)
	if String(op["t"]) == "build":
		name = "build:%s:%d" % [op["id"], Build_count(g.state, String(op["id"]))]
	if String(op["t"]) == "cremove":
		return
	purchase_times.append(t)
	purchase_names.append(name)
	if not milestones.has(name):
		milestones[name] = t
	if not milestones.has("first_purchase"):
		milestones["first_purchase"] = t
	if String(op["t"]) == "cplace" and not milestones.has("first_canal_piece"):
		milestones["first_canal_piece"] = t


func _record_gap() -> void:
	var gap: float = t - last_purchase_t
	if gap > max_gap:
		max_gap = gap
		max_gap_at = t
	last_purchase_t = t


## Alinabilecek (modellenen) kalici ogeler: bitince "her sey alindi" sayilir.
func remaining_items(gg: Node) -> Array:
	var out: Array = []
	var s: GameState = gg.state
	for i: int in Cfg.TOOLS.size():
		if i > s.tool_unlocked:
			out.append("kilit:" + String(Cfg.TOOLS[i]["id"]))
		if i > s.tool_level:
			out.append("alet:" + String(Cfg.TOOLS[i]["id"]))
		elif Economy.cost_tool_upgrade(s, i) >= 0.0:
			out.append("kapasite:%s(%d/%d)" % [Cfg.TOOLS[i]["id"], Economy.tool_upgrade_level(s, i), Cfg.TOOL_UPGRADE_MAX_LEVEL])
	if s.rate_level + 1 < Cfg.RATE_LEVELS.size():
		out.append("oran:%d/%d" % [s.rate_level, Cfg.RATE_LEVELS.size() - 1])
	for def: Dictionary in Cfg.LOSS_UPGRADES:
		if Economy.cost_loss(s, String(def["id"])) >= 0.0:
			out.append("kayip:" + String(def["id"]))
	if not s.hammer_owned:
		out.append("cekic")
	for def: Dictionary in Cfg.SOURCES:
		if not s.unlocked_sources.has(String(def["id"])):
			out.append("kaynak_kilit:" + String(def["id"]))
	for def: Dictionary in BuildCfg.LOSS_STRUCTURES:
		if not s.unlocked_structures.has(String(def["id"])):
			out.append("yapi_kilit:" + String(def["id"]))
		if Build_count(s, String(def["id"])) < int(def["max_effective"]):
			out.append("yapi:%s(%d/%d)" % [def["id"], Build_count(s, String(def["id"])), def["max_effective"]])
	if not s.canal_unlocked:
		out.append("kanal_kilit")
	for sid: String in gg.canal.spring_ids():
		if not gg.canal.is_spring_open(sid):
			out.append("pinar:" + sid)
	for id: String in ["tee", "elbow", "mill"]:
		if not s.unlocked_pieces.has(id):
			out.append("parca:" + id)
	for id: String in ["wood", "stone"]:
		if not s.unlocked_materials.has(id):
			out.append("malzeme:" + id)
	if gg.canal.width_level < Pieces.WIDTH_MAX_LEVEL:
		out.append("genislik:%d/%d" % [gg.canal.width_level, Pieces.WIDTH_MAX_LEVEL])
	if gg.canal.lining_level < Pieces.LINING_MAX_LEVEL:
		out.append("kaplama:%d/%d" % [gg.canal.lining_level, Pieces.LINING_MAX_LEVEL])
	if gg.canal.mill_count() < Pieces.MILL_BONUS_MAX_COUNT:
		out.append("degirmen:%d/%d" % [gg.canal.mill_count(), Pieces.MILL_BONUS_MAX_COUNT])
	return out


func _new_slice() -> Dictionary:
	return {"hand": 0.0, "passive": 0.0, "canal": 0.0}


func _flush_slice(minute_end: float) -> void:
	var total: float = float(slice_acc["hand"]) + float(slice_acc["passive"]) + float(slice_acc["canal"])
	var span_min: float = SLICE_SECONDS / 60.0
	slices.append({"until_min": minute_end, "money_per_min": total / span_min,
		"hand": float(slice_acc["hand"]) / maxf(total, 1.0e-9), "passive": float(slice_acc["passive"]) / maxf(total, 1.0e-9),
		"canal": float(slice_acc["canal"]) / maxf(total, 1.0e-9), "drops": g.state.total_drops})
	slice_acc = _new_slice()


func run(p_strat: Dictionary) -> Dictionary:
	strat = p_strat
	rng.seed = int(strat.get("seed", 1))
	g = GameScript.new()
	g.setup(false)
	tmp = GameScript.new()
	tmp.setup(false)
	slice_acc = _new_slice()
	cur = _haul_action("fill")
	busy = float(cur["dur"])
	var last_stage: int = 0
	var next_slice: float = SLICE_SECONDS
	var s: GameState = g.state
	while t < MAX_SECONDS and not Economy.is_finished(s):
		var delivered: float = float(g.canal_result().get("delivered", 0.0))
		var ratio: float = Economy.drops_per_money(s)
		slice_acc["passive"] += Economy.passive_rate_net(s) * STEP / ratio
		slice_acc["canal"] += delivered * STEP / ratio
		passive_money_total += Economy.passive_rate_net(s) * STEP / ratio
		canal_money_total += delivered * STEP / ratio
		Economy.tick(s, STEP, delivered)
		t += STEP
		busy -= STEP
		if s.money < min_meaningful_cost:
			dry_run += STEP
			if t >= 1200.0 and t <= 3600.0:
				max_dry_mid = maxf(max_dry_mid, dry_run)
			if dry_run > max_dry:
				max_dry = dry_run
				max_dry_at = t
				max_dry_label = min_meaningful_label
		else:
			dry_run = 0.0
		earned_hist.append(s.total_money_earned)
		if first_line_step < 0 and float(g.canal_result().get("delivered", 0.0)) > 0.0:
			first_line_step = earned_hist.size() - 1
		var stage: int = Economy.stage_index(s)
		if stage != last_stage:
			last_stage = stage
			stage_times[String(Cfg.STAGES[stage]["id"])] = t
		if t >= next_slice:
			_flush_slice(next_slice / 60.0)
			next_slice += SLICE_SECONDS
		var guard: int = 0
		while busy <= 0.0 and guard < 50:
			guard += 1
			_complete(cur)
			cur = _next()
			busy += float(cur["dur"])
	var finished: bool = Economy.is_finished(s)
	var end_t: float = t
	if not finished:
		# bitmediyse mevcut hizla tahmin
		var rate_drops: float = maxf(income(g) * Economy.drops_per_money(s), 1.0e-6)
		end_t = t + (Cfg.GAME_END_DROPS - s.total_drops) / rate_drops
	var result: Dictionary = {
		"strategy": String(strat.get("name", strat.get("kind", "?"))), "seed": int(strat.get("seed", 1)),
		"end_s": end_t, "finished": finished, "milestones": milestones, "stages": stage_times, "slices": slices,
		"max_gap_s": max_gap, "max_gap_at_s": max_gap_at, "early2": early_income(), "max_dry_s": max_dry, "max_dry_mid_s": max_dry_mid, "first_line_s": first_line_time(), "jump": jump_ratio(), "max_dry_at_s": max_dry_at, "max_dry_label": max_dry_label, "purchases": purchase_times.size(),
		"unbought": remaining_items(g), "replans": replans, "events": events,
		"hand_money": hand_money_total, "passive_money": passive_money_total, "canal_money": canal_money_total,
		"last30_purchases": 0, "last30_new_left": new_items_left_at(end_t - 1800.0),
	}
	var n30: int = 0
	for pt: float in purchase_times:
		if pt >= end_t - 1800.0:
			n30 += 1
	result["last30_purchases"] = n30
	g.free()
	tmp.free()
	return result


## end_t - 30 dk aninda kalan ogeler yaklasik olarak: kalan ogeler listesi, alim zamanlarindan geri kurulur.
## Basit tahmin: sonda kalanlar + son 30 dk'da alinan benzersiz (yapi olmayan) ogeler.
func new_items_left_at(at: float) -> int:
	var left: int = remaining_items(g).size()
	for i: int in purchase_times.size():
		if purchase_times[i] >= at:
			var n: String = purchase_names[i]
			if not n.begins_with("build:") and not n.begins_with("cplace"):
				left += 1
	return left


## Ilk pinar hattinin gelir verdigi an (sn); yoksa -1.
func first_line_time() -> float:
	return -1.0 if first_line_step < 0 else float(first_line_step + 1) * STEP


## Ilk hat devreye girince gelir sicramasi: sonraki 2 dk ortalama geliri / onceki 2 dk ortalama geliri; hesaplanamazsa 0.
func jump_ratio() -> float:
	var w: int = int(120.0 / STEP)
	if first_line_step < w or first_line_step + w >= earned_hist.size():
		return 0.0
	var before: float = earned_hist[first_line_step] - earned_hist[first_line_step - w]
	var after: float = earned_hist[first_line_step + w] - earned_hist[first_line_step]
	return after / maxf(before, 1.0e-9)


## Adayin henuz odenmemis partilerinin toplam maliyeti.
func _remaining_cost() -> float:
	var total: float = 0.0
	for i: int in range(batch_i, (committed["batches"] as Array).size()):
		total += float(committed["batches"][i]["cost"])
	return total


## Ilk 30 dakikanin 2 dakikalik dilimlerinde para/dk (kazanilan para).
func early_income() -> Array:
	var out: Array = []
	var w: int = int(120.0 / STEP)
	for k: int in 15:
		var hi: int = (k + 1) * w - 1
		var lo: int = k * w - 1
		if hi >= earned_hist.size():
			break
		var a: float = earned_hist[lo] if lo >= 0 else 0.0
		out.append((earned_hist[hi] - a) / 2.0)
	return out
