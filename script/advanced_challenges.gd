extends Node

# This file contains additional challenge scenarios that can be loaded
# Use this to extend the game with more complex malware scenarios

class_name ChallengeScenarios

# Advanced Challenge: Ransomware Attack
static var RANSOMWARE_SCENARIO = {
	"name": "Ransomware Response",
	"difficulty": "HARD",
	"description": "WannaCry-style ransomware is encrypting files. Act fast!",
	"time_limit": 300,  # 5 minutes
	"processes": [
		{"name": "System", "pid": 4, "memory": "8 K", "malware": false},
		{"name": "csrss.exe", "pid": 456, "memory": "3,892 K", "malware": false},
		{"name": "taskhost.exe", "pid": 1892, "memory": "4,256 K", "malware": false},
		{"name": "mssecsvc.exe", "pid": 3344, "memory": "18,432 K", "malware": true},  # Fake security service
		{"name": "@WanaDecryptor@.exe", "pid": 3456, "memory": "24,128 K", "malware": true},
		{"name": "explorer.exe", "pid": 1456, "memory": "45,232 K", "malware": false},
	],
	"files": [
		"C:\\Windows\\Temp\\mssecsvc.exe",
		"C:\\ProgramData\\@WanaDecryptor@.exe",
		"C:\\Users\\Public\\Documents\\README_DECRYPT.txt",
	],
	"registry": [
		"HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\MsSecSvc",
		"HKCU\\Software\\WanaCrypt0r\\EncKey",
	],
	"stages": [
		{
			"title": "Emergency Detection",
			"objective": "Identify ransomware processes immediately!",
			"command": "tasklist /v",
			"tutorial": """RANSOMWARE EMERGENCY RESPONSE

CRITICAL INDICATORS:
• Multiple encryption processes
• Files being renamed (.wncry, .encrypted)
• High CPU usage during encryption
• Ransom note files appearing

IMMEDIATE ACTIONS:
1. Disconnect from network (prevent spread)
2. Identify malicious processes
3. DO NOT reboot (may trigger encryption)
4. Document everything for forensics"""
		},
		{
			"title": "Network Isolation",
			"objective": "Check network connections to prevent lateral movement",
			"command": "netstat -ano",
			"tutorial": """NETWORK CONTAINMENT

netstat -ano shows:
-a: All connections and listening ports
-n: Numerical addresses (faster, no DNS lookup)
-o: Shows owning process PID

LOOK FOR:
• Connections to unknown IPs
• Unusual ports (445/SMB, 139, 3389/RDP)
• Multiple connections from same process

LATERAL MOVEMENT PREVENTION:
Ransomware spreads through:
• SMB shares (port 445)
• Remote Desktop (port 3389)
• Email attachments"""
		},
		{
			"title": "Kill Encryption Process",
			"objective": "Stop @WanaDecryptor@.exe before more files are encrypted",
			"command": "taskkill /im @WanaDecryptor@.exe /f",
			"tutorial": """STOPPING ENCRYPTION

CRITICAL TIMING:
Every second counts - ransomware encrypts files rapidly!

USE FORCE:
/f flag is essential - ransomware resists normal termination

VERIFY SUCCESS:
Check tasklist again to confirm process killed

POST-TERMINATION:
• Check for shadow copies (vssadmin list shadows)
• Document encrypted file count
• Preserve ransom note for analysis"""
		},
		{
			"title": "Kill Persistence Service",
			"objective": "Terminate the fake security service (mssecsvc.exe)",
			"command": "taskkill /im mssecsvc.exe /f",
			"tutorial": """MULTI-COMPONENT MALWARE

Ransomware often has multiple components:
1. Dropper (initial infection)
2. Encryptor (encrypts files)
3. Persistence mechanism (survives reboot)
4. C2 communicator (sends encryption keys)

mssecsvc.exe is a PERSISTENCE mechanism
• Disguised as Microsoft Security Service
• Real service: MsMpEng.exe (Windows Defender)
• Respawns the encryptor if rebooted"""
		},
		{
			"title": "File Removal",
			"objective": "Delete all ransomware executables",
			"commands": [
				"del C:\\Windows\\Temp\\mssecsvc.exe",
				"del C:\\ProgramData\\@WanaDecryptor@.exe"
			],
			"tutorial": """ERADICATION PHASE

DELETE ALL COMPONENTS:
Missing even one file can allow reinfection

FORENSIC PRESERVATION:
In real incidents:
1. Copy files to isolated system
2. Calculate hash (certutil -hashfile file.exe SHA256)
3. Submit to VirusTotal
4. Then delete

DOCUMENT IoCs:
• File hashes (MD5, SHA256)
• File paths
• File sizes
• Creation timestamps"""
		},
		{
			"title": "Registry Cleanup",
			"objective": "Remove all persistence mechanisms",
			"commands": [
				"reg delete HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\Run /v MsSecSvc /f",
				"reg delete HKCU\\Software\\WanaCrypt0r /f"
			],
			"tutorial": """PERSISTENCE REMOVAL

REGISTRY LOCATIONS:
HKLM entries affect ALL users (more dangerous)
HKCU entries affect current user only

WanaCrypt0r KEY:
Contains encryption keys and configuration
MUST be deleted to prevent re-encryption

ADDITIONAL CHECKS:
• Services: sc query | findstr /i "wana"
• Scheduled Tasks: schtasks /query /fo LIST
• Startup Folder: dir shell:startup"""
		},
		{
			"title": "Recovery Verification",
			"objective": "Verify system is clean and check for shadow copies",
			"command": "vssadmin list shadows",
			"tutorial": """POST-INCIDENT RECOVERY

SHADOW COPIES (VSS):
Windows Volume Shadow Copy Service creates restore points
Ransomware often deletes these!

vssadmin commands:
• list shadows: Show available restore points
• delete shadows: Remove restore points (malware does this)
• resize shadowstorage: Adjust shadow copy space

RECOVERY OPTIONS:
If shadow copies exist:
1. Use System Restore
2. Previous Versions in File Explorer
3. vssadmin revert command

IF NO SHADOW COPIES:
• Check backups (offline/cloud)
• Consider decryption tools (No More Ransom project)
• DO NOT pay ransom (funds more attacks)

LESSONS LEARNED:
• Enable and monitor VSS
• Maintain offline backups
• Implement least privilege
• Keep systems patched"""
		}
	]
}

# Advanced Challenge: APT (Advanced Persistent Threat)
static var APT_SCENARIO = {
	"name": "APT Investigation",
	"difficulty": "EXPERT",
	"description": "Nation-state actor has infiltrated your network. Find all backdoors.",
	"processes": [
		{"name": "svchost.exe", "pid": 892, "memory": "5,432 K", "malware": false},
		{"name": "rundll32.exe", "pid": 2156, "memory": "3,128 K", "malware": true},  # Running malicious DLL
		{"name": "dllhost.exe", "pid": 2892, "memory": "4,896 K", "malware": false},
		{"name": "conhost.exe", "pid": 3124, "memory": "2,256 K", "malware": true},  # Fake console host
		{"name": "WmiPrvSE.exe", "pid": 3568, "memory": "8,432 K", "malware": true},  # WMI persistence
	],
	"tutorial": """ADVANCED PERSISTENT THREAT (APT) RESPONSE

APTs are sophisticated, state-sponsored attacks with:
• Multiple backdoors
• Legitimate process abuse (living off the land)
• Advanced evasion techniques
• Long-term persistence

INVESTIGATION TECHNIQUES:
1. Identify suspicious rundll32.exe usage
   Command: wmic process where name="rundll32.exe" get commandline
   
2. Check WMI persistence
   Command: wmic /namespace:\\\\root\\subscription path __EventFilter GET __RELPATH
   
3. Examine DLL hijacking
   Command: where rundll32.exe (should be System32 only)
   
4. Check scheduled tasks
   Command: schtasks /query /fo LIST /v | findstr /i "rundll32"

INDICATORS OF COMPROMISE:
• rundll32.exe running unusual DLLs
• WMI event subscriptions
• Fake system processes
• Outbound connections to suspicious IPs

APT GROUPS USE:
• PowerShell fileless malware
• DLL side-loading
• Registry-only persistence
• Encrypted C2 channels"""
}

# Advanced Challenge: Rootkit Detection
static var ROOTKIT_SCENARIO = {
	"name": "Rootkit Hunt",
	"difficulty": "EXPERT",
	"description": "Kernel-mode rootkit is hiding processes. Use advanced techniques.",
	"tutorial": """ROOTKIT DETECTION & REMOVAL

WHAT IS A ROOTKIT?
Software that hides its presence by modifying OS components:
• Kernel drivers (kernel-mode rootkits)
• User-mode libraries
• Boot sector (bootkits)

DETECTION CHALLENGES:
Standard tools (tasklist) may be compromised!
Rootkit hooks API calls to hide itself.

ADVANCED DETECTION:
1. Cross-view comparison
   Compare: tasklist vs Process Explorer vs Volatility
   
2. Check drivers
   Command: driverquery /v
   Look for unsigned or suspicious drivers
   
3. Verify system files
   Command: sfc /scannow
   System File Checker detects modifications
   
4. Boot-time scan
   Defender Offline or GMER tool
   
5. Memory analysis
   Use: Volatility Framework
   Analyze RAM dump for hidden processes

REMOVAL TECHNIQUES:
• Offline scanning (boot from USB)
• Driver signature enforcement
• Kernel debugging tools
• Sometimes: Clean OS reinstall required

PREVENTION:
• Enable Secure Boot
• Driver signature verification
• ELAM (Early Launch Anti-Malware)
• Regular integrity checks"""
}

# Challenge: Cryptominer Detection
static var CRYPTOMINER_SCENARIO = {
	"name": "Cryptominer Removal",
	"difficulty": "MEDIUM",
	"description": "Unauthorized cryptocurrency mining is slowing down the system",
	"processes": [
		{"name": "chrome.exe", "pid": 2348, "memory": "98,432 K", "malware": false},
		{"name": "chrome.exe", "pid": 2456, "memory": "124,876 K", "malware": false},
		{"name": "nvidia.exe", "pid": 3892, "memory": "256,432 K", "malware": true},  # Fake nvidia process
		{"name": "msiexec.exe", "pid": 4124, "memory": "4,256 K", "malware": true},  # Persistence installer
	],
	"tutorial": """CRYPTOMINER DETECTION

SYMPTOMS:
• High CPU/GPU usage (80-100%)
• System slowdown
• Increased electricity usage
• Cooling fans at max speed

DETECTION:
1. Check resource usage
   Command: tasklist /v
   Look for processes using excessive CPU
   
2. Check GPU usage
   Command: nvidia-smi (if NVIDIA GPU)
   Look for unknown processes using GPU
   
3. Network connections
   Command: netstat -ano
   Miners connect to mining pools (port 3333, 4444, etc.)

COMMON CRYPTOMINERS:
• XMRig (Monero)
• CGMiner
• NiceHash
• Coinhive (browser-based)

INDICATORS:
• Processes named after GPU brands (nvidia.exe from wrong path)
• Random executable names in Temp folders
• Connections to known mining pools:
  - pool.supportxmr.com
  - xmr.nanopool.org
  - minergate.com

PREVENTION:
• Ad blockers (block browser miners)
• Application whitelisting
• Monitor resource usage
• Regular security scans"""
}

# Function to load challenge by name
static func get_challenge(challenge_name: String) -> Dictionary:
	match challenge_name:
		"ransomware":
			return RANSOMWARE_SCENARIO
		"apt":
			return APT_SCENARIO
		"rootkit":
			return ROOTKIT_SCENARIO
		"cryptominer":
			return CRYPTOMINER_SCENARIO
		_:
			return {}

# Get all available challenges
static func get_all_challenges() -> Array:
	return [
		RANSOMWARE_SCENARIO,
		APT_SCENARIO,
		ROOTKIT_SCENARIO,
		CRYPTOMINER_SCENARIO
	]

# Get challenges by difficulty
static func get_challenges_by_difficulty(difficulty: String) -> Array:
	var challenges = get_all_challenges()
	var filtered = []
	for challenge in challenges:
		if challenge["difficulty"] == difficulty:
			filtered.append(challenge)
	return filtered