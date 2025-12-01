# Validation Test Scenarios
## Comprehensive Testing Guide for System Validators

---

## Introduction

This document provides step-by-step test scenarios for validators to thoroughly evaluate the multi-game social platform. Each scenario includes:
- **Prerequisites** - Setup requirements
- **Test Steps** - Detailed instructions
- **Expected Results** - What should happen
- **Pass/Fail Criteria** - Clear success indicators

---

## Setup Requirements

### Required Equipment
- [ ] 2 devices for multiplayer testing (PC, laptop, or mobile)
- [ ] Different network connections (WiFi + mobile data recommended)
- [ ] Internet connectivity
- [ ] Audio output for testing music/sound effects

### Test Accounts
- [ ] Create 2 test user accounts before testing
- [ ] Or use Google OAuth for quick setup

---

## Test Scenario 1: Authentication & User Management

### TC-001: User Registration

**Prerequisites:** Application installed and launched

**Test Steps:**
1. Launch the application
2. Click "Sign Up" button
3. Enter email: `validator1@test.com`
4. Enter password: `TestPass123!`
5. Enter username: `Validator1`
6. Select an avatar
7. Click "Create Account"

**Expected Results:**
- Account created successfully
- User redirected to landing page
- User profile displays: username, avatar, level 1, 0 wins/losses

**Pass Criteria:** ✅ User can register and see their profile

---

### TC-002: Google OAuth Login

**Test Steps:**
1. Click "Login with Google"
2. Select Google account
3. Grant permissions

**Expected Results:**
- Authentication successful
- User redirected to landing page
- Profile populated from Google account

**Pass Criteria:** ✅ OAuth login completes without errors

---

### TC-003: Online Presence

**Test Steps:**
1. Login on Device 1 with User A
2. Login on Device 2 with User B
3. On Device 1, check friend list or user search
4. Verify User B shows as "online" (green indicator)
5. Close app on Device 2
6. Wait 5 seconds
7. Check Device 1 again

**Expected Results:**
- User B shows as "online" when logged in
- User B shows as "offline" after app closes

**Pass Criteria:** ✅ Presence updates within 10 seconds

---

## Test Scenario 2: Social Features

### TC-004: Real-Time Chat

**Prerequisites:** 2 users logged in on different devices

**Test Steps:**
1. Device 1: Open chat with User B
2. Device 1: Send message "Hello from Validator!"
3. Device 2: Open chat with User A
4. Verify message appears

**Expected Results:**
- Message delivered within 3 seconds
- Message appears in correct chat thread
- Timestamp is accurate

**Pass Criteria:** ✅ Messages sync in real-time

---

### TC-005: Unread Message Counter

**Test Steps:**
1. Device 1: Send 3 messages to User B
2. Device 2: Check chat list (DO NOT open chat)
3. Verify unread counter shows "3"
4. Device 2: Open chat
5. Verify counter clears

**Expected Results:**
- Unread counter accurate
- Counter clears when chat opened
- Badge notification visible

**Pass Criteria:** ✅ Unread tracking works correctly

---

## Test Scenario 3: WebSocket Relay Architecture

### TC-006: Cross-Network Connectivity

**Prerequisites:** 2 devices on DIFFERENT networks (home WiFi + mobile data)

**Test Steps:**
1. Device 1 (WiFi): Create Code Breaker room
2. Device 2 (Mobile Data): Refresh lobby list
3. Verify room appears
4. Device 2: Join room
5. Check console logs for "Relay connected!"

**Expected Results:**
- Room visible across networks
- Both devices connect to relay
- No port forwarding required

**Pass Criteria:** ✅ Connection succeeds across different networks

---

### TC-007: Host Disconnect & Promotion

**Test Steps:**
1. Device 1 (Host): Create room
2. Device 2 (Client): Join room
3. Both verify relay connection
4. Device 1: Close application (force quit)
5. Device 2: Wait 5 seconds
6. Verify Device 2 promoted to host

**Expected Results:**
- Client promoted to host automatically
- Room remains active
- No data loss

**Pass Criteria:** ✅ Host promotion occurs within 10 seconds

---

### TC-008: Relay Message Accuracy

**Test Steps:**
1. Create room with 2 players
2. Client: Toggle READY status 5 times
3. Host: Observe each toggle
4. Count total toggles received

**Expected Results:**
- All 5 toggles received
- No duplicate messages
- No missing messages
- Latency < 500ms per message

**Pass Criteria:** ✅ 100% message delivery, no duplicates

---

## Test Scenario 4: Code Breaker - Lobby & Room

### TC-009: Room Creation

**Test Steps:**
1. Navigate to Code Breaker lobby
2. Click "Create Room"
3. Enter room name: "Validator Test Room"
4. Click "Create"
5. Verify transition to room scene

**Expected Results:**
- Room created successfully
- Room ID generated
- Host appears in left player card
- READY button visible and functional

**Pass Criteria:** ✅ Room created and host can see room state

---

### TC-010: Room Browsing & Refresh

**Test Steps:**
1. Device 1: Create 3 different rooms
2. Device 2: Open lobby
3. Wait 5 seconds (auto-refresh)
4. Verify all 3 rooms appear
5. Device 1: Delete 1 room
6. Device 2: Wait 5 seconds
7. Verify room removed from list

**Expected Results:**
- All active rooms visible
- Auto-refresh every 5 seconds
- Deleted rooms disappear

**Pass Criteria:** ✅ Room list stays synchronized

---

### TC-011: Join Room Flow

**Test Steps:**
1. Device 1: Create room
2. Device 2: Click room in list
3. Click "Join"
4. Verify transition to room scene
5. Both devices: Check player cards

**Expected Results:**
- Client appears in right player card
- Both players see each other
- Relay connection established
- Ready buttons functional

**Pass Criteria:** ✅ Both players see synchronized room state

---

### TC-012: Heartbeat System

**Test Steps:**
1. Create room as host
2. Wait 90 seconds without interaction
3. Check if room still exists (should remain active)
4. Minimize app for 2 minutes
5. Check room status

**Expected Results:**
- Room stays active with heartbeat (30s intervals)
- Room deleted after 90s without heartbeat
- Server logs show heartbeat requests

**Pass Criteria:** ✅ Heartbeat keeps room alive

---

## Test Scenario 5: Code Breaker - Loading Screen

### TC-013: Player Synchronization

**Test Steps:**
1. 2 players in room
2. Client: Click READY
3. Host: Click START MATCH
4. Observe loading screen on both devices
5. Monitor progress bars

**Expected Results:**
- Both players see loading screen
- Progress bars animate: 30% → 60% → 100%
- "YOU" card on left, "OPPONENT" on right
- Loading completes in ~1.5 seconds

**Pass Criteria:** ✅ Both players sync and proceed to arena

---

### TC-014: Loading Timeout

**Test Steps:**
1. Start match
2. Device 2: Disconnect WiFi during loading
3. Device 1: Wait 30 seconds
4. Verify timeout handling

**Expected Results:**
- Timeout after 30 seconds
- User returned to room
- Error message displayed

**Pass Criteria:** ✅ Graceful timeout handling

---

## Test Scenario 6: Code Breaker - Arena Gameplay

### TC-015: Full Gameplay Match

**Test Steps:**
1. Complete loading sequence
2. Observe 3-2-1-TYPE countdown
3. Both players: Type displayed code snippets
4. Complete at least 5 correct answers each
5. Continue until one player reaches 0 HP or finishes all snippets

**Expected Results:**
- Countdown displays with bounce animations
- Timer paused during countdown
- Typing input responsive
- Correct answers: damage opponent, spawn particles
- Wrong answers: self-damage, shake animation
- Health bars update in real-time
- Score syncs every 0.5 seconds
- Battle music plays
- Winner/loser determined correctly

**Pass Criteria:** ✅ Game completes without crashes, winner determined

---

### TC-016: Damage System Validation

**Test Steps:**
1. Start match
2. Player 1: Answer correctly
3. Player 2: Observe health reduction
4. Player 2: Verify shake animation
5. Check if critical hit occurs when HP < 30%

**Expected Results:**
- Damage: 2 HP per correct answer
- Opponent health bar shakes
- Screen shake on critical hits
- Explosion particles spawn
- Audio feedback on damage

**Pass Criteria:** ✅ Damage applies correctly with visual feedback

---

### TC-017: Stats Synchronization

**Test Steps:**
1. During gameplay, monitor stats panel
2. Answer correctly 3 times
3. Verify opponent sees score updates
4. Check sync interval (should be ~0.5s)

**Expected Results:**
- Stats update every 0.5 seconds
- Score accurate on both devices
- Health matches
- No desync issues

**Pass Criteria:** ✅ Stats stay synchronized throughout match

---

### TC-018: Visual Effects Validation

**Test Steps:**
1. Start match
2. Correct answer: Observe success particles (sparkles)
3. Damage received: Observe explosion particles
4. Reduce HP below 30%: Check screen shake intensity
5. Verify countdown animations (bounce/scale)

**Expected Results:**
- Success: 15 cyan/blue sparkle particles
- Damage: 12-25 red/orange explosion particles
- Critical damage: Stronger screen shake
- Countdown: Bounce animation with text outline
- Panel shadows visible (8-12px)

**Pass Criteria:** ✅ All visual effects render smoothly

---

### TC-019: Battle Music & Audio

**Test Steps:**
1. Start match
2. Verify music fades in (-80dB → -5dB over 2s)
3. Complete match
4. Click "Leave" button
5. Verify music stops cleanly

**Expected Results:**
- Music starts on arena entry
- Volume fades in smoothly
- Music stops when leaving arena
- No audio glitches

**Pass Criteria:** ✅ Audio plays and stops correctly

---

### TC-020: Return to Room After Match

**Test Steps:**
1. Complete full match
2. Winner declared
3. Click "Leave" or wait for auto-return
4. Verify scene transition

**Expected Results:**
- Both players return to room scene
- Relay connection preserved
- Room state maintained
- Can start new match immediately

**Pass Criteria:** ✅ Smooth return to room for rematch

---

## Test Scenario 7: Performance & Stability

### TC-021: Extended Gameplay Session

**Test Steps:**
1. Play 5 consecutive matches
2. Monitor frame rate (should stay ~60 FPS)
3. Check for memory leaks
4. Verify no performance degradation

**Expected Results:**
- Consistent performance
- No slowdowns over time
- Memory usage stable

**Pass Criteria:** ✅ 60 FPS maintained, no leaks

---

### TC-022: Network Latency Handling

**Test Steps:**
1. Start match
2. Simulate poor network (use network throttling tool)
3. Continue gameplay with 200ms latency
4. Verify game remains playable

**Expected Results:**
- Game compensates for latency
- No freezing or stuttering
- Stats eventually sync

**Pass Criteria:** ✅ Playable with moderate latency

---

### TC-023: Rapid Scene Transitions

**Test Steps:**
1. Quickly navigate: Lobby → Room → Leave → Lobby (5 times)
2. Check for crashes or leaks
3. Verify UI loads correctly each time

**Expected Results:**
- No crashes
- Clean transitions
- No visual glitches

**Pass Criteria:** ✅ Stable rapid navigation

---

## Test Scenario 8: Edge Cases & Error Handling

### TC-024: Disconnect During Match

**Test Steps:**
1. Start match
2. Midway through: Device 2 force-close app
3. Device 1: Continue for 10 seconds
4. Verify error handling

**Expected Results:**
- Device 1 detects disconnect
- Error message displayed
- User prompted to return to lobby
- No crash

**Pass Criteria:** ✅ Graceful disconnect handling

---

### TC-025: Invalid Room Join

**Test Steps:**
1. Device 1: Create room
2. Device 2: Note room ID
3. Device 1: Leave/delete room
4. Device 2: Try to join deleted room

**Expected Results:**
- Error message: "Room no longer exists"
- User stays in lobby
- No crash

**Pass Criteria:** ✅ Clear error message shown

---

### TC-026: Simultaneous Room Creation

**Test Steps:**
1. Device 1 & 2: Simultaneously create rooms
2. Verify both rooms created
3. Check for unique room IDs

**Expected Results:**
- 2 separate rooms created
- No ID collision
- Both rooms functional

**Pass Criteria:** ✅ Concurrent operations handled

---

## Validation Checklist Summary

### Critical Functionality (Must Pass)
- [ ] TC-001: User registration works
- [ ] TC-006: Cross-network multiplayer works
- [ ] TC-011: Room join flow works
- [ ] TC-015: Full match completes successfully
- [ ] TC-016: Damage system accurate
- [ ] TC-020: Return to room works

### Important Features (Should Pass)
- [ ] TC-002: OAuth login
- [ ] TC-004: Real-time chat
- [ ] TC-007: Host promotion
- [ ] TC-013: Loading sync
- [ ] TC-017: Stats sync
- [ ] TC-024: Disconnect handling

### Quality Enhancements (Nice to Pass)
- [ ] TC-018: Visual effects
- [ ] TC-019: Audio/music
- [ ] TC-021: Performance stability
- [ ] TC-022: Latency handling

---

## Reporting Issues

When documenting issues, please include:
1. **Test Case ID** (e.g., TC-015)
2. **Device/OS** (Windows/Android/etc.)
3. **Network Type** (WiFi/mobile/etc.)
4. **Steps to Reproduce**
5. **Expected vs Actual Result**
6. **Screenshots/Logs** (if available)
7. **Severity** (Critical/Major/Minor)

---

**Document Version:** 1.0  
**Last Updated:** December 1, 2025
