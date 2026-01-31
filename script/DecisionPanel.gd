extends PanelContainer

enum DecisionType { GRANT, MFA, DENY }

@export var decision_type: DecisionType = DecisionType.GRANT
@export var action_name: String = "grant"

# Texture paths - set these in the editor or use defaults
@export var normal_texture: Texture2D
@export var hover_texture: Texture2D
@export var selected_texture: Texture2D

var is_selected: bool = false
var display_text: String = ""  # For DropZone to display

@onready var icon_label = $VBox/Icon
@onready var action_label = $VBox/ActionLabel
@onready var sub_label = $VBox/SubLabel

# Style resources
var normal_style: StyleBoxTexture
var hover_style: StyleBoxTexture
var selected_style: StyleBoxTexture

func _ready():
	add_to_group("decision_panels")
	
	# Setup styles
	_setup_styles()
	
	# Configure based on decision type
	_configure_appearance()
	
	# Connect signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _setup_styles():
	# Create StyleBoxTexture for each state
	normal_style = StyleBoxTexture.new()
	hover_style = StyleBoxTexture.new()
	selected_style = StyleBoxTexture.new()
	
	# Set expand margins (adjust for your textures)
	for style in [normal_style, hover_style, selected_style]:
		style.expand_margin_left = 10.0
		style.expand_margin_top = 10.0
		style.expand_margin_right = 10.0
		style.expand_margin_bottom = 10.0

func _configure_appearance():
	match decision_type:
		DecisionType.GRANT:
			action_name = "grant"
			display_text = ""
			icon_label.text = ""
			action_label.text = ""
			sub_label.text = ""
			
			# Load textures (use exported ones if available, otherwise load defaults)
			if normal_texture:
				normal_style.texture = normal_texture
				hover_style.texture = hover_texture if hover_texture else normal_texture
				selected_style.texture = selected_texture if selected_texture else normal_texture
			else:
				# Try to load from default paths
				var grant_tex = load("res://asset/minigamesicon/grant_button.png")
				if grant_tex:
					normal_style.texture = grant_tex
					hover_style.texture = grant_tex
					selected_style.texture = grant_tex
					# Apply modulation for different states
					hover_style.modulate_color = Color(1.2, 1.2, 1.2, 1)
					selected_style.modulate_color = Color(1.4, 1.4, 1.4, 1)
			
		DecisionType.MFA:
			action_name = "mfa"
			display_text = ""
			icon_label.text = ""
			action_label.text = ""
			sub_label.text = ""
			
			if normal_texture:
				normal_style.texture = normal_texture
				hover_style.texture = hover_texture if hover_texture else normal_texture
				selected_style.texture = selected_texture if selected_texture else normal_texture
			else:
				var mfa_tex = load("res://asset/minigamesicon/mfa_button.png")
				if mfa_tex:
					normal_style.texture = mfa_tex
					hover_style.texture = mfa_tex
					selected_style.texture = mfa_tex
					hover_style.modulate_color = Color(1.2, 1.2, 1.2, 1)
					selected_style.modulate_color = Color(1.4, 1.4, 1.4, 1)
			
		DecisionType.DENY:
			action_name = "deny"
			display_text = ""
			icon_label.text = ""
			action_label.text = ""
			sub_label.text = ""
			
			if normal_texture:
				normal_style.texture = normal_texture
				hover_style.texture = hover_texture if hover_texture else normal_texture
				selected_style.texture = selected_texture if selected_texture else normal_texture
			else:
				var deny_tex = load("res://asset/minigamesicon/deny_button.png")
				if deny_tex:
					normal_style.texture = deny_tex
					hover_style.texture = deny_tex
					selected_style.texture = deny_tex
					hover_style.modulate_color = Color(1.2, 1.2, 1.2, 1)
					selected_style.modulate_color = Color(1.4, 1.4, 1.4, 1)
	
	# Apply the normal style
	add_theme_stylebox_override("panel", normal_style)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_clicked()

func _on_clicked():
	print("Panel clicked: ", action_name)
	
	# Deselect ALL other panels first
	_deselect_all_panels()
	
	# Find the drop zone
	var drop_zone = _find_drop_zone()
	if drop_zone:
		print("Panel: Found drop zone, sending decision")
		drop_zone._on_panel_clicked(self)
		
		# Mark as selected
		is_selected = true
		add_theme_stylebox_override("panel", selected_style)
		
		# Pulse animation
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		print("ERROR: Panel could not find drop zone!")

func _deselect_all_panels():
	var all_panels = get_tree().get_nodes_in_group("decision_panels")
	for panel in all_panels:
		if panel != self:
			panel.deselect()

func _find_drop_zone() -> Node:
	var request_card = get_tree().get_first_node_in_group("request_card")
	if request_card:
		var drop_zone = request_card.get_node_or_null("VBox/DropZoneSection/DropZone")
		if drop_zone:
			return drop_zone
	
	var drop_zones = get_tree().get_nodes_in_group("drop_zones")
	if drop_zones.size() > 0:
		return drop_zones[0]
	
	return null

func deselect():
	is_selected = false
	add_theme_stylebox_override("panel", normal_style)
	scale = Vector2(1, 1)

func _on_mouse_entered():
	if not is_selected:
		add_theme_stylebox_override("panel", hover_style)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exited():
	if not is_selected:
		add_theme_stylebox_override("panel", normal_style)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1, 1), 0.1)