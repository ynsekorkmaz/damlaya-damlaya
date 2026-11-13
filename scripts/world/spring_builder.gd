extends RefCounted
## Su kaynağı: assets/models/spring_rock.glb (Poly Haven CC0 kayalarından Blender'da kurulmuş kaya grubu, ortasında dikey yarık).
## Her kaya parçası için basit dışbükey çarpışma, yarıktan süzülen ince su şeridi (yarığın içindeki yüzeye oturur)
## ve dipte küçük, yumuşak kenarlı birikinti. Yerel +Z doğuş noktasına bakar (yarığın ağzı).

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")
const TerrainShape = preload("res://scripts/core/terrain_shape.gd")

const MODEL_PATH: String = "res://assets/models/spring_rock.glb"
const LINER_NAME: String = "Crevice"   # çarpışması olmayan koyu yarık astarı

const STREAM_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;

uniform vec4 light_color : source_color;
uniform vec4 dark_color : source_color;
uniform float scroll_speed = 3.0;
uniform float wave_length = 0.45;

void fragment() {
	float s = 0.5 + 0.5 * sin((UV.y / wave_length - TIME * scroll_speed) * 6.2831);
	float side = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	ALBEDO = mix(dark_color.rgb, light_color.rgb, s);
	ROUGHNESS = 0.15;
	ALPHA = side * (0.5 + 0.4 * s);
}
"""


## Kaynağın dünyadaki taban noktası (y: kayanın yerleştiği yükseklik, gömülme dahil).
static func origin() -> Vector3:
	var p: Vector3 = Config.SPRING_POSITION
	var ground: float = TerrainShape.height(p.x, p.z)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		ground = minf(ground, TerrainShape.height(p.x + cos(a) * Config.SPRING_RADIUS, p.z + sin(a) * Config.SPRING_RADIUS))
	return Vector3(p.x, ground - Config.SPRING_SINK, p.z)


## Kayanın +Z yüzü doğuş noktasına dönük olsun.
static func yaw() -> float:
	var o: Vector3 = Config.SPRING_POSITION
	var s: Vector3 = Config.PLAYER_SPAWN
	return atan2(s.x - o.x, s.z - o.z)


static var _tris: Array = []        ## [{tm: TriangleMesh, xf: Transform3D}] (model yerel uzayı)


static func _model_scene() -> PackedScene:
	return load(MODEL_PATH) if ResourceLoader.exists(MODEL_PATH) else null


## Model düğümü (her çağrıda yeni örnek); yoksa boş Node3D.
static func make_model() -> Node3D:
	var scene: PackedScene = _model_scene()
	if scene == null:
		push_warning("spring_rock.glb yok")
		return Node3D.new()
	return scene.instantiate() as Node3D


## Düğümün altındaki ağlar (MeshInstance3D) ve kökten göreli dönüşümleri.
static func mesh_parts(root: Node3D) -> Array:
	var out: Array = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		out.append({"node": mi, "xf": xf})
	return out


static func _ensure_tris() -> void:
	if not _tris.is_empty():
		return
	var model: Node3D = make_model()
	for part: Dictionary in mesh_parts(model):
		var mi: MeshInstance3D = part["node"]
		_tris.append({"tm": mi.mesh.generate_triangle_mesh(), "xf": part["xf"]})
	model.free()


## Yerel (x, y) noktasında +Z'den -Z'ye bakan ışının kayaya ilk değdiği z (yoksa 0).
static func front_z_at(x: float, y: float) -> float:
	_ensure_tris()
	var best: float = -INF
	var from := Vector3(x, y, 4.0)
	for part: Dictionary in _tris:
		var inv: Transform3D = (part["xf"] as Transform3D).affine_inverse()
		var hit: Dictionary = (part["tm"] as TriangleMesh).intersect_ray(inv * from, inv.basis * Vector3(0.0, 0.0, -1.0))
		if not hit.is_empty():
			best = maxf(best, ((part["xf"] as Transform3D) * (hit["position"] as Vector3)).z)
	return best if best > -INF else 0.0


## x = 0 düzleminde, y yüksekliğinde yarığın içindeki yüzeyin z'si.
static func front_z(y: float) -> float:
	return front_z_at(0.0, y)


## Yarığın ağzı: iki yan kayanın ön yüzeyinin en öndeki z'si.
static func mouth_z() -> float:
	return maxf(front_z_at(-0.4, 0.6), front_z_at(0.4, 0.6))


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Spring"
	root.position = origin()
	root.rotation.y = yaw()

	var body := StaticBody3D.new()
	body.name = "SpringRock"
	body.add_to_group("rock")
	var model: Node3D = make_model()
	model.name = "Model"
	body.add_child(model)
	for part: Dictionary in mesh_parts(model):
		var mi: MeshInstance3D = part["node"]
		if mi.name.begins_with(LINER_NAME):
			continue
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_convex_shape(true, true)
		cs.transform = part["xf"]
		cs.name = "Col_" + String(mi.name)
		body.add_child(cs)
	root.add_child(body)

	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = _build_stream()
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stream)

	var puddle := MeshInstance3D.new()
	puddle.name = "Puddle"
	puddle.mesh = _build_puddle(root.position, root.rotation.y)
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(puddle)
	return root


static func _build_stream() -> ArrayMesh:
	var rows: int = Config.SPRING_STREAM_ROWS
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var length: float = 0.0
	var prev := Vector3.ZERO
	for i in range(rows + 1):
		var s: float = float(i) / float(rows)
		var y: float = lerpf(Config.SPRING_STREAM_TOP, Config.SPRING_STREAM_BOTTOM, s)
		var z: float = front_z(y) + Config.SPRING_STREAM_OFFSET
		var dz: float = front_z(y - 0.05) - front_z(y + 0.05)
		var n := Vector3(0.0, dz / 0.1, 1.0).normalized()
		var sway: float = 0.035 * sin(s * 7.0) * (1.0 - s)
		var half: float = Config.SPRING_STREAM_WIDTH * 0.5 * (1.0 + 0.8 * s)
		var mid := Vector3(sway, y, z)
		if i > 0:
			length += mid.distance_to(prev)
		prev = mid
		verts.append(Vector3(sway - half, y, z))
		verts.append(Vector3(sway + half, y, z))
		normals.append(n)
		normals.append(n)
		uvs.append(Vector2(0.0, length))
		uvs.append(Vector2(1.0, length))
	for i in range(rows):
		var k: int = i * 2
		idx.append_array([k, k + 1, k + 3, k, k + 3, k + 2])
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = STREAM_SHADER
	mat.shader = shader
	mat.set_shader_parameter("light_color", Palette.WATER_STREAM)
	mat.set_shader_parameter("dark_color", Palette.WATER_STREAM_DARK)
	mat.set_shader_parameter("scroll_speed", Config.SPRING_STREAM_SCROLL)
	mat.set_shader_parameter("wave_length", Config.SPRING_STREAM_WAVELENGTH)
	return _mesh_from(verts, normals, uvs, PackedColorArray(), idx, mat)


## Dipteki küçük birikinti: su, kenara doğru yumuşakça ıslak toprağa ve şeffaflığa iner (sert hâle yok).
static func _build_puddle(root_pos: Vector3, root_yaw: float) -> ArrayMesh:
	var segs: int = Config.SPRING_PUDDLE_SEGMENTS
	var basis := Basis(Vector3.UP, root_yaw)
	var center := Vector3(0.0, 0.0, mouth_z() + Config.SPRING_PUDDLE_FORWARD)
	var ring_scale: Array[float] = [0.0, 0.45, 0.85, 1.0, 1.2]
	var ring_color: Array[Color] = [
		Color(Palette.WATER, 0.88),
		Color(Palette.WATER, 0.85),
		Color(Palette.WATER.lerp(Palette.WET_EARTH, 0.4), 0.55),
		Color(Palette.WET_EARTH, 0.2),
		Color(Palette.WET_EARTH, 0.0),
	]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for ri in range(ring_scale.size()):
		var count: int = 1 if ri == 0 else segs
		for j in range(count):
			var ang: float = TAU * float(j) / float(segs)
			# Kenar hafif düzensiz: doğal görünsün
			var wobble: float = 1.0 + 0.12 * sin(3.0 * ang + 0.5) + 0.07 * sin(5.0 * ang + 2.0)
			var rr: float = Config.SPRING_PUDDLE_RADIUS * ring_scale[ri] * wobble
			var local := center + Vector3(cos(ang) * rr * 1.2, 0.0, sin(ang) * rr * 0.9)
			var world: Vector3 = root_pos + basis * local
			local.y = TerrainShape.height(world.x, world.z) + Config.SPRING_PUDDLE_LIFT - root_pos.y
			verts.append(local)
			normals.append(Vector3.UP)
			colors.append(ring_color[ri])
	# merkez yelpazesi + halkalar arası şerit (üstten bakınca saat yönü)
	for j in range(segs):
		var j2: int = (j + 1) % segs
		idx.append_array([0, 1 + j2, 1 + j])
	for ri in range(1, ring_scale.size() - 1):
		var base: int = 1 + (ri - 1) * segs
		var next: int = base + segs
		for j in range(segs):
			var j2: int = (j + 1) % segs
			idx.append_array([base + j, base + j2, next + j2, base + j, next + j2, next + j])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mesh_from(verts, normals, PackedVector2Array(), colors, idx, mat)


static func _mesh_from(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh
