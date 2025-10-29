extends Window

signal confirmed(room_name: String, anonymous: bool)
signal canceled

@onready var _room_name_edit: LineEdit = $VBox/RoomNameContainer/RoomNameEdit
@onready var _anonymous_check: CheckBox = $VBox/AnonymousContainer/AnonymousCheckInsideRoom
@onready var _create_btn: Button = $VBox/Buttons/CreateButton
@onready var _cancel_btn: Button = $VBox/Buttons/CancelButton

var _default_name: String = ""

func _ready() -> void:
	# Wire UI
	_create_btn.pressed.connect(_on_create_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_anonymous_check.toggled.connect(func(_pressed: bool):
		_apply_name()
	)
	close_requested.connect(_on_close_requested)

	# Ensure initial text reflects current toggle state
	_apply_name()

func init_with_username(username: String) -> void:
	_default_name = username
	_apply_name()

func _apply_name() -> void:
	var effective := "Anonymous" if _anonymous_check.button_pressed else (_default_name if _default_name != "" else _room_name_edit.text)
	_room_name_edit.text = effective

func _on_create_pressed() -> void:
	emit_signal("confirmed", _room_name_edit.text, _anonymous_check.button_pressed)

func _on_cancel_pressed() -> void:
	emit_signal("canceled")

func _on_close_requested() -> void:
	emit_signal("canceled")
