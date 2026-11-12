extends RefCounted
## Arazi yüksekliği. Saf ve belirlenimci. Çanak boyutu parametre olarak verilir (0 = çanak yok).

const Config = preload("res://scripts/core/config.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")


## Zemin dalgaları (vadi kenarı olmadan).
static func waves(x: float, z: float) -> float:
	var r: float = sqrt(x * x + z * z)
	var calm: float = lerpf(Config.CALM_MIN, 1.0, smoothstep(Config.CALM_NEAR, Config.CALM_FAR, r))
	return (
		Config.WAVE_AMP_A * sin(x * Config.WAVE_FREQ_AX) * cos(z * Config.WAVE_FREQ_AZ)
		+ Config.WAVE_AMP_B * sin(x * Config.WAVE_FREQ_BX + z * Config.WAVE_FREQ_BZ)
		+ Config.WAVE_AMP_C * cos(z * Config.WAVE_FREQ_CZ - x * Config.WAVE_FREQ_CX)
	) * calm


## Çanaksız zemin (dalgalar + vadi kenarı).
static func ground(x: float, z: float) -> float:
	var r: float = sqrt(x * x + z * z)
	var rim: float = smoothstep(Config.VALLEY_RADIUS, Config.VALLEY_RADIUS + Config.RIM_WIDTH, r) * Config.RIM_HEIGHT
	return waves(x, z) + rim


## Çanak varsa içeride dalgalar sönümlenir (düzgün kıyı), çanak profili eklenir.
static func height(x: float, z: float, basin_radius: float = 0.0, basin_depth: float = 0.0) -> float:
	var h: float = ground(x, z)
	if basin_radius > 0.0:
		var r: float = sqrt(x * x + z * z)
		h += waves(x, z) * (BasinShape.wave_keep(r, basin_radius) - 1.0) + BasinShape.pit(r, basin_radius, basin_depth)
	return h
