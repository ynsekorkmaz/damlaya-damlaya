extends RefCounted
## Tüm ayar sayıları burada durur. Saf mantık: Node ya da çizim sınıfı yok.

# Vadi (metre)
const VALLEY_RADIUS := 55.0
const RIM_HEIGHT := 9.0
const RIM_WIDTH := 18.0
const PIT_RADIUS := 7.0
const PIT_DEPTH := 1.6
const PIT_SHAPE := 0.5  # gauss genişliği: exp(-r^2 / (PIT_RADIUS^2 * PIT_SHAPE))

# Hafif dalgalı zemin (genlikler toplamı 1 m'nin altında)
const WAVE_AMP_A := 0.35
const WAVE_FREQ_AX := 0.11
const WAVE_FREQ_AZ := 0.09
const WAVE_AMP_B := 0.25
const WAVE_FREQ_BX := 0.23
const WAVE_FREQ_BZ := 0.17
const WAVE_AMP_C := 0.15
const WAVE_FREQ_CX := 0.13
const WAVE_FREQ_CZ := 0.31
const CALM_MIN := 0.25     # çukur merkezinde dalga çarpanı
const CALM_NEAR := 6.0     # bu yarıçaptan itibaren dalga artmaya başlar
const CALM_FAR := 22.0     # bu yarıçapta dalga tam güçte

# Arazi ağı
const TERRAIN_SIZE := 170.0
const TERRAIN_CELLS := 56

# Arazi renkleri
const EARTH_HEIGHT_LOW := -1.2
const EARTH_HEIGHT_HIGH := -0.3
const ROCK_NORMAL_Y_LOW := 0.80
const ROCK_NORMAL_Y_HIGH := 0.92
const HILLTOP_DRY_START := 0.35  # RIM_HEIGHT oranı
const HILLTOP_DRY_END := 0.8
const HILLTOP_DRY_AMOUNT := 0.6
const COLOR_HASH_X := 12.9898
const COLOR_HASH_Z := 78.233
const COLOR_JITTER := 0.6  # çimen rengi çeşitlemesi (0-1)

# Oyuncu doğuş noktası (çukura 14 m, çukura bakar); y main.gd'de araziye göre ayarlanır
const PLAYER_SPAWN := Vector3(0.0, 0.0, 14.0)
const SPAWN_LIFT := 0.2

# Oyuncu
const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.8
const JUMP_VELOCITY := 4.6
const GRAVITY := 14.0
const ACCELERATION := 28.0
const MOUSE_SENSITIVITY := 0.0022
const PLAYER_HEIGHT := 1.7
const PLAYER_RADIUS := 0.35
const EYE_HEIGHT := 1.55
const PITCH_LIMIT_DEG := 85.0

# Gökyüzü ve ışık
const SUN_ROTATION_DEG := Vector3(-48.0, -35.0, 0.0)
const SUN_ENERGY := 1.1
const AMBIENT_ENERGY := 0.9
const SKY_SUN_ANGLE_MAX := 30.0

# Kayalar
const ROCK_COUNT := 20
const ROCK_SEED := 7
const ROCK_SCALE_MIN := Vector3(0.8, 0.6, 0.8)
const ROCK_SCALE_MAX := Vector3(2.6, 1.8, 2.6)
const ROCK_VERTEX_JITTER := 0.18
const ROCK_SINK := 0.25            # kayanın zemine gömülme miktarı
const ROCK_PIT_CLEARANCE := 4.0    # çukur kenarından uzaklık
const ROCK_RIM_CLEARANCE := 6.0    # vadi sınırından içeri uzaklık
const ROCK_SPAWN_CLEARANCE := 4.0  # doğuş noktasından uzaklık (en az 3 m)
const ROCK_MAX_TRIES := 200

# Ölçüm
const SCREENSHOT_WAIT_FRAMES := 120
