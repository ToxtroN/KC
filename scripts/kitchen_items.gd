class_name KitchenItems
## Предметы кухни: поднос-группа, запас продукта, тарелка, сковорода, звонок, чек заказа, пятно.


## Длинный лоток со всеми продуктами; группы разделены тонкими чертами, подписи — под лотком.
class LongTray extends Node2D:
	var open_x: Array = []           # x открытых продуктов: подписи групп без продуктов не рисуем

	func setup() -> void:
		var r: Rect2 = ChefCfg.LONG_TRAY
		var s := Sprite2D.new()
		s.texture = ChefCfg.tex("long_tray.png")
		s.centered = false
		if s.texture:
			s.scale = r.size / s.texture.get_size()
		s.position = r.position
		add_child(s)

	func _draw() -> void:
		var r: Rect2 = ChefCfg.LONG_TRAY
		var font := ThemeDB.fallback_font
		var groups: Array = ChefCfg.TRAY_GROUPS
		for i in groups.size():
			var g: Dictionary = groups[i]
			var used := false
			for x in open_x:
				if x >= g.x.x and x <= g.x.y:
					used = true
			if not used:
				continue
			if i > 0:
				var x: float = g.x.x
				draw_line(Vector2(x, r.position.y + r.size.y * 0.26), Vector2(x, r.end.y - r.size.y * 0.26), Color(0.55, 0.48, 0.4, 0.45), 2.0)
			draw_string(font, Vector2(g.x.x, r.end.y + 16), g.title, HORIZONTAL_ALIGNMENT_CENTER, g.x.y - g.x.x, 18,
				Color(1, 0.96, 0.88, 0.8))


## Запас продукта. Наведение — чуть увеличивается, подсветка — когда его ждут.
## stock — сколько штук осталось (тараканы воруют, запас пополняется).
class Supply extends Node2D:
	var id := ""
	var radius := 50.0
	var w := 90.0
	var stand := false               # бутылка стоит на столе, а не лежит на лотке
	var stock := ChefCfg.STOCK_MAX
	var pile: Node2D
	var tex: Texture2D
	var hovered := false
	var glow := false
	var _t := 0.0
	var _restock_t := 0.0
	var _badge: Node2D

	func setup(d: Dictionary) -> void:
		id = d.id
		position = d.pos
		w = d.w
		stand = d.get("stand", false)
		var file: String = ChefCfg.ING[id].tex if ChefCfg.ING.has(id) else id + ".png"
		tex = ChefCfg.tex(file)
		pile = Node2D.new()
		add_child(pile)
		var n := 3 if is_stack() else 1
		for i in n:
			var s := Sprite2D.new()
			s.texture = tex
			s.scale = Vector2.ONE * ChefCfg.fit(tex, w)
			s.position = Vector2(i * 3 - 3, -i * 5 + 5)
			s.rotation = randf_range(-0.12, 0.12)
			pile.add_child(s)
		radius = w * (0.9 if stand else 0.6)
		_badge = Node2D.new()
		_badge.z_index = 3   # поверх соседних продуктов на лотке
		_badge.draw.connect(func():
			if not is_sauce():
				_draw_badge())
		add_child(_badge)
		_refresh()

	func is_stack() -> bool:
		return not stand and id not in ["bacon_raw", "eggs"]

	func is_sauce() -> bool:
		return stand

	func can_take() -> bool:
		return is_sauce() or stock > 0

	func take() -> void:
		if not is_sauce():
			stock -= 1
			_refresh()

	func refill() -> void:
		stock = ChefCfg.STOCK_MAX
		_refresh()
		var tw := pile.create_tween()
		pile.scale = Vector2.ONE * 1.25
		tw.tween_property(pile, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

	func give_back() -> void:
		if not is_sauce():
			stock = mini(stock + 1, ChefCfg.STOCK_MAX)
			_refresh()

	func _refresh() -> void:
		var shown := pile.get_child_count() if is_sauce() else mini(stock, pile.get_child_count())
		for i in pile.get_child_count():
			var s: Sprite2D = pile.get_child(i)
			if is_stack():
				s.visible = i < shown
			else:
				s.modulate.a = 1.0 if (is_sauce() or stock > 0) else 0.25
		queue_redraw()

	func contains(p: Vector2) -> bool:
		return p.distance_to(global_position) <= radius

	## Как выглядит одна штука (для полёта на тарелку и в руке).
	func make_piece(width: float) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * ChefCfg.fit(tex, width)
		return s

	func _process(delta: float) -> void:
		_t += delta
		var target := 1.1 if hovered else 1.0
		pile.scale = pile.scale.lerp(Vector2.ONE * target, clampf(delta * 14.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		if stand:
			draw_circle(Vector2(6, w * 0.95), w * 0.55, Color(0, 0, 0, 0.18))   # тень от бутылки
		if glow:
			var a := 0.35 + 0.25 * sin(_t * 6.0)
			draw_circle(Vector2.ZERO, radius * 0.95, Color(1, 0.85, 0.3, a * 0.45))
			draw_arc(Vector2.ZERO, radius * 0.95, 0, TAU, 40, Color(1, 0.9, 0.4, a + 0.2), 3.0)
		if not is_sauce():
			_badge.queue_redraw()


	## Сколько штук осталось — кружок с цифрой поверх картинки продукта
	## (рисуется отдельным узлом, иначе его закрывает сама картинка).
	func _draw_badge() -> void:
		var font := ThemeDB.fallback_font
		var c := Vector2(radius * 0.68, radius * 0.52)
		var col := Color(0.85, 0.15, 0.1) if stock == 0 else (Color(0.95, 0.6, 0.1) if stock <= 1 else Color(0.2, 0.18, 0.15))
		_badge.draw_circle(c, 17, Color(1, 1, 1))
		_badge.draw_circle(c, 14.5, col)
		_badge.draw_string(font, c + Vector2(-15, 8), str(stock), HORIZONTAL_ALIGNMENT_CENTER, 30, 22, Color.WHITE)


## Тарелка: на ней собирают сэндвич, грязную моют губкой.
class Plate extends Node2D:
	var clean_s: Sprite2D
	var dirty_s: Sprite2D
	var layers_node: Node2D
	var layers: Array[String] = []
	var dirt := 0.0
	var radius := 110.0

	func setup() -> void:
		position = ChefCfg.PLATE_POS
		radius = ChefCfg.PLATE_W * 0.47
		clean_s = Sprite2D.new()
		clean_s.texture = ChefCfg.tex("plate_clean.png")
		clean_s.scale = Vector2.ONE * ChefCfg.fit(clean_s.texture, ChefCfg.PLATE_W)
		add_child(clean_s)
		dirty_s = Sprite2D.new()
		dirty_s.texture = ChefCfg.tex("plate_dirty.png")
		dirty_s.scale = Vector2.ONE * ChefCfg.fit(dirty_s.texture, ChefCfg.PLATE_W)
		add_child(dirty_s)
		layers_node = Node2D.new()
		add_child(layers_node)
		set_dirt(0.0)

	func is_dirty() -> bool:
		return dirt > 0.0

	func set_dirt(v: float) -> void:
		dirt = clampf(v, 0.0, 1.0)
		dirty_s.modulate.a = dirt

	func contains(p: Vector2) -> bool:
		return p.distance_to(global_position) <= radius

	func top_offset() -> Vector2:
		return Vector2(0, -layers.size() * 5.0)

	func add_layer(id: String) -> void:
		layers.append(id)
		var d: Dictionary = ChefCfg.ING[id]
		var i := layers.size() - 1
		var off := Vector2(randf_range(-4, 4), -i * 5.0)
		var node: Node2D
		if d.kind == "sauce":
			var line := Line2D.new()
			line.width = 9.0
			line.default_color = d.color
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			for k in 9:
				line.add_point(Vector2(-56.0 + k * 14.0, (16.0 if k % 2 == 0 else -16.0) + randf_range(-4, 4)))
			node = line
		else:
			var s := Sprite2D.new()
			s.texture = ChefCfg.tex(d.tex)
			s.scale = Vector2.ONE * ChefCfg.fit(s.texture, d.w * ChefCfg.PLATE_W / 280.0)
			s.rotation = randf_range(-0.15, 0.15)
			node = s
		node.position = off
		layers_node.add_child(node)
		# «поп»: слой чуть увеличивается и встаёт на место
		var base := node.scale
		node.scale = base * 1.25
		node.create_tween().tween_property(node, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func clear_layers() -> void:
		layers.clear()
		for c in layers_node.get_children():
			c.queue_free()


## Сковорода на плитке. Жарит что-то одно: котлету, бекон или яйцо.
## Индикатор готовности — кольцо по краю: жёлтое — жарится, зелёное — готово, красное — сгорело.
class Pan extends Node2D:
	signal burnt
	var raw_s: Sprite2D
	var cooked_s: Sprite2D
	var t := 0.0
	var has_patty := false            # на сковороде что-то есть
	var item := ""                    # ключ из COOKABLE (patty_raw / bacon_raw / eggs)
	var glow := false
	var rim := 70.0
	var pan_s: Sprite2D
	var _smoke_t := 0.0
	var _gt := 0.0
	var _burnt_sent := false

	func setup() -> void:
		position = ChefCfg.STOVE_POS + Vector2(0, -8)
		var pan := Sprite2D.new()
		pan.texture = ChefCfg.tex("pan.png")
		pan.scale = Vector2.ONE * ChefCfg.fit(pan.texture, ChefCfg.PAN_W)
		if pan.texture:
			pan.position = Vector2(0, pan.texture.get_height() * pan.scale.y * 0.17)
		add_child(pan)
		pan_s = pan
		rim = ChefCfg.PAN_W * 0.43
		raw_s = Sprite2D.new()
		add_child(raw_s)
		cooked_s = Sprite2D.new()
		add_child(cooked_s)
		clear()

	func result() -> String:
		return ChefCfg.COOKABLE[item].result if item != "" else ""

	func clear() -> void:
		has_patty = false
		item = ""
		t = 0.0
		raw_s.visible = false
		cooked_s.visible = false

	func put_raw(key: String = "patty_raw") -> void:
		item = key
		has_patty = true
		t = 0.0
		_burnt_sent = false
		var d: Dictionary = ChefCfg.COOKABLE[key]
		raw_s.texture = ChefCfg.tex(d.raw)
		cooked_s.texture = ChefCfg.tex(ChefCfg.ING[d.result].tex)
		var w := ChefCfg.PAN_W * 0.6
		raw_s.scale = Vector2.ONE * ChefCfg.fit(raw_s.texture, w)
		cooked_s.scale = Vector2.ONE * ChefCfg.fit(cooked_s.texture, w)
		raw_s.visible = true
		cooked_s.visible = true
		cooked_s.modulate = Color(1, 1, 1, 0)

	func show_food(v: bool) -> void:
		raw_s.visible = v
		cooked_s.visible = v

	func _cook() -> float:
		return ChefCfg.COOKABLE[item].cook

	func _burn() -> float:
		return ChefCfg.COOKABLE[item].burn

	func state() -> String:
		if not has_patty:
			return "empty"
		if t < _cook():
			return "raw"
		if t < _cook() + _burn():
			return "cooked"
		return "burnt"

	func contains(p: Vector2) -> bool:
		return p.distance_to(global_position) <= rim + 15.0

	func _process(delta: float) -> void:
		_gt += delta
		queue_redraw()
		var k := (0.5 + 0.5 * sin(_gt * 5.0)) if glow and not has_patty else 0.0
		pan_s.modulate = Color(1, 1, 1).lerp(Color(1.35, 1.05, 0.75), k)
		if not has_patty:
			return
		t += delta
		cooked_s.modulate.a = clampf(t / _cook(), 0.0, 1.0)
		if t > _cook():
			var b := clampf((t - _cook()) / _burn(), 0.0, 1.0)
			var g := 1.0 - 0.6 * b * b
			cooked_s.modulate = Color(g, g * 0.9, g * 0.85, 1.0)
		if state() == "burnt":
			cooked_s.modulate = Color(0.18, 0.15, 0.13, 1.0)   # угли
			if not _burnt_sent:
				_burnt_sent = true
				burnt.emit()
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = 0.12 if state() == "burnt" else 0.25
			_puff(Color(0.12, 0.12, 0.12, 0.7) if state() == "burnt" else Color(1, 1, 1, 0.35))

	func _puff(c: Color) -> void:
		var p := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 10:
			pts.append(Vector2.from_angle(TAU * i / 10.0) * randf_range(8, 12))
		p.polygon = pts
		p.color = c
		p.position = Vector2(randf_range(-30, 30), randf_range(-25, 15))
		add_child(p)
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "position:y", p.position.y - 55.0, 1.0)
		tw.tween_property(p, "scale", Vector2.ONE * 2.0, 1.0)
		tw.tween_property(p, "modulate:a", 0.0, 1.0)
		tw.chain().tween_callback(p.queue_free)

	func _draw() -> void:
		if glow and not has_patty:
			var a := 0.3 + 0.2 * sin(_gt * 5.0)
			draw_arc(Vector2.ZERO, rim + 4, 0, TAU, 48, Color(1, 0.8, 0.3, a + 0.3), 3.0)
		if not has_patty:
			return
		var s := state()
		var col := Color(1, 0.8, 0.2)
		var k := t / _cook()
		if s == "cooked":
			col = Color(0.3, 0.95, 0.35)
			k = 1.0 - (t - _cook()) / _burn()
		elif s == "burnt":
			col = Color(0.9, 0.15, 0.1) if int(_gt * 4.0) % 2 == 0 else Color(0.4, 0.05, 0.05)
			k = 1.0
		draw_arc(Vector2.ZERO, rim, -PI / 2, -PI / 2 + TAU, 48, Color(0, 0, 0, 0.35), 6.0)
		draw_arc(Vector2.ZERO, rim, -PI / 2, -PI / 2 + TAU * clampf(k, 0.0, 1.0), 48, col, 4.0)


## Звонок и плашка «ГОТОВО». Когда заказ собран — звонок подпрыгивает и блестит.
class Bell extends Node2D:
	var sprite: Sprite2D
	var lit := false
	var _t := 0.0

	func setup() -> void:
		position = ChefCfg.BELL_POS
		sprite = Sprite2D.new()
		sprite.texture = ChefCfg.tex("bell.png")
		sprite.scale = Vector2.ONE * ChefCfg.fit(sprite.texture, ChefCfg.BELL_W)
		add_child(sprite)

	func contains(p: Vector2) -> bool:
		return p.distance_to(global_position) <= ChefCfg.BELL_W * 0.55 or \
			Rect2(ChefCfg.READY_POS - Vector2(70, 22), Vector2(140, 44)).has_point(p)

	func press() -> void:
		var tw := sprite.create_tween()
		var base := Vector2.ONE * ChefCfg.fit(sprite.texture, ChefCfg.BELL_W)
		tw.tween_property(sprite, "scale", base * Vector2(1.08, 0.85), 0.05)
		tw.tween_property(sprite, "scale", base, 0.15).set_trans(Tween.TRANS_BACK)

	func _process(delta: float) -> void:
		_t += delta
		sprite.position.y = -absf(sin(_t * 7.0)) * 10.0 if lit else 0.0
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		if lit:
			var a := 0.4 + 0.3 * sin(_t * 8.0)
			draw_circle(Vector2(0, -10), ChefCfg.BELL_W * 0.62, Color(1, 0.95, 0.5, a * 0.55))
			draw_arc(Vector2(0, -10), ChefCfg.BELL_W * 0.62, 0, TAU, 48, Color(1, 1, 0.7, a + 0.3), 4.0)
			for i in 6:   # блёстки
				var ang := _t * 2.0 + TAU * i / 6.0
				var p := Vector2.from_angle(ang) * ChefCfg.BELL_W * 0.62 + Vector2(0, -10)
				draw_line(p - Vector2(6, 0), p + Vector2(6, 0), Color(1, 1, 0.8, a + 0.3), 2.0)
				draw_line(p - Vector2(0, 6), p + Vector2(0, 6), Color(1, 1, 0.8, a + 0.3), 2.0)
		var plate_r := Rect2(ChefCfg.READY_POS - global_position - Vector2(70, 20), Vector2(140, 40))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.6, 0.25, 0.95) if lit else Color(0.15, 0.1, 0.06, 0.55)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(1, 1, 1, 0.6) if lit else Color(1, 1, 1, 0.15)
		sb.set_border_width_all(2)
		draw_style_box(sb, plate_r)
		draw_string(font, plate_r.position + Vector2(0, 29), "ГОТОВО", HORIZONTAL_ALIGNMENT_CENTER, plate_r.size.x, 24,
			Color.WHITE if lit else Color(1, 1, 1, 0.45))


## Бумажный чек заказа: неровный нижний край, крупный номер, галочки у сделанного.
class Ticket extends Node2D:
	var recipe: Array = []
	var done := 0
	var number := 1
	var total := 1
	var time_left := 1.0
	var time_total := 1.0
	var size := ChefCfg.TICKET_RECT.size
	var flash := 0.0                 # красная вспышка при ошибке
	var _icons := {}

	func _ready() -> void:
		# значки грузим заранее: загрузка прямо в _draw в веб-рендере даёт пустые квадраты
		for id in ChefCfg.ING:
			_icons[id] = ChefCfg.tex(ChefCfg.ING[id].tex)
	var _shake := 0.0
	var _base := Vector2.ZERO

	func error() -> void:
		flash = 1.0
		_shake = 0.35

	func _process(delta: float) -> void:
		if _base == Vector2.ZERO:
			_base = position
		flash = maxf(flash - delta * 2.5, 0.0)
		if _shake > 0.0:
			_shake -= delta
			position.x = _base.x + sin(_shake * 70.0) * 8.0 * (_shake / 0.35)
		queue_redraw()

	func _paper_poly(h: float) -> PackedVector2Array:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
		var n := 12
		for i in n + 1:
			var x := size.x - size.x * i / n
			pts.append(Vector2(x, h + (8.0 if i % 2 == 0 else 0.0)))
		return pts

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var n := recipe.size()
		var row := 38.0
		var h := 92.0 + n * row + 30.0
		var paper := _paper_poly(h)
		var shadow := PackedVector2Array()
		for p in paper:
			shadow.append(p + Vector2(5, 6))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		draw_colored_polygon(paper, Color(0.99, 0.97, 0.9).lerp(Color(1, 0.55, 0.5), flash * 0.6))
		# дырочки от кассового аппарата сверху
		for i in 9:
			draw_circle(Vector2(12 + i * (size.x - 24) / 8.0, 6), 2.5, Color(0.85, 0.82, 0.75))
		draw_string(font, Vector2(0, 46), ("Заказ %d/%d" % [number, total]) if total > 0 else ("Заказ №%d" % number), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(0.18, 0.12, 0.08))
		for i in 3:
			draw_line(Vector2(14, 60 + i * 3), Vector2(size.x - 14, 60 + i * 3), Color(0.7, 0.62, 0.5, 0.6), 1.0)
		# сверху — верхний слой, как сэндвич выглядит сбоку
		for i in n:
			var idx := n - 1 - i
			var y := 72.0 + i * row
			var id: String = recipe[idx]
			var d: Dictionary = ChefCfg.ING[id]
			var col := Color(0.2, 0.14, 0.1)
			var is_done := idx < done
			if is_done:
				col = Color(0.5, 0.5, 0.46)
			elif idx == done:
				draw_rect(Rect2(6, y, size.x - 12, row - 2), Color(1, 0.88, 0.45, 0.55))
			var t: Texture2D = _icons.get(id)
			if t:
				var sz := row - 8.0
				var w := sz * minf(1.0, float(t.get_width()) / t.get_height())
				var hh := sz * minf(1.0, float(t.get_height()) / t.get_width())
				draw_texture_rect(t, Rect2(14 + (sz - w) / 2, y + 4 + (sz - hh) / 2, w, hh), false, Color(1, 1, 1, 0.55 if is_done else 1.0))
			draw_string(font, Vector2(50, y + row * 0.7), d.name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 72, 23, col)
			if is_done:
				var ty := y + row * 0.5
				draw_line(Vector2(50, ty), Vector2(size.x - 40, ty), Color(0.35, 0.35, 0.3, 0.6), 1.5)
				var c := Vector2(size.x - 24, y + row * 0.5)
				draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-3, 7), c + Vector2(10, -8)]), Color(0.15, 0.65, 0.2), 4.0)
		# терпение посетителя
		var k := clampf(time_left / time_total, 0.0, 1.0)
		var bar := Rect2(12, h - 22, size.x - 24, 10)
		draw_rect(bar, Color(0.85, 0.82, 0.75))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color(0.3, 0.75, 0.3).lerp(Color(0.9, 0.2, 0.15), 1.0 - k))


## Пятно на столе: крошки, кетчуп или жир. Трётся губкой.
class Stain extends Node2D:
	var kind := "crumbs"
	var amount := 1.0
	var _shapes: Array = []

	func setup(k: String, p: Vector2) -> void:
		kind = k
		position = p
		rotation = randf() * TAU
		match kind:
			"ketchup":
				_shapes.append([_blob(Vector2.ZERO, 16, 0.4), Color(0.75, 0.08, 0.05, 0.85)])
				for i in 5:
					_shapes.append([_blob(Vector2.from_angle(randf() * TAU) * randf_range(18, 34), randf_range(3, 7), 0.2), Color(0.75, 0.08, 0.05, 0.85)])
			"roach":
				_shapes.append([_blob(Vector2.ZERO, 14, 0.5), Color(0.35, 0.22, 0.08, 0.8)])
				for i in 4:
					_shapes.append([_blob(Vector2.from_angle(randf() * TAU) * randf_range(12, 22), randf_range(3, 6), 0.3), Color(0.4, 0.28, 0.1, 0.75)])
			"grease":
				_shapes.append([_blob(Vector2.ZERO, 30, 0.25), Color(0.95, 0.8, 0.3, 0.28)])
				_shapes.append([_blob(Vector2(8, -4), 18, 0.25), Color(1, 0.9, 0.5, 0.25)])
			_:
				for i in 12:
					_shapes.append([_blob(Vector2.from_angle(randf() * TAU) * randf_range(0, 30), randf_range(2.5, 5), 0.35), Color(0.75, 0.55, 0.25, 0.95)])

	func _blob(c: Vector2, r: float, wob: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var ph := randf() * TAU
		for i in 18:
			var a := TAU * i / 18.0
			pts.append(c + Vector2.from_angle(a) * r * (1.0 + wob * sin(a * 3.0 + ph)))
		return pts

	func contains(p: Vector2) -> bool:
		return p.distance_to(global_position) <= 45.0

	func wash(dist: float) -> bool:
		amount -= dist / ChefCfg.STAIN_WASH
		modulate.a = clampf(amount, 0.0, 1.0)
		return amount <= 0.0

	func _draw() -> void:
		for s in _shapes:
			draw_colored_polygon(s[0], s[1])



## Рука поставщика/официанта: тянется сверху, из-за стола.
## point — где ладонь; carry — что несёт (тарелка едет вместе с ладонью).
class SupplierHand extends Node2D:
	var point := Vector2(640, -300)
	var carry: Node2D
	var carry_off := Vector2.ZERO
	var sprite: Sprite2D
	var shadow: Sprite2D
	var _flinch := 0.0

	func setup() -> void:
		var t := ChefCfg.tex(ChefCfg.SUPPLIER_TEX)
		shadow = Sprite2D.new()
		shadow.texture = t
		shadow.centered = false
		shadow.offset = -ChefCfg.SUPPLIER_HEAD
		shadow.modulate = Color(0, 0, 0, 0.25)
		shadow.scale = Vector2.ONE * ChefCfg.SUPPLIER_SCALE
		add_child(shadow)
		sprite = Sprite2D.new()
		sprite.texture = t
		sprite.centered = false
		sprite.offset = -ChefCfg.SUPPLIER_HEAD
		sprite.scale = Vector2.ONE * ChefCfg.SUPPLIER_SCALE
		add_child(sprite)
		visible = false

	## «Плечо» всегда высоко над ладонью — рука не перекручивается и не торчит обрубком.
	func shoulder() -> Vector2:
		return Vector2(lerpf(ChefCfg.SUPPLIER_SHOULDER.x, point.x, 0.6), minf(ChefCfg.SUPPLIER_SHOULDER.y, point.y - 700.0))

	func flinch() -> void:
		_flinch = 0.35

	## Попал ли удар по руке (ладонь или рукав выше неё).
	func hit_test(p: Vector2, r: float) -> bool:
		if not visible:
			return false
		var a := point
		var b := point + (shoulder() - point).normalized() * 900.0
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		return p.distance_to(a.lerp(b, t)) <= r + 32.0

	func _process(delta: float) -> void:
		_flinch = maxf(_flinch - delta, 0.0)
		var shake := Vector2(sin(_flinch * 90.0), 0) * 10.0 * (_flinch / 0.35)
		global_position = point + shake
		# рука растёт сверху: «вверх» спрайта направлено от плеча к ладони
		rotation = (point - shoulder()).angle() + PI / 2.0
		shadow.position = Vector2(14, 22).rotated(-rotation)
		if carry and is_instance_valid(carry):
			carry.global_position = point + carry_off
