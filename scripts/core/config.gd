extends RefCounted
## Tüm ayar sayıları burada durur. Saf mantık: Node ya da çizim sınıfı yok.

# Vadi (metre)
const VALLEY_RADIUS := 55.0
const RIM_HEIGHT := 9.0
const RIM_WIDTH := 18.0
const PIT_RADIUS := 16.0
const PIT_DEPTH := 3.5
const PIT_SHAPE := 0.6  # gauss genişliği: exp(-r^2 / (PIT_RADIUS^2 * PIT_SHAPE))

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
const CALM_MIN := 0.2      # çukur merkezinde dalga çarpanı
const CALM_NEAR := 14.0    # bu yarıçaptan itibaren dalga artmaya başlar
const CALM_FAR := 32.0     # bu yarıçapta dalga tam güçte

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

# Oyuncu doğuş noktası (çukur ve kaynak birlikte görünür); y main.gd'de araziye göre ayarlanır
const PLAYER_SPAWN := Vector3(5.0, 0.0, 36.0)
const SPAWN_LOOK_AT := Vector2(-3.0, 12.0)  # doğuşta bakılan yer (x, z)
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

# Su kaynağı (kaya kütlesi, çatlak, süzülen su, birikinti); y araziden alınır
const SPRING_POSITION := Vector3(-9.0, 0.0, 26.0)
const SPRING_HEIGHT := 2.5
const SPRING_RADIUS := 1.35          # taban yarıçapı (m)
const SPRING_TAPER := 0.22        # tepeye doğru daralma
const SPRING_TOP_POWER := 2.4        # tepe yuvarlaklığı (büyük = yassı tepe)
const SPRING_RINGS := 14
const SPRING_SEGMENTS := 22
const SPRING_BUMP := 0.13            # yüzey bozulması (yarıçap oranı)
const SPRING_SINK := 0.25            # araziye gömülme (m)
const SPRING_CRACK_TOP := 0.80       # çatlağın üst ucu (yüksekliğin oranı)
const SPRING_CRACK_BOTTOM := 0.60
const SPRING_CRACK_WIDTH := 0.16     # m
const SPRING_STREAM_WIDTH := 0.1     # m
const SPRING_STREAM_BOTTOM := 0.04
const SPRING_SURFACE_OFFSET := 0.025 # çatlak ve şeridin yüzeyden çıkıntısı (m)
const SPRING_STREAM_ROWS := 10
const SPRING_PUDDLE_RADIUS := 0.6
const SPRING_PUDDLE_SEGMENTS := 20
const SPRING_PUDDLE_LIFT := 0.035
const SPRING_STREAM_SCROLL := 3.0    # süzülme hızı
const SPRING_STREAM_WAVELENGTH := 0.45  # m

# Etkileşim
const FILL_REACH := 3.0              # kaya yüzeyinden en çok uzaklık (m)
const FILL_LOOK_COS := 0.82          # kaynağa bakış (kamera yönü ile hedef arası kosinüs)
const FILL_TARGET_HEIGHT := 1.4      # bakılan noktanın kaynağın tabanından yüksekliği (m)
const POUR_ZONE_RADIUS := 19.0       # çukur merkezinden bu uzaklığa kadar dökülebilir
const GUIDE_DROPS_LIMIT := 30.0      # bu kadar damlaya dek yönlendirme ipucu

# Göl
const LAKE_TOP_LEVEL := -0.75        # su seviyesi üst sınırı (çanağın ağzına yakın)
const LAKE_PUDDLE_THICKNESS := 0.04  # ilk damlanın dipteki kalınlığı
const LAKE_LEVEL_SPEED := 1.4        # seviyenin hedefe yaklaşma hızı (1/sn)
const LAKE_SEGMENTS := 56
const LAKE_RINGS := 8
const LAKE_RADIUS_MARGIN := 0.6      # kıyı yarıçapına eklenen pay (arazi altında kalır)
const LAKE_TABLE_STEPS := 48
const LAKE_RAYS := 24
const LAKE_RAY_STEP := 0.2
const LAKE_RAY_MAX := 30.0
const LAKE_WAVE_AMP_1 := 0.035
const LAKE_WAVE_AMP_2 := 0.025
const LAKE_WAVE_FREQ_1 := 0.9
const LAKE_WAVE_FREQ_2 := 1.7
const LAKE_WAVE_SPEED_1 := 1.1
const LAKE_WAVE_SPEED_2 := 1.6
const LAKE_ALPHA_CENTER := 0.9
const LAKE_ALPHA_EDGE := 0.6
const LAKE_ALPHA_FADE_IN := 0.25     # su kalınlığı bu kadarken tam görünür (m)
const RIPPLE_POOL := 4
const RIPPLE_SEGMENTS := 40
const RIPPLE_WIDTH := 0.12           # halka kalınlığı (yarıçap oranı)
const RIPPLE_SECONDS := 1.4
const RIPPLE_MAX_RADIUS := 3.2
const RIPPLE_START_RADIUS := 0.4
const RIPPLE_LIFT := 0.04

# Elde su (kamera çocuğu)
const HELD_OFFSET := Vector3(0.24, -0.26, -0.5)
const HELD_TILT_DEG := Vector3(22.0, 0.0, -6.0)
const HELD_SCALE := 1.1
const HELD_SEGMENTS := 20
const HELD_WATER_MIN := 0.025        # boş kapta dip yüksekliği (m)
const HELD_WATER_MAX := 0.1          # tam doluyken su yüksekliği (m)
const HELD_LERP_SPEED := 10.0

# Ölçüm
const SCREENSHOT_WAIT_FRAMES := 120
const SCREENSHOT_POUR_FRAMES_BEFORE := 25  # --debug-pour: dökme, çekimden bu kadar kare önce
