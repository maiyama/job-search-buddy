extends Control

var _bounce_offset := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 140)

func set_message(_msg: String) -> void:
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_bounce, 0.0, 1.0, 0.25)
	tween.tween_method(_set_bounce, 1.0, 0.0, 0.25)

func _set_bounce(v: float) -> void:
	_bounce_offset = sin(v * PI) * 7.0
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x / 220.0, size.y / 170.0)
	s = maxf(s, 0.4)
	var ox := (size.x - 220.0 * s) / 2.0
	var oy := maxf((size.y - 170.0 * s) / 2.0, 0.0)
	draw_set_transform(Vector2(ox, oy), 0.0, Vector2(s, s))

	var cx    := 110.0
	var cy    := 96.0 + _bounce_offset
	var cream := Color("#F8F4EE")
	var snout := Color("#EEE8DF")
	var brown := Color("#5C3218")

	# Drop shadow
	_draw_ellipse(cx + 3, cy + 5, 70, 66, Color(0, 0, 0, 0.06))
	# Body — nearly circular
	_draw_ellipse(cx, cy, 70, 66, cream)
	# Large snout oval
	_draw_ellipse(cx, cy + 10, 30, 22, snout)
	# Eyes — brown filled circles
	draw_circle(Vector2(cx - 27, cy - 6), 7.5, brown)
	draw_circle(Vector2(cx + 27, cy - 6), 7.5, brown)
	# T-shaped nose: dot + philtrum line
	draw_circle(Vector2(cx, cy + 3), 4.0, brown)
	draw_line(Vector2(cx, cy + 7), Vector2(cx, cy + 13), brown, 2.5)
	# Smile
	_draw_smile(cx, cy + 15, brown)
	# Whiskers — 2 horizontal pairs, one per side
	draw_line(Vector2(cx - 20, cy + 5),  Vector2(cx - 38, cy + 3),  brown, 1.5)
	draw_line(Vector2(cx - 20, cy + 10), Vector2(cx - 38, cy + 9),  brown, 1.5)
	draw_line(Vector2(cx + 20, cy + 5),  Vector2(cx + 38, cy + 3),  brown, 1.5)
	draw_line(Vector2(cx + 20, cy + 10), Vector2(cx + 38, cy + 9),  brown, 1.5)
	# Small stubby flippers at bottom
	_draw_ellipse(cx - 52, cy + 54, 17, 11, cream)
	_draw_ellipse(cx + 52, cy + 54, 17, 11, cream)

func _draw_ellipse(ecx: float, ecy: float, rx: float, ry: float, color: Color) -> void:
	var steps := 48
	var pts   := PackedVector2Array()
	var cols  := PackedColorArray()
	for i in range(steps):
		var theta := float(i) / float(steps) * TAU
		pts.append(Vector2(ecx + cos(theta) * rx, ecy + sin(theta) * ry))
		cols.append(color)
	draw_polygon(pts, cols)

func _draw_smile(scx: float, scy: float, color: Color) -> void:
	var pts   := PackedVector2Array()
	var steps := 10
	for i in range(steps + 1):
		var t    := float(i) / float(steps)
		var p0   := Vector2(scx - 9, scy - 3)
		var ctrl := Vector2(scx,     scy + 3)
		var p2   := Vector2(scx + 9, scy - 3)
		pts.append(p0 * (1-t)*(1-t) + ctrl * 2*(1-t)*t + p2 * t*t)
	draw_polyline(pts, color, 2.0)

