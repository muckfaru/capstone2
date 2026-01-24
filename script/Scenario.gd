class_name Scenario
extends Resource

# User Information
var user_name: String
var user_role: String  # "admin", "developer", "employee", "intern", "contractor"
var role_color: Color

# Authentication
var auth_level: int  # 1=password, 2=mfa, 3=hardware token
var auth_passed: bool = true

# Request Details
var requested_resource: String
var risk_level: String  # "low", "medium", "high"

# Context Flags (red flags)
var context_flags: Array = []  # ["unusual_time", "new_device", "wrong_location", etc.]
var location: String
var device: String
var time: String

# Correct Answer
var correct_action: String  # "grant", "deny", "require_mfa"
var is_attacker: bool = false

# Feedback
var feedback_correct: String
var feedback_incorrect: String
var threat_consequence: int = 20  # How much trust score is lost if wrong

# Difficulty
var wave: int = 1
var time_limit: float = 20.0

func _init():
	pass

static func create_scenario(data: Dictionary) -> Scenario:
	var s = Scenario.new()
	s.user_name = data.get("user_name", "Unknown User")
	s.user_role = data.get("user_role", "employee")
	s.role_color = _get_role_color(s.user_role)
	s.auth_level = data.get("auth_level", 1)
	s.auth_passed = data.get("auth_passed", true)
	s.requested_resource = data.get("requested_resource", "Unknown Resource")
	s.risk_level = data.get("risk_level", "medium")
	s.context_flags = data.get("context_flags", [])
	s.location = data.get("location", "Seattle, WA")
	s.device = data.get("device", "Company Laptop")
	s.time = data.get("time", "14:35 PST")
	s.correct_action = data.get("correct_action", "deny")
	s.is_attacker = data.get("is_attacker", false)
	s.feedback_correct = data.get("feedback_correct", "Correct decision!")
	s.feedback_incorrect = data.get("feedback_incorrect", "Incorrect decision!")
	s.threat_consequence = data.get("threat_consequence", 20)
	s.wave = data.get("wave", 1)
	s.time_limit = data.get("time_limit", 20.0)
	return s

static func _get_role_color(role: String) -> Color:
	match role:
		"admin":
			return Color("#e74c3c")  # Red
		"developer":
			return Color("#3498db")  # Blue
		"employee":
			return Color("#2ecc71")  # Green
		"intern":
			return Color("#f39c12")  # Yellow
		"contractor":
			return Color("#e67e22")  # Orange
		_:
			return Color("#95a5a6")  # Gray