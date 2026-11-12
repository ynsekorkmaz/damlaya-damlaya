extends CharacterBody3D
## First-person player: mouse look, walking, sprinting, jumping, valley boundary.

const Config = preload("res://scripts/core/config.gd")

const CAMERA_FOV: float = 75.0
const CAMERA_NEAR: float = 0.05
const CAMERA_FAR: float = 400.0
const FALL_LIMIT_Y: float = -30.0
const FLOOR_SNAP: float = 0.3

## Dükkân paneli açıkken false: hareket ve bakış durur.
var input_enabled: bool = true

var _camera: Camera3D
var _pitch: float = 0.0
var _spawn_position: Vector3


func _ready() -> void:
	_spawn_position = global_position

	floor_stop_on_slope = true
	floor_snap_length = FLOOR_SNAP

	var capsule := CapsuleShape3D.new()
	capsule.height = Config.PLAYER_HEIGHT
	capsule.radius = Config.PLAYER_RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = Config.PLAYER_HEIGHT * 0.5
	add_child(collision)

	_camera = Camera3D.new()
	_camera.position.y = Config.EYE_HEIGHT
	_camera.fov = CAMERA_FOV
	_camera.near = CAMERA_NEAR
	_camera.far = CAMERA_FAR
	add_child(_camera)
	_camera.current = true


func get_camera() -> Camera3D:
	return _camera


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * Config.MOUSE_SENSITIVITY)
		var limit: float = deg_to_rad(Config.PITCH_LIMIT_DEG)
		_pitch = clampf(_pitch - motion.relative.y * Config.MOUSE_SENSITIVITY, -limit, limit)
		_camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Config.GRAVITY * delta
	elif input_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = Config.JUMP_VELOCITY

	var input_dir: Vector2 = Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	var speed: float = Config.SPRINT_SPEED if (input_enabled and Input.is_action_pressed("sprint")) else Config.WALK_SPEED
	var step: float = Config.ACCELERATION * delta
	velocity.x = move_toward(velocity.x, direction.x * speed, step)
	velocity.z = move_toward(velocity.z, direction.z * speed, step)

	move_and_slide()
	_keep_inside_valley()

	if global_position.y < FALL_LIMIT_Y:
		global_position = _spawn_position
		velocity = Vector3.ZERO


func _keep_inside_valley() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	var distance: float = flat.length()
	if distance <= Config.VALLEY_RADIUS:
		return
	var outward: Vector2 = flat / distance
	global_position.x = outward.x * Config.VALLEY_RADIUS
	global_position.z = outward.y * Config.VALLEY_RADIUS
	var outward_speed: float = velocity.x * outward.x + velocity.z * outward.y
	if outward_speed > 0.0:
		velocity.x -= outward.x * outward_speed
		velocity.z -= outward.y * outward_speed
