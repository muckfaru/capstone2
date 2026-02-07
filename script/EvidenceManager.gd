class_name EvidenceManager
extends RefCounted

var collected_evidence: Array = []
var minimum_evidence_required: int = 3

func add_evidence(evidence_data: Dictionary):
	# Check if evidence already exists
	for ev in collected_evidence:
		if ev.name == evidence_data.name:
			return
	
	collected_evidence.append(evidence_data)

func get_all_evidence() -> Array:
	return collected_evidence

func has_minimum_evidence() -> bool:
	return collected_evidence.size() >= minimum_evidence_required

func get_evidence_count() -> int:
	return collected_evidence.size()

func clear_evidence():
	collected_evidence.clear()

func has_evidence_type(evidence_name: String) -> bool:
	for ev in collected_evidence:
		if evidence_name.to_lower() in ev.name.to_lower():
			return true
	return false