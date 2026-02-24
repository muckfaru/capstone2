extends Control

# ── Signals ──────────────────────────────────────────────────────────────────
signal quiz_finished

# ── State ────────────────────────────────────────────────────────────────────
enum Screen { GRID, QUESTION, SCORE }

var quiz_data: Dictionary       = {}
var total_questions: int        = 0
var time_per_question: int      = 0
var quiz_timer_seconds: int     = 0
var current_question_index: int = 0

# Per-question tracking
var student_answers: Array      = []   # String per question ("" = unanswered)
var answered_flags: Array       = []   # bool per question

var _quiz_elapsed: float        = 0.0
var _quiz_timer_running: bool   = false
var _q_elapsed: float           = 0.0
var _q_timer_running: bool      = false

# ── Screen roots ─────────────────────────────────────────────────────────────
@onready var grid_screen:     Control = $GridScreen
@onready var question_screen: Control = $QuestionScreen
@onready var score_screen:    Control = $ScoreScreen

# ── Grid screen nodes ─────────────────────────────────────────────────────────
@onready var grid_back_btn:   Button        = $GridScreen/TopBar/BackButton
@onready var grid_hint_label: Label         = $GridScreen/TopBar/HintLabel
@onready var grid_timer_lbl:  Label         = $GridScreen/TopBar/TimerLabel
@onready var question_grid:   GridContainer = $GridScreen/QuestionGrid
@onready var submit_btn:      Button        = $GridScreen/SubmitButton

# ── Question screen nodes ─────────────────────────────────────────────────────
@onready var q_back_btn:      Button = $QuestionScreen/TopBar/BackButton
@onready var q_timer_lbl:     Label  = $QuestionScreen/TopBar/TimerLabel
@onready var q_tpq_label:     Label  = $QuestionScreen/Card/TPQCircle/TPQLabel
@onready var q_title_label:   Label  = $QuestionScreen/Card/QuestionLabel
@onready var q_next_btn:      Button = $QuestionScreen/NextButton

# ── Score screen nodes ────────────────────────────────────────────────────────
@onready var score_back_btn:  Button        = $ScoreScreen/TopBar/BackButton
@onready var score_number:    Label         = $ScoreScreen/ScorePanel/ScoreNumber
@onready var score_pct:       Label         = $ScoreScreen/ScorePanel/PctLabel
@onready var score_grid:      GridContainer = $ScoreScreen/ResultGrid
@onready var score_message:   Label         = $ScoreScreen/MessageLabel
@onready var done_btn:        Button        = $ScoreScreen/DoneButton

var _grid_buttons: Array[Button] = []

# ── Styles ────────────────────────────────────────────────────────────────────
var _sb_unanswered: StyleBoxFlat
var _sb_answered:   StyleBoxFlat
var _sb_correct:    StyleBoxFlat
var _sb_wrong:      StyleBoxFlat

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false
	_build_styles()

func _build_styles() -> void:
	_sb_unanswered = _make_sb(Color(0.04, 0.10, 0.28, 1.0), Color(0.145, 0.878, 0.992, 0.4))
	_sb_answered   = _make_sb(Color(0.145, 0.878, 0.992, 1.0), Color(0.145, 0.878, 0.992, 1.0))
	_sb_correct    = _make_sb(Color(0.145, 0.878, 0.992, 1.0), Color(0.145, 0.878, 0.992, 1.0))
	_sb_wrong      = _make_sb(Color(0.85, 0.10, 0.10, 1.0),    Color(1.0,   0.15, 0.15, 1.0))

func _make_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.shadow_color = border
	s.shadow_size  = 6 if border.a > 0.5 else 0
	return s

# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────
func start_quiz(data: Dictionary) -> void:
	quiz_data          = data
	total_questions    = data.get("total_questions", 0)
	time_per_question  = data.get("time_per_question", 30)
	quiz_timer_seconds = data.get("quiz_timer", 1800)

	student_answers.clear()
	answered_flags.clear()
	for i in range(total_questions):
		student_answers.append("")
		answered_flags.append(false)

	_quiz_elapsed       = 0.0
	_quiz_timer_running = true
	visible             = true

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
	var h  := remaining / 3600
	var m  := (remaining % 3600) / 60
	var s  := remaining % 60
	if h > 0:
		lbl.text = "%02d:%02d:%02d" % [h, m, s]
	else:
		lbl.text = "%02d:%02d:%02d" % [0, m, s]

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
		btn.custom_minimum_size        = Vector2(80, 80)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.flat                       = false
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
		if answered_flags[i]:
			btn.add_theme_stylebox_override("normal",  _sb_answered)
			btn.add_theme_stylebox_override("hover",   _sb_answered)
			btn.add_theme_stylebox_override("pressed", _sb_answered)
		else:
			btn.add_theme_stylebox_override("normal",  _sb_unanswered)
			btn.add_theme_stylebox_override("hover",   _sb_unanswered)
			btn.add_theme_stylebox_override("pressed", _sb_unanswered)

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

	# Show next or done
	if index >= total_questions - 1:
		q_next_btn.text = "Done"
	else:
		q_next_btn.text = "Next →"

	# Mark as answered immediately on open (student viewed it)
	# Real answer tracking would happen here with choice buttons
	answered_flags[index] = true
	student_answers[index] = "viewed"  # placeholder until answer buttons added

	_update_grid_visuals()
	_update_submit_button()

	# Animate card
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
	_show_score()

# ─────────────────────────────────────────────────────────────────────────────
# SCORE SCREEN
# ─────────────────────────────────────────────────────────────────────────────
func _show_score() -> void:
	_show_screen(Screen.SCORE)
	_build_score_grid()

	# For now score = number of answered questions (placeholder)
	# Real scoring: compare student_answers[i] with correct_answer
	var questions: Array = quiz_data.get("questions", [])
	var correct_count := 0
	var correct_flags: Array[bool] = []

	for i in range(total_questions):
		var q: Dictionary = questions[i] if i < questions.size() else {}
		var correct_ans: String = q.get("correct_answer", "").strip_edges().to_lower()
		var student_ans: String = student_answers[i].strip_edges().to_lower()
		var is_correct := student_ans != "" and student_ans == correct_ans
		correct_flags.append(is_correct)
		if is_correct:
			correct_count += 1

	score_number.text = str(correct_count)
	var pct := (float(correct_count) / float(total_questions)) * 100.0 if total_questions > 0 else 0.0
	score_pct.text    = "Percentage: %.0f%%" % pct

	# Color the result grid boxes
	var result_btns := score_grid.get_children()
	for i in range(result_btns.size()):
		var btn: Button = result_btns[i]
		if i < correct_flags.size():
			if correct_flags[i]:
				btn.add_theme_stylebox_override("normal", _sb_correct)
			else:
				btn.add_theme_stylebox_override("normal", _sb_wrong)

	# Message
	if pct >= 80:
		score_message.text = "Great job soldier! 🎖️"
	elif pct >= 50:
		score_message.text = "Good effort! Keep it up! 💪"
	else:
		score_message.text = "Keep practicing soldier! 📚"

func _build_score_grid() -> void:
	for child in score_grid.get_children():
		child.queue_free()
	for i in range(total_questions):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.disabled            = true
		btn.flat                = false
		btn.add_theme_stylebox_override("normal",   _sb_unanswered)
		btn.add_theme_stylebox_override("disabled", _sb_unanswered)
		score_grid.add_child(btn)

func _on_done_pressed() -> void:
	emit_signal("quiz_finished")
	_animate_out()

func _on_score_back_pressed() -> void:
	emit_signal("quiz_finished")
	_animate_out()

# ─────────────────────────────────────────────────────────────────────────────
# SCREEN MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _show_screen(which: Screen) -> void:
	_current_screen       = which
	grid_screen.visible     = (which == Screen.GRID)
	question_screen.visible = (which == Screen.QUESTION)
	score_screen.visible    = (which == Screen.SCORE)

	# Hint label update
	if which == Screen.GRID:
		var unanswered := 0
		for flag in answered_flags:
			if not flag: unanswered += 1
		if unanswered == 0:
			grid_hint_label.text = "All done! Click Submit."
		else:
			grid_hint_label.text = "Click here to Start"

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