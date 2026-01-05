# CodeBreakerTutorialGuide.gd
# Pokemon-style dialogue guide for Code Breaker tutorial
extends CanvasLayer

# UI References
@onready var overlay: ColorRect = $Overlay
@onready var dialogue_box: Panel = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/MarginContainer/DialogueText
@onready var continue_indicator: Label = $DialogueBox/ContinueIndicator
@onready var portrait: TextureRect = $DialogueBox/Portrait/TextureRect
@onready var highlight_box: ReferenceRect = $HighlightBox

# Tutorial step data
var tutorial_steps := [
	{
		"text": "Welcome to Code Breaker, Agent %s! Let me show you how to hack like a pro!",
		"highlight": null,
		"action": null
	},
	{
		"text": "These are your HEALTH BARS. When your HP reaches 0, you lose! Keep an eye on both yours and your opponent's.",
		"highlight": "VBox/ScorePanel",
		"action": null
	},
	{
		"text": "This is the CODE DISPLAY. Security commands will appear here - you need to type them EXACTLY as shown!",
		"highlight": "VBox/CodeDisplayPanel",
		"action": null
	},
	{
		"text": "Type the command here and press ENTER to submit. Be fast and accurate!",
		"highlight": "VBox/InputField",
		"action": null
	},
	{
		"text": "✅ CORRECT submission = +100 Score and -10 HP to your opponent! Type fast to deal more damage!",
		"highlight": null,
		"action": null
	},
	{
		"text": "❌ WRONG submission = -8 HP to YOU! Be careful - mistakes hurt!",
		"highlight": null,
		"action": null
	},
	{
		"text": "You have 15 SECONDS per snippet. If time runs out, you take damage! Type quickly!",
		"highlight": "VBox/CodeDisplayPanel/SnippetTimer",
		"action": null
	},
	{
		"text": "Watch for POWER-UPS! Green = Heal, Blue = Freeze Time, Yellow = Extend Time, Grey = Shield!",
		"highlight": "VBox/CodeDisplayPanel",
		"action": null
	},
	{
		"text": "Ready to practice? Let's see what you've got! Good luck, Agent!",
		"highlight": null,
		"action": "start_match"
	}
]

var current_step := 0
var is_typing := false
var char_index := 0
var typing_speed := 0.025
var current_text := ""
var arena_control: Control = null
var active_tweens: Array[Tween] = []
var player_name := "Agent"

signal tutorial_completed
signal tutorial_skipped
signal start_practice_match

func _ready() -> void:
	print("[CBTutorialGuide] _ready() called")
	
	# Initially hide everything
	visible = false
	
	if highlight_box:
		highlight_box.visible = false
		highlight_box.border_color = Color(0.0, 0.9, 1.0) # Cyan
		highlight_box.border_width = 4.0
		highlight_box.editor_only = false
	
	if overlay:
		overlay.color = Color(0, 0, 0, 0.6)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.gui_input.connect(_on_overlay_input)
	
	if dialogue_box:
		dialogue_box.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if continue_indicator:
		_animate_continue_indicator()
	
	# Load Agent01 portrait
	if portrait:
		var agent_texture = load("res://asset/icons/AGENT01.png")
		if agent_texture:
			portrait.texture = agent_texture
			print("[CBTutorialGuide] ✅ Loaded Agent01 portrait")
		else:
			push_warning("[CBTutorialGuide] Could not load Agent01 portrait")


func start_tutorial(arena: Control, username: String = "Agent") -> void:
	"""Start the tutorial with arena reference and player name"""
	print("[CBTutorialGuide] ========== START TUTORIAL ==========")
	arena_control = arena
	player_name = username
	
	visible = true
	
	if overlay:
		overlay.visible = true
	
	if dialogue_box:
		dialogue_box.visible = true
	
	current_step = 0
	_show_step(current_step)
	print("[CBTutorialGuide] Tutorial started successfully!")

func _show_step(step: int) -> void:
	if step >= tutorial_steps.size():
		_complete_tutorial()
		return
	
	var step_data = tutorial_steps[step]
	
	# Clear previous highlight
	_clear_highlight()
	
	# Show new text with player name substitution
	current_text = step_data["text"] % [player_name] if "%s" in step_data["text"] else step_data["text"]
	_start_typing()
	
	# Highlight UI element if specified
	if step_data.has("highlight") and step_data["highlight"] != null:
		_highlight_element(step_data["highlight"])
	
	# Execute action if any
	if step_data.has("action") and step_data["action"] == "start_match":
		# Don't start immediately, wait for click
		pass

func _start_typing() -> void:
	is_typing = true
	char_index = 0
	dialogue_text.text = ""
	continue_indicator.visible = false
	_type_next_char()

func _type_next_char() -> void:
	if char_index < current_text.length():
		dialogue_text.text += current_text[char_index]
		char_index += 1
		await get_tree().create_timer(typing_speed).timeout
		_type_next_char()
	else:
		is_typing = false
		continue_indicator.visible = true

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_dialogue()

func _advance_dialogue() -> void:
	if is_typing:
		# Skip typing animation
		dialogue_text.text = current_text
		is_typing = false
		char_index = current_text.length()
		continue_indicator.visible = true
	else:
		# Check if current step has action
		var step_data = tutorial_steps[current_step]
		if step_data.has("action") and step_data["action"] == "start_match":
			_complete_tutorial()
			return
		
		# Move to next step
		current_step += 1
		_show_step(current_step)

func _highlight_element(element_path: String) -> void:
	if not arena_control:
		push_warning("[CBTutorialGuide] No arena reference for highlighting")
		return
	
	var target_node = arena_control.get_node_or_null(element_path)
	if not target_node:
		push_warning("[CBTutorialGuide] Cannot find element: %s" % element_path)
		return
	
	if not highlight_box:
		return
	
	# Position highlight around the target
	var global_pos = target_node.global_position
	var node_size = target_node.size
	
	# Add padding
	var padding := Vector2(10, 10)
	highlight_box.global_position = global_pos - padding
	highlight_box.size = node_size + (padding * 2)
	highlight_box.visible = true
	
	# Animate highlight
	_animate_highlight()

func _clear_highlight() -> void:
	_kill_all_tweens()
	if highlight_box:
		highlight_box.visible = false

func _animate_highlight() -> void:
	if not highlight_box:
		return
	
	var tween = create_tween()
	tween.set_loops(100)
	tween.tween_property(highlight_box, "modulate:a", 0.4, 0.4)
	tween.tween_property(highlight_box, "modulate:a", 1.0, 0.4)
	
	active_tweens.append(tween)
	tween.finished.connect(func(): active_tweens.erase(tween))

func _animate_continue_indicator() -> void:
	if not continue_indicator:
		return
	
	var tween = create_tween()
	tween.set_loops(100)
	tween.tween_property(continue_indicator, "modulate:a", 0.3, 0.5)
	tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)
	
	active_tweens.append(tween)
	tween.finished.connect(func(): active_tweens.erase(tween))

func _kill_all_tweens() -> void:
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()

func _complete_tutorial() -> void:
	print("[CBTutorialGuide] ========== COMPLETING TUTORIAL ==========")
	
	_kill_all_tweens()
	_clear_highlight()
	
	# Hide tutorial UI
	dialogue_text.text = "Let's start the practice match!"
	continue_indicator.visible = false
	
	await get_tree().create_timer(1.0).timeout
	
	_kill_all_tweens()
	visible = false
	
	# Emit signal to start practice match
	start_practice_match.emit()
	tutorial_completed.emit()
	print("[CBTutorialGuide] ✅ Tutorial completed!")

func skip_tutorial() -> void:
	"""Allow player to skip the tutorial"""
	print("[CBTutorialGuide] Tutorial skipped by player")
	_kill_all_tweens()
	_clear_highlight()
	visible = false
	tutorial_skipped.emit()

func _exit_tree() -> void:
	_kill_all_tweens()
	print("[CBTutorialGuide] Cleaned up on exit")
