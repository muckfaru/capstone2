#RewardPopup.gd

extends CanvasLayer  # ✅ Changed from CanvasLayer to Control

# === Signals ===
signal rewards_claimed
signal popup_closed

# === UI References ===
var panel_container: PanelContainer
var title_label: Label
var reward_grid: GridContainer
var claim_button: Button
var particle_system: CPUParticles2D
var glow_rect: ColorRect
var xp_progress_bar: ProgressBar
var xp_label: Label
var instruction_label: Label
var sound_panel_appear: AudioStreamPlayer
var sound_item_pop: AudioStreamPlayer
var sound_item_bounce: AudioStreamPlayer
var sound_claim: AudioStreamPlayer
var sound_item_fly: AudioStreamPlayer
var sound_success: AudioStreamPlayer
var sound_reveal: AudioStreamPlayer
var save_status_label: Label = null
var is_saving: bool = false

var save_to_inventory: bool = true
# === Animation State ===
var rewards: Array = []
var is_animating: bool = false
var revealed_rewards: int = 0

# Store the panel style for border animation
var panel_style: StyleBoxFlat

# === Rarity System ===
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
var rarity_colors = {
	Rarity.COMMON: Color(0.7, 0.7, 0.7, 1),      # Gray
	Rarity.RARE: Color(0.2, 0.6, 1, 1),          # Blue
	Rarity.EPIC: Color(0.7, 0.2, 1, 1),          # Purple
	Rarity.LEGENDARY: Color(1, 0.84, 0, 1)       # Gold
}

func _ready() -> void:
	# ✅ Removed layer = 99 (Control nodes don't have layer property)
	_build_ui()
	_setup_sounds()

# === Sound Setup ===
func _setup_sounds() -> void:
	sound_panel_appear = AudioStreamPlayer.new()
	sound_panel_appear.volume_db = -5
	sound_panel_appear.bus = "Master"
	add_child(sound_panel_appear)
	
	sound_item_pop = AudioStreamPlayer.new()
	sound_item_pop.volume_db = -10
	sound_item_pop.bus = "Master"
	add_child(sound_item_pop)
	
	sound_item_bounce = AudioStreamPlayer.new()
	sound_item_bounce.volume_db = -15
	sound_item_bounce.bus = "Master"
	add_child(sound_item_bounce)
	
	sound_claim = AudioStreamPlayer.new()
	sound_claim.volume_db = 0
	sound_claim.bus = "Master"
	add_child(sound_claim)
	
	sound_item_fly = AudioStreamPlayer.new()
	sound_item_fly.volume_db = -8
	sound_item_fly.bus = "Master"
	add_child(sound_item_fly)
	
	sound_success = AudioStreamPlayer.new()
	sound_success.volume_db = -3
	sound_success.bus = "Master"
	add_child(sound_success)
	
	sound_reveal = AudioStreamPlayer.new()
	sound_reveal.volume_db = -8
	sound_reveal.bus = "Master"
	add_child(sound_reveal)
	
	_load_sound(sound_panel_appear, "res://asset/audio/sfx/ui_whoosh.mp3")
	_load_sound(sound_item_pop, "res://asset/audio/sfx/ui_pop.mp3")
	_load_sound(sound_item_bounce, "res://asset/audio/sfx/ui_bounce.mp3")
	_load_sound(sound_claim, "res://asset/audio/sfx/ui_confirm.mp3")
	_load_sound(sound_item_fly, "res://asset/audio/sfx/ui_swoosh.mp3")
	_load_sound(sound_success, "res://asset/audio/sfx/success_jingle.mp3")
	_load_sound(sound_reveal, "res://asset/audio/sfx/ui_pop.mp3")
	
	if not sound_panel_appear.stream:
		sound_panel_appear.stream = _generate_beep(440, 0.2)
	if not sound_item_pop.stream:
		sound_item_pop.stream = _generate_beep(880, 0.1)
	if not sound_item_bounce.stream:
		sound_item_bounce.stream = _generate_beep(660, 0.08)
	if not sound_claim.stream:
		sound_claim.stream = _generate_beep(523, 0.3)
	if not sound_item_fly.stream:
		sound_item_fly.stream = _generate_beep(740, 0.15)
	if not sound_success.stream:
		sound_success.stream = _generate_beep(1046, 0.4)
	if not sound_reveal.stream:
		sound_reveal.stream = _generate_beep(1200, 0.12)

func _load_sound(player: AudioStreamPlayer, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			player.stream = stream
			print("[RewardPopup] ✅ Loaded: %s" % path)
		else:
			push_warning("[RewardPopup] ⚠️ Failed to load: %s" % path)
	else:
		push_warning("[RewardPopup] ⚠️ File not found: %s" % path)

func _generate_beep(frequency: float, duration: float) -> AudioStreamGenerator:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = duration
	return generator

func _play_sound(player: AudioStreamPlayer, pitch: float = 1.0) -> void:
	if player and player.stream:
		player.pitch_scale = pitch
		player.play()
	else:
		push_warning("[RewardPopup] ⚠️ Cannot play sound - no stream")

func _load_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			print("[RewardPopup] ✅ Loaded icon: %s" % path)
			return texture
		else:
			push_warning("[RewardPopup] ⚠️ Failed to load icon: %s" % path)
	else:
		push_warning("[RewardPopup] ⚠️ Icon not found: %s" % path)
	return null

# ✅ Screen Shake Effect
func _screen_shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		var shake_tween = create_tween()
		var steps = int(duration * 60)  # 60 FPS
		
		for i in range(steps):
			var shake_offset = Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			shake_tween.tween_property(camera, "offset", original_offset + shake_offset, 0.016)
		
		shake_tween.tween_property(camera, "offset", original_offset, 0.1)

# ✅ Get rarity based on reward amount/type
func _get_reward_rarity(reward: RewardItem) -> Rarity:
	if reward.type == "badge":
		return Rarity.LEGENDARY
	elif reward.amount >= 100:
		return Rarity.EPIC
	elif reward.amount >= 50:
		return Rarity.RARE
	else:
		return Rarity.COMMON

func show_rewards(reward_list: Array, popup_title: String = "🎉 Rewards!") -> void:
	if is_animating:
		return
	
	rewards = reward_list
	revealed_rewards = 0
	title_label.text = popup_title
	
	for child in reward_grid.get_children():
		child.queue_free()
	
	# ✅ FIX: Only initialize progress bar, don't animate yet
	if xp_progress_bar:
		var current_xp = TutorialManager.total_xp
		var max_xp = 1000
		
		xp_progress_bar.max_value = max_xp
		xp_progress_bar.value = current_xp
		xp_label.text = "XP: %d / %d" % [current_xp, max_xp]
	
	# Create reward items (with "?" overlay)
	for reward in rewards:
		_create_reward_item(reward)
	
	visible = true
	_animate_entrance()

func _build_ui() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(650, 520)  # ✅ Increased from 500 to 520 for better spacing
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.position = Vector2(-325, -260)  # ✅ Adjusted position for new height
	
	# ✅ NEW DESIGN: Cyan/Turquoise background with rounded corners
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.7, 0.85, 1)  # Cyan/Turquoise color
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.0, 0.2, 0.5, 1)  # ✅ Dark blue border
	panel_style.corner_radius_top_left = 25
	panel_style.corner_radius_top_right = 25
	panel_style.corner_radius_bottom_left = 25
	panel_style.corner_radius_bottom_right = 25
	panel_style.shadow_color = Color(0.0, 0.2, 0.5, 0.6)  # ✅ Dark blue shadow with stronger opacity
	panel_style.shadow_size = 25  # ✅ Increased shadow size for more glow
	panel_container.add_theme_stylebox_override("panel", panel_style)
	add_child(panel_container)
	
	# ✅ Keep animated border but with cyan colors
	_start_animated_border()
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel_container.add_child(vbox)
	
	# Remove glow rect (not in new design)
	# glow_rect removed
	
	# ✅ NEW: Title with black text and top border accent
	var title_container = PanelContainer.new()
	title_container.custom_minimum_size = Vector2(650, 60)
	
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.15, 0.55, 0.7, 1)  # Darker cyan
	title_style.border_width_bottom = 3
	title_style.border_color = Color(1, 1, 1, 0.3)
	title_style.corner_radius_top_left = 22
	title_style.corner_radius_top_right = 22
	title_container.add_theme_stylebox_override("panel", title_style)
	vbox.add_child(title_container)
	
	title_label = Label.new()
	title_label.text = "NEW USER BONUS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))  # Black text
	title_container.add_child(title_label)
	
	# ✅ NEW: Remove subtitle (not in design)
	# subtitle removed
	
	# ✅ XP Progress Bar (keep same position)
	var progress_container = MarginContainer.new()
	progress_container.add_theme_constant_override("margin_left", 50)
	progress_container.add_theme_constant_override("margin_right", 50)
	progress_container.add_theme_constant_override("margin_top", 10)
	progress_container.add_theme_constant_override("margin_bottom", 5)
	vbox.add_child(progress_container)
	
	var progress_vbox = VBoxContainer.new()
	progress_vbox.add_theme_constant_override("separation", 5)
	progress_container.add_child(progress_vbox)
	
	xp_label = Label.new()
	xp_label.text = "xp 0/1000"
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))  # White text
	progress_vbox.add_child(xp_label)
	
	xp_progress_bar = ProgressBar.new()
	xp_progress_bar.custom_minimum_size = Vector2(550, 25)
	xp_progress_bar.max_value = 1000
	xp_progress_bar.value = 0
	xp_progress_bar.show_percentage = false
	
	# ✅ NEW: Orange/Yellow progress bar
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.15, 0.55, 0.7, 0.5)  # Darker cyan background
	progress_style.corner_radius_top_left = 8
	progress_style.corner_radius_top_right = 8
	progress_style.corner_radius_bottom_left = 8
	progress_style.corner_radius_bottom_right = 8
	
	var progress_fill = StyleBoxFlat.new()
	progress_fill.bg_color = Color(1, 0.7, 0, 1)  # Orange/Yellow fill
	progress_fill.corner_radius_top_left = 8
	progress_fill.corner_radius_top_right = 8
	progress_fill.corner_radius_bottom_left = 8
	progress_fill.corner_radius_bottom_right = 8
	
	xp_progress_bar.add_theme_stylebox_override("background", progress_style)
	xp_progress_bar.add_theme_stylebox_override("fill", progress_fill)
	progress_vbox.add_child(xp_progress_bar)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)  # ✅ Increased spacing
	vbox.add_child(spacer1)
	
	var center_container = CenterContainer.new()
	center_container.custom_minimum_size = Vector2(0, 180)  # ✅ Reduced from 200 to 180
	vbox.add_child(center_container)
	
	reward_grid = GridContainer.new()
	reward_grid.columns = 2
	reward_grid.add_theme_constant_override("h_separation", 20)
	reward_grid.add_theme_constant_override("v_separation", 15)
	center_container.add_child(reward_grid)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)  # ✅ Increased spacing
	vbox.add_child(spacer2)
	
	# ✅ NEW: "Click to reveal your reward" label
	instruction_label = Label.new()
	instruction_label.text = "Click to reveal your reward"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 16)
	instruction_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vbox.add_child(instruction_label)
	
	save_status_label = Label.new()
	save_status_label.text = "💾 Saving rewards..."
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_status_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	save_status_label.add_theme_font_size_override("font_size", 14)
	save_status_label.visible = false
	vbox.add_child(save_status_label)



	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)  # ✅ Increased spacing before button
	vbox.add_child(spacer3)
	
	claim_button = Button.new()
	claim_button.text = " Claim All Rewards "
	claim_button.custom_minimum_size = Vector2(300, 50)
	claim_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	claim_button.disabled = true  # Disabled until all revealed
	
	# ✅ Updated button colors to match dark blue theme
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.0, 0.4, 0.7, 0.9)  # Dark blue
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(0.0, 0.3, 0.6, 1)  # Darker blue border
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.0, 0.5, 0.8, 1)  # Lighter blue on hover
	btn_hover.shadow_color = Color(0.0, 0.3, 0.7, 0.5)  # Dark blue glow
	btn_hover.shadow_size = 12
	
	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.3, 0.3, 0.4, 0.5)
	btn_disabled.border_color = Color(0.5, 0.5, 0.5, 0.5)
	
	claim_button.add_theme_stylebox_override("normal", btn_normal)
	claim_button.add_theme_stylebox_override("hover", btn_hover)
	claim_button.add_theme_stylebox_override("pressed", btn_hover)
	claim_button.add_theme_stylebox_override("disabled", btn_disabled)
	claim_button.add_theme_font_size_override("font_size", 18)
	claim_button.add_theme_color_override("font_color", Color.WHITE)
	
	claim_button.pressed.connect(_on_claim_pressed)
	vbox.add_child(claim_button)
	
	# ✅ Add bottom padding
	var spacer_bottom = Control.new()
	spacer_bottom.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer_bottom)
	
	# Multiple colored particle systems (confetti)
	_create_confetti_particles()
	
	visible = false

# ✅ Create colorful confetti particles
func _create_confetti_particles() -> void:
	var confetti_colors = [
		Color(1, 0, 0, 1),     # Red
		Color(0, 1, 0, 1),     # Green
		Color(0, 0.5, 1, 1),   # Blue
		Color(1, 0.84, 0, 1),  # Gold
		Color(1, 0, 1, 1),     # Magenta
	]
	
	for i in range(3):  # Create 3 particle systems for better effect
		var particles = CPUParticles2D.new()
		particles.position = Vector2(325, 50) + Vector2(randf_range(-50, 50), 0)
		particles.amount = 40
		particles.lifetime = 2.5
		particles.explosiveness = 0.9
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 30
		particles.direction = Vector2(0, -1)
		particles.spread = 60
		particles.gravity = Vector2(0, 250)
		particles.initial_velocity_min = 150
		particles.initial_velocity_max = 300
		particles.scale_amount_min = 3
		particles.scale_amount_max = 6
		particles.color = confetti_colors[i % confetti_colors.size()]
		particles.emitting = false
		panel_container.add_child(particles)
		
		if i == 0:
			particle_system = particles  # Store first one for main reference

# ✅ IMPROVED: Create reward item with rarity and click-to-reveal
func _create_reward_item(reward: RewardItem) -> void:
	var item_panel = PanelContainer.new()
	item_panel.custom_minimum_size = Vector2(280, 110)
	item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var rarity = _get_reward_rarity(reward)
	var rarity_color = rarity_colors[rarity]
	
	var item_style = StyleBoxFlat.new()
	item_style.bg_color = Color(0.1, 0.15, 0.2, 0.8)
	item_style.border_width_left = 3
	item_style.border_width_top = 3
	item_style.border_width_right = 3
	item_style.border_width_bottom = 3
	item_style.border_color = rarity_color
	item_style.corner_radius_top_left = 6
	item_style.corner_radius_top_right = 6
	item_style.corner_radius_bottom_left = 6
	item_style.corner_radius_bottom_right = 6
	item_style.shadow_color = rarity_color * Color(1, 1, 1, 0.6)
	item_style.shadow_size = 8
	item_panel.add_theme_stylebox_override("panel", item_style)
	
	# ✅ Click-to-reveal overlay
	var reveal_overlay = ColorRect.new()
	reveal_overlay.color = Color(0.1, 0.1, 0.15, 0.95)
	reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	reveal_overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # Show hand cursor
	reveal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_panel.add_child(reveal_overlay)
	
	# ✅ Load chest icon instead of "?"
	var chest_texture = _load_icon("res://asset/icons/chest_icon.png")
	
	if chest_texture:
		# Use chest image
		var chest_rect = TextureRect.new()
		chest_rect.texture = chest_texture
		chest_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		chest_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# Add margin to center the icon better
		var chest_margin = MarginContainer.new()
		chest_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		chest_margin.add_theme_constant_override("margin_left", 30)
		chest_margin.add_theme_constant_override("margin_right", 30)
		chest_margin.add_theme_constant_override("margin_top", 30)
		chest_margin.add_theme_constant_override("margin_bottom", 30)
		chest_margin.add_child(chest_rect)
		reveal_overlay.add_child(chest_margin)
		
		# Add glow effect to chest
		var glow_tween = create_tween().set_loops()
		glow_tween.tween_property(chest_rect, "modulate", Color(1, 1, 1, 0.7), 0.8)
		glow_tween.tween_property(chest_rect, "modulate", Color(1, 1, 1, 1), 0.8)
	else:
		# Fallback to "?" if chest icon not found
		var reveal_icon = Label.new()
		reveal_icon.text = "?"
		reveal_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reveal_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		reveal_icon.add_theme_font_size_override("font_size", 72)
		reveal_icon.add_theme_color_override("font_color", rarity_color)
		reveal_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		reveal_overlay.add_child(reveal_icon)
	
	# Content container (hidden initially)
	var content_container = Control.new()
	content_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.visible = false
	item_panel.add_child(content_container)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	content_container.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	
	# Icon
	var icon_texture: Texture2D = null
	
	if reward.icon:
		icon_texture = reward.icon
	else:
		match reward.type:
			"xp":
				icon_texture = _load_icon("res://asset/icons/xp icon.png")
			"badge":
				icon_texture = _load_icon("res://asset/icons/badge_icon.png")
			"currency":
				icon_texture = _load_icon("res://asset/icons/currency_icon.png")
			"item":
				icon_texture = _load_icon("res://asset/icons/item_icon.png")
			_:
				icon_texture = _load_icon("res://asset/icons/default_icon.png")
	
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(50, 50)
	
	if icon_texture:
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.custom_minimum_size = Vector2(50, 50)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(icon_rect)
	else:
		var icon_label = Label.new()
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 32)
		
		match reward.type:
			"xp":
				icon_label.text = "⭐"
			"badge":
				icon_label.text = "🏆"
			"currency":
				icon_label.text = "💰"
			"item":
				icon_label.text = "🎁"
			_:
				icon_label.text = "✨"
		
		icon_container.add_child(icon_label)
	
	hbox.add_child(icon_container)
	
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(text_vbox)
	
	var name_label = Label.new()
	name_label.text = reward.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", rarity_color)
	text_vbox.add_child(name_label)
	
	var amount_label = Label.new()
	if reward.amount > 0:
		amount_label.text = "+%d" % reward.amount
		amount_label.add_theme_font_size_override("font_size", 20)
		amount_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2, 1))
	else:
		amount_label.text = "Unlocked!"
		amount_label.add_theme_font_size_override("font_size", 14)
		amount_label.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	text_vbox.add_child(amount_label)
	
	if reward.description != "":
		var desc_label = Label.new()
		desc_label.text = reward.description
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size.x = 180
		text_vbox.add_child(desc_label)
	
	reward_grid.add_child(item_panel)
	
	item_panel.modulate.a = 0
	item_panel.position.y = 150
	item_panel.scale = Vector2(0.85, 0.85)
	
	var item_index = reward_grid.get_child_count() - 1
	var delay = item_index * 0.12
	await get_tree().create_timer(delay).timeout
	
	_play_sound(sound_item_pop, 1.0 + (item_index * 0.08))
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(item_panel, "modulate:a", 1.0, 0.5)
	tween.tween_property(item_panel, "position:y", 0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item_panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	_play_sound(sound_item_bounce, 1.2 + (item_index * 0.05))
	
	var bounce = create_tween()
	bounce.tween_property(item_panel, "scale", Vector2(1.05, 1.05), 0.15)
	bounce.tween_property(item_panel, "scale", Vector2.ONE, 0.15)
	
	# ✅ Connect click handler for reveal (on the overlay, not the panel)
	reveal_overlay.gui_input.connect(_on_reward_clicked.bind(item_panel, content_container, reveal_overlay, reward, rarity))
	
	# ✅ Enhanced hover effect with 3D hint
	reveal_overlay.mouse_entered.connect(func():
		var hover_tween = create_tween()
		hover_tween.set_parallel(true)
		hover_tween.tween_property(item_panel, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_ELASTIC)
		hover_tween.tween_property(item_style, "shadow_size", 12, 0.2)
		# Slight X-axis tilt to hint at flip
		hover_tween.tween_property(item_panel, "rotation_degrees", 3, 0.2)
	)
	
	reveal_overlay.mouse_exited.connect(func():
		var exit_tween = create_tween()
		exit_tween.set_parallel(true)
		exit_tween.tween_property(item_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)
		exit_tween.tween_property(item_style, "shadow_size", 8, 0.2)
		exit_tween.tween_property(item_panel, "rotation_degrees", 0, 0.2)
	)

# ✅ Handle reward reveal click
func _on_reward_clicked(event: InputEvent, panel: PanelContainer, content: Control, overlay: ColorRect, reward: RewardItem, rarity: Rarity) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if overlay.visible:
			_reveal_reward(panel, content, overlay, reward, rarity)

# ✅ Reveal reward with 3D card flip animation
func _reveal_reward(panel: PanelContainer, content: Control, overlay: ColorRect, reward: RewardItem, rarity: Rarity) -> void:
	revealed_rewards += 1
	
	_play_sound(sound_reveal, 1.0 + (revealed_rewards * 0.1))
	_screen_shake(5.0, 0.2)
	
	# Legendary rewards get extra effect
	if rarity == Rarity.LEGENDARY:
		_screen_shake(15.0, 0.4)
		_play_sound(sound_success)
	
	# ✅ FIX: Update XP bar immediately if this is an XP reward
	if reward.type == "xp" and reward.amount > 0:
		_animate_xp_increment(reward.amount)
	
	# ✅ 3D CARD FLIP ANIMATION
	var flip_duration := 0.6
	
	# Phase 1: Flip to 90° (hide front)
	var flip_tween1 = create_tween()
	flip_tween1.set_parallel(true)
	flip_tween1.set_ease(Tween.EASE_IN)
	flip_tween1.set_trans(Tween.TRANS_CUBIC)
	
	# Simulate 3D rotation by scaling X to 0 (looks like rotating on Y-axis)
	flip_tween1.tween_property(panel, "scale:x", 0.0, flip_duration / 2.0)
	flip_tween1.tween_property(overlay, "modulate:a", 0.0, flip_duration / 2.0)
	
	await flip_tween1.finished
	
	# Switch content at 90° (when card is edge-on)
	overlay.visible = false
	content.visible = true
	content.modulate.a = 1.0
	content.scale = Vector2.ONE
	
	# Phase 2: Flip from 90° to 0° (show back)
	var flip_tween2 = create_tween()
	flip_tween2.set_ease(Tween.EASE_OUT)
	flip_tween2.set_trans(Tween.TRANS_CUBIC)
	
	flip_tween2.tween_property(panel, "scale:x", 1.0, flip_duration / 2.0)
	
	await flip_tween2.finished
	
	# Bounce effect after flip
	var bounce_tween = create_tween()
	bounce_tween.tween_property(panel, "scale", Vector2(1.1, 1.1), 0.1)
	bounce_tween.tween_property(panel, "scale", Vector2.ONE, 0.1)

	
	if instruction_label:
		var fade_tween = create_tween()
		fade_tween.tween_property(instruction_label, "modulate:a", 0.0, 0.3)
		await fade_tween.finished
		instruction_label.visible = false


	# Check if all revealed -> enable claim button
	if revealed_rewards >= rewards.size():
		claim_button.disabled = false
		_play_sound(sound_success)
		
		# Animate button
		var button_tween = create_tween()
		button_tween.tween_property(claim_button, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_ELASTIC)
		button_tween.tween_property(claim_button, "scale", Vector2.ONE, 0.3)

# ✅ NEW: Animate XP bar increment for each XP card revealed
func _animate_xp_increment(xp_amount: int) -> void:
	if not xp_progress_bar or xp_amount <= 0:
		return
	
	var current_xp = int(xp_progress_bar.value)
	var max_xp = 1000
	var new_xp = min(current_xp + xp_amount, max_xp)
	
	# Animate the progress bar filling
	var fill_tween = create_tween()
	fill_tween.tween_property(xp_progress_bar, "value", new_xp, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fill_tween.parallel().tween_method(
		func(val): xp_label.text = "xp %d/%d" % [int(val), max_xp],  # ✅ Changed format to match design
		float(current_xp), 
		float(new_xp), 
		0.8
	)

# ✅ Animate XP bar only after all rewards revealed (REMOVED - now using instant updates)
# This function is no longer needed as we update XP immediately per card
# func _animate_xp_bar_after_reveal() -> void:
	# ... removed ...

func _animate_entrance() -> void:
	is_animating = true
	
	_play_sound(sound_panel_appear)
	_screen_shake(8.0, 0.25)
	
	panel_container.modulate.a = 0
	panel_container.scale = Vector2(0.8, 0.8)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.4)
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Removed glow pulse (not in new design)
	
	await tween.finished
	is_animating = false

# Removed _start_glow_pulse() function (not needed in new design)

func _start_animated_border() -> void:
	# ✅ Updated to use dark blue color scheme
	var border_tween = create_tween().set_loops()
	border_tween.set_ease(Tween.EASE_IN_OUT)
	border_tween.set_trans(Tween.TRANS_SINE)
	
	border_tween.tween_property(panel_style, "border_color", Color(0.0, 0.3, 0.7, 1), 1.5)  # Lighter dark blue
	border_tween.tween_property(panel_style, "border_color", Color(0.0, 0.2, 0.5, 1), 1.5)  # Darker blue
	
	var shadow_tween = create_tween().set_loops()
	shadow_tween.set_ease(Tween.EASE_IN_OUT)
	shadow_tween.set_trans(Tween.TRANS_SINE)
	
	shadow_tween.tween_property(panel_style, "shadow_color", Color(0.0, 0.3, 0.7, 0.7), 1.5)  # Lighter dark blue glow
	shadow_tween.tween_property(panel_style, "shadow_color", Color(0.0, 0.2, 0.5, 0.6), 1.5)  # Darker blue glow

func _animate_claim() -> void:
	if is_saving:
		return
	
	is_saving = true
	claim_button.disabled = true
	
	_play_sound(sound_claim)
	_screen_shake(12.0, 0.4)
	
	# Trigger confetti
	for child in panel_container.get_children():
		if child is CPUParticles2D:
			child.emitting = true
	
	# Flash effect
	var flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_container.add_child(flash_overlay)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 0.3), 0.1)
	flash_tween.tween_property(flash_overlay, "color", Color(1, 1, 1, 0), 0.3)
	
	# Animate items flying away
	var item_index = 0
	for item in reward_grid.get_children():
		if item_index < rewards.size():
			var current_reward = rewards[item_index]
			if current_reward.amount > 0:
				_create_floating_number(item, current_reward.amount, current_reward.type)
		
		if item_index == 0:
			_play_sound(sound_item_fly)
		
		var exit_tween = create_tween()
		exit_tween.set_parallel(true)
		exit_tween.set_ease(Tween.EASE_IN)
		exit_tween.set_trans(Tween.TRANS_CUBIC)
		
		exit_tween.tween_property(item, "position:y", -80, 0.6)
		exit_tween.tween_property(item, "modulate:a", 0.0, 0.6)
		exit_tween.tween_property(item, "scale", Vector2(0.7, 0.7), 0.6)
		
		item_index += 1
		await get_tree().create_timer(0.12).timeout
	
	await get_tree().create_timer(0.5).timeout
	
	# ✅ CRITICAL: Show "Saving..." and hide claim button
	claim_button.visible = false
	if instruction_label:
		instruction_label.visible = false
	if save_status_label:
		save_status_label.visible = true
		save_status_label.text = "💾 Saving rewards to inventory..."
	
	# ✅ Apply rewards and WAIT for completion
	await _apply_rewards()
	
	# ✅ Update status
	if save_status_label:
		save_status_label.text = "✅ All rewards saved!"
	
	_play_sound(sound_success)
	
	# Wait a moment to show success message
	await get_tree().create_timer(1.0).timeout
	
	# NOW close the popup
	var panel_exit = create_tween()
	panel_exit.set_parallel(true)
	panel_exit.set_ease(Tween.EASE_IN)
	panel_exit.set_trans(Tween.TRANS_CUBIC)
	
	panel_exit.tween_property(panel_container, "modulate:a", 0.0, 0.4)
	panel_exit.tween_property(panel_container, "scale", Vector2(0.9, 0.9), 0.4)
	
	await panel_exit.finished
	
	rewards_claimed.emit()
	popup_closed.emit()
	queue_free()

func _create_floating_number(parent_item: Control, amount: int, reward_type: String) -> void:
	var float_label = Label.new()
	
	var item_pos = parent_item.global_position
	var item_size = parent_item.size
	float_label.global_position = Vector2(item_pos.x + item_size.x / 2, item_pos.y + item_size.y / 2)
	
	match reward_type:
		"xp":
			float_label.text = "+%d XP" % amount
			float_label.add_theme_color_override("font_color", Color(1, 1, 0, 1))
		"currency":
			float_label.text = "+%d" % amount
			float_label.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		"badge":
			float_label.text = "✓"
			float_label.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
		_:
			float_label.text = "+%d" % amount
			float_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	
	float_label.add_theme_font_size_override("font_size", 32)
	float_label.modulate.a = 0
	float_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	float_label.add_theme_constant_override("outline_size", 3)
	
	add_child(float_label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(float_label, "modulate:a", 1.0, 0.2)
	tween.tween_property(float_label, "global_position:y", float_label.global_position.y - 100, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_label, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_property(float_label, "scale", Vector2(1.5, 1.5), 0.3)
	
	await tween.finished
	float_label.queue_free()

func _apply_rewards() -> void:
	print("\n========== APPLYING REWARDS ==========")
	print("[RewardPopup] Total rewards: %d" % rewards.size())
	
	var total_items_to_save := 0
	var items_saved := 0
	
	# Count items that need saving
	for reward in rewards:
		if save_to_inventory and reward.type in ["badge", "item", "card", "avatar", "powerup"]:
			total_items_to_save += 1
	
	print("[RewardPopup] Items to save to inventory: %d" % total_items_to_save)
	
	for i in range(rewards.size()):
		var reward = rewards[i]
		print("\n--- Reward %d/%d ---" % [i + 1, rewards.size()])
		print("Type: %s | Name: %s | Amount: %d" % [reward.type, reward.name, reward.amount])
		
		match reward.type:
			"xp":
				print("[RewardPopup] → Processing XP reward")
				if TutorialManager:
					TutorialManager.add_xp(reward.amount, reward.name)
					print("[RewardPopup] ✅ XP added")
			
			"badge", "item", "card", "avatar", "powerup":
				if save_to_inventory:
					items_saved += 1
					
					# ✅ Update status label during save
					if save_status_label:
						save_status_label.text = "💾 Saving %s (%d/%d)..." % [reward.name, items_saved, total_items_to_save]
					
					print("[RewardPopup] → Saving %s to inventory..." % reward.type)
					var success := await _save_reward_to_inventory_async(reward, reward.type)
					
					if success:
						print("[RewardPopup] ✅ %s saved!" % reward.type.capitalize())
					else:
						push_error("[RewardPopup] ❌ Failed to save %s" % reward.type)
				else:
					print("[RewardPopup] ⚠️ save_to_inventory is FALSE")
			
			"currency":
				print("[RewardPopup] → Currency reward (not saved)")
			
			_:
				print("[RewardPopup] ⚠️ Unknown type: %s" % reward.type)
	
	print("\n========== REWARDS APPLIED (%d/%d saved) ==========" % [items_saved, total_items_to_save])

func _on_claim_pressed() -> void:
	if is_saving:
		print("[RewardPopup] ⚠️ Already saving, ignoring click")
		return
	
	_animate_claim()

static func show_xp_reward(parent: Node, xp_amount: int, title: String = "🎉 Reward!") -> void:
	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	parent.add_child(popup)
	var rewards = [
		RewardItem.new("xp", xp_amount, "Experience Points", null, "Level up!")
	]
	popup.show_rewards(rewards, title)

static func show_multiple_rewards(parent: Node, reward_data: Array, title: String = "🎉 Rewards!") -> void:
	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	parent.add_child(popup)
	var rewards: Array = []
	for data in reward_data:
		rewards.append(RewardItem.new(
			data.get("type", "xp"),
			data.get("amount", 0),
			data.get("name", "Reward"),
			data.get("icon", null),
			data.get("description", "")
		))
	popup.show_rewards(rewards, title)

# ✅ NEW: Async version that waits for completion
# ✅ FIXED: Now uses integer timestamps
func _save_reward_to_inventory_async(reward: RewardItem, item_type: String) -> bool:
	"""Save a reward item and return success status"""
	print("\n========== SAVING TO FIRESTORE ==========")
	print("[RewardPopup] Item: %s | Type: %s" % [reward.name, item_type])
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	if user_id == "" or id_token == "":
		push_error("[RewardPopup] ❌ User not logged in")
		return false
	
	# ✅ FIX: Convert timestamp to integer (remove decimals)
	var timestamp = int(Time.get_unix_time_from_system())
	var random_suffix = randi() % 10000
	var item_id = "%d_%s_%d" % [timestamp, item_type, random_suffix]
	
	print("[RewardPopup] Item ID: %s" % item_id)
	
	# Determine rarity
	var rarity_value = _get_reward_rarity(reward)
	var rarity_string = ""
	match rarity_value:
		Rarity.COMMON: rarity_string = "common"
		Rarity.RARE: rarity_string = "rare"
		Rarity.EPIC: rarity_string = "epic"
		Rarity.LEGENDARY: rarity_string = "legendary"
	
	# Get icon path
	var icon_path = ""
	if reward.icon and reward.icon.resource_path:
		icon_path = reward.icon.resource_path
	else:
		icon_path = "res://asset/icons/%s_icon.png" % item_type
	
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s/inventory/%s" % [user_id, item_id]
	
	# ✅ FIX: Ensure all integer fields use str(int(...))
	var body = {
		"fields": {
			"name": {"stringValue": reward.name},
			"type": {"stringValue": item_type},
			"rarity": {"stringValue": rarity_string},
			"description": {"stringValue": reward.description},
			"icon_path": {"stringValue": icon_path},
			"amount": {"integerValue": str(reward.amount)},
			"date_acquired": {"integerValue": str(timestamp)},  # ← Now using integer!
			"is_equipped": {"booleanValue": false},
			"is_used": {"booleanValue": false}
		}
	}
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	# ✅ Create HTTPRequest as child of root, NOT RewardPopup
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	
	print("[RewardPopup] Sending HTTP request...")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	
	if err != OK:
		push_error("[RewardPopup] ❌ HTTP request failed: %s" % err)
		http.queue_free()
		return false
	
	# ✅ Wait for response
	var response = await http.request_completed
	var code = response[1]
	var response_body = response[3]
	
	print("[RewardPopup] Response code: %d" % code)
	
	# Clean up
	http.queue_free()
	
	if code == 200:
		print("[RewardPopup] ✅ SUCCESS! Item saved: %s" % reward.name)
		return true
	else:
		var error_msg = response_body.get_string_from_utf8() if response_body.size() > 0 else "No error message"
		push_error("[RewardPopup] ❌ Save failed (Code %d): %s" % [code, error_msg])
		return false

# ✅ LEGACY: Keep old function for compatibility (but not used anymore)
func _save_reward_to_inventory(reward: RewardItem, item_type: String) -> void:
	"""Save a reward item to player's inventory in Firestore with detailed logging"""
	print("\n========== SAVING REWARD TO INVENTORY ==========")
	print("[RewardPopup] 🎁 Reward Name: %s" % reward.name)
	print("[RewardPopup] 🎁 Reward Type: %s" % item_type)
	print("[RewardPopup] 🎁 Reward Amount: %d" % reward.amount)
	
	var user_id = Auth.current_local_id
	var id_token = Auth.current_id_token
	
	print("[RewardPopup] 🔑 User ID: %s" % user_id)
	print("[RewardPopup] 🔑 Has Token: %s" % (id_token != ""))
	
	if user_id == "" or id_token == "":
		push_error("[RewardPopup] ❌ CRITICAL: User not logged in - cannot save to inventory")
		return
	
	# Generate unique item ID (timestamp + random)
	var timestamp = Time.get_unix_time_from_system()
	var random_suffix = randi() % 10000
	var item_id = "%d_%s_%d" % [timestamp, item_type, random_suffix]
	
	print("[RewardPopup] 🆔 Generated Item ID: %s" % item_id)
	
	# Determine rarity
	var rarity_value = _get_reward_rarity(reward)
	var rarity_string = ""
	match rarity_value:
		Rarity.COMMON: rarity_string = "common"
		Rarity.RARE: rarity_string = "rare"
		Rarity.EPIC: rarity_string = "epic"
		Rarity.LEGENDARY: rarity_string = "legendary"
	
	print("[RewardPopup] ⭐ Rarity: %s" % rarity_string)
	
	# Get icon path if available
	var icon_path = ""
	if reward.icon and reward.icon.resource_path:
		icon_path = reward.icon.resource_path
	else:
		# Use default icon based on type
		icon_path = "res://asset/icons/%s_icon.png" % item_type
	
	print("[RewardPopup] 🖼️ Icon Path: %s" % icon_path)
	
	# ✅ Firestore URL - will auto-create "inventory" subcollection
	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s/inventory/%s" % [user_id, item_id]
	
	print("[RewardPopup] 🌐 Firestore URL: %s" % url)
	
	# Build Firestore document
	var body = {
		"fields": {
			"name": {"stringValue": reward.name},
			"type": {"stringValue": item_type},
			"rarity": {"stringValue": rarity_string},
			"description": {"stringValue": reward.description},
			"icon_path": {"stringValue": icon_path},
			"amount": {"integerValue": str(reward.amount)},
			"date_acquired": {"integerValue": str(timestamp)},
			"is_equipped": {"booleanValue": false},
			"is_used": {"booleanValue": false}
		}
	}
	
	print("[RewardPopup] 📦 Request Body: %s" % JSON.stringify(body))
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(_r, code, _h, response_body):
		print("\n========== FIRESTORE RESPONSE ==========")
		print("[RewardPopup] 📥 Response Code: %d" % code)
		
		http.queue_free()
		
		if code == 200:
			print("[RewardPopup] ✅✅✅ SUCCESS! Item saved to inventory!")
			print("[RewardPopup] ✅ Saved: %s (%s)" % [reward.name, item_type])
			print("[RewardPopup] ✅ Item ID: %s" % item_id)
		elif code == 403:
			print("[RewardPopup] ❌ 403 PERMISSION DENIED!")
			print("[RewardPopup] ❌ Check Firestore Security Rules!")
			var error_msg = response_body.get_string_from_utf8() if response_body.size() > 0 else "No error message"
			print("[RewardPopup] ❌ Error Details: %s" % error_msg)
		else:
			var error_msg = response_body.get_string_from_utf8() if response_body.size() > 0 else "Unknown error"
			push_error("[RewardPopup] ❌ Failed to save to inventory (Code %d): %s" % [code, error_msg])
			print("[RewardPopup] ❌ Full Response: %s" % error_msg)
		
		print("========================================\n")
	)
	
	print("[RewardPopup] 📤 Sending HTTP request...")
	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	
	if err != OK:
		push_error("[RewardPopup] ❌ HTTP REQUEST FAILED TO START: %s" % err)
		http.queue_free()
	else:
		print("[RewardPopup] ✅ HTTP request sent successfully, waiting for response...")
