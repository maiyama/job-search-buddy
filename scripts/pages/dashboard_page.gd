extends Control

const ACTIVITY_COLORS := {
	"Review": Color("#4A90D9"),
	"Research": Color("#7B886F"),
	"Interview": Color("#BF5700"),
	"Application": Color("#27AE60"),
	"Networking": Color("#E74C3C")
}

var _range_option: OptionButton
var _pie_chart: Control
var _app_count_label: Label
var _interview_count_label: Label
var _company_count_label: Label
var _hours_label: Label
var _recent_list: VBoxContainer
var _dm: Node

func _ready() -> void:
	_dm = get_node("/root/DataManager")
	_build_ui()
	_refresh()
	_dm.connect("data_changed", _refresh)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	vbox.add_child(header_row)

	var title := Label.new()
	title.text = "Dashboard"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#000000"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var range_lbl := Label.new()
	range_lbl.text = "Show:"
	range_lbl.add_theme_color_override("font_color", Color("#665F50"))
	range_lbl.add_theme_font_size_override("font_size", 14)
	header_row.add_child(range_lbl)

	_range_option = OptionButton.new()
	_range_option.add_item("This Week")
	_range_option.add_item("Today")
	_range_option.add_item("This Month")
	_range_option.add_item("All Time")
	_range_option.selected = 0
	_range_option.add_theme_font_size_override("font_size", 14)
	_range_option.item_selected.connect(func(_i: int): _refresh())
	header_row.add_child(_range_option)

	# Content row
	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 20)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_row)

	# Pie chart card
	var chart_card := _make_card()
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(chart_card)

	var chart_vbox := VBoxContainer.new()
	chart_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	chart_vbox.add_theme_constant_override("separation", 8)
	chart_card.add_child(chart_vbox)

	var chart_lbl := Label.new()
	chart_lbl.text = "Activity Breakdown"
	chart_lbl.add_theme_font_size_override("font_size", 16)
	chart_lbl.add_theme_color_override("font_color", Color("#000000"))
	chart_vbox.add_child(chart_lbl)

	_pie_chart = load("res://scripts/components/pie_chart.gd").new() as Control
	_pie_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pie_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_vbox.add_child(_pie_chart)

	# Right column
	var right_col := VBoxContainer.new()
	right_col.custom_minimum_size = Vector2(240, 0)
	right_col.add_theme_constant_override("separation", 16)
	content_row.add_child(right_col)

	# Stats cards
	var stats_lbl := Label.new()
	stats_lbl.text = "Stats"
	stats_lbl.add_theme_font_size_override("font_size", 16)
	stats_lbl.add_theme_color_override("font_color", Color("#000000"))
	right_col.add_child(stats_lbl)

	_app_count_label = _make_stat_card(right_col, "Applications Sent", "0", Color("#27AE60"))
	_interview_count_label = _make_stat_card(right_col, "Interviews", "0", Color("#7B886F"))
	_company_count_label = _make_stat_card(right_col, "Companies Tracked", "0", Color("#BF5700"))
	_hours_label = _make_stat_card(right_col, "Hours Spent", "0.0", Color("#4A90D9"))

	var sep := HSeparator.new()
	right_col.add_child(sep)

	var recent_lbl := Label.new()
	recent_lbl.text = "Recent Activities"
	recent_lbl.add_theme_font_size_override("font_size", 14)
	recent_lbl.add_theme_color_override("font_color", Color("#665F50"))
	right_col.add_child(recent_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)

	_recent_list = VBoxContainer.new()
	_recent_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recent_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_recent_list)

func _refresh() -> void:
	if not is_instance_valid(_pie_chart):
		return
	var range_map: Array[String] = ["Week", "Day", "Month", "All"]
	var range_key: String = range_map[_range_option.selected]
	var activities: Array = _dm.call("get_activities_for_range", range_key) as Array

	_pie_chart.call("set_activities", activities)

	var app_count := 0
	var total_minutes := 0
	for a in activities:
		var a_dict := a as Dictionary
		if a_dict.get("from_apply", false):
			app_count += 1
		total_minutes += _time_diff_minutes(a_dict.get("start_time", ""), a_dict.get("end_time", ""))

	var companies_in_range: Array = _dm.call("get_companies_for_range", range_key) as Array
	var interview_count := companies_in_range.filter(
		func(c: Dictionary) -> bool: return c.get("progress", "") == "In-interview"
	).size()

	_app_count_label.text = str(app_count)
	_interview_count_label.text = str(interview_count)
	_company_count_label.text = str(companies_in_range.size())
	_hours_label.text = "%.1f" % (total_minutes / 60.0)

	# Recent list
	for child in _recent_list.get_children():
		child.queue_free()

	var start: int = maxi(0, activities.size() - 8)
	var recent: Array = activities.slice(start, activities.size())
	recent.reverse()
	for a in recent:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_recent_list.add_child(row)

		var a_dict := a as Dictionary
		var a_type: String = a_dict.get("type", "Review")
		var a_text: String = a_dict.get("text", "")

		var badge := Label.new()
		badge.text = a_type.left(3).to_upper()
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.custom_minimum_size = Vector2(34, 0)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = ACTIVITY_COLORS.get(a_type, Color.GRAY)
		badge_style.set_corner_radius_all(4)
		badge_style.content_margin_left = 4
		badge_style.content_margin_right = 4
		badge_style.content_margin_top = 3
		badge_style.content_margin_bottom = 3
		badge.add_theme_stylebox_override("normal", badge_style)
		row.add_child(badge)

		var text_lbl := Label.new()
		text_lbl.text = a_text.left(40) + ("..." if a_text.length() > 40 else "")
		text_lbl.add_theme_font_size_override("font_size", 12)
		text_lbl.add_theme_color_override("font_color", Color("#333344"))
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_lbl.clip_text = true
		row.add_child(text_lbl)

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.06)
	style.shadow_size = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	return card

func _make_stat_card(parent: Node, label: String, value: String, color: Color) -> Label:
	var card := _make_card()
	card.custom_minimum_size = Vector2(0, 72)
	parent.add_child(card)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	card.add_child(inner)

	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(6, 60)
	inner.add_child(dot)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(text_col)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("#887766"))
	text_col.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 28)
	val_lbl.add_theme_color_override("font_color", Color("#000000"))
	text_col.add_child(val_lbl)

	return val_lbl

func _time_diff_minutes(from_str: String, to_str: String) -> int:
	if from_str.is_empty() or to_str.is_empty():
		return 0
	var fp := from_str.split(":")
	var tp := to_str.split(":")
	if fp.size() != 2 or tp.size() != 2:
		return 0
	var diff := (int(tp[0]) * 60 + int(tp[1])) - (int(fp[0]) * 60 + int(fp[1]))
	return maxi(diff, 0)
