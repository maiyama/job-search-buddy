extends Node

signal response_ready(text: String)
signal categorization_ready(activity_type: String, company: String, role: String, contacts: String)
signal weekly_review_ready(feelings: String, wins: String, ofps: String, encouragement: String)

const API_URL := "https://api.anthropic.com/v1/messages"
const MODEL := "claude-haiku-4-5-20251001"

var _http: HTTPRequest
var _pending_callback: Callable
var _busy := false
var _queue: Array = []
var _dm: Node
var _buddy_context := ""

const FALLBACKS := {
	"interview_scheduled": [
		"An interview — they reached out because you're worth talking to. Prep well and trust yourself. 💪",
		"That's a real signal of interest. Take a breath, prepare, and walk in knowing you earned that seat.",
		"Interview locked in. Go show them who you are. 🌟"
	],
	"offer_received": [
		"An offer. All that work just paid off. Take your time deciding — you've earned the right to choose. 🎉",
		"They want you. Whether you take it or not, this proves you're exactly what companies are looking for. 💗",
		"Offer on the table! Celebrate this moment, then decide with a clear head. 🌟"
	],
	"all_done": [
		"Everything on your list — done. That's discipline, not luck. 🎉",
		"All goals complete. You said you'd do it, and you did. 💪",
		"Goals done! Days like this build real momentum. ⭐"
	],
	"encouragement": [
		"You keep showing up. That matters more than you know. 💗",
		"Job searching is hard. Some things are outside your control — focus on what isn't.",
		"Your work will shine through. I believe in you. 🌟"
	],
	"rejection": [
		"Not every role is the right fit, and that goes both ways. The right one is still out there. 💗",
		"They passed — their call. You have a lot to offer and the right company will see it.",
		"Every no narrows it down. Keep going. 🌟"
	]
}

func _ready() -> void:
	_dm = get_node("/root/DataManager")
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_load_buddy_context()

func _load_buddy_context() -> void:
	var file := FileAccess.open("res://reference/BUDDY.md", FileAccess.READ)
	if file:
		_buddy_context = file.get_as_text().strip_edges()
		file.close()

func has_api_key() -> bool:
	return not str(_dm.call("get_api_key")).is_empty()

func get_fallback(category: String) -> String:
	var options: Array = FALLBACKS.get(category, FALLBACKS["encouragement"])
	return options[randi() % options.size()]

func get_buddy_response(user_text: String, context: String = "") -> void:
	if not has_api_key():
		if "all_done" in context:
			response_ready.emit(get_fallback("all_done"))
		elif "offer" in context:
			response_ready.emit(get_fallback("offer_received"))
		elif "interview" in context:
			response_ready.emit(get_fallback("interview_scheduled"))
		elif "gone" in context or "reject" in user_text.to_lower():
			response_ready.emit(get_fallback("rejection"))
		else:
			response_ready.emit(get_fallback("encouragement"))
		return

	var user_name: String = str(_dm.call("get_user_name_val"))
	var system_msg := ""
	if not _buddy_context.is_empty():
		system_msg = "[Buddy profile]\n%s\n\n" % _buddy_context
	system_msg += "Be warm but brief and genuine — not sycophantic. Only celebrate real milestones: an interview scheduled, an offer received, or all daily goals completed. For those, 1-2 sentences of genuine encouragement. Otherwise, skip praise."
	var prompt := "User: %s\nContext: %s\nMessage: %s\n\nRespond in 1-2 sentences. Match the weight of the moment." % [user_name, context, user_text]
	_call_api(system_msg, prompt, func(r: String): response_ready.emit(r))

func get_encouragement(feeling: String) -> void:
	if not has_api_key():
		var lower := feeling.to_lower()
		if "frustrated" in lower or "tired" in lower or "sad" in lower or "hard" in lower or "difficult" in lower:
			response_ready.emit("I hear you — job searching is genuinely hard. Remember, some things are out of your control, and that's okay. Focus on what you can control, and you're already doing that! 💗")
		else:
			response_ready.emit(get_fallback("encouragement"))
		return

	var user_name: String = str(_dm.call("get_user_name_val"))
	var system_msg := ""
	if not _buddy_context.is_empty():
		system_msg = "[Buddy profile]\n%s\n\n" % _buddy_context
	system_msg += "Be empathetic, genuine, and warm. Keep response to 2-3 sentences."
	var prompt := """User %s just finished a day of job searching.
They said: "%s"

If they're frustrated or struggling, remind them that some things are outside their control and to focus on what they can control. Their time is valuable and their life is worthy.
If they had a good day, celebrate with them!
Be authentic, not generic.""" % [user_name, feeling]
	_call_api(system_msg, prompt, func(r: String): response_ready.emit(r))

func analyze_activity(text: String) -> void:
	if not has_api_key():
		var fallback_type: String = str(_dm.call("categorize_activity", text))
		categorization_ready.emit(fallback_type, "", "", "")
		return

	var system_msg := """You are a job search activity analyzer. Extract structured information from activity descriptions.
Respond ONLY with valid JSON, no markdown, no explanation."""
	var prompt := """Analyze this job search activity and respond with ONLY a JSON object:
Activity: "%s"

JSON format (required fields, use empty string if not found):
{
  "activity_type": "Review|Research|Interview|Application|Networking",
  "company": "company name if user applied or interviewed",
  "role": "job role/title if mentioned",
  "contacts": "person names mentioned, comma-separated"
}

Activity type guide:
- Review: planning, reviewing progress, daily reflection, preparing notes
- Research: researching companies, reading about industry, watching company videos
- Interview: interview calls, interview prep, mock interviews, practice stories
- Application: applying to jobs, updating resume/LinkedIn profile, sending applications
- Networking: reaching out to people, coffee chats, messaging contacts, recruiter calls""" % text

	_call_api(system_msg, prompt, func(r: String):
		var clean := r.strip_edges()
		if clean.begins_with("```"):
			var lines: PackedStringArray = clean.split("\n")
			var json_lines := PackedStringArray()
			var in_json := false
			for line in lines:
				if line.begins_with("```"):
					in_json = not in_json
				elif not line.begins_with("```"):
					if in_json:
						json_lines.append(line)
			clean = "\n".join(json_lines).strip_edges()
		var parsed = JSON.parse_string(clean)
		if parsed is Dictionary:
			var fallback_type: String = str(_dm.call("categorize_activity", text))
			categorization_ready.emit(
				parsed.get("activity_type", fallback_type),
				parsed.get("company", ""),
				parsed.get("role", ""),
				parsed.get("contacts", "")
			)
		else:
			var fallback_type2: String = str(_dm.call("categorize_activity", text))
			categorization_ready.emit(fallback_type2, "", "", "")
	)

func _call_api(system_msg: String, prompt: String, callback: Callable, max_tokens: int = 256) -> void:
	if _busy:
		_queue.append({"system": system_msg, "prompt": prompt, "callback": callback, "max_tokens": max_tokens})
		return
	_busy = true
	_pending_callback = callback

	var api_key: String = str(_dm.call("get_api_key"))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	])
	var body := JSON.stringify({
		"model": MODEL,
		"max_tokens": max_tokens,
		"system": system_msg,
		"messages": [{"role": "user", "content": prompt}]
	})
	var err := _http.request(API_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false
		callback.call(get_fallback("encouragement"))

func _on_response(result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var cb := _pending_callback
	_pending_callback = Callable()

	if result == HTTPRequest.RESULT_SUCCESS:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("content"):
			var content: Array = parsed["content"]
			if not content.is_empty() and content[0] is Dictionary:
				cb.call(content[0].get("text", get_fallback("encouragement")))
				_process_queue()
				return

	cb.call(get_fallback("encouragement"))
	_process_queue()

func process_weekly_review(feelings_raw: String, wins_raw: String, ofps_raw: String) -> void:
	if not has_api_key():
		var words := feelings_raw.split(" ")
		var feelings := feelings_raw if words.size() <= 30 else " ".join(words.slice(0, 30)) + "..."
		weekly_review_ready.emit(feelings, wins_raw, ofps_raw, get_fallback("encouragement"))
		return

	var user_name: String = str(_dm.call("get_user_name_val"))
	var system_msg := ""
	if not _buddy_context.is_empty():
		system_msg = "[Buddy profile]\n%s\n\n" % _buddy_context
	system_msg += "Process weekly job search reviews. Respond ONLY with valid JSON, no markdown."

	var prompt := """Process %s's weekly job search review.

Feelings input (ALWAYS rephrase to capture emotional tone in 30 words or less): "%s"
Wins input (keep as-is; only summarize if over 30 words; use "" if empty): "%s"
OFPs input (keep as-is; only summarize if over 30 words; use "" if empty): "%s"

Respond with ONLY this JSON:
{
  "feelings": "rephrased feeling in 30 words or less",
  "wins": "wins text, summarized only if needed",
  "ofps": "ofps text, summarized only if needed",
  "encouragement": "warm 2-3 sentence encouraging message for %s based on their week"
}""" % [user_name, feelings_raw, wins_raw, ofps_raw, user_name]

	_call_api(system_msg, prompt, func(r: String):
		var clean := r.strip_edges()
		if clean.begins_with("```"):
			var lines := clean.split("\n")
			var json_lines := PackedStringArray()
			var in_json := false
			for line in lines:
				if line.begins_with("```"):
					in_json = not in_json
				elif in_json:
					json_lines.append(line)
			clean = "\n".join(json_lines).strip_edges()
		var parsed = JSON.parse_string(clean)
		if parsed is Dictionary:
			weekly_review_ready.emit(
				parsed.get("feelings", feelings_raw),
				parsed.get("wins", wins_raw),
				parsed.get("ofps", ofps_raw),
				parsed.get("encouragement", get_fallback("encouragement"))
			)
		else:
			weekly_review_ready.emit(feelings_raw, wins_raw, ofps_raw, get_fallback("encouragement"))
	, 512)

func _process_queue() -> void:
	if _queue.is_empty():
		return
	var next: Dictionary = _queue.pop_front()
	_call_api(next["system"], next["prompt"], next["callback"], next.get("max_tokens", 256))
