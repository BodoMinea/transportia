import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/recent_search.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// The searches the rider ran most recently, each to run again with a tap,
/// under a heading. Nothing at all while there are none.
class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({
    super.key,
    required this.searches,
    required this.onTap,
  });

  final List<RecentSearch> searches;
  final ValueChanged<RecentSearch> onTap;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Recent searches', style: AppText.heading),
        const SizedBox(height: 12),
        for (final search in searches)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _SearchTile(search: search, onTap: () => onTap(search)),
          ),
      ],
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({required this.search, required this.onTap});

  final RecentSearch search;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.black.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Search again from ${search.from.name} to ${search.to.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.black.withValues(alpha: 0.07),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                search.from.isMyLocation
                    ? LucideIcons.locateFixed
                    : LucideIcons.history,
                size: 18,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    search.from.name,
                    style: AppText.listTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.chevronRight, size: 14, color: muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          search.to.name,
                          style: TextStyle(
                            color: muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(LucideIcons.search, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}
