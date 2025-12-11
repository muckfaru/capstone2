# intro_scene.gd
# Introduction scene with talking guide before username creation
# UPDATED: Now redirects to landing_tutorial.tscn after username creation

extends Control

# Node references
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var dialogue_label: Label = $DialoguePanel/DialogueLabel
@onready var skip_button: Button = $SkipButton
@onready var hologram_guide: TextureRect = $HologramGuide
@onready var username_input: LineEdit = $UsernameInput
@onready var confirm_button: Button = $ConfirmButton

# Firestore configuration
const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

# Dialogue configuration
var dialogues := [
	"This is CyberArena, a private organization.",
	"Your early skills caught our attention",
	"You're not an expert yet… but your potential is clear.",
	"We've seen enough to know your capabilities so far.",
	"Every operative chooses their code name. Identify yourself."
]

# State variables
var current_dialogue_index := 0
var current_char_index := 0
var typing_speed := 0.05
var is_typing := false
var can_skip := false
var hologram_tween: Tween

func _ready() -> void:
	print("🎬 IntroScene started!")
	
	# Initialize UI
	dialogue_label.text = ""
	dialogue_panel.modulate.a = 1.0
	skip_button.visible = false
	hologram_guide.modulate.a = 0.0
	username_input.visible = false
	confirm_button.visible = false
	
	# Connect signals
	skip_button.pressed.connect(_on_skip_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	username_input.text_submitted.connect(_on_username_submitted)
	
	# Start introduction sequence
	await get_tree().create_timer(0.5).timeout
	_fade_in_hologram()
	await get_tree().create_timer(1.5).timeout
	_show_next_dialogue()

func _fade_in_hologram() -> void:
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

func _show_next_dialogue() -> void:
	print("💬 Showing dialogue #", current_dialogue_index)
	
	if current_dialogue_index >= dialogues.size():
		print("✅ All dialogues complete! Showing username input...")
		_stop_hologram_talk_animation()
		_show_username_input()
		return
	
	is_typing = true
	can_skip = false
	dialogue_label.text = ""
	current_char_index = 0
	skip_button.text = "Press ENTER to Continue >"
	skip_button.visible = false
	
	_start_hologram_talk_animation()
	
	var current_text: String = dialogues[current_dialogue_index]
	print("📝 Starting to type: ", current_text)
	_type_character(current_text)

func _type_character(full_text: String) -> void:
	if current_char_index < full_text.length():
		dialogue_label.text += full_text[current_char_index]
		current_char_index += 1
		
		await get_tree().create_timer(typing_speed).timeout
		_type_character(full_text)
	else:
		print("✅ Typing complete: ", dialogue_label.text)
		_on_typing_complete()

func _on_typing_complete() -> void:
	is_typing = false
	can_skip = true
	skip_button.visible = true
	
	_stop_hologram_talk_animation()
	
	await get_tree().create_timer(3.0).timeout
	if can_skip:
		_advance_dialogue()

func _advance_dialogue() -> void:
	if not can_skip:
		return
	
	can_skip = false
	current_dialogue_index += 1
	skip_button.visible = false
	
	await get_tree().create_timer(0.8).timeout
	_show_next_dialogue()

func _on_skip_pressed() -> void:
	if is_typing:
		dialogue_label.text = dialogues[current_dialogue_index]
		is_typing = false
		can_skip = true
		skip_button.text = "Press ENTER to Continue >"
		_stop_hologram_talk_animation()
	elif can_skip:
		_advance_dialogue()

func _show_username_input() -> void:
	print("📝 Showing username input...")
	
	skip_button.visible = false
	dialogue_label.text = "Enter your name above"
	
	username_input.visible = true
	confirm_button.visible = true
	username_input.modulate.a = 0.0
	confirm_button.modulate.a = 0.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(username_input, "modulate:a", 1.0, 0.5)
	tween.tween_property(confirm_button, "modulate:a", 1.0, 0.5)
	
	await tween.finished
	username_input.grab_focus()

func _on_username_submitted(_text: String) -> void:
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	
	if username == "":
		dialogue_label.text = "⚠️ Please enter a username."
		return
	
	if username.length() < 4:
		dialogue_label.text = "⚠️ Username must be at least 4 characters."
		return
	
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		dialogue_label.text = "⚠️ Missing Auth info. Please log in again."
		return
	
	username_input.editable = false
	confirm_button.disabled = true
	dialogue_label.text = "⏳ Checking existing profile..."
	
	var url: String = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: PackedStringArray = ["Authorization: Bearer %s" % Auth.current_id_token]
	
	var req := HTTPRequest.new()
	add_child(req)
	
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		
		if code == 200:
			print("✅ Existing user found, redirecting to landing.tscn...")
			get_tree().change_scene_to_file("res://scene/landing.tscn")
			return
		
		print("🆕 No existing user found (code: %s), creating new Firestore doc..." % code)
		_create_new_user(username)
	)
	
	var err := req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("Failed to start user check request: %s" % err)
		req.queue_free()
		username_input.editable = true
		confirm_button.disabled = false
		dialogue_label.text = "❌ Connection error. Try again."

func _create_new_user(username: String) -> void:
	dialogue_label.text = "⏳ Creating new profile..."
	
	# Create the Firestore document structure
	var body := {
		"fields": {
			"username": {"stringValue": username},
			"avatar": {"stringValue": "default.png"},
			"wins": {"integerValue": "0"},
			"losses": {"integerValue": "0"},
			"level": {"integerValue": "1"},
			"friends": {"arrayValue": {"values": []}},
			"requests_received": {"arrayValue": {"values": []}},
			"first_login": {"booleanValue": true},
			"tutorial_completed": {"booleanValue": false}
		}
	}
	
	var url: String = "%s/users?documentId=%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: PackedStringArray = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, response_body: PackedByteArray):
		http.queue_free()
		
		var text: String = response_body.get_string_from_utf8()
		print("Firestore Response: Code=%s, Body=%s" % [code, text])
		
		if code == 200 or code == 201:
			dialogue_label.text = "✅ Profile created successfully!"
			
			await get_tree().create_timer(1.0).timeout
			dialogue_label.text = "Welcome, %s!" % username
			
			# Redirect to tutorial for new users
			await get_tree().create_timer(2.0).timeout
			print("🎓 Redirecting to landing.tscn...")
			get_tree().change_scene_to_file("res://scene/landing.tscn")
		else:
			dialogue_label.text = "❌ Failed to create profile (Error %s)" % code
			push_warning("Firestore error: %s" % text)
			username_input.editable = true
			confirm_button.disabled = false
	)
	
	var json_string := JSON.stringify(body)
	print("Sending to Firestore: ", json_string)
	
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		push_error("Failed to start Firestore POST request: %s" % err)
		http.queue_free()
		username_input.editable = true
		confirm_button.disabled = false
		dialogue_label.text = "❌ Connection error. Try again."

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if can_skip or is_typing:
			_on_skip_pressed()
			accept_event()
