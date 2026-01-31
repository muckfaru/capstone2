extends Control

signal tutorial_skipped

var arrow_up: bool = true

@onready var arrow = $Arrow
@onready var animation_timer = $AnimationTimer
@onready var skip_button = $TooltipPanel/VBox/SkipButton

func _ready():
	visible = false
	animation_timer.timeout.connect(_on_animation_timer_timeout)

func show_tutorial():
	visible = true
	animation_timer.start()

func hide_tutorial():
	visible = false
	animation_timer.stop()
	emit_signal("tutorial_skipped")

func _on_skip_button_pressed():
	hide_tutorial()

func _on_animation_timer_timeout():
	# Animate arrow bouncing
	var tween = create_tween()
	
	if arrow_up:
		tween.tween_property(arrow, "position:y", arrow.position.y - 20, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(arrow, "position:y", arrow.position.y + 20, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	arrow_up = !arrow_up