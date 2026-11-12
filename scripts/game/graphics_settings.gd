extends Node
## Grafik kalitesi: ön ayarı (graphics_config.gd) ortama, güneşe, görüntü alanına ve arazi
## malzemesine anında uygular; seçimi user://settings.json'a yazar (oyun kaydından ayrı).
## Compatibility (OpenGL) çizicisinde desteklenmeyen efektler (SSAO, SSIL, hacimsel sis, TAA)
## sessizce atlanır. Okuma/yazma hatası oyunu çökertmez.

signal quality_changed(level: int)
signal show_fps_changed(on: bool)

const GraphicsConfig = preload("res://scripts/core/graphics_config.gd")
const TerrainBuilder = preload("res://scripts/world/terrain_builder.gd")

const KEY_QUALITY: String = "quality"
const KEY_SHOW_FPS: String = "show_fps"
const ARG_QUALITY: String = "--quality="
const ARG_NO_SAVE: String = "--no-save"
const COMPAT_METHOD: String = "gl_compatibility"

var level: int = GraphicsConfig.DEFAULT_LEVEL
var show_fps: bool = false

var _environment: Environment
var _sun: DirectionalLight3D
var _file_enabled: bool = true
var _saved_level: int = GraphicsConfig.DEFAULT_LEVEL   # dosyadaki seçim (--quality bunu değiştirmez)


## Komut satırı: --no-save dosyayı hiç okumaz/yazmaz; --quality=low|medium|high dosyaya yazmadan uygulanır.
func _ready() -> void:
	name = "GraphicsSettings"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_file_enabled = not args.has(ARG_NO_SAVE)
	var forced: int = -1
	for arg: String in args:
		if arg.begins_with(ARG_QUALITY):
			forced = GraphicsConfig.level_from_arg(arg.substr(ARG_QUALITY.length()))
	if _file_enabled:
		_load_file()
	if forced >= 0:
		level = forced


## Ortam ve güneş bağlanınca ayar ilk kez uygulanır.
func bind(environment: Environment, sun: DirectionalLight3D) -> void:
	_environment = environment
	_sun = sun
	apply(level)
	show_fps_changed.emit(show_fps)


static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == COMPAT_METHOD


func set_level(new_level: int) -> void:
	var clamped: int = GraphicsConfig.clamp_level(new_level)
	if clamped == level:
		return
	level = clamped
	_saved_level = clamped
	apply(level)
	_save_file()


func set_show_fps(on: bool) -> void:
	if on == show_fps:
		return
	show_fps = on
	show_fps_changed.emit(on)
	_save_file()


## Ön ayarı uygular ve quality_changed yayar.
func apply(new_level: int) -> void:
	level = GraphicsConfig.clamp_level(new_level)
	var p: Dictionary = GraphicsConfig.preset(level)
	var compat: bool = is_compatibility()
	_apply_viewport(p, compat)
	_apply_sun(p)
	_apply_environment(p, compat)
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_atlas"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(p["shadow_filter"]) as RenderingServer.ShadowQuality)
	TerrainBuilder.apply_quality(float(p["terrain_normal"]), int(p["terrain_tex_k"]))
	quality_changed.emit(level)


func _apply_viewport(p: Dictionary, compat: bool) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	vp.scaling_3d_scale = float(p["render_scale"])
	var msaa: int = int(p["msaa"])
	match msaa:
		2:
			vp.msaa_3d = Viewport.MSAA_2X
		4:
			vp.msaa_3d = Viewport.MSAA_4X
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(p["fxaa"]) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = bool(p["taa"]) and not compat


func _apply_sun(p: Dictionary) -> void:
	if _sun == null:
		return
	var on: bool = bool(p["shadows"])
	_sun.shadow_enabled = on
	_sun.light_energy = float(p["sun_energy"])
	if not on:
		return
	match int(p["shadow_splits"]):
		4:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		2:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_:
			_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = float(p["shadow_distance"])
	_sun.directional_shadow_split_1 = float(p["shadow_split_1"])
	_sun.directional_shadow_split_2 = float(p["shadow_split_2"])
	_sun.directional_shadow_split_3 = float(p["shadow_split_3"])
	_sun.shadow_bias = float(p["shadow_bias"])
	_sun.shadow_normal_bias = float(p["shadow_normal_bias"])
	_sun.shadow_blur = float(p["shadow_blur"])


func _apply_environment(p: Dictionary, compat: bool) -> void:
	var env: Environment = _environment
	if env == null:
		return
	env.tonemap_mode = int(p["tonemap"]) as Environment.ToneMapper
	env.tonemap_exposure = float(p["tonemap_exposure"])
	env.tonemap_white = float(p["tonemap_white"])
	if bool(p["ambient_sky"]):
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = float(p["ambient_energy"])
	env.fog_enabled = bool(p["fog"])
	env.fog_density = float(p["fog_density"])
	env.fog_sky_affect = float(p["fog_sky_affect"])
	env.glow_enabled = bool(p["glow"])
	env.glow_intensity = float(p["glow_intensity"])
	env.glow_bloom = float(p["glow_bloom"])
	env.glow_hdr_threshold = float(p["glow_threshold"])
	# Yalnızca Forward+ (Compatibility'de bu efektler yok; atlanır)
	env.ssao_enabled = bool(p["ssao"]) and not compat
	env.ssil_enabled = bool(p["ssil"]) and not compat
	env.volumetric_fog_enabled = bool(p["volumetric_fog"]) and not compat


# ---------- Dosya ----------

func _load_file() -> void:
	if not FileAccess.file_exists(GraphicsConfig.SETTINGS_PATH):
		return
	var file: FileAccess = FileAccess.open(GraphicsConfig.SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Ayar dosyası okunamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("Ayar dosyası bozuk, varsayılanlar kullanılıyor.")
		return
	var data: Dictionary = json.data
	if data.get(KEY_QUALITY) is float:
		level = GraphicsConfig.clamp_level(int(data[KEY_QUALITY]))
		_saved_level = level
	if data.get(KEY_SHOW_FPS) is bool:
		show_fps = data[KEY_SHOW_FPS]


func _save_file() -> void:
	if not _file_enabled:
		return
	var data: Dictionary = {KEY_QUALITY: _saved_level, KEY_SHOW_FPS: show_fps}
	var file: FileAccess = FileAccess.open(GraphicsConfig.SETTINGS_TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Ayar dosyası yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	var err: int = dir.rename(GraphicsConfig.SETTINGS_TMP_PATH.get_file(), GraphicsConfig.SETTINGS_PATH.get_file())
	if err != OK:
		push_warning("Ayar dosyası yeniden adlandırılamadı: %s" % error_string(err))
