extends Node
## Oyunun tek durum sahibi: ekonomi durumu, kanal ızgarası, kayıt ve ipucu metni.

signal poured(drops: float, money: float)
signal filled(amount: float)
signal stage_changed(index: int)
signal prompt_changed(text: String)
signal purchased(kind: String, id: String)
signal shop_requested

const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const SaveCodec = preload("res://scripts/core/save_codec.gd")
const CanalGrid = preload("res://scripts/core/canal_grid.gd")
const CanalFlow = preload("res://scripts/core/canal_flow.gd")

const SAVE_PATH: String = "user://save_v1.json"
const SAVE_TMP_PATH: String = "user://save_v1.json.tmp"
const SAVE_INTERVAL: float = 3.0
const NO_SAVE_ARG: String = "--no-save"
const SECONDS_PER_MINUTE: float = 60.0

var state: GameState = GameState.new()
var canal: CanalGrid = CanalGrid.new()
var prompt_text: String = ""

var _save_enabled: bool = true
var _save_timer: float = 0.0
var _flow_cache: Dictionary = {}
var _last_stage: int = 0


func _ready() -> void:
	setup(not OS.get_cmdline_user_args().has(NO_SAVE_ARG))


## Kayıt kullanımını ayarlar; açıksa kayıt dosyasını yükler ve çevrimdışı üretimi uygular.
func setup(use_save: bool) -> void:
	_save_enabled = use_save
	if _save_enabled:
		_load()
		Economy.apply_offline(state, int(Time.get_unix_time_from_system()), _canal_delivered())
	_last_stage = Economy.stage_index(state)


func _process(delta: float) -> void:
	Economy.tick(state, delta, _canal_delivered())
	var stage: int = Economy.stage_index(state)
	if stage != _last_stage:
		_last_stage = stage
		stage_changed.emit(stage)
	if _save_enabled:
		_save_timer += delta
		if _save_timer >= SAVE_INTERVAL:
			_save_timer = 0.0
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()


## Elde taşınan suyu artırır. Eklenen miktarı döndürür.
func try_fill(delta: float) -> float:
	var added: float = Economy.fill(state, delta)
	if added > 0.0:
		filled.emit(added)
	return added


## Eldeki suyu çukura döker. Kazanılan parayı döndürür.
func try_pour() -> float:
	var drops: float = state.carried
	if not (drops > 0.0):
		return 0.0
	var money: float = Economy.pour(state)
	poured.emit(drops, money)
	return money


## Pasif ve kanal gelirinin para/dakika karşılığı.
func income_per_minute() -> float:
	var drops_per_sec: float = Economy.passive_rate_net(state) + _canal_delivered()
	return drops_per_sec / Economy.drops_per_money(state) * SECONDS_PER_MINUTE


# ---------- Satın alma ----------

func buy_tool() -> bool:
	return _finish_purchase(Economy.buy_tool(state), "tool", Cfg.TOOLS[state.tool_level]["id"])


func buy_rate() -> bool:
	return _finish_purchase(Economy.buy_rate(state), "rate", "rate")


func buy_source(id: String) -> bool:
	return _finish_purchase(Economy.buy_source(state, id), "source", id)


func buy_loss(id: String) -> bool:
	return _finish_purchase(Economy.buy_loss(state, id), "loss", id)


func _finish_purchase(ok: bool, kind: String, id: String) -> bool:
	if not ok:
		return false
	purchased.emit(kind, id)
	save()
	return true


## Etkileşim, oyuncu dükkânın önündeyken E'ye basınca çağırır; panel dinler.
func request_shop() -> void:
	shop_requested.emit()


func set_prompt(text: String) -> void:
	if text == prompt_text:
		return
	prompt_text = text
	prompt_changed.emit(text)


func _canal_delivered() -> float:
	var result: Dictionary = CanalFlow.compute_cached(canal, _flow_cache)
	return float(result.get("delivered", 0.0))


# ---------- Kayıt ----------

func save() -> void:
	if not _save_enabled:
		return
	state.last_seen_unix = int(Time.get_unix_time_from_system())
	var data: Dictionary = SaveCodec.to_dict(state)
	data["canal"] = canal.to_dict()
	var file: FileAccess = FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	var err: int = dir.rename(SAVE_TMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_warning("Kayıt dosyası yeniden adlandırılamadı: %s" % error_string(err))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Kayıt okunamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Kayıt dosyası bozuk, yeni oyun başlıyor.")
		return
	state = SaveCodec.from_dict(json.data)
	if json.data is Dictionary:
		canal.from_dict((json.data as Dictionary).get("canal", null))
