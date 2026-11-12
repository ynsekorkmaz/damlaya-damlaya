extends SceneTree
## Sayi bicimi testleri. Calistirma: godot --headless --path . -s res://tests/format_tests.gd

const NumberFormat = preload("res://scripts/core/number_format.gd")

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	_int_cases()
	_money_cases()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(label: String, actual: String, expected: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("BASARISIZ %s: beklenen '%s', gelen '%s'" % [label, expected, actual])


func _int_cases() -> void:
	var cases: Array = [
		[0.0, "0"], [1.0, "1"], [999.0, "999"], [1000.0, "1.000"], [1234.0, "1.234"],
		[999999.0, "999.999"], [1000000.0, "1 Mn"], [1230000.0, "1,23 Mn"],
		[1500000.0, "1,5 Mn"], [2000000.0, "2 Mn"], [999999.6, "1 Mn"],
		[999999999.0, "1 Mr"], [2.0e9, "2 Mr"], [3.25e12, "3,25 Tr"],
		[5.0e15, "5.000 Tr"], [-5.0, "0"], [NAN, "0"], [INF, "0"], [-INF, "0"],
		[0.4, "0"],
	]
	for c: Array in cases:
		_expect("int(%s)" % str(c[0]), NumberFormat.format_int(c[0]), c[1])


func _money_cases() -> void:
	var cases: Array = [
		[0.0, "0"], [0.4, "0,4"], [0.04, "0"], [1.0, "1"], [2.5, "2,5"], [3.0, "3"],
		[12.34, "12,3"], [999.0, "999"], [999.96, "1.000"], [1000.0, "1.000"],
		[1234.5, "1.235"], [1500000.0, "1,5 Mn"], [2.0e9, "2 Mr"], [3.25e12, "3,25 Tr"],
		[-1.0, "0"], [NAN, "0"], [INF, "0"],
	]
	for c: Array in cases:
		_expect("money(%s)" % str(c[0]), NumberFormat.format_money(c[0]), c[1])
