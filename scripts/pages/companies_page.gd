extends Control

const PROGRESS_COLORS := {
	"Applied": Color("#4A90D9"),
	"Stale": Color("#95A5A6"),
	"In-interview": Color("#BF5700"),
	"Gone": Color("#E74C3C"),
	"Offer": Color("#27AE60"),
	"Offer declined": Color("#7F8C8D")
}

const PROGRESS_OPTIONS := ["Applied", "Stale", "In-interview", "Gone", "Offer", "Offer declined"]

var _company_list: VBoxContainer
var _empty_label: Label
var _overlay: Control
var _dm: Node
var _as: Node

func _ready() -> void:
	_dm = get_node("/root/DataManager")
	_as = get_node("/root/AIService")
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
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Companies"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#000000"))
	vbox.add_child(title)

	# Legend row
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	vbox.add_child(legend)

	for prog in PROGRESS_OPTIONS:
		var chip := _make_progress_chip(prog)
		legend.add_child(chip)

	# Table header
	var header_card := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color("#E8EDE4")
	hs.set_corner_radius_all(8)
	hs.content_margin_left = 12
	hs.content_margin_right = 12
	hs.content_margin_top = 8
	hs.content_margin_bottom = 8
	header_card.add_theme_stylebox_override("panel", hs)
	vbox.add_child(header_card)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_card.add_child(header_row)

	_make_col_header("Company", header_row, 2)
	_make_col_header("Role", header_row, 3)
	_make_col_header("Contacts", header_row, 2)
	_make_col_header("Progress", header_row, 1)
	_make_col_header("Date", header_row, 1)

	# Spacer aligned to the edit + delete buttons
	var actions_spacer := Control.new()
	actions_spacer.custom_minimum_size = Vector2(72, 0)
	header_row.add_child(actions_spacer)

	# Scrollable company list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_company_list = VBoxContainer.new()
	_company_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_company_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_company_list)

	# Empty state
	_empty_label = Label.new()
	_empty_label.text = "No companies yet.\nLog an application activity to add companies here! 💼"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.add_theme_color_override("font_color", Color("#887766"))
	_empty_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_empty_label)

func _refresh() -> void:
	if not is_instance_valid(_company_list):
		return
	for child in _company_list.get_children():
		child.queue_free()

	var companies: Array = _dm.call("get_companies") as Array
	_empty_label.visible = companies.is_empty()

	for i in range(companies.size() - 1, -1, -1):
		var company: Dictionary = companies[i]
		var row_card := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color.WHITE
		rs.set_corner_radius_all(8)
		rs.shadow_color = Color(0, 0, 0, 0.04)
		rs.shadow_size = 2
		rs.content_margin_left = 12
		rs.content_margin_right = 12
		rs.content_margin_top = 8
		rs.content_margin_bottom = 8
		row_card.add_theme_stylebox_override("panel", rs)
		_company_list.add_child(row_card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_card.add_child(row)

		_make_cell(company.get("name", ""), row, 2, true)
		_make_cell(company.get("role", "—"), row, 3, false)
		_make_cell(company.get("contacts", "—"), row, 2, false)

		# Progress dropdown
		var prog_container := HBoxContainer.new()
		prog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prog_container.size_flags_stretch_ratio = 1
		row.add_child(prog_container)

		var current_prog: String = company.get("progress", "Applied")
		var prog_color: Color = PROGRESS_COLORS.get(current_prog, Color.GRAY)

		var opt := OptionButton.new()
		for prog in PROGRESS_OPTIONS:
			opt.add_item(prog)
		opt.selected = PROGRESS_OPTIONS.find(current_prog)
		opt.add_theme_font_size_override("font_size", 13)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.add_theme_color_override("font_color", prog_color)

		var idx := i
		opt.item_selected.connect(func(sel: int) -> void:
			var prog: String = PROGRESS_OPTIONS[sel]
			_dm.call("update_company_progress", idx, prog)
			opt.add_theme_color_override("font_color", PROGRESS_COLORS.get(prog, Color.GRAY))
			if prog == "Gone":
				_as.call("get_buddy_response", "gone", "gone")
		)
		prog_container.add_child(opt)

		# Date cell
		var date_str := _format_date(company.get("applied_date", ""))
		_make_cell(date_str, row, 1, false)

		# Edit button
		var edit_btn := Button.new()
		edit_btn.text = "✏"
		edit_btn.custom_minimum_size = Vector2(32, 32)
		edit_btn.tooltip_text = "Edit"
		_style_icon_button(edit_btn, false)
		var company_snapshot := company.duplicate()
		edit_btn.pressed.connect(func(): _show_edit_dialog(idx, company_snapshot))
		row.add_child(edit_btn)

		# Delete button
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(32, 32)
		del_btn.tooltip_text = "Remove"
		_style_icon_button(del_btn, true)
		var company_name: String = company.get("name", "")
		del_btn.pressed.connect(func(): _show_delete_confirm(idx, company_name))
		row.add_child(del_btn)

# ── Dialogs ───────────────────────────────────────────────────────────────────

func _build_overlay_base(title_text: String) -> VBoxContainer:
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
	dialog.custom_minimum_size = Vector2(400, 0)
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

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color("#BF5700"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	return vbox

func _show_edit_dialog(index: int, company: Dictionary) -> void:
	var vbox := _build_overlay_base("Edit Company ✏")

	var name_input := _make_dialog_field(vbox, "Company Name", company.get("name", ""))
	var role_input := _make_dialog_field(vbox, "Role", company.get("role", ""))
	var contacts_input := _make_dialog_field(vbox, "Contacts", company.get("contacts", ""))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	_style_flat_button(cancel_btn)
	cancel_btn.pressed.connect(_close_overlay)
	btn_row.add_child(cancel_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(100, 40)
	_style_primary_button(save_btn)
	save_btn.pressed.connect(func():
		_dm.call("update_company", index, name_input.text, role_input.text, contacts_input.text)
		_close_overlay()
	)
	btn_row.add_child(save_btn)

	name_input.grab_focus()

func _show_delete_confirm(index: int, company_name: String) -> void:
	var vbox := _build_overlay_base("Remove Company")

	var msg := Label.new()
	msg.text = "Remove \"%s\" from your list?\nThis cannot be undone." % company_name
	msg.add_theme_font_size_override("font_size", 14)
	msg.add_theme_color_override("font_color", Color("#44443A"))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	_style_flat_button(cancel_btn)
	cancel_btn.pressed.connect(_close_overlay)
	btn_row.add_child(cancel_btn)

	var del_btn := Button.new()
	del_btn.text = "Remove"
	del_btn.custom_minimum_size = Vector2(100, 40)
	_style_delete_button(del_btn)
	del_btn.pressed.connect(func():
		_dm.call("delete_company", index)
		_close_overlay()
	)
	btn_row.add_child(del_btn)

func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null

func _make_dialog_field(parent: VBoxContainer, label_text: String, prefill: String) -> LineEdit:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#665F50"))
	parent.add_child(lbl)

	var input := LineEdit.new()
	input.text = prefill
	input.custom_minimum_size = Vector2(0, 40)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#F5F2ED")
	s.border_color = Color("#C0C9BA")
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 8; s.content_margin_bottom = 8
	input.add_theme_stylebox_override("normal", s)
	input.add_theme_color_override("font_color", Color("#000000"))
	input.add_theme_font_size_override("font_size", 14)
	parent.add_child(input)
	return input

# ── Table helpers ─────────────────────────────────────────────────────────────

func _make_col_header(text: String, parent: Node, expand: int) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#665F50"))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = expand
	parent.add_child(lbl)

func _make_cell(text: String, parent: Node, expand: int, bold: bool) -> void:
	var lbl := Label.new()
	lbl.text = text if not text.is_empty() else "—"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color("#000000") if bold else Color("#44443A"))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_stretch_ratio = expand
	lbl.clip_text = true
	parent.add_child(lbl)

func _format_date(date_str: String) -> String:
	if date_str.is_empty():
		return "—"
	var parts := date_str.split("-")
	if parts.size() < 3:
		return date_str
	var month_names := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
						"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month := int(parts[1])
	var day := int(parts[2])
	if month < 1 or month > 12:
		return date_str
	return "%s %d" % [month_names[month - 1], day]

func _make_progress_chip(progress: String) -> Control:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = PROGRESS_COLORS.get(progress, Color.GRAY)
	s.set_corner_radius_all(10)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.bg_color.a = 0.15
	panel.add_theme_stylebox_override("panel", s)

	var lbl := Label.new()
	lbl.text = progress
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", PROGRESS_COLORS.get(progress, Color.GRAY))
	panel.add_child(lbl)
	return panel

# ── Style helpers ─────────────────────────────────────────────────────────────

func _style_icon_button(btn: Button, is_delete: bool) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#FDECEA") if is_delete else Color("#E8EDE4")
	n.set_corner_radius_all(8)
	n.content_margin_left = 6; n.content_margin_right = 6
	n.content_margin_top = 6; n.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color("#F5C6C2") if is_delete else Color("#C0C9BA")
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color("#C0392B") if is_delete else Color("#BF5700"))
	btn.add_theme_font_size_override("font_size", 14)

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
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)

func _style_flat_button(btn: Button) -> void:
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

func _style_delete_button(btn: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("#E74C3C")
	n.set_corner_radius_all(10)
	n.content_margin_left = 16; n.content_margin_right = 16
	n.content_margin_top = 10; n.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat; h.bg_color = Color("#C0392B")
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 14)
