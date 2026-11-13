extends RefCounted
## GameState <-> Dictionary. Dosya islemi yok. Bozuk veri cokertmez, alan varsayilana doner.

const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Build = preload("res://scripts/core/build.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const Pieces = preload("res://scripts/core/canal_pieces.gd")


static func to_dict(state: GameState) -> Dictionary:
	return {
		"version": Cfg.SAVE_VERSION,
		"carried": state.carried,
		"total_drops": state.total_drops,
		"money": state.money,
		"total_money_earned": state.total_money_earned,
		"tool_level": state.tool_level,
		"tool_unlocked": state.tool_unlocked,
		"tool_upgrades": state.tool_upgrades.duplicate(),
		"rate_level": state.rate_level,
		"unlocked_sources": state.unlocked_sources.duplicate(),
		"canal_unlocked": state.canal_unlocked,
		"loss_upgrades": state.loss_upgrades.duplicate(),
		"last_seen_unix": state.last_seen_unix,
		"hammer_unlocked": state.hammer_unlocked,
		"hammer_owned": state.hammer_owned,
		"unlocked_pieces": state.unlocked_pieces.duplicate(),
		"unlocked_materials": state.unlocked_materials.duplicate(),
		"unlocked_structures": state.unlocked_structures.duplicate(),
		"structures": _structures_to_list(state),
	}


static func _structures_to_list(state: GameState) -> Array:
	var out: Array = []
	for item: Dictionary in state.structures:
		out.append(item.duplicate())
	return out


static func from_dict(d: Variant) -> GameState:
	var state: GameState = GameState.new()
	if not (d is Dictionary):
		return state
	var data: Dictionary = d
	var version: Variant = data.get("version", 1) # surumsuz kayit en eski bicim sayilir
	if not _is_number(version) or not _is_valid(version) or int(version) > Cfg.SAVE_VERSION:
		return state # gelecek surum ya da bozuk: yeni oyun

	state.total_drops = _number(data, "total_drops", 0.0)
	state.money = _number(data, "money", 0.0)
	state.total_money_earned = maxf(_number(data, "total_money_earned", 0.0), state.money)
	state.tool_level = _level(data, "tool_level", Cfg.TOOLS.size())
	state.rate_level = _level(data, "rate_level", Cfg.RATE_LEVELS.size())
	# Surum 1 kayitlarinda yeni alanlar yok: sahip olunan aletler ve kaynaklar kilidi acik sayilir.
	state.tool_unlocked = maxi(_level(data, "tool_unlocked", Cfg.TOOLS.size()), state.tool_level)
	_load_tool_upgrades(state, data.get("tool_upgrades", {}))
	state.carried = minf(_number(data, "carried", 0.0), Economy.tool_capacity(state))
	state.last_seen_unix = int(_number(data, "last_seen_unix", 0.0))
	var raw_canal: Variant = data.get("canal_unlocked", false)
	state.canal_unlocked = typeof(raw_canal) == TYPE_BOOL and raw_canal

	var raw_unlocked: Variant = data.get("unlocked_sources", [])
	if raw_unlocked is Array:
		for id: Variant in raw_unlocked:
			if id is String and not Economy.source_def(id).is_empty() and not state.unlocked_sources.has(id):
				state.unlocked_sources.append(id)
	var raw_structs_unlocked: Variant = data.get("unlocked_structures", [])
	if raw_structs_unlocked is Array:
		for id: Variant in raw_structs_unlocked:
			if id is String and Build.is_kind(id) and not Build.is_source(id) and not state.unlocked_structures.has(id):
				state.unlocked_structures.append(id)

	var hammer_unlocked: Variant = data.get("hammer_unlocked", false)
	var hammer_owned: Variant = data.get("hammer_owned", false)
	state.hammer_owned = typeof(hammer_owned) == TYPE_BOOL and hammer_owned
	state.hammer_unlocked = (typeof(hammer_unlocked) == TYPE_BOOL and hammer_unlocked) or state.hammer_owned
	_load_id_list(state.unlocked_pieces, data.get("unlocked_pieces", null), Pieces.PIECES)
	_load_id_list(state.unlocked_materials, data.get("unlocked_materials", null), Pieces.MATERIALS)

	if int(version) >= 3:
		_load_structures(state, data.get("structures", []))
	else:
		_migrate_old_structures(state, data)
	Build.rebuild_counts(state)
	# Elde olan yapinin kilidi acik sayilir (kayit eksik yazilmis olsa bile).
	for owned: String in state.counts:
		if Build.is_source(owned):
			if not state.unlocked_sources.has(owned):
				state.unlocked_sources.append(owned)
		elif not state.unlocked_structures.has(owned):
			state.unlocked_structures.append(owned)

	var raw_loss: Variant = data.get("loss_upgrades", [])
	if raw_loss is Array:
		for id: Variant in raw_loss:
			if id is String and not Economy.loss_def(id).is_empty() and not state.loss_upgrades.has(id):
				state.loss_upgrades.append(id)
	return state


## Bilinmeyen id, sahip olunmayan alet, tam sayi olmayan ya da 1..MAX disi seviye atilir.
static func _load_tool_upgrades(state: GameState, raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	for key: Variant in raw:
		if not (key is String):
			continue
		var index: int = Economy.tool_index(key)
		if index < 0 or index > state.tool_level:
			continue
		var level: Variant = raw[key]
		if not _is_number(level) or not _is_valid(level):
			continue
		var f: float = float(level)
		if f == floorf(f) and f >= 1.0 and f <= Cfg.TOOL_UPGRADE_MAX_LEVEL:
			state.tool_upgrades[key] = int(f)


## Kayittaki kimlikleri (varsayilan acik olanlara ek olarak) ekler; bilinmeyen ya da dize olmayan atilir.
static func _load_id_list(target: Array[String], raw: Variant, known: Dictionary) -> void:
	if not (raw is Array):
		return
	for id: Variant in raw:
		if id is String and known.has(id) and not target.has(id):
			target.append(id)


## Surum 3: dogrulamali yukleme. Bilinmeyen tur, sayi olmayan/sonsuz koordinat atilir; en fazla MAX_STRUCTURES.
static func _load_structures(state: GameState, raw: Variant) -> void:
	if not (raw is Array):
		return
	for item: Variant in raw:
		if state.structures.size() >= BuildCfg.MAX_STRUCTURES:
			break
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var kind: Variant = d.get("kind", null)
		if not (kind is String) or not Build.is_kind(kind):
			continue
		var placed_raw: Variant = d.get("placed", true)
		var placed: bool = not (typeof(placed_raw) == TYPE_BOOL and not placed_raw)
		if not placed:
			Build.add(state, kind, 0.0, 0.0, 0.0, false)
			continue
		var x: Variant = d.get("x", null)
		var z: Variant = d.get("z", null)
		if not _is_finite_number(x) or not _is_finite_number(z):
			continue
		var rot: Variant = d.get("rot", 0.0)
		Build.add(state, kind, float(x), float(z), float(rot) if _is_finite_number(rot) else 0.0, true)


## Surum 1 ve 2: eski "sources" adetleri konumsuz (placed=false) yapilar olarak korunur; eski "Kamis kenari" /
## "Golge agaclari" yukseltmeleri 7'ser konumsuz kamis/agaca doner.
static func _migrate_old_structures(state: GameState, data: Dictionary) -> void:
	var raw_sources: Variant = data.get("sources", {})
	if raw_sources is Dictionary:
		for key: Variant in raw_sources:
			if not (key is String) or Economy.source_def(key).is_empty():
				continue
			var count: Variant = raw_sources[key]
			if _is_number(count) and _is_valid(count) and float(count) >= 1.0:
				_add_unplaced(state, key, int(float(count)))
	var raw_loss: Variant = data.get("loss_upgrades", [])
	if raw_loss is Array:
		for id: Variant in raw_loss:
			if id is String and BuildCfg.LEGACY_LOSS_MIGRATION.has(id):
				var kind: String = BuildCfg.LEGACY_LOSS_MIGRATION[id]
				if Build.count(state, kind) == 0:
					_add_unplaced(state, kind, BuildCfg.LEGACY_LOSS_MIGRATION_COUNT)


static func _add_unplaced(state: GameState, kind: String, amount: int) -> void:
	for i: int in amount:
		if state.structures.size() >= BuildCfg.MAX_STRUCTURES:
			return
		Build.add(state, kind, 0.0, 0.0, 0.0, false)


static func _is_finite_number(v: Variant) -> bool:
	return _is_number(v) and not is_nan(float(v)) and not is_inf(float(v)) and absf(float(v)) <= Cfg.SAVE_MAX_NUMBER


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Sonlu, negatif olmayan ve makul buyuklukte mi.
static func _is_valid(v: Variant) -> bool:
	var f: float = float(v)
	return not is_nan(f) and not is_inf(f) and f >= 0.0 and f <= Cfg.SAVE_MAX_NUMBER


static func _number(data: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = data.get(key, fallback)
	if _is_number(v) and _is_valid(v):
		return float(v)
	return fallback


## Seviye: tam sayi degerli ve 0..count-1 araliginda degilse 0.
static func _level(data: Dictionary, key: String, count: int) -> int:
	var v: Variant = data.get(key, 0)
	if not _is_number(v) or not _is_valid(v):
		return 0
	var f: float = float(v)
	if f != floorf(f) or f >= count:
		return 0
	return int(f)
