extends CanvasLayer

@export_file("*.tscn") var next_scene_path: String = "res://scene/main.tscn"
@export var auto_advance_time: float = 4.0
@export var fade_duration: float = 0.8

# ADD YOUR IMAGE PATHS HERE - Make sure these match your actual files!
@export var panel1_image: Texture2D
@export var panel2_image: Texture2D
@export var panel3_image: Texture2D
@export var panel4_image: Texture2D
@export var panel5_image: Texture2D

# ADD YOUR SOUND EFFECT HERE
@export var turn_page_sound: AudioStream

@onready var panel_display = $Control/ImageContainer/TextureRect
@onready var dialogue_box = $Control/DialogueBox
@onready var dialogue_label = $Control/DialogueBox/MarginContainer/Label
@onready var fade_overlay = $Control/FadeOverlay
@onready var next_indicator = $Control/NextIndicator
@onready var sfx_player = $SFXPlayer  # Reference to the AudioStreamPlayer

var story_panels = []
var current_panel = 0
var can_advance = false
var auto_timer = 0.0
var is_transitioning = false

func _ready():
	# Build story panels from exported images
	story_panels = [
		{
			"image": panel1_image,
			"text": "Wow they're having fun playing CyberRun 2026, the new game.
					 I want to play that too it looks good..."
		},
		{
			"image": panel2_image,
			"text": "₱1000...That's way too expensive for me."
		},
		{
			"image": panel3_image,
			"text": "My friends keeps showing me the screenshots. It looks amazing with all the new features!
					 I wish I could join them..."
		},
		{
			"image": panel4_image,
			"text": "Why it's so expensive though? I wonder if I can find it for free somewhere..."
		},
		{
			"image": panel5_image,
			"text": "Maybe I can find it online somewhere... I'll just check my computer.
					 and see if I can download it. and so i can join my friends playing it."
		}
	]
	
	# Check if images are assigned
	for i in range(story_panels.size()):
		if story_panels[i].image == null:
			print("WARNING: Panel ", i+1, " image is not assigned!")
	
	# Setup initial visibility
	panel_display.modulate.a = 0.0
	fade_overlay.modulate.a = 1.0
	dialogue_box.modulate.a = 0.0
	next_indicator.modulate.a = 0.0
	
	print("Starting cutscene...")
	print("Panel display size: ", panel_display.size)
	print("Panel display visible: ", panel_display.visible)
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_duration)
	await tween.finished
	
	show_panel(0)

func show_panel(index: int):
	if index >= story_panels.size():
		end_story()
		return
	
	# Play turn page sound when transitioning to a new panel
	if turn_page_sound and sfx_player:
		sfx_player.stream = turn_page_sound
		sfx_player.play()
	
	can_advance = false
	current_panel = index
	auto_timer = 0.0
	
	var panel = story_panels[index]
	
	# Check if image exists
	if panel.image == null:
		print("ERROR: No image for panel ", index + 1)
		advance_panel()
		return
	
	# Fade out old content
	var fade_out = create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(panel_display, "modulate:a", 0.0, 0.3)
	fade_out.tween_property(dialogue_box, "modulate:a", 0.0, 0.3)
	fade_out.tween_property(next_indicator, "modulate:a", 0.0, 0.2)
	await fade_out.finished
	
	# Change content
	panel_display.texture = panel.image
	dialogue_label.text = panel.text
	
	# Debug info
	print("Showing panel ", index + 1)
	print("Image assigned: ", panel.image != null)
	if panel.image:
		print("Image size: ", panel.image.get_size())
	print("TextureRect size: ", panel_display.size)
	
	# Force update
	panel_display.queue_redraw()
	
	# Fade in new content
	var fade_in = create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(panel_display, "modulate:a", 1.0, 0.5)
	fade_in.tween_property(dialogue_box, "modulate:a", 1.0, 0.5)
	await fade_in.finished
	
	# Typing effect
	await type_text(panel.text)
	
	can_advance = true
	blink_indicator()

func type_text(text: String, speed: float = 0.03):
	dialogue_label.visible_characters = 0
	for i in range(text.length()):
		dialogue_label.visible_characters = i + 1
		await get_tree().create_timer(speed).timeout

func blink_indicator():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(next_indicator, "modulate:a", 1.0, 0.5)
	tween.tween_property(next_indicator, "modulate:a", 0.3, 0.5)

func _process(delta):
	if can_advance and not is_transitioning:
		auto_timer += delta
		if auto_timer >= auto_advance_time:
			advance_panel()

func _input(event):
	if is_transitioning:
		return
		
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if can_advance:
			advance_panel()
		else:
			dialogue_label.visible_characters = -1
			can_advance = true
			blink_indicator()

func advance_panel():
	current_panel += 1
	show_panel(current_panel)

func end_story():
	if is_transitioning:
		return
	is_transitioning = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_duration)
	tween.tween_property(dialogue_box, "modulate:a", 0.0, fade_duration)
	tween.tween_property(panel_display, "modulate:a", 0.0, fade_duration)
	await tween.finished
	
	change_to_game()

func change_to_game():
	# Load and show the simple transition screen
	var transition = preload("res://scene/simple_transition.tscn").instantiate()
	transition.next_scene_path = next_scene_path  # Pass the destination
	get_tree().root.add_child(transition)
	
	# Remove this cutscene
	queue_free()
