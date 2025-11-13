SUMMARY - CODE BREAKER v2.0 (Health-Based Typing Combat)

CODE BREAKER is a 1v1 real-time code typing battle game. Correct typing damages the opponent, while mistakes lower your score and restart the current line. You win by reducing the opponent’s health to zero, finishing the code first, or having higher health when the timer ends.

Core Mechanics:
Both players receive the same code snippet.
Each player starts with 100 health and 0 score.
Match lasts 3 minutes.
All snippets use GDScript.

Combat System:
-Correct character gives plus 3 score and deals 2 damage to the enemy.
-Wrong character gives minus 3 score and restarts the current line.
-Typing must match exactly, including spaces and capitalization.
-Pasting is not allowed.

Win Conditions:
-Opponent health reaches zero.
-You finish the code snippet first.
-If time expires, the player with higher health wins. If health is tied, the higher score wins.

Gameplay Flow:
-Players enter a room and start the match.
-The host sends the code snippet.
-Players type character by character.
-Damage and health updates happen in real time through RPC.
-Match ends by knockout, completion, or timeout.

UI Feedback:
-Green flash for correct input.
-Red flash for errors.
-Health bars update continuously.
-Game shows error, victory, and defeat messages.

Technical Highlights:
-Tracks starting index of the current line.
-RPCs handle damage, death, completion, and line restart.
-Functions added for feedback, victory, defeat, and timeout.
-Variables added to control game state such as game_active and opponent_alive.

Test Scenarios:
-Checks damage from correct inputs.
-Checks score penalty from errors.
-Checks line restart behavior.
-Checks knockout behavior.
-Checks case sensitivity.
-Checks paste blocking.

Key Balance Values:
-Plus 3 score per correct input.
-Minus 3 score per error.
-Two damage per correct input.
-One hundred starting health.
-One hundred eighty seconds match duration.

New in Version 2.0:
-Added health-based combat.
-Added score penalties.
-Added line restart mechanic.
-Correct input now deals damage.
-Timeout winner determined by health then score.

Removed or Changed:
-Removed progress-based win.
-Removed self-damage on errors.
-Reduced score gain from ten to three.

Future Add-ons:
-Planned power-ups, difficulty modes, and new game modes.
-Possible features include combos, critical hits, and ranked matches.

Main Idea:
-The game is now focused on strategic typing combat. Accuracy, timing, and pressure management matter more than pure speed. Every keypress helps you attack or slows you down depending on whether it is correct or wrong.