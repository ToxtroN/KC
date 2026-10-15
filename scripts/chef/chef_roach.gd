class_name ChefRoach
extends Node2D
## Таракан на кухне: бежит к продукту или сэндвичу и садится на него.
## Пока сидит — продукт взять нельзя, а сэндвич через SANDWICH_SPOIL секунд испорчен.

enum State { GO, SIT, FLEE, DEAD }

var type := "normal"
var data: Dictionary
var game: Node
var state := State.GO
var hp := 1
var speed := 100.0
var radius := 24.0
var heading := 0.0
var spot: Node2D                  # Supply, тарелка или пятно
var carrying: Node2D               # Supply, у которого утащил штуку
var loot_s: Sprite2D
var spot_offset := Vector2.ZERO
var sit_t := 0.0
var body: AnimatedSprite2D
var shadow: AnimatedSprite2D
var wings: Array[Polygon2D] = []
var alt := 0.0
var _goal := Vector2.ZERO
var _seed := 0.0
var _waypoint := Vector2.ZERO
var _route_t := 0.0
var _route_goal := Vector2.INF


func setup(t: String, start: Vector2, g: Node) -> void:
	type = t
	data = Cfg.ROACHES[t]
	game = g
	position = start
	hp = data.hp
	speed = data.speed * randf_range(0.9, 1.1)
	radius = data.radius
	_seed = randf() * 100.0
	add_to_group("chef_roaches")
	var frames := Cfg.roach_frames()
	shadow = AnimatedSprite2D.new()
	shadow.sprite_frames = frames
	shadow.modulate = Color(0, 0, 0, 0.3)
	shadow.scale = Vector2.ONE * data.scale
	shadow.visible = false
	add_child(shadow)
	body = AnimatedSprite2D.new()
	body.sprite_frames = frames
	body.scale = Vector2.ONE * data.scale
	body.modulate = data.tint
	add_child(body)
	if data.get("wings", false):
		alt = 1.0
		for side in [-1.0, 1.0]:
			var w := Polygon2D.new()
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				pts.append(Vector2(cos(a) * 26.0, sin(a) * 52.0))
			w.polygon = pts
			w.color = Color(0.85, 0.9, 1.0, 0.45)
			w.position = Vector2(side * 24.0, 0)
			w.set_meta("side", side)
			body.add_child(w)
			wings.append(w)
	heading = (ChefCfg.VIEW * 0.5 - position).angle()
	rotation = heading + PI / 2.0
	body.play(data.move)
	shadow.play(data.move)
	_pick()


func is_alive() -> bool:
	return state != State.DEAD


func is_sitting_on(n: Node) -> bool:
	return state == State.SIT and spot == n


func hit_test(p: Vector2, r: float) -> bool:
	return is_alive() and p.distance_to(global_position) <= r + radius


func _pick() -> void:
	var s: Dictionary = game.pick_spot(global_position)
	if s.is_empty():
		flee(global_position + Vector2(0, -1))
		return
	spot = s.node
	spot_offset = s.offset
	state = State.GO


## Возвращает true, если погиб.
func damage() -> bool:
	hp -= 1
	if hp > 0:
		body.modulate = Color(1.6, 0.6, 0.6)
		create_tween().tween_property(body, "modulate", data.tint, 0.35)
		flee(global_position + Vector2.from_angle(randf() * TAU))
		return false
	state = State.DEAD
	spot = null
	carrying = null
	if loot_s:
		loot_s.queue_free()
		loot_s = null
	alt = 0.0
	shadow.visible = false
	for w in wings:
		w.queue_free()
	wings.clear()
	remove_from_group("chef_roaches")
	body.speed_scale = 1.0
	body.play("die")
	get_parent().move_child(self, 0)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)
	return true


## Хватает штуку продукта и тащит со стола.
func _steal(s) -> void:
	s.take()
	carrying = s
	loot_s = s.make_piece(42)
	loot_s.position = Vector2(0, -Cfg.ROACH_CELL.y * 0.3)
	body.add_child(loot_s)
	flee(s.global_position + Vector2(0, 1))
	_goal = game.exit_point(global_position, global_position - ChefCfg.VIEW * 0.5)


## Уехал в сэндвич вместе с продуктом: сидит на тарелке, пока не прихлопнут или не спугнут.
func ride_plate(plate: Node2D) -> void:
	spot = plate
	spot_offset = Vector2(randf_range(-35, 35), randf_range(-30, 25))
	state = State.SIT
	sit_t = 9999.0
	alt = 0.0
	body.play("idle")
	shadow.play("idle")


## Спугнули — бежит прочь со стола.
func flee(from: Vector2) -> void:
	if not is_alive():
		return
	state = State.FLEE
	spot = null
	_goal = game.exit_point(global_position, global_position - from)


func _process(delta: float) -> void:
	match state:
		State.DEAD:
			return
		State.GO:
			if spot == null or not is_instance_valid(spot) or not spot.visible:
				_pick()
				return
			var p: Vector2 = spot.global_position + spot_offset
			if wings.size() > 0:
				alt = clampf(global_position.distance_to(p) / 200.0, 0.0, 1.0)
			if global_position.distance_to(p) < 10.0:
				state = State.SIT
				var steal: bool = spot is KitchenItems.Supply
				var rng: Vector2 = ChefCfg.STEAL_TIME if steal else ChefCfg.SIT_TIME
				sit_t = randf_range(rng.x, rng.y)
				body.play("idle")
				shadow.play("idle")
			else:
				_move(p, delta, 1.0)
		State.SIT:
			if spot == null or not is_instance_valid(spot) or not spot.visible:
				_pick()
				return
			global_position = spot.global_position + spot_offset   # едет вместе с тарелкой
			sit_t -= delta
			if sit_t <= 0.0:
				if spot is KitchenItems.Supply and spot.stock > 0:
					_steal(spot)
				elif randf() < 0.5:
					flee(global_position + Vector2(0, 1))
				else:
					_pick()
		State.FLEE:
			_move(_goal, delta, 1.5)
			var m := 70.0
			var p := global_position
			if p.x < -m or p.x > ChefCfg.VIEW.x + m or p.y < -m or p.y > ChefCfg.VIEW.y + m:
				if carrying and is_instance_valid(carrying):
					game.on_stolen(carrying)
				queue_free()
	_visuals()


func _move(p: Vector2, delta: float, mult: float) -> void:
	if body.animation != data.move and body.animation != "run":
		body.play("run" if mult > 1.2 else data.move)
		shadow.play(body.animation)
	# в обход плиты и чека (летающий в воздухе — напрямую)
	var pad := radius * 0.8
	var walking := alt < 0.3
	if walking:
		_route_t -= delta
		# путь пересчитываем, когда дошли до угла или раз в секунду — без метаний между углами
		if _route_t <= 0.0 or global_position.distance_to(_waypoint) < 14.0 or _route_goal.distance_to(p) > 30.0:
			_route_t = 1.0
			_route_goal = p
			_waypoint = game.route(global_position, p, pad)
		p = _waypoint
	var t := Time.get_ticks_msec() / 1000.0 + _seed
	var want := (p - global_position).angle()
	var dist := global_position.distance_to(p)
	if dist > 80.0:
		want += (sin(t * 3.1) * 0.6 + sin(t * 7.3) * 0.25) * 0.5
	# у цели поворачиваем резко и тормозим, иначе таракан кружит вокруг точки
	var turn := 6.0 if dist > 70.0 else 18.0
	heading = lerp_angle(heading, want, clampf(delta * turn, 0.0, 1.0))
	var step := speed * mult * delta
	if dist < 70.0:
		step = minf(step, dist)
	position += Vector2.from_angle(heading) * step
	if walking:
		var fixed: Vector2 = game.push_out(global_position, pad)
		if fixed != global_position:
			global_position = fixed
			_route_t = 0.0
	rotation = heading + PI / 2.0
	body.speed_scale = mult


func _visuals() -> void:
	shadow.visible = alt > 0.02
	body.scale = Vector2.ONE * data.scale * (1.0 + 0.35 * alt)
	shadow.global_position = global_position + Vector2(18, 28) * alt
	shadow.frame = body.frame
	var t := Time.get_ticks_msec() / 1000.0
	for w in wings:
		var side: float = w.get_meta("side")
		var flap := absf(sin(t * 40.0 + _seed)) if alt > 0.05 else 0.0
		w.scale = Vector2(0.4 + 0.6 * flap, 1.0)
		w.visible = alt > 0.05
		w.rotation = side * (0.35 + 0.4 * flap)
