extends SceneTree
## Grafik ön ayar tablosu tutarlılık testi.
## Çalıştırma: godot --headless --path . -s res://tests/graphics_tests.gd

const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	_table_cases()
	_ordering_cases()
	_helper_cases()
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(label: String, ok: bool) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("BASARISIZ ", label)


func _table_cases() -> void:
	_expect("on ayar sayisi", GraphicsConfig.PRESETS.size() == GraphicsConfig.LEVEL_COUNT)
	_expect("isim sayisi", GraphicsConfig.LEVEL_NAMES.size() == GraphicsConfig.LEVEL_COUNT)
	for level: int in range(GraphicsConfig.PRESETS.size()):
		var p: Dictionary = GraphicsConfig.PRESETS[level]
		for key: String in GraphicsConfig.BOUNDS:
			_expect("seviye %d anahtar yok: %s" % [level, key], p.has(key))
			if not p.has(key):
				continue
			var range_pair: Array = GraphicsConfig.BOUNDS[key]
			var v: float = float(p[key])
			_expect("seviye %d %s sinir disi: %s" % [level, key, str(p[key])], v >= float(range_pair[0]) and v <= float(range_pair[1]))
		for key: String in p:
			_expect("seviye %d bilinmeyen anahtar: %s" % [level, key], GraphicsConfig.BOUNDS.has(key))
		var atlas: int = int(p["shadow_atlas"])
		_expect("seviye %d atlas ikinin kuvveti" % level, atlas > 0 and (atlas & (atlas - 1)) == 0)
		_expect("seviye %d kademe sayisi 1/2/4" % level, [1, 2, 4].has(int(p["shadow_splits"])))
		_expect("seviye %d msaa 0/2/4" % level, [0, 2, 4].has(int(p["msaa"])))
		_expect("seviye %d split sirali" % level,
			float(p["shadow_split_1"]) <= float(p["shadow_split_2"]) and float(p["shadow_split_2"]) <= float(p["shadow_split_3"]))
		if bool(p["shadows"]):
			_expect("seviye %d golge mesafesi > 0" % level, float(p["shadow_distance"]) > 0.0)


## Düşük < Orta < Yüksek: gölge/efekt yalnızca yukarı çıkar.
func _ordering_cases() -> void:
	var low: Dictionary = GraphicsConfig.preset(GraphicsConfig.LOW)
	var med: Dictionary = GraphicsConfig.preset(GraphicsConfig.MEDIUM)
	var high: Dictionary = GraphicsConfig.preset(GraphicsConfig.HIGH)
	_expect("dusukte golge yok", not bool(low["shadows"]))
	_expect("dusukte efekt yok", not (bool(low["ssao"]) or bool(low["glow"]) or bool(low["fog"]) or bool(low["volumetric_fog"])))
	_expect("dusukte msaa yok", int(low["msaa"]) == 0 and not bool(low["fxaa"]))
	_expect("ortada golge var", bool(med["shadows"]))
	_expect("yuksekte kademe >= orta", int(high["shadow_splits"]) >= int(med["shadow_splits"]))
	_expect("yuksekte mesafe >= orta", float(high["shadow_distance"]) >= float(med["shadow_distance"]))
	_expect("2k doku yalniz yuksekte", int(low["terrain_tex_k"]) == 1 and int(med["terrain_tex_k"]) == 1 and int(high["terrain_tex_k"]) == 2)
	_expect("normal haritasi dusukte kapali", float(low["terrain_normal"]) == 0.0 and float(med["terrain_normal"]) > 0.0)
	_expect("varsayilan orta", GraphicsConfig.DEFAULT_LEVEL == GraphicsConfig.MEDIUM)
	_expect("hedef fps dusuk >= orta", int(low["target_fps"]) >= int(med["target_fps"]))


func _helper_cases() -> void:
	_expect("clamp alt", GraphicsConfig.clamp_level(-3) == 0)
	_expect("clamp ust", GraphicsConfig.clamp_level(9) == GraphicsConfig.LEVEL_COUNT - 1)
	_expect("arg low", GraphicsConfig.level_from_arg("low") == 0)
	_expect("arg medium buyuk harf", GraphicsConfig.level_from_arg(" MEDIUM ") == 1)
	_expect("arg high", GraphicsConfig.level_from_arg("high") == 2)
	_expect("arg bilinmeyen", GraphicsConfig.level_from_arg("ultra") == -1)
