extends Node
## Açık panel yöneticisi: aynı anda tek panel açık kalır.
## Tab: Geliştirmeler'i açar/kapatır (dükkân açıksa onu kapatıp açar; duraklatma menüsü açıkken bir şey yapmaz).
## E (dükkân tezgâhı): dükkânı yalnızca hiçbir panel açık değilken açar.
## Q (yapı kitapçığı): yalnızca çekiç eldeyken ve hiçbir panel açık değilken açar; Q ya da Esc kapatır.
## Esc: açık paneli kapatır (panellerin kendi _input'u); hiçbiri açık değilse duraklatma menüsü açılır.
## Dış bağlantı: add_child'dan önce `game`, `shop`, `upgrades`, `pause`, `book`, `equipment` atanır.

var game: Node
var shop: Node
var upgrades: Node
var pause: Node
var book: Node
var equipment: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if game != null and game.has_signal("shop_requested"):
		game.connect("shop_requested", _on_shop_requested)


func any_open() -> bool:
	return bool(shop.call("is_open")) or bool(upgrades.call("is_open")) or bool(pause.call("is_open")) \
			or (book != null and bool(book.call("is_open")))


## Tab'ın yaptığı iş; testler ve ekran görüntüsü argümanları için ayrı.
func toggle_upgrades() -> void:
	if bool(pause.call("is_open")):
		return
	if bool(upgrades.call("is_open")):
		upgrades.call("close")
		return
	if bool(shop.call("is_open")):
		shop.call("close")
	if book != null and bool(book.call("is_open")):
		book.call("close")
	upgrades.call("open")


## Q'nun yaptığı iş: kitapçık açıksa kapatır; değilse çekiç eldeyken ve panel yokken açar.
func toggle_book() -> void:
	if book == null:
		return
	if bool(book.call("is_open")):
		book.call("close")
		return
	if any_open() or equipment == null or not bool(equipment.call("hammer_active")):
		return
	book.call("open")


func _on_shop_requested() -> void:
	if not any_open():
		shop.call("open")


## Tab, Godot'un odak gezinmesinden (ui_focus_next) önce burada yakalanır.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrades") and not event.is_echo():
		toggle_upgrades()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_book") and not event.is_echo():
		if book != null and not bool(book.call("is_open")) and (any_open() or equipment == null or not bool(equipment.call("hammer_active"))):
			return
		if book != null and bool(book.call("is_open")):
			return # kitapçık kendi _input'unda kapatır
		toggle_book()
		get_viewport().set_input_as_handled()
