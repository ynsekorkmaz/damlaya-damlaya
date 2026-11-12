extends RefCounted
## GameState <-> Dictionary. Dosya islemi yok. Bozuk veri cokertmez, alan varsayilana doner.

const Cfg = preload("res://scripts/core/economy_config.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")


static func to_dict(state: GameState) -> Dictionary:
	return {
		"version": Cfg.SAVE_VERSION,
		"carried": state.carried,
		"total_drops": state.total_drops,
		"money": state.money,
		"total_money_earned": state.total_money_earned,
		"tool_level": state.tool_level,
		"rate_level": state.rate_level,
		"sources": state.sources.duplicate(),
		"loss_upgrades": state.loss_upgrades.duplicate(),
		"last_seen_unix": state.last_seen_unix,
	}


static func from_dict(d: Variant) -> GameState:
	var state: GameState = GameState.new()
	if not (d is Dictionary):
		return state
	var data: Dictionary = d
	var version: Variant = data.get("version", Cfg.SAVE_VERSION)
	if not _is_number(version) or not _is_valid(version) or int(version) > Cfg.SAVE_VERSION:
		return state # gelecek surum ya da bozuk: yeni oyun

	state.total_drops = _number(data, "total_drops", 0.0)
	state.money = _number(data, "money", 0.0)
	state.total_money_earned = maxf(_number(data, "total_money_earned", 0.0), state.money)
	state.tool_level = _level(data, "tool_level", Cfg.TOOLS.size())
	state.rate_level = _level(data, "rate_level", Cfg.RATE_LEVELS.size())
	state.carried = minf(_number(data, "carried", 0.0), Economy.tool_capacity(state))
	state.last_seen_unix = int(_number(data, "last_seen_unix", 0.0))

	var raw_sources: Variant = data.get("sources", {})
	if raw_sources is Dictionary:
		for key: Variant in raw_sources:
			if not (key is String) or Economy.source_def(key).is_empty():
				continue
			var count: Variant = raw_sources[key]
			if _is_number(count) and _is_valid(count) and float(count) >= 1.0 and float(count) <= Cfg.MAX_SOURCE_COUNT:
				state.sources[key] = int(count)

	var raw_loss: Variant = data.get("loss_upgrades", [])
	if raw_loss is Array:
		for id: Variant in raw_loss:
			if id is String and not Economy.loss_def(id).is_empty() and not state.loss_upgrades.has(id):
				state.loss_upgrades.append(id)
	return state


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
