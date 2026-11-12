extends RefCounted
## Registers all gameplay input actions in code, so project.godot needs no input entries.

const ACTION_KEYS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"toggle_debug": [KEY_F3],
	"shop": [KEY_E],
	"upgrades": [KEY_TAB],
}


## Fare tuşu eylemleri.
const ACTION_MOUSE: Dictionary = {
	"interact": [MOUSE_BUTTON_LEFT],   # su doldur (basılı tut)
	"pour": [MOUSE_BUTTON_RIGHT],      # suyu dök
}


static func register() -> void:
	for action: String in ACTION_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in ACTION_KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode as Key
			InputMap.action_add_event(action, event)
	for action: String in ACTION_MOUSE:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button: int in ACTION_MOUSE[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button as MouseButton
			InputMap.action_add_event(action, event)
