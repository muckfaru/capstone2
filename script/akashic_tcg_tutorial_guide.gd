# AkashicTCGTutorialGuide.gd
# Pokemon-style dialogue guide for AkashicTCG tutorial
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
		"text": "Welcome to the AkashicTCG Arena, %s! I'm your Cyber Guide. Let me show you the ropes!",
		"highlight": null,
		"action": null
	},
	{
		"text": "This is your SYSTEM INTEGRITY bar. Think of it as your health - if it drops to zero, you lose the battle!",
		"highlight": "HUD/PlayerBars/YouSIBar",
		"action": null
	},
	{
		"text": "Below that is your FIREWALL. Some attack cards need to break through this first before dealing damage!",
		"highlight": "HUD/PlayerBars/YouFWBar",
		"action": null
	},
	{
		"text": "These are your CARDS! Each card has unique abilities. Drag them to the play zone to attack your opponent!",
		"highlight": "HUD/HandArea",
		"action": null
	},
	{
		"text": "Keep an eye on your RESOURCES here - Bandwidth (BW) for playing cards and the number of plays per turn!",
		"highlight": "HUD/PlayerBars/ResourceLabel",
		"action": null
	},
	{
		"text": "This timer shows how long the match has been running. Manage your time wisely!",
		"highlight": "HUD/Sidebar/TimerLabel",
		"action": null
	},
	{
		"text": "Up here is your OPPONENT'S stats. Your goal is to reduce their System Integrity to zero!",
		"highlight": "HUD/OpponentBars",
		"action": null
	},
	{
		"text": "The PLAY ZONE is where the action happens! Cards you play appear here.",
		"highlight": "HUD/Table/PlayZone",
		"action": null
	},
	{
		"text": "When you're done with your turn, click the END TURN button to pass control to your opponent.",
		"highlight": "HUD/PlayerBars/EndTurnButton",
		"action": null
	},
	{
		"text": "That's all the basics! Ready to try a friendly practice match? Good luck, champion!",
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
var player_name := "Player"

signal tutorial_completed
signal tutorial_skipped
signal start_friendly_match

func _ready() -> void:
	print("[TutorialGuide] _ready() called")
	
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
			print("[TutorialGuide] ✅ Loaded Agent01 portrait")
		else:
			push_warning("[TutorialGuide] Could not load Agent01 portrait")


func start_tutorial(arena: Control, username: String = "Player") -> void:
	"""Start the tutorial with arena reference and player name"""
	print("[TutorialGuide] ========== START TUTORIAL ==========")
	arena_control = arena
	player_name = username
	
	visible = true
	
	if overlay:
		overlay.visible = true
	
	if dialogue_box:
		dialogue_box.visible = true
	
	current_step = 0
	_show_step(current_step)
	print("[TutorialGuide] Tutorial started successfully!")

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
		push_warning("[TutorialGuide] No arena reference for highlighting")
		return
	
	var target_node = arena_control.get_node_or_null(element_path)
	if not target_node:
		push_warning("[TutorialGuide] Cannot find element: %s" % element_path)
		return
	
	if not highlight_box:
		return
	
	# Position highlight around the target
	var global_pos = target_node.global_position
	var size = target_node.size
	
	# Add padding
	var padding := Vector2(10, 10)
	highlight_box.global_position = global_pos - padding
	highlight_box.size = size + (padding * 2)
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
	print("[TutorialGuide] ========== COMPLETING TUTORIAL ==========")
	
	_kill_all_tweens()
	_clear_highlight()
	
	# Hide tutorial UI
	dialogue_text.text = "Let's start the practice match!"
	continue_indicator.visible = false
	
	await get_tree().create_timer(1.0).timeout
	
	_kill_all_tweens()
	visible = false
	
	# Emit signal to start friendly match
	start_friendly_match.emit()
	tutorial_completed.emit()
	print("[TutorialGuide] ✅ Tutorial completed!")

func skip_tutorial() -> void:
	"""Allow player to skip the tutorial"""
	print("[TutorialGuide] Tutorial skipped by player")
	_kill_all_tweens()
	_clear_highlight()
	visible = false
	tutorial_skipped.emit()

func _exit_tree() -> void:
	_kill_all_tweens()
	print("[TutorialGuide] Cleaned up on exit")
