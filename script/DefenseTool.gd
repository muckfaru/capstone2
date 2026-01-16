extends TextureButton

@export var defense_type = "firewall"

static var selected_defense = null  # Reference to selected DefenseTool
static var cursor_label: Label = null

@onready var label = $Label
@onready var name_label = $NameLabel

var original_modulate = Color.WHITE
var selected_modulate = Color(0.5, 1.0, 0.5)  # Green tint when selected

func _ready():
	original_modulate = modulate
	
	# Add to defense_tools group for easy access
	add_to_group("defense_tools")
	
	# Connect button press signal
	connect("pressed", _on_tool_selected)
	
	# Create static cursor label if it doesn't exist
	if cursor_label == null:
		cursor_label = Label.new()
		cursor_label.z_index = 1000
		cursor_label.add_theme_font_size_override("font_size", 40)
		cursor_label.visible = false
		
		# CRITICAL FIX: Make cursor label ignore mouse input
		cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Use call_deferred to add child after scene tree is ready
		get_tree().root.call_deferred("add_child", cursor_label)
	
	print("🛡️ Defense tool ready: ", defense_type)

func _on_tool_selected():
	print("🖱️ Defense tool clicked: ", defense_type)
	
	# If this tool is already selected, deselect it
	if selected_defense == self:
		print("   Deselecting ", defense_type)
		deselect()
		return
	
	# Deselect previous tool
	if selected_defense != null:
		print("   Deselecting previous: ", selected_defense.defense_type)
		selected_defense.deselect()
	
	# Select this tool
	selected_defense = self
	modulate = selected_modulate
	
	print("   ✅ Selected defense: ", defense_type)
	
	# Update cursor with this tool's emoji
	if cursor_label and label:
		cursor_label.text = label.text
		cursor_label.visible = true
		cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Extra safety
		# DON'T HIDE THE MOUSE! Keep it visible so you can see where you're clicking
		# Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)  # ❌ REMOVED THIS LINE

func deselect():
	modulate = original_modulate
	selected_defense = null
	
	if cursor_label:
		cursor_label.visible = false
	
	# Mouse is already visible, no need to change it
	# Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("   Defense deselected")

func _process(_delta):
	# Update cursor label position - offset so it doesn't block your mouse cursor
	if cursor_label and cursor_label.visible:
		# Position the emoji ABOVE AND TO THE RIGHT of the cursor
		var mouse_pos = get_viewport().get_mouse_position()
		cursor_label.global_position = mouse_pos + Vector2(20, -60)

# Static function to check if a defense is selected
static func get_selected_defense_type() -> String:
	if selected_defense != null:
		return selected_defense.defense_type
	return ""

# Static function to clear selection (called from outside)
static func clear_selection():
	if selected_defense != null:
		selected_defense.deselect()

# Instance methods that can be called from other scripts to access static variables
func get_class_selected_defense_type() -> String:
	var result = ""
	if selected_defense != null:
		result = selected_defense.defense_type
	print("   📋 get_class_selected_defense_type called, returning: '", result, "'")
	return result

func clear_class_selection():
	print("   🧹 clear_class_selection called")
	if selected_defense != null:
		selected_defense.deselect()
