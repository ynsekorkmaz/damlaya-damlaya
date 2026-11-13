extends Node
## Oyunun tek durum sahibi: ekonomi durumu, kanal ağı, serbest yapılar, kayıt ve ipucu metni.
## Dünya katmanı yerleştirme için can_place_canal / place_canal / remove_canal / rotate_canal / toggle_gate / canal_result ve
## can_place_structure / place_structure / remove_structure / structures / set_structure_position çağırır;
## değişimde structures_changed yayılır.

signal poured(drops: float, money: float)
signal filled(amount: float)
signal stage_changed(index: int)
signal prompt_changed(text: String)
signal purchased(kind: String, id: String)
signal shop_requested
signal purchase_denied(kind: String, id: String) ## Satın alma başarısız (para ya da koşul yetmedi); ses için
signal structures_changed ## Kanal ağı ya da serbest yapılar değişti (kur, sök, döndür, savak)

const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Cfg = preload("res://scripts/core/economy_config.gd")
const SaveCodec = preload("res://scripts/core/save_codec.gd")
const CanalNetwork = preload("res://scripts/core/canal_network.gd")
const CanalNetworkFlow = preload("res://scripts/core/canal_network_flow.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")
const Build = preload("res://scripts/core/build.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")

const SAVE_PATH: String = "user://save_v1.json"
const SAVE_TMP_PATH: String = "user://save_v1.json.tmp"
const SAVE_INTERVAL: float = 3.0
const NO_SAVE_ARG: String = "--no-save"
const SECONDS_PER_MINUTE: float = 60.0

var state: GameState = GameState.new()
var canal: CanalNetwork = CanalNetwork.new()
var prompt_text: String = ""

var _save_enabled: bool = true
var _save_timer: float = 0.0
var _flow_cache: Dictionary = {}
var _last_stage: int = 0
var _primed: bool = false ## İlk karede aşama yalnızca eşitlenir; açılışta aşama değişimi sayılmaz


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
	if not _primed:
		_primed = true
		_last_stage = stage
	elif stage != _last_stage:
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

## Dükkân: yalnızca kilidi açılmış sıradaki alet.
func buy_tool() -> bool:
	if not Economy.next_tool_unlocked(state):
		return false
	var id: String = Cfg.TOOLS[state.tool_level + 1]["id"]
	return _finish_purchase(Economy.buy_tool(state), "tool", id)


## Geliştirmeler: sıradaki kilitli aletin kilidini açar.
func unlock_tool() -> bool:
	if Economy.cost_tool_unlock(state) < 0.0:
		return false
	var id: String = Cfg.TOOLS[state.tool_unlocked + 1]["id"]
	return _finish_purchase(Economy.unlock_tool(state), "tool_unlock", id)


func upgrade_tool(id: String) -> bool:
	var index: int = Economy.tool_index(id)
	if index < 0:
		return false
	return _finish_purchase(Economy.upgrade_tool(state, index), "tool_upgrade", id)


## Çekiç: kilidi Geliştirmeler'den açılır, dükkândan alınır; yapı kurmak için şarttır.
func unlock_hammer() -> bool:
	return _finish_purchase(Economy.unlock_hammer(state), "hammer_unlock", "hammer")


func buy_hammer() -> bool:
	return _finish_purchase(Economy.buy_hammer(state), "hammer", "hammer")


func buy_rate() -> bool:
	return _finish_purchase(Economy.buy_rate(state), "rate", "rate")


## Pasif kaynak kilidi. Adet artık çekiçle kurulan yapıdır (place_structure).
func unlock_source(id: String) -> bool:
	return _finish_purchase(Economy.unlock_source(state, id), "source_unlock", id)


## Kamış ve gölge ağacı kilidi (kaynaklar için unlock_source).
func unlock_structure(kind: String) -> bool:
	if Build.is_source(kind):
		return false
	return _finish_purchase(Build.unlock(state, kind), "structure_unlock", kind)


func buy_loss(id: String) -> bool:
	return _finish_purchase(Economy.buy_loss(state, id), "loss", id)


func unlock_canal() -> bool:
	return _finish_purchase(Economy.unlock_canal(state), "canal_unlock", "canal")


## Kanal parça türü ve malzeme kilitleri: kanal sistemi açık olmalı.
func unlock_piece(id: String) -> bool:
	if not state.canal_unlocked:
		return false
	return _finish_purchase(Economy.unlock_piece(state, id), "piece_unlock", id)


func unlock_material(id: String) -> bool:
	if not state.canal_unlocked:
		return false
	return _finish_purchase(Economy.unlock_material(state, id), "material_unlock", id)


## Kanal öğeleri: kanal sistemi açık olmalı, ücret ekonomi parasından düşer, ağ yalnızca maliyeti verir.
func open_spring(id: String) -> bool:
	if not state.canal_unlocked or canal.is_spring_open(id):
		return false
	var cost: int = canal.spring_cost(id)
	if cost < 0 or not Economy.spend(state, float(cost)):
		return false
	return _finish_purchase(canal.open_spring(id), "canal_spring", id)


func upgrade_canal_width() -> bool:
	if not state.canal_unlocked:
		return false
	var cost: int = canal.width_cost()
	if cost < 0 or not Economy.spend(state, float(cost)):
		return false
	return _finish_purchase(canal.upgrade_width(), "canal_width", "width")


func upgrade_canal_lining() -> bool:
	if not state.canal_unlocked:
		return false
	var cost: int = canal.lining_cost()
	if cost < 0 or not Economy.spend(state, float(cost)):
		return false
	return _finish_purchase(canal.upgrade_lining(), "canal_lining", "lining")


func _finish_purchase(ok: bool, kind: String, id: String) -> bool:
	if not ok:
		purchase_denied.emit(kind, id)
		return false
	purchased.emit(kind, id)
	save()
	return true


# ---------- Yerleştirme arayüzü (dünya katmanı çağırır) ----------

## Kanal akış sonucu (ağ değişmedikçe önbellekten): input, delivered, leaked, overflow, wasted, flowing, flow_dir, per_spring.
func canal_result() -> Dictionary:
	return CanalNetworkFlow.compute_cached(canal, _flow_cache)


## Bu parça ve malzemenin şimdi konsa ödenecek fiyatı; bilinmeyen için -1.
func canal_piece_cost(piece_id: String, material: String) -> int:
	return canal.cost(piece_id, material)


## {ok, reason_tr, cost}. Neden sırası: çekiç, kanal kilidi, bilinmeyen, parça/malzeme kilidi, sınır, dolu hücre, para.
func can_place_canal(col: int, row: int, piece_id: String, _rotation: int, material: String) -> Dictionary:
	var cost: int = canal.cost(piece_id, material)
	var result: Dictionary = {"ok": false, "reason_tr": "", "cost": cost}
	if not state.hammer_owned:
		result["reason_tr"] = BuildCfg.REASON_NO_HAMMER_TR
	elif not state.canal_unlocked:
		result["reason_tr"] = BuildCfg.REASON_CANAL_LOCKED_TR
	elif not Pieces.has_piece(piece_id):
		result["reason_tr"] = BuildCfg.REASON_UNKNOWN_PIECE_TR
	elif not Pieces.has_material(material):
		result["reason_tr"] = BuildCfg.REASON_UNKNOWN_MATERIAL_TR
	elif not state.unlocked_pieces.has(piece_id) or not state.unlocked_materials.has(material):
		result["reason_tr"] = BuildCfg.REASON_LOCKED_TR
	elif not canal.in_bounds(col, row):
		result["reason_tr"] = BuildCfg.REASON_OUT_OF_BOUNDS_TR
	elif not canal.get_piece(col, row).is_empty():
		result["reason_tr"] = BuildCfg.REASON_OCCUPIED_TR
	elif state.money < float(cost):
		result["reason_tr"] = BuildCfg.REASON_NO_MONEY_TR
	else:
		result["ok"] = true
	return result


## Kurallar sağlanırsa parayı düşer, parçayı koyar, kaydeder ve structures_changed yayar.
func place_canal(col: int, row: int, piece_id: String, rotation: int, material: String) -> bool:
	var check: Dictionary = can_place_canal(col, row, piece_id, rotation, material)
	if not check["ok"]:
		return false
	var cost: int = check["cost"]
	if not canal.place(col, row, piece_id, rotation, material):
		return false
	state.money -= float(cost)
	_structures_dirty()
	return true


## Parçayı söker, iadeyi paraya ekler ve döndürür. Çekiç yoksa ya da hücre boşsa 0.
func remove_canal(col: int, row: int) -> int:
	if not state.hammer_owned or canal.get_piece(col, row).is_empty():
		return 0
	var refund: int = canal.remove(col, row)
	state.money += float(refund)
	_structures_dirty()
	return refund


## Parçayı 90 derece saat yönünde çevirir (çekiç gerekir).
func rotate_canal(col: int, row: int) -> bool:
	if not state.hammer_owned or not canal.rotate(col, row):
		return false
	_structures_dirty()
	return true


## Savağı açar/kapatır (çekiç gerekmez; yalnızca savak parçasında çalışır).
func toggle_gate(col: int, row: int) -> bool:
	if not canal.toggle_gate(col, row):
		return false
	_structures_dirty()
	return true


## {ok, reason_tr, cost, note_tr}: kamış, gölge ağacı ve pasif kaynak yapıları. Konum kuralları dünya katmanındadır.
func can_place_structure(kind: String) -> Dictionary:
	return Build.can_place(state, kind)


func place_structure(kind: String, x: float, z: float, rot: float) -> bool:
	if not Build.place(state, kind, x, z, rot):
		return false
	_structures_dirty()
	return true


## İade: söküldükten sonraki adetle hesaplanan fiyatın yarısı (paraya eklenir). Çekiç yoksa ya da indeks geçersizse 0.
func remove_structure(index: int) -> int:
	if not state.hammer_owned or index < 0 or index >= state.structures.size():
		return 0
	var refund: int = Build.remove(state, index)
	_structures_dirty()
	return refund


## Yapı listesinin kopyası; öğe: {kind, x, z, rot, placed}. placed=false olanlara dünya katmanı yer verir.
func structures() -> Array:
	var out: Array = []
	for item: Dictionary in state.structures:
		out.append(item.duplicate())
	return out


## Konumsuz (eski kayıttan göçen) yapıya yer verir.
func set_structure_position(index: int, x: float, z: float, rot: float) -> bool:
	if not Build.set_position(state, index, x, z, rot):
		return false
	_structures_dirty()
	return true


func _structures_dirty() -> void:
	structures_changed.emit()
	save()


## Etkileşim, oyuncu dükkânın önündeyken E'ye basınca çağırır; panel dinler.
func request_shop() -> void:
	shop_requested.emit()


func set_prompt(text: String) -> void:
	if text == prompt_text:
		return
	prompt_text = text
	prompt_changed.emit(text)


func _canal_delivered() -> float:
	return float(canal_result().get("delivered", 0.0))


# ---------- Kayıt ----------

func save() -> void:
	if not _save_enabled:
		return
	state.last_seen_unix = int(Time.get_unix_time_from_system())
	var data: Dictionary = SaveCodec.to_dict(state)
	data["canal"] = canal.to_dict() # yeni ağ biçimi; eski ızgara biçimi okununca boş ağa döner
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
