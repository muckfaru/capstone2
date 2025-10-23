extends Control
class_name BadgeNotification

var _user_id: String = ""
var _badge_bg: Panel

func _ready() -> void:
	# Create background panel
	_badge_bg = Panel.new()
	
	# Set a fixed size for the dot (e.g., 12x12)
	var dot_size = 12
	_badge_bg.custom_minimum_size = Vector2(dot_size, dot_size)
	
	# Style the badge background (red circle)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0, 0, 1)  # Red
	# Set corner radius to half the size to make it a perfect circle
	style.corner_radius_top_left = dot_size / 2
	style.corner_radius_top_right = dot_size / 2
	style.corner_radius_bottom_left = dot_size / 2
	style.corner_radius_bottom_right = dot_size / 2
	_badge_bg.add_theme_stylebox_override("panel", style)
	add_child(_badge_bg)
	
	# --- NEW LINE ---
	# Adjust the position. -5 moves it 5 pixels to the left.
	# You can also adjust the 'y' value (0) to move it up (negative) or down (positive).
	_badge_bg.position = Vector2( 10, 0)
	
	# Start hidden
	visible = false
	
	# Connect to ChatManager signals
	if is_instance_valid(ChatManager):
		ChatManager.unread_count_changed.connect(_on_unread_count_changed)
		print("[Badge] Connected to ChatManager for user: ", _user_id)
	
	# Initial update
	_update_badge()

func set_user_id(user_id: String) -> void:
	_user_id = user_id
	print("[Badge] User ID set to: ", _user_id)
	_update_badge()

func _on_unread_count_changed(user_id: String, count: int) -> void:
	if user_id == _user_id:
		print("[Badge] Unread count changed for %s: %d" % [_user_id, count])
		_update_badge()

func _update_badge() -> void:
	if _user_id.is_empty() or not is_instance_valid(ChatManager):
		visible = false
		return
	
	var count = ChatManager.get_unread_count(_user_id)
	print("[Badge] Updating badge for %s: count=%d" % [_user_id, count])
	
	# Simply show the badge if count > 0, and hide it if count is 0.
	visible = (count > 0)
