extends RefCounted
## Tüm ayar sayıları burada durur. Saf mantık: Node ya da çizim sınıfı yok.

# Vadi (metre)
const VALLEY_RADIUS := 55.0
const RIM_HEIGHT := 9.0
const RIM_WIDTH := 18.0

# Çanak (çukur -> göl): aşama eşiklerine göre hedef yarıçap ve derinlik (m).
# Anahtarlar: Aşama eşikleri + GAME_END_DROPS (economy_config.gd); aralar log(1+toplam) üzerinden yumuşak.
const BASIN_RADII: Array[float] = [0.7, 1.6, 4.0, 9.0, 16.0, 19.0]
const BASIN_DEPTHS: Array[float] = [0.25, 0.5, 1.1, 2.2, 3.5, 4.0]
const BASIN_FLAT_START := 0.7        # çanak içinde zemin dalgaları sönümlenir (yarıçap oranı)
const BASIN_FLAT_END := 1.15
const BASIN_FLAT_KEEP := 0.15        # çanak içinde kalan dalga payı
const BASIN_SMOOTH := 0.5            # 0 = log üzerinde doğrusal, 1 = tam smoothstep
const BASIN_REBUILD_DELTA := 0.03    # yama, yarıçap bu kadar (m) değişince yeniden kurulur
const POUR_MARGIN := 2.5             # çanak kıyısından bu kadar yakında dökülebilir (m)

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
const TERRAIN_CELLS := 100  # hücre ~1,7 m; ortadaki kısım çanak yamasıyla değiştirilir
# Çanak yaması: merkezde, kutupsal ızgara, hücre kenarı ortada ~0,3 m, kıyıda ~1,4 m
const PATCH_RADIUS := 24.0
const PATCH_CELL_MIN := 0.3
const PATCH_CELL_GROWTH := 0.045     # yarıçap başına hücre büyümesi
const PATCH_SEAM_MARGIN := 2.5       # dış arazi hücreleri, bu kadar içeriden kesilir
const PATCH_VERTS_PER_FRAME := 600   # yeniden kurma kareye bölünür
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

# Arazi dokusu (assets/shaders/terrain.gdshader); vertex rengi = karışım ağırlığı
const TERRAIN_SHADER_PATH := "res://assets/shaders/terrain.gdshader"
const TERRAIN_TEX_GRASS := "res://assets/textures/terrain/grass.jpg"
const TERRAIN_TEX_SOIL := "res://assets/textures/terrain/soil.jpg"
const TERRAIN_TEX_ROCK := "res://assets/textures/terrain/rock.jpg"
const TERRAIN_TILE_NEAR := 3.0      # m, yakın ölçekte bir döşeme
const TERRAIN_TILE_FAR := 13.0      # m, uzak (döndürülmüş) ölçek
const TERRAIN_FAR_MIX_MIN := 0.3    # uzak ölçeğin yakındaki payı
const TERRAIN_FAR_MIX_MAX := 0.65   # uzaktaki payı
const TERRAIN_FAR_DIST_START := 8.0
const TERRAIN_FAR_DIST_END := 60.0
const TERRAIN_TINT_STRENGTH := 0.6  # palet renginin dokuya karışma payı (0 = ham doku)
const TERRAIN_GRASS_GAIN := 2.5     # palet renginin çarpanı (dokular palete göre koyu)
const TERRAIN_DRY_GAIN := 1.9
const TERRAIN_SOIL_GAIN := 1.7
const TERRAIN_ROCK_GAIN := 1.9

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
const SKY_HDRI_PATH := "res://assets/sky/sky_day.hdr"
const SKY_HDRI_ENERGY := 1.4        # gökyüzü görüntüsü parlaklığı
const SKY_SUN_DIR := Vector3(0.3046, 0.8542, -0.4208)  # HDRI'de güneşe bakan yön (birim): yükseklik 58,7 derece
const SUN_ENERGY := 0.95
const AMBIENT_ENERGY := 1.15

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
const ROCK_PIT_CLEARANCE := 4.0    # en büyük çanak yarıçapından uzaklık
const ROCK_RIM_CLEARANCE := 6.0    # vadi sınırından içeri uzaklık
const ROCK_SPAWN_CLEARANCE := 4.0  # doğuş noktasından uzaklık (en az 3 m)
const ROCK_MAX_TRIES := 400

# Su kaynağı: iç içe 3 yassı kaya kütlesi, aralarında yarık, süzülen su, dipte birikinti; y araziden alınır
const SPRING_POSITION := Vector3(-9.0, 0.0, 26.0)
const SPRING_HEIGHT := 2.2
const SPRING_RADIUS := 1.9           # etkileşim için yaklaşık taban yarıçapı (m)
# Kütleler yerel uzayda (+Z doğuş noktasına bakar): merkez, yarıçaplar
const SPRING_BLOBS: Array[Dictionary] = [
	{"center": Vector3(-1.05, 0.75, 0.05), "radii": Vector3(1.05, 1.45, 1.0)},
	{"center": Vector3(1.0, 0.5, 0.15), "radii": Vector3(0.98, 1.2, 0.95)},
	{"center": Vector3(0.0, 0.55, -0.85), "radii": Vector3(1.35, 1.3, 1.1)},
]
const SPRING_RINGS := 12
const SPRING_SEGMENTS := 20
const SPRING_BUMP := 0.12            # yüzey bozulması (yarıçap oranı)
const SPRING_SKIRT := 0.4           # alt yarıda yanlara taşma (yassı etek)
const SPRING_SINK := 0.25            # araziye gömülme (m)
const SPRING_AO_DIST := 0.7          # komşu kütleye bu kadar yakın yüzey kararır (m)
const SPRING_AO_AMOUNT := 0.85
const SPRING_STREAM_TOP := 1.55      # süzülen suyun başladığı yükseklik
const SPRING_STREAM_WIDTH := 0.1     # m
const SPRING_STREAM_BOTTOM := 0.03
const SPRING_STREAM_ROWS := 14
const SPRING_STREAM_OFFSET := 0.04   # yüzeyden çıkıntı (m)
const SPRING_PUDDLE_RADIUS := 0.6
const SPRING_PUDDLE_SEGMENTS := 20
const SPRING_PUDDLE_LIFT := 0.03
const SPRING_STREAM_SCROLL := 2.0    # süzülme hızı
const SPRING_STREAM_WAVELENGTH := 0.45  # m

# Etkileşim
const FILL_REACH := 3.0              # kaya yüzeyinden en çok uzaklık (m)
const FILL_LOOK_COS := 0.82          # kaynağa bakış (kamera yönü ile hedef arası kosinüs)
const FILL_TARGET_HEIGHT := 1.4      # bakılan noktanın kaynağın tabanından yüksekliği (m)
const HINT_BRING_SECONDS := 2.0      # uzakta sağ tıkta "Suyu çukura götür." süresi
const GUIDE_DROPS_LIMIT := 30.0      # bu kadar damlaya dek yönlendirme ipucu

# Göl
const LAKE_FREEBOARD := 0.15          # su yüzeyi çanak ağzının bu kadar altında kalır (m)
const LAKE_PUDDLE_THICKNESS := 0.04  # ilk damlanın dipteki kalınlığı
const LAKE_RAMP_DROPS := 100.0       # su bu toplamda tam seviyeye ulaşır (log ölçeği)
const LAKE_SHORE_INTERVAL := 0.2     # kıyı hesabı en sık bu aralıkla (sn)
const LAKE_LEVEL_SPEED := 1.4        # seviyenin hedefe yaklaşma hızı (1/sn)
const LAKE_SEGMENTS := 56
const LAKE_RINGS := 8
const LAKE_RADIUS_MARGIN := 0.6      # kıyı yarıçapına eklenen pay (arazi altında kalır)
const LAKE_RAYS := 24
const LAKE_RAY_STEPS := 48
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

# Dükkân: doğuş noktasından görünür, en büyük gölün (19 m) dışında, kaynak ile çukur arasındaki yolun yanında.
# Yüz (-Z) çukura döner; y araziden alınır.
const SHOP_POSITION := Vector3(10.0, 0.0, 20.0)
const SHOP_SIZE := Vector3(3.2, 2.6, 1.6)        # kaplama kutusu (en, boy, derinlik; derinlik +Z'ye uzanır)
const SHOP_COLLIDE_SIZE := Vector3(3.0, 1.1, 0.9) # tezgâh çarpışma kutusu
const SHOP_INTERACT_RADIUS := 3.5     # oyuncunun tezgâh önüne uzaklığı (m)
const SHOP_LOOK_COS := 0.75           # dükkâna bakış
const SHOP_LOOK_HEIGHT := 1.1         # bakılan noktanın zemin üstü yüksekliği
const SHOP_ROCK_CLEARANCE := 5.0      # kayalar dükkândan bu kadar uzak durur (m)
const SHOP_MODEL_PATH := "res://assets/models/shop/shop.glb"

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
