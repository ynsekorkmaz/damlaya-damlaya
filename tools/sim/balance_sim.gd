extends SceneTree
## Denge simulatoru (basiz). Calistirma:
##   godot --headless --path <proje> -s res://tools/sim/balance_sim.gd -- [--strategy=all|greedy|variants|hand|rush|random] [--seed=N] [--verbose]
## Cikti: insan okur tablo + son satirda makine okur JSON ("SIM_JSON ...").

const SimCore = preload("res://tools/sim/sim_core.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")

const MILESTONE_KEYS: Array[String] = ["first_purchase", "unlock:cup", "tool:cup", "tool:bucket", "hammer_unlock", "hammer_buy",
	"canal_unlock", "spring:A", "spring:B", "spring:C", "rate:1", "rate:2", "rate:3", "rate:4", "tool:double_bucket", "tool:yoke",
	"piece_unlock:tee", "mat_unlock:wood", "mat_unlock:stone", "piece_unlock:mill"]


func _init() -> void:
	var args: Array = []
	var which: String = "all"
	var seed_arg: int = -1
	var verbose: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--strategy="):
			which = a.substr(11)
		elif a.begins_with("--seed="):
			seed_arg = int(a.substr(7))
		elif a == "--verbose":
			verbose = true
	var strategies: Array = strategies_for(which, seed_arg)
	var results: Array = []
	var t0: int = Time.get_ticks_msec()
	for st: Dictionary in strategies:
		var r: Dictionary = SimCore.new().run(st)
		r["name"] = st["name"]
		results.append(r)
		if verbose:
			print_detail(r)
	print_table(results)
	var best: Dictionary = best_of(results)
	print("SIM_JSON ", JSON.stringify(summary(results, best)))
	print("Sure: %.1f sn" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


static func strategies_for(which: String, seed_arg: int) -> Array:
	var out: Array = []
	var seeds: Array = [1, 2, 3, 4, 5] if seed_arg < 0 else [seed_arg]
	if which == "all" or which == "greedy":
		out.append({"name": "acgozlu", "kind": "greedy", "wait_w": 0.5, "seed": 1})
	if which == "variants":
		for w: float in [0.1, 0.25, 0.5, 1.0, 2.0, 4.0]:
			for b: float in [0.7, 1.0, 1.5]:
				out.append({"name": "acgozlu w=%.1f b=%d" % [w, int(b)], "kind": "greedy", "wait_w": w, "canal_bias": b, "seed": 1})
		for h: float in [60.0, 600.0]:
			out.append({"name": "acgozlu ufuk=%d" % int(h), "kind": "greedy", "horizon": h, "seed": 1})
	if which == "extra":
		out.append({"name": "kanalsiz", "kind": "greedy", "wait_w": 0.5, "canal": false, "seed": 1})
		out.append({"name": "oran yok", "kind": "greedy", "wait_w": 0.5, "no_rate": true, "seed": 1})
		out.append({"name": "yalniz pasif", "kind": "greedy", "wait_w": 0.5, "canal": false, "no_rate": true, "seed": 1})
	if which == "all" or which == "hand":
		out.append({"name": "yalniz elle", "kind": "hand", "build": false, "canal": false, "seed": 1})
	if which == "all" or which == "rush":
		out.append({"name": "erken kanal", "kind": "canal_rush", "wait_w": 1.0, "seed": 1})
	if which == "all" or which == "random":
		for sd: int in seeds:
			out.append({"name": "rastgele s%d" % sd, "kind": "random", "seed": sd})
	return out


static func best_of(results: Array) -> Dictionary:
	var best: Dictionary = {}
	for r: Dictionary in results:
		if String(r["name"]) == "yalniz elle":
			continue
		if best.is_empty() or float(r["end_s"]) < float(best["end_s"]):
			best = r
	return best


static func fmt_time(sec: float) -> String:
	var m: int = int(sec / 60.0)
	return "%d:%02d:%02d" % [m / 60, m % 60, int(sec) % 60]


static func mm(sec: Variant) -> String:
	if sec == null:
		return "   -  "
	return "%6.1f" % (float(sec) / 60.0)


static func print_table(results: Array) -> void:
	print("")
	print("Strateji            | Bitis      | Alim | Alim arasi (dk) | Kuru (dk) | Son30 alim | Son30 kalan | Elle%  Pasif% Kanal%")
	for r: Dictionary in results:
		var tot: float = float(r["hand_money"]) + float(r["passive_money"]) + float(r["canal_money"])
		print("%-19s | %s%s | %4d | %6.1f (@%5.1f)  | %5.1f@%5.1f | %4d       | %4d        | %5.1f %5.1f %5.1f" % [
			r["name"], fmt_time(float(r["end_s"])), "" if bool(r["finished"]) else "*", int(r["purchases"]),
			float(r["max_gap_s"]) / 60.0, float(r["max_gap_at_s"]) / 60.0, float(r["max_dry_s"]) / 60.0, float(r["max_dry_at_s"]) / 60.0, int(r["last30_purchases"]), int(r["last30_new_left"]),
			100.0 * float(r["hand_money"]) / maxf(tot, 1.0), 100.0 * float(r["passive_money"]) / maxf(tot, 1.0), 100.0 * float(r["canal_money"]) / maxf(tot, 1.0)])
	print("(* = 10 saatte bitmedi, mevcut hizla tahmin)")


static func print_detail(r: Dictionary) -> void:
	print("--- %s ---" % r["name"])
	var ms: Dictionary = r["milestones"]
	for k: String in ms.keys():
		if k.begins_with("build:") and not k.ends_with(":1"):
			continue
		print("  %-28s %s dk" % [k, mm(ms[k]).strip_edges()])
	print("  asamalar: ", r["stages"])
	for sl: Dictionary in r["slices"]:
		print("  dilim %5.0f dk: %9.0f para/dk  elle %3.0f%% pasif %3.0f%% kanal %3.0f%%  toplam damla %9.0f" % [float(sl["until_min"]), float(sl["money_per_min"]),
			100.0 * float(sl["hand"]), 100.0 * float(sl["passive"]), 100.0 * float(sl["canal"]), float(sl["drops"])])
	print("  kalan: ", r["unbought"])
	print("  en uzun kuru donem: %.1f dk @ %.1f dk, en ucuz anlamli: %s" % [float(r["max_dry_s"]) / 60.0, float(r["max_dry_at_s"]) / 60.0, r["max_dry_label"]])
	if OS.get_cmdline_user_args().has("--events"):
		for e: Dictionary in r["events"]:
			print("  @%6.1f dk %-22s maliyet %10.0f  +%8.3f para/sn  geri odeme %7.1f dk  gelir %8.2f/sn" % [float(e["t"]) / 60.0, e["label"],
				float(e["cost"]), float(e["delta"]), float(e["payback"]) / 60.0, float(e["income"])])


static func summary(results: Array, best: Dictionary) -> Dictionary:
	var rows: Array = []
	for r: Dictionary in results:
		rows.append({"name": r["name"], "end_s": snappedf(float(r["end_s"]), 0.1), "finished": r["finished"], "purchases": r["purchases"],
			"max_gap_s": r["max_gap_s"], "max_dry_s": r["max_dry_s"], "last30_purchases": r["last30_purchases"]})
	var out: Dictionary = {"results": rows}
	if not best.is_empty():
		out["best"] = best["name"]
		out["best_end_s"] = best["end_s"]
		out["milestones"] = best["milestones"]
		out["stages"] = best["stages"]
		out["slices"] = best["slices"]
		out["unbought"] = best["unbought"]
	return out
