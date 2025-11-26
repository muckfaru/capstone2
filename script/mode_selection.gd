extends Control

@onready var beginner_btn: Button = $CanvasLayer/ButtonContainer/BeginnerButton
@onready var advance_btn: Button = $CanvasLayer/ButtonContainer/AdvanceButton
@onready var intermediate_btn: Button = $CanvasLayer/ButtonContainer/IntermediateButton

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
		"advance": btn = advance_btn
		"intermediate": btn = intermediate_btn
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
		"advance": btn = advance_btn
		"intermediate": btn = intermediate_btn
		_: return
	
	# Click animation (press down → bounce back)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)
	
	await tween.finished
	
	# Save level to Firestore + navigate to tutorial
	_save_level_and_navigate(level)


# -------------------------
# SAVE LEVEL TO FIRESTORE + NAVIGATE TO TUTORIAL
# -------------------------
func _save_level_and_navigate(level: String) -> void:
	print("💾 Saving level to Firestore...")
	
	# Convert level string to integer for Auth.current_level
	var level_int: int = 1
	var tutorial_scene: String = ""
	
	match level:
		"beginner":
			level_int = 1
			tutorial_scene = "res://scene/tutorial_beginner.tscn"
		"intermediate":
			level_int = 2
			tutorial_scene = "res://scene/tutorial_intermediate.tscn"
		"advance":
			level_int = 3
			tutorial_scene = "res://scene/tutorial_advance.tscn"
	
	# Update Auth singleton immediately (client-side)
	Auth.current_level = level_int
	
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
			print("✅ Level saved successfully:", level)
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
