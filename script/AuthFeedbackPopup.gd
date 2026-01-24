extends Panel

signal feedback_complete

@onready var result_icon = $VBox/ResultIcon
@onready var feedback_text = $VBox/FeedbackText
@onready var consequence_label = $VBox/ConsequenceLabel
@onready var auto_close_timer = $AutoCloseTimer

func show_feedback(is_correct: bool, feedback_message: String, score_change: int, scenario: Scenario):
	visible = true
	modulate = Color(1, 1, 1, 1)  # Reset opacity
	scale = Vector2(1, 1)  # Reset scale
	
	if is_correct:
		result_icon.text = "✅"
		result_icon.modulate = Color.GREEN
		feedback_text.text = feedback_message
		consequence_label.text = "Trust Score: +" + str(score_change) + " | +10 XP"
		consequence_label.modulate = Color.GREEN
	else:
		result_icon.text = "❌"
		result_icon.modulate = Color.RED
		feedback_text.text = feedback_message
		consequence_label.text = "Trust Score: -" + str(scenario.threat_consequence)
		consequence_label.modulate = Color.RED
		
		if scenario.is_attacker:
			consequence_label.text += " | BREACH DETECTED!"
	
	# Simple popup animation using Tween
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.3).from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0)
	
	# Start auto-close timer
	auto_close_timer.start()

func _on_auto_close_timer_timeout():
	# Simple fadeout using Tween
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3).from(1.0)
	await tween.finished
	visible = false
	emit_signal("feedback_complete")