# 🎮 CODE BREAKER - Quick Refactor Summary

**Date:** November 5, 2025

## ✅ What Changed

### **Old System (Progress-Based)**
- Correct input: +10 score
- Wrong input: -5 HP (self damage)
- Win by: First to finish code OR highest score at timeout

### **New System (Health-Based Combat)**
- ✅ Correct input: **+3 score**, **-2 HP to opponent**
- ❌ Wrong input: **-3 score penalty**, **restart current line**
- 💀 Win by: **First to 0 HP = LOSE**

---

## 🎯 Key Mechanics

| Mechanic | Description |
|----------|-------------|
| **Health Combat** | Each correct keystroke deals 2 damage to opponent |
| **Score Penalty** | Errors cost -3 points (not self-damage) |
| **Line Restart** | Errors force restart of current line (race-style) |
| **Knockout System** | First player to 0 HP dies instantly |
| **Case-Sensitive** | Exact match required (Var ≠ var) |
| **No Paste** | Multi-character input rejected |

---

## 📝 New Constants

```gdscript
const SCORE_CORRECT = 3          # Points per correct char
const SCORE_PENALTY = -3         # Points per error
const DAMAGE_TO_ENEMY = 2        # HP damage per correct char
const STARTING_HEALTH = 100      # Starting HP
```

---

## 🔧 New Functions Added

1. **`_restart_current_line()`** - Reset to line start on error
2. **`_on_player_died()`** - Handle player death (HP = 0)
3. **`_deal_damage_to_opponent.rpc()`** - Send damage to opponent
4. **`_on_opponent_died.rpc()`** - Receive opponent death notification
5. **`_on_line_restarted.rpc()`** - Notify opponent of error
6. **`_flash_success()`** - Green flash on correct input
7. **`_show_error_message()`** - Display error temporarily
8. **`_end_game_victory()`** - Victory screen
9. **`_end_game_defeat()`** - Defeat screen
10. **`_end_game_timeout()`** - Timeout screen (health → score priority)

---

## 🎨 UI Messages

- Start: "⚔️ CODE BREAKER DUEL - TYPE TO ATTACK!"
- Error: "❌ ERROR! Line restarted. Expected: 'x'"
- Death: "💀 YOU DIED! Health: 0"
- Victory: "🎉 VICTORY!"
- Defeat: "💀 DEFEAT!"

---

## 🧪 Test It!

1. **Run two instances** (Editor + .exe)
2. **Join same room**
3. **Host presses START MATCH**
4. **Type correctly** → Enemy loses 2 HP per char
5. **Make error** → You lose 3 points + restart line
6. **Get enemy to 0 HP** → You win!

---

## 📚 Full Documentation

See **`CODE_BREAKER_GAME_MECHANICS.md`** for:
- Complete game rules
- Win conditions
- Scoring examples
- Strategy tips
- Future enhancement ideas

---

## ⚠️ Testing Checklist

- [ ] Correct input deals 2 damage to opponent
- [ ] Wrong input penalizes -3 score
- [ ] Wrong input restarts current line
- [ ] Player dies at 0 HP
- [ ] Victory/defeat screens show correctly
- [ ] Health bars update in real-time
- [ ] Score displays correctly
- [ ] Line restart resets progress bar
- [ ] Case-sensitive typing enforced
- [ ] Paste is blocked

---

**Status:** ✅ Refactored and ready for testing!  
**Next:** Test ang gameplay at sabihan ako kung may problema! 🚀
