extends CanvasLayer

# ============================================
# PREMIUM RANK UP NOTIFICATION - WITH LETTER-BY-LETTER ANIMATION
# ============================================

signal notification_closed

@onready var background: ColorRect = $Background
@onready var panel: Panel = $CenterContainer/Panel
@onready var rank_icon: TextureRect = $CenterContainer/Panel/MarginContainer/VBoxContainer/RankIconContainer/RankIcon
@onready var rewards_container: HBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/RewardsContainer
@onready var progress_bar: ProgressBar = $CenterContainer/Panel/MarginContainer/VBoxContainer/ProgressContainer/ProgressBar
@onready var progress_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/ProgressContainer/ProgressLabel
@onready var close_hint: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/CloseHint
@onready var sfx_rank_up: AudioStreamPlayer = $SFX_RankUp
@onready var sfx_coin_flip: AudioStreamPlayer = $SFX_CoinFlip
@onready var sfx_particles: AudioStreamPlayer = $SFX_Particles
@onready var sfx_reveal: AudioStreamPlayer = $SFX_Reveal

# Rich text labels for animations
var title_rich: RichTextLabel
var rank_name_rich: RichTextLabel
var message_rich: RichTextLabel

var can_close: bool = false
var particles: CPUParticles2D
var light_rays: Node2D
var screen_flash: ColorRect
var scanlines: Node2D
var old_rank_data: Dictionary
var new_rank_data: Dictionary
var panel_style: StyleBoxFlat

# Custom font
var custom_font: FontFile

# Reward system
var rank_rewards: Dictionary = {
	"Iron": ["10 Credits", "Starter Badge"],
	"Bronze": ["25 Credits", "Bronze Badge", "Speed Boost"],
	"Silver": ["50 Credits", "Silver Badge", "2x XP Boost"],
	"Gold": ["100 Credits", "Gold Badge", "Special Ability"],
	"Platinum": ["200 Credits", "Platinum Badge", "VIP Access"],
	"Diamond": ["500 Credits", "Diamond Badge", "Elite Skin"],
	"Master": ["750 Credits", "Master Badge", "Pro Features"],
	"Grandmaster": ["1000 Credits", "Grandmaster Badge", "Exclusive Content"],
	"Challenger": ["2000 Credits", "Challenger Badge", "Ultimate Power"]
}

func _ready() -> void:
	layer = 100
	background.modulate.a = 0
	panel.modulate.a = 0
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Load custom font FIRST
	_load_custom_font()
	
	# Replace labels with RichTextLabels for animation
	_setup_rich_text_labels()
	
	_apply_cyberpunk_style()
	_create_particle_effects()
	_create_light_rays()
	_create_screen_flash()
	_create_scanlines()
	_setup_progress_bar()
	_setup_sound_effects()
	
	# Ensure proper z-index hierarchy
	var vbox = $CenterContainer/Panel/MarginContainer/VBoxContainer
	if vbox:
		# Make sure all content is above background effects
		var rank_icon_container = vbox.get_node_or_null("RankIconContainer")
		if rank_icon_container:
			rank_icon_container.z_index = 8
		
		if rewards_container:
			rewards_container.z_index = 10
		
		var progress_container = vbox.get_node_or_null("ProgressContainer")
		if progress_container:
			progress_container.z_index = 10
	
	set_process_input(true)

func _load_custom_font() -> void:
	"""Load NicoMoji-Regular.ttf font"""
	var font_paths = [
		"res://asset/fonts/NicoMoji-Regular.ttf",
		"res://assets/fonts/NicoMoji-Regular.ttf",
		"res://font/NicoMoji-Regular.ttf",
		"res://fonts/NicoMoji-Regular.ttf"
	]
	
	for font_path in font_paths:
		if ResourceLoader.exists(font_path):
			custom_font = load(font_path)
			if custom_font:
				print("[RankUpNotification] ✅ Loaded custom font from: %s" % font_path)
				return
	
	push_warning("[RankUpNotification] ⚠️ Font not found in any location, using default")
	print("[RankUpNotification] ⚠️ Tried paths: %s" % font_paths)

func _setup_rich_text_labels() -> void:
	"""Replace key labels with RichTextLabels for letter animation"""
	var title_label = $CenterContainer/Panel/MarginContainer/VBoxContainer/Title
	if title_label:
		title_rich = _create_rich_text_label(title_label)
		title_rich.z_index = 10
		title_label.get_parent().add_child(title_rich)
		title_label.get_parent().move_child(title_rich, title_label.get_index())
		title_label.queue_free()
		print("[RankUpNotification] ✅ Created title_rich at size: ", title_rich.custom_minimum_size)
	
	var rank_name_label = $CenterContainer/Panel/MarginContainer/VBoxContainer/RankNameLabel
	if rank_name_label:
		rank_name_rich = _create_rich_text_label(rank_name_label)
		rank_name_rich.z_index = 10
		rank_name_label.get_parent().add_child(rank_name_rich)
		rank_name_label.get_parent().move_child(rank_name_rich, rank_name_label.get_index())
		rank_name_label.queue_free()
		print("[RankUpNotification] ✅ Created rank_name_rich at size: ", rank_name_rich.custom_minimum_size)
	
	var message_label = $CenterContainer/Panel/MarginContainer/VBoxContainer/MessageLabel
	if message_label:
		message_rich = _create_rich_text_label(message_label)
		message_rich.z_index = 10
		message_label.get_parent().add_child(message_rich)
		message_label.get_parent().move_child(message_rich, message_label.get_index())
		message_label.queue_free()
		print("[RankUpNotification] ✅ Created message_rich at size: ", message_rich.custom_minimum_size)

func _create_rich_text_label(source_label: Label) -> RichTextLabel:
	"""Create a RichTextLabel matching the source label's properties"""
	var rich = RichTextLabel.new()
	rich.name = source_label.name + "_Rich"
	
	# Copy ALL layout properties
	rich.custom_minimum_size = source_label.custom_minimum_size
	rich.size = source_label.size
	rich.position = source_label.position
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.size_flags_vertical = source_label.size_flags_vertical
	rich.layout_mode = source_label.layout_mode
	
	# Copy anchors if they exist
	rich.anchor_left = source_label.anchor_left
	rich.anchor_top = source_label.anchor_top
	rich.anchor_right = source_label.anchor_right
	rich.anchor_bottom = source_label.anchor_bottom
	
	# RichTextLabel specific settings
	rich.bbcode_enabled = true
	rich.fit_content = false
	rich.scroll_active = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# Make sure text is centered
	rich.text = "[center][/center]"
	rich.visible = true
	
	return rich

func _animate_text_letter_by_letter(rich_label: RichTextLabel, text: String, colors: Array, delay_per_letter: float = 0.05, start_delay: float = 0.0) -> void:
	"""Animate text with letter-by-letter color change"""
	if not rich_label or text.is_empty():
		return
	
	await get_tree().create_timer(start_delay).timeout
	
	rich_label.text = "[center]"
	rich_label.visible = true
	rich_label.modulate.a = 1.0
	
	for i in range(text.length()):
		var char = text[i]
		var color = colors[i % colors.size()]
		var color_hex = color.to_html()
		
		rich_label.text += "[color=#%s]%s[/color]" % [color_hex, char]
		
		await get_tree().create_timer(delay_per_letter).timeout
	
	rich_label.text += "[/center]"
	
	_start_color_wave(rich_label, text, colors)

func _start_color_wave(rich_label: RichTextLabel, text: String, colors: Array, wave_speed: float = 0.08) -> void:
	"""Create a continuous color wave effect across the text"""
	var wave_offset = 0
	
	while rich_label and is_instance_valid(rich_label):
		var bbcode_text = "[center]"
		
		for i in range(text.length()):
			var char = text[i]
			var color_index = (i + wave_offset) % colors.size()
			var color = colors[color_index]
			var color_hex = color.to_html()
			
			bbcode_text += "[color=#%s]%s[/color]" % [color_hex, char]
		
		bbcode_text += "[/center]"
		rich_label.text = bbcode_text
		wave_offset += 1
		
		await get_tree().create_timer(wave_speed).timeout

func _setup_sound_effects() -> void:
	"""Load and setup all sound effects"""
	_load_sound(sfx_rank_up, "res://asset/audio/sfx/rank_up.mp3", -3.0)
	_load_sound(sfx_coin_flip, "res://asset/audio/sfx/coin_flip.mp3", -5.0)
	_load_sound(sfx_particles, "res://asset/audio/sfx/particles_burst.mp3", -8.0)
	_load_sound(sfx_reveal, "res://asset/audio/sfx/reveal.mp3", -6.0)
	
	# Generate fallback sounds if files don't exist
	if not sfx_rank_up.stream:
		sfx_rank_up.stream = _generate_rank_up_sound()
	if not sfx_coin_flip.stream:
		sfx_coin_flip.stream = _generate_whoosh_sound()
	if not sfx_particles.stream:
		sfx_particles.stream = _generate_particle_sound()
	if not sfx_reveal.stream:
		sfx_reveal.stream = _generate_reveal_sound()

func _load_sound(player: AudioStreamPlayer, path: String, volume_db: float) -> void:
	"""Helper to load sound file"""
	player.volume_db = volume_db
	
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			player.stream = stream
			print("[RankUpNotification] ✅ Loaded sound: %s" % path)
		else:
			push_warning("[RankUpNotification] ⚠️ Failed to load sound: %s" % path)
	else:
		push_warning("[RankUpNotification] ⚠️ Sound not found: %s" % path)

# Procedural sound generation for fallbacks
func _generate_rank_up_sound() -> AudioStreamGenerator:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 1.0
	return gen

func _generate_whoosh_sound() -> AudioStreamGenerator:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.5
	return gen

func _generate_particle_sound() -> AudioStreamGenerator:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.8
	return gen

func _generate_reveal_sound() -> AudioStreamGenerator:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.6
	return gen

func _apply_custom_font(label: Label, size: int) -> void:
	"""Apply custom font to a label"""
	if custom_font:
		label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", size)

func _apply_custom_font_rich(rich_label: RichTextLabel, size: int) -> void:
	"""Apply custom font to RichTextLabel"""
	if custom_font:
		rich_label.add_theme_font_override("normal_font", custom_font)
		rich_label.add_theme_font_override("bold_font", custom_font)
	rich_label.add_theme_font_size_override("normal_font_size", size)
	rich_label.add_theme_font_size_override("bold_font_size", size)

func _apply_cyberpunk_style() -> void:
	"""Apply premium cyberpunk styling with semi-transparent background"""
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.1, 0.15, 0.85)
	panel_style.border_width_left = 5
	panel_style.border_width_top = 5
	panel_style.border_width_right = 5
	panel_style.border_width_bottom = 5
	panel_style.border_color = Color(0, 1, 1, 1)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.shadow_color = Color(0, 1, 1, 0.8)
	panel_style.shadow_size = 40
	panel.add_theme_stylebox_override("panel", panel_style)
	
	await get_tree().process_frame
	
	# Style title (rich text)
	if title_rich:
		_apply_custom_font_rich(title_rich, 25)
		title_rich.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		title_rich.add_theme_constant_override("outline_size", 3)
	
	# Style rank name (rich text)
	if rank_name_rich:
		_apply_custom_font_rich(rank_name_rich, 52)
		rank_name_rich.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		rank_name_rich.add_theme_constant_override("outline_size", 4)
	
	# Style message (rich text)
	if message_rich:
		_apply_custom_font_rich(message_rich, 20)
		message_rich.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		message_rich.add_theme_constant_override("outline_size", 2)
	
	if close_hint:
		close_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_custom_font(close_hint, 14)
		close_hint.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
		close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _setup_progress_bar() -> void:
	"""Style the progress bar"""
	if not progress_bar:
		return
	
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var progress_bg = StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.1, 0.15, 0.2, 0.9)
	progress_bg.border_width_left = 2
	progress_bg.border_width_right = 2
	progress_bg.border_width_top = 2
	progress_bg.border_width_bottom = 2
	progress_bg.border_color = Color(0, 0.6, 0.6, 0.7)
	progress_bg.corner_radius_top_left = 12
	progress_bg.corner_radius_top_right = 12
	progress_bg.corner_radius_bottom_left = 12
	progress_bg.corner_radius_bottom_right = 12
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color(0, 1, 1, 0.9)
	progress_fill.corner_radius_top_left = 10
	progress_fill.corner_radius_top_right = 10
	progress_fill.corner_radius_bottom_left = 10
	progress_fill.corner_radius_bottom_right = 10
	
	progress_bar.add_theme_stylebox_override("background", progress_bg)
	progress_bar.add_theme_stylebox_override("fill", progress_fill)
	
	if progress_label:
		progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_custom_font(progress_label, 15)
		progress_label.add_theme_color_override("font_color", Color(0.9, 1, 1))
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _create_particle_effects() -> void:
	"""Enhanced particle effects"""
	particles = CPUParticles2D.new()
	particles.emitting = false
	particles.amount = 100
	particles.lifetime = 2.5
	particles.one_shot = false
	particles.explosiveness = 0.95
	particles.z_index = 5
	
	particles.position = Vector2(325, 225)
	
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50.0
	
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 180
	particles.initial_velocity_max = 350
	particles.angular_velocity_min = -400
	particles.angular_velocity_max = 400
	
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0.9, 0, 1))
	gradient.add_point(0.25, Color(0, 1, 1, 1))
	gradient.add_point(0.5, Color(1, 0.85, 0, 0.9))
	gradient.add_point(0.75, Color(0, 1, 1, 0.6))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	particles.color_ramp = gradient
	
	panel.add_child(particles)

func _create_light_rays() -> void:
	"""Enhanced light rays"""
	light_rays = Node2D.new()
	light_rays.modulate.a = 0
	light_rays.position = Vector2(325, 225)
	light_rays.z_index = -3
	
	for i in range(16):
		var ray = ColorRect.new()
		ray.color = Color(0, 1, 1, 0.25) if i % 2 == 0 else Color(1, 0.85, 0, 0.2)
		ray.size = Vector2(12, 300)
		ray.position = Vector2(-6, -150)
		ray.rotation = (PI * 2 * i) / 16.0
		light_rays.add_child(ray)
	
	panel.add_child(light_rays)

func _create_screen_flash() -> void:
	"""Create full-screen flash"""
	screen_flash = ColorRect.new()
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.z_index = 150
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_flash)
	
	screen_flash.anchors_preset = Control.PRESET_FULL_RECT
	screen_flash.anchor_left = 0
	screen_flash.anchor_top = 0
	screen_flash.anchor_right = 1
	screen_flash.anchor_bottom = 1

func _create_scanlines() -> void:
	"""Create scanlines effect"""
	scanlines = Node2D.new()
	scanlines.z_index = -2
	scanlines.modulate.a = 0
	
	await get_tree().process_frame
	
	var panel_height = 550
	var line_height = 3
	var num_lines = 18
	var spacing = panel_height / (num_lines + 1)
	
	for i in range(num_lines):
		var line = ColorRect.new()
		line.color = Color(0, 1, 1, 0.15)
		line.size = Vector2(650, line_height)
		line.position = Vector2(0, spacing * (i + 1))
		scanlines.add_child(line)
	
	panel.add_child(scanlines)

func show_rank_up(old_rank: Dictionary, new_rank: Dictionary, xp_progress: float = 0.0) -> void:
	"""Main entry point to show rank up notification"""
	print("[RankUpNotification] Showing rank up: %s → %s" % [old_rank["name"], new_rank["name"]])
	print("[RankUpNotification] Current XP: %d, Min XP: %d, Max XP: %d" % [new_rank["current_xp"], new_rank["min_xp"], new_rank["max_xp"]])
	
	old_rank_data = old_rank
	new_rank_data = new_rank
	
	await get_tree().process_frame
	
	# Position effects at panel center
	var panel_center = panel.size / 2
	particles.position = panel_center
	light_rays.position = panel_center
	
	# Start with old rank icon
	if old_rank.has("icon"):
		var old_texture = load(old_rank["icon"])
		if old_texture:
			rank_icon.texture = old_texture
	
	# Prepare text but don't show yet
	var rank_name_text = new_rank["name"].to_upper()
	
	# Dynamic messages
	var messages = [
		"🚀 Next Level Unlocked!",
		"⚡ Power Level Rising!",
		"🔥 Unstoppable Progress!",
		"💎 Elite Status Achieved!",
		"🎯 Exceptional Performance!"
	]
	var message_text = messages[randi() % messages.size()]
	
	# Show rewards
	_display_rewards(new_rank["name"])
	
	# Setup progress bar
	if progress_bar and progress_label:
		var current_xp = new_rank["current_xp"]
		var min_xp = new_rank["min_xp"]
		var max_xp = new_rank["max_xp"]
		
		if max_xp != 999999:
			var xp_range = max_xp - min_xp + 1
			var xp_in_rank = current_xp - min_xp
			
			progress_bar.max_value = xp_range
			progress_bar.value = 0
			
			print("[RankUpNotification] Progress Bar Setup:")
			print("  XP Range: %d (from %d to %d)" % [xp_range, min_xp, max_xp])
			print("  XP in Rank: %d" % xp_in_rank)
			print("  Progress: %.1f%%" % ((float(xp_in_rank) / float(xp_range)) * 100.0))
			
			progress_label.text = "Progress to next rank: 0%"
		else:
			progress_bar.max_value = 100
			progress_bar.value = 100
			progress_label.text = "MAX RANK ACHIEVED! 🏆"
	
	# Start animations with letter-by-letter text
	_animate_entrance_with_text(xp_progress, rank_name_text, message_text, new_rank["color"])
	
	# Enable closing
	await get_tree().create_timer(3.5).timeout
	can_close = true
	close_hint.visible = true
	_pulse_close_hint()

func _animate_entrance_with_text(xp_progress: float, rank_name_text: String, message_text: String, rank_color: Color) -> void:
	"""Complete entrance animation WITH letter-by-letter text animations"""
	panel.scale = Vector2(0.6, 0.6)
	
	# 1. Dramatic entrance
	var tween1 = create_tween()
	tween1.set_parallel(true)
	tween1.set_trans(Tween.TRANS_BACK)
	tween1.set_ease(Tween.EASE_OUT)
	tween1.tween_property(background, "modulate:a", 1.0, 0.5)
	tween1.tween_property(panel, "modulate:a", 1.0, 0.5)
	tween1.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.65)
	
	# ✨ Animate title text letter-by-letter (gold → cyan gradient)
	var title_colors = [
		Color(1, 0.85, 0, 1),
		Color(1, 0.9, 0.2, 1),
		Color(0.8, 1, 0.8, 1),
		Color(0.4, 1, 1, 1),
		Color(0, 1, 1, 1),
		Color(0.4, 1, 1, 1),
	]
	_animate_text_letter_by_letter(title_rich, "Congratulations For Reaching", title_colors, 0.04, 0.3)
	
	await tween1.finished
	
	# Settle
	var settle = create_tween()
	settle.set_trans(Tween.TRANS_BACK)
	settle.set_ease(Tween.EASE_OUT)
	settle.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25)
	
	# 2. Screen shake
	_screen_shake()
	
	# 3. Spin old rank
	await get_tree().create_timer(0.2).timeout
	_spin_icon_3d(rank_icon, true)
	
	# 4. Particles
	await get_tree().create_timer(0.4).timeout
	particles.emitting = true
	_play_sound(sfx_particles)
	
	# 5. 3D coin-flip transformation
	await get_tree().create_timer(0.6).timeout
	_coin_flip_transform()
	
	# 6. Play main rank up SFX
	await get_tree().create_timer(0.3).timeout
	_play_sound(sfx_rank_up)
	
	# 7. Reveal new rank with effects
	_reveal_new_rank()
	
	# ✨ Animate rank name letter-by-letter (rank-specific color wave)
	await get_tree().create_timer(0.5).timeout
	var rank_colors = [
		rank_color,
		rank_color.lightened(0.3),
		Color(1, 1, 1, 1),
		rank_color.lightened(0.3),
		rank_color,
	]
	_animate_text_letter_by_letter(rank_name_rich, rank_name_text, rank_colors, 0.08, 0.0)
	
	# ✨ Animate message letter-by-letter
	await get_tree().create_timer(0.6).timeout
	var message_colors = [
		Color(1, 1, 1, 1),
		Color(0.9, 0.95, 1, 1),
		Color(0.8, 1, 1, 1),
		Color(0.9, 0.95, 1, 1),
	]
	_animate_text_letter_by_letter(message_rich, message_text, message_colors, 0.03, 0.0)
	
	# 8. Progress bar
	await get_tree().create_timer(0.7).timeout
	_animate_progress_bar(xp_progress)

func _display_rewards(rank_name: String) -> void:
	"""Display unlocked rewards - horizontally aligned"""
	if not rewards_container:
		return
	
	# Clear existing
	for child in rewards_container.get_children():
		child.queue_free()
	
	var rewards = rank_rewards.get(rank_name, ["New Rewards Unlocked!"])
	
	for reward in rewards:
		var reward_label = Label.new()
		reward_label.text = "✨ " + reward
		reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_custom_font(reward_label, 16)
		reward_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
		reward_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		reward_label.add_theme_constant_override("outline_size", 2)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		reward_label.modulate.a = 0
		rewards_container.add_child(reward_label)
		
		# Stagger animations
		await get_tree().create_timer(0.12).timeout
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(reward_label, "modulate:a", 1.0, 0.35)

func _screen_shake() -> void:
	"""Enhanced screen shake"""
	var original_pos = panel.position
	var shake_amount = 15.0
	var shake_duration = 0.6
	var shake_count = 12
	var tween = create_tween()
	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		tween.tween_property(panel, "position", original_pos + offset, shake_duration / shake_count)
	tween.tween_property(panel, "position", original_pos, shake_duration / shake_count)

func _spin_icon_3d(icon: TextureRect, clockwise: bool = true) -> void:
	"""3D-style rotation with Y-axis flip simulation"""
	var direction = 1 if clockwise else -1
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(icon, "rotation", TAU * 2 * direction, 1.0)
	
	var scale_tween = create_tween()
	scale_tween.set_trans(Tween.TRANS_ELASTIC)
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(icon, "scale", Vector2(1.5, 1.5), 0.5)
	scale_tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.5)

func _coin_flip_transform() -> void:
	"""3D coin-flip effect - front to back rotation"""
	_play_sound(sfx_coin_flip)
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Phase 1: Shrink to 0 (rotating away from viewer)
	tween.tween_property(rank_icon, "scale:x", 0.0, 0.4)
	tween.parallel().tween_property(rank_icon, "modulate:a", 0.3, 0.4)
	
	await tween.finished
	
	# Swap texture at thinnest point
	if new_rank_data.has("icon"):
		var new_texture = load(new_rank_data["icon"])
		if new_texture:
			rank_icon.texture = new_texture
	
	# Phase 2: Grow back (rotating toward viewer)
	var tween2 = create_tween()
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.set_ease(Tween.EASE_OUT)
	tween2.tween_property(rank_icon, "scale:x", 1.3, 0.4)
	tween2.parallel().tween_property(rank_icon, "modulate:a", 1.0, 0.4)

func _reveal_new_rank() -> void:
	"""Epic reveal with all effects"""
	_play_sound(sfx_reveal)
	
	# 1. Screen flash
	var flash_tween = create_tween()
	flash_tween.tween_property(screen_flash, "color:a", 0.85, 0.1)
	flash_tween.tween_property(screen_flash, "color:a", 0.0, 0.5)
	
	# 2. Light rays
	_animate_light_rays()
	
	# 3. Pulsing border
	_start_pulsing_border()
	
	# 4. Scanlines
	_animate_scanlines()
	
	# 5. Pop effect on icon
	var pop_tween = create_tween()
	pop_tween.set_trans(Tween.TRANS_ELASTIC)
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(rank_icon, "scale", Vector2(1.4, 1.4), 0.35)
	pop_tween.tween_property(rank_icon, "scale", Vector2(1.0, 1.0), 0.45)
	
	await pop_tween.finished
	
	# 6. Multiple particle bursts
	for i in range(3):
		particles.emitting = true
		_play_sound(sfx_particles)
		await get_tree().create_timer(0.18).timeout
		particles.emitting = false
		await get_tree().create_timer(0.12).timeout
	
	rank_icon.rotation = 0

func _animate_light_rays() -> void:
	"""Fade in and rotate light rays"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(light_rays, "modulate:a", 0.6, 0.7)
	
	var rotate_tween = create_tween()
	rotate_tween.set_loops()
	rotate_tween.tween_property(light_rays, "rotation", TAU, 10.0)

func _start_pulsing_border() -> void:
	"""Pulse border between cyan and gold"""
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_method(_update_border_pulse, 0.0, 1.0, 1.2)
	tween.tween_method(_update_border_pulse, 1.0, 0.0, 1.2)

func _update_border_pulse(value: float) -> void:
	"""Update border color"""
	if panel_style:
		var cyan = Color(0, 1, 1)
		var gold = Color(1, 0.85, 0)
		var color = cyan.lerp(gold, value)
		panel_style.border_color = color
		panel_style.shadow_size = 40 + int(value * 25)

func _animate_scanlines() -> void:
	"""Smooth scanline animation"""
	var fade_tween = create_tween()
	fade_tween.tween_property(scanlines, "modulate:a", 0.7, 0.5)
	
	var move_tween = create_tween()
	move_tween.set_loops()
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_property(scanlines, "position:y", -25, 2.5)
	move_tween.tween_property(scanlines, "position:y", 25, 2.5)
	move_tween.tween_property(scanlines, "position:y", 0, 2.5)

func _animate_progress_bar(target_value: float) -> void:
	"""Animate progress bar filling with actual rank progress"""
	if not progress_bar or not progress_label:
		print("[RankUpNotification] ⚠️ Progress bar or label not found!")
		return
	
	# Check if max rank
	if new_rank_data.get("max_xp", 0) == 999999:
		progress_bar.value = 100
		progress_label.text = "MAX RANK ACHIEVED! 🏆"
		print("[RankUpNotification] Max rank achieved!")
		return
	
	# Calculate XP in current rank
	var min_xp = new_rank_data.get("min_xp", 0)
	var max_xp = new_rank_data.get("max_xp", 1000)
	var current_xp = new_rank_data.get("current_xp", min_xp)
	var xp_range = max_xp - min_xp + 1
	var xp_in_rank = current_xp - min_xp
	
	print("[RankUpNotification] Animating Progress Bar:")
	print("  Target XP in Rank: %d / %d" % [xp_in_rank, xp_range])
	print("  Target Percentage: %.1f%%" % ((float(xp_in_rank) / float(xp_range)) * 100.0))
	
	# Animate the progress bar value
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(progress_bar, "value", float(xp_in_rank), 1.2)
	
	# Update label during animation
	tween.parallel().tween_method(
		func(val: float):
			var percentage = (val / float(xp_range)) * 100.0
			progress_label.text = "Progress to next rank: %d%%" % int(percentage),
		0.0,
		float(xp_in_rank),
		1.2
	)
	
	await tween.finished
	print("[RankUpNotification] ✅ Progress bar animation complete!")

func _play_sound(player: AudioStreamPlayer) -> void:
	"""Safely play audio"""
	if player and player.stream:
		player.play()

func _pulse_close_hint() -> void:
	"""Pulse close hint"""
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(close_hint, "modulate:a", 0.3, 0.8)
	tween.tween_property(close_hint, "modulate:a", 1.0, 0.8)

func close_notification() -> void:
	"""Close notification with fade out"""
	if not can_close:
		return
	
	print("[RankUpNotification] Closing notification...")
	
	if light_rays:
		var ray_tween = create_tween()
		ray_tween.tween_property(light_rays, "modulate:a", 0.0, 0.35)
	
	if scanlines:
		var scan_tween = create_tween()
		scan_tween.tween_property(scanlines, "modulate:a", 0.0, 0.35)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	
	tween.tween_property(background, "modulate:a", 0.0, 0.45)
	tween.tween_property(panel, "modulate:a", 0.0, 0.45)
	tween.tween_property(panel, "scale", Vector2(0.6, 0.6), 0.45)
	
	await tween.finished
	notification_closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	"""Handle input to close"""
	if not can_close:
		return
	
	if event is InputEventMouseButton and event.pressed:
		close_notification()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			close_notification()
			get_viewport().set_input_as_handled()