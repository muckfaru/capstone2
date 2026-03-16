extends ColorRect

var score_label
var accuracy_label
var data_label
var network_label
var game_manager = null  # Reference for audio

func _ready():
	score_label = $VBox/ScoreLabel
	accuracy_label = $VBox/AccuracyLabel
	data_label = $VBox/DataLabel
	network_label = $VBox/NetworkLabel
	
	# Connect button sounds
	var retry_btn = $VBox/ButtonContainer/RetryButton
	var next_btn = $VBox/ButtonContainer/NextButton
	
	if retry_btn:
		retry_btn.mouse_entered.connect(_on_button_hover)
		retry_btn.pressed.connect(_on_button_click)
		if not retry_btn.pressed.is_connected(_on_retry_pressed):
			retry_btn.pressed.connect(_on_retry_pressed)
	if next_btn:
		next_btn.mouse_entered.connect(_on_button_hover)
		next_btn.pressed.connect(_on_button_click)
		if not next_btn.pressed.is_connected(_on_next_pressed):
			next_btn.pressed.connect(_on_next_pressed)

func _on_button_hover():
	if game_manager:
		game_manager._play_sfx(game_manager.audio_zone_hover, 0.1, 1.0)

func _on_button_click():
	if game_manager:
		game_manager._play_sfx(game_manager.audio_button_click, 0.05, 1.0)

func setup(final_score: int, accuracy: int, data_correct: int, data_total: int, network_correct: int, network_total: int):
	# Ensure nodes are ready
	if not is_node_ready():
		await ready
	
	score_label.text = "Final Score: %d" % final_score
	accuracy_label.text = "Accuracy: %d%%" % accuracy
	data_label.text = "Data Security: %d/%d %s" % [data_correct, data_total, "✓" if data_correct == data_total else ""]
	network_label.text = "Network Security: %d/%d %s" % [network_correct, network_total, "✓" if network_correct == network_total else ""]
	
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _on_retry_pressed():
	get_tree().reload_current_scene()

func _on_next_pressed():
	print("Returning to mode selection...")
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
