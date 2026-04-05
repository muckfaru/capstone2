extends Node
class_name StudentDatabaseClass

## Student Information Management System - Data Storage
## Stores sections and students locally at user://student_database.json

const DATABASE_PATH := "user://student_database.json"

signal database_changed

var _data: Dictionary = {
	"sections": {},
	"version": 1
}

func _ready() -> void:
	load_database()

# ─────────────────────────────────────────────────────────────
# DATABASE I/O
# ─────────────────────────────────────────────────────────────

func load_database() -> void:
	if not FileAccess.file_exists(DATABASE_PATH):
		_data = { "sections": {}, "version": 1 }
		return
	
	var file := FileAccess.open(DATABASE_PATH, FileAccess.READ)
	if file == null:
		push_warning("StudentDatabase: Could not open database file")
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_warning("StudentDatabase: JSON parse error at line %d" % json.get_error_line())
		return
	
	_data = json.data
	if not _data.has("sections"):
		_data["sections"] = {}

func save_database() -> void:
	var file := FileAccess.open(DATABASE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("StudentDatabase: Could not save database")
		return
	
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()
	database_changed.emit()

# ─────────────────────────────────────────────────────────────
# SECTION CRUD
# ─────────────────────────────────────────────────────────────

func create_section(section_name: String, school_year: String) -> String:
	var section_id := _generate_section_id(section_name, school_year)
	
	if _data["sections"].has(section_id):
		push_warning("StudentDatabase: Section already exists: %s" % section_id)
		return section_id
	
	_data["sections"][section_id] = {
		"id": section_id,
		"name": section_name,
		"school_year": school_year,
		"created_at": Time.get_unix_time_from_system(),
		"students": []
	}
	
	save_database()
	return section_id

func get_section(section_id: String) -> Dictionary:
	return _data["sections"].get(section_id, {})

func get_all_sections() -> Array:
	var sections: Array = []
	for id in _data["sections"]:
		sections.append(_data["sections"][id])
	
	# Sort by created_at descending (newest first)
	sections.sort_custom(func(a, b): return a.get("created_at", 0) > b.get("created_at", 0))
	return sections

func delete_section(section_id: String) -> bool:
	if not _data["sections"].has(section_id):
		return false
	
	_data["sections"].erase(section_id)
	save_database()
	return true

func update_section(section_id: String, new_name: String, new_school_year: String) -> bool:
	if not _data["sections"].has(section_id):
		return false
	
	_data["sections"][section_id]["name"] = new_name
	_data["sections"][section_id]["school_year"] = new_school_year
	save_database()
	return true

# ─────────────────────────────────────────────────────────────
# STUDENT CRUD
# ─────────────────────────────────────────────────────────────

func add_students_to_section(section_id: String, students: Array, skip_duplicates: bool = true) -> Dictionary:
	if not _data["sections"].has(section_id):
		return { "added": 0, "skipped": 0, "error": "Section not found" }
	
	var section: Dictionary = _data["sections"][section_id]
	var existing_numbers := {}
	for s in section["students"]:
		existing_numbers[s["number"]] = true
	
	var added := 0
	var skipped := 0
	
	for student in students:
		var number: String = str(student.get("number", "")).strip_edges().to_upper()
		if number.is_empty():
			skipped += 1
			continue
		
		if existing_numbers.has(number):
			if skip_duplicates:
				skipped += 1
				continue
			else:
				# Update existing student
				for i in range(section["students"].size()):
					if section["students"][i]["number"] == number:
						section["students"][i]["name"] = student.get("name", "")
						section["students"][i]["gender"] = student.get("gender", "")
						break
				added += 1
				continue
		
		section["students"].append({
			"number": number,
			"name": str(student.get("name", "")).strip_edges(),
			"gender": str(student.get("gender", "")).strip_edges().to_upper().substr(0, 1)
		})
		existing_numbers[number] = true
		added += 1
	
	save_database()
	return { "added": added, "skipped": skipped }

func add_single_student(section_id: String, number: String, student_name: String, gender: String = "") -> bool:
	return add_students_to_section(section_id, [{
		"number": number,
		"name": student_name,
		"gender": gender
	}])["added"] > 0

func remove_student(section_id: String, student_number: String) -> bool:
	if not _data["sections"].has(section_id):
		return false
	
	var students: Array = _data["sections"][section_id]["students"]
	for i in range(students.size()):
		if students[i]["number"] == student_number.to_upper():
			students.remove_at(i)
			save_database()
			return true
	
	return false

func get_students_in_section(section_id: String) -> Array:
	if not _data["sections"].has(section_id):
		return []
	return _data["sections"][section_id].get("students", [])

func get_student_numbers_for_section(section_id: String) -> Array:
	var students := get_students_in_section(section_id)
	var numbers: Array = []
	for s in students:
		numbers.append(s["number"])
	return numbers

func get_student_count(section_id: String) -> int:
	return get_students_in_section(section_id).size()

func get_gender_counts(section_id: String) -> Dictionary:
	var students := get_students_in_section(section_id)
	var male := 0
	var female := 0
	var other := 0
	
	for s in students:
		var g: String = s.get("gender", "")
		if g == "M":
			male += 1
		elif g == "F":
			female += 1
		else:
			other += 1
	
	return { "male": male, "female": female, "other": other }

# ─────────────────────────────────────────────────────────────
# SEARCH & FILTER
# ─────────────────────────────────────────────────────────────

func search_students(section_id: String, query: String) -> Array:
	var students := get_students_in_section(section_id)
	if query.is_empty():
		return students
	
	var q := query.to_lower()
	var results: Array = []
	
	for s in students:
		if s["number"].to_lower().contains(q) or s["name"].to_lower().contains(q):
			results.append(s)
	
	return results

func find_student_by_number(student_number: String) -> Dictionary:
	var num := student_number.strip_edges().to_upper()
	for section_id in _data["sections"]:
		for s in _data["sections"][section_id]["students"]:
			if s["number"] == num:
				return {
					"student": s,
					"section_id": section_id,
					"section_name": _data["sections"][section_id]["name"]
				}
	return {}

# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────

func _generate_section_id(name: String, school_year: String) -> String:
	var clean_name := name.strip_edges().to_upper().replace(" ", "-")
	var clean_year := school_year.strip_edges().replace(" ", "")
	return "%s-%s" % [clean_name, clean_year]

func section_exists(section_id: String) -> bool:
	return _data["sections"].has(section_id)

func get_section_display_name(section_id: String) -> String:
	var section := get_section(section_id)
	if section.is_empty():
		return ""
	return "%s (%s)" % [section.get("name", ""), section.get("school_year", "")]

func get_total_students() -> int:
	var total: int = 0
	for section_id in _data["sections"]:
		total += _data["sections"][section_id]["students"].size()
	return total

func get_total_sections() -> int:
	return _data["sections"].size()
