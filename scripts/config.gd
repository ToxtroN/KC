extends Node
## Общие настройки (автозагрузка «Cfg»): тараканы и их анимации.
## Всё про кухню — в scripts/chef/chef_cfg.gd.

const VIEW := Vector2(1280, 720)
const SPRITES := "res://assets/sprites/"
const SOUNDS := "res://assets/sounds/"

# ---------- Анимации таракана ----------
# Листы кадров по горизонтали, голова ВВЕРХ, ячейка ROACH_CELL.
const ROACH_CELL := Vector2(150, 190)
const ROACH_ANIMS := {
	"walk": {"tex": "roach_walk.png", "frames": 8, "fps": 14.0, "loop": true},
	"run": {"tex": "roach_run.png", "frames": 8, "fps": 22.0, "loop": true},
	"idle": {"tex": "roach_idle.png", "frames": 8, "fps": 10.0, "loop": true},
	"startle": {"tex": "roach_startle.png", "frames": 6, "fps": 18.0, "loop": false},
	"die": {"tex": "roach_die.png", "frames": 8, "fps": 16.0, "loop": false},
}

# ---------- Виды тараканов ----------
# move — анимация бега; tint — оттенок; wings — летающий (крылья рисуются кодом).
const ROACHES := {
	"normal": {"move": "walk", "scale": 0.62, "tint": Color(1, 1, 1),
		"speed": 105.0, "hp": 1, "score": 10, "radius": 24.0},
	"fast": {"move": "run", "scale": 0.52, "tint": Color(1.15, 1.0, 0.8),
		"speed": 190.0, "hp": 1, "score": 20, "radius": 20.0},
	"big": {"move": "walk", "scale": 0.9, "tint": Color(0.65, 0.55, 0.5),
		"speed": 70.0, "hp": 2, "score": 35, "radius": 34.0},
	"flying": {"move": "run", "scale": 0.62, "tint": Color(1, 0.9, 0.85), "wings": true,
		"speed": 150.0, "hp": 1, "score": 40, "radius": 26.0},
}

var _roach_frames: SpriteFrames


func tex(file: String) -> Texture2D:
	var path := SPRITES + file
	if ResourceLoader.exists(path):
		return load(path)
	return null


## Общие кадры тараканов (собираются один раз из листов).
func roach_frames() -> SpriteFrames:
	if _roach_frames:
		return _roach_frames
	_roach_frames = SpriteFrames.new()
	_roach_frames.remove_animation("default")
	for anim_name in ROACH_ANIMS:
		var d: Dictionary = ROACH_ANIMS[anim_name]
		var t := tex(d.tex)
		_roach_frames.add_animation(anim_name)
		_roach_frames.set_animation_speed(anim_name, d.fps)
		_roach_frames.set_animation_loop(anim_name, d.loop)
		if t == null:
			continue
		for i in d.frames:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2(Vector2(i * ROACH_CELL.x, 0), ROACH_CELL)
			_roach_frames.add_frame(anim_name, at)
	return _roach_frames
