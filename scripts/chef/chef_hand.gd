class_name ChefHand
extends Node2D
## Рука повара: пустая рука, губка или мухобойка. Точка под курсором — то, что в руке.
## Рука тянется от «плеча» за нижним краем экрана и вытягивается к дальним краям стола.

signal slammed(point: Vector2, radius: float)

var tool := "hand"
var sprite: Sprite2D
var shadow: Sprite2D
var _lift := 1.0
var _busy := false
var _fist_t := 0.0
var _scrub_t := 0.0
var held: Node2D                  # продукт в руке (при перетаскивании)
var _held_slot: Node2D


func _ready() -> void:
	shadow = Sprite2D.new()
	shadow.centered = false
	shadow.modulate = Color(0, 0, 0, 0.28)
	add_child(shadow)
	_held_slot = Node2D.new()
	add_child(_held_slot)
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	set_tool("hand")


func set_tool(t: String) -> void:
	tool = t
	_apply(t)


func _apply(key: String) -> void:
	var d: Dictionary = ChefCfg.HANDS[key]
	var tx := ChefCfg.tex(d.tex)
	sprite.texture = tx
	shadow.texture = tx
	sprite.offset = -d.head
	shadow.offset = -d.head


func aim(p: Vector2) -> void:
	global_position = p
	rotation = (p - ChefCfg.SHOULDER).angle() + PI / 2.0


## Удар мухобойкой: замах и шлепок.
func swing() -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(self, "_lift", 1.3, 0.04)
	tw.tween_property(self, "_lift", 0.0, 0.05).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): slammed.emit(global_position, ChefCfg.HIT_RADIUS))
	tw.tween_interval(0.05)
	tw.tween_property(self, "_lift", 1.0, 0.12)
	tw.tween_callback(func(): _busy = false)


## Короткое касание рукой (взять продукт, прогнать таракана).
func tap() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_lift", 0.2, 0.05)
	tw.tween_property(self, "_lift", 1.0, 0.1)


## Удар кулаком по звонку: замах, удар (в момент удара вызывается on_hit), возврат.
func punch(on_hit: Callable) -> void:
	if _busy:
		return
	_busy = true
	_fist_t = 0.6
	_apply("fist")
	var tw := create_tween()
	tw.tween_property(self, "_lift", 1.8, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_lift", -0.15, 0.06).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_hit)
	tw.tween_interval(0.08)
	tw.tween_property(self, "_lift", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _busy = false)


## Взять продукт: пальцы сжимаются, продукт между ними.
func grab(piece: Node2D) -> void:
	drop()
	held = piece
	_held_slot.add_child(piece)
	piece.position = Vector2(0, -18)
	piece.rotation = -rotation   # продукт не крутится вместе с рукой
	_apply("fist")
	_fist_t = 0.0


## Отпустить: вернуть позу инструмента. Возвращает продукт (уже без родителя).
func drop() -> Node2D:
	var p := held
	held = null
	if p:
		var gp := p.global_position
		_held_slot.remove_child(p)
		p.global_position = gp
	_apply(tool)
	return p


## Тереть губкой: рука покачивается.
func scrub() -> void:
	_scrub_t = 0.12


func _process(delta: float) -> void:
	if _fist_t > 0.0:
		_fist_t -= delta
		if _fist_t <= 0.0 and held == null:
			_apply(tool)
	if held:
		held.rotation = -rotation
	_scrub_t -= delta
	var wob := sin(Time.get_ticks_msec() / 40.0) * 0.08 if _scrub_t > 0.0 else 0.0
	sprite.rotation = wob
	shadow.rotation = wob
	var s := ChefCfg.HAND_SCALE * (1.0 + 0.1 * _lift)
	sprite.scale = Vector2.ONE * s
	_held_slot.scale = Vector2.ONE * (1.0 + 0.1 * _lift)
	shadow.scale = Vector2.ONE * ChefCfg.HAND_SCALE
	shadow.position = (Vector2(14, 20) * _lift).rotated(-rotation)
