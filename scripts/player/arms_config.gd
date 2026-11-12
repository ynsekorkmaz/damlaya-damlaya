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
