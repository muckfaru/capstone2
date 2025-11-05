# ⚔️ CODE BREAKER - Health-Based Typing Combat System

**Date:** November 5, 2025  
**Version:** 2.0 - Complete Refactor

---

## 🎮 Game Concept

**CODE BREAKER** is a 1v1 real-time typing duel where players compete by typing code snippets to attack their opponent. The first player to reduce their opponent's health to 0 wins!

---

## 🔹 Core Game Mechanics

### **Round Start**
- Both players receive the **same code snippet** (synchronized)
- Starting health: **100 HP** each
- Starting score: **0 points** each
- Timer: **3 minutes** (180 seconds)
- Code snippet: Random GDScript syntax (8 different snippets)

### **Scoring System**

| Action | Score Change | Health Effect |
|--------|--------------|---------------|
| ✅ **Correct Input** | **+3 points** | **-2 HP to opponent** |
| ❌ **Wrong Input** | **-3 points** (error penalty) | None (but line restarts) |

### **Typing Race Mechanics**

1. **Character-by-Character Input**
   - Players type one character at a time
   - Each keystroke is evaluated immediately
   - No auto-complete or suggestions

2. **Line Restart on Error**
   - Wrong keystroke → **restart current line**
   - Progress resets to beginning of line
   - Score penalty applied (-3 points)
   - Opponent is notified of your error

3. **Real-Time Combat**
   - Correct keystroke → Deal **2 damage** to opponent
   - Damage is applied immediately via RPC
   - Health bars update in real-time (~50ms delay)

### **Win Conditions**

| Condition | Result |
|-----------|--------|
| 💀 **Opponent health = 0** | **YOU WIN** (Victory) |
| 💀 **Your health = 0** | **YOU LOSE** (Defeat) |
| 🏁 **Complete code first** | **YOU WIN** (Victory) |
| ⏰ **Time runs out** | Highest health wins, then highest score |

---

## 🔹 Game Rules

### **Strict Typing Requirements**
- ❌ **No auto-correct** - Exactly as shown
- ✅ **Case-sensitive** - `Var` ≠ `var`
- ✅ **Exact match required** - Spaces, tabs, newlines must match
- ❌ **No partial submissions** - Character-by-character only
- ❌ **No paste allowed** - Multi-character input rejected

### **Combat Rules**
- Each correct character is an **attack** (-2 HP to enemy)
- Each error is a **penalty** (-3 points to you)
- Errors force you to **restart the current line**
- First to **0 health dies** immediately
- **No respawn** - Game ends on death

### **Match Result Display**
- **Victory Screen:**
  - "🎉 VICTORY!"
  - Your final score
  - Opponent's remaining health
- **Defeat Screen:**
  - "💀 DEFEAT!"
  - Your final score
  - Your remaining health
- **Timeout Screen:**
  - Winner determined by: Health → Score
  - Both values displayed

---

## 📊 Constants & Values

```gdscript
const SCORE_CORRECT = 3          # Points gained per correct char
const SCORE_PENALTY = -3         # Points lost per error
const DAMAGE_TO_ENEMY = 2        # HP damage dealt per correct char
const STARTING_HEALTH = 100      # Starting HP for both players
const GAME_DURATION = 180.0      # 3 minutes in seconds
```

---

## 🎯 Gameplay Flow

### **Pre-Game (Room)**
1. Players join room
2. Host presses "START MATCH"
3. Multiplayer peer established (ENet localhost)
4. Both transition to arena

### **Game Start**
1. Host generates random code snippet
2. Code synced to client via RPC
3. Both players see: "⚔️ CODE BREAKER DUEL - TYPE TO ATTACK!"
4. Input field becomes editable
5. Timer starts counting down from 3:00

### **During Combat**
1. Player types character
2. **IF CORRECT:**
   - Score +3
   - Progress bar advances
   - Deal 2 damage to opponent (RPC)
   - Opponent's health bar updates
   - Green flash feedback
3. **IF WRONG:**
   - Score -3
   - Line position resets
   - Progress bar retracts
   - Error message shown
   - Red flash feedback
   - Opponent notified

### **Game End Scenarios**

#### **Scenario 1: Health Knockout**
```
Player 1: Typing correctly... (Enemy HP: 50 → 48 → 46...)
Player 2: Typing but making errors... (HP: 100 → 100 → 100...)
Player 1: Enemy HP reaches 0
Result: Player 1 WINS (Victory screen)
```

#### **Scenario 2: Code Completion**
```
Player 1: Types entire code snippet first
Player 1: "🏆 CODE COMPLETE!"
Result: Player 1 WINS (Victory screen)
```

#### **Scenario 3: Timeout**
```
Time: 00:00
Player 1: Score 120, HP 80
Player 2: Score 150, HP 60
Result: Player 1 WINS (Higher HP)
```

---

## 🔧 Technical Implementation

### **New Variables**
```gdscript
var _current_line_start_index: int = 0  # Track line start for restart
var _game_active: bool = false          # Prevent input after death
var _opponent_alive: bool = true        # Track opponent status
```

### **New Functions**

#### **Combat System**
- `_restart_current_line()` - Reset to line start on error
- `_on_player_died()` - Handle local player death
- `_deal_damage_to_opponent.rpc()` - Send damage to opponent
- `_on_opponent_died.rpc()` - Receive opponent death notification

#### **Visual Feedback**
- `_flash_success()` - Green flash (0.05s) on correct input
- `_flash_error()` - Red flash (0.15s) on wrong input
- `_show_error_message()` - Display error for 1s

#### **Game End**
- `_end_game_victory()` - You won (death or completion)
- `_end_game_defeat()` - You lost (death or opponent completed)
- `_end_game_timeout()` - Time expired (health/score comparison)

### **Modified RPC Calls**

| RPC Function | Purpose | Reliability |
|--------------|---------|-------------|
| `_deal_damage_to_opponent()` | Send damage value | Reliable |
| `_on_opponent_died()` | Notify of death | Reliable |
| `_on_line_restarted()` | Notify of error | Unreliable |
| `_on_player_finished()` | Notify of completion | Reliable |

---

## 🎨 UI/UX Changes

### **Status Messages**
- Start: "⚔️ CODE BREAKER DUEL - TYPE TO ATTACK!"
- Error: "❌ ERROR! Line restarted. Expected: 'x'"
- Paste: "⛔ NO PASTE ALLOWED!"
- Complete: "🏆 CODE COMPLETE! Time: X.XX s | WPM: XX"
- Death: "💀 YOU DIED! Health: 0"
- Victory: "🎉 VICTORY! Score: XX | Opponent Health: XX"
- Defeat: "💀 DEFEAT! Score: XX | Your Health: XX"

### **Visual Feedback**
- ✅ **Green flash** - Correct keystroke (50ms)
- ❌ **Red flash** - Wrong keystroke (150ms)
- 💥 **Red indicator** - Taking damage (200ms)
- 💚 **Green indicator** - Connection active

### **Progress Tracking**
- **Progress Bar** - Shows current position in code
  - Advances on correct input
  - Retracts on line restart
- **Health Bars** - P1 (cyan) and P2 (red/pink)
  - Update in real-time (~50ms polling)
  - Visual color: Green (100-60), Yellow (60-30), Red (30-0)

---

## 🧪 Testing Scenarios

### **Test 1: Basic Combat**
1. Start match
2. Player 1 types correctly 10 times
3. **Expected:** Player 2 health = 80 (100 - 20)
4. **Expected:** Player 1 score = 30 (10 × 3)

### **Test 2: Error Penalty**
1. Start match
2. Player 1 makes 5 errors
3. **Expected:** Player 1 score = -15 (5 × -3)
4. **Expected:** No health damage to Player 2

### **Test 3: Line Restart**
1. Start match
2. Player 1 types: "var p" (4 correct chars)
3. Player 1 types wrong char on 5th
4. **Expected:** Position resets to start of line
5. **Expected:** Must retype "var p" again

### **Test 4: Health Knockout**
1. Start match
2. Player 1 types 50 correct chars (50 × 2 = 100 damage)
3. **Expected:** Player 2 health = 0
4. **Expected:** "💀 YOU DIED!" on Player 2 screen
5. **Expected:** "🎉 VICTORY!" on Player 1 screen

### **Test 5: Case Sensitivity**
1. Code snippet contains: "Var player"
2. Player types: "var player"
3. **Expected:** Error on 'v' (should be 'V')
4. **Expected:** Line restart

### **Test 6: No Paste**
1. Player copies "var player_data"
2. Player tries to paste
3. **Expected:** "⛔ NO PASTE ALLOWED!"
4. **Expected:** Input rejected

---

## 📈 Scoring Examples

### **Perfect Play (No Errors)**
```
Code snippet: 50 characters
Time: 30 seconds
Correct: 50 keystrokes
Errors: 0

Final Score: 50 × 3 = 150 points
Opponent Damage: 50 × 2 = 100 HP (opponent dead)
Result: VICTORY
```

### **Aggressive Play (Some Errors)**
```
Code snippet: 50 characters
Time: 60 seconds
Correct: 40 keystrokes
Errors: 10 keystrokes

Final Score: (40 × 3) + (10 × -3) = 120 - 30 = 90 points
Opponent Damage: 40 × 2 = 80 HP (opponent at 20 HP)
Result: Opponent still alive, continue typing
```

### **Error-Prone Play**
```
Code snippet: 50 characters
Time: 90 seconds
Correct: 20 keystrokes
Errors: 30 keystrokes

Final Score: (20 × 3) + (30 × -3) = 60 - 90 = -30 points
Opponent Damage: 20 × 2 = 40 HP (opponent at 60 HP)
Result: Likely DEFEAT (low damage, negative score)
```

---

## 🔄 Changes from Previous Version

### **Removed Mechanics**
- ❌ Health damage on errors (self-damage)
- ❌ Progress-based win condition
- ❌ +10 points per correct char (now +3)
- ❌ -5 HP per error (now -3 score instead)

### **Added Mechanics**
- ✅ Damage opponent's health on correct input (-2 HP)
- ✅ Score penalty on errors (-3 points)
- ✅ Line restart on errors
- ✅ Health-based knockout system
- ✅ First to 0 HP loses
- ✅ Timeout winner by health → score priority

### **Modified Behavior**
- Character input now **attacks opponent** instead of just scoring
- Errors now **penalize score** instead of damaging self
- Health bars now show **combat status** instead of accuracy
- Win condition now **combat-focused** (knockout) instead of race-focused

---

## 🚀 Future Enhancements (Ideas)

### **Power-Ups**
- 💊 **Health Pack** - Restore 10 HP on special character
- ⚡ **Damage Boost** - Next 5 correct = 3 damage instead of 2
- 🛡️ **Shield** - Block next 3 incoming damage

### **Difficulty Levels**
- **Easy:** 1 damage per correct, -1 score per error
- **Normal:** 2 damage per correct, -3 score per error (current)
- **Hard:** 3 damage per correct, -5 score per error, no line restart

### **Game Modes**
- **Sudden Death:** 50 HP start, no timer
- **Time Attack:** 60 seconds, highest score wins
- **Survival:** Multiple rounds, best of 3
- **Team Battle:** 2v2 shared health pool

### **Advanced Features**
- **Combo System:** 10 correct in a row = double damage
- **Critical Hits:** Random 2x damage chance
- **Special Moves:** Type specific keywords for abilities
- **Ranked Matches:** ELO rating system
- **Replay System:** Record and watch matches

---

## 🎓 Tips for Players

### **Offensive Strategy**
- Focus on **accuracy over speed**
- Every correct char = 2 damage to enemy
- 50 correct chars = instant kill (100 HP)
- **Minimize errors** to maintain pressure

### **Defensive Strategy**
- **Avoid errors** to prevent score loss
- Line restarts waste time (enemy keeps damaging)
- Watch opponent's health bar
- If opponent at low HP, **push aggressively**

### **Comeback Strategy**
- If low HP, focus on **perfect typing**
- One mistake = opponent gains advantage
- Type faster when opponent makes errors
- Remember: **First to 0 loses**, not first to finish

### **Pro Tips**
- 💡 **Memorize common patterns** (var, func, if/else)
- 💡 **Watch for capital letters** (case-sensitive!)
- 💡 **Count spaces/tabs carefully**
- 💡 **Newlines count as characters**
- 💡 **Practice GDScript syntax** before matches

---

## 📝 Code Snippet Examples

The game uses 8 different GDScript snippets:

1. **Function with return type:**
   ```gdscript
   func calculate_damage(base: int, multiplier: float) -> int:
   	return int(base * multiplier)
   ```

2. **For loop with await:**
   ```gdscript
   for i in range(10):
   	print("Iteration: %d" % i)
   	await get_tree().create_timer(0.5).timeout
   ```

3. **Dictionary literal:**
   ```gdscript
   var player_data = {"name": "Alice", "level": 42, "score": 9999}
   ```

4. **If-elif-else:**
   ```gdscript
   if health <= 0:
   	game_over()
   elif health < 20:
   	show_warning()
   ```

5. **Constants and variables:**
   ```gdscript
   const MAX_SPEED = 500.0
   var velocity: Vector2 = Vector2.ZERO
   ```

6. **Exported variables:**
   ```gdscript
   @export var damage: int = 10
   @onready var sprite = $Sprite2D
   ```

7. **Signal declarations:**
   ```gdscript
   signal player_died(player_name: String)
   signal score_changed(new_score: int)
   ```

8. **Class extension:**
   ```gdscript
   extends CharacterBody2D
   
   func _physics_process(delta):
   	move_and_slide()
   ```

---

## 🐛 Known Issues & Limitations

### **Current Limitations**
1. **Line detection** - Relies on `\n` character detection
   - Tabs/spaces at line start don't reset position
   - May need smarter line boundary detection

2. **Paste detection** - Only blocks multi-char input
   - Fast typing might trigger false positive
   - Consider adding clipboard monitor

3. **Network delay** - ~50-100ms for damage to show
   - RPC polling every 50ms
   - Acceptable for LAN, may lag on internet

4. **No reconnect** - Disconnection = instant loss
   - No pause/resume feature
   - Consider adding reconnection grace period

### **Balance Concerns**
- **2 damage per char** might be too high (50 correct = instant win)
- **-3 score penalty** might discourage aggressive play
- **Line restart** might be too punishing for long lines
- Consider playtesting for balance adjustments

---

## 🎯 Conclusion

The new **CODE BREAKER** mechanics transform the game from a simple typing race into a **strategic combat system** where every keystroke matters. Players must balance **accuracy** (to deal damage) with **speed** (to finish first) while managing their **health pool** and **score**.

**Key Takeaway:** This is no longer "who can type faster" - it's **"who can type better under pressure while attacking their opponent."**

**Try it now and may the best coder win! ⚔️🎮**

---

**Refactored by:** GitHub Copilot  
**Date:** November 5, 2025  
**Files Modified:** `script/code_breaker_arena.gd`  
**Lines Changed:** ~200+ lines refactored  
**Test Status:** ⚠️ Ready for testing
