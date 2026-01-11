extends Control

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users" % PROJECT_ID

# UI References
@onready var computer_icon: TextureButton = $BackgroundLayer/IconContainer/ComputerIcon
@onready var data_icon: TextureButton = $BackgroundLayer/IconContainer/DataIcon
@onready var network_icon: TextureButton = $BackgroundLayer/IconContainer/NetworkIcon
@onready var cloud_icon: TextureButton = $BackgroundLayer/IconContainer/CloudIcon
@onready var iot_icon: TextureButton = $BackgroundLayer/IconContainer/IoTIcon

# Description labels (shown on hover)
@onready var computer_desc: Label = $BackgroundLayer/IconContainer/ComputerIcon/HoverDescription
@onready var data_desc: Label = $BackgroundLayer/IconContainer/DataIcon/HoverDescription
@onready var network_desc: Label = $BackgroundLayer/IconContainer/NetworkIcon/HoverDescription
@onready var cloud_desc: Label = $BackgroundLayer/IconContainer/CloudIcon/HoverDescription
@onready var iot_desc: Label = $BackgroundLayer/IconContainer/IoTIcon/HoverDescription

@onready var next_button: Button = $NextButton
@onready var arrow_button: Button = $BackgroundLayer/Arrow

# Dialogue system
@onready var dialogue_box: Panel = $DialogueBox
@onready var agent_portrait: TextureRect = $DialogueBox/Portrait
@onready var agent_name_label: Label = $DialogueBox/AgentName
@onready var dialogue_text: Label = $DialogueBox/DialogueText
@onready var continue_indicator: Label = $DialogueBox/ContinueIndicator

var current_dialogue_lines: Array = []
var current_line_index: int = 0
var is_showing_dialogue: bool = false

var icons_clicked: Dictionary = {
	"computer": false,
	"data": false,
	"network": false,
	"cloud": false,
	"iot": false
}

var all_icons_viewed: bool = false

func _ready() -> void:
	print("[IntroCyber] ✅ Introduction Scene Ready | UID:", Auth.current_local_id)
	
	# ✅ AUTO-SAVE: Mark intro as completed immediately when scene loads
	_save_intro_completion()
	
	# Keep CONTINUE button visible from start
	next_button.visible = true
	
	# Hide dialogue box initially
	dialogue_box.visible = false
	
	# Hide all hover descriptions initially
	if computer_desc: computer_desc.visible = false
	if data_desc: data_desc.visible = false
	if network_desc: network_desc.visible = false
	if cloud_desc: cloud_desc.visible = false
	if iot_desc: iot_desc.visible = false
	
	# Connect icon click signals
	computer_icon.pressed.connect(_on_icon_clicked.bind("computer"))
	data_icon.pressed.connect(_on_icon_clicked.bind("data"))
	network_icon.pressed.connect(_on_icon_clicked.bind("network"))
	cloud_icon.pressed.connect(_on_icon_clicked.bind("cloud"))
	iot_icon.pressed.connect(_on_icon_clicked.bind("iot"))
	
	# Connect hover signals
	computer_icon.mouse_entered.connect(_on_icon_hover.bind("computer", true))
	computer_icon.mouse_exited.connect(_on_icon_hover.bind("computer", false))
	data_icon.mouse_entered.connect(_on_icon_hover.bind("data", true))
	data_icon.mouse_exited.connect(_on_icon_hover.bind("data", false))
	network_icon.mouse_entered.connect(_on_icon_hover.bind("network", true))
	network_icon.mouse_exited.connect(_on_icon_hover.bind("network", false))
	cloud_icon.mouse_entered.connect(_on_icon_hover.bind("cloud", true))
	cloud_icon.mouse_exited.connect(_on_icon_hover.bind("cloud", false))
	iot_icon.mouse_entered.connect(_on_icon_hover.bind("iot", true))
	iot_icon.mouse_exited.connect(_on_icon_hover.bind("iot", false))
	
	next_button.pressed.connect(_on_next_pressed)
	
	# Connect arrow button to skip intro
	if arrow_button:
		arrow_button.pressed.connect(_on_skip_intro)
	
	# Show initial dialogue
	await get_tree().create_timer(0.5).timeout
	_show_welcome_dialogue()

func _input(event: InputEvent) -> void:
	if is_showing_dialogue and event.is_action_pressed("ui_accept"):
		_advance_dialogue()

func _show_dialogue(lines: Array, agent_name: String = "AGENT 00", portrait_path: String = "") -> void:
	current_dialogue_lines = lines
	current_line_index = 0
	is_showing_dialogue = true
	
	# Set agent name
	agent_name_label.text = agent_name
	
	# Load and set portrait if path provided
	if portrait_path != "" and agent_portrait:
		var portrait = load(portrait_path)
		if portrait:
			agent_portrait.texture = portrait
			agent_portrait.visible = true
		else:
			agent_portrait.visible = false
	else:
		if agent_portrait:
			agent_portrait.visible = false
	
	# Show dialogue box with fade in
	dialogue_box.visible = true
	dialogue_box.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.3)
	
	# Display first line
	_display_current_line()

func _display_current_line() -> void:
	if current_line_index < current_dialogue_lines.size():
		dialogue_text.text = current_dialogue_lines[current_line_index]
		
		# Show continue indicator if not last line
		if continue_indicator:
			continue_indicator.visible = current_line_index < current_dialogue_lines.size() - 1

func _advance_dialogue() -> void:
	current_line_index += 1
	
	if current_line_index < current_dialogue_lines.size():
		_display_current_line()
	else:
		_hide_dialogue()

func _hide_dialogue() -> void:
	is_showing_dialogue = false
	
	# Fade out dialogue box
	var tween = create_tween()
	tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.3)
	await tween.finished
	dialogue_box.visible = false

func _show_welcome_dialogue() -> void:
	var dialogue_lines = [
		"Welcome to Cybersecurity Fundamentals!",
		"Before we begin, let's understand what cybersecurity protects.",
		"Click on each icon to learn what cybersecurity defends."
	]
	
	_show_dialogue(dialogue_lines, "AGENT 00", "res://asset/icons/mission_file.png")
	
	# Wait for dialogue to finish
	while is_showing_dialogue:
		await get_tree().process_frame

func _on_icon_clicked(icon_type: String) -> void:
	if icons_clicked[icon_type]:
		return  # Already clicked
	
	icons_clicked[icon_type] = true
	print("[IntroCyber] Icon clicked:", icon_type)
	
	# Check if all icons viewed
	_check_completion()

func _on_icon_hover(icon_type: String, is_hovering: bool) -> void:
	var desc_label: Label = null
	match icon_type:
		"computer": desc_label = computer_desc
		"data": desc_label = data_desc
		"network": desc_label = network_desc
		"cloud": desc_label = cloud_desc
		"iot": desc_label = iot_desc
	
	if desc_label:
		if is_hovering:
			# Show description with fade in
			desc_label.visible = true
			desc_label.modulate.a = 0
			var tween = create_tween()
			tween.tween_property(desc_label, "modulate:a", 1.0, 0.2)
		else:
			# Hide description with fade out
			var tween = create_tween()
			tween.tween_property(desc_label, "modulate:a", 0.0, 0.2)
			await tween.finished
			desc_label.visible = false

func _check_completion() -> void:
	var all_viewed = true
	for viewed in icons_clicked.values():
		if not viewed:
			all_viewed = false
			break
	
	print("[IntroCyber] All icons viewed:", all_viewed, "| Already shown:", all_icons_viewed)
	
	if all_viewed and not all_icons_viewed:
		all_icons_viewed = true
		print("[IntroCyber] All icons clicked! Showing completion dialogue...")
		_show_completion_dialogue()

func _on_skip_intro() -> void:
	print("[IntroCyber] Arrow clicked - skipping intro")
	# Mark all icons as clicked
	for key in icons_clicked.keys():
		icons_clicked[key] = true
	_check_completion()

func _show_completion_dialogue() -> void:
	print("[IntroCyber] Starting completion dialogue...")
	await get_tree().create_timer(0.5).timeout
	
	var dialogue_lines = [
		"Excellent! You now understand what cybersecurity protects.",
		"These are the foundations of digital security.",
		"Ready to start your training? Let's begin!"
	]
	
	_show_dialogue(dialogue_lines, "AGENT 00", "res://asset/agent_portrait.png")
	
	# Wait for dialogue to finish
	while is_showing_dialogue:
		await get_tree().process_frame

func _on_next_pressed() -> void:
	# Transition to mode selection (save already happened on scene load)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	get_tree().change_scene_to_file("res://scene/mode_selection.tscn")

func _save_intro_completion() -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("[IntroCyber] Auth not ready!")
		return
	
	print("[IntroCyber] 💾 Auto-saving intro completion to Firestore...")
	
	# Use PATCH with updateMask to update the specific field
	var url = FIRESTORE_URL + "/" + Auth.current_local_id + "?updateMask.fieldPaths=cybersecurity_intro_completed"
	
	var data = {
		"fields": {
			"cybersecurity_intro_completed": {"booleanValue": true}
		}
	}
	
	var headers = [
		"Authorization: Bearer " + Auth.current_id_token,
		"Content-Type: application/json"
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			print("[IntroCyber] ✅ Intro completion saved to Firestore")
		else:
			var response_text = body.get_string_from_utf8() if body.size() > 0 else ""
			print("[IntroCyber] ⚠️ Failed to save intro completion (code %d)" % code)
			print("[IntroCyber] Response: ", response_text)
	)
	
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))

func _try_get_and_create_document() -> void:
	print("[IntroCyber] 🔍 Checking if user document exists...")
	
	var url = FIRESTORE_URL + "/" + Auth.current_local_id
	var headers = ["Authorization: Bearer " + Auth.current_id_token]
	
	var http_get = HTTPRequest.new()
	add_child(http_get)
	
	http_get.request_completed.connect(func(_r, code, _h, _b):
		http_get.queue_free()
		if code == 404:
			# Document doesn't exist, create it with PUT
			print("[IntroCyber] 📝 Document doesn't exist, creating it...")
			_create_user_document()
		elif code == 200:
			print("[IntroCyber] ✅ Document exists, intro flag should be saved now")
		else:
			print("[IntroCyber] ⚠️ Unexpected GET response: ", code)
	)
	
	http_get.request(url, headers, HTTPClient.METHOD_GET)

func _create_user_document() -> void:
	var url = FIRESTORE_URL + "/" + Auth.current_local_id
	
	var data = {
		"fields": {
			"username": {"stringValue": Auth.current_username},
			"cybersecurity_intro_completed": {"booleanValue": true},
			"level": {"integerValue": "1"},
			"xp": {"integerValue": "0"},
			"wins": {"integerValue": "0"},
			"losses": {"integerValue": "0"}
		}
	}
	
	var headers = [
		"Authorization: Bearer " + Auth.current_id_token,
		"Content-Type: application/json"
	]
	
	var http_put = HTTPRequest.new()
	add_child(http_put)
	
	http_put.request_completed.connect(func(_r, code, _h, _b):
		http_put.queue_free()
		if code == 200:
			print("[IntroCyber] ✅ User document created with intro flag")
		else:
			print("[IntroCyber] ⚠️ Failed to create document (code %d)" % code)
	)
	
	http_put.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(data))
