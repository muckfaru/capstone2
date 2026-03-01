extends Control

# ── Signals ──────────────────────────────────────────────────────────────────
signal quiz_finished

# ── State ────────────────────────────────────────────────────────────────────
enum Screen {GRID, QUESTION, SCORE, WAITING, LEADERBOARD}

var quiz_data: Dictionary = {}
var total_questions: int = 0
var time_per_question: int = 0
var quiz_timer_seconds: int = 0
var current_question_index: int = 0

# Per-question tracking
var student_answers: Array = [] # String per question ("" = unanswered)
var answered_flags: Array = []  # bool per question

var _quiz_elapsed: float = 0.0
var _quiz_timer_running: bool = false
var _q_elapsed: float = 0.0
var _q_timer_running: bool = false

# CyberQuiz server mode
var _is_cyber_quiz: bool = false
var _cyber_quiz_room_code: String = ""
var _cyber_quiz_lobby_url: String = ""
var _wait_poll_timer: Timer = null
var _answer_buttons: Array[Button] = []

# ── Screen roots ─────────────────────────────────────────────────────────────
@onready var grid_screen: Control     = $GridScreen
@onready var question_screen: Control = $QuestionScreen
@onready var score_screen: Control    = $ScoreScreen

# ── Grid screen nodes ─────────────────────────────────────────────────────────
@onready var grid_back_btn: Button        = $GridScreen/TopBar/BackButton
@onready var grid_hint_label: Label       = $GridScreen/TopBar/HintLabel
@onready var grid_timer_lbl: Label        = $GridScreen/TopBar/TimerLabel
@onready var question_grid: GridContainer = $GridScreen/QuestionGrid
@onready var submit_btn: Button           = $GridScreen/SubmitButton

# ── Question screen nodes ─────────────────────────────────────────────────────
@onready var q_back_btn: Button    = $QuestionScreen/TopBar/BackButton
@onready var q_timer_lbl: Label    = $QuestionScreen/TopBar/TimerLabel
@onready var q_tpq_label: Label    = $QuestionScreen/Card/TPQCircle/TPQLabel
@onready var q_title_label: Label  = $QuestionScreen/Card/QuestionLabel
@onready var q_next_btn: Button    = $QuestionScreen/NextButton
# ChoicesVBox is now declared in the .tscn — reference it directly
@onready var choices_vbox: VBoxContainer = $QuestionScreen/Card/ChoicesVBox

# ── Score screen nodes ────────────────────────────────────────────────────────
@onready var score_back_btn: Button        = $ScoreScreen/TopBar/BackButton
@onready var score_number: Label           = $ScoreScreen/ContentRow/ScorePanel/ScoreNumber
@onready var score_pct: Label              = $ScoreScreen/ContentRow/ScorePanel/PctLabel
@onready var score_grid: GridContainer     = $ScoreScreen/ContentRow/ResultGrid
@onready var score_message: Label          = $ScoreScreen/MessageLabel
@onready var done_btn: Button              = $ScoreScreen/DoneButton

var _grid_buttons: Array[Button] = []
var _last_correct_count: int = 0
var _question_results: Array = []    # Per-question results from server
var _score_submitted: bool = false   # Whether server submission is done

# ── Styles ────────────────────────────────────────────────────────────────────
var _sb_unanswered: StyleBoxFlat
var _sb_answered: StyleBoxFlat
var _sb_correct: StyleBoxFlat
var _sb_wrong: StyleBoxFlat

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false
	_build_styles()
	# Check if launched from CyberQuiz join flow
	if get_tree().has_meta("cyber_quiz_room_code"):
		_is_cyber_quiz = true
		_cyber_quiz_room_code = get_tree().get_meta("cyber_quiz_room_code")
		_cyber_quiz_lobby_url = get_tree().get_meta("cyber_quiz_lobby_url", "")
		get_tree().remove_meta("cyber_quiz_room_code")
		get_tree().remove_meta("cyber_quiz_lobby_url")
		visible = true
		_show_waiting_screen()
		_start_wait_polling()

func _build_styles() -> void:
	_sb_unanswered = _make_sb(Color(0.04, 0.10, 0.28, 1.0), Color(0.145, 0.878, 0.992, 0.4))
	_sb_answered   = _make_sb(Color(0.145, 0.878, 0.992, 1.0), Color(0.145, 0.878, 0.992, 1.0))
	_sb_correct    = _make_sb(Color(0.145, 0.878, 0.992, 1.0), Color(0.145, 0.878, 0.992, 1.0))
	_sb_wrong      = _make_sb(Color(0.85, 0.10, 0.10, 1.0), Color(1.0, 0.15, 0.15, 1.0))

func _make_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.shadow_color = border
	s.shadow_size = 6 if border.a > 0.5 else 0
	return s

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────
func start_quiz(data: Dictionary) -> void:
	quiz_data = data
	total_questions    = data.get("total_questions", 0)
	time_per_question  = data.get("time_per_question", 30)
	quiz_timer_seconds = data.get("quiz_timer", 1800)

	student_answers.clear()
	answered_flags.clear()
	for i in range(total_questions):
		student_answers.append("")
		answered_flags.append(false)

	_quiz_elapsed = 0.0
	_quiz_timer_running = true
	visible = true

	_build_grid()
	_show_screen(Screen.GRID)
	_animate_in()

# ─────────────────────────────────────────────────────────────────────────────
# PROCESS — timers
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# Quiz-wide timer
	if _quiz_timer_running:
		_quiz_elapsed += delta
		var remaining := maxi(0, quiz_timer_seconds - int(_quiz_elapsed))
		_update_timer_label(grid_timer_lbl, remaining)
		if current_screen() == Screen.QUESTION:
			_update_timer_label(q_timer_lbl, remaining)
		if remaining <= 0:
			_quiz_timer_running = false
			_force_submit()

	# Per-question timer
	if _q_timer_running:
		_q_elapsed += delta
		var q_remaining := maxi(0, time_per_question - int(_q_elapsed))
		q_tpq_label.text = "%ds" % q_remaining
		if q_remaining <= 0:
			_q_timer_running = false
			_auto_advance_question()

func _update_timer_label(lbl: Label, remaining: int) -> void:
	if not lbl: return
	var h := remaining / 3600
	var m := (remaining % 3600) / 60
	var s := remaining % 60
	lbl.text = "%02d:%02d:%02d" % [h, m, s]

var _current_screen: Screen = Screen.GRID
func current_screen() -> Screen: return _current_screen

# ─────────────────────────────────────────────────────────────────────────────
# GRID SCREEN
# ─────────────────────────────────────────────────────────────────────────────
func _build_grid() -> void:
	for child in question_grid.get_children():
		child.queue_free()
	_grid_buttons.clear()

	for i in range(total_questions):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.flat = false
		btn.add_theme_stylebox_override("normal",  _sb_unanswered)
		btn.add_theme_stylebox_override("hover",   _sb_unanswered)
		btn.add_theme_stylebox_override("pressed", _sb_unanswered)
		btn.add_theme_stylebox_override("focus",   _sb_unanswered)
		var idx := i
		btn.pressed.connect(func(): _on_grid_box_pressed(idx))
		question_grid.add_child(btn)
		_grid_buttons.append(btn)

	_update_grid_visuals()
	_update_submit_button()

func _update_grid_visuals() -> void:
	for i in range(_grid_buttons.size()):
		var btn := _grid_buttons[i]
		var sb  := _sb_answered if answered_flags[i] else _sb_unanswered
		btn.add_theme_stylebox_override("normal",  sb)
		btn.add_theme_stylebox_override("hover",   sb)
		btn.add_theme_stylebox_override("pressed", sb)

func _update_submit_button() -> void:
	var all_answered := true
	for flag in answered_flags:
		if not flag:
			all_answered = false
			break
	submit_btn.modulate.a = 1.0 if all_answered else 0.6

func _on_grid_box_pressed(index: int) -> void:
	current_question_index = index
	_load_question(index)
	_show_screen(Screen.QUESTION)

func _on_submit_pressed() -> void:
	_quiz_timer_running = false
	_q_timer_running    = false
	_show_score()

# ─────────────────────────────────────────────────────────────────────────────
# QUESTION SCREEN
# ─────────────────────────────────────────────────────────────────────────────
func _load_question(index: int) -> void:
	var questions: Array = quiz_data.get("questions", [])
	if index >= questions.size(): return
	var q: Dictionary = questions[index]

	q_title_label.text = "Question # %d\n\n%s" % [index + 1, q.get("question", "")]
	q_tpq_label.text   = "%ds" % time_per_question
	_q_elapsed         = 0.0
	_q_timer_running   = true

	q_next_btn.text = "Done" if index >= total_questions - 1 else "Next →"

	# Build answer-choice buttons into the scene-declared ChoicesVBox
	_build_answer_choices(q, index)

	_update_grid_visuals()
	_update_submit_button()

	# Fade-in card
	var card := $QuestionScreen/Card
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)

func _on_q_next_pressed() -> void:
	_q_timer_running = false
	if current_question_index >= total_questions - 1:
		_show_screen(Screen.GRID)
	else:
		current_question_index += 1
		_load_question(current_question_index)

func _on_q_back_pressed() -> void:
	_q_timer_running = false
	_show_screen(Screen.GRID)

func _auto_advance_question() -> void:
	answered_flags[current_question_index] = true
	_update_grid_visuals()
	_update_submit_button()
	_show_screen(Screen.GRID)

func _force_submit() -> void:
	# Always show score screen (CyberQuiz will auto-submit from there)
	_show_score()

# ─────────────────────────────────────────────────────────────────────────────
# ANSWER CHOICE BUTTONS  (uses ChoicesVBox from .tscn — no dynamic creation)
# ─────────────────────────────────────────────────────────────────────────────
func _build_answer_choices(q: Dictionary, q_index: int) -> void:
	# Clear previous buttons
	for btn in _answer_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_answer_buttons.clear()

	# Also clear any leftover children in the vbox
	for child in choices_vbox.get_children():
		child.queue_free()

	var choices: Array = q.get("choices", q.get("options", []))
	if choices.is_empty():
		return

	var choice_colors := [
		Color(0.1, 0.4, 0.7, 0.9),
		Color(0.1, 0.6, 0.4, 0.9),
		Color(0.6, 0.4, 0.1, 0.9),
		Color(0.6, 0.1, 0.3, 0.9),
	]

	for i in range(choices.size()):
		var choice_text: String = str(choices[i])
		var btn := Button.new()
		btn.text = choice_text
		btn.custom_minimum_size    = Vector2(0, 48)
		btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical    = Control.SIZE_EXPAND_FILL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		# Normal style
		var col: Color = choice_colors[i % choice_colors.size()]
		var sb := _make_choice_sb(col, col.lightened(0.3), false)
		var sb_hover := _make_choice_sb(col.lightened(0.2), col.lightened(0.4), false)
		btn.add_theme_stylebox_override("normal",  sb)
		btn.add_theme_stylebox_override("hover",   sb_hover)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus",   sb)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_font_size_override("font_size", 15)

		var idx := q_index
		var ans := choice_text
		btn.pressed.connect(func(): _on_choice_selected(idx, ans, btn))
		choices_vbox.add_child(btn)
		_answer_buttons.append(btn)

	# Restore highlight if question was already answered
	if answered_flags[q_index]:
		var prev_ans: String = student_answers[q_index]
		for btn in _answer_buttons:
			if btn.text == prev_ans:
				_highlight_selected(btn)

func _make_choice_sb(bg: Color, border: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color     = bg
	sb.border_color = border
	sb.set_border_width_all(3 if selected else 2)
	sb.set_corner_radius_all(8)
	return sb

func _highlight_selected(selected_btn: Button) -> void:
	var sel_bg     := Color(0, 0.7, 1, 1)
	var sel_border := Color(0, 1, 1, 1)
	var dim_bg     := Color(0.15, 0.15, 0.2, 0.7)
	var dim_border := Color(0.3, 0.3, 0.4, 0.5)

	for btn in _answer_buttons:
		if btn == selected_btn:
			var sb := _make_choice_sb(sel_bg, sel_border, true)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover",  sb)
		else:
			var sb := _make_choice_sb(dim_bg, dim_border, false)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover",  sb)

func _on_choice_selected(q_index: int, answer: String, clicked_btn: Button) -> void:
	student_answers[q_index] = answer
	answered_flags[q_index]  = true
	print("[StudentQuiz DEBUG] Selected Q%d answer='%s'" % [q_index, answer])
	_update_grid_visuals()
	_update_submit_button()
	_highlight_selected(clicked_btn)

# ─────────────────────────────────────────────────────────────────────────────
# SCORE SCREEN
# ─────────────────────────────────────────────────────────────────────────────
func _show_score() -> void:
	_show_screen(Screen.SCORE)
	_build_score_grid()

	if _is_cyber_quiz:
		# Server-authoritative: show loading state, submit, update on response
		score_number.text = "..."
		score_pct.text = "Calculating..."
		score_message.text = ""
		done_btn.text = "⏳ Submitting..."
		done_btn.disabled = true
		_submit_and_update_score()
		return

	# Offline / teacher-hosted: compute score client-side
	var questions: Array = quiz_data.get("questions", [])
	var correct_count := 0
	var correct_flags: Array[bool] = []

	print("[StudentQuiz DEBUG] Scoring %d questions, student_answers=%s" % [total_questions, str(student_answers)])
	for i in range(total_questions):
		var q: Dictionary       = questions[i] if i < questions.size() else {}
		var correct_ans: String = q.get("correct_answer", "").strip_edges().to_lower()
		var student_ans: String = student_answers[i].strip_edges().to_lower() if i < student_answers.size() else ""
		var is_correct          := student_ans != "" and student_ans == correct_ans
		print("[StudentQuiz DEBUG] Q%d: correct='%s' student='%s' match=%s" % [i, correct_ans, student_ans, str(is_correct)])
		correct_flags.append(is_correct)
		if is_correct:
			correct_count += 1

	score_number.text = str(correct_count)
	var pct := (float(correct_count) / float(total_questions)) * 100.0 if total_questions > 0 else 0.0
	score_pct.text    = "Percentage: %.0f%%" % pct

	var result_btns := score_grid.get_children()
	for i in range(result_btns.size()):
		var btn: Button = result_btns[i]
		if i < correct_flags.size():
			btn.add_theme_stylebox_override("normal", _sb_correct if correct_flags[i] else _sb_wrong)
			btn.add_theme_stylebox_override("disabled", _sb_correct if correct_flags[i] else _sb_wrong)

	if pct >= 80:
		score_message.text = "Great job soldier! 🎖️"
	elif pct >= 50:
		score_message.text = "Good effort! Keep it up! 💪"
	else:
		score_message.text = "Keep practicing soldier! 📚"

	_last_correct_count = correct_count

func _build_score_grid() -> void:
	for child in score_grid.get_children():
		child.queue_free()
	for i in range(total_questions):
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(48, 48)
		btn.disabled = true
		btn.flat     = false
		btn.add_theme_stylebox_override("normal",   _sb_unanswered)
		btn.add_theme_stylebox_override("disabled", _sb_unanswered)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8))
		btn.add_theme_font_size_override("font_size", 14)
		score_grid.add_child(btn)

func _on_done_pressed() -> void:
	if _is_cyber_quiz:
		# Score already submitted during _show_score; just go to leaderboard
		_fetch_leaderboard()
		return
	emit_signal("quiz_finished")
	_animate_out()

func _on_score_back_pressed() -> void:
	if _is_cyber_quiz:
		get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
		return
	emit_signal("quiz_finished")
	_animate_out()

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _show_screen(which: Screen) -> void:
	_current_screen     = which
	grid_screen.visible     = (which == Screen.GRID)
	question_screen.visible = (which == Screen.QUESTION)
	score_screen.visible    = (which == Screen.SCORE)

	var waiting_node = get_node_or_null("WaitingScreen")
	if waiting_node: waiting_node.visible = (which == Screen.WAITING)
	var lb_node = get_node_or_null("LeaderboardScreen")
	if lb_node: lb_node.visible = (which == Screen.LEADERBOARD)

	if which == Screen.GRID:
		var unanswered := 0
		for flag in answered_flags:
			if not flag: unanswered += 1
		grid_hint_label.text = "All done! Click Submit." if unanswered == 0 else "Click here to Start"

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _animate_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

func _animate_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_on_animate_out_done)

func _on_animate_out_done() -> void:
	visible = false

# ─────────────────────────────────────────────────────────────────────────────
# CYBERQUIZ: WAITING SCREEN
# ─────────────────────────────────────────────────────────────────────────────
var _lobby_panel_instance: Control = null

func _show_waiting_screen() -> void:
	grid_screen.visible     = false
	question_screen.visible = false
	score_screen.visible    = false

	var ws = get_node_or_null("WaitingScreen")
	if ws:
		ws.visible = true
		return

	ws = Control.new()
	ws.name = "WaitingScreen"
	ws.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ws)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.12, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ws.add_child(bg)

	var lobby_scene := preload("res://scene/TeacherRoomPanel.tscn")
	_lobby_panel_instance = lobby_scene.instantiate()
	_lobby_panel_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	ws.add_child(_lobby_panel_instance)

	if _lobby_panel_instance.has_method("show_lobby"):
		_lobby_panel_instance.show_lobby(
			_cyber_quiz_room_code, "CyberQuiz", "Multiple Choice", "", 10
		)
	if _lobby_panel_instance.has_method("start_server_polling"):
		_lobby_panel_instance.start_server_polling(
			_cyber_quiz_room_code, _cyber_quiz_lobby_url
		)

	# Hide Start button, chat, and back AFTER show_lobby (which re-enables them)
	var bottom_bar = _lobby_panel_instance.get_node_or_null("PanelBg/BottomBar")
	if bottom_bar:
		var start_btn  = bottom_bar.get_node_or_null("StartQuizButton")
		if start_btn:   start_btn.visible  = false
		var chat_input = bottom_bar.get_node_or_null("ChatInput")
		if chat_input:  chat_input.visible = false
	var top_bar = _lobby_panel_instance.get_node_or_null("PanelBg/TopBar")
	if top_bar:
		var back_btn = top_bar.get_node_or_null("BackButton")
		if back_btn: back_btn.visible = false

	var wait_label := Label.new()
	wait_label.name = "WaitingLabel"
	wait_label.text = "⏳ Waiting for teacher to start..."
	wait_label.add_theme_color_override("font_color", Color(0, 1, 1))
	wait_label.add_theme_font_size_override("font_size", 18)
	wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wait_label.offset_top    = -50
	wait_label.offset_bottom = -15
	ws.add_child(wait_label)

	var dot_timer := Timer.new()
	dot_timer.wait_time = 0.5
	dot_timer.autostart = true
	ws.add_child(dot_timer)
	var dc := [0]
	dot_timer.timeout.connect(func():
		dc[0] = (dc[0] % 3) + 1
		wait_label.text = "⏳ Waiting for teacher to start" + ".".repeat(dc[0])
	)

	_current_screen = Screen.WAITING

func _start_wait_polling() -> void:
	if _wait_poll_timer:
		_wait_poll_timer.queue_free()
	_wait_poll_timer = Timer.new()
	_wait_poll_timer.wait_time = 2.0
	_wait_poll_timer.autostart = true
	add_child(_wait_poll_timer)
	_wait_poll_timer.timeout.connect(_poll_quiz_status)

func _poll_quiz_status() -> void:
	if _cyber_quiz_lobby_url.is_empty(): return
	var url  := _cyber_quiz_lobby_url + "/api/quiz/%s/info" % _cyber_quiz_room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200: return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return
		var status: String = data.get("status", "waiting")
		if status == "active":
			print("[CyberQuiz] Quiz is active! Fetching questions...")
			if _wait_poll_timer:
				_wait_poll_timer.queue_free()
				_wait_poll_timer = null
			_fetch_questions()
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _fetch_questions() -> void:
	var url  := _cyber_quiz_lobby_url + "/api/quiz/%s/questions" % _cyber_quiz_room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200:
			push_error("[CyberQuiz] Failed to fetch questions: %d" % code)
			return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return

		var questions: Array = data.get("questions", [])
		var tpq: int         = data.get("time_per_question", 30)
		var quiz := {
			"questions":        questions,
			"total_questions":  questions.size(),
			"time_per_question": tpq,
			"quiz_timer":       tpq * questions.size() + 60,
		}

		if _lobby_panel_instance and _lobby_panel_instance.has_method("stop_server_polling"):
			_lobby_panel_instance.stop_server_polling()
		var ws = get_node_or_null("WaitingScreen")
		if ws: ws.visible = false

		print("[CyberQuiz] Received %d questions. Starting quiz!" % questions.size())
		for i in range(questions.size()):
			print("[CyberQuiz DEBUG] Q%d: choices=%s" % [i, str(questions[i].get("choices", []))])
		start_quiz(quiz)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

# ─────────────────────────────────────────────────────────────────────────────
# CYBERQUIZ: SUBMIT + LEADERBOARD
# ─────────────────────────────────────────────────────────────────────────────
func _submit_to_server_and_show_leaderboard(score: int = -1) -> void:
	if not _is_cyber_quiz or _cyber_quiz_lobby_url.is_empty(): return

	var url  := _cyber_quiz_lobby_url + "/api/quiz/%s/submit" % _cyber_quiz_room_code
	var body := {
		"player_id": Auth.current_local_id,
		"answers":   student_answers,
	}
	print("[CyberQuiz DEBUG] Submitting answers: %s" % str(student_answers))
	var headers := ["Content-Type: application/json"]
	var http    := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code == 200:
			var resp_text: String = resp_body.get_string_from_utf8()
			var resp_data = JSON.parse_string(resp_text)
			if typeof(resp_data) == TYPE_DICTIONARY:
				var server_score: int = resp_data.get("score", 0)
				var server_total: int = resp_data.get("total_questions", total_questions)
				print("[CyberQuiz] ✅ Server score: %d/%d" % [server_score, server_total])
				score_number.text = str(server_score)
				var pct := (float(server_score) / float(server_total)) * 100.0 if server_total > 0 else 0.0
				score_pct.text = "Percentage: %.0f%%" % pct
				if pct >= 80:
					score_message.text = "Great job soldier! 🎖️"
				elif pct >= 50:
					score_message.text = "Good effort! Keep it up! 💪"
				else:
					score_message.text = "Keep practicing soldier! 📚"
		else:
			push_error("[CyberQuiz] ❌ Submit failed: %d" % code)
		_fetch_leaderboard()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

# ── NEW: Submit and update score screen (no auto-leaderboard) ────────────────
func _submit_and_update_score() -> void:
	if not _is_cyber_quiz or _cyber_quiz_lobby_url.is_empty(): return
	var url  := _cyber_quiz_lobby_url + "/api/quiz/%s/submit" % _cyber_quiz_room_code
	var body := {
		"player_id": Auth.current_local_id,
		"answers":   student_answers,
	}
	print("[CyberQuiz DEBUG] Submitting answers for score update: %s" % str(student_answers))
	var headers := ["Content-Type: application/json"]
	var http    := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		_score_submitted = true
		if code != 200:
			push_error("[CyberQuiz] Submit failed: %d" % code)
			score_number.text = "?"
			score_pct.text = "Error submitting"
			done_btn.text = "View Leaderboard →"
			done_btn.disabled = false
			return

		var resp_text: String = resp_body.get_string_from_utf8()
		var resp_data = JSON.parse_string(resp_text)
		if typeof(resp_data) != TYPE_DICTIONARY:
			done_btn.text = "View Leaderboard →"
			done_btn.disabled = false
			return

		var server_score: int = resp_data.get("score", 0)
		var server_total: int = resp_data.get("total_questions", total_questions)
		_question_results = resp_data.get("question_results", [])
		_last_correct_count = server_score
		print("[CyberQuiz] Server score: %d/%d, question_results: %d items" % [server_score, server_total, _question_results.size()])

		# Update score display
		score_number.text = str(server_score)
		var pct := (float(server_score) / float(server_total)) * 100.0 if server_total > 0 else 0.0
		score_pct.text = "Percentage: %.0f%%" % pct
		if pct >= 80:
			score_message.text = "Great job soldier! 🎖️"
		elif pct >= 50:
			score_message.text = "Good effort! Keep it up! 💪"
		else:
			score_message.text = "Keep practicing soldier! 📚"

		# Color grid and enable wrong-answer review
		_update_score_grid_from_results()

		done_btn.text = "View Leaderboard →"
		done_btn.disabled = false
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _update_score_grid_from_results() -> void:
	var result_btns := score_grid.get_children()
	for i in range(result_btns.size()):
		var btn: Button = result_btns[i]
		if i >= _question_results.size(): continue
		var res: Dictionary = _question_results[i]
		var is_correct: bool = res.get("is_correct", false)
		var sb: StyleBoxFlat = _sb_correct if is_correct else _sb_wrong
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("disabled", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		if not is_correct:
			# Make wrong answers clickable for review
			btn.disabled = false
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.tooltip_text = "Click to review"
			var idx := i
			if not btn.pressed.is_connected(_on_review_btn_pressed):
				btn.pressed.connect(_on_review_btn_pressed.bind(idx))

func _on_review_btn_pressed(index: int) -> void:
	_show_question_review(index)

func _show_question_review(index: int) -> void:
	if index >= _question_results.size(): return
	var result: Dictionary = _question_results[index]
	var question_text: String = result.get("question_text", "Question %d" % (index + 1))
	var correct_answer: String = result.get("correct_answer", "")
	var student_answer: String = result.get("student_answer", "")
	var choices: Array = result.get("choices", [])

	# Remove existing review popup
	var existing = get_node_or_null("ReviewPopup")
	if existing: existing.queue_free()

	# Dimmed backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "ReviewPopup"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.6)
	add_child(backdrop)

	# Popup panel
	var popup := PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(520, 0)
	popup.offset_left = -260
	popup.offset_right = 260
	popup.offset_top = -200
	popup.offset_bottom = 200
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.04, 0.07, 0.16, 0.98)
	popup_style.border_color = Color(0, 1, 1, 0.8)
	popup_style.set_border_width_all(2)
	popup_style.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", popup_style)
	backdrop.add_child(popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "📋 Question %d — Review" % (index + 1)
	header.add_theme_color_override("font_color", Color(0, 1, 1))
	header.add_theme_font_size_override("font_size", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Question text
	var q_label := Label.new()
	q_label.text = question_text
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	q_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(q_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	# Choices with correct/wrong coloring
	for choice in choices:
		var choice_str: String = str(choice)
		var is_correct := choice_str.strip_edges().to_lower() == correct_answer.strip_edges().to_lower()
		var is_student_pick := choice_str.strip_edges().to_lower() == student_answer.strip_edges().to_lower()

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var icon_lbl := Label.new()
		icon_lbl.custom_minimum_size = Vector2(28, 0)
		icon_lbl.add_theme_font_size_override("font_size", 16)

		var choice_lbl := Label.new()
		choice_lbl.text = choice_str
		choice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_lbl.add_theme_font_size_override("font_size", 15)

		if is_correct:
			icon_lbl.text = "✅"
			choice_lbl.add_theme_color_override("font_color", Color(0.2, 1, 0.5))
		elif is_student_pick:
			icon_lbl.text = "❌"
			choice_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		else:
			icon_lbl.text = "  "
			choice_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

		row.add_child(icon_lbl)
		row.add_child(choice_lbl)

		# Highlight row background for student's pick
		if is_student_pick and not is_correct:
			var row_panel := PanelContainer.new()
			var row_sb := StyleBoxFlat.new()
			row_sb.bg_color = Color(0.5, 0.08, 0.08, 0.4)
			row_sb.set_corner_radius_all(6)
			row_sb.set_content_margin_all(6)
			row_panel.add_theme_stylebox_override("panel", row_sb)
			row_panel.add_child(row)
			vbox.add_child(row_panel)
		elif is_correct:
			var row_panel := PanelContainer.new()
			var row_sb := StyleBoxFlat.new()
			row_sb.bg_color = Color(0.05, 0.3, 0.1, 0.4)
			row_sb.set_corner_radius_all(6)
			row_sb.set_content_margin_all(6)
			row_panel.add_theme_stylebox_override("panel", row_sb)
			row_panel.add_child(row)
			vbox.add_child(row_panel)
		else:
			vbox.add_child(row)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(140, 44)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0, 0.4, 0.6, 0.9)
	close_sb.border_color = Color(0, 1, 1, 0.6)
	close_sb.set_border_width_all(1)
	close_sb.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func(): backdrop.queue_free())
	vbox.add_child(close_btn)

func _fetch_leaderboard() -> void:
	var url  := _cyber_quiz_lobby_url + "/api/quiz/%s/results" % _cyber_quiz_room_code
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if code != 200: return
		var text: String = resp_body.get_string_from_utf8()
		var data = JSON.parse_string(text)
		if typeof(data) != TYPE_DICTIONARY: return
		_show_leaderboard_screen(data)
	)
	http.request(url, [], HTTPClient.METHOD_GET)

func _show_leaderboard_screen(data: Dictionary) -> void:
	grid_screen.visible     = false
	question_screen.visible = false
	score_screen.visible    = false

	var lb = get_node_or_null("LeaderboardScreen")
	if lb: lb.queue_free()

	lb = Control.new()
	lb.name = "LeaderboardScreen"
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lb)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.04, 0.12, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb.add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 20; scroll.offset_bottom = -80
	scroll.offset_left = 40; scroll.offset_right = -40
	lb.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var header := Label.new()
	var total_q: int = data.get("total_questions", 0)
	header.text = "🏆 CyberQuiz Leaderboard"
	header.add_theme_color_override("font_color", Color(0, 1, 1))
	header.add_theme_font_size_override("font_size", 22)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sub_header := Label.new()
	sub_header.text = "%s — %d questions" % [data.get("room_name", ""), total_q]
	sub_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
	sub_header.add_theme_font_size_override("font_size", 14)
	sub_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_header)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var leaderboard: Array = data.get("leaderboard", [])
	for entry in leaderboard:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.custom_minimum_size = Vector2(0, 40)

		var rank_num: int = entry.get("rank", 0)
		var rank_lbl  := Label.new()
		var emoji     := "🥇" if rank_num == 1 else ("🥈" if rank_num == 2 else ("🥉" if rank_num == 3 else "#%d" % rank_num))
		rank_lbl.text = emoji
		rank_lbl.add_theme_font_size_override("font_size", 20)
		rank_lbl.custom_minimum_size = Vector2(50, 0)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		var uname: String = entry.get("username", "???")
		var is_me := (uname == Auth.current_username)
		name_lbl.text = uname + (" (You)" if is_me else "")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0, 1, 1) if is_me else Color(0.9, 0.95, 1))
		name_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(name_lbl)

		var score_lbl    := Label.new()
		var finished: bool = entry.get("finished", false)
		score_lbl.text = "%d/%d" % [entry.get("score", 0), total_q] if finished else "answering..."
		score_lbl.add_theme_color_override("font_color", Color(0, 1, 0.5) if finished else Color(0.7, 0.7, 0.7))
		score_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(score_lbl)

		if is_me:
			var row_panel := PanelContainer.new()
			var row_style := StyleBoxFlat.new()
			row_style.bg_color     = Color(0, 0.3, 0.5, 0.4)
			row_style.border_color = Color(0, 1, 1, 0.5)
			row_style.set_border_width_all(1)
			row_style.set_corner_radius_all(6)
			row_panel.add_theme_stylebox_override("panel", row_style)
			row_panel.add_child(row)
			vbox.add_child(row_panel)
		else:
			vbox.add_child(row)

	var done := Button.new()
	done.text = "← Back to Landing"
	done.custom_minimum_size = Vector2(220, 48)
	done.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	done.offset_top = -60; done.offset_bottom = -12
	done.offset_left = -110; done.offset_right = 110
	var done_sb := StyleBoxFlat.new()
	done_sb.bg_color     = Color(0, 0.5, 0.7, 0.9)
	done_sb.border_color = Color(0, 1, 1, 0.8)
	done_sb.set_border_width_all(2)
	done_sb.set_corner_radius_all(8)
	done.add_theme_stylebox_override("normal", done_sb)
	done.add_theme_color_override("font_color", Color(1, 1, 1))
	done.add_theme_font_size_override("font_size", 16)
	done.pressed.connect(func():
		get_tree().change_scene_to_file("res://scene/landing.tscn")
	)
	lb.add_child(done)

	_current_screen = Screen.LEADERBOARD