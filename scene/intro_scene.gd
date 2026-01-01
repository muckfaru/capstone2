# intro_scene.gd - Redesigned UI
# Introduction scene with Pokemon-style dialogue box
# UPDATED: New clean UI design with portrait and corner accents

extends Control

# Node references
@onready var dialogue_box: MarginContainer = $DialogueBox
@onready var agent_label: Label = $DialogueBox/MainPanel/HBoxContainer/VBoxContainer/MarginContainer/VBox/AgentLabel
@onready var dialogue_text: Label = $DialogueBox/MainPanel/HBoxContainer/VBoxContainer/MarginContainer/VBox/DialogueText
@onready var continue_indicator: Label = $DialogueBox/MainPanel/HBoxContainer/VBoxContainer/ContinueIndicator
@onready var hologram_guide: TextureRect = $DialogueBox/MainPanel/HBoxContainer/Portrait/MarginContainer/HologramGuide
@onready var username_input: LineEdit = $UsernameInput
@onready var confirm_button: Button = $ConfirmButton
@onready var overlay: ColorRect = $Overlay
@onready var terminal_panel: Panel = $TerminalPanel
@onready var terminal_output: RichTextLabel = $TerminalPanel/MarginContainer/VBoxContainer/TerminalOutput
@onready var terminal_overlay: ColorRect = $TerminalOverlay
@onready var fade_overlay: ColorRect = $FadeOverlay
# Audio players
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var typing_sfx_player: AudioStreamPlayer = $TypingSFXPlayer
@onready var special_sfx_player: AudioStreamPlayer = $SpecialSFXPlayer
@onready var progress_loop_player: AudioStreamPlayer = $ProgressLoopPlayer

# Audio exports
@export_group("Background Music")
@export var intro_music: AudioStream  ## Ambient music for intro dialogue
@export var terminal_music: AudioStream  ## Tense music for terminal verification
@export var music_volume: float = -10.0  ## Volume in dB (-80 to 0)

@export_group("Terminal Sound Effects")
@export var typing_sfx: Array[AudioStream] = []  ## Multiple typing sounds for variation
@export var typing_volume: float = -15.0  ## Volume in dB
@export var typing_pitch_min: float = 0.9  ## Minimum pitch variation
@export var typing_pitch_max: float = 1.1  ## Maximum pitch variation

@export_group("Special Sound Effects")
@export var line_complete_sfx: AudioStream  ## Sound when a line finishes typing
@export var success_sfx: AudioStream  ## Success/confirmation sound
@export var error_sfx: AudioStream  ## Error sound
@export var progress_loop_sfx: AudioStream  ## Looping sound for progress bars
@export var matrix_scramble_sfx: AudioStream  ## Sound for matrix text effect
@export var sfx_volume: float = -10.0  ## Volume in dB for special effects

# Firestore configuration
const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

# Dialogue configuration
var dialogues := [
	"Welcome, operative. This is Cyber Arena, the ultimate battleground for those who want to prove their skills.",
	"If you seek to learn and compete, you've come to the right place.",
	"Here, you'll find various modules to train your abilities, games to test your mettle, and a community of like-minded individuals.",
	"So, Claim your spot in the Cyber Arena",
	"But first, we need to establish your identity. Every operative needs a codename.",
	"Please enter your operative codename below. Choose wisely; this will be your identity in the arena."
]

# State variables
var current_dialogue_index := 0
var current_char_index := 0
var typing_speed := 0.03  # Faster typing
var is_typing := false
var can_skip := false
var hologram_tween: Tween
var indicator_tween: Tween
var is_showing_username_input := false  # Track if we're in input mode
var cursor_blink_timer := 0.0
var is_terminal_active := false
var pending_username := ""  # Store username for terminal operations

# Terminal colors
const COLOR_SUCCESS := Color(0.2, 1.0, 0.3)  # Green
const COLOR_PROCESSING := Color(0.2, 1.0, 0.3)  # Green (changed from yellow)
const COLOR_ERROR := Color(1.0, 0.2, 0.2)  # Red
const COLOR_INFO := Color(0.2, 1.0, 0.3)  # Green (changed from cyan)
const COLOR_DEFAULT := Color(0.2, 1.0, 0.3)  # Green (changed from gray)

# Random characters for matrix effect
const MATRIX_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"

func _ready() -> void:
	print("🎬 IntroScene started (Redesigned UI)!")
	
	# Safety check: if user already has username, skip to landing (prevents story replay)
	if Auth.current_username != "" and Auth.current_username != null:
		print("⚠️ User already has username, skipping to landing")
		get_tree().change_scene_to_file("res://scene/landing.tscn")
		return
	
	# Initialize UI
	dialogue_text.text = ""
	dialogue_box.modulate.a = 0.0
	continue_indicator.visible = false
	username_input.visible = false
	confirm_button.visible = false
	overlay.modulate.a = 0.0
	terminal_panel.visible = false
	terminal_overlay.visible = false
	terminal_output.text = ""
	
	# Setup audio
	_setup_audio()
	
	# Connect signals
	confirm_button.pressed.connect(_on_confirm_pressed)
	username_input.text_submitted.connect(_on_username_submitted)
	
	# Make dialogue box clickable
	dialogue_box.gui_input.connect(_on_dialogue_box_clicked)
	
	# Start introduction sequence
	await get_tree().create_timer(0.5).timeout
	_play_music(intro_music)
	_fade_in_overlay()
	await get_tree().create_timer(0.8).timeout
	_fade_in_dialogue_box()
	await get_tree().create_timer(0.5).timeout
	_show_next_dialogue()

func _setup_audio() -> void:
	# Configure audio players
	if music_player:
		music_player.volume_db = music_volume
	if typing_sfx_player:
		typing_sfx_player.volume_db = typing_volume
	if special_sfx_player:
		special_sfx_player.volume_db = sfx_volume
	if progress_loop_player:
		progress_loop_player.volume_db = sfx_volume

func _process(delta: float) -> void:
	if is_terminal_active:
		cursor_blink_timer += delta
		# Cursor blink is handled by the terminal text output

func _fade_in_overlay() -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 1.0)

func _fade_in_dialogue_box() -> void:
	var tween := create_tween()
	tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.8)

func _start_hologram_talk_animation() -> void:
	if hologram_tween:
		hologram_tween.kill()
	
	hologram_tween = create_tween()
	hologram_tween.set_loops()
	hologram_tween.tween_property(hologram_guide, "modulate:a", 0.6, 0.3)
	hologram_tween.tween_property(hologram_guide, "modulate:a", 1.0, 0.3)

func _stop_hologram_talk_animation() -> void:
	if hologram_tween:
		hologram_tween.kill()
	
	var tween := create_tween()
	tween.tween_property(hologram_guide, "modulate:a", 1.0, 0.2)

func _animate_continue_indicator() -> void:
	if indicator_tween:
		indicator_tween.kill()
	
	continue_indicator.visible = true
	indicator_tween = create_tween()
	indicator_tween.set_loops()
	indicator_tween.tween_property(continue_indicator, "modulate:a", 0.5, 0.5)
	indicator_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)

func _stop_continue_indicator() -> void:
	if indicator_tween:
		indicator_tween.kill()
	continue_indicator.visible = false

func _show_next_dialogue() -> void:
	print("💬 Showing dialogue #", current_dialogue_index)
	
	if current_dialogue_index >= dialogues.size():
		print("✅ All dialogues complete! Showing username input...")
		_stop_hologram_talk_animation()
		_stop_continue_indicator()
		_show_username_input()
		return
	
	is_typing = true
	can_skip = false
	dialogue_text.text = ""
	current_char_index = 0
	_stop_continue_indicator()
	
	_start_hologram_talk_animation()
	
	var current_text: String = dialogues[current_dialogue_index]
	print("📝 Starting to type: ", current_text)
	_type_character(current_text)

func _type_character(full_text: String) -> void:
	if current_char_index < full_text.length():
		dialogue_text.text += full_text[current_char_index]
		current_char_index += 1
		
		# Play typing sound
		_play_typing_sound()
		
		await get_tree().create_timer(typing_speed).timeout
		_type_character(full_text)
	else:
		print("✅ Typing complete: ", dialogue_text.text)
		_on_typing_complete()

func _on_typing_complete() -> void:
	is_typing = false
	can_skip = true
	_animate_continue_indicator()
	_stop_hologram_talk_animation()
	
	# Play line complete sound
	_play_sfx(line_complete_sfx)
	
	await get_tree().create_timer(3.0).timeout
	if can_skip:
		_advance_dialogue()

func _advance_dialogue() -> void:
	if not can_skip:
		return
	
	can_skip = false
	current_dialogue_index += 1
	_stop_continue_indicator()
	
	await get_tree().create_timer(0.5).timeout
	_show_next_dialogue()

func _on_skip_pressed() -> void:
	if is_typing:
		dialogue_text.text = dialogues[current_dialogue_index]
		is_typing = false
		can_skip = true
		_animate_continue_indicator()
		_stop_hologram_talk_animation()
	elif can_skip:
		_advance_dialogue()

func _show_username_input() -> void:
	print("📝 Showing username input...")
	is_showing_username_input = true
	
	# Update dialogue box for username prompt
	agent_label.text = "SYSTEM"
	dialogue_text.text = "Enter your operative codename below."
	
	# Show input fields
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
		dialogue_text.text = "⚠️ Codename cannot be empty."
		return
	
	if username.length() < 4:
		dialogue_text.text = "⚠️ Codename must be at least 4 characters."
		return
	
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		dialogue_text.text = "⚠️ Authentication error. Please restart."
		return
	
	username_input.editable = false
	confirm_button.disabled = true
	
	# Hide username input and show terminal
	_show_terminal_verification(username)
	


func _on_dialogue_box_clicked(event: InputEvent) -> void:
	if is_showing_username_input:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			# Complete the typing instantly
			dialogue_text.text = dialogues[current_dialogue_index]
			is_typing = false
			can_skip = true
			_animate_continue_indicator()
			_stop_hologram_talk_animation()
		elif can_skip:
			# Advance to next dialogue
			_advance_dialogue()

func _input(event: InputEvent) -> void:
	if is_showing_username_input and username_input.has_focus():
		return
	
	if event.is_action_pressed("ui_accept"):  # Enter, Space, or gamepad button
		if is_typing:
			# Complete typing instantly
			dialogue_text.text = dialogues[current_dialogue_index]
			is_typing = false
			can_skip = true
			_animate_continue_indicator()
			_stop_hologram_talk_animation()
		elif can_skip:
			# Advance dialogue
			_advance_dialogue()
		accept_event()

# ============================================================================
# TERMINAL SYSTEM
# ============================================================================

func _show_terminal_verification(username: String) -> void:
	print("🖥️ Starting terminal verification sequence...")
	is_terminal_active = true
	pending_username = username  # Store for later use
	
	# Switch to terminal music
	_fade_music_to(terminal_music, 1.0)
	
	# Hide username input
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(username_input, "modulate:a", 0.0, 0.3)
	tween.tween_property(confirm_button, "modulate:a", 0.0, 0.3)
	tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	username_input.visible = false
	confirm_button.visible = false
	dialogue_box.visible = false
	
	# Show terminal with fade
	terminal_overlay.visible = true
	terminal_panel.visible = true
	terminal_panel.modulate.a = 0.0
	terminal_overlay.modulate.a = 0.0
	
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(terminal_overlay, "modulate:a", 1.0, 0.5)
	fade_tween.tween_property(terminal_panel, "modulate:a", 1.0, 0.5)
	
	await fade_tween.finished
	await get_tree().create_timer(0.3).timeout
	
	# Start terminal sequence
	await _terminal_line("INITIALIZING SECURE CONNECTION...", COLOR_INFO, true)
	await _terminal_progress_bar("ESTABLISHING LINK", 0.4)
	_play_sfx(success_sfx)
	await _terminal_line("CONNECTION ESTABLISHED", COLOR_SUCCESS)
	await get_tree().create_timer(0.3).timeout
	
	await _terminal_line("ACCESSING CYBERARENA DATABASE...", COLOR_PROCESSING, true)
	await _terminal_scramble_line("DATABASE ONLINE", COLOR_SUCCESS, 0.8)
	_play_sfx(success_sfx)
	await get_tree().create_timer(0.2).timeout
	
	await _terminal_line("SEARCHING FOR AGENT ID: " + Auth.current_local_id.substr(0, 12) + "...", COLOR_INFO, true)
	await _terminal_progress_bar("QUERY PROGRESS", 0.6)
	
	# Make the actual Firestore request
	_check_existing_user(pending_username)

func _check_existing_user(username: String) -> void:
	var url: String = "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: PackedStringArray = ["Authorization: Bearer %s" % Auth.current_id_token]
	
	var req := HTTPRequest.new()
	add_child(req)
	
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		
		if code == 200:
			_play_sfx(success_sfx)
			await _terminal_line_with_highlight("AGENT PROFILE FOUND: ", username, COLOR_SUCCESS, COLOR_ERROR)
			await _terminal_line("STATUS: EXISTING OPERATIVE", COLOR_INFO)
			await get_tree().create_timer(1.0).timeout
			await _terminal_line("REDIRECTING TO COMMAND CENTER...", COLOR_PROCESSING, true)
			await get_tree().create_timer(1.5).timeout
			_fade_to_scene("res://scene/landing.tscn")
			return
		
		# New user - continue with creation
		_play_sfx(success_sfx)
		await _terminal_line("QUERY COMPLETE", COLOR_SUCCESS)
		await _terminal_line("STATUS: NEW AGENT DETECTED", COLOR_PROCESSING)
		await get_tree().create_timer(0.5).timeout
		await _terminal_line("INITIATING PROFILE CREATION...", COLOR_INFO, true)
		await get_tree().create_timer(0.5).timeout
		_create_new_user_terminal(username)
	)
	
	var err := req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_play_sfx(error_sfx)
		await _terminal_line("CONNECTION ERROR", COLOR_ERROR)
		await _terminal_line("ERROR CODE: " + str(err), COLOR_ERROR)
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

func _create_new_user_terminal(username: String) -> void:
	await _terminal_line("UPLOADING CREDENTIALS...", COLOR_PROCESSING, true)
	await _terminal_progress_bar("UPLOAD PROGRESS", 0.5)
	
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
			"tutorial_completed": {"booleanValue": true},
			"welcome_tutorial_completed": {"booleanValue": false}
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
		
		if code == 200 or code == 201:
			_play_sfx(success_sfx)
			await _terminal_line("CREDENTIALS UPLOADED", COLOR_SUCCESS)
			await _terminal_line("PROFILE CREATED SUCCESSFULLY", COLOR_SUCCESS)
			await get_tree().create_timer(0.5).timeout
			await _terminal_scramble_line_with_highlight("WELCOME, AGENT ", username.to_upper(), COLOR_INFO, COLOR_ERROR, 1.2)
			await get_tree().create_timer(1.5).timeout
			await _terminal_line("REDIRECTING TO COMMAND CENTER...", COLOR_PROCESSING, true)
			await get_tree().create_timer(1.5).timeout
			_fade_to_scene("res://scene/landing.tscn")
		else:
			_play_sfx(error_sfx)
			await _terminal_line("PROFILE CREATION FAILED", COLOR_ERROR)
			await _terminal_line("ERROR CODE: " + str(code), COLOR_ERROR)
			await get_tree().create_timer(2.0).timeout
			get_tree().reload_current_scene()
	)
	
	var json_string := JSON.stringify(body)
	var err := http.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		_play_sfx(error_sfx)
		await _terminal_line("CONNECTION ERROR", COLOR_ERROR)
		await get_tree().create_timer(2.0).timeout
		get_tree().reload_current_scene()

# ============================================================================
# AUDIO FUNCTIONS
# ============================================================================

func _play_music(stream: AudioStream) -> void:
	if not stream or not music_player:
		return
	
	if music_player.stream == stream and music_player.playing:
		return
	
	music_player.stream = stream
	music_player.play()

func _fade_music_to(new_stream: AudioStream, fade_duration: float = 1.0) -> void:
	if not new_stream or not music_player:
		return
	
	# Fade out current music
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -80.0, fade_duration / 2.0)
	await tween.finished
	
	# Switch and fade in new music
	music_player.stream = new_stream
	music_player.play()
	
	var fade_in := create_tween()
	fade_in.tween_property(music_player, "volume_db", music_volume, fade_duration / 2.0)

func _play_typing_sound() -> void:
	if typing_sfx.is_empty() or not typing_sfx_player:
		return
	
	# Pick random typing sound
	var random_sfx: AudioStream = typing_sfx[randi() % typing_sfx.size()]
	typing_sfx_player.stream = random_sfx
	
	# Random pitch variation
	typing_sfx_player.pitch_scale = randf_range(typing_pitch_min, typing_pitch_max)
	
	typing_sfx_player.play()

func _play_sfx(stream: AudioStream) -> void:
	if not stream or not special_sfx_player:
		return
	
	special_sfx_player.stream = stream
	special_sfx_player.pitch_scale = 1.0
	special_sfx_player.play()

func _start_progress_loop() -> void:
	if not progress_loop_sfx or not progress_loop_player:
		return
	
	progress_loop_player.stream = progress_loop_sfx
	progress_loop_player.play()

func _stop_progress_loop() -> void:
	if progress_loop_player:
		var tween := create_tween()
		tween.tween_property(progress_loop_player, "volume_db", -80.0, 0.3)
		await tween.finished
		progress_loop_player.stop()
		progress_loop_player.volume_db = sfx_volume

# ============================================================================
# TERMINAL EFFECT FUNCTIONS
# ============================================================================

func _terminal_line(text: String, color: Color = COLOR_DEFAULT, show_cursor: bool = false) -> void:
	var line := "[color=#%s]> %s" % [color.to_html(false), text]
	if show_cursor:
		line += "[/color][color=#%s]▌[/color]" % COLOR_PROCESSING.to_html(false)
	else:
		line += "[/color]"
	
	terminal_output.text += line + "\n"
	await get_tree().create_timer(0.05).timeout
	
	# Type out character by character
	for i in range(text.length()):
		_play_typing_sound()
		await get_tree().create_timer(0.02).timeout
	
	if show_cursor:
		# Remove cursor after typing
		terminal_output.text = terminal_output.text.substr(0, terminal_output.text.length() - 9) + "[/color]\n"

func _terminal_scramble_line(final_text: String, color: Color, duration: float) -> void:
	var scramble_iterations := int(duration * 20)  # 20 iterations per second
	var current_text := ""
	
	# Play matrix scramble sound if available
	if matrix_scramble_sfx:
		_play_sfx(matrix_scramble_sfx)
	
	# Build up scrambled text
	for _iteration in range(scramble_iterations):
		current_text = ""
		for i in range(final_text.length()):
			var progress := float(_iteration) / float(scramble_iterations)
			if randf() < progress:
				current_text += final_text[i]
			else:
				current_text += MATRIX_CHARS[randi() % MATRIX_CHARS.length()]
		
		# Update the last line
		var lines := terminal_output.text.split("\n")
		if lines.size() > 0:
			lines[lines.size() - 1] = "[color=#%s]> %s[/color]" % [color.to_html(false), current_text]
			terminal_output.text = "\n".join(lines)
		else:
			terminal_output.text = "[color=#%s]> %s[/color]\n" % [color.to_html(false), current_text]
		
		if _iteration % 3 == 0:  # Play typing sound every 3 iterations
			_play_typing_sound()
		
		await get_tree().create_timer(0.05).timeout
	
	# Set final text
	var lines := terminal_output.text.split("\n")
	lines[lines.size() - 1] = "[color=#%s]> %s[/color]" % [color.to_html(false), final_text]
	terminal_output.text = "\n".join(lines) + "\n"

func _terminal_progress_bar(label: String, duration: float) -> void:
	var bar_length := 20
	var steps := 20
	
	# Start progress loop sound
	_start_progress_loop()
	
	for step in range(steps + 1):
		var filled := int((float(step) / float(steps)) * bar_length)
		var empty := bar_length - filled
		var bar := "[" + "█".repeat(filled) + "░".repeat(empty) + "]"
		var percentage := int((float(step) / float(steps)) * 100)
		
		var color := COLOR_PROCESSING if step < steps else COLOR_SUCCESS
		var line := "[color=#%s]> %s %s %d%%[/color]" % [color.to_html(false), label, bar, percentage]
		
		# Update last line
		var lines := terminal_output.text.split("\n")
		if step == 0:
			terminal_output.text += line + "\n"
		else:
			lines[lines.size() - 2] = line
			terminal_output.text = "\n".join(lines)
		
		if step % 2 == 0:  # Play tick sound every other step
			_play_typing_sound()
		
		await get_tree().create_timer(duration / steps).timeout
	
	# Stop progress loop sound
	_stop_progress_loop()
	
	await get_tree().create_timer(0.2).timeout


func _fade_to_scene(scene_path: String) -> void:
	# Make overlay visible and start from transparent
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	
	# Fade to black
	var fade_out := create_tween()
	fade_out.tween_property(fade_overlay, "modulate:a", 1.0, 0.8)
	await fade_out.finished
	
	# Change scene
	get_tree().change_scene_to_file(scene_path)

# Terminal line with highlighted text
func _terminal_line_with_highlight(text: String, highlight: String, text_color: Color, highlight_color: Color, show_cursor: bool = false) -> void:
	var line := "[color=#%s]> %s[/color][color=#%s]%s[/color]" % [
		text_color.to_html(false), 
		text, 
		highlight_color.to_html(false), 
		highlight
	]
	
	if show_cursor:
		line += "[color=#%s]▌[/color]" % COLOR_PROCESSING.to_html(false)
	
	terminal_output.text += line + "\n"
	await get_tree().create_timer(0.05).timeout
	
	# Type out character by character
	var total_length = text.length() + highlight.length()
	for i in range(total_length):
		_play_typing_sound()
		await get_tree().create_timer(0.02).timeout
	
	if show_cursor:
		# Remove cursor after typing
		var lines := terminal_output.text.split("\n")
		if lines.size() > 0:
			lines[lines.size() - 1] = line.replace("[color=#%s]▌[/color]" % COLOR_PROCESSING.to_html(false), "")
			terminal_output.text = "\n".join(lines) + "\n"

# Terminal scramble with highlighted text
func _terminal_scramble_line_with_highlight(text: String, highlight: String, text_color: Color, highlight_color: Color, duration: float) -> void:
	var scramble_iterations := int(duration * 20)
	var highlight_text := ""
	
	# Play matrix scramble sound if available
	if matrix_scramble_sfx:
		_play_sfx(matrix_scramble_sfx)
	
	# Build up scrambled highlight text
	for _iteration in range(scramble_iterations):
		highlight_text = ""
		for i in range(highlight.length()):
			var progress := float(_iteration) / float(scramble_iterations)
			if randf() < progress:
				highlight_text += highlight[i]
			else:
				highlight_text += MATRIX_CHARS[randi() % MATRIX_CHARS.length()]
		
		# Update the last line with colored text
		var line := "[color=#%s]> %s[/color][color=#%s]%s[/color]" % [
			text_color.to_html(false),
			text,
			highlight_color.to_html(false),
			highlight_text
		]
		
		var lines := terminal_output.text.split("\n")
		if lines.size() > 0:
			lines[lines.size() - 1] = line
			terminal_output.text = "\n".join(lines)
		else:
			terminal_output.text = line + "\n"
		
		if _iteration % 3 == 0:
			_play_typing_sound()
		
		await get_tree().create_timer(0.05).timeout
	
	# Set final text with highlight
	var final_line := "[color=#%s]> %s[/color][color=#%s]%s[/color]" % [
		text_color.to_html(false),
		text,
		highlight_color.to_html(false),
		highlight
	]
	
	var lines := terminal_output.text.split("\n")
	lines[lines.size() - 1] = final_line
	terminal_output.text = "\n".join(lines) + "\n"