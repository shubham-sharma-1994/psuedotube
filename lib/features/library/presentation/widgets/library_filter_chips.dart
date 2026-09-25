import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';

/// YTM-style horizontal filter chips for Library.
class LibraryFilterChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<String> labels;

  const LibraryFilterChips({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.select((SettingsProvider p) => p.accentColor);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
        itemCount: labels.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimens.spacingSm),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return FilterChip(
            label: Text(
              labels[index],
              style: AppTextStyles.chipLabel(isDarkMode: isDark).copyWith(
                color: selected ? Colors.white : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            selected: selected,
            onSelected: (_) => onSelected(index),
            selectedColor: accent,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            checkmarkColor: Colors.white,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
