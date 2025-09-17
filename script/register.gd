extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




func _on_register_button_pressed() -> void:
	var email = $NinePatchRect/EmailTextEdit.text
	var password = $NinePatchRect/PasswordTextEdit.text
	var repeatpassword = $NinePatchRect/RepeatPasswordTextEdit.text
	
	Firebase.Auth.signup_with_email_and_password(email, password)
	
	pass # Replace with function body.
