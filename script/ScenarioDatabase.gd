class_name ScenarioDatabase
extends Node

# All game scenarios organized by wave
var scenarios_data = []

func _init():
	_initialize_scenarios()

func _initialize_scenarios():
	# WAVE 1-3: FUNDAMENTALS
	scenarios_data = [
		# Wave 1
		{
			"user_name": "Sarah Chen",
			"user_role": "employee",
			"auth_level": 1,
			"requested_resource": "Marketing Shared Drive",
			"risk_level": "low",
			"location": "Seattle, WA",
			"device": "Company Laptop",
			"time": "14:35 PST",
			"context_flags": [],
			"correct_action": "grant",
			"is_attacker": false,
			"feedback_correct": "Correct! Employee accessing appropriate departmental resources.",
			"feedback_incorrect": "This was a legitimate request. Denying appropriate access hurts productivity.",
			"threat_consequence": 10,
			"wave": 1,
			"time_limit": 20.0
		},
		{
			"user_name": "Marcus Johnson",
			"user_role": "intern",
			"auth_level": 1,
			"requested_resource": "Financial Database",
			"risk_level": "high",
			"location": "Seattle, WA",
			"device": "Company Laptop",
			"time": "10:20 PST",
			"context_flags": [],
			"correct_action": "deny",
			"is_attacker": false,
			"feedback_correct": "Correct! Interns should not access financial data. Least privilege enforced.",
			"feedback_incorrect": "Security breach! Intern accessed financial records. This violates least privilege principle.",
			"threat_consequence": 30,
			"wave": 1,
			"time_limit": 20.0
		},
		{
			"user_name": "Dr. Elena Rodriguez",
			"user_role": "admin",
			"auth_level": 1,
			"requested_resource": "User Management Console",
			"risk_level": "high",
			"location": "Public WiFi - Coffee Shop",
			"device": "Personal Laptop",
			"time": "19:45 PST",
			"context_flags": ["public_network", "personal_device"],
			"correct_action": "require_mfa",
			"is_attacker": false,
			"feedback_correct": "Excellent! Admin access from public network requires MFA for security.",
			"feedback_incorrect": "Risky! Admin credentials on public WiFi without MFA can be intercepted.",
			"threat_consequence": 25,
			"wave": 1,
			"time_limit": 20.0
		},
		
		# Wave 2
		{
			"user_name": "James Park",
			"user_role": "developer",
			"auth_level": 2,
			"requested_resource": "Production Code Repository",
			"risk_level": "medium",
			"location": "Seattle, WA",
			"device": "Work Laptop",
			"time": "16:00 PST",
			"context_flags": [],
			"correct_action": "grant",
			"is_attacker": false,
			"feedback_correct": "Good! Developer with proper MFA accessing appropriate resources.",
			"feedback_incorrect": "This was legitimate. Developer needs code access for their job.",
			"threat_consequence": 15,
			"wave": 2,
			"time_limit": 18.0
		},
		{
			"user_name": "Priya Sharma",
			"user_role": "contractor",
			"auth_level": 2,
			"requested_resource": "Client Database - All Records",
			"risk_level": "high",
			"location": "Mumbai, India",
			"device": "Personal Device",
			"time": "02:30 PST",
			"context_flags": ["contract_expired", "unusual_time"],
			"correct_action": "deny",
			"is_attacker": false,
			"feedback_correct": "Perfect! Contract expired 2 weeks ago. Access should have been revoked.",
			"feedback_incorrect": "Major breach! Former contractor retained access to sensitive client data.",
			"threat_consequence": 40,
			"wave": 2,
			"time_limit": 18.0
		},
		
		# Wave 3
		{
			"user_name": "Alex Thompson",
			"user_role": "employee",
			"auth_level": 1,
			"requested_resource": "HR Payroll System",
			"risk_level": "high",
			"location": "Seattle, WA",
			"device": "Company Laptop",
			"time": "11:00 PST",
			"context_flags": ["wrong_department"],
			"correct_action": "deny",
			"is_attacker": false,
			"feedback_correct": "Correct! Marketing employee shouldn't access HR payroll. Least privilege.",
			"feedback_incorrect": "Privacy violation! Non-HR employee accessed salary information.",
			"threat_consequence": 35,
			"wave": 3,
			"time_limit": 18.0
		},
		
		# WAVE 4-6: MFA & CONTEXT AWARENESS
		{
			"user_name": "James Park",
			"user_role": "developer",
			"auth_level": 2,
			"requested_resource": "Deploy to Production Servers",
			"risk_level": "high",
			"location": "Seattle, WA",
			"device": "Work Laptop",
			"time": "23:00 PST Friday",
			"context_flags": ["unusual_time"],
			"correct_action": "grant",
			"is_attacker": false,
			"feedback_correct": "Good judgment! Late deployment with proper MFA is acceptable for developers.",
			"feedback_incorrect": "This was legitimate. Developers often deploy after hours to minimize disruption.",
			"threat_consequence": 20,
			"wave": 4,
			"time_limit": 15.0
		},
		{
			"user_name": "Elena Rodriguez",
			"user_role": "admin",
			"auth_level": 1,
			"auth_passed": false,
			"requested_resource": "Security Audit Logs",
			"risk_level": "high",
			"location": "Kyiv, Ukraine",
			"device": "Unknown Device",
			"time": "03:15 PST",
			"context_flags": ["mfa_failed", "wrong_location", "unusual_time", "unknown_device"],
			"correct_action": "deny",
			"is_attacker": true,
			"feedback_correct": "Excellent! Stolen admin credentials detected. MFA failure + wrong location = attack.",
			"feedback_incorrect": "CRITICAL BREACH! Attacker gained admin access. They can now cover their tracks.",
			"threat_consequence": 50,
			"wave": 4,
			"time_limit": 15.0
		},
		
		# Wave 5
		{
			"user_name": "Sarah Chen",
			"user_role": "employee",
			"auth_level": 2,
			"requested_resource": "Download Customer Database (500GB)",
			"risk_level": "high",
			"location": "Seattle, WA",
			"device": "Company Laptop",
			"time": "14:00 PST",
			"context_flags": ["unusual_request", "large_download"],
			"correct_action": "deny",
			"is_attacker": false,
			"feedback_correct": "Great call! HR employee has no business downloading entire customer database.",
			"feedback_incorrect": "Data exfiltration! 50,000 customer records exposed. GDPR fine: $500,000.",
			"threat_consequence": 45,
			"wave": 5,
			"time_limit": 15.0
		},
		
		# WAVE 7-10: ADVANCED THREATS
		{
			"user_name": "Marcus Johnson",
			"user_role": "intern",
			"auth_level": 1,
			"requested_resource": "Admin Panel Access",
			"risk_level": "high",
			"location": "Seattle, WA",
			"device": "New Device",
			"time": "02:00 PST",
			"context_flags": ["unusual_time", "privilege_escalation", "social_engineering"],
			"correct_action": "deny",
			"is_attacker": true,
			"feedback_correct": "Perfect! Social engineering detected. 'CEO urgent request' at 2 AM is classic attack.",
			"feedback_incorrect": "Compromised! Attacker used stolen intern credentials to gain admin access.",
			"threat_consequence": 50,
			"wave": 7,
			"time_limit": 12.0
		},
		{
			"user_name": "James Park",
			"user_role": "developer",
			"auth_level": 2,
			"requested_resource": "Delete Production Database Backups",
			"risk_level": "critical",
			"location": "Seattle, WA",
			"device": "Work Laptop",
			"time": "15:30 PST",
			"context_flags": ["destructive_action", "unusual_request"],
			"correct_action": "deny",
			"is_attacker": true,
			"feedback_correct": "Critical save! This was ransomware attempting to delete backups before encryption.",
			"feedback_incorrect": "CATASTROPHIC! Ransomware deleted backups then encrypted systems. Recovery cost: $2.4M",
			"threat_consequence": 60,
			"wave": 8,
			"time_limit": 10.0
		},
		{
			"user_name": "Dr. Elena Rodriguez",
			"user_role": "admin",
			"auth_level": 3,
			"requested_resource": "System Configuration Files",
			"risk_level": "medium",
			"location": "Seattle, WA",
			"device": "Company Laptop",
			"time": "10:00 PST",
			"context_flags": [],
			"correct_action": "grant",
			"is_attacker": false,
			"feedback_correct": "Correct! Legitimate admin request with strong authentication.",
			"feedback_incorrect": "False denial. This was the actual admin with hardware token MFA.",
			"threat_consequence": 10,
			"wave": 9,
			"time_limit": 10.0
		},
		{
			"user_name": "Alex Thompson",
			"user_role": "employee",
			"auth_level": 2,
			"requested_resource": "Install Third-Party Software",
			"risk_level": "high",
			"location": "Seattle, WA",
			"device": "Company Laptop",
			"time": "13:00 PST",
			"context_flags": ["unapproved_software"],
			"correct_action": "deny",
			"is_attacker": false,
			"feedback_correct": "Good! Employees shouldn't install unapproved software. Malware prevention.",
			"feedback_incorrect": "Malware installed! Network-wide ransomware infection. 200 systems compromised.",
			"threat_consequence": 55,
			"wave": 10,
			"time_limit": 10.0
		}
	]

func get_scenarios_for_wave(wave: int) -> Array:
	var wave_scenarios = []
	for data in scenarios_data:
		if data.wave == wave:
			wave_scenarios.append(Scenario.create_scenario(data))
	return wave_scenarios

func get_all_scenarios() -> Array:
	var all = []
	for data in scenarios_data:
		all.append(Scenario.create_scenario(data))
	return all