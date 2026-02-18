extends Control

@onready var hover_overlay: PanelContainer = $Panel/Content/HoverOverlay
@onready var content: Control = $Panel/Content
@onready var panel: PanelContainer = $Panel

var _hover_tween: Tween = null
var rarity_color: Color = Color(0.7, 0.7, 0.7, 1)  # set externally by RewardPopup

func _ready() -> void:
	hover_overlay.visible = false
	hover_overlay.modulate.a = 0.0
	# Panel has mouse_filter=0, so connect to IT not self
	panel.mouse_entered.connect(_on_mouse_entered)
	panel.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	if not content.visible:
		return
	if _hover_tween:
		_hover_tween.kill()

	# Tint the hover overlay with rarity color at 70% opacity.
	# Guard: HoverOverlay uses StyleBoxFlat — but be safe in case it ever changes.
	var style = hover_overlay.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var tinted = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.75)
		(style as StyleBoxFlat).bg_color = tinted

	hover_overlay.visible = true
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_CUBIC)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(hover_overlay, "modulate:a", 1.0, 0.18)

func _on_mouse_exited() -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_CUBIC)
	_hover_tween.set_ease(Tween.EASE_IN)
	_hover_tween.tween_property(hover_overlay, "modulate:a", 0.0, 0.15)
	await _hover_tween.finished
	hover_overlay.visible = false