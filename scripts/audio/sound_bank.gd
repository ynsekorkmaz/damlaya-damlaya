extends RefCounted
## Tüm sesleri koddan üretir (hazır ses dosyası yok): açılışta bir kez çalışır, sonuç AudioStreamWAV (16 bit, mono) olarak durur.
## Katalog: ad -> Array[AudioStreamWAV] (aynı adın birkaç varyasyonu olabilir). Döngü sesleri baş-son çapraz geçişiyle kesintisizdir.
## Her tampon DC'den arındırılır ve tepesi AudioConfig.NORMALIZE_PEAK'e ölçeklenir (kırpma yok); ses düzeyi çalarken verilir.

const AC = preload("res://scripts/core/audio_config.gd")

const TWO_PI: float = TAU
const LOOP_XFADE_SEC: float = 0.3

## Tek atımlık ve döngü sesleri: ad -> varyasyon sayısı. Katalog tam bu adları içerir.
const ONESHOT_VARIANTS: Dictionary = {
	"plink": 4, "full": 1, "pour_s": 2, "pour_m": 2, "pour_l": 2, "coins": 3,
	"step_grass": 5, "step_water": 4, "hammer_place": 3, "hammer_remove": 2, "tick": 2, "dull": 2,
	"purchase": 1, "unlock": 1, "fail": 1, "ui_hover": 1, "ui_click": 1,
	"panel_open": 1, "panel_close": 1, "page": 3, "stage": 1, "bird": 5,
}

var _rng := RandomNumberGenerator.new()
var _rate: float = float(AC.MIX_RATE)


func _init() -> void:
	_rng.seed = AC.SEED


## Bütün katalog. Bir kez, açılışta çağrılır.
func build_all() -> Dictionary:
	var out: Dictionary = {}
	for key: String in ONESHOT_VARIANTS:
		var list: Array = []
		for i in range(int(ONESHOT_VARIANTS[key])):
			list.append(_build_oneshot(key, i))
		out[key] = list
	out["fill_loop"] = [_loop_fill()]
	out["spring_loop"] = [_loop_spring()]
	out["canal_loop"] = [_loop_canal()]
	out["lake_loop"] = [_loop_lake()]
	out["mill_loop"] = [_loop_mill()]
	out["wind_loop"] = [_loop_wind()]
	return out


func _build_oneshot(key: String, variant: int) -> AudioStreamWAV:
	match key:
		"plink": return _finish(_plink(variant), false)
		"full": return _finish(_full(), false)
		"pour_s": return _finish(_pour(0.8 + 0.1 * variant, 700.0 + 80.0 * variant), false)
		"pour_m": return _finish(_pour(1.3 + 0.15 * variant, 600.0 + 60.0 * variant), false)
		"pour_l": return _finish(_pour(2.0 + 0.2 * variant, 500.0 + 50.0 * variant), false)
		"coins": return _finish(_coins(), false)
		"step_grass": return _finish(_step_grass(), false)
		"step_water": return _finish(_step_water(), false)
		"hammer_place": return _finish(_hammer_place(), false)
		"hammer_remove": return _finish(_hammer_remove(), false)
		"tick": return _finish(_tick(), false)
		"dull": return _finish(_dull(), false)
		"purchase": return _finish(_purchase(), false)
		"unlock": return _finish(_unlock(), false)
		"fail": return _finish(_fail(), false)
		"ui_hover": return _finish(_ui_hover(), false)
		"ui_click": return _finish(_ui_click(), false)
		"panel_open": return _finish(_swish(0.2, 450.0, 1800.0, 0.35), false)
		"panel_close": return _finish(_swish(0.2, 1600.0, 380.0, 0.35), false)
		"page": return _finish(_page(), false)
		"stage": return _finish(_stage(), false)
		"bird": return _finish(_bird(), false)
	return _finish(_zeros(256), false)


# ---------- Temel işlemler ----------

func _count(seconds: float) -> int:
	return maxi(int(seconds * _rate), 16)


func _zeros(n: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(n)
	return buf


func _noise(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(n)
	for i in range(n):
		buf[i] = _rng.randf_range(-1.0, 1.0)
	return buf


## RBJ iki kutuplu süzgeç. kind: 0 alçak geçiren, 1 yüksek geçiren, 2 bant geçiren.
func _biquad(src: PackedFloat32Array, kind: int, freq: float, q: float) -> PackedFloat32Array:
	var n: int = src.size()
	var out: PackedFloat32Array = _zeros(n)
	var w0: float = TWO_PI * clampf(freq, 20.0, _rate * 0.45) / _rate
	var cw: float = cos(w0)
	var alpha: float = sin(w0) / (2.0 * q)
	var b0: float
	var b1: float
	var b2: float
	match kind:
		0:
			b0 = (1.0 - cw) * 0.5
			b1 = 1.0 - cw
			b2 = b0
		1:
			b0 = (1.0 + cw) * 0.5
			b1 = -(1.0 + cw)
			b2 = b0
		_:
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	b0 /= a0
	b1 /= a0
	b2 /= a0
	a1 /= a0
	a2 /= a0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i in range(n):
		var x: float = src[i]
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Tek kutuplu alçak geçiren; kesim frekansı f0'dan f1'e kayar (süpürme), iki kez uygulanır.
func _sweep_lp(src: PackedFloat32Array, f0: float, f1: float) -> PackedFloat32Array:
	var n: int = src.size()
	var out: PackedFloat32Array = _zeros(n)
	var y: float = 0.0
	var z: float = 0.0
	for i in range(n):
		var f: float = lerpf(f0, f1, float(i) / float(n))
		var a: float = 1.0 - exp(-TWO_PI * f / _rate)
		y += a * (src[i] - y)
		z += a * (y - z)
		out[i] = z
	return out


## Tampona üstel sönümlü sinüs ekler (başlangıç zamanı t0 sn, frekans f0'dan f1'e kayar).
func _add_tone(buf: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, amp: float, decay: float, attack: float = 0.003) -> void:
	var start: int = int(t0 * _rate)
	var count: int = int(dur * _rate)
	var phase: float = 0.0
	for i in range(count):
		var idx: int = start + i
		if idx >= buf.size():
			break
		var t: float = float(i) / _rate
		var f: float = lerpf(f0, f1, minf(t / maxf(dur, 0.001), 1.0))
		phase += TWO_PI * f / _rate
		var env: float = exp(-t / decay) * minf(t / attack, 1.0)
		buf[idx] += sin(phase) * amp * env


## Tampona (başlangıçtan itibaren) üstel sönümlü bir gürültü atımı ekler.
func _add_burst(buf: PackedFloat32Array, t0: float, noise: PackedFloat32Array, amp: float, decay: float, attack: float = 0.002) -> void:
	var start: int = int(t0 * _rate)
	for i in range(noise.size()):
		var idx: int = start + i
		if idx >= buf.size():
			break
		var t: float = float(i) / _rate
		buf[idx] += noise[i] * amp * exp(-t / decay) * minf(t / attack, 1.0)


func _envelope(buf: PackedFloat32Array, attack: float, release: float) -> void:
	var n: int = buf.size()
	var a: int = maxi(int(attack * _rate), 1)
	var r: int = maxi(int(release * _rate), 1)
	for i in range(n):
		var g: float = minf(float(i) / float(a), 1.0) * minf(float(n - 1 - i) / float(r), 1.0)
		buf[i] *= g


func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float) -> void:
	var n: int = mini(dst.size(), src.size())
	for i in range(n):
		dst[i] += src[i] * gain


## Gürültüyü yavaş bir zarfla titreştirir: zarf = 1 - depth + depth * (süzülmüş gürültü, 0..1).
func _modulate(buf: PackedFloat32Array, mod_hz: float, depth: float) -> PackedFloat32Array:
	var n: int = buf.size()
	var slow: PackedFloat32Array = _biquad(_noise(n), 0, mod_hz, 0.7)
	var peak: float = 0.0001
	for i in range(n):
		peak = maxf(peak, absf(slow[i]))
	var out: PackedFloat32Array = _zeros(n)
	for i in range(n):
		var m: float = 0.5 + 0.5 * slow[i] / peak
		out[i] = buf[i] * (1.0 - depth + depth * m)
	return out


# ---------- Bitirme: DC, tepe, kenar yumuşatma, WAV ----------

func _finish(buf: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var n: int = buf.size()
	if not looped:
		var fade: int = mini(int(AC.EDGE_FADE_SEC * _rate), n / 2)
		for i in range(fade):
			var g: float = float(i) / float(maxi(fade, 1))
			buf[i] *= g
			buf[n - 1 - i] *= g
	var mean: float = 0.0
	for i in range(n):
		mean += buf[i]
	mean /= float(n)
	var peak: float = 0.00001
	for i in range(n):
		buf[i] -= mean
		peak = maxf(peak, absf(buf[i]))
	var scale: float = AC.NORMALIZE_PEAK / peak
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, clampi(int(roundf(buf[i] * scale * 32767.0)), -32767, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AC.MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


## Uzunluğu seconds olan kesintisiz döngü: üretici seconds + çapraz geçiş kadar uzun tampon verir, kuyruk başa karıştırılır.
func _loop(make: Callable, seconds: float) -> AudioStreamWAV:
	var n: int = _count(seconds)
	var x: int = _count(LOOP_XFADE_SEC)
	var raw: PackedFloat32Array = make.call(n + x)
	var out: PackedFloat32Array = _zeros(n)
	for i in range(n):
		if i < x:
			var w: float = float(i) / float(x)
			out[i] = raw[i] * w + raw[n + i] * (1.0 - w)
		else:
			out[i] = raw[i]
	return _finish(out, true)


# ---------- Tek atımlık sesler ----------

func _plink(variant: int) -> PackedFloat32Array:
	var base: float = 900.0 + 190.0 * float(variant) + _rng.randf_range(-40.0, 40.0)
	var buf: PackedFloat32Array = _zeros(_count(0.4))
	_add_tone(buf, 0.0, 0.4, base * 1.04, base, 1.0, 0.07, 0.002)
	_add_tone(buf, 0.0, 0.2, base * 2.76, base * 2.76, 0.18, 0.03, 0.001)
	return buf


func _full() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.6))
	_add_tone(buf, 0.0, 0.4, 660.0, 660.0, 0.8, 0.09)
	_add_tone(buf, 0.11, 0.4, 990.0, 990.0, 0.8, 0.12)
	_add_tone(buf, 0.11, 0.3, 1980.0, 1980.0, 0.12, 0.05)
	return buf


func _pour(seconds: float, center: float) -> PackedFloat32Array:
	var n: int = _count(seconds)
	var body: PackedFloat32Array = _biquad(_noise(n), 2, center, 0.6)
	body = _modulate(body, 14.0, 0.55)
	var low: PackedFloat32Array = _biquad(_noise(n), 0, 260.0, 0.7)
	_mix_into(body, low, 0.5)
	_envelope(body, 0.06, seconds * 0.45)
	# birkaç damla
	var drops: int = int(seconds * 5.0)
	for k in range(drops):
		var t: float = _rng.randf_range(0.1, seconds - 0.1)
		var f: float = _rng.randf_range(700.0, 1400.0)
		_add_tone(body, t, 0.12, f * 0.8, f * 1.3, _rng.randf_range(0.15, 0.3), 0.025, 0.002)
	return body


func _coins() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.75))
	var pings: int = _rng.randi_range(4, 6)
	for k in range(pings):
		var t: float = _rng.randf_range(0.0, 0.3)
		var f: float = _rng.randf_range(2200.0, 3400.0)
		var a: float = _rng.randf_range(0.5, 1.0)
		_add_tone(buf, t, 0.35, f, f, a, 0.08, 0.001)
		_add_tone(buf, t, 0.25, f * 1.504, f * 1.504, a * 0.5, 0.05, 0.001)
		_add_tone(buf, t, 0.15, f * 2.76, f * 2.76, a * 0.2, 0.03, 0.001)
	return buf


func _step_grass() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.18))
	var hi: PackedFloat32Array = _biquad(_noise(buf.size()), 2, _rng.randf_range(2600.0, 4200.0), 0.8)
	var lo: PackedFloat32Array = _biquad(_noise(buf.size()), 0, _rng.randf_range(500.0, 800.0), 0.7)
	_add_burst(buf, 0.0, hi, 0.9, 0.035, 0.004)
	_add_burst(buf, 0.0, lo, 0.7, 0.05, 0.003)
	_add_tone(buf, 0.0, 0.1, 100.0, 70.0, 0.5, 0.04, 0.003)
	return buf


func _step_water() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.32))
	var wash: PackedFloat32Array = _biquad(_noise(buf.size()), 0, _rng.randf_range(1500.0, 2200.0), 0.7)
	_add_burst(buf, 0.0, wash, 1.0, 0.09, 0.006)
	var f: float = _rng.randf_range(260.0, 340.0)
	_add_tone(buf, 0.02, 0.12, f, f * 2.0, 0.45, 0.06, 0.004)
	_add_tone(buf, 0.09, 0.12, f * 1.3, f * 2.4, 0.3, 0.05, 0.004)
	return buf


func _hammer_place() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.22))
	var base: float = _rng.randf_range(380.0, 460.0)
	_add_tone(buf, 0.0, 0.12, base, base * 0.42, 1.0, 0.04, 0.001)
	_add_tone(buf, 0.0, 0.08, base * 2.4, base * 2.0, 0.3, 0.02, 0.001)
	var click: PackedFloat32Array = _biquad(_noise(_count(0.03)), 2, 2400.0, 1.0)
	_add_burst(buf, 0.0, click, 0.7, 0.008, 0.0005)
	return buf


func _hammer_remove() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.34))
	var scrape: PackedFloat32Array = _biquad(_noise(buf.size()), 2, 900.0, 1.2)
	_envelope(scrape, 0.06, 0.2)
	_mix_into(buf, scrape, 0.8)
	_add_tone(buf, 0.0, 0.3, 210.0, 105.0, 0.7, 0.1, 0.004)
	var click: PackedFloat32Array = _biquad(_noise(_count(0.02)), 2, 1800.0, 1.0)
	_add_burst(buf, 0.18, click, 0.5, 0.01, 0.0005)
	return buf


func _tick() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.07))
	var click: PackedFloat32Array = _biquad(_noise(buf.size()), 2, 3000.0, 2.0)
	_add_burst(buf, 0.0, click, 1.0, 0.006, 0.0003)
	_add_tone(buf, 0.0, 0.04, 1700.0, 1500.0, 0.5, 0.01, 0.0005)
	return buf


func _dull() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.16))
	var thud: PackedFloat32Array = _biquad(_noise(buf.size()), 0, 320.0, 0.7)
	_add_burst(buf, 0.0, thud, 1.0, 0.04, 0.002)
	_add_tone(buf, 0.0, 0.1, 120.0, 90.0, 0.8, 0.045, 0.002)
	return buf


func _purchase() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.75))
	for note: Array in [[0.0, 523.25], [0.1, 783.99]]:
		var t0: float = note[0]
		var f: float = note[1]
		_add_tone(buf, t0, 0.6, f, f, 0.7, 0.2, 0.004)
		_add_tone(buf, t0, 0.4, f * 2.0, f * 2.0, 0.15, 0.1, 0.004)
		_add_tone(buf, t0, 0.3, f * 3.0, f * 3.0, 0.05, 0.06, 0.004)
	return buf


func _unlock() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(1.2))
	var notes: Array = [523.25, 659.25, 783.99, 1046.5]
	for i in range(notes.size()):
		var f: float = notes[i]
		var t0: float = 0.09 * float(i)
		_add_tone(buf, t0, 0.8, f, f, 0.6, 0.28, 0.004)
		_add_tone(buf, t0, 0.5, f * 2.0, f * 2.0, 0.12, 0.12, 0.004)
	return buf


func _fail() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.3))
	_add_tone(buf, 0.0, 0.2, 330.0, 320.0, 0.8, 0.07, 0.003)
	_add_tone(buf, 0.09, 0.22, 247.0, 235.0, 0.8, 0.08, 0.003)
	_add_tone(buf, 0.09, 0.15, 741.0, 705.0, 0.12, 0.04, 0.003)
	return buf


func _ui_hover() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.05))
	_add_tone(buf, 0.0, 0.04, 1500.0, 1500.0, 1.0, 0.008, 0.0008)
	return buf


func _ui_click() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.08))
	_add_tone(buf, 0.0, 0.06, 950.0, 760.0, 1.0, 0.012, 0.0008)
	var click: PackedFloat32Array = _biquad(_noise(_count(0.02)), 2, 2500.0, 1.0)
	_add_burst(buf, 0.0, click, 0.4, 0.004, 0.0003)
	return buf


## Süpürülen, zarflı gürültü hışırtısı (panel açma/kapama).
func _swish(seconds: float, f0: float, f1: float, depth: float) -> PackedFloat32Array:
	var n: int = _count(seconds)
	var buf: PackedFloat32Array = _sweep_lp(_noise(n), f0, f1)
	for i in range(n):
		var t: float = float(i) / float(n)
		buf[i] *= sin(PI * t) * (1.0 - depth + depth * t)
	return buf


## Sayfa çevirme: kâğıt hışırtısı (yüksek frekanslı gürültü, hızlı titreşimli zarf).
func _page() -> PackedFloat32Array:
	var seconds: float = _rng.randf_range(0.28, 0.4)
	var n: int = _count(seconds)
	var raw: PackedFloat32Array = _noise(n)
	var hp: PackedFloat32Array = _biquad(raw, 1, 2200.0, 0.7)
	var band: PackedFloat32Array = _biquad(hp, 0, 7000.0, 0.7)
	band = _modulate(band, 40.0, 0.6)
	for i in range(n):
		var t: float = float(i) / float(n)
		band[i] *= pow(sin(PI * pow(t, 0.6)), 1.5)
	return band


func _stage() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(3.2))
	var freqs: Array = [261.63, 329.63, 392.0, 493.88, 523.25]
	var amps: Array = [0.9, 0.8, 0.8, 0.5, 0.45]
	for i in range(freqs.size()):
		var f: float = freqs[i]
		var t0: float = 0.06 * float(i)
		_add_tone(buf, t0, 3.0, f, f, amps[i], 1.1, 0.25)
		_add_tone(buf, t0, 3.0, f * 1.004, f * 1.004, amps[i] * 0.6, 1.0, 0.3)
		_add_tone(buf, t0, 2.0, f * 2.0, f * 2.0, amps[i] * 0.12, 0.6, 0.3)
	return buf


func _bird() -> PackedFloat32Array:
	var buf: PackedFloat32Array = _zeros(_count(0.9))
	var chirps: int = _rng.randi_range(2, 4)
	var t: float = 0.02
	var f0: float = _rng.randf_range(2600.0, 4200.0)
	for k in range(chirps):
		var dur: float = _rng.randf_range(0.07, 0.13)
		var f1: float = f0 * _rng.randf_range(0.7, 1.45)
		var seg_n: int = int(dur * _rate)
		var phase: float = 0.0
		for i in range(seg_n):
			var idx: int = int(t * _rate) + i
			if idx >= buf.size():
				break
			var u: float = float(i) / float(seg_n)
			var f: float = lerpf(f0, f1, u)
			phase += TWO_PI * f / _rate
			var env: float = sin(PI * u)
			buf[idx] += (sin(phase) + 0.25 * sin(phase * 2.0)) * env
		t += dur + _rng.randf_range(0.05, 0.12)
		f0 = f1 * _rng.randf_range(0.9, 1.15)
	return buf


# ---------- Döngüler ----------

## Akan su gürültüsü: bant gürültü + alçak katman, hafif titreşim.
func _rush(n: int, center: float, q: float, mod_hz: float, depth: float, low_gain: float) -> PackedFloat32Array:
	var body: PackedFloat32Array = _biquad(_noise(n), 2, center, q)
	body = _modulate(body, mod_hz, depth)
	var low: PackedFloat32Array = _biquad(_noise(n), 0, center * 0.35, 0.7)
	_mix_into(body, low, low_gain)
	return body


func _loop_fill() -> AudioStreamWAV:
	return _loop(_make_fill, 1.6)


func _make_fill(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _rush(n, 1100.0, 0.7, 9.0, 0.5, 0.35)
	var bubbles: int = int(float(n) / _rate * 5.0)
	for k in range(bubbles):
		var f: float = _rng.randf_range(500.0, 1100.0)
		_add_tone(buf, _rng.randf_range(0.0, float(n) / _rate - 0.1), 0.08, f, f * 1.8, 0.35, 0.03, 0.003)
	return buf


func _loop_spring() -> AudioStreamWAV:
	return _loop(_make_spring, 3.0)


func _make_spring(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _rush(n, 1500.0, 0.6, 3.0, 0.25, 0.4)
	var sparkle: PackedFloat32Array = _biquad(_modulate(_noise(n), 6.0, 0.7), 1, 3500.0, 0.7)
	_mix_into(buf, sparkle, 0.25)
	return buf


func _loop_canal() -> AudioStreamWAV:
	return _loop(_make_canal, 3.0)


func _make_canal(n: int) -> PackedFloat32Array:
	return _rush(n, 750.0, 0.5, 2.0, 0.2, 0.5)


## 4 sn, iki salınım: zarf periyodu uzunluğun yarısı, dolayısıyla baş-son uyumlu.
func _loop_lake() -> AudioStreamWAV:
	return _loop(_make_lake, 4.0)


func _make_lake(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _biquad(_noise(n), 0, 600.0, 0.6)
	var total: float = float(n) - _rate * LOOP_XFADE_SEC
	for i in range(n):
		var ph: float = TWO_PI * float(i) / total * 2.0
		buf[i] *= 0.55 + 0.45 * sin(ph)
	return buf


func _loop_wind() -> AudioStreamWAV:
	return _loop(_make_wind, 6.0)


func _make_wind(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _biquad(_noise(n), 0, 380.0, 0.9)
	var total: float = float(n) - _rate * LOOP_XFADE_SEC
	for i in range(n):
		var ph: float = TWO_PI * float(i) / total
		buf[i] *= 0.5 + 0.3 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0 + 1.0)
	return buf


## 3,75 sn: su çarpması + her 1,25 sn'de bir gıcırtı ve tok vuruş.
func _loop_mill() -> AudioStreamWAV:
	return _loop(_make_mill, 3.75)


func _make_mill(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _rush(n, 520.0, 0.6, 2.5, 0.35, 0.6)
	var span: float = float(n) / _rate
	var t: float = 0.2
	while t < span - 0.05:
		_add_tone(buf, t, 0.5, 140.0, 205.0, 0.22, 0.45, 0.06)
		_add_tone(buf, t, 0.5, 280.0, 410.0, 0.07, 0.3, 0.06)
		var thump: PackedFloat32Array = _biquad(_noise(_count(0.15)), 0, 220.0, 0.7)
		_add_burst(buf, t + 0.55, thump, 0.9, 0.05, 0.003)
		t += 1.25
	return buf
