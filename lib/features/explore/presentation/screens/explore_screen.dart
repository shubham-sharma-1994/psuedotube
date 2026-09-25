import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../trending/presentation/screens/trending_screen.dart';

/// YTM Explore: Charts + Moods & genres.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const _moods = <(String, Color)>[
    ('Workout', Color(0xFFE53935)),
    ('Relax', Color(0xFF1E88E5)),
    ('Focus', Color(0xFF43A047)),
    ('Party', Color(0xFF8E24AA)),
    ('Sleep', Color(0xFF3949AB)),
    ('Romance', Color(0xFFD81B60)),
    ('Energize', Color(0xFFFB8C00)),
    ('Commute', Color(0xFF00897B)),
    ('Feel good', Color(0xFFFDD835)),
    ('Sad', Color(0xFF546E7A)),
    ('Chill', Color(0xFF00ACC1)),
    ('Jazz', Color(0xFF6D4C41)),
  ];

  void _openSearch(BuildContext context, [String? query]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select((SettingsProvider p) => p.accentColor);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.paddingLg,
              AppDimens.paddingMd,
              AppDimens.paddingLg,
              AppDimens.spacingSm,
            ),
            child: Text(
              'Charts',
              style: AppTextStyles.titleLg().copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
            child: Text(
              'Top songs by country and global charts',
              style: AppTextStyles.caption(isDarkMode: isDarkMode).copyWith(
                color: (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spacingSm)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child: const TrendingScreen(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.paddingLg,
              AppDimens.paddingXl,
              AppDimens.paddingLg,
              AppDimens.spacingMd,
            ),
            child: Text(
              'Moods & genres',
              style: AppTextStyles.titleLg().copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final (label, color) = _moods[index];
                return Material(
                  color: color.withValues(alpha: isDarkMode ? 0.85 : 0.9),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => _openSearch(context, label),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: _moods.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppDimens.paddingXl)),
      ],
    );
  }
}
