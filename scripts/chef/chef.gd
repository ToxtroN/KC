extends Node2D
## Режим «Повар»: заказ → сборка сэндвича → звонок → грязная тарелка → губка → снова заказ.
## Продукты можно брать тапом (летят на тарелку сами) или перетаскивать рукой.
## Тараканы садятся на продукты и сэндвич — их гоняют рукой или бьют мухобойкой.

const SAVE := "user://chef.cfg"

enum Mode { MENU, PLAY, END }
var mode := Mode.MENU

var world: Node2D
var stains_layer: Node2D
var items: Node2D
var roach_layer: Node2D
var fx: Node2D
var over: Node2D                  # то, что «над» столом: чек заказа
var top_fx: Node2D                # надписи поверх руки
var hand: ChefHand
var hud: ChefHud
var plate: KitchenItems.Plate
var pan: KitchenItems.Pan
var ticket: KitchenItems.Ticket
var bell: KitchenItems.Bell
var supplies: Array = []
var obstacles: Array[Rect2] = []
var _tray: KitchenItems.LongTray
var supplier: KitchenItems.SupplierHand
var _sup_busy := false
var _sup_queue: Array[String] = []   # "serve" / "restock"
var _served_roach := false
var _carry_roach = null             # таракан, сидевший на взятом продукте
var _ring_t := 0.0                   # окно для второго удара по звонку

var shift_i := 0
var shift: Dictionary
var score := 0
var served := 0
var fails := 0                    # сорванные заказы (время вышло)
var mistakes := 0                 # все ошибки: не тот продукт, сорванные, испорченные
var order_n := 0
var order: Dictionary = {}        # {recipe, time_left, total}
var plate_away := false
var best := 0
var stage_orders := 0             # заказов на текущем этапе
var order_time := 45.0

var _roach_t := 2.0
var _spoil_t := 0.0
var _dirt_hud_t := 0.0
var _mouse_down := false
var _last_mouse := Vector2(640, 420)
var _shake := 0.0
# нажатие на продукт или сковородку: тап или начало перетаскивания
var _press_src = null             # Supply, pan или null
var _press_pos := Vector2.ZERO
var _dragging := false
var _intro := false
var _touch := false               # играют пальцем: перетаскиваемый продукт приподнят над пальцем
const TOUCH_LIFT := 85.0               # открыт экран с историей и подсказками

const DRAG_START := 14.0


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var table := Sprite2D.new()
	table.texture = ChefCfg.tex("kitchen_table.png")
	table.centered = false
	world.add_child(table)
	stains_layer = Node2D.new()
	world.add_child(stains_layer)
	items = Node2D.new()
	world.add_child(items)
	roach_layer = Node2D.new()
	world.add_child(roach_layer)
	over = Node2D.new()
	world.add_child(over)
	supplier = KitchenItems.SupplierHand.new()
	world.add_child(supplier)
	supplier.setup()
	fx = Node2D.new()
	world.add_child(fx)
	hand = ChefHand.new()
	world.add_child(hand)
	hand.slammed.connect(_on_slam)
	hand.aim(_last_mouse)
	top_fx = Node2D.new()
	world.add_child(top_fx)

	hud = ChefHud.new()
	add_child(hud)
	hud.shift_chosen.connect(func(_i): start_shift(0))
	hud.tool_chosen.connect(set_tool)
	hud.menu_pressed.connect(_on_menu)
	hud.pause_pressed.connect(func(): _set_paused(true))
	hud.resume_pressed.connect(func(): _set_paused(false))
	set_tool("hand")
	Sound.music(self, "music_chef.mp3")
	_load()
	_check_assets()
	_build_kitchen()
	start_shift(0, true)   # «Новая игра» в меню: сначала история и подсказки, потом за плиту


## Если каких-то картинок нет (проект скопирован не целиком) — пишем список прямо на экран.
func _check_assets() -> void:
	var need := ["kitchen_table.png", "long_tray.png", "stove_electric.png", "pan.png", "plate_clean.png",
		"plate_dirty.png", "bell.png", "hand_open.png", "hand_fist.png", "hand_sponge.png", "hand_swatter.png",
		"hand_supplier.png", "patty_raw.png"]
	for id in ChefCfg.ING:
		need.append(ChefCfg.ING[id].tex)
	var missing: Array = []
	for f in need:
		if ChefCfg.tex(f) == null:   # нет файла или он не загрузился
			missing.append(f)
	if missing.is_empty():
		return
	push_error("Kitchen Commotion: нет файлов в assets/sprites/kitchen/: " + ", ".join(missing))
	var l := Label.new()
	l.text = "Не загрузились картинки из assets/sprites/kitchen/:\n" + ", ".join(missing) + \
		"\nЗакройте Godot, удалите папку .godot в проекте и откройте проект заново."
	l.position = Vector2(20, 230)
	l.size = Vector2(1240, 200)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(l)


func _build_kitchen() -> void:
	for c in items.get_children():
		c.queue_free()
	if ticket:
		ticket.queue_free()
	for c in stains_layer.get_children():
		c.queue_free()
	supplies.clear()
	var tray := KitchenItems.LongTray.new()
	items.add_child(tray)
	tray.setup()
	_tray = tray
	var stove := Sprite2D.new()
	stove.texture = ChefCfg.tex(ChefCfg.STOVE_TEX)
	stove.scale = Vector2.ONE * ChefCfg.fit(stove.texture, ChefCfg.STOVE_W)
	stove.position = ChefCfg.STOVE_POS
	items.add_child(stove)
	pan = KitchenItems.Pan.new()
	items.add_child(pan)
	pan.setup()
	pan.burnt.connect(func(): _popup(pan.global_position + Vector2(0, -90), "Сгорело! Выбрось и жарь заново", Color(1, 0.45, 0.3)))
	# на столе только продукты, открытые в этой смене
	var open_ids := _open_supplies()
	if "patty_raw" in open_ids:
		var dish := Sprite2D.new()   # блюдце под сырыми котлетами
		dish.texture = ChefCfg.tex("plate_clean.png")
		dish.scale = Vector2.ONE * ChefCfg.fit(dish.texture, ChefCfg.PATTY_DISH_W)
		for d in ChefCfg.SUPPLIES:
			if d.id == "patty_raw":
				dish.position = d.pos
		items.add_child(dish)
	for d in ChefCfg.SUPPLIES:
		if not d.id in open_ids:
			continue
		if not d.get("stand", false):
			tray.open_x.append(d.pos.x)
		var s := KitchenItems.Supply.new()
		items.add_child(s)
		s.setup(d)
		supplies.append(s)
	bell = KitchenItems.Bell.new()
	items.add_child(bell)
	bell.setup()
	plate = KitchenItems.Plate.new()
	items.add_child(plate)
	plate.setup()
	ticket = KitchenItems.Ticket.new()
	ticket.position = ChefCfg.TICKET_RECT.position
	ticket.visible = false
	over.add_child(ticket)
	# препятствия для тараканов: плита, тарелка (на неё не лезут) и чек (висит над столом)
	obstacles.clear()
	var pr := ChefCfg.PLATE_W * 0.42
	obstacles.append(Rect2(ChefCfg.PLATE_POS - Vector2(pr, pr), Vector2(pr, pr) * 2.0))
	var st_size: Vector2 = (stove.texture.get_size() if stove.texture else Vector2(240, 220)) * stove.scale
	obstacles.append(Rect2(ChefCfg.STOVE_POS - st_size * 0.5, st_size))
	# чек висит у правого края — перекрываем и щель до края экрана, чтобы там не застревали
	var tr: Rect2 = ChefCfg.TICKET_RECT
	obstacles.append(Rect2(tr.position - Vector2(0, 200), Vector2(ChefCfg.VIEW.x - tr.position.x + 200, tr.size.y + 200)))
	obstacles.append(Rect2(ChefCfg.STOVE_POS + Vector2(-22, st_size.y * 0.5 - 10), Vector2(44, 110)))   # ручка сковороды


# ------------------------------------------------------------ смена

func start_shift(i: int, intro := false) -> void:
	shift_i = clampi(i, 0, ChefCfg.SHIFTS.size() - 1)
	shift = ChefCfg.SHIFTS[shift_i]
	stage_orders = 0
	order_time = shift.time
	_sup_queue.clear()
	_sup_busy = false
	_ring_t = 0.0
	if supplier:
		supplier.visible = false
		supplier.carry = null
	for c in roach_layer.get_children():
		c.queue_free()
	_build_kitchen()
	score = 0
	served = 0
	fails = 0
	mistakes = 0
	order_n = 0
	order = {}
	plate_away = false
	_cancel_press()
	_roach_t = 3.0
	mode = Mode.PLAY
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_tool("hand")
	hud.show_game()
	if intro:
		# первый заказ сразу, чтобы на подсказке был виден чек; время стоит, пока открыт экран
		_next_order()
		_update_hud()
		_show_intro()
		return
	get_tree().create_timer(1.0, false).timeout.connect(_next_order)
	_update_hud()


## Экран «как играть»: история и подписи к предметам. Игра на паузе до «Продолжить».
func _show_intro() -> void:
	_intro = true
	get_tree().paused = true
	ticket.position = ChefCfg.TICKET_RECT.position   # чек сразу на месте, без «выезда» на паузе
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var intro := ChefIntro.new()
	layer.add_child(intro)
	intro.done.connect(func():
		_intro = false
		layer.queue_free()
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN)


func _next_order() -> void:
	if mode != Mode.PLAY:
		return
	# бесконечно: этап сменяется после orders заказов, открывается новый продукт
	if stage_orders >= shift.orders:
		stage_orders = 0
		if shift_i + 1 < ChefCfg.SHIFTS.size():
			_next_stage()
		else:
			order_time = maxf(ChefCfg.ENDLESS_TIME_MIN, order_time * ChefCfg.ENDLESS_TIME_DECAY)
	stage_orders += 1
	order_n += 1
	var recipe: Array = ["bread"]
	var n := randi_range(shift.layers.x, shift.layers.y)
	var prev := ""
	for k in n:
		var pick: String = shift.fillings.pick_random()
		while pick == prev and shift.fillings.size() > 1:
			pick = shift.fillings.pick_random()
		recipe.append(pick)
		prev = pick
	recipe.append("bread")
	order = {"recipe": recipe, "time_left": order_time, "total": order_time}
	ticket.recipe = recipe
	ticket.done = plate.layers.size()
	ticket.number = order_n
	ticket.total = 0
	ticket.time_total = order_time
	ticket.time_left = order_time
	ticket.visible = true
	ticket._base = ChefCfg.TICKET_RECT.position
	ticket.position = ChefCfg.TICKET_RECT.position + Vector2(0, -480)
	ticket.create_tween().tween_property(ticket, "position", ChefCfg.TICKET_RECT.position, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_play("order")
	_update_hud()


## Новый этап: на лоток добавляется новый продукт.
func _next_stage() -> void:
	var before := _open_supplies()
	shift_i += 1
	shift = ChefCfg.SHIFTS[shift_i]
	order_time = shift.time
	for d in ChefCfg.SUPPLIES:
		if d.id in _open_supplies() and not d.id in before:
			_add_supply(d)
	var names: Array = []
	for f in shift.fillings:
		if not f in ChefCfg.SHIFTS[shift_i - 1].fillings:
			names.append(ChefCfg.ING[f].name)
	_popup(Vector2(560, 250), "%s! Новый продукт: %s" % [shift.name, ", ".join(names)], Color(0.7, 1, 0.7))
	_play("stage")


func _add_supply(d: Dictionary) -> void:
	if d.id == "patty_raw":
		var dish := Sprite2D.new()
		dish.texture = ChefCfg.tex("plate_clean.png")
		dish.scale = Vector2.ONE * ChefCfg.fit(dish.texture, ChefCfg.PATTY_DISH_W)
		dish.position = d.pos
		items.add_child(dish)
		items.move_child(dish, 1)
	if not d.get("stand", false) and _tray:
		_tray.open_x.append(d.pos.x)
		_tray.queue_redraw()
	var s := KitchenItems.Supply.new()
	items.add_child(s)
	s.setup(d)
	supplies.append(s)
	s.scale = Vector2.ZERO
	s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash(s.global_position, Color(0.5, 1, 0.5))


## Сорван заказ: страйк. После STRIKES — конец игры.
func _strike() -> void:
	fails += 1
	_update_hud()
	if fails >= ChefCfg.STRIKES:
		get_tree().create_timer(1.2, false).timeout.connect(_end_shift)


func _end_shift() -> void:
	if mode != Mode.PLAY:
		return
	mode = Mode.END
	_cancel_press()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	var record := score > best
	if record:
		best = score
	_save()
	hud.show_end_endless(served, shift_i + 1, score, best, record)


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ------------------------------------------------------------ цикл

## Какие запасы лежат на столе в текущей смене.
func _open_supplies() -> Array:
	var sh: Dictionary = shift if not shift.is_empty() else ChefCfg.SHIFTS[0]
	var ids := ["bread"]
	for f in sh.fillings:
		var raw := cook_key_for(f)
		ids.append(raw if raw != "" else f)
	return ids


## Грязь кухни 0..1: пятна, грязная тарелка, сгоревшее.
func dirt_level() -> float:
	var pts := 0.0
	for st in stains_layer.get_children():
		if not st.is_queued_for_deletion():
			pts += ChefCfg.DIRT_WEIGHT.get(st.kind, 1.0) * clampf(st.amount, 0.0, 1.0)
	if plate and not plate_away:
		pts += ChefCfg.DIRT_PLATE * plate.dirt
	return clampf(pts / ChefCfg.DIRT_MAX, 0.0, 1.0)


func is_table_dirty() -> bool:
	return dirt_level() >= ChefCfg.DIRTY_LEVEL


func next_needed() -> String:
	if order.is_empty() or plate_away or plate.is_dirty():
		return ""
	var i := plate.layers.size()
	return order.recipe[i] if i < order.recipe.size() else "bell"


func _process(delta: float) -> void:
	_tick_wash(delta)
	if _ring_t > 0.0 and mode == Mode.PLAY:
		_ring_t -= delta
		if _ring_t <= 0.0 and not order.is_empty() and not plate_away:
			_popup(bell.global_position + Vector2(-150, -90), "Заказ не готов\n(2 удара — поставщик)", Color(1, 0.9, 0.6))
	_shake = maxf(_shake - delta * 40.0, 0.0)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	if mode != Mode.PLAY or get_tree().paused:
		return
	var dirty := is_table_dirty()
	if not order.is_empty():
		order.time_left -= delta * (ChefCfg.DIRTY_PATIENCE if dirty else 1.0)
		ticket.time_left = order.time_left
		if order.time_left <= 0.0:
			_order_failed()
	# тараканы сами не заводятся — их приманивает грязь
	var d := dirt_level()
	_roach_t -= delta
	if _roach_t <= 0.0:
		_roach_t = lerpf(ChefCfg.ROACH_INTERVAL.x, ChefCfg.ROACH_INTERVAL.y, d) * randf_range(0.7, 1.3)
		var cap := ceili(d * ChefCfg.MAX_ROACHES)
		if d >= ChefCfg.ROACH_MIN_DIRT and get_tree().get_nodes_in_group("chef_roaches").size() < cap:
			_spawn_roach()
	_dirt_hud_t -= delta
	if _dirt_hud_t <= 0.0:
		_dirt_hud_t = 0.2
		hud.set_dirt(d, dirty)
	_update_hints()


## Подсказки: что сейчас нужно — светится; собранный заказ — звонок прыгает.
func _update_hints() -> void:
	var need := next_needed()
	var raw_key := cook_key_for(need)
	for s in supplies:
		s.glow = (s.id == need) or (raw_key != "" and s.id == raw_key and not pan.has_patty)
		s.hovered = hand.tool == "hand" and not _dragging and s.contains(_last_mouse)
	pan.glow = raw_key != "" and not pan.has_patty
	bell.lit = need == "bell"


## Какой сырой продукт жарить, чтобы получить слой id ("" — не жарится).
func cook_key_for(id: String) -> String:
	for k in ChefCfg.COOKABLE:
		if ChefCfg.COOKABLE[k].result == id:
			return k
	return ""


func _order_failed() -> void:
	_strike()
	mistakes += 1
	score = maxi(score - ChefCfg.TIMEOUT_PENALTY, 0)
	_popup(ChefCfg.TICKET_RECT.get_center(), "Время вышло!\n-%d" % ChefCfg.TIMEOUT_PENALTY, Color(1, 0.4, 0.3))
	if plate.layers.size() > 0:
		plate.clear_layers()
		plate.set_dirt(1.0)
	_drop_ticket()
	if fails < ChefCfg.STRIKES:
		get_tree().create_timer(1.5, false).timeout.connect(_next_order)


func _drop_ticket() -> void:
	order = {}
	var tw := ticket.create_tween()
	tw.tween_property(ticket, "position", ticket.position + Vector2(260, 0), 0.25)
	tw.tween_callback(func(): ticket.visible = false)
	_update_hud()


func _ruin(text: String, penalty: int = ChefCfg.RUIN_PENALTY) -> void:
	plate.clear_layers()
	plate.set_dirt(1.0)
	_spoil_t = 0.0
	mistakes += 1
	score = maxi(score - penalty, 0)
	ticket.done = 0
	ticket.error()
	_popup(plate.global_position, "%s\n-%d" % [text, penalty], Color(1, 0.4, 0.3))
	_flash(plate.global_position, Color(1, 0.2, 0.15))
	_play("ruin")
	_update_hud()


# ------------------------------------------------------------ рука: взять, перетащить, положить

func set_tool(t: String) -> void:
	_cancel_press()
	hand.set_tool(t)
	hud.set_tool(t)


## Тап по столу текущей рукой (нажал и отпустил на месте). Им пользуется и тестовый бот.
func click(p: Vector2) -> void:
	press(p)
	release(p)


func press(p: Vector2) -> void:
	if mode != Mode.PLAY:
		return
	_last_mouse = p
	hand.aim(p)
	match hand.tool:
		"swatter":
			hand.swing()
		"sponge":
			scrub(p, 0.0)
		"hand":
			_hand_press(p)


func release(p: Vector2) -> void:
	if _press_src == null:
		return
	var src = _press_src
	_press_src = null
	if _dragging:
		_dragging = false
		var piece := hand.drop()
		fx.add_child(piece)
		piece.global_position = p
		_drop_piece(src, piece, p)
	else:
		_tap_source(src)


func drag(p: Vector2) -> void:
	if _press_src != null and not _dragging and p.distance_to(_press_pos) > DRAG_START:
		_start_drag()


func _cancel_press() -> void:
	_press_src = null
	if _dragging and hand:
		_dragging = false
		var piece := hand.drop()
		if piece:
			piece.queue_free()
		if pan and pan.has_patty:
			pan.show_food(true)


func _hand_press(p: Vector2) -> void:
	_carry_roach = null
	# продукт берём, даже если на нём сидит таракан — он уедет в сэндвич вместе с продуктом
	for s in supplies:
		if s.contains(p) and s.can_take():
			for r in get_tree().get_nodes_in_group("chef_roaches"):
				if r.is_sitting_on(s):
					_carry_roach = r
			_press_src = s
			_press_pos = p
			return
	# таракан под пальцами — убегает
	for r in get_tree().get_nodes_in_group("chef_roaches"):
		if r.is_alive() and r.global_position.distance_to(p) <= ChefCfg.SCARE_RADIUS + r.radius:
			hand.tap()
			r.flee(p)
			return
	if bell.contains(p):
		hand.aim(bell.global_position + Vector2(0, -6))
		hand.punch(_bell_hit)
		return
	if pan.contains(p) and pan.has_patty:
		match pan.state():
			"raw":
				hand.tap()
				_popup(pan.global_position, "Ещё сырое!", Color(1, 0.9, 0.6))
			"burnt":
				hand.tap()
				_toss_burnt()
			"cooked":
				_press_src = pan
				_press_pos = p
		return
	for s in supplies:
		if s.contains(p):
			if not s.can_take():
				hand.tap()
				_popup(s.global_position + Vector2(0, 70), "Закончилось —\nждём подвоз", Color(1, 0.6, 0.4))
				return
			_press_src = s
			_press_pos = p
			return


func _piece_for(src) -> Node2D:
	if src == pan:
		var s := Sprite2D.new()
		s.texture = ChefCfg.tex(ChefCfg.ING[pan.result()].tex)
		s.scale = Vector2.ONE * ChefCfg.fit(s.texture, 90)
		return s
	return src.make_piece(minf(src.w, 90.0))


func _src_id(src) -> String:
	return pan.result() if src == pan else src.id


func _start_drag() -> void:
	_dragging = true
	hand.aim(_lift(_last_mouse))
	if _press_src == pan:
		pan.show_food(false)
	else:
		_press_src.take()
	hand.grab(_piece_for(_press_src))


## Тап по продукту: он сам летит туда, где нужен (на тарелку или сковороду).
func _tap_source(src) -> void:
	hand.tap()
	var piece := _piece_for(src)
	fx.add_child(piece)
	piece.global_position = src.global_position
	var target: Vector2 = pan.global_position if ChefCfg.COOKABLE.has(_src_id(src)) else plate.global_position + plate.top_offset()
	if src == pan:
		pan.show_food(false)
	else:
		src.take()
	var tw := piece.create_tween()
	tw.tween_property(piece, "global_position", target, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _drop_piece(src, piece, target))


## Продукт отпущен в точке p — решаем, что с ним будет.
func _drop_piece(src, piece: Node2D, p: Vector2) -> void:
	var id := _src_id(src)
	if ChefCfg.COOKABLE.has(id):
		if pan.contains(p) and not pan.has_patty:
			piece.queue_free()
			pan.put_raw(id)
			_flash(pan.global_position, Color(0.4, 1, 0.4))
			_play("sizzle")
		else:
			if pan.has_patty:
				_popup(pan.global_position, "Сковорода занята", Color(1, 0.9, 0.6))
			_bounce_back(src, piece)
		return
	if not plate.contains(p):
		_bounce_back(src, piece)
		return
	var why := ""
	if plate_away:
		why = "Тарелку унесли"
	elif order.is_empty():
		why = "Заказа пока нет"
	elif plate.is_dirty():
		why = "Тарелка грязная —\nвозьми губку"
	elif plate.layers.size() >= order.recipe.size():
		why = "Готово — жми звонок!"
	if why != "":
		_popup(plate.global_position, why, Color(1, 0.9, 0.6))
		_bounce_back(src, piece)
		return
	if order.recipe[plate.layers.size()] != id:
		# не тот продукт — красная вспышка, список дёргается, продукт отскакивает назад
		mistakes += 1
		score = maxi(score - ChefCfg.WRONG_PENALTY, 0)
		ticket.error()
		_flash(plate.global_position, Color(1, 0.2, 0.15))
		_popup(plate.global_position + Vector2(0, -60), "Не то! Нужно: %s" % ChefCfg.ING[order.recipe[plate.layers.size()]].name, Color(1, 0.5, 0.4))
		_play("wrong")
		_bounce_back(src, piece)
		_update_hud()
		return
	piece.queue_free()
	if src == pan:
		pan.clear()
	plate.add_layer(id)
	if _carry_roach and is_instance_valid(_carry_roach) and _carry_roach.is_alive() and _carry_roach.is_sitting_on(src):
		_carry_roach.ride_plate(plate)
	_carry_roach = null
	ticket.done = plate.layers.size()
	_flash(plate.global_position + plate.top_offset(), Color(0.35, 1, 0.4))
	_play("place")


func _bounce_back(src, piece: Node2D) -> void:
	var home: Vector2 = src.global_position
	var tw := piece.create_tween()
	tw.tween_property(piece, "global_position", home + (piece.global_position - home) * 0.15, 0.08)
	tw.tween_property(piece, "global_position", home, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		piece.queue_free()
		if src == pan:
			if pan.has_patty:
				pan.show_food(true)
		else:
			src.give_back())


## Сгоревшее — в мусор: летит со стола и исчезает, жарить заново.
func _toss_burnt() -> void:
	var s := Sprite2D.new()
	s.texture = pan.cooked_s.texture
	s.scale = pan.cooked_s.scale
	s.modulate = Color(0.18, 0.15, 0.13)
	fx.add_child(s)
	s.global_position = pan.global_position
	pan.clear()
	mistakes += 1
	score = maxi(score - ChefCfg.BURNT_PENALTY, 0)
	_popup(pan.global_position + Vector2(0, -60), "В мусор! -%d" % ChefCfg.BURNT_PENALTY, Color(1, 0.4, 0.3))
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "global_position", Vector2(-60, ChefCfg.VIEW.y + 40), 0.5).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "rotation", -4.0, 0.5)
	tw.chain().tween_callback(s.queue_free)
	var st := KitchenItems.Stain.new()   # гарь у плиты — тоже грязь
	st.setup("grease", ChefCfg.STOVE_POS + Vector2(randf_range(60, 120), randf_range(60, 110)))
	st.kind = "burnt"
	stains_layer.add_child(st)
	_update_hud()


## Кулак ударил по звонку: звонок сплющивается, экран вздрагивает, звёздочка удара.
func _bell_hit() -> void:
	bell.press()
	_shake = 12.0
	_impact(bell.global_position + Vector2(0, -10), 46.0)
	_popup(bell.global_position + Vector2(-150, -40), "ДЗЫНЬ!", Color(1, 1, 0.7))
	_play("bell")
	# второй удар подряд — вызов поставщика
	if _ring_t > 0.0:
		_ring_t = 0.0
		_call_restock()
		return
	# заказ собран — отдаём сразу; иначе ждём, не будет ли второго удара
	if not order.is_empty() and not plate_away and plate.layers.size() >= order.recipe.size():
		_ring()
	else:
		_ring_t = ChefCfg.DOUBLE_RING


func _ring() -> void:
	if order.is_empty() or plate_away:
		return
	if plate.layers.size() < order.recipe.size():
		_popup(bell.global_position + Vector2(0, -120), "Заказ не готов", Color(1, 0.9, 0.6))
		return
	if _roach_on(plate):
		# отдал с тараканом: заказ уносят, а за кадром посетителя тошнит
		mistakes += 1
		_drop_ticket()
		_serve_plate(true)
		_add_stains()
		return
	var k: float = clampf(order.time_left / order.total, 0.0, 1.0)
	var gained: int = ChefCfg.ORDER_BASE + ChefCfg.ORDER_PER_LAYER * order.recipe.size() + int(ChefCfg.ORDER_TIME_BONUS * k)
	score += gained
	served += 1
	_popup(plate.global_position + Vector2(0, -130), "Заказ отдан!\n+%d" % gained, Color(0.6, 1, 0.6))
	_flash(bell.global_position, Color(1, 1, 0.6))
	_drop_ticket()
	_serve_plate()
	_add_stains()


## Тарелку уносит рука официанта и через пару секунд возвращает грязную.
func _serve_plate(with_roach := false) -> void:
	plate_away = true
	_served_roach = with_roach
	_sup_request("serve")


# ------------------------------------------------------------ рука поставщика

func _call_restock() -> void:
	var need := false
	for s in supplies:
		if not s.is_sauce() and s.stock < ChefCfg.STOCK_MAX:
			need = true
	if not need:
		_popup(bell.global_position + Vector2(-150, -90), "Всё и так есть", Color(1, 0.9, 0.6))
		return
	if "restock" in _sup_queue:
		return
	_popup(bell.global_position + Vector2(-150, -90), "Поставщик, сюда!", Color(0.7, 0.9, 1))
	_sup_request("restock")


func _sup_request(job: String) -> void:
	_sup_queue.append(job)
	if not _sup_busy:
		_sup_next()


func _sup_next() -> void:
	if _sup_queue.is_empty() or mode != Mode.PLAY:
		_sup_busy = false
		return
	_sup_busy = true
	var job: String = _sup_queue.pop_front()
	if job == "serve":
		_sup_serve()
	else:
		_sup_restock()


func _off_top(p: Vector2) -> Vector2:
	return Vector2(p.x, -260)


func _sup_serve() -> void:
	var at := ChefCfg.PLATE_POS
	supplier.point = _off_top(at)
	supplier.visible = true
	var tw := supplier.create_tween()
	tw.tween_property(supplier, "point", at, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		supplier.carry = plate
		supplier.carry_off = Vector2.ZERO)
	tw.tween_interval(0.1)
	tw.tween_property(supplier, "point", _off_top(at), 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		supplier.visible = false   # пока тарелки нет — руки на экране нет
		for r in get_tree().get_nodes_in_group("chef_roaches"):
			if r.spot == plate:
				r.queue_free()
		plate.clear_layers()
		plate.set_dirt(1.0))
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if _served_roach:
			_served_roach = false
			_play("vomit")
			score = maxi(score - ChefCfg.VOMIT_PENALTY, 0)
			_shake = 8.0
			_popup(Vector2(640, 120), "Посетителя стошнило! Таракан в сэндвиче -%d" % ChefCfg.VOMIT_PENALTY, Color(0.6, 1, 0.3))
			_update_hud())
	tw.tween_interval(0.7)
	tw.tween_callback(func(): supplier.visible = true)
	tw.tween_property(supplier, "point", at, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		supplier.carry = null
		plate.position = ChefCfg.PLATE_POS
		plate_away = false
		_next_order())
	tw.tween_interval(0.1)
	tw.tween_property(supplier, "point", _off_top(at), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		supplier.visible = false
		_sup_next())


## Поставщик обходит все кончившиеся продукты и докладывает их.
func _sup_restock() -> void:
	var todo: Array = supplies.filter(func(s): return not s.is_sauce() and s.stock < ChefCfg.STOCK_MAX)
	todo.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	if todo.is_empty():
		_sup_next()
		return
	supplier.point = _off_top(todo[0].global_position)
	supplier.visible = true
	var tw := supplier.create_tween()
	for s in todo:
		tw.tween_property(supplier, "point", s.global_position + Vector2(0, -10), 0.35).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func():
			s.refill()
			_play("place"))
		tw.tween_interval(0.12)
	tw.tween_property(supplier, "point", _off_top(supplier.point if todo.is_empty() else todo[-1].global_position), 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		supplier.visible = false
		_sup_next())


## После заказа на столе остаются крошки, кетчуп, жир.
func _add_stains() -> void:
	var n := randi_range(ChefCfg.STAINS_PER_ORDER.x, ChefCfg.STAINS_PER_ORDER.y)
	for i in n:
		var st := KitchenItems.Stain.new()
		var p := Vector2.ZERO
		for k in 20:   # не на тарелку, плиту и прочие препятствия
			p = Vector2(randf_range(60, 1040), randf_range(230, ChefCfg.TABLE_EDGE - 40))
			if not blocked_at(p, 30.0):
				break
		st.setup(["crumbs", "ketchup", "grease"].pick_random(), p)
		stains_layer.add_child(st)
	_update_hud()


## Тереть губкой. dist — сколько пикселей прошла губка. Моет тарелку и пятна на столе.
func scrub(p: Vector2, dist: float) -> void:
	if not plate_away and plate.is_dirty() and plate.contains(p):
		hand.scrub()
		_wash_sound()
		plate.set_dirt(plate.dirt - dist / ChefCfg.WASH_DIST)
		if randf() < 0.35:
			_bubble(p)
		if not plate.is_dirty():
			_popup(plate.global_position, "Чисто!", Color(0.7, 0.95, 1))
			_flash(plate.global_position, Color(0.6, 0.9, 1))
			_play("clean")
		return
	for st in stains_layer.get_children():
		if st.amount > 0.0 and st.contains(p):
			hand.scrub()
			_wash_sound()
			if randf() < 0.3:
				_bubble(p)
			if st.wash(dist):
				st.queue_free()
				_update_hud.call_deferred()
			return


# ------------------------------------------------------------ препятствия (плита, чек)

func _grown(r: Rect2, pad: float) -> Rect2:
	return r.grow(pad)


func blocked_at(p: Vector2, pad: float) -> bool:
	for r in obstacles:
		if _grown(r, pad).has_point(p):
			return true
	return false


## Выталкивает точку из препятствия к ближайшему краю.
func push_out(p: Vector2, pad: float) -> Vector2:
	for r in obstacles:
		var g := _grown(r, pad)
		if g.has_point(p):
			var dl := p.x - g.position.x
			var dr := g.end.x - p.x
			var dt := p.y - g.position.y
			var db := g.end.y - p.y
			var m := minf(minf(dl, dr), minf(dt, db))
			if m == dl: p.x = g.position.x - 0.5
			elif m == dr: p.x = g.end.x + 0.5
			elif m == dt: p.y = g.position.y - 0.5
			else: p.y = g.end.y + 0.5
	return p


func _seg_hits(a: Vector2, b: Vector2, g: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var ps := [-d.x, d.x, -d.y, d.y]
	var qs := [a.x - g.position.x, g.end.x - a.x, a.y - g.position.y, g.end.y - a.y]
	for i in 4:
		var p: float = ps[i]
		var q: float = qs[i]
		if absf(p) < 0.0001:
			if q < 0.0:
				return false
		else:
			var r := q / p
			if p < 0.0:
				t0 = maxf(t0, r)
			else:
				t1 = minf(t1, r)
			if t0 > t1:
				return false
	return true


func path_clear(a: Vector2, b: Vector2, pad: float) -> bool:
	for r in obstacles:
		if _seg_hits(a, b, _grown(r, pad)):
			return false
	return true


## Куда идти сейчас, чтобы попасть в to в обход препятствий: сама цель или угол препятствия.
func route(from: Vector2, to: Vector2, pad: float) -> Vector2:
	# с запасом 0.85: таракан, прижатый к краю препятствия, не считается «внутри»
	if path_clear(from, to, pad * 0.85):
		return to
	var best := to
	var bd := INF
	for r in obstacles:
		var g := _grown(r, pad + 16.0)
		for c in [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]:
			if blocked_at(c, pad) or not path_clear(from, c, pad * 0.85):
				continue
			if from.distance_to(c) < 20.0:   # уже стоим в этом углу — он не цель, иначе застрянем
				continue
			var dd: float = from.distance_to(c) + c.distance_to(to)
			if dd < bd:
				bd = dd
				best = c
	return best


# ------------------------------------------------------------ тараканы

func _spawn_roach() -> void:
	var r := ChefRoach.new()
	roach_layer.add_child(r)
	var m := 40.0
	var p: Vector2
	for i in 30:   # не появляемся за чеком и плитой
		match randi() % 3:
			0: p = Vector2(-m, randf_range(60, ChefCfg.TABLE_EDGE - 60))
			1: p = Vector2(ChefCfg.VIEW.x + m, randf_range(60, ChefCfg.TABLE_EDGE - 60))
			_: p = Vector2(randf_range(60, ChefCfg.VIEW.x - 60), -m)
		if not blocked_at(p + (ChefCfg.VIEW * 0.5 - p).normalized() * 70.0, 30.0) and not blocked_at(p, 10.0):
			break
	r.setup(shift.roaches.pick_random(), p, self)


## Куда сесть: продукт или сэндвич (сэндвич привлекает сильнее).
func pick_spot(_from: Vector2) -> Dictionary:
	var opts: Array = []
	for s in supplies:
		if not s.is_sauce() and s.stock > 0:   # воровать есть что
			opts.append({"node": s, "w": 1.0, "r": s.radius * 0.45})
	for st in stains_layer.get_children():   # пятна приманивают
		if not st.is_queued_for_deletion():
			opts.append({"node": st, "w": 0.8, "r": 10.0})
	var total := 0.0
	for o in opts:
		total += o.w
	var x := randf() * total
	for o in opts:
		x -= o.w
		if x <= 0.0:
			return {"node": o.node, "offset": Vector2.from_angle(randf() * TAU) * randf() * o.r}
	return {}


func exit_point(from: Vector2, dir: Vector2) -> Vector2:
	if dir.length() < 0.1:
		dir = Vector2.UP
	dir = dir.normalized()
	if dir.y > 0.3:
		dir.y = -dir.y   # вниз со стола не бегут — там повар
	return from + dir * 1600.0


func _roach_on(n: Node) -> bool:
	for r in get_tree().get_nodes_in_group("chef_roaches"):
		if r.is_sitting_on(n):
			return true
	return false


func _on_slam(p: Vector2, r: float) -> void:
	if mode != Mode.PLAY:
		return
	_shake = 6.0
	_play("slap")
	_impact(p, r)
	if supplier.hit_test(p, r):
		supplier.flinch()
		_play("supplier_ouch")
		_popup(p + Vector2(0, -60), "Ай! Я же свой!", Color(1, 0.7, 0.5))
	var killed := 0
	var returned := 0
	for c in get_tree().get_nodes_in_group("chef_roaches"):
		if c.hit_test(p, r):
			var loot = c.carrying
			Sound.roach_hit(self)
			if c.damage():
				killed += 1
				score += int(c.data.score)
				_roach_stain(c.global_position)
				if loot and is_instance_valid(loot):
					# прибил воришку — продукт летит обратно
					returned += 1
					score += ChefCfg.STOLEN_BACK
					_fly_back(c.global_position, loot)
		elif c.global_position.distance_to(p) < 160.0:
			c.flee(p)
	if killed > 0:
		var txt := "+%d" % (killed * 10)
		if returned > 0:
			txt += "\nВернул продукт!"
		_popup(p, txt, Color(1, 0.95, 0.4))
		_play("splat")
	_update_hud()


## Таракан унёс продукт со стола.
func on_stolen(sup) -> void:
	var name: String = ChefCfg.ING[sup.id].name if ChefCfg.ING.has(sup.id) else {"patty_raw": "Котлету", "bacon_raw": "Бекон", "eggs": "Яйцо"}.get(sup.id, "продукт")
	_popup(sup.global_position + Vector2(0, 80), "Таракан утащил: %s" % name, Color(1, 0.55, 0.35))
	_play("stolen")


## Раздавленный таракан оставляет пятно — оно приманивает новых.
func _roach_stain(at: Vector2) -> void:
	var st := KitchenItems.Stain.new()
	st.setup("roach", at)
	stains_layer.add_child(st)


func _fly_back(from: Vector2, sup) -> void:
	var piece: Sprite2D = sup.make_piece(50)
	fx.add_child(piece)
	piece.global_position = from
	var tw := piece.create_tween()
	tw.tween_property(piece, "global_position", sup.global_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		piece.queue_free()
		sup.give_back())


# ------------------------------------------------------------ ввод

func _unhandled_input(e: InputEvent) -> void:
	if mode != Mode.PLAY or _intro:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1: set_tool("hand")
			KEY_2: set_tool("sponge")
			KEY_3: set_tool("swatter")
			KEY_ESCAPE: _set_paused(not get_tree().paused)
			KEY_TAB:
				if not get_tree().paused:
					hud.ring.open(_last_mouse)
	if e is InputEventKey and not e.pressed and e.keycode == KEY_TAB and hud.ring.visible:
		hud.ring.close(true)
	if get_tree().paused:
		if e is InputEventMouseButton and e.pressed:
			_set_paused(false)
		return
	if e is InputEventMouseMotion:
		var d: float = e.position.distance_to(_last_mouse)
		_last_mouse = e.position
		hand.aim(_lift(e.position))
		if _mouse_down:
			if hand.tool == "sponge":
				scrub(e.position, d)
			drag(e.position)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = e.pressed
		_last_mouse = e.position
		if e.pressed:
			press(e.position)
		else:
			release(_lift(e.position))


## Палец закрывает продукт — при перетаскивании пальцем держим его чуть выше точки касания.
func _lift(p: Vector2) -> Vector2:
	return p + Vector2(0, -TOUCH_LIFT) if _touch and _dragging else p


func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_touch = true
	elif e is InputEventMouse and e.device != InputEvent.DEVICE_ID_EMULATION:
		_touch = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == Mode.PLAY and not _intro:
		_set_paused(true)


func _set_paused(v: bool) -> void:
	get_tree().paused = v
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if v else Input.MOUSE_MODE_HIDDEN
	hud.show_pause(v)


# ------------------------------------------------------------ эффекты

func _update_hud() -> void:
	hud.set_info(score, shift.get("name", ""), order_n, fails, mistakes, is_table_dirty())
	hud.set_dirt(dirt_level(), is_table_dirty())


func _popup(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.size = Vector2(340, 80)
	l.position = (at - Vector2(170, 40)).clamp(Vector2(0, 0), ChefCfg.VIEW - Vector2(340, 80))
	top_fx.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


## Короткая вспышка-кольцо: зелёная — верно, красная — ошибка.
func _flash(at: Vector2, c: Color) -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.from_angle(TAU * i / 32.0) * 60.0)
	ring.points = pts
	ring.width = 8.0
	ring.default_color = c
	ring.position = at
	ring.scale = Vector2.ONE * 0.4
	fx.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2.ONE * 1.4, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(ring.queue_free)


func _impact(at: Vector2, r: float) -> void:
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 28:
		pts.append(Vector2.from_angle(TAU * i / 28.0) * r * (1.25 if i % 2 == 0 else 0.75))
	star.polygon = pts
	star.color = Color(1, 1, 1, 0.85)
	star.position = at
	star.scale = Vector2.ONE * 0.5
	fx.add_child(star)
	var tw := star.create_tween().set_parallel()
	tw.tween_property(star, "scale", Vector2.ONE * 1.1, 0.12)
	tw.tween_property(star, "modulate:a", 0.0, 0.18).set_delay(0.06)
	tw.chain().tween_callback(star.queue_free)


func _splat(at: Vector2) -> void:
	var sp := Sprite2D.new()
	sp.texture = Cfg.tex("splat.png")
	sp.position = at
	sp.rotation = randf() * TAU
	sp.scale = Vector2.ONE * 0.6
	sp.modulate = Color(1, 1, 1, 0.7)
	fx.add_child(sp)
	fx.move_child(sp, 0)
	var tw := sp.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(sp, "modulate:a", 0.0, 1.5)
	tw.tween_callback(sp.queue_free)


func _bubble(at: Vector2) -> void:
	var b := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(Vector2.from_angle(TAU * i / 12.0) * randf_range(6, 12))
	b.polygon = pts
	b.color = Color(1, 1, 1, 0.75)
	b.position = at + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	fx.add_child(b)
	var tw := b.create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2.ONE * 1.6, 0.6)
	tw.tween_property(b, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(b.queue_free)


## Звуки необязательны: assets/sounds/<имя>.ogg|wav|mp3.
## Имена: order, place, wrong, ruin, bell, sizzle, clean, slap, splat.
var _sfx := {}
var _players: Array[AudioStreamPlayer] = []
var _wash: AudioStreamPlayer
var _wash_t := 0.0


func _sound(sound: String) -> AudioStream:
	if not _sfx.has(sound):
		_sfx[sound] = null
		for ext in ["ogg", "wav", "mp3"]:
			var p := "res://assets/sounds/%s.%s" % [sound, ext]
			if ResourceLoader.exists(p):
				_sfx[sound] = load(p)
				break
	return _sfx[sound]


## Короткий звук; несколько могут звучать одновременно.
func _play(sound: String) -> void:
	var st := _sound(sound)
	if st == null:
		return
	if _players.is_empty():
		for i in 5:
			_players.append(Sound.sfx_player(self))
	for p in _players:
		if not p.playing:
			p.stream = st
			p.pitch_scale = randf_range(0.95, 1.05) if sound == "place" else 1.0
			p.play()
			return
	_players[0].stream = st
	_players[0].play()


## Звук мытья (тарелки и стола): играет, пока трёшь губкой, и затихает, когда перестал.
func _wash_sound() -> void:
	if _wash == null:
		_wash = Sound.sfx_player(self)
		_wash.stream = _sound("wash")
	_wash_t = 0.25
	_wash.volume_db = 0.0
	if _wash.stream and not _wash.playing:
		_wash.play(randf() * 4.0)


func _tick_wash(delta: float) -> void:
	if _wash and _wash.playing:
		_wash_t -= delta
		if _wash_t <= 0.0:
			_wash.volume_db -= delta * 120.0   # быстро затухает
			if _wash.volume_db < -40.0:
				_wash.stop()


# ------------------------------------------------------------ сохранение

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		best = cf.get_value("chef", "best", 0)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("chef", "best", best)
	cf.save(SAVE)
