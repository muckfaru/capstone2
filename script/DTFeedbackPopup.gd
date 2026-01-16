extends PanelContainer

@onready var status_label = $VBox/StatusLabel
@onready var message_label = $VBox/MessageLabel
@onready var timer = $Timer

func setup(is_success: bool, title: String, message: String):
	status_label.text = title
	message_label.text = message
	
	if is_success:
		status_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	else:
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	timer.start()

func _on_timer_timeout():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()