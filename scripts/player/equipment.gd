extends Node
## Oyuncunun elindeki alet: iki yuva (0 su aleti, 1 çekiç) ve çekiçle seçili yapı.
## 1 / 2 yuvayı seçer, fare tekerleği yuvayı değiştirir, Shift + tekerlek son kullanılan yapılar arasında geçer.
## Dış bağlantı: add_child'dan önce `game` ve `player` atanır.

signal slot_changed(slot: int)
signal selection_changed(key: String)
signal hammer_denied(unlocked: bool) ## Çekiç yokken çekice geçilmek istendi; unlocked = kilidi açık ama alınmamış

const Config = preload("res://scripts/core/config.gd")

const SLOT_WATER: int = 0
const SLOT_HAMMER: int = 1
const KEY_CANAL: String = "canal:"
const KEY_FREE: String = "free:"

var game: Node
var player: Node

var slot: int = SLOT_WATER
var selected: String = ""          ## "canal:<parça_id>" ya da "free:<tür>"; boş = yok
var material: String = "earth"
var canal_rotation: int = 0
var free_rotation: float = 0.0     ## radyan
var recent: Array[String] = []


func _ready() -> void:
	name = "Equipment"


func hammer_owned() -> bool:
	if game == null:
		return false
	return bool((game.get("state") as Object).get("hammer_owned"))


func hammer_active() -> bool:
	return slot == SLOT_HAMMER and hammer_owned()


func set_slot(new_slot: int) -> void:
	var s: int = clampi(new_slot, SLOT_WATER, SLOT_HAMMER)
	if s == SLOT_HAMMER and not hammer_owned():
		return
	if s == slot:
		return
	slot = s
	slot_changed.emit(slot)


## Oyuncu girdisiyle çekice geçer; çekiç yoksa nedenini bildirir.
func request_hammer() -> void:
	if hammer_owned():
		set_slot(SLOT_HAMMER)
	else:
		hammer_denied.emit(bool((game.get("state") as Object).get("hammer_unlocked")) if game != null else false)


func select(key: String) -> void:
	selected = key
	if not key.is_empty():
		recent.erase(key)
		recent.push_front(key)
		while recent.size() > Config.RECENT_MAX:
			recent.pop_back()
	selection_changed.emit(key)


## Son kullanılan yapılar arasında dolaşır (step +1 / -1).
func cycle_recent(step: int) -> void:
	if recent.is_empty():
		return
	var i: int = recent.find(selected)
	var next: int = 0 if i < 0 else posmod(i + step, recent.size())
	selected = recent[next]
	selection_changed.emit(selected)


func is_canal() -> bool:
	return selected.begins_with(KEY_CANAL)


func is_free() -> bool:
	return selected.begins_with(KEY_FREE)


## Seçili yapının id'si (parça ya da tür).
func selected_id() -> String:
	if is_canal():
		return selected.substr(KEY_CANAL.length())
	if is_free():
		return selected.substr(KEY_FREE.length())
	return ""


func _process(_delta: float) -> void:
	if slot == SLOT_HAMMER and not hammer_owned():
		slot = SLOT_WATER
		slot_changed.emit(slot)


func _input_ready() -> bool:
	return player != null and bool(player.get("input_enabled")) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _input_ready():
		return
	if event.is_action_pressed("slot_1") and not event.is_echo():
		set_slot(SLOT_WATER)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("slot_2") and not event.is_echo():
		request_hammer()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button: int = (event as InputEventMouseButton).button_index
		if button != MOUSE_BUTTON_WHEEL_UP and button != MOUSE_BUTTON_WHEEL_DOWN:
			return
		var step: int = 1 if button == MOUSE_BUTTON_WHEEL_DOWN else -1
		if (event as InputEventMouseButton).shift_pressed:
			if hammer_active():
				cycle_recent(step)
		elif slot == SLOT_HAMMER:
			set_slot(SLOT_WATER)
		else:
			request_hammer()
		get_viewport().set_input_as_handled()
