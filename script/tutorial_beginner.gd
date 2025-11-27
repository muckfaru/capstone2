extends Control

@onready var password_input: LineEdit = $WindowDialog/VBox/ContentPanel/MarginContainer/VBox/PasswordInput
@onready var progress_bar: ProgressBar = $WindowDialog/VBox/ContentPanel/MarginContainer/VBox/ProgressBar
@onready var next_button: Button = $WindowDialog/VBox/ContentPanel/MarginContainer/VBox/ButtonContainer/NextButton
@onready var timer_label: Label = $TimerLabel
@onready var dark_overlay: ColorRect = $DarkOverlay

# Password strength criteria
const MIN_LENGTH := 16
var strength_score := 0

# Timer system
const TIME_LIMIT := 30.0
var time_remaining := TIME_LIMIT
var timer_active := true

func _ready() -> void:
	# Disable NEXT button initially
	next_button.disabled = true
	
	# Configure progress bar
	progress_bar.value = 0
	progress_bar.max_value = 5.0
	_update_progress_bar_color(0)
	
	# Start timer
	time_remaining = TIME_LIMIT
	_update_timer_display()
	
	print("✅ Tutorial Beginner Scene Ready - Windows 95 Style!")


func _process(delta: float) -> void:
	if not timer_active:
		return
	
	# Countdown timer
	time_remaining -= delta
	_update_timer_display()
	
	# Time's up!
	if time_remaining <= 0.0:
		_on_time_expired()


func _update_timer_display() -> void:
	var total_seconds := floori(time_remaining)
	timer_label.text = "%d" % total_seconds
	
	# Change color based on time remaining
	if time_remaining < 10.0:
		timer_label.modulate = Color(1, 0, 0)
	elif time_remaining < 20.0:
		timer_label.modulate = Color(1, 0.5, 0)
	else:
		timer_label.modulate = Color(1, 0.3, 0.3)


func _on_time_expired() -> void:
	timer_active = false
	timer_label.text = "0"
	timer_label.modulate = Color(1, 0, 0)
	
	# Disable input
	password_input.editable = false
	next_button.disabled = true
	
	# Show dark overlay with warning popup
	dark_overlay.visible = true
	
	# Scale animation for popup
	var popup = dark_overlay.get_node("WarningPopup")
	popup.scale = Vector2(0, 0)
	popup.modulate.a = 0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	
	await tween.finished
	await get_tree().create_timer(3.0).timeout
	
	# Fade out and return to mode selection
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await fade_tween.finished
	
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


# -------------------------
# PASSWORD VALIDATION (Real-time)
# -------------------------
func _on_password_changed(new_text: String) -> void:
	strength_score = 0
	
	# Check length (most important)
	var length := new_text.length()
	if length >= MIN_LENGTH:
		strength_score += 2
	
	# Check uppercase
	if new_text != new_text.to_lower():
		strength_score += 1
	
	# Check numbers
	var has_number := false
	for i in range(10):
		if new_text.contains(str(i)):
			has_number = true
			break
	if has_number:
		strength_score += 1
	
	# Check special characters
	var has_special := false
	var specials := "!@#$%^&*()-_=+[]{}|;:'\",.<>?/`~"
	for c in new_text:
		if specials.contains(c):
			has_special = true
			break
	if has_special:
		strength_score += 1
	
	# Update progress bar (chunky blue blocks style)
	progress_bar.value = strength_score
	_update_progress_bar_color(strength_score)
	
	# Enable NEXT button when strong
	if strength_score == 5:
		next_button.disabled = false
	else:
		next_button.disabled = true


# -------------------------
# PROGRESS BAR COLOR (Chunky blue blocks style)
# -------------------------
func _update_progress_bar_color(score: int) -> void:
	match score:
		0:
			progress_bar.modulate = Color(0.5, 0.5, 0.5)  # Gray
		1:
			progress_bar.modulate = Color(1, 0, 0)  # Red
		2:
			progress_bar.modulate = Color(1, 0.5, 0)  # Orange
		3:
			progress_bar.modulate = Color(1, 1, 0)  # Yellow
		4:
			progress_bar.modulate = Color(0, 0.5, 1)  # Light blue
		5:
			progress_bar.modulate = Color(0, 0, 1)  # Blue


# -------------------------
# NEXT BUTTON (Submit password)
# -------------------------
func _on_next_pressed() -> void:
	if strength_score < 5:
		return
	
	print("✅ Password accepted:", password_input.text)
	timer_active = false
	
	# Navigate to next tutorial: Malware Types
	get_tree().change_scene_to_file("res://scene/tutorial_malware_types.tscn")


# -------------------------
# BACK BUTTON (Return to mode selection)
# -------------------------
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


# -------------------------
# X BUTTON (Close - same as BACK)
# -------------------------
func _on_close_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
