extends CanvasLayer

# ============================================
# RANK UP NOTIFICATION  -  3-Phase League-style UI
# Phase 1 : Show OLD rank card  (bar fills to 98/100)
# Phase 2 : RANK UP! banner slams in + confetti
# Phase 3 : Card swaps to NEW rank  (bar resets to 0/100)
# ============================================

signal notification_closed

# ── Scene nodes ───────────────────────────────────────────────────────────
@onready var background: ColorRect        = $Background
@onready var screen_flash: ColorRect      = $ScreenFlash

# Rank icon - free node, no container parent
@onready var rank_icon: TextureRect       = $RankIcon
@onready var icon_glow: ColorRect         = $IconGlow

# Card (Phase 1 & 3)
@onready var card: Panel                  = $CardCenter/Card
@onready var rank_name_label: Label       = $CardCenter/Card/ContentMargin/ContentVBox/RankNameLabel
@onready var progress_bar: ProgressBar    = $CardCenter/Card/ContentMargin/ContentVBox/ProgressBar
@onready var lp_label: Label              = $CardCenter/Card/ContentMargin/ContentVBox/LPLabel
@onready var close_hint: Label            = $CardCenter/Card/ContentMargin/ContentVBox/CloseHint
@onready var scanlines: Node2D            = $CardCenter/Card/Scanlines

# RANK UP! Banner (Phase 2)
@onready var banner_center: CenterContainer = $BannerCenter
@onready var banner: Panel                  = $BannerCenter/Banner
@onready var rank_up_label: Label           = $BannerCenter/Banner/RankUpLabel
@onready var old_rank_ghost: Label          = $BannerCenter/Banner/OldRankGhost

# Confetti
@onready var confetti: CPUParticles2D     = $ConfettiParticles
@onready var confetti_side: CPUParticles2D = $ConfettiSide

# Audio
@onready var sfx_rank_up: AudioStreamPlayer   = $SFX_RankUp
@onready var sfx_coin_flip: AudioStreamPlayer = $SFX_CoinFlip
@onready var sfx_particles: AudioStreamPlayer = $SFX_Particles
@onready var sfx_reveal: AudioStreamPlayer    = $SFX_Reveal

# ── State ─────────────────────────────────────────────────────────────────
var can_close: bool = false
var old_rank_data: Dictionary
var new_rank_data: Dictionary
var card_style: StyleBoxFlat
var custom_font: FontFile


func _ready() -> void:
	layer = 100
	background.modulate.a = 0
	card.modulate.a = 0
	icon_glow.modulate.a = 0
	rank_icon.modulate.a = 0
	banner_center.modulate.a = 0
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	scanlines.modulate.a = 0
	confetti.emitting = false
	confetti_side.emitting = false

	_load_custom_font()
	_setup_sound_effects()

	# Cache the card stylebox so we can animate border color
	card_style = card.get_theme_stylebox("panel") as StyleBoxFlat

	set_process_input(true)


# ─────────────────────────────────────────────────────────────────────────────
# FONT
# ─────────────────────────────────────────────────────────────────────────────
func _load_custom_font() -> void:
	var paths = [
		"res://asset/fonts/NicoMoji-Regular.ttf",
		"res://assets/fonts/NicoMoji-Regular.ttf",
		"res://fonts/NicoMoji-Regular.ttf"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			custom_font = load(p)
			if custom_font:
				_apply_font_to_all()
				return


func _apply_font_to_all() -> void:
	if not custom_font:
		return
	for lbl in [rank_name_label, lp_label, close_hint, rank_up_label, old_rank_ghost]:
		if lbl:
			lbl.add_theme_font_override("font", custom_font)


func _apply_font(lbl: Label, size: int) -> void:
	if custom_font:
		lbl.add_theme_font_override("font", custom_font)
	lbl.add_theme_font_size_override("font_size", size)


# ─────────────────────────────────────────────────────────────────────────────
# SOUND
# ─────────────────────────────────────────────────────────────────────────────
func _setup_sound_effects() -> void:
	_try_load_sound(sfx_rank_up,   "res://asset/audio/sfx/rank_up.mp3",         -3.0)
	_try_load_sound(sfx_coin_flip, "res://asset/audio/sfx/coin_flip.mp3",       -5.0)
	_try_load_sound(sfx_particles, "res://asset/audio/sfx/particles_burst.mp3", -8.0)
	_try_load_sound(sfx_reveal,    "res://asset/audio/sfx/reveal.mp3",          -6.0)


func _try_load_sound(player: AudioStreamPlayer, path: String, vol: float) -> void:
	player.volume_db = vol
	if ResourceLoader.exists(path):
		var s = load(path)
		if s:
			player.stream = s


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


# ─────────────────────────────────────────────────────────────────────────────
# MAIN ENTRY  — called from mode_selection.gd / wherever rank-up fires
# ─────────────────────────────────────────────────────────────────────────────
func show_rank_up(old_rank: Dictionary, new_rank: Dictionary, _xp_progress: float = 0.0) -> void:
	print("[RankUp] %s → %s" % [old_rank["name"], new_rank["name"]])
	old_rank_data = old_rank
	new_rank_data = new_rank

	await get_tree().process_frame

	# ── Build old-rank LP values ──────────────────────────────────────────
	var old_min  = old_rank.get("min_xp", 0)
	var old_max  = old_rank.get("max_xp", 100)
	var cur_xp   = old_rank.get("current_xp", old_min)
	var lp_range = float(old_max - old_min + 1)
	var lp_now   = float(cur_xp - old_min)
	var lp_max   = int(lp_range)

	# ── Populate card with OLD rank ───────────────────────────────────────
	rank_name_label.text = old_rank["name"]
	_tint_rank_name(old_rank)
	progress_bar.max_value = lp_range
	progress_bar.value = 0
	lp_label.text = "0 / %d XP" % lp_max
	old_rank_ghost.text = old_rank["name"]

	# Set old rank icon
	if old_rank.has("icon"):
		var tex = load(old_rank["icon"])
		if tex:
			rank_icon.texture = tex

	# ─── PHASE 1 : Reveal card ───────────────────────────────────────────
	await _phase1_reveal_card(lp_now, lp_max, lp_range)

	# Brief pause at full bar
	await get_tree().create_timer(0.5).timeout

	# ─── PHASE 2 : RANK UP! banner ───────────────────────────────────────
	await _phase2_rank_up_banner()

	# ─── PHASE 3 : Show new rank ─────────────────────────────────────────
	await _phase3_new_rank()

	# Enable close
	await get_tree().create_timer(1.0).timeout
	can_close = true
	close_hint.visible = true
	_pulse_close_hint()


# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1  –  Card slides in, bar fills to current LP
# ─────────────────────────────────────────────────────────────────────────────
func _phase1_reveal_card(lp_now: float, lp_max: int, lp_range: float) -> void:
	# Slide card in from below
	var card_center = $CardCenter
	card_center.position.y = 80
	card.modulate.a = 0

	var t = create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(background, "modulate:a", 1.0, 0.4)
	t.tween_property(card, "modulate:a", 1.0, 0.45)
	t.tween_property(rank_icon, "modulate:a", 1.0, 0.45).set_delay(0.1)
	t.tween_property(icon_glow, "modulate:a", 1.0, 0.5).set_delay(0.15)
	t.tween_property(card_center, "position:y", 0.0, 0.45)
	await t.finished

	# Scanlines fade in
	var sl = create_tween()
	sl.tween_property(scanlines, "modulate:a", 0.8, 0.6)

	# Animate scanline scroll
	_scroll_scanlines()

	# Fill bar to current LP
	await get_tree().create_timer(0.2).timeout
	var bar_tween = create_tween()
	bar_tween.set_trans(Tween.TRANS_CUBIC)
	bar_tween.set_ease(Tween.EASE_OUT)
	bar_tween.tween_property(progress_bar, "value", lp_now, 1.0)
	bar_tween.parallel().tween_method(
		func(v: float): lp_label.text = "%d / %d XP" % [int(v), lp_max],
		0.0, lp_now, 1.0
	)
	await bar_tween.finished


# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2  –  RANK UP! banner slams in, confetti bursts
# ─────────────────────────────────────────────────────────────────────────────
func _phase2_rank_up_banner() -> void:
	_play(sfx_rank_up)

	# Screen flash
	var flash = create_tween()
	flash.tween_property(screen_flash, "color:a", 0.7, 0.08)
	flash.tween_property(screen_flash, "color:a", 0.0, 0.45)

	# Banner slams in (scale punch)
	banner_center.modulate.a = 1.0
	banner.scale = Vector2(1.3, 0.6)
	var bt = create_tween()
	bt.set_trans(Tween.TRANS_BACK)
	bt.set_ease(Tween.EASE_OUT)
	bt.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.4)

	# Confetti burst
	await get_tree().create_timer(0.1).timeout
	confetti.emitting = true
	confetti_side.emitting = true
	_play(sfx_particles)

	# Screen shake on card
	_screen_shake()

	# Pulse banner border gold ↔ cyan
	_pulse_banner_border()

	# RANK UP! label zoom in
	rank_up_label.scale = Vector2(0.5, 0.5)
	rank_up_label.modulate.a = 0
	var lt = create_tween()
	lt.set_parallel(true)
	lt.set_trans(Tween.TRANS_ELASTIC)
	lt.set_ease(Tween.EASE_OUT)
	lt.tween_property(rank_up_label, "scale", Vector2(1.0, 1.0), 0.6)
	lt.tween_property(rank_up_label, "modulate:a", 1.0, 0.3)

	# Hold banner for 2.2 seconds
	await get_tree().create_timer(2.2).timeout

	# Fade banner out
	var fade = create_tween()
	fade.set_trans(Tween.TRANS_QUAD)
	fade.set_ease(Tween.EASE_IN)
	fade.tween_property(banner_center, "modulate:a", 0.0, 0.35)
	await fade.finished


# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3  –  Swap card to NEW rank, icon coin-flip, bar resets to 0
# ─────────────────────────────────────────────────────────────────────────────
func _phase3_new_rank() -> void:
	_play(sfx_coin_flip)

	var new_min = new_rank_data.get("min_xp", 0)
	var new_max = new_rank_data.get("max_xp", 100)
	var new_lp_max = int(float(new_max - new_min + 1))

	# Coin-flip icon swap
	await _coin_flip_to_new_rank()

	# Update rank name & colour
	rank_name_label.text = new_rank_data["name"]
	_tint_rank_name(new_rank_data)

	# Reset bar to 0
	progress_bar.max_value = float(new_lp_max)
	progress_bar.value = 0
	lp_label.text = "0 / %d XP" % new_lp_max

	# Tint LP label to match new rank colour
	if new_rank_data.has("color"):
		lp_label.add_theme_color_override("font_color", new_rank_data["color"])
		rank_name_label.add_theme_color_override("font_color", new_rank_data["color"])

	# Pulse card border to new rank colour
	_pulse_card_to_rank_color(new_rank_data.get("color", Color(0.2, 0.85, 1)))

	# Pop icon scale
	var pop = create_tween()
	pop.set_trans(Tween.TRANS_ELASTIC)
	pop.set_ease(Tween.EASE_OUT)
	pop.tween_property(rank_icon, "scale", Vector2(1.35, 1.35), 0.35)
	pop.tween_property(rank_icon, "scale", Vector2(1.0, 1.0), 0.4)

	_play(sfx_reveal)


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _tint_rank_name(rank: Dictionary) -> void:
	if rank.has("color"):
		rank_name_label.add_theme_color_override("font_color", rank["color"])


func _coin_flip_to_new_rank() -> void:
	# Squish x to 0
	var t1 = create_tween()
	t1.set_trans(Tween.TRANS_CUBIC)
	t1.set_ease(Tween.EASE_IN)
	t1.tween_property(rank_icon, "scale:x", 0.0, 0.25)
	t1.parallel().tween_property(rank_icon, "modulate:a", 0.2, 0.25)
	await t1.finished

	# Swap texture
	if new_rank_data.has("icon"):
		var tex = load(new_rank_data["icon"])
		if tex:
			rank_icon.texture = tex

	# Grow x back
	var t2 = create_tween()
	t2.set_trans(Tween.TRANS_BACK)
	t2.set_ease(Tween.EASE_OUT)
	t2.tween_property(rank_icon, "scale:x", 1.2, 0.35)
	t2.parallel().tween_property(rank_icon, "modulate:a", 1.0, 0.3)
	await t2.finished

	var t3 = create_tween()
	t3.set_trans(Tween.TRANS_BACK)
	t3.set_ease(Tween.EASE_OUT)
	t3.tween_property(rank_icon, "scale:x", 1.0, 0.2)


func _screen_shake() -> void:
	var orig = card.position
	var t = create_tween()
	for i in range(10):
		t.tween_property(card, "position",
			orig + Vector2(randf_range(-12, 12), randf_range(-8, 8)), 0.04)
	t.tween_property(card, "position", orig, 0.04)


func _scroll_scanlines() -> void:
	var t = create_tween()
	t.set_loops()
	t.set_trans(Tween.TRANS_LINEAR)
	t.tween_property(scanlines, "position:y", -30, 2.0)
	t.tween_property(scanlines, "position:y", 30, 2.0)
	t.tween_property(scanlines, "position:y", 0, 2.0)


func _pulse_banner_border() -> void:
	var banner_style = banner.get_theme_stylebox("panel") as StyleBoxFlat
	if not banner_style:
		return
	var t = create_tween()
	t.set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_method(
		func(v: float): banner_style.border_color = Color(0.2, 0.85, 1).lerp(Color(1, 0.82, 0.1), v),
		0.0, 1.0, 0.7)
	t.tween_method(
		func(v: float): banner_style.border_color = Color(0.2, 0.85, 1).lerp(Color(1, 0.82, 0.1), v),
		1.0, 0.0, 0.7)


func _pulse_card_to_rank_color(rank_color: Color) -> void:
	if not card_style:
		return
	var t = create_tween()
	t.set_loops(4)
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_method(
		func(v: float):
			card_style.border_color = Color(0.2, 0.85, 1).lerp(rank_color, v)
			card_style.shadow_size = int(30 + v * 20),
		0.0, 1.0, 0.6)
	t.tween_method(
		func(v: float):
			card_style.border_color = Color(0.2, 0.85, 1).lerp(rank_color, v)
			card_style.shadow_size = int(30 + v * 20),
		1.0, 0.0, 0.6)


func _pulse_close_hint() -> void:
	var t = create_tween()
	t.set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(close_hint, "modulate:a", 0.25, 0.7)
	t.tween_property(close_hint, "modulate:a", 1.0, 0.7)


# ─────────────────────────────────────────────────────────────────────────────
# CLOSE
# ─────────────────────────────────────────────────────────────────────────────
func close_notification() -> void:
	if not can_close:
		return
	print("[RankUp] Closing")

	var t = create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_IN)
	t.tween_property(background, "modulate:a", 0.0, 0.4)
	t.tween_property(card, "modulate:a", 0.0, 0.4)
	t.tween_property(rank_icon, "modulate:a", 0.0, 0.35)
	t.tween_property(icon_glow, "modulate:a", 0.0, 0.35)
	t.tween_property($CardCenter, "position:y", 60.0, 0.4)
	await t.finished

	notification_closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not can_close:
		return
	if event is InputEventMouseButton and event.pressed:
		close_notification()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			close_notification()
			get_viewport().set_input_as_handled()