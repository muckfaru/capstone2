extends PanelContainer

signal decision_dropped(action: String)

var current_panel: Node = null

# Store the original dropzone texture
var original_texture: Texture2D
var original_style: StyleBoxTexture

@onready var placeholder_icon = $Content/PlaceholderIcon
@onready var placeholder_text = $Content/PlaceholderText
@onready var content_container = $Content

func _ready():
	add_to_group("drop_zones")
	
	# Store the PANELCONTAINER's own background texture
	var panel_style = get_theme_stylebox("panel")
	if panel_style is StyleBoxTexture:
		original_texture = panel_style.texture
		original_style = panel_style.duplicate()
		print("DropZone: Stored original texture: ", original_texture)
	else:
		print("DropZone: No StyleBoxTexture found on PanelContainer")

func can_accept_drop() -> bool:
	return true

func _on_panel_clicked(panel: Node):
	"""Called when a decision panel is clicked"""
	print("\n=== DropZone: Panel clicked = ", panel.action_name, " ===")
	
	# Deselect previous panel if different
	if current_panel and current_panel != panel:
		print("DropZone: Deselecting previous panel: ", current_panel.action_name)
		current_panel.deselect()
	
	# Store reference to new panel
	current_panel = panel
	
	# Hide placeholder elements
	_hide_placeholder()
	
	# REPLACE the dropzone background with the decision button texture
	_replace_background_with_button(panel)
	
	# Pulse animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Emit signal
	emit_signal("decision_dropped", panel.action_name)
	print("DropZone: Emitted signal for ", panel.action_name)
	print("DropZone: Background replaced with button texture\n")

func _replace_background_with_button(panel: Node):
	"""Replace the entire dropzone background with the decision button texture"""
	print("DropZone: _replace_background_with_button() for ", panel.action_name)
	
	# Check if panel has selected_style property
	if not "selected_style" in panel:
		print("  ERROR: Panel doesn't have 'selected_style' property!")
		return
	
	if not panel.selected_style:
		print("  ERROR: Panel selected_style is null!")
		return
	
	var button_texture = panel.selected_style.texture
	
	if button_texture:
		print("  Button texture found: ", button_texture)
		
		# Create new StyleBoxTexture for background
		var new_style = StyleBoxTexture.new()
		new_style.texture = button_texture
		
		# Copy expand margins from the original button style
		new_style.expand_margin_left = panel.selected_style.expand_margin_left
		new_style.expand_margin_top = panel.selected_style.expand_margin_top
		new_style.expand_margin_right = panel.selected_style.expand_margin_right
		new_style.expand_margin_bottom = panel.selected_style.expand_margin_bottom
		
		# Full brightness
		new_style.modulate_color = Color(1, 1, 1, 1)
		
		# REPLACE the PanelContainer's own background texture
		add_theme_stylebox_override("panel", new_style)
		
		print("  Successfully replaced DropZone background with: ", panel.action_name, " texture")
	else:
		print("  ERROR: Button texture is null!")
		print("  Panel selected_style exists but texture is: ", panel.selected_style.texture)

func clear_decision():
	"""Remove the current decision and restore original dropzone texture"""
	print("\n=== DropZone: clear_decision() called ===")
	
	if current_panel:
		print("DropZone: Deselecting panel: ", current_panel.action_name)
		current_panel.deselect()
		current_panel = null
	
	# RESTORE the original dropzone background texture
	_restore_original_background()
	
	# Show placeholder
	_show_placeholder()
	
	print("DropZone: Clear complete\n")

func _restore_original_background():
	"""Restore the original dropzone background texture"""
	print("DropZone: Restoring original background...")
	
	if original_style:
		# Use the stored original style
		add_theme_stylebox_override("panel", original_style.duplicate())
		print("  Restored original dropzone texture")
	elif original_texture:
		# Fallback: recreate style from texture
		var restored_style = StyleBoxTexture.new()
		restored_style.texture = original_texture
		restored_style.expand_margin_top = 2.0
		restored_style.expand_margin_bottom = 20.0
		
		add_theme_stylebox_override("panel", restored_style)
		print("  Restored original dropzone texture (from stored texture)")
	else:
		print("  ERROR: No original texture/style found!")

func get_current_decision() -> String:
	if current_panel:
		return current_panel.action_name
	return ""

func _show_placeholder():
	if placeholder_icon:
		placeholder_icon.visible = true
	if placeholder_text:
		placeholder_text.visible = true

func _hide_placeholder():
	if placeholder_icon:
		placeholder_icon.visible = false
	if placeholder_text:
		placeholder_text.visible = false

# Keep these for backward compatibility
func _on_drag_started(_panel: Node):
	pass

func _on_drag_stopped():
	pass

func _on_panel_dropped(_panel: Node):
	pass
