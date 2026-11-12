extends RefCounted
## Turkce sayi bicimi. Saf mantik: binlik ayraci nokta, ondalik ayraci virgul.

const MILLION: float = 1.0e6
const BILLION: float = 1.0e9
const TRILLION: float = 1.0e12


## Tam sayi bicimi: 1.234, 1,23 Mn, 4,5 Mr, 2 Tr. Gecersiz girdide "0".
static func format_int(value: float) -> String:
	if not _is_valid(value):
		return "0"
	var rounded: float = roundf(value)
	if rounded < MILLION:
		return _group(int(rounded))
	return _format_large(rounded)


## Para bicimi: 1.000'in altinda en fazla tek ondalik (0,4), tam sayiysa ondaliksiz.
static func format_money(value: float) -> String:
	if not _is_valid(value):
		return "0"
	var tenths: float = roundf(value * 10.0) / 10.0
	if tenths < 1000.0:
		if is_equal_approx(tenths, roundf(tenths)):
			return _group(int(roundf(tenths)))
		return _trim_decimal(tenths, 1)
	return format_int(value)


static func _is_valid(value: float) -> bool:
	return not is_nan(value) and not is_inf(value) and value > 0.0


static func _format_large(value: float) -> String:
	var unit: String = "Mn"
	var divisor: float = MILLION
	if value >= TRILLION:
		unit = "Tr"
		divisor = TRILLION
	elif value >= BILLION:
		unit = "Mr"
		divisor = BILLION
	var scaled: float = roundf(value / divisor * 100.0) / 100.0
	# 999,999 Mn gibi degerler 1000'e yuvarlanirsa bir ust birime gec.
	if scaled >= 1000.0:
		if unit == "Mn":
			return "1 Mr"
		if unit == "Mr":
			return "1 Tr"
		return _group(int(scaled)) + " Tr"
	return _trim_decimal(scaled, 2) + " " + unit


## Ondalik kismi virgulle yazar, gereksiz sifirlari atar.
static func _trim_decimal(value: float, places: int) -> String:
	var text: String = String.num(value, places)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text.replace(".", ",")


static func _group(value: int) -> String:
	var digits: String = str(value)
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = digits[i] + out
		count += 1
	return out
