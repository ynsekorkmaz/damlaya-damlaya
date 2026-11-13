extends RefCounted
## Serbest yapıların yer kuralları (kamış, gölge ağacı, çatlak, çiğ otu, bulut direği, çeşme, dere ağzı). Saf mantık.
## bağlam (ctx): {shore: float (gölün o anki kıyı yarıçapı), max_radius: float (en büyük göl yarıçapı),
## structures: Array (öğe: {kind, x, z, rot, placed}), on_rock: bool (bakılan yer bir kaya)}.
## Sonuç: {ok: bool, reason_tr: String}.

const Config = preload("res://scripts/core/config.gd")
const BuildCfg = preload("res://scripts/core/build_config.gd")
const CanalField = preload("res://scripts/core/canal_field.gd")

const GOLDEN_ANGLE: float = 2.399963
const AUTO_TRIES: int = 240


static func check_free(kind: String, x: float, z: float, ctx: Dictionary) -> Dictionary:
	var reason: String = _reason(kind, x, z, ctx)
	return {"ok": reason.is_empty(), "reason_tr": reason}


static func _reason(kind: String, x: float, z: float, ctx: Dictionary) -> String:
	var r: float = sqrt(x * x + z * z)
	var shore: float = float(ctx.get("shore", 0.0))
	var structures: Array = ctx.get("structures", [])
	if r > Config.VALLEY_RADIUS - Config.PLACE_VALLEY_MARGIN:
		return BuildCfg.REASON_OUT_OF_VALLEY_TR
	if CanalField.contains(x, z, Config.PLACE_FIELD_MARGIN):
		return BuildCfg.REASON_IN_CANAL_FIELD_TR
	var shop := Vector2(Config.SHOP_POSITION.x, Config.SHOP_POSITION.z)
	if Vector2(x, z).distance_to(shop) < Config.PLACE_SHOP_CLEARANCE:
		return BuildCfg.REASON_NEAR_SHOP_TR
	var spring := Vector2(Config.SPRING_POSITION.x, Config.SPRING_POSITION.z)
	if kind != "crack" and Vector2(x, z).distance_to(spring) < Config.SPRING_RADIUS + Config.PLACE_SPRING_ROCK_CLEARANCE:
		return BuildCfg.REASON_NEAR_SPRING_ROCK_TR
	if kind != "reeds" and r < shore:
		return BuildCfg.REASON_IN_LAKE_TR
	match kind:
		"reeds":
			if absf(r - shore) > Config.PLACE_REED_SHORE_RANGE:
				return BuildCfg.REASON_REEDS_SHORE_TR
			if _too_close(structures, x, z, Config.PLACE_REED_MIN_DISTANCE, "reeds"):
				return BuildCfg.REASON_TOO_CLOSE_TR
		"shade_tree":
			if r <= float(ctx.get("max_radius", 0.0)):
				return BuildCfg.REASON_TREE_OUTSIDE_LAKE_TR
			if _too_close(structures, x, z, Config.PLACE_TREE_MIN_DISTANCE, "shade_tree"):
				return BuildCfg.REASON_TREE_CLOSE_TR
		"crack":
			if not bool(ctx.get("on_rock", false)):
				return BuildCfg.REASON_CRACK_ROCK_TR
			if _too_close(structures, x, z, Config.PLACE_REED_MIN_DISTANCE, "crack"):
				return BuildCfg.REASON_TOO_CLOSE_TR
		"stream_mouth":
			if r <= Config.PLACE_STREAM_MOUTH_MIN_R:
				return BuildCfg.REASON_STREAM_EDGE_TR
			if _too_close(structures, x, z, Config.PLACE_MIN_DISTANCE, ""):
				return BuildCfg.REASON_TOO_CLOSE_TR
		_:
			if _too_close(structures, x, z, Config.PLACE_MIN_DISTANCE, ""):
				return BuildCfg.REASON_TOO_CLOSE_TR
	return ""


## Yerleştirilmiş bir yapı (kind boşsa herhangi bir tür) limit içinde mi.
static func _too_close(structures: Array, x: float, z: float, limit: float, kind: String) -> bool:
	for item: Variant in structures:
		var s: Dictionary = item
		if not bool(s.get("placed", true)):
			continue
		if not kind.is_empty() and String(s.get("kind", "")) != kind:
			continue
		var dx: float = float(s["x"]) - x
		var dz: float = float(s["z"]) - z
		if dx * dx + dz * dz < limit * limit:
			return true
	return false


## Konumsuz yapıya yer verir: {found, x, z, rot}. index: aynı türden kaçıncı olduğu (halka dağılımı için).
## ctx["rock_spots"]: Array[Vector2] (çatlak adayları, büyük kayaların merkezi).
static func auto_place(kind: String, index: int, ctx: Dictionary) -> Dictionary:
	var shore: float = float(ctx.get("shore", 0.0))
	var max_radius: float = float(ctx.get("max_radius", 0.0))
	var rot: float = fposmod(float(index) * 1.7, TAU)
	if kind == "crack":
		var spots: Array = ctx.get("rock_spots", [])
		var c2: Dictionary = ctx.duplicate()
		c2["on_rock"] = true
		for i in range(spots.size()):
			var spot: Vector2 = spots[(index + i) % spots.size()]
			if bool(check_free(kind, spot.x, spot.y, c2)["ok"]):
				return {"found": true, "x": spot.x, "z": spot.y, "rot": rot}
		return {"found": false, "x": 0.0, "z": 0.0, "rot": 0.0}
	for k in range(AUTO_TRIES):
		var ang: float = GOLDEN_ANGLE * float(index + k * 7)
		var radius: float
		match kind:
			"reeds":
				radius = shore + sin(float(index * 3 + k) * 1.3) * 1.6
			"shade_tree":
				radius = max_radius + 5.0 + float((index + k) % 4) * 3.0 + float(floori(float(index) / 8.0)) * 4.0
			"stream_mouth":
				radius = Config.PLACE_STREAM_MOUTH_MIN_R + 1.0 + float((index + k) % 3) * 3.0
			_:
				radius = max_radius + 6.0 + float((index + k) % 6) * 4.0
		var x: float = cos(ang) * radius
		var z: float = sin(ang) * radius
		if bool(check_free(kind, x, z, ctx)["ok"]):
			return {"found": true, "x": x, "z": z, "rot": rot}
	return {"found": false, "x": 0.0, "z": 0.0, "rot": 0.0}


## Kıyı için: göl suyu varsa gerçek kıyı, yoksa çanak yarıçapı.
static func effective_shore(lake_radius: float, basin_radius: float) -> float:
	return lake_radius if lake_radius > 0.05 else basin_radius
