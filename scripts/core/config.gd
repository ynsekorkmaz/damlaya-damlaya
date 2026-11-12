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
const TERRAIN_CELLS := 100  # hücre ~1,7 m, 20.000 üçgen
const NORMAL_EPS := 1.7    # normal için merkezi fark aralığı (m)

# Arazi renkleri
const EARTH_HEIGHT_LOW := -1.2
const EARTH_HEIGHT_HIGH := -0.3
const ROCK_NORMAL_Y_LOW := 0.55    # yalnızca gerçekten dik yüzeyler kayalaşır
const ROCK_NORMAL_Y_HIGH := 0.72
const ROCK_SLOPE_AMOUNT := 0.7
const HILLTOP_DRY_START := 0.12    # RIM_HEIGHT oranı: çimen -> kuru ot
const HILLTOP_DRY_END := 0.5
const HILLTOP_DRY_AMOUNT := 0.85
const HILL_EARTH_START := 0.45     # kuru ot -> sıcak toprak/kaya
const HILL_EARTH_END := 1.0
const HILL_EARTH_AMOUNT := 0.8
const HILL_ROCK_MIX := 0.4         # üst yamaçta toprak içine karışan kaya tonu
const COLOR_WAVE_FREQ_X := 0.045  # geniş, yumuşak çimen tonu dalgası
const COLOR_WAVE_FREQ_Z := 0.037
const COLOR_WAVE_AMOUNT := 0.55   # çimen rengi çeşitlemesi (0-1)
const HILL_WAVE_FREQ := 0.11      # yamaçta ton çeşitlemesi
const HILL_WAVE_AMOUNT := 0.35

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
const SUN_ENERGY := 0.95
const AMBIENT_ENERGY := 1.15
const SKY_SUN_ANGLE_MAX := 30.0

# Kayalar
const ROCK_COUNT := 40             # toplam kaya (büyük, orta ve küçük taşlar)
const ROCK_SEED := 7
const ROCK_VARIANTS := 3           # ayrı biçim = ayrı MultiMesh
const ROCK_RINGS := 7              # dilim sayısı (enlem)
const ROCK_SEGMENTS := 11          # boylam dilimi
const ROCK_TRI_BUDGET := 6000      # tüm kayaların üçgen üst sınırı
const ROCK_BUMP := 0.16            # düşük frekanslı biçim bozulması (yarıçap oranı)
const ROCK_BUMP_FREQ := 2.3
const ROCK_BUMP_FREQ_2 := 4.1
const ROCK_BUMP_2 := 0.45          # ikinci sinüs katmanının payı
const ROCK_BASE_FLAT := 0.30       # alt yarının yassılması (0 = küre)
const ROCK_SINK_FRAC := 0.12       # yüksekliğin bu oranı kadar yere gömülür
const ROCK_TILT_MAX := 0.18        # radyan, hafif eğiklik
const ROCK_CLUSTER_COUNT := 9      # kümelerin ana (büyük) kayaları
const ROCK_BIG_SIZE_MIN := 1.5     # m, ana kaya genişliği
const ROCK_BIG_SIZE_MAX := 2.5
const ROCK_MID_SIZE_MIN := 0.7
const ROCK_MID_SIZE_MAX := 1.2
const ROCK_SMALL_SIZE_MIN := 0.25
const ROCK_SMALL_SIZE_MAX := 0.55
const ROCK_MID_CHANCE := 0.3       # serpilmiş tek kayada orta boy olasılığı
const ROCK_AXIS_MIN := 0.75        # eksen ölçeği çarpanı (genişlik)
const ROCK_AXIS_MAX := 1.25
const ROCK_HEIGHT_MIN := 0.8      # yükseklik / genişlik
const ROCK_HEIGHT_MAX := 1.1
const ROCK_SAT_MIN := 1             # kümedeki uydu kaya sayısı
const ROCK_SAT_MAX := 2
const ROCK_SAT_DIST_MIN := 0.9     # uydunun ana kayaya uzaklığı (ana yarıçapının katı)
const ROCK_SAT_DIST_MAX := 1.5
const ROCK_COLLIDE_MIN_SIZE := 1.0 # bu genişlik ve üstü çarpışır
const ROCK_COLLIDE_FRAC := 0.85    # çarpışma küresi / görünür yarıçap
const ROCK_PIT_CLEARANCE := 4.0    # çukur kenarından uzaklık
const ROCK_RIM_CLEARANCE := 6.0    # vadi sınırından içeri uzaklık
const ROCK_SPAWN_CLEARANCE := 4.0  # doğuş noktasından uzaklık (en az 3 m)
const ROCK_MAX_TRIES := 400

# Ölçüm
const SCREENSHOT_WAIT_FRAMES := 120
