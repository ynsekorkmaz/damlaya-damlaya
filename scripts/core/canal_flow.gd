extends RefCounted
## Kanal akis hesabi (belge 5.3). Saf fonksiyonlar, durum tutmaz.

const CanalConfig = preload("res://scripts/core/canal_config.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func _is_canal(grid, c: Vector2i) -> bool:
	return grid.get_cell(c.x, c.y) != CanalConfig.CELL_EMPTY


static func _is_exit(grid, c: Vector2i) -> bool:
	return c.x == CanalConfig.EXIT_COL and _is_canal(grid, c)


## Sonuc: {input, delivered, leaked, overflow, wasted, flowing: Array[Vector2i], flow_dir: Dictionary}
static func compute(grid) -> Dictionary:
	var result: Dictionary = {
		"input": 0.0, "delivered": 0.0, "leaked": 0.0, "overflow": 0.0, "wasted": 0.0,
		"flowing": [], "flow_dir": {},
	}
	var flow_dir: Dictionary = result["flow_dir"]

	# 1. Bilesenler (flood fill)
	var comp_of: Dictionary = {}
	var comp_count: int = 0
	for row in range(CanalConfig.ROWS):
		for col in range(CanalConfig.COLS):
			var start := Vector2i(col, row)
			if not _is_canal(grid, start) or comp_of.has(start):
				continue
			var stack: Array[Vector2i] = [start]
			comp_of[start] = comp_count
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				for d in DIRS:
					var nb: Vector2i = cur + d
					if grid.in_bounds(nb.x, nb.y) and _is_canal(grid, nb) and not comp_of.has(nb):
						comp_of[nb] = comp_count
						stack.append(nb)
			comp_count += 1

	var arrival: Array[float] = []
	arrival.resize(comp_count)
	arrival.fill(0.0)
	var comp_has_flow: Array[bool] = []
	comp_has_flow.resize(comp_count)
	comp_has_flow.fill(false)

	var leak: float = CanalConfig.LEAK_PER_CELL[grid.lining_level]

	# 2. Her acik pinar icin en kisa yol
	for id in CanalConfig.SPRING_IDS:
		if not grid.open_springs.has(id):
			continue
		var spring: Dictionary = CanalConfig.SPRINGS[id]
		var flow: float = spring["flow"]
		result["input"] += flow
		var start := Vector2i(CanalConfig.SPRING_COL, int(spring["row"]))
		var path: Array[Vector2i] = _shortest_path(grid, start)
		if path.is_empty():
			result["wasted"] += flow
			continue
		var cells_on_path: int = path.size()
		var arrived: float = flow * pow(1.0 - leak, cells_on_path)
		result["leaked"] += flow - arrived
		var comp: int = comp_of[start]
		arrival[comp] += arrived
		comp_has_flow[comp] = true
		for i in range(path.size()):
			if flow_dir.has(path[i]):
				continue
			if i + 1 < path.size():
				flow_dir[path[i]] = path[i + 1] - path[i]
			else:
				flow_dir[path[i]] = Vector2i(1, 0)

	# 3. Bilesen basina kapasite ve degirmen carpani
	var exits: Array[int] = []
	exits.resize(comp_count)
	exits.fill(0)
	var mills: Array[int] = []
	mills.resize(comp_count)
	mills.fill(0)
	for c in comp_of:
		var ci: int = comp_of[c]
		if _is_exit(grid, c):
			exits[ci] += 1
		if grid.get_cell(c.x, c.y) == CanalConfig.CELL_MILL:
			mills[ci] += 1
	var cap_per_exit: float = CanalConfig.CAP_PER_EXIT_BASE * pow(CanalConfig.CAP_WIDTH_GROWTH, grid.width_level)
	for ci in range(comp_count):
		if not comp_has_flow[ci]:
			continue
		var capacity: float = exits[ci] * cap_per_exit
		var base: float = minf(arrival[ci], capacity)
		result["overflow"] += arrival[ci] - base
		var bonus: float = 1.0 + CanalConfig.MILL_BONUS_PER_MILL * mini(mills[ci], CanalConfig.MILL_BONUS_MAX_COUNT)
		result["delivered"] += base * bonus

	# Akan hucreler ve yonler; yol disi hucreler en yakin cikisa yonelir
	var flowing: Array[Vector2i] = []
	var exit_dir: Dictionary = {}
	var exit_dir_ready: Dictionary = {}
	for c in comp_of:
		var ci: int = comp_of[c]
		if not comp_has_flow[ci]:
			continue
		flowing.append(c)
		if not flow_dir.has(c):
			if not exit_dir_ready.has(ci):
				exit_dir_ready[ci] = true
				exit_dir.merge(_dirs_to_nearest_exit(grid, comp_of, ci))
			flow_dir[c] = exit_dir.get(c, Vector2i(1, 0))
	result["flowing"] = flowing
	return result


## Pinar basindan sutun 7'deki kanala en kisa yol (baslangic ve cikis dahil). Yol yoksa bos.
static func _shortest_path(grid, start: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not _is_canal(grid, start):
		return empty
	var prev: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if _is_exit(grid, cur):
			var path: Array[Vector2i] = []
			var node: Vector2i = cur
			while node != start:
				path.append(node)
				node = prev[node]
			path.append(start)
			path.reverse()
			return path
		for d in DIRS:
			var nb: Vector2i = cur + d
			if grid.in_bounds(nb.x, nb.y) and _is_canal(grid, nb) and not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	return empty


## Bilesendeki her hucre icin en yakin cikisa giden yon (cok kaynakli BFS).
static func _dirs_to_nearest_exit(grid, comp_of: Dictionary, comp: int) -> Dictionary:
	var dirs: Dictionary = {}
	var queue: Array[Vector2i] = []
	for c in comp_of:
		if comp_of[c] == comp and _is_exit(grid, c):
			dirs[c] = Vector2i(1, 0)
			queue.append(c)
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in DIRS:
			var nb: Vector2i = cur + d
			if comp_of.get(nb, -1) == comp and not dirs.has(nb):
				dirs[nb] = cur - nb
				queue.append(nb)
	return dirs


## Ayni izgara surumu icin sonucu onbellekten verir.
static func compute_cached(grid, cache: Dictionary) -> Dictionary:
	if cache.has("result") and cache.get("grid_id", 0) == grid.get_instance_id() and cache.get("version", -1) == grid.version:
		return cache["result"]
	var result: Dictionary = compute(grid)
	cache["grid_id"] = grid.get_instance_id()
	cache["version"] = grid.version
	cache["result"] = result
	return result
