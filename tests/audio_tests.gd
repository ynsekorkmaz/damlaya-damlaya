extends SceneTree
## Ses sistemi: üretilen tamponlar (uzunluk, hız, tepe, DC, döngü süreksizliği), config tutarlılığı, ayar kaydet/yükle,
## olay -> ses bağlantısı, ses havuzu sınırı.
## Çalıştırma: godot --headless --path . -s res://tests/audio_tests.gd

const AC = preload("res://scripts/core/audio_config.gd")
const SoundBank = preload("res://scripts/audio/sound_bank.gd")
const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")

const MAX_DC: float = 0.02
const MIN_PEAK: float = 0.5
const EDGE_MAX: float = 0.08
const LOOP_JUMP_FACTOR: float = 1.6

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	await process_frame # dugumler agaca ancak ilk karede girer
	test_config()
	var manager: Node = Node.new()
	manager.set_script(preload("res://scripts/audio/audio_manager.gd"))
	root.add_child(manager)
	var bank: Dictionary = manager.call("bank")
	test_bank(bank)
	test_events(bank)
	test_pool(manager)
	test_settings()
	manager.queue_free()
	await process_frame
	print("Kontrol: %d, basarisiz: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("BASARISIZ: ", msg)


func samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var n: int = wav.data.size() / 2
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = float(wav.data.decode_s16(i * 2)) / 32767.0
	return out


func test_config() -> void:
	check(AC.POSITIONAL_SOURCES <= 5 and AC.POSITIONAL_SOURCES >= 4, "konumlu kaynak sayisi 4-5")
	check(AC.DEFAULT_VOLUME > 0.0 and AC.DEFAULT_VOLUME <= 1.0, "varsayilan ses duzeyi aralikta")
	check(is_equal_approx(AC.DEFAULT_VOLUME, 0.6), "varsayilan ana ses 0,6")
	check(AC.NORMALIZE_PEAK > 0.0 and AC.NORMALIZE_PEAK < 1.0, "tepe 1'in altinda")
	check(AC.SFX_VOICES >= 4 and AC.UI_VOICES >= 2, "havuz yeterli ama sinirli")
	check(AC.BIRD_GAP_MIN > 0.0 and AC.BIRD_GAP_MAX >= AC.BIRD_GAP_MIN, "kus araligi tutarli")
	check(AC.STRIDE_SPRINT > AC.STRIDE_WALK and AC.STEP_MIN_SPEED < AC.SPRINT_SPEED_MIN, "adim sayilari tutarli")
	check(AC.COIN_DELAY_SEC > 0.0 and AC.FILL_HOLD_SEC > 0.0, "gecikmeler pozitif")
	check(AC.master_db(0.6, false) <= -79.0 and AC.master_db(0.0, true) <= -79.0, "kapali ya da sifir ses sessiz")
	check(absf(AC.master_db(1.0, true)) < 0.001, "tam ses 0 dB")
	check(AC.master_db(0.6, true) < 0.0 and AC.master_db(0.6, true) > -10.0, "0,6 duzeyi makul")
	check(is_equal_approx(AC.clamp_volume(0.64), 0.6) and is_equal_approx(AC.clamp_volume(5.0), 1.0) and AC.clamp_volume(-1.0) == 0.0, "ses duzeyi 10'luk adima oturur")
	check(AC.volume_percent(0.6) == 60 and AC.volume_percent(1.0) == 100, "yuzde")
	for event: String in AC.EVENTS:
		var def: Dictionary = AC.EVENTS[event]
		check(def.has("sound") and def.has("bus") and def.has("db") and def.has("pitch"), "olay alanlari: " + event)
		check(["sfx", "ui", "ambience"].has(String(def["bus"])), "olay veri yolu gecerli: " + event)
		check(float(def["db"]) <= 0.0 and float(def["pitch"]) >= 0.0 and float(def["pitch"]) < 0.5, "olay duzeyi/perdesi makul: " + event)


func test_bank(bank: Dictionary) -> void:
	for key: String in SoundBank.ONESHOT_VARIANTS:
		check(bank.has(key), "katalogda ses var: " + key)
		if bank.has(key):
			check((bank[key] as Array).size() == int(SoundBank.ONESHOT_VARIANTS[key]), "varyasyon sayisi: " + key)
	for key: String in AC.LOOPS:
		check(bank.has(key), "katalogda dongu var: " + key)
	for key: String in bank:
		for item in bank[key] as Array:
			var wav: AudioStreamWAV = item
			var s: PackedFloat32Array = samples(wav)
			var looped: bool = AC.LOOPS.has(key)
			check(s.size() > 100, "uzunluk: " + key)
			check(wav.mix_rate == AC.MIX_RATE and not wav.stereo and wav.format == AudioStreamWAV.FORMAT_16_BITS, "ornekleme hizi/bicim: " + key)
			var peak: float = 0.0
			var sum: float = 0.0
			var max_diff: float = 0.0
			for i in range(s.size()):
				peak = maxf(peak, absf(s[i]))
				sum += s[i]
				if i > 0:
					max_diff = maxf(max_diff, absf(s[i] - s[i - 1]))
			check(peak <= 1.0, "kirpma yok: " + key)
			check(peak >= MIN_PEAK and peak <= AC.NORMALIZE_PEAK + 0.001, "tepe normallesmis (%.3f): %s" % [peak, key])
			check(absf(sum / float(s.size())) < MAX_DC, "DC kaymasi kucuk: " + key)
			if looped:
				check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end == s.size(), "dongu isaretli: " + key)
				var jump: float = absf(s[0] - s[s.size() - 1])
				check(jump <= max_diff * LOOP_JUMP_FACTOR + 0.001, "dongu bas-son sureksizligi (%.3f, en buyuk komsu fark %.3f): %s" % [jump, max_diff, key])
			else:
				check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "tek atim donguye girmez: " + key)
				check(absf(s[0]) <= EDGE_MAX and absf(s[s.size() - 1]) <= EDGE_MAX, "bas/son sessiz: " + key)


func test_events(bank: Dictionary) -> void:
	for event: String in AC.EVENTS:
		var sound: String = AC.EVENTS[event]["sound"]
		check(bank.has(sound) and not (bank[sound] as Array).is_empty(), "olay '%s' sese bagli: %s" % [event, sound])
	var required: Array[String] = [
		"fill_full", "pour_small", "pour_mid", "pour_large", "coins", "step_grass", "step_water",
		"build_place", "build_remove", "build_rotate", "build_denied", "purchase", "unlock", "purchase_denied",
		"ui_hover", "ui_click", "panel_open", "panel_close", "book_open", "book_close", "stage", "bird",
	]
	for event: String in required:
		check(AC.EVENTS.has(event), "gerekli olay tanimli: " + event)


func test_pool(manager: Node) -> void:
	check(not bool(manager.call("play_event", "yok_boyle_olay")), "bilinmeyen olay false")
	for i in range(100):
		for event: String in AC.EVENTS:
			manager.call("play_event", event)
	check(int(manager.call("playing_count")) <= int(manager.call("voice_capacity")), "ayni anda calan ses havuzla sinirli")
	check(int(manager.call("positional_count")) == AC.POSITIONAL_SOURCES, "konumlu kaynak sayisi config ile ayni")
	var buses: Array[String] = [AC.BUS_MASTER, AC.BUS_SFX, AC.BUS_AMBIENCE, AC.BUS_UI]
	for b: String in buses:
		check(AudioServer.get_bus_index(b) >= 0, "veri yolu var: " + b)


func _read_settings_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(GraphicsConfig.SETTINGS_PATH):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(GraphicsConfig.SETTINGS_PATH)


func _new_settings() -> Node:
	var n := Node.new()
	n.set_script(preload("res://scripts/game/graphics_settings.gd"))
	root.add_child(n)
	return n


## Ayar dosyası gerçek kullanıcı dosyasıdır: yedeklenir, test sonunda geri konur (ya da silinir).
func test_settings() -> void:
	var existed: bool = FileAccess.file_exists(GraphicsConfig.SETTINGS_PATH)
	var backup: PackedByteArray = _read_settings_bytes()
	var dir: DirAccess = DirAccess.open("user://")
	if existed:
		dir.remove(GraphicsConfig.SETTINGS_PATH.get_file())
	var a: Node = _new_settings()
	check(bool(a.get("sound_on")) and is_equal_approx(float(a.get("volume")), 0.6), "varsayilan: ses acik, 0,6")
	a.call("set_level", 2)
	a.call("set_show_fps", true)
	a.call("set_volume", 0.3)
	a.call("set_sound_on", false)
	var b: Node = _new_settings()
	check(not bool(b.get("sound_on")), "kayitli ses kapali yuklenir")
	check(is_equal_approx(float(b.get("volume")), 0.3), "kayitli ses duzeyi yuklenir")
	check(int(b.get("level")) == 2 and bool(b.get("show_fps")), "grafik ayarlari ses yazilirken korunur")
	b.call("set_level", 1)
	var c: Node = _new_settings()
	check(is_equal_approx(float(c.get("volume")), 0.3) and not bool(c.get("sound_on")), "grafik yazilirken ses ayari korunur")
	c.call("set_volume", 7.0)
	check(is_equal_approx(float(c.get("volume")), 1.0), "ses duzeyi 1'e kirpilir")
	var text: String = FileAccess.get_file_as_string(GraphicsConfig.SETTINGS_PATH)
	var json := JSON.new()
	check(json.parse(text) == OK and json.data is Dictionary and (json.data as Dictionary).has("sound_on") and (json.data as Dictionary).has("volume") and (json.data as Dictionary).has("quality"), "dosyada ses ve grafik ayni duzende")
	for n: Node in [a, b, c]:
		n.queue_free()
	if existed:
		var f: FileAccess = FileAccess.open(GraphicsConfig.SETTINGS_PATH, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup)
			f.close()
	else:
		dir.remove(GraphicsConfig.SETTINGS_PATH.get_file())
