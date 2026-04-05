extends RefCounted
class_name FileImporter

## CSV and XLSX file parser for student roster import
## Supports column auto-detection and validation

signal import_progress(percent: float, message: String)

# Column detection keywords
const NUMBER_KEYWORDS := ["number", "id", "student", "no", "num", "studno"]
const NAME_KEYWORDS := ["name", "student name", "full name", "fullname", "lastname", "firstname"]
const GENDER_KEYWORDS := ["gender", "sex", "m/f"]

var _last_error := ""

func get_last_error() -> String:
	return _last_error

# ─────────────────────────────────────────────────────────────
# FILE TYPE DETECTION
# ─────────────────────────────────────────────────────────────

static func get_file_type(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "csv":
		return "csv"
	elif ext == "xlsx" or ext == "xls":
		return "xlsx"
	return "unknown"

static func is_supported_file(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext in ["csv", "xlsx", "xls"]

# ─────────────────────────────────────────────────────────────
# CSV PARSING
# ─────────────────────────────────────────────────────────────

func parse_csv(file_path: String) -> Dictionary:
	_last_error = ""
	
	if not FileAccess.file_exists(file_path):
		_last_error = "File not found: %s" % file_path
		return { "success": false, "error": _last_error }
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_last_error = "Could not open file"
		return { "success": false, "error": _last_error }
	
	var rows: Array = []
	var headers: Array = []
	var line_num := 0
	
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		
		var cells := _parse_csv_line(line)
		
		if line_num == 0:
			headers = cells
		else:
			if cells.size() > 0:
				rows.append(cells)
		
		line_num += 1
	
	file.close()
	
	return {
		"success": true,
		"headers": headers,
		"rows": rows,
		"row_count": rows.size()
	}

func _parse_csv_line(line: String) -> Array:
	var cells: Array = []
	var current_cell := ""
	var in_quotes := false
	var i := 0
	
	while i < line.length():
		var c := line[i]
		
		if c == '"':
			if in_quotes and i + 1 < line.length() and line[i + 1] == '"':
				# Escaped quote
				current_cell += '"'
				i += 1
			else:
				in_quotes = not in_quotes
		elif c == ',' and not in_quotes:
			cells.append(current_cell.strip_edges())
			current_cell = ""
		else:
			current_cell += c
		
		i += 1
	
	# Add last cell
	cells.append(current_cell.strip_edges())
	
	return cells

# ─────────────────────────────────────────────────────────────
# XLSX PARSING (Using XML extraction from ZIP)
# ─────────────────────────────────────────────────────────────

func parse_xlsx(file_path: String) -> Dictionary:
	_last_error = ""
	
	if not FileAccess.file_exists(file_path):
		_last_error = "File not found: %s" % file_path
		return { "success": false, "error": _last_error }
	
	# XLSX is a ZIP file containing XML
	var reader := ZIPReader.new()
	var err := reader.open(file_path)
	
	if err != OK:
		_last_error = "Could not open XLSX file (invalid format)"
		return { "success": false, "error": _last_error }
	
	# Read shared strings (text values are stored separately)
	var shared_strings: Array = []
	if reader.file_exists("xl/sharedStrings.xml"):
		var ss_data := reader.read_file("xl/sharedStrings.xml")
		shared_strings = _parse_shared_strings(ss_data.get_string_from_utf8())
	
	# Read the first sheet
	var sheet_data: PackedByteArray
	if reader.file_exists("xl/worksheets/sheet1.xml"):
		sheet_data = reader.read_file("xl/worksheets/sheet1.xml")
	else:
		reader.close()
		_last_error = "No worksheet found in XLSX"
		return { "success": false, "error": _last_error }
	
	reader.close()
	
	var result := _parse_sheet_xml(sheet_data.get_string_from_utf8(), shared_strings)
	return result

func _parse_shared_strings(xml_text: String) -> Array:
	var strings: Array = []
	var parser := XMLParser.new()
	parser.open_buffer(xml_text.to_utf8_buffer())
	
	var current_text := ""
	var in_si := false
	
	while parser.read() == OK:
		var node_type := parser.get_node_type()
		var node_name := parser.get_node_name()
		
		if node_type == XMLParser.NODE_ELEMENT:
			if node_name == "si":
				in_si = true
				current_text = ""
		elif node_type == XMLParser.NODE_TEXT:
			if in_si:
				current_text += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "si":
				strings.append(current_text)
				in_si = false
	
	return strings

func _parse_sheet_xml(xml_text: String, shared_strings: Array) -> Dictionary:
	var parser := XMLParser.new()
	parser.open_buffer(xml_text.to_utf8_buffer())
	
	var rows: Array = []
	var current_row: Array = []
	var current_cell_value := ""
	var current_cell_type := ""
	var in_row := false
	var in_cell := false
	var in_value := false
	var row_num := 0
	
	while parser.read() == OK:
		var node_type := parser.get_node_type()
		var node_name := parser.get_node_name()
		
		if node_type == XMLParser.NODE_ELEMENT:
			if node_name == "row":
				in_row = true
				current_row = []
			elif node_name == "c" and in_row:
				in_cell = true
				current_cell_value = ""
				current_cell_type = parser.get_named_attribute_value_safe("t")
			elif node_name == "v" and in_cell:
				in_value = true
		
		elif node_type == XMLParser.NODE_TEXT:
			if in_value:
				current_cell_value += parser.get_node_data()
		
		elif node_type == XMLParser.NODE_ELEMENT_END:
			if node_name == "v":
				in_value = false
			elif node_name == "c":
				# Resolve the cell value
				var resolved_value := ""
				if current_cell_type == "s" and not current_cell_value.is_empty():
					# Shared string reference
					var idx := int(current_cell_value)
					if idx >= 0 and idx < shared_strings.size():
						resolved_value = shared_strings[idx]
				else:
					resolved_value = current_cell_value
				
				current_row.append(resolved_value.strip_edges())
				in_cell = false
			elif node_name == "row":
				if current_row.size() > 0:
					rows.append(current_row)
				in_row = false
	
	# First row is headers
	var headers: Array = []
	var data_rows: Array = []
	
	if rows.size() > 0:
		headers = rows[0]
		data_rows = rows.slice(1)
	
	return {
		"success": true,
		"headers": headers,
		"rows": data_rows,
		"row_count": data_rows.size()
	}

# ─────────────────────────────────────────────────────────────
# COLUMN AUTO-DETECTION
# ─────────────────────────────────────────────────────────────

func detect_columns(headers: Array) -> Dictionary:
	var result := {
		"number_col": -1,
		"name_col": -1,
		"gender_col": -1
	}
	
	for i in range(headers.size()):
		var header: String = str(headers[i]).to_lower().strip_edges()
		
		# Check for student number column
		if result["number_col"] == -1:
			for keyword in NUMBER_KEYWORDS:
				if header.contains(keyword):
					result["number_col"] = i
					break
		
		# Check for name column
		if result["name_col"] == -1:
			for keyword in NAME_KEYWORDS:
				if header.contains(keyword):
					result["name_col"] = i
					break
		
		# Check for gender column
		if result["gender_col"] == -1:
			for keyword in GENDER_KEYWORDS:
				if header.contains(keyword):
					result["gender_col"] = i
					break
	
	return result

# ─────────────────────────────────────────────────────────────
# DATA EXTRACTION
# ─────────────────────────────────────────────────────────────

func extract_students(parse_result: Dictionary, column_mapping: Dictionary) -> Array:
	if not parse_result.get("success", false):
		return []
	
	var students: Array = []
	var number_col: int = column_mapping.get("number_col", -1)
	var name_col: int = column_mapping.get("name_col", -1)
	var gender_col: int = column_mapping.get("gender_col", -1)
	
	if number_col == -1:
		_last_error = "Student number column not specified"
		return []
	
	for row in parse_result["rows"]:
		if row.size() <= number_col:
			continue
		
		var number: String = str(row[number_col]).strip_edges()
		if number.is_empty():
			continue
		
		var student := {
			"number": number,
			"name": "",
			"gender": ""
		}
		
		if name_col >= 0 and name_col < row.size():
			student["name"] = str(row[name_col]).strip_edges()
		
		if gender_col >= 0 and gender_col < row.size():
			var g: String = str(row[gender_col]).strip_edges().to_upper()
			if g.begins_with("M"):
				student["gender"] = "M"
			elif g.begins_with("F"):
				student["gender"] = "F"
		
		students.append(student)
	
	return students

# ─────────────────────────────────────────────────────────────
# VALIDATION
# ─────────────────────────────────────────────────────────────

func validate_import_data(students: Array) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var valid_count := 0
	var seen_numbers := {}
	
	for i in range(students.size()):
		var s: Dictionary = students[i]
		var row_num := i + 2  # Account for header row + 0-index
		
		# Check required field
		if s.get("number", "").is_empty():
			errors.append("Row %d: Missing student number" % row_num)
			continue
		
		# Check for duplicates within import
		var num: String = s["number"].to_upper()
		if seen_numbers.has(num):
			warnings.append("Row %d: Duplicate student number '%s' (first seen at row %d)" % [row_num, num, seen_numbers[num]])
		else:
			seen_numbers[num] = row_num
		
		# Validate gender if present
		var gender: String = s.get("gender", "")
		if not gender.is_empty() and gender not in ["M", "F"]:
			warnings.append("Row %d: Invalid gender '%s' (expected M or F)" % [row_num, gender])
		
		valid_count += 1
	
	return {
		"valid": errors.size() == 0,
		"valid_count": valid_count,
		"errors": errors,
		"warnings": warnings
	}

# ─────────────────────────────────────────────────────────────
# UNIFIED PARSE (auto-detects file type)
# ─────────────────────────────────────────────────────────────

func parse_file(file_path: String) -> Dictionary:
	var file_type := get_file_type(file_path)
	
	match file_type:
		"csv":
			return parse_csv(file_path)
		"xlsx":
			return parse_xlsx(file_path)
		_:
			_last_error = "Unsupported file type: %s" % file_path.get_extension()
			return { "success": false, "error": _last_error }
