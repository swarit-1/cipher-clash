import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/progression_api.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Cosmetics shop: real catalog, coin-validated purchases, equipping.
class ShopScreen extends StatefulWidget {
  const ShopScreen({Key? key}) : super(key: key);

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _catalog = const [];
  Set<String> _owned = {};
  int _coins = 0;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final profile = await AuthService.fetchProfile();
    final catalogResp = await ProgressionApi.cosmeticsCatalog();
    final inventoryResp = await ProgressionApi.cosmeticsInventory();
    if (!mounted) return;

    if (!catalogResp.ok) {
      setState(() {
        _loading = false;
        _error = catalogResp.errorMessage;
      });
      return;
    }

    final catalogBody = catalogResp.json;
    final catalogList = catalogBody is Map
        ? (catalogBody['cosmetics'] ?? catalogBody['catalog'] ?? catalogBody['data'])
        : catalogBody;

    final inventoryBody = inventoryResp.json;
    final inventoryList = inventoryBody is Map
        ? (inventoryBody['inventory'] ?? inventoryBody['cosmetics'] ?? inventoryBody['data'])
        : inventoryBody;

    setState(() {
      _loading = false;
      _coins = (profile?['coins'] as num?)?.toInt() ?? 0;
      _catalog = catalogList is List
          ? catalogList
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
          : const [];
      _owned = inventoryList is List
          ? inventoryList
              .whereType<Map>()
              .map((e) => e['cosmetic_id'] as String? ?? '')
              .where((id) => id.isNotEmpty)
              .toSet()
          : {};
    });
  }

  Future<void> _purchase(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    setState(() => _busyId = id);
    final response = await ProgressionApi.purchaseCosmetic(id);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (response.ok) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Acquired ${item['name']}!'),
        backgroundColor: AppTheme.darkNavy,
      ));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.errorMessage),
        backgroundColor: AppTheme.neonRed,
      ));
    }
  }

  Future<void> _equip(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null) return;
    setState(() => _busyId = id);
    final response = await ProgressionApi.equipCosmetic(id);
    if (!mounted) return;
    setState(() => _busyId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(response.ok
          ? '${item['name']} equipped'
          : response.errorMessage),
      backgroundColor: response.ok ? AppTheme.darkNavy : AppTheme.neonRed,
    ));
  }

  Color _rarityColor(dynamic rarity) {
    switch (rarity) {
      case 'legendary':
      case 'mythic':
        return AppTheme.electricYellow;
      case 'epic':
        return AppTheme.neonPurple;
      case 'rare':
        return AppTheme.cyberBlue;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _categoryIcon(dynamic category) {
    switch (category) {
      case 'title':
        return Icons.military_tech;
      case 'avatar_frame':
        return Icons.filter_frames;
      case 'background':
        return Icons.wallpaper;
      case 'particle_effect':
        return Icons.auto_awesome;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing2),
              child: Text(
                '🪙 $_coins',
                style: const TextStyle(
                  color: AppTheme.electricYellow,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: AsyncView(
                loading: _loading,
                error: _error,
                onRetry: _load,
                empty: _catalog.isEmpty,
                emptyIcon: Icons.storefront,
                emptyTitle: 'The shop is being restocked',
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacing2),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: AppTheme.spacing1,
                    crossAxisSpacing: AppTheme.spacing1,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: _catalog.length,
                  itemBuilder: (context, index) =>
                      _buildItem(_catalog[index], index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item, int index) {
    final rarity = item['rarity'] as String? ?? 'common';
    final color = _rarityColor(rarity);
    final cost = (item['coin_cost'] as num?)?.toInt() ?? 0;
    final id = item['id'] as String? ?? '';
    final owned = _owned.contains(id);
    final affordable = _coins >= cost;
    final busy = _busyId == id;

    return GlowCard(
      glowVariant: owned ? GlowCardVariant.success : GlowCardVariant.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_categoryIcon(item['category']), color: color, size: 28),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  rarity.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing1),
          Text(
            item['name'] as String? ?? '???',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              item['description'] as String? ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppTheme.spacing1),
          SizedBox(
            width: double.infinity,
            child: owned
                ? OutlinedButton.icon(
                    onPressed: busy ? null : () => _equip(item),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: Text(busy ? '…' : 'EQUIP'),
                  )
                : FilledButton.tonal(
                    onPressed:
                        busy || !affordable || cost == 0 ? null : () => _purchase(item),
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            cost == 0 ? 'UNLOCKABLE' : '🪙 $cost',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: affordable && cost > 0
                                  ? AppTheme.electricYellow
                                  : AppTheme.textTertiary,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (30 * (index % 12)).ms);
  }
}
