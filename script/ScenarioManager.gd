class_name ScenarioManager
extends RefCounted

enum ScenarioType {
	PHISHING_TROJAN,
	RDP_BRUTE_FORCE,
	CREDENTIAL_REUSE,
	BACKDOOR_MALWARE,
	RANSOMWARE,
	SCHEDULED_TASK
}

var current_scenario: Dictionary
var scenario_type: ScenarioType

func load_random_scenario():
	scenario_type = randi() % ScenarioType.size()
	
	match scenario_type:
		ScenarioType.PHISHING_TROJAN:
			_load_phishing_scenario()
		ScenarioType.RDP_BRUTE_FORCE:
			_load_rdp_brute_force_scenario()
		ScenarioType.CREDENTIAL_REUSE:
			_load_credential_reuse_scenario()
		ScenarioType.BACKDOOR_MALWARE:
			_load_backdoor_scenario()
		ScenarioType.RANSOMWARE:
			_load_ransomware_scenario()
		ScenarioType.SCHEDULED_TASK:
			_load_scheduled_task_scenario()

func _load_phishing_scenario():
	current_scenario = {
		"briefing": """[color=yellow]INCIDENT REPORT #IR-2026-0347[/color]
		
[color=white]Date: January 31, 2026
Time: 14:35 UTC
Severity: HIGH

A user in the Finance department reported suspicious system behavior after opening an email attachment earlier today. The user's antivirus software was disabled, and unusual network traffic has been detected.

Your task: Investigate the workstation, identify the attack vector, collect evidence, and recommend appropriate incident response actions.[/color]""",
		
		"objective": "Investigate phishing attack and trojan malware infection",
		
		"current_user": "CORP\\jsmith",
		
		"system_info": """Host Name:                 FINANCE-WS-042
OS Name:                   Microsoft Windows 10 Pro
OS Version:                10.0.19045 N/A Build 19045
System Manufacturer:       Dell Inc.
System Model:              OptiPlex 7080
Processor:                 Intel(R) Core(TM) i7-10700 CPU @ 2.90GHz
Total Physical Memory:     16,384 MB
Domain:                    CORP.LOCAL""",
		
		"users": ["Administrator", "jsmith", "Guest", "DefaultAccount"],
		
		"suspicious_user": "",
		
		"processes": [
			{"name": "System", "pid": 4, "session": "Services", "memory": "4,832 K"},
			{"name": "smss.exe", "pid": 388, "session": "Services", "memory": "1,024 K"},
			{"name": "csrss.exe", "pid": 584, "session": "Console", "memory": "4,512 K"},
			{"name": "explorer.exe", "pid": 2844, "session": "Console", "memory": "45,632 K"},
			{"name": "chrome.exe", "pid": 3256, "session": "Console", "memory": "125,440 K"},
			{"name": "outlook.exe", "pid": 4120, "session": "Console", "memory": "88,224 K"},
			{"name": "svchost.exe", "pid": 1532, "session": "Services", "memory": "12,288 K"},
			{"name": "winlogon32.exe", "pid": 5788, "session": "Console", "memory": "8,192 K"},
		],
		
		"malicious_process": "winlogon32.exe",
		
		"network_connections": [
			{"proto": "TCP", "local": "192.168.1.42:49234", "foreign": "40.112.72.205:443", "state": "ESTABLISHED", "pid": 3256},
			{"proto": "TCP", "local": "192.168.1.42:49235", "foreign": "172.217.14.108:443", "state": "ESTABLISHED", "pid": 4120},
			{"proto": "TCP", "local": "192.168.1.42:49240", "foreign": "185.220.101.47:8443", "state": "ESTABLISHED", "pid": 5788},
			{"proto": "TCP", "local": "192.168.1.42:49241", "foreign": "192.168.1.1:445", "state": "ESTABLISHED", "pid": 4},
		],
		
		"suspicious_ip": "185.220.101.47",
		
		"security_log": """2026-01-31 09:15:23 EventID:4624 Successful logon - User: jsmith
2026-01-31 09:47:12 EventID:5140 Network share accessed - \\\\FILESERVER\\Finance
2026-01-31 11:32:45 EventID:4688 Process created: outlook.exe
2026-01-31 11:45:02 EventID:4688 Process created: Invoice_Q4.exe
2026-01-31 11:45:15 EventID:5001 Windows Defender Real-time protection disabled
2026-01-31 11:45:22 EventID:4688 Process created: winlogon32.exe""",
		
		"auth_log": """2026-01-31 09:15:21 INFO: Authentication attempt - User: jsmith - Source: 192.168.1.42
2026-01-31 09:15:23 SUCCESS: User jsmith logged in successfully
2026-01-31 14:20:15 INFO: Authentication attempt - User: jsmith - Source: 192.168.1.42""",
		
		"system_log": """2026-01-31 09:00:01 INFO: System startup
2026-01-31 09:15:30 INFO: User profile loaded for jsmith
2026-01-31 11:45:05 WARNING: Unknown file execution detected
2026-01-31 11:45:16 ERROR: Windows Defender service stopped unexpectedly
2026-01-31 11:45:25 WARNING: Outbound connection to unrecognized IP
2026-01-31 12:30:44 ERROR: Scheduled task created without admin approval""",
		
		"has_brute_force": false,
		
		"correct_attack_type": "Phishing → Trojan Malware",
		"correct_entry_method": "Malicious Email Attachment",
		"correct_response": "All of the Above"
	}

func _load_rdp_brute_force_scenario():
	current_scenario = {
		"briefing": """[color=yellow]INCIDENT REPORT #IR-2026-0348[/color]
		
[color=white]Date: January 31, 2026
Time: 03:22 UTC
Severity: CRITICAL

Automated monitoring detected multiple failed RDP authentication attempts against a server, followed by a successful login from an unusual IP address. The account was not previously known to authenticate from this location.

Your task: Investigate the RDP brute-force attack, identify the compromised account, and determine the attacker's actions.[/color]""",
		
		"objective": "Investigate RDP brute-force attack and unauthorized access",
		
		"current_user": "CORP\\Administrator",
		
		"system_info": """Host Name:                 WEB-SERVER-01
OS Name:                   Microsoft Windows Server 2019 Standard
OS Version:                10.0.17763 N/A Build 17763
System Manufacturer:       HP
System Model:              ProLiant DL380 Gen10
Processor:                 Intel(R) Xeon(R) Gold 6230 CPU @ 2.10GHz
Total Physical Memory:     65,536 MB
Domain:                    CORP.LOCAL""",
		
		"users": ["Administrator", "backup_admin", "webadmin", "Guest"],
		
		"suspicious_user": "backup_admin",
		
		"processes": [
			{"name": "System", "pid": 4, "session": "Services", "memory": "8,192 K"},
			{"name": "smss.exe", "pid": 312, "session": "Services", "memory": "1,024 K"},
			{"name": "csrss.exe", "pid": 484, "session": "Services", "memory": "5,120 K"},
			{"name": "svchost.exe", "pid": 1024, "session": "Services", "memory": "24,576 K"},
			{"name": "TermService.exe", "pid": 2048, "session": "Services", "memory": "12,288 K"},
			{"name": "cmd.exe", "pid": 3344, "session": "RDP-Tcp#2", "memory": "4,096 K"},
			{"name": "powershell.exe", "pid": 3876, "session": "RDP-Tcp#2", "memory": "45,056 K"},
		],
		
		"malicious_process": "powershell.exe",
		
		"network_connections": [
			{"proto": "TCP", "local": "0.0.0.0:3389", "foreign": "0.0.0.0:0", "state": "LISTENING", "pid": 2048},
			{"proto": "TCP", "local": "10.0.1.15:3389", "foreign": "198.51.100.87:54321", "state": "ESTABLISHED", "pid": 2048},
			{"proto": "TCP", "local": "10.0.1.15:49876", "foreign": "10.0.1.5:445", "state": "ESTABLISHED", "pid": 3876},
		],
		
		"suspicious_ip": "198.51.100.87",
		
		"security_log": """2026-01-31 02:45:12 EventID:4625 Failed logon - User: Administrator - IP: 198.51.100.87
2026-01-31 02:45:15 EventID:4625 Failed logon - User: admin - IP: 198.51.100.87
2026-01-31 02:45:18 EventID:4625 Failed logon - User: root - IP: 198.51.100.87
2026-01-31 02:45:21 EventID:4625 Failed logon - User: backup_admin - IP: 198.51.100.87
2026-01-31 02:45:24 EventID:4625 Failed logon - User: backup_admin - IP: 198.51.100.87
2026-01-31 02:45:27 EventID:4624 Successful logon - User: backup_admin - IP: 198.51.100.87
2026-01-31 02:45:45 EventID:4672 Special privileges assigned to new logon - User: backup_admin
2026-01-31 03:12:33 EventID:4688 Process created: powershell.exe - User: backup_admin""",
		
		"auth_log": """2026-01-30 23:15:42 INFO: RDP connection attempt from 198.51.100.87
2026-01-31 02:45:12 FAILED: Invalid credentials - User: Administrator
2026-01-31 02:45:15 FAILED: Invalid credentials - User: admin
2026-01-31 02:45:18 FAILED: Invalid credentials - User: root
2026-01-31 02:45:21 FAILED: Invalid credentials - User: backup_admin
2026-01-31 02:45:24 FAILED: Invalid credentials - User: backup_admin
2026-01-31 02:45:27 SUCCESS: User backup_admin authenticated via RDP
2026-01-31 02:45:28 INFO: RDP session established - User: backup_admin""",
		
		"system_log": """2026-01-30 18:00:01 INFO: System running normally
2026-01-31 02:45:10 WARNING: Multiple authentication failures detected
2026-01-31 02:45:28 INFO: Remote Desktop session started
2026-01-31 03:12:35 WARNING: PowerShell execution policy bypassed
2026-01-31 03:15:22 ERROR: Suspicious command execution detected""",
		
		"has_brute_force": true,
		
		"correct_attack_type": "RDP Brute-Force Attack",
		"correct_entry_method": "Weak Password",
		"correct_response": "All of the Above"
	}

func _load_credential_reuse_scenario():
	current_scenario = {
		"briefing": """[color=yellow]INCIDENT REPORT #IR-2026-0349[/color]
		
[color=white]Date: January 31, 2026
Time: 16:45 UTC
Severity: HIGH

An employee's corporate credentials were used to access internal systems from a location they've never accessed from before. The credentials match those recently leaked in a third-party data breach.

Your task: Investigate the credential theft and unauthorized system access.[/color]""",
		
		"objective": "Investigate credential reuse attack and unauthorized access",
		
		"current_user": "CORP\\mwilson",
		
		"system_info": """Host Name:                 HR-LAPTOP-15
OS Name:                   Microsoft Windows 11 Pro
OS Version:                10.0.22631 N/A Build 22631
System Manufacturer:       Lenovo
System Model:              ThinkPad X1 Carbon Gen 11
Processor:                 Intel(R) Core(TM) i7-1365U vPro
Total Physical Memory:     32,768 MB
Domain:                    CORP.LOCAL""",
		
		"users": ["Administrator", "mwilson", "Guest", "temp_support"],
		
		"suspicious_user": "temp_support",
		
		"processes": [
			{"name": "System", "pid": 4, "session": "Services", "memory": "6,144 K"},
			{"name": "explorer.exe", "pid": 2156, "session": "Console", "memory": "52,224 K"},
			{"name": "chrome.exe", "pid": 3488, "session": "Console", "memory": "145,920 K"},
			{"name": "Teams.exe", "pid": 4012, "session": "Console", "memory": "98,304 K"},
			{"name": "svchost.exe", "pid": 1688, "session": "Services", "memory": "16,384 K"},
		],
		
		"malicious_process": "",
		
		"network_connections": [
			{"proto": "TCP", "local": "192.168.10.77:49344", "foreign": "52.114.76.43:443", "state": "ESTABLISHED", "pid": 4012},
			{"proto": "TCP", "local": "192.168.10.77:49345", "foreign": "172.217.14.206:443", "state": "ESTABLISHED", "pid": 3488},
			{"proto": "TCP", "local": "192.168.10.77:49350", "foreign": "192.168.10.5:445", "state": "ESTABLISHED", "pid": 4},
		],
		
		"suspicious_ip": "",
		
		"security_log": """2026-01-31 08:30:15 EventID:4624 Successful logon - User: mwilson - IP: 192.168.10.77
2026-01-31 12:15:33 EventID:4624 Successful logon - User: mwilson - IP: 203.0.113.42 (VPN)
2026-01-31 12:16:01 EventID:4720 User account created - User: temp_support - Creator: mwilson
2026-01-31 12:16:15 EventID:4732 User added to security group - User: temp_support - Group: Administrators
2026-01-31 14:22:10 EventID:4624 Successful logon - User: temp_support
2026-01-31 14:25:44 EventID:5140 Network share accessed - \\\\FILESERVER\\HR_Records""",
		
		"auth_log": """2026-01-31 08:30:13 INFO: Authentication attempt - User: mwilson - Source: 192.168.10.77
2026-01-31 08:30:15 SUCCESS: User mwilson logged in successfully
2026-01-31 12:15:30 INFO: VPN connection from IP: 203.0.113.42 - User: mwilson
2026-01-31 12:15:33 SUCCESS: VPN authentication successful - User: mwilson
2026-01-31 14:22:08 INFO: Authentication attempt - User: temp_support
2026-01-31 14:22:10 SUCCESS: User temp_support logged in successfully""",
		
		"system_log": """2026-01-31 08:30:20 INFO: User profile loaded for mwilson
2026-01-31 12:16:05 WARNING: New user account created outside business hours
2026-01-31 12:16:18 WARNING: Privilege escalation detected
2026-01-31 14:25:50 WARNING: Sensitive file access by non-authorized user
2026-01-31 14:30:12 ERROR: Unauthorized data export attempt detected""",
		
		"has_brute_force": false,
		
		"correct_attack_type": "Credential Reuse",
		"correct_entry_method": "Stolen Credentials",
		"correct_response": "Reset User Credentials"
	}

func _load_backdoor_scenario():
	current_scenario = {
		"briefing": """[color=yellow]INCIDENT REPORT #IR-2026-0350[/color]
		
[color=white]Date: January 31, 2026
Time: 11:20 UTC
Severity: CRITICAL

Network monitoring detected persistent outbound connections to a suspicious IP address. The connections occur every 5 minutes and originate from a process that appears to mimic a legitimate system service.

Your task: Identify the backdoor malware and determine how it maintains persistence.[/color]""",
		
		"objective": "Investigate backdoor malware and persistence mechanism",
		
		"current_user": "CORP\\dchen",
		
		"system_info": """Host Name:                 DEV-WORKSTATION-08
OS Name:                   Microsoft Windows 10 Pro
OS Version:                10.0.19045 N/A Build 19045
System Manufacturer:       ASUS
System Model:              ROG Strix G15
Processor:                 AMD Ryzen 9 5900HX
Total Physical Memory:     32,768 MB
Domain:                    CORP.LOCAL""",
		
		"users": ["Administrator", "dchen", "Guest"],
		
		"suspicious_user": "",
		
		"processes": [
			{"name": "System", "pid": 4, "session": "Services", "memory": "5,632 K"},
			{"name": "smss.exe", "pid": 356, "session": "Services", "memory": "1,024 K"},
			{"name": "csrss.exe", "pid": 512, "session": "Console", "memory": "4,896 K"},
			{"name": "explorer.exe", "pid": 2688, "session": "Console", "memory": "48,128 K"},
			{"name": "Code.exe", "pid": 3712, "session": "Console", "memory": "256,512 K"},
			{"name": "svchost.exe", "pid": 1456, "session": "Services", "memory": "14,336 K"},
			{"name": "svchosts.exe", "pid": 4932, "session": "Services", "memory": "8,704 K"},
		],
		
		"malicious_process": "svchosts.exe",
		
		"network_connections": [
			{"proto": "TCP", "local": "10.0.2.88:49456", "foreign": "13.107.42.14:443", "state": "ESTABLISHED", "pid": 3712},
			{"proto": "TCP", "local": "10.0.2.88:49457", "foreign": "151.101.1.69:443", "state": "ESTABLISHED", "pid": 3712},
			{"proto": "TCP", "local": "10.0.2.88:49460", "foreign": "94.156.177.23:4444", "state": "ESTABLISHED", "pid": 4932},
			{"proto": "TCP", "local": "10.0.2.88:49461", "foreign": "10.0.2.1:445", "state": "ESTABLISHED", "pid": 4},
		],
		
		"suspicious_ip": "94.156.177.23",
		
		"security_log": """2026-01-30 15:32:10 EventID:4624 Successful logon - User: dchen
2026-01-30 15:45:22 EventID:4688 Process created: git.exe
2026-01-30 15:46:08 EventID:4688 Process created: setup_tools.exe
2026-01-30 15:46:15 EventID:4698 Scheduled task created - Task: SystemMaintenanceService
2026-01-30 15:46:20 EventID:4688 Process created: svchosts.exe
2026-01-31 00:00:15 EventID:4688 Process created: svchosts.exe (via scheduled task)
2026-01-31 06:00:15 EventID:4688 Process created: svchosts.exe (via scheduled task)""",
		
		"auth_log": """2026-01-30 15:32:08 INFO: Authentication attempt - User: dchen
2026-01-30 15:32:10 SUCCESS: User dchen logged in successfully
2026-01-31 08:15:22 INFO: Authentication attempt - User: dchen
2026-01-31 08:15:24 SUCCESS: User dchen logged in successfully""",
		
		"system_log": """2026-01-30 15:32:15 INFO: User profile loaded for dchen
2026-01-30 15:46:05 WARNING: Unsigned executable launched
2026-01-30 15:46:18 WARNING: New scheduled task created with SYSTEM privileges
2026-01-30 15:46:25 ERROR: Outbound connection to suspicious IP detected
2026-01-31 00:00:16 WARNING: Scheduled task executed: SystemMaintenanceService
2026-01-31 06:00:16 WARNING: Scheduled task executed: SystemMaintenanceService""",
		
		"has_brute_force": false,
		
		"correct_attack_type": "Backdoor Malware",
		"correct_entry_method": "Software Vulnerability",
		"correct_response": "All of the Above"
	}

func _load_ransomware_scenario():
	current_scenario = {
		"briefing": """[color=yellow]INCIDENT REPORT #IR-2026-0351[/color]
		
[color=white]Date: January 31, 2026
Time: 07:15 UTC
Severity: CRITICAL

Multiple users reported being unable to access their files. All document files have been encrypted with a .locked extension, and a ransom note has appeared on affected systems demanding cryptocurrency payment.

Your task: Investigate the ransomware infection and identify the initial infection vector.[/color]""",
		
		"objective": "Investigate ransomware attack and encryption activity",
		
		"current_user": "CORP\\tpark",
		
		"system_info": """Host Name:                 SALES-PC-23
OS Name:                   Microsoft Windows 10 Pro
OS Version:                10.0.19045 N/A Build 19045
System Manufacturer:       Dell Inc.
System Model:              Latitude 5420
Processor:                 Intel(R) Core(TM) i5-1145G7 CPU @ 2.60GHz
Total Physical Memory:     16,384 MB
Domain:                    CORP.LOCAL""",
		
		"users": ["Administrator", "tpark", "Guest"],
		
		"suspicious_user": "",
		
		"processes": [
			{"name": "System", "pid": 4, "session": "Services", "memory": "5,120 K"},
			{"name": "explorer.exe", "pid": 2444, "session": "Console", "memory": "44,032 K"},
			{"name": "chrome.exe", "pid": 3128, "session": "Console", "memory": "118,784 K"},
			{"name": "svchost.exe", "pid": 1344, "session": "Services", "memory": "13,312 K"},
			{"name": "encrypt.exe", "pid": 5216, "session": "Console", "memory": "32,768 K"},
			{"name": "vssvc.exe", "pid": 2856, "session": "Services", "memory": "6,144 K"},
		],
		
		"malicious_process": "encrypt.exe",
		
		"network_connections": [
			{"proto": "TCP", "local": "192.168.5.134:49567", "foreign": "142.250.185.46:443", "state": "ESTABLISHED", "pid": 3128},
			{"proto": "TCP", "local": "192.168.5.134:49570", "foreign": "45.142.212.61:8080", "state": "ESTABLISHED", "pid": 5216},
			{"proto": "TCP", "local": "192.168.5.134:49571", "foreign": "192.168.5.10:445", "state": "ESTABLISHED", "pid": 5216},
		],
		
		"suspicious_ip": "45.142.212.61",
		
		"security_log": """2026-01-31 06:45:12 EventID:4624 Successful logon - User: tpark
2026-01-31 07:02:33 EventID:4688 Process created: chrome.exe
2026-01-31 07:05:44 EventID:4688 Process created: document_final.exe
2026-01-31 07:05:50 EventID:4688 Process created: encrypt.exe
2026-01-31 07:06:01 EventID:4656 Object access: C:\\Users\\tpark\\Documents\\*
2026-01-31 07:06:15 EventID:4663 File system: Mass file modification detected
2026-01-31 07:08:22 EventID:4689 Process terminated: vssvc.exe (Shadow Copy Service)""",
		
		"auth_log": """2026-01-31 06:45:10 INFO: Authentication attempt - User: tpark
2026-01-31 06:45:12 SUCCESS: User tpark logged in successfully""",
		
		"system_log": """2026-01-31 06:45:18 INFO: User profile loaded for tpark
2026-01-31 07:05:48 WARNING: Unsigned executable launched from Downloads
2026-01-31 07:06:05 ERROR: Rapid file modification detected
2026-01-31 07:06:18 ERROR: Multiple file encryption operations
2026-01-31 07:08:24 CRITICAL: Volume Shadow Copy Service terminated
2026-01-31 07:10:33 CRITICAL: Backup files deleted
2026-01-31 07:12:45 ERROR: Ransom note created on desktop""",
		
		"has_brute_force": false,
		
		"correct_attack_type": "Ransomware Infection",
		"correct_entry_method": "Malicious Email Attachment",
		"correct_response": "All of the Above"
	}

func _load_scheduled_task_scenario():
	current_scenario = {
		"briefing": """[color=yellow]INCIDENT REPORT #IR-2026-0352[/color]
		
[color=white]Date: January 31, 2026
Time: 13:40 UTC
Severity: HIGH

Automated security monitoring detected a new scheduled task created with SYSTEM-level privileges. The task executes a PowerShell script every hour that was not approved by IT.

Your task: Investigate the malicious scheduled task and identify what it's doing.[/color]""",
		
		"objective": "Investigate malicious scheduled task and persistence",
		
		"current_user": "CORP\\arodriguez",
		
		"system_info": """Host Name:                 MARKETING-WS-11
OS Name:                   Microsoft Windows 10 Pro
OS Version:                10.0.19045 N/A Build 19045
System Manufacturer:       HP
System Model:              EliteDesk 800 G8
Processor:                 Intel(R) Core(TM) i7-11700 CPU @ 2.50GHz
Total Physical Memory:     32,768 MB
Domain:                    CORP.LOCAL""",
		
		"users": ["Administrator", "arodriguez", "Guest", "svc_backup"],
		
		"suspicious_user": "svc_backup",
		
		"processes": [
			{"name": "System", "pid": 4, "session": "Services", "memory": "6,400 K"},
			{"name": "explorer.exe", "pid": 2912, "session": "Console", "memory": "50,176 K"},
			{"name": "svchost.exe", "pid": 1552, "session": "Services", "memory": "15,360 K"},
			{"name": "powershell.exe", "pid": 4688, "session": "Services", "memory": "62,464 K"},
			{"name": "Adobe.exe", "pid": 3344, "session": "Console", "memory": "95,232 K"},
		],
		
		"malicious_process": "powershell.exe",
		
		"network_connections": [
			{"proto": "TCP", "local": "172.16.10.55:49678", "foreign": "23.56.89.123:443", "state": "ESTABLISHED", "pid": 4688},
			{"proto": "TCP", "local": "172.16.10.55:49679", "foreign": "172.16.10.5:445", "state": "ESTABLISHED", "pid": 4},
		],
		
		"suspicious_ip": "23.56.89.123",
		
		"security_log": """2026-01-30 17:22:15 EventID:4624 Successful logon - User: arodriguez
2026-01-30 17:35:42 EventID:4688 Process created: AdobeUpdate.exe
2026-01-30 17:35:55 EventID:4720 User account created - User: svc_backup
2026-01-30 17:36:02 EventID:4732 User added to group - User: svc_backup - Group: Administrators
2026-01-30 17:36:15 EventID:4698 Scheduled task created - Task: AdobeUpdateTask
2026-01-31 09:00:01 EventID:4688 Process created: powershell.exe (via scheduled task)
2026-01-31 10:00:01 EventID:4688 Process created: powershell.exe (via scheduled task)""",
		
		"auth_log": """2026-01-30 17:22:13 INFO: Authentication attempt - User: arodriguez
2026-01-30 17:22:15 SUCCESS: User arodriguez logged in successfully
2026-01-31 08:30:11 INFO: Authentication attempt - User: arodriguez
2026-01-31 08:30:13 SUCCESS: User arodriguez logged in successfully""",
		
		"system_log": """2026-01-30 17:22:20 INFO: User profile loaded for arodriguez
2026-01-30 17:35:50 WARNING: Suspicious executable launched
2026-01-30 17:36:00 WARNING: New service account created outside IT approval
2026-01-30 17:36:18 ERROR: Scheduled task with SYSTEM privileges created
2026-01-31 09:00:03 WARNING: PowerShell script execution from scheduled task
2026-01-31 10:00:03 WARNING: PowerShell script execution from scheduled task
2026-01-31 11:00:03 WARNING: PowerShell script execution from scheduled task""",
		
		"has_brute_force": false,
		
		"correct_attack_type": "Malicious Scheduled Task",
		"correct_entry_method": "Software Vulnerability",
		"correct_response": "All of the Above"
	}

# Getter methods
func get_briefing() -> String:
	return current_scenario.get("briefing", "")

func get_objective() -> String:
	return current_scenario.get("objective", "")

func get_current_user() -> String:
	return current_scenario.get("current_user", "UNKNOWN")

func get_system_info() -> String:
	return current_scenario.get("system_info", "")

func get_user_accounts() -> Array:
	return current_scenario.get("users", [])

func get_suspicious_user() -> String:
	return current_scenario.get("suspicious_user", "")

func get_processes() -> Array:
	return current_scenario.get("processes", [])

func get_processes_with_services() -> Array:
	var processes = []
	for proc in current_scenario.get("processes", []):
		processes.append({
			"name": proc.name,
			"pid": proc.pid,
			"service": "N/A" if proc.session == "Console" else proc.session
		})
	return processes

func get_malicious_process() -> String:
	return current_scenario.get("malicious_process", "")

func get_network_connections() -> Array:
	return current_scenario.get("network_connections", [])

func get_suspicious_ip() -> String:
	return current_scenario.get("suspicious_ip", "")

func get_ip_config() -> String:
	return """Windows IP Configuration

Ethernet adapter Ethernet:
   Connection-specific DNS Suffix  . : corp.local
   IPv4 Address. . . . . . . . . . . : 192.168.1.42
   Subnet Mask . . . . . . . . . . . : 255.255.255.0
   Default Gateway . . . . . . . . . : 192.168.1.1"""

func get_directory_listing() -> Array:
	return [
		{"date": "2026-01-28  14:22", "name": "Documents"},
		{"date": "2026-01-31  09:15", "name": "Downloads"},
		{"date": "2026-01-20  11:30", "name": "Desktop"},
		{"date": "2026-01-15  08:45", "name": "Pictures"},
	]

func get_security_log() -> String:
	return current_scenario.get("security_log", "")

func get_auth_log() -> String:
	return current_scenario.get("auth_log", "")

func get_system_log() -> String:
	return current_scenario.get("system_log", "")

func has_brute_force_attempts() -> bool:
	return current_scenario.get("has_brute_force", false)

func get_correct_attack_type() -> String:
	return current_scenario.get("correct_attack_type", "")

func get_correct_entry_method() -> String:
	return current_scenario.get("correct_entry_method", "")

func get_correct_response() -> String:
	return current_scenario.get("correct_response", "")