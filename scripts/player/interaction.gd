extends Node
## Etkileşim: kaynakta su doldurma, çukurda dökme, ipucu metni. Raycast yok, basit vektör hesabı.

const Config = preload("res://scripts/core/config.gd")
const Economy = preload("res://scripts/core/economy.gd")
const BasinShape = preload("res://scripts/core/basin_shape.gd")
const SpringBuilder = preload("res://scripts/world/spring_builder.gd")
const ShopBuilder = preload("res://scripts/world/shop_builder.gd")

const PROMPT_FILL: String = "Sol tıkı basılı tut: su doldur"
const PROMPT_FULL: String = "Elin dolu. Çukura götür."
const PROMPT_POUR: String = "Sağ tık: suyu dök"
const PROMPT_BRING: String = "Suyu çukura götür."
const PROMPT_GUIDE: String = "Kayadaki kaynaktan su al."
const PROMPT_SHOP: String = "E: dükkânı aç"

var game: Node
var player: CharacterBody3D

var _spring_center: Vector3
var _was_captured: bool = false
var _bring_timer: float = 0.0
var _shop_point: Vector3
var _shop_ready: bool = false


func _ready() -> void:
	name = "Interaction"
	_spring_center = SpringBuilder.origin() + Vector3(0.0, Config.FILL_TARGET_HEIGHT, 0.0)
	_shop_point = ShopBuilder.origin() + Vector3(0.0, Config.SHOP_LOOK_HEIGHT, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _shop_ready and game != null and event.is_action_pressed("shop") and not event.is_echo():
		game.call("request_shop")
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if game == null or player == null:
		return
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# Fareyi yakalayan ilk tıklama etkileşim sayılmaz.
	var active: bool = captured and _was_captured
	_was_captured = captured
	if not captured:
		_shop_ready = false
		game.call("set_prompt", "")
		return

	var state: Object = game.get("state")
	var carried: float = state.carried
	var capacity: float = Economy.tool_capacity(state)
	var prompt: String = ""
	_bring_timer = maxf(_bring_timer - delta, 0.0)
	if active and carried > 0.0 and Input.is_action_just_pressed("pour"):
		if _in_pour_zone(state):
			game.call("try_pour")
		else:
			_bring_timer = Config.HINT_BRING_SECONDS

	_shop_ready = _near_shop() and _looking_at_shop()
	if _shop_ready:
		prompt = PROMPT_SHOP
	elif _near_spring() and _looking_at_spring():
		if carried < capacity:
			prompt = PROMPT_FILL
			if active and Input.is_action_pressed("interact"):
				game.call("try_fill", delta)
		else:
			prompt = PROMPT_FULL
	elif carried > 0.0 and _bring_timer > 0.0:
		prompt = PROMPT_BRING
	elif carried > 0.0 and _in_pour_zone(state):
		prompt = PROMPT_POUR
	elif carried <= 0.0 and state.total_drops < Config.GUIDE_DROPS_LIMIT:
		prompt = PROMPT_GUIDE
	elif carried > 0.0 and state.total_drops < Config.GUIDE_DROPS_LIMIT:
		prompt = PROMPT_FULL
	game.call("set_prompt", prompt)


func _near_shop() -> bool:
	var flat := Vector2(player.global_position.x - _shop_point.x, player.global_position.z - _shop_point.z)
	return flat.length() <= Config.SHOP_INTERACT_RADIUS


func _looking_at_shop() -> bool:
	var camera: Camera3D = player.call("get_camera")
	var to_target: Vector3 = (_shop_point - camera.global_position).normalized()
	return (-camera.global_transform.basis.z).dot(to_target) >= Config.SHOP_LOOK_COS


func _near_spring() -> bool:
	var flat := Vector2(player.global_position.x - _spring_center.x, player.global_position.z - _spring_center.z)
	return flat.length() - Config.SPRING_RADIUS < Config.FILL_REACH


func _looking_at_spring() -> bool:
	var camera: Camera3D = player.call("get_camera")
	var to_target: Vector3 = (_spring_center - camera.global_position).normalized()
	var forward: Vector3 = -camera.global_transform.basis.z
	return forward.dot(to_target) >= Config.FILL_LOOK_COS


## Dökme bölgesi: o anki çanak yarıçapı + POUR_MARGIN.
func _in_pour_zone(state: Object) -> bool:
	var flat := Vector2(player.global_position.x, player.global_position.z)
	return flat.length() <= BasinShape.radius(state.total_drops) + Config.POUR_MARGIN
