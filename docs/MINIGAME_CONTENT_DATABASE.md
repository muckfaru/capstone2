# Minigame Content Database

> Complete listing of all questions, scenarios, commands, and answers across all 13 minigames.
> Organized by syllabus lesson order.

---

## Table of Contents

| # | Game | Lesson | Type |
|---|------|--------|------|
| 1 | [Cybersecurity Fundamentals](#1-cybersecurity-fundamentals) | 1.1 – Intro to Info Assurance & Security | Tutorial |
| 2 | [Network Basics](#2-network-basics) | 1.2 – Data and Networking Security | Tutorial |
| 3 | [Drop Zone Defender](#3-drop-zone-defender) | 1.2 – Data vs Network Classification | Drag & Drop |
| 4 | [Threat Identification Lab](#4-threat-identification-lab) | 2.2 – Threat Categories & Classification | Timed Classification |
| 5 | [Asset vs Threats](#5-asset-vs-threats) | 2.2 – Assets and Associated Threats | Wave Defense |
| 6 | [Encryption (Caesar Cipher)](#6-encryption-caesar-cipher) | 3.1 – Symmetric Encryption Algorithms | Interactive |
| 7 | [Crypt Contract](#7-crypt-contract) | 3.2 – Purpose of Cryptography | Story Mission |
| 8 | [Encryption Audit Lab](#8-encryption-audit-lab) | 3.3/4.1 – Encryption Standards (DES, 3DES, AES) | Email Audit |
| 9 | [Cipher Defense Terminal](#9-cipher-defense-terminal) | 4.2 – AES Encryption Defense | Typing Defense |
| 10 | [Crypto Sorter](#10-crypto-sorter) | 5.1-5.2 – Symmetric & Asymmetric Cryptography | Classification |
| 11 | [RSA Key Lab](#11-rsa-key-lab) | 6.2-6.4 – RSA, Diffie-Hellman & Cryptography in Practice | Interactive Lab |
| 12 | [Password Fortress Defender](#12-password-fortress-defender) | 7.1 – Authentication | Battle |
| 13 | [Security Guardian](#13-security-guardian) | 7.1 – Authentication Systems | Decision Game |

---

## 1. Cybersecurity Fundamentals

**Script:** `script/tutorial_cyber_fundamentals.gd`
**Lesson:** 1.1 – Intro to Info Assurance & Security
**Type:** Educational Tutorial (text-based, 4 sections)

### Section 1: INTRO – What is Cybersecurity?

- Cybersecurity = Protecting computers, networks, and data from attacks
- Foundation concepts: CIA Triad (3 core principles) + Threat Model

### Section 2: CIA TRIAD

| Principle | Definition | Examples |
|-----------|-----------|----------|
| **Confidentiality** | Keep data secret from unauthorized access | Passwords, medical records, credit cards |
| **Integrity** | Keep data accurate, prevent tampering | Bank balances, software, prescriptions |
| **Availability** | Keep systems accessible when needed | Websites online, email servers, hospitals |

### Section 3: THREAT MODEL

**Formula:** THREAT + VULNERABILITY = RISK

| Scenario | Threat | Vulnerability | Risk | Fix |
|----------|--------|---------------|------|-----|
| Weak Password | Hacker with cracking tools | "password123" | HIGH – easily cracked | Strong password like "T7$mK9#pL2@xR4!" |
| Outdated Software | Malware exploiting known bugs | Software not updated in 2 years | HIGH – bugs exploitable | Install latest updates |
| No Backups | Ransomware encrypting files | No backup copies exist | HIGH – total data loss | Regular backups to external drive/cloud |

### Section 4: COMPLETE

Key takeaway summary and XP award.

---

## 2. Network Basics

**Script:** `script/tutorial_network_basics.gd` + `script/network_defense_game.gd`
**Lesson:** 1.2 – Data and Networking Security
**Type:** Tutorial (4 sections) → Defense Game (4 phases)

### Tutorial – Section 1: INTRO

Internet analogy: Postal system → Computer address = IP address → Different doors = Ports → Communication rules = Protocols

### Tutorial – Section 2: IP ADDRESSES

**Private IPs (Home/Internal):**
- `192.168.x.x` – most home networks
- `10.x.x.x` – big companies
- `172.16-31.x.x` – medium networks

**Public IPs (Internet-visible):**
- Example: `8.8.8.8` (Google DNS)
- Visible to everyone on the internet

### Tutorial – Section 3: PORTS

**Common Safe Ports:**
| Port | Service | Purpose |
|------|---------|---------|
| 80 | HTTP | Regular websites |
| 443 | HTTPS | Secure websites (SSL/TLS) |
| 22 | SSH | Remote server login |
| 25 | SMTP | Sending email |
| 53 | DNS | Domain name lookup |

**Dangerous Hacker Ports:**
| Port | Name | Danger |
|------|------|--------|
| 4444 | Backdoor | Trojan communications |
| 31337 | "Elite" | Hacker favorite |
| 1337 | L33t | Hacker favorite |
| 12345 | NetBus | Trojan remote access |

### Tutorial – Section 4: PROTOCOLS

Covers HTTP, HTTPS, SSH, FTP, and Telnet with security implications.

### Defense Game – Phase 1: IP Challenges

| IP Address | Verdict | Category | Hint |
|-----------|---------|----------|------|
| 192.168.1.100 | ✅ SAFE | Private | "192.168 = Home network" |
| 10.0.0.50 | ✅ SAFE | Private | "10.x = Company network" |
| 45.33.32.156:4444 | ❌ THREAT | Backdoor | "Port 4444 = BACKDOOR!" |
| 172.16.5.20 | ✅ SAFE | Private | "172.16-31 = Private" |
| 8.8.8.8:53 | ✅ SAFE | DNS | "Google DNS" |
| 203.45.67.89:31337 | ❌ THREAT | Hacker | "31337 = Elite hacker port" |

### Defense Game – Phase 2: Port Challenges

| Address | Verdict | Hint |
|---------|---------|------|
| 192.168.1.100:80 | ✅ SAFE | "Port 80 = HTTP" |
| 45.33.32.156:443 | ✅ SAFE | "Port 443 = HTTPS" |
| 203.45.12.34:4444 | ❌ THREAT | "4444 = TROJAN" |
| 8.8.8.8:22 | ✅ SAFE | "Port 22 = SSH" |
| 45.67.89.12:1337 | ❌ THREAT | "1337 = Malware" |

### Defense Game – Phase 3: Protocol Challenges

| Protocol | Verdict | Hint |
|----------|---------|------|
| HTTPS | ✅ SAFE | "Encrypted web" |
| HTTP | ❌ THREAT | "No encryption!" |
| SSH | ✅ SAFE | "Secure shell" |
| FTP | ❌ THREAT | "Plain text transfer" |
| Telnet | ❌ THREAT | "Sends passwords plain!" |

---

## 3. Drop Zone Defender

**Script:** `script/datavsnetworkgmmanager.gd`
**Lesson:** 1.2 – Data vs Network Classification
**Type:** Drag-and-drop classification (8 waves)
**Max Score:** 500

### Attack Database (10 attacks)

Players drag attack cards into the correct zone: **📁 DATA** or **🌐 NETWORK**.

| # | Attack | Zone | Description | Explanation |
|---|--------|------|-------------|-------------|
| 1 | Ransomware Encryption | 📁 DATA | Malware encrypting employee database files | Locks your DATA files – like a padlock on your filing cabinet |
| 2 | USB Virus | 📁 DATA | Infected USB drive copying files from computers | Virus on USB steals DATA when plugged in |
| 3 | Password Theft | 📁 DATA | Keylogger recording usernames and passwords | Stealing login DATA – like writing passwords from your keyboard |
| 4 | DDoS Attack | 🌐 NETWORK | 1000+ bots flooding web server with traffic | Fake visitors crashing your NETWORK – like blocking a store entrance |
| 5 | WiFi Jamming | 🌐 NETWORK | Signal blocker disrupting wireless connections | Blocking WiFi NETWORK signals – like jamming a radio |
| 6 | Spam Email Flood | 🌐 NETWORK | Millions of junk emails overloading mail server | Spam clogging your NETWORK email system |
| 7 | SQL Injection | 📁 DATA | Hacker inserting code to extract customer records | Tricks database to reveal DATA – like a trick question |
| 8 | Insider Data Leak | 📁 DATA | Employee copying files to personal USB drive | Insider stealing DATA files – like photocopying documents |
| 9 | Cloud Storage Hack | 📁 DATA | Weak password exposed company cloud files | Online DATA storage accessed – like guessing a locker code |
| 10 | Man-in-the-Middle | 🌐 NETWORK | Attacker intercepting unencrypted WiFi traffic | Eavesdropping on NETWORK connection – like tapping a phone |

### Wave Configuration

| Wave | Attacks | Delay | Speed | Unlocks |
|------|---------|-------|-------|---------|
| 1 | 3 | 5.0s | 60 | Attacks 1-6 |
| 2 | 4 | 4.5s | 100 | Attacks 7-10 |
| 3 | 5 | 4.0s | 120 | All |
| 4 | 5 | 3.5s | 140 | All |
| 5 | 6 | 3.0s | 160 | All |
| 6 | 7 | 2.8s | 180 | All |
| 7 | 8 | 2.5s | 200 | All |
| 8 | 10 | 2.0s | 220 | All |

---

## 4. Threat Identification Lab

**Script:** `script/tutorial_malware_types.gd`
**Lesson:** 2.2 – Threat Categories & Classification
**Type:** Timed classification game (90 seconds, 18 scenario pool → 6 per game)
**Max Score:** 100

### All 18 Scenarios (6 categories × 3 each)

#### Category 1: SOCIAL ENGINEERING

**Incident #2847 – Business Email Compromise**
- Employee received email impersonating the CEO
- Email requests urgent wire transfer to new account
- Sender address has subtle misspelling of company domain
- *Explanation: BEC manipulates trust and authority to trick employees*

**Incident #4102 – Pretexting**
- Help desk received call from someone claiming to be VP
- Caller demanded immediate password reset for 'locked account'
- Caller became aggressive when asked security questions
- *Explanation: Pretexting invents a scenario to manipulate staff into bypassing procedures*

**Incident #6230 – Baiting**
- USB drives labeled 'Salary Report Q4' found in parking lot
- Curious employee plugged one into work computer
- Malicious script executed automatically on insertion
- *Explanation: Baiting uses physical media to lure victims via curiosity*

#### Category 2: MALWARE ATTACK

**Incident #1923 – Ransomware**
- All company files encrypted with .locked extension
- Popup demands Bitcoin payment for decryption key
- Backup server also infected via network share
- *Explanation: Ransomware encrypts files and demands payment. Threatens Availability and Integrity*

**Incident #3871 – Spyware/Keylogger**
- Antivirus detected keylogger on accounting workstation
- Keystrokes logged and sent to external server every hour
- Banking portal credentials likely compromised
- *Explanation: Malware silently records user activity, stealing credentials. Threatens Confidentiality*

**Incident #5519 – Worm**
- Worm spreading across internal network without user action
- 40% of workstations infected within 2 hours
- Network bandwidth completely saturated
- *Explanation: Worms self-replicate automatically across networks. Threatens Availability*

#### Category 3: NETWORK ATTACK

**Incident #5634 – DDoS (Distributed Denial-of-Service)**
- Company website unreachable for 6 hours
- Server logs show millions of requests from worldwide IPs
- Legitimate customers unable to access online services
- *Explanation: DDoS floods servers with traffic to disrupt Availability*

**Incident #7788 – Man-in-the-Middle (MitM)**
- Employees on coffee shop WiFi report strange SSL warnings
- Login credentials intercepted between laptop and server
- Attacker positioned between user and legitimate network
- *Explanation: MitM intercepts communications. Threatens Confidentiality and Integrity*

**Incident #9045 – DNS Spoofing/Poisoning**
- Company DNS records modified without authorization
- Customers redirected to fake version of company website
- Fake site collects login credentials and credit card info
- *Explanation: DNS spoofing redirects users to malicious sites. Threatens Confidentiality and Integrity*

#### Category 4: INSIDER THREAT

**Incident #7721 – Data Theft**
- Departing employee downloaded entire customer database
- Downloaded files found on personal USB drive
- Employee had legitimate access to the database
- *Explanation: Insider threats from trusted personnel who misuse authorized access. Threatens Confidentiality*

**Incident #8334 – Privileged Insider**
- IT admin created hidden account with full system privileges
- Account used to access payroll data after business hours
- Activity only discovered during routine access audit
- *Explanation: Privileged insiders can abuse administrative access. Regular audits detect unauthorized activity*

**Incident #2190 – NDA Violation**
- Contractor shared proprietary source code on public forum
- Code contained API keys and database connection strings
- Contractor had signed NDA but violated it intentionally
- *Explanation: Contractors pose insider risk. NDAs alone don't prevent intentional leaks — access controls needed*

#### Category 5: PHYSICAL THREAT

**Incident #3309 – Hardware Theft**
- Company laptop stolen from employee's car
- Laptop contained unencrypted client financial records
- No remote wipe capability was enabled
- *Explanation: Physical theft without encryption exposes all stored data. Threatens Confidentiality*

**Incident #4467 – Tailgating**
- Unauthorized person followed employee through secure door
- Individual accessed server room and photographed equipment
- Security cameras were non-functional due to maintenance
- *Explanation: Tailgating breaches physical security. Unauthorized server room access threatens all CIA properties*

**Incident #6601 – Natural Disaster**
- Flooding from burst pipe damaged ground-floor server room
- 3 servers and 2 network switches destroyed
- No off-site backups existed for affected systems
- *Explanation: Environmental hazards are physical threats. Backups and disaster recovery protect Availability*

#### Category 6: DATA BREACH

**Incident #8156 – Misconfiguration**
- Misconfigured cloud storage exposed 2 million records
- Personal data (names, emails, SSNs) publicly accessible
- Discovered by security researcher, not internal team
- *Explanation: Data breaches from misconfigured systems. Sensitive data is exposed unintentionally*

**Incident #9923 – SQL Injection**
- SQL injection attack extracted entire user database
- Passwords stored in plaintext, no hashing applied
- Attack exploited unpatched vulnerability in web application
- *Explanation: SQL injection leads to breaches when input is not sanitized. Plaintext passwords violate Confidentiality*

**Incident #1177 – Accidental Exposure**
- Company accidentally emailed spreadsheet to wrong recipient
- File contained employee SSNs, salaries, and medical info
- Error discovered 3 days later by compliance team
- *Explanation: Accidental breaches are still breaches. Human error is top cause — classification and access controls help*

---

## 5. Asset vs Threats

**Script:** `script/GameManager.gd`
**Lesson:** 2.2 – Assets and Associated Threats
**Type:** Wave-based click defense (5 waves)
**Max Score:** 500

### Assets (6 systems, 5 HP each)

| Asset | Description |
|-------|-------------|
| Employee PC | Workstation |
| Database | Data storage |
| Router | Network device |
| Email Server | Mail system |
| Backup | Backup storage |
| CEO Laptop | Executive device |

### Threats and Correct Defenses

| Threat | Target Assets | Damage | Correct Defense |
|--------|--------------|--------|-----------------|
| Phishing | Employee PC, CEO Laptop | Steals passwords | **Email Filter** |
| Brute Force | Database | Cracks passwords | **Firewall** or **Strong Password** |
| Malware | Employee PC | Encrypts files | **Antivirus** |
| DDoS | Router | Floods network | **Firewall** |
| SQL Injection | Database | Steals data | **Security Patch** |
| Ransomware | Backup, Database | Encrypts files | **Antivirus** or **Backup System** |
| Zero-Day | Employee PC, Database, Router | Exploits vulnerability | **Security Patch** |
| Insider Threat | Database, CEO Laptop | Data breach | **Access Control** |

### Wave Configuration

| Wave | Threats Available | Count | Speed | HP |
|------|------------------|-------|-------|-----|
| 1 | Phishing, Malware, Brute Force, DDoS, SQL Injection, Ransomware | 8 | 60 | 1 |
| 2 | Phishing, Brute Force, Malware, DDoS | 8 | 100 | 1 |
| 3 | Phishing, DDoS, SQL Injection, Malware, Brute Force | 12 | 120 | 2 |
| 4 | Ransomware, Zero-Day, SQL Injection, DDoS, Phishing, Malware | 15 | 140 | 2 |
| 5 | Ransomware, Zero-Day, Insider Threat, SQL Injection, DDoS, Brute Force, Phishing | 20 | 160 | 3 |

---

## 6. Encryption (Caesar Cipher)

**Script:** `script/tutorial_encryption_basics.gd`
**Lesson:** 3.1 – Symmetric Encryption Algorithms
**Type:** Interactive tutorial (6 phases)

### Phase 1: INTRO – How Caesar Cipher Works

Shift each letter forward by the key number. Example with key = 3: H → K

### Phase 2: LEARN_WHEEL – Visual Animation

Shows the cipher wheel animating: H → I → J → K (encrypt) and K → J → I → H (decrypt)

### Phase 3: PRACTICE_MODE – Decrypt Messages

| Encrypted | Answer | Key |
|-----------|--------|-----|
| KHOOR | HELLO | 3 |
| ZRUOG | WORLD | 3 |
| FRGH | CODE | 3 |

### Phase 4: CHALLENGE_MODE – Speed Decrypt

| Encrypted | Answer | Key |
|-----------|--------|-----|
| VDIH | SAFE | 3 |
| VHFUHW | SECRET | 3 |
| ORFN | LOCK | 3 |

### Phase 5: RANSOMWARE_EXPLANATION

- Caesar Cipher = only 26 possible keys → cracked in seconds
- Modern AES-256 = 2^256 keys → billions of years to brute force
- **Ransomware process:** Malware encrypts files with AES-256 → deletes key → demands payment
- **Best defense:** Regular backups (daily), offline backups, never pay ransom

### Phase 6: COMPLETE

Key takeaways: substitution ciphers, encryption/decryption, key importance, why modern encryption is unbreakable, ransomware exploitation of encryption, backup importance.

---

## 7. Crypt Contract

**Script:** `script/PhoneEncryption.gd`
**Lesson:** 3.2 – Purpose of Cryptography
**Type:** Story-driven encryption game (5 missions)
**Max Score:** 500

### Mission 1: Initial Recruitment

| Boss Message | Player Reply |
|-------------|-------------|
| "Meet me at pier 9 tonight" | "Understood boss" |
| "Package delivered successfully" | "Package confirmed" |
| "Payment confirmed" | "Payment received" |
| "New contact in the morning" | "Contact established" |
| "Everything looks clear" | "All clear on my end" |

### Mission 2: Escalation

| Boss Message | Player Reply |
|-------------|-------------|
| "New target: Victor Morales" | "Target acquired" |
| "Surveillance team spotted" | "Surveillance evaded" |
| "Change safe house now" | "Moving to new location" |
| "Police are getting close" | "Staying under the radar" |
| "Asset secured successfully" | "Asset in custody" |

### Mission 3: Serious Crimes

| Boss Message | Player Reply |
|-------------|-------------|
| "Eliminate the witness" | "Witness neutralized" |
| "Document retrieval urgent" | "Documents secured" |
| "Transfer complete by midnight" | "Transfer initiated" |
| "They know about the pier" | "Situation handled" |
| "Switch to backup protocol" | "Protocol activated" |

### Mission 4: Heat Intensifies

| Boss Message | Player Reply |
|-------------|-------------|
| "Abort mission immediately" | "Mission aborted" |
| "Extract at 0200 hours" | "En route to extraction" |
| "Target has been relocated" | "New position acquired" |
| "Federal agents involved now" | "Understood. Moving fast" |
| "Burn the safe house" | "Safe house abandoned" |

### Mission 5: Final Assignment

| Boss Message | Player Reply |
|-------------|-------------|
| "Burn all evidence" | "Everything burned" |
| "Final job. Disappear after" | "Copy that boss" |
| "Prepare extraction plan B" | "Plan B ready" |
| "This is your last assignment" | "Getting out now" |
| "Leave the country tonight" | "This is goodbye" |

---

## 8. Encryption Audit Lab

**Script:** `script/tutorial_phishing_lab.gd`
**Lesson:** 3.3/4.1 – Encryption Standards (DES, 3DES, AES)
**Type:** Email audit game (8 scenarios per game from pool of 18, 90 second timer)
**Max Score:** 1200 (8 × 150 points)
**Verdicts:** ✅ Approve (secure) | ⚠️ Flag (weak) | ❌ Reject (broken)

### APPROVE – Secure Configurations (6 scenarios, 3 selected per game)

**1. AES-256-CBC – Customer Database**
- Algorithm: AES-256, Mode: CBC with random IVs, Key Storage: HSM, Padding: PKCS7
- ✅ *AES-256 gold standard, CBC with random IVs prevents patterns, HSM best practice*

**2. AES-128-GCM – REST API**
- Algorithm: AES-128, Mode: GCM (authenticated), Auth Tag: 128-bit, Nonce: 96-bit unique
- ✅ *AES-128 unbroken, GCM provides authentication, unique nonces prevent replays*

**3. Triple DES 3-Key – Payment Terminals**
- Algorithm: 3DES with 3 independent keys, Key: 168-bit effective, Mode: CBC, Compliance: ANSI X9.52, Migration: planned to AES
- ✅ *3-key 3DES still acceptable, 168-bit secure, ANSI compliant, migration planned*

**4. AES-256-GCM – Cloud Storage**
- Algorithm: AES-256, Mode: GCM, Key Mgmt: AWS KMS auto-rotation (90 days), Envelope Encryption: yes
- ✅ *AES-256-GCM authenticated, AWS KMS industry standard, envelope encryption adds layer*

**5. AES-192-CBC-HMAC – Internal Chat**
- Algorithm: AES-192, Mode: CBC + HMAC-SHA256, IV: random per message, Key Exchange: ECDH
- ✅ *AES-192 strong, CBC-HMAC is encrypt-then-MAC, ECDH secure key exchange*

**6. Triple DES 3-Key – Interbank System**
- Algorithm: 3DES 3-key, Key: 3 independent 56-bit keys, Mode: CBC, Key Exchange: dual-control ceremony, Compliance: PCI DSS + ISO 8583
- ✅ *Dual-control ceremony excellent, PCI DSS compliant, justified by partner requirement*

### FLAG – Weak/Vulnerable Configurations (6 scenarios, 3 selected per game)

**1. AES-256-ECB – Media Assets**
- Algorithm: AES-256, Mode: **ECB**, Key Storage: config file on server
- ⚠️ *ECB does NOT hide patterns! Identical blocks produce identical ciphertext. Use CBC or GCM*

**2. AES-128-CBC Hardcoded – Mobile App**
- Algorithm: AES-128, Mode: CBC, Key: **hardcoded in source code** (Base64), IV: **fixed**
- ⚠️ *Hardcoded keys extractable from binaries. Fixed IV enables pattern analysis*

**3. Triple DES 2-Key – Invoice Processing**
- Algorithm: **2-key 3DES** (2TDEA), Key: 112-bit effective, Mode: CBC
- ⚠️ *2-key 3DES only 112-bit security. NIST deprecated after 2023. Meet-in-the-middle vulnerable*

**4. AES-256-CBC No MAC – Session Tokens**
- Algorithm: AES-256, Mode: CBC, Authentication: **None (no MAC/HMAC)**, Padding: PKCS7
- ⚠️ *CBC without MAC vulnerable to padding oracle attacks. Add HMAC-SHA256 or use GCM*

**5. AES-128-CBC Static Zero IV – IoT Sensor**
- Algorithm: AES-128, Mode: CBC, IV: **0x00000000000000000000000000000000** (static), Key: derived from serial number
- ⚠️ *Static zero IV makes CBC vulnerable to pattern leakage. Key from serial is predictable*

**6. Triple DES 3-Key Plaintext Keys – QA**
- Algorithm: 3DES 3-key, Mode: CBC, Key Storage: **keys.properties file (plaintext!)**
- ⚠️ *Keys stored in plaintext easily stolen. Anyone with filesystem access reads keys*

### REJECT – Broken/Deprecated (6 scenarios, 2 selected per game)

**1. DES-56-ECB – Credit Card Storage**
- Algorithm: **DES (single)**, Key: **56 bits**, Mode: **ECB**
- ❌ *Single DES cracked in 1999 (22 hours). 56-bit key too small. ECB makes it worse. PCI requires AES-128 minimum*

**2. DES-56-ECB – Medical Records**
- Algorithm: **DES**, Key: **56 bits**, Mode: **ECB**, Data: patient names, diagnoses
- ❌ *DES completely broken, NIST-deprecated since 2005. ECB leaks patterns in structured data. HIPAA requires strong encryption*

**3. HTTP Plaintext – Login API**
- Protocol: **HTTP (port 80)**, Encryption: **None (plaintext)**, Password: plain text in POST body
- ❌ *Credentials interceptable by anyone on network. "Internal network only" is NOT security. Must use HTTPS/TLS*

**4. DES Weak Key – Firmware Updates**
- Algorithm: **DES**, Key: **0x0101010101010101** (known weak key!), Mode: CBC
- ❌ *Known DES weak key produces identical encryption/decryption. Single DES already broken. Firmware needs AES-GCM*

**5. ROT13 – Financial Reports**
- Algorithm: **ROT13 encoding** (letter substitution A→N), Coverage: .xlsx and .pdf files
- ❌ *ROT13 is NOT encryption! Applied twice returns original. Zero security. No key = not encryption by definition*

**6. DES – Cloud Migration**
- Algorithm: **DES**, Key: **56 bits**, Mode: CBC, Storage: AWS S3, Data: HR records, contracts, payroll
- ❌ *Single DES NEVER for new systems. 56-bit brute-forcible in hours. AWS S3 offers AES-256 by default*

---

## 9. Cipher Defense Terminal

**Script:** `script/SOCMain.gd`
**Lesson:** 4.2 – AES Encryption Defense
**Type:** Command-typing defense game (10 waves)
**Max Score:** 500

### Command Database (9 commands)

| Command | Category | Description | Effective Against |
|---------|----------|-------------|-------------------|
| `enforce-aes256` | ALGORITHM | Upgrade to AES-256 key strength | Weak Key |
| `upgrade-cipher` | ALGORITHM | Replace deprecated cipher with AES | Legacy DES |
| `switch-to-cbc` | MODE | CBC mode hides data patterns | ECB Mode Leak |
| `enable-gcm` | MODE | Enable authenticated encryption (AEAD) | No Authentication Tag |
| `rotate-keys` | KEY MGMT | Enforce regular key rotation schedule | Key Never Rotated |
| `use-hsm` | KEY MGMT | Store keys in Hardware Security Module | Keys in Plain Text |
| `randomize-iv` | IV/NONCE | Generate random IV per encryption | IV Reuse |
| `add-hmac` | AUTH | Add HMAC to prevent padding oracle | Padding Oracle |
| `enforce-tls` | TRANSPORT | Encrypt data in transit with TLS | No Transit Encryption |

### Threat Types (9 vulnerabilities)

| Threat | Visual | Speed | Description | Impact | Correct Command |
|--------|--------|-------|-------------|--------|-----------------|
| Weak Key (56-bit) | 🔑 | 30 | 56-bit key — brute-forceable | Encryption cracked in hours | `enforce-aes256` |
| ECB Mode Leak | 📊 | 35 | ECB mode leaking patterns | Data patterns exposed | `switch-to-cbc` |
| Legacy DES | ⚠️ | 40 | Deprecated DES still active | Cipher broken — data exposed | `upgrade-cipher` |
| No Authentication Tag | 🔓 | 25 | Encryption without authentication | Ciphertext tampered undetected | `enable-gcm` |
| IV Reuse | 🔄 | 32 | Same IV used for every message | First blocks reveal patterns | `randomize-iv` |
| Key Never Rotated | 🗝️ | 38 | Same key used 3+ years | Years of data compromised if leaked | `rotate-keys` |
| Padding Oracle | 🧩 | 45 | Padding errors reveal plaintext | Full decryption via error leaks | `add-hmac` |
| Keys in Plain Text | 📄 | 42 | Encryption keys stored unprotected | All encrypted data exposed | `use-hsm` |
| No Transit Encryption | 📡 | 36 | Data sent over plain HTTP | Credentials intercepted on network | `enforce-tls` |

### Wave Progression

| Waves | Available Threats |
|-------|------------------|
| 1–3 | Weak Key, ECB Mode Leak, Legacy DES |
| 4–6 | + No Authentication Tag, IV Reuse |
| 7–10 | All 9 threats |

---

## 10. Crypto Sorter

**Script:** `script/crypto_sorter.gd`
**Lesson:** 5.1-5.2 – Symmetric & Asymmetric Cryptography
**Type:** Classification game (5 waves)
**Max Score:** 500

### Algorithms (12 total)

**Symmetric (6):**
| Algorithm | Key Detail |
|-----------|-----------|
| AES | Block cipher, 128/192/256-bit keys, gold standard |
| DES | Older, 56-bit key, now broken |
| 3DES | Triple DES, 112/168-bit security |
| Blowfish | Fast, 32–448 bit keys, variable length |
| ChaCha20 | Stream cipher, used in TLS 1.3 and WireGuard |
| Twofish | AES finalist, 256-bit keys, unpatented |

**Asymmetric (6):**
| Algorithm | Key Detail |
|-----------|-----------|
| RSA | Public/private key pair, factoring-based |
| Diffie-Hellman | Key exchange, discrete logarithm |
| ECC | Elliptic Curve, smaller keys (256-bit ECC ≈ 3072-bit RSA) |
| ElGamal | Based on DH, encryption + signatures |
| DSA | Digital Signature Algorithm only |
| RC4 | Stream cipher, deprecated, WEP vulnerable |

### Properties (12 total)

**Symmetric properties:**
- Uses ONE shared key for both encrypt and decrypt
- Much faster for large data amounts
- Key must be shared secretly before communication
- Typical key sizes: 128, 192, 256 bits
- Used for bulk data (files, disks, VPNs)
- Examples: AES, DES, 3DES, Blowfish, ChaCha20

**Asymmetric properties:**
- Uses PUBLIC key + PRIVATE key pair
- Solves key distribution problem
- Enables digital signatures for authentication
- Typical key sizes: 2048 or 4096 bits
- Used for key exchange, certificates, signatures
- Examples: RSA, ECC, DH, ElGamal, DSA

### Use Case Scenarios (8)

| Scenario | Answer | Reason |
|----------|--------|--------|
| Encrypting hard drive (BitLocker) | Symmetric (AES-256) | Speed needed for bulk data |
| Website HTTPS verification | Asymmetric (RSA/ECC) | Certificate verification |
| WhatsApp message encryption | Symmetric (AES-256 + Signal) | Speed for messages |
| Signing software updates | Asymmetric (RSA/DSA) | Authentication |
| VPN tunnel data | Symmetric (AES-256/ChaCha20) | Bulk encryption |
| Email PGP signature | Asymmetric (RSA/ECC) | Sign + verify identity |
| Database field encryption | Symmetric (AES-256) | Small data fields |
| SSH key authentication | Asymmetric (RSA/Ed25519) | Passwordless login |

### Challenge Questions (10)

| # | Question | Correct Answer |
|---|----------|---------------|
| 1 | Company encrypting 10 TB backup should use? | **Symmetric (AES)** – faster for bulk |
| 2 | Alice sends message only Bob can read, never met? | **Asymmetric (Bob's public key)** |
| 3 | In TLS/HTTPS, how are they used together? | **Asymmetric for key exchange, symmetric for data** |
| 4 | Main disadvantage of asymmetric? | **Very slow vs symmetric** (100–1000× slower) |
| 5 | Which is TRUE about key distribution? | **Symmetric keys via secure channel only** |
| 6 | Digital signatures use which type? | **Asymmetric** (sign private, verify public) |
| 7 | 256-bit AES ≈ what RSA size? | **15360-bit RSA** |
| 8 | Which based on factoring large primes? | **Asymmetric (RSA)** |
| 9 | In hybrid encryption, asymmetric encrypts? | **Symmetric session key** |
| 10 | Why prefer ECC over RSA in mobile? | **ECC same security smaller keys** |

---

## 11. RSA Key Lab

**Script:** `script/rsa_key_lab.gd`
**Lesson:** 6.2-6.4 – RSA, Diffie-Hellman & Cryptography in Practice
**Type:** Interactive cryptography lab (5 phases)
**Max Score:** 500

### Phase 1: RSA LEARN (6 guided steps)

| Step | Action | Example |
|------|--------|---------|
| 1 | Choose p, q (two primes) | p=3, q=11 |
| 2 | Compute n = p × q | n = 3 × 11 = 33 |
| 3 | Compute φ(n) = (p-1)(q-1) | φ(n) = 2 × 10 = 20 |
| 4 | Choose e where gcd(e, φ(n)) = 1 | e = 7 |
| 5 | Compute d where (d × e) mod φ(n) = 1 | d = 3 (3×7=21, 21 mod 20=1) |
| 6 | Public key: (e, n), Private key: (d, n) | Public (7,33), Private (3,33) |

**Encryption:** cipher = message^e mod n
**Decryption:** message = cipher^d mod n

### Phase 2: RSA PRACTICE (6 problems)

| # | p | q | Expected n | Expected φ(n) | Student computes d |
|---|---|---|-----------|---------------|-------------------|
| 1 | 3 | 11 | 33 | 20 | varies by e chosen |
| 2 | 5 | 7 | 35 | 24 | varies |
| 3 | 7 | 11 | 77 | 60 | varies |
| 4 | 5 | 13 | 65 | 48 | varies |
| 5 | 11 | 3 | 33 | 20 | varies |
| 6 | 7 | 13 | 91 | 72 | varies |

### Phase 3: DIFFIE-HELLMAN LEARN

Two people create a shared secret over a public channel:
1. Agree on prime p and generator g
2. Each picks a SECRET random number
3. Each computes a PUBLIC value from secret
4. Exchange public values (visible to anyone)
5. Each computes the SAME shared secret

**Security basis:** Discrete Logarithm Problem
**Used in:** TLS, VPNs, Signal, WhatsApp, SSH

### Phase 4: DIFFIE-HELLMAN PRACTICE (3 problems)

| # | p | g | Alice secret (a) | Bob secret (b) | Student computes A, B, shared secret |
|---|---|---|-----------------|----------------|--------------------------------------|
| 1 | 23 | 5 | 4 | 3 | A = 5^4 mod 23 = 4, B = 5^3 mod 23 = 10, s = 10^4 mod 23 = 18 |
| 2 | 29 | 2 | 5 | 7 | A = 2^5 mod 29 = 3, B = 2^7 mod 29 = 12, s = 12^5 mod 29 = 7 |
| 3 | 17 | 3 | 6 | 4 | A = 3^6 mod 17 = 15, B = 3^4 mod 17 = 13, s = 13^6 mod 17 = 1 |

Formula: A = g^a mod p, B = g^b mod p, shared secret s = B^a mod p = A^b mod p

### Phase 5: CRYPTOGRAPHY IN PRACTICE (10 scenario questions)

| # | Scenario | Options | Correct | Explanation |
|---|----------|---------|---------|-------------|
| 1 | Setting up HTTPS — what does the certificate contain? | Server's private key / **Server's public key + identity info** / Symmetric session key / User's password hash | 1 | Certificate contains PUBLIC key + identity, signed by CA. Private key never leaves server. |
| 2 | TLS handshake — how is pre-master secret sent to server? | Plaintext / **Encrypted with server's public key (RSA)** / Hashed with SHA-256 / Separate channel | 1 | Client encrypts pre-master secret with server's RSA public key. Only server can decrypt. |
| 3 | TLS 1.3 uses ECDHE instead of RSA key exchange — why? | Simpler / **Forward Secrecy** / RSA broken / ECDHE no certs needed | 1 | Forward Secrecy: if server's key compromised later, past sessions stay safe (unique keys per session). |
| 4 | Alice signs document with private key — what can Bob verify? | Encrypted by Alice / **Not tampered AND from Alice** / Confidential / Sent recently | 1 | Digital signatures = Authentication (from Alice) + Integrity (unmodified). |
| 5 | Switch RSA-2048 to ECC-256 — good idea? | No, 256 < 2048 / **Yes, ECC-256 ≈ RSA-3072** / No, not standardized / Only for symmetric | 1 | ECC-256 ≈ 128 bits security ≈ RSA-3072. ECC more efficient for mobile/IoT. |
| 6 | VPN established with RSA. What encrypts the data tunnel? | RSA encrypts all / **AES-256 (symmetric)** / DH encrypts data / No encryption after exchange | 1 | RSA only exchanges keys. AES-256 encrypts data (100-1000× faster) = hybrid encryption. |
| 7 | Why can't DH alone send encrypted email? | Too slow / Only exchanges keys / **Both parties must be online simultaneously** / Only 1024-bit keys | 2 | Classic DH is interactive (real-time exchange). Email is asynchronous. Use RSA/stored public key instead. |
| 8 | Bitcoin uses ECDSA — what does signing prove? | Amount correct / **Sender owns private key for address** / Transaction encrypted / Blockchain secure | 1 | ECDSA proves private key ownership, authorizing transaction without revealing the key. |
| 9 | PGP: encrypt body with AES, encrypt AES key with RSA — why not RSA for everything? | **RSA can only encrypt small data (< key size)** / RSA insecure for large / No reason / AES required by law | 0 | RSA max ~245 bytes for RSA-2048. Hybrid: RSA encrypts small key, AES encrypts large message. |
| 10 | MITM attack on DH — how to prevent? | Larger primes / **Authenticate public values using certificates** / DH over HTTPS only / Run DH twice | 1 | Plain DH has no authentication. Certificates (CA-signed) authenticate DH public values, preventing MITM. |

### Phase Tutorials (shown before each phase)

| Phase | Key Concepts |
|-------|-------------|
| RSA Learn | 6 steps of RSA key generation with small numbers |
| RSA Practice | Student computes n, φ(n), d from given p, q, e |
| DH Learn | Shared secret over public channel, discrete logarithm |
| DH Practice | Student computes A, B, shared secret from p, g, a, b |
| Practice Quiz | TLS, digital signatures, hybrid encryption, forward secrecy, certificates |

---

## 12. Password Fortress Defender

**Script:** `script/tutorial_password_basics.gd`
**Lesson:** 7.1 – Authentication
**Type:** Wave-based password battle (5 waves + tutorial + victory)
**Max Score:** 200

### Cybersecurity Terms Dictionary (12 terms)

| Term | Definition |
|------|-----------|
| Password | Secret word/phrase proving identity — like a key to your digital house |
| Strong Password | 12+ chars, mixed types (ABC, 123, !@#), no common words |
| Weak Password | Easy to guess: '123456', 'password', birthday — cracked in seconds |
| Hacker | Person who breaks into computers/accounts without permission |
| Brute Force Attack | Computer tries millions of combinations until finding the right one |
| Dictionary Attack | Uses list of common words to guess passwords |
| Pattern Attack | Detects keyboard patterns: 'qwerty', '12345', 'asdfgh' |
| Personal Info Attack | Uses your birthday, pet names, hobbies to guess |
| Rainbow Table | Pre-computed database of password hashes — instant lookup |
| Character | Any single letter, number, or symbol in your password |
| Special Characters | Symbols like !@#$%^&*() — exponentially harder to guess |
| Password Manager | Secure app remembering all passwords — only need one master password |

### Common Password Attempts (used by bot guessing)

```
password, 123456, admin, qwerty, letmein, welcome, monkey, dragon, master, sunshine,
password123, 12345678, abc123, iloveyou, admin123, Password1, Welcome1, Qwerty123, P@ssword, Admin@123
```

### Wave 0: Tutorial Briefing

Introduction to the game mechanic: BRIEFING → BUILD → BATTLE → VICTORY cycle.

### Wave 1: Dictionary Attack Bot

- **Enemy:** Dictionary Attack Bot (Power: 30, Speed: 0.8)
- **Attack method:** 10,000+ common passwords at 100/second
- **Stats:** 80% of people use dictionary words; "123456" is #1 used password; crack time: INSTANT
- **Requirements:** Min 8 chars, mix uppercase/lowercase, no real words, add numbers/symbols
- **Unlocks:** lowercase

### Wave 2: Brute Force Attack Bot

- **Enemy:** Brute Force Bot (Power: 50, Speed: 0.6)
- **Attack method:** Tries EVERY combination at 1,000,000/second
- **Crack time examples:**
  - 6 chars lowercase: 2 seconds
  - 8 chars mixed case: 1 hour
  - 10 chars letters+numbers: 3 weeks
  - 12 chars all types: 34,000 YEARS
- **Requirements:** Min 12 chars, uppercase + lowercase + numbers + symbols
- **Unlocks:** UPPERCASE letters

### Wave 3: Pattern Recognition Bot

- **Enemy:** Pattern Bot (Power: 60, Speed: 0.5)
- **Attack method:** AI-powered keyboard pattern detection (rows, columns, sequences, repeating)
- **Stats:** "qwerty" is 4th most common; 15% of passwords are patterns
- **Requirements:** Avoid keyboard patterns, no sequential numbers, mix randomly, special chars between letters
- **Unlocks:** NUMBERS

### Wave 4: Personal Info Sniper Bot

- **Enemy:** Social Engineer Bot (Power: 70, Speed: 0.4)
- **Attack method:** Scrapes social media (Facebook, Instagram, LinkedIn, Twitter) for personal info
- **Stats:** 50% use personal info; average person has 100+ facts online; cracked in minutes
- **Requirements:** Min 14 chars, NEVER use name/birthday/pet, no social media info, random unrelated words
- **Unlocks:** SPECIAL CHARACTERS (!@#$%)

### Wave 5: Rainbow Table Assassin

- **Enemy:** Rainbow Table Bot (Power: 85, Speed: 0.3)
- **Attack method:** Pre-computed hash tables with billions of entries — INSTANT lookup
- **How it works:** Websites hash passwords → hackers create massive databases of pre-cracked hashes
- **Stats:** 100+ billion hashes; simple passwords cracked in milliseconds
- **Requirements:** Min 16+ chars (rainbow tables can't pre-compute long passwords), maximum randomness, every character type, truly unique
- **Unlocks:** Extended length (16+)

### Victory Screen

**Real-world tips:**
1. Use a Password Manager (1Password, Bitwarden, LastPass)
2. Never reuse passwords across sites
3. Change passwords if you suspect a breach
4. Enable 2FA everywhere
5. Min 12 chars for regular accounts, 16 chars for important accounts

**Formula:** Length > Complexity > Everything Else (16 lowercase chars > 8 chars with everything)

---

## 13. Security Guardian

**Script:** `script/authgmMain.gd` + `script/ScenarioDatabase.gd`
**Lesson:** 7.1 – Authentication Systems
**Type:** Grant/Deny/Require MFA decision game (10 waves, 3 scenarios per wave = 30 total)
**Max Score:** 500

### All 30 Scenarios by Wave

#### Wave 1: AUTHENTICATION BASICS — Understanding WHO is requesting access

| # | User | Role | Resource | Location | Device | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Sarah Chen | employee | Marketing Shared Drive | Seattle, WA | Company Laptop | — | **GRANT** | No | Simple password auth acceptable for low-risk with normal context | Don't over-restrict — balance security with productivity | 10 |
| 2 | James Wilson | employee | Employee Portal | Seattle, WA | Company Laptop | `mfa_failed` | **DENY** | Yes | Failed auth = deny. Fundamental Rule #1 | BREACH! Never grant when auth fails. Authentication verifies WHO | 45 |
| 3 | Marcus Johnson | intern | Financial Database | Seattle, WA | Company Laptop | — | **DENY** | No | Auth passed (WHO) but authorization failed (WHAT). Interns lack financial access | Auth ≠ Authorization! Proved WHO but don't have permission for WHAT | 30 |

#### Wave 2: MULTI-FACTOR AUTHENTICATION (MFA) — Strengthening WHO verification

| # | User | Role | Resource | Location | Device | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Dr. Elena Rodriguez | admin | User Management Console | Public WiFi - Coffee Shop | Personal Laptop | `public_network`, `personal_device` | **REQUIRE MFA** | No | Password-only auth is weak. MFA adds 'something you have' = 99% attack prevention | Passwords can be stolen. MFA requires second factor to prove WHO | 35 |
| 2 | Lisa Wong | developer | Production Database Access | Seattle, WA | Company Laptop | — | **REQUIRE MFA** | No | Critical resources ALWAYS require MFA, even in normal conditions. Defense in depth! | Critical systems need MFA. One compromised password = entire DB breach | 40 |
| 3 | James Park | developer | Production Code Repository | Seattle, WA | Work Laptop | — | **GRANT** | No | MFA completed = strong authentication. All context normal. Proper security! | Don't over-restrict legitimate users who completed proper MFA | 15 |
| 4 | Robert Martinez | employee | Email System | Seattle, WA | Company Phone | `mfa_failed` | **DENY** | Yes | MFA failure = auth failure. Even for low risk, failed auth = DENY | BREACH! Attacker tried stolen password, didn't have second factor. MFA stopped this | 40 |

#### Wave 3: AUTHENTICATION CONTEXT — Location, Time, Device matter

| # | User | Role | Resource | Location | Device | Time | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Sarah Chen | employee | Company Wiki | Tokyo, Japan | Personal Phone | 22:00 PST | — | **GRANT** | No | Business travel is normal. Different location isn't suspicious if it makes sense | Don't deny legitimate travel! Context awareness means understanding user patterns | 15 |
| 2 | Elena Rodriguez | admin | Server Access | Moscow, Russia | Unknown Device | 03:00 PST | `wrong_location`, `unknown_device`, `unusual_time` | **REQUIRE MFA** | No | Unusual context = verify harder. MFA confirms WHO despite red flags | Multiple red flags demand stronger authentication! MFA verifies identity | 35 |
| 3 | James Park | developer | AWS Console | Lagos, Nigeria | Unknown Device | 04:30 PST | `mfa_failed`, `wrong_location`, `unknown_device`, `unusual_time` | **DENY** | Yes | Failed auth + suspicious context = credential theft. Authentication stopped this! | CRITICAL BREACH! Stolen credentials from different country. MFA failure is key | 55 |

#### Wave 4: AUTHENTICATION LEVELS — Different strengths for different needs

| # | User | Role | Resource | Location | Device | Time | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Priya Sharma | contractor | Client Database - Read Only | Mumbai, India | Personal Device | 09:00 PST | — | **GRANT** | No | MFA auth for contractors accessing client data is appropriate | Contractors with proper MFA and valid contracts should have access | 20 |
| 2 | Priya Sharma | contractor | Client Database - Full Access | Mumbai, India | Personal Device | 02:30 PST | `contract_expired`, `unusual_time` | **DENY** | No | Contract expired = credentials should be revoked. MFA doesn't help if account should be disabled! | MAJOR BREACH! Former contractor retained access. Auth management includes disabling old accounts | 45 |
| 3 | Dr. Elena Rodriguez | admin | Domain Controller Access | Seattle, WA | Company Laptop + Hardware Token | 10:00 PST | — | **GRANT** | No | Hardware token = strongest auth (Level 3). Something you HAVE + can't be phished! | Gold standard authentication! Hardware tokens = cryptographic proof of identity | 10 |

#### Wave 5: SESSION HIJACKING & RE-AUTHENTICATION

| # | User | Role | Resource | Location | Device | Time | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | James Park | developer | Deploy to Production Servers | Seattle, WA | Work Laptop | 23:00 PST Fri | `unusual_time` | **GRANT** | No | Late deployment with proper MFA acceptable. Auth context considers job role patterns | Developers often deploy after hours. Strong auth allows flexibility | 20 |
| 2 | Sarah Chen | employee | Download Customer Database (500GB) | Seattle, WA | Company Laptop | 14:00 PST | `unusual_request`, `large_download` | **REQUIRE MFA** | No | Unusual behavior = re-authenticate! Step-up auth for sensitive actions in active session | HR downloading entire customer DB is unusual! Re-auth verifies it's really them | 40 |
| 3 | Lisa Wong | developer | Change Password for User 'admin' | Seattle, WA | Work Laptop | 15:30 PST | `privilege_escalation` | **DENY** | Yes | Session hijacked! Real user authenticated, but attacker took over. Unusual action reveals attack | BREACH! Attacker hijacked session. Authentication isn't just login — monitor ongoing activity | 50 |

#### Wave 6: BIOMETRIC & ADAPTIVE AUTHENTICATION

| # | User | Role | Resource | Location | Device | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Dr. Elena Rodriguez | admin | Security Audit Logs | Seattle, WA | Company Laptop + Fingerprint | — | **GRANT** | No | Biometric + hardware token = multi-modal authentication. Extremely secure! | Best-practice authentication! Biometrics = 'something you ARE' factor | 10 |
| 2 | Alex Thompson | employee | Change Email Forwarding Rules | Seattle, WA | Company Laptop | `unusual_request` | **REQUIRE MFA** | No | Adaptive authentication! Email forwarding = attack indicator — verify identity again | Email forwarding = common attack vector. Re-auth for sensitive settings changes | 35 |
| 3 | Marcus Johnson | intern | VPN Access from New Location | Home (First Time) | Personal Laptop | `unknown_device` | **REQUIRE MFA** | No | Risk-based authentication! New device/location = verify more thoroughly | First-time access from new location should trigger MFA. Adaptive security! | 30 |

#### Wave 7: SOCIAL ENGINEERING & AUTHENTICATION BYPASS

| # | User | Role | Resource | Location | Device | Time | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Marcus Johnson | intern | Admin Panel Access | Seattle, WA | Company Laptop | 02:00 PST | `unusual_time`, `privilege_escalation`, `social_engineering` | **DENY** | Yes | Social engineering detected. Auth succeeded but authorization violated. 'CEO urgent request' = classic attack | COMPROMISED! Stolen intern credentials + social engineering. Check authorization! | 55 |
| 2 | IT Support | employee | Password Reset for 'Elena Rodriguez' | Seattle, WA | Help Desk System | 16:00 PST | `social_engineering` | **REQUIRE MFA** | Yes | Password reset requests should verify BOTH agent AND account owner via out-of-band MFA | ATTACK! Attacker impersonated IT support. Password resets need multi-channel verification | 50 |
| 3 | Sarah Chen | employee | Click Link in Email: 'Reset Your Password' | Seattle, WA | Company Laptop | 10:00 PST | `social_engineering` | **DENY** | Yes | Phishing attack! Never authenticate via email links. Go directly to official site | PHISHED! Email links can lead to fake auth pages. Always verify URL before entering credentials | 45 |

#### Wave 8: ZERO TRUST & CONTINUOUS AUTHENTICATION

| # | User | Role | Resource | Location | Device | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | James Park | developer | Access Git Repository | Seattle, WA | Work Laptop | — | **GRANT** | No | Zero Trust ≠ deny everything — verify everything. Normal activity + proper auth = grant | Zero Trust = verify, not deny. Authenticated users doing normal work should have access | 15 |
| 2 | James Park | developer | Delete Production Database Backups | Seattle, WA | Work Laptop | `destructive_action`, `unusual_request` | **DENY** | Yes | Never trust, always verify. Destructive actions need re-auth + approval! | CATASTROPHIC! Ransomware using compromised session. Continuous auth monitors behavior | 60 |
| 3 | Lisa Wong | developer | Install Backdoor Service | Seattle, WA | Work Laptop + Hardware Token | `unusual_request` | **DENY** | Yes | Even strong auth doesn't mean blind trust. Unusual behavior = deny + investigate! | BREACH! Strong auth bypassed via compromised device. Zero Trust = continuous verification | 55 |

#### Wave 9: AUTHENTICATION BEST PRACTICES

| # | User | Role | Resource | Location | Device | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Dr. Elena Rodriguez | admin | View Security Policies | Seattle, WA | Company Laptop + Hardware Token | — | **GRANT** | No | Legitimate admin with strongest auth. Textbook proper access! | False denial. Don't over-restrict properly authenticated administrators | 10 |
| 2 | Automated Service | service_account | Backup Database at 2 AM | Internal Network | Backup Server | — | **GRANT** | No | Service account auth with API keys/certificates. Scheduled tasks normal at odd hours! | Service accounts need auth too! API keys, certificates = non-human auth methods | 25 |
| 3 | Guest WiFi | guest | Internal File Servers | Office - Guest Network | Unknown Device | `wrong_network` | **DENY** | Yes | Network segmentation + auth. Guest network should NEVER access internal resources! | BREACH! Guest WiFi lacks proper auth for internal access. Network boundaries matter | 50 |

#### Wave 10: FINAL EXAM — Complex Authentication Scenarios

| # | User | Role | Resource | Location | Device | Time | Flags | Correct | Attacker? | Feedback (Correct) | Feedback (Incorrect) | Consequence |
|---|------|------|----------|----------|--------|------|-------|---------|-----------|-------------------|---------------------|-------------|
| 1 | Alex Thompson | employee | Access Personal Files | Seattle, WA | Company Laptop | 13:00 PST | — | **GRANT** | No | MFA completed, normal context, appropriate resource. Efficient security allows productivity! | Don't block legitimate work! Auth is about protecting, not obstructing | 10 |
| 2 | Alex Thompson | employee | Install Unapproved Software: 'Productivity Tool' | Seattle, WA | Company Laptop | 13:00 PST | `unapproved_software` | **DENY** | No | Auth passed but authorization failed. Software install needs admin privileges + approval! | MALWARE! Authentication confirms WHO, not WHAT. Privilege separation prevents this | 55 |
| 3 | CFO Office | executive | Wire Transfer $50,000 | Seattle, WA | Company Desktop | 16:45 PST | `social_engineering` | **REQUIRE MFA** | Yes | BEC (Business Email Compromise) attack! Financial transactions need multi-person auth! | $50,000 STOLEN! Never trust urgent financial requests. Require MFA + callback verification | 60 |
| 4 | System Administrator | admin | Emergency Server Restart | Seattle, WA | Admin Workstation + Hardware Token | 03:00 PST | `unusual_time` | **GRANT** | No | IT emergencies happen at odd hours. Strongest auth + admin role = appropriate access! | False denial during emergency! Proper auth allows admins to respond to critical issues | 30 |

---

## 14. CIA Triad Challenge

**Script:** `script/tutorial_cia_triad.gd`
**Lesson:** 2.1 – CIA Triad Classification
**Type:** Multiple-choice drag classification (10 random from pool of 21)
**Scoring:** 10 scenarios per game, shuffled from full pool

### All 21 Scenarios

#### CONFIDENTIALITY (7 scenarios) — Correct answer: C

| # | Scenario | Explanation |
|---|----------|-------------|
| 1 | Hospital computer system breached via weak password. 10,000 patient medical records exposed on internet. | Confidentiality = keeping data PRIVATE. Patient records exposed to unauthorized people. |
| 2 | Laptop stolen from coffee shop with unprotected company financial reports and credit card info. | Sensitive financial data can now be SEEN by unauthorized people (the thief). |
| 3 | Employee plugged in parking-lot USB labeled 'Employee Salaries 2025'. Hidden virus copied and sent company files to criminals. | Virus STOLE and SENT files to attackers. Private data exposed to unauthorized parties. |
| 4 | Hacker intercepted unencrypted emails with SSNs and bank details of 500 customers. | Sensitive data EXPOSED through interception. |
| 5 | Employee accidentally emailed entire customer database to wrong recipient outside company. | Confidential info DISCLOSED to unauthorized external parties. |
| 6 | Someone photographed confidential documents on unattended office computer screens. | Confidential info ACCESSED and potentially copied by unauthorized individuals. |
| 7 | Internal chat logs about unreleased products leaked to competitor through former employee. | Proprietary info DISCLOSED to competitors. |

#### INTEGRITY (7 scenarios) — Correct answer: I

| # | Scenario | Explanation |
|---|----------|-------------|
| 1 | Hacker changed 20 students' report card grades from C to A. | Integrity = data stays ACCURATE and UNCHANGED. Grades modified incorrectly. |
| 2 | Attackers replaced company homepage with graffiti and fake news about CEO. | Website content was TAMPERED with. |
| 3 | Insider changed online store prices from $1,000 to $1 before purchasing. | Product pricing ALTERED without authorization. |
| 4 | Hackers modified bank account balances, transferring money to fake accounts. | Financial records TAMPERED with, making data inaccurate. |
| 5 | Attacker altered security system timestamp logs to hide building break-in evidence. | Audit logs MODIFIED to conceal unauthorized activity. |
| 6 | Someone intercepted payment and changed recipient's bank account number. | Transaction data ALTERED during transmission. |
| 7 | Disgruntled employee modified customer shipping addresses, sending orders to wrong locations. | Customer data CORRUPTED through unauthorized modifications. |

#### AVAILABILITY (7 scenarios) — Correct answer: A

| # | Scenario | Explanation |
|---|----------|-------------|
| 1 | Virus locked all company files, demanding payment. No email, payroll, or docs for 2 days. | Availability = systems ACCESSIBLE when needed. Virus blocked access, didn't steal or change data. |
| 2 | Millions of fake visitors flooded shopping website. Real customers can't load or buy. | Website BLOCKED from legitimate users. Data not stolen/changed, just inaccessible. |
| 3 | Backup storage destroyed in fire. 6 months of data unrecoverable. | Data couldn't be ACCESSED when needed due to failed backups. |
| 4 | Power outage took hospital patient monitoring offline for 3 hours. | Critical systems UNAVAILABLE when needed. |
| 5 | Hackers crashed airline booking system during peak holiday season for 48 hours. | Service DISRUPTED and inaccessible to users. |
| 6 | Construction crew cut fiber optic cable — company internet/cloud down all day. | Network services UNAVAILABLE. |
| 7 | Misconfigured update crashed email server. No email for entire morning shift. | Email service INACCESSIBLE due to system failure. |

---

## 15. Hash Integrity Game (Bonus)

**Script:** `script/hash_integrity_game.gd`
**Type:** Hash verification mini-game

### File Database (8 files)

| File | Content | Icon |
|------|---------|------|
| config.txt | `server_ip=192.168.1.1` | 📄 |
| user_data.json | `{"users":["alice","bob"]}` | 📋 |
| payment.dat | `amount=500&recipient=alice` | 💳 |
| update.exe | `binary_executable_data` | ⚙️ |
| certificate.pem | `-----BEGIN CERTIFICATE-----` | 🔐 |
| backup.tar | `compressed_backup_data` | 📦 |
| credentials.xml | `<user>admin</user><pass>secret</pass>` | 🔑 |
| database.sql | `SELECT * FROM users WHERE admin=1` | 🗄️ |

### Hash Algorithms

| Algorithm | Strength | Collision Chance |
|-----------|----------|-----------------|
| MD5 | ❌ Broken | 80% |
| SHA-1 | ⚠️ Weak | 30% |
| SHA-256 | ✅ Strong | 0% |

### Challenges (4)

| Challenge | Description | Target |
|-----------|-------------|--------|
| Speed Run | Detect 5 tampered files in 20 seconds | 5 files |
| Perfect Score | No mistakes allowed for 10 files | 10 files, 0 mistakes |
| Algorithm Master | Use only SHA-256 for 8 files | 8 files, SHA-256 only |
| Under Pressure | 15 second time limit per file | 5 files |

---

*End of Complete Minigame Content Database — 15 games, all raw scenario data included.*
| Secret | a (random) | b (random) |
| Public | A = g^a mod p | B = g^b mod p |
| Shared | s = B^a mod p | s = A^b mod p |

Both compute the same shared secret s.

### Phase 5: CRYPTOGRAPHY IN PRACTICE (10 scenarios)

| # | Topic | Key Concept |
|---|-------|-------------|
| 1 | TLS handshake | Client encrypts pre-master secret with server's RSA public key |
| 2 | TLS 1.3 ECDHE vs RSA | ECDHE provides forward secrecy — unique session keys |
| 3 | SSH key authentication | Public key on server, private on machine — passwordless |
| 4 | Email PGP | Sender signs with private key, recipient verifies with sender's public key |
| 5 | VPN key exchange | Asymmetric for initial exchange, symmetric (AES) for data |
| 6 | Certificate verification | Certificate contains server's public key, signed by trusted CA |
| 7 | Blockchain Bitcoin | Uses ECDSA — proves sender has private key for address |
| 8 | ECC migration | ECC-256 ≈ RSA-3072 in security, smaller keys, faster on mobile/IoT |
| 9 | Hybrid encryption | RSA can only encrypt ~245 bytes (RSA-2048). Must use hybrid for large messages |
| 10 | Man-in-Middle defense | CA-signed certificates authenticate DH public values to prevent MITM |

---

## 12. Password Fortress Defender

**Script:** `script/tutorial_password_basics.gd`
**Lesson:** 7.1 – Authentication
**Type:** Educational battle game (8 waves)
**Max Score:** 200

### Wave 1: DICTIONARY ATTACK BOT

**Enemy:** Database of 10,000+ common passwords, 100 passwords/second
**Targets:** "password", "123456", "welcome", "qwerty", common names, simple words

**Defense requirements:**
- Minimum 8 characters
- Mix uppercase and lowercase
- No real dictionary words
- Add numbers and symbols

**Stat:** 80% of people use dictionary words. "123456" is #1 most used password.

### Wave 2: BRUTE FORCE ATTACK BOT

**Enemy:** Tries EVERY possible combination at 1,000,000/second

**Crack times by complexity:**
| Type | Time |
|------|------|
| 6 chars (lowercase) | 2 seconds |
| 8 chars (lower + upper) | 1 hour |
| 10 chars (letters + numbers) | 3 weeks |
| 12 chars (all types) | 34,000 YEARS |

**Defense:** Minimum 12 characters, all character types
**Unlock:** Uppercase letters enabled

### Wave 3: PATTERN RECOGNITION BOT

**Enemy:** AI-powered pattern detection, keyboard pattern recognition
**Targets:** "qwerty", "12345", "asdfgh", keyboard rows/columns/sequences/repeats

**Defense:** Avoid keyboard patterns, no sequences, random mix, special chars between letters
**Unlock:** Numbers enabled
**Stat:** 15% of passwords are keyboard patterns. "qwerty" is #4 most common.

### Wave 4: PERSONAL INFO SNIPER BOT

**Enemy:** Social media scraping — birthdays, pet names, hobbies
**Research sources:** Facebook, Instagram, LinkedIn, Twitter
**Targets:** "john2010", "fluffy123", "soccer2024"

**Defense:** Never use name/birthday/pet, no social media info, random unrelated words + symbols
**Unlock:** Special characters (!@#$%) enabled
**Stat:** 50% use personal info. 100+ facts about average person are online.

### Wave 5: RAINBOW TABLE ASSASSIN

**Enemy:** Pre-computed hash tables with billions of passwords, INSTANT lookup

**How it works:** Websites hash passwords ("password" → "5f4dcc3b5aa765d61d8327deb882cf99"). Rainbow tables have billions pre-hashed — just look up the hash.

**Defense:** Minimum 16+ characters, maximum randomness, all types, truly unique, never reused
**Unlock:** Extended length limit (16+ chars)

### Waves 6–7: Advanced Combinations

Higher-difficulty combinations of previous attack types.

### Wave 8: COMPLETE – Mission Accomplished

**Real-World Tips:**
1. Use a Password Manager (1Password, Bitwarden, LastPass)
2. Never reuse passwords
3. Change passwords on breach
4. Enable 2FA everywhere
5. 12+ chars for regular, 16+ for important

**Key formula:** Length > Complexity > Everything Else (16-char lowercase > 8-char complex)

---

## 13. Security Guardian

**Script:** `script/authgmMain.gd` + `script/ScenarioDatabase.gd`
**Lesson:** 7.1 – Authentication Systems
**Type:** Decision-making game (10 waves, 3 scenarios per wave = 30 total)
**Max Score:** 500
**Actions:** Grant ✅ | Deny ❌ | Require MFA 🔒

### Wave 1: AUTHENTICATION BASICS – Understanding WHO is requesting access

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Sarah Chen | Employee | Marketing Shared Drive | Seattle | Company Laptop | 14:35 | — | ✅ Grant |
| James Wilson | Employee | Employee Portal | Seattle | Company Laptop | 09:00 | MFA failed | ❌ Deny |
| Marcus Johnson | Intern | Financial Database | Seattle | Company Laptop | 10:20 | — | ❌ Deny |

*Wave 1 lessons: Failed auth = deny. Authentication ≠ Authorization (WHO ≠ WHAT).*

### Wave 2: MULTI-FACTOR AUTHENTICATION – Strengthening WHO verification

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Dr. Elena Rodriguez | Admin | User Management Console | Public WiFi - Coffee Shop | Personal Laptop | 19:45 | Public network, personal device | 🔒 Require MFA |
| Lisa Wong | Developer | Production Database | Seattle | Company Laptop | 15:00 | — | 🔒 Require MFA |
| James Park | Developer | Production Code Repo | Seattle | Work Laptop | 16:00 | — | ✅ Grant |
| Robert Martinez | Employee | Email System | Seattle | Company Phone | 11:30 | MFA failed | ❌ Deny |

*Wave 2 lessons: Critical resources ALWAYS need MFA. MFA failure = deny. Public WiFi = extra caution.*

### Wave 3: AUTHENTICATION CONTEXT – Location, Time, Device matter

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Sarah Chen | Employee | Company Wiki | Tokyo, Japan | Personal Phone | 22:00 PST | — | ✅ Grant |
| Elena Rodriguez | Admin | Server Access | Moscow, Russia | Unknown Device | 03:00 | Wrong location, unknown device, unusual time | 🔒 Require MFA |
| James Park | Developer | AWS Console | Lagos, Nigeria | Unknown Device | 04:30 | MFA failed, wrong location, unknown device, unusual time | ❌ Deny |

*Wave 3 lessons: Business travel is normal. Multiple red flags = verify harder. Failed auth + suspicious context = credential theft.*

### Wave 4: AUTHENTICATION LEVELS – Different strengths for different needs

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Priya Sharma | Contractor | Client Database (Read Only) | Mumbai | Personal Device | 09:00 | — | ✅ Grant |
| Priya Sharma | Contractor | Client Database (Full Access) | Mumbai | Personal Device | 02:30 | Contract expired, unusual time | ❌ Deny |
| Dr. Elena Rodriguez | Admin | Domain Controller | Seattle | Laptop + Hardware Token | 10:00 | — | ✅ Grant |

*Wave 4 lessons: Expired contracts = revoke access. Hardware tokens = strongest authentication (Level 3).*

### Wave 5: SESSION HIJACKING & RE-AUTHENTICATION

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| James Park | Developer | Deploy to Production | Seattle | Work Laptop | 23:00 Fri | Unusual time | ✅ Grant |
| Sarah Chen | Employee | Download Customer DB (500GB) | Seattle | Company Laptop | 14:00 | Unusual request, large download | 🔒 Require MFA |
| Lisa Wong | Developer | Change Password for 'admin' | Seattle | Work Laptop | 15:30 | Privilege escalation | ❌ Deny |

*Wave 5 lessons: Developers deploy after hours. Unusual behavior = re-authenticate. Session hijacking detected by unusual actions.*

### Wave 6: BIOMETRIC & ADAPTIVE AUTHENTICATION

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Dr. Elena Rodriguez | Admin | Security Audit Logs | Seattle | Laptop + Fingerprint | 09:00 | — | ✅ Grant |
| Alex Thompson | Employee | Change Email Forwarding Rules | Seattle | Company Laptop | 14:00 | Unusual request | 🔒 Require MFA |
| Marcus Johnson | Intern | VPN Access from New Location | Home (first time) | Personal Laptop | 18:00 | Unknown device | 🔒 Require MFA |

*Wave 6 lessons: Biometric + hardware token = multi-modal (very secure). Email forwarding = common attack vector. New device/location = verify identity.*

### Wave 7: SOCIAL ENGINEERING & AUTHENTICATION BYPASS

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Marcus Johnson | Intern | Admin Panel Access | Seattle | Company Laptop | 02:00 | Unusual time, privilege escalation, social engineering | ❌ Deny |
| IT Support | Employee | Password Reset for 'Elena Rodriguez' | Seattle | Help Desk | 16:00 | Social engineering | 🔒 Require MFA |
| Sarah Chen | Employee | Click Link: 'Reset Your Password' | Seattle | Company Laptop | 10:00 | Social engineering | ❌ Deny |

*Wave 7 lessons: "CEO urgent request" = classic social engineering. Password resets need multi-channel verification. Never authenticate via email links (phishing).*

### Wave 8: ZERO TRUST & CONTINUOUS AUTHENTICATION

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| James Park | Developer | Access Git Repository | Seattle | Work Laptop | 10:00 | — | ✅ Grant |
| James Park | Developer | Delete Production DB Backups | Seattle | Work Laptop | 15:30 | Destructive action, unusual request | ❌ Deny |
| Lisa Wong | Developer | Install Backdoor Service | Seattle | Work Laptop + HW Token | 14:00 | Unusual request | ❌ Deny |

*Wave 8 lessons: Zero Trust = verify, not deny everything. Destructive actions need re-auth + approval. Strong auth doesn't mean blind trust.*

### Wave 9: AUTHENTICATION BEST PRACTICES

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Dr. Elena Rodriguez | Admin | View Security Policies | Seattle | Laptop + HW Token | 10:00 | — | ✅ Grant |
| Automated Service | Service Account | Backup Database at 2 AM | Internal Network | Backup Server | 02:00 | — | ✅ Grant |
| Guest WiFi | Guest | Internal File Servers | Office - Guest Network | Unknown Device | 11:00 | Wrong network | ❌ Deny |

*Wave 9 lessons: Properly authenticated admins should work normally. Service accounts use API keys/certificates. Guest network must NEVER access internal resources.*

### Wave 10: FINAL EXAM – Complex Authentication Scenarios

| User | Role | Resource | Location | Device | Time | Flags | Correct Action |
|------|------|----------|----------|--------|------|-------|---------------|
| Alex Thompson | Employee | Access Personal Files | Seattle | Company Laptop | 13:00 | — | ✅ Grant |
| Alex Thompson | Employee | Install Unapproved Software | Seattle | Company Laptop | 13:00 | Unapproved software | ❌ Deny |
| CFO Office | Executive | Wire Transfer $50,000 | Seattle | Company Desktop | 16:45 | Social engineering | 🔒 Require MFA |
| System Administrator | Admin | Emergency Server Restart | Seattle | Admin Workstation + HW Token | 03:00 | Unusual time | ✅ Grant |

*Wave 10 lessons: Authentication confirms WHO, authorization controls WHAT. BEC attacks target financial transactions. IT emergencies happen at odd hours — strong auth allows response.*

---

## Summary

| # | Game | Lesson | Content Items | Max Score |
|---|------|--------|---------------|-----------|
| 1 | Cybersecurity Fundamentals | 1.1 | 3 sections | 100 |
| 2 | Network Basics + Defense Game | 1.2 | 4 sections + 16 challenges | 150+ |
| 3 | Drop Zone Defender | 1.2 | 10 attack types × 8 waves | 500 |
| 4 | Threat Identification Lab | 2.2 | 18 scenarios (6 per game) | 100 |
| 5 | Asset vs Threats | 2.2 | 8 threats × 5 waves | 500 |
| 6 | Encryption (Caesar Cipher) | 3.1 | 6 decrypt challenges | Time-only |
| 7 | Crypt Contract | 3.2 | 5 missions × 5 messages | 500 |
| 8 | Encryption Audit Lab | 3.3/4.1 | 18 scenarios (8 per game) | 1200 |
| 9 | Cipher Defense Terminal | 4.2 | 9 commands × 9 threats × 10 waves | 500 |
| 10 | Crypto Sorter | 5.1-5.2 | 12 algorithms + 8 scenarios + 10 MCQs | 500 |
| 11 | RSA Key Lab | 6.2-6.4 | 6 RSA + DH practice + 10 scenarios | 500 |
| 12 | Password Fortress Defender | 7.1 | 5 attack types × 8 waves | 200 |
| 13 | Security Guardian | 7.1 | 30 scenarios (10 waves × 3) | 500 |
