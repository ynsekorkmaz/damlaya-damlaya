extends RefCounted
## Gökyüzü (Poly Haven HDRI), sabit renkli ortam ışığı ve gölgesiz güneş.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Sky"

	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load(Config.SKY_HDRI_PATH)
	sky_mat.energy_multiplier = Config.SKY_HDRI_ENERGY
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.AMBIENT
	env.ambient_light_energy = Config.AMBIENT_ENERGY
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Palette.SUN
	sun.light_energy = Config.SUN_ENERGY
	sun.shadow_enabled = false
	# Işık HDRI'deki güneşin geldiği yönden gelir (DirectionalLight -Z yönüne ışıldar)
	sun.transform.basis = Basis.looking_at(-Config.SKY_SUN_DIR.normalized(), Vector3.UP)
	root.add_child(sun)
	return root
