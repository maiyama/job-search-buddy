extends Control

var _content_area: Control
var _nav_buttons: Dictionary = {}
var _current_page_id := ""
var _current_page: Control = null
var _overlay: Control = null
var _dm: Node
var _as: Node

func _ready() -> void:
	_dm = get_node("/root/DataManager")
	_as = get_node("/root/AIService")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()

	_as.connect("response_ready", _on_ai_response_for_dialog)
	_dm.connect("data_changed", _on_data_changed)

	if not bool(_dm.call("get_first_session_done")):
		_navigate_to("activity_input")
		await get_tree().process_frame
		_show_first_session()
	elif bool(_dm.call("is_new_day")):
		_navigate_to("activity_input")
		await get_tree().process_frame
		_show_daily_greeting()
	else:
		_navigate_to("activity_input")

# ── Layout ────────────────────────────────────────────────────────────────────

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#F3F1EE")
	add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	hbox.add_child(_build_sidebar())

	_content_area = Control.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_content_area)

func _build_sidebar() -> Control:
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(206, 0)
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color("#E8EDE4")
	ss.border_color = Color("#C0C9BA")
	ss.border_width_right = 1
	sidebar.add_theme_stylebox_override("panel", ss)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	sidebar.add_child(vbox)

	# Header
	var header := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color("#BF5700")
	hs.content_margin_left = 12; hs.content_margin_right = 12
	hs.content_margin_top = 14; hs.content_margin_bottom = 14
	header.add_theme_stylebox_override("panel", hs)
	vbox.add_child(header)

	var hvbox := VBoxContainer.new()
	hvbox.add_theme_constant_override("separation", 2)
	header.add_child(hvbox)

	var title := Label.new()
	title.text = "Job Search Buddy"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hvbox.add_child(title)

	var sub := Label.new()
	sub.text = "with %s 🦭" % AIService.get_buddy_name()
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hvbox.add_child(sub)

	# Spacing
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 8); vbox.add_child(sp)

	# Nav items
	for item in [
		{"id": "activity_input", "icon": "📝", "label": "Activity Input"},
		{"id": "dashboard", "icon": "📊", "label": "Dashboard"},
		{"id": "companies", "icon": "🏢", "label": "Companies"},
		{"id": "weekly_review", "icon": "📓", "label": "Weekly Review"}
	]:
		var btn := Button.new()
		btn.text = "  %s  %s" % [item.icon, item.label]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 46)
		_apply_nav_style(btn, false)
		btn.pressed.connect(_navigate_to.bind(item.id))
		vbox.add_child(btn)
		_nav_buttons[item.id] = btn

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# API settings
	var api_btn := Button.new()
	api_btn.text = "  ⚙  API Settings"
	api_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	api_btn.custom_minimum_size = Vector2(0, 40)
	api_btn.flat = true
	_apply_nav_style(api_btn, false)
	api_btn.pressed.connect(_show_api_settings)
	vbox.add_child(api_btn)

	# API key indicator
	var api_status := Label.new()
	api_status.name = "APIStatus"
	api_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	api_status.add_theme_font_size_override("font_size", 11)
	_update_api_status_label(api_status)
	vbox.add_child(api_status)

	var sp2 := Control.new(); sp2.custom_minimum_size = Vector2(0, 6); vbox.add_child(sp2)

	return sidebar

func _update_api_status_label(lbl: Label) -> void:
	if str(_dm.call("get_api_key")).is_empty():
		lbl.text = "● AI offline"
		lbl.add_theme_color_override("font_color", Color("#E74C3C"))
	else:
		lbl.text = "● AI online"
		lbl.add_theme_color_override("font_color", Color("#27AE60"))

# ── Navigation ────────────────────────────────────────────────────────────────

func _navigate_to(page_id: String) -> void:
	if _current_page_id == page_id and _current_page != null:
		return

	if is_instance_valid(_current_page):
		_current_page.queue_free()
		_current_page = null

	for id in _nav_buttons:
		_apply_nav_style(_nav_buttons[id], id == page_id)

	_current_page_id = page_id

	var page: Control = null
	match page_id:
		"activity_input":
			page = load("res://scripts/pages/activity_input_page.gd").new()
			page.connect("end_of_day_triggered", _show_end_of_day_dialog)
			page.connect("edit_goals_requested", _show_edit_goals_dialog)
			page.connect("edit_weekly_goals_requested", _show_edit_weekly_goals_dialog)
		"dashboard":
			page = load("res://scripts/pages/dashboard_page.gd").new()
		"companies":
			page = load("res://scripts/pages/companies_page.gd").new()
		"weekly_review":
			page = load("res://scripts/pages/weekly_review_page.gd").new()

	if page == null:
		return

	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(page)
	_current_page = page

# ── Dialogs ───────────────────────────────────────────────────────────────────

var _dialog_submit_callback: Callable
var _dialog_input_ref: LineEdit
var _waiting_for_encouragement := false

func _show_first_session() -> void:
	_dialog_submit_callback = func(user_name: String) -> void:
		if user_name.strip_edges().is_empty():
			return
		_dm.call("set_user_name", user_name)
		_dm.call("mark_greeted")
		_close_overlay()
		_show_welcome(user_name)
	var bname := AIService.get_buddy_name()
	_show_dialog(
		"Hi! I'm %s! 🦭" % bname,
		"Hi! I'm %s. I'm your job search buddy.\n\nCould you tell me your name?" % bname,
		"Your name"
	)

func _show_welcome(user_name: String) -> void:
	_dialog_submit_callback = func(_text: String) -> void:
		_close_overlay()
		_show_daily_greeting()
	_show_dialog(
		"Nice to meet you, %s! 💗" % user_name,
		"I'll be cheering you on every step of the way.\n\nLet's start by setting your to-dos for today!",
		"",
		false
	)

func _show_daily_greeting() -> void:
	var user_name: String = str(_dm.call("get_user_name_val"))
	var greeting := "Good day, %s! 🌟" % user_name if not user_name.is_empty() else "Good day! 🌟"
	_dialog_submit_callback = func(text: String) -> void:
		_close_overlay()
		_dm.call("mark_greeted")
		_parse_and_save_todos(text)
		if bool(_dm.call("is_new_week_monday")):
			_show_weekly_goals_dialog()
	_show_dialog(
		greeting,
		"What are the top 1-2 things you want to accomplish today?\nBe specific!",
		"e.g., Apply to 3 companies, Reach out to Stephanie"
	)

func _show_end_of_day_dialog() -> void:
	_dialog_submit_callback = func(feeling: String) -> void:
		_close_overlay()
		if not feeling.strip_edges().is_empty():
			_waiting_for_encouragement = true
			_as.call("get_encouragement", feeling)
	_show_dialog(
		"Another day done! 🌙",
		"Another day done! How do you feel?",
		"Share your feelings..."
	)

func _show_edit_goals_dialog() -> void:
	var existing: Array = _dm.call("get_today_todos") as Array
	var prefill := ""
	if not existing.is_empty():
		var parts: Array[String] = []
		for t in existing:
			var txt: String = (t as Dictionary).get("text", "")
			if not txt.is_empty():
				parts.append(txt)
		prefill = ", ".join(parts)
	_dialog_submit_callback = func(text: String) -> void:
		_close_overlay()
		_parse_and_save_todos(text)
	_show_dialog(
		"Edit Today's To-Dos ✏",
		"Update your to-dos for today. Up to 2, separated by a comma.",
		prefill if not prefill.is_empty() else "e.g., Apply to 3 companies, Reach out to a contact"
	)

func _show_weekly_goals_dialog() -> void:
	_dialog_submit_callback = func(text: String) -> void:
		_close_overlay()
		_dm.call("mark_week_prompted")
		_parse_and_save_weekly_goals(text)
	_show_dialog(
		"New Week, New To-Dos! 🌱",
		"It's a new week! What are your to-dos for this week?\nSeparate multiple to-dos with a comma.",
		"e.g., Land 2 interviews, Expand my network"
	)

func _show_edit_weekly_goals_dialog() -> void:
	var existing: Array = _dm.call("get_this_week_goals") as Array
	var prefill := ""
	if not existing.is_empty():
		var parts: Array[String] = []
		for g in existing:
			var txt: String = (g as Dictionary).get("text", "")
			if not txt.is_empty():
				parts.append(txt)
		prefill = ", ".join(parts)
	_dialog_submit_callback = func(text: String) -> void:
		_close_overlay()
		_parse_and_save_weekly_goals(text)
	_show_dialog(
		"Edit This Week's To-Dos ✏",
		"Update your to-dos for this week. Separate multiple to-dos with a comma.",
		prefill if not prefill.is_empty() else "e.g., Land 2 interviews, Expand my network"
	)

func _show_api_settings() -> void:
	_dialog_submit_callback = func(key: String) -> void:
		_dm.call("set_api_key", key)
		_close_overlay()
		var status := _find_api_status_label()
		if status:
			_update_api_status_label(status)
	var current_key: String = str(_dm.call("get_api_key"))
	_show_dialog(
		"⚙  API Settings",
		"Enter your Anthropic API key to enable AI-powered buddy responses.\n\nGet one at console.anthropic.com",
		current_key if not current_key.is_empty() else "sk-ant-...",
		true,
		true
	)

func _show_dialog(title: String, message: String, placeholder: String, has_input: bool = true, is_secret: bool = false) -> void:
	_close_overlay()

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 50
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.1, 0.08, 0.04, 0.55)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(440, 0)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color.WHITE
	ds.set_corner_radius_all(18)
	ds.shadow_color = Color(0.1, 0.05, 0.0, 0.18)
	ds.shadow_size = 12
	ds.shadow_offset = Vector2(0, 4)
	ds.content_margin_left = 28; ds.content_margin_right = 28
	ds.content_margin_top = 28; ds.content_margin_bottom = 28
	dialog.add_theme_stylebox_override("panel", ds)
	center.add_child(dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	dialog.add_child(vbox)

	# Momo emoji header
	var momo_lbl := Label.new()
	momo_lbl.text = "🦭"
	momo_lbl.add_theme_font_size_override("font_size", 40)
	momo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(momo_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color("#BF5700"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_font_size_override("font_size", 14)
	msg_lbl.add_theme_color_override("font_color", Color("#44443A"))
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_lbl)

	if has_input:
		var input := LineEdit.new()
		input.placeholder_text = placeholder
		input.custom_minimum_size = Vector2(0, 44)
		var stored_key: String = str(_dm.call("get_api_key"))
		if is_secret and not stored_key.is_empty():
			input.text = stored_key
		input.add_theme_font_size_override("font_size", 14)
		var ist := StyleBoxFlat.new()
		ist.bg_color = Color("#F5F2ED")
		ist.border_color = Color("#C0C9BA")
		ist.set_border_width_all(2)
		ist.set_corner_radius_all(10)
		ist.content_margin_left = 12; ist.content_margin_right = 12
		ist.content_margin_top = 8; ist.content_margin_bottom = 8
		input.add_theme_stylebox_override("normal", ist)
		var focus_st := ist.duplicate() as StyleBoxFlat
		focus_st.border_color = Color("#BF5700")
		input.add_theme_stylebox_override("focus", focus_st)
		input.add_theme_color_override("font_color", Color("#000000"))
		input.add_theme_color_override("caret_color", Color("#BF5700"))
		if is_secret:
			input.secret = true
		vbox.add_child(input)
		input.grab_focus()
		_dialog_input_ref = input
		input.text_submitted.connect(func(text: String) -> void: _on_dialog_submit(text))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	if has_input:
		var cancel := Button.new()
		cancel.text = "Cancel"
		_apply_flat_button_style(cancel)
		cancel.pressed.connect(_close_overlay)
		btn_row.add_child(cancel)

	var ok := Button.new()
	ok.text = "Continue →" if has_input else "Let's go! 🚀"
	ok.custom_minimum_size = Vector2(130, 40)
	_apply_primary_button_style(ok)
	ok.pressed.connect(func() -> void:
		if has_input and is_instance_valid(_dialog_input_ref):
			_on_dialog_submit(_dialog_input_ref.text)
		else:
			_on_dialog_submit("")
	)
	btn_row.add_child(ok)

func _on_dialog_submit(text: String) -> void:
	if _dialog_submit_callback.is_valid():
		_dialog_submit_callback.call(text)

func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_dialog_input_ref = null

# ── Encourage after end-of-day AI response ────────────────────────────────────

func _on_ai_response_for_dialog(text: String) -> void:
	if _waiting_for_encouragement:
		_waiting_for_encouragement = false
		_show_encouragement_dialog(text)

func _show_encouragement_dialog(message: String) -> void:
	_dialog_submit_callback = func(_t: String) -> void: _close_overlay()
	_show_dialog("%s says... 💗" % AIService.get_buddy_name(), message, "", false)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _parse_and_save_todos(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	var raw_todos: Array[Dictionary] = []
	var lines: PackedStringArray
	if "," in text:
		lines = text.split(",")
	elif "\n" in text:
		lines = text.split("\n")
	else:
		lines = [text]

	for line in lines:
		var clean := line.strip_edges()
		if clean.length() > 2 and clean[0].is_valid_int() and clean[1] == ".":
			clean = clean.substr(2).strip_edges()
		if not clean.is_empty():
			raw_todos.append({"text": clean, "done": false})
		if raw_todos.size() >= 2:
			break

	if not raw_todos.is_empty():
		_dm.call("set_today_todos", raw_todos)
		if _current_page != null and _current_page.has_method("_load_todos"):
			_current_page.call("_load_todos")

func _parse_and_save_weekly_goals(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	var raw_goals: Array[Dictionary] = []
	var parts: PackedStringArray
	if "," in text:
		parts = text.split(",")
	elif "\n" in text:
		parts = text.split("\n")
	else:
		parts = [text]
	for part in parts:
		var clean := part.strip_edges()
		if not clean.is_empty():
			raw_goals.append({"text": clean, "done": false})
	if not raw_goals.is_empty():
		_dm.call("set_this_week_goals", raw_goals)
		if _current_page != null and _current_page.has_method("_load_weekly_goals"):
			_current_page.call("_load_weekly_goals")

func _on_data_changed() -> void:
	pass

func _find_api_status_label() -> Label:
	var sidebar := get_child(1) if get_child_count() > 1 else null
	if not sidebar:
		return null
	return _find_node_named(sidebar, "APIStatus") as Label

func _find_node_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_named(child, node_name)
		if found:
			return found
	return null

# ── Style helpers ─────────────────────────────────────────────────────────────

func _apply_nav_style(btn: Button, selected: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#7B886F") if selected else Color(0, 0, 0, 0)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 10; s.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", s)

	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color("#7B886F") if selected else Color("#C0C9BA")
	btn.add_theme_stylebox_override("hover", h)

	var p := s.duplicate() as StyleBoxFlat
	p.bg_color = Color("#A34A00")
	btn.add_theme_stylebox_override("pressed", p)

	var f := s.duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("focus", f)
	btn.add_theme_color_override("font_color", Color.WHITE if selected else Color("#44443A"))
	btn.add_theme_font_size_override("font_size", 14)

func _apply_primary_button_style(btn: Button) -> void:
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
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)

func _apply_flat_button_style(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#E8EDE4")
	n.set_corner_radius_all(10)
	n.content_margin_left = 14; n.content_margin_right = 14
	n.content_margin_top = 8; n.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat; h.bg_color = Color("#C0C9BA")
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color("#BF5700"))
	btn.add_theme_font_size_override("font_size", 14)
