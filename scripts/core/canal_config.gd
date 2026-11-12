extends RefCounted
## Kanal sistemi sabitleri (tasarim belgesi bolum 5). Koda sayi gomulmez, hepsi burada.

const COLS: int = 8
const ROWS: int = 5

const CELL_EMPTY: int = 0
const CELL_CANAL: int = 1
const CELL_MILL: int = 2

## Pinarlar: sabit satir, akis (damla/sn), acma maliyeti.
const SPRING_IDS: Array[String] = ["A", "B", "C"]
const SPRINGS: Dictionary = {
	"A": {"row": 2, "flow": 60.0, "cost": 4000},
	"B": {"row": 0, "flow": 180.0, "cost": 30000},
	"C": {"row": 4, "flow": 480.0, "cost": 200000},
}
const SPRING_COL: int = 0
const EXIT_COL: int = 7

## Fiyat formulleri: taban * carpan^n
const CANAL_BASE_COST: float = 30.0
const CANAL_COST_GROWTH: float = 1.04
const MILL_BASE_COST: float = 600.0
const MILL_COST_GROWTH: float = 1.5
const REFUND_FACTOR: float = 0.5

## Yukseltmeler
const WIDTH_MAX_LEVEL: int = 4
const WIDTH_BASE_COST: float = 3000.0
const WIDTH_COST_GROWTH: float = 4.0
const LINING_MAX_LEVEL: int = 3
const LINING_BASE_COST: float = 5000.0
const LINING_COST_GROWTH: float = 4.0

## Akis parametreleri
const CAP_PER_EXIT_BASE: float = 80.0
const CAP_WIDTH_GROWTH: float = 2.0
const LEAK_PER_CELL: Array[float] = [0.05, 0.035, 0.02, 0.008]
const MILL_BONUS_PER_MILL: float = 0.08
const MILL_BONUS_MAX_COUNT: int = 3
