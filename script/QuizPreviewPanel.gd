extends Control

signal preview_closed

var quiz_data: Dictionary = {}
var current_page: int = 0
var total_questions: int = 0
var time_per_question: int = 0
var quiz_timer_seconds: int = 0

var _timer_running: bool = false
var _elapsed: float = 0.0

@onready var back_btn: Button         = $TopBar/BackButton
@onready var timer_label: Label       = $TopBar/TimerLabel
@onready var question_card: Panel     = $CardArea/QuestionCard
@onready var tpq_circle: Panel        = $CardArea/QuestionCard/TPQCircle
@onready var tpq_label: Label         = $CardArea/QuestionCard/TPQCircle/TPQLabel
@onready var question_label: Label    = $CardArea/QuestionCard/QuestionLabel
@onready var prev_btn: Button         = $BottomBar/PrevButton
@onready var page_label: Label        = $BottomBar/PageLabel
@onready var next_btn: Button         = $BottomBar/NextButton

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if not _timer_running: return
	_elapsed += delta
	var remaining := maxi(0, quiz_timer_seconds - int(_elapsed))
	_update_timer_display(remaining)
	if remaining <= 0:
		_timer_running = false

func show_preview(data: Dictionary) -> void:
	quiz_data          = data
	total_questions    = data.get("total_questions", 0)
	time_per_question  = data.get("time_per_question", 0)
	quiz_timer_seconds = data.get("quiz_timer", 0)
	current_page       = 0
	_elapsed           = 0.0
	_timer_running     = true

	visible = true
	_update_timer_display(quiz_timer_seconds)
	_update_tpq_circle()
	_render_question(current_page)
	_update_pagination()
	_animate_in()

func _update_timer_display(remaining: int) -> void:
	var h  := remaining / 3600
	var m  := (remaining % 3600) / 60
	var s  := remaining % 60
	if h > 0:
		timer_label.text = "%02d:%02d:%02d" % [h, m, s]
	else:
		timer_label.text = "%02d:%02d" % [m, s]

func _update_tpq_circle() -> void:
	tpq_label.text = "%ds" % time_per_question

func _render_question(index: int) -> void:
	if index >= total_questions: return
	var questions: Array = quiz_data.get("questions", [])
	if index >= questions.size(): return
	var q: Dictionary = questions[index]

	question_label.text = "Question # %d\n\n%s" % [index + 1, q.get("question", "")]

	# Clear old choices
	for child in question_card.get_children():
		if child.name.begins_with("ChoiceRow"):
			child.queue_free()

	# Build choices below the question label
	var choices: Array  = q.get("choices", [])
	var correct: String = q.get("correct_answer", "").strip_edges().to_lower()
	var letters         := ["A", "B", "C", "D"]

	for i in range(choices.size()):
		var choice_text: String = choices[i]
		var is_correct: bool    = choice_text.strip_edges().to_lower() == correct

		var row := HBoxContainer.new()
		row.name = "ChoiceRow%d" % i
		row.add_theme_constant_override("separation", 8)
		row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		row.offset_top    = 220 + i * 48
		row.offset_bottom = row.offset_top + 38
		row.offset_left   = 28
		row.offset_right  = -28
		question_card.add_child(row)

		var letter_lbl := Label.new()
		letter_lbl.text = letters[i] if i < letters.size() else str(i + 1)
		letter_lbl.custom_minimum_size = Vector2(32, 32)
		letter_lbl.add_theme_font_size_override("font_size", 13)
		letter_lbl.add_theme_color_override("font_color",
			Color(0.03, 0.05, 0.12, 1) if is_correct else Color(0.145, 0.878, 0.992, 1))
		letter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		row.add_child(letter_lbl)

		var choice_lbl := Label.new()
		choice_lbl.text = choice_text
		choice_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice_lbl.add_theme_font_size_override("font_size", 14)
		choice_lbl.add_theme_color_override("font_color",
			Color(0.145, 0.878, 0.992, 1.0) if is_correct else Color(0.78, 0.88, 1.0, 1.0))
		choice_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(choice_lbl)

		if is_correct:
			var check := Label.new()
			check.text = "✓"
			check.add_theme_font_size_override("font_size", 16)
			check.add_theme_color_override("font_color", Color(0.145, 0.878, 0.992, 1.0))
			check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(check)

	# Animate card
	question_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(question_card, "modulate:a", 1.0, 0.18)

func _update_pagination() -> void:
	page_label.text   = "%d / %d" % [current_page + 1, total_questions]
	prev_btn.visible  = current_page > 0
	next_btn.visible  = current_page < total_questions - 1

func _on_prev_pressed() -> void:
	if current_page <= 0: return
	current_page -= 1
	_render_question(current_page)
	_update_pagination()

func _on_next_pressed() -> void:
	if current_page >= total_questions - 1: return
	current_page += 1
	_render_question(current_page)
	_update_pagination()

func _on_back_pressed() -> void:
	_timer_running = false
	preview_closed.emit()
	_animate_out()

func _animate_in() -> void:
	modulate.a = 0.0
	scale      = Vector2(0.96, 0.96)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "scale", Vector2(0.96, 0.96), 0.18)
	tw.tween_callback(_on_animate_out_done)

func _on_animate_out_done() -> void:
	visible = false