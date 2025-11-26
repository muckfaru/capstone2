extends Node3D

@onready var password_input: LineEdit = $CanvasLayer/TerminalUI/Panel/VBoxContainer/PasswordInput
@onready var strength_bar: ProgressBar = $CanvasLayer/TerminalUI/Panel/VBoxContainer/StrengthBar
@onready var feedback_label: Label = $CanvasLayer/TerminalUI/Panel/VBoxContainer/FeedbackLabel
@onready var ok_button: Button = $CanvasLayer/TerminalUI/Panel/VBoxContainer/ButtonContainer/OKButton
@onready var timer_label: Label = $CanvasLayer/HackerAlert/VBox/TimerLabel
@onready var alert_label: Label = $CanvasLayer/HackerAlert/VBox/AlertLabel
@onready var hacker_alert: PanelContainer = $CanvasLayer/HackerAlert
@onready var screen_light: OmniLight3D = $Terminal/Screen/ScreenLight
@onready var warning_label: Label = $CanvasLayer/TerminalUI/Panel/VBoxContainer/WarningLabel
@onready var hacker_progress_bar: ProgressBar = $CanvasLayer/TerminalUI/Panel/VBoxContainer/HackerProgressBar

# Password strength criteria
const MIN_LENGTH := 16
var strength_score := 0

# Timer system
const TIME_LIMIT := 30.0  # 30 seconds - one try only!
var time_remaining := TIME_LIMIT
var timer_active := true
var blink_time := 0.0

func _ready() -> void:
	# Disable OK button initially
	ok_button.disabled = true
	
	# Configure strength bar colors
	strength_bar.value = 0
	_update_strength_bar_color(0)
	
	# Initialize hacker progress bar
	hacker_progress_bar.max_value = TIME_LIMIT
	hacker_progress_bar.value = 0
	
	# Start timer
	time_remaining = TIME_LIMIT
	_update_timer_display()
	
	print("✅ Tutorial Beginner Scene Ready - Timer started!")


func _process(delta: float) -> void:
	if not timer_active:
		return
	
	# Countdown timer
	time_remaining -= delta
	_update_timer_display()
	
	# Update hacker progress bar (fills as time runs out)
	var progress := TIME_LIMIT - time_remaining
	hacker_progress_bar.value = progress
	
	# Change progress bar color based on progress
	if progress < 10.0:
		hacker_progress_bar.modulate = Color(1, 1, 0)  # Yellow - starting
	elif progress < 20.0:
		hacker_progress_bar.modulate = Color(1, 0.5, 0)  # Orange - halfway
	else:
		hacker_progress_bar.modulate = Color(1, 0, 0)  # Red - almost done
	
	# Blink warning label
	blink_time += delta
	var blink_speed := 2.0 if time_remaining < 10.0 else 1.0
	warning_label.modulate.a = 0.5 + abs(sin(blink_time * blink_speed * TAU)) * 0.5
	
	# Time's up!
	if time_remaining <= 0.0:
		_on_time_expired()


func _update_timer_display() -> void:
	var total_seconds := floori(time_remaining)
	timer_label.text = "%d" % total_seconds
	
	# Change color based on time remaining
	if time_remaining < 10.0:
		timer_label.modulate = Color(1, 0, 0)  # Red - critical
		alert_label.text = "🚨 CRITICAL! HACKER ALMOST IN! 🚨"
	elif time_remaining < 20.0:
		timer_label.modulate = Color(1, 0.5, 0)  # Orange - warning
		alert_label.text = "⚠️ WARNING! DATABASE BREACH IMMINENT ⚠️"
	else:
		timer_label.modulate = Color(1, 0.3, 0.3)  # Light red
		alert_label.text = "⚠️ SECURITY BREACH DETECTED ⚠️"


func _on_time_expired() -> void:
	timer_active = false
	timer_label.text = "0"
	alert_label.text = "💀 DATABASE COMPROMISED! 💀"
	feedback_label.text = "❌ TIME'S UP! Hacker got in!"
	feedback_label.modulate = Color(1, 0, 0)
	
	# Disable input
	password_input.editable = false
	ok_button.disabled = true
	
	# Flash red
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(hacker_alert, "modulate:a", 0.3, 0.3)
	tween.tween_property(hacker_alert, "modulate:a", 1.0, 0.3)
	
	await get_tree().create_timer(3.0).timeout
	
	# Return to mode selection
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")


# -------------------------
# PASSWORD VALIDATION (Real-time)
# -------------------------
func _on_password_changed(new_text: String) -> void:
	strength_score = 0
	var issues: Array[String] = []
	
	# Check length (most important)
	var length := new_text.length()
	if length >= MIN_LENGTH:
		strength_score += 2  # Length gives 2 points
	else:
		issues.append("❌ Need %d+ characters (%d/16)" % [MIN_LENGTH, length])
	
	# Check uppercase
	if new_text != new_text.to_lower():
		strength_score += 1
	else:
		issues.append("❌ Add uppercase letters")
	
	# Check numbers
	if new_text.contains("0") or new_text.contains("1") or new_text.contains("2") or \
	   new_text.contains("3") or new_text.contains("4") or new_text.contains("5") or \
	   new_text.contains("6") or new_text.contains("7") or new_text.contains("8") or \
	   new_text.contains("9"):
		strength_score += 1
	else:
		issues.append("❌ Add numbers")
	
	# Check special characters
	var has_special := false
	var specials := "!@#$%^&*()-_=+[]{}|;:'\",.<>?/`~"
	for c in new_text:
		if specials.contains(c):
			has_special = true
			break
	
	if has_special:
		strength_score += 1
	else:
		issues.append("❌ Add symbols (!@#$*)")
	
	# Update UI
	strength_bar.value = strength_score
	_update_strength_bar_color(strength_score)
	
	# Update feedback
	if strength_score == 5:
		feedback_label.text = "✅ STRONG PASSWORD! Ready to submit."
		feedback_label.modulate = Color(0, 1, 0)  # Green
		ok_button.disabled = false
	elif length == 0:
		feedback_label.text = "Waiting for input..."
		feedback_label.modulate = Color(1, 0.7, 0)  # Orange
		ok_button.disabled = true
	else:
		feedback_label.text = "\n".join(issues)
		feedback_label.modulate = Color(1, 0.3, 0.3)  # Red
		ok_button.disabled = true
	
	# Estimate cracking time (simplified)
	if strength_score >= 4:
		feedback_label.text += "\n🔒 Cracking Time: 1000+ years"
	elif strength_score >= 3:
		feedback_label.text += "\n⚠️ Cracking Time: 10-100 years"
	elif strength_score >= 1 and length > 0:
		feedback_label.text += "\n⚠️ Cracking Time: Days to months"


# -------------------------
# STRENGTH BAR COLOR (Visual feedback)
# -------------------------
func _update_strength_bar_color(score: int) -> void:
	match score:
		0:
			strength_bar.modulate = Color(0.3, 0.3, 0.3)  # Gray
		1:
			strength_bar.modulate = Color(1, 0, 0)  # Red
		2:
			strength_bar.modulate = Color(1, 0.5, 0)  # Orange
		3:
			strength_bar.modulate = Color(1, 1, 0)  # Yellow
		4:
			strength_bar.modulate = Color(0.5, 1, 0)  # Light green
		5:
			strength_bar.modulate = Color(0, 1, 0)  # Green


# -------------------------
# OK BUTTON (Submit password)
# -------------------------
func _on_ok_pressed() -> void:
	if strength_score < 5:
		feedback_label.text = "❌ Password not strong enough!"
		return
	
	print("✅ Password accepted:", password_input.text)
	feedback_label.text = "✅ Password saved! Hacker blocked!"
	
	# Stop timer
	timer_active = false
	alert_label.text = "✅ SECURITY RESTORED! ✅"
	alert_label.modulate = Color(0, 1, 0)
	timer_label.modulate = Color(0, 1, 0)
	
	# Success animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hacker_alert, "modulate", Color(0, 1, 0, 1), 0.3)
	tween.tween_property($CanvasLayer/TerminalUI, "modulate:a", 0.0, 0.5)
	tween.tween_property($Camera3D, "fov", 30.0, 0.5)
	
	await tween.finished
	
	# TODO: Save progress to Firestore (beginner module 1 complete)
	# For now, go to landing
	get_tree().change_scene_to_file("res://scene/landing.tscn")


# -------------------------
# BACK BUTTON (Return to mode selection)
# -------------------------
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")
