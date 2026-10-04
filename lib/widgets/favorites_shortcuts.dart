import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/favorites_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/favorite_icons.dart';

/// The rider's favourite places as a row of shortcuts, under a heading, for
/// the home screen. One tap goes there from where they are.
///
/// Reads [FavoritesService.favoritesListenable], so a place hearted anywhere
/// in the app is here as soon as it is kept; loading it is the screen's job.
class FavoritesShortcuts extends StatelessWidget {
  const FavoritesShortcuts({super.key, required this.onTap});

  final ValueChanged<FavoritePlace> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Favourites', style: AppText.heading),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<FavoritePlace>>(
          valueListenable: FavoritesService.favoritesListenable,
          builder: (context, favorites, _) {
            if (favorites.isEmpty) return const _NoFavourites();
            return _ShortcutRow(favorites: favorites, onTap: onTap);
          },
        ),
      ],
    );
  }
}

/// Side of one shortcut tile.
const double _kShortcutSize = 96;

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.favorites, required this.onTap});

  final List<FavoritePlace> favorites;
  final ValueChanged<FavoritePlace> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final favorite in favorites) ...[
            _Shortcut(favorite: favorite, onTap: () => onTap(favorite)),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.favorite, required this.onTap});

  final FavoritePlace favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Go to ${favorite.displayName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: _kShortcutSize,
          height: _kShortcutSize,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentWash(accent),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  iconForFavorite(favorite.iconName),
                  size: 22,
                  color: accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                favorite.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoFavourites extends StatelessWidget {
  const _NoFavourites();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentWash(accent),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.heart, size: 24, color: accent),
          ),
          const SizedBox(height: 12),
          Text('No favourites yet', style: AppText.heading),
          const SizedBox(height: 4),
          Text(
            'Tap the heart on a place when you search for one, and it will be '
            'here.',
            textAlign: TextAlign.center,
            style: AppText.subtitle,
          ),
        ],
      ),
    );
  }
}
