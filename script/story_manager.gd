extends Node

signal exploration_tip_finished
signal intro_dialogue_finished

var has_shown_exploration_tip = false
var has_shown_intro_dialogue = false
var exploration_complete = false

func _ready():
	# Wait a bit then show exploration tip
	await get_tree().create_timer(2.0).timeout
	show_exploration_tip()

func show_exploration_tip():
	if has_shown_exploration_tip:
		return
	
	has_shown_exploration_tip = true
	
	var tip_lines = [
		"Welcome to your room.",
		"Feel free to explore and look around.",
		"Use WASD to move, SHIFT to run, and your mouse to look around.",
		"Press E to interact with objects when you see the prompt."
	]
	
	DialogueManager.show_dialogue(tip_lines, "SYSTEM")
	await DialogueManager.dialogue_box.dialogue_finished
	exploration_tip_finished.emit()
	
	# After tip, wait for player to explore or go to computer
	await get_tree().create_timer(4.0).timeout
	show_intro_monologue()

func show_intro_monologue():
	if has_shown_intro_dialogue:
		return
	
	has_shown_intro_dialogue = true
	
	var monologue_lines = [
		"Man, all my friends are playing CyberRun 2026... I really want to try it out.",
		"Everyone's talking about it in the group chat.",
		"It costs 1000 pesos though. That's way too much for me right now.",
		"Maybe I can find it somewhere online for free?",
		"I guess I'll browse the internet and try to find where I can download it.",
		"Let me check my computer..."
	]
	
	DialogueManager.show_dialogue(monologue_lines, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	intro_dialogue_finished.emit()

func mark_exploration_complete():
	exploration_complete = true
	if not has_shown_intro_dialogue:
		show_intro_monologue()
