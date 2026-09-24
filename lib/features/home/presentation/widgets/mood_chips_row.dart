import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../search/presentation/screens/search_screen.dart';

/// Horizontally scrollable mood / category chips (YTM Home style).
/// Tapping a chip opens Search so the user can explore that mood.
class MoodChipsRow extends StatelessWidget {
  const MoodChipsRow({super.key});

  static const _moods = <String>[
    'Workout',
    'Commute',
    'Focus',
    'Relax',
    'Energize',
    'Party',
    'Sleep',
    'Romance',
  ];

  void _openSearch(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.select((SettingsProvider p) => p.accentColor);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
        physics: const BouncingScrollPhysics(),
        itemCount: _moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.spacingSm),
        itemBuilder: (context, index) {
          final label = _moods[index];
          return ActionChip(
            label: Text(
              label,
              style: AppTextStyles.chipLabel(isDarkMode: isDark),
            ),
            onPressed: () => _openSearch(context),
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            // Subtle accent on first chip to match YTM "selected" affordance
            surfaceTintColor: index == 0 ? accent : null,
          );
        },
      ),
    );
  }
}
