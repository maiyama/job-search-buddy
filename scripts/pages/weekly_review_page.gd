extends Control

var _feelings_input: TextEdit
var _wins_input: TextEdit
var _ofps_input: TextEdit
var _submit_btn: Button
var _table_list: VBoxContainer
var _empty_label: Label
var _buddy_display: Control
var _buddy_msg: Label
var _dm: Node
var _as: Node

var _pending_feelings_raw := ""
var _pending_wins_raw := ""
var _pending_ofps_raw := ""

func _ready() -> void:
	_dm = get_node("/root/DataManager")
	_as = get_node("/root/AIService")
	_build_ui()
	_prefill_if_same_week()
	_refresh_table()
	_as.connect("weekly_review_ready", _on_review_ready)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)

	# ── Left panel ──
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	hbox.add_child(left)

	var title := Label.new()
	title.text = "Weekly Review"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#000000"))
	left.add_child(title)

	_feelings_input = _make_input_section(left, "How did this week feel? *", "Share your feelings about this week...")
	_wins_input = _make_input_section(left, "What were your wins?", "What went well? (optional)")
	_ofps_input = _make_input_section(left, "What could be better?", "Opportunities for improvement... (optional)")

	_feelings_input.text_changed.connect(_update_submit_state)

	_submit_btn = Button.new()
	_submit_btn.text = "Save & Reflect"
	_submit_btn.custom_minimum_size = Vector2(160, 44)
	_submit_btn.disabled = true
	_style_primary_button(_submit_btn)
	_submit_btn.pressed.connect(_on_submit)
	left.add_child(_submit_btn)

	left.add_child(HSeparator.new())

	# Table header
	var header_card := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color("#E8EDE4")
	hs.set_corner_radius_all(8)
	hs.content_margin_left = 12; hs.content_margin_right = 12
	hs.content_margin_top = 8; hs.content_margin_bottom = 8
	header_card.add_theme_stylebox_override("panel", hs)
	left.add_child(header_card)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_card.add_child(header_row)
	_make_col_header("Week", header_row, 1)
	_make_col_header("Feelings", header_row, 2)
	_make_col_header("Wins", header_row, 2)
	_make_col_header("OFPs", header_row, 2)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)

	_table_list = VBoxContainer.new()
	_table_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_table_list)

	_empty_label = Label.new()
	_empty_label.text = "No reviews yet.\nSave your first weekly review above! 📓"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", Color("#887766"))
	_empty_label.add_theme_font_size_override("font_size", 15)
	left.add_child(_empty_label)

	# ── Right panel ──
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(248, 0)
	right.add_theme_constant_override("separation", 12)
	hbox.add_child(right)

	var buddy_bg := PanelContainer.new()
	var bb_style := StyleBoxFlat.new()
	bb_style.bg_color = Color("#7B886F")
	bb_style.set_corner_radius_all(16)
	bb_style.content_margin_left = 8; bb_style.content_margin_right = 8
	bb_style.content_margin_top = 8; bb_style.content_margin_bottom = 8
	buddy_bg.add_theme_stylebox_override("panel", bb_style)
	right.add_child(buddy_bg)

	_buddy_display = load("res://scripts/components/buddy_display.gd").new() as Control
	buddy_bg.add_child(_buddy_display)

	var momo_lbl := Label.new()
	momo_lbl.text = "Momo says..."
	momo_lbl.add_theme_font_size_override("font_size", 13)
	momo_lbl.add_theme_color_override("font_color", Color("#888899"))
	right.add_child(momo_lbl)

	_buddy_msg = Label.new()
	_buddy_msg.text = "Reflect on your week and I'll share my thoughts! 🦭"
	_buddy_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buddy_msg.add_theme_color_override("font_color", Color("#333344"))
	_buddy_msg.add_theme_font_size_override("font_size", 13)
	right.add_child(_buddy_msg)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_input_section(parent: VBoxContainer, label_text: String, placeholder: String) -> TextEdit:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color("#000000"))
	parent.add_child(lbl)

	var te := TextEdit.new()
	te.placeholder_text = placeholder
	te.custom_minimum_size = Vector2(0, 60)
	_style_text_edit(te)
	parent.add_child(te)
	return te

func _update_submit_state() -> void:
	_submit_btn.disabled = _feelings_input.text.strip_edges().is_empty()

func _prefill_if_same_week() -> void:
	var review: Dictionary = _dm.call("get_this_week_review") as Dictionary
	if review.is_empty():
		return
	_feelings_input.text = review.get("feelings_raw", "")
	_wins_input.text = review.get("wins_raw", "")
	_ofps_input.text = review.get("ofps_raw", "")
	_update_submit_state()

func _on_submit() -> void:
	var feelings := _feelings_input.text.strip_edges()
	if feelings.is_empty():
		return
	_pending_feelings_raw = feelings
	_pending_wins_raw = _wins_input.text.strip_edges()
	_pending_ofps_raw = _ofps_input.text.strip_edges()
	_submit_btn.disabled = true
	_submit_btn.text = "Reflecting..."
	_as.call("process_weekly_review", _pending_feelings_raw, _pending_wins_raw, _pending_ofps_raw)

func _on_review_ready(feelings: String, wins: String, ofps: String, encouragement: String) -> void:
	var review := {
		"monday": str(_dm.call("get_this_week_monday")),
		"feelings_raw": _pending_feelings_raw,
		"wins_raw": _pending_wins_raw,
		"ofps_raw": _pending_ofps_raw,
		"feelings": feelings,
		"wins": wins,
		"ofps": ofps
	}
	_dm.call("save_week_review", review)
	_buddy_display.call("set_message", encouragement)
	_buddy_msg.text = encouragement
	_refresh_table()
	_submit_btn.disabled = false
	_submit_btn.text = "Save & Reflect"

func _refresh_table() -> void:
	if not is_instance_valid(_table_list):
		return
	for child in _table_list.get_children():
		child.queue_free()

	var reviews: Array = _dm.call("get_all_week_reviews") as Array
	_empty_label.visible = reviews.is_empty()

	for review in reviews:
		var monday_str: String = review.get("monday", "")
		var week_label: String = str(_dm.call("week_label_from_monday", monday_str))

		var row_card := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color.WHITE
		rs.set_corner_radius_all(8)
		rs.shadow_color = Color(0, 0, 0, 0.04)
		rs.shadow_size = 2
		rs.content_margin_left = 12; rs.content_margin_right = 12
		rs.content_margin_top = 8; rs.content_margin_bottom = 8
		row_card.add_theme_stylebox_override("panel", rs)
		_table_list.add_child(row_card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_card.add_child(row)

		_make_cell(week_label, row, 1, true)
		_make_cell(review.get("feelings", ""), row, 2, false)
		_make_cell(review.get("wins", ""), row, 2, false)
		_make_cell(review.get("ofps", ""), row, 2, false)

func _make_col_header(text: String, parent: Node, stretch: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#665F50"))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = stretch
	parent.add_child(lbl)

func _make_cell(text: String, parent: Node, stretch: int, bold: bool) -> void:
	var lbl := Label.new()
	lbl.text = text if not text.is_empty() else "—"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#000000") if bold else Color("#44443A"))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = stretch
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)

# ── Style helpers ─────────────────────────────────────────────────────────────

func _style_text_edit(te: TextEdit) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.WHITE
	s.border_color = Color("#C0C9BA")
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 10; s.content_margin_bottom = 10
	te.add_theme_stylebox_override("normal", s)
	te.add_theme_color_override("font_color", Color("#000000"))
	te.add_theme_font_size_override("font_size", 14)

func _style_primary_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#BF5700")
	n.set_corner_radius_all(10)
	n.content_margin_left = 16; n.content_margin_right = 16
	n.content_margin_top = 10; n.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat; h.bg_color = Color("#A34A00")
	btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat; p.bg_color = Color("#8C3F00")
	btn.add_theme_stylebox_override("pressed", p)
	var d := n.duplicate() as StyleBoxFlat; d.bg_color = Color("#B0AFA8")
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
