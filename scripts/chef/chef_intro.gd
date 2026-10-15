class_name ChefIntro
extends Control
## Экран перед первой сменой: короткая история и подписи ко всему на кухне.
## Кухня видна за затемнением, к каждому предмету тянется стрелка с подписью.
## «Продолжить» — и игра начинается.

signal done

const STORY_TITLE := "Kitchen Commotion"
const STORY := "Ты — повар забегаловки, а на кухню лезут тараканы! Собирай сэндвичи по чеку, жарь, бей по звонку, мой посуду и гоняй воришек. %d сорванных заказа — конец смены."

# подпись: текст, где стоит табличка, её ширина и куда тянется стрелка
# (шрифт крупный — на телефоне экран сжимается примерно вдвое)
var notes := [
	{"text": "ЛОТОК С ПРОДУКТАМИ\nТапни продукт — он сам полетит на тарелку. Можно перетащить. Цифра — сколько осталось.",
		"pos": Vector2(400, 30), "w": 560, "to": Vector2(300, 105)},
	{"text": "СКОВОРОДА\nЖарь котлеты, бекон, яйца. Зелёное кольцо — готово.",
		"pos": Vector2(258, 248), "w": 206, "to": Vector2(205, 330)},
	{"text": "ТАРЕЛКА\nСэндвич снизу вверх: хлеб, начинка, хлеб.",
		"pos": Vector2(478, 214), "w": 250, "to": Vector2(590, 330)},
	{"text": "ЧЕК ЗАКАЗА\nЧто положить. Полоска — время.",
		"pos": Vector2(800, 200), "w": 250, "to": Vector2(1084, 160)},
	{"text": "ЗВОНОК\nЗаказ готов — бей! Два удара — приедет поставщик.",
		"pos": Vector2(862, 340), "w": 240, "to": Vector2(1128, 478)},
	{"text": "СМЕНА РУКИ\nРука, губка, мухобойка.",
		"pos": Vector2(870, 545), "w": 250, "to": Vector2(1140, 640)},
	{"text": "ГРЯЗЬ И ОЧКИ\nГрязь манит тараканов — мой губкой.",
		"pos": Vector2(18, 410), "w": 300, "to": Vector2(110, 556)},
]

var _story: PanelContainer
var _boxes: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = ChefCfg.VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	for n in notes:
		var b := _note(n)
		_boxes.append(b)
	_build_story()
	# подписи появляются по очереди — глаз успевает пробежать по кухне
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	for b in _boxes:
		b.scale = Vector2.ONE * 0.6
		b.modulate.a = 0.0
		tw.tween_property(b, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _note(n: Dictionary) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.97, 0.86)
	sb.border_color = Color(0.35, 0.22, 0.1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	p.position = n.pos
	p.custom_minimum_size = Vector2(n.w, 0)
	p.size = Vector2(n.w, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = n.text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(n.w - 20, 0)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.22, 0.13, 0.06))
	l.add_theme_constant_override("line_spacing", -2)
	p.add_child(l)
	add_child(p)
	p.pivot_offset = Vector2(n.w * 0.5, 30)
	return p


func _build_story() -> void:
	_story = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.06, 0.96)
	sb.border_color = Color(1.0, 0.75, 0.25)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(14)
	_story.add_theme_stylebox_override("panel", sb)
	_story.position = Vector2(372, 440)
	_story.custom_minimum_size = Vector2(480, 0)
	add_child(_story)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_story.add_child(col)
	var t := Label.new()
	t.text = STORY_TITLE
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	col.add_child(t)
	var s := Label.new()
	s.text = STORY % ChefCfg.STRIKES
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(450, 0)
	s.add_theme_font_size_override("font_size", 19)
	s.add_theme_color_override("font_color", Color(1, 0.95, 0.88))
	s.add_theme_constant_override("line_spacing", -2)
	col.add_child(s)
	var b := Button.new()
	b.text = "Продолжить"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(280, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 28)
	for st in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.25, 0.62, 0.25) if st == "normal" else (Color(0.33, 0.74, 0.33) if st == "hover" else Color(0.2, 0.5, 0.2))
		bs.border_color = Color(0.08, 0.05, 0.02)
		bs.set_border_width_all(3)
		bs.set_corner_radius_all(14)
		b.add_theme_stylebox_override(st, bs)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(_finish)
	col.add_child(b)


func _finish() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		done.emit()
		queue_free())


func _process(_d: float) -> void:
	queue_redraw()   # стрелки следуют за табличками, пока те «выпрыгивают»


func _draw() -> void:
	# затемнение кухни, сквозь которое всё видно
	draw_rect(Rect2(Vector2.ZERO, ChefCfg.VIEW), Color(0, 0, 0, 0.45))
	for i in notes.size():
		var b := _boxes[i]
		if b.modulate.a <= 0.01:
			continue
		var r := Rect2(b.position, b.size)
		var to: Vector2 = notes[i].to
		var from := Vector2(clampf(to.x, r.position.x + 12, r.end.x - 12), clampf(to.y, r.position.y + 10, r.end.y - 10))
		# стрелка выходит из ближайшего к цели края таблички
		if to.y < r.position.y:
			from.y = r.position.y
		elif to.y > r.end.y:
			from.y = r.end.y
		elif to.x < r.position.x:
			from.x = r.position.x
		else:
			from.x = r.end.x
		var c := Color(1.0, 0.85, 0.3, b.modulate.a)
		draw_line(from, to, Color(0, 0, 0, 0.6 * b.modulate.a), 7.0, true)
		draw_line(from, to, c, 3.5, true)
		var dir := (to - from).normalized()
		var side := dir.orthogonal()
		var head := PackedVector2Array([to, to - dir * 16 + side * 8, to - dir * 16 - side * 8])
		draw_colored_polygon(head, c)
		draw_circle(to, 4.0, c)
