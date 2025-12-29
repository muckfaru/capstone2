extends Node

var dialogue_box_scene = preload("res://ui/dialogue_box.tscn")
var dialogue_box = null
var is_dialogue_active = false

func _ready():
	# Create dialogue box and add to scene tree
	dialogue_box = dialogue_box_scene.instantiate()
	dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

func show_dialogue(lines: Array, character_name: String = "You"):
	if not dialogue_box.is_inside_tree():
		get_tree().root.add_child(dialogue_box)
	
	is_dialogue_active = true
	dialogue_box.start_dialogue(lines, character_name)

func hide_dialogue():
	"""Force hide the dialogue box"""
	if dialogue_box and dialogue_box.visible:
		dialogue_box.visible = false
	is_dialogue_active = false

func _on_dialogue_finished():
	is_dialogue_active = false

func is_active() -> bool:
	return is_dialogue_active
