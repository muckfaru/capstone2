extends Control

@onready var beginner_btn: Button = $CanvasLayer/ButtonContainer/BeginnerButton
@onready var intermediate_btn: Button = $CanvasLayer/ButtonContainer/IntermediateButton
@onready var advanced_btn: Button = $CanvasLayer/ButtonContainer/AdvancedButton

const PROJECT_ID := "capstone-823dc"
const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID

func _ready() -> void:
	# Verify auth state
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		push_error("❌ No auth state! Redirecting to login...")
		get_tree().change_scene_to_file("res://scene/login.tscn")
		return
	
	print("✅ Mode Selection Ready | UID:", Auth.current_local_id)


# -------------------------
# BUTTON HOVER EFFECT (Scale animation)
# -------------------------
func _on_button_hover(level: String) -> void:
	var btn: Button
	match level:
		"beginner": btn = beginner_btn
		"intermediate": btn = intermediate_btn
		"advanced": btn = advanced_btn
		_: return
	
	# Bounce scale animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.3)


# -------------------------
# LEVEL SELECTION (Main logic)
# -------------------------
func _on_level_selected(level: String) -> void:
	print("🎯 Level selected:", level)
	
	var btn: Button
	match level:
		"beginner": btn = beginner_btn
		"intermediate": btn = intermediate_btn
		"advanced": btn = advanced_btn
		_: return
	
	# Click animation (press down → bounce back)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	
	await tween.finished
	
	# Show tutorial selection menu for this level
	_show_tutorial_menu(level)


# -------------------------
# SHOW TUTORIAL MENU (Selection Dialog)
# -------------------------
func _show_tutorial_menu(level: String) -> void:
	var tutorials: Array = []
	var level_int: int = 1
	
	match level:
		"beginner":
			level_int = 1
			tutorials = [
				{"name": "🎓 Cybersecurity Fundamentals (Start Here!)", "scene": "res://scene/tutorial_cyber_fundamentals.tscn", "id": "beginner_fundamentals"},
				{"name": "🌐 Network Basics", "scene": "res://scene/tutorial_network_basics.tscn", "id": "beginner_network"},
				{"name": "🔐 Encryption Basics", "scene": "res://scene/tutorial_encryption_basics.tscn", "id": "beginner_encryption"},
				{"name": "🦠 Malware Types Overview", "scene": "res://scene/tutorial_malware_types.tscn", "id": "beginner_malware"}
			]
		"intermediate":
			level_int = 2
			tutorials = [
				{"name": "🎣 Phishing Detection Lab", "scene": "res://scene/tutorial_phishing_lab.tscn", "id": "intermediate_phishing"},
				{"name": "🐴 Trojan Horse Analysis", "scene": "res://scene/malware_trojan_tutorial.tscn", "id": "intermediate_trojan"},
				{"name": "🛡️ Interactive Defense Training", "scene": "res://scene/tutorial_advance_interactive.tscn", "id": "intermediate_defense"},
				{"name": "🔬 Advanced Malware Lab", "scene": "res://scene/malware_tutorial_menu.tscn", "id": "intermediate_lab"}
			]
		"advanced":
			level_int = 3
			tutorials = [
				{"name": "⚔️ Advanced Threat Scenarios", "scene": "res://scene/tutorial_advance.tscn", "id": "advanced_scenarios"},
				{"name": "💀 Malware Research Lab", "scene": "res://scene/malware_tutorial_menu.tscn", "id": "advanced_lab"}
			]
	
	# Update Auth level
	Auth.current_level = level_int
	
	# Create selection dialog
	var dialog := ConfirmationDialog.new()
	dialog.title = "Choose Tutorial - Level %d Assessment" % level_int
	dialog.dialog_text = "Complete tutorials to earn XP and unlock games!\nPassing score: 70% or higher"
	dialog.get_ok_button().visible = false
	dialog.get_cancel_button().text = "Back"
	
	# Create vertical list of tutorial buttons
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.add_theme_constant_override("separation", 10)
	
	for tutorial in tutorials:
		var btn := Button.new()
		btn.text = "🎯 " + tutorial["name"]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(func():
			dialog.queue_free()
			# Store tutorial metadata for result tracking
			get_tree().set_meta("tutorial_id", tutorial["id"])
			get_tree().set_meta("tutorial_level", level_int)
			_save_level_and_navigate(level_int, tutorial["scene"])
		)
		vbox.add_child(btn)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()


# -------------------------
# SAVE LEVEL TO FIRESTORE + NAVIGATE TO TUTORIAL
# -------------------------
func _save_level_and_navigate(level_int: int, tutorial_scene: String) -> void:
	print("💾 Saving level to Firestore...")
	
	# Build Firestore PATCH request (only update 'level' field)
	var url: String = "%s/users/%s?updateMask.fieldPaths=level" % [FIRESTORE_URL, Auth.current_local_id]
	var headers: Array = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % Auth.current_id_token
	]
	var body := {
		"fields": {
			"level": {"integerValue": level_int}
		}
	}
	
	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, body_response):
		http.queue_free()
		var text: String = body_response.get_string_from_utf8()
		
		if code == 200:
			print("✅ Level saved successfully:", level_int)
		else:
			push_error("❌ Failed to save level (%s): %s" % [code, text])
		
		# Navigate to tutorial scene (even if save fails)
		_transition_to_tutorial(tutorial_scene)
	)
	
	var err := http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("Failed to start Firestore PATCH: %s" % err)
		http.queue_free()
		_transition_to_tutorial(tutorial_scene)


# -------------------------
# TRANSITION TO TUTORIAL (Zoom + Fade animation)
# -------------------------
func _transition_to_tutorial(scene_path: String) -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	
	# Zoom in + fade out
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	
	# Navigate to tutorial scene
	get_tree().change_scene_to_file(scene_path)


# -------------------------
# MENU BUTTON (Placeholder)
# -------------------------
func _on_menu_pressed() -> void:
	print("🍔 Menu button pressed (placeholder)")
	# TODO: Open settings or back navigation
