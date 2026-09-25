import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/favorite_song_provider.dart';
import '../../../../core/providers/settings_provider.dart';

/// YTM-style pinned "Liked songs" row at the top of Library.
class LikedSongsLibraryRow extends StatelessWidget {
  final VoidCallback? onTap;

  const LikedSongsLibraryRow({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.select((SettingsProvider p) => p.accentColor);
    final favorites = context.watch<FavoriteSongProvider>();
    final count = favorites.likedSongs.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.paddingLg,
            vertical: AppDimens.spacingMd,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.9),
                      accent.withValues(alpha: 0.45),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDimens.spacingLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liked songs',
                      style: AppTextStyles.titleSm(isDarkMode: isDark).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'No liked songs yet'
                          : '$count song${count == 1 ? '' : 's'}',
                      style: AppTextStyles.caption(isDarkMode: isDark).copyWith(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
