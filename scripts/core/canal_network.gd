extends RefCounted
## Yonlu parcalarla kanal izgarasi: durum ve duzenleme. Saf mantik; odeme baska katmanda yapilir.

const Pieces = preload("res://scripts/core/canal_pieces.gd")

var cols: int = Pieces.DEFAULT_COLS
var rows: int = Pieces.DEFAULT_ROWS
## Pinar tanimlari: id -> {row, flow, cost}. Pinarlar bati kenarindadir.
var spring_defs: Dictionary = {}
var open_springs: Array[String] = []
var width_level: int = 0
var lining_level: int = 0
## Her degisiklikte artar (onbellek icin).
var version: int = 0

## Hucreler satir satir (row * cols + col). Bos hucre {}, dolu hucre {piece, rotation, material, open}.
var _cells: Array = []


func _init(p_cols: int = Pieces.DEFAULT_COLS, p_rows: int = Pieces.DEFAULT_ROWS, p_springs: Dictionary = Pieces.DEFAULT_SPRINGS) -> void:
	configure(p_cols, p_rows, p_springs)


## Boyut ve pinarlari ayarlar; izgarayi ve yukseltmeleri sifirlar.
func configure(p_cols: int, p_rows: int, p_springs: Dictionary) -> void:
	cols = maxi(p_cols, 1)
	rows = maxi(p_rows, 1)
	spring_defs = p_springs.duplicate(true)
	open_springs = []
	width_level = 0
	lining_level = 0
	_clear_cells()
	version += 1


func _clear_cells() -> void:
	_cells = []
	_cells.resize(cols * rows)
	for i in range(_cells.size()):
		_cells[i] = {}


func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < cols and row >= 0 and row < rows


func _idx(col: int, row: int) -> int:
	return row * cols + col


func spring_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in spring_defs.keys():
		ids.append(String(id))
	return ids


# --- Sorgular ---

## Bos hucre ya da sinir disi icin {}. Kopya doner.
func get_piece(col: int, row: int) -> Dictionary:
	if not in_bounds(col, row):
		return {}
	return (_cells[_idx(col, row)] as Dictionary).duplicate()


func piece_count() -> int:
	var n: int = 0
	for c in _cells:
		if not (c as Dictionary).is_empty():
			n += 1
	return n


func count_of(piece_id: String) -> int:
	var n: int = 0
	for c in _cells:
		var d: Dictionary = c
		if not d.is_empty() and d["piece"] == piece_id:
			n += 1
	return n


func mill_count() -> int:
	return count_of("mill")


## Simdi konsaydi odenecek fiyat. Bilinmeyen parca/malzeme icin -1.
func cost(piece_id: String, material: String) -> int:
	return Pieces.piece_cost(piece_id, material, piece_count(), mill_count())


func spring_cost(id: String) -> int:
	if not spring_defs.has(id):
		return -1
	return int(spring_defs[id]["cost"])


func width_cost() -> int:
	return Pieces.width_upgrade_cost(width_level)


func lining_cost() -> int:
	return Pieces.lining_upgrade_cost(lining_level)


## Sokulursa verilecek iade (sokulduktan sonraki sayiya gore fiyatin yarisi). Bos hucre 0.
func removal_refund(col: int, row: int) -> int:
	var p: Dictionary = get_piece(col, row)
	if p.is_empty():
		return 0
	var mills_after: int = mill_count()
	if p["piece"] == "mill":
		mills_after -= 1
	var price: int = Pieces.piece_cost(p["piece"], p["material"], piece_count() - 1, mills_after)
	return Pieces.refund_of(price)


# --- Duzenleme ---

func place(col: int, row: int, piece_id: String, rotation: int, material: String) -> bool:
	if not in_bounds(col, row) or not Pieces.has_piece(piece_id) or not Pieces.has_material(material):
		return false
	if not (_cells[_idx(col, row)] as Dictionary).is_empty():
		return false
	var cell: Dictionary = {"piece": piece_id, "rotation": posmod(rotation, 4), "material": material}
	if piece_id == "gate":
		cell["open"] = true
	_cells[_idx(col, row)] = cell
	version += 1
	return true


## Iade tutarini dondurur; hucre bosalir.
func remove(col: int, row: int) -> int:
	if not in_bounds(col, row) or (_cells[_idx(col, row)] as Dictionary).is_empty():
		return 0
	var refund: int = removal_refund(col, row)
	_cells[_idx(col, row)] = {}
	version += 1
	return refund


## Parcayi 90 derece saat yonunde cevirir.
func rotate(col: int, row: int) -> bool:
	if not in_bounds(col, row):
		return false
	var cell: Dictionary = _cells[_idx(col, row)]
	if cell.is_empty():
		return false
	cell["rotation"] = (int(cell["rotation"]) + 1) % 4
	version += 1
	return true


func toggle_gate(col: int, row: int) -> bool:
	if not in_bounds(col, row):
		return false
	var cell: Dictionary = _cells[_idx(col, row)]
	if cell.is_empty() or cell["piece"] != "gate":
		return false
	cell["open"] = not bool(cell.get("open", true))
	version += 1
	return true


func is_spring_open(id: String) -> bool:
	return open_springs.has(id)


func open_spring(id: String) -> bool:
	if not spring_defs.has(id) or open_springs.has(id):
		return false
	open_springs.append(id)
	version += 1
	return true


func upgrade_width() -> bool:
	if width_level >= Pieces.WIDTH_MAX_LEVEL:
		return false
	width_level += 1
	version += 1
	return true


func upgrade_lining() -> bool:
	if lining_level >= Pieces.LINING_MAX_LEVEL:
		return false
	lining_level += 1
	version += 1
	return true


# --- Kayit ---

func to_dict() -> Dictionary:
	var cell_list: Array = []
	for c in _cells:
		cell_list.append((c as Dictionary).duplicate())
	var spring_list: Array = []
	for id in open_springs:
		spring_list.append(id)
	return {
		"cols": cols,
		"rows": rows,
		"cells": cell_list,
		"open_springs": spring_list,
		"width_level": width_level,
		"lining_level": lining_level,
	}


## Bozuk veri cokertmez: bilinmeyen parca/malzeme hucresi bosalir, yanlis boyutlu veri bos izgara verir.
## Boyut ve pinar tanimlari bu nesnenin kendi ayarindan gelir.
func from_dict(d: Variant) -> void:
	_clear_cells()
	open_springs = []
	width_level = 0
	lining_level = 0
	version += 1
	if typeof(d) != TYPE_DICTIONARY:
		return
	var data: Dictionary = d
	if _to_whole(data.get("cols", null)) != cols or _to_whole(data.get("rows", null)) != rows:
		return
	var raw_cells: Variant = data.get("cells", null)
	if typeof(raw_cells) == TYPE_ARRAY:
		var arr: Array = raw_cells
		if arr.size() == _cells.size():
			for i in range(arr.size()):
				_cells[i] = _sanitize_cell(arr[i])
	var raw_springs: Variant = data.get("open_springs", null)
	if typeof(raw_springs) == TYPE_ARRAY:
		for s in raw_springs:
			if typeof(s) == TYPE_STRING and spring_defs.has(s) and not open_springs.has(s):
				open_springs.append(s)
	width_level = _sanitize_level(data.get("width_level", 0), Pieces.WIDTH_MAX_LEVEL)
	lining_level = _sanitize_level(data.get("lining_level", 0), Pieces.LINING_MAX_LEVEL)


static func _to_whole(v: Variant) -> int:
	# JSON sayilari float gelir; yalnizca tam sayi degerli sayilar kabul edilir.
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
		return int(v)
	return -1


static func _sanitize_cell(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var src: Dictionary = v
	var piece_id: Variant = src.get("piece", null)
	var material: Variant = src.get("material", null)
	if typeof(piece_id) != TYPE_STRING or not Pieces.has_piece(piece_id):
		return {}
	if typeof(material) != TYPE_STRING or not Pieces.has_material(material):
		return {}
	var rot: int = _to_whole(src.get("rotation", null))
	if rot < 0 or rot > 3:
		return {}
	var cell: Dictionary = {"piece": piece_id, "rotation": rot, "material": material}
	if piece_id == "gate":
		cell["open"] = src.get("open", true) != false
	return cell


static func _sanitize_level(v: Variant, max_level: int) -> int:
	var n: int = _to_whole(v)
	if n < 0:
		return 0
	return mini(n, max_level)
