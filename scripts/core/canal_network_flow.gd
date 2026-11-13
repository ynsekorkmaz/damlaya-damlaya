extends RefCounted
## Yonlu parcalar icin kanal akis hesabi. Saf fonksiyonlar, durum tutmaz.
## Dugum = parca icindeki bagli agiz grubu. Dugum kimligi = hucre_indeksi * MAX_NODES + dugum_no.

const Pieces = preload("res://scripts/core/canal_pieces.gd")

const MAX_NODES: int = 3


@warning_ignore("integer_division")
static func _cell_of(node: int) -> int:
	return node / MAX_NODES


static func _connect(adj: Dictionary, a: int, b: int) -> void:
	adj[a].append(b)
	adj[b].append(a)


## Sonuc: {input, delivered, leaked, overflow, wasted, flowing, flow_dir, per_spring, flowing_nodes}
## flowing_nodes: akan hucre (Vector2i) -> o hucrede akan dugumlerin agiz yonlari (dunya yonu N, E, S, W; liste).
## Su kemerinde yalnizca akan hattin agizlari yer alir.
static func compute(net) -> Dictionary:
	var cols: int = net.cols
	var rows: int = net.rows
	var result: Dictionary = {
		"input": 0.0, "delivered": 0.0, "leaked": 0.0, "overflow": 0.0, "wasted": 0.0,
		"flowing": [], "flow_dir": {}, "per_spring": {}, "flowing_nodes": {},
	}

	# Dugumler ve kenarlar
	var adj: Dictionary = {}
	var port_node: Dictionary = {}
	var cell_pos: Dictionary = {}
	var cell_piece: Dictionary = {}
	var cell_nodes: Dictionary = {}
	var hubs: Dictionary = {}
	for row in range(rows):
		for col in range(cols):
			var p: Dictionary = net.get_piece(col, row)
			if p.is_empty():
				continue
			if p["piece"] == "gate" and not bool(p.get("open", true)):
				continue
			var idx: int = row * cols + col
			var def: Dictionary = Pieces.get_piece_def(p["piece"])
			var nodes: Array = Pieces.rotated_nodes(p["piece"], int(p["rotation"]))
			var pn: Array[int] = [-1, -1, -1, -1]
			for k in range(nodes.size()):
				adj[idx * MAX_NODES + k] = []
				for dir in nodes[k]:
					pn[dir] = k
			for link in def["links"]:
				_connect(adj, idx * MAX_NODES + int(link[0]), idx * MAX_NODES + int(link[1]))
			if def.has("hub"):
				hubs[idx * MAX_NODES + int(def["hub"])] = true
			port_node[idx] = pn
			cell_pos[idx] = Vector2i(col, row)
			cell_piece[idx] = p
			cell_nodes[idx] = nodes
	for idx in port_node:
		var pn: Array[int] = port_node[idx]
		for dir in [Pieces.E, Pieces.S]:
			if pn[dir] < 0:
				continue
			var nb: Vector2i = cell_pos[idx] + Pieces.DIR_VEC[dir]
			if not net.in_bounds(nb.x, nb.y):
				continue
			var nidx: int = nb.y * cols + nb.x
			if not port_node.has(nidx):
				continue
			var npn: Array[int] = port_node[nidx]
			var nk: int = npn[Pieces.opposite(dir)]
			if nk >= 0:
				_connect(adj, idx * MAX_NODES + pn[dir], nidx * MAX_NODES + nk)

	# Cikislar: son sutunda DOGU agzi olan dugumler
	var is_exit: Dictionary = {}
	for idx in port_node:
		if cell_pos[idx].x == cols - 1:
			var k: int = (port_node[idx] as Array[int])[Pieces.E]
			if k >= 0:
				is_exit[idx * MAX_NODES + k] = true

	# Bilesenler
	var comp_of: Dictionary = {}
	var comp_count: int = 0
	for start in adj:
		if comp_of.has(start):
			continue
		var stack: Array[int] = [start]
		comp_of[start] = comp_count
		while not stack.is_empty():
			var cur: int = stack.pop_back()
			for nb in adj[cur]:
				if not comp_of.has(nb):
					comp_of[nb] = comp_count
					stack.append(nb)
		comp_count += 1

	var arrival: Array[float] = []
	arrival.resize(comp_count)
	arrival.fill(0.0)
	var comp_has_flow: Array[bool] = []
	comp_has_flow.resize(comp_count)
	comp_has_flow.fill(false)
	var node_dir: Dictionary = {}
	var node_weight: Dictionary = {}

	# Her acik pinar icin en kisa yol
	for id in net.spring_defs.keys():
		if not net.open_springs.has(id):
			continue
		var spring: Dictionary = net.spring_defs[id]
		var flow: float = float(spring["flow"])
		result["input"] += flow
		var per: Dictionary = {"arrived": 0.0, "path_length": 0, "reached": false}
		result["per_spring"][id] = per
		var start_node: int = -1
		var srow: int = int(spring["row"])
		if net.in_bounds(0, srow) and port_node.has(srow * cols):
			var k0: int = (port_node[srow * cols] as Array[int])[Pieces.W]
			if k0 >= 0:
				start_node = srow * cols * MAX_NODES + k0
		var path: Array[int] = _find_path(adj, hubs, is_exit, start_node)
		if path.is_empty():
			result["wasted"] += flow
			continue
		# Yoldaki parcalar (ardisik ayni hucre bir parca sayilir)
		var arrived: float = flow
		var piece_cells: Array[int] = []
		for n in path:
			var c: int = _cell_of(n)
			if piece_cells.is_empty() or piece_cells.back() != c:
				piece_cells.append(c)
				var pc: Dictionary = cell_piece[c]
				arrived *= 1.0 - Pieces.leak(pc["piece"], pc["material"], net.lining_level)
		result["leaked"] += flow - arrived
		per["arrived"] = arrived
		per["path_length"] = piece_cells.size()
		per["reached"] = true
		var comp: int = comp_of[start_node]
		arrival[comp] += arrived
		comp_has_flow[comp] = true
		for i in range(path.size()):
			node_weight[path[i]] = float(node_weight.get(path[i], 0.0)) + flow
			if node_dir.has(path[i]):
				continue
			var d: Vector2i = Vector2i(1, 0)
			for j in range(i + 1, path.size()):
				if _cell_of(path[j]) != _cell_of(path[i]):
					d = cell_pos[_cell_of(path[j])] - cell_pos[_cell_of(path[i])]
					break
			node_dir[path[i]] = d

	# Bilesen basina cikis, degirmen ve havuz sayilari
	var exits: Array[int] = []
	exits.resize(comp_count)
	exits.fill(0)
	var mills: Array[int] = []
	mills.resize(comp_count)
	mills.fill(0)
	var reservoirs: Array[int] = []
	reservoirs.resize(comp_count)
	reservoirs.fill(0)
	for n in is_exit:
		exits[comp_of[n]] += 1
	for idx in cell_piece:
		var pid: String = cell_piece[idx]["piece"]
		if pid == "mill":
			mills[comp_of[idx * MAX_NODES]] += 1
		elif pid == "reservoir":
			reservoirs[comp_of[idx * MAX_NODES]] += 1

	var cap_per_exit: float = Pieces.cap_per_exit(net.width_level)
	var res_extra: float = Pieces.reservoir_extra(net.width_level)
	for ci in range(comp_count):
		if not comp_has_flow[ci]:
			continue
		var capacity: float = exits[ci] * cap_per_exit + mini(reservoirs[ci], Pieces.RESERVOIR_MAX_COUNT) * res_extra
		var base: float = minf(arrival[ci], capacity)
		result["overflow"] += arrival[ci] - base
		var bonus: float = 1.0 + Pieces.MILL_BONUS_PER_MILL * mini(mills[ci], Pieces.MILL_BONUS_MAX_COUNT)
		result["delivered"] += base * bonus

	# Akan hucreler ve yonler
	var toward_exit: Dictionary = _toward_exit(adj, is_exit)
	var flowing: Array[Vector2i] = []
	var flow_dir: Dictionary = result["flow_dir"]
	var flowing_nodes: Dictionary = result["flowing_nodes"]
	for idx in cell_piece:
		var best_node: int = -1
		var best_weight: float = -1.0
		for k in range(MAX_NODES):
			var n: int = idx * MAX_NODES + k
			if not comp_of.has(n) or not comp_has_flow[comp_of[n]]:
				continue
			var w: float = float(node_weight.get(n, 0.0))
			if w > best_weight:
				best_weight = w
				best_node = n
		if best_node < 0:
			continue
		flowing.append(cell_pos[idx])
		var mouths: Array[int] = []
		var groups: Array = cell_nodes[idx]
		for k in range(groups.size()):
			var gn: int = idx * MAX_NODES + k
			if comp_of.has(gn) and comp_has_flow[comp_of[gn]]:
				for d in groups[k]:
					mouths.append(int(d))
		flowing_nodes[cell_pos[idx]] = mouths
		if node_dir.has(best_node):
			flow_dir[cell_pos[idx]] = node_dir[best_node]
		else:
			flow_dir[cell_pos[idx]] = _dir_toward_exit(best_node, toward_exit, cell_pos)
	result["flowing"] = flowing
	return result


## En az parca gecen yol (dugum listesi, baslangic ve cikis dahil). Yol yoksa bos.
## Hucre degistirmek 1 parca sayilir; ayni parca icindeki gecis bedava.
## Y kanalda bir koldan govdeye girilmisse diger kola gecilemez.
static func _find_path(adj: Dictionary, hubs: Dictionary, is_exit: Dictionary, start: int) -> Array[int]:
	var none: Array[int] = []
	if start < 0 or not adj.has(start):
		return none
	var prev: Dictionary = {start: -1}
	var frontier: Array[int] = [start]
	while not frontier.is_empty():
		# Ayni parca icinde yayilma
		var i: int = 0
		while i < frontier.size():
			var cur: int = frontier[i]
			i += 1
			if hubs.has(cur) and prev[cur] >= 0 and _cell_of(prev[cur]) == _cell_of(cur):
				continue
			for nb in adj[cur]:
				if _cell_of(nb) == _cell_of(cur) and not prev.has(nb):
					prev[nb] = cur
					frontier.append(nb)
		for n in frontier:
			if is_exit.has(n):
				var path: Array[int] = []
				var node: int = n
				while node != -1:
					path.append(node)
					node = prev[node]
				path.reverse()
				return path
		# Komsu parcaya gecis
		var next_frontier: Array[int] = []
		for cur in frontier:
			for nb in adj[cur]:
				if _cell_of(nb) != _cell_of(cur) and not prev.has(nb):
					prev[nb] = cur
					next_frontier.append(nb)
		frontier = next_frontier
	return none


## Her dugum icin en yakin cikisa dogru bir sonraki dugum (cok kaynakli BFS).
static func _toward_exit(adj: Dictionary, is_exit: Dictionary) -> Dictionary:
	var next: Dictionary = {}
	var seen: Dictionary = {}
	var queue: Array[int] = []
	for n in is_exit:
		seen[n] = true
		next[n] = -1
		queue.append(n)
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for nb in adj[cur]:
			if not seen.has(nb):
				seen[nb] = true
				next[nb] = cur
				queue.append(nb)
	return next


static func _dir_toward_exit(node: int, toward_exit: Dictionary, cell_pos: Dictionary) -> Vector2i:
	var cur: int = node
	while true:
		var nxt: int = int(toward_exit.get(cur, -1))
		if nxt < 0:
			return Vector2i(1, 0)
		if _cell_of(nxt) != _cell_of(cur):
			return cell_pos[_cell_of(nxt)] - cell_pos[_cell_of(cur)]
		cur = nxt
	return Vector2i(1, 0)


## Ayni izgara surumu icin sonucu onbellekten verir.
static func compute_cached(net, cache: Dictionary) -> Dictionary:
	if cache.has("result") and cache.get("net_id", 0) == net.get_instance_id() and cache.get("version", -1) == net.version:
		return cache["result"]
	var result: Dictionary = compute(net)
	cache["net_id"] = net.get_instance_id()
	cache["version"] = net.version
	cache["result"] = result
	return result
