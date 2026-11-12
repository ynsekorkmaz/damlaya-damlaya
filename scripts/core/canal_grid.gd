extends RefCounted
## Kanal izgarasinin durumu ve duzenlemesi. Saf mantik; odeme ekonomi katmaninda yapilir.

const CanalConfig = preload("res://scripts/core/canal_config.gd")

var cells: PackedInt32Array = PackedInt32Array()
var open_springs: Array[String] = []
var width_level: int = 0
var lining_level: int = 0
## Izgara, pinar ya da yukseltme her degistiginde artar (onbellek icin).
var version: int = 0


func _init() -> void:
	_clear_cells()


func _clear_cells() -> void:
	cells = PackedInt32Array()
	cells.resize(CanalConfig.COLS * CanalConfig.ROWS)
	cells.fill(CanalConfig.CELL_EMPTY)


func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < CanalConfig.COLS and row >= 0 and row < CanalConfig.ROWS


func get_cell(col: int, row: int) -> int:
	if not in_bounds(col, row):
		return CanalConfig.CELL_EMPTY
	return cells[row * CanalConfig.COLS + col]


func _set_cell(col: int, row: int, value: int) -> void:
	cells[row * CanalConfig.COLS + col] = value
	version += 1


## Kanal + degirmen hucrelerinin toplami.
func piece_count() -> int:
	var n: int = 0
	for v in cells:
		if v != CanalConfig.CELL_EMPTY:
			n += 1
	return n


func mill_count() -> int:
	var n: int = 0
	for v in cells:
		if v == CanalConfig.CELL_MILL:
			n += 1
	return n


# --- Fiyatlar ---

static func _canal_price(piece_total: int) -> int:
	return floori(CanalConfig.CANAL_BASE_COST * pow(CanalConfig.CANAL_COST_GROWTH, piece_total))


static func _mill_price(mill_total: int) -> int:
	return floori(CanalConfig.MILL_BASE_COST * pow(CanalConfig.MILL_COST_GROWTH, mill_total))


func canal_cost() -> int:
	return _canal_price(piece_count())


func mill_cost() -> int:
	return _mill_price(mill_count())


func spring_cost(id: String) -> int:
	if not CanalConfig.SPRINGS.has(id):
		return -1
	return int(CanalConfig.SPRINGS[id]["cost"])


## En yuksek seviyede -1 dondurur.
func width_cost() -> int:
	if width_level >= CanalConfig.WIDTH_MAX_LEVEL:
		return -1
	return floori(CanalConfig.WIDTH_BASE_COST * pow(CanalConfig.WIDTH_COST_GROWTH, width_level))


## En yuksek seviyede -1 dondurur.
func lining_cost() -> int:
	if lining_level >= CanalConfig.LINING_MAX_LEVEL:
		return -1
	return floori(CanalConfig.LINING_BASE_COST * pow(CanalConfig.LINING_COST_GROWTH, lining_level))


# --- Duzenleme ---

func place_canal(col: int, row: int) -> bool:
	if not in_bounds(col, row) or get_cell(col, row) != CanalConfig.CELL_EMPTY:
		return false
	_set_cell(col, row, CanalConfig.CELL_CANAL)
	return true


func place_mill(col: int, row: int) -> bool:
	if not in_bounds(col, row) or get_cell(col, row) != CanalConfig.CELL_CANAL:
		return false
	_set_cell(col, row, CanalConfig.CELL_MILL)
	return true


## Iade tutarini dondurur. Degirmen sokulunce hucre kanal kalir, kanal sokulunce bosalir.
func remove(col: int, row: int) -> int:
	var v: int = get_cell(col, row)
	if v == CanalConfig.CELL_EMPTY:
		return 0
	var refund: int
	if v == CanalConfig.CELL_MILL:
		# Parca sayisi degismez; degirmen sayisi bir azalir.
		refund = floori(_mill_price(mill_count() - 1) * CanalConfig.REFUND_FACTOR)
		_set_cell(col, row, CanalConfig.CELL_CANAL)
	else:
		refund = floori(_canal_price(piece_count() - 1) * CanalConfig.REFUND_FACTOR)
		_set_cell(col, row, CanalConfig.CELL_EMPTY)
	return refund


func is_spring_open(id: String) -> bool:
	return open_springs.has(id)


func open_spring(id: String) -> bool:
	if not CanalConfig.SPRINGS.has(id) or open_springs.has(id):
		return false
	open_springs.append(id)
	version += 1
	return true


func upgrade_width() -> bool:
	if width_level >= CanalConfig.WIDTH_MAX_LEVEL:
		return false
	width_level += 1
	version += 1
	return true


func upgrade_lining() -> bool:
	if lining_level >= CanalConfig.LINING_MAX_LEVEL:
		return false
	lining_level += 1
	version += 1
	return true


# --- Kayit ---

## Hucreler satir satir (row * COLS + col) duz liste olarak yazilir.
func to_dict() -> Dictionary:
	var cell_list: Array = []
	for v in cells:
		cell_list.append(v)
	var spring_list: Array = []
	for id in open_springs:
		spring_list.append(id)
	return {
		"cells": cell_list,
		"open_springs": spring_list,
		"width_level": width_level,
		"lining_level": lining_level,
	}


## Bozuk veri cokertmez: gecersiz hucre 0 olur, yanlis boyutlu izgara bos kalir.
func from_dict(d: Variant) -> void:
	_clear_cells()
	open_springs = []
	width_level = 0
	lining_level = 0
	version += 1
	if typeof(d) != TYPE_DICTIONARY:
		return
	var data: Dictionary = d
	var raw_cells: Variant = data.get("cells", null)
	if typeof(raw_cells) == TYPE_ARRAY:
		var arr: Array = raw_cells
		if arr.size() == cells.size():
			for i in range(arr.size()):
				cells[i] = _sanitize_cell(arr[i])
	var raw_springs: Variant = data.get("open_springs", null)
	if typeof(raw_springs) == TYPE_ARRAY:
		for s in raw_springs:
			if typeof(s) == TYPE_STRING and CanalConfig.SPRINGS.has(s) and not open_springs.has(s):
				open_springs.append(s)
	width_level = _sanitize_level(data.get("width_level", 0), CanalConfig.WIDTH_MAX_LEVEL)
	lining_level = _sanitize_level(data.get("lining_level", 0), CanalConfig.LINING_MAX_LEVEL)


static func _to_whole(v: Variant) -> int:
	# JSON sayilari float gelir; yalnizca tam sayi degerli sayilar kabul edilir.
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
		return int(v)
	return -1


static func _sanitize_cell(v: Variant) -> int:
	var n: int = _to_whole(v)
	if n == CanalConfig.CELL_CANAL or n == CanalConfig.CELL_MILL:
		return n
	return CanalConfig.CELL_EMPTY


static func _sanitize_level(v: Variant, max_level: int) -> int:
	var n: int = _to_whole(v)
	if n < 0:
		return 0
	return mini(n, max_level)
