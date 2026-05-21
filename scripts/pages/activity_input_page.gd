extends Control

signal end_of_day_triggered
signal edit_goals_requested
signal edit_weekly_goals_requested

var _activity_input: TextEdit
var _time_from: LineEdit
var _time_to: LineEdit
var _todo_container: VBoxContainer
var _weekly_goal_container: VBoxContainer
var _buddy_display: Control
var _buddy_scroll: ScrollContainer
var _buddy_messages: VBoxContainer
var _log_button: Button
var _dm: Node
var _as: Node

var _pending_text := ""
var _pending_from := ""
var _pending_to := ""
var _pending_mode := ""  # "", "apply", "update"
var _preserve_input := false

func _ready() -> void:
	_dm = get_node("/root/DataManager")
	_as = get_node("/root/AIService")
	_build_ui()
	_load_todos()
	_load_weekly_goals()
	_as.connect("response_ready", _on_buddy_response)
	_as.connect("categorization_ready", _on_activity_analyzed)

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
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	hbox.add_child(left_scroll)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	left_scroll.add_child(left)

	var header := Label.new()
	header.text = "What did you work on?"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color("#000000"))
	left.add_child(header)

	_activity_input = TextEdit.new()
	_activity_input.placeholder_text = "e.g., Researched companies... | [apply] Applied to Stripe for PM | [update] Company X sent a rejection email"
	_activity_input.custom_minimum_size = Vector2(0, 64)
	_style_text_edit(_activity_input)
	left.add_child(_activity_input)

	# Time row
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	left.add_child(time_row)

	_make_label("From:", time_row, Color("#665F50"))
	_time_from = LineEdit.new()
	_time_from.placeholder_text = "HH:MM"
	_time_from.custom_minimum_size = Vector2(60, 0)
	_time_from.text = _current_time()
	_style_line_edit(_time_from)
	time_row.add_child(_time_from)

	_make_label("To:", time_row, Color("#665F50"))
	_time_to = LineEdit.new()
	_time_to.placeholder_text = "HH:MM"
	_time_to.custom_minimum_size = Vector2(60, 0)
	_time_to.text = _current_time()
	_style_line_edit(_time_to)
	time_row.add_child(_time_to)

	var now_btn := Button.new()
	now_btn.text = "Now"
	_style_secondary_button(now_btn)
	now_btn.pressed.connect(func(): _time_to.text = _current_time())
	time_row.add_child(now_btn)

	var ts := Control.new()
	ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(ts)

	_log_button = Button.new()
	_log_button.text = "Log Activity"
	_log_button.custom_minimum_size = Vector2(140, 44)
	_style_primary_button(_log_button)
	_log_button.pressed.connect(_on_log_pressed)
	left.add_child(_log_button)

	left.add_child(HSeparator.new())

	# Todo section
	var todo_row := HBoxContainer.new()
	todo_row.add_theme_constant_override("separation", 8)
	left.add_child(todo_row)

	var todo_hdr := Label.new()
	todo_hdr.text = "Today's Goals"
	todo_hdr.add_theme_font_size_override("font_size", 17)
	todo_hdr.add_theme_color_override("font_color", Color("#000000"))
	todo_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	todo_row.add_child(todo_hdr)

	var edit_goals_btn := Button.new()
	edit_goals_btn.text = "✏ Edit"
	_style_secondary_button(edit_goals_btn)
	edit_goals_btn.pressed.connect(func(): edit_goals_requested.emit())
	todo_row.add_child(edit_goals_btn)

	_todo_container = VBoxContainer.new()
	_todo_container.add_theme_constant_override("separation", 6)
	left.add_child(_todo_container)

	left.add_child(HSeparator.new())

	# Weekly goals section
	var weekly_row := HBoxContainer.new()
	weekly_row.add_theme_constant_override("separation", 8)
	left.add_child(weekly_row)

	var weekly_hdr := Label.new()
	weekly_hdr.text = "This Week's Goals"
	weekly_hdr.add_theme_font_size_override("font_size", 17)
	weekly_hdr.add_theme_color_override("font_color", Color("#000000"))
	weekly_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weekly_row.add_child(weekly_hdr)

	var edit_weekly_btn := Button.new()
	edit_weekly_btn.text = "✏ Edit"
	_style_secondary_button(edit_weekly_btn)
	edit_weekly_btn.pressed.connect(func(): edit_weekly_goals_requested.emit())
	weekly_row.add_child(edit_weekly_btn)

	_weekly_goal_container = VBoxContainer.new()
	_weekly_goal_container.add_theme_constant_override("separation", 6)
	left.add_child(_weekly_goal_container)

	# ── Right panel ──
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(200, 0)
	right.add_theme_constant_override("separation", 12)
	hbox.add_child(right)

	var buddy_bg := PanelContainer.new()
	var bb_style := StyleBoxFlat.new()
	bb_style.bg_color = Color("#7B886F")
	bb_style.set_corner_radius_all(16)
	bb_style.content_margin_left = 8
	bb_style.content_margin_right = 8
	bb_style.content_margin_top = 8
	bb_style.content_margin_bottom = 8
	buddy_bg.add_theme_stylebox_override("panel", bb_style)
	right.add_child(buddy_bg)

	_buddy_display = load("res://scripts/components/buddy_display.gd").new() as Control
	buddy_bg.add_child(_buddy_display)

	var history_lbl := Label.new()
	history_lbl.text = "Momo says..."
	history_lbl.add_theme_font_size_override("font_size", 13)
	history_lbl.add_theme_color_override("font_color", Color("#888899"))
	right.add_child(history_lbl)

	_buddy_scroll = ScrollContainer.new()
	_buddy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buddy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_buddy_scroll)

	_buddy_messages = VBoxContainer.new()
	_buddy_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buddy_messages.add_theme_constant_override("separation", 8)
	_buddy_scroll.add_child(_buddy_messages)

func _load_todos() -> void:
	if not is_instance_valid(_todo_container):
		return
	for child in _todo_container.get_children():
		child.queue_free()

	var todos: Array = _dm.call("get_today_todos") as Array
	if todos.is_empty():
		var lbl := Label.new()
		lbl.text = "Share your goals for today with Momo at the start of the day! 💪"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color("#888899"))
		lbl.add_theme_font_size_override("font_size", 13)
		_todo_container.add_child(lbl)
		return

	for i in todos.size():
		var todo: Dictionary = todos[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_todo_container.add_child(row)

		var cb := CheckBox.new()
		cb.button_pressed = todo.get("done", false)

		var is_done: bool = todo.get("done", false)
		var lbl := Label.new()
		lbl.text = todo.get("text", "")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color("#888899") if is_done else Color("#000000"))
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP

		var idx := i
		cb.toggled.connect(func(pressed: bool) -> void:
			var t: Array = _dm.call("get_today_todos") as Array
			if idx < t.size():
				t[idx]["done"] = pressed
				_dm.call("set_today_todos", t)
			lbl.add_theme_color_override("font_color", Color("#888899") if pressed else Color("#000000"))
			if bool(_dm.call("all_todos_done")):
				_on_all_todos_done.call_deferred()
		)
		lbl.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				cb.button_pressed = !cb.button_pressed
		)
		row.add_child(cb)
		row.add_child(lbl)

func _on_all_todos_done() -> void:
	_as.call("get_buddy_response", "", "all_done")
	var confetti: Node = load("res://scripts/components/confetti_effect.gd").new()
	get_tree().root.add_child(confetti)

func _on_log_pressed() -> void:
	var text := _activity_input.text.strip_edges()
	if text.is_empty():
		return
	if text.to_lower() == "review":
		end_of_day_triggered.emit()
		_activity_input.text = ""
		return

	_pending_mode = ""
	var lower := text.to_lower()
	var clean := text
	if lower.begins_with("[apply]"):
		_pending_mode = "apply"
		clean = text.substr(7).strip_edges()
	elif lower.begins_with("[update]"):
		_pending_mode = "update"
		clean = text.substr(8).strip_edges()

	_log_button.disabled = true
	_log_button.text = "Logging..."
	_pending_text = clean
	_pending_from = _time_from.text
	_pending_to = _time_to.text
	_as.call("analyze_activity", clean)

func _on_activity_analyzed(activity_type: String, company: String, role: String, contacts: String) -> void:
	if _pending_mode == "apply":
		_dm.call("add_activity", _pending_text, "Application", _pending_from, _pending_to, true)
		if not company.is_empty():
			_dm.call("add_or_update_company", company, role, contacts)
			var label := company + (" (%s)" % role if not role.is_empty() else "")
			_on_buddy_response("%s added to your Companies table." % label)
		else:
			_on_buddy_response("Application logged. Mention the company name so it appears in your Companies table.")

	elif _pending_mode == "update":
		var new_progress := _determine_progress_from_text(_pending_text)
		var target := company if not company.is_empty() else _find_company_in_text(_pending_text)
		if target.is_empty():
			_preserve_input = true
			_on_buddy_response("Mention the company name to update its progress.")
		elif new_progress.is_empty():
			_preserve_input = true
			_on_buddy_response("Couldn't determine the new status — try mentioning rejection, offer, or interview.")
		else:
			var matched: String = str(_dm.call("update_company_progress_by_name", target, new_progress))
			if not matched.is_empty():
				_add_history("%s updated to '%s'." % [matched, new_progress])
				if new_progress == "Gone":
					_as.call("get_buddy_response", _pending_text, "gone")
				elif new_progress == "Offer":
					_as.call("get_buddy_response", _pending_text, "offer_received at " + matched)
				elif new_progress == "In-interview":
					_as.call("get_buddy_response", _pending_text, "interview_scheduled at " + matched)
				else:
					_buddy_display.call("set_message", "%s updated to '%s'." % [matched, new_progress])
			else:
				_on_buddy_response("Couldn't find %s in your Companies table. Check the spelling and try again." % target)

	else:
		_dm.call("add_activity", _pending_text, activity_type, _pending_from, _pending_to)

		var lower := _pending_text.to_lower()
		var is_interview := activity_type == "Interview"
		var is_offer := "offer" in lower and ("receiv" in lower or "got" in lower or "accepted" in lower or "signing" in lower)

		if is_offer:
			_as.call("get_buddy_response", _pending_text, "offer_received" + (" at " + company if not company.is_empty() else ""))
		elif is_interview:
			_as.call("get_buddy_response", _pending_text, "interview_scheduled" + (" at " + company if not company.is_empty() else ""))
		else:
			_on_buddy_response("%s activity logged. See your Dashboard for the breakdown." % activity_type)

	_pending_mode = ""
	_time_from.text = _pending_to
	_time_to.text = _current_time()
	if not _preserve_input:
		_activity_input.text = ""
	else:
		_activity_input.text = "[update] " + _pending_text
	_preserve_input = false
	_log_button.disabled = false
	_log_button.text = "Log Activity"

func _determine_progress_from_text(text: String) -> String:
	var lower := text.to_lower()
	if "offer" in lower and ("decline" in lower or "not accept" in lower or "turn down" in lower or "turning down" in lower):
		return "Offer declined"
	if "reject" in lower or "not moving forward" in lower or "not selected" in lower or "no longer" in lower or "passed on" in lower or "went with someone" in lower:
		return "Gone"
	if "offer" in lower:
		return "Offer"
	if "interview" in lower:
		return "In-interview"
	return ""

func _find_company_in_text(text: String) -> String:
	var lower := text.to_lower()
	var companies: Array = _dm.call("get_companies") as Array
	for c in companies:
		if (c.name as String).to_lower() in lower:
			return c.name
	return ""

func _on_buddy_response(text: String) -> void:
	_buddy_display.call("set_message", text)
	_add_history(text)

func _add_history(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = false
	lbl.text = "🦭 " + text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.fit_content = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("normal_font_size", 12)
	lbl.add_theme_color_override("default_color", Color("#333344"))
	_buddy_messages.add_child(lbl)
	await get_tree().process_frame
	_buddy_scroll.scroll_vertical = int(_buddy_scroll.get_v_scroll_bar().max_value)

func _load_weekly_goals() -> void:
	if not is_instance_valid(_weekly_goal_container):
		return
	for child in _weekly_goal_container.get_children():
		child.queue_free()

	var goals: Array = _dm.call("get_this_week_goals") as Array
	if goals.is_empty():
		var lbl := Label.new()
		lbl.text = "Set your goals for this week with Momo! 🌱"
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color("#888899"))
		lbl.add_theme_font_size_override("font_size", 13)
		_weekly_goal_container.add_child(lbl)
		return

	for i in goals.size():
		var goal: Dictionary = goals[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_weekly_goal_container.add_child(row)

		var cb := CheckBox.new()
		cb.button_pressed = goal.get("done", false)

		var is_done: bool = goal.get("done", false)
		var lbl := Label.new()
		lbl.text = goal.get("text", "")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color("#888899") if is_done else Color("#000000"))
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP

		var idx := i
		cb.toggled.connect(func(pressed: bool) -> void:
			var g: Array = _dm.call("get_this_week_goals") as Array
			if idx < g.size():
				g[idx]["done"] = pressed
				_dm.call("set_this_week_goals", g)
			lbl.add_theme_color_override("font_color", Color("#888899") if pressed else Color("#000000"))
		)
		lbl.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				cb.button_pressed = !cb.button_pressed
		)
		row.add_child(cb)
		row.add_child(lbl)

func set_todos(_todos: Array) -> void:
	_load_todos()

func set_weekly_goals(_goals: Array) -> void:
	_load_weekly_goals()

func get_buddy_display() -> Control:
	return _buddy_display

# ── Time helpers ──────────────────────────────────────────────────────────────

func _current_time() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%02d:%02d" % [dt.hour, dt.minute]

# ── Style helpers ─────────────────────────────────────────────────────────────

func _make_label(text: String, parent: Node, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 14)
	parent.add_child(lbl)
	return lbl

func _style_text_edit(te: TextEdit) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.WHITE
	s.border_color = Color("#C0C9BA")
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	te.add_theme_stylebox_override("normal", s)
	te.add_theme_color_override("font_color", Color("#000000"))
	te.add_theme_font_size_override("font_size", 14)

func _style_line_edit(le: LineEdit) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.WHITE
	s.border_color = Color("#C0C9BA")
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	le.add_theme_stylebox_override("normal", s)
	le.add_theme_color_override("font_color", Color("#000000"))
	le.add_theme_font_size_override("font_size", 14)

func _style_primary_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#BF5700")
	n.set_corner_radius_all(10)
	n.content_margin_left = 16; n.content_margin_right = 16
	n.content_margin_top = 10; n.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color("#A34A00"); btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color("#8C3F00"); btn.add_theme_stylebox_override("pressed", p)
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = Color("#B0AFA8"); btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)

func _style_secondary_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#E8EDE4")
	n.set_corner_radius_all(8)
	n.content_margin_left = 12; n.content_margin_right = 12
	n.content_margin_top = 8; n.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color("#C0C9BA"); btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color("#BF5700"))
	btn.add_theme_font_size_override("font_size", 14)
