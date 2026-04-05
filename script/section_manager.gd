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

@onready var file_dialog: FileDialog = $FileDialog
@onready var new_section_dialog: ConfirmationDialog = $NewSectionDialog
@onready var delete_confirm_dialog: ConfirmationDialog = $DeleteConfirmDialog
@onready var add_student_dialog: ConfirmationDialog = $AddStudentDialog

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
	_refresh_section_list()
	_update_global_stats()
	_show_no_selection()

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
	new_section_dialog.confirmed.connect(_on_new_section_confirmed)
	delete_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_student_dialog.confirmed.connect(_on_add_student_confirmed)

# ─────────────────────────────────────────────────────────────
# SECTION LIST
# ─────────────────────────────────────────────────────────────

func _refresh_section_list() -> void:
	# Clear existing
	for child in section_list_container.get_children():
		child.queue_free()
	
	var sections := StudentDatabase.get_all_sections()
	
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
	var card := PanelContainer.new()
	card.set_meta("section_id", section["id"])
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	card.add_child(vbox)
	
	var name_label := Label.new()
	name_label.text = "📁 %s" % section.get("name", "Unnamed")
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var info_label := Label.new()
	var count: int = section.get("students", []).size()
	info_label.text = "%s • %d student%s" % [section.get("school_year", ""), count, "" if count == 1 else "s"]
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(info_label)
	
	# Make clickable
	card.gui_input.connect(_on_section_card_input.bind(section["id"]))
	card.mouse_entered.connect(func(): _highlight_card(card, true))
	card.mouse_exited.connect(func(): _highlight_card(card, section["id"] == _selected_section_id))
	
	# Highlight if selected
	if section["id"] == _selected_section_id:
		_highlight_card(card, true)
	
	return card

func _highlight_card(card: PanelContainer, highlight: bool) -> void:
	var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate()
	if highlight:
		style.bg_color = Color(0.2, 0.3, 0.4)
		style.border_color = Color(0.3, 0.6, 0.9)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 0
	card.add_theme_stylebox_override("panel", style)

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

# ─────────────────────────────────────────────────────────────
# DETAIL PANEL
# ─────────────────────────────────────────────────────────────

func _refresh_detail_panel() -> void:
	if _selected_section_id.is_empty():
		_show_no_selection()
		return
	
	var section := StudentDatabase.get_section(_selected_section_id)
	if section.is_empty():
		_show_no_selection()
		return
	
	section_name_label.text = "%s (%s)" % [section.get("name", ""), section.get("school_year", "")]
	
	var counts := StudentDatabase.get_gender_counts(_selected_section_id)
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
	var row := HBoxContainer.new()
	
	var style_color := Color(0.3, 0.3, 0.35) if is_header else Color(0.12, 0.12, 0.15)
	var font_color := Color(0.8, 0.8, 0.8) if is_header else Color(1, 1, 1)
	
	# Row number
	var num_label := Label.new()
	num_label.text = num
	num_label.custom_minimum_size = Vector2(40, 30)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.add_theme_color_override("font_color", font_color)
	row.add_child(num_label)
	
	# Student number
	var snum_label := Label.new()
	snum_label.text = student_num
	snum_label.custom_minimum_size = Vector2(120, 30)
	snum_label.add_theme_color_override("font_color", font_color)
	row.add_child(snum_label)
	
	# Name
	var name_label := Label.new()
	name_label.text = student_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2(200, 30)
	name_label.add_theme_color_override("font_color", font_color)
	row.add_child(name_label)
	
	# Gender
	var gender_label := Label.new()
	gender_label.text = gender
	gender_label.custom_minimum_size = Vector2(60, 30)
	gender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gender_label.add_theme_color_override("font_color", font_color)
	row.add_child(gender_label)
	
	# Delete button (not for header)
	if not is_header and not student_id.is_empty():
		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(30, 30)
		del_btn.pressed.connect(_on_remove_student.bind(student_id))
		row.add_child(del_btn)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(30, 30)
		row.add_child(spacer)
	
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
	back_pressed.emit()
	get_tree().change_scene_to_file(_return_scene)

func _on_new_section_pressed() -> void:
	var name_input: LineEdit = new_section_dialog.get_node("DialogVBox/NameInput")
	var year_input: LineEdit = new_section_dialog.get_node("DialogVBox/YearInput")
	name_input.text = ""
	year_input.text = "2025-2026"
	new_section_dialog.popup_centered()

func _on_new_section_confirmed() -> void:
	var name_input: LineEdit = new_section_dialog.get_node("DialogVBox/NameInput")
	var year_input: LineEdit = new_section_dialog.get_node("DialogVBox/YearInput")
	
	var section_name := name_input.text.strip_edges()
	var school_year := year_input.text.strip_edges()
	
	if section_name.is_empty():
		return
	
	var section_id := StudentDatabase.create_section(section_name, school_year)
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
	var num_input: LineEdit = add_student_dialog.get_node("DialogVBox/NumInput")
	var name_input: LineEdit = add_student_dialog.get_node("DialogVBox/StudentNameInput")
	var gender_input: LineEdit = add_student_dialog.get_node("DialogVBox/GenderInput")
	num_input.text = ""
	name_input.text = ""
	gender_input.text = ""
	add_student_dialog.popup_centered()

func _on_add_student_confirmed() -> void:
	var num_input: LineEdit = add_student_dialog.get_node("DialogVBox/NumInput")
	var name_input: LineEdit = add_student_dialog.get_node("DialogVBox/StudentNameInput")
	var gender_input: LineEdit = add_student_dialog.get_node("DialogVBox/GenderInput")
	
	var number := num_input.text.strip_edges()
	var student_name := name_input.text.strip_edges()
	var gender := gender_input.text.strip_edges().to_upper()
	
	if number.is_empty():
		return
	
	StudentDatabase.add_single_student(_selected_section_id, number, student_name, gender)
	_refresh_detail_panel()
	_refresh_section_list()
	_update_global_stats()

func _on_export_pressed() -> void:
	var students := StudentDatabase.get_students_in_section(_selected_section_id)
	if students.is_empty():
		return
	
	var section := StudentDatabase.get_section(_selected_section_id)
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
	var section := StudentDatabase.get_section(_selected_section_id)
	delete_confirm_dialog.dialog_text = "Are you sure you want to delete '%s'?\nThis will remove all %d students in this section." % [
		section.get("name", ""),
		section.get("students", []).size()
	]
	delete_confirm_dialog.popup_centered()

func _on_delete_confirmed() -> void:
	StudentDatabase.delete_section(_selected_section_id)
	_selected_section_id = ""
	_refresh_section_list()
	_update_global_stats()
	_show_no_selection()

# ─────────────────────────────────────────────────────────────
# STATS
# ─────────────────────────────────────────────────────────────

func _update_global_stats() -> void:
	var section_count := StudentDatabase.get_total_sections()
	var student_count := StudentDatabase.get_total_students()
	stats_label.text = "%d section%s • %d student%s" % [
		section_count, "" if section_count == 1 else "s",
		student_count, "" if student_count == 1 else "s"
	]
