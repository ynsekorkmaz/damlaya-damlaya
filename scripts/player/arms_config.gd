extends RefCounted
## Birinci sahis kollar ve avuc: konum/olcek sayilari (metre, kamera uzayi) ve su rengi.
## Eller Blender de MPFB (CC0 insan agi) ile uretilir (tools/blender/make_hands_mpfb.py -> assets/models/hands.glb).
## Model orijini iki bilegin ortasi; canagin agzi +Y, parmak uclari -Z (kamerenin baktigi yon).

const MODEL_PATH: String = "res://assets/models/hands.glb"
const WATER := Color(0.55, 0.78, 0.92, 0.55)
const ARM_SCALE: float = 1.2

# ---- Su: glb'deki "Water" (alt yari elipsoid, ustu duz, orijin altta, boy 0.026 m) ----
const WATER_MESH_HEIGHT: float = 0.026
const WATER_TOP_MIN: float = 0.014        # az dolu ust yuksekligi (orijinden, m)
const WATER_TOP_MAX: float = 0.026        # tam dolu
const WATER_SPREAD_MIN: float = 0.6       # az doluyken yatay olcek
const WATER_LERP_SPEED: float = 10.0
const WATER_VISIBLE_MIN: float = 0.005
const WATER_WOBBLE: float = 0.02
const WATER_WOBBLE_HZ: float = 2.6

# ---- Duruslar (model orijini = bilekler; derece: pitch, yaw, roll) ----
const CUP_POS := Vector3(0.0, -0.27, -0.34)
const CUP_ROT_DEG := Vector3(22.0, 0.0, 0.0)
const IDLE_POS := Vector3(0.0, -0.62, -0.3)
const IDLE_ROT_DEG := Vector3(14.0, 0.0, 0.0)
const BLEND_SPEED: float = 7.0
const CUP_CARRIED_MIN: float = 0.001      # bunun ustu tasima = avuc durusu

# ---- Hareket ----
const WALK_SPEED_REF: float = 5.0         # sallanma bu hizda tam genlik
const SWAY_X: float = 0.007
const SWAY_Y: float = 0.006
const SWAY_FREQ: float = 7.0              # rad / (m/s ile olceklenmeden) sabit adim sikligi
const BREATH_Y: float = 0.0012
const BREATH_HZ: float = 0.7
const SPEED_SMOOTH: float = 8.0
const POUR_TIME: float = 0.7
const POUR_PITCH_DEG: float = -50.0
const POUR_FORWARD: float = -0.07
const POUR_LIFT: float = 0.04

# ---- Aletler (tas, kova, cift kova, sirik) ----
# Model yolu: assets/models/tools/<alet_id>.glb; yoksa kodla yer tutucu cizilir.
const TOOL_MODEL_DIR: String = "res://assets/models/tools/"
const GRIP_MODEL_PATH: String = "res://assets/models/hands_grip.glb"   # istege bagli: kova kulbunu tutan sag el
const TOOL_WATER_PREFIX: String = "Water"

# Tas, ellerin yerel uzayinda (canagin alt orta noktasi). Eller hep avuc durusunda.
const CUP_TOOL_POS := Vector3(0.0, -0.012, -0.06)
const CUP_TOOL_SCALE: float = 1.0

# Asili aletler: kamera uzayinda orijin (kulp / omuz noktasi), derece, olcek.
# swing: yururken sarkac genligi (derece); pour_pitch: dokme egilmesi (derece, orijin etrafinda);
# pour_pos: dokmede orijin kaymasi.
const TOOL_POSES: Dictionary = {
	"bucket": {
		"pos": Vector3(0.30, -0.02, -0.55), "rot": Vector3(14.0, -8.0, 0.0), "scale": 0.9,
		"swing": 5.0, "pour_pitch": -55.0, "pour_pos": Vector3(-0.04, 0.03, -0.06),
	},
	"double_bucket": {
		"pos": Vector3(0.0, -0.02, -0.6), "rot": Vector3(14.0, 0.0, 0.0), "scale": 1.0,
		"swing": 5.0, "pour_pitch": -40.0, "pour_pos": Vector3(0.0, 0.03, -0.05),
	},
	"yoke": {
		"pos": Vector3(0.0, 0.25, -0.5), "rot": Vector3(8.0, 0.0, 0.0), "scale": 0.85,
		"swing": 6.0, "pour_pitch": -35.0, "pour_pos": Vector3(0.0, 0.03, -0.04),
	},
}
const SWING_LAG: float = 0.55             # sarkac, adim fazindan bu kadar geriden gelir (rad)
const IDLE_SWING_DEG: float = 0.6         # dururken hafif salinim
const IDLE_SWING_HZ: float = 0.5
const TOOL_CHANGE_DROP: float = 0.5       # alet degisiminde asagi kayma (m)
const TOOL_CHANGE_SPEED: float = 5.0      # kayma hizi (1/sn)

# Yer tutucu boyutlari (m)
const PH_WOOD := Color(0.55, 0.36, 0.20)
const PH_METAL := Color(0.62, 0.64, 0.66)
const PH_ROPE := Color(0.62, 0.52, 0.34)
const PH_CUP_RADIUS: float = 0.07
const PH_BUCKET_TOP_R: float = 0.115
const PH_BUCKET_BOTTOM_R: float = 0.085
const PH_BUCKET_HEIGHT: float = 0.22
const PH_BUCKET_DROP: float = 0.1          # kulp tepesinden agiz kenarina
const PH_YOKE_HALF: float = 0.62           # sirigin yarisi
const PH_YOKE_ROPE: float = 0.4
const PH_DOUBLE_HALF: float = 0.25
