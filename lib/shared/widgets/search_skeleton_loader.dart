import 'package:flutter/material.dart';

import 'premium_widgets.dart';

/// Three stacked shimmer skeleton cards for search / barcode lookup states.
class SearchSkeletonLoader extends StatelessWidget {
  const SearchSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SearchResultSkeletonCard(),
        SizedBox(height: 10),
        _SearchResultSkeletonCard(),
        SizedBox(height: 10),
        _SearchResultSkeletonCard(),
      ],
    );
  }
}

class _SearchResultSkeletonCard extends StatelessWidget {
  const _SearchResultSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          ShimmerSkeletonBlock(height: 48, width: 48, borderRadius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeletonBlock(height: 16, width: double.infinity),
                const SizedBox(height: 8),
                ShimmerSkeletonBlock(height: 12, width: 140),
                const SizedBox(height: 10),
                ShimmerSkeletonBlock(height: 10, width: 100),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerSkeletonBlock(height: 22, width: 52, borderRadius: 999),
                    const SizedBox(width: 6),
                    ShimmerSkeletonBlock(height: 22, width: 52, borderRadius: 999),
                    const SizedBox(width: 6),
                    ShimmerSkeletonBlock(height: 22, width: 52, borderRadius: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
