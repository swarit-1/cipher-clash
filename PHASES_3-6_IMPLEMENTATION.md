# 🚀 Cipher Clash V2.0 - Phases 3-6 Implementation Guide

## Overview
This document provides detailed implementation instructions for Phases 3-6 of the Cipher Clash V2.0 transformation.

**Current Status**: Phase 1-2 Complete (Backend 100%)
**Next**: Phases 3-6 (Frontend + Infrastructure)

---

## 📱 PHASE 3: Flutter Frontend Transformation

### ✅ Design System (COMPLETE)

**Files Created**:
- ✅ `apps/client/lib/src/theme/app_theme.dart` - Complete cyberpunk design system
- ✅ `apps/client/lib/src/widgets/cyberpunk_button.dart` - Animated glowing buttons
- ✅ `apps/client/lib/src/widgets/glow_card.dart` - Glowing card components

**Design System Features**:
- Cyber Blue (#00D9FF), Neon Purple (#B24BF3), Electric Green (#00FF85)
- Space Grotesk (headings), Inter (body), JetBrains Mono (code)
- 8px spacing grid system
- Glow effects with animations
- Rank tier colors (Bronze → Diamond)
- Responsive gradients and shadows

---

### 🎨 Phase 3.1: New Screens Implementation

#### Priority 1: Authentication Flow

**1. Onboarding Screen** (`apps/client/lib/src/features/onboarding/onboarding_screen.dart`)

```dart
// Interactive 60-second cipher introduction
// Features:
// - 3-step animated tutorial
// - Interactive cipher demo (Caesar shift)
// - Smooth page transitions
// - "Skip" and "Get Started" buttons
```

**Implementation**:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Competitive Cryptography',
      description: 'Solve ciphers faster than your opponent in real-time duels',
      animation: 'assets/animations/intro_1.json', // Add Lottie animations
      color: AppTheme.cyberBlue,
    ),
    OnboardingPage(
      title: '15 Cipher Types',
      description: 'From Caesar to RSA - master them all and climb the ranks',
      animation: 'assets/animations/intro_2.json',
      color: AppTheme.neonPurple,
    ),
    OnboardingPage(
      title: 'Global Leaderboards',
      description: 'Compete with players worldwide and prove your skills',
      animation: 'assets/animations/intro_3.json',
      color: AppTheme.electricGreen,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
          ),

          // Page view
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index]),
          ),

          // Bottom navigation
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation placeholder (use Lottie or custom animations)
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.color.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.security,
              size: 150,
              color: page.color,
            ),
          ).animate().scale(duration: 600.ms).fadeIn(),

          const SizedBox(height: AppTheme.spacing4),

          Text(
            page.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: page.color,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: AppTheme.spacing2),

          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip button
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Skip'),
          ),

          // Page indicators
          Row(
            children: List.generate(
              _pages.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? AppTheme.cyberBlue
                      : AppTheme.cyberBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate().scale(duration: 200.ms),
            ),
          ),

          // Next/Get Started button
          CyberpunkButton(
            label: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
            onPressed: () {
              if (_currentPage == _pages.length - 1) {
                Navigator.pushReplacementNamed(context, '/login');
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            variant: CyberpunkButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String animation;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.animation,
    required this.color,
  });
}
```

**2. Login Screen** (`apps/client/lib/src/features/auth/login_screen.dart`)

**Features**:
- Email/password input with validation
- "Remember me" checkbox
- "Forgot password" link
- Social login (optional)
- Animated error messages
- Loading state during authentication

**3. Registration Screen** (`apps/client/lib/src/features/auth/register_screen.dart`)

**Features**:
- Username, email, password, region selection
- Password strength indicator
- Terms and conditions checkbox
- Animated form validation
- Avatar selection (optional)

---

#### Priority 2: Core Gameplay Screens

**4. Main Menu Screen** (`apps/client/lib/src/features/menu/main_menu_screen.dart`)

**Features**:
- Quick Play button (cyberpunk style)
- Ranked/Casual mode selector
- Daily quests preview (3 cards)
- Player stats widget (ELO, rank, win rate)
- Navigation to Profile, Leaderboard, Settings
- Animated background (matrix rain or circuit pattern)

**5. Matchmaking Queue Screen** (`apps/client/lib/src/features/matchmaking/queue_screen.dart`)

**Features**:
- Animated search indicator
- Player count in queue
- Estimated wait time with countdown
- "Cancel" button
- Opponent found animation (explosion effect)
- ELO range display with expanding animation

**6. Game Screen** (`apps/client/lib/src/features/game/game_screen.dart`)

**Features**:
- Split-screen layout (you vs opponent)
- Timer countdown (top center)
- Cipher display with formatted text
- Solution input field
- Hint button (power-up)
- Real-time score tracking
- Particle effects on correct solve
- Victory/defeat animations

**7. Post-Match Summary** (`apps/client/lib/src/features/game/match_summary_screen.dart`)

**Features**:
- Winner announcement with confetti
- XP gain animation (progress bar filling)
- ELO change (+/- with color)
- Stats breakdown (solve time, accuracy)
- "Play Again" and "Back to Menu" buttons
- Achievements unlocked (if any)
- Replay option

---

#### Priority 3: Progression & Social

**8. Profile Screen** (`apps/client/lib/src/features/profile/profile_screen.dart`)

**Features**:
- Avatar and username
- Current rank tier with progress bar
- Total stats (games, wins, losses, win rate)
- Recent match history (last 10)
- Achievement showcase (top 6)
- Edit profile button
- Settings button

**9. Leaderboard Screen** (`apps/client/lib/src/features/leaderboard/leaderboard_screen.dart`)

**Features**:
- Tabs: Global, Regional, Friends
- Top 3 podium with special styling
- Scrollable list with rank, avatar, username, ELO
- Current player highlight
- Refresh button
- Season selector

**10. Achievement Gallery** (`apps/client/lib/src/features/achievements/achievements_screen.dart`)

**Features**:
- Grid layout of achievement cards
- Locked/unlocked states
- Progress bars for incomplete achievements
- Categories (Speed, Mastery, Streak, Collection)
- Rarity indicators (Common, Rare, Epic, Legendary)
- Total achievement points

**11. Social Hub** (`apps/client/lib/src/features/social/social_hub_screen.dart`)

**Features**:
- Friends list with online status
- Add friend button
- Chat interface (basic)
- Clan overview (if member)
- Private match invites

**12. Settings Screen** (`apps/client/lib/src/features/settings/settings_screen.dart`)

**Features**:
- Audio (SFX, music volume)
- Graphics (animations on/off, quality)
- Notifications (push, email)
- Account (change password, logout)
- About (version, credits, licenses)

---

### 🎭 Phase 3.2: Animations & Polish

**Particle System** (`apps/client/lib/src/widgets/particle_effect.dart`)

```dart
// Victory confetti
// Solve success particles
// Defeat animation
// Level up explosion
```

**Page Transitions** (`apps/client/lib/src/utils/page_transitions.dart`)

```dart
// Fade + slide transition
// Cyberpunk glitch effect
// Scale transition
```

**Loading Skeletons** (`apps/client/lib/src/widgets/loading_skeleton.dart`)

```dart
// Shimmer effect for cards
// Pulse animation for text
// Gradient animation
```

**Dependencies to Add**:
```yaml
dependencies:
  flutter_animate: ^4.3.0      # Easy animations
  lottie: ^2.7.0               # Animation files
  confetti: ^0.7.0             # Victory confetti
  shimmer: ^3.0.0              # Loading shimmer
  vibration: ^1.8.4            # Haptic feedback
```

---

### 🔌 Phase 3.3: State Management Upgrade

**Riverpod Providers** (`apps/client/lib/src/providers/`)

```dart
// auth_provider.dart - Authentication state
// game_provider.dart - Active game state
// matchmaking_provider.dart - Queue state
// user_provider.dart - User profile
// leaderboard_provider.dart - Cached leaderboard
// achievements_provider.dart - Achievement progress
```

**Offline Support** (`apps/client/lib/src/services/cache_service.dart`)

```dart
// Local storage with Hive or SharedPreferences
// Sync queue for offline actions
// Optimistic updates
```

---

## 🏆 PHASE 4: Social & Progression

### Backend Services Needed

**Achievement Service** (`services/achievement/`)

```go
// Endpoints:
// GET  /api/v1/achievements - List all achievements
// GET  /api/v1/achievements/user/:id - User progress
// POST /api/v1/achievements/check - Check and unlock
```

**Social Service** (`services/social/`)

```go
// Endpoints:
// POST   /api/v1/friends/add
// DELETE /api/v1/friends/:id
// GET    /api/v1/friends
// POST   /api/v1/clans/create
// GET    /api/v1/clans/:id
```

### Achievement System

**Achievement Definitions** (Database seed)

```sql
INSERT INTO achievements (id, name, description, category, rarity, points) VALUES
-- Speed Achievements
('speed_30s', 'Lightning Fast', 'Solve a puzzle in under 30 seconds', 'SPEED', 'RARE', 50),
('speed_15s', 'Speedrunner', 'Solve a puzzle in under 15 seconds', 'SPEED', 'EPIC', 100),

-- Mastery Achievements
('caesar_100', 'Caesar Master', 'Solve 100 Caesar ciphers', 'MASTERY', 'COMMON', 25),
('vigenere_50', 'Vigenere Virtuoso', 'Solve 50 Vigenere ciphers', 'MASTERY', 'RARE', 50),
('rsa_10', 'RSA Expert', 'Solve 10 RSA ciphers', 'MASTERY', 'EPIC', 100),

-- Streak Achievements
('win_streak_5', 'Hot Streak', 'Win 5 matches in a row', 'STREAK', 'RARE', 75),
('win_streak_10', 'Unstoppable', 'Win 10 matches in a row', 'STREAK', 'EPIC', 150),

-- Collection Achievements
('try_all_ciphers', 'Cipher Explorer', 'Try all 15 cipher types', 'COLLECTION', 'RARE', 100),
('master_all_ciphers', 'Cryptography God', 'Master all 15 ciphers', 'COLLECTION', 'LEGENDARY', 500);
```

### XP System

**Level Curve** (Exponential):

```
Level 1: 0 XP
Level 2: 100 XP
Level 3: 250 XP
Level 4: 450 XP
Level 5: 700 XP
...
Level 100: 500,000 XP
```

**Formula**: `xp_required = base * (level ^ 1.5)`

**XP Gains**:
- Match win: 50 XP + (10 * difficulty)
- Match loss: 10 XP
- First win of day: +25 XP bonus
- Daily quest: 100 XP each
- Achievement: Varies (25-500 XP)

---

## 📊 PHASE 5: Observability & DevOps

### Monitoring Stack Setup

**1. Prometheus** (`infra/monitoring/prometheus.yml`)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'auth-service'
    static_configs:
      - targets: ['auth:8080']

  - job_name: 'puzzle-service'
    static_configs:
      - targets: ['puzzle:8082']

  - job_name: 'matchmaker-service'
    static_configs:
      - targets: ['matchmaker:8081']

  - job_name: 'game-service'
    static_configs:
      - targets: ['game:8083']
```

**Add to services** (example: `services/auth/main.go`):

```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )

    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "http_request_duration_seconds",
            Help: "HTTP request duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal)
    prometheus.MustRegister(requestDuration)
}

// In main():
http.Handle("/metrics", promhttp.Handler())
```

**2. Grafana Dashboards** (`infra/monitoring/dashboards/`)

- `system_health.json` - CPU, memory, disk
- `game_metrics.json` - Active matches, queue times
- `user_engagement.json` - DAU, retention, session length
- `performance.json` - Latency p50/p95/p99
- `business_kpis.json` - Registrations, matches played

**3. Jaeger Tracing** (`docker-compose.yml`)

```yaml
jaeger:
  image: jaegertracing/all-in-one:latest
  ports:
    - "5775:5775/udp"
    - "6831:6831/udp"
    - "6832:6832/udp"
    - "5778:5778"
    - "16686:16686"  # UI
    - "14268:14268"
```

### CI/CD Pipeline

**GitHub Actions** (`.github/workflows/backend.yml`)

```yaml
name: Backend CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.23'
      - name: Run tests
        run: make test
      - name: Run linter
        run: make lint

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Docker images
        run: make build-docker
      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push your-registry/cipher-clash:latest

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to staging
        run: |
          # Deploy commands here
```

**Flutter CI** (`.github/workflows/flutter.yml`)

```yaml
name: Flutter CI/CD

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter test

  build-web:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build web --release
      - name: Deploy to hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
```

---

## 🧪 PHASE 6: Testing & Quality

### Backend Testing

**Unit Tests** (`services/auth/internal/service/auth_service_test.go`)

```go
func TestAuthService_Register(t *testing.T) {
    // Setup
    service := setupTestService(t)

    // Test cases
    tests := []struct {
        name    string
        req     *RegisterRequest
        wantErr bool
    }{
        {
            name: "valid registration",
            req: &RegisterRequest{
                Username: "testuser",
                Email:    "test@test.com",
                Password: "password123",
            },
            wantErr: false,
        },
        {
            name: "duplicate username",
            req: &RegisterRequest{
                Username: "existinguser",
                Email:    "new@test.com",
                Password: "password123",
            },
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := service.Register(context.Background(), tt.req)
            if (err != nil) != tt.wantErr {
                t.Errorf("Register() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

**Load Testing** (`tests/load/k6-script.js`)

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up
    { duration: '5m', target: 1000 }, // Stay at 1000 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<200'],  // 95% under 200ms
    http_req_failed: ['rate<0.01'],    // Error rate < 1%
  },
};

export default function () {
  // Register
  let registerRes = http.post('http://localhost:8080/api/v1/auth/register', JSON.stringify({
    username: `user_${__VU}_${__ITER}`,
    email: `test_${__VU}_${__ITER}@test.com`,
    password: 'password123',
  }), { headers: { 'Content-Type': 'application/json' } });

  check(registerRes, {
    'register status 200': (r) => r.status === 200,
  });

  sleep(1);

  // Generate puzzle
  let puzzleRes = http.post('http://localhost:8082/api/v1/puzzle/generate', JSON.stringify({
    difficulty: 5,
  }));

  check(puzzleRes, {
    'puzzle generation < 50ms': (r) => r.timings.duration < 50,
  });
}
```

### Anti-Cheat System

**Server-Side Validation** (`services/puzzle_engine/internal/anticheat/`)

```go
package anticheat

import (
    "time"
)

// SolveAnalysis checks if a solve is suspicious
type SolveAnalysis struct {
    IsSuspicious bool
    Reasons      []string
    ConfidenceScore float64
}

func AnalyzeSolve(difficulty int, solveTimeMs int, userELO int) *SolveAnalysis {
    analysis := &SolveAnalysis{
        Reasons: []string{},
    }

    // Check for impossibly fast solves
    minTimeMs := calculateMinimumTime(difficulty)
    if solveTimeMs < minTimeMs {
        analysis.IsSuspicious = true
        analysis.Reasons = append(analysis.Reasons, "Impossibly fast solve time")
        analysis.ConfidenceScore = 0.9
    }

    // Check for consistent timings (bot pattern)
    // TODO: Implement statistical analysis

    return analysis
}

func calculateMinimumTime(difficulty int) int {
    // Human reaction time + minimum cipher solve time
    baseTime := 3000 // 3 seconds minimum
    return baseTime + (difficulty * 500)
}
```

---

## 📝 Implementation Priority

### Week 1: Core Frontend
1. ✅ Design system (DONE)
2. Login/Register screens
3. Main menu screen
4. Game screen update

### Week 2: Gameplay Features
1. Matchmaking queue screen
2. Post-match summary
3. Profile screen
4. Leaderboard screen

### Week 3: Polish & Social
1. Animations and particles
2. Achievement gallery
3. Social hub (basic)
4. Settings screen

### Week 4: Infrastructure
1. Prometheus + Grafana setup
2. CI/CD pipelines
3. Load testing
4. Anti-cheat system

---

## 🚀 Quick Start Commands

```bash
# Frontend development
cd apps/client
flutter pub get
flutter run -d chrome

# Run tests
flutter test

# Build for production
flutter build web --release

# Backend monitoring (add to docker-compose.yml)
docker-compose up -d prometheus grafana jaeger

# Load testing
k6 run tests/load/k6-script.js
```

---

**Status**: Implementation guide complete. Start with Week 1 priorities for maximum impact.
