extends Control

## Section Manager - UI for managing student sections
## Allows creating, viewing, and managing sections with imported student data

signal back_pressed

# UI References
@onready var back_btn: Button = $MainContainer/TopBar/BackButton
@onready var stats_label: Label = $MainContainer/TopBar/StatsLabel
@onready var section_list_container: VBoxContainer = $MainContainer/ContentArea/SectionListPanel/SectionListVBox/SectionScroll/SectionListContainer
@onready var new_section_btn: Button = $MainContainer/ContentArea/SectionListPanel/SectionListVBox/SectionListHeader/NewSectionBtn
@onready var import_btn: Button = $MainContainer/ContentArea/SectionListPanel/SectionListVBox/SectionListHeader/ImportBtn

@onready var section_name_label: Label = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailHeader/SectionNameLabel
@onready var search_box: LineEdit = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailHeader/SearchBox
@onready var detail_stats: Label = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailStats
@onready var student_list_container: VBoxContainer = $MainContainer/ContentArea/DetailPanel/DetailVBox/StudentScroll/StudentListContainer
@onready var empty_state: CenterContainer = $MainContainer/ContentArea/DetailPanel/DetailVBox/EmptyState

@onready var add_student_btn: Button = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailActions/AddStudentBtn
@onready var import_more_btn: Button = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailActions/ImportMoreBtn
@onready var export_btn: Button = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailActions/ExportBtn
@onready var delete_section_btn: Button = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailActions/DeleteSectionBtn
var create_room_btn: Button = null
var export_grades_btn: Button = null
var dashboard_btn: Button = null
var dynamic_actions_row: HBoxContainer = null

@onready var file_dialog: FileDialog = $FileDialog

var _selected_section_id: String = ""
var _import_target_section_id: String = ""  # Section to import into
var _is_new_import := false  # True if importing to create new section
var _return_scene: String = "res://scene/landing.tscn"  # Where to go on back

func _ready() -> void:
	# Check if we came from teacher mode
	if get_tree().has_meta("section_manager_return"):
		_return_scene = get_tree().get_meta("section_manager_return")
		get_tree().remove_meta("section_manager_return")
	
	_connect_signals()
	_build_dynamic_actions_row()
	_build_create_room_button()
	_build_export_grades_button()
	_build_dashboard_button()
	_refresh_section_list()
	_update_global_stats()
	_show_no_selection()
	
	# Load latest data from Firestore (overwrites local)
	StudentDatabase.firestore_loaded.connect(_on_firestore_loaded)
	StudentDatabase.load_from_firestore()

func _connect_signals() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	new_section_btn.pressed.connect(_on_new_section_pressed)
	import_btn.pressed.connect(_on_import_pressed)
	
	search_box.text_changed.connect(_on_search_changed)
	add_student_btn.pressed.connect(_on_add_student_pressed)
	import_more_btn.pressed.connect(_on_import_more_pressed)
	export_btn.pressed.connect(_on_export_pressed)
	delete_section_btn.pressed.connect(_on_delete_section_pressed)
	
	file_dialog.file_selected.connect(_on_file_selected)

# ─────────────────────────────────────────────────────────────
# SECTION LIST
# ─────────────────────────────────────────────────────────────

func _refresh_section_list() -> void:
	# Clear existing
	for child in section_list_container.get_children():
		child.queue_free()
	
	var sections: Array = StudentDatabase.get_all_sections()
	
	if sections.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No sections yet.\nClick '+ New' or 'Import' to get started."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		section_list_container.add_child(empty_label)
		return
	
	for section in sections:
		var card := _create_section_card(section)
		section_list_container.add_child(card)

func _create_section_card(section: Dictionary) -> PanelContainer:
	var card_scene: PackedScene = load("res://scene/ui_components/section_card.tscn")
	var card: PanelContainer = card_scene.instantiate()
	card.set_meta("section_id", section["id"])
	
	card.get_node("MainVBox/NameLabel").text = "     %s" % section.get("name", "Unnamed")
	
	var count: int = section.get("students", []).size()
	card.get_node("MainVBox/InfoLabel").text = "%s • %d student%s" % [section.get("school_year", ""), count, "" if count == 1 else "s"]
	
	# Make clickable
	card.gui_input.connect(_on_section_card_input.bind(section["id"]))
	card.mouse_entered.connect(func(): _highlight_card(card, true))
	card.mouse_exited.connect(func(): _highlight_card(card, section["id"] == _selected_section_id))
	
	# Highlight if selected
	if section["id"] == _selected_section_id:
		_highlight_card(card, true)
	
	return card

func _highlight_card(card: PanelContainer, highlight: bool) -> void:
	# Use self_modulate to brighten/dim the card so we NEVER override 
	# the background colors the user designed inside the Godot .tscn editor!
	if highlight:
		card.self_modulate = Color(1.1, 1.1, 1.1, 1.0) # Slight glow for selected/hovered
	else:
		card.self_modulate = Color(0.7, 0.7, 0.7, 0.95) # Dimmed when unselected

func _on_section_card_input(event: InputEvent, section_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_section(section_id)

func _select_section(section_id: String) -> void:
	_selected_section_id = section_id
	_refresh_section_list()  # Re-render to update highlights
	_refresh_detail_panel()
	
	# Enable action buttons
	add_student_btn.disabled = false
	import_more_btn.disabled = false
	export_btn.disabled = false
	delete_section_btn.disabled = false
	create_room_btn.disabled = false
	if export_grades_btn:
		export_grades_btn.disabled = false
	if dashboard_btn:
		dashboard_btn.disabled = false

func _show_no_selection() -> void:
	section_name_label.text = "Select a section"
	detail_stats.text = ""
	search_box.text = ""
	
	for child in student_list_container.get_children():
		child.queue_free()
	
	empty_state.visible = false
	
	add_student_btn.disabled = true
	import_more_btn.disabled = true
	export_btn.disabled = true
	delete_section_btn.disabled = true
	create_room_btn.disabled = true
	if export_grades_btn:
		export_grades_btn.disabled = true
	if dashboard_btn:
		dashboard_btn.disabled = true

# ─────────────────────────────────────────────────────────────
# DETAIL PANEL
# ─────────────────────────────────────────────────────────────

func _refresh_detail_panel() -> void:
	if _selected_section_id.is_empty():
		_show_no_selection()
		return
	
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	if section.is_empty():
		_show_no_selection()
		return
	
	section_name_label.text = "%s (%s)" % [section.get("name", ""), section.get("school_year", "")]
	
	var counts: Dictionary = StudentDatabase.get_gender_counts(_selected_section_id)
	var total: int = counts.male + counts.female + counts.other
	detail_stats.text = "Total: %d students • %d Male • %d Female" % [total, counts.male, counts.female]
	
	_refresh_student_list(search_box.text)

func _refresh_student_list(search_query: String = "") -> void:
	for child in student_list_container.get_children():
		child.queue_free()
	
	var students: Array
	if search_query.is_empty():
		students = StudentDatabase.get_students_in_section(_selected_section_id)
	else:
		students = StudentDatabase.search_students(_selected_section_id, search_query)
	
	if students.is_empty():
		empty_state.visible = true
		return
	
	empty_state.visible = false
	
	# Header row
	var header := _create_student_row("#", "Student Number", "Name", "Gender", true)
	student_list_container.add_child(header)
	
	# Student rows
	for i in range(students.size()):
		var s: Dictionary = students[i]
		var row := _create_student_row(
			str(i + 1),
			s.get("number", ""),
			s.get("name", ""),
			s.get("gender", ""),
			false,
			s.get("number", "")
		)
		student_list_container.add_child(row)

func _create_student_row(num: String, student_num: String, student_name: String, gender: String, is_header: bool, student_id: String = "") -> HBoxContainer:
	var row_scene: PackedScene = load("res://scene/ui_components/student_row_item.tscn")
	var row: HBoxContainer = row_scene.instantiate()
	
	var num_lbl = row.get_node("NumLabel")
	var s_num_lbl = row.get_node("StudentNumLabel")
	var name_lbl = row.get_node("NameLabel")
	var gender_lbl = row.get_node("GenderLabel")
	var act_cont = row.get_node("ActionsContainer")
	var perf_btn = row.get_node("ActionsContainer/PerfBtn")
	var del_btn = row.get_node("ActionsContainer/DelBtn")
	
	num_lbl.text = num
	s_num_lbl.text = student_num
	name_lbl.text = student_name
	gender_lbl.text = gender
	
	var font_color := Color(0.8, 0.8, 0.8) if is_header else Color(1, 1, 1)
	num_lbl.add_theme_color_override("font_color", font_color)
	s_num_lbl.add_theme_color_override("font_color", font_color)
	name_lbl.add_theme_color_override("font_color", font_color)
	gender_lbl.add_theme_color_override("font_color", font_color)
	
	if is_header or student_id.is_empty():
		perf_btn.visible = false
		del_btn.visible = false
	else:
		perf_btn.pressed.connect(_on_view_performance.bind(student_id, student_name))
		del_btn.pressed.connect(_on_remove_student.bind(student_id))
	
	return row

func _on_search_changed(new_text: String) -> void:
	_refresh_student_list(new_text)

func _on_remove_student(student_number: String) -> void:
	StudentDatabase.remove_student(_selected_section_id, student_number)
	_refresh_detail_panel()
	_refresh_section_list()
	_update_global_stats()

# ─────────────────────────────────────────────────────────────
# DIALOGS & ACTIONS
# ─────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	# Batch sync to Firestore before leaving
	StudentDatabase.sync_to_firestore()
	back_pressed.emit()
	if has_meta("is_overlay") and get_meta("is_overlay"):
		queue_free()
	else:
		get_tree().change_scene_to_file(_return_scene)

func _on_new_section_pressed() -> void:
	var dialog_scene = preload("res://scene/ui_components/dialog_new_section.tscn")
	var dialog = dialog_scene.instantiate()
	add_child(dialog)
	
	var name_input = dialog.get_node("ColorRect/Panel/VBox/Margin/FormVBox/Fields/NameInput")
	var year_input = dialog.get_node("ColorRect/Panel/VBox/Margin/FormVBox/Fields/YearInput")
	var cancel_btn = dialog.get_node("ColorRect/Panel/VBox/Buttons/CancelBtn")
	var confirm_btn = dialog.get_node("ColorRect/Panel/VBox/Buttons/ConfirmBtn")
	
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	confirm_btn.pressed.connect(func():
		_on_new_section_confirmed_custom(name_input.text, year_input.text)
		dialog.queue_free()
	)

func _on_new_section_confirmed_custom(section_name: String, school_year: String) -> void:
	section_name = section_name.strip_edges()
	school_year = school_year.strip_edges()
	
	if section_name.is_empty():
		return
	
	var section_id: String = StudentDatabase.create_section(section_name, school_year)
	_refresh_section_list()
	_update_global_stats()
	_select_section(section_id)

func _on_import_pressed() -> void:
	_is_new_import = true
	_import_target_section_id = ""
	file_dialog.popup_centered()

func _on_import_more_pressed() -> void:
	_is_new_import = false
	_import_target_section_id = _selected_section_id
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	# Open import wizard with the selected file
	var wizard_scene := preload("res://scene/import_wizard.tscn")
	var wizard: Control = wizard_scene.instantiate()
	
	wizard.set_meta("file_path", path)
	wizard.set_meta("is_new_section", _is_new_import)
	wizard.set_meta("target_section_id", _import_target_section_id)
	
	wizard.import_completed.connect(_on_import_completed)
	wizard.import_cancelled.connect(_on_import_cancelled)
	
	add_child(wizard)
	wizard.start_import(path)

func _on_import_completed(section_id: String, result: Dictionary) -> void:
	_refresh_section_list()
	_update_global_stats()
	_select_section(section_id)

func _on_import_cancelled() -> void:
	pass  # Just close wizard

func _on_add_student_pressed() -> void:
	var dialog_scene = preload("res://scene/ui_components/dialog_add_student.tscn")
	var dialog = dialog_scene.instantiate()
	add_child(dialog)
	
	var num_input = dialog.get_node("ColorRect/Panel/VBox/Margin/FormVBox/Fields/NumInput")
	var name_input = dialog.get_node("ColorRect/Panel/VBox/Margin/FormVBox/Fields/NameInput")
	var gender_input = dialog.get_node("ColorRect/Panel/VBox/Margin/FormVBox/Fields/GenderInput")
	
	var cancel_btn = dialog.get_node("ColorRect/Panel/VBox/Buttons/CancelBtn")
	var confirm_btn = dialog.get_node("ColorRect/Panel/VBox/Buttons/ConfirmBtn")
	
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	confirm_btn.pressed.connect(func():
		_on_add_student_confirmed_custom(num_input.text, name_input.text, gender_input.text)
		dialog.queue_free()
	)

func _on_add_student_confirmed_custom(number: String, student_name: String, gender: String) -> void:
	number = number.strip_edges()
	student_name = student_name.strip_edges()
	gender = gender.strip_edges().to_upper()
	
	if number.is_empty():
		return
	
	StudentDatabase.add_single_student(_selected_section_id, number, student_name, gender)
	_refresh_detail_panel()
	_refresh_section_list()
	_update_global_stats()

func _on_export_pressed() -> void:
	var students: Array = StudentDatabase.get_students_in_section(_selected_section_id)
	if students.is_empty():
		return
	
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	var filename := "%s_%s.csv" % [section.get("name", "export").replace(" ", "_"), section.get("school_year", "")]
	
	# Build CSV content
	var csv := "Student Number,Name,Gender\n"
	for s in students:
		csv += '"%s","%s","%s"\n' % [s.get("number", ""), s.get("name", ""), s.get("gender", "")]
	
	# Save to user directory
	var path := "user://%s" % filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(csv)
		file.close()
		OS.shell_open(ProjectSettings.globalize_path("user://"))

func _on_delete_section_pressed() -> void:
	var dialog_scene = preload("res://scene/ui_components/dialog_delete_confirm.tscn")
	var dialog = dialog_scene.instantiate()
	add_child(dialog)
	
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	var msg_label = dialog.get_node("ColorRect/Panel/VBox/Margin/MessageLabel")
	msg_label.text = "Are you sure you want to delete '%s'?\nThis will remove all %d students in this section." % [
		section.get("name", ""),
		section.get("students", []).size()
	]
	
	var cancel_btn = dialog.get_node("ColorRect/Panel/VBox/Buttons/CancelBtn")
	var confirm_btn = dialog.get_node("ColorRect/Panel/VBox/Buttons/ConfirmBtn")
	
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	confirm_btn.pressed.connect(func():
		_on_delete_confirmed()
		dialog.queue_free()
	)

func _on_delete_confirmed() -> void:
	StudentDatabase.delete_section(_selected_section_id)
	_selected_section_id = ""
	_refresh_section_list()
	_update_global_stats()
	_show_no_selection()

func _build_dynamic_actions_row() -> void:
	var detail_vbox: VBoxContainer = $MainContainer/ContentArea/DetailPanel/DetailVBox
	var detail_actions: HBoxContainer = $MainContainer/ContentArea/DetailPanel/DetailVBox/DetailActions
	if not detail_vbox or not detail_actions:
		return
	
	var row_scene: PackedScene = load("res://scene/ui_components/section_actions_row.tscn")
	dynamic_actions_row = row_scene.instantiate()
	
	# Insert right after DetailActions
	var actions_idx := detail_actions.get_index()
	detail_vbox.add_child(dynamic_actions_row)
	detail_vbox.move_child(dynamic_actions_row, actions_idx + 1)
	
	create_room_btn = dynamic_actions_row.get_node("CreateRoomBtn")
	export_grades_btn = dynamic_actions_row.get_node("ExportBtn")
	dashboard_btn = dynamic_actions_row.get_node("DashboardBtn")
	
	create_room_btn.pressed.connect(_on_create_room_for_section)
	export_grades_btn.pressed.connect(_on_export_grades_pressed)
	dashboard_btn.pressed.connect(_on_dashboard_pressed)
	
	# Initial state
	create_room_btn.disabled = true
	export_grades_btn.disabled = true
	dashboard_btn.disabled = true

func _build_create_room_button() -> void:
	pass

func _build_export_grades_button() -> void:
	pass

func _build_dashboard_button() -> void:
	pass

# ─────────────────────────────────────────────────────────────
# CREATE ROOM FOR SECTION
# ─────────────────────────────────────────────────────────────

func _on_create_room_for_section() -> void:
	if _selected_section_id.is_empty():
		return
	
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	if section.is_empty():
		return
	
	if has_meta("is_overlay") and get_meta("is_overlay"):
		var p = get_parent()
		while p != null:
			if p.has_method("_handle_section_prefill"):
				p._handle_section_prefill(_selected_section_id, section.get("name", ""), section.get("students", []).size())
				queue_free()
				return
			p = p.get_parent()
	
	# Pass section info to TeacherCreateRoom via tree meta
	get_tree().set_meta("prefill_section_id", _selected_section_id)
	get_tree().set_meta("prefill_section_name", section.get("name", ""))
	get_tree().set_meta("prefill_student_count", section.get("students", []).size())
	get_tree().set_meta("section_manager_return", "res://scene/section_manager.tscn")
	get_tree().change_scene_to_file("res://scene/TeacherCreateRoom.tscn")

# ─────────────────────────────────────────────────────────────
# STATS
# ─────────────────────────────────────────────────────────────

func _update_global_stats() -> void:
	var section_count: int = StudentDatabase.get_total_sections()
	var student_count: int = StudentDatabase.get_total_students()
	stats_label.text = "%d section%s • %d student%s" % [
		section_count, "" if section_count == 1 else "s",
		student_count, "" if student_count == 1 else "s"
	]

func _on_firestore_loaded(success: bool) -> void:
	if success:
		print("[SectionManager] Firestore data loaded, refreshing UI.")
		_refresh_section_list()
		_update_global_stats()
		if not _selected_section_id.is_empty():
			_refresh_detail_panel()
	else:
		print("[SectionManager] Firestore load failed, using local data.")

# ─────────────────────────────────────────────────────────────
# STUDENT PERFORMANCE CARD
# ─────────────────────────────────────────────────────────────

const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/capstone-823dc/databases/(default)/documents"

func _on_view_performance(student_number: String, student_name: String) -> void:
	print("[SectionManager] Viewing performance for: %s (%s)" % [student_name, student_number])
	_show_performance_popup(student_number, student_name)

func _show_performance_popup(student_number: String, student_name: String) -> void:
	# Remove old popup if any
	var old: Node = get_node_or_null("PerfPopup")
	if old:
		old.queue_free()
	
	var popup_scene: PackedScene = load("res://scene/ui_components/student_perf_popup.tscn")
	var backdrop: ColorRect = popup_scene.instantiate()
	backdrop.name = "PerfPopup"
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	
	var title = backdrop.get_node("Panel/MainVBox/HeaderRow/TitleLabel")
	var close_btn = backdrop.get_node("Panel/MainVBox/HeaderRow/CloseBtn")
	var info_label = backdrop.get_node("Panel/MainVBox/InfoLabel")
	
	title.text = " %s" % student_name if not student_name.is_empty() else "👤 %s" % student_number
	close_btn.pressed.connect(func(): backdrop.queue_free())
	
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	info_label.text = " %s • #%s" % [section.get("name", ""), student_number]
	
	# Fetch room results from Firestore
	_fetch_room_results_for_student(backdrop, student_number, student_name)

func _fetch_room_results_for_student(popup: Control, student_number: String, student_name: String) -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		_populate_performance_results(popup, student_number, student_name, {})
		return
	
	var url := "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := ["Authorization: Bearer %s" % Auth.current_id_token]
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if not is_instance_valid(popup):
			return
		
		var all_results := {}
		var room_history_data: Array = []
		
		if code == 200:
			var json: Variant = JSON.parse_string(resp_body.get_string_from_utf8())
			if json != null and json.has("fields"):
				var fields: Dictionary = json["fields"]
				
				# Parse room_results
				if fields.has("room_results"):
					var results_map: Dictionary = fields["room_results"].get("mapValue", {}).get("fields", {})
					for room_code in results_map:
						var json_str: String = results_map[room_code].get("stringValue", "")
						if not json_str.is_empty():
							var data: Variant = JSON.parse_string(json_str)
							if typeof(data) == TYPE_DICTIONARY:
								all_results[room_code] = data
				
				# Parse room_history for room names
				if fields.has("room_history"):
					var arr: Variant = fields["room_history"].get("arrayValue", {}).get("values", [])
					for item in arr:
						var rf: Variant = item.get("mapValue", {}).get("fields", {})
						room_history_data.append({
							"room_code": rf.get("room_code", {}).get("stringValue", ""),
							"room_name": rf.get("room_name", {}).get("stringValue", ""),
							"game_name": rf.get("game_name", {}).get("stringValue", ""),
							"category": rf.get("category", {}).get("stringValue", ""),
							"created_at": rf.get("created_at", {}).get("timestampValue", "")
						})
		
		_populate_performance_results(popup, student_number, student_name, all_results, room_history_data)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _entry_matches_student(entry: Dictionary, student_number: String, student_name: String) -> bool:
	var search_num := student_number.to_upper().strip_edges()
	var search_name := student_name.to_lower().strip_edges()
	var entry_student_num := str(entry.get("student_number", "")).to_upper().strip_edges()

	# Preferred match: authoritative student number from server leaderboard entry.
	if not search_num.is_empty() and not entry_student_num.is_empty() and entry_student_num == search_num:
		return true

	# Backward-compatible fallback for older cached results that don't include student_number.
	var username := str(entry.get("username", "")).to_lower()
	if not search_num.is_empty() and username.contains(search_num.to_lower()):
		return true
	if not search_name.is_empty() and search_name.length() >= 3 and username.contains(search_name):
		return true

	return false

func _populate_performance_results(popup: Control, student_number: String, student_name: String, all_results: Dictionary, room_history: Array = []) -> void:
	if not is_instance_valid(popup):
		return
	
	# Build room_code → room_name lookup
	var room_names: Dictionary = {}
	var room_games: Dictionary = {}
	var room_dates: Dictionary = {}
	for rh in room_history:
		var code: String = str(rh.get("room_code", "")).replace("/", "_")
		room_names[code] = str(rh.get("room_name", ""))
		room_games[code] = str(rh.get("game_name", ""))
		room_dates[code] = str(rh.get("created_at", ""))
	
	# Find student entries across all rooms
	var student_results: Array = []
	
	for room_code in all_results:
		var data: Dictionary = all_results[room_code]
		var leaderboard: Array = data.get("leaderboard", [])
		
		for entry in leaderboard:
			if _entry_matches_student(entry, student_number, student_name):
				var username: String = str(entry.get("username", ""))
				student_results.append({
					"room_code": room_code,
					"room_name": room_names.get(room_code, room_code),
					"game_name": room_games.get(room_code, ""),
					"date": room_dates.get(room_code, ""),
					"username": username,
					"score": int(entry.get("score", 0)),
					"finished": entry.get("finished", false),
					"rank": int(entry.get("rank", 0))
				})
	
	# Update UI
	var loading: Node = popup.get_node_or_null("PanelContainer/VBoxContainer/LoadingLabel")
	if not loading:
		# Try alternative path
		for child in popup.get_children():
			var pc: PanelContainer = child as PanelContainer
			if pc:
				for c2 in pc.get_children():
					var vb: VBoxContainer = c2 as VBoxContainer
					if vb:
						loading = vb.get_node_or_null("LoadingLabel")
	
	var scroll: ScrollContainer = null
	var results_vbox: VBoxContainer = null
	for child in popup.get_children():
		var pc: PanelContainer = child as PanelContainer
		if pc:
			for c2 in pc.get_children():
				var vb: VBoxContainer = c2 as VBoxContainer
				if vb:
					scroll = vb.get_node_or_null("ResultsScroll")
					if scroll:
						results_vbox = scroll.get_node_or_null("ResultsVBox")
	
	if loading:
		loading.visible = false
	if scroll:
		scroll.visible = true
	if not results_vbox:
		return
	
	# Clear results container
	for child in results_vbox.get_children():
		child.queue_free()
	
	if student_results.is_empty():
		# Summary stats
		var empty_summary := Label.new()
		empty_summary.text = "🎮 Games Played: 0   •   ⭐ Average: N/A"
		empty_summary.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		empty_summary.add_theme_font_size_override("font_size", 14)
		results_vbox.add_child(empty_summary)
		
		var empty_label := Label.new()
		empty_label.text = "\n💭 No game results found for this student yet.\n\nPossible reasons:\n• Student hasn't joined any rooms\n• Student's username doesn't match their name/number"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		results_vbox.add_child(empty_label)
		return
	
	# Calculate stats
	var total_score := 0
	var finished_count := 0
	for r in student_results:
		total_score += r["score"]
		if r["finished"]:
			finished_count += 1
	var avg_score: float = float(total_score) / float(student_results.size()) if not student_results.is_empty() else 0.0
	
	# Summary stats bar
	var summary := Label.new()
	summary.text = "🎮 Games: %d   •   ✅ Finished: %d   •   ⭐ Avg Score: %.0f" % [student_results.size(), finished_count, avg_score]
	summary.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	summary.add_theme_font_size_override("font_size", 14)
	results_vbox.add_child(summary)
	
	# Divider
	var div2 := HSeparator.new()
	var div2_sb := StyleBoxLine.new()
	div2_sb.color = Color(0.2, 0.3, 0.4, 0.5)
	div2.add_theme_stylebox_override("separator", div2_sb)
	results_vbox.add_child(div2)
	
	# Result rows
	for r in student_results:
		var card := PanelContainer.new()
		var card_sb := StyleBoxFlat.new()
		card_sb.bg_color = Color(0.1, 0.12, 0.18, 0.8)
		card_sb.set_corner_radius_all(8)
		card_sb.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", card_sb)
		
		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)
		
		# Room name + game
		var room_label := Label.new()
		var display_name: String = r.get("room_name", r["room_code"])
		var game_name: String = r.get("game_name", "")
		if not game_name.is_empty():
			room_label.text = "🎮 %s • %s" % [display_name, game_name]
		else:
			room_label.text = "🎮 %s" % display_name
		room_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		room_label.add_theme_font_size_override("font_size", 13)
		room_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card_vbox.add_child(room_label)
		
		# Score + status row
		var score_row := HBoxContainer.new()
		score_row.add_theme_constant_override("separation", 12)
		
		var score_label := Label.new()
		score_label.text = "⭐ Score: %d" % r["score"]
		if r["finished"]:
			score_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		else:
			score_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		score_label.add_theme_font_size_override("font_size", 13)
		score_row.add_child(score_label)
		
		var status_label := Label.new()
		if r["finished"]:
			status_label.text = "✅ Completed"
			status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		else:
			status_label.text = "⏳ In Progress"
			status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
		status_label.add_theme_font_size_override("font_size", 12)
		score_row.add_child(status_label)
		
		if r["rank"] > 0:
			var rank_label := Label.new()
			var rank_emojis := ["🥇", "🥈", "🥉"]
			if r["rank"] <= 3:
				rank_label.text = rank_emojis[r["rank"] - 1]
			else:
				rank_label.text = "#%d" % r["rank"]
			rank_label.add_theme_font_size_override("font_size", 13)
			score_row.add_child(rank_label)
		
		card_vbox.add_child(score_row)
		
		# Date (if available)
		var date_str: String = r.get("date", "")
		if not date_str.is_empty():
			var date_label := Label.new()
			# Format: 2026-04-05T14:30:00Z → Apr 5, 2026
			var short_date := date_str.substr(0, 10) if date_str.length() >= 10 else date_str
			date_label.text = "📅 %s" % short_date
			date_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			date_label.add_theme_font_size_override("font_size", 11)
			card_vbox.add_child(date_label)
		
		results_vbox.add_child(card)

# ─────────────────────────────────────────────────────────────
# EXPORT GRADES
# ─────────────────────────────────────────────────────────────

func _on_export_grades_pressed() -> void:
	if _selected_section_id.is_empty():
		return
	
	# Disable button while exporting
	if export_grades_btn:
		export_grades_btn.disabled = true
		export_grades_btn.text = "⏳ Exporting..."
	
	# Fetch room results from Firestore
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		_generate_grades_csv({}, [])
		return
	
	var url := "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := ["Authorization: Bearer %s" % Auth.current_id_token]
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		
		var all_results := {}
		var room_history_data: Array = []
		
		if code == 200:
			var json: Variant = JSON.parse_string(resp_body.get_string_from_utf8())
			if json != null and json.has("fields"):
				var fields: Dictionary = json["fields"]
				
				if fields.has("room_results"):
					var results_map: Dictionary = fields["room_results"].get("mapValue", {}).get("fields", {})
					for room_code in results_map:
						var json_str: String = results_map[room_code].get("stringValue", "")
						if not json_str.is_empty():
							var data: Variant = JSON.parse_string(json_str)
							if typeof(data) == TYPE_DICTIONARY:
								all_results[room_code] = data
				
				if fields.has("room_history"):
					var arr: Variant = fields["room_history"].get("arrayValue", {}).get("values", [])
					for item in arr:
						var rf: Variant = item.get("mapValue", {}).get("fields", {})
						room_history_data.append({
							"room_code": rf.get("room_code", {}).get("stringValue", ""),
							"room_name": rf.get("room_name", {}).get("stringValue", ""),
							"game_name": rf.get("game_name", {}).get("stringValue", ""),
						})
		
		_generate_grades_csv(all_results, room_history_data)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _generate_grades_csv(all_results: Dictionary, room_history: Array) -> void:
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	var students: Array = section.get("students", [])
	var section_name: String = section.get("name", "export")
	
	# Build room_code → display name lookup
	var room_names: Dictionary = {}
	for rh in room_history:
		var code: String = str(rh.get("room_code", "")).replace("/", "_")
		var name: String = str(rh.get("room_name", ""))
		var game: String = str(rh.get("game_name", ""))
		if not game.is_empty():
			room_names[code] = "%s (%s)" % [name, game]
		else:
			room_names[code] = name
	
	# Find which rooms have any student from this section
	var relevant_rooms: Array = []  # room codes that have section students
	var student_scores: Dictionary = {}  # { student_number: { room_code: score } }
	
	for s in students:
		student_scores[s.get("number", "")] = {}
	
	for room_code in all_results:
		var data: Dictionary = all_results[room_code]
		var leaderboard: Array = data.get("leaderboard", [])
		var room_has_students := false
		
		for entry in leaderboard:
			var score: int = int(entry.get("score", 0))
			
			# Try to match against each student
			for s in students:
				if _entry_matches_student(entry, str(s.get("number", "")), str(s.get("name", ""))):
					student_scores[s.get("number", "")][room_code] = score
					room_has_students = true
		
		if room_has_students and room_code not in relevant_rooms:
			relevant_rooms.append(room_code)
	
	# Build CSV
	var csv := ""
	
	# Header row
	var header_parts: Array = ['"Student Number"', '"Name"', '"Gender"']
	for rc in relevant_rooms:
		var display: String = str(room_names.get(rc, rc))
		header_parts.append('"%s"' % display.replace('"', "'"))
	header_parts.append('"Average"')
	header_parts.append('"Games Played"')
	csv += ",".join(header_parts) + "\n"
	
	# Student rows
	for s in students:
		var snum: String = s.get("number", "")
		var sname: String = s.get("name", "")
		var sgender: String = s.get("gender", "")
		var scores: Dictionary = student_scores.get(snum, {})
		
		var row_parts: Array = ['"%s"' % snum, '"%s"' % sname, '"%s"' % sgender]
		
		var total := 0
		var count := 0
		for rc in relevant_rooms:
			if scores.has(rc):
				row_parts.append(str(scores[rc]))
				total += scores[rc]
				count += 1
			else:
				row_parts.append("N/A")
		
		# Average
		if count > 0:
			row_parts.append("%.1f" % (float(total) / float(count)))
		else:
			row_parts.append("N/A")
		
		# Games played
		row_parts.append(str(count))
		
		csv += ",".join(row_parts) + "\n"
	
	# Save file
	var safe_name := section_name.replace(" ", "_").replace("/", "-")
	var now := Time.get_datetime_dict_from_system()
	var date_str := "%04d%02d%02d" % [now.year, now.month, now.day]
	var filename := "Grades_%s_%s.csv" % [safe_name, date_str]
	var path := "user://%s" % filename
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(csv)
		file.close()
		print("[SectionManager] ✅ Grades exported to: %s" % path)
		OS.shell_open(ProjectSettings.globalize_path("user://"))
	else:
		push_error("[SectionManager] ❌ Failed to write grades file")
	
	# Reset button
	if export_grades_btn:
		export_grades_btn.disabled = false
		export_grades_btn.text = "📊 Export Grades"

# ─────────────────────────────────────────────────────────────
# SECTION DASHBOARD
# ─────────────────────────────────────────────────────────────

func _on_dashboard_pressed() -> void:
	if _selected_section_id.is_empty():
		return
	
	# Remove old popup
	var old_popup: Node = get_node_or_null("DashPopup")
	if old_popup:
		old_popup.queue_free()
	
	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.name = "DashPopup"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	
	# Popup panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_top = -270
	panel.offset_right = 340
	panel.offset_bottom = 270
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.06, 0.04, 0.14, 0.97)
	panel_sb.border_color = Color(0.6, 0.3, 0.9, 0.6)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(14)
	panel_sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_sb)
	backdrop.add_child(panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)
	
	# Header
	var section: Dictionary = StudentDatabase.get_section(_selected_section_id)
	var header_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "📊 %s Dashboard" % section.get("name", "")
	title.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	close_btn.pressed.connect(func(): backdrop.queue_free())
	header_row.add_child(close_btn)
	main_vbox.add_child(header_row)
	
	# Section info
	var students: Array = section.get("students", [])
	var info := Label.new()
	var genders: Dictionary = StudentDatabase.get_gender_counts(_selected_section_id)
	info.text = "🏫 %s • %d students • 👦 %d M • 👧 %d F" % [section.get("school_year", ""), students.size(), genders.get("male", 0), genders.get("female", 0)]
	info.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	info.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(info)
	
	# Divider
	var div := HSeparator.new()
	var div_sb := StyleBoxLine.new()
	div_sb.color = Color(0.4, 0.2, 0.6, 0.4)
	div.add_theme_stylebox_override("separator", div_sb)
	main_vbox.add_child(div)
	
	# Loading
	var loading := Label.new()
	loading.name = "DashLoading"
	loading.text = "⏳ Analyzing performance data..."
	loading.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	loading.add_theme_font_size_override("font_size", 13)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(loading)
	
	# Results area
	var scroll := ScrollContainer.new()
	scroll.name = "DashScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	main_vbox.add_child(scroll)
	
	var content := VBoxContainer.new()
	content.name = "DashContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	
	# Fetch data
	_fetch_dashboard_data(backdrop, students)

func _fetch_dashboard_data(popup: Control, students: Array) -> void:
	if Auth.current_local_id == "" or Auth.current_id_token == "":
		_populate_dashboard(popup, students, {}, [])
		return
	
	var url := "%s/users/%s" % [FIRESTORE_URL, Auth.current_local_id]
	var headers := ["Authorization: Bearer %s" % Auth.current_id_token]
	
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, resp_body):
		http.queue_free()
		if not is_instance_valid(popup):
			return
		
		var all_results: Dictionary = {}
		var room_history_data: Array = []
		
		if code == 200:
			var json: Variant = JSON.parse_string(resp_body.get_string_from_utf8())
			if json != null and json.has("fields"):
				var fields: Dictionary = json["fields"]
				
				if fields.has("room_results"):
					var results_map: Dictionary = fields["room_results"].get("mapValue", {}).get("fields", {})
					for room_code in results_map:
						var json_str: String = results_map[room_code].get("stringValue", "")
						if not json_str.is_empty():
							var data: Variant = JSON.parse_string(json_str)
							if typeof(data) == TYPE_DICTIONARY:
								all_results[room_code] = data
				
				if fields.has("room_history"):
					var arr: Variant = fields["room_history"].get("arrayValue", {}).get("values", [])
					for item in arr:
						var rf: Variant = item.get("mapValue", {}).get("fields", {})
						room_history_data.append({
							"room_code": rf.get("room_code", {}).get("stringValue", ""),
							"room_name": rf.get("room_name", {}).get("stringValue", ""),
							"game_name": rf.get("game_name", {}).get("stringValue", ""),
						})
		
		_populate_dashboard(popup, students, all_results, room_history_data)
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _populate_dashboard(popup: Control, students: Array, all_results: Dictionary, room_history: Array) -> void:
	if not is_instance_valid(popup):
		return
	
	# Find scroll/content nodes
	var loading_node: Node = null
	var scroll_node: ScrollContainer = null
	var content_node: VBoxContainer = null
	
	for child in popup.get_children():
		var pc: PanelContainer = child as PanelContainer
		if pc:
			for c2 in pc.get_children():
				var vb: VBoxContainer = c2 as VBoxContainer
				if vb:
					loading_node = vb.get_node_or_null("DashLoading")
					scroll_node = vb.get_node_or_null("DashScroll") as ScrollContainer
					if scroll_node:
						content_node = scroll_node.get_node_or_null("DashContent") as VBoxContainer
	
	if loading_node:
		loading_node.visible = false
	if scroll_node:
		scroll_node.visible = true
	if not content_node:
		return
	
	# Build room name lookup
	var room_names: Dictionary = {}
	for rh in room_history:
		var code: String = str(rh.get("room_code", "")).replace("/", "_")
		var rname: String = str(rh.get("room_name", ""))
		var game: String = str(rh.get("game_name", ""))
		if not game.is_empty():
			room_names[code] = "%s (%s)" % [rname, game]
		else:
			room_names[code] = rname
	
	# Match students to results
	var active_students: Array = []
	var inactive_students: Array = []
	var student_avg_scores: Dictionary = {}  # { student_number: avg_score }
	var all_scores: Array = []
	
	for s in students:
		var snum: String = str(s.get("number", "")).strip_edges()
		var sname: String = str(s.get("name", "")).strip_edges()
		var scores: Array = []
		
		for room_code in all_results:
			var data: Dictionary = all_results[room_code]
			var leaderboard: Array = data.get("leaderboard", [])
			
			for entry in leaderboard:
				if _entry_matches_student(entry, snum, sname):
					scores.append(int(entry.get("score", 0)))
		
		if scores.is_empty():
			inactive_students.append(s)
		else:
			active_students.append(s)
			var total := 0
			for sc in scores:
				total += sc
				all_scores.append(sc)
			student_avg_scores[snum] = float(total) / float(scores.size())
	
	# Calculate class average
	var class_avg := 0.0
	if not all_scores.is_empty():
		var total := 0
		for sc in all_scores:
			total += sc
		class_avg = float(total) / float(all_scores.size())
	
	# Find top performer and lowest scorer
	var top_student := ""
	var top_score := 0.0
	var low_student := ""
	var low_score := 999999.0
	
	for snum in student_avg_scores:
		var avg: float = student_avg_scores[snum]
		if avg > top_score:
			top_score = avg
			# Find name
			for s in students:
				if s.get("number", "") == snum:
					top_student = "%s (%s)" % [s.get("name", ""), snum]
					break
		if avg < low_score:
			low_score = avg
			for s in students:
				if s.get("number", "") == snum:
					low_student = "%s (%s)" % [s.get("name", ""), snum]
					break
	
	# === BUILD UI ===
	
	# Stats grid (2x3)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	
	# Stat cards
	var active_card := _create_stat_card(str(active_students.size()), "🟢 Active", Color(0.3, 0.9, 0.5))
	var inactive_card := _create_stat_card(str(inactive_students.size()), "🔴 Inactive", Color(1.0, 0.4, 0.4))
	var avg_text := "%.0f pts" % class_avg if not all_scores.is_empty() else "N/A"
	var avg_card := _create_stat_card(avg_text, "⭐ Class Avg", Color(1.0, 0.85, 0.3))
	
	grid.add_child(active_card)
	grid.add_child(inactive_card)
	grid.add_child(avg_card)
	
	content_node.add_child(grid)
	
	# Top performer & needs help
	if not top_student.is_empty():
		var highlights := VBoxContainer.new()
		highlights.add_theme_constant_override("separation", 4)
		
		var top_lbl := Label.new()
		top_lbl.text = "🏆 Top Performer: %s • %.0f avg pts" % [top_student, top_score]
		top_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		top_lbl.add_theme_font_size_override("font_size", 14)
		highlights.add_child(top_lbl)
		
		if not low_student.is_empty() and low_student != top_student:
			var low_lbl := Label.new()
			low_lbl.text = "⚠️ Needs Help: %s • %.0f avg pts" % [low_student, low_score]
			low_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			low_lbl.add_theme_font_size_override("font_size", 14)
			highlights.add_child(low_lbl)
		
		content_node.add_child(highlights)
	
	# Divider
	var div2 := HSeparator.new()
	var div2_sb := StyleBoxLine.new()
	div2_sb.color = Color(0.3, 0.2, 0.5, 0.3)
	div2.add_theme_stylebox_override("separator", div2_sb)
	content_node.add_child(div2)
	
	# Inactive students list
	if not inactive_students.is_empty():
		var inactive_header := Label.new()
		inactive_header.text = "🔴 Inactive Students (%d)" % inactive_students.size()
		inactive_header.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		inactive_header.add_theme_font_size_override("font_size", 14)
		content_node.add_child(inactive_header)
		
		var inactive_list := Label.new()
		var names: Array = []
		for s in inactive_students:
			names.append("%s (%s)" % [s.get("name", ""), s.get("number", "")])
		inactive_list.text = "• " + "\n• ".join(names)
		inactive_list.add_theme_color_override("font_color", Color(0.55, 0.5, 0.6))
		inactive_list.add_theme_font_size_override("font_size", 12)
		inactive_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_node.add_child(inactive_list)
	else:
		var all_active := Label.new()
		all_active.text = "✅ All students have participated!"
		all_active.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		all_active.add_theme_font_size_override("font_size", 14)
		content_node.add_child(all_active)

func _create_stat_card(value_text: String, label_text: String, accent_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.06, 0.16, 0.9)
	csb.set_corner_radius_all(10)
	csb.set_content_margin_all(12)
	csb.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.3)
	csb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", csb)
	
	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 4)
	card.add_child(cvbox)
	
	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_color_override("font_color", accent_color)
	val_lbl.add_theme_font_size_override("font_size", 22)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cvbox.add_child(val_lbl)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cvbox.add_child(lbl)
	
	return card
