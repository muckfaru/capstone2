extends Control

signal quiz_creation_completed(quiz_data: Dictionary)
signal quiz_creation_cancelled

class QuestionData:
	var question_text: String = ""
	var choices: Array[String] = ["", "", "", ""]
	var correct_answer: String = ""
	var is_completed: bool = false

	func is_valid() -> bool:
		if question_text.strip_edges().is_empty():
			return false
		for choice in choices:
			if choice.strip_edges().is_empty():
				return false
		if correct_answer.strip_edges().is_empty():
			return false
		var answer_lower := correct_answer.strip_edges().to_lower()
		for choice in choices:
			if choice.strip_edges().to_lower() == answer_lower:
				return true
		return false

	func to_dict() -> Dictionary:
		return {
			"question": question_text,
			"choices": choices.duplicate(),
			"correct_answer": correct_answer,
			"is_completed": is_completed
		}

var total_questions: int = 0
var time_per_question: int = 0

var current_question_index: int = 0
var questions_data: Array[QuestionData] = []
var minibox_buttons: Array[Button] = []

var _sb_empty: StyleBoxFlat
var _sb_completed: StyleBoxFlat
var _sb_current: StyleBoxFlat
var _sb_invalid: StyleBoxFlat

# Node paths — must match TSCN exactly
@onready var minibox_grid: GridContainer = $MainPanel/Root/TopPanel/ContentRow/MiniBoxGrid
@onready var q_num_lbl: Label = $MainPanel/Root/TopPanel/ContentRow/PreviewCol/QuestionNumberLabel
@onready var prev_question: Label = $MainPanel/Root/TopPanel/ContentRow/PreviewCol/PreviewQuestionLabel
@onready var prev_choices: GridContainer = $MainPanel/Root/TopPanel/ContentRow/PreviewCol/PreviewChoicesGrid
@onready var prev_answer: Label = $MainPanel/Root/TopPanel/ContentRow/PreviewCol/PreviewAnswerRow/PreviewAnswerValue

@onready var question_input: LineEdit = $MainPanel/Root/InputSection/QuestionInput
@onready var choice_inputs: Array[LineEdit] = [
	$MainPanel/Root/InputSection/ChoicesGrid/Choice1,
	$MainPanel/Root/InputSection/ChoicesGrid/Choice2,
	$MainPanel/Root/InputSection/ChoicesGrid/Choice3,
	$MainPanel/Root/InputSection/ChoicesGrid/Choice4,
]
@onready var answer_input: LineEdit = $MainPanel/Root/InputSection/AnswerSection/AnswerInput
@onready var next_button: Button = $MainPanel/Root/BottomBar/NextButton
@onready var done_button: Button = $MainPanel/Root/BottomBar/DoneButton

func _ready() -> void:
	_build_styles()
	visible = false

func _build_styles() -> void:
	# Empty — dark navy, faint cyan border
	_sb_empty = StyleBoxFlat.new()
	_sb_empty.bg_color = Color(0.031, 0.082, 0.208, 1.0)
	_sb_empty.set_border_width_all(2)
	_sb_empty.border_color = Color(0.145, 0.878, 0.992, 0.45)
	_sb_empty.set_corner_radius_all(5)

	# Completed — solid cyan fill
	_sb_completed = StyleBoxFlat.new()
	_sb_completed.bg_color = Color(0.145, 0.878, 0.992, 1.0)
	_sb_completed.set_border_width_all(2)
	_sb_completed.border_color = Color(0.145, 0.878, 0.992, 1.0)
	_sb_completed.set_corner_radius_all(5)

	# Current — dark navy bg + red border (focused question)
	_sb_current = StyleBoxFlat.new()
	_sb_current.bg_color = Color(0.031, 0.082, 0.208, 1.0)
	_sb_current.set_border_width_all(3)
	_sb_current.border_color = Color(1.0, 0.0, 0.0, 1.0)
	_sb_current.set_corner_radius_all(5)

	# Invalid — partial data, dark red bg + red border
	_sb_invalid = StyleBoxFlat.new()
	_sb_invalid.bg_color = Color(0.18, 0.04, 0.04, 0.9)
	_sb_invalid.set_border_width_all(2)
	_sb_invalid.border_color = Color(0.9, 0.15, 0.15, 1.0)
	_sb_invalid.set_corner_radius_all(5)

func initialize(num_questions: int, time_per_q: int) -> void:
	total_questions = num_questions
	time_per_question = time_per_q

	# Preserve existing question data instead of wiping it
	var old_data: Array[QuestionData] = questions_data.duplicate()

	questions_data.clear()
	for i in range(total_questions):
		if i < old_data.size():
			# Reuse the saved question data for existing slots
			questions_data.append(old_data[i])
		else:
			# Only create blank entries for NEW slots
			questions_data.append(QuestionData.new())

	_create_miniboxes()
	current_question_index = 0
	_load_question(0)
	_update_ui()
	visible = true
	_animate_in()
	
func _create_miniboxes() -> void:
	for child in minibox_grid.get_children():
		child.queue_free()
	minibox_buttons.clear()

	for i in range(total_questions):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.flat = false
		var idx := i
		btn.pressed.connect(func(): _on_minibox_pressed(idx))
		minibox_grid.add_child(btn)
		minibox_buttons.append(btn)

	_update_minibox_states()

func _apply_style(btn: Button, sb: StyleBoxFlat) -> void:
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_stylebox_override("disabled", sb)

func _update_minibox_states() -> void:
	for i in range(minibox_buttons.size()):
		var btn := minibox_buttons[i]
		var q := questions_data[i]
		var sb: StyleBoxFlat

		if i == current_question_index:
			sb = _sb_current
		elif q.is_completed:
			sb = _sb_completed
		elif _has_partial_data(q):
			sb = _sb_invalid
		else:
			sb = _sb_empty

		_apply_style(btn, sb)

func _has_partial_data(q: QuestionData) -> bool:
	if not q.question_text.strip_edges().is_empty(): return true
	for c in q.choices:
		if not c.strip_edges().is_empty(): return true
	if not q.correct_answer.strip_edges().is_empty(): return true
	return false

func _on_minibox_pressed(index: int) -> void:
	if index == current_question_index: return
	_save_current_question()
	current_question_index = index
	_load_question(index)
	_update_ui()

func _save_current_question() -> void:
	var q := questions_data[current_question_index]
	q.question_text = question_input.text
	q.choices[0] = choice_inputs[0].text
	q.choices[1] = choice_inputs[1].text
	q.choices[2] = choice_inputs[2].text
	q.choices[3] = choice_inputs[3].text
	q.correct_answer = answer_input.text
	q.is_completed = q.is_valid()

func _load_question(index: int) -> void:
	var q := questions_data[index]
	question_input.text = q.question_text
	choice_inputs[0].text = q.choices[0]
	choice_inputs[1].text = q.choices[1]
	choice_inputs[2].text = q.choices[2]
	choice_inputs[3].text = q.choices[3]
	answer_input.text = q.correct_answer
	_update_preview()

func _update_preview() -> void:
	var q := questions_data[current_question_index]
	q_num_lbl.text = "Q%d" % (current_question_index + 1)

	if q.question_text.strip_edges().is_empty():
		prev_question.visible = false
		prev_question.text = ""
	else:
		prev_question.visible = true
		prev_question.text = q.question_text

	for child in prev_choices.get_children():
		child.queue_free()
	for i in range(4):
		var txt := q.choices[i].strip_edges()
		if not txt.is_empty():
			var lbl := Label.new()
			lbl.text = txt
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.92, 1, 1))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prev_choices.add_child(lbl)

	prev_answer.text = q.correct_answer.strip_edges()

func _update_ui() -> void:
	q_num_lbl.text = "Q%d" % (current_question_index + 1)
	_update_minibox_states()
	_update_navigation_buttons()

func _update_navigation_buttons() -> void:
	var valid := questions_data[current_question_index].is_valid()
	if current_question_index < total_questions - 1:
		next_button.visible = true
		next_button.disabled = not valid
		done_button.visible = false
	else:
		next_button.visible = false
		done_button.visible = true
		done_button.disabled = not _all_questions_completed()

func _all_questions_completed() -> bool:
	for q in questions_data:
		if not q.is_completed or not q.is_valid(): return false
	return true

func _on_input_changed(_t: String = "") -> void:
	_save_current_question()
	_update_preview()
	_update_ui()

func _on_next_pressed() -> void:
	if current_question_index >= total_questions - 1: return
	_save_current_question()
	current_question_index += 1
	_load_question(current_question_index)
	_update_ui()
	_animate_question_transition()

func _on_done_pressed() -> void:
	if not _all_questions_completed():
		push_warning("[QuizCreationPanel] Not all questions complete.")
		return
	_save_current_question()
	var quiz_data := {
		"total_questions": total_questions,
		"time_per_question": time_per_question,
		"questions": []
	}
	for q in questions_data:
		quiz_data["questions"].append(q.to_dict())
	quiz_creation_completed.emit(quiz_data)
	_animate_out()

func _on_back_pressed() -> void:
	quiz_creation_cancelled.emit()
	_animate_out()

func _animate_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _animate_out() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_property(self, "scale", Vector2(0.95, 0.95), 0.2)
	tw.tween_callback(func(): visible = false)

func _animate_question_transition() -> void:
	var sec := $MainPanel/Root/InputSection
	var tw := create_tween()
	tw.tween_property(sec, "modulate:a", 0.3, 0.1)
	tw.tween_property(sec, "modulate:a", 1.0, 0.15)

func clear_all_data() -> void:
	for q in questions_data:
		q.question_text = ""
		q.choices = ["", "", "", ""]
		q.correct_answer = ""
		q.is_completed = false
	current_question_index = 0
	if questions_data.size() > 0:
		_load_question(0)
	_update_ui()

func load_existing_data(saved_questions: Array) -> void:
	for i in range(mini(saved_questions.size(), questions_data.size())):
		var src: Dictionary = saved_questions[i]
		var q: QuestionData = questions_data[i]
		q.question_text = src.get("question", "")
		q.choices[0] = src.get("choices", ["", "", "", ""])[0]
		q.choices[1] = src.get("choices", ["", "", "", ""])[1]
		q.choices[2] = src.get("choices", ["", "", "", ""])[2]
		q.choices[3] = src.get("choices", ["", "", "", ""])[3]
		q.correct_answer = src.get("correct_answer", "")
		q.is_completed = q.is_valid()
	_load_question(0)
	_update_ui()