class_name ChefHud
extends CanvasLayer
## Интерфейс повара: очки, заказы, кнопка смены руки, кольцо выбора, меню смен и итоги.

signal shift_chosen(index: int)
signal tool_chosen(tool: String)
signal menu_pressed
signal pause_pressed
signal resume_pressed

var score_l: Label
var info_l: Label
var err_l: Label
var dirt_l: Label
var dirt_bar: DirtBar
var tool_btn: Button
var ring: ToolRing
var overlay: ColorRect
var box: VBoxContainer
var pause_l: Label
var pause_btn: Button
var pause_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# компактная панель слева снизу
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 588)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.72)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	# шрифты крупнее обычного: на телефоне экран 1280×720 сжимается примерно вдвое
	score_l = _label(col, 30, Vector2.ZERO)
	info_l = _label(col, 23, Vector2.ZERO)
	err_l = _label(col, 23, Vector2.ZERO)
	# счётчик грязи кухни: полоска над панелью
	dirt_bar = DirtBar.new()
	dirt_bar.position = Vector2(18, 540)
	add_child(dirt_bar)
	dirt_l = _label(self, 22, Vector2(250, 532))
	dirt_l.add_theme_color_override("font_color", Color(1, 0.6, 0.3))
	# кнопка смены руки (на телефоне — главный способ, на ПК можно Tab или 1/2/3)
	tool_btn = Button.new()
	tool_btn.position = Vector2(1140, 596)
	tool_btn.size = Vector2(122, 106)
	tool_btn.focus_mode = Control.FOCUS_NONE
	tool_btn.expand_icon = true
	tool_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tool_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tool_btn.add_theme_font_size_override("font_size", 20)
	tool_btn.pressed.connect(func(): ring.open(tool_btn.position + Vector2(-110, -120), true))
	add_child(tool_btn)
	ring = ToolRing.new()
	add_child(ring)
	ring.chosen.connect(func(t): tool_chosen.emit(t))

	# кнопка паузы — на телефоне нет клавиши Esc
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.position = Vector2(1056, 628)
	pause_btn.size = Vector2(74, 74)
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.add_theme_font_size_override("font_size", 34)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(pause_btn)

	pause_l = _label(self, 56, Vector2(0, 0))
	pause_l.size = ChefCfg.VIEW
	pause_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_l.text = ""
	pause_l.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = ChefCfg.VIEW
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_l.add_child(dim)
	pause_box = VBoxContainer.new()
	pause_box.position = Vector2(440, 220)
	pause_box.size = Vector2(400, 280)
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 22)
	pause_l.add_child(pause_box)
	var pt := _label(pause_box, 64, Vector2.ZERO)
	pt.text = "Пауза"
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for pair in [["Продолжить", func(): resume_pressed.emit(), Color(0.25, 0.62, 0.25)], ["В меню", func(): menu_pressed.emit(), Color(0.78, 0.27, 0.15)]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(400, 76)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 34)
		b.add_theme_color_override("font_color", Color.WHITE)
		for st in ["normal", "hover", "pressed"]:
			var c: Color = pair[2]
			var bs := StyleBoxFlat.new()
			bs.bg_color = c.lightened(0.12) if st == "hover" else (c.darkened(0.2) if st == "pressed" else c)
			bs.border_color = Color(0.08, 0.05, 0.02)
			bs.set_border_width_all(4)
			bs.set_corner_radius_all(16)
			b.add_theme_stylebox_override(st, bs)
		b.pressed.connect(pair[1])
		pause_box.add_child(b)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)


func _label(parent: Node, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _clear_box() -> void:
	for c in box.get_children():
		c.queue_free()


func _title(text: String, size := 56) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	box.add_child(l)


func _button(text: String, cb: Callable, enabled := true) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(380, 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	box.add_child(b)


## Выбор смены. stars — массив звёзд по сменам, unlocked — сколько смен открыто.
func show_shifts(stars: Array, unlocked: int) -> void:
	_clear_box()
	overlay.visible = true
	tool_btn.visible = false
	pause_btn.visible = false
	_title("Повар против тараканов", 46)
	_title("Собирай сэндвичи по заказу, жарь, бей кулаком по звонку, мой тарелки.\nТараканы сами не заводятся — их приманивает грязь: пятна, крошки, гарь, немытая тарелка. Чем грязнее кухня (счётчик слева внизу), тем больше тараканов. Они воруют продукты — прибей воришку, и продукт вернётся.\nСменить руку: Tab, 1/2/3 или кнопка справа внизу.", 18)
	# смены — сеткой в две колонки, чтобы все 10 влезли
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for i in ChefCfg.SHIFTS.size():
		var st := "★".repeat(stars[i]) + "☆".repeat(3 - stars[i])
		var text: String = "%s   %s" % [ChefCfg.SHIFTS[i].name, st] if i < unlocked else "%s   🔒" % ChefCfg.SHIFTS[i].name
		var idx := i
		var b := Button.new()
		b.text = text
		b.disabled = i >= unlocked
		b.custom_minimum_size = Vector2(300, 46)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(func(): shift_chosen.emit(idx))
		grid.add_child(b)
	_button("В меню", func(): menu_pressed.emit())


func show_game() -> void:
	overlay.visible = false
	tool_btn.visible = true
	pause_btn.visible = true
	pause_l.visible = false


func show_pause(v: bool) -> void:
	pause_l.visible = v
	pause_btn.visible = not v and not overlay.visible


## Старт бесконечного режима.
func show_start(best: int) -> void:
	_clear_box()
	overlay.visible = true
	tool_btn.visible = false
	pause_btn.visible = false
	_title("Повар против тараканов", 50)
	_title("Заказы идут без конца. Собирай сэндвичи, жарь, бей кулаком по звонку, мой тарелки.\nКаждые несколько заказов на лотке появляется новый продукт, а время на заказ сокращается.\nПродукты сами не пополняются: ударь по звонку дважды — придёт поставщик и доложит.\nТараканов приманивает грязь — держи кухню в чистоте, бей воришек.\n%d сорванных заказа — смена окончена.\nСменить руку: Tab, 1/2/3 или кнопка справа внизу." % ChefCfg.STRIKES, 19)
	if best > 0:
		_title("Рекорд: %d" % best, 26)
	_button("Играть", func(): shift_chosen.emit(0))
	_button("В меню", func(): menu_pressed.emit())


func show_end_endless(served: int, stage: int, score: int, best: int, record: bool) -> void:
	_clear_box()
	overlay.visible = true
	tool_btn.visible = false
	pause_btn.visible = false
	_title("Смена окончена", 54)
	_title("Отдано заказов: %d\nДошёл до этапа: %d\nОчки: %d\n%s" % [served, stage, score, "Новый рекорд!" if record else "Рекорд: %d" % best], 26)
	_button("Ещё раз", func(): shift_chosen.emit(0))
	_button("В меню", func(): menu_pressed.emit())


func show_end(shift_i: int, served: int, total: int, score: int, stars: int, has_next: bool) -> void:
	_clear_box()
	overlay.visible = true
	tool_btn.visible = false
	pause_btn.visible = false
	_title("%s окончена" % ChefCfg.SHIFTS[shift_i].name)
	_title("★".repeat(stars) + "☆".repeat(3 - stars), 64)
	_title("Отдано заказов: %d из %d\nОчки: %d" % [served, total, score], 26)
	if has_next and stars > 0:
		_button("Следующая смена", func(): shift_chosen.emit(shift_i + 1))
	_button("Ещё раз", func(): shift_chosen.emit(shift_i))
	_button("Выбор смены", func(): menu_pressed.emit())


func set_info(score: int, stage_name: String, order: int, strikes: int, mistakes: int, dirty: bool) -> void:
	score_l.text = "Очки: %d" % score
	info_l.text = "%s • Заказ %d" % [stage_name, order]
	# без значков ✖/○: в браузерном шрифте их нет, на телефоне были квадратики
	err_l.text = "Сорвано: %d из %d   Ошибок: %d" % [strikes, ChefCfg.STRIKES, mistakes]
	pass


func set_dirt(level: float, dirty: bool) -> void:
	dirt_bar.level = level
	dirt_bar.queue_redraw()
	dirt_l.text = "Грязно! Тараканы лезут — бери губку" if dirty else ""


func set_tool(t: String) -> void:
	tool_btn.text = ChefCfg.TOOL_NAMES[t]
	tool_btn.icon = ToolRing.icon_for(t)


## Кольцо выбора руки: Tab — открыть у курсора, навести, отпустить Tab.
## На телефоне открывается кнопкой, выбор — тапом по значку.
class ToolRing extends Control:
	signal chosen(tool: String)
	const R := 105.0
	var center := Vector2.ZERO
	var hover := -1
	var tap_mode := false
	static var _icons := {}

	static func icon_for(t: String) -> Texture2D:
		if _icons.has(t):
			return _icons[t]
		var d: Dictionary = ChefCfg.HANDS[t]
		var tx := ChefCfg.tex(d.tex)
		var at := AtlasTexture.new()
		at.atlas = tx
		var s := 300.0
		at.region = Rect2(d.head.x - s / 2, maxf(0.0, d.head.y - 60.0), s, s)
		_icons[t] = at
		return at

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func open(at: Vector2, by_tap := false) -> void:
		center = at.clamp(Vector2(R + 50, R + 50), ChefCfg.VIEW - Vector2(R + 50, R + 50))
		tap_mode = by_tap
		hover = -1
		# явный размер на весь экран: иначе на телефоне кольцо не ловит касания
		position = Vector2.ZERO
		size = ChefCfg.VIEW
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()

	func close(apply: bool) -> void:
		if apply and hover >= 0:
			chosen.emit(ChefCfg.TOOLS[hover])
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _slot_pos(i: int) -> Vector2:
		var a := -PI / 2 + TAU * i / ChefCfg.TOOLS.size()
		return center + Vector2.from_angle(a) * R

	func _hover_at(p: Vector2) -> int:
		if p.distance_to(center) < 30.0:
			return -1
		var best := -1
		var bd := INF
		for i in ChefCfg.TOOLS.size():
			var d := p.distance_to(_slot_pos(i))
			if d < bd:
				bd = d
				best = i
		return best

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			hover = _hover_at(e.position)
			queue_redraw()
		elif e is InputEventMouseButton and e.pressed:
			hover = _hover_at(e.position)
			close(true)
			accept_event()

	func _draw() -> void:
		draw_circle(center, R + 62, Color(0, 0, 0, 0.45))
		var font := ThemeDB.fallback_font
		for i in ChefCfg.TOOLS.size():
			var t: String = ChefCfg.TOOLS[i]
			var p := _slot_pos(i)
			draw_circle(p, 54, Color(1, 0.85, 0.3, 0.95) if i == hover else Color(0.95, 0.93, 0.88, 0.95))
			var ic := icon_for(t)
			draw_texture_rect(ic, Rect2(p - Vector2(42, 46), Vector2(84, 84)), false)
			draw_string(font, p + Vector2(-70, 76), "%d %s" % [i + 1, ChefCfg.TOOL_NAMES[t]], HORIZONTAL_ALIGNMENT_CENTER, 140, 19, Color.WHITE)


## Полоска «Грязь кухни»: зелёная → жёлтая → красная, значок таракана при грязи.
class DirtBar extends Node2D:
	var level := 0.0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.07, 0.05, 0.72)
		bg.set_corner_radius_all(10)
		draw_style_box(bg, Rect2(0, 0, 222, 42))
		draw_string(font, Vector2(10, 17), "Грязь кухни: %d%%" % int(round(level * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.95, 0.88))
		var bar := Rect2(10, 24, 202, 10)
		draw_rect(bar, Color(0.25, 0.22, 0.2))
		var c := Color(0.35, 0.8, 0.35)
		if level > 0.35:
			c = Color(0.95, 0.75, 0.2)
		if level >= ChefCfg.DIRTY_LEVEL:
			c = Color(0.9, 0.25, 0.15)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * level, bar.size.y)), c)
		# порог, с которого тараканы начинают приходить
		var x := bar.position.x + bar.size.x * ChefCfg.ROACH_MIN_DIRT
		draw_line(Vector2(x, bar.position.y - 2), Vector2(x, bar.end.y + 2), Color(1, 1, 1, 0.6), 1.5)
