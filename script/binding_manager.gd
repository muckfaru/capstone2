extends Control

## Binding Manager - Teacher UI for managing student-account bindings
## Allows viewing, searching, and unbinding student numbers

signal back_pressed

# UI References
@onready var back_btn: Button = $MainContainer/VBox/TopBar/BackButton
@onready var refresh_btn: Button = $MainContainer/VBox/TopBar/RefreshBtn
@onready var info_label: Label = $MainContainer/VBox/ContentPanel/ContentVBox/Header/HeaderHBox/InfoLabel
@onready var storage_indicator: Label = $MainContainer/VBox/ContentPanel/ContentVBox/Header/HeaderHBox/StorageIndicator
@onready var search_box: LineEdit = $MainContainer/VBox/ContentPanel/ContentVBox/SearchRow/SearchBox
@onready var clear_all_btn: Button = $MainContainer/VBox/ContentPanel/ContentVBox/SearchRow/ClearAllBtn
@onready var binding_list: VBoxContainer = $MainContainer/VBox/ContentPanel/ContentVBox/BindingScroll/BindingList
@onready var empty_state: CenterContainer = $MainContainer/VBox/ContentPanel/ContentVBox/EmptyState
@onready var confirm_clear_dialog: ConfirmationDialog = $ConfirmClearDialog
@onready var confirm_unbind_dialog: ConfirmationDialog = $ConfirmUnbindDialog

var _lobby_url: String = "https://codebreaker-lobby.onrender.com"
var _return_scene: String = "res://scene/TeacherCreateRoom.tscn"
var _bindings: Array = []
var _pending_unbind: String = ""  # Student number to unbind
var _http_request: HTTPRequest

func _ready() -> void:
	# Check return scene
	if get_tree().has_meta("binding_manager_return"):
		_return_scene = get_tree().get_meta("binding_manager_return")
		get_tree().remove_meta("binding_manager_return")
	
	if get_tree().has_meta("binding_manager_lobby_url"):
		_lobby_url = get_tree().get_meta("binding_manager_lobby_url")
		get_tree().remove_meta("binding_manager_lobby_url")
	
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	
	_connect_signals()
	_fetch_bindings()

func _connect_signals() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	refresh_btn.pressed.connect(_fetch_bindings)
	search_box.text_changed.connect(_on_search_changed)
	clear_all_btn.pressed.connect(_on_clear_all_pressed)
	confirm_clear_dialog.confirmed.connect(_on_clear_confirmed)
	confirm_unbind_dialog.confirmed.connect(_on_unbind_confirmed)

func _on_back_pressed() -> void:
	back_pressed.emit()
	get_tree().change_scene_to_file(_return_scene)

func _fetch_bindings() -> void:
	info_label.text = "📊 Loading..."
	
	var url := _lobby_url + "/api/bindings"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			var text: String = body.get_string_from_utf8()
			var data = JSON.parse_string(text)
			if typeof(data) == TYPE_DICTIONARY:
				_bindings = data.get("bindings", [])
				var count: int = data.get("count", 0)
				var storage: String = str(data.get("storage", "memory"))
				_update_header(count, storage)
				_refresh_list("")
		else:
			info_label.text = "❌ Failed to fetch bindings"
			_show_empty()
	)
	http.request(url)

func _update_header(count: int, storage: String) -> void:
	info_label.text = "📊 Bindings: %d | Storage: %s" % [count, storage]
	
	if storage == "firestore":
		storage_indicator.text = "✅ Persistent (Firebase)"
		storage_indicator.modulate = Color(0.2, 1, 0.4)
	else:
		storage_indicator.text = "⚠️ Non-persistent (resets on server restart)"
		storage_indicator.modulate = Color(1, 0.8, 0)

func _refresh_list(filter_text: String) -> void:
	# Clear existing
	for child in binding_list.get_children():
		child.queue_free()
	
	var filter := filter_text.strip_edges().to_upper()
	var visible_count := 0
	
	for b in _bindings:
		var student_num: String = str(b.get("student_number", ""))
		var username: String = str(b.get("username", ""))
		var uid: String = str(b.get("uid", ""))
		var bound_at = b.get("bound_at", 0)
		
		# Filter
		if filter != "":
			if not (filter in student_num.to_upper() or filter in username.to_upper()):
				continue
		
		var row := _create_binding_row(student_num, username, uid, bound_at)
		binding_list.add_child(row)
		visible_count += 1
	
	if visible_count == 0:
		_show_empty()
	else:
		empty_state.visible = false

func _create_binding_row(student_num: String, username: String, uid: String, bound_at) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 50
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.border_color = Color(0, 0.6, 0.6, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	
	# Student Number
	var num_label := Label.new()
	num_label.text = "📋 %s" % student_num
	num_label.custom_minimum_size.x = 150
	num_label.add_theme_color_override("font_color", Color(0, 1, 1))
	num_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(num_label)
	
	# Username
	var name_label := Label.new()
	name_label.text = "👤 %s" % username
	name_label.custom_minimum_size.x = 200
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	hbox.add_child(name_label)
	
	# UID (truncated)
	var uid_label := Label.new()
	var short_uid: String = uid.substr(0, 12) + "..." if uid.length() > 15 else uid
	uid_label.text = "🔑 %s" % short_uid
	uid_label.custom_minimum_size.x = 150
	uid_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	uid_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(uid_label)
	
	# Bound date
	var date_label := Label.new()
	if bound_at is float or bound_at is int:
		var dt := Time.get_datetime_dict_from_unix_time(int(bound_at) / 1000)
		date_label.text = "%02d/%02d/%d" % [dt.month, dt.day, dt.year]
	else:
		date_label.text = "—"
	date_label.custom_minimum_size.x = 100
	date_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	date_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(date_label)
	
	# Unbind button
	var unbind_btn := Button.new()
	unbind_btn.text = "🔓 Unbind"
	unbind_btn.custom_minimum_size = Vector2(100, 35)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.6, 0.3, 0.1, 0.8)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(1, 0.5, 0.2)
	btn_style.set_corner_radius_all(4)
	unbind_btn.add_theme_stylebox_override("normal", btn_style)
	unbind_btn.pressed.connect(func(): _on_unbind_pressed(student_num, username))
	hbox.add_child(unbind_btn)
	
	return panel

func _show_empty() -> void:
	empty_state.visible = true
	for child in binding_list.get_children():
		child.queue_free()

func _on_search_changed(new_text: String) -> void:
	_refresh_list(new_text)

func _on_clear_all_pressed() -> void:
	if _bindings.size() == 0:
		return
	confirm_clear_dialog.popup_centered()

func _on_clear_confirmed() -> void:
	var url := _lobby_url + "/api/bindings/clear"
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			_bindings.clear()
			_refresh_list("")
			_update_header(0, "memory")
		else:
			push_error("Failed to clear bindings")
	)
	http.request(url, [], HTTPClient.METHOD_POST)

func _on_unbind_pressed(student_num: String, username: String) -> void:
	_pending_unbind = student_num
	confirm_unbind_dialog.dialog_text = "Unbind student number %s (%s)?\n\nThey will need to re-bind when they next join a restricted room." % [student_num, username]
	confirm_unbind_dialog.popup_centered()

func _on_unbind_confirmed() -> void:
	if _pending_unbind.is_empty():
		return
	
	var url := _lobby_url + "/api/bindings/" + _pending_unbind
	var http := HTTPRequest.new()
	add_child(http)
	var sn := _pending_unbind
	http.request_completed.connect(func(_r, code, _h, body):
		http.queue_free()
		if code == 200:
			# Remove from local list
			for i in range(_bindings.size()):
				if str(_bindings[i].get("student_number", "")) == sn:
					_bindings.remove_at(i)
					break
			_refresh_list(search_box.text)
			_update_header(_bindings.size(), "memory")
		else:
			push_error("Failed to unbind: %s" % sn)
	)
	http.request(url, [], HTTPClient.METHOD_DELETE)
	_pending_unbind = ""
