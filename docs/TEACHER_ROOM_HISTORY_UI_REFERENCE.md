# Teacher Room History - UI Reference

## Main Panel View

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  CYBER CT                                           ← Back    + Create    ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  Room History:                                                            ║
║                                                                           ║
║  ┌─────────────────────────────────────────────────────────────────┐    ║
║  │ ● Quiz Session 1    ABC123DEF456    Easy    👥 10    [View]    │    ║
║  └─────────────────────────────────────────────────────────────────┘    ║
║  ↑ Active room (green dot)                                               ║
║                                                                           ║
║  ┌─────────────────────────────────────────────────────────────────┐    ║
║  │ ✓ Security Quiz     XYZ789GHI012    Medium  👥 25    [View]    │    ║
║  └─────────────────────────────────────────────────────────────────┘    ║
║  ↑ Completed room (green checkmark)                                      ║
║                                                                           ║
║  ┌─────────────────────────────────────────────────────────────────┐    ║
║  │ ● Network Game      JKL345MNO678    Hard    👥 15               │    ║
║  │   Cybersecurity Fundamentals                        [View]      │    ║
║  └─────────────────────────────────────────────────────────────────┘    ║
║  ↑ GameMode room with game name shown                                    ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## Room Item Breakdown

### Active Room
```
┌───────────────────────────────────────────────────────────────┐
│ ● │ Room Name    │ ROOM-CODE-12 │ Easy │ 👥 10 │ Game │ View │
│   │  (130px)     │  (flexible)  │ 70px │  auto │ flex │ 70px │
└───────────────────────────────────────────────────────────────┘
 ↑ Status Badge (● = active, ✓ = completed)
```

### Completed Room
```
┌───────────────────────────────────────────────────────────────┐
│ ✓ │ Finished Quiz │ XYZ789ABC123 │ Med │ 👥 25 │     │ View │
│   │  (130px)      │  (flexible)  │ 70px│  auto │     │ 70px │
└───────────────────────────────────────────────────────────────┘
 ↑ Green checkmark for completed
```

## Statistics Panel View

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  ← Back to Room History                      Quiz Session 1               ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  🏆 CyberQuiz Leaderboard (10 questions)                                 ║
║                                                                           ║
║  🥇  Alice Johnson          Score: 10/10                                  ║
║  🥈  Bob Smith              Score: 9/10                                   ║
║  🥉  Charlie Davis          Score: 8/10                                   ║
║  #4  Diana Evans            Score: 7/10                                   ║
║  #5  Ethan Foster           Score: 6/10                                   ║
║                                                                           ║
║  [Waiting for students to finish...]                                      ║
║                                                                           ║
║                                                                           ║
║                     ┌────────────────────────────┐                        ║
║                     │ ← Back to Room History     │                        ║
║                     └────────────────────────────┘                        ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## Color Scheme

### Status Badges
- **Active (●)**: `Color(0, 1, 0.5)` — Bright green
- **Completed (✓)**: `Color(0.2, 0.8, 0.3)` — Muted green

### Room Item Backgrounds
- **Active**: `bg_color = Color(0.05, 0.1, 0.2, 0.9)`  
  `border_color = Color(0.145, 0.878, 0.992, 0.6)` — Bright cyan
- **Completed**: `bg_color = Color(0.03, 0.08, 0.15, 0.8)`  
  `border_color = Color(0.145, 0.878, 0.992, 0.3)` — Dim cyan

### Text Colors
- **Room Name**: White `Color(1, 1, 1, 1)`
- **Room Code**: Light cyan `Color(0.7, 0.9, 1, 1)`
- **Difficulty**: Light gray `Color(0.8, 0.8, 0.8, 1)`
- **Player Count**: Cyan `Color(0.6, 0.9, 1, 1)`
- **Game Name**: Mint green `Color(0.5, 1, 0.8, 1)`

### View Button
- **Background**: `Color(0.145, 0.878, 0.992, 0.8)` — Cyan
- **Text**: `Color(0.03, 0.05, 0.12, 1)` — Dark blue/black

## Flow Diagram

```
┌─────────────────────┐
│  Teacher Landing    │
│     Page            │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ TeacherCreateRoom   │◄──────────────┐
│   (Main Panel)      │               │
│                     │               │
│ • Room History List │               │
│ • Create Button     │               │
└──────────┬──────────┘               │
           │                          │
     ┌─────┴─────┐                    │
     │           │                    │
     ↓           ↓                    │
┌─────────┐ ┌─────────┐              │
│ Create  │ │  View   │              │
│  Room   │ │  Stats  │              │
└────┬────┘ └────┬────┘              │
     │           │                    │
     ↓           ↓                    │
┌─────────┐ ┌─────────────────────┐  │
│Generate │ │  Statistics Panel   │  │
│  Code   │ │                     │  │
└────┬────┘ │ • Live Leaderboard  │  │
     │      │ • Back to History   │──┘
     ↓      └─────────────────────┘
┌─────────┐         ↑
│ Lobby   │         │
│ & Game  │─────────┘
└─────────┘   (When teacher clicks back)
```

## Interaction Guide

### Creating a Room
1. Click "+ Create" button
2. Fill in room details
3. Click "Generate"
4. Room is saved to Firestore with status "active"
5. Room appears in list with green ● badge
6. Share room code with students

### Viewing Statistics
1. Click "View" button on any room
2. Statistics panel opens
3. See real-time leaderboard updates
4. Click "← Back to Room History"
5. Room marked as "completed" in Firestore
6. Return to main panel
7. Room now shows green ✓ badge

### Reviewing Past Rooms
1. Scroll through room history list
2. Active rooms (●) are still in progress
3. Completed rooms (✓) are finished sessions
4. Click "View" on any room to see final results
5. View button works for both active and completed rooms

## Responsive Layout

### Room Item Sizing
```
┌──────────────────────────────────────────────────────────┐
│ [2]  [   130px    ]  [  flexible  ] [70] [auto] [flex] [70]│
│  ●    Room Name      ROOM-CODE-123  Easy  👥 10  Game  View│
└──────────────────────────────────────────────────────────┘
  ↑         ↑                ↑          ↑      ↑      ↑    ↑
Badge   Name (fixed)    Code (grows)  Diff  Count  Game  Btn
```

### Minimum Size
- Room item height: 52px
- View button: 70×32px
- Badge icon: 16px font size

---

**Note**: This UI follows the existing TeacherCreateRoom design system with cyan accents and dark blue backgrounds. Status badges use green to differentiate from the cyan accent color.
