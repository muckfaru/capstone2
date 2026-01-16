extends ColorRect

@onready var score_label = $VBox/ScoreLabel
@onready var accuracy_label = $VBox/AccuracyLabel
@onready var data_label = $VBox/DataLabel
@onready var network_label = $VBox/NetworkLabel

func setup(final_score: int, accuracy: int, data_correct: int, data_total: int, network_correct: int, network_total: int):
	score_label.text = "Final Score: %d" % final_score
	accuracy_label.text = "Accuracy: %d%%" % accuracy
	data_label.text = "📁 Data Security: %d/%d %s" % [data_correct, data_total, "✓" if data_correct == data_total else ""]
	network_label.text = "🌐 Network Security: %d/%d %s" % [network_correct, network_total, "✓" if network_correct == network_total else ""]
	
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_retry_pressed():
	get_tree().reload_current_scene()

func _on_next_pressed():
	# TODO: Load next lesson scene
	print("Next lesson not implemented yet")
	get_tree().quit()