extends Control

const COLORS := [
	Color("#FF85A1"), Color("#FFD700"), Color("#7C5CFC"),
	Color("#27AE60"), Color("#F39C12"), Color("#4A90D9"),
	Color("#E74C3C"), Color("#9B59B6"), Color("#FF6B6B")
]

var _pieces: Array = []
var _elapsed := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_spawn()

func _spawn() -> void:
	var sw := get_viewport_rect().size.x
	for i in 90:
		_pieces.append({
			"pos": Vector2(randf_range(0, sw), randf_range(-120.0, -5.0)),
			"vel": Vector2(randf_range(-50.0, 50.0), randf_range(180.0, 380.0)),
			"color": COLORS[randi() % COLORS.size()],
			"size": Vector2(randf_range(6.0, 13.0), randf_range(4.0, 9.0)),
			"rot": randf_range(0.0, TAU),
			"rot_vel": randf_range(-4.0, 4.0),
			"life": 1.0
		})

func _process(delta: float) -> void:
	_elapsed += delta
	var any_alive := false
	for p in _pieces:
		p.pos += p.vel * delta
		p.vel.y += 60.0 * delta  # gravity
		p.rot += p.rot_vel * delta
		p.life -= delta * 0.38
		if p.life > 0.0:
			any_alive = true
	queue_redraw()
	if not any_alive:
		queue_free()

func _draw() -> void:
	for p in _pieces:
		if p.life <= 0.0:
			continue
		var col: Color = p.color
		col.a = clampf(p.life, 0.0, 1.0)
		draw_polygon(_rotated_rect(p.pos, p.size, p.rot),
				PackedColorArray([col, col, col, col]))

func _rotated_rect(center: Vector2, sz: Vector2, angle: float) -> PackedVector2Array:
	var hw := sz.x / 2.0
	var hh := sz.y / 2.0
	var pts := PackedVector2Array()
	for c in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]:
		pts.append(center + c.rotated(angle))
	return pts
