extends RefCounted
## Canlılar (balık, kuş) için sayılar. Adetler economy_config.gd'den gelir (FISH_BY_STAGE, BIRDS_BY_STAGE).
## Modeller: tools/blender/make_life.py -> assets/models/life/*.glb. Çizim: scripts/world/life_view.gd.

const FISH_MODEL: String = "res://assets/models/life/fish.glb"
const BIRD_MODEL: String = "res://assets/models/life/bird.glb"

# ---- Balık ----
const FISH_MIN_LAKE_RADIUS: float = 2.0    # bundan küçük gölde balık görünmez (m)
const FISH_EDGE_FRAC: float = 0.72         # kıyı yarıçapının bu oranında dönmeye başlar
const FISH_SCALE_MIN: float = 1.0
const FISH_SCALE_MAX: float = 1.8
const FISH_SPEED_MIN: float = 0.5          # m/sn
const FISH_SPEED_MAX: float = 1.3
const FISH_SPEED_WAVE: float = 0.35        # hızın sinüsle oynama oranı
const FISH_SPEED_WAVE_HZ: float = 0.12
const FISH_TURN_MAX: float = 1.6           # rad/sn
const FISH_TURN_SMOOTH: float = 2.5        # dönüş hızı yumuşatma (1/sn)
const FISH_WANDER_MIN_SEC: float = 2.0
const FISH_WANDER_MAX_SEC: float = 6.0
const FISH_WANDER_ANGLE: float = 1.1       # rastgele yön sapması (rad)
const FISH_DEPTH_MIN: float = 0.07         # yüzeyin altı (m)
const FISH_DEPTH_MAX: float = 0.18
const FISH_DEPTH_WAVE: float = 0.03
const FISH_DEPTH_WAVE_HZ: float = 0.17
const FISH_DEPTH_FRAC: float = 0.6         # yerel su derinliğinin en çok bu kadarına iner
const FISH_ROLL_PER_TURN: float = 0.25     # dönüşte yatış (rad / (rad/sn))
const FISH_WIGGLE_AMP: float = 0.07        # kuyruk sallanma genliği (model uzayında, m)
const FISH_WIGGLE_HZ: float = 3.2          # rad/sn çarpanı
const FISH_WIGGLE_WAVE: float = 9.0        # gövde boyunca faz farkı (rad/m)
const FISH_GLOW: float = 0.55             # suyun altından seçilsin diye kendi rengini yayma payı
const FISH_SILVER_CHANCE: float = 0.35     # gümüşi renk alma olasılığı
const FISH_FADE_IN_SEC: float = 1.5        # gölün yarıçapı 2 m'yi geçince ölçekle belirme

# ---- Kuş ----
const BIRD_SCALE: float = 3.4              # model kanat açıklığı 1 m
const BIRD_ALT_MIN: float = 15.0           # su seviyesinin üstü (m)
const BIRD_ALT_MAX: float = 30.0
const BIRD_ALT_WAVE: float = 1.5
const BIRD_ALT_WAVE_HZ: float = 0.05
const BIRD_SPEED_MIN: float = 7.0
const BIRD_SPEED_MAX: float = 11.0
const BIRD_ORBIT_MIN: float = 20.0         # dönüş yarıçapı (m)
const BIRD_ORBIT_MAX: float = 45.0
const BIRD_RANGE: float = 55.0             # gölden bu kadar uzaklaşınca içe döner
const BIRD_TURN_SMOOTH: float = 0.8
const BIRD_REVERSE_MIN_SEC: float = 18.0   # dönüş yönünü değiştirme aralığı
const BIRD_REVERSE_MAX_SEC: float = 45.0
const BIRD_MAX_BANK_DEG: float = 32.0
const BIRD_GRAVITY: float = 9.8
const BIRD_FLAP_AMP: float = 0.10          # kanat ucu yukarı aşağı (model uzayında, m)
const BIRD_FLAP_HZ: float = 3.5            # rad/sn
const BIRD_FLAP_VARIATION: float = 0.35    # kuş başına hız oynaması
