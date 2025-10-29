extends Window

signal confirmed(room_name: String, anonymous: bool)
signal canceled

@onready var _room_name_edit: LineEdit = $VBox/RoomNameContainer/RoomNameEdit
@onready var _anonymous_check: CheckBox = $VBox/AnonymousContainer/AnonymousCheckInsideRoom
@onready var _create_btn: Button = $VBox/Buttons/CreateButton
@onready var _cancel_btn: Button = $VBox/Buttons/CancelButton

var _default_name: String = ""
var _user_entered_name: String = ""

func _ready() -> void:
	# Wire UI
	_create_btn.pressed.connect(_on_create_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_anonymous_check.toggled.connect(func(_pressed: bool):
		_apply_name()
	)
	_room_name_edit.text_changed.connect(func(t: String):
		# Only record user-entered text when not in anonymous mode
		if not _anonymous_check.button_pressed:
			_user_entered_name = t
	)
	close_requested.connect(_on_close_requested)

	# Ensure initial text reflects current toggle state
	_apply_name()

func init_with_username(username: String) -> void:
	_default_name = username
	_apply_name()

func _apply_name() -> void:
	if _anonymous_check.button_pressed:
		# Save current non-anonymous entry before switching
		var curr := _room_name_edit.text
		if curr != "Anonymous" and curr.strip_edges() != "":
			_user_entered_name = curr
		_room_name_edit.text = "Anonymous"
		_room_name_edit.editable = false
	else:
		_room_name_edit.editable = true
		var curr2 := _room_name_edit.text
		if curr2 == "Anonymous" or curr2.strip_edges() == "":
			var fallback := (_user_entered_name if _user_entered_name.strip_edges() != "" else _default_name)
			_room_name_edit.text = fallback

func _on_create_pressed() -> void:
	emit_signal("confirmed", _room_name_edit.text, _anonymous_check.button_pressed)

func _on_cancel_pressed() -> void:
	emit_signal("canceled")

func _on_close_requested() -> void:
	emit_signal("canceled")
