extends Panel

# ✅ FIX: Use correct node paths from your Main.tscn
@onready var title_label = $VBox/TitleLabel
@onready var message_label = $VBox/MessageLabel
var timer: Timer = null

func _ready():
	visible = false
	
	if not timer:
		timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.connect("timeout", _on_Timer_timeout)
	
	print("📢 FeedbackPopup ready!")
	print("   Title label exists: ", title_label != null)
	print("   Message label exists: ", message_label != null)

func show_message(title, color, message):
	print("\n🎨 FeedbackPopup.show_message() called")
	print("   Title: ", title)
	print("   Visible before: ", visible)
	
	if title_label:
		title_label.text = title
		title_label.modulate = color
		print("   Title label updated")
	else:
		print("   ❌ title_label is null!")
	
	if message_label:
		message_label.text = message
		print("   Message label updated")
	else:
		print("   ❌ message_label is null!")
	
	visible = true
	print("   Visible after: ", visible)
	print("   Global position: ", global_position)
	print("   Size: ", size)
	
	# Auto-hide after 1.5 seconds
	if timer:
		timer.start(1.5)
		print("   Timer started for 1.5 seconds")

func _on_Timer_timeout():
	visible = false
	print("   Feedback popup hidden")