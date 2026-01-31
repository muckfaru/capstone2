extends Panel

signal feedback_complete

# Export texture variables so you can set them in the editor
@export var unlock_texture: Texture2D  # For correct answers
@export var lock_texture: Texture2D    # For wrong answers

@onready var result_icon = $VBox/ResultIcon
@onready var feedback_text = $VBox/FeedbackText
@onready var consequence_label = $VBox/ConsequenceLabel
@onready var auto_close_timer = $AutoCloseTimer

func _ready():
	# Load textures if not set in editor
	if not unlock_texture:
		unlock_texture = load("res://asset/minigamesicon/medunlock.png")
	if not lock_texture:
		lock_texture = load("res://asset/minigamesicon/medilock.png")

func show_feedback(is_correct: bool, feedback_message: String, score_change: int, scenario: Scenario):
	visible = true
	modulate = Color(1, 1, 1, 1)  # Reset opacity
	scale = Vector2(1, 1)  # Reset scale
	
	if is_correct:
		# Show unlock icon for correct answers
		result_icon.texture = unlock_texture
		result_icon.modulate = Color(1, 1, 1, 1)  # White (no tint)
		feedback_text.text = feedback_message
		consequence_label.text = "Trust Score: +" + str(score_change) + " | +10 XP"
		consequence_label.modulate = Color.GREEN
	else:
		# Show lock icon for wrong answers
		result_icon.texture = lock_texture
		result_icon.modulate = Color(1, 1, 1, 1)  # White (no tint)
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
