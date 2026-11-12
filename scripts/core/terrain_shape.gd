extends RefCounted
## Arazi yüksekliği. Saf ve belirlenimci.

const Config = preload("res://scripts/core/config.gd")


static func height(x: float, z: float) -> float:
	var r: float = sqrt(x * x + z * z)
	var calm: float = lerpf(Config.CALM_MIN, 1.0, smoothstep(Config.CALM_NEAR, Config.CALM_FAR, r))
	var waves: float = (
		Config.WAVE_AMP_A * sin(x * Config.WAVE_FREQ_AX) * cos(z * Config.WAVE_FREQ_AZ)
		+ Config.WAVE_AMP_B * sin(x * Config.WAVE_FREQ_BX + z * Config.WAVE_FREQ_BZ)
		+ Config.WAVE_AMP_C * cos(z * Config.WAVE_FREQ_CZ - x * Config.WAVE_FREQ_CX)
	) * calm
	var rim: float = smoothstep(Config.VALLEY_RADIUS, Config.VALLEY_RADIUS + Config.RIM_WIDTH, r) * Config.RIM_HEIGHT
	var pit: float = -Config.PIT_DEPTH * exp(-(r * r) / (Config.PIT_RADIUS * Config.PIT_RADIUS * Config.PIT_SHAPE))
	return waves + rim + pit
