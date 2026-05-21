extends Control

const ACTIVITY_COLORS := {
	"Review": Color("#4A90D9"),
	"Research": Color("#7B886F"),
	"Interview": Color("#BF5700"),
	"Application": Color("#27AE60"),
	"Networking": Color("#E74C3C")
}

var _segments: Array = []

func set_activities(activities: Array) -> void:
	var minutes: Dictionary = {}
	for a in activities:
		var t: String = a.get("type", "Review")
		var m := _time_diff_minutes(a.get("start_time", ""), a.get("end_time", ""))
		minutes[t] = minutes.get(t, 0) + m

	_segments = []
	for type in ["Review", "Research", "Interview", "Application", "Networking"]:
		if minutes.get(type, 0) > 0:
			_segments.append({
				"label": type,
				"value": float(minutes[type]),
				"color": ACTIVITY_COLORS[type]
			})
	queue_redraw()

func _time_diff_minutes(from_str: String, to_str: String) -> int:
	if from_str.is_empty() or to_str.is_empty():
		return 0
	var fp := from_str.split(":")
	var tp := to_str.split(":")
	if fp.size() != 2 or tp.size() != 2:
		return 0
	var diff := (int(tp[0]) * 60 + int(tp[1])) - (int(fp[0]) * 60 + int(fp[1]))
	return maxi(diff, 0)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 13

	if _segments.is_empty():
		var center := size / 2.0
		var r: float = minf(size.x, size.y) * 0.35
		draw_arc(center, r, 0, TAU, 64, Color("#E2E6DF"), r, true)
		draw_string(font, center + Vector2(-40, 6), "No data yet",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#887766"))
		return

	var total := 0.0
	for s in _segments:
		total += s.value

	# Pie chart area (left 60% of control)
	var chart_area_w := size.x * 0.58
	var center := Vector2(chart_area_w / 2.0, size.y / 2.0)
	var radius: float = minf(chart_area_w, size.y) * 0.42

	var start := -PI / 2.0
	for s in _segments:
		var sweep: float = (s.value / total) * TAU
		_draw_segment(center, radius, start, sweep, s.color)
		start += sweep

	# Legend (right 40%)
	var lx := chart_area_w + 16.0
	var ly := (size.y - _segments.size() * 28.0) / 2.0
	for i in _segments.size():
		var s: Dictionary = _segments[i]
		var row_y := ly + i * 28.0
		draw_rect(Rect2(lx, row_y + 1, 14, 14), s.color, true)
		var pct := int(s.value / total * 100.0)
		var h := int(s.value) / 60
		var m := int(s.value) % 60
		var time_str: String = ("%dh %dm" % [h, m]) if h > 0 else ("%dm" % m)
		draw_string(font, Vector2(lx + 22, row_y + 13),
				"%s: %s (%d%%)" % [s.label, time_str, pct],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#333344"))

func _draw_segment(center: Vector2, radius: float, start: float, sweep: float, color: Color) -> void:
	if sweep <= 0.001:
		return
	var steps: int = maxi(6, int(sweep * 18))
	var pts := PackedVector2Array()
	pts.append(center)
	for i in steps + 1:
		var angle := start + sweep * float(i) / float(steps)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var colors := PackedColorArray()
	colors.resize(pts.size())
	colors.fill(color)
	draw_polygon(pts, colors)
	# White border lines
	draw_line(center, pts[1], Color.WHITE, 1.5)
	draw_line(center, pts[pts.size() - 1], Color.WHITE, 1.5)
