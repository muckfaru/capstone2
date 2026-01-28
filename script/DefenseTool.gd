extends TextureButton

@export var defense_type = "firewall"

static var selected_defense = null
static var cursor_label: Label = null

@onready var label = $Label
@onready var name_label = $NameLabel

var original_modulate = Color.WHITE
var selected_modulate = Color(0.5, 1.0, 0.5)

func _ready():
	original_modulate = modulate
	
	add_to_group("defense_tools")
	connect("pressed", _on_tool_selected)
	
	# Create static cursor label
	if cursor_label == null:
		cursor_label = Label.new()
		cursor_label.z_index = 1000
		cursor_label.add_theme_font_size_override("font_size", 40)
		cursor_label.visible = false
		cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.call_deferred("add_child", cursor_label)
	
	print("🛡️ Defense tool ready: ", defense_type)

func _process(delta):
	# Update cursor position
	if cursor_label and cursor_label.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		cursor_label.global_position = mouse_pos + Vector2(20, -60)

func _on_tool_selected():
	print("\n=== 🖱️ DEFENSE TOOL CLICKED ===")
	print("   Defense type: ", defense_type)
	print("   Currently selected: ", selected_defense.defense_type if selected_defense else "none")
	
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
	
	# Update cursor
	if cursor_label and label:
		cursor_label.text = label.text
		cursor_label.visible = true
		cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("   ✅ Cursor updated with emoji: ", label.text)
	
	print("=== END DEFENSE TOOL CLICKED ===\n")

func deselect():
	print("   🧹 Deselecting defense: ", defense_type)
	modulate = original_modulate
	selected_defense = null
	
	if cursor_label:
		cursor_label.visible = false

# Static methods for compatibility
static func get_selected_defense_type() -> String:
	if selected_defense != null:
		return selected_defense.defense_type
	return ""

static func clear_selection():
	if selected_defense != null:
		selected_defense.deselect()

# Class methods for GameManager
func get_class_selected_defense_type() -> String:
	var result = ""
	if selected_defense != null:
		result = selected_defense.defense_type
	print("   📋 get_class_selected_defense_type returning: '", result, "'")
	return result

func clear_class_selection():
	print("   🧹 clear_class_selection called - keeping selection active!")
	# ✅ FIX: Don't deselect after use - keep the defense tool selected
	# This allows rapid clicking on multi-health threats