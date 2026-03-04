# Teacher Room History - Troubleshooting Guide

## Common Issues & Solutions

### 1. Room History Not Loading

#### Symptoms
- Main panel shows "No rooms" even though you've created rooms
- Console shows Firestore query errors

#### Possible Causes
A. **Auth not initialized**
   - Check: `Auth.current_username` is set
   - Solution: Ensure user is logged in before opening TeacherCreateRoom

B. **Firestore permissions**
   - Check: Firestore console → Rules
   - Solution: Update rules to allow authenticated reads:
     ```javascript
     match /room_history/{document} {
       allow read: if request.auth != null;
       allow write: if request.auth != null 
         && document.split('_')[0] == request.auth.token.name;
     }
     ```

C. **Network issues**
   - Check: Browser console for HTTP errors
   - Solution: Verify internet connection and Firestore URL

#### Debug Steps
1. Add debug print in `_load_room_history()`:
   ```gdscript
   print("[Debug] Loading history for: ", Auth.current_username)
   ```

2. Add debug print in `_on_room_history_loaded()`:
   ```gdscript
   print("[Debug] Loaded ", room_history.size(), " rooms")
   print("[Debug] Raw response: ", text)
   ```

3. Check Firestore console for documents:
   - Go to Firebase Console → Firestore Database
   - Look for `room_history` collection
   - Verify documents exist with correct teacher_id

---

### 2. Status Badge Not Updating

#### Symptoms
- Room shows ● (active) even after clicking back button
- Status remains "active" in Firestore after completion

#### Possible Causes
A. **`_mark_room_completed()` not called**
   - Check: Console for "Marked room X as completed" message
   - Solution: Verify `_on_stats_back_pressed()` calls the function

B. **Firestore update failed**
   - Check: HTTP response code in console
   - Solution: Verify Firestore write permissions

C. **Room history not reloaded**
   - Check: `_load_room_history()` called after marking complete
   - Solution: Already implemented in `_on_stats_back_pressed()`

#### Debug Steps
1. Add debug print in `_on_stats_back_pressed()`:
   ```gdscript
   print("[Debug] Marking room complete: ", current_room_code)
   ```

2. Verify Firestore document updated:
   - Firebase Console → room_history collection
   - Check document's `status` field changed to "completed"
   - Check `completed_at` timestamp added

---

### 3. View Button Shows Wrong Statistics

#### Symptoms
- Click View on GameMode room → Shows CyberQuiz leaderboard
- Click View on CyberQuiz room → Shows GameMode leaderboard

#### Possible Causes
A. **Wrong category saved to Firestore**
   - Check: Firestore document's `category` field
   - Solution: Verify `_save_room_to_history()` saves correct category

B. **Category detection wrong in `_view_room_history()`**
   - Check: Console for "[RoomHistory] Unknown category" warning
   - Solution: Ensure category is "game_mode" or "multiple_choice"

#### Debug Steps
1. Add debug print in `_save_room_to_history()`:
   ```gdscript
   print("[Debug] Saving room with category: ", category)
   ```

2. Add debug print in `_view_room_history()`:
   ```gdscript
   print("[Debug] Viewing room: ", code, " | Category: ", category)
   ```

3. Verify Firestore document has correct category:
   - Should be "game_mode" or "multiple_choice" (lowercase, no spaces)

---

### 4. Room Code Panel Still Appears

#### Symptoms
- After clicking back from statistics, shows room code panel instead of main panel
- Can't see room history list

#### Possible Causes
A. **`_on_stats_back_pressed()` still calls `_show_screen("code")`**
   - Check: Function implementation
   - Solution: Verify it calls `_show_screen("main")`

B. **Old code not updated**
   - Check: File saved properly
   - Solution: Restart Godot editor and reload project

#### Quick Fix
Ensure `_on_stats_back_pressed()` looks like this:
```gdscript
func _on_stats_back_pressed() -> void:
	if not current_room_code.is_empty():
		_mark_room_completed(current_room_code)
	
	if _quiz_poll_timer:
		_quiz_poll_timer.queue_free()
		_quiz_poll_timer = null
	if _quiz_heartbeat_timer:
		_quiz_heartbeat_timer.queue_free()
		_quiz_heartbeat_timer = null
	
	_load_room_history()
	_show_screen("main")  # ← Must be "main", not "code"
```

---

### 5. Duplicate Rooms in List

#### Symptoms
- Same room appears twice in list
- One active (●), one completed (✓)

#### Possible Causes
A. **Room saved twice to Firestore with different statuses**
   - Check: Firestore console for duplicate documents
   - Solution: Delete duplicate documents (keep the correct one)

B. **Room appears in both `rooms` dict and `room_history` array**
   - Check: `_refresh_room_list()` logic
   - Solution: Already handled with `already_shown` check

#### Prevention
- Only create room once (don't click Generate multiple times)
- Wait for Firestore save confirmation before creating another room

---

### 6. Statistics Not Loading

#### Symptoms
- Click View button → Statistics panel is blank
- No leaderboard data shown

#### Possible Causes
A. **Server endpoint not responding**
   - Check: Browser console for HTTP errors
   - Solution: Verify server is running and accessible

B. **Room code not found on server**
   - Check: Server logs for room code lookup
   - Solution: Re-create room and ensure it's posted to server

C. **Polling not started**
   - Check: `_start_results_polling()` or `_start_gamemode_results_polling()` called
   - Solution: Already implemented in `_view_room_history()`

#### Debug Steps
1. Check if room exists on server:
   - **CyberQuiz**: `GET https://[lobby_url]/api/quiz/[room_code]/leaderboard`
   - **GameMode**: `GET https://[lobby_url]/api/gamemode/[room_code]/results`

2. Verify polling timer is running:
   ```gdscript
   print("[Debug] Starting polling for room: ", code)
   ```

---

### 7. "Back to Room History" Button Shows "Back to Landing"

#### Symptoms
- Statistics panel still shows old text
- Button doesn't work as expected

#### Possible Causes
A. **Old leaderboard button not updated**
   - Check: `_update_stats_leaderboard()` and `_update_gamemode_leaderboard()`
   - Solution: Verify button text changed to "← Back to Room History"

B. **Cached button from previous session**
   - Check: Button recreation logic
   - Solution: Buttons are dynamically created each time, should be fine

#### Quick Fix
Search for "Back to Landing" in TeacherCreateRoom.gd:
- Replace all instances with "Back to Room History"
- Ensure button connects to: `func(): _on_stats_back_pressed()`

---

### 8. Room History Loads Slowly

#### Symptoms
- Long delay before rooms appear
- "Loading..." message for several seconds

#### Possible Causes
A. **Too many rooms in history**
   - Check: Number of documents in Firestore
   - Solution: Implement pagination (future enhancement)

B. **Slow network connection**
   - Check: Network speed
   - Solution: Optimize Firestore query (already using indexed query)

C. **Firestore cold start**
   - Check: First load after idle period
   - Solution: Normal behavior, subsequent loads will be faster

#### Optimization Tips
1. Limit query to recent rooms only:
   ```gdscript
   "limit": 50  # Add to structuredQuery
   ```

2. Add loading indicator while fetching:
   ```gdscript
   empty_label.text = "Loading room history..."
   empty_label.visible = true
   ```

---

## Error Messages Reference

### `[RoomHistory] No Auth or username — cannot save room history`
**Meaning**: User not logged in  
**Solution**: Ensure Auth singleton is initialized and user is authenticated

### `[RoomHistory] Failed to save room: HTTP 403`
**Meaning**: Firestore permission denied  
**Solution**: Update Firestore security rules to allow writes

### `[RoomHistory] Failed to load history: HTTP 400`
**Meaning**: Malformed Firestore query  
**Solution**: Check query structure in `_load_room_history()`

### `[RoomHistory] Unexpected response format`
**Meaning**: Firestore returned non-array response  
**Solution**: Verify query endpoint and response structure

### `[RoomHistory] Unknown category: [category]`
**Meaning**: Room has invalid category (not "game_mode" or "multiple_choice")  
**Solution**: Check room creation logic and Firestore document

---

## Testing Scenarios

### Scenario 1: First Time User
1. Log in as teacher
2. Open TeacherCreateRoom
3. Expect: Empty room list with "No rooms yet"
4. Create a room
5. Expect: Room appears with ● badge
6. Close and reopen
7. Expect: Room still appears (persists)

### Scenario 2: Multiple Rooms
1. Create 3 GameMode rooms
2. Create 2 CyberQuiz rooms
3. Expect: All 5 rooms appear in list
4. Complete one room (view stats → back)
5. Expect: That room shows ✓ badge
6. Others still show ● badge

### Scenario 3: View Historical Stats
1. Complete a room (status = "completed")
2. Close and reopen app
3. Click View on completed room
4. Expect: Statistics panel shows final results
5. Expect: Can still see player scores/times

### Scenario 4: Session Persistence
1. Create room A
2. Log out
3. Log in as different teacher
4. Expect: Room A NOT visible (belongs to other teacher)
5. Log back in as original teacher
6. Expect: Room A visible again

---

## Performance Tips

### Firestore Optimization
- Index the `teacher_id` and `created_at` fields for faster queries
- Consider composite index: `teacher_id` + `created_at` + `status`

### Memory Management
- HTTPRequest nodes are properly freed after use
- Timers are cleaned up in `_on_stats_back_pressed()`
- Old room items are freed in `_refresh_room_list()`

### UI Responsiveness
- Room list uses dynamic creation (no pre-allocation)
- Status badges use simple Label nodes (lightweight)
- View buttons use lambdas (efficient signal connection)

---

## Support Checklist

When reporting issues, provide:
- [ ] Godot version (should be 4.4)
- [ ] Browser console logs (if web build)
- [ ] Firestore collection screenshot
- [ ] Steps to reproduce
- [ ] Expected vs actual behavior
- [ ] Any error messages from console

---

**Last Updated**: March 1, 2026  
**Maintainer**: Development Team
