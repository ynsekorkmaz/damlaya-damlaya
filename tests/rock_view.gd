extends SceneTree
## Kaya görünüm ve sarım doğrulaması.
## Kullanım: -s res://tests/rock_view.gd -- --out=yol.png [--side=yol2.png] [--check]

const Config = preload("res://scripts/core/config.gd")
const RocksBuilder = preload("res://scripts/world/rocks_builder.gd")


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


## Godot ön yüzü saat yönü: (b-a)x(c-a) dışa değil içe bakmalı.
func _count_inverted() -> int:
	var bad: int = 0
	var total: int = 0
	for v in range(Config.ROCK_VARIANTS):
		var mesh: ArrayMesh = RocksBuilder.build_rock_mesh(v)
		var arr: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var center := Vector3.ZERO
		for p in verts:
			center += p
		center /= float(verts.size())
		for i in range(0, idx.size(), 3):
			var a: Vector3 = verts[idx[i]]
			var b: Vector3 = verts[idx[i + 1]]
			var c: Vector3 = verts[idx[i + 2]]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length_squared() < 1e-14:
				continue
			total += 1
			var mid: Vector3 = (a + b + c) / 3.0 - center
			# Ön yüz için çapraz çarpım içe bakar (merkeze doğru)
			if n.dot(mid) > 0.0:
				bad += 1
	print("ucgen: %d" % total)
	print("ters ucgen: %d" % bad)
	return bad


func _initialize() -> void:
	var bad: int = _count_inverted()
	var out: String = _arg("--out=")
	if out == "" or OS.get_cmdline_user_args().has("--check"):
		quit(0 if bad == 0 else 1)
		return
	var side: String = _arg("--side=")

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.6, 0.75, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)

	var rocks: Node3D = RocksBuilder.build()
	root.add_child(rocks)
	var list: Array[Dictionary] = RocksBuilder.make_rocks()
	var big: Dictionary = list[0]
	for r in list:
		if r["size"] > big["size"]:
			big = r
	var org: Vector3 = (big["transform"] as Transform3D).origin

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.5, 0.25)
	floor_mi.material_override = fm
	floor_mi.position = Vector3(org.x, org.y - float(big["size"]) * 0.3, org.z)
	root.add_child(floor_mi)

	var cam := Camera3D.new()
	cam.current = true
	root.add_child(cam)
	cam.look_at_from_position(org + Vector3(1.5, 4.0, 1.5), org, Vector3.UP)
	for i in range(6):
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("kaydedildi: ", out)

	if side != "":
		# Zeminin altından, kayanın dibine bakan açı (taban açık mı)
		floor_mi.visible = false
		var sz: float = float(big["size"])
		cam.look_at_from_position(org + Vector3(sz * 1.2, -sz * 0.9, sz * 0.6), org, Vector3.UP)
		for i in range(6):
			await process_frame
		root.get_texture().get_image().save_png(side)
		print("kaydedildi: ", side)
	quit(0 if bad == 0 else 1)
