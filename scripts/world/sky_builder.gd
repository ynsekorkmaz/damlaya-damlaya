extends RefCounted
## Gökyüzü, ortam ışığı ve gölgesiz güneş.

const Config = preload("res://scripts/core/config.gd")
const Palette = preload("res://scripts/core/palette.gd")


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Sky"

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Palette.SKY_TOP
	sky_mat.sky_horizon_color = Palette.SKY_HORIZON
	sky_mat.ground_horizon_color = Palette.GROUND_HORIZON
	sky_mat.ground_bottom_color = Palette.GROUND_BOTTOM
	sky_mat.sun_angle_max = Config.SKY_SUN_ANGLE_MAX
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
	sun.rotation_degrees = Config.SUN_ROTATION_DEG
	root.add_child(sun)
	return root
