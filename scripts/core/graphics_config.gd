extends RefCounted
## Grafik kalite ön ayarları (saf veri). Düşük = 0, Orta = 1, Yüksek = 2.
## Sayısal anahtarlar Godot sabitlerinin değerleridir; açıklamalar yanlarında.
## Uygulama: scripts/game/graphics_settings.gd. Tutarlılık testi: tests/graphics_tests.gd.

const Config = preload("res://scripts/core/config.gd")

const LOW: int = 0
const MEDIUM: int = 1
const HIGH: int = 2
const DEFAULT_LEVEL: int = MEDIUM
const LEVEL_COUNT: int = 3
const LEVEL_NAMES: Array[String] = ["Düşük", "Orta", "Yüksek"]
const LEVEL_ARGS: Array[String] = ["low", "medium", "high"]

const SETTINGS_PATH: String = "user://settings.json"
const SETTINGS_TMP_PATH: String = "user://settings.json.tmp"

# Orta/Yüksek: gökyüzü ortamına karışan sıcak renk
const AMBIENT_TINT := Color(0.80, 0.74, 0.64)

# Derinlik sisi rengi (uzak tepeleri gökyüzüne yaklaştırır)
# Ten rengi çarpanı: kırmızı kanal tam, yeşil ve mavi gain ile daha çok düşer
const SKIN_WARMTH := Vector2(0.94, 0.88)

const FOG_COLOR := Color(0.66, 0.76, 0.88)

## Anahtar -> [en az, en çok]; test bunu kullanır. bool anahtarlar 0/1 sayılır.
const BOUNDS: Dictionary = {
	"shadows": [0, 1],
	"shadow_splits": [1, 4],            # 1 = tek kademe (DirectionalLight3D.SHADOW_ORTHOGONAL), 2, 4
	"shadow_distance": [0.0, 300.0],    # m
	"shadow_split_1": [0.02, 0.5],      # kademe sınırları, uzaklığın oranı
	"shadow_split_2": [0.05, 0.8],
	"shadow_split_3": [0.1, 0.95],
	"shadow_bias": [0.0, 0.2],
	"shadow_normal_bias": [0.0, 4.0],
	"shadow_blur": [0.0, 4.0],
	"shadow_atlas": [512, 8192],        # piksel, ikinin kuvveti
	"shadow_filter": [0, 5],            # RenderingServer.ShadowQuality: 0 sert ... 5 çok yumuşak
	"msaa": [0, 4],                     # 0 kapalı, 2 = 2x, 4 = 4x
	"fxaa": [0, 1],
	"taa": [0, 1],                      # yalnızca Forward+
	"render_scale": [0.5, 1.0],         # 3B çözünürlük ölçeği
	"tonemap": [0, 4],                  # Environment.ToneMapper: 0 doğrusal, 2 filmic, 3 ACES
	"tonemap_exposure": [0.3, 3.0],
	"tonemap_white": [1.0, 16.0],
	"ambient_sky": [0, 1],              # ortam ışığı gökyüzünden
	"ambient_energy": [0.0, 3.0],
	"ambient_sky_mix": [0.0, 1.0],      # gökyüzü payı; kalan, Palette.AMBIENT renginden (sıcak, gökyüzünün beyaz bulutları teni/kayayı solgunlaştırmasın)
	"fog_begin": [0.0, 500.0],          # m, sis başlangıcı (derinlik sisi)
	"fog_end": [10.0, 1000.0],
	"sun_energy": [0.0, 4.0],
	"fog": [0, 1],
	"fog_density": [0.0, 1.0],          # derinlik sisinin en çok kapladığı oran
	"fog_sky_affect": [0.0, 1.0],
	"ssao": [0, 1],                     # yalnızca Forward+ / Mobile değil
	"ssil": [0, 1],
	"glow": [0, 1],
	"glow_intensity": [0.0, 2.0],
	"glow_bloom": [0.0, 1.0],
	"glow_threshold": [0.0, 4.0],
	"volumetric_fog": [0, 1],           # yalnızca Forward+
	"terrain_normal": [0.0, 2.0],       # arazi normal haritası gücü, 0 = kapalı (doku yüklenmez)
	"terrain_tex_k": [1, 2],            # arazi doku çözünürlüğü: 1 = 1k, 2 = 2k
	"skin_gain": [0.3, 1.5],          # eller ve aletlerin parlaklık çarpanı (tonemap teni solgunlaştırmasın)
	"water": [0, 2],                    # 0 sade, 1 derinlik geçişi + fresnel + güneş, 2 ek dalga ayrıntısı
	"target_fps": [30, 144],
}

const PRESETS: Array[Dictionary] = [
	{ # Düşük: gl_compatibility dönemindeki görünüm
		"shadows": false, "shadow_splits": 1, "shadow_distance": 0.0,
		"shadow_split_1": 0.1, "shadow_split_2": 0.2, "shadow_split_3": 0.5,
		"shadow_bias": 0.03, "shadow_normal_bias": 1.0, "shadow_blur": 1.0,
		"shadow_atlas": 1024, "shadow_filter": 1,
		"msaa": 0, "fxaa": false, "taa": false, "render_scale": 1.0,
		"tonemap": 0, "tonemap_exposure": 1.0, "tonemap_white": 6.0,
		"ambient_sky": false, "ambient_energy": Config.AMBIENT_ENERGY, "ambient_sky_mix": 0.0, "sun_energy": Config.SUN_ENERGY,
		"fog": false, "fog_begin": 60.0, "fog_end": 250.0, "fog_density": 0.0, "fog_sky_affect": 0.0,
		"ssao": false, "ssil": false,
		"glow": false, "glow_intensity": 0.0, "glow_bloom": 0.0, "glow_threshold": 1.0,
		"volumetric_fog": false,
		"terrain_normal": 0.0, "terrain_tex_k": 1,
		"skin_gain": 1.0, "water": 0, "target_fps": 60,
	},
	{ # Orta (varsayılan)
		"shadows": true, "shadow_splits": 2, "shadow_distance": 70.0,
		"shadow_split_1": 0.2, "shadow_split_2": 0.2, "shadow_split_3": 0.5,
		"shadow_bias": 0.04, "shadow_normal_bias": 1.5, "shadow_blur": 1.2,
		"shadow_atlas": 2048, "shadow_filter": 2,
		"msaa": 2, "fxaa": false, "taa": false, "render_scale": 1.0,
		"tonemap": 2, "tonemap_exposure": 0.9, "tonemap_white": 6.0,
		"ambient_sky": true, "ambient_energy": 0.55, "ambient_sky_mix": 0.4, "sun_energy": 1.5,
		"fog": true, "fog_begin": 70.0, "fog_end": 260.0, "fog_density": 0.55, "fog_sky_affect": 0.0,
		"ssao": false, "ssil": false,
		"glow": false, "glow_intensity": 0.0, "glow_bloom": 0.0, "glow_threshold": 1.0,
		"volumetric_fog": false,
		"terrain_normal": 1.0, "terrain_tex_k": 1,
		"skin_gain": 0.8, "water": 1, "target_fps": 50,
	},
	{ # Yüksek
		"shadows": true, "shadow_splits": 4, "shadow_distance": 140.0,
		"shadow_split_1": 0.06, "shadow_split_2": 0.15, "shadow_split_3": 0.4,
		"shadow_bias": 0.03, "shadow_normal_bias": 1.2, "shadow_blur": 1.6,
		"shadow_atlas": 4096, "shadow_filter": 4,
		"msaa": 4, "fxaa": false, "taa": false, "render_scale": 1.0,
		"tonemap": 2, "tonemap_exposure": 0.9, "tonemap_white": 6.0,
		"ambient_sky": true, "ambient_energy": 0.55, "ambient_sky_mix": 0.4, "sun_energy": 1.5,
		"fog": true, "fog_begin": 70.0, "fog_end": 260.0, "fog_density": 0.55, "fog_sky_affect": 0.0,
		"ssao": true, "ssil": false,
		"glow": true, "glow_intensity": 0.5, "glow_bloom": 0.04, "glow_threshold": 1.2,
		"volumetric_fog": false,
		"terrain_normal": 1.0, "terrain_tex_k": 2,
		"skin_gain": 0.8, "water": 2, "target_fps": 30,
	},
]


static func clamp_level(level: int) -> int:
	return clampi(level, 0, LEVEL_COUNT - 1)


static func preset(level: int) -> Dictionary:
	return PRESETS[clamp_level(level)]


static func level_name(level: int) -> String:
	return LEVEL_NAMES[clamp_level(level)]


## "low" / "medium" / "high" (büyük küçük harf fark etmez); tanınmazsa -1.
static func level_from_arg(text: String) -> int:
	return LEVEL_ARGS.find(text.strip_edges().to_lower())
