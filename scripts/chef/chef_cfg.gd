class_name ChefCfg
## Настройки режима «Повар». Все цифры и расстановка — здесь.

const SPR := "res://assets/sprites/kitchen/"
const VIEW := Vector2(1280, 720)
const TABLE_EDGE := 570.0          # экранная Y ближнего края столешницы

# ---------- Ингредиенты ----------
# kind: slice — кладётся картинкой; sauce — рисуется зигзагом цвета color; cooked — жарится на сковороде.
# w — ширина слоя на тарелке.
const ING := {
	"bread": {"name": "Хлеб", "tex": "bread.png", "kind": "slice", "w": 190},
	"cheese": {"name": "Сыр", "tex": "cheese.png", "kind": "slice", "w": 170},
	"sausage": {"name": "Колбаса", "tex": "sausage.png", "kind": "slice", "w": 150},
	"tomato": {"name": "Помидор", "tex": "tomato.png", "kind": "slice", "w": 120},
	"cucumber": {"name": "Огурец", "tex": "cucumber.png", "kind": "slice", "w": 105},
	"lettuce": {"name": "Салат", "tex": "lettuce.png", "kind": "slice", "w": 185},
	"onion": {"name": "Лук", "tex": "onion.png", "kind": "slice", "w": 115},
	"patty": {"name": "Котлета", "tex": "patty_cooked.png", "kind": "cooked", "w": 160},
	"bacon": {"name": "Бекон", "tex": "bacon_cooked.png", "kind": "cooked", "w": 165},
	"egg": {"name": "Яйцо", "tex": "egg_fried.png", "kind": "cooked", "w": 165},
	"ketchup": {"name": "Кетчуп", "tex": "ketchup.png", "kind": "sauce", "color": Color(0.85, 0.08, 0.05)},
	"mustard": {"name": "Горчица", "tex": "mustard.png", "kind": "sauce", "color": Color(0.95, 0.78, 0.1)},
}

# ---------- Стол ----------
# Продукты лежат на длинном лотке группами: основа, овощи, «жарить» (сырые бекон и яйца).
# Соусы стоят прямо на столе. Сырые котлеты — на блюдце у плиты.
# Тап по продукту — он летит туда, где нужен (на тарелку или на сковороду). Можно и перетащить.
# stock — сколько штук в запасе: тараканы их воруют, запас понемногу пополняется.
const LONG_TRAY := Rect2(18, 8, 1050, 196)
const TRAY_GROUPS := [
	{"title": "ОСНОВА", "x": Vector2(60, 360)},
	{"title": "ОВОЩИ", "x": Vector2(360, 790)},
	{"title": "ЖАРИТЬ", "x": Vector2(790, 1030)},
]
const SUPPLIES := [
	{"id": "bread", "pos": Vector2(118, 104), "w": 96},
	{"id": "cheese", "pos": Vector2(214, 104), "w": 86},
	{"id": "sausage", "pos": Vector2(306, 104), "w": 84},
	{"id": "tomato", "pos": Vector2(424, 104), "w": 84},
	{"id": "cucumber", "pos": Vector2(522, 104), "w": 80},
	{"id": "lettuce", "pos": Vector2(626, 104), "w": 94},
	{"id": "onion", "pos": Vector2(728, 104), "w": 84},
	{"id": "bacon_raw", "pos": Vector2(858, 104), "w": 104},
	{"id": "eggs", "pos": Vector2(962, 104), "w": 88},
	{"id": "patty_raw", "pos": Vector2(330, 350), "w": 84},
	{"id": "ketchup", "pos": Vector2(950, 268), "w": 62, "stand": true},
	{"id": "mustard", "pos": Vector2(1030, 268), "w": 66, "stand": true},
]
# Что жарится: сырой продукт (запас) → готовый слой. cook/burn — секунды.
const COOKABLE := {
	"patty_raw": {"result": "patty", "raw": "patty_raw.png", "cook": 6.0, "burn": 7.0},
	"bacon_raw": {"result": "bacon", "raw": "bacon_raw.png", "cook": 4.5, "burn": 6.0},
	"eggs": {"result": "egg", "raw": "egg_raw.png", "cook": 4.0, "burn": 6.0},
}
const STOCK_MAX := 5
# Сами продукты не пополняются. Два удара по звонку подряд — приходит рука поставщика
# и докладывает всё, что кончилось. Эта же рука уносит готовый заказ и возвращает грязную тарелку.
const DOUBLE_RING := 0.8            # окно для второго удара, сек
const SUPPLIER_TEX := "hand_supplier.png"
const SUPPLIER_HEAD := Vector2(312, 95)
const SUPPLIER_SCALE := 0.55
const SUPPLIER_SHOULDER := Vector2(640, -420)   # рука тянется сверху, из-за стола напротив
const PATTY_DISH_W := 125
const STOVE_TEX := "stove_electric.png"
const STOVE_POS := Vector2(150, 350)
const STOVE_W := 200
const PAN_W := 175
const PLATE_POS := Vector2(590, 355)
const PLATE_W := 245
const BELL_POS := Vector2(1172, 470)   # под чеком заказа
const BELL_W := 92
const READY_POS := Vector2(1172, 530)   # плашка «ГОТОВО» под звонком
const TICKET_RECT := Rect2(1080, 18, 188, 420)

# ---------- Жарка ----------
const BURNT_PENALTY := 20           # сгоревшее выбрасывается, жарить заново

# ---------- Мытьё ----------
const WASH_DIST := 2600.0           # сколько пикселей нужно натереть губкой

# ---------- Рука ----------
# head — пиксель спрайта под курсором (центр предмета в руке).
const HANDS := {
	"hand": {"tex": "hand_open.png", "head": Vector2(293, 62)},
	"sponge": {"tex": "hand_sponge.png", "head": Vector2(322, 92)},
	"swatter": {"tex": "hand_swatter.png", "head": Vector2(312, 69)},
	"fist": {"tex": "hand_fist.png", "head": Vector2(158, 57)},
}
const TOOLS := ["hand", "sponge", "swatter"]
const TOOL_NAMES := {"hand": "Рука", "sponge": "Губка", "swatter": "Мухобойка"}
const HAND_SCALE := 0.6
const SHOULDER := Vector2(640, 1010)
const HIT_RADIUS := 58.0
const SCARE_RADIUS := 50.0          # тап рукой по таракану — он убегает

# ---------- Очки ----------
const ORDER_BASE := 100
const ORDER_PER_LAYER := 10
const ORDER_TIME_BONUS := 100       # максимум за скорость
const RUIN_PENALTY := 30            # таракан испортил сэндвич
const WRONG_PENALTY := 10           # не тот продукт — он отскакивает назад
const TIMEOUT_PENALTY := 50
const VOMIT_PENALTY := 50           # отдал сэндвич с тараканом внутри — посетителя тошнит
const STOLEN_BACK := 15             # прибил воришку — продукт вернулся

# ---------- Тараканы на кухне ----------
# Таракан садится на продукт, посидев — хватает штуку и тащит со стола (запас −1).
# Прихлопнешь воришку — продукт вернётся. На тарелку тараканы не залезают — обходят её.
# Раздавленный таракан оставляет пятно, пятна добавляют грязи, а грязь приманивает новых.
const STEAL_TIME := Vector2(2.5, 4.5)  # сколько сидит на продукте, прежде чем утащить
const SIT_TIME := Vector2(4.0, 7.0)    # сколько сидит на пятне

# ---------- Этапы бесконечной игры ----------
# Режим «Повар» бесконечный: заказы идут без конца. Список ниже — этапы:
# этап 1 — только хлеб, сыр, колбаса; после orders заказов открывается следующий этап
# и на лоток добавляется новый продукт. После последнего этапа время на заказ
# каждый раз сокращается (ENDLESS_TIME_DECAY), пока не дойдёт до ENDLESS_TIME_MIN.
# Игра кончается, когда сорвано STRIKES заказов (время вышло или жалоба).
# fillings — что может быть внутри сэндвича; layers — сколько начинок (мин, макс);
# orders — заказов за смену; time — секунд на заказ; roaches — какие виды тараканов приходят.
const SHIFTS := [
	{"name": "Этап 1", "fillings": ["cheese", "sausage"], "layers": Vector2i(1, 2),
		"orders": 4, "time": 45.0, "roaches": ["normal"]},
	{"name": "Этап 2", "fillings": ["cheese", "sausage", "tomato"], "layers": Vector2i(1, 3),
		"orders": 4, "time": 45.0, "roaches": ["normal"]},
	{"name": "Этап 3", "fillings": ["cheese", "sausage", "tomato", "cucumber"], "layers": Vector2i(2, 3),
		"orders": 5, "time": 45.0, "roaches": ["normal", "fast"]},
	{"name": "Этап 4", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup"], "layers": Vector2i(2, 3),
		"orders": 5, "time": 48.0, "roaches": ["normal", "fast"]},
	{"name": "Этап 5", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup", "patty"], "layers": Vector2i(2, 4),
		"orders": 6, "time": 48.0, "roaches": ["normal", "fast", "big"]},
	{"name": "Этап 6", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup", "patty", "lettuce"], "layers": Vector2i(2, 4),
		"orders": 6, "time": 48.0, "roaches": ["normal", "fast", "big"]},
	{"name": "Этап 7", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup", "patty", "lettuce", "egg"], "layers": Vector2i(3, 4),
		"orders": 7, "time": 46.0, "roaches": ["normal", "fast", "big", "flying"]},
	{"name": "Этап 8", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup", "patty", "lettuce", "egg", "onion"], "layers": Vector2i(3, 5),
		"orders": 7, "time": 46.0, "roaches": ["normal", "fast", "big", "flying"]},
	{"name": "Этап 9", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup", "patty", "lettuce", "egg", "onion", "mustard"], "layers": Vector2i(3, 5),
		"orders": 9, "time": 46.0, "roaches": ["normal", "fast", "big", "flying"]},
	{"name": "Этап 10", "fillings": ["cheese", "sausage", "tomato", "cucumber", "ketchup", "patty", "lettuce", "egg", "onion", "mustard", "bacon"], "layers": Vector2i(3, 5),
		"orders": 9, "time": 46.0, "roaches": ["normal", "fast", "big", "flying"]},
]
const MAX_ROACHES := 10
const STRIKES := 3
const ENDLESS_TIME_DECAY := 0.97
const ENDLESS_TIME_MIN := 24.0

# ---------- Грязь кухни ----------
# Тараканы сами не заводятся — их приманивает грязь. Счётчик грязи 0–100%:
# пятна на столе, грязная тарелка, сгоревшая еда, раздавленные тараканы.
# 0% — тараканов нет совсем; чем грязнее, тем чаще и больше приходят.
const DIRT_MAX := 10.0              # столько «очков грязи» = 100%
const DIRT_WEIGHT := {"crumbs": 1.0, "ketchup": 1.0, "grease": 1.5, "roach": 1.5, "burnt": 2.0}
const DIRT_PLATE := 1.0             # грязная тарелка добавляет столько (пока не помыта)
const STAINS_PER_ORDER := Vector2i(1, 2)
const ROACH_MIN_DIRT := 0.08        # ниже этого тараканы не приходят
const ROACH_INTERVAL := Vector2(9.0, 1.4)   # интервал появления при малой и полной грязи, сек
const DIRTY_LEVEL := 0.7            # выше — посетители теряют терпение быстрее
const DIRTY_PATIENCE := 1.6
const STAIN_WASH := 380.0           # сколько натереть губкой одно пятно


static var _tex_cache := {}


## Картинка из assets/sprites/kitchen/. Если Godot не смог её импортировать
## (битый кэш .godot, файл подменили при открытом редакторе) — читаем PNG напрямую.
static func tex(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	var p := SPR + file
	var t: Texture2D = null
	if ResourceLoader.exists(p):
		t = load(p) as Texture2D
	if t == null and FileAccess.file_exists(p):
		var img := Image.load_from_file(ProjectSettings.globalize_path(p))
		if img and not img.is_empty():
			t = ImageTexture.create_from_image(img)
			push_warning("Kitchen Commotion: %s прочитан напрямую — импорт Godot не сработал" % file)
	if t != null:
		_tex_cache[file] = t
	return t


## Масштаб, чтобы картинка стала шириной w.
static func fit(t: Texture2D, w: float) -> float:
	return w / t.get_width() if t else 1.0
