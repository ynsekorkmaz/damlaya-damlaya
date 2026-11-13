extends SceneTree
## Denge simulatoru testleri: belirlenimci, en iyi sure hedef araliginda, tempo olcutleri saglaniyor.
## Sayilar degisince dengeyi korur; sinirlar DENGE.md'deki hedeflerin makul toleranslisidir.

const SimCore = preload("res://tools/sim/sim_core.gd")
const BalanceSim = preload("res://tools/sim/balance_sim.gd")

const MIN_BEST_SECONDS: float = 2.0 * 3600.0 + 50.0 * 60.0 ## en iyi oyuncu bundan once bitirmemeli
const MAX_BEST_SECONDS: float = 3.0 * 3600.0 + 15.0 * 60.0
const FLOOR_SECONDS: float = 2.0 * 3600.0 + 45.0 * 60.0 ## hicbir strateji bundan once bitirmemeli
const MAX_DRY_SECONDS: float = 240.0

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	var strategies: Array = BalanceSim.strategies_for("all", -1)
	strategies.append({"name": "acgozlu w=0.5 b=0.7", "kind": "greedy", "wait_w": 0.5, "canal_bias": 0.7, "seed": 1})
	strategies.append({"name": "acgozlu w=0.1 b=1", "kind": "greedy", "wait_w": 0.1, "canal_bias": 1.0, "seed": 1})
	strategies.append({"name": "acgozlu w=1 b=0.7", "kind": "greedy", "wait_w": 1.0, "canal_bias": 0.7, "seed": 1})
	var results: Array = []
	for st: Dictionary in strategies:
		var r: Dictionary = SimCore.new().run(st)
		r["name"] = st["name"]
		results.append(r)
	test_deterministic(results)
	test_target_range(results)
	test_tempo(results)
	test_pacing(results)
	test_last_hour(results)
	test_first_line(results)
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func _find(results: Array, name: String) -> Dictionary:
	for r: Dictionary in results:
		if String(r["name"]) == name:
			return r
	return {}


## Zaman dakika cinsinden; yoksa -1.
func _min(d: Dictionary, key: String) -> float:
	if not d.has(key):
		return -1.0
	return float(d[key]) / 60.0


func _best(results: Array) -> Dictionary:
	var best: Dictionary = {}
	for r: Dictionary in results:
		if best.is_empty() or float(r["end_s"]) < float(best["end_s"]):
			best = r
	return best


func test_deterministic(results: Array) -> void:
	var a: Dictionary = _find(results, "acgozlu")
	var again: Dictionary = SimCore.new().run({"name": "acgozlu", "kind": "greedy", "wait_w": 0.5, "seed": 1})
	check(float(a["end_s"]) == float(again["end_s"]) and int(a["purchases"]) == int(again["purchases"]), "ayni strateji ayni sonuc")
	var s1: Dictionary = _find(results, "rastgele s1")
	var s1_again: Dictionary = SimCore.new().run({"name": "rastgele s1", "kind": "random", "seed": 1})
	check(float(s1["end_s"]) == float(s1_again["end_s"]), "ayni tohum ayni sonuc")
	var s2: Dictionary = _find(results, "rastgele s2")
	check(float(s1["end_s"]) != float(s2["end_s"]), "farkli tohum farkli sonuc")


func test_target_range(results: Array) -> void:
	var best: Dictionary = _best(results)
	var best_s: float = float(best["end_s"])
	print("En iyi: %s %.1f dk" % [best["name"], best_s / 60.0])
	check(bool(best["finished"]), "en iyi strateji bitirir")
	check(best_s >= MIN_BEST_SECONDS and best_s <= MAX_BEST_SECONDS, "en iyi sure 2:50..3:15 (%.1f dk, %s)" % [best_s / 60.0, best["name"]])
	for r: Dictionary in results:
		check(float(r["end_s"]) >= FLOOR_SECONDS, "%s 2:45'ten once bitirmez (%.1f dk)" % [r["name"], float(r["end_s"]) / 60.0])
	var hand: Dictionary = _find(results, "yalniz elle")
	check(float(hand["end_s"]) > 2.0 * best_s, "yalniz elle en az 2 kat yavas")
	var random_ok: bool = true
	for r: Dictionary in results:
		if String(r["name"]).begins_with("rastgele") and float(r["end_s"]) > 4.5 * 3600.0:
			random_ok = false
	check(random_ok, "makul rastgele oyuncu 4,5 saatte bitirir")


func test_tempo(results: Array) -> void:
	var best: Dictionary = _find(results, "acgozlu")
	var ms: Dictionary = best["milestones"]
	var stages: Dictionary = best["stages"]
	check(_min(ms, "first_purchase") > 0.0 and _min(ms, "first_purchase") <= 1.0, "ilk satin alma 60 sn icinde (%.2f dk)" % _min(ms, "first_purchase"))
	check(_min(ms, "tool:cup") > 0.0 and _min(ms, "tool:cup") <= 3.0, "ilk alet (tas) 3 dk icinde (%.2f dk)" % _min(ms, "tool:cup"))
	check(_min(ms, "hammer_buy") >= 7.0 and _min(ms, "hammer_buy") <= 13.0, "cekic 8-12. dk (%.2f dk)" % _min(ms, "hammer_buy"))
	check(_min(ms, "canal_unlock") >= 18.0 and _min(ms, "canal_unlock") <= 32.0, "kanal sistemi 20-30. dk (%.2f dk)" % _min(ms, "canal_unlock"))
	check(_min(stages, "pit") >= 0.75 and _min(stages, "pit") <= 2.5, "Cukur 1-2 dk (%.2f dk)" % _min(stages, "pit"))
	check(_min(stages, "pond") >= 11.0 and _min(stages, "pond") <= 19.0, "Havuz 12-18 dk (%.1f dk)" % _min(stages, "pond"))
	check(_min(stages, "lake") >= 58.0 and _min(stages, "lake") <= 82.0, "Gol 60-80 dk (%.1f dk)" % _min(stages, "lake"))
	check(_min(stages, "great_lake") >= 128.0 and _min(stages, "great_lake") <= 152.0, "Buyuk gol 130-150 dk (%.1f dk)" % _min(stages, "great_lake"))
	var order_ok: bool = _min(ms, "tool:cup") < _min(ms, "tool:bucket") and _min(ms, "tool:bucket") < _min(ms, "hammer_buy") \
		and _min(ms, "hammer_buy") < _min(ms, "canal_unlock") and _min(ms, "canal_unlock") < _min(ms, "spring:A") \
		and _min(ms, "spring:A") < _min(ms, "spring:B") and _min(ms, "spring:B") < _min(ms, "spring:C")
	check(order_ok, "siralama: tas, kova, cekic, kanal, pinar A < B < C")


func test_pacing(results: Array) -> void:
	var best: Dictionary = _best(results)
	check(float(best["max_dry_s"]) <= MAX_DRY_SECONDS, "en iyi oyuncuda alinabilir hicbir sey olmayan en uzun bekleme <= 4 dk (%.1f dk, %s)" % [float(best["max_dry_s"]) / 60.0, best["max_dry_label"]])
	var primary: Dictionary = _find(results, "acgozlu")
	check(float(primary["max_dry_s"]) <= 1.25 * MAX_DRY_SECONDS, "ana acgozlu stratejide kuru donem <= 5 dk (%.1f dk)" % (float(primary["max_dry_s"]) / 60.0))
	# Oyunun son yarim saati "her sey alindi, yalniz bekle" olmamali.
	check(int(best["last30_purchases"]) >= 5, "son 30 dk'da en az 5 alim (%d)" % int(best["last30_purchases"]))
	check(int(best["last30_new_left"]) >= 3, "son 30 dk basinda alinmamis kalici ogeler var (%d)" % int(best["last30_new_left"]))


func test_last_hour(results: Array) -> void:
	# Son saatte gelirin buyuk kismi kanal ve pasiften gelir; el ile tasima oyun boyunca sifirlanmaz.
	var best: Dictionary = _find(results, "acgozlu")
	var end_min: float = float(best["end_s"]) / 60.0
	var total: float = 0.0
	var canal: float = 0.0
	var hand: float = 0.0
	var passive: float = 0.0
	for sl: Dictionary in best["slices"]:
		if float(sl["until_min"]) >= end_min - 60.0:
			var m: float = float(sl["money_per_min"])
			total += m
			canal += m * float(sl["canal"])
			hand += m * float(sl["hand"])
			passive += m * float(sl["passive"])
	check(total > 0.0 and canal / total >= 0.5, "son saatte gelirin en az yarisi kanaldan (%.0f%%)" % (100.0 * canal / maxf(total, 1.0)))
	check(canal > passive, "son saatte kanal pasiften buyuk")
	check(hand / maxf(total, 1.0) >= 0.03 and hand / maxf(total, 1.0) <= 0.25, "el ile tasima son saatte %%3-25 (%.0f%%)" % (100.0 * hand / maxf(total, 1.0)))


func test_first_line(results: Array) -> void:
	var best: Dictionary = _find(results, "acgozlu")
	var line_min: float = float(best["first_line_s"]) / 60.0
	check(line_min >= 18.0 and line_min <= 26.0, "ilk pinar hatti 18-26. dk'da tamamlanir (%.1f dk)" % line_min)
	var ms: Dictionary = best["milestones"]
	check(float(best["first_line_s"]) - float(ms["canal_unlock"]) <= 180.0, "kilitten sonra ilk hat en cok 3 dk (%.1f dk)" % ((float(best["first_line_s"]) - float(ms["canal_unlock"])) / 60.0))
	check(float(best["jump"]) >= 3.0, "ilk hatla gelir en az 3 kat (x%.1f)" % float(best["jump"]))
	check(float(best["max_dry_mid_s"]) <= 180.0, "20-60. dk arasi en uzun kuru donem <= 3 dk (%.1f dk)" % (float(best["max_dry_mid_s"]) / 60.0))
	var rush: Dictionary = _find(results, "erken kanal")
	var ratio: float = float(rush["end_s"]) / float(_best(results)["end_s"])
	check(ratio >= 1.27 and ratio <= 1.43, "erken kanal en iyinin 1,30-1,40 kati (x%.2f)" % ratio)
	# Ilk ~20 dk yavas ve elle: 20. dk'ya kadar gelirin tamami el + ucuz pasif, kanal yok
	var early: Array = best["early2"]
	check(early.size() >= 12 and float(early[4]) < 100.0, "ilk 10 dk yavas (8-10. dk %.0f para/dk)" % float(early[4]))
