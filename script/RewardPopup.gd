# RewardPopup.gd
extends CanvasLayer

# =============================================================================
# SIGNALS
# =============================================================================
signal rewards_claimed
signal popup_closed

# =============================================================================
# SCENE NODES
# =============================================================================
@onready var panel_container: PanelContainer = $PanelCenter/PanelContainer

# Main layout
@onready var title_label: Label = $PanelCenter/PanelContainer/MarginContainer/MainVBox/TitleLabel
@onready var chest_container: Control = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ChestArea/ChestContainer
@onready var chest_icon: TextureRect = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ChestArea/ChestContainer/ChestIcon
@onready var chest_glow: ColorRect = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ChestArea/ChestContainer/ChestGlow
@onready var burst_ring: ColorRect = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ChestArea/ChestContainer/BurstRing

# Reward overlay — direct child of CanvasLayer, NOT inside the panel VBox
@onready var reward_overlay: Control = $RewardOverlay
@onready var items_row: HBoxContainer = $RewardOverlay/OverlayCenter/OverlayVBox/ItemsRow
@onready var xp_area: VBoxContainer = $RewardOverlay/OverlayCenter/OverlayVBox/XPArea
@onready var xp_progress_bar: ProgressBar = $RewardOverlay/OverlayCenter/OverlayVBox/XPArea/XPProgressBar
@onready var xp_label: Label = $RewardOverlay/OverlayCenter/OverlayVBox/XPArea/XPLabel

# Buttons
@onready var claim_button: Button = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ButtonArea/ClaimButton
@onready var close_button: Button = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ButtonArea/CloseButton
@onready var save_status_label: Label = $PanelCenter/PanelContainer/MarginContainer/MainVBox/ButtonArea/SaveStatusLabel

# Audio
@onready var sound_panel_appear: AudioStreamPlayer = $SFX_PanelAppear
@onready var sound_chest_open: AudioStreamPlayer = $SFX_ChestOpen
@onready var sound_item_reveal: AudioStreamPlayer = $SFX_ItemReveal
@onready var sound_claim: AudioStreamPlayer = $SFX_Claim
@onready var sound_success: AudioStreamPlayer = $SFX_Success

# Confetti
@onready var confetti: CPUParticles2D = $PanelCenter/PanelContainer/Confetti

# ── Chest textures ──
const CHEST_CLOSED_PATH = "res://asset/icons/chest_closed.png"
const CHEST_OPEN_PATH   = "res://asset/icons/newopen_chest-Photoroom.png"

# ── Preload RewardItem scene ──
const REWARD_ITEM_SCENE = preload("res://scene/reward_item.tscn")

# =============================================================================
# STATE
# =============================================================================
var rewards: Array = []
var is_animating: bool = false
var is_saving: bool = false
var save_to_inventory: bool = true
var panel_style: StyleBoxFlat
var _glow_tween: Tween = null
var _chest_bob_tween: Tween = null

# Rarity system
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

# Rarity colors — still used for hover tinting in reward_item.gd
var rarity_colors = {
	Rarity.COMMON:    Color(0.7, 0.7, 0.7, 1),
	Rarity.RARE:      Color(0.2, 1.0, 0.3, 1),
	Rarity.EPIC:      Color(0.7, 0.3, 1.0, 1),
	Rarity.LEGENDARY: Color(1.0, 0.9, 0.2, 1)
}

# =============================================================================
# RARITY BORDER TEXTURES
# =============================================================================
const RARITY_BORDER_PATHS = {
	# Rarity.COMMON    -> your existing green border
	# Rarity.RARE      -> blue/cyan border PNG
	# Rarity.EPIC      -> purple/violet border PNG
	# Rarity.LEGENDARY -> gold/yellow border PNG
}

# Expand margins per rarity
const RARITY_BORDER_MARGINS = {
	0: [200.0, 60.0, 200.0, 60.0],   # COMMON
	1: [200.0, 60.0, 200.0, 60.0],   # RARE
	2: [200.0, 60.0, 200.0, 60.0],   # EPIC
	3: [200.0, 60.0, 200.0, 60.0],   # LEGENDARY
}

# Region rect per rarity
const RARITY_BORDER_REGIONS = {
	0: Rect2(0, 0, 1280, 706),   # COMMON
	1: Rect2(0, 0, 1280, 706),   # RARE
	2: Rect2(0, 0, 1280, 706),   # EPIC
	3: Rect2(0, 0, 1280, 706),   # LEGENDARY
}

# =============================================================================
# READY
# =============================================================================
func _ready() -> void:
	visible = false
	burst_ring.visible = false
	chest_glow.visible = false  # Removed: was causing cyan glow pulse
	reward_overlay.visible = false
	reward_overlay.modulate.a = 0.0

	var overlay_center: CenterContainer = $RewardOverlay/OverlayCenter
	overlay_center.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_load_all_sounds()
	panel_style = panel_container.get_theme_stylebox("panel") as StyleBoxFlat
	# _start_animated_border() — Removed: was causing cyan/purple border flash

# =============================================================================
# PUBLIC ENTRY POINT
# =============================================================================
func show_rewards(reward_list: Array, popup_title: String = "REWARD UNLOCKED!") -> void:
	if is_animating:
		return

	rewards = reward_list
	title_label.text = popup_title

	# RESET TO PHASE 1 STATE
	claim_button.disabled = false
	claim_button.text = ""
	reward_overlay.visible = false
	reward_overlay.modulate.a = 0.0
	burst_ring.visible = false
	save_status_label.visible = false

	_set_chest_texture(CHEST_CLOSED_PATH)

	if xp_progress_bar and TutorialManager:
		xp_progress_bar.max_value = 1000
		xp_progress_bar.value    = TutorialManager.total_xp
		xp_label.text            = "XP: %d / 1000" % TutorialManager.total_xp

	visible = true
	_play_sound(sound_panel_appear)
	_animate_entrance()
	_start_chest_idle_animation()

# =============================================================================
# PHASE 1 — ENTRANCE (Closed Chest)
# =============================================================================
func _animate_entrance() -> void:
	is_animating = true
	panel_container.modulate.a = 0

	var fade = create_tween()
	fade.set_trans(Tween.TRANS_CUBIC)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(panel_container, "modulate:a", 1.0, 0.4)
	await fade.finished

	is_animating = false

func _start_chest_idle_animation() -> void:
	# Only chest bob remains — cyan glow pulse removed
	if _chest_bob_tween:
		_chest_bob_tween.kill()
	_chest_bob_tween = create_tween().set_loops()
	_chest_bob_tween.set_trans(Tween.TRANS_SINE)
	_chest_bob_tween.set_ease(Tween.EASE_IN_OUT)
	_chest_bob_tween.tween_property(chest_icon, "position:y", chest_icon.position.y - 10, 1.3)
	_chest_bob_tween.tween_property(chest_icon, "position:y", chest_icon.position.y, 1.3)

	# Removed: _glow_tween cycling chest_glow alpha — was the cyan pulse

# =============================================================================
# BUTTON HANDLERS
# =============================================================================
func _on_claim_pressed() -> void:
	if is_saving or is_animating:
		return

	claim_button.disabled = true

	if _chest_bob_tween:
		_chest_bob_tween.kill()
	if _glow_tween:
		_glow_tween.kill()

	await _phase2_chest_burst()
	await _phase3_reveal_rewards()

func _on_close_pressed() -> void:
	_close_popup()

# =============================================================================
# PHASE 2 — CHEST BURST OPEN (burst ring + glow flash removed)
# =============================================================================
func _phase2_chest_burst() -> void:
	is_animating = true
	_play_sound(sound_chest_open)

	# Removed: burst_ring show/scale/fade — was the cyan ring flash
	# Removed: chest_glow alpha flash — was the cyan glow burst

	var original_pos = chest_icon.position
	var shake = create_tween()
	for i in range(8):
		var offset = 12 if i % 2 == 0 else -12
		shake.tween_property(chest_icon, "position:y", original_pos.y + offset, 0.06)
	shake.tween_property(chest_icon, "position", original_pos, 0.08)

	var burst = create_tween().set_parallel(true)
	burst.set_trans(Tween.TRANS_CUBIC)
	burst.set_ease(Tween.EASE_OUT)
	burst.tween_property(chest_icon, "scale", Vector2(1.2, 1.2), 0.25)

	await get_tree().create_timer(0.2).timeout

	_set_chest_texture(CHEST_OPEN_PATH)

	var fade = create_tween().set_parallel(true)
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_IN)
	fade.tween_property(chest_icon, "scale", Vector2.ONE, 0.4)

	await fade.finished
	is_animating = false

# =============================================================================
# PHASE 3 — REVEAL REWARD ITEMS
# =============================================================================
func _phase3_reveal_rewards() -> void:
	_play_sound(sound_item_reveal)

	if confetti:
		confetti.emitting = true

	for child in items_row.get_children():
		child.queue_free()

	for reward in rewards:
		_create_reward_item_card(reward)

	# Stay hidden at zero alpha until tween fires — prevents background bleed
	reward_overlay.modulate.a = 0.0
	reward_overlay.visible = false
	await get_tree().create_timer(0.05).timeout
	reward_overlay.visible = true

	var fade = create_tween()
	fade.set_trans(Tween.TRANS_CUBIC)
	fade.set_ease(Tween.EASE_OUT)
	fade.tween_property(reward_overlay, "modulate:a", 1.0, 0.5)
	await fade.finished

	for reward in rewards:
		if reward.type == "xp" and reward.amount > 0:
			await _animate_xp_increment(reward.amount)

	await get_tree().create_timer(0.5).timeout
	claim_button.text     = ""
	claim_button.disabled = false
	_play_sound(sound_success)

	var pulse = create_tween()
	pulse.tween_property(claim_button, "scale", Vector2(1.08, 1.08), 0.2)
	pulse.tween_property(claim_button, "scale", Vector2.ONE,         0.2)

	if not claim_button.pressed.is_connected(_on_claim_all_pressed):
		claim_button.pressed.connect(_on_claim_all_pressed, CONNECT_ONE_SHOT)

# =============================================================================
# CREATE REWARD ITEM CARD
# =============================================================================
func _create_reward_item_card(reward: RewardItem) -> void:
	var card = REWARD_ITEM_SCENE.instantiate()

	var rarity       = _get_reward_rarity(reward)
	var rarity_color = rarity_colors[rarity]

	# Pass rarity color to the card script for hover tinting
	card.rarity_color = rarity_color

	# ── Rarity border: swap the Panel's StyleBox to a texture PNG ──
	var panel_node = card.get_node("Panel")
	var rarity_tex = _get_rarity_border_texture(rarity)

	if rarity_tex:
		var tex_style          = StyleBoxTexture.new()
		tex_style.texture      = rarity_tex

		var margins = RARITY_BORDER_MARGINS.get(rarity, [200.0, 60.0, 200.0, 60.0])
		tex_style.expand_margin_left   = margins[0]
		tex_style.expand_margin_top    = margins[1]
		tex_style.expand_margin_right  = margins[2]
		tex_style.expand_margin_bottom = margins[3]

		var region = RARITY_BORDER_REGIONS.get(rarity, Rect2(0, 0, 1280, 706))
		tex_style.region_rect = region

		panel_node.add_theme_stylebox_override("panel", tex_style)
	else:
		# Fallback: no texture found — tint the existing StyleBoxFlat border color
		push_warning("[RewardPopup] No border texture found for rarity %d, falling back to color tint." % rarity)
		var card_style = panel_node.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if card_style:
			card_style.border_color = rarity_color
			card_style.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.5)
			panel_node.add_theme_stylebox_override("panel", card_style)

	var reveal_overlay = card.get_node("Panel/RevealOverlay")
	var content        = card.get_node("Panel/Content")
	var icon_rect      = content.get_node("IconRect")
	var icon_fallback  = content.get_node("IconFallback")
	var hover_vbox     = content.get_node("HoverOverlay/HoverMargin/HoverVBox")
	var name_label     = hover_vbox.get_node("NameLabel")
	var amount_label   = hover_vbox.get_node("AmountLabel")
	var desc_label     = hover_vbox.get_node("DescLabel")

	reveal_overlay.visible = false
	content.visible = true

	var icon_tex = _get_reward_icon(reward)
	if icon_tex:
		icon_rect.texture     = icon_tex
		icon_rect.visible     = true
		icon_fallback.visible = false
	else:
		icon_rect.visible     = false
		icon_fallback.visible = true
		match reward.type:
			"xp":       icon_fallback.text = "⭐"
			"badge":    icon_fallback.text = "🏆"
			"currency": icon_fallback.text = "💰"
			"item":     icon_fallback.text = "🎁"
			_:          icon_fallback.text = "✨"

	name_label.text = reward.name.to_upper()
	name_label.add_theme_color_override("font_color", Color.WHITE)

	if reward.amount > 0:
		amount_label.text    = "+%d" % reward.amount
		amount_label.visible = true
	else:
		amount_label.visible = false

	desc_label.text    = reward.description if reward.description else ""
	desc_label.visible = desc_label.text != ""

	items_row.add_child(card)

	card.modulate.a = 0.0
	var anim = create_tween()
	anim.set_trans(Tween.TRANS_CUBIC)
	anim.set_ease(Tween.EASE_OUT)
	anim.tween_property(card, "modulate:a", 1.0, 0.5)

func _get_reward_icon(reward: RewardItem) -> Texture2D:
	if reward.icon:
		return reward.icon
	var paths = {
		"xp":       "res://asset/minigamesuite/rewardxpicon.png",
		"badge":    "res://asset/icons/badge_icon.png",
		"currency": "res://asset/icons/currency_icon.png",
		"item":     "res://asset/icons/item_icon.png",
	}
	return _load_icon(paths.get(reward.type, "res://asset/icons/default_icon.png"))

# =============================================================================
# RARITY BORDER TEXTURE LOOKUP
# =============================================================================
func _get_rarity_border_texture(rarity: Rarity) -> Texture2D:
	var paths = {
		Rarity.COMMON:    "res://asset/minigamesuite/rewardcommonborder.png",
		Rarity.RARE:      "res://asset/minigamesuite/rewardrareborder.png",
		Rarity.EPIC:      "res://asset/minigamesuite/rewardepicborder.png",
		Rarity.LEGENDARY: "res://asset/minigamesuite/rewardlegendaryborder.png",
	}
	var path = paths.get(rarity, "")
	if path == "":
		return null
	return _load_icon(path)

# =============================================================================
# CLAIM ALL — save to Firestore then close
# =============================================================================
func _on_claim_all_pressed() -> void:
	if is_saving:
		return

	is_saving = true
	claim_button.disabled = true
	_play_sound(sound_claim)

	save_status_label.visible = true
	save_status_label.text    = "💾 Saving rewards to inventory..."

	await _apply_rewards()

	save_status_label.text = "✅ All rewards saved!"
	_play_sound(sound_success)

	await get_tree().create_timer(1.2).timeout

	var exit = create_tween().set_parallel(true)
	exit.set_ease(Tween.EASE_IN)
	exit.set_trans(Tween.TRANS_CUBIC)
	exit.tween_property(panel_container, "modulate:a", 0.0,        0.4)
	exit.tween_property(panel_container, "scale",      Vector2(0.9, 0.9), 0.4)
	exit.tween_property(reward_overlay,  "modulate:a", 0.0,        0.3)
	await exit.finished

	rewards_claimed.emit()
	popup_closed.emit()
	queue_free()

func _close_popup() -> void:
	var t = create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_IN)
	t.set_trans(Tween.TRANS_CUBIC)
	t.tween_property(panel_container, "modulate:a", 0.0,        0.35)
	t.tween_property(panel_container, "scale",      Vector2(0.9, 0.9), 0.35)
	t.tween_property(reward_overlay,  "modulate:a", 0.0,        0.25)
	await t.finished
	popup_closed.emit()
	queue_free()

# =============================================================================
# XP BAR ANIMATION
# =============================================================================
func _animate_xp_increment(xp_amount: int) -> void:
	if not xp_progress_bar or xp_amount <= 0:
		return

	var current_xp = int(xp_progress_bar.value)
	var new_xp     = min(current_xp + xp_amount, 1000)

	var t = create_tween()
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(xp_progress_bar, "value", new_xp, 1.0)
	t.parallel().tween_method(
		func(v): xp_label.text = "XP: %d / 1000" % int(v),
		float(current_xp),
		float(new_xp),
		1.0
	)
	await t.finished

# =============================================================================
# ANIMATED BORDER — Removed (was causing cyan/purple flashing on panel edge)
# =============================================================================
func _start_animated_border() -> void:
	pass  # Intentionally disabled

# =============================================================================
# HELPERS
# =============================================================================
func _set_chest_texture(path: String) -> void:
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex:
			chest_icon.texture = tex

func _get_reward_rarity(reward: RewardItem) -> Rarity:
	if reward.type == "badge":
		return Rarity.LEGENDARY
	elif reward.amount >= 100:
		return Rarity.EPIC
	elif reward.amount >= 50:
		return Rarity.RARE
	else:
		return Rarity.COMMON

func _screen_shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var original_offset = camera.offset
	var t = create_tween()
	for _i in range(int(duration * 60)):
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		t.tween_property(camera, "offset", original_offset + shake_offset, 0.016)
	t.tween_property(camera, "offset", original_offset, 0.1)

func _load_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			return texture
	return null

# =============================================================================
# SOUND LOADING
# =============================================================================
func _load_all_sounds() -> void:
	_load_sound(sound_panel_appear, "res://asset/audio/sfx/ui_whoosh.mp3")
	_load_sound(sound_chest_open,   "res://asset/audio/sfx/chest_open.mp3")
	_load_sound(sound_item_reveal,  "res://asset/audio/sfx/ui_pop.mp3")
	_load_sound(sound_claim,        "res://asset/audio/sfx/ui_confirm.mp3")
	_load_sound(sound_success,      "res://asset/audio/sfx/success_jingle.mp3")

	if not sound_panel_appear.stream: sound_panel_appear.stream = _generate_beep(440,  0.2)
	if not sound_chest_open.stream:   sound_chest_open.stream   = _generate_beep(880,  0.3)
	if not sound_item_reveal.stream:  sound_item_reveal.stream  = _generate_beep(1046, 0.15)
	if not sound_claim.stream:        sound_claim.stream        = _generate_beep(523,  0.25)
	if not sound_success.stream:      sound_success.stream      = _generate_beep(1200, 0.4)

func _load_sound(player: AudioStreamPlayer, path: String) -> void:
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			player.stream = stream

func _generate_beep(_frequency: float, duration: float) -> AudioStreamGenerator:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate      = 44100
	generator.buffer_length = duration
	return generator

func _play_sound(player: AudioStreamPlayer, pitch: float = 1.0) -> void:
	if player and player.stream:
		player.pitch_scale = pitch
		player.play()

# =============================================================================
# APPLY REWARDS (Firestore save)
# =============================================================================
func _apply_rewards() -> void:
	print("\n========== APPLYING REWARDS ==========")
	var total_to_save := 0
	var saved         := 0

	for reward in rewards:
		if save_to_inventory and reward.type in ["badge", "item", "card", "avatar", "powerup"]:
			total_to_save += 1

	for reward in rewards:
		match reward.type:
			"xp":
				if TutorialManager:
					TutorialManager.add_xp(reward.amount, reward.name)
			"badge", "item", "card", "avatar", "powerup":
				if save_to_inventory:
					saved += 1
					if save_status_label:
						save_status_label.text = "💾 Saving %s (%d/%d)..." % [reward.name, saved, total_to_save]
					var success := await _save_reward_to_inventory_async(reward, reward.type)
					if not success:
						push_error("[RewardPopup] ❌ Failed to save %s" % reward.type)
			"currency":
				pass
			_:
				print("[RewardPopup] ⚠️ Unknown reward type: %s" % reward.type)

# =============================================================================
# STATIC HELPER METHODS
# =============================================================================
static func show_xp_reward(parent: Node, xp_amount: int, title: String = "REWARD UNLOCKED!") -> void:
	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	parent.add_child(popup)
	popup.show_rewards([RewardItem.new("xp", xp_amount, "Experience Points", null, "Level up!")], title)

static func show_multiple_rewards(parent: Node, reward_data: Array, title: String = "REWARD UNLOCKED!") -> void:
	var popup = preload("res://scene/reward_popup.tscn").instantiate()
	parent.add_child(popup)
	var reward_list: Array = []
	for data in reward_data:
		reward_list.append(RewardItem.new(
			data.get("type", "xp"),
			data.get("amount", 0),
			data.get("name", "Reward"),
			data.get("icon", null),
			data.get("description", "")
		))
	popup.show_rewards(reward_list, title)

# =============================================================================
# FIRESTORE SAVE
# =============================================================================
func _save_reward_to_inventory_async(reward: RewardItem, item_type: String) -> bool:
	var user_id  = Auth.current_local_id
	var id_token = Auth.current_id_token

	if user_id == "" or id_token == "":
		push_error("[RewardPopup] ❌ User not logged in")
		return false

	var timestamp = int(Time.get_unix_time_from_system())
	var item_id   = "%d_%s_%d" % [timestamp, item_type, randi() % 10000]

	var rarity_val = _get_reward_rarity(reward)
	var rarity_str = ""
	match rarity_val:
		Rarity.COMMON:    rarity_str = "common"
		Rarity.RARE:      rarity_str = "rare"
		Rarity.EPIC:      rarity_str = "epic"
		Rarity.LEGENDARY: rarity_str = "legendary"

	var icon_path = ""
	if reward.icon and reward.icon.resource_path:
		icon_path = reward.icon.resource_path
	else:
		icon_path = "res://asset/icons/%s_icon.png" % item_type

	var url = "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents/users/%s/inventory/%s" % [user_id, item_id]

	var body = {
		"fields": {
			"name":          {"stringValue":  reward.name},
			"type":          {"stringValue":  item_type},
			"rarity":        {"stringValue":  rarity_str},
			"description":   {"stringValue":  reward.description},
			"icon_path":     {"stringValue":  icon_path},
			"amount":        {"integerValue": str(reward.amount)},
			"date_acquired": {"integerValue": str(timestamp)},
			"is_equipped":   {"booleanValue": false},
			"is_used":       {"booleanValue": false}
		}
	}

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % id_token
	]

	var http = HTTPRequest.new()
	get_tree().root.add_child(http)

	var err = http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body))
	if err != OK:
		push_error("[RewardPopup] ❌ HTTP request failed: %d" % err)
		http.queue_free()
		return false

	var response      = await http.request_completed
	var response_code = response[1]
	var response_body = response[3]

	http.queue_free()

	if response_code == 200:
		return true

	push_error("[RewardPopup] ❌ Save failed (Code %d): %s" % [
		response_code,
		response_body.get_string_from_utf8() if response_body.size() > 0 else "no body"
	])
	return false
