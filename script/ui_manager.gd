extends Node
class_name UIManager

# UI Node references
var title_label: Label
var level_info_label: Label
var tutorial_text: Label

# Sender panel
var sender_message_text: Label
var sender_symmetric_key: Panel
var sender_public_key: Panel
var sender_private_key: Panel

# Network panel
var network_status: Label
var packet_display: VBoxContainer
var encrypted_data_label: Label
var attacker_indicator: Panel

# Receiver panel
var receiver_message_text: Label
var receiver_symmetric_key: Panel
var receiver_public_key: Panel
var receiver_private_key: Panel

# Control panel
var symmetric_button: Button
var asymmetric_button: Button
var hybrid_button: Button
var next_level_button: Button

# Feedback panel
var feedback_panel: Panel
var feedback_title: Label
var feedback_message: Label
var feedback_details: Label

func _ready():
	# Cache all UI node references
	cache_ui_nodes()
	print("UIManager initialized")

func cache_ui_nodes():
	var root = get_parent()
	if not root:
		push_error("UIManager: No parent node found")
		return
	
	# Title bar
	title_label = root.get_node_or_null("TitleBar/Title")
	level_info_label = root.get_node_or_null("TitleBar/LevelInfo")
	if not title_label:
		push_error("UIManager: Could not find title_label at TitleBar/Title")
	if not level_info_label:
		push_error("UIManager: Could not find level_info_label at TitleBar/LevelInfo")
	
	# Sender panel
	sender_message_text = root.get_node_or_null("MainContainer/SenderPanel/VBox/MessageDisplay/MessageText")
	sender_symmetric_key = root.get_node_or_null("MainContainer/SenderPanel/VBox/KeysContainer/SymmetricKey")
	sender_public_key = root.get_node_or_null("MainContainer/SenderPanel/VBox/KeysContainer/PublicKey")
	sender_private_key = root.get_node_or_null("MainContainer/SenderPanel/VBox/KeysContainer/PrivateKey")
	
	# Network panel
	network_status = root.get_node_or_null("MainContainer/NetworkPanel/VBox/StatusLabel")
	packet_display = root.get_node_or_null("MainContainer/NetworkPanel/VBox/TransmissionArea/PacketDisplay")
	encrypted_data_label = root.get_node_or_null("MainContainer/NetworkPanel/VBox/TransmissionArea/PacketDisplay/EncryptedData")
	attacker_indicator = root.get_node_or_null("MainContainer/NetworkPanel/VBox/TransmissionArea/AttackerIndicator")
	
	# Receiver panel
	receiver_message_text = root.get_node_or_null("MainContainer/ReceiverPanel/VBox/ReceivedDisplay/MessageText")
	receiver_symmetric_key = root.get_node_or_null("MainContainer/ReceiverPanel/VBox/KeysContainer/SymmetricKey")
	receiver_public_key = root.get_node_or_null("MainContainer/ReceiverPanel/VBox/KeysContainer/PublicKey")
	receiver_private_key = root.get_node_or_null("MainContainer/ReceiverPanel/VBox/KeysContainer/PrivateKey")
	
	# Control panel
	tutorial_text = root.get_node_or_null("ControlPanel/VBox/TutorialText")
	symmetric_button = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/SymmetricButton")
	asymmetric_button = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/AsymmetricButton")
	hybrid_button = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/HybridButton")
	next_level_button = root.get_node_or_null("ControlPanel/VBox/ButtonContainer/NextLevelButton")
	
	# Feedback panel
	feedback_panel = root.get_node_or_null("FeedbackPanel")
	feedback_title = root.get_node_or_null("FeedbackPanel/VBox/Title")
	feedback_message = root.get_node_or_null("FeedbackPanel/VBox/Message")
	feedback_details = root.get_node_or_null("FeedbackPanel/VBox/Details")

# Title and level management
func set_level_title(title: String):
	if level_info_label:
		level_info_label.text = title

func set_tutorial_text(text: String):
	if tutorial_text:
		tutorial_text.text = text

# Message management
func set_message(message: String):
	if sender_message_text:
		sender_message_text.text = message

func show_received_message(message: String):
	if receiver_message_text:
		receiver_message_text.text = message
		receiver_message_text.add_theme_color_override("font_color", Color(0.4, 1, 0.4))

# Key visibility
func show_symmetric_key(visible: bool):
	if sender_symmetric_key:
		sender_symmetric_key.visible = visible
	if receiver_symmetric_key:
		receiver_symmetric_key.visible = visible

func show_asymmetric_keys(visible: bool):
	if sender_public_key:
		sender_public_key.visible = visible
	if sender_private_key:
		sender_private_key.visible = visible
	if receiver_public_key:
		receiver_public_key.visible = visible
	if receiver_private_key:
		receiver_private_key.visible = visible

# Network transmission visualization
func show_transmission(encrypted_text: String, method: String):
	if encrypted_data_label:
		encrypted_data_label.text = "🔒 Encrypted with %s:\n%s" % [method, encrypted_text]
		encrypted_data_label.add_theme_color_override("font_color", Color(0.8, 0.6, 1))
	
	set_network_status("Transmitting encrypted data...")
	
	# Animate the transmission
	animate_transmission()

func animate_transmission():
	if not packet_display:
		return
	
	var arrow1 = packet_display.get_node_or_null("Arrow1")
	var arrow2 = packet_display.get_node_or_null("Arrow2")
	
	for arrow in [arrow1, arrow2]:
		if arrow:
			var tween = create_tween()
			tween.set_loops(3)
			tween.tween_property(arrow, "modulate:a", 0.3, 0.3)
			tween.tween_property(arrow, "modulate:a", 1.0, 0.3)

func reset_transmission():
	if encrypted_data_label:
		encrypted_data_label.text = "[Waiting for transmission...]"
		encrypted_data_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	if receiver_message_text:
		receiver_message_text.text = "[No message received]"
		receiver_message_text.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	if network_status:
		network_status.text = "Network Status: Idle"
	if attacker_indicator:
		attacker_indicator.visible = false

func set_network_status(status: String):
	if network_status:
		network_status.text = status

# Attacker visualization
func show_attacker_indicator(visible: bool):
	if not attacker_indicator:
		return
	
	attacker_indicator.visible = visible
	
	if visible:
		# Pulse animation
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(attacker_indicator, "modulate:a", 0.6, 0.5)
		tween.tween_property(attacker_indicator, "modulate:a", 1.0, 0.5)

# Button management
func enable_encryption_buttons(enabled: bool):
	if symmetric_button:
		symmetric_button.disabled = not enabled
	if asymmetric_button:
		asymmetric_button.disabled = not enabled
	if hybrid_button:
		hybrid_button.disabled = not enabled

func show_hybrid_button(visible: bool):
	if hybrid_button:
		hybrid_button.visible = visible

func show_next_level_button(visible: bool):
	if next_level_button:
		next_level_button.visible = visible

# Feedback panel
func show_feedback(success: bool, title: String, message: String, details: String):
	if not feedback_panel:
		return
	
	if feedback_title:
		feedback_title.text = title
	if feedback_message:
		feedback_message.text = message
	if feedback_details:
		feedback_details.text = details
	
	# Style based on success/failure
	var panel_style = feedback_panel.get_theme_stylebox("panel")
	if success:
		panel_style.bg_color = Color(0.1, 0.6, 0.2, 0.95)
		panel_style.border_color = Color(0.2, 0.8, 0.3, 1)
		if feedback_title:
			feedback_title.add_theme_color_override("font_color", Color(0.9, 1, 0.9))
	else:
		panel_style.bg_color = Color(0.6, 0.1, 0.1, 0.95)
		panel_style.border_color = Color(0.9, 0.2, 0.2, 1)
		if feedback_title:
			feedback_title.add_theme_color_override("font_color", Color(1, 0.9, 0.9))
	
	feedback_panel.visible = true
	
	# Fade in animation
	feedback_panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(feedback_panel, "modulate:a", 1.0, 0.3)

func hide_feedback():
	if not feedback_panel:
		return
	
	var tween = create_tween()
	tween.tween_property(feedback_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): feedback_panel.visible = false)

# Visual effects
func pulse_element(element: Control, duration: float = 0.5):
	var original_scale = element.scale
	var tween = create_tween()
	tween.tween_property(element, "scale", original_scale * 1.1, duration / 2)
	tween.tween_property(element, "scale", original_scale, duration / 2)

func highlight_key(key_panel: Panel):
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(key_panel, "modulate", Color(1.5, 1.5, 1), 0.3)
	tween.tween_property(key_panel, "modulate", Color(1, 1, 1), 0.3)

# Show educational tooltips
func show_tooltip(text: String, position: Vector2):
	# Could implement tooltip system here
	pass

# Progress indicators
func show_loading_indicator(visible: bool, text: String = "Processing..."):
	# Could add loading spinner
	if visible:
		set_network_status(text)

# Performance metrics display
func show_performance_metrics(metrics: Dictionary):
	var metrics_text = "Performance:\n"
	metrics_text += "Speed: %s\n" % metrics.get("speed", "N/A")
	metrics_text += "Security: %s" % metrics.get("security", "N/A")
	
	# Could display this in a dedicated panel
	print(metrics_text)

# Educational hints
func show_hint(hint_text: String):
	if not tutorial_text:
		return
	
	tutorial_text.text = "💡 Hint: " + hint_text
	
	var tween = create_tween()
	tween.tween_property(tutorial_text, "modulate", Color(1.2, 1.2, 0.8), 0.3)
	tween.tween_property(tutorial_text, "modulate", Color(1, 1, 1), 0.3)

# Reset all UI elements
func reset_ui():
	reset_transmission()
	show_symmetric_key(false)
	show_asymmetric_keys(false)
	show_hybrid_button(false)
	show_next_level_button(false)
	enable_encryption_buttons(true)
	hide_feedback()
