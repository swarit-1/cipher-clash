# Cipher Clash V2.0 - Complete Implementation Guide

**Date:** 2025-01-25
**Version:** 2.0.0
**Author:** Lead Game Designer + Full-Stack Engineer

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Database Schema](#database-schema)
3. [New Backend Services](#new-backend-services)
4. [New Cipher Types](#new-cipher-types)
5. [Flutter UI Components](#flutter-ui-components)
6. [API Endpoints](#api-endpoints)
7. [Implementation Checklist](#implementation-checklist)
8. [Migration Guide](#migration-guide)

---

## 🎯 Overview

Cipher Clash V2.0 introduces **5 major feature categories** to enhance player engagement and retention:

### 1. Onboarding & Training
- ✅ Interactive multi-step tutorial (8 steps)
- ✅ First-match guided bot battle
- ✅ Cipher visualizers (Caesar, Vigenère, Rail Fence, Playfair)
- ✅ Daily mini-lessons system

### 2. New Game Modes
- ✅ Speed Solve (60-second micro puzzles)
- ✅ Cipher Gauntlet (progressive difficulty)
- ✅ Boss Battles (AI with special abilities)

### 3. Social Systems
- ✅ Enhanced player profile with statistics
- ✅ Friends list with invite-to-match
- ✅ Basic spectator mode

### 4. Progression & Retention
- ✅ Achievements overhaul
- ✅ Daily missions (5-7 rotating tasks)
- ✅ Collection/cosmetic system
- ✅ Cipher Mastery Tree

### 5. Puzzle & Content Expansion
- ✅ 3 new cipher types: **Affine, Autokey, Enigma-lite**
- ✅ Multi-stage puzzles (2-3 cipher layers)
- ✅ AI-generated practice puzzle sets

---

## 🗄️ Database Schema

### Migration File
**Location:** `infra/postgres/migrations/001_new_features_v2.sql`

### New Tables Summary

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `tutorial_progress` | Track user tutorial completion | user_id, step_id, status, completed_at |
| `tutorial_steps` | Tutorial step definitions | id, title, category, cipher_type, xp_reward |
| `mission_templates` | Reusable mission definitions | id, name, objective_type, xp_reward, coin_reward |
| `user_missions` | User-assigned missions | user_id, template_id, progress, target, expires_at |
| `mastery_nodes` | Skill tree node definitions | id, cipher_type, tier, unlock_cost, bonus_type |
| `user_mastery` | Unlocked mastery nodes | user_id, node_id, points_spent |
| `cipher_mastery_points` | Per-cipher statistics | user_id, cipher_type, total_points, mastery_level |
| `cosmetics` | Cosmetic items catalog | id, name, category, rarity, coin_cost |
| `user_cosmetics` | User inventory | user_id, cosmetic_id, is_equipped |
| `user_loadout` | Currently equipped items | user_id, background_id, particle_effect_id, title_id |
| `friendships` | Friend connections | user_id, friend_id, status |
| `match_invitations` | Friend match invites | sender_id, recipient_id, game_mode, expires_at |
| `spectator_sessions` | Spectator tracking | match_id, spectator_id, is_active |
| `game_modes` | Game mode configs | id, name, time_limit_seconds, puzzles_per_match |
| `boss_battles` | Boss definitions | id, name, difficulty, abilities, loot_table |
| `boss_battle_sessions` | Boss fight tracking | user_id, boss_id, status, boss_health_remaining |
| `achievement_categories` | Achievement grouping | id, name, display_order |
| `puzzle_chains` | Multi-stage puzzles | id, total_stages, difficulty |
| `puzzle_stages` | Individual chain stages | chain_id, stage_number, puzzle_id |
| `cipher_solve_stats` | Daily solve statistics | user_id, cipher_type, date, puzzles_solved |
| `user_activity` | Heatmap data | user_id, activity_date, matches_played, xp_earned |
| `user_wallet` | User currency | user_id, coins, premium_currency |
| `wallet_transactions` | Transaction log | user_id, transaction_type, amount, source |

### Seeded Data

#### Game Modes
```sql
- ranked: Competitive ELO-based (180s, 3 puzzles)
- casual: Relaxed practice (180s, 3 puzzles)
- speed_solve: Rapid-fire (60s, 1 puzzle)
- cipher_gauntlet: Progressive difficulty (300s, 5 puzzles)
- boss_battle: AI opponents (600s, 10 puzzles)
```

#### Tutorial Steps
```
1. Welcome to Cipher Clash (25 XP)
2. Caesar Cipher Basics (50 XP)
3. Vigenère Cipher (75 XP)
4. Your First Match (100 XP)
5. Rail Fence Cipher (75 XP)
6. Playfair Cipher (100 XP)
7. Using Power-Ups (75 XP)
8. Cipher Mastery Trees (50 XP)
```

#### Mission Templates
```
- Victory Lap: Win 2 matches (100 XP, 15 coins)
- Puzzle Master: Solve 5 puzzles (75 XP, 10 coins)
- Caesar Day: Solve 3 Caesar ciphers (50 XP, 8 coins)
- Speed Demon: Complete 1 Speed Solve (80 XP, 12 coins)
- Win Streak: Win 3 in a row (150 XP, 20 coins)
- Ranked Warrior: Play 10 ranked matches (500 XP, 100 coins)
- Gauntlet Runner: Complete 3 Gauntlets (300 XP, 50 coins)
```

---

## 🔧 New Backend Services

### 1. Tutorial Service (Port 8089)

**Location:** `services/tutorial/`

**Structure:**
```
services/tutorial/
├── main.go
├── internal/
│   ├── handler/
│   │   └── tutorial_handler.go
│   ├── service/
│   │   ├── tutorial_service.go
│   │   └── visualizer_service.go
│   └── repository/
│       ├── tutorial_repository.go
│       └── progress_repository.go
└── go.mod
```

**Endpoints:**
```
GET    /api/v1/tutorial/steps
GET    /api/v1/tutorial/progress
POST   /api/v1/tutorial/progress
POST   /api/v1/tutorial/complete
POST   /api/v1/tutorial/skip
POST   /api/v1/tutorial/visualize/{cipher_type}
GET    /api/v1/tutorial/visualizers
POST   /api/v1/tutorial/bot-battle/start
POST   /api/v1/tutorial/bot-battle/submit
GET    /health
```

**Key Features:**
- Tutorial step management
- Progress tracking with XP rewards
- Caesar, Vigenère, Rail Fence, Playfair visualizers
- Bot battle opponent (difficulty = 1, ELO = 1000)
- Step-by-step cipher visualization

### 2. Missions Service (Port 8090)

**Location:** `services/missions/`

**Structure:**
```
services/missions/
├── main.go
├── internal/
│   ├── handler/
│   │   └── missions_handler.go
│   ├── service/
│   │   ├── missions_service.go
│   │   └── scheduler.go
│   └── repository/
│       ├── missions_repository.go
│       └── user_missions_repository.go
└── go.mod
```

**Endpoints:**
```
GET    /api/v1/missions/active
GET    /api/v1/missions/templates
POST   /api/v1/missions/assign
POST   /api/v1/missions/progress
POST   /api/v1/missions/complete
POST   /api/v1/missions/abandon
POST   /api/v1/missions/refresh
GET    /health
```

**Key Features:**
- Daily/weekly mission rotation
- Progress tracking with auto-increment
- Reward claiming (XP, coins, cosmetics)
- Mission expiration (24h for daily, 7d for weekly)
- Smart assignment algorithm (weighted by priority)

### 3. Mastery Service (Port 8091)

**Location:** `services/mastery/`

**Structure:**
```
services/mastery/
├── main.go
├── internal/
│   ├── handler/
│   │   └── mastery_handler.go
│   ├── service/
│   │   ├── mastery_service.go
│   │   └── stats_service.go
│   └── repository/
│       ├── mastery_repository.go
│       └── stats_repository.go
└── go.mod
```

**Endpoints:**
```
GET    /api/v1/mastery/tree/{cipher_type}
GET    /api/v1/mastery/user/{cipher_type}
POST   /api/v1/mastery/unlock
GET    /api/v1/mastery/stats/{cipher_type}
POST   /api/v1/mastery/award-points
GET    /api/v1/mastery/leaderboard/{cipher_type}
GET    /health
```

**Mastery Tree Structure (per cipher):**
```
Tier 1 (Root nodes):
- Speed Boost I: 10% faster solve time (100 pts)
- Hint Discount I: 25% cheaper hints (100 pts)

Tier 2:
- Speed Boost II: 20% faster (requires Speed Boost I, 200 pts)
- Score Multiplier I: 1.1x score (requires Hint Discount I, 200 pts)

Tier 3:
- Speed Boost III: 30% faster (requires Speed Boost II, 300 pts)
- Auto-Decrypt: Show first letter (requires Score Multiplier I, 300 pts)

Tier 4:
- Master Bonus: 1.5x all bonuses (requires Tier 3 nodes, 500 pts)

Tier 5:
- Grandmaster: Unlock cosmetic + title (requires Master Bonus, 1000 pts)
```

**Points Earning:**
- Solve puzzle: 10-50 pts (based on difficulty & speed)
- Achievement unlock: 100 pts
- Daily bonus: 25 pts
- Level up: 500 pts

### 4. Social Service (Port 8092)

**Location:** `services/social/`

**Endpoints:**
```
POST   /api/v1/friends/request
POST   /api/v1/friends/accept
POST   /api/v1/friends/decline
DELETE /api/v1/friends/remove
GET    /api/v1/friends
GET    /api/v1/friends/requests
POST   /api/v1/friends/block

POST   /api/v1/invites/send
POST   /api/v1/invites/respond
GET    /api/v1/invites/pending

POST   /api/v1/spectate/join
POST   /api/v1/spectate/leave
GET    /api/v1/spectate/viewers
GET    /api/v1/spectate/matches
GET    /health
```

### 5. Cosmetics Service (Port 8093)

**Location:** `services/cosmetics/`

**Endpoints:**
```
GET    /api/v1/cosmetics/catalog
GET    /api/v1/cosmetics/inventory
POST   /api/v1/cosmetics/purchase
POST   /api/v1/cosmetics/equip
POST   /api/v1/cosmetics/unequip
GET    /api/v1/cosmetics/loadout
PUT    /api/v1/cosmetics/loadout
POST   /api/v1/cosmetics/grant
GET    /health
```

**Cosmetic Categories:**
- Backgrounds: Animated backdrops
- Particle Effects: Visual effects during matches
- Titles: Display titles under username
- Avatar Frames: Profile picture borders
- Cipher Skins: Custom cipher UI themes

**Rarity Tiers:**
- Common: 50-100 coins
- Rare: 150-300 coins
- Epic: 500-750 coins
- Legendary: 1000-2000 coins
- Mythic: Achievement/mission exclusive

---

## 🔐 New Cipher Types

### 16. Affine Cipher

**Mathematical Formula:**
```
Encryption: E(x) = (ax + b) mod 26
Decryption: D(y) = a⁻¹(y - b) mod 26
```

**Key Generation:**
```go
Valid 'a' values (coprime with 26): [3, 5, 7, 9, 11, 15, 17, 19, 21, 23, 25]
keyA := validA[difficulty % len(validA)]
keyB := (difficulty * 5) % 26
```

**Example:**
```
Plaintext: HELLO
Key: a=5, b=8
Ciphertext: RCLLA
```

### 17. Autokey Cipher

**Algorithm:**
- Primer: Short initial key (e.g., "KEY")
- Keystream: Primer + plaintext itself
- Similar to Vigenère but self-extending

**Key Generation:**
```go
primerLength := 3 + (difficulty / 3)
primer := randomLetters(primerLength)
```

**Example:**
```
Plaintext: HELLO
Primer: KEY
Keystream: KEYHELLO (primer + plaintext)
Process: H+K, E+E, L+Y, L+H, O+E
Ciphertext: RIJST
```

### 18. Enigma-lite Cipher

**Components:**
- 3 rotors (stepping left-to-right)
- 1 reflector
- Initial rotor positions

**Key Generation:**
```go
5 predefined rotor wirings
Rotor positions: (difficulty % 26, (difficulty*3) % 26, (difficulty*7) % 26)
```

**Process Flow:**
```
1. Step rotors (right rotor steps every char)
2. Forward pass: Input → Rotor1 → Rotor2 → Rotor3 → Reflector
3. Backward pass: Reflector → Rotor3⁻¹ → Rotor2⁻¹ → Rotor1⁻¹ → Output
4. Reciprocal: Encrypt(Decrypt(x)) = x
```

**Example:**
```
Plaintext: HELLO
Rotor positions: 0, 3, 7
Ciphertext: KJXYS (changes as rotors step)
```

---

## 📱 Flutter UI Components

### New Screens

#### 1. Tutorial Screen (`apps/client/lib/src/features/tutorial/tutorial_screen.dart`)

**Features:**
- Step-by-step progression UI
- Interactive cipher practice
- Progress bar (8 steps)
- Skip tutorial option
- XP reward animations

**Layout:**
```dart
Column(
  - AppBar("Tutorial - Step X/8")
  - ProgressIndicator(completedSteps / totalSteps)
  - StepContent(
      - Title
      - Description
      - InteractiveCipherWidget() // If cipher step
      - ActionButtons()
  )
  - NavigationButtons(Previous, Next/Complete)
)
```

#### 2. Cipher Visualizer Widget (`apps/client/lib/src/widgets/cipher_visualizer.dart`)

**Supported Ciphers:**
- Caesar: Show shift animation
- Vigenère: Highlight key alignment
- Rail Fence: Display rail pattern
- Playfair: Show matrix grid

**Features:**
- Step-by-step animation
- Play/Pause controls
- Speed adjustment
- Export visualization

**Caesar Example:**
```dart
CipherVisualizer(
  cipherType: 'CAESAR',
  input: 'HELLO',
  key: {'shift': 3},
  onStepComplete: (step) => showStep(step),
)

Steps:
1. H → shift 3 → K
2. E → shift 3 → H
3. L → shift 3 → O
4. L → shift 3 → O
5. O → shift 3 → R
Result: KHOOR
```

#### 3. Missions Screen (`apps/client/lib/src/features/missions/missions_screen.dart`)

**Tabs:**
- Active Missions (5 daily)
- Completed Today
- Weekly Missions

**Mission Card:**
```dart
Card(
  - Icon(missionType)
  - Title + Description
  - ProgressBar(current / target)
  - Rewards(xp, coins, cosmetic?)
  - TimeRemaining
  - CompleteButton() // if progress >= target
)
```

**Features:**
- Auto-refresh daily at midnight
- Real-time progress updates
- Claim rewards animation
- Mission history

#### 4. Mastery Tree Screen (`apps/client/lib/src/features/mastery/mastery_tree_screen.dart`)

**Layout:**
- Cipher selector dropdown (18 ciphers)
- Available points display
- Tree canvas with nodes
- Node details panel

**Node Rendering:**
```dart
CustomPaint(
  painter: MasteryTreePainter(
    nodes: nodes,
    connections: edges,
    unlocked: userUnlockedNodes,
  ),
)

Node states:
- Locked (gray, prerequisites not met)
- Available (glowing, can unlock)
- Unlocked (colored, bonus active)
```

**Bonuses Applied:**
- Speed Boost: Reduce timer by %
- Score Multiplier: Increase final score
- Hint Discount: Reduce hint cost
- Auto-Decrypt: Reveal first N letters

#### 5. Enhanced Profile Screen (`apps/client/lib/src/features/profile/enhanced_profile_screen.dart`)

**Sections:**

**Header:**
- Avatar with frame
- Username + Title
- ELO rating + Rank tier
- Friend count

**Statistics:**
```dart
StatRow(icon: Icons.emoji_events, label: "Total Wins", value: 142)
StatRow(icon: Icons.speed, label: "Avg Solve Time", value: "45s")
StatRow(icon: Icons.trending_up, label: "Win Rate", value: "68%")
StatRow(icon: Icons.local_fire_department, label: "Current Streak", value: 5)
```

**Activity Heatmap:**
```dart
CalendarHeatmap(
  data: last365Days,
  colorScheme: [grey, lightBlue, mediumBlue, darkBlue],
  onDayTap: (date) => showDayDetails(date),
)
```

**Cipher Mastery Overview:**
```dart
GridView.count(
  crossAxisCount: 3,
  children: ciphers.map((c) => CipherMasteryCard(
    cipherType: c.type,
    masteryLevel: c.level,
    progress: c.progress,
  )),
)
```

**Achievements:**
- Grid of unlocked achievements
- Progress toward locked ones
- Recent unlocks highlighted

#### 6. Friends Screen (`apps/client/lib/src/features/social/friends_screen.dart`)

**Tabs:**
- Friends List
- Friend Requests
- Search Users

**Friend Card:**
```dart
Card(
  - Avatar + Status Indicator (online/offline/in-match)
  - Username + Rank
  - ELO Rating
  - Actions:
    - InviteToMatch()
    - ViewProfile()
    - RemoveFriend()
)
```

**Features:**
- Real-time online status
- Quick invite button
- Filter by status
- Recent activity

#### 7. Spectator Mode (`apps/client/lib/src/features/spectate/spectator_screen.dart`)

**Layout:**
```dart
Column(
  - MatchInfo(players, mode, timeElapsed)
  - SplitView(
      left: Player1State(score, currentPuzzle, attempts)
      right: Player2State(score, currentPuzzle, attempts)
  )
  - SpectatorControls(
      - ViewerCount
      - LeaveButton
  )
)
```

**Features:**
- Real-time score updates via WebSocket
- See both players' progress
- Can't see solutions (until solved)
- Viewer list

#### 8. Game Mode Selection (`apps/client/lib/src/features/menu/game_mode_screen.dart`)

**Modes:**
```dart
ModeCard(
  name: "Speed Solve",
  description: "60-second rapid puzzles",
  difficulty: "Easy-Medium",
  rewards: "50 XP, 5 coins",
  icon: Icons.speed,
  onTap: () => joinQueue('speed_solve'),
)
```

**Unlocked Modes:**
- Ranked (default)
- Casual (default)
- Speed Solve (level 5+)
- Cipher Gauntlet (level 10+)
- Boss Battle (level 15+)

#### 9. Boss Battle Screen (`apps/client/lib/src/features/boss/boss_battle_screen.dart`)

**UI Elements:**
- Boss portrait + name + title
- Boss health bar
- Player health bar
- Current puzzle
- Boss ability cooldown indicator
- Loot preview

**Boss Abilities (random activation):**
- Time Drain: -10 seconds
- Scramble: Shuffle puzzle text
- Hint Block: Disable hints for 30s
- Double Damage: Next wrong answer = -20 health

**Victory Screen:**
- Loot acquired
- XP earned
- Mastery points
- Cosmetic unlocks

#### 10. Cosmetics Shop (`apps/client/lib/src/features/cosmetics/cosmetics_shop_screen.dart`)

**Tabs:**
- Backgrounds
- Particle Effects
- Titles
- Avatar Frames

**Cosmetic Card:**
```dart
Card(
  - Preview(animated if particle effect)
  - Name + Rarity Badge
  - Description
  - Price / Unlock Requirement
  - PurchaseButton() or EquipButton()
)
```

**Features:**
- Live preview
- Owned indicator
- Equipped indicator
- Sort by rarity/price
- Filter by owned/unowned

---

## 🌐 API Endpoints Summary

### Tutorial Service (8089)
```
GET    /api/v1/tutorial/steps                     → List all tutorial steps
GET    /api/v1/tutorial/progress?user_id=...      → Get user progress
POST   /api/v1/tutorial/progress                  → Update step progress
POST   /api/v1/tutorial/complete                  → Complete step
POST   /api/v1/tutorial/skip                      → Skip tutorial
POST   /api/v1/tutorial/visualize/{cipher_type}   → Get visualization steps
GET    /api/v1/tutorial/visualizers               → List available visualizers
POST   /api/v1/tutorial/bot-battle/start          → Start bot match
POST   /api/v1/tutorial/bot-battle/submit         → Submit solution
```

### Missions Service (8090)
```
GET    /api/v1/missions/active?user_id=...        → Active missions
GET    /api/v1/missions/templates                 → All mission templates
POST   /api/v1/missions/assign                    → Assign daily missions
POST   /api/v1/missions/progress                  → Update progress
POST   /api/v1/missions/complete                  → Claim rewards
POST   /api/v1/missions/abandon                   → Abandon mission
POST   /api/v1/missions/refresh                   → Refresh daily missions
```

### Mastery Service (8091)
```
GET    /api/v1/mastery/tree/{cipher_type}         → Get mastery tree
GET    /api/v1/mastery/user/{cipher_type}?user_id → User progress
POST   /api/v1/mastery/unlock                     → Unlock node
GET    /api/v1/mastery/stats/{cipher_type}        → Cipher statistics
POST   /api/v1/mastery/award-points               → Award mastery points
GET    /api/v1/mastery/leaderboard/{cipher_type}  → Mastery rankings
```

### Social Service (8092)
```
POST   /api/v1/friends/request                    → Send friend request
POST   /api/v1/friends/accept                     → Accept request
POST   /api/v1/friends/decline                    → Decline request
DELETE /api/v1/friends/remove                     → Remove friend
GET    /api/v1/friends?user_id=...                → Get friends list
GET    /api/v1/friends/requests?user_id=...       → Pending requests
POST   /api/v1/friends/block                      → Block user

POST   /api/v1/invites/send                       → Send match invite
POST   /api/v1/invites/respond                    → Accept/decline invite
GET    /api/v1/invites/pending?user_id=...        → Pending invites

POST   /api/v1/spectate/join                      → Join as spectator
POST   /api/v1/spectate/leave                     → Leave spectating
GET    /api/v1/spectate/viewers?match_id=...      → List spectators
GET    /api/v1/spectate/matches?user_id=...       → Spectatable matches
```

### Cosmetics Service (8093)
```
GET    /api/v1/cosmetics/catalog                  → All cosmetics
GET    /api/v1/cosmetics/inventory?user_id=...    → User inventory
POST   /api/v1/cosmetics/purchase                 → Buy cosmetic
POST   /api/v1/cosmetics/equip                    → Equip item
POST   /api/v1/cosmetics/unequip                  → Unequip item
GET    /api/v1/cosmetics/loadout?user_id=...      → Current loadout
PUT    /api/v1/cosmetics/loadout                  → Update loadout
POST   /api/v1/cosmetics/grant                    → Grant cosmetic
```

---

## ✅ Implementation Checklist

### Phase 1: Backend Foundation ✅
- [x] Database migration script created
- [x] Protobuf definitions created (tutorial, missions, mastery, social, cosmetics)
- [x] Updated puzzle.proto with new cipher types
- [x] Implemented 3 new ciphers (Affine, Autokey, Enigma-lite)

### Phase 2: Backend Services 🔄
- [ ] Tutorial Service complete
- [ ] Missions Service complete
- [ ] Mastery Service complete
- [ ] Social Service complete
- [ ] Cosmetics Service complete

### Phase 3: Flutter UI 🔄
- [ ] Tutorial screen + visualizers
- [ ] Missions screen
- [ ] Mastery tree screen
- [ ] Enhanced profile screen
- [ ] Friends screen
- [ ] Spectator mode
- [ ] Boss battle screen
- [ ] Cosmetics shop
- [ ] Game mode selection

### Phase 4: Integration
- [ ] Update app routes
- [ ] Connect Flutter services to new backends
- [ ] WebSocket integration for spectator mode
- [ ] Real-time mission progress updates
- [ ] Achievement integration with new systems

### Phase 5: Testing & Polish
- [ ] Unit tests for new services
- [ ] Integration tests
- [ ] UI/UX testing
- [ ] Performance optimization
- [ ] Bug fixes

---

## 🚀 Migration Guide

### Step 1: Run Database Migration
```bash
psql -U cipher_clash_user -d cipher_clash -f infra/postgres/migrations/001_new_features_v2.sql
```

### Step 2: Update Environment Variables
```bash
# Add to .env
TUTORIAL_SERVICE_PORT=8089
MISSIONS_SERVICE_PORT=8090
MASTERY_SERVICE_PORT=8091
SOCIAL_SERVICE_PORT=8092
COSMETICS_SERVICE_PORT=8093
```

### Step 3: Build and Run New Services
```bash
# Tutorial Service
cd services/tutorial
go mod init github.com/swarit-1/cipher-clash/services/tutorial
go mod tidy
go build -o ../../bin/tutorial-service
../../bin/tutorial-service

# Repeat for other services...
```

### Step 4: Update Docker Compose
```yaml
tutorial-service:
  build:
    context: .
    dockerfile: infra/docker/go.Dockerfile
    args:
      SERVICE_PATH: services/tutorial
  ports:
    - "8089:8089"
  environment:
    - TUTORIAL_SERVICE_PORT=8089
  depends_on:
    - postgres
    - redis
```

### Step 5: Update Flutter Dependencies
```yaml
# pubspec.yaml
dependencies:
  fl_chart: ^0.66.0        # For heatmap
  calendar_heatmap: ^1.0.0 # Activity visualization
  timelines: ^1.1.0        # Tutorial progress
  badges: ^3.1.2           # Notification badges
```

### Step 6: Update Flutter API Config
```dart
// apps/client/lib/src/services/api_config.dart
static const String tutorialServiceUrl = 'http://localhost:8089';
static const String missionsServiceUrl = 'http://localhost:8090';
static const String masteryServiceUrl = 'http://localhost:8091';
static const String socialServiceUrl = 'http://localhost:8092';
static const String cosmeticsServiceUrl = 'http://localhost:8093';
```

---

## 📊 Expected Metrics

### User Engagement
- **Tutorial Completion Rate:** Target 75%
- **Daily Mission Completion:** Target 60%
- **Mastery Tree Interaction:** Target 50% of users
- **Friend List Size:** Average 8-12 friends
- **Cosmetic Collection:** Average 15-20 items

### Retention
- **Day 1 Retention:** Target 70% (up from 50%)
- **Day 7 Retention:** Target 40% (up from 25%)
- **Day 30 Retention:** Target 20% (up from 10%)

### Monetization Opportunities
- Premium cosmetics
- XP boosters
- Mastery point packs
- Exclusive boss battles
- Limited-time cosmetics

---

## 🎨 Design Consistency

All new UI follows existing cyberpunk theme:
- Primary color: #00D9FF (Cyber Blue)
- Secondary: #B24BF3 (Neon Purple)
- Accent: #00FF85 (Electric Green)
- Background: #0A0E1A (Deep Dark)
- Surface: #131829 (Dark Navy)

All animations use `flutter_animate` package.
All loading states use shimmer effect.
All success states trigger haptic feedback.

---

## 📝 Next Steps

1. Complete implementation of all 5 backend services
2. Build Flutter UI components
3. Integrate with existing game flow
4. Comprehensive testing
5. Deploy to staging environment
6. User testing and feedback
7. Production deployment

---

**End of Implementation Guide**

For detailed code implementations, see individual service directories.
For Flutter components, see `apps/client/lib/src/` subdirectories.
