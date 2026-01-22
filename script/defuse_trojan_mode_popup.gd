extends Window

signal single_selected
signal multiplayer_selected
signal canceled

@onready var single_btn: Button = $Background/VBox/Buttons/SingleButton
@onready var multi_btn: Button = $Background/VBox/Buttons/MultiplayerButton
@onready var cancel_btn: Button = $Background/VBox/Buttons/CancelButton
@onready var close_btn: Button = $Background/CloseButton

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(func():
			canceled.emit()
			queue_free()
		)
	if cancel_btn:
		cancel_btn.pressed.connect(func():
			canceled.emit()
			queue_free()
		)
	if single_btn:
		single_btn.pressed.connect(func():
			single_selected.emit()
			queue_free()
		)
	if multi_btn:
		multi_btn.pressed.connect(func():
			multiplayer_selected.emit()
			queue_free()
		)

	close_requested.connect(func():
		canceled.emit()
		queue_free()
	)
