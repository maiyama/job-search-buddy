extends Node

const SAVE_PATH := "user://job_search_data.json"
const CONFIG_PATH := "user://config.json"
const USER_PROFILE_PATH := "user://config/user.md"

signal data_changed

var data: Dictionary = {
	"user_name": "",
	"first_session_done": false,
	"last_greeted_date": "",
	"last_week_prompted_date": "",
	"activities": [],
	"companies": [],
	"todos": {},
	"weekly_goals": {},
	"weekly_reviews": {}
}

var config: Dictionary = {
	"api_key": ""
}

func _ready() -> void:
	_load_data()
	_load_user_profile()
	_load_config()
	_check_stale_companies()

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for key in data:
			if parsed.has(key):
				data[key] = parsed[key]

func _save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	data_changed.emit()

func _load_user_profile() -> void:
	if not FileAccess.file_exists(USER_PROFILE_PATH):
		return
	var file := FileAccess.open(USER_PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	for line in file.get_as_text().split("\n"):
		var s := line.strip_edges()
		if s.begins_with("Name:"):
			var val := s.substr(5).strip_edges()
			if not val.is_empty():
				data.user_name = val
				data.first_session_done = true
	file.close()

func _save_user_profile() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("config"):
		dir.make_dir("config")
	var file := FileAccess.open(USER_PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("# User Profile\n\nName: %s\n" % data.user_name)
	file.close()

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for key in config:
			if parsed.has(key):
				config[key] = parsed[key]

func save_config() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(config, "\t"))
	file.close()

# ── Activity ──────────────────────────────────────────────────────────────────

func categorize_activity(text: String) -> String:
	var t := text.to_lower()
	if ("interview" in t) or ("recruiter call" in t) or ("practice" in t and "stor" in t) or ("mock interview" in t):
		return "Interview"
	if ("reach out" in t) or ("message" in t and "linkedin profile" not in t) or \
	   ("network" in t) or ("mentorship" in t) or \
	   ("joined" in t and "linkedin profile" not in t) or \
	   ("recruiter" in t and "interview" not in t) or ("coffee chat" in t):
		return "Networking"
	if ("appl" in t) or ("resume" in t) or ("linkedin profile" in t) or \
	   ("cover letter" in t) or ("sent application" in t) or ("revising" in t and "linkedin" in t):
		return "Application"
	if ("research" in t) or ("reading about" in t) or ("looking for job" in t) or \
	   ("watch" in t and "video" in t) or ("set up" in t) or ("learn" in t):
		return "Research"
	return "Review"

func add_activity(text: String, activity_type: String, start_time: String, end_time: String, from_apply: bool = false) -> Dictionary:
	var activity := {
		"id": str(Time.get_unix_time_from_system()),
		"text": text,
		"type": activity_type,
		"start_time": start_time,
		"end_time": end_time,
		"date": Time.get_date_string_from_system(),
		"from_apply": from_apply
	}
	data.activities.append(activity)
	_save_data()
	return activity

func get_activities_for_range(range_type: String) -> Array:
	var today := Time.get_date_string_from_system()
	match range_type:
		"Day":
			return data.activities.filter(func(a: Dictionary) -> bool: return a.date == today)
		"Week":
			var bounds := _get_week_bounds()
			return data.activities.filter(func(a: Dictionary) -> bool:
				var d: String = a.get("date", "")
				return d >= bounds[0] and d <= bounds[1])
		"Month":
			return data.activities.filter(func(a: Dictionary) -> bool: return _within_days(a.date, 30))
		_:
			return data.activities.duplicate()

func _get_week_bounds() -> Array:
	var monday_str := get_this_week_monday()
	var parts := monday_str.split("-")
	var dt := {
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 12, "minute": 0, "second": 0
	}
	var monday_unix := Time.get_unix_time_from_datetime_dict(dt)
	var sunday_dt := Time.get_datetime_dict_from_unix_time(int(monday_unix) + 6 * 86400)
	var sunday_str := "%04d-%02d-%02d" % [sunday_dt.year, sunday_dt.month, sunday_dt.day]
	return [monday_str, sunday_str]

func _within_days(date_str: String, days: int) -> bool:
	var parts := date_str.split("-")
	if parts.size() != 3:
		return false
	var dt := {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
			   "hour": 12, "minute": 0, "second": 0}
	var then := Time.get_unix_time_from_datetime_dict(dt)
	return (Time.get_unix_time_from_system() - then) <= days * 86400.0

# ── Company ───────────────────────────────────────────────────────────────────

func add_or_update_company(company_name: String, role: String, contacts: String, progress: String = "Applied") -> void:
	if company_name.strip_edges().is_empty():
		return
	var name_l := company_name.to_lower().strip_edges()
	var role_l := role.to_lower().strip_edges()
	for company in data.companies:
		if company.name.to_lower() == name_l and company.role.to_lower() == role_l:
			if not contacts.is_empty():
				var existing: String = company.contacts
				if existing.is_empty():
					company.contacts = contacts
				elif contacts not in existing:
					company.contacts = existing + ", " + contacts
			if progress != "Applied":
				company.progress = progress
			_save_data()
			return
	data.companies.append({
		"name": company_name.strip_edges(),
		"role": role.strip_edges(),
		"contacts": contacts.strip_edges(),
		"progress": progress,
		"applied_date": Time.get_date_string_from_system()
	})
	_save_data()

func update_company(index: int, name: String, role: String, contacts: String) -> void:
	if index >= 0 and index < data.companies.size():
		data.companies[index].name = name.strip_edges()
		data.companies[index].role = role.strip_edges()
		data.companies[index].contacts = contacts.strip_edges()
		_save_data()

func delete_company(index: int) -> void:
	if index >= 0 and index < data.companies.size():
		data.companies.remove_at(index)
		_save_data()

func update_company_progress(index: int, progress: String) -> void:
	if index >= 0 and index < data.companies.size():
		data.companies[index].progress = progress
		_save_data()

func update_company_progress_by_name(company_name: String, new_progress: String) -> String:
	var name_l := company_name.to_lower().strip_edges()
	for i in data.companies.size():
		var c: Dictionary = data.companies[i]
		var c_l: String = c.name.to_lower()
		if name_l in c_l or c_l in name_l:
			data.companies[i].progress = new_progress
			_save_data()
			return c.name
	return ""

func get_companies_for_range(range_type: String) -> Array:
	match range_type:
		"Day":
			var today := Time.get_date_string_from_system()
			return data.companies.filter(func(c: Dictionary) -> bool: return c.get("applied_date", "") == today)
		"Week":
			var bounds := _get_week_bounds()
			return data.companies.filter(func(c: Dictionary) -> bool:
				var d: String = c.get("applied_date", "")
				return d >= bounds[0] and d <= bounds[1])
		"Month":
			return data.companies.filter(func(c: Dictionary) -> bool: return _within_days(c.get("applied_date", ""), 30))
		_:
			return data.companies.duplicate()

func _check_stale_companies() -> void:
	var changed := false
	for company in data.companies:
		if company.progress == "Applied":
			if not _within_days(company.get("applied_date", ""), 21):
				company.progress = "Stale"
				changed = true
	if changed:
		_save_data()

# ── Todos ─────────────────────────────────────────────────────────────────────

func get_today_todos() -> Array:
	var today := Time.get_date_string_from_system()
	return data.todos.get(today, [])

func set_today_todos(todos: Array) -> void:
	var today := Time.get_date_string_from_system()
	data.todos[today] = todos
	_save_data()

func all_todos_done() -> bool:
	var todos := get_today_todos()
	if todos.is_empty():
		return false
	for t in todos:
		if not t.get("done", false):
			return false
	return true

# ── Weekly Goals ──────────────────────────────────────────────────────────────

func get_this_week_monday() -> String:
	var today := Time.get_date_string_from_system()
	var parts := today.split("-")
	var dt := {
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 12, "minute": 0, "second": 0
	}
	var unix := Time.get_unix_time_from_datetime_dict(dt)
	var full_dt := Time.get_datetime_dict_from_unix_time(int(unix))
	var days_since_monday := (int(full_dt.weekday) - 1 + 7) % 7
	var monday_dt := Time.get_datetime_dict_from_unix_time(int(unix) - days_since_monday * 86400)
	return "%04d-%02d-%02d" % [monday_dt.year, monday_dt.month, monday_dt.day]

func get_this_week_goals() -> Array:
	return data.weekly_goals.get(get_this_week_monday(), [])

func set_this_week_goals(goals: Array) -> void:
	data.weekly_goals[get_this_week_monday()] = goals
	_save_data()

func is_new_week_monday() -> bool:
	var today := Time.get_date_string_from_system()
	var parts := today.split("-")
	var dt := {
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 12, "minute": 0, "second": 0
	}
	var unix := Time.get_unix_time_from_datetime_dict(dt)
	var weekday := int(Time.get_datetime_dict_from_unix_time(int(unix)).weekday)
	if weekday != 1:
		return false
	return data.get("last_week_prompted_date", "") != get_this_week_monday()

func mark_week_prompted() -> void:
	data["last_week_prompted_date"] = get_this_week_monday()
	_save_data()

# ── Weekly Reviews ────────────────────────────────────────────────────────────

func get_this_week_review() -> Dictionary:
	return data.weekly_reviews.get(get_this_week_monday(), {})

func save_week_review(review: Dictionary) -> void:
	data.weekly_reviews[get_this_week_monday()] = review
	_save_data()

func get_all_week_reviews() -> Array:
	var keys: Array = data.weekly_reviews.keys()
	keys.sort()
	keys.reverse()
	var result: Array = []
	for k in keys:
		result.append(data.weekly_reviews[k])
	return result

func week_label_from_monday(monday_str: String) -> String:
	var parts := monday_str.split("-")
	if parts.size() != 3:
		return monday_str
	var dt := {
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 12, "minute": 0, "second": 0
	}
	var unix := Time.get_unix_time_from_datetime_dict(dt)
	var fri := Time.get_datetime_dict_from_unix_time(int(unix) + 4 * 86400)
	return "%d/%d-%d/%d" % [int(parts[1]), int(parts[2]), fri.month, fri.day]

# ── Stats ─────────────────────────────────────────────────────────────────────

func get_application_count() -> int:
	return data.activities.filter(func(a: Dictionary) -> bool: return a.get("from_apply", false)).size()

func get_company_count() -> int:
	return data.companies.size()

# ── Session ───────────────────────────────────────────────────────────────────

func is_new_day() -> bool:
	var today := Time.get_date_string_from_system()
	return data.get("last_greeted_date", "") != today

func mark_greeted() -> void:
	data["last_greeted_date"] = Time.get_date_string_from_system()
	_save_data()

func set_user_name(user_name: String) -> void:
	data.user_name = user_name.strip_edges()
	data.first_session_done = true
	_save_user_profile()
	_save_data()

# ── Typed accessors (for cross-autoload access) ───────────────────────────────

func get_api_key() -> String:
	return config.get("api_key", "")

func set_api_key(key: String) -> void:
	config.api_key = key.strip_edges()
	save_config()

func get_user_name_val() -> String:
	return data.get("user_name", "friend")

func get_first_session_done() -> bool:
	return data.get("first_session_done", false)

func get_companies() -> Array:
	return data.companies
