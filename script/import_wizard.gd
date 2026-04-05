extends Control

## Import Wizard - Multi-step wizard for importing students from CSV/XLSX

signal import_completed(section_id: String, result: Dictionary)
signal import_cancelled

# UI References - Step navigation
@onready var title_label: Label = $WizardPanel/MainVBox/Header/Title
@onready var close_btn: Button = $WizardPanel/MainVBox/Header/CloseBtn
@onready var back_btn: Button = $WizardPanel/MainVBox/ButtonRow/BackBtn
@onready var cancel_btn: Button = $WizardPanel/MainVBox/ButtonRow/CancelBtn
@onready var next_btn: Button = $WizardPanel/MainVBox/ButtonRow/NextBtn

# Step containers
@onready var step1: VBoxContainer = $WizardPanel/MainVBox/StepContainer/Step1
@onready var step2: VBoxContainer = $WizardPanel/MainVBox/StepContainer/Step2
@onready var step3: VBoxContainer = $WizardPanel/MainVBox/StepContainer/Step3

# Step 1 UI
@onready var file_info_label: Label = $WizardPanel/MainVBox/StepContainer/Step1/FileInfoLabel
@onready var status_label: Label = $WizardPanel/MainVBox/StepContainer/Step1/StatusLabel
@onready var error_label: Label = $WizardPanel/MainVBox/StepContainer/Step1/ErrorLabel

# Step 2 UI
@onready var num_dropdown: OptionButton = $WizardPanel/MainVBox/StepContainer/Step2/MappingGrid/NumDropdown
@onready var name_dropdown: OptionButton = $WizardPanel/MainVBox/StepContainer/Step2/MappingGrid/NameDropdown
@onready var gender_dropdown: OptionButton = $WizardPanel/MainVBox/StepContainer/Step2/MappingGrid/GenderDropdown
@onready var preview_container: VBoxContainer = $WizardPanel/MainVBox/StepContainer/Step2/PreviewScroll/PreviewContainer

# Step 3 UI
@onready var summary_label: Label = $WizardPanel/MainVBox/StepContainer/Step3/SummaryLabel
@onready var existing_radio: CheckBox = $WizardPanel/MainVBox/StepContainer/Step3/ExistingRadio
@onready var existing_dropdown: OptionButton = $WizardPanel/MainVBox/StepContainer/Step3/ExistingDropdown
@onready var new_radio: CheckBox = $WizardPanel/MainVBox/StepContainer/Step3/NewRadio
@onready var new_name_input: LineEdit = $WizardPanel/MainVBox/StepContainer/Step3/NewSectionGrid/NewNameInput
@onready var new_year_input: LineEdit = $WizardPanel/MainVBox/StepContainer/Step3/NewSectionGrid/NewYearInput
@onready var skip_duplicates_check: CheckBox = $WizardPanel/MainVBox/StepContainer/Step3/SkipDuplicatesCheck

# State
var _current_step := 1
var _file_path := ""
var _parse_result: Dictionary = {}
var _column_mapping: Dictionary = {}
var _extracted_students: Array = []
var _importer: FileImporter

# From meta (set by section_manager)
var _is_new_section := true
var _target_section_id := ""

func _ready() -> void:
	_importer = FileImporter.new()
	_connect_signals()
	
	# Read meta from parent
	_is_new_section = get_meta("is_new_section", true)
	_target_section_id = get_meta("target_section_id", "")

func _connect_signals() -> void:
	close_btn.pressed.connect(_on_cancel)
	cancel_btn.pressed.connect(_on_cancel)
	back_btn.pressed.connect(_on_back)
	next_btn.pressed.connect(_on_next)
	
	existing_radio.toggled.connect(_on_existing_toggled)
	new_radio.toggled.connect(_on_new_toggled)
	
	num_dropdown.item_selected.connect(_on_mapping_changed)
	name_dropdown.item_selected.connect(_on_mapping_changed)
	gender_dropdown.item_selected.connect(_on_mapping_changed)

func start_import(file_path: String) -> void:
	_file_path = file_path
	_show_step(1)
	_parse_file()

# ─────────────────────────────────────────────────────────────
# STEP NAVIGATION
# ─────────────────────────────────────────────────────────────

func _show_step(step: int) -> void:
	_current_step = step
	
	step1.visible = step == 1
	step2.visible = step == 2
	step3.visible = step == 3
	
	back_btn.disabled = step == 1
	
	match step:
		1:
			title_label.text = "📥 Import Students - Step 1 of 3"
			next_btn.text = "Next →"
		2:
			title_label.text = "📥 Import Students - Step 2 of 3"
			next_btn.text = "Next →"
		3:
			title_label.text = "📥 Import Students - Step 3 of 3"
			next_btn.text = "✓ Import"

func _on_back() -> void:
	if _current_step > 1:
		_show_step(_current_step - 1)

func _on_next() -> void:
	match _current_step:
		1:
			if _parse_result.get("success", false):
				_setup_step2()
				_show_step(2)
		2:
			if _validate_mapping():
				_setup_step3()
				_show_step(3)
		3:
			_do_import()

func _on_cancel() -> void:
	import_cancelled.emit()
	queue_free()

# ─────────────────────────────────────────────────────────────
# STEP 1: PARSE FILE
# ─────────────────────────────────────────────────────────────

func _parse_file() -> void:
	file_info_label.text = "Parsing: %s" % _file_path.get_file()
	status_label.text = ""
	error_label.text = ""
	next_btn.disabled = true
	
	# Parse the file
	_parse_result = _importer.parse_file(_file_path)
	
	if _parse_result.get("success", false):
		var row_count: int = _parse_result.get("row_count", 0)
		var headers: Array = _parse_result.get("headers", [])
		
		status_label.text = "✓ Found %d rows with %d columns" % [row_count, headers.size()]
		error_label.text = ""
		next_btn.disabled = false
		
		# Auto-detect columns
		_column_mapping = _importer.detect_columns(headers)
	else:
		status_label.text = ""
		error_label.text = "✗ Error: %s" % _parse_result.get("error", "Unknown error")
		next_btn.disabled = true

# ─────────────────────────────────────────────────────────────
# STEP 2: COLUMN MAPPING
# ─────────────────────────────────────────────────────────────

func _setup_step2() -> void:
	var headers: Array = _parse_result.get("headers", [])
	
	# Clear and populate dropdowns
	num_dropdown.clear()
	name_dropdown.clear()
	gender_dropdown.clear()
	
	# Add "Not mapped" option for optional fields
	gender_dropdown.add_item("(Not mapped)", -1)
	
	for i in range(headers.size()):
		var header: String = str(headers[i])
		var display := "Column %d: %s" % [i + 1, header]
		num_dropdown.add_item(display, i)
		name_dropdown.add_item(display, i)
		gender_dropdown.add_item(display, i)
	
	# Set auto-detected selections
	if _column_mapping.get("number_col", -1) >= 0:
		num_dropdown.select(_column_mapping["number_col"])
	
	if _column_mapping.get("name_col", -1) >= 0:
		name_dropdown.select(_column_mapping["name_col"])
	
	if _column_mapping.get("gender_col", -1) >= 0:
		gender_dropdown.select(_column_mapping["gender_col"] + 1)  # +1 for "Not mapped" option
	else:
		gender_dropdown.select(0)  # Not mapped
	
	_update_preview()

func _on_mapping_changed(_index: int) -> void:
	_update_preview()

func _update_preview() -> void:
	# Get current mapping
	_column_mapping["number_col"] = num_dropdown.get_selected_id()
	_column_mapping["name_col"] = name_dropdown.get_selected_id()
	
	var gender_id := gender_dropdown.get_selected_id()
	_column_mapping["gender_col"] = gender_id if gender_id >= 0 else -1
	
	# Extract students for preview
	_extracted_students = _importer.extract_students(_parse_result, _column_mapping)
	
	# Clear preview
	for child in preview_container.get_children():
		child.queue_free()
	
	# Add header
	var header := _create_preview_row("Student Number", "Name", "Gender", true)
	preview_container.add_child(header)
	
	# Add first 5 rows
	var preview_count := mini(_extracted_students.size(), 5)
	for i in range(preview_count):
		var s: Dictionary = _extracted_students[i]
		var row := _create_preview_row(
			s.get("number", ""),
			s.get("name", ""),
			s.get("gender", ""),
			false
		)
		preview_container.add_child(row)

func _create_preview_row(col1: String, col2: String, col3: String, is_header: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	
	var color := Color(0.8, 0.8, 0.8) if is_header else Color(1, 1, 1)
	
	var l1 := Label.new()
	l1.text = col1
	l1.custom_minimum_size = Vector2(120, 25)
	l1.add_theme_color_override("font_color", color)
	row.add_child(l1)
	
	var l2 := Label.new()
	l2.text = col2
	l2.custom_minimum_size = Vector2(200, 25)
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.add_theme_color_override("font_color", color)
	row.add_child(l2)
	
	var l3 := Label.new()
	l3.text = col3
	l3.custom_minimum_size = Vector2(60, 25)
	l3.add_theme_color_override("font_color", color)
	row.add_child(l3)
	
	return row

func _validate_mapping() -> bool:
	if _column_mapping.get("number_col", -1) < 0:
		return false
	if _extracted_students.is_empty():
		return false
	return true

# ─────────────────────────────────────────────────────────────
# STEP 3: SECTION ASSIGNMENT
# ─────────────────────────────────────────────────────────────

func _setup_step3() -> void:
	summary_label.text = "Ready to import %d students" % _extracted_students.size()
	
	# Populate existing sections dropdown
	existing_dropdown.clear()
	var sections := StudentDatabase.get_all_sections()
	
	if sections.is_empty():
		existing_radio.disabled = true
		existing_dropdown.disabled = true
		new_radio.button_pressed = true
	else:
		existing_radio.disabled = false
		for section in sections:
			existing_dropdown.add_item(
				"%s (%s)" % [section.get("name", ""), section.get("school_year", "")],
				0
			)
			existing_dropdown.set_item_metadata(existing_dropdown.item_count - 1, section["id"])
	
	# If importing to existing section (from "Import More" button)
	if not _target_section_id.is_empty() and not _is_new_section:
		existing_radio.button_pressed = true
		existing_dropdown.disabled = false
		# Find and select the target section
		for i in range(existing_dropdown.item_count):
			if existing_dropdown.get_item_metadata(i) == _target_section_id:
				existing_dropdown.select(i)
				break
	
	_update_step3_ui()

func _on_existing_toggled(pressed: bool) -> void:
	existing_dropdown.disabled = not pressed
	_update_step3_ui()

func _on_new_toggled(pressed: bool) -> void:
	new_name_input.editable = pressed
	new_year_input.editable = pressed
	_update_step3_ui()

func _update_step3_ui() -> void:
	var new_section_grid: GridContainer = $WizardPanel/MainVBox/StepContainer/Step3/NewSectionGrid
	new_section_grid.modulate.a = 1.0 if new_radio.button_pressed else 0.5
	existing_dropdown.modulate.a = 1.0 if existing_radio.button_pressed else 0.5

# ─────────────────────────────────────────────────────────────
# IMPORT EXECUTION
# ─────────────────────────────────────────────────────────────

func _do_import() -> void:
	var section_id: String
	
	if new_radio.button_pressed:
		# Create new section
		var section_name := new_name_input.text.strip_edges()
		var school_year := new_year_input.text.strip_edges()
		
		if section_name.is_empty():
			summary_label.text = "⚠ Please enter a section name"
			return
		
		section_id = StudentDatabase.create_section(section_name, school_year)
	else:
		# Use existing section
		var selected_idx := existing_dropdown.selected
		if selected_idx < 0:
			summary_label.text = "⚠ Please select a section"
			return
		section_id = existing_dropdown.get_item_metadata(selected_idx)
	
	# Add students
	var skip_duplicates := skip_duplicates_check.button_pressed
	var result := StudentDatabase.add_students_to_section(section_id, _extracted_students, skip_duplicates)
	
	import_completed.emit(section_id, result)
	queue_free()
