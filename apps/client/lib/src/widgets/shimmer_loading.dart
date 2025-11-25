import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Cyberpunk-themed shimmer loading effect
class ShimmerLoading extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    Key? key,
    this.width,
    this.height,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.darkNavy.withValues(alpha: 0.3),
      highlightColor: AppTheme.cyberBlue.withValues(alpha: 0.2),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.darkNavy,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Shimmer loading for list items
class ShimmerListItem extends StatelessWidget {
  const ShimmerListItem({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const ShimmerLoading(width: 60, height: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoading(
                  height: 16,
                  width: double.infinity,
                ),
                const SizedBox(height: 8),
                ShimmerLoading(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer loading for cards
class ShimmerCard extends StatelessWidget {
  final double height;

  const ShimmerCard({
    Key? key,
    this.height = 120,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      width: double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
    );
  }
}
