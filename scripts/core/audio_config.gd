extends RefCounted
## Ses sisteminin tüm sayıları. Sesler kodla üretilir (sound_bank.gd), hazır ses dosyası yoktur.
## Olay tablosu: olay adı -> {sound: ses adı, bus: "sfx"|"ui"|"ambience", db: ses düzeyi, pitch: rastgele perde sapması (oran)}.

const BUS_MASTER: String = "Master"
const BUS_SFX: String = "SFX"
const BUS_AMBIENCE: String = "Ambience"
const BUS_UI: String = "UI"
const BUS_DB_SFX: float = 0.0
const BUS_DB_AMBIENCE: float = -3.0
const BUS_DB_UI: float = -3.0

const DEFAULT_VOLUME: float = 0.6   ## ana ses düzeyi 0..1
const VOLUME_STEP: float = 0.1
const DEFAULT_SOUND_ON: bool = true

const MIX_RATE: int = 22050
const NORMALIZE_PEAK: float = 0.85   ## her tamponun tepe genliği (kırpma yok)
const EDGE_FADE_SEC: float = 0.004   ## tek atımlık seslerin baş/son yumuşatması
const SEED: int = 20261113

# Ses havuzu
const SFX_VOICES: int = 10
const UI_VOICES: int = 4
const POSITIONAL_SOURCES: int = 5   ## kaynak kayası, göl kıyısı, en yakın 2 su (kanal/çeşme), değirmen

# Dolum
const FILL_HOLD_SEC: float = 0.18   ## son dolum olayından sonra döngü bu kadar sürer
const FILL_FADE_IN: float = 250.0   ## döngü ses düzeyi yükselişi (dB/sn)
const FILL_FADE_OUT: float = 200.0
const FILL_DB: float = -9.0
const FILL_FULL_EPS: float = 0.001

# Dökme ve para
const POUR_SMALL_DROPS: float = 15.0
const POUR_MID_DROPS: float = 150.0
const COIN_DELAY_SEC: float = 0.45
const PLINK_DELAY_MIN: float = 0.15
const PLINK_DELAY_MAX: float = 0.9
const PLINK_COUNT: int = 2
const SCHEDULE_SLOTS: int = 8
const WATER_STRUCTURE_KINDS: Array[String] = ["spring", "stream_mouth"]

# Ayak sesi
const STRIDE_WALK: float = 1.7      ## bir adım için yürünen yol (m)
const STRIDE_SPRINT: float = 2.1
const STEP_MIN_SPEED: float = 0.8   ## bunun altında adım sayılmaz (m/sn)
const SPRINT_SPEED_MIN: float = 5.5
const STEP_WATER_MARGIN: float = 0.3 ## gölün kıyı yarıçapından bu kadar içeride su sesi
const STEP_DB: float = -12.0
const STEP_WATER_DB: float = -9.0
const LAND_DB: float = -8.0

# Arayüz
const UI_HOVER_MIN_GAP: float = 0.05

# Konumlu döngüler
const POS_UPDATE_SEC: float = 0.4
const POS_MOVE_SPEED: float = 30.0   ## kaynak konumu hedefe bu hızla kayar (m/sn)
const POS_UNIT_SIZE: float = 3.0
const POS_MAX_DISTANCE: float = 45.0
const SPRING_DB: float = -6.0
const LAKE_DB: float = -10.0
const CANAL_DB: float = -9.0
const MILL_DB: float = -8.0
const LAKE_MIN_RADIUS: float = 1.5
const SPRING_HEIGHT: float = 1.0

# Ambiyans
const WIND_DB: float = -16.0
const BIRD_DB: float = -11.0
const BIRD_GAP_MIN: float = 7.0
const BIRD_GAP_MAX: float = 16.0
const BIRD_GAP_FACTOR_WITH_BIRDS: float = 0.4
const BIRD_DISTANCE_MIN: float = 12.0
const BIRD_DISTANCE_MAX: float = 30.0
const BIRD_HEIGHT_MIN: float = 6.0
const BIRD_HEIGHT_MAX: float = 16.0

## Olaylar. Ses adları sound_bank.gd'deki katalogdadır (aynı ada birkaç varyasyon olabilir).
const EVENTS: Dictionary = {
	"fill_full": {"sound": "full", "bus": "sfx", "db": -8.0, "pitch": 0.0},
	"pour_small": {"sound": "pour_s", "bus": "sfx", "db": -7.0, "pitch": 0.04},
	"pour_mid": {"sound": "pour_m", "bus": "sfx", "db": -6.0, "pitch": 0.04},
	"pour_large": {"sound": "pour_l", "bus": "sfx", "db": -5.0, "pitch": 0.03},
	"plink": {"sound": "plink", "bus": "sfx", "db": -15.0, "pitch": 0.15},
	"coins": {"sound": "coins", "bus": "sfx", "db": -13.0, "pitch": 0.04},
	"step_grass": {"sound": "step_grass", "bus": "sfx", "db": -12.0, "pitch": 0.10},
	"step_water": {"sound": "step_water", "bus": "sfx", "db": -9.0, "pitch": 0.10},
	"land": {"sound": "step_grass", "bus": "sfx", "db": -8.0, "pitch": 0.06},
	"build_place": {"sound": "hammer_place", "bus": "sfx", "db": -6.0, "pitch": 0.06},
	"build_remove": {"sound": "hammer_remove", "bus": "sfx", "db": -7.0, "pitch": 0.05},
	"build_rotate": {"sound": "tick", "bus": "sfx", "db": -10.0, "pitch": 0.04},
	"build_denied": {"sound": "dull", "bus": "sfx", "db": -4.0, "pitch": 0.04},
	"purchase": {"sound": "purchase", "bus": "ui", "db": -4.0, "pitch": 0.0},
	"unlock": {"sound": "unlock", "bus": "ui", "db": -4.0, "pitch": 0.0},
	"purchase_denied": {"sound": "fail", "bus": "ui", "db": -6.0, "pitch": 0.0},
	"ui_hover": {"sound": "ui_hover", "bus": "ui", "db": -16.0, "pitch": 0.05},
	"ui_click": {"sound": "ui_click", "bus": "ui", "db": -12.0, "pitch": 0.03},
	"panel_open": {"sound": "panel_open", "bus": "ui", "db": -9.0, "pitch": 0.0},
	"panel_close": {"sound": "panel_close", "bus": "ui", "db": -9.0, "pitch": 0.0},
	"book_open": {"sound": "page", "bus": "ui", "db": -8.0, "pitch": 0.05},
	"book_close": {"sound": "page", "bus": "ui", "db": -9.0, "pitch": 0.05},
	"stage": {"sound": "stage", "bus": "sfx", "db": -8.0, "pitch": 0.0},
	"bird": {"sound": "bird", "bus": "ambience", "db": -11.0, "pitch": 0.08},
}

## Döngülü sesler (sound_bank.gd katalogunda aynı adlarla bulunur).
const LOOPS: Array[String] = ["fill_loop", "spring_loop", "canal_loop", "lake_loop", "mill_loop", "wind_loop"]


static func clamp_volume(v: float) -> float:
	return clampf(snappedf(v, VOLUME_STEP), 0.0, 1.0)


static func volume_percent(v: float) -> int:
	return int(roundf(clamp_volume(v) * 100.0))


## Ana ses düzeyinden Master veri yolu dB değeri.
static func master_db(volume: float, sound_on: bool) -> float:
	if not sound_on or volume <= 0.0:
		return -80.0
	return linear_to_db(clampf(volume, 0.0, 1.0))
