extends Node3D

@onready var player = $Player
@onready var story_manager = $StoryManager
@onready var hologram = $hologram

var hologram_ringtone_player: AudioStreamPlayer
var screen_flicker_player: AudioStreamPlayer
var beep_player: AudioStreamPlayer
var call_connect_player: AudioStreamPlayer
var call_disconnect_player: AudioStreamPlayer

@export var hologram_ringtone: AudioStream
@export var screen_flicker_sound: AudioStream
@export var beep_sound: AudioStream
@export var call_connect_sound: AudioStream
@export var call_disconnect_sound: AudioStream


func _ready():

	setup_audio_players()

	# Hide hologram initially
	if hologram:
		hologram.visible = false
	
	# IMPORTANT: Hide dialogue box immediately when scene loads
	if DialogueManager.dialogue_box and DialogueManager.dialogue_box.visible:
		DialogueManager.dialogue_box.visible = false
	
	# Check if returning from computer
	if GlobalState.returning_from_computer and not GlobalState.joined_ca_organization:
		# Position player at computer desk
		player.global_position = Vector3(-3, 6.31636, -2.05119)
		player.rotation.y = 0
		
		# Disable story manager dialogues when returning
		if story_manager:
			story_manager.has_shown_exploration_tip = true
			story_manager.has_shown_intro_dialogue = true
		
		# Reset flag
		GlobalState.returning_from_computer = false
		
		# Defer the panic sequence so _ready() completes first
		# This prevents await chains from blocking node initialization
		call_deferred("_start_post_infection_sequence")
	elif GlobalState.joined_ca_organization:
		# Player joined CA - position at desk, ready to use computer
		player.global_position = Vector3(-3, 6.31636, -2.05119)
		player.rotation.y = 0
		
		# Make sure hologram is hidden
		if hologram:
			hologram.visible = false
		
		# Re-enable mouse capture
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		print("Welcome back, CA recruit! Use your computer to access CyberArena.")

func _start_post_infection_sequence() -> void:
	# Ensure the scene tree is fully ready before starting async sequences
	await get_tree().process_frame
	await add_fade_in()
	await get_tree().create_timer(0.5).timeout
	start_panic_sequence()

func add_fade_in():
	# Create black overlay
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 100
	add_child(fade_overlay)
	
	# Fade from black
	await get_tree().create_timer(0.3).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 0.0, 1.0)
	await fade_tween.finished
	fade_overlay.queue_free()

func start_panic_sequence():
	# Ensure mouse is visible so player can see the 3D scene
	# Dialogue advances with Space/Enter, but mouse must not be captured
	# to avoid confusing the player
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Start camera shake
	start_camera_shake(3.0)  # Shake for 3 seconds
	
	# Show panic dialogue
	var panic_lines = [
		"What what just happened?! to my computer?!",
		"My computer just shut down on its own...",
		"Is my computer not compatible with CyberRun 2026?. 
		 but the specs just match my computer...",
		"That's wierd...",
		"Or there's something wrong with the download?",
	]
	
	# Safety: ensure dialogue box is ready before showing
	if not DialogueManager.dialogue_box:
		push_warning("[Main] dialogue_box is null, skipping panic dialogue")
		return
	if not DialogueManager.dialogue_box.is_inside_tree():
		get_tree().root.add_child(DialogueManager.dialogue_box)
		await get_tree().process_frame
	
	DialogueManager.show_dialogue(panic_lines, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Stop shake after dialogue
	stop_camera_shake()
	
	# After panic, show what to do next
	await get_tree().create_timer(1.0).timeout
	
	if GlobalState.computer_infected:
		var next_lines = [
			"I need to check if my computer still works...",
			"Maybe I should try turning it on again?"
		]
		DialogueManager.show_dialogue(next_lines, "You")
		await DialogueManager.dialogue_box.dialogue_finished
		
		# Trigger hologram sequence after dialogue ends
		await get_tree().create_timer(1.5).timeout
		trigger_hologram_call()

func trigger_hologram_call():
	# PREVENT RETRIGGERING
	if hologram.visible or GlobalState.joined_ca_organization or GlobalState.declined_ca_offer:
		print("Hologram sequence already completed, skipping...")
		return
	
	# Play ringtone sound
	play_hologram_ringtone()
	
	# Show hologram with animation
	await get_tree().create_timer(0.5).timeout
	show_hologram_with_animation()
	
	# Show incoming call dialogue
	await get_tree().create_timer(1.0).timeout
	var call_lines = [
		"*BEEP BEEP BEEP*",
		"What's that sound?",
		"Oh it's my hologram is receiving a call!. I need to calm down for a second",
		"I should check it out..."
	]
	DialogueManager.show_dialogue(call_lines, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Enable hologram interaction
	if player:
		player.enable_hologram_interaction()

func play_hologram_ringtone():
	# Create audio player for ringtone
	var ringtone_player = AudioStreamPlayer.new()
	add_child(ringtone_player)
	
	# You'll need to add your ringtone sound file
	# For now, using a placeholder - replace with: preload("res://asset/audio/sfx/hologram_ringtone.mp3")
	ringtone_player.stream = preload("res://asset/audio/sfx/hologram_ringtone.mp3")
	ringtone_player.volume_db = 0.0
	
	# Play ringtone (will loop until answered)
	ringtone_player.play()
	
	# Store reference to stop it later
	set_meta("ringtone_player", ringtone_player)

func show_hologram_with_animation():
	if not hologram:
		return
	
	# Make visible
	hologram.visible = true
	
	# Store original scale and position
	var original_scale = hologram.scale
	var original_position = hologram.position
	
	# Start from invisible (scale 0)
	hologram.scale = Vector3.ZERO
	hologram.position = original_position + Vector3(0, -0.5, 0)
	
	# Animate appearance
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hologram, "scale", original_scale, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(hologram, "position", original_position, 0.8).set_ease(Tween.EASE_OUT)
	
	# Add pulsing glow effect
	await tween.finished
	start_hologram_pulse()

func start_hologram_pulse():
	if not hologram:
		return
	
	var original_scale = hologram.scale
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(hologram, "scale", original_scale * 1.1, 0.5)
	pulse_tween.tween_property(hologram, "scale", original_scale, 0.5)
	
	# Store reference to stop later
	set_meta("hologram_pulse_tween", pulse_tween)

func stop_hologram_effects():
	# Stop ringtone
	if has_meta("ringtone_player"):
		var ringtone = get_meta("ringtone_player")
		if ringtone:
			ringtone.stop()
			ringtone.queue_free()
	
	# Stop pulse animation
	if has_meta("hologram_pulse_tween"):
		var tween = get_meta("hologram_pulse_tween")
		if tween:
			tween.kill()

func answer_hologram_call():
	# Stop effects
	stop_hologram_effects()
	
	# Play answer animation
	play_answer_animation()
	
	# Wait for animation
	await get_tree().create_timer(1.0).timeout
	
	# Start the CA Organization conversation
	start_ca_conversation()

func play_answer_animation():
	if not hologram:
		return
	
	# Create pickup animation - hologram moves up and gets brighter
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move up slightly
	var target_pos = hologram.position + Vector3(0, 0.3, 0)
	tween.tween_property(hologram, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT)
	
	# Scale up a bit
	var target_scale = hologram.scale * 1.2
	tween.tween_property(hologram, "scale", target_scale, 0.5).set_ease(Tween.EASE_OUT)
	
	# Add rotation for dramatic effect
	tween.tween_property(hologram, "rotation:y", hologram.rotation.y + PI * 2, 0.8)

# ============================================
# CA ORGANIZATION CONVERSATION SYSTEM
# ============================================

func start_ca_conversation():

	play_call_connect()
	# Initial connection
	var intro_lines = [
		"*Static noise*",
		"Connection established...",
		"Hello? Can you hear me?"
	]
	DialogueManager.show_dialogue(intro_lines, "???")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await get_tree().create_timer(0.5).timeout
	
	# CA Agent introduction
	var agent_intro = [
		"This Anonymouse from the CA Organization.",
		"We've detected suspicious malware activity from your network.",
		"Your computer was compromised approximately 3 minutes ago.",
		"Did you download anything unusual recently?"
	]
	DialogueManager.show_dialogue(agent_intro, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# First choice point
	await present_choice_1()

func present_choice_1():
	# Make sure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var choices = [
		"Yes, I downloaded something to my computer. but it was just a game.",
		"No, I didn't download anything!",
		"Who are you? How did you find me?"
	]
	
	# Just show choices - dialogue is already showing from previous lines
	var choice = await DialogueManager.show_choices("", choices)
	
	match choice:
		0:  # Admitted downloading
			await handle_admission()
		1:  # Denied downloading
			await handle_denial()
		2:  # Asked about CA
			await handle_ca_question()

func handle_admission():
	var player_response = [
		"I... I did download something.",
		"but it was just a game, nothing more. and my computer just crashed after that.",
		"Everything went black and shut down."
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"Oh your honesty suprises me. I appreciate that.",
		"That 'game' was a sophisticated Malware virus.",
		"It's already begun spreading through your system. that's cause the crash.",
		"But we can fix this... if you cooperate."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await present_choice_2_cooperation()

func handle_denial():
	var player_response = [
		"No, I didn't download anything!",
		"My computer just crashed on its own! it was working fine before!"
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"*Sighs* Listen carefully.",
		"I'm looking at your network logs right now.",
		"3 minutes ago: Connection to User: unknown_Source_123.darkweb",
		"Downloaded: CyberRun 2026.exe - 847MB",
		"Do those ring any bells?"
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await get_tree().create_timer(0.5).timeout
	
	var player_realization = [
		"How did you know that?! Okay... fine.",
		"I did download something.",
		"I didn't think it would be a problem! Because i always get free games from that site...",
	]
	DialogueManager.show_dialogue(player_realization, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await present_choice_2_cooperation()

func handle_ca_question():
	var player_response = [
		"Wait, who even are you?",
		"How did you get my network information?",
		"This feels like a scam..."
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_explanation = [
		"Valid questions. I would be suspicious too.",
		"The CA organization monitors illegal cyber activity worldwide.",
		"When that virus activated, it pinged our detection systems.",
		"We're the ones who hunt down the people who created it.",
		"Now... we can help you, or you can try fixing this yourself.",
		"But I guarantee you won't succeed alone."
	]
	DialogueManager.show_dialogue(agent_explanation, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await present_choice_2_cooperation()

func present_choice_2_cooperation():
	await get_tree().create_timer(0.5).timeout
	
	var setup_lines = [
		"Here's the situation:",
		"This virus you downloaded is Military grade malware.",
		"It's designed to shutdown user computers, 
		 while the virus still works, and spread to other devices through networks.",
		"In 5 hours, your entire system will be completely destroyed your important apps and files.",
		"But I can remotely access your system and neutralize it. to save your networks.",
	]
	DialogueManager.show_dialogue(setup_lines, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Make sure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var choices = [
		"Please help me fix this!",
		"What's the catch? What do you want?",
		"Can't I just boot up in safe mode or do a factory reset?"
	]
	
	# Just show choices - dialogue is already showing
	var choice = await DialogueManager.show_choices("", choices)
	
	match choice:
		0:  # Accepts help immediately
			await handle_accepts_help()
		1:  # Asks about catch
			await handle_suspicious()
		2:  # Suggests factory reset
			await handle_factory_reset()

func handle_accepts_help():
	var player_response = [
		"Yes, please help me! i don't want to lose my files! and my computer!",
		"I don't want to cause problems for my friends either..."
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await begin_fix_sequence()

func handle_suspicious():
	var player_response = [
		"Wait wait... why would you help me? is this some kind of trick?",
		"Or do i need to pay you back later?",
		"What do you want from me?"
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"Why we help random people like you? what an unusual question. for you to ask.",
		"We're an CA Organization. our mission is to fight cyber threats.",
		"a random person like you who don't know what is happening in the cyber world is an easy target for these threats.",
		"What we want is simple. you to become aware of these threats.",
		"Fix your computer first. Then we'll talk about opportunities."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await begin_fix_sequence()

func handle_factory_reset():
	var player_response = [
		"Can't I just wipe everything?",
		"Bootable media should remove any virus, right?"
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"What you're suggesting is a common misconception. This virus has already infected your BIOS firmware.",
		"Factory reset won't help you. Can't you understand that?",
		"Helping you with a factory reset is out of the question.",
		"I'll help you, but only if you cooperate.",
		"You need professional intervention. My intervention."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await begin_fix_sequence()

func begin_fix_sequence():
	await get_tree().create_timer(0.5).timeout
	play_beep()
	var fix_intro = [
		"Alright. Initiating remote access protocol.",
		"Don't touch anything. This will take a few moments.",
		"*Typing sounds*"
	]
	DialogueManager.show_dialogue(fix_intro, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Visual effect - screen flicker
	await create_screen_flicker(2.0)
	
	var fix_progress = [
		"Accessing your system... Done.",
		"Isolating malware signatures... Done.",
		"Deploying countermeasures...",
		"...This is interesting."
	]
	DialogueManager.show_dialogue(fix_progress, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await present_choice_3_discovery()

func create_screen_flicker(duration: float):
	play_screen_flicker()
	var flicker_overlay = ColorRect.new()
	flicker_overlay.color = Color(0, 1, 1, 0)
	flicker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flicker_overlay.z_index = 50
	add_child(flicker_overlay)
	
	var elapsed = 0.0
	while elapsed < duration:
		var tween = create_tween()
		tween.tween_property(flicker_overlay, "color:a", randf_range(0.1, 0.3), 0.1)
		await tween.finished
		
		tween = create_tween()
		tween.tween_property(flicker_overlay, "color:a", 0.0, 0.1)
		await tween.finished
		
		elapsed += 0.2
	
	flicker_overlay.queue_free()

func present_choice_3_discovery():
	var discovery_lines = [
		"Wait a second...",
		"This virus isn't just random malware. These patterns... I think I've seen this before.",
		"Whoever infected you isn't some script kiddie.",
		"They're professionals. Dangerous ones."
	]
	DialogueManager.show_dialogue(discovery_lines, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Make sure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var choices = [
		"What?! Why would they target ME?",
		"Can you still fix it?",
		"Should I call the police?"
	]
	
	# Just show choices - dialogue is already showing
	var choice = await DialogueManager.show_choices("", choices)
	
	match choice:
		0:  # Why me
			await handle_why_targeted()
		1:  # Can you fix
			await handle_can_fix()
		2:  # Call police
			await handle_police_suggestion()

func handle_why_targeted():
	var player_response = [
		"But why would they target me?",
		"I don't have anything valuable on my computer... I just wanted to play a game."
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"No they're not targeting you specifically. they're targeting people like you. 
		 people who are unaware of cyber threats.",
		"Even you don't realize it, your computer is part of a larger network.",
		"This virus is designed to spread through networks, infecting as many devices as possible.",
		"You were just an unwitting carrier."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await conclude_fix()

func handle_can_fix():
	var player_response = [
		"Forget about who did it!",
		"Can you fix my computer or not?!"
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"You're getting impatient I see, calm down yourself.",
		"I'm fixing it right now.",
		"You'r computer will be operational again shortly."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await conclude_fix()

func handle_police_suggestion():
	var player_response = [
		"Shouldn't I call the police?",
		"Report this to someone official?"
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"Calling the police won't help you in this situation. right now.",
		"Some police departments don't have the resources to handle cybercrimes effectively.",
		"By the time they investigate, the malware would have already caused significant damage.",
		"That's why I'm here to help you directly. Trust me on this.",
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await conclude_fix()

func conclude_fix():
	await get_tree().create_timer(0.5).timeout
	
	var completion_lines = [
		"*Beep* Malware neutralized. Your system is clean.",
		"Your computer should function normally now. Open it up and check.",
		"But first, we need to discuss something important..."
	]
	DialogueManager.show_dialogue(completion_lines, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await final_recruitment()

func final_recruitment():
	var recruitment_lines = [
		"You need to understand the bigger picture here.",
		"Download the game you wanted to play from a legitimate source. But be aware, your computer is now on a watchlist.",
		"Because you have downloaded many games from unofficial sources before. I see on your logs.",
		"You need to be more careful in the future.",
		"We are CA Organization. We combat cyber threats ",
		"and we could use someone like you.",
		"I see you like games, but do you also have an interest in cybersecurity?",
		"Are you interested in joining us? The Cyber Arena"
	]
	DialogueManager.show_dialogue(recruitment_lines, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Make sure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var choices = [
		"I want to join. Teach me.",
		"What exactly is Cyber Arena do?",
		"That's sounds interesting."
	]
	
	# Just show choices - dialogue is already showing
	var choice = await DialogueManager.show_choices("", choices)
	
	match choice:
		0:  # Immediate yes
			await handle_immediate_yes()
		1:  # Ask for details
			await handle_ask_details()
		2:  # Decline
			await handle_decline()

func handle_immediate_yes():
	var player_response = [
		"I want to join. You're amazing at what you do.",
		"I want to learn how to protect myself and others.",
		"I don't want to feel helpless again."
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await accept_recruitment()

func handle_ask_details():
	var player_response = [
		"What does the CA Organization actually do?",
		"What would I be benefiting from joining?"
	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"The Cyber Arena are our platfrom that teach and train individuals in cybersecurity.",
		"We also let people who join us to fight for thier places in cyber threat.",
		"People who will join us will fight each other to protect thier honor and thier skills in the cyber world.",
		"You want to be one of those people? then join us."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	await accept_recruitment()
	# Make sure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var follow_up_choices = [
		"I'm in. Where do I start?",
		"That's sounds interesting for me..."
	]
	
	# Just show choices - dialogue is already showing
	var follow_up = await DialogueManager.show_choices("", follow_up_choices)
	
	if follow_up == 0:
		await accept_recruitment()
	else:
		await handle_decline()

func handle_decline():
	var player_response = [
		"That's sounds interesting. but I will think it for a minute.",

	]
	DialogueManager.show_dialogue(player_response, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	var agent_response = [
		"Your computer is fixed. You can go back to normal.",
		"But remember... they're still out there.",
		"If you change your mind, check your email.",
		"I'll send you information. The choice will be yours.",
		"Stay safe out there."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await accept_recruitment()

func accept_recruitment():
	var agent_response = [
		"Excellent choice.",
		"Welcome to the Cyber Arena Organization.",
		"Your training begins now.",
		"First lesson: Your computer is your weapon.",
		"And you just survived your first cyber attack.",
		"Check your system. I've left you something...",
		"A  Platform. Complete it.",
		"When you're ready, we'll talk again.",
		"Good luck, recruit."
	]
	DialogueManager.show_dialogue(agent_response, "Anonymouse")
	await DialogueManager.dialogue_box.dialogue_finished
	
	await end_call_accepted()

func end_call_accepted():
	play_call_disconnect()
	# Set global state for recruitment
	GlobalState.joined_ca_organization = true
	GlobalState.computer_infected = false
	
	var ending_lines = [
		"*Connection terminated*",
		"The hologram flickers and disappears.",
		"My computer... it's fixed.",
		"But everything has changed.",
		"I'm part of something now. Something bigger.",
		"Time to see what they left for me..."
	]
	DialogueManager.show_dialogue(ending_lines, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Hide hologram properly - just make it invisible
	if hologram:
		hologram.visible = false
	
	# IMPORTANT: Disable hologram interaction permanently
	if player:
		player.hologram_interaction_enabled = false
		player.can_interact_hologram = false
		
		# Re-enable mouse look
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("Player joined CA Organization! Computer is now accessible with new training program.")
	
	# Give player control back
	await get_tree().create_timer(0.5).timeout

func end_call_declined():
	play_call_disconnect()
	# Set global state
	GlobalState.computer_infected = false
	GlobalState.declined_ca_offer = true
	
	var ending_lines = [
		"*Connection terminated*",
		"The hologram fades away.",
		"My computer is fixed... that's something.",
		"But I can't shake this feeling.",
		"That this isn't really over.",
		"Maybe I should check my computer..."
	]
	DialogueManager.show_dialogue(ending_lines, "You")
	await DialogueManager.dialogue_box.dialogue_finished
	
	# Hide hologram
	if hologram:
		hologram.visible = false
	
	# IMPORTANT: Disable hologram interaction permanently
	if player:
		player.hologram_interaction_enabled = false
		player.can_interact_hologram = false
		
		# Re-enable mouse look
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	print("Player declined CA offer. Computer is now accessible.")
	
	# Give player control back
	await get_tree().create_timer(0.5).timeout

func start_camera_shake(duration: float):
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D")
		var original_position = camera.position
		
		# Create shake effect
		var shake_timer = 0.0
		var shake_intensity = 0.15
		
		while shake_timer < duration:
			var offset_x = randf_range(-shake_intensity, shake_intensity)
			var offset_y = randf_range(-shake_intensity, shake_intensity)
			var offset_z = randf_range(-shake_intensity, shake_intensity)
			
			camera.position = original_position + Vector3(offset_x, offset_y, offset_z)
			
			await get_tree().create_timer(0.05).timeout
			shake_timer += 0.05
		
		# Reset camera position
		camera.position = original_position

func stop_camera_shake():
	if player and player.has_node("Camera3D"):
		var camera = player.get_node("Camera3D")
		# Reset to default position
		camera.position = Vector3(0.674639, 0.195653, -0.305826)

func setup_audio_players():
	# Hologram ringtone player
	hologram_ringtone_player = AudioStreamPlayer.new()
	hologram_ringtone_player.name = "HologramRingtone"
	hologram_ringtone_player.volume_db = 0.0
	add_child(hologram_ringtone_player)
	
	# Screen flicker sound
	screen_flicker_player = AudioStreamPlayer.new()
	screen_flicker_player.name = "ScreenFlicker"
	screen_flicker_player.volume_db = 0.0
	add_child(screen_flicker_player)
	
	# Beep sound (for messages/notifications)
	beep_player = AudioStreamPlayer.new()
	beep_player.name = "BeepPlayer"
	beep_player.volume_db = 0.0
	add_child(beep_player)
	
	# Call connect sound
	call_connect_player = AudioStreamPlayer.new()
	call_connect_player.name = "CallConnect"
	call_connect_player.volume_db = 0.0
	add_child(call_connect_player)
	
	# Call disconnect sound
	call_disconnect_player = AudioStreamPlayer.new()
	call_disconnect_player.name = "CallDisconnect"
	call_disconnect_player.volume_db = 0.0
	add_child(call_disconnect_player)

# ============================================
# SOUND FUNCTIONS - ADD THESE
# ============================================
func play_beep():
	if beep_sound and beep_player:
		beep_player.stream = beep_sound
		beep_player.play()

func play_screen_flicker():
	if screen_flicker_sound and screen_flicker_player:
		screen_flicker_player.stream = screen_flicker_sound
		screen_flicker_player.play()

func play_call_connect():
	if call_connect_sound and call_connect_player:
		call_connect_player.stream = call_connect_sound
		call_connect_player.play()

func play_call_disconnect():
	if call_disconnect_sound and call_disconnect_player:
		call_disconnect_player.stream = call_disconnect_sound
		call_disconnect_player.play()