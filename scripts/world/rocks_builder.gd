extends RefCounted
## Vadiye serpilmiş yumuşak gölgeli kayalar: biçim başına bir MultiMeshInstance3D,
## büyük kayalar için basit küre çarpışması.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")


static func build() -> Node3D:
	var rocks: Array[Dictionary] = make_rocks()
	var root := Node3D.new()
	root.name = "Rocks"
	for v in range(Config.ROCK_VARIANTS):
		var list: Array[Dictionary] = []
		for r in rocks:
			if r["variant"] == v:
				list.append(r)
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = build_rock_mesh(v)
		mm.instance_count = list.size()
		for i in range(list.size()):
			mm.set_instance_transform(i, list[i]["transform"])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "RockShape%d" % v
		mmi.multimesh = mm
		root.add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "RockColliders"
	for r in rocks:
		if r["size"] < Config.ROCK_COLLIDE_MIN_SIZE:
			continue
		var sphere := SphereShape3D.new()
		sphere.radius = r["collide_radius"]
		var cs := CollisionShape3D.new()
		cs.shape = sphere
		cs.position = (r["transform"] as Transform3D).origin
		body.add_child(cs)
	root.add_child(body)
	return root


## Tohumlu, belirlenimci yerleşim (dönüşüm listesi).
static func make_placements() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for r in make_rocks():
		out.append(r["transform"])
	return out


## Her kaya: transform, variant, size (genişlik, m), collide_radius.
static func make_rocks() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = Config.ROCK_SEED
	var out: Array[Dictionary] = []
	var tries: int = 0
	var max_tries: int = Config.ROCK_COUNT * Config.ROCK_MAX_TRIES
	var clusters: int = 0
	while out.size() < Config.ROCK_COUNT and tries < max_tries:
		tries += 1
		var pos: Vector2 = _random_position(rng)
		if not is_allowed(pos):
			continue
		if clusters < Config.ROCK_CLUSTER_COUNT:
			clusters += 1
			var big: float = rng.randf_range(Config.ROCK_BIG_SIZE_MIN, Config.ROCK_BIG_SIZE_MAX)
			out.append(_make_rock(rng, pos, big))
			var sats: int = rng.randi_range(Config.ROCK_SAT_MIN, Config.ROCK_SAT_MAX)
			for k in range(sats):
				var a: float = rng.randf() * TAU
				var d: float = big * 0.5 * rng.randf_range(Config.ROCK_SAT_DIST_MIN, Config.ROCK_SAT_DIST_MAX) + 0.4
				var sp: Vector2 = pos + Vector2(cos(a), sin(a)) * d
				if out.size() >= Config.ROCK_COUNT or not is_allowed(sp):
					continue
				var size: float
				if rng.randf() < 0.5:
					size = rng.randf_range(Config.ROCK_MID_SIZE_MIN, Config.ROCK_MID_SIZE_MAX)
				else:
					size = rng.randf_range(Config.ROCK_SMALL_SIZE_MIN, Config.ROCK_SMALL_SIZE_MAX)
				out.append(_make_rock(rng, sp, size))
		else:
			var size2: float
			if rng.randf() < Config.ROCK_MID_CHANCE:
				size2 = rng.randf_range(Config.ROCK_MID_SIZE_MIN, Config.ROCK_MID_SIZE_MAX)
			else:
				size2 = rng.randf_range(Config.ROCK_SMALL_SIZE_MIN, Config.ROCK_SMALL_SIZE_MAX)
			out.append(_make_rock(rng, pos, size2))
	return out


static func _random_position(rng: RandomNumberGenerator) -> Vector2:
	var r_min: float = BasinShape.max_radius() + Config.ROCK_PIT_CLEARANCE
	var r_max: float = Config.VALLEY_RADIUS - Config.ROCK_RIM_CLEARANCE
	var angle: float = rng.randf() * TAU
	var r: float = rng.randf_range(r_min, r_max)
	return Vector2(cos(angle), sin(angle)) * r


## En büyük çanaktan, vadi kenarından, doğuş noktasından ve dükkândan uzak mı.
static func is_allowed(pos: Vector2) -> bool:
	var spawn := Vector2(Config.PLAYER_SPAWN.x, Config.PLAYER_SPAWN.z)
	var r: float = pos.length()
	if r < BasinShape.max_radius() + Config.ROCK_PIT_CLEARANCE:
		return false
	if r > Config.VALLEY_RADIUS - Config.ROCK_RIM_CLEARANCE:
		return false
	var shop := Vector2(Config.SHOP_POSITION.x, Config.SHOP_POSITION.z)
	if pos.distance_to(shop) < Config.SHOP_ROCK_CLEARANCE:
		return false
	return pos.distance_to(spawn) >= Config.ROCK_SPAWN_CLEARANCE


static func _make_rock(rng: RandomNumberGenerator, pos: Vector2, size: float) -> Dictionary:
	var variant: int = rng.randi_range(0, Config.ROCK_VARIANTS - 1)
	var sx: float = size * rng.randf_range(Config.ROCK_AXIS_MIN, Config.ROCK_AXIS_MAX)
	var sz: float = size * rng.randf_range(Config.ROCK_AXIS_MIN, Config.ROCK_AXIS_MAX)
	var sy: float = size * rng.randf_range(Config.ROCK_HEIGHT_MIN, Config.ROCK_HEIGHT_MAX)
	var tilt := Vector3(
		rng.randf_range(-Config.ROCK_TILT_MAX, Config.ROCK_TILT_MAX),
		rng.randf() * TAU,
		rng.randf_range(-Config.ROCK_TILT_MAX, Config.ROCK_TILT_MAX))
	var basis := Basis.from_euler(tilt).scaled_local(Vector3(sx, sy, sz))
	# Zeminin en alçak yakın noktasına oturt, hafifçe göm
	var reach: float = minf(sx, sz) * 0.5
	var ground: float = TerrainShape.height(pos.x, pos.y)
	for k in range(4):
		var a: float = k * TAU / 4.0 + 0.4
		ground = minf(ground, TerrainShape.height(pos.x + cos(a) * reach, pos.y + sin(a) * reach))
	var y: float = ground + sy * 0.5 - sy * Config.ROCK_SINK_FRAC
	return {
		"transform": Transform3D(basis, Vector3(pos.x, y, pos.y)),
		"variant": variant,
		"size": size,
		"collide_radius": reach * Config.ROCK_COLLIDE_FRAC,
	}


## Yarıçap: küre, farklı fazlı düşük frekanslı sinüslerle bozulmuş, tabanı yassı.
static func _surface(dir: Vector3, variant: int) -> Vector3:
	var ph: float = variant * 2.3
	var f1: float = Config.ROCK_BUMP_FREQ
	var f2: float = Config.ROCK_BUMP_FREQ_2
	var b1: float = (sin(dir.x * f1 + ph) + sin(dir.y * f1 * 1.2 + ph * 1.7 + 1.0) + sin(dir.z * f1 + ph * 0.6 + 2.0)) / 3.0
	var b2: float = (sin(dir.x * f2 * 1.1 + dir.z * f2 * 0.7 + ph * 2.0) + sin(dir.y * f2 + dir.x * f2 * 0.5 + ph + 3.0)) / 2.0
	var rad: float = 0.5 * (1.0 + Config.ROCK_BUMP * (b1 + Config.ROCK_BUMP_2 * b2))
	var p: Vector3 = dir * rad
	if p.y < 0.0:
		p.y *= 1.0 - Config.ROCK_BASE_FLAT
	return p


static func build_rock_mesh(variant: int = 0) -> ArrayMesh:
	var rings: int = Config.ROCK_RINGS
	var segs: int = Config.ROCK_SEGMENTS
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	var e: float = 0.05
	for r in range(rings + 1):
		var phi: float = PI * r / float(rings)
		for s in range(segs + 1):
			var theta: float = TAU * s / float(segs)
			var p: Vector3 = _surface(_dir(phi, theta), variant)
			# Normal: yüzeyin sayısal teğetlerinden (kutuplardan kaçınarak)
			var pc: float = clampf(phi, e * 2.0, PI - e * 2.0)
			var dphi: Vector3 = _surface(_dir(pc + e, theta), variant) - _surface(_dir(pc - e, theta), variant)
			var dth: Vector3 = _surface(_dir(pc, theta + e), variant) - _surface(_dir(pc, theta - e), variant)
			var n: Vector3 = dth.cross(dphi).normalized()
			if n.dot(p) < 0.0:
				n = -n
			st.set_normal(n)
			var lit: float = smoothstep(-0.7, 0.8, n.y)
			var col: Color = Palette.ROCK_DARK.lerp(Palette.ROCK, smoothstep(0.0, 0.5, lit))
			col = col.lerp(Palette.ROCK_LIGHT, smoothstep(0.5, 1.0, lit))
			st.set_color(col)
			st.add_vertex(p)
	var w: int = segs + 1
	for r in range(rings):
		for s in range(segs):
			var a: int = r * w + s
			var b: int = a + 1
			var c: int = a + w
			var d: int = c + 1
			# Godot ön yüzü saat yönü, dışa bakar
			if r > 0:
				for k in [a, c, b]:
					st.add_index(k)
			if r < rings - 1:
				for k in [b, c, d]:
					st.add_index(k)
	return st.commit()


static func _dir(phi: float, theta: float) -> Vector3:
	return Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
