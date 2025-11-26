# Cipher Clash V2.0 - Flutter UI Code Samples

This document provides production-ready code samples for all major UI components in the V2.0 update.

---

## Table of Contents
1. [Tutorial System Widgets](#tutorial-system-widgets)
2. [Missions Screen](#missions-screen)
3. [Mastery Tree](#mastery-tree)
4. [Enhanced Profile](#enhanced-profile)
5. [Friends & Social](#friends-social)
6. [Cosmetics Shop](#cosmetics-shop)
7. [Helper Widgets](#helper-widgets)

---

## Tutorial System Widgets

### Tutorial Progress Bar
**File:** `apps/client/lib/src/features/tutorial/widgets/tutorial_progress_bar.dart`

```dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TutorialProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const TutorialProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      color: AppTheme.darkNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${currentStep + 1}/$totalSteps',
                style: const TextStyle(
                  color: AppTheme.cyberBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing1),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.textDisabled,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyberBlue),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
```

### Cipher Practice Widget
**File:** `apps/client/lib/src/features/tutorial/widgets/cipher_practice_widget.dart`

```dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class CipherPracticeWidget extends StatefulWidget {
  final String cipherType;
  final String encryptedText;
  final Map<String, dynamic> cipherKey;
  final String answer;
  final VoidCallback onCorrect;

  const CipherPracticeWidget({
    super.key,
    required this.cipherType,
    required this.encryptedText,
    required this.cipherKey,
    required this.answer,
    required this.onCorrect,
  });

  @override
  State<CipherPracticeWidget> createState() => _CipherPracticeWidgetState();
}

class _CipherPracticeWidgetState extends State<CipherPracticeWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isCorrect = false;
  bool _showHint = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: _isCorrect ? AppTheme.electricGreen : AppTheme.cyberBlue,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Encrypted Text:',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppTheme.spacing1),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: AppTheme.deepDark,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              widget.encryptedText,
              style: const TextStyle(
                color: AppTheme.cyberBlue,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            'Key: ${widget.cipherKey}',
            style: const TextStyle(
              color: AppTheme.electricGreen,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spacing3),
          TextField(
            controller: _controller,
            enabled: !_isCorrect,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter your answer...',
              hintStyle: const TextStyle(color: AppTheme.textDisabled),
              filled: true,
              fillColor: AppTheme.deepDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                borderSide: const BorderSide(color: AppTheme.cyberBlue),
              ),
              suffixIcon: _isCorrect
                  ? const Icon(Icons.check_circle, color: AppTheme.electricGreen)
                  : null,
            ),
            onSubmitted: _checkAnswer,
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCorrect ? null : () => _checkAnswer(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyberBlue,
                    disabledBackgroundColor: AppTheme.textDisabled,
                  ),
                  child: const Text('Submit'),
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              IconButton(
                icon: const Icon(Icons.lightbulb_outline),
                color: AppTheme.electricYellow,
                onPressed: () => setState(() => _showHint = !_showHint),
              ),
            ],
          ),
          if (_showHint) ...[
            const SizedBox(height: AppTheme.spacing2),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing2),
              decoration: BoxDecoration(
                color: AppTheme.electricYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.electricYellow),
              ),
              child: Text(
                'Hint: First letter is "${widget.answer[0]}"',
                style: const TextStyle(color: AppTheme.electricYellow),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _checkAnswer(String input) {
    if (input.trim().toUpperCase() == widget.answer.toUpperCase()) {
      setState(() => _isCorrect = true);
      widget.onCorrect();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not quite right. Try again!'),
          backgroundColor: AppTheme.neonRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## Missions Screen

**File:** `apps/client/lib/src/features/missions/missions_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepDark,
      appBar: AppBar(
        title: const Text('Daily Missions'),
        backgroundColor: AppTheme.darkNavy,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.cyberBlue,
          labelColor: AppTheme.cyberBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveMissions(),
          _buildCompletedMissions(),
          _buildWeeklyMissions(),
        ],
      ),
    );
  }

  Widget _buildActiveMissions() {
    // Mock data - replace with API call
    final missions = _getMockMissions();

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      itemCount: missions.length,
      itemBuilder: (context, index) => MissionCard(mission: missions[index]),
    );
  }

  Widget _buildCompletedMissions() {
    return const Center(
      child: Text(
        'No completed missions today',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildWeeklyMissions() {
    return const Center(
      child: Text(
        'Weekly missions coming soon!',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  List<Mission> _getMockMissions() {
    return [
      Mission(
        id: '1',
        name: 'Victory Lap',
        description: 'Win 2 matches today',
        progress: 1,
        target: 2,
        xpReward: 100,
        coinReward: 15,
        icon: Icons.emoji_events,
        expiresIn: const Duration(hours: 8),
      ),
      Mission(
        id: '2',
        name: 'Puzzle Master',
        description: 'Solve 5 puzzles today',
        progress: 3,
        target: 5,
        xpReward: 75,
        coinReward: 10,
        icon: Icons.extension,
        expiresIn: const Duration(hours: 8),
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class MissionCard extends StatelessWidget {
  final Mission mission;

  const MissionCard({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    final progressPercent = mission.progress / mission.target;
    final isComplete = mission.progress >= mission.target;

    return GlowCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing2),
                decoration: BoxDecoration(
                  color: AppTheme.cyberBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(mission.icon, color: AppTheme.cyberBlue),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      mission.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${mission.progress}/${mission.target}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(progressPercent * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppTheme.cyberBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        backgroundColor: AppTheme.textDisabled,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isComplete ? AppTheme.electricGreen : AppTheme.cyberBlue,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: AppTheme.electricGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${mission.xpReward} XP',
                    style: const TextStyle(
                      color: AppTheme.electricGreen,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing2),
                  const Icon(Icons.monetization_on, color: AppTheme.goldYellow, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${mission.coinReward} coins',
                    style: const TextStyle(
                      color: AppTheme.goldYellow,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (isComplete)
                ElevatedButton(
                  onPressed: () => _claimReward(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.electricGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing3,
                      vertical: AppTheme.spacing1,
                    ),
                  ),
                  child: const Text('Claim'),
                )
              else
                Text(
                  'Expires in ${_formatDuration(mission.expiresIn)}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _claimReward(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.electricGreen),
            const SizedBox(width: AppTheme.spacing2),
            Text('Claimed ${mission.xpReward} XP and ${mission.coinReward} coins!'),
          ],
        ),
        backgroundColor: AppTheme.darkNavy,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }
}

class Mission {
  final String id;
  final String name;
  final String description;
  final int progress;
  final int target;
  final int xpReward;
  final int coinReward;
  final IconData icon;
  final Duration expiresIn;

  Mission({
    required this.id,
    required this.name,
    required this.description,
    required this.progress,
    required this.target,
    required this.xpReward,
    required this.coinReward,
    required this.icon,
    required this.expiresIn,
  });
}
```

---

## Mastery Tree

**File:** `apps/client/lib/src/features/mastery/mastery_tree_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

class MasteryTreeScreen extends StatefulWidget {
  const MasteryTreeScreen({super.key});

  @override
  State<MasteryTreeScreen> createState() => _MasteryTreeScreenState();
}

class _MasteryTreeScreenState extends State<MasteryTreeScreen> {
  String selectedCipher = 'CAESAR';
  int availablePoints = 250;

  final List<String> cipherTypes = [
    'CAESAR',
    'VIGENERE',
    'RAIL_FENCE',
    'PLAYFAIR',
    'AFFINE',
    'AUTOKEY',
    'ENIGMA_LITE',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepDark,
      appBar: AppBar(
        title: const Text('Cipher Mastery'),
        backgroundColor: AppTheme.darkNavy,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMasteryTree()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      color: AppTheme.darkNavy,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedCipher,
                  decoration: InputDecoration(
                    labelText: 'Select Cipher',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.deepDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                  dropdownColor: AppTheme.deepDark,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  items: cipherTypes.map((cipher) {
                    return DropdownMenuItem(
                      value: cipher,
                      child: Text(cipher.replaceAll('_', ' ')),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedCipher = value!);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Points:',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing2,
                  vertical: AppTheme.spacing1,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cyberBlue.withOpacity(0.3),
                      AppTheme.electricGreen.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.cyberBlue),
                ),
                child: Text(
                  '$availablePoints pts',
                  style: const TextStyle(
                    color: AppTheme.cyberBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryTree() {
    final nodes = _getMockNodes();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      child: Column(
        children: [
          for (int tier = 1; tier <= 5; tier++) ...[
            _buildTierHeader(tier),
            const SizedBox(height: AppTheme.spacing2),
            Wrap(
              spacing: AppTheme.spacing2,
              runSpacing: AppTheme.spacing2,
              children: nodes
                  .where((node) => node.tier == tier)
                  .map((node) => MasteryNodeCard(
                        node: node,
                        onUnlock: _unlockNode,
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppTheme.spacing4),
          ],
        ],
      ),
    );
  }

  Widget _buildTierHeader(int tier) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing2,
            vertical: AppTheme.spacing1,
          ),
          decoration: BoxDecoration(
            color: AppTheme.neonPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.neonPurple),
          ),
          child: Text(
            'Tier $tier',
            style: const TextStyle(
              color: AppTheme.neonPurple,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing2),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.neonPurple.withOpacity(0.5),
                  AppTheme.neonPurple.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _unlockNode(MasteryNode node) {
    if (availablePoints >= node.cost) {
      setState(() {
        availablePoints -= node.cost;
        node.isUnlocked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unlocked: ${node.name}!'),
          backgroundColor: AppTheme.electricGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough mastery points!'),
          backgroundColor: AppTheme.neonRed,
        ),
      );
    }
  }

  List<MasteryNode> _getMockNodes() {
    return [
      MasteryNode(
        id: '1',
        name: 'Speed Boost I',
        description: '10% faster solve time',
        tier: 1,
        cost: 100,
        bonusType: 'speed_boost',
        bonusValue: 1.10,
      ),
      MasteryNode(
        id: '2',
        name: 'Hint Discount I',
        description: '25% cheaper hints',
        tier: 1,
        cost: 100,
        bonusType: 'hint_discount',
        bonusValue: 0.75,
      ),
      MasteryNode(
        id: '3',
        name: 'Speed Boost II',
        description: '20% faster solve time',
        tier: 2,
        cost: 200,
        bonusType: 'speed_boost',
        bonusValue: 1.20,
        prerequisiteId: '1',
      ),
      MasteryNode(
        id: '4',
        name: 'Score Multiplier I',
        description: '1.1x score multiplier',
        tier: 2,
        cost: 200,
        bonusType: 'score_multiplier',
        bonusValue: 1.10,
        prerequisiteId: '2',
      ),
    ];
  }
}

class MasteryNodeCard extends StatelessWidget {
  final MasteryNode node;
  final Function(MasteryNode) onUnlock;

  const MasteryNodeCard({
    super.key,
    required this.node,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  node.isUnlocked ? Icons.check_circle : Icons.lock_outline,
                  color: node.isUnlocked ? AppTheme.electricGreen : AppTheme.textDisabled,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      color: node.isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing1),
            Text(
              node.description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppTheme.spacing2),
            if (!node.isUnlocked)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onUnlock(node),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyberBlue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('${node.cost} pts'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.electricGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.electricGreen),
                ),
                child: const Text(
                  'ACTIVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MasteryNode {
  final String id;
  final String name;
  final String description;
  final int tier;
  final int cost;
  final String bonusType;
  final double bonusValue;
  final String? prerequisiteId;
  bool isUnlocked;

  MasteryNode({
    required this.id,
    required this.name,
    required this.description,
    required this.tier,
    required this.cost,
    required this.bonusType,
    required this.bonusValue,
    this.prerequisiteId,
    this.isUnlocked = false,
  });
}
```

---

## Note on Implementation

These code samples demonstrate the core UI structure. For a complete implementation:

1. **Connect to Backend Services**: Replace mock data with actual API calls
2. **State Management**: Implement Riverpod providers for each feature
3. **Missing Widgets**: Create helper widgets like progress indicators, badges, etc.
4. **Error Handling**: Add proper error states and loading indicators
5. **Animations**: Use `flutter_animate` package for transitions
6. **Testing**: Write widget tests for all components

See `CIPHER_CLASH_V2_IMPLEMENTATION_GUIDE.md` for the complete architecture overview.
