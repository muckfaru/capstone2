# landing_tutorial.gd
# Interactive tutorial that guides new users through the landing page features

extends Control

# Node references
@onready var overlay: ColorRect = $Overlay
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var dialogue_label: Label = $DialoguePanel/DialogueLabel
@onready var hologram_guide: TextureRect = $HologramGuide
@onready var skip_button: Button = $SkipButton
@onready var next_button: Button = $NextButton
@onready var highlight_box: Panel = $HighlightBox
@onready var progress_label: Label = $ProgressLabel



# Firestore configuration
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users"

# Tutorial steps configuration
var tutorial_steps := [
	{
		"text": "Welcome to Cyber Arena! I'm your guide. Let me show you around this platform.",
		"highlight": null,
		"wait_time": 0.5
	},
	{
		"text": "This navigation bar at the top helps you move between different sections.",
		"highlight": Vector2(0, 0),  # Will highlight navigation panel
		"size": Vector2(1920, 50),
		"wait_time": 0.8
	},
	{
		"text": "Click HOME to return to your main dashboard anytime.",
		"highlight": Vector2(200, 0),
		"size": Vector2(150, 50),
		"wait_time": 0.8
	},
	{
		"text": "The GAME section shows all available games. Some require XP to unlock!",
		"highlight": Vector2(350, 0),
		"size": Vector2(150, 50),
		"wait_time": 1.0
	},
	{
		"text": "Check RANKING to see top players and compete for the leaderboard!",
		"highlight": Vector2(500, 0),
		"size": Vector2(180, 50),
		"wait_time": 0.8
	},
	{
		"text": "Your PROFILE shows your stats, rank, and match history.",
		"highlight": Vector2(680, 0),
		"size": Vector2(160, 50),
		"wait_time": 0.8
	},
	{
		"text": "This is the most important: MODULE contains tutorials that teach you AND give you XP!",
		"highlight": Vector2(840, 0),
		"size": Vector2(170, 50),
		"wait_time": 1.2
	},
	{
		"text": "Complete tutorials to earn XP, unlock games, and climb ranks from Iron to Legend!",
		"highlight": null,
		"wait_time": 1.0
	},
	{
		"text": "Your friends list is here. Add friends to chat and play together!",
		"highlight": Vector2(1500, 100),
		"size": Vector2(300, 500),
		"wait_time": 0.8
	},
	{
		"text": "Ready to start? Head to MODULE and complete your first tutorial. Good luck, agent!",
		"highlight": null,
		"wait_time": 1.0
	}
]

# State variables
var current_step := 0
var is_typing := false
var current_char_index := 0
var typing_speed := 0.04
var hologram_tween: Tween

func _ready() -> void:
	print("🎓 Landing Tutorial Started!")
	
	# Initialize UI
	overlay.color = Color(0, 0, 0, 0.7)
	dialogue_label.text = ""
	highlight_box.visible = false
	next_button.disabled = true
	
	# Connect signals
	skip_button.pressed.connect(_on_skip_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# Start tutorial
	await get_tree().create_timer(0.5).timeout
	_fade_in_hologram()
	await get_tree().create_timer(1.0).timeout
	_show_current_step()

func _fade_in_hologram() -> void:
	hologram_guide.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(hologram_guide, "modulate:a", 1.0, 1.5)

func _start_hologram_talk_animation() -> void:
	if hologram_tween:
		hologram_tween.kill()
	
	hologram_tween = create_tween()
	hologram_tween.set_loops()
	hologram_tween.tween_property(hologram_guide, "modulate:a", 0.7, 0.4)
	hologram_tween.tween_property(hologram_guide, "modulate:a", 1.0, 0.4)

func _stop_hologram_talk_animation() -> void:
	if hologram_tween:
		hologram_tween.kill()
	
	var tween := create_tween()
	tween.tween_property(hologram_guide, "modulate:a", 1.0, 0.3)

func _show_current_step() -> void:
	if current_step >= tutorial_steps.size():
		_complete_tutorial()
		return
	
	var step: Dictionary = tutorial_steps[current_step]
	
	# Update progress
	progress_label.text = "Step %d/%d" % [current_step + 1, tutorial_steps.size()]
	
	# Show/hide highlight box
	if step.has("highlight") and step["highlight"] != null:
		_show_highlight(step["highlight"], step.get("size", Vector2(200, 100)))
	else:
		highlight_box.visible = false
	
	# Start typing dialogue
	is_typing = true
	dialogue_label.text = ""
	current_char_index = 0
	next_button.disabled = true
	
	_start_hologram_talk_animation()
	_type_character(step["text"])

func _type_character(full_text: String) -> void:
	if current_char_index < full_text.length():
		dialogue_label.text += full_text[current_char_index]
		current_char_index += 1
		
		await get_tree().create_timer(typing_speed).timeout
		_type_character(full_text)
	else:
		_on_typing_complete()

func _on_typing_complete() -> void:
	is_typing = false
	next_button.disabled = false
	_stop_hologram_talk_animation()
	
	var step: Dictionary = tutorial_steps[current_step]
	var wait_time: float = step.get("wait_time", 2.0)
	
	# Auto-advance after wait time
	await get_tree().create_timer(wait_time + 2.0).timeout
	if current_step < tutorial_steps.size():
		_on_next_pressed()

func _show_highlight(pos: Vector2, size: Vector2) -> void:
	highlight_box.visible = true
	highlight_box.position = pos
	highlight_box.size = size
	
	# Animate highlight
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(highlight_box, "modulate:a", 0.3, 0.8)
	tween.tween_property(highlight_box, "modulate:a", 0.6, 0.8)

func _on_next_pressed() -> void:
	if is_typing:
		# Skip typing animation
		dialogue_label.text = tutorial_steps[current_step]["text"]
		_on_typing_complete()
		return
	
	current_step += 1
	_show_current_step()

func _on_skip_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Skip Tutorial?"
	dialog.dialog_text = "Are you sure you want to skip the tutorial?\n\nYou can always access tutorials from the MODULE section."
	dialog.ok_button_text = "Skip"
	dialog.cancel_button_text = "Continue Tutorial"
	
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_complete_tutorial()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

func _complete_tutorial() -> void:
	print("✅ Tutorial Complete! Marking in Firestore...")
	
	# Show completion message
	dialogue_label.text = "Tutorial complete! Redirecting to landing page..."
	highlight_box.visible = false
	next_button.visible = false
	skip_button.visible = false
	
	# Mark tutorial as completed in Firestore
	_mark_tutorial_completed()

func _mark_tutorial_completed() -> void:
	var user_id := Auth.current_local_id
	var id_token := Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("⚠️ Auth info missing, cannot mark tutorial complete")
		_redirect_to_landing()
		return
	
	var url := "%s/%s?updateMask.fieldPaths=tutorial_completed&updateMask.fieldPaths=first_login" % [FIRESTORE_URL, user_id]
	var body := {
		"fields": {
			"tutorial_completed": {"booleanValue": true},
			"first_login": {"booleanValue": false}
		}
	}
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, _body):
		http.queue_free()
		
		if code == 200:
			print("✅ Tutorial marked complete in Firestore")
		else:
			push_warning("⚠️ Failed to mark tutorial complete: %s" % code)
		
		_redirect_to_landing()
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore request: %s" % err)
		http.queue_free()
		_redirect_to_landing()

func _redirect_to_landing() -> void:
	await get_tree().create_timer(1.5).timeout
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	
	get_tree().change_scene_to_file("res://scene/landing.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not next_button.disabled:
		_on_next_pressed()
		accept_event()
